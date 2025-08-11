terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.28.0"
    }
  }
}

provider "helm" {}
provider "kubernetes" {}

locals {
  inputs = var.inputs
  enable_capi = try(local.inputs.flags.enable_capi, false)

  providers_cr_yaml = templatefile(
    "${path.module}/templates/providers-cr.yaml.tmpl",
    {
      providers = try(local.inputs.capi_operator.providers, {})
    }
  )

  providers_cr_docs = [for d in split("\n---\n", local.providers_cr_yaml) : d if trimspace(d) != ""]
}

# Optional: install Cluster API Operator via Helm (chart details provided via inputs)
resource "helm_release" "capi_operator" {
  count      = local.enable_capi && try(local.inputs.capi_operator.helm.enabled, false) ? 1 : 0
  name       = try(local.inputs.capi_operator.helm.name, "cluster-api-operator")
  repository = try(local.inputs.capi_operator.helm.repository, null)
  chart      = try(local.inputs.capi_operator.helm.chart, null)
  version    = try(local.inputs.capi_operator.helm.version, null)
  namespace  = try(local.inputs.capi_operator.helm.namespace, "capi-operator-system")
  create_namespace = true
  wait       = true
}

# Apply Provider CRs to enable infrastructure/bootstrap/control-plane providers
resource "kubernetes_manifest" "providers" {
  for_each = local.enable_capi ? { for i, d in local.providers_cr_docs : i => yamldecode(d) } : {}
  manifest = each.value
  field_manager { force_conflicts = true }
  depends_on = [helm_release.capi_operator]
}
