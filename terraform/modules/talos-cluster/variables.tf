variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint (IP or FQDN)"
  type        = string
}

variable "node_endpoints" {
  description = "List of all node endpoints for Talos client"
  type        = list(string)
}

variable "controlplane_endpoints" {
  description = "List of control plane node endpoints"
  type        = list(string)
}

variable "worker_endpoints" {
  description = "List of worker node endpoints"
  type        = list(string)
  default     = []
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 0
}

variable "install_disk" {
  description = "Disk to install Talos on"
  type        = string
  default     = "/dev/sda"
}

variable "network_config" {
  description = "Network configuration for Talos nodes"
  type        = any
  default     = {}
}

variable "global_config_patches" {
  description = "Global configuration patches applied to all nodes"
  type        = list(string)
  default     = []
}

variable "controlplane_config_patches" {
  description = "Configuration patches applied only to control plane nodes"
  type        = list(string)
  default     = []
}

variable "worker_config_patches" {
  description = "Configuration patches applied only to worker nodes"
  type        = list(string)
  default     = []
}

variable "vm_dependency" {
  description = "Dependency on VM creation to ensure proper ordering"
  type        = any
  default     = null
}

variable "save_kubeconfig" {
  description = "Whether to save kubeconfig to file"
  type        = bool
  default     = true
}

variable "kubeconfig_path" {
  description = "Path to save kubeconfig file"
  type        = string
  default     = "./kubeconfig"
}

variable "save_talosconfig" {
  description = "Whether to save Talos config to file"
  type        = bool
  default     = true
}

variable "talosconfig_path" {
  description = "Path to save Talos config file"
  type        = string
  default     = "./talosconfig"
}
