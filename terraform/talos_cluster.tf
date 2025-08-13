resource "talos_machine_secrets" "cluster" {}

locals {
  endpoint = "https://${var.controlplane_vip}:6443"
}

# Generate base configs
data "talos_machine_configuration" "cp_cfg" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.endpoint
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  machine_type     = "controlplane"
  talos_version    = var.talos_version

  # Talos patches for CP
  config_patches = [
    yamlencode({
      cluster = {
        network = {
          cni = { name = "none" }   # we'll install Cilium ourselves
          podSubnets = [var.pod_cidr]
          serviceSubnets = [var.svc_cidr]
        }
        proxy = { disabled = true } # kube-proxy off for Cilium
        apiServer = {
          # advertise via VIP, KubePrism is separate
        }
        discovery = { enabled = true }
        # Optionally: inlineManifests / extraManifests (we install via Helm)
      }
      machine = {
        features = {
          kubePrism = { enabled = true, port = 7445 }
        }
      }
    })
  ]
}

data "talos_machine_configuration" "wrk_cfg" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.endpoint
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  machine_type     = "worker"
  talos_version    = var.talos_version

  config_patches = [
    yamlencode({
      cluster = {
        network = {
          cni = { name = "none" }
          podSubnets = [var.pod_cidr]
          serviceSubnets = [var.svc_cidr]
        }
        proxy = { disabled = true }
      }
      machine = {
        features = {
          kubePrism = { enabled = true, port = 7445 }
        }
      }
    })
  ]
}

# Apply machine configs by discovered IPs from Proxmox
resource "talos_machine_configuration_apply" "cp_apply" {
  count                       = var.controlplane_count
  node                        = proxmox_virtual_environment_vm.cp[count.index].ipv4_addresses[0]
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.cp_cfg.machine_configuration
  # leave mode default (auto)
}

resource "talos_machine_configuration_apply" "wrk_apply" {
  count                       = var.worker_count
  node                        = proxmox_virtual_environment_vm.worker[count.index].ipv4_addresses[0]
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.wrk_cfg.machine_configuration
}

# Bootstrap etcd on first control plane
resource "talos_machine_bootstrap" "bootstrap" {
  node                 = talos_machine_configuration_apply.cp_apply[0].node
  client_configuration = talos_machine_secrets.cluster.client_configuration
}

# kubeconfig & talosconfig
resource "talos_cluster_kubeconfig" "admin" {
  node                 = talos_machine_configuration_apply.cp_apply[0].node
  client_configuration = talos_machine_secrets.cluster.client_configuration
  depends_on = [talos_machine_bootstrap.bootstrap]
}

# Wire providers only after cluster is ready
provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.admin.kubernetes_client_configuration.host
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.admin.kubernetes_client_configuration.ca_certificate)
  client_certificate     = base64decode(talos_cluster_kubeconfig.admin.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.admin.kubernetes_client_configuration.client_key)
}

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.admin.kubernetes_client_configuration.host
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.admin.kubernetes_client_configuration.ca_certificate)
    client_certificate     = base64decode(talos_cluster_kubeconfig.admin.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.admin.kubernetes_client_configuration.client_key)
  }
}
