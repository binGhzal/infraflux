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
	enabled = try(local.inputs.flags.enable_clusters, false)
	cluster_yaml = templatefile(
		"${path.module}/templates/cluster.yaml.tmpl",
		{
			cluster = try(local.inputs.cluster, {})
			proxmox = try(local.inputs.proxmox, {})
		}
	)
	docs = [for d in split("\n---\n", local.cluster_yaml) : d if trimspace(d) != ""]
}

resource "kubernetes_manifest" "cluster" {
	for_each = local.enabled ? { for i, d in local.docs : i => yamldecode(d) } : {}
	manifest = each.value
	field_manager { force_conflicts = true }
}
