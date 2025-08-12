variable "vm_name" {
  description = "Base name for the VM(s)"
  type        = string
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "vm_ids" {
  description = "Specific VM IDs to use (optional)"
  type        = list(number)
  default     = null
}

variable "target_node" {
  description = "Proxmox node to deploy VMs on"
  type        = string
}

variable "template_name" {
  description = "Name of the template to clone"
  type        = string
  default     = null
}

variable "template_id" {
  description = "ID of the template to clone"
  type        = number
  default     = null
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Primary disk size in GB"
  type        = number
  default     = 40
}

variable "storage" {
  description = "Storage pool for primary disk"
  type        = string
}

variable "disk_cache" {
  description = "Disk cache type"
  type        = string
  default     = "none"
}

variable "disk_ssd" {
  description = "Whether disk is SSD"
  type        = bool
  default     = false
}

variable "additional_disks" {
  description = "Additional disks configuration"
  type = list(object({
    slot     = string
    size_gb  = number
    storage  = string
    cache    = string
    ssd      = bool
  }))
  default = []
}

variable "network_interfaces" {
  description = "Network interface configuration"
  type = list(object({
    id       = number
    model    = string
    bridge   = string
    vlan_tag = number
  }))
  default = [
    {
      id       = 0
      model    = "virtio"
      bridge   = "vmbr0"
      vlan_tag = null
    }
  ]
}

variable "iso_path" {
  description = "ISO path for CD-ROM mount"
  type        = string
  default     = null
}

variable "os_type" {
  description = "Operating system type"
  type        = string
  default     = "l26"
}

variable "cloud_init_user" {
  description = "Cloud-init username"
  type        = string
  default     = "admin"
}

variable "cloud_init_password" {
  description = "Cloud-init password"
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys for cloud-init"
  type        = string
  default     = ""
}

variable "ip_config" {
  description = "IP configuration for cloud-init"
  type        = string
  default     = "dhcp"
}

variable "qemu_agent" {
  description = "Enable QEMU guest agent"
  type        = number
  default     = 1
}

variable "start_on_boot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}

variable "scsi_controller" {
  description = "SCSI controller type"
  type        = string
  default     = "virtio-scsi-pci"
}

variable "tags" {
  description = "Tags for VM organization"
  type        = string
  default     = ""
}
