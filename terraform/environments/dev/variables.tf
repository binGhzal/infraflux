variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys for node access"
  type        = string
  default     = ""
}
