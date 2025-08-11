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
  # endpoint = local.inputs.proxmox.endpoint
  # api_token = local.inputs.proxmox.api_token
}

provider "talos" {}
provider "helm" {}
provider "kubernetes" {}

module "proxmox_foundation" {
  source = "../00-proxmox-foundation"

  proxmox_endpoint  = local.inputs.proxmox.endpoint
  proxmox_api_token = local.inputs.proxmox.api_token
  proxmox_datastore = local.inputs.proxmox.datastore
  proxmox_node      = local.inputs.proxmox.node
}

module "mgmt_talos" {
  source = "../10-mgmt-talos"

  cluster_name            = local.inputs.mgmt.cluster_name
  control_plane_endpoints = local.inputs.mgmt.control_plane_endpoints
}

module "capi_operator" {
  source = "../20-capi-operator"

  namespace = local.inputs.capi_operator.namespace
}

module "capmox" {
  source = "../30-capmox"

  proxmox_credentials_secret = "capmox-credentials" # can be created from inputs if needed
}

module "clusters" {
  source = "../40-clusters"

  cluster_name = local.inputs.mgmt.cluster_name
}

module "addons" {
  source = "../50-addons"

  install_method = local.inputs.addons.cilium_install_method
}
