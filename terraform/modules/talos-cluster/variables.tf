variable "cluster_name" {
  description = "Cluster name"
  type        = string
}

variable "cluster_vip" {
  description = "Virtual IP for Kubernetes API (Talos VIP)"
  type        = string
}

variable "controlplane_ips" {
  description = "List of control-plane node IPv4 addresses"
  type        = list(string)
}

variable "worker_ips" {
  description = "List of worker node IPv4 addresses"
  type        = list(string)
  default     = []
}

variable "talos_version" {
  description = "Talos features version to use for config generation"
  type        = string
  default     = null
}

variable "install_disk" {
  description = "Install disk path on Talos nodes (e.g., /dev/sda or /dev/vda)"
  type        = string
  default     = "/dev/sda"
}
