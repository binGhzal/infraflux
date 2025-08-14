terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

variable "namespace" {
  type        = string
  description = "Namespace to install Cilium"
  default     = "kube-system"
}

variable "lb_pool_start" {
  type        = string
  description = "LB IPAM pool start"
  default     = "10.0.15.100"
}

variable "lb_pool_stop" {
  type        = string
  description = "LB IPAM pool stop"
  default     = "10.0.15.250"
}

variable "chart_version" {
  type        = string
  description = "Cilium chart version"
  default     = "1.16.1"
}

locals {
  cilium_values = yamlencode({
    kubeProxyReplacement = "strict"
    socketLB             = { enabled = true }
    ipam = {
      mode = "kubernetes"
      operator = {
        clusterPoolIPv4PodCIDRList = []
      }
    }
    l2announcements = { enabled = true }
    l2announcementsConfig = {
      # Enable L2 announcements for LoadBalancers
      service = { enabled = true }
    }
    hubble = {
      enabled = true
      relay   = { enabled = true }
      ui      = { enabled = true }
    }
    encryption = { enabled = true, type = "wireguard" }
    gatewayAPI = { enabled = true }
  })
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 600

  values = [local.cilium_values]
}

# CRDs for LB IPAM pool and L2 announcements policy
resource "kubernetes_manifest" "lb_pool" {
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata   = { name = "lb-pool" }
    spec = {
      blocks = [{ start = var.lb_pool_start, stop = var.lb_pool_stop }]
    }
  }

  depends_on = [helm_release.cilium]
}

resource "kubernetes_manifest" "l2_policy" {
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumL2AnnouncementPolicy"
    metadata   = { name = "l2-policy" }
    spec       = { externalIPs = true, loadBalancerIPs = true }
  }

  depends_on = [helm_release.cilium]
}
