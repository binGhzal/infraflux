# InfraFlux

InfraFlux is an opinionated, **push-button, multi-cloud Kubernetes platform** inspired by ElfHosted and the Geek-Cookbook’s “recipe” model.

**Core stack**

- **Cluster API (CAPI)** for cluster lifecycle across AWS, Azure, GCP, and Proxmox.
- **Talos Linux** for immutable, API-driven node OS (no SSH, less drift).
- **Cilium** as CNI with kube-proxy replacement (eBPF) for a lean dataplane.
- **FluxCD** for GitOps delivery of curated app bundles (“recipes”).
- **Crossplane** _(optional)_ to provision cloud resources via Kubernetes CRDs.

**Repo highlights**

- `/management` – management cluster bootstrap (clusterctl, Talos, Flux).
- `/clusters` – provider-agnostic templates + per-provider overlays.
- `/recipes` – Flux Kustomizations/HelmReleases for app bundles.
- `/crossplane` – providers, compositions, and claims for cloud resources.
- `/cli` – minimal Go CLI (`infraflux`) that renders plans/manifests.

> InfraFlux favors **declarative config** and **GitOps**. The CLI helps render/compose manifests; **agents code**, humans review, Git reconciles.
