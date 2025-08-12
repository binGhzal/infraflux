# Proxmox VM Module
# Creates and configures VMs on Proxmox infrastructure

terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

resource "proxmox_vm_qemu" "vm" {
  count = var.vm_count

  name        = var.vm_count > 1 ? "${var.vm_name}-${count.index + 1}" : var.vm_name
  target_node = var.target_node
  vmid        = var.vm_ids != null ? var.vm_ids[count.index] : null

  # Template cloning
  clone      = var.template_name
  clone_id   = var.template_id
  full_clone = true

  # VM Configuration
  agent    = var.qemu_agent
  onboot   = var.start_on_boot
  cores    = var.cpu_cores
  memory   = var.memory_mb
  scsihw   = var.scsi_controller

  # Boot order
  boot = var.iso_path != null ? "order=ide2;scsi0;net0" : "order=scsi0;net0"

  # Primary disk
  disk {
    slot    = "scsi0"
    size    = format("%dG", var.disk_size_gb)
    type    = "disk"
    storage = var.storage
    cache   = var.disk_cache
    ssd     = var.disk_ssd
  }

  # Additional disks
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      slot    = disk.value.slot
      size    = format("%dG", disk.value.size_gb)
      type    = "disk"
      storage = disk.value.storage
      cache   = disk.value.cache
      ssd     = disk.value.ssd
    }
  }

  # Optional ISO mount
  dynamic "disk" {
    for_each = var.iso_path != null ? [1] : []
    content {
      slot = "ide2"
      type = "cdrom"
      iso  = var.iso_path
    }
  }

  # Network interfaces
  dynamic "network" {
    for_each = var.network_interfaces
    content {
      id     = network.value.id
      model  = network.value.model
      bridge = network.value.bridge
      tag    = network.value.vlan_tag
    }
  }

  # Cloud-init configuration
  os_type    = var.os_type
  ciuser     = var.cloud_init_user
  cipassword = var.cloud_init_password
  sshkeys    = var.ssh_public_keys
  ipconfig0  = var.ip_config

  # Tags for organization
  tags = var.tags

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      ciuser,
      cipassword,
      sshkeys,
    ]
  }
}
