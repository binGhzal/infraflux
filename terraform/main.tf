provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

locals {
  # Single bootstrap node only
  bootstrap_vmid = var.bootstrap_vmid != null ? var.bootstrap_vmid : 7000

  # Determine the cluster endpoint
  cluster_endpoint = var.cluster_vip != null ? var.cluster_vip : var.talos_cluster_endpoint
}

# Generate Talos machine configuration
resource "talos_machine_secrets" "bootstrap" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.talos_cluster_name
  cluster_endpoint = "https://${local.cluster_endpoint}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.bootstrap.machine_secrets
}

data "talos_client_configuration" "bootstrap" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.bootstrap.client_configuration
  endpoints            = [var.talos_cluster_endpoint]
}

# Module-level validations
resource "null_resource" "validations" {
  lifecycle {
    precondition {
      condition     = (var.talos_template != null) != (var.talos_template_id != null)
      error_message = "Set exactly one of talos_template (name) or talos_template_id (VMID)."
    }
  }
}

resource "proxmox_vm_qemu" "bootstrap" {
  name        = var.bootstrap_node_name
  target_node = var.target_node
  vmid        = local.bootstrap_vmid

  # Set ONE of the following: clone (NAME) or clone_id (VMID)
  clone      = var.talos_template
  clone_id   = var.talos_template_id
  full_clone = true

  agent    = 1
  onboot   = true
  cores    = var.cpu_cores
  memory   = var.memory_mb
  scsihw   = "virtio-scsi-pci"
  boot     = var.iso_path != null ? "order=ide2;scsi0;net0" : "order=scsi0;net0"

  disk {
    slot    = "scsi0"
    size    = format("%dG", var.disk_size_gb)
    type    = "disk"
    storage = var.datastore
  }

  # Optional ISO mount on ide2 as cdrom
  dynamic "disk" {
    for_each = var.iso_path != null ? [1] : []
    content {
      slot = "ide2"
      type = "cdrom"
      iso  = var.iso_path
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }

  os_type = "l26"
  ciuser   = var.cloud_init_user
  cipassword = var.cloud_init_password
  sshkeys    = var.ssh_public_keys
}

# Apply Talos configuration to the bootstrap node
resource "talos_machine_configuration_apply" "bootstrap" {
  depends_on = [proxmox_vm_qemu.bootstrap]

  client_configuration        = talos_machine_secrets.bootstrap.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.talos_cluster_endpoint

  # Wait for the VM to be ready
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
      }
    })
  ]
}

# Bootstrap the Talos cluster
resource "talos_machine_bootstrap" "bootstrap" {
  depends_on = [talos_machine_configuration_apply.bootstrap]

  client_configuration = talos_machine_secrets.bootstrap.client_configuration
  node                 = var.talos_cluster_endpoint
}

# Wait for cluster to be ready and get kubeconfig
data "talos_cluster_kubeconfig" "bootstrap" {
  depends_on = [talos_machine_bootstrap.bootstrap]

  client_configuration = talos_machine_secrets.bootstrap.client_configuration
  node                 = var.talos_cluster_endpoint
}

# Save kubeconfig to local file
resource "local_file" "kubeconfig" {
  content  = data.talos_cluster_kubeconfig.bootstrap.kubeconfig_raw
  filename = "${path.module}/kubeconfig"

  provisioner "local-exec" {
    command = "chmod 600 ${path.module}/kubeconfig"
  }
}
output "bootstrap_vm_name" {
  value = var.bootstrap_node_name
}

output "bootstrap_vm_id" {
  value = local.bootstrap_vmid
}

output "talos_client_config" {
  value     = data.talos_client_configuration.bootstrap.talos_config
  sensitive = true
}

output "kubeconfig_path" {
  value = local_file.kubeconfig.filename
}

output "cluster_endpoint" {
  value = "https://${local.cluster_endpoint}:6443"
}
