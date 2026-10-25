# terraform/tailscale

Manages the **whole** tailnet policy (`policy.hujson`) and the one-time join key for
`agent-devbox` (`tag:agent`). Edit the policy here, not in the admin console, or the
next apply will overwrite console edits.

## Credentials

An OAuth client from admin console → Settings → **Trust credentials** → Credential → OAuth:

- Policy file: Write
- Auth keys: Write, tag `tag:agent`

Export in your shell env file (never commit):

```sh
export TAILSCALE_OAUTH_CLIENT_ID=...
export TAILSCALE_OAUTH_CLIENT_SECRET=...
```

## Usage

```sh
terraform init
terraform plan     # policy diff + key
terraform apply
```

The existing policy was adopted with the `import` block in `main.tf`.
Tailscale runs the `tests` in `policy.hujson` on every save and rejects the policy if any fail.

## Auth key

One-time, pre-approved, not ephemeral, expires 1h after creation. Read it with:

```sh
terraform output -raw agent_devbox_auth_key
```

New key (rebuild, or the old one expired before use):

```sh
terraform apply -replace=tailscale_tailnet_key.agent_devbox
```

## Granting / revoking agent SSH to other hosts

In `policy.hujson`, under `AGENT-DEVBOX`, uncomment the placeholder rule and list hosts
(`"dst": ["prometheus:22"]`), then apply. Revoke by commenting it out and applying again.
Update the `deny` list in `tests` to match, or the apply will fail.

## Why `autogroup:member` instead of `*`

Tailscale ACLs are allow-only. Any rule with `src: ["*"]` also matches `tag:agent`, so
broad rules use `autogroup:member` (untagged devices of tailnet users) instead. Don't add
new `"*"` sources.
