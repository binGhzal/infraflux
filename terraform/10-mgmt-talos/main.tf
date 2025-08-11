terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.4.0-alpha.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

provider "talos" {}
provider "local" {}

locals {
  inputs       = var.inputs
  mgmt         = try(local.inputs.mgmt, {})
  cluster_name = try(local.mgmt.cluster_name, "mgmt")
  talos        = try(local.inputs.talos, {})
  controlplane_endpoints = try(local.mgmt.control_plane_endpoints, [])
  worker_endpoints       = try(local.mgmt.worker_endpoints, [])

  controlplane_cfg = templatefile("${path.module}/templates/machineconfig-controlplane.yaml.tmpl", {
    cluster = { name = local.cluster_name }
    talos   = local.talos
  })
  worker_cfg = templatefile("${path.module}/templates/machineconfig-worker.yaml.tmpl", {
    cluster = { name = local.cluster_name }
    talos   = local.talos
  })
}

# Generate Talos machine secrets (shared among nodes)
resource "talos_machine_secrets" "this" {}

# Apply machine configuration to control plane nodes
resource "talos_machine_configuration_apply" "controlplane" {
  count                  = length(local.controlplane_endpoints)
  client_configuration   = talos_machine_secrets.this.client_configuration
  endpoint               = local.controlplane_endpoints[count.index]
  node                   = local.controlplane_endpoints[count.index]
  machine_configuration_input = local.controlplane_cfg
}

# Bootstrap the first control plane node
resource "talos_machine_bootstrap" "cp" {
  depends_on = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint = try(local.controlplane_endpoints[0], null)
  node     = try(local.controlplane_endpoints[0], null)
}

# Apply worker configuration
resource "talos_machine_configuration_apply" "worker" {
  count                  = length(local.worker_endpoints)
  depends_on             = [talos_machine_bootstrap.cp]
  client_configuration   = talos_machine_secrets.this.client_configuration
  endpoint               = local.worker_endpoints[count.index]
  node                   = local.worker_endpoints[count.index]
  machine_configuration_input = local.worker_cfg
}

# Retrieve kubeconfig for the management cluster (data source; resource is available but not required)
resource "talos_cluster_kubeconfig" "mgmt" {
  depends_on = [talos_machine_bootstrap.cp]
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint = try(local.controlplane_endpoints[0], null)
  node     = try(local.controlplane_endpoints[0], null)
}

# Persist kubeconfig to the path provided in inputs (optional but convenient)
resource "local_file" "mgmt_kubeconfig" {
  count    = try(local.inputs.kubernetes.kubeconfig, null) != null ? 1 : 0
  content  = talos_cluster_kubeconfig.mgmt.kubeconfig_raw
  filename = local.inputs.kubernetes.kubeconfig
}
