# 🚀 InfraFlux

**InfraFlux** is an **opinionated, fully-automated, multi-cloud Kubernetes platform** inspired by [ElfHosted](https://elfhosted.com) and the [Geek Cookbook Premix](https://geek-cookbook.funkypenguin.co.nz/).
It fast-tracks the deployment of complete "recipes" (curated Kubernetes app bundles) on clusters running in **AWS, Azure, GCP, or Proxmox**—all driven by declarative manifests and GitOps.

> **Goal:** One command from zero to a production-ready Kubernetes cluster with curated apps, anywhere.

---

## ✨ Key Features

- **Multi-Cloud + Proxmox support** via [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/):
  - AWS (CAPA)
  - Azure (CAPZ)
  - GCP (CAPG)
  - Proxmox (CAPMOX)
- **Immutable OS** with [Talos Linux](https://www.talos.dev/) for deterministic, API-driven node configuration.
- **Unified networking** with [Cilium](https://cilium.io/) using kube-proxy replacement for low latency and minimal overhead.
- **GitOps app delivery** via [FluxCD](https://fluxcd.io/) syncing curated "recipes."
- **Optional cloud infra management** with [Crossplane](https://crossplane.io/)—provision cloud databases, DNS, and storage from Kubernetes CRDs.
- **Batteries included**: cert-manager, ExternalDNS, Gateway API + Envoy Gateway, CSI storage.

---

## 📂 Repository Structure

```filesystem
infraflux/
├─ cli/ # Minimal Go/Python CLI for init, up, destroy
│ └─ cmd/
│
├─ management/ # Management cluster configs
│ ├─ clusterctl/ # clusterctl provider components
│ ├─ talos/ # Talos machineconfigs for mgmt cluster
│ └─ flux/ # Flux bootstrap manifests
│
├─ clusters/ # Workload cluster definitions
│ ├─ templates/ # Base CAPI + Talos YAML templates
│ ├─ aws/
│ ├─ azure/
│ ├─ gcp/
│ ├─ proxmox/
│ ├─ cilium/helmrelease.yaml # Cilium install (kube-proxy replacement)
│ └─ gateway # Gateway API + Envoy Gateway manifests
│
├─ recipes/ # App stacks delivered via Flux
│ ├─ base/ # Core infra: cert-manager, ExternalDNS, storage
│ ├─ observability/ # Monitoring/logging stack
│ ├─ media/ # Media processing stack
│ └─ devtools/ # Developer tools stack
│
├─ crossplane/ # Crossplane providers, compositions, claims
│ ├─ base/
│ └─ compositions/
│
└─ sops/ # SOPS/age key management for secrets
```

---

## 🛠️ Workflow Overview

1. **Management Cluster Init**

   - Create a small Talos management cluster (anywhere).
   - Install CAPI + desired infrastructure providers (aws, azure, gcp, proxmox).
   - Bootstrap FluxCD pointing at this repo.

2. **Workload Cluster Creation**

   - Apply CAPI manifests for desired provider from `/clusters/<provider>/`.
   - Nodes boot via Talos machineconfigs.
   - Cilium installed with kube-proxy replacement.
   - Gateway API + Envoy Gateway configured.

3. **Recipe Deployment**

   - Recipes are Flux Kustomizations/HelmReleases in `/recipes/`.
   - Commit desired recipe configs → Flux applies automatically.
   - cert-manager + ExternalDNS handle TLS/DNS automation.

4. **(Optional) Infra Resources**
   - Crossplane providers manage DBs, buckets, DNS zones declaratively.

---

## 🚧 Development Roadmap

- [ ] CLI scaffolding (`infraflux`) with `init`, `up`, and `destroy` commands.
- [ ] Management cluster Talos + CAPI bootstrapping manifests.
- [ ] Provider overlays for AWS, Azure, GCP, Proxmox.
- [ ] Cilium HelmRelease with kube-proxy replacement enabled.
- [ ] Gateway API + Envoy Gateway setup.
- [ ] Flux recipe catalog (base, observability, media, devtools).
- [ ] Crossplane base installation & common compositions.
- [ ] SOPS integration for secrets in Git.

---

## 📜 License

MIT License © 2025 InfraFlux Contributors

---

## 🙌 Acknowledgements

- [ElfHosted](https://elfhosted.com) for inspiration in simplicity and automation.
- [Geek Cookbook](https://geek-cookbook.funkypenguin.co.nz/) for the recipe concept.
- [Talos Linux](https://www.talos.dev/) for making immutable Kubernetes nodes easy.
- [Cluster API](https://cluster-api.sigs.k8s.io/) for multi-cloud lifecycle management.
- [Cilium](https://cilium.io/) for networking done right.
- [FluxCD](https://fluxcd.io/) for GitOps that just works.
