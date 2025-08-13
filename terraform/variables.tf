variable "pm_api_url"        { type = string }
variable "pm_user"           { type = string }
variable "pm_password"       { type = string, sensitive = true }
variable "pm_tls_insecure"   { type = bool, default = true }

variable "pve_node"          { type = string }
variable "iso_storage"       { type = string }
variable "vm_disk_storage"   { type = string }
variable "bridge"            { type = string }

variable "cluster_name"      { type = string }
variable "talos_version"     { type = string }
variable "schematic_id"      { type = string }
variable "controlplane_vip"  { type = string }
variable "controlplane_count"{ type = number }
variable "controlplane_vcpus"{ type = number }
variable "controlplane_mem_mb" { type = number }
variable "controlplane_disk_gb" { type = number }

variable "worker_count"      { type = number }
variable "worker_vcpus"      { type = number }
variable "worker_mem_mb"     { type = number }
variable "worker_disk_gb"    { type = number }

variable "use_dhcp"          { type = bool, default = true }
variable "pod_cidr"          { type = string }
variable "svc_cidr"          { type = string }

variable "base_domain"       { type = string }
variable "ingress_domain"    { type = string }

variable "lb_ip_pool_start"  { type = string }
variable "lb_ip_pool_end"    { type = string }
variable "enable_wireguard"  { type = bool, default = false }
variable "cilium_version"    { type = string }

variable "authentik_issuer_url" { type = string }
variable "authentik_client_id"  { type = string }

variable "cloudflare_zone"   { type = string }
variable "cloudflare_email"  { type = string, default = "" }

variable "onepassword_connect_url" { type = string }

variable "minio_endpoint"    { type = string }
variable "minio_bucket"      { type = string }
variable "velero_retention_days" { type = number, default = 7 }

variable "org_prefix"        { type = string }
