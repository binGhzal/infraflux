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

resource "proxmox_vm_qemu" "cp" {
  count       = var.cp_count
  name        = local.cp_names[count.index]
  target_node = var.target_node
  vmid        = var.cp_vmid_base + count.index

  clone    = var.talos_template
  full_clone = true

  agent    = 1
  onboot   = true
  cores    = var.cp_cpu
  memory   = var.cp_memory_mb
  scsihw   = "virtio-scsi-pci"
  boot     = "order=scsi0;net0"

  disk {
    slot    = 0
    size    = format("%dG", var.disk_size_gb)
    type    = "scsi"
    storage = var.datastore
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
  vmid        = var.worker_vmid_base + count.index

  clone    = var.talos_template
  full_clone = true

  agent  = 1
  onboot = true
  cores  = var.worker_cpu
  memory = var.worker_memory_mb
  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0;net0"

  disk {
    slot    = 0
    size    = format("%dG", var.disk_size_gb)
    type    = "scsi"
    storage = var.datastore
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
