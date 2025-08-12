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
    description = "(Deprecated) Name of an existing Talos VM template to clone"
    type        = string
    default     = null
}

variable "talos_template_id" {
    description = "VMID of the Talos template to clone (preferred)"
    type        = number
    default     = null
}

variable "bootstrap_node_name" {
    description = "Name for the single bootstrap Talos node"
    type        = string
    default     = "talos-bootstrap"
}

variable "bootstrap_vmid" {
    description = "VMID for the bootstrap node (optional, will auto-assign if not set)"
    type        = number
    default     = null
}

variable "cpu_cores" {
    type        = number
    description = "vCPU cores for the bootstrap node"
    default     = 2
}

variable "memory_mb" {
    type        = number
    description = "Memory MB for the bootstrap node"
    default     = 4096
}

variable "disk_size_gb" {
    type        = number
    description = "Primary disk size in GB"
    default     = 40
}

variable "iso_path" {
    type        = string
    description = "Optional ISO to mount as cdrom (format: <storage>:iso/<file.iso>)"
    default     = null
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
