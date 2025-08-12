# infraflux

**Infrastructure-as-code scaffold for Talos + Cluster API on Proxmox, managed via Argo CD.**
Homelab-first, production-ready when you are. Multi-cluster by design, cloud-expandable.

---

## Highlights

- **End-to-end GitOps**: Argo CD app-of-apps drives platform add-ons and clusters.
- **Immutable nodes**: Talos Linux for minimal, secure Kubernetes.
- **Lifecycle as code**: Cluster API manages clusters and machines (Proxmox today; clouds next).
- **Batteries included**: Cilium (CNI + Gateway API), cert-manager, ExternalDNS, Longhorn, kube-prom-stack.
- **Secrets sane**: SOPS (age) by default; External Secrets Operator optional for vault-backed flows.
- **Homelab → Prod**: Start on Proxmox, scale out to AWS/Azure/GCP with extra CAPI providers.

---

## Architecture (at a glance)

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Git Repository (infraflux)                  │
│ docs/  terraform/  clusters/  platform/  argo/  .github/workflows/  │
└───────────────┬───────────────────────────────────────────────┬──────┘
                │                                               │
        Terraform (bootstrap)                            Argo CD (GitOps)
                │                                               │
        Proxmox VMs (Talos)  ──>  Talos mgmt cluster  <─────────┘
                │                         │
                │        Cluster API + Providers (Talos CP, Proxmox)
                │                         │
                └──────────► Reconcile workload clusters on Proxmox
                                          │
                                Platform add-ons via GitOps
                               (Cilium, cert-manager, DNS, etc.)
```

---

## Repository layout

```
docs/                    Runbooks, design notes, ADRs
terraform/
  00-proxmox-foundation  Proxmox image/network/storage prep
  10-mgmt-talos          Talos mgmt cluster VMs + bootstrap
  20-capi-operator       Cluster API Operator (+ providers) install
  30-capmox              ProxmoxCluster + credentials/secrets
  40-clusters            ClusterClass + templates (+ MHC)
  50-argo                Argo CD install + app-of-apps bootstrap
clusters/                CAPI Cluster manifests per environment (dev/prod/…)
platform/                Cluster add-ons (Helm values, policies, CRDs)
  secrets/               SOPS-encrypted manifests
argo/
  install/               Argo CD install chart/values
  apps/                  App-of-apps tree (child Applications)
.github/workflows/       CI: formatting + kubeconform/helm validation
```

> Note: VS Code YAML LSP may flag Cluster API CRDs. CI ignores missing schemas. Tweak `.vscode/settings.json` if you want quiet editors.

---

## Prerequisites

- **Proxmox VE** with API token (Datastore + VM privileges), cloud-init enabled.
- **Local toolbelt**: `terraform`, `kubectl`, `helm`, `kustomize`, `talosctl`, `sops`, `age`, `yq`, `pre-commit`.
- **Domain + DNS** (optional but recommended) for ExternalDNS/ingress (e.g., Cloudflare).

---

## Quick start (homelab)

1. **Generate an age key & SOPS policy**

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

`./.sops.yaml`:

```yaml
creation_rules:
  - path_regex: platform/secrets/.*\.(ya?ml|json)$
    age:
      - age1PUBLICKEY_OF_YOUR_MACHINE
    encrypted_regex: "^(data|stringData)$"
```

2. **Fill in Terraform variables** for each stage under `terraform/**` (Proxmox URL/token, datastore, bridge, VM sizes, etc.).

3. **Bootstrap**
   Run stages in order (or wrap in a script):

```bash
pushd terraform/00-proxmox-foundation && terraform init && terraform apply -auto-approve && popd
pushd terraform/10-mgmt-talos        && terraform init && terraform apply -auto-approve && popd
pushd terraform/20-capi-operator     && terraform init && terraform apply -auto-approve && popd
pushd terraform/30-capmox            && terraform init && terraform apply -auto-approve && popd
pushd terraform/40-clusters          && terraform init && terraform apply -auto-approve && popd
pushd terraform/50-argo              && terraform init && terraform apply -auto-approve && popd
```

4. **After Argo syncs**

- `platform/*` add-ons roll out via Helm/Kustomize.
- `clusters/*` environments are reconciled by Cluster API and provisioned on Proxmox.

---

## Bootstrap sequence (details)

1. **00-proxmox-foundation**

   - Upload Talos image/template to datastore.
   - Ensure bridge (e.g., `vmbr0`), VLANs, and storage pools exist.
   - Optional: pre-create cloud-init templates.

2. **10-mgmt-talos**

   - Create mgmt VMs (control plane+workers) on Proxmox.
   - Generate Talos configs; **kube-proxy disabled, CNI none**.
   - Apply configs with `talosctl`; fetch kubeconfig for mgmt cluster.

3. **20-capi-operator**

   - Install Cluster API Operator (Helm).
   - Install providers: **Core**, **Talos (bootstrap/controlplane)**, **Proxmox (infrastructure)**.

4. **30-capmox**

   - Create `ProxmoxCluster` and credentials Secret (SOPS-encrypted).
   - Verify provider controllers are healthy.

5. **40-clusters**

   - Define a **ClusterClass** (Talos CP + Proxmox machines) and **MachineHealthChecks**.
   - Add templates for control plane/worker `ProxmoxMachineTemplate` and Talos configs.

6. **50-argo**

   - Install Argo CD (Helm).
   - Apply **app-of-apps** pointing to `argo/apps/`.

> **Important**: With kube-proxy off and CNI unset in mgmt bootstrap, ensure **Cilium** is synced **first**. Use Argo sync waves:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

---

## Secrets

### SOPS (default)

- Keep Kubernetes Secrets in `platform/secrets/` encrypted with SOPS (age).
- Example:

```bash
kubectl -n capmox-system create secret generic capmox-credentials \
  --from-literal=url='https://proxmox:8006/api2/json' \
  --from-literal=tokenID='user@pam!token' \
  --from-literal=tokenSecret='REDACTED' \
  --dry-run=client -o yaml > platform/secrets/capmox-credentials.yaml
sops -e -i platform/secrets/capmox-credentials.yaml
```

### KSOPS (optional, in-cluster decryption)

- Store age private key as secret (e.g., `argocd/sops-age`).
- Configure Argo CD to use KSOPS Kustomize plugin for decrypt-at-sync.

### External Secrets Operator (recommended for production)

- Deploy ESO via Argo; configure a SecretStore (Vault, AWS Secrets Manager, Azure Key Vault, etc.).
- Replace SOPS files with `ExternalSecret` CRs that fetch real values at runtime.

---

## Platform add-ons (suggested defaults)

- **Networking**: Cilium CNI with **Gateway API** (HTTPRoute/TLSRoute).

  - Optional: Cilium service mesh (mTLS, Hubble) as it matures.

- **Certificates**: cert-manager (Issuer/ClusterIssuer for Let’s Encrypt or internal CA).
- **DNS**: ExternalDNS (e.g., Cloudflare provider, `domainFilters` set to your zone).
- **Storage**: Longhorn for distributed PVs (set replication, backup target).
- **Monitoring**: kube-prometheus-stack (Prometheus, Alertmanager, Grafana).
- **Logging** (optional but recommended): Loki + Promtail or EFK stack.
- **Dashboards**: Kubernetes Dashboard (lock down in prod).

All of the above should live under `argo/apps/` as Argo Applications or Kustomize overlays with clear `values.yaml`.

---

## Cluster API on Proxmox (CAPMox)

- **Proxmox credentials**: Put URL/token in a namespaced Secret (`capmox-system`).
- **ProxmoxCluster**: Global defaults (datastore, bridge, cluster name).
- **ClusterClass**: Encapsulate Talos CP + Proxmox machine templates.

Example **Cluster** (workload):

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: prod
  namespace: default
spec:
  clusterNetwork:
    pods: { cidrBlocks: ["10.244.0.0/16"] }
  topology:
    class: talos-proxmox-class
    version: v1.30.0
    controlPlane:
      replicas: 3
    workers:
      machineDeployments:
        - class: md-tal
          name: md-0
          replicas: 3
```

---

## Multi-cluster & clouds

- Register more clusters by committing `clusters/<env>/cluster.yaml` manifests.
- To expand beyond Proxmox:

  - Install additional CAPI providers (e.g., **CAPA** for AWS, **CAPZ** for Azure).
  - Create provider credentials as Kubernetes Secrets.
  - Add Cluster manifests targeting cloud providers (Talos works on clouds too).

Deployment patterns:

- **Single Argo (mgmt)** pushes apps to many clusters (add cluster secrets to Argo).
- Or **Argo per cluster** bootstrapped by mgmt (stronger isolation).

---

## CI & developer workflow

- **Pre-commit** (recommended locally)

  ```bash
  pipx install pre-commit
  pre-commit install
  pre-commit run --all-files
  ```

- **CI** (`.github/workflows/`)

  - Helm template + **kubeconform** (`-ignore-missing-schemas`) on all YAML.
  - Terraform fmt/validate/plan (non-destructive) on PRs.
  - Optional: `conftest`/`kube-linter` for policy checks.

> CI should **not** need to decrypt secrets. Avoid rendering templates that require plaintext at CI time.

---

## Operations & hardening checklist

- **RBAC**: Least-privilege roles for Argo, CI, humans.
- **NetworkPolicy**: Enforce namespace isolation (Cilium).
- **Policy engine**: Gatekeeper or Kyverno for admission controls.
- **Backups**: Velero (S3/MinIO); Longhorn backups to object storage.
- **HA**: 3 control-plane nodes for mgmt/prod; test MachineHealthChecks.
- **Upgrades**: Plan Talos & Kubernetes upgrades (rolling via Cluster API).
- **Audit**: Enable Talos/K8s audit logs; centralize in Loki/ELK.
- **Cost** (cloud): OpenCost/Kubecost for showback/chargeback.

---

## Troubleshooting

- **No workloads schedule / DNS flaky**
  Ensure Cilium installed and healthy before other add-ons when kube-proxy is disabled. Use Argo **sync waves** to pin Cilium first.

- **Talos unreachable**
  Confirm Proxmox firewall allows Talos API and node IPs; verify NTP (clock skew breaks TLS).

- **ExternalDNS doesn’t create records**
  Validate provider token scopes and `domainFilters`. Check controller logs.

- **Certs not issuing**
  Confirm Issuer/ClusterIssuer and HTTP-01/ALPN reachability via Gateway.

- **Machines not provisioning**
  Check CAPMox/controller logs; verify Proxmox token roles include VM.\* and Datastore.\*.

---

## Roadmap

- [ ] Finish Terraform stages `00…50` with real modules and variables.
- [ ] Argo app-of-apps tree for all platform add-ons (sync waves set).
- [ ] External Secrets Operator integration & migration plan off SOPS (optional).
- [ ] Logging stack (Loki/EFK) with retention and dashboarding.
- [ ] Service mesh selection (Cilium Mesh, Linkerd, or Istio) with mTLS and traffic policies.
- [ ] Multi-cluster app deployment patterns (central Argo vs per-cluster Argo).
- [ ] Cloud expansion: install CAPA/CAPZ/CAPG and ship a reference cloud cluster.
- [ ] DR: Velero + periodic restore drills; Longhorn backups configured.
- [ ] Security: Gatekeeper/Kyverno baseline policies; image scanning (Trivy Operator).
- [ ] Developer UX: templates/scaffolding for app repos, sample pipelines.

---

## Licensing & contributions

- Pick a license (e.g., Apache-2.0/MIT) and add `LICENSE`.
- PRs welcome: follow conventional commits; ensure pre-commit/CI pass.
- Add ADRs in `docs/adrs/` when making architectural decisions.

---

## contributing

- Run `pre-commit install` and `pre-commit run --all-files` before pushing.
- Keep changes small and tested; prefer GitOps for cluster changes.

## license

MIT (or your preferred license; update as needed)
