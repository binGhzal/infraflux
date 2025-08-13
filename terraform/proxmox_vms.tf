locals {
  vm_common = {
    node_name        = var.pve_node
    bios             = "ovmf"
    machine          = "q35"
    scsihw           = "virtio-scsi-pci"
    on_boot          = true
    tablet           = false
    qemu_guest_agent = true
    boot_order       = "scsi0;ide2;net0"
    bridge           = var.bridge
    iso_path         = "${var.iso_storage}:iso/talos-installer-${var.talos_version}.iso"
  }
}

# Control planes
resource "proxmox_virtual_environment_vm" "cp" {
  count       = var.controlplane_count
  name        = format("%s-cp-%02d", var.cluster_name, count.index + 1)
  description = "Talos control-plane"
  node_name   = local.vm_common.node_name
  machine     = local.vm_common.machine
  bios        = local.vm_common.bios
  on_boot     = local.vm_common.on_boot
  tags        = ["${var.org_prefix}", "talos", "cp"]

  agent {
    enabled = true
  }

  cpu {
    cores = var.controlplane_vcpus
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.controlplane_mem_mb
  }

  operating_system {
    type = "l26"
  }

  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi0"
    size         = var.controlplane_disk_gb
    file_format  = "raw"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  efi_disk {
    datastore_id = var.vm_disk_storage
  }

  cdrom {
    file_id = local.vm_common.iso_path
  }

  network_device {
    bridge = local.vm_common.bridge
    model  = "virtio"
  }

  initialization {
    # Talos pulls config via API; keep cloud-init minimal
    user_account {
      username = "talos" # unused on Talos, but keeps CI happy
    }
    ip_config {
      ipv4 {
        # DHCP enabled by default when no address/gateway specified
      }
    }
  }
}

# Workers
resource "proxmox_virtual_environment_vm" "worker" {
  count       = var.worker_count
  name        = format("%s-wrk-%02d", var.cluster_name, count.index + 1)
  description = "Talos worker"
  node_name   = local.vm_common.node_name
  bios        = local.vm_common.bios
  on_boot     = local.vm_common.on_boot
  tags        = ["${var.org_prefix}", "talos", "worker"]

  agent { enabled = true }

  cpu {
    cores = var.worker_vcpus
    type  = "x86-64-v2-AES"
  }

  memory { dedicated = var.worker_mem_mb }

  operating_system { type = "l26" }

  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi0"
    size         = var.worker_disk_gb
    file_format  = "raw"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  efi_disk { datastore_id = var.vm_disk_storage }

  cdrom {
    file_id = local.vm_common.iso_path
  }

  network_device {
    bridge = local.vm_common.bridge
    model  = "virtio"
  }

  initialization {
    user_account {
      username = "talos"
    }
    ip_config {
      ipv4 {
        # DHCP enabled by default when no address/gateway specified
      }
    }
  }
}

# VM IPs from agent for Talos
output "cp_ips" {
  value = [for vm in proxmox_virtual_environment_vm.cp : vm.ipv4_addresses[0]]
}
output "worker_ips" {
  value = [for vm in proxmox_virtual_environment_vm.worker : vm.ipv4_addresses[0]]
}
