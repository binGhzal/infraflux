provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

locals {
  cp_names     = [for i in range(var.cp_count) : format("%s-cp-%02d", var.cluster_name, i + 1)]
  worker_names = [for i in range(var.worker_count) : format("%s-w-%02d", var.cluster_name, i + 1)]
}

# Module-level validations
resource "null_resource" "validations" {
  lifecycle {
    precondition {
      condition     = (var.talos_template != null) != (var.talos_template_id != null)
      error_message = "Set exactly one of talos_template (name) or talos_template_id (VMID)."
    }
    precondition {
      condition     = var.cp_vmids == null || length(var.cp_vmids) == var.cp_count
      error_message = "cp_vmids length must equal cp_count when provided."
    }
    precondition {
      condition     = var.worker_vmids == null || length(var.worker_vmids) == var.worker_count
      error_message = "worker_vmids length must equal worker_count when provided."
    }
  }
}

resource "proxmox_vm_qemu" "cp" {
  count       = var.cp_count
  name        = local.cp_names[count.index]
  target_node = var.target_node
  vmid        = var.cp_vmids != null ? var.cp_vmids[count.index] : var.cp_vmid_base + count.index

  # Set ONE of the following: clone (NAME) or clone_id (VMID)
  clone      = var.talos_template
  clone_id   = var.talos_template_id
  full_clone = true

  agent    = 1
  onboot   = true
  cores    = var.cp_cpu
  memory   = var.cp_memory_mb
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
}

resource "proxmox_vm_qemu" "worker" {
  count       = var.worker_count
  name        = local.worker_names[count.index]
  target_node = var.target_node
  vmid        = var.worker_vmids != null ? var.worker_vmids[count.index] : var.worker_vmid_base + count.index

  # Set ONE of the following: clone (NAME) or clone_id (VMID)
  clone      = var.talos_template
  clone_id   = var.talos_template_id
  full_clone = true

  agent  = 1
  onboot = true
  cores  = var.worker_cpu
  memory = var.worker_memory_mb
  scsihw = "virtio-scsi-pci"
  boot   = var.iso_path != null ? "order=ide2;scsi0;net0" : "order=scsi0;net0"

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
}

output "cp_vm_names" {
  value = local.cp_names
}

output "worker_vm_names" {
  value = local.worker_names
}
