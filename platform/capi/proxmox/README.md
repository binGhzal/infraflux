# Proxmox with Cluster API + Talos

## Prereqs

- Proxmox VE API endpoint reachable
- API token/secret with permissions to create VMs, templates, networks, disks
- Talos images available in Proxmox storage (cloud-init compatible ISO/Template) or use image
  factory
- Network bridge/vlan prepared; DHCP or static addressing approach defined

## Clusterctl config

- `clusterctl.yaml` at repo root pins providers, including `proxmox` infra and `talos`
  bootstrap/control-plane

## Flow

1. Bootstrap: run `hack/bootstrap.sh --provider proxmox --git-url <repo> --branch main`
2. Generate cluster:
   `clusterctl generate cluster <name> --flavor talos-proxmox > clusters/<env>/<name>.yaml`
3. Apply: `kubectl apply -f clusters/<env>/<name>.yaml`
4. Wait for Talos nodes; pivot/move when ready

## Secrets & credentials

- Create a Secret in `capi-system` with Proxmox API credentials referenced by CAPMox (see upstream
  docs). Example keys:
  - PROXMOX_URL
  - PROXMOX_TOKEN_ID
  - PROXMOX_TOKEN_SECRET
- For image/template IDs, set fields in the Cluster/MD YAML accordingly

## Notes

- Consider Cilium L2/L3 LB or MetalLB with BGP for bare-metal L4
- Storage classes: local-lvm or Ceph/RBD via Rook for persistent workloads
