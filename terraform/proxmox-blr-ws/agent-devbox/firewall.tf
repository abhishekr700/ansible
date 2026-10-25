# Inert until the datacenter firewall is enabled (see vm_firewall_enabled).
resource "proxmox_virtual_environment_firewall_options" "agent_devbox" {
  node_name = var.node_name
  vm_id     = proxmox_virtual_environment_vm.agent_devbox.vm_id

  enabled       = var.vm_firewall_enabled
  dhcp          = true
  macfilter     = true
  ipfilter      = false
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

# Rules are evaluated top to bottom; first match wins.
resource "proxmox_virtual_environment_firewall_rules" "agent_devbox" {
  node_name = var.node_name
  vm_id     = proxmox_virtual_environment_vm.agent_devbox.vm_id

  # --- in: nothing from the LAN except bootstrap SSH from the Proxmox host ---
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "bootstrap ssh via ProxyJump through proxmox-blr-ws"
    source  = var.proxmox_host_ip
    proto   = "tcp"
    dport   = "22"
  }

  # --- out: gateway DNS, explicit per-host allows, then drop private ranges ---
  rule {
    type    = "out"
    action  = "ACCEPT"
    comment = "dns (udp)"
    dest    = var.lan_dns
    proto   = "udp"
    dport   = "53"
  }

  rule {
    type    = "out"
    action  = "ACCEPT"
    comment = "dns (tcp)"
    dest    = var.lan_dns
    proto   = "tcp"
    dport   = "53"
  }

  rule {
    type    = "out"
    action  = "ACCEPT"
    comment = "dns v6 (udp)"
    dest    = var.lan_dns_v6
    proto   = "udp"
    dport   = "53"
  }

  rule {
    type    = "out"
    action  = "ACCEPT"
    comment = "dns v6 (tcp)"
    dest    = var.lan_dns_v6
    proto   = "tcp"
    dport   = "53"
  }

  dynamic "rule" {
    for_each = var.extra_allow_out
    content {
      type    = "out"
      action  = "ACCEPT"
      comment = rule.value.comment
      dest    = rule.value.dest
      proto   = rule.value.proto
      dport   = rule.value.dport
    }
  }

  rule {
    type    = "out"
    action  = "DROP"
    comment = "no LAN / private ranges"
    dest    = join(",", var.private_ranges)
  }

  rule {
    type    = "out"
    action  = "DROP"
    comment = "no LAN / private ranges (v6)"
    dest    = join(",", var.private_ranges_v6)
  }

  # Everything else (internet, Tailscale WireGuard/DERP) falls through to output_policy ACCEPT.
}
