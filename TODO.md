# TODO

Open work across the homelab. Each item links to where the detail lives. Remove items when done.

## Proxmox firewall for agent-devbox (security gap)
The VM's LAN block is ufw inside the guest only. `hermes` is in the docker group (root-equivalent), so it can
turn ufw off and reach the LAN (Proxmox UI, Jellyfin, router). Tailscale doesn't cover the LAN path.
- Fix: enable the Proxmox datacenter firewall and the VM rules that are already written
  (`vm_firewall_enabled` in `terraform/proxmox-blr-ws/agent-devbox`). See `agent-devbox/Readme.md`, "Isolation, as built".
- **Only when you have a way back in** (at the machine, or a tested out-of-band path): a wrong datacenter rule
  can lock you out of proxmox-blr-ws.
- Check its default policy keeps SSH/8006 open for your own access, apply, then test from the VM that the
  LAN, v4 and v6, is unreachable with ufw switched off.

## foodies-app: local dev writes to the production DB
`foodies-app/.env` points at the production Supabase project, so a local `npm run dev` or
the e2e tests write real data. That's how "Debug User" (e2e-place-add@example.com) got into production on 2026-10-04;
it stays, by the user's choice. Fix: a separate dev database (local Postgres in Docker, or a second Supabase project).

## Homelab agent (trusted, holds credentials)
A second agent, separate from the dev agent on agent-devbox, for delegated homelab tasks.
- Separate VM and credentials. **No channel from the dev agent**: no shared memory, Telegram bot or repos it acts on.
- Read-only by default: status, logs, diagnosis.
- Writes go through the `ansible` repo as merge requests that you merge. Break-glass only for urgent cases.
- Narrow credentials per job (like the Proxmox token limited to pool `agent`). No root keys to everything.
- Few inputs: only you instruct it, no general web browsing, no package installs or dev work.
- A log of every command it runs.
- First decide whether Claude Code on the laptop, with you approving, is enough before building an always-on agent.

## Agent git access (in progress)
GitLab deploy key for the dev agent: `terraform/gitlab/README.md`, Status section.
