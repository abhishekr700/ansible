# Token comes from the environment only (see agent-devbox/docs/proxmox-tokens.md):
#   PROXMOX_VE_API_TOKEN="terraform@pve!tf=<secret>"
# No ssh block: everything here goes through the API, so Terraform never needs root SSH.
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  # PVE's self-signed certificate.
  insecure = true
}
