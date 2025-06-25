# TODO: InfraFlux Refactoring Tasks
# - [x] Added external_endpoint variable for external cluster access
# - [ ] Consider moving all cluster endpoint configuration to a dedicated object
# - [ ] Add validation for external_endpoint format (URL/IP)

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "template_name" {
  description = "Name of the VM template to clone"
  type        = string
  default     = "ubuntu-cloud-init-template"
}

variable "template_vm_id" {
  description = "ID of the VM template to clone"
  type        = number
  default     = 9000
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_private_key_file" {
  description = "Path to SSH private key file for Ansible"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "datastore_id" {
  description = "Proxmox datastore ID"
  type        = string
  default     = "local-lvm"
}

variable "vm_username" {
  description = "Default username for VMs"
  type        = string
  default     = "ansible"
}

variable "rke2_servers" {
  description = "RKE2 server nodes configuration"
  type        = object({
    count        = number
    vm_id_start  = number
    ip_start     = string
    cpu_cores    = number
    memory       = number
    disk_size    = number
  })
  default = {
    count        = 3
    vm_id_start  = 500
    ip_start     = "192.168.3.21"
    cpu_cores    = 2
    memory       = 4096
    disk_size    = 50
  }
}

variable "rke2_agents" {
  description = "RKE2 agent nodes configuration"
  type        = object({
    count        = number
    vm_id_start  = number
    ip_start     = string
    cpu_cores    = number
    memory       = number
    disk_size    = number
  })
  default = {
    count        = 2
    vm_id_start  = 550
    ip_start     = "192.168.3.24"
    cpu_cores    = 2
    memory       = 4096
    disk_size    = 50
  }
}

variable "rke2_config" {
  description = "RKE2 cluster configuration"
  type        = object({
    os               = string
    arch             = string
    vip              = string
    vip_interface    = string
    metallb_version  = string
    lb_range         = string
    lb_pool_name     = string
    rke2_version     = string
    kube_vip_version = string
  })
  default = {
    os               = "linux"
    arch             = "amd64"
    vip              = "192.168.3.50"
    vip_interface    = "eth0"
    metallb_version  = "v0.13.12"
    lb_range         = "192.168.3.80-192.168.3.90"
    lb_pool_name     = "first-pool"
    rke2_version     = "v1.29.4+rke2r1"
    kube_vip_version = "v0.8.0"
  }
}

variable "network_config" {
  description = "Network configuration for RKE2 cluster"
  type        = object({
    bridge      = string
    subnet      = string
    subnet_mask = number
    gateway     = string
    vlan_id     = number
  })
  default = {
    bridge      = "vmbr0"
    subnet      = "192.168.3.0/24"
    subnet_mask = 24
    gateway     = "192.168.3.1"
    vlan_id     = null
  }
}

variable "external_endpoint" {
  description = "External endpoint for accessing the cluster from outside the internal network (e.g., public IP or FQDN)"
  type        = string
  default     = ""
}

# Cloudflare Configuration
variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_domain" {
  description = "Primary domain for cluster services (e.g., k8s.example.com)"
  type        = string
}

# Cilium-specific networking configuration
variable "cilium_config" {
  description = "Cilium-specific networking configuration"
  type = object({
    pod_cidr           = string
    service_cidr       = string
    bgp_asn           = number
    bgp_peer_asn      = number
    lb_ip_range       = string
    enable_bgp        = bool
    enable_encryption = bool
  })
  default = {
    pod_cidr           = "10.244.0.0/16"
    service_cidr       = "10.96.0.0/12"
    bgp_asn           = 65001
    bgp_peer_asn      = 65000
    lb_ip_range       = "192.168.3.80-192.168.3.90"
    enable_bgp        = true
    enable_encryption = true
  }
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "infraflux-rke2"
}
