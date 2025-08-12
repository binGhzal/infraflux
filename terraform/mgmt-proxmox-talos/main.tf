terraform {
  # OpenTofu compatible version constraint
  required_version = ">= 1.6"
  required_providers {
    proxmox    = { source = "Telmate/proxmox", version = "~> 3.0" }
    talos      = { source = "siderolabs/talos", version = "~> 0.8" }
    helm       = { source = "hashicorp/helm", version = "~> 2.12" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.33" }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

# NOTE: Add your proxmox_vm_qemu resources for control plane and workers here
# and output their IP addresses to feed Talos below.

provider "talos" {}

resource "talos_machine_secrets" "this" {}
resource "talos_client_configuration" "this" {
  cluster_name    = var.cluster_name
  endpoints       = var.controlplane_ips
  nodes           = concat(var.controlplane_ips, var.worker_ips)
  machine_secrets = talos_machine_secrets.this.machine_secrets
}

resource "talos_cluster_kubeconfig" "kube" {
  client_configuration = talos_client_configuration.this
  node                 = var.controlplane_ips[0]
  wait                 = true
}

provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.kube.kubeconfig[0].host
  cluster_ca_certificate = talos_cluster_kubeconfig.kube.kubeconfig[0].cluster_ca_certificate
  token                  = talos_cluster_kubeconfig.kube.kubeconfig[0].token
}

provider "helm" {
  kubernetes {
    host                   = talos_cluster_kubeconfig.kube.kubeconfig[0].host
    cluster_ca_certificate = talos_cluster_kubeconfig.kube.kubeconfig[0].cluster_ca_certificate
    token                  = talos_cluster_kubeconfig.kube.kubeconfig[0].token
  }
}

resource "helm_release" "capi_operator" {
  name             = "capi-operator"
  repository       = "https://kubernetes-sigs.github.io/cluster-api-operator"
  chart            = "cluster-api-operator"
  namespace        = "capi-operator-system"
  create_namespace = true
  wait             = true
  timeout          = 300
}
