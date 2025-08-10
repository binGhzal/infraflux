# Platform: Cluster API

This folder pins Cluster API versions and provider manifests (CAPA/CAPZ/CAPG/Proxmox/Metal3) and Talos providers.

- Add version matrix and manifests per provider.
- Management cluster templates should live here and be applied by `hack/bootstrap.sh`.

- Notes

- If `clusterctl init` fails to resolve Talos providers due to org rename, configure
  `~/.cluster-api/clusterctl.yaml` with provider URL mappings for:
  - BootstrapProvider talos → <https://github.com/siderolabs/cluster-api-bootstrap-provider-talos/releases/latest/bootstrap-components.yaml>
  - ControlPlaneProvider talos → <https://github.com/siderolabs/cluster-api-control-plane-provider-talos/releases/latest/control-plane-components.yaml>
  - InfrastructureProvider sidero (optional) → <https://github.com/siderolabs/sidero/releases/latest/infrastructure-components.yaml>
- Prefer template rotation when updating ClusterClass references. Use `clusterctl alpha topology plan` to preview impact.
