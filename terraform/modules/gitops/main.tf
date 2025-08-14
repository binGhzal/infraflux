terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
  }
}

locals {
  ns = var.namespace
}

# Namespace should already exist via Argo CD module

resource "kubernetes_manifest" "root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.root_app_name
      namespace = local.ns
      labels = {
        "app.kubernetes.io/part-of" = "platform"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.revision
        path           = var.path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = local.ns
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}
