terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = { source = "bpg/proxmox", version = ">= 0.58.0" }
    talos   = { source = "siderolabs/talos", version = ">= 0.4.0-alpha.0" }
    helm    = { source = "hashicorp/helm", version = ">= 2.13.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.28.0" }
  }
}

locals {
  inputs = yamldecode(file(var.inputs_file))
}

provider "proxmox" {
  endpoint    = try(local.inputs.proxmox.endpoint, null)
  api_token   = try(local.inputs.proxmox.api_token, null)
  tls_insecure = try(local.inputs.proxmox.tls_insecure, false)
}

provider "talos" {}
provider "kubernetes" {
  config_path = try(local.inputs.kubernetes.kubeconfig, null)
}
provider "helm" {
  kubernetes {
    config_path = try(local.inputs.kubernetes.kubeconfig, null)
  }
}

module "proxmox_foundation" {
  source = "../00-proxmox-foundation"

  inputs = local.inputs
}

module "mgmt_talos" {
  source = "../10-mgmt-talos"

  inputs = local.inputs
}

module "capi_operator" {
  source = "../20-capi-operator"

  inputs = local.inputs
}

module "capmox" {
  source = "../30-capmox"

  inputs = local.inputs
}

module "clusters" {
  source = "../40-clusters"

  inputs = local.inputs
}

module "addons" {
  source = "../50-addons"

  inputs = local.inputs
}
