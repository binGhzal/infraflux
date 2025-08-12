variable "kubeconfig" {
	description = "Path to kubeconfig for the management cluster"
	type        = string
	default     = "~/.kube/config"
}

variable "namespace" {
	description = "Namespace to install Cluster API Operator into"
	type        = string
	default     = "capi-operator-system"
}

provider "helm" {
	kubernetes {
		config_path = var.kubeconfig
	}
}

provider "kubernetes" {
	config_path = var.kubeconfig
}

resource "kubernetes_namespace" "capi_operator" {
	metadata {
		name = var.namespace
	}
}

resource "helm_release" "capi_operator" {
	name       = "cluster-api-operator"
	repository = "https://kubernetes-sigs.github.io/cluster-api-operator"
	chart      = "cluster-api-operator"
	version    = "0.13.0"
	namespace  = kubernetes_namespace.capi_operator.metadata[0].name

	values = [file("${path.module}/../..//clusters/mgmt/capi-operator/values.yaml")]
}
