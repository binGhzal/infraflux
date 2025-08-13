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

# module "talos" {
#   source = "../../modules/talos-cluster"
# }

# module "cilium" {
#   source = "../../modules/cilium"
# }
