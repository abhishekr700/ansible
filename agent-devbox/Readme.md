# agent-devbox

A disposable VM (VMID 120) on `proxmox-blr-ws` that runs Hermes Agent and Claude Code. The agents have
full control inside the VM, but no standing access to storage or other hosts.

## The big picture (read this first)

Four layers, each built on the one before. **Terraform creates things; Ansible configures them.**

```
 ┌─ 1. Host prep ────────── Ansible → proxmox-blr-ws (as root) ─────────────────────┐
 │  Only places files on the host; creates no VM.                                   │
 │  1a. proxmox-blr-ws/setup-proxmox-blr-ws-vm-base.yaml     (reusable, any VM)     │
 │      • enables "snippets" on the local storage                                   │
 │      • downloads the Debian 13 cloud image (.qcow2, pinned in                    │
 │        host_vars/proxmox-blr-ws.yml + checksummed)                 ── used in 2  │
 │  1b. proxmox-blr-ws/setup-proxmox-blr-ws-agent-devbox.yaml  (devbox only)        │
 │      • stores VM 120's cloud-init file on local:snippets           ── used in 3  │
 │        (source: proxmox-blr-ws/templates/agent-devbox-user-data.yaml.j2)         │
 └──────────────────────────────────────────────────────────────────────────────────┘
                     │ image file
                     ▼
 ┌─ 2. Template 9000 ────── Terraform → Proxmox API ────────────────────────────────┐
 │  terraform/proxmox-blr-ws/debian13-template/                                     │
 │  image file → a frozen master disk. Never runs; only gets cloned.                │
 │  Bare Debian 13: no user of ours, no key, nothing devbox-specific.               │
 └──────────────────────────────────────────────────────────────────────────────────┘
                     │ clone
                     ▼
 ┌─ 3. VM 120 agent-devbox ─ Terraform → Proxmox API ───────────────────────────────┐
 │  terraform/proxmox-blr-ws/agent-devbox/                                          │
 │  clone + 4 CPU / 8 GB / 64 GB, boots, outputs its LAN IP.                        │
 │  The cloud-init file from step 1 is attached here; at first boot it creates      │
 │  user abhi (your key, sudo) and installs qemu-guest-agent.                       │
 │  Also holds the Proxmox VM firewall rules (written, switched OFF for now).       │
 └──────────────────────────────────────────────────────────────────────────────────┘
                     │ SSH (first time via LAN + ProxyJump, after that via Tailscale)
                     ▼
 ┌─ 4. Inside the VM ────── Ansible → agent-devbox ─────────────────────────────────┐
 │  agent-devbox/setup-agent-devbox.yaml                                            │
 │  base hardening → Tailscale → hermes user → Docker → Hermes → Claude → ufw (last)│
 └──────────────────────────────────────────────────────────────────────────────────┘

 Side layer: Tailscale  ── Terraform → Tailscale API ── terraform/tailscale/
   • the WHOLE tailnet policy (tag:agent may only reach atlas:443)
   • the one-time join key that step 4 uses
```

### Who's allowed to do what

| Thing | Credential | Lives in | Can touch |
|---|---|---|---|
| Terraform → Proxmox | token `terraform@pve!tf` | `PROXMOX_VE_API_TOKEN` in your shell env file | only pool `agent` (template 9000, VM 120); **not** jellyfin/hephaestus |
| Terraform → Tailscale | OAuth client | `TAILSCALE_OAUTH_*` in your shell env file | tailnet policy + `tag:agent` keys |
| Ansible → host | your SSH key as root | `~/.ssh` | the host (as always) |
| Ansible → VM | your SSH key as `abhi` (passwordless sudo) | `~/.ssh` | the VM |
| Hermes in the VM | none for other hosts | — | inside the VM only |

### Users on the VM

| User | Purpose | Privileges | How you get there |
|---|---|---|---|
| `abhi` | your admin login; Ansible connects as it | passwordless sudo | `ssh abhi@agent-devbox` |
| `hermes` | runs Hermes Agent (`~/.hermes`, user service `hermes-gateway`) and Claude Code (`~/.claude`) | **no sudo**; `docker` group (root-equivalent inside the VM only) | `sudo -iu hermes` from `abhi` |

The `hermes` and `claude` commands exist only for the `hermes` user (`~hermes/.local/bin`). As `abhi`, you get
`command not found`. Switch with `sudo -iu hermes`; the `-i` sets up its PATH.

Terraform's env vars only load in an interactive shell, so an agent on your Mac runs it as `zsh -ic 'terraform ...'`.
You run `terraform apply` yourself (Claude's auto mode blocks it).

### Where the state lives (don't lose these)

- `terraform/*/terraform.tfstate`: local only, gitignored. Losing it doesn't break the VM,
  but Terraform forgets it owns it (recover with `terraform import`).
- `~hermes/.hermes` and `~hermes/.claude` inside the VM: Hermes config, memory and sessions, and the Claude
  login and history. Only backups protect them (`docs/backup.md`).

### "I want to…" cheat sheet

| Goal | Do |
|---|---|
| Change VM CPU/RAM/disk | edit `terraform/proxmox-blr-ws/agent-devbox/main.tf` → plan → apply |
| Change something inside the VM | edit `agent-devbox/*.yaml` or `host_vars/agent-devbox.yml` → `ansible-playbook -i inventory.yaml agent-devbox/setup-agent-devbox.yaml` |
| Let the agent reach a new host | `terraform/tailscale/policy.hujson` (+ tests) → apply; see "Temporary SSH" below |
| Start over from scratch | **Rebuild** below |
| Get rid of it | **Destroy** below |
| Check the agent's isolation | the reachability checks in "What was built and verified" |

### What was built and verified (2026-10-25)

- Template 9000 and VM 120 created. VM 120 is on DHCP at `192.168.5.141`, and on the tailnet as
  `agent-devbox` / `100.81.5.90` / `tag:agent`.
- The playbook is idempotent: the second run gave `changed=0`.
- From inside the VM:
  - **blocked:** Proxmox host over LAN (22, 8006), router admin (v4 + v6),
    proxmox-blr-ws/prometheus/hermes-Pi over the tailnet;
  - **open:** atlas:443, internet, DNS to the router.
- Found and fixed on the way: the cloud image has no gpg (added `gnupg`); `hermes gateway install`
  prompts on the tty (now non-interactive flags); the LAN also runs IPv6 (added v6 blocks).
- 2026-10-26: Claude Code (2.1.310) installed for `hermes`; the second run gave `changed=0`.

Isolation, as built:
- **Tailscale policy:** `tag:agent` → `atlas:443` only. This is the real boundary.
- **ufw in the VM:** inbound SSH on `tailscale0` only, plus best-effort outbound LAN deny.
  The agent can undo this, and it doesn't apply to container traffic.
- **Proxmox VM firewall:** written but **off** (`vm_firewall_enabled = false`) because the datacenter
  firewall is off. Turn both on when you're next at the machine.
- **Storage:** no NFS, SMB or ZFS mounts, no passthrough. The `hermes` user has no sudo; it's in the docker group.

## Prerequisites (once)

1. Tokens: follow `docs/proxmox-tokens.md` (pool `agent`, `terraform@pve!tf`). Export `PROXMOX_VE_API_TOKEN`.
2. Host prep (base first, then the devbox cloud-init file):
   `ansible-playbook -i inventory.yaml proxmox-blr-ws/setup-proxmox-blr-ws-vm-base.yaml proxmox-blr-ws/setup-proxmox-blr-ws-agent-devbox.yaml`
3. Template:
   ```sh
   terraform -chdir=terraform/proxmox-blr-ws/debian13-template init
   terraform -chdir=terraform/proxmox-blr-ws/debian13-template plan    # review
   terraform -chdir=terraform/proxmox-blr-ws/debian13-template apply
   ```

## Create

```sh
TF=terraform/proxmox-blr-ws/agent-devbox
terraform -chdir=$TF init
terraform -chdir=$TF plan       # review
terraform -chdir=$TF apply
IP=$(terraform -chdir=$TF output -raw ipv4_address)

# Fresh one-time join key (the key expires 1h after creation)
zsh -ic 'terraform -chdir=terraform/tailscale apply -replace=tailscale_tailnet_key.agent_devbox'

# Accept the host key once, through the Proxmox host (the VM isn't on Tailscale yet)
ssh -J root@100.113.136.34 abhi@$IP true

# First run: LAN IP via ProxyJump
TS_AUTHKEY="$(zsh -ic 'terraform -chdir=terraform/tailscale output -raw agent_devbox_auth_key')" \
ansible-playbook -i inventory.yaml agent-devbox/setup-agent-devbox.yaml \
  -e ansible_host=$IP -e "ansible_ssh_common_args='-J root@100.113.136.34'"
```

From then on, connect over Tailscale (`ssh abhi@agent-devbox`) and run the playbook without extras:

```sh
ansible-playbook -i inventory.yaml agent-devbox/setup-agent-devbox.yaml
```

### Configure Hermes (manual, interactive)

```sh
ssh abhi@agent-devbox
sudo -iu hermes
hermes setup          # model / provider login
hermes gateway setup  # Telegram bot token + allowed user IDs (TELEGRAM_ALLOWED_USERS)
hermes doctor
```

Then set `hermes_gateway_enabled: true` in `host_vars/agent-devbox.yml` and run
`ansible-playbook -i inventory.yaml agent-devbox/setup-agent-devbox.yaml --tags hermes`.
Logs: `sudo -iu hermes journalctl --user -u hermes-gateway -f`.

### Sign in Claude Code (manual, once)

As `hermes`, run `claude`, then `/login` with your account. There's no API key on the box, and nothing goes in the repo.
After a rebuild, sign in again.

## Rebuild

Throws away everything in the VM, including `~hermes/.hermes` and the Claude login. Take a backup first if you want it (`docs/backup.md`).

```sh
terraform -chdir=$TF apply -replace=proxmox_virtual_environment_vm.agent_devbox
```

Then remove the old `agent-devbox` device in the Tailscale admin console (otherwise the new one becomes
`agent-devbox-1`), run `ssh-keygen -R agent-devbox` and `ssh-keygen -R $IP`, and follow **Create**
from "Fresh one-time join key" onwards.

## Destroy

```sh
terraform -chdir=$TF destroy
```

Then remove the device in the Tailscale console. The template, the snippet and the image stay;
remove them with `terraform -chdir=terraform/proxmox-blr-ws/debian13-template destroy` if you want.

## Temporary SSH from the agent to another host

Grant takes both steps: the network path, and the key on the target.

1. **Network:** in `terraform/tailscale/policy.hujson`, under `AGENT-DEVBOX`, uncomment the SSH rule,
   set `"dst": ["<host>:22"]` and update the test that denies it. Then plan and apply that root.
2. **Key:** get the agent's key with `ssh abhi@agent-devbox sudo cat /home/hermes/.ssh/id_ed25519.pub`.
   Add it to the target's `~/.ssh/authorized_keys`, ideally with a restricting prefix and an expiry:
   ```
   expiry-time="20261101",no-agent-forwarding,no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAA... hermes@agent-devbox
   ```
   Use a dedicated low-privilege user on the target rather than your own, where you can.

To revoke, delete that line from `authorized_keys`, and revert the policy rule and its test, then apply.
Either step alone already cuts access. `expiry-time` revokes the key on its own when it runs out.
