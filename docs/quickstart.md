# Quickstart

> Goal: get a **management cluster** syncing this repo, then stand up a **workload cluster** and auto-install recipes — with zero manual YAML editing beyond credentials.

## 1) Prerequisites

Install the following locally (or in your build runner):

- `go` ≥ 1.22
- `kubectl` ≥ 1.28
- `clusterctl` ≥ 1.6
- `talosctl` ≥ v1.7
- `flux` ≥ 2.2
- `sops` + `age`
- `yq` (for YAML checks)

## 2) Clone and build the CLI (render-only)

```bash
git clone https://github.com/your-org/infraflux
cd infraflux
make build-cli
./bin/infraflux --help
```

## 3) Bootstrap Flux in your management cluster

You can bring up a tiny Talos cluster for management anywhere you like. Once you have KUBECONFIG set:
flux install --export > management/flux/gotk-components.yaml
kubectl apply -k management/flux
Flux will:
Add Helm catalogs (Cilium, Jetstack, Bitnami, Prometheus, Argo, Longhorn, Envoy, Grafana, Ingress-NGINX, HashiCorp).
Create Git source to this repo.
Sync recipes/base (cert-manager, ExternalDNS, storage).

## 4) Configure secrets

Generate an age key and set up sops/.sops.yaml recipients.
Store provider credentials (AWS, Azure, GCP, Proxmox) as SOPS-encrypted Secret manifests under sops/ (or your preferred layout).
Never commit plaintext secrets.

## 5) Render a workload cluster plan (example: Proxmox)

./bin/infraflux up \
 --provider proxmox \
 --name lab \
 --workers 2 --cpu 4 --memory 8 \
 --k8s 1.30
This currently renders the manifests/plan and prints next steps (the agent will implement output to ./out/<cluster>).

## 6) Recipes

By default, management/flux/gotk-sync\*.yaml syncs:
recipes/base
recipes/observability
recipes/devtools
Adjust paths, namespaces, and add your own bundles in /recipes.
When ready, wire a pipeline step (or an operator) to apply rendered manifests to the management cluster. InfraFlux itself keeps the agent scoped to code generation — not live changes.

---

## `docs/architecture.md`

```markdown
# Architecture

+-------------------+ Git (this repo) +-------------------+
| Developer/Agent | --------------------------------> Flux Controllers |
+-------------------+ | (mgmt cluster) |
+-------+----------+
|
| Kustomizations / HelmReleases
v
+-------+----------+
| Workload |
| Clusters |
| (CAPI + Talos + |
| Cilium + Apps) |
+------------------+

**Layers**

- **Management**: Runs Flux, Cluster API core + providers (CAPA/CAPZ/CAPG/CAPMOX), and optional Crossplane.
- **Workload**: Created via CAPI, nodes run **Talos**; **Cilium** provides networking; **Flux** delivers recipes.

**Why this design**

- **Portability**: CAPI abstracts away cloud/proxmox specifics.
- **Determinism**: Talos eliminates OS drift.
- **Simplicity**: Cilium with kube-proxy replacement reduces moving parts.
- **GitOps**: Flux reconciles application/infrastructure state from Git.
```
