provider "proxmox" {
  # Authentication via environment variables is recommended:
  # PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET
  # Optional: PM_TLS_INSECURE ("true" to skip TLS verify in homelab)
}

# Kubernetes and Helm providers will be configured after the cluster is up.
# We keep them declared here for module wiring later in the roadmap.
provider "kubernetes" {
  config_path = var.kubeconfig
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
