# infraflux

Infrastructure-as-code scaffold for Talos + Cluster API on Proxmox, managed via Argo CD. Homelab-first, production-ready when you are. Multi-cluster by design, cloud-expandable.

---

## Highlights

- End-to-end GitOps with Argo CD app-of-apps.
- Immutable nodes via Talos Linux.
- Lifecycle as code using Cluster API (Proxmox today; clouds next).
- Batteries included: Cilium, cert-manager, ExternalDNS, Longhorn, kube-prometheus-stack.
- Secrets sane: SOPS (age) by default; ESO optional for vault-backed flows.

---

## Architecture (at a glance)

```text
┌──────────────────────────────────────────────────────────────────────┐
│                          Git Repository (infraflux)                  │
│ docs/  terraform/  clusters/  gitops/  .github/workflows/           │
└───────────────┬───────────────────────────────────────────────┬──────┘
                │                                               │
        OpenTofu (bootstrap)                             Argo CD (GitOps)
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

```text
docs/                    Runbooks, design notes, ADRs
terraform/
  00-proxmox-foundation  Proxmox image/network/storage prep
  10-mgmt-talos          Talos mgmt cluster VMs + bootstrap
  20-capi-operator       Cluster API Operator (+ providers) install
  30-capmox              ProxmoxCluster + credentials/secrets
  40-clusters            ClusterClass + templates (+ MHC)
  50-argo                Argo CD install + app-of-apps bootstrap
clusters/                CAPI Cluster manifests per environment
gitops/argocd/           Argo CD app-of-apps and applications
.github/workflows/       CI: lint + validate (OpenTofu, yamllint, kubeconform)
```

> VS Code YAML LSP may flag Cluster API CRDs. CI ignores missing schemas.

---

## Prerequisites

- Proxmox VE with API token (Datastore + VM privileges), cloud-init enabled.
- Local toolbelt: `tofu`, `kubectl`, `helm`, `kustomize`, `talosctl`, `sops`, `age`, `yq`, `pre-commit`.
- Domain + DNS (optional) for ExternalDNS/ingress (e.g., Cloudflare).

---

## Quick start (homelab)

1. Generate an age key and SOPS policy

   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   ```

   Add to `./.sops.yaml`:

   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.(ya?ml|json)$
       age:
         - age1PUBLICKEY_OF_YOUR_MACHINE
       encrypted_regex: "^(data|stringData)$"
   ```

1. Fill in OpenTofu variables for each stage under `terraform/**` (Proxmox URL/token, datastore, bridge, VM sizes, etc.).

1. Bootstrap (run stages in order):

   ```bash
   pushd terraform/00-proxmox-foundation && tofu init && tofu validate && tofu apply -auto-approve && popd
   pushd terraform/10-mgmt-talos        && tofu init && tofu validate && tofu apply -auto-approve && popd
   pushd terraform/20-capi-operator     && tofu init && tofu validate && tofu apply -auto-approve && popd
   pushd terraform/30-capmox            && tofu init && tofu validate && tofu apply -auto-approve && popd
   pushd terraform/40-clusters          && tofu init && tofu validate && tofu apply -auto-approve && popd
   pushd terraform/50-argo              && tofu init && tofu validate && tofu apply -auto-approve && popd
   ```

1. After Argo syncs

   - `gitops/argocd/apps/*` add-ons roll out via Helm/Kustomize.
   - `clusters/*` environments are reconciled by Cluster API and provisioned on Proxmox.

---

## Bootstrap sequence (details)

1. 00-proxmox-foundation

   - Upload Talos image/template to datastore.
   - Ensure bridge (e.g., `vmbr0`), VLANs, and storage pools exist.

1. 10-mgmt-talos

   - Create mgmt VMs (control plane+workers) on Proxmox.
   - Generate Talos configs; kube-proxy disabled, CNI none.
   - Apply configs with `talosctl`; fetch kubeconfig for mgmt cluster.

1. 20-capi-operator

   - Install Cluster API Operator (Helm or kustomize).
   - Install providers: Core, Talos (bootstrap/controlplane), Proxmox (infrastructure).

1. 30-capmox

   - Create `ProxmoxCluster` and credentials Secret (SOPS-encrypted).
   - Verify provider controllers are healthy.

1. 40-clusters

   - Define a ClusterClass and MachineHealthChecks.
   - Add templates for control plane/worker `ProxmoxMachineTemplate` and Talos configs.

1. 50-argo
   - Install Argo CD (Helm).
   - Apply app-of-apps pointing to `gitops/argocd/apps/`.

> With kube-proxy off and CNI unset in mgmt bootstrap, ensure Cilium is synced first. Use Argo sync waves:
>
> ```yaml
> metadata:
>   annotations:
>     argocd.argoproj.io/sync-wave: "0"
> ```

---

## Secrets

### SOPS (default)

- Keep Kubernetes Secrets in `secrets/` encrypted with SOPS (age).
- Example:

  ```bash
  kubectl -n capmox-system create secret generic capmox-credentials \
    --from-literal=url='https://proxmox:8006/api2/json' \
    --from-literal=tokenID='user@pam!token' \
    --from-literal=tokenSecret='REDACTED' \
    --dry-run=client -o yaml > secrets/capmox-credentials.sops.yaml
  sops -e -i secrets/capmox-credentials.sops.yaml
  ```

### KSOPS (optional)

- Store age private key as secret (e.g., `argocd/sops-age`).
- Configure Argo CD to use KSOPS Kustomize plugin for decrypt-at-sync.

### External Secrets Operator (recommended for production)

- Deploy ESO via Argo; configure a SecretStore (Vault, AWS Secrets Manager, Azure Key Vault, etc.).
- Replace SOPS files with `ExternalSecret` CRs that fetch real values at runtime.

---

## Platform add-ons (suggested defaults)

- Networking: Cilium CNI with Gateway API (HTTPRoute/TLSRoute).
- Certificates: cert-manager (Issuer/ClusterIssuer for Let’s Encrypt or internal CA).
- DNS: ExternalDNS (e.g., Cloudflare provider; set `domainFilters`).
- Storage: Longhorn for distributed PVs (replicas, backup target).
- Monitoring: kube-prometheus-stack (Prometheus, Alertmanager, Grafana).
- Logging (optional): Loki + Promtail or EFK stack.
- Dashboards: Kubernetes Dashboard (lock down in prod).

All of the above live under `gitops/argocd/apps/` as Argo Applications.

---

## Cluster API on Proxmox (CAPMox)

- Proxmox credentials: Put URL/token in a namespaced Secret (`capmox-system`).
- ProxmoxCluster: Global defaults (datastore, bridge, cluster name).
- ClusterClass: Encapsulate Talos CP + Proxmox machine templates.

Example Cluster (workload):

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

## CI & developer workflow

- Pre-commit (recommended locally)

  ```bash
  pipx install pre-commit
  pre-commit install
  pre-commit run --all-files
  ```

- CI (`.github/workflows/`)
  - Markdownlint, yamllint, kubeconform on YAML.
  - OpenTofu fmt/validate across `terraform/**`.
  - Optional: conftest/kube-linter for policies.

> CI should not need to decrypt secrets.

---

## Operations & hardening checklist

- RBAC: Least-privilege roles for Argo, CI, humans.
- NetworkPolicy: Enforce namespace isolation (Cilium).
- Policy engine: Gatekeeper or Kyverno for admission controls.
- Backups: Velero (S3/MinIO); Longhorn backups to object storage.
- HA: 3 control-plane nodes for mgmt/prod; test MachineHealthChecks.
- Upgrades: Plan Talos & Kubernetes upgrades (rolling via Cluster API).
- Audit: Enable Talos & K8s audit logs; centralize in Loki/ELK.
- Cost (cloud): OpenCost/Kubecost for showback/chargeback.

---

## Roadmap

- [ ] Finish OpenTofu stages `00…50` with real modules and variables.
- [ ] Argo app-of-apps tree for all platform add-ons (sync waves set).
- [ ] External Secrets Operator integration & migration off SOPS (optional).
- [ ] Logging stack (Loki/EFK) with retention and dashboarding.
- [ ] Service mesh selection (Cilium Mesh, Linkerd, or Istio) with mTLS and traffic policies.
- [ ] Multi-cluster app deployment patterns (central Argo vs per-cluster Argo).
- [ ] Cloud expansion: install CAPA/CAPZ/CAPG and ship a reference cloud cluster.
- [ ] DR: Velero + periodic restore drills; Longhorn backups configured.
- [ ] Security: Gatekeeper/Kyverno baseline policies; image scanning (Trivy Operator).
- [ ] Developer UX: templates/scaffolding for app repos, sample pipelines.

---

## Contributing

- Run `pre-commit install` and `pre-commit run --all-files` before pushing.
- Keep changes small and tested; prefer GitOps for cluster changes.

## License

MIT (or your preferred license; update as needed)
