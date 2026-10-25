variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (proxmox-blr-ws over Tailscale)."
  type        = string
  default     = "https://100.113.136.34:8006/"
}

variable "node_name" {
  type    = string
  default = "proxmox-blr-ws"
}

variable "pool_id" {
  description = "Resource pool the Terraform token is scoped to."
  type        = string
  default     = "agent"
}

variable "template_vm_id" {
  type    = number
  default = 9000
}

# Placed on the host by proxmox-blr-ws/setup-proxmox-blr-ws-vm-base.yaml
# (pin in host_vars/proxmox-blr-ws.yml). Keep the two in sync.
variable "image_file_id" {
  type    = string
  default = "local:import/debian-13-genericcloud-amd64-20261021-2638.qcow2"
}

variable "vm_datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}
