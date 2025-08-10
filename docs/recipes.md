# Recipes

**Recipes** are composable app bundles delivered through Flux. Each bundle is a directory with:

- `kustomization.yaml`
- One or more `HelmRelease` manifests
- Optional `ConfigMap`/`Secret` overlays (SOPS encrypted if needed)

## Included bundles

- `recipes/base`: cert-manager, ExternalDNS, storage (Longhorn by default)
- `recipes/observability`: kube-prometheus-stack (Prometheus, Alertmanager, Grafana)
- `recipes/devtools`: Argo CD (optional, primarily as an example)

## Creating a new bundle

1. Create `recipes/<bundle>/kustomization.yaml`.
2. Add `HelmRelease` objects that reference catalogs from `management/flux/sources/helm`.
3. If secrets are needed, commit SOPS-encrypted resources to `sops/`.

## Enabling bundles

- Wire a `Kustomization` in `management/flux/gotk-sync-<bundle>.yaml` pointing to `./recipes/<bundle>`.
- Commit and let Flux reconcile.
