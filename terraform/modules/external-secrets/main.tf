terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
  }
}

locals {
  ns = var.namespace
}

resource "kubernetes_namespace" "eso" {
  metadata {
    name = local.ns
  }
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace.eso.metadata[0].name
  repository = var.helm_repo
  chart      = var.helm_chart
  version    = var.chart_version

  values = [
    yamlencode({
      installCRDs = var.create_crds
      metrics     = { serviceMonitor = { enabled = false } }
    })
  ]

  timeout       = 600
  wait          = true
  recreate_pods = false
}
# end module
