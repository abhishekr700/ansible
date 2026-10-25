# Proxmox API tokens (proxmox-blr-ws)

Run these on `proxmox-blr-ws` as root yourself. Both tokens are made by hand, not by Terraform:
Terraform can't create its own token, and a token created by Terraform would leave its secret in
plaintext in the state file. Creating it from Terraform would also need `User.Modify` and
`Permissions.Modify`, which makes the Terraform token nearly an admin.

## 1. Terraform token: scoped to the `agent` pool

Everything Terraform manages (template 9000, VM 120) lives in the resource pool `agent`. VM
privileges are granted on `/pool/agent` only, so this token **can't touch existing guests**
(101 jellyfin, 105 hephaestus) or anything else outside the pool.

```sh
pveum pool add agent --comment "Terraform-managed: agent-devbox + its template"

pveum role add TerraformAgent -privs "\
VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
VM.PowerMgmt VM.GuestAgent.Audit \
Datastore.AllocateSpace Datastore.Audit SDN.Use Sys.Audit Pool.Audit"

pveum user add terraform@pve --comment "Terraform (agent pool only)"

# VMs and templates: only inside the pool
pveum acl modify /pool/agent                 --users terraform@pve --roles TerraformAgent
# Disks + cloud-init drive on local-lvm; read the image and snippet on local
pveum acl modify /storage/local-lvm          --users terraform@pve --roles TerraformAgent
pveum acl modify /storage/local              --users terraform@pve --roles TerraformAgent
# Attach NICs to vmbr0
pveum acl modify /sdn/zones/localnetwork     --users terraform@pve --roles TerraformAgent
# Read node status
pveum acl modify /nodes/proxmox-blr-ws       --users terraform@pve --roles TerraformAgent

# privsep 0: the token has exactly the user's (already scoped) permissions
pveum user token add terraform@pve tf --privsep 0 --comment "terraform/proxmox-blr-ws"
```

The last command prints the secret **once**. Store it outside the repo, next to the Tailscale OAuth vars
in your shell env file:

```sh
export PROXMOX_VE_API_TOKEN='terraform@pve!tf=<secret>'
```

Not verified yet: whether this privilege list is exactly enough. If an apply fails with
`403 ... Permission check failed (/..., <Privilege>)`, add that one privilege to the role
(`pveum role modify TerraformAgent -append 1 -privs <Privilege>`) instead of widening paths.

Revoke: `pveum user token remove terraform@pve tf` (or `pveum user delete terraform@pve`).

## 2. Agent token: read-only (PVEAuditor)

For Hermes to read Proxmox state. Can't change anything.

```sh
pveum user add agent@pve --comment "Hermes Agent, read-only"
pveum acl modify / --users agent@pve --roles PVEAuditor
pveum user token add agent@pve hermes --privsep 0 --comment "agent-devbox read-only"
```

Notes:
- PVEAuditor on `/` can read every guest's config, storage and node status, including cloud-init
  settings. That's the point, but it's still visibility of the whole host.
- **The agent can't reach the API yet.** The Tailscale policy only allows `tag:agent` → `atlas:443`,
  and the LAN is blocked. To use the token, add a rule `tag:agent` → `proxmox-blr-ws:8006` in
  `terraform/tailscale/policy.hujson` (and update its tests), then apply.
- Giving the secret to Hermes is your call. It isn't put on the VM by Ansible (no credentials for other
  hosts on the box).

Revoke: `pveum user token remove agent@pve hermes`.
