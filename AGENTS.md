# AGENTS.md

This guide tells autonomous coding agents how to work in this repository **safely, effectively, and independently**—from planning through merge.

---

## Mission

Build and operate a **Talos + Cluster API** platform on **Proxmox**, managed by **Argo CD** (GitOps). Start with a management cluster, then reconcile workload clusters, and evolve toward multi-cluster/cloud.

Primary goals:

- Provision a Talos **management** cluster on Proxmox via **OpenTofu** (preferred) or Terraform.
- Install **Cluster API Operator** and providers (Talos CP/Bootstrap, Proxmox infra).
- Bootstrap **Argo CD** and sync **platform add-ons** from `argo/apps/`.
- Define and reconcile **workload clusters** in `clusters/*` via Cluster API.

---

## Operating assumptions

- You **may** create new files/directories and small modules; keep changes **scoped**.
- Prefer **GitOps**: declare desired state; let controllers reconcile.
- Keep edits **surgical**: do not mass-reformat or rename unless necessary for function.
- All secrets are **SOPS-encrypted** (age). No plaintext secrets in commits.
- CI runs **kubeconform** (with `-ignore-missing-schemas`), **helm template**, and linters.

---

## Tooling & commands

Agents should use the following tools and conventions:

- **OpenTofu** (alias `tofu`) for IaC. Terraform is acceptable if already in use, but prefer `tofu`.
- **kubectl**, **helm**, **kustomize**, **talosctl**, **sops**, **age**, **yq**, **pre-commit**.
- **Argo CD** manifests live in `argo/`; **platform** add-on values/overlays in `platform/`.
- **Cluster manifests** per environment in `clusters/`.

### Standard commands

```bash
# IaC
tofu init && tofu validate && tofu plan
# or: terraform init && terraform validate && terraform plan

# Lint / schema
pre-commit run --all-files || true
helm template <chart-path> | kubeconform -ignore-missing-schemas -strict -summary

# SOPS
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
sops -e -i platform/secrets/<file>.yaml
```

---

## Required inputs (never commit plaintext)

Provide these at runtime or as SOPS-encrypted manifests:

- **Proxmox**: `PROXMOX_URL`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN_SECRET`, datastore, bridge.
- **Talos**: cluster name, VIP (if any), node sizing.
- **Argo CD**: domain (optional), admin bootstrap (if overridden).
- **ExternalDNS (optional)**: `CF_API_TOKEN` or other provider token.
- **SOPS age**: private key path in runner env (`SOPS_AGE_KEY_FILE`).

If a required value is missing, **open a draft PR** with placeholders, a `TODO(secrets)` note, and a checklist.

---

## Execution order (decision-driven)

Agents should follow this **state machine** rather than a hardcoded sequence:

1. **Proxmox foundation** (`terraform/00-proxmox-foundation`)

   - If Talos image/template or required bridge/storage are **absent**, implement/upload.
   - **Exit criteria**: image/template present; network/storage available; module idempotent.

2. **Management VMs** (`terraform/10-mgmt-talos`)

   - Create CP/worker VMs sized from variables.
   - **Talos bootstrap** (`terraform/mgmt-proxmox-talos` or inline):

     - Generate secrets/configs; **CNI = none**, **kube-proxy = disabled**.
     - Apply configs; retrieve kubeconfig as an **output**.

   - **Exit criteria**: `kubeconfig` available; `kubectl get nodes` returns Ready CP.

3. **CAPI Operator & providers** (`terraform/20-capi-operator` + `terraform/30-capmox`)

   - Install CAPI Operator (Helm).
   - Install providers: Core, **Talos (bootstrap/controlplane)**, **Proxmox infra**.
   - Apply `ProxmoxCluster` + credentials Secret (SOPS).
   - **Exit criteria**: provider deployments healthy; CRDs present.

4. **ClusterClass & templates** (`terraform/40-clusters`)

   - Add `ClusterClass`, `ProxmoxMachineTemplate`s, Talos control plane/MD templates, **MHC**.
   - **Exit criteria**: manifests applied; `kubectl get clusterclass` returns class.

5. **Argo CD** (`terraform/50-argo`)

   - Install Argo CD; apply **app-of-apps** pointing to `argo/apps/`.
   - **Sync waves** so **Cilium** rolls out **first** (wave `0`).
   - **Exit criteria**: root app **Synced/Healthy**; child apps progressing.

6. **Workload clusters** (`clusters/<env>/*.yaml`)

   - Add one `Cluster` referencing the `ClusterClass` (e.g., `prod`).
   - **Exit criteria**: CAPI machines provisioning on Proxmox; kubeconfig retrievable.

Agents may **skip** a completed step if outputs and health checks pass.

---

## Editing rules

- **YAML**

  - 2-space indent; preserve key order where practical.
  - Keep manifests **namespaced** and **scoped**; avoid global defaults that surprise other envs.

- **OpenTofu/Terraform**

  - Pin provider versions.
  - Modules must be **idempotent**; expose **useful outputs** (IPs, kubeconfig path, etc.).
  - Avoid local-exec shell unless necessary; prefer providers/resources.

- **Docs**

  - Pass markdownlint; use `1.` ordered lists; include minimal context and commands.

---

## Secrets & SOPS policy

- Commit **only** SOPS-encrypted files under `platform/secrets/` (or app-local `secrets/`).
- Use `.sops.yaml` creation rules; encrypt only `data|stringData` fields.
- For Argo decryption:

  - **Preferred**: External Secrets Operator (if present) — fetch from Vault/KMS at sync time.
  - **Fallback**: KSOPS — ensure `argocd/sops-age` secret exists (agent may create from env, never commit key).

If a secret is needed:

1. Generate YAML via `kubectl create secret ... --dry-run=client -o yaml`.
2. Place under `platform/secrets/`.
3. Run `sops -e -i <file>.yaml`.
4. Reference it from manifests.

---

## Validation & quality gates

Before opening a PR, agents must:

- `pre-commit run --all-files` (do not fail the run if hooks are missing locally).
- `helm template` any charts touched and pipe to `kubeconform -ignore-missing-schemas -strict -summary`.
- `tofu validate && tofu plan` on changed stacks (attach plan summary to PR).
- **Smoke checks**:

  - Argo Applications have `destination`, `source.repoURL`, `path`, `targetRevision`.
  - CAPI objects reference existing templates/classes.
  - Cilium app has `argocd.argoproj.io/sync-wave: "0"`.

---

## Allowed actions

Agents **may**:

- Implement missing modules in `terraform/*`.
- Create/modify Argo Applications and Helm/Kustomize overlays in `argo/apps/` and `platform/`.
- Add/modify `ClusterClass`, `ProxmoxMachineTemplate`, `TalosControlPlane`, `MachineHealthCheck`.
- Add **CI** workflows for lint/schema and IaC validation.
- Create documentation (README updates, runbooks).
- Introduce **External Secrets Operator** integration (if absent), wired but disabled by default.
- Add **Velero** and **Loki/Promtail** apps behind feature flags.

Agents **must not**:

- Commit plaintext secrets or private keys.
- Remove `kubeconform -ignore-missing-schemas` without adding CRDs.
- Mass-reformat unrelated files.
- Hardcode environment-specific values in shared overlays.

---

## Planning loop (for autonomous agents)

1. **Discover**: Read repo tree; compute delta of missing stages.
2. **Plan**: Produce a short task list with expected outputs and files to touch.
3. **Change**: Implement minimal changes; keep commits atomic.
4. **Validate**: Run lint/schema/IaC plans; adjust as needed.
5. **Document**: Update README/runbooks if behavior or usage changes.
6. **Propose**: Open PR with templated description and checklists.

---

## PR strategy

- Use **feature branches** per unit of work (e.g., `feat/capi-operator-helm`).
- One logical change per PR; avoid bundling unrelated edits.
- Include **artifacts** in PR description:

  - OpenTofu plan (trimmed).
  - `kubeconform` summary.
  - Screenshots/logs optional.

### PR description template

```markdown
## Summary

Implement <component>. Enables <outcome>.

## Changes

- Added <files>
- Updated <files>
- Created SOPS secret placeholders at <paths>

## Validation

- pre-commit: ✅
- helm|kubeconform: ✅ (ignore-missing-schemas)
- tofu validate/plan: ✅
  <optional plan snippet>

## Risks / Rollback

- Minimal: config-only. Rollback by reverting commit.

## Follow-ups

- Provide secrets for: <list>
- Configure domain: <value>
```

---

## Task library (pick & execute)

### T-01 Proxmox foundation (`terraform/00-proxmox-foundation`)

- **Create** module: provider, image upload/template, bridge/storage assertions.
- **Outputs**: template name, datastore, bridge.
- **Done when**: `tofu plan` idempotent; template exists.

### T-02 Mgmt VMs + Talos bootstrap (`terraform/10-mgmt-talos`, `terraform/mgmt-proxmox-talos`)

- **Create** VMs (3 CP by default). Expose IPs.
- **Bootstrap** Talos CP: CNI none; kube-proxy disabled.
- **Outputs**: kubeconfig path/content (sensitive), CP IPs.
- **Done when**: `kubectl get nodes` shows Ready CP; kubeconfig emitted.

### T-03 CAPI Operator & providers (`terraform/20-capi-operator`, `terraform/30-capmox`)

- **Install** operator via Helm.
- **Apply** provider CRs (Talos CP/Bootstrap, Proxmox Infra).
- **Create** `capmox-credentials` Secret (SOPS) and `ProxmoxCluster`.
- **Done when**: `kubectl get deployments -A` shows providers Ready.

### T-04 ClusterClass & MHC (`terraform/40-clusters`)

- **Add** `ClusterClass`, Talos CP template, MD templates, **MHC**.
- **Done when**: class and templates exist; `kubectl get mhc` returns objects.

### T-05 Argo CD + app-of-apps (`terraform/50-argo`)

- **Install** Argo CD; **root** app points to `argo/apps/`.
- **Ensure** Cilium app has sync wave `0`.
- **Done when**: Argo root is Synced; children in Sync/Progressing.

### T-06 Workload cluster (`clusters/prod`)

- **Create** `Cluster` referencing class; 3 CP / N workers.
- **Done when**: CAPI provisions Proxmox VMs; new kubeconfig retrievable.

### T-07 External Secrets Operator (optional prod feature)

- **Add** ESO chart/app; define `SecretStore` stubs.
- **Replace** SOPS files gradually with `ExternalSecret`s.
- **Done when**: one secret delivered by ESO, documented.

### T-08 Observability & DR (optional)

- **Add** Loki/Promtail and/or EFK; **Velero** with object storage.
- **Done when**: logs visible in Grafana; backup schedule present.

---

## Health checks & gates

Agents should evaluate these conditions before moving forward:

- **Mgmt cluster**: `kubectl get cs` (if available), `kubectl get nodes`, core DNS pods Ready.
- **CAPI**: CRDs present (`kubectl get crd | grep cluster.x-k8s.io`), controllers Ready.
- **Argo**: `argocd-server` and controllers Ready; root Application Synced.
- **Cilium**: `cilium status` (if CLI available) or DaemonSet Ready; Hubble UI optional.
- **Workload cluster**: machines progressing; CP reaches Ready; kube-api reachable.

If a gate fails, stop and open a PR with diagnostics.

---

## Sync-ordering rules (Argo)

- **Wave 0**: Cilium (CNI), CRDs needed by early apps (Gateway API if external).
- **Wave 1**: cert-manager (with CRDs enabled).
- **Wave 2**: ExternalDNS, Longhorn, monitoring stack.
- **Wave 3**: dashboards, mesh, extras.

Annotate apps:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "N"
```

---

## File/Path conventions

- **Do edit**:

  - `terraform/**`
  - `clusters/**`
  - `platform/**` (values, overlays, CRDs)
  - `argo/install/**`, `argo/apps/**`
  - `.github/workflows/**`
  - `docs/**`

- **Do not**:

  - Commit anything under `platform/secrets/**` **unencrypted**.
  - Remove `.sops.yaml` or CI schema ignores.

---

## Definition of Done (platform baseline)

- Management cluster running; kubeconfig produced as module output.
- Cluster API Operator + Talos + Proxmox providers installed and healthy.
- Argo CD installed; app-of-apps syncing; **Cilium** successful and first.
- At least one workload cluster manifest applied and reconciling.
- Lint/schema/plan checks pass in CI.
- No plaintext secrets in repo.

---

## Escalation / stop conditions

Agents must **open a draft PR** and stop on:

- Missing non-optional secrets (Proxmox/Cloud provider tokens).
- Proxmox API unreachable (foundation cannot be verified).
- Talos bootstrap fails after two attempts (attach logs).
- CAPI providers continuously crash-loop (attach events).

PR should include: logs, plan output, and a checklist of what’s needed from maintainers.

---

## Templates

### Proxmox credentials Secret (encrypt before commit)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: capmox-credentials
  namespace: capmox-system
type: Opaque
stringData:
  url: "https://proxmox.example:8006/api2/json"
  tokenID: "root@pam!capmox"
  tokenSecret: "REDACTED"
  insecure: "true"
```

### .sops.yaml (policy)

```yaml
creation_rules:
  - path_regex: platform/secrets/.*\.(ya?ml|json)$
    age:
      - age1REPLACE_WITH_PUBLIC_KEY
    encrypted_regex: "^(data|stringData)$"
```

---

This document is the **contract** for agents: act within these guardrails, prefer minimal diffs that advance the platform, validate every change, and propose mergeable PRs with clear signals, but also create documentation.
