resource "talos_machine_secrets" "cluster" {}

locals {
  endpoint = "https://${var.controlplane_vip}:6443"
}

# Generate base configs
resource "talos_machine_configuration_controlplane" "cp_cfg" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.endpoint
  machine_secrets  = talos_machine_secrets.cluster
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

resource "talos_machine_configuration_worker" "wrk_cfg" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.endpoint
  machine_secrets  = talos_machine_secrets.cluster
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
  count                 = var.controlplane_count
  node                  = element(proxmox_virtual_environment_vm.cp.*.ipv4_addresses, count.index)[0]
  client_configuration  = talos_machine_secrets.cluster.client_configuration
  machine_configuration = talos_machine_configuration_controlplane.cp_cfg.machine_configuration
  # leave mode default (auto)
}

resource "talos_machine_configuration_apply" "wrk_apply" {
  count                 = var.worker_count
  node                  = element(proxmox_virtual_environment_vm.worker.*.ipv4_addresses, count.index)[0]
  client_configuration  = talos_machine_secrets.cluster.client_configuration
  machine_configuration = talos_machine_configuration_worker.wrk_cfg.machine_configuration
}

# Bootstrap etcd on first control plane
resource "talos_machine_bootstrap" "bootstrap" {
  node                 = talos_machine_configuration_apply.cp_apply[0].node
  client_configuration = talos_machine_secrets.cluster.client_configuration
}

# kubeconfig & talosconfig
resource "talos_kubeconfig" "admin" {
  node                 = talos_machine_configuration_apply.cp_apply[0].node
  client_configuration = talos_machine_secrets.cluster.client_configuration
  depends_on = [talos_machine_bootstrap.bootstrap]
}

# Wire providers only after cluster is ready
provider "kubernetes" {
  host                   = local.endpoint
  cluster_ca_certificate = base64decode(talos_kubeconfig.admin.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
  token                  = talos_kubeconfig.admin.kubeconfig["users"][0]["user"]["token"]
}

provider "helm" {
  kubernetes {
    host                   = local.endpoint
    cluster_ca_certificate = base64decode(talos_kubeconfig.admin.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
    token                  = talos_kubeconfig.admin.kubeconfig["users"][0]["user"]["token"]
  }
}
