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

Dev hooks:

- Install pre-commit then enable hooks for this repo:
  - pipx install pre-commit
  - pre-commit install
- Optional: run on all files once: pre-commit run --all-files
- Notes: kubeconform/helm hooks skip if tools aren’t installed locally. CI still validates.

Editor note:

- VS Code YAML LSP may flag CAPI CRDs (Cluster API) with schema warnings. CI ignores missing schemas. You can keep validation on, or adjust .vscode/settings.json schema mappings per your preference.

Troubleshooting YAML schemas:

- If you see errors like "Unable to load schema kubernetes:/schemas/cluster.x-k8s.io/v1beta1/Cluster", install the recommended VS Code extensions and keep `yaml.schemaStore.enable` true. These CRDs are not part of the built-in Kubernetes schema. Options:
  - Ignore in editor: set `yaml.validate` to false for workspace, or rely on pre-commit/CI kubeconform which already uses `-ignore-missing-schemas`.
  - Provide CRD schemas: use kubeconform with an extra `-schema-location` for CAPI/other CRDs when you validate locally.

This repo is a starter layout; adjust to your needs.
