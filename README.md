# infraflux

Infrastructure-as-code for Talos Linux + Cluster API on Proxmox, managed declaratively via Argo CD (GitOps).

## repo structure

- `docs/`
  - `bootstrap.md` – human runbook for first cluster bring-up
  - `adrs/` – architecture decisions
  - `runbooks/` – operations procedures
- `terraform/`
  - `00-proxmox-foundation/` – Proxmox projects, networks, storage (placeholder)
  - `10-mgmt-talos/` – management cluster VMs (placeholder)
  - `20-capi-operator/` – install Cluster API Operator (placeholder)
  - `30-capmox/` – Proxmox provider setup (placeholder)
  - `40-clusters/` – workload cluster automation (placeholder)
  - `50-argo/` – Argo CD installation (placeholder)
  - `mgmt-proxmox-talos/` – active module for Talos bootstrap + CAPI Operator helm release (includes `terraform.tfvars.example`)
- `clusters/`
  - `mgmt/` – provider/operator configuration for the management cluster
  - `prod/` – workload cluster manifests (to be added)
- `gitops/argocd/`
  - `bootstrap/` – Argo CD AppProject and App-of-Apps
  - `apps/` – platform add-ons (cert-manager, cilium, dashboard, external-dns, longhorn, monitoring)
  - `values/` – Argo CD chart values
- `secrets/`
  - `age/` – guidance for SOPS age keys
  - `README.md` and `proxmox-credentials.sops.example.yaml`
- repo hygiene: `.pre-commit-config.yaml`, `.kubeconform.yaml`, `.sops.yaml`, `.yamllint`, `.markdownlint.json`, `.vscode/`

## end-to-end plan

1. Proxmox foundation (terraform 00)

- Define networks, storage, and any Proxmox objects needed.

1. Management cluster VMs (terraform 10)

- Provision control-plane and worker VMs (via `proxmox_vm_qemu`).
- Output their IPs for Talos.

1. Bootstrap Talos and obtain kubeconfig (terraform mgmt-proxmox-talos)

- Use `talos_machine_secrets`, `talos_client_configuration`, and `talos_cluster_kubeconfig`.
- Verify cluster health using the generated kubeconfig.

1. Install Cluster API Operator (terraform 20)

- Install `cluster-api-operator` Helm chart.
- Apply provider manifests (e.g., `clusters/mgmt/providers/infrastructure-proxmox.yaml`).

1. Install Argo CD (terraform 50 or manifests)

- Install Argo CD using Helm with `gitops/argocd/values/argocd-values.yaml`.
- Apply bootstrap: `gitops/argocd/bootstrap/project-platform.yaml` and `app-of-apps.yaml`.

1. GitOps platform add-ons

- Argo syncs platform apps from `gitops/argocd/apps/*`.
- Replace placeholders (domains, tokens) and create needed secrets (SOPS).

1. Define workload clusters (clusters/{dev,prod})

- Add CAPI Cluster and machine templates for Proxmox.
- Commit and let Argo/CD controllers reconcile.

## prerequisites

- Proxmox access (API URL/user/password)
- OpenTofu (tofu) >= 1.6, Talosctl if testing outside Terraform
- Helm, kubectl
- SOPS + age (for secret management)
- Pre-commit

## bootstrap (quick outline)

1. Configure OpenTofu variables in `terraform/mgmt-proxmox-talos/variables.tf` (pm creds, IP addresses).
2. Apply `terraform/mgmt-proxmox-talos` with OpenTofu to bring up Talos and get kubeconfig.
3. Confirm `capi-operator` Helm release is installed.
4. Install Argo CD (either via Terraform or Helm manually) with `gitops/argocd/values/argocd-values.yaml`.
5. Apply `gitops/argocd/bootstrap/` (AppProject + App-of-Apps).
6. Set secrets (SOPS/KSOPS) and configure app values:
   - Create `sops-age` secret for Argo Repo Server
   - external-dns: Cloudflare token secret `external-dns` with `CF_API_TOKEN`
   - Update `domainFilters` and Argo CD `global.domain`

## values to customize (placeholders)

- `gitops/argocd/values/argocd-values.yaml` → `global.domain`
- `gitops/argocd/apps/external-dns/values.yaml` → `domainFilters`, Cloudflare token
- `gitops/argocd/apps/cilium` → remove `k8sServiceHost/Port` overrides unless needed

## dev tooling

- Pre-commit: yaml/markdown lint, kubeconform (skips if not installed)
- VS Code: recommended extensions added in `.vscode/extensions.json`
  - YAML (Red Hat), Kubernetes tools

## YAML schema notes

- The editor may show errors for CRDs (e.g., Cluster API) if schemas aren’t available locally.
- CI uses kubeconform with `-ignore-missing-schemas`, so it won’t block.
- Options:
  - Disable Kubernetes schema in the workspace: `"yaml.kubernetes": false`.
  - Connect to a cluster with CRDs installed so the schema provider fetches them.
  - Provide custom schema locations to kubeconform for stricter local validation.

## roadmap

- Flesh out Terraform stages 00–50 with real modules
- Argo CD install via Terraform with chart values
- Add `clusters/prod` example CAPI manifests for Proxmox (Talos)
- Secrets via SOPS with KSOPS-driven GitOps
- Add CI workflow for lint + kubeconform

## contributing

- Run `pre-commit install` and `pre-commit run --all-files` before pushing.
- Keep changes small and tested; prefer GitOps for cluster changes.

## license

MIT (or your preferred license; update as needed)
