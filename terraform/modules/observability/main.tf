terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
  }
}

resource "helm_release" "kps" {
  name       = "kube-prometheus-stack"
  namespace  = var.monitoring_namespace
  repository = var.kps_repo
  chart      = var.kps_chart
  version    = var.kps_version

  create_namespace = true

  values = [yamlencode({
    grafana = {
      defaultDashboardsEnabled = true
      service = { type = "ClusterIP" }
    }
  })]
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = var.logging_namespace
  repository = var.loki_repo
  chart      = var.loki_chart
  version    = var.loki_version

  create_namespace = true

  values = [yamlencode({
    monitoring = { selfMonitoring = { enabled = false } },
    limits_config = {
      retention_period = "168h"
    }
  })]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  namespace  = var.logging_namespace
  repository = var.promtail_repo
  chart      = var.promtail_chart
  version    = var.promtail_version

  values = [yamlencode({
    config = {
      clients = [{ url = "http://loki.${var.logging_namespace}.svc.cluster.local:3100/loki/api/v1/push" }]
    }
  })]

  depends_on = [helm_release.loki]
}
