variable "kubeconfig" {
    description = "Path to kubeconfig for the management cluster"
    type        = string
    default     = "~/.kube/config"
}

variable "namespace" {
    description = "Namespace where CAPMox runs"
    type        = string
    default     = "capmox-system"
}

variable "proxmox_url" {
    description = "Proxmox API URL"
    type        = string
}

variable "pm_user" {
    description = "Proxmox username (e.g., root@pam)"
    type        = string
}

variable "pm_password" {
    description = "Proxmox password"
    type        = string
    sensitive   = true
}

provider "kubernetes" {
    config_path = var.kubeconfig
}

resource "kubernetes_namespace" "capmox" {
    metadata {
        name = var.namespace
    }
}

resource "kubernetes_secret" "capmox_credentials" {
    metadata {
    name      = "capmox-credentials"
        namespace = kubernetes_namespace.capmox.metadata[0].name
    }
    type = "Opaque"
    data = {
    PM_API_URL = base64encode(var.proxmox_url)
    PM_USER    = base64encode(var.pm_user)
    PM_PASSWORD= base64encode(var.pm_password)
    }
}

# Optional: ProxmoxCluster default for management cluster
resource "kubernetes_manifest" "proxmoxcluster_default" {
    manifest = {
        apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
        kind       = "ProxmoxCluster"
        metadata = {
            name      = "default"
            namespace = kubernetes_namespace.capmox.metadata[0].name
        }
        spec = {
            # Fill with your global defaults as needed
        }
    }
}
