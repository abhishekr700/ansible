# AGENTS.md

Homelab infra for one person. Ansible configures machines; Terraform creates VMs and the tailnet policy.

## Map
- `inventory.yaml` (root, gitignored: it has public IPs and the repo is public), `host_vars/<host>.yml`, `roles/`, one folder per host with `setup-<host>.yaml` as the entry playbook.
- `terraform/<scope>/<root>/`: one root per stack, local state (gitignored).
- Machine docs, so start there: `agent-devbox/Readme.md` (Hermes Agent VM on proxmox-blr-ws: layers, credentials, rebuild).
  Tailnet policy: `terraform/tailscale/README.md`.
- `hermes` in the inventory is a Raspberry Pi, not Hermes Agent.

## Conventions
- Filenames are hyphen-case (`setup-foo.yaml`). Host-specific vars go in `host_vars/`, not in playbooks.
- Dedicated app playbooks are `import_playbook`-ed at the end of the host's main playbook.
- `include_tasks` + tags: use `apply: {tags: x}` as well as `tags: x`, or the included tasks won't be tagged.
- Use `become: true` only where needed (some hosts need `-K` for the sudo password). Use modules over `command`/`shell`; when `command` is unavoidable, make it idempotent (`creates`, guards, `changed_when`).
- Compose: inline static values instead of `.env` files where possible.

## Security defaults (apply without asking)
- Scoped credentials only (e.g. the Proxmox token is limited to pool `agent`), never root@pam. Secrets go in env vars or gitignored files, never in the repo, and out of Terraform state where possible.
- Least exposure: open only the path that's used (SSH on `tailscale0`), key-only SSH, no root login, no agent forwarding into untrusted VMs.
- The Tailscale policy is the network boundary. Tag untrusted machines, keep `tests` in the policy, and no `src: "*"` (use `autogroup:member`).
- Untrusted/agent VMs: no host mounts or passthrough, no creds for other hosts, block LAN egress on IPv4 **and IPv6** (the LAN runs ULA).
- Say so when a layer is weak: an in-guest ufw can be undone by root/docker users, and Docker bypasses ufw.
- Pin and verify inputs: image builds with checksums, provider versions.

## Working rules
- Read-only inspection is fine. Before any change: `terraform plan`, or `ansible-playbook --check --diff`. Show it, then wait.
- The user runs `terraform apply` themselves. Verify idempotency with a second run (`changed=0`).
- Terraform credentials load only in an interactive shell: `zsh -ic 'terraform -chdir=... plan'`.
- Never touch existing guests (proxmox-blr-ws: LXC 101 jellyfin, 105 hephaestus), storage pools or backups.
- No host firewall or network changes on remote hosts: the user often has no physical access.
- Commit only when asked.
