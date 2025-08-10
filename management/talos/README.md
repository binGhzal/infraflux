# Management Cluster (Talos)

This directory holds sample Talos machine and cluster configs for the management cluster.

- Generate real configs with `talosctl gen config` and store securely (or encrypt with SOPS).
- Do not commit real secrets.
- Quick bootstrap helper: `management/bootstrap.sh` (requires clusterctl, flux, kubectl).

Example:

```bash
# Point Flux at your repo
export IFX_GIT_REPO=https://github.com/you/infraflux
# Choose providers to install with CAPI (comma-separated)
export IFX_PROVIDERS=aws,azure
# Optional namespace for mgmt artifacts
export IFX_NAMESPACE=infraflux-system

management/bootstrap.sh
```
