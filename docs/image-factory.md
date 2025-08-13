# Talos Image Factory — Schematic & Build

Purpose: Build a universal Talos image for Proxmox VMs (control-plane + workers) with required system extensions.

## Schematic

See `image-factory/schematic.yaml`. Extensions included:

- siderolabs/qemu-guest-agent
- siderolabs/iscsi-tools
- siderolabs/util-linux-tools
- siderolabs/intel-ucode

## Build steps

1. Upload schematic and capture ID

Optional command:

```sh
curl -X POST --data-binary @image-factory/schematic.yaml https://factory.talos.dev/schematics
# Response: {"id":"<schematic_id>"}
```

1. Retrieve assets (choose one for Proxmox workflow)

- ISO (manual): [nocloud-amd64.iso](https://factory.talos.dev/image/SCHEMATIC_ID/RELEASE/nocloud-amd64.iso)
- RAW disk: [nocloud-amd64.raw.xz](https://factory.talos.dev/image/SCHEMATIC_ID/RELEASE/nocloud-amd64.raw.xz)
- Installer image (for machine config): `factory.talos.dev/installer/SCHEMATIC_ID:RELEASE`

Notes

- Replace `<release>` with a Talos version, e.g. `v1.8.2`
- Schematics are content-addressable; same content returns same ID
- Confirm extensions on a running node: `talosctl get extensions`

## Pitfalls

- Missing iscsi/util-linux tools → Longhorn volumes fail
- Wrong platform asset (e.g., arm64) won’t boot on Proxmox amd64
- If using RAW, remember to decompress before importing to Proxmox storage

## References

- Talos Image Factory: <https://www.talos.dev/latest/learn-more/image-factory/>
- Boot assets & API: <https://www.talos.dev/latest/talos-guides/install/boot-assets/>
