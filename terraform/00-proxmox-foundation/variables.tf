variable "pm_api_url" {
  description = "Proxmox API URL, e.g., https://proxmox.example:8006/api2/json"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID, e.g., root@pam!token"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Skip TLS verification when connecting to Proxmox"
  type        = bool
  default     = false
}

variable "datastore" {
  description = "Proxmox datastore name where images and disks are stored"
  type        = string
}

variable "bridge" {
  description = "Network bridge name to attach VMs to"
  type        = string
}

variable "talos_template" {
  description = "Name of the Talos VM template/image"
  type        = string
}

variable "upload_talos_image" {
  description = "Run local command to upload Talos image if template absent"
  type        = bool
  default     = false
}

variable "upload_talos_image_cmd" {
  description = "Shell command executed when upload_talos_image is true"
  type        = string
  default     = "echo 'Talos image upload command not provided'"
}
