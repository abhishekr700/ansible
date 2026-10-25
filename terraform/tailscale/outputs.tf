output "agent_devbox_auth_key" {
  description = "One-time auth key for agent-devbox to join as tag:agent."
  value       = tailscale_tailnet_key.agent_devbox.key
  sensitive   = true
}
