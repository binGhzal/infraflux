# Aggregate dependency to wait for all controlplane applies
resource "null_resource" "cp_applied" {
  triggers = {
    # change if any controlplane IP changes
    cp = join(",", var.controlplane_ips)
  }

  depends_on = [
    talos_machine_configuration_apply.cp
  ]
}
terraform {
  required_providers {
    talos = {
      source = "siderolabs/talos"
    }
  }
}

# Generate cluster secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# Generate control-plane machine config with patches for CNI none, kube-proxy disabled, VIP, KubePrism
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    yamlencode({
      cluster = {
        network = {
          cni = { name = "none" }
        }
        proxy = { disabled = true }
      }
      machine = {
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
        network = {
          interfaces = [
            {
              # Let Talos pick the only NIC if single NIC; VIP bound on controlplanes
              deviceSelector = { physical = true }
              dhcp           = true
              vip            = { ip = var.cluster_vip }
            }
          ]
        }
        install = {
          disk = var.install_disk
        }
      }
    })
  ]
}

# Generate worker machine config (no VIP on workers)
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  config_patches = [
    yamlencode({
      cluster = {
        network = { cni = { name = "none" } }
        proxy   = { disabled = true }
      }
      machine = {
        features = {
          kubePrism = { enabled = true, port = 7445 }
        }
        install = { disk = var.install_disk }
      }
    })
  ]
}

# Apply machine configs to controlplanes
resource "talos_machine_configuration_apply" "cp" {
  for_each                    = { for ip in var.controlplane_ips : ip => ip }
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value
}

# Bootstrap etcd/k8s on the first controlplane
resource "talos_machine_bootstrap" "this" {
  depends_on           = [null_resource.cp_applied]
  node                 = var.controlplane_ips[0]
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Apply machine configs to workers (after bootstrap)
resource "talos_machine_configuration_apply" "worker" {
  for_each                    = { for ip in var.worker_ips : ip => ip }
  depends_on                  = [talos_machine_bootstrap.this]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value
}

# Export kubeconfig after bootstrap (use resource; data source deprecated)
resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]
}
