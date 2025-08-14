terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.28"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.6.0"
    }
  }
}
