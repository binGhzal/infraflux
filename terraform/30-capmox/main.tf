terraform {
	required_providers {
		kubernetes = {
			source  = "hashicorp/kubernetes"
			version = ">= 2.28.0"
		}
	}
}

provider "kubernetes" {}

locals {
	inputs = var.inputs
	enabled = try(local.inputs.flags.enable_capmox, false)

	secret_yaml = templatefile(
		"${path.module}/templates/proxmox-credentials-secret.yaml.tmpl",
		{
			credentials = try(local.inputs.capmox.credentials, {})
		}
	)
	proxmoxcluster_yaml = templatefile(
		"${path.module}/templates/proxmoxcluster.yaml.tmpl",
		{
			cluster = try(local.inputs.cluster, {})
			proxmox = try(local.inputs.proxmox, {})
		}
	)

	manifests = [for d in split("\n---\n", join("\n---\n", [local.secret_yaml, local.proxmoxcluster_yaml])) : d if trimspace(d) != ""]
}

resource "kubernetes_manifest" "capmox" {
	for_each = local.enabled ? { for i, d in local.manifests : i => yamldecode(d) } : tomap({})
	manifest = each.value
	field_manager { force_conflicts = true }
}
