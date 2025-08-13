# --- Proxmox connection ---
variable "pm_api_url" { type = string }
variable "pm_user" { type = string } # e.g., "root@pam"
variable "pm_token_id" {
  type      = string
  sensitive = true
} # "root@pam!terraform"
variable "pm_token_secret" {
  type      = string
  sensitive = true
}
variable "pm_tls_insecure" {
  type    = bool
  default = true
}

# --- Proxmox placement ---
variable "pve_node" { type = string }        # "pve"
variable "iso_storage" { type = string }     # "local"
variable "vm_disk_storage" { type = string } # "bigdisk"
variable "bridge" { type = string }          # "vmbr0"

# --- Talos cluster identity ---
variable "cluster_name" { type = string }     # "infraflux"
variable "talos_version" { type = string }    # e.g., "v1.7.5"
variable "schematic_id" { type = string }     # Image Factory schematic ID
variable "controlplane_vip" { type = string } # "10.0.1.50"

# --- Sizing ---
variable "controlplane_count" {
  type    = number
  default = 3
}
variable "controlplane_vcpus" {
  type    = number
  default = 2
}
variable "controlplane_mem_mb" {
  type    = number
  default = 8192
}
variable "controlplane_disk_gb" {
  type    = number
  default = 60
}

variable "worker_count" {
  type    = number
  default = 9
}
variable "worker_vcpus" {
  type    = number
  default = 4
}
variable "worker_mem_mb" {
  type    = number
  default = 16384
}
variable "worker_os_disk_gb" {
  type    = number
  default = 100
}
variable "worker_data_disk_gb" {
  type    = number
  default = 200
} # Longhorn data disk

# --- Networking ---
variable "use_dhcp" {
  type    = bool
  default = true
}
variable "pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}
variable "svc_cidr" {
  type    = string
  default = "10.96.0.0/12"
}
variable "mtu" {
  type    = number
  default = 1500
}

# --- Domains / TLS / DNS ---
variable "base_domain" {
  type    = string
  default = "binghzal.com"
}
variable "argocd_hostname" {
  type    = string
  default = "argocd.binghzal.com"
}

# --- Cilium ---
variable "lb_ip_pool_start" {
  type    = string
  default = "10.0.15.100"
}
variable "lb_ip_pool_end" {
  type    = string
  default = "10.0.15.250"
}
variable "enable_wireguard" {
  type    = bool
  default = true
}
variable "cilium_version" {
  type    = string
  default = "1.18.0"
}

# --- Authentik OIDC (Argo CD & kube-apiserver) ---
variable "oidc_issuer_url" { type = string } # e.g., "https://auth.binghzal.com/application/o/argocd/"
variable "oidc_client_id" {
  type    = string
  default = "argocd"
}
# client secret supplied via ESO (not here)

# --- Cloudflare (ESO will provide token) ---
variable "cloudflare_zone" {
  type    = string
  default = "binghzal.com"
}

# --- 1Password SDK (ESO) ---
variable "op_org_url" { type = string } # e.g., "https://yourorg.1password.com"
# Service account token supplied at runtime into a K8s Secret (not here)
variable "op_vaults" {
  type    = list(string)
  default = ["infraflux-prod"]
}

# --- MinIO (Synology) ---
variable "minio_endpoint" {
  type    = string
  default = "http://10.0.0.49:9000"
}

# --- Labels / prefix ---
variable "org_prefix" {
  type    = string
  default = "infraflux"
}
