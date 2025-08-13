resource "talos_machine_secrets" "cluster" {}

locals {
  endpoint = "https://${var.controlplane_vip}:6443"
}

# Generate machine configuration data (data sources in v0.8.x)
data "talos_machine_configuration" "cp" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.endpoint
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  talos_version    = var.talos_version
  machine_type     = "controlplane"

  config_patches = [
    yamlencode({
      cluster = {
        network = {
          cni            = { name = "none" }
          podSubnets     = [var.pod_cidr]
          serviceSubnets = [var.svc_cidr]
        }
        proxy     = { disabled = true }
        discovery = { enabled = true }
      }
      machine = {
        features = {
          kubePrism = { enabled = true, port = 7445 }
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.endpoint
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  talos_version    = var.talos_version
  machine_type     = "worker"

  config_patches = data.talos_machine_configuration.cp.config_patches
}

# Apply machine configs to nodes discovered via Proxmox agent IPs
resource "talos_machine_configuration_apply" "cp_apply" {
  count                       = var.controlplane_count
  node                        = element(proxmox_virtual_environment_vm.cp.*.ipv4_addresses, count.index)[0]
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.cp.machine_configuration
}

resource "talos_machine_configuration_apply" "wrk_apply" {
  count                       = var.worker_count
  node                        = element(proxmox_virtual_environment_vm.worker.*.ipv4_addresses, count.index)[0]
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
}

resource "talos_machine_bootstrap" "bootstrap" {
  node                 = talos_machine_configuration_apply.cp_apply[0].node
  client_configuration = talos_machine_secrets.cluster.client_configuration
}

data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoint             = local.endpoint
  depends_on           = [talos_machine_bootstrap.bootstrap]
}

locals {
  kubeconfig = yamldecode(data.talos_cluster_kubeconfig.this.kubeconfig)
}

provider "kubernetes" {
  host                   = local.endpoint
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
  token                  = local.kubeconfig.users[0].user.token
}

provider "helm" {
  kubernetes = {
    host                   = local.endpoint
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
    token                  = local.kubeconfig.users[0].user.token
  }
}

provider "kubectl" {
  host                   = local.endpoint
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
  token                  = local.kubeconfig.users[0].user.token
  load_config_file       = false
}
