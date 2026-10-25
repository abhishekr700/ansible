# Handoff: Tailscale policy + auth key under Terraform

Written 2026-10-25 from the `agent-devbox` planning session. That session continues
separately; this one only owns the Tailscale piece. Read this whole file first.

## Why this exists

We're building `agent-devbox`, an isolated VM on `proxmox-blr-ws` that runs Hermes Agent
(a personal AI agent, reached over Telegram/CLI). The agent gets full control inside the
VM but must not have standing access to the rest of the tailnet. The VM joins Tailscale
as `tag:agent`, so the tailnet policy is the main network boundary. (The Proxmox
datacenter firewall is deliberately **not** being enabled: the user has no physical
access to the host right now and doesn't want to risk losing remote access.)

The user decided to bring the **entire** tailnet policy under Terraform, not just apply a
snippet by hand in the admin console.

The user said they were "facing some issues" before this was handed off. Details weren't
captured; most likely around creating the OAuth client. Ask them what went wrong first.

## Scope of this session

1. Get Tailscale API credentials working (OAuth client, see below).
2. Create `terraform/tailscale/` as its own Terraform root module.
3. Import the **current** policy into `tailscale_acl` so the first plan is a true diff.
4. Add `tag:agent` rules (below) without breaking existing access for any other device.
5. Add a `tailscale_tailnet_key` for the VM's one-time join, exposed as an output.
6. Show the user `terraform plan` and the policy diff. **Apply only after they approve.**

Out of scope here: the Proxmox VM, template, and Ansible. Those are handled in the main session.

## Decisions already made (don't re-ask)

- Terraform lives in this repo (`ansible/`) under `terraform/`, one root per stack.
  This one is `terraform/tailscale/` (tailnet-wide, so it's not under a Proxmox host dir).
- Provider: `tailscale/tailscale` (latest is 0.29.2 as of 2026-10-25). Pin it.
- Auth: an **OAuth client**, not an API key (API keys expire every ≤90 days).
  Credentials via env vars only: `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`.
  The user creates it in admin console → Settings → OAuth clients, with scopes:
  - `policy_file` (write)
  - `auth_keys` (write), tag restricted to `tag:agent`
  The tailnet setting may need to be `-` or `taila8099.ts.net` with OAuth; verify against provider docs.
- Auth key: **one-time use**, tagged `tag:agent`, pre-approved, not ephemeral, short expiry
  (e.g. 1h). The user accepts it sitting in state (single-use, quick expiry).
- Never commit secrets. State stays local and gitignored for now.

## Facts gathered (2026-10-25)

- Tailnet DNS suffix: `taila8099.ts.net`. Owner/login: abhishekr700@ (the user's own account).
- **No device currently has a tag.** All devices are owned by the user's account. Relevant ones:
  - `atlas` 100.101.51.88: Oracle VM; CouchDB is served on **443 via Tailscale Serve**.
  - `proxmox-blr-ws` 100.113.136.34: the host the VM will run on.
  - `hermes` 100.71.201.14: an **existing Raspberry Pi**, unrelated to Hermes Agent. Don't confuse them.
  - Others: bifrost, hephaestus, prometheus, nanokvm, macbook, iphone, plus many offline nodes.
- The current policy contents are **unknown**. Read them via the API once credentials work
  (read-only) before writing anything.

## Target policy behaviour for `tag:agent`

- `tagOwners`: `tag:agent` owned by the user (e.g. `autogroup:admin` or their login).
- Outbound from `tag:agent`: **only** `atlas` on `tcp:443`. Use a `hosts` alias or
  the IP for atlas, since atlas isn't tagged.
- SSH **to other hosts**: none yet. Leave a clearly commented, empty placeholder
  (e.g. a `hosts`/group the user can fill) for "SSH to hosts I list later".
  This is how temporary access gets granted and revoked.
- Inbound to `tag:agent`: the user's own devices may SSH (`tcp:22`) to it. Nothing else.
- Prefer `grants` syntax if the current policy uses it; match whatever style the existing policy uses.

### The trap to check carefully

If the existing policy has the default allow-all (`src: ["*"], dst: ["*:*"]` or the
equivalent grant), `tag:agent` matches `*` and would reach everything. Fix by narrowing
`src` from `*` to `autogroup:member` (tagged devices are not members). Since no device
is currently tagged, this shouldn't change access for any existing device. **Verify** that
against the real policy and show the user. Also check `ssh` rules, `autoApprovers`, and
`nodeAttrs` for wildcards that would cover `tag:agent`.

Use `tests` in the policy file to assert: agent → atlas:443 accepted; agent →
proxmox-blr-ws:22/8006, prometheus, bifrost, hermes denied; user's macbook → agent:22 accepted.
Tailscale rejects a policy whose tests fail, which is a free safety net.

## Contract with the main session

The main session's Ansible will read the key with:

```
terraform -chdir=terraform/tailscale output -raw agent_devbox_auth_key
```

Keep that output name, mark it `sensitive = true`. For rebuilds:
`terraform -chdir=terraform/tailscale apply -replace=tailscale_tailnet_key.agent_devbox`.

## Repo conventions

- The repo is mostly Ansible: per-host dirs, `setup-<host>.yaml`, hyphen-case filenames,
  `host_vars/<host>.yml`, `inventory.yaml` at the root. No Terraform existed before this.
- `.gitignore` has no Terraform entries yet. Add if missing: `**/.terraform/`,
  `*.tfstate`, `*.tfstate.*`, `*.tfvars` (keep `!*.tfvars.example`), `crash.log`.
  Commit `.terraform.lock.hcl`.
- The user's global rules: verify before claiming something works; say what was and wasn't
  verified; commit only when asked; read-only inspection is fine, applies need approval.

## Suggested files

```
terraform/tailscale/
├── versions.tf        # terraform + provider pin
├── providers.tf       # oauth via env vars
├── policy.hujson      # full policy, loaded with file()
├── main.tf            # tailscale_acl + tailscale_tailnet_key
├── outputs.tf         # agent_devbox_auth_key (sensitive)
└── README.md          # credentials setup, import, plan/apply, key rotation, how to grant/revoke SSH
```

Import the existing policy first (`terraform import tailscale_acl.this acl`, or an `import`
block; check provider docs). Then edit `policy.hujson` so the plan only shows the `tag:agent` changes.

## Done when

- `terraform plan` shows only the intended policy changes plus the new key, and the user has reviewed it.
- After the user approves the apply: the policy tests pass, `tag:agent` is in `tagOwners`, and the
  output works (check that it's non-empty; don't print it).
- Report back what was applied and verified, so the main session can continue with the VM.

## Status (2026-10-25): DONE, applied

- Applied by the user. Live policy == `policy.hujson` (diffed via API); `terraform plan` is clean.
- Policy: the three `src: ["*"]` rules (allow-all, iperf, uptime-kuma) now use `autogroup:member`.
  `tag:agent` → `atlas:443/tcp` only. Commented SSH placeholder under `AGENT-DEVBOX`.
  Tests in the policy (enforced, verified with a deliberately failing test) cover agent deny/accept.
- Inbound to the agent from the user's devices is **all ports** (not just 22): the member allow-all
  has `dst *:*` and ACLs are allow-only. Accepted; the agent can't initiate to them.
- Key `tailscale_tailnet_key.agent_devbox`: one-time, tag:agent, preauthorized, not ephemeral.
  Expires **2026-10-25T12:05:09Z**. If the VM isn't up by then:
  `terraform -chdir=terraform/tailscale apply -replace=tailscale_tailnet_key.agent_devbox`.
- Credentials: OAuth client vars live in the user's zsh env file; they only load in an
  interactive shell, so run Terraform via `zsh -ic '...'` from Claude's Bash tool.
- Claude's auto mode blocks `terraform apply`; the user runs applies themselves.
- Not committed yet.
