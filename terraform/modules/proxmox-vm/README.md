# Proxmox VM module

Creates Talos control-plane and worker VMs on a Proxmox node, attaching a Talos ISO and enabling the QEMU guest agent. Workers get an extra data disk for Longhorn.

Inputs (key):

- cluster_name (string)
- org_prefix (string, default "infraflux")
- pve_node (string)
- iso_file_id (string, e.g., `local:iso/talos-installer-<ver>-SCHEMATIC_ID.iso`)
- vm_disk_storage (string)
- bridge (string, default `vmbr0`)
- controlplane_count (number, default 3)
- controlplane_vcpus (number, default 4)
- controlplane_mem_mb (number, default 8192)
- controlplane_disk_gb (number, default 40)
- worker_count (number, default 3)
- worker_vcpus (number, default 4)
- worker_mem_mb (number, default 8192)
- worker_os_disk_gb (number, default 40)
- worker_data_disk_gb (number, default 200)

Outputs:

- controlplane_vm_ids, worker_vm_ids
- controlplane_ipv4, worker_ipv4 (best-effort via guest agent)
- controlplane_mac_addrs, worker_mac_addrs

Example usage:

module "proxmox_vms" {
source = "../../modules/proxmox-vm"
cluster_name = "infraflux-prod"
org_prefix = "infraflux"
pve_node = "pve"
iso_file_id = "local:iso/talos-installer-1.8.2-SCHEMATIC_ID.iso"
vm_disk_storage = "bigdisk"
bridge = "vmbr0"
controlplane_count = 3
worker_count = 3
}
