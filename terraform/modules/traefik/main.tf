terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

variable "namespace" {
  type        = string
  description = "Namespace to install Traefik"
  default     = "traefik"
}

variable "chart_version" {
  type        = string
  description = "Traefik chart version"
  default     = "26.0.0"
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.chart_version
  namespace  = var.namespace

  values = [yamlencode({
    # Enable Kubernetes Gateway API provider
    providers = {
      kubernetesGateway = {
        enabled             = true
        experimentalChannel = true
      }
    }
    experimental = { kubernetesGateway = { enabled = true } }
  })]
}
