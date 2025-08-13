variable "cluster_name" {
  description = "Cluster name prefix for VMs (e.g., infraflux-prod)"
  type        = string
}

variable "org_prefix" {
  description = "Organization/project tag prefix"
  type        = string
  default     = "infraflux"
}

variable "pve_node" {
  description = "Proxmox node name to place the VMs on"
  type        = string
}

variable "iso_file_id" {
  description = "Full Proxmox file ID for Talos ISO (e.g., local:iso/talos-installer-1.8.2-<schematic>.iso)"
  type        = string
}

variable "iso_storage" {
  description = "Datastore for ISO files (kept for compatibility; not used if iso_file_id is provided)"
  type        = string
  default     = "local"
}

variable "vm_disk_storage" {
  description = "Datastore for VM disks (e.g., local-lvm, bigdisk)"
  type        = string
}

variable "bridge" {
  description = "Bridge interface (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "controlplane_count" {
  description = "Number of control-plane nodes"
  type        = number
  default     = 3
}

variable "controlplane_vcpus" {
  description = "vCPU cores per control-plane VM"
  type        = number
  default     = 4
}

variable "controlplane_mem_mb" {
  description = "RAM in MB per control-plane VM"
  type        = number
  default     = 8192
}

variable "controlplane_disk_gb" {
  description = "OS disk size in GB for control-plane"
  type        = number
  default     = 40
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "worker_vcpus" {
  description = "vCPU cores per worker VM"
  type        = number
  default     = 4
}

variable "worker_mem_mb" {
  description = "RAM in MB per worker VM"
  type        = number
  default     = 8192
}

variable "worker_os_disk_gb" {
  description = "OS disk size in GB for worker"
  type        = number
  default     = 40
}

variable "worker_data_disk_gb" {
  description = "Longhorn data disk size in GB per worker"
  type        = number
  default     = 200
}
