# Proxmox VM module

Creates Talos control-plane and worker VMs on a Proxmox node, attaching a Talos ISO and enabling the QEMU guest agent. Workers also get a data disk for Longhorn.

## Inputs (key)

- cluster_name (string)
- org_prefix (string, default "infraflux")
- pve_node (string)
- iso_file_id (string, e.g., `local:iso/talos-installer-1.8.2-SCHEMATIC_ID.iso`)
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

## Outputs

- controlplane_vm_ids, worker_vm_ids
- controlplane_ipv4, worker_ipv4 (best-effort via guest agent)

## Example usage (env `prod`)

Add the module in `terraform/envs/prod/main.tf` (already scaffolded):

- Set `pve_node`, `iso_file_id`, and `vm_disk_storage`.
- Optionally override counts/sizing in `prod.auto.tfvars`.

## Notes & pitfalls

- Talos ISO is attached via CD-ROM; DHCP is enabled via cloud-init ip_config for initial network. Guest agent must be enabled in the image (we included siderolabs/qemu-guest-agent in the Image Factory schematic).
- For Proxmox datastore permissions, ensure the token has access to the ISO and VM disk datastores, and API privileges to create VMs.
- If using path-style storage or different disk buses, adjust the `disk.interface` values.

## Mini diagram

```mermaid
flowchart LR
  subgraph Proxmox Node (pve)
    CP1[VM: cp-01]\nscsi0: OS
    CP2[VM: cp-02]\nscsi0: OS
    CP3[VM: cp-03]\nscsi0: OS
    W1[VM: wrk-01]\nscsi0: OS\nscsi1: data
    W2[VM: wrk-02]\nscsi0: OS\nscsi1: data
    W3[VM: wrk-03]\nscsi0: OS\nscsi1: data
  end
  ISO[(ISO: Talos installer)] --> CP1
  ISO --> CP2
  ISO --> CP3
  ISO --> W1
  ISO --> W2
  ISO --> W3
```

## References

- Proxmox VM resource: bpg/proxmox provider (initialization, disk, network, agent).
- Cloud-init ip_config DHCP pattern for VMs.
- Outputs via guest agent (`ipv4_addresses`) best-effort.
