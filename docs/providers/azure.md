# Azure (CAPZ)

## Credentials

- Service Principal with least-privilege for VMSS, VNets, Load Balancers, Managed Disks, and optionally DNS Zones.
- Store as SOPS Secret; reference in CAPZ ProviderConfig.

## Networking

- Prepare a VNet with subnets and NSGs or let CAPZ create defaults per overlay config.

## Overlays

- Mirror the AWS layout under `clusters/azure/`, setting:
  - location (e.g., `westeurope`)
  - VM sizes (e.g., `Standard_D2s_v5`)
  - replicas and versions.

## Notes

- Consider Azure Disk/Files CSI if you prefer managed storage over Longhorn.
