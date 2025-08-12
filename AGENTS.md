# AGENTS guide

This document instructs automation agents how to work in this repo safely and effectively.

## goals

- Provision a Talos management cluster on Proxmox via Terraform
- Install Cluster API Operator and Proxmox provider
- Bootstrap Argo CD and GitOps-managed platform add-ons
- Define workload clusters via Cluster API (Talos + Proxmox)

## conventions

- Keep edits minimal and targeted; do not reformat unrelated code
- Never commit live secrets; use SOPS with age and commit only encrypted files
- Respect repo tools: yamllint, markdownlint, kubeconform
- Prefer GitOps (declare desired state, let controllers reconcile)

## execution order

1. Proxmox foundation (terraform/00-proxmox-foundation) – implement as needed
2. Management VMs (terraform/10-mgmt-talos) – implement VM resources
3. Talos bootstrap (terraform/mgmt-proxmox-talos) – ensure kubeconfig is produced
4. CAPI Operator (terraform/20-capi-operator) – install chart
5. Proxmox Provider – apply `clusters/mgmt/providers/infrastructure-proxmox.yaml`
6. Argo CD install (terraform/50-argo or helm) – apply bootstrap manifests
7. Platform apps – verify Argo CD syncs from `gitops/argocd/apps`
8. Workload clusters – add manifests under `clusters/prod` and reconcile

## editing rules

- YAML: keep consistent indentation (2 spaces), preserve existing keys order when possible
- Terraform: pin provider versions, keep modules idempotent, output useful values
- Docs: pass markdownlint; use `1.` style ordered lists

## secrets and SOPS

- Place plaintext secrets in a temp location only; never commit
- Use `sops` to encrypt and commit under `secrets/` or app folders
- Ensure Argo CD KSOPS can decrypt via `sops-age` secret in the `argocd` namespace

## validation & quality gates

- Lint: yamllint, markdownlint should pass
- Schema: kubeconform with `-ignore-missing-schemas` should pass
- Build: Terraform `init/plan` should succeed in changed modules
- Smoke test: validate Argo CD Application manifests render minimal required fields

## CRD schemas in editor

- Editor warnings for CAPI CRDs are acceptable; do not block on them
- If needed, disable Kubernetes schema in workspace (`yaml.kubernetes: false`)

## do-not-do

- Do not remove kubeconform `-ignore-missing-schemas` without adding CRD schemas
- Do not hardcode environment-specific secrets in values files
- Do not rewrite large files for small changes

## small helpful tasks

- Replace placeholders: domain names, external-dns domainFilters, tokens (encrypted)
- Remove Cilium `k8sServiceHost/Port` overrides unless strictly required
- Add CI workflow for lint + kubeconform if missing

## completion criteria

- Management cluster up, kubeconfig available
- CAPI Operator + Proxmox provider installed
- Argo CD installed and app-of-apps syncing add-ons
- At least one workload cluster manifest present and applied via GitOps
