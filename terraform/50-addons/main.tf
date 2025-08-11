# Option A: Helm install Cilium to workload cluster using helm_release with values/cilium-full.yaml
# Option B: Create ClusterResourceSet to auto-apply Cilium across clusters.
terraform {
	required_providers {
		kubernetes = {
			source  = "hashicorp/kubernetes"
			version = ">= 2.28.0"
		}
		helm = {
			source  = "hashicorp/helm"
			version = ">= 2.13.0"
		}
	}
}

provider "kubernetes" {}
provider "helm" {}

locals {
	inputs = var.inputs
	enabled = try(local.inputs.flags.enable_addons, false)
	cilium_install_method = try(local.inputs.addons.cilium_install_method, "helm")
	# path.root points to the root module (terraform/_root); values/ lives two levels up
	cilium_values_yaml    = file("${path.root}/../../values/cilium-full.yaml")
}

# Option A: ClusterResourceSet to auto-apply Cilium values
locals {
	crs_yaml = templatefile(
		"${path.module}/templates/clusterresourceset-cilium.yaml.tmpl",
		{
			cluster     = try(local.inputs.cluster, {})
			values_yaml = indent(4, local.cilium_values_yaml)
		}
	)
	crs_docs = [for d in split("\n---\n", local.crs_yaml) : d if trimspace(d) != ""]
}

resource "kubernetes_manifest" "cilium_crs" {
	count    = local.enabled && local.cilium_install_method == "crs" ? 1 : 0
	for_each = local.enabled && local.cilium_install_method == "crs" ? { for i, d in local.crs_docs : i => yamldecode(d) } : {}
	manifest = each.value
}

# Option B: Helm install Cilium directly
resource "helm_release" "cilium" {
	count      = local.enabled && local.cilium_install_method == "helm" ? 1 : 0
	name       = "cilium"
	repository = "https://helm.cilium.io"
	chart      = "cilium"
	version    = try(local.inputs.addons.cilium_version, null)
	namespace  = "kube-system"
	create_namespace = false
	values = [local.cilium_values_yaml]
}
# Example: render CRS from template with configmap references
# locals {
#   crs_yaml = templatefile("${path.module}/templates/crs-cilium.yaml.tftpl", {
#     name = "cilium-crs"
#   })
# }
