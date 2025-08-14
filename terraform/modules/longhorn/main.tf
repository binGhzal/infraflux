terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
  }
}

locals {
  values = merge({
    persistence = {
      defaultClass = true
    }
    defaultSettings = {
      # Respect Talos iscsi/util-linux pre-reqs per roadmap
    }
  }, var.backup_target != null ? {
    defaultSettings = {
      backupTarget = var.backup_target
      # Optional: secret containing keys for S3-compatible backup target
      backupTargetCredentialSecret = var.backup_credentials_secret
    }
  } : {})
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  namespace  = var.namespace
  repository = var.helm_repo
  chart      = var.helm_chart
  version    = var.chart_version

  create_namespace = true

  values = [yamlencode(local.values)]

  timeout       = 600
  wait          = true
  recreate_pods = false
}
