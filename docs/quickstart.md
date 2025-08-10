# Quickstart

> Goal: get a management cluster syncing this repo, then render a workload cluster and auto-install recipes.

For complete steps, see the Installation guide.

## 1) Prerequisites

Install locally (or in CI): go, kubectl, clusterctl, talosctl, flux, sops + age, yq.

## 2) Build the CLI (render-only)

```bash
git clone https://github.com/your-org/infraflux
cd infraflux
make build-cli
./bin/infraflux --help
```

## 3) Bootstrap Flux in your management cluster

```bash
flux install --export > management/flux/gotk-components.yaml
kubectl apply -k management/flux
```

## 4) Configure secrets (SOPS)

- Generate an age key; update `sops/.sops.yaml` recipients
- Create provider credential Secrets as SOPS-encrypted files

## 5) Render a workload cluster plan (Proxmox example)

```bash
./bin/infraflux up \
  --provider proxmox \
  --name lab \
  --workers 2 --cpu 4 --memory 8 \
  --k8s 1.30 \
  --recipes base,observability,devtools,media
```

Outputs are written to `out/<cluster>/`.

## 6) Next steps

Apply manifests with kubectl (human/CI), then Flux reconciles state.

See also: Installation, Recipes, Troubleshooting.
