terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.58.0"
    }
  }
}

provider "proxmox" {
  # These should be set in the root provider; keeping here for module-level plan if used standalone
  # endpoint  = try(var.inputs.proxmox.endpoint, null)
  # api_token = try(var.inputs.proxmox.api_token, null)
}

locals {
  inputs   = var.inputs
  upload   = try(local.inputs.proxmox.upload, {})
  talos    = try(local.inputs.talos, {})
  enabled  = try(local.upload.enabled, true)
}

# Upload Talos ISO/image to Proxmox datastore
resource "proxmox_virtual_environment_file" "talos_image" {
  count    = local.enabled ? 1 : 0
  content_type = try(local.upload.content_type, "iso")
  datastore    = try(local.inputs.proxmox.datastore, null)
  node         = try(local.inputs.proxmox.node, null)
  source_file  = try(local.upload.source_file, null)
  # Optional checksum support
  checksum     = try(local.upload.checksum, null)
}

# Optionally, create a base VM template from the uploaded image (disabled by default)
resource "proxmox_virtual_environment_vm" "talos_template" {
  count    = try(local.inputs.proxmox.create_vm_template, false) ? 1 : 0
  node     = try(local.inputs.proxmox.node, null)
  name     = try(local.inputs.proxmox.vm_template_name, "talos-template")
  on_boot  = false
  template = true

  agent {
    enabled = true
  }

  boot_order = ["ide0"]

  cpu {
    cores = try(local.inputs.proxmox.template_cpu_cores, 2)
    sockets = try(local.inputs.proxmox.template_cpu_sockets, 1)
  }

  memory {
    dedicated = try(local.inputs.proxmox.template_memory_mib, 2048)
  }

  disk {
    interface = "ide0"
    datastore = try(local.inputs.proxmox.datastore, null)
    file_id   = try(proxmox_virtual_environment_file.talos_image[0].id, null)
    size      = try(local.inputs.proxmox.template_disk_gib, 20)
  }

  network_device {
    bridge = try(local.inputs.proxmox.bridge, "vmbr0")
  }
}

locals {
  # Example: read a templated VM cloud-init or metadata YAML if needed
  # vm_metadata = yamldecode(templatefile("${path.module}/templates/vm-metadata.yaml.tftpl", {
  #   cluster_name = var.cluster_name
  # }))
}
