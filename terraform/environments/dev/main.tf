# Development Environment Configuration
# Single-node Talos cluster for development and testing

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.4"
    }
  }
}

# Load environment configuration
locals {
  config = yamldecode(file("${path.module}/../../config/environments/dev.yaml"))

  # Compute node endpoints
  node_endpoints = [for i in range(local.config.cluster.controlplane_count) :
    "${local.config.network.base_ip}${local.config.network.ip_start + i}"
  ]
}

# Proxmox provider configuration
provider "proxmox" {
  pm_api_url      = local.config.proxmox.api_url
  pm_user         = local.config.proxmox.user
  pm_password     = var.proxmox_password
  pm_tls_insecure = local.config.proxmox.tls_insecure
}

# Create control plane VMs
module "controlplane_vms" {
  source = "../../modules/proxmox-vm"

  vm_name     = "${local.config.cluster.name}-cp"
  vm_count    = local.config.cluster.controlplane_count
  target_node = local.config.proxmox.target_node

  template_id = local.config.talos.template_id

  cpu_cores    = local.config.nodes.controlplane.cpu_cores
  memory_mb    = local.config.nodes.controlplane.memory_mb
  disk_size_gb = local.config.nodes.controlplane.disk_size_gb
  storage      = local.config.proxmox.storage

  network_interfaces = [
    {
      id       = 0
      model    = "virtio"
      bridge   = local.config.network.bridge
      vlan_tag = local.config.network.vlan_tag
    }
  ]

  ssh_public_keys = var.ssh_public_keys
  tags           = "environment:dev,role:controlplane"
}

# Create Talos cluster
module "talos_cluster" {
  source = "../../modules/talos-cluster"

  cluster_name     = local.config.cluster.name
  cluster_endpoint = local.node_endpoints[0]  # Use first node as endpoint for single-node

  node_endpoints        = local.node_endpoints
  controlplane_endpoints = local.node_endpoints
  worker_endpoints      = []

  global_config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        kubelet = {
          nodeIP = {
            validSubnets = [local.config.network.subnet]
          }
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = true  # Single node setup
        network = {
          cni = {
            name = "none"  # Install Cilium via GitOps
          }
        }
      }
    })
  ]

  kubeconfig_path  = "${path.module}/kubeconfig-${local.config.cluster.name}"
  talosconfig_path = "${path.module}/talosconfig-${local.config.cluster.name}"

  vm_dependency = module.controlplane_vms.vm_objects
}
