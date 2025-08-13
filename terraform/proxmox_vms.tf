locals {
  common = {
    node_name = var.pve_node
    bios      = "ovmf"
    machine   = "q35"
    on_boot   = true
    bridge    = var.bridge
    iso_path  = "${var.iso_storage}:iso/talos-installer-${var.talos_version}-${var.schematic_id}.iso"
  }
}

# Control planes
resource "proxmox_virtual_environment_vm" "cp" {
  count       = var.controlplane_count
  name        = format("%s-cp-%02d", var.cluster_name, count.index + 1)
  node_name   = local.common.node_name
  description = "Talos control-plane"
  tags        = [var.org_prefix, "talos", "cp"]

  bios    = local.common.bios
  machine = local.common.machine
  on_boot = local.common.on_boot

  agent { enabled = true }

  cpu { cores = var.controlplane_vcpus }
  memory { dedicated = var.controlplane_mem_mb }

  operating_system { type = "l26" }

  efi_disk { datastore_id = var.vm_disk_storage }

  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi0"
    size         = var.controlplane_disk_gb
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  cdrom {
    enabled = true
    file_id = local.common.iso_path
  }

  network_device {
    bridge = local.common.bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        dhcp = var.use_dhcp
      }
    }
  }
}

# Workers
resource "proxmox_virtual_environment_vm" "worker" {
  count       = var.worker_count
  name        = format("%s-wrk-%02d", var.cluster_name, count.index + 1)
  node_name   = local.common.node_name
  description = "Talos worker"
  tags        = [var.org_prefix, "talos", "worker"]

  bios    = local.common.bios
  machine = local.common.machine
  on_boot = local.common.on_boot

  agent { enabled = true }

  cpu { cores = var.worker_vcpus }
  memory { dedicated = var.worker_mem_mb }

  operating_system { type = "l26" }

  efi_disk { datastore_id = var.vm_disk_storage }

  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi0"
    size         = var.worker_os_disk_gb
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  # Longhorn data disk
  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi1"
    size         = var.worker_data_disk_gb
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  cdrom {
    enabled = true
    file_id = local.common.iso_path
  }

  network_device {
    bridge = local.common.bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        dhcp = var.use_dhcp
      }
    }
  }
}

# VM IPs from agent for Talos
output "cp_ips" { value = [for vm in proxmox_virtual_environment_vm.cp : try(vm.ipv4_addresses[0], null)] }
output "worker_ips" { value = [for vm in proxmox_virtual_environment_vm.worker : try(vm.ipv4_addresses[0], null)] }
