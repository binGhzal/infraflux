terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.57.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.8.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.pm_api_url
  insecure = var.pm_tls_insecure
  # bpg/proxmox expects full API token string in format "<user>!<tokenid>=<secret>"
  api_token = "${var.pm_token_id}=${var.pm_token_secret}"
}

# K8s & Helm providers get configured AFTER cluster comes up (see talos_cluster.tf)
