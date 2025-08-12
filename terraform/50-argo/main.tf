provider "helm" {
    kubernetes {
        config_path = var.kubeconfig
    }
}

provider "kubernetes" {
    config_path = var.kubeconfig
}

variable "kubeconfig" {
    description = "Path to kubeconfig for the management cluster"
    type        = string
    default     = "~/.kube/config"
}

variable "namespace" {
    description = "Namespace to install Argo CD into"
    type        = string
    default     = "argocd"
}

resource "kubernetes_namespace" "argocd" {
    metadata {
        name = var.namespace
    }
}

resource "helm_release" "argocd" {
    name       = "argocd"
    repository = "https://argoproj.github.io/argo-helm"
    chart      = "argo-cd"
    version    = "5.53.15"
    namespace  = kubernetes_namespace.argocd.metadata[0].name

    values = [file("${path.module}/values.yaml")]
}

resource "kubernetes_manifest" "app_of_apps" {
    manifest = yamldecode(file("${path.module}/../..//gitops/argocd/bootstrap/app-of-apps.yaml"))
}
