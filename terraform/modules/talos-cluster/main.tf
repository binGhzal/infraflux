# Talos Kubernetes Cluster Module
# Configures and bootstraps Talos Kubernetes clusters

terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Generate Talos machine secrets
resource "talos_machine_secrets" "cluster" {}

# Control plane configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_endpoint}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = concat(
    var.global_config_patches,
    var.controlplane_config_patches,
    [
      yamlencode({
        machine = {
          install = {
            disk = var.install_disk
          }
          network = var.network_config
        }
        cluster = {
          network = {
            cni = {
              name = "none"  # We'll install Cilium via GitOps
            }
          }
        }
      })
    ]
  )
}

# Worker configuration (if workers are needed)
data "talos_machine_configuration" "worker" {
  count = var.worker_count > 0 ? 1 : 0

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_endpoint}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = concat(
    var.global_config_patches,
    var.worker_config_patches,
    [
      yamlencode({
        machine = {
          install = {
            disk = var.install_disk
          }
          network = var.network_config
        }
      })
    ]
  )
}

# Client configuration
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = var.node_endpoints
}

# Apply configuration to control plane nodes
resource "talos_machine_configuration_apply" "controlplane" {
  count = length(var.controlplane_endpoints)

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_endpoints[count.index]

  depends_on = [var.vm_dependency]
}

# Apply configuration to worker nodes
resource "talos_machine_configuration_apply" "worker" {
  count = length(var.worker_endpoints)

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[0].machine_configuration
  node                        = var.worker_endpoints[count.index]

  depends_on = [var.vm_dependency]
}

# Bootstrap the cluster (only on first control plane node)
resource "talos_machine_bootstrap" "cluster" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.controlplane_endpoints[0]
}

# Wait for cluster to be ready and get kubeconfig
data "talos_cluster_kubeconfig" "cluster" {
  depends_on = [talos_machine_bootstrap.cluster]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.controlplane_endpoints[0]
}

# Save kubeconfig to file
resource "local_file" "kubeconfig" {
  count = var.save_kubeconfig ? 1 : 0

  content  = data.talos_cluster_kubeconfig.cluster.kubeconfig_raw
  filename = var.kubeconfig_path

  provisioner "local-exec" {
    command = "chmod 600 ${var.kubeconfig_path}"
  }
}

# Save Talos client config
resource "local_file" "talosconfig" {
  count = var.save_talosconfig ? 1 : 0

  content  = data.talos_client_configuration.cluster.talos_config
  filename = var.talosconfig_path

  provisioner "local-exec" {
    command = "chmod 600 ${var.talosconfig_path}"
  }
}
