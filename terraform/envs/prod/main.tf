# Step 3: Terraform repo skeleton for prod environment

# Module wiring will be added in subsequent roadmap steps.
# For now, keep a placeholder to ensure terraform validate passes.

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# Example placeholders (commented until modules exist)
# module "proxmox_vms" {
#   source = "../../modules/proxmox-vm"
#   # ...inputs
# }

# module "talos" {
#   source = "../../modules/talos-cluster"
# }

# module "cilium" {
#   source = "../../modules/cilium"
# }
