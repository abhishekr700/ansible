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

variable "vm_id" {
  type    = number
  default = 120
}

variable "template_vm_id" {
  description = "From terraform/proxmox-blr-ws/debian13-template."
  type        = number
  default     = 9000
}

variable "vm_datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

# Uploaded by proxmox-blr-ws/setup-proxmox-blr-ws-agent-devbox.yaml.
variable "user_data_file_id" {
  type    = string
  default = "local:snippets/agent-devbox-user-data.yaml"
}

# --- Proxmox VM firewall ---
# Rules only take effect once the *datacenter* firewall is enabled, which is
# deliberately left off for now (no physical access to the host). Flip this to
# true at the same time as enabling it.
variable "vm_firewall_enabled" {
  type    = bool
  default = false
}

variable "lan_gateway" {
  type    = string
  default = "192.168.5.1"
}

# Assumed to be the gateway; confirm from the VM's DHCP lease after first boot.
variable "lan_dns" {
  type    = string
  default = "192.168.5.1"
}

# The LAN also runs IPv6 (ULA via router advertisements); the router serves DNS there too.
variable "lan_dns_v6" {
  type    = string
  default = "fdac:9576:407b::1"
}

variable "private_ranges_v6" {
  description = "Outbound IPv6 to these is dropped (ULA + link-local). PVE rules can't mix v4 and v6."
  type        = list(string)
  default     = ["fc00::/7", "fe80::/10"]
}

variable "proxmox_host_ip" {
  description = "Only LAN source allowed in: bootstrap SSH via ProxyJump through the host."
  type        = string
  default     = "192.168.5.50"
}

variable "private_ranges" {
  description = "Outbound to these is dropped (after the explicit allows)."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]
}

# Open things up per host here, e.g.
#   { comment = "prometheus ssh", dest = "192.168.5.20", proto = "tcp", dport = "22" }
variable "extra_allow_out" {
  type = list(object({
    comment = string
    dest    = string
    proto   = string
    dport   = string
  }))
  default = []
}
