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

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.ns
  }
}

# Argo CD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = var.helm_repo
  chart      = var.helm_chart
  version    = var.chart_version

  values = [
    yamlencode({
      global = {
        image = {
          tag = var.argocd_version
        }
      }
      applicationset = {
        enabled = true
      }
      server = {
        # Service as ClusterIP; we'll expose via Gateway API
        service = {
          type             = "ClusterIP"
          servicePortHttp  = 80
          servicePortHttps = 443
        }
        # SSO placeholders to be filled at Step 13 via ESO
        extraArgs = [
          "--insecure"
        ]
      }
      configs = {
        params = {
          "server.insecure" = true
        }
        cm = (
          var.enable_oidc ? {
            "oidc.config" = join("\n", concat([
              "name: Authentik",
              "issuer: ${var.oidc.issuer}",
              "clientID: ${var.oidc.client_id}",
              "clientSecret: $argo:oidc.clientSecret",
              "requestedScopes:",
            ], [for s in var.oidc.requested_scopes : "  - ${s}"]))
          } : null
        )
      }
    })
  ]

  timeout = 600
  wait    = true

  recreate_pods = false
}

# Optional: minimal Gateway and HTTPRoute to expose Argo CD
resource "kubernetes_manifest" "gateway" {
  count = var.enable_gateway ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.gateway_name
      namespace = local.ns
    }
    spec = {
      gatewayClassName = var.gateway_class
      listeners = [
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                kind = "Secret"
                name = var.tls_secret_name
              }
            ]
          }
          hostname = var.hostname
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "httproute" {
  count = var.enable_gateway ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd"
      namespace = local.ns
    }
    spec = {
      parentRefs = [
        {
          name = var.gateway_name
        }
      ]
      hostnames = [var.hostname]
      rules = [
        {
          backendRefs = [
            {
              name = "argocd-server"
              port = 80
            }
          ]
        }
      ]
    }
  }
}
