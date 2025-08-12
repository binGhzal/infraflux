variable "kubeconfig" {
	description = "Path to kubeconfig for the management cluster"
	type        = string
	default     = "~/.kube/config"
}

variable "namespace" {
	description = "Namespace where CAPMox runs"
	type        = string
	default     = "capmox-system"
}

variable "proxmox_url" {
	description = "Proxmox API URL"
	type        = string
}

variable "proxmox_token_id" {
	description = "Proxmox API token ID"
	type        = string
}

variable "proxmox_token_secret" {
	description = "Proxmox API token secret"
	type        = string
	sensitive   = true
}

provider "kubernetes" {
	config_path = var.kubeconfig
}

resource "kubernetes_namespace" "capmox" {
	metadata {
		name = var.namespace
	}
}

resource "kubernetes_secret" "capmox_credentials" {
	metadata {
		name      = "proxmox-credentials"
		namespace = kubernetes_namespace.capmox.metadata[0].name
	}
	type = "Opaque"
	string_data = {
		url         = var.proxmox_url
		tokenID     = var.proxmox_token_id
		tokenSecret = var.proxmox_token_secret
	}
}

# Optional: ProxmoxCluster default for management cluster
resource "kubernetes_manifest" "proxmoxcluster_default" {
	manifest = {
		apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
		kind       = "ProxmoxCluster"
		metadata = {
			name      = "default"
			namespace = kubernetes_namespace.capmox.metadata[0].name
		}
		spec = {
			# Fill with your global defaults as needed
		}
	}
}
