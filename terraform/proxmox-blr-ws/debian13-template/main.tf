# Debian 13 cloud-init template. Kept in its own root so destroying a VM never
# touches the template, and vice versa.
resource "proxmox_virtual_environment_vm" "debian13" {
  name        = "debian13-cloud"
  description = "Debian 13 genericcloud template. Managed by terraform/proxmox-blr-ws/debian13-template."
  tags        = ["template", "terraform"]

  node_name = var.node_name
  vm_id     = var.template_vm_id
  pool_id   = var.pool_id

  template = true
  started  = false

  # Clones install and start qemu-guest-agent via cloud-init user-data.
  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.vm_datastore_id
    import_from  = var.image_file_id
    interface    = "scsi0"
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = var.bridge
  }

  operating_system {
    type = "l26"
  }

  # Debian cloud images log to the serial console.
  serial_device {}
}
