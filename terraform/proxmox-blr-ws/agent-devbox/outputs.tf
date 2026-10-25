locals {
  # Once Docker and Tailscale are installed the agent also reports docker0 and
  # tailscale0, so pick the physical NIC by name.
  nic_ipv4 = flatten([
    for i, name in proxmox_virtual_environment_vm.agent_devbox.network_interface_names :
    proxmox_virtual_environment_vm.agent_devbox.ipv4_addresses[i]
    if can(regex("^(eth|en)", name))
  ])
}

output "ipv4_address" {
  description = "LAN IPv4 from the guest agent (used only for the first, bootstrap Ansible run)."
  value       = try(local.nic_ipv4[0], null)
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.agent_devbox.vm_id
}
