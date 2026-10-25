resource "proxmox_virtual_environment_vm" "agent_devbox" {
  name        = "agent-devbox"
  description = "Hermes Agent dev box. Managed by terraform/proxmox-blr-ws/agent-devbox; configured by agent-devbox/setup-agent-devbox.yaml."
  tags        = ["agent"]

  node_name = var.node_name
  vm_id     = var.vm_id
  pool_id   = var.pool_id

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = true
    wait_for_ip {
      ipv4 = true
    }
  }

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 8192
  }

  # Only disk: no passthrough, no host mounts, no virtiofs.
  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi0"
    size         = 64
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge   = var.bridge
    firewall = var.vm_firewall_enabled
  }

  initialization {
    datastore_id = var.vm_datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    # User, SSH key and qemu-guest-agent come from this snippet; Ansible does the rest.
    user_data_file_id = var.user_data_file_id
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  on_boot = true
}
