# Step 3: Terraform repo skeleton for prod environment

# Module wiring will be added in subsequent roadmap steps.
# For now, keep a placeholder to ensure terraform validate passes.

locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "proxmox_vms" {
  source = "../../modules/proxmox-vm"

  cluster_name    = local.name_prefix
  org_prefix      = var.project
  pve_node        = "pve"                                              # TODO: set your node name
  iso_file_id     = "local:iso/talos-installer-1.8.2-SCHEMATIC_ID.iso" # TODO: replace with your actual file ID
  vm_disk_storage = "local-lvm"                                        # TODO: set your datastore
  bridge          = "vmbr0"

  # Defaults are fine; override if needed via tfvars
}

module "talos" {
  source = "../../modules/talos-cluster"

  cluster_name     = local.name_prefix
  cluster_vip      = "10.0.1.50"
  controlplane_ips = module.proxmox_vms.controlplane_ipv4
  worker_ips       = module.proxmox_vms.worker_ipv4
  # talos_version  = null  # use provider default
  # install_disk   = "/dev/sda"  # override if needed
}

output "kubeconfig" {
  description = "Kubeconfig from Talos cluster"
  value       = module.talos.kubeconfig
  sensitive   = true
}

module "cilium" {
  source = "../../modules/cilium"

  depends_on = [module.talos]
}

# Optional: Traefik Gateway API (fallback)
# module "traefik" {
#   source = "../../modules/traefik"
#   depends_on = [module.talos]
# }
