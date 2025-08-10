# Proxmox (CAPMOX)

## Credentials

- Proxmox API token (realm, user, token name, secret).
- Encrypt with SOPS; the CAPMOX controller references it.

## Templates

- Prepare a **Talos** VM template in Proxmox (cloud-init capable or via documented CAPMOX method).
- Ensure storage pool and network bridge are configured.

## Overlays

- `clusters/proxmox/` should define:
  - `node` (PVE host)
  - `storage` (e.g., `local-lvm`)
  - `network` bridge (e.g., `vmbr0`)
  - CPU, memory, disk sizes
  - replicas and versions

## Notes

- For LoadBalancing, use **Kube-VIP** or **MetalLB** (ship as optional recipe).
