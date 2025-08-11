terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.4.0-alpha.0"
    }
  }
}

provider "talos" {}

# Use talos_machine_configuration and talos_machine_bootstrap resources
# to generate/apply configs and fetch kubeconfig.

locals {
  # Example: generate Talos machine config from a template and inputs
  # controlplane_cfg = templatefile("${path.module}/templates/controlplane.yaml.tftpl", {
  #   cluster_name = var.cluster_name
  #   endpoints    = var.control_plane_endpoints
  # })
}
