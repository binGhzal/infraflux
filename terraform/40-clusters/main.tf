variable "kubeconfig" {
    description = "Path to kubeconfig for the management cluster"
    type        = string
    default     = "~/.kube/config"
}

provider "kubernetes" {
    config_path = var.kubeconfig
}

# Placeholders for ClusterClass, TalosControlPlane templates, etc.
# Commit your real templates under clusters/<env>/ and/or apply with Argo.

resource "kubernetes_manifest" "placeholder" {
    manifest = {
        apiVersion = "v1"
        kind       = "ConfigMap"
        metadata = {
            name      = "clusters-todo"
            namespace = "default"
        }
        data = {
            message = "Define ClusterClass and templates for workload clusters here."
        }
    }
}
