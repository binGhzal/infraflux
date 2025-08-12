variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }

variable "target_node" {
    description = "Proxmox node name to place VMs on (e.g., pve01)"
    type        = string
}

variable "datastore" {
    description = "Proxmox storage name for VM disks"
    type        = string
}

variable "bridge" {
    description = "Proxmox network bridge, e.g., vmbr0"
    type        = string
}

variable "talos_template" {
    description = "Name of an existing Talos VM template to clone"
    type        = string
}

variable "cluster_name" {
    description = "Cluster name prefix for VMs"
    type        = string
    default     = "mgmt"
}

variable "cp_count" {
    description = "Number of control plane nodes"
    type        = number
    default     = 3
}

variable "worker_count" {
    description = "Number of worker nodes"
    type        = number
    default     = 0
}

variable "cp_vmid_base" {
    description = "Base VMID for control plane nodes; incremented per node"
    type        = number
    default     = 7000
}

variable "worker_vmid_base" {
    description = "Base VMID for worker nodes; incremented per node"
    type        = number
    default     = 7100
}

variable "cp_cpu" {
    type        = number
    description = "vCPU cores for control plane nodes"
    default     = 2
}

variable "cp_memory_mb" {
    type        = number
    description = "Memory MB for control plane nodes"
    default     = 4096
}

variable "worker_cpu" {
    type        = number
    description = "vCPU cores for worker nodes"
    default     = 2
}

variable "worker_memory_mb" {
    type        = number
    description = "Memory MB for worker nodes"
    default     = 4096
}

variable "disk_size_gb" {
    type        = number
    description = "Primary disk size in GB"
    default     = 40
}

variable "ssh_public_keys" {
    type        = string
    description = "SSH public keys appended to cloud-init for Talos (optional)"
    default     = ""
}

variable "cloud_init_user" {
    type        = string
    description = "Cloud-init user (Talos ignores login by default; used for emergency access)"
    default     = "talos"
}

variable "cloud_init_password" {
    type        = string
    description = "Cloud-init password (hashed or plain per Proxmox settings)"
    default     = "changeme"
}
