# Adopt the existing tailnet policy instead of overwriting it blindly.
import {
  to = tailscale_acl.this
  id = "acl"
}

resource "tailscale_acl" "this" {
  acl = file("${path.module}/policy.hujson")
}

# One-time join key for agent-devbox. Rotate with:
#   terraform apply -replace=tailscale_tailnet_key.agent_devbox
resource "tailscale_tailnet_key" "agent_devbox" {
  description   = "agent-devbox one-time join"
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags          = ["tag:agent"]

  # Tags must exist in tagOwners before a key can carry them.
  depends_on = [tailscale_acl.this]
}
