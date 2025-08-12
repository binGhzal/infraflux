provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

locals {
  # Single bootstrap node only
  bootstrap_vmid = var.bootstrap_vmid != null ? var.bootstrap_vmid : 7000
}

# Module-level validations
resource "null_resource" "validations" {
  lifecycle {
    precondition {
      condition     = (var.talos_template != null) != (var.talos_template_id != null)
      error_message = "Set exactly one of talos_template (name) or talos_template_id (VMID)."
    }
  }
}

resource "proxmox_vm_qemu" "bootstrap" {
  name        = var.bootstrap_node_name
  target_node = var.target_node
  vmid        = local.bootstrap_vmid

  # Set ONE of the following: clone (NAME) or clone_id (VMID)
  clone      = var.talos_template
  clone_id   = var.talos_template_id
  full_clone = true

  agent    = 1
  onboot   = true
  cores    = var.cpu_cores
  memory   = var.memory_mb
  scsihw   = "virtio-scsi-pci"
  boot     = var.iso_path != null ? "order=ide2;scsi0;net0" : "order=scsi0;net0"

  disk {
    slot    = "scsi0"
    size    = format("%dG", var.disk_size_gb)
    type    = "disk"
    storage = var.datastore
  }

  # Optional ISO mount on ide2 as cdrom
  dynamic "disk" {
    for_each = var.iso_path != null ? [1] : []
    content {
      slot = "ide2"
      type = "cdrom"
      iso  = var.iso_path
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }

  os_type = "l26"
  ciuser   = var.cloud_init_user
  cipassword = var.cloud_init_password
  sshkeys    = var.ssh_public_keys
}output "bootstrap_vm_name" {
  value = var.bootstrap_node_name
}

output "bootstrap_vm_id" {
  value = local.bootstrap_vmid
}
