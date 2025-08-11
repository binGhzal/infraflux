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

# Install Cluster API Operator via Helm chart with wait
# resource "helm_release" "capi_operator" { ... }
