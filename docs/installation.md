# Installation

This guide walks you from a blank machine to a management cluster syncing InfraFlux,
and rendering a workload cluster plan with curated recipes.

## Prerequisites

Install locally (or in CI):

- go >= 1.22
- kubectl >= 1.28
- clusterctl >= 1.6
- talosctl >= 1.7
- flux >= 2.2
- sops + age
- yq (optional; enables YAML verify in hooks)

Optionally enable repo git hooks:

```bash
git config core.hooksPath githooks
```

## Get the sources and build the CLI (render-only)

```bash
git clone https://github.com/your-org/infraflux
cd infraflux
make build-cli
./bin/infraflux --help
```

## Provision a management cluster

Use your preferred method to create a small management cluster (Talos recommended).
Once KUBECONFIG is set, bootstrap Flux and point it at this repo.

```bash
# Install Flux controllers into the management cluster
flux install --export > management/flux/gotk-components.yaml
kubectl apply -k management/flux
```

The management manifests will:

- Create HelmRepository sources
  (cilium, jetstack, bitnami, prometheus-community, argo, longhorn,
  envoy-gateway, grafana, ingress-nginx, hashicorp)
- Configure Git sync to this repository
- Sync default bundles: recipes/base, recipes/observability, recipes/devtools

## SOPS secrets setup

Generate an age key and configure SOPS policy. Store provider credentials as encrypted Secrets.

```bash
# generate an age keypair
age-keygen -o ~/.config/sops/age/keys.txt

# edit sops/.sops.yaml to include your recipient public key
# then create secrets (examples live in sops/)
```

Never commit plaintext secrets. Use the examples in `sops/` as a reference.

## Render a workload cluster plan

Render manifests for your target provider; output goes to `out/<cluster>/`.

```bash
./bin/infraflux up \
  --provider proxmox \
  --name lab \
  --workers 2 --cpu 4 --memory 8 \
  --k8s 1.30 \
  --recipes base,observability,devtools,media
```

This produces:

- out/lab/cluster/ — CAPI + Talos manifests
- out/lab/addons/cilium/ — Cilium HelmRelease
- out/lab/addons/gateway/ — Envoy Gateway HelmRelease
- out/lab/recipes/ — per-cluster Kustomizations pointing to recipe bundles

## Apply (outside the scope of InfraFlux agent)

InfraFlux is render-only. To proceed, a human/CI can apply the plan to the management cluster:

```bash
# example only — adjust namespaces and paths as needed
kubectl apply -f out/lab/cluster/
kubectl apply -f out/lab/addons/
kubectl apply -f out/lab/recipes/
```

Flux will take over reconciliation once the manifests are applied.

## Recipes and catalogs

- Bundles live under `recipes/` (base, observability, devtools, media)
- Per-cluster Kustomizations are generated in `out/<cluster>/recipes/*.yaml`
- Helm catalogs are defined in `management/flux/sources/helm/`

To add apps, commit new HelmReleases under a bundle and include that bundle via `--recipes`.

## Crossplane (optional)

- Providers are pinned in `crossplane/base/`
- ProviderConfigs reference SOPS-encrypted Secrets
- Compositions live in `crossplane/compositions/`

You can define claims (e.g., Postgres) and wire recipes to depend on them.

## Troubleshooting

- Verify YAML: install `yq` and run `make verify-yaml`
- Run tests: `make test`
- Render sample: `make render-sample`

See also: Troubleshooting and FAQ docs.
