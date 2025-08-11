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
  # endpoint   = var.proxmox_endpoint
  # api_token  = var.proxmox_api_token
}

# Upload Talos ISO/image and create base VM template(s)
# resource "proxmox_virtual_environment_file" "talos_iso" { ... }
# resource "proxmox_virtual_environment_vm"   "mgmt_template" { ... }

locals {
  # Example: read a templated VM cloud-init or metadata YAML if needed
  # vm_metadata = yamldecode(templatefile("${path.module}/templates/vm-metadata.yaml.tftpl", {
  #   cluster_name = var.cluster_name
  # }))
}
