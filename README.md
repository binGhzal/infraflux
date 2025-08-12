# infraflux

Infrastructure-as-code scaffold for Talos + Cluster API on Proxmox, managed via Argo CD.

Structure overview:

- docs/: runbooks and architecture decisions
- terraform/: foundational infra and bootstrap steps
- clusters/: CAPI Cluster manifests per environment
- platform/: cluster add-ons (Helm values, policies, CRDs)
- argo/: Argo CD installation and app-of-apps
- .github/workflows/: CI to validate YAML/Helm

Getting started:

1. Fill out terraform modules and variables per folder.
2. Bootstrap Argo CD (argo/install) and push app-of-apps (argo/apps).
3. Commit secrets using SOPS with age keys in platform/secrets.

This repo is a starter layout; adjust to your needs.
