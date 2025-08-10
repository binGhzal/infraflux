# InfraFlux — Turnkey Multi‑Cloud Kubernetes with GitOps & Cilium

<!-- markdownlint-disable MD013 -->

> full architecture, design trade‑offs, defaults, ops runbooks, and a detailed roadmap.
> Cilium Gateway API + Cilium Ingress are the defaults. All Cilium capabilities are enabled by default and
> controllable via ClusterClass variables.

---

## 0) Principles

- **Clone → Run → Everything:** no pre‑existing cluster; bootstrap is one command using upstream tools only (`kind`, `clusterctl`, `flux`, `talosctl`, `kubectl`).
- **Single declarative model:** Cluster lifecycle, add‑ons, and apps are all YAML in Git, reconciled continuously.
- **Talos everywhere:** immutable, API‑managed nodes (no SSH) for deterministic behavior and upgrades.
- **Cilium everywhere:** eBPF dataplane, L4 LB, Gateway/Ingress, policy/observability. Alternatives exist but are disabled.
- **Secure by default:** least‑privilege RBAC, NetworkPolicies, policy‑as‑code, secrets hygiene, runtime security.
- **Modular by design:** ClusterClass variables select modules/overlays; swaps don’t require rewiring.

---

## 1) Project Goals

- **Zero‑touch bootstrap:** one script provisions the management cluster, moves CAPI, installs Flux, and creates workload clusters.
- **One abstraction across environments:** CAPI providers for AWS/Azure/GCP/Proxmox/Metal3.
- **Git‑native ops:** Git is the source of truth for clusters, add‑ons, and apps.
- **Operational clarity:** explicit dependencies and health checks prevent chicken/egg problems.
- **Security & compliance:** auditable change history, policy guardrails, runtime detection, encrypted transport and secrets.

**Advantages**: repeatability, cloud portability, strong defaults, minimal snowflakes.
**Weaknesses**: requires Git hygiene/version pinning; initial learning curve for Talos and Cilium features.

---

## 2) Architecture Overview

### 2.1 Bootstrap Flow (Zero‑to‑Clusters)

1. **Ephemeral bootstrap cluster (local):**

   - Create a short‑lived `kind` cluster.
   - Run `clusterctl init` to install CAPI core + infra providers (AWS/Azure/GCP/Proxmox/Metal3) **and** Talos bootstrap/control‑plane providers.

2. **Provision real management cluster (Talos):**

   - Apply Cluster API manifests for a Talos‑based management cluster on the target provider.
   - Nodes boot from Talos images; control plane is managed via the Talos APIs.

3. **Relocate management (`clusterctl move`):**

   - Move all CAPI objects from the ephemeral cluster to the new Talos management cluster; delete the `kind` cluster.

4. **Install Flux (`flux bootstrap`):**

   - Flux controllers are installed and pointed at this repo to reconcile everything from Git.

5. **Create workload clusters:**

   - Defined via **ClusterClass + ClusterTopology** under `clusters/`.
   - Flux applies add‑ons and app recipes automatically using the GitOps workload‑bootstrap pattern.

**Pros:** all steps are upstream‑documented; idempotent; everything recorded in Git.
**Cons:** requires Docker and CLIs locally; air‑gapped setups need image/helm registries mirrored.

### 2.2 Workload Cluster Baseline

- **OS:** Talos Linux (immutable, API‑driven, SSH‑less).
- **Networking:** Cilium with kube‑proxy replacement for performance and simplicity.
- **Edge/Routing:** **Cilium Gateway API** and **Cilium Ingress** (defaults) for L4/L7 path.
- **GitOps:** Flux manages controllers, add‑ons, and apps; dependencies are explicit with `dependsOn` and health checks.

**Trade‑offs:** Talos’s API model replaces SSH workflows; Cilium’s rich features increase responsibility for kernel/host prerequisites.

---

## 3) Repository Structure

```text
.
├── hack/
│   ├── bootstrap.sh           # one‑shot: kind → CAPI → Talos mgmt → move → flux bootstrap
│   └── destroy.sh             # optional teardown; removes clusters via CAPI then kills bootstrap
├── clusters/
│   ├── clusterclasses/        # ClusterClass (prod/dev/edge) + JSON6902 patches + vars
│   └── <env>/                 # ClusterTopology per env/tenant (refs a ClusterClass)
├── modules/
│   ├── networking/cilium/     # HelmRelease + overlays for all Cilium capabilities
│   ├── ingress/               # Alt modules (Envoy Gateway, Ingress‑NGINX, Traefik) — disabled by default
│   └── storage/               # Cloud CSI classes; Rook‑Ceph for Proxmox/bare‑metal
├── platform/
│   ├── capi/                  # CAPI core + infra providers + Talos providers (versions pinned)
│   ├── flux/                  # Flux bootstrap manifests (owned by `flux bootstrap`)
│   ├── addons/                # cert‑manager, ExternalDNS, Sealed Secrets, ESO, Velero, observability
│   └── security/              # RBAC, NetworkPolicies, Gatekeeper/Kyverno, Tetragon/Falco baselines
├── apps/
│   └── <app‑recipes>/         # 5‑file pattern: namespace, repo, kustomization, values, helmrelease
├── infra/
│   ├── compositions/          # Crossplane Compositions (optional) for DB/bucket/DNS
│   └── claims/                # Crossplane Claims used by app recipes
└── docs/
    ├── roadmap.md             # exported from this README’s Roadmap section
    └── security.md            # deeper dives and runbooks
```

### Pros

clear boundaries, ownership, and CODEOWNERS; easy multi‑tenant layering.

### Cons

more files; requires discipline in `dependsOn` and naming.

---

## 4) Cilium: All Features Enabled by Default (Configurable)

Cilium is both the CNI and the L4/L7 edge by default. Every capability is enabled; you can turn any off via ClusterClass variables.

### 4.1 Cilium Features, Rationale, Strengths & Weaknesses

| Capability                            | Rationale                              | Advantages                                          | Weaknesses / Caveats                          |
| ------------------------------------- | -------------------------------------- | --------------------------------------------------- | --------------------------------------------- |
| **High‑Performance CNI**              | eBPF dataplane for Pod/Service routing | Lower latency/CPU; fewer hops; simplifies stack     | Needs modern kernels/capabilities (eBPF/XDP)  |
| **Kube‑proxy Replacement**            | Remove iptables/ipvs                   | Maglev consistent hashing; less drift               | Some tooling expects kube‑proxy semantics     |
| **Layer‑4 Load Balancer**             | Native L4 LB incl. DSR/XDP             | Great for bare‑metal; fewer components              | XDP driven features depend on NIC/driver      |
| **Gateway API**                       | Modern routing model                   | Portable, policy‑aware; aligns with future K8s edge | Evolving spec; test advanced cases            |
| **Ingress**                           | Simple app on‑ramp                     | No extra controller to operate                      | Prefer Gateway long‑term to avoid duplication |
| **Cluster Mesh**                      | Multi‑cluster services/identity        | Global services; shared identity                    | Secret/CA exchange; more moving parts         |
| **Bandwidth/Latency**                 | EDT/BBR queueing                       | Smoother latency under load                         | Host/NIC feature‑gated; lab validation        |
| **BGP Control Plane**                 | Route advertisement                    | Works great with Proxmox/bare‑metal                 | Coordinate with network team to avoid leaks   |
| **Egress Gateway**                    | Stable egress IPs                      | Policy routing per namespace/app                    | Egress nodes become critical path; size them  |
| **Multicast**                         | Niche L2 broadcast                     | Supports specific workloads                         | Kernel/network maturity varies                |
| **Host Firewall**                     | Node‑level identity policies           | Contain node surface; Talos synergy                 | Careful policy authoring; staged rollouts     |
| **Service Map (Hubble UI)**           | Visual topology                        | Faster troubleshooting; dependency clarity          | Extra components; lock down RBAC/edge         |
| **Metrics & Tracing Export**          | Prom/OTel                              | Strong SRE visibility                               | Storage/CPU cost; set retention budgets       |
| **Identity‑aware L3/L4/DNS Logs**     | Auditable flows                        | DNS egress control; incident response               | Consider sampling; can be chatty              |
| **Advanced Protocol Visibility (L7)** | Policy & observability                 | HTTP/gRPC/Kafka parsing                             | CPU overhead; scope to key namespaces         |
| **Transparent Encryption**            | WG/IPsec on the wire                   | Defense‑in‑depth; compliance                        | Throughput hit; key management rotation       |
| **Runtime Security (Tetragon)**       | eBPF runtime observability             | Detect/block suspicious syscalls                    | Policy learning curve; tune to avoid noise    |
| **Advanced Network Policy**           | Go beyond K8s NetworkPolicy            | L7/DNS/FQDN/identity selectors                      | Complexity; add CI policy tests               |

### 4.2 ClusterClass Variables (defaults)

```yaml
spec:
  variables:
    - name: cilium
      value:
        kubeProxyReplacement: "strict"
        l4lb: true
        gatewayAPI: true
        ingress: true
        clustermesh: true
        bandwidthManager: true
        bgp: true
        egressGateway: true
        multicast: true
        hostFirewall: true
        serviceMap: true
        flowLogs: true
        metricsTracing: true
        l7Visibility:
          enabled: true
          protocols: ["http", "grpc", "kafka", "dns"]
        wireguard: true
        tetragon: true
        advancedPolicy: true
```

**Scoping guidance:** enable L7 parsing and Hubble UI selectively in prod; keep cluster‑wide flow logs with sampling; encrypt inter‑node traffic where required by policy.

---

## 5) Core Platform Capabilities (Add‑ons)

All delivered as Flux‑managed Helm/Kustomize modules. Alternatives exist, but defaults are chosen for simplicity.

### 5.1 Load Balancer

- **Default:** Cilium L4 LB (Maglev, optional DSR/XDP).
- **Alternative (bare‑metal):** MetalLB (ARP/BGP/FRR). Keep disabled unless you need its specific model.
- **Ops notes:** On Proxmox/bare‑metal, pair L4 LB with BGP to advertise LB IPs to your routers.

### 5.2 Secrets Management

- **Sealed Secrets:** encrypt bootstrap secrets in Git; only the in‑cluster controller can decrypt.
- **External Secrets Operator (ESO):** sync runtime secrets from Vault / AWS Secrets Manager / Azure Key Vault / GCP Secret Manager.
- **When to use which:**

  - Bootstrap credentials & first‑run tokens → **Sealed Secrets**
  - Application/runtime secrets with rotation → **ESO**

### 5.3 ExternalDNS

- Reconciles DNS records from `HTTPRoute`/`Gateway`/`Ingress` and `Service` resources to Route53 / Cloud DNS / Azure DNS.
- **Multi‑tenant:** label filters and separate credentials per zone.

### 5.4 SSL Certificates

- **cert‑manager** for ACME (Let’s Encrypt) or internal CA issuance.
- Works with **Gateway API** and **Ingress**; supports `HTTP‑01` and `DNS‑01`.
- **Best practice:** wildcard or per‑service certs depending on tenancy.

### 5.5 Ingress / Gateway

- **Default:** Cilium Gateway API + Cilium Ingress.
- **Alternatives:** Envoy Gateway, Ingress‑NGINX, Traefik; keep disabled unless you require controller‑specific features.

### 5.6 Persistence (Storage)

- **Cloud:** native CSI drivers (EBS, PD, Azure Disk/File) + `VolumeSnapshotClass`.
- **Proxmox/Bare‑metal:** **Rook‑Ceph** for RBD/CephFS. Alternatives: Longhorn, TopoLVM, Local Path, SMB CSI, NFS Subdir.
- **Ops notes:** plan capacity/placement; define default and gold storage classes; enable snapshots for Velero.

### 5.7 OIDC Authentication

- **Cluster API auth:** **Pinniped** (Supervisor + Concierge) integrates Azure AD, Google, Okta, etc. Dex available as lightweight IdP.
- **App SSO:** `oauth2‑proxy` in front of Gateway/Ingress for apps lacking native OIDC.

### 5.8 Backup & DR

- **Velero** to back up API objects and PVCs (CSI snapshots, or restic/kopia when CSI isn’t available).
- **Schedules & retention:** per‑env defaults; DR runbooks cover restore to new clusters/regions.

### 5.9 Observability (recommended bundle)

- **Metrics:** Prometheus Operator + kube‑state‑metrics; Cilium metrics scraped; custom dashboards.
- **Logs:** Loki (or Elasticsearch) + promtail/Vector.
- **Tracing:** OpenTelemetry Collector exporting to Jaeger/Tempo/Cloud traces; Cilium L7 tracing wires into OTel.
- **Alerting:** Alertmanager with route templates per team/tenant.

### 5.10 Policy as Code & Runtime Security

- **OPA Gatekeeper or Kyverno** baseline policies (no `:latest`, allowed registries, mandatory labels/owners, deny privileged/hostPath, require TLS, mandatory NetworkPolicies).
- **Runtime:** **Tetragon** enabled (default) for eBPF tracing/enforcement; **Falco** optional.

---

## 6) Flux App Delivery — 5‑File Pattern per App

**Why:** multi‑namespace copies, explicit dependency ordering, and one object per file for clarity.

### Files per app instance

- Namespace (`namespace-<app>.yaml`) under `bootstrap/namespaces/`
- HelmRepository (`helmrepository-<name>.yaml`) under `bootstrap/helmrepositories/`
- Kustomization (`kustomization-<app>.yaml`) under `bootstrap/kustomizations/`
- Values ConfigMap (`configmap-<app>-values.yaml`) under `apps/<app>/`
- HelmRelease (`helmrelease-<app>.yaml`) under `apps/<app>/`

### Kustomization example

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 5m
  path: ./apps/podinfo
  prune: true
  wait: true
  targetNamespace: podinfo
  dependsOn:
    - name: bootstrap-namespaces
    - name: bootstrap-helmrepositories
  healthChecks:
    - apiVersion: helm.toolkit.fluxcd.io/v2
      kind: HelmRelease
      name: podinfo
      namespace: podinfo
```

### HelmRelease example

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: podinfo
spec:
  interval: 5m
  chart:
    spec:
      chart: podinfo
      version: "6.*"
      sourceRef:
        kind: HelmRepository
        name: podinfo
        namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: podinfo-values
      valuesKey: values.yaml
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
```

### Tips

keep values in ConfigMaps/Secrets (referenced via `valuesFrom`), install CRD owners first, keep repositories in `flux-system` for shared caching.

---

## 7) Security Stack

- **Immutable OS:** Talos (no SSH, API‑managed upgrades).
- **RBAC & multi‑tenancy:** Flux impersonation; per‑namespace SAs; namespace isolation with NetworkPolicies.
- **Policy as Code:** Gatekeeper/Kyverno baselines; CI checks enforce policies pre‑merge.
- **Secrets:** Sealed Secrets for bootstrap; ESO with cloud KMS/Vault for runtime rotation.
- **Transport:** Cilium WireGuard/IPsec for on‑wire encryption (enabled by default).
- **Runtime:** Tetragon + optional Falco; tuned rules and alert routes.
- **Auditability:** Git history + Hubble flow logs + Kubernetes audit logs.

**Risks & mitigations:** policy lockouts (use break‑glass namespaces), noisy runtime alerts (iterate allowlists), secrets sprawl (centralize via ESO backends).

---

## 8) Operations

### 8.1 Version Matrix & Pinning

- Pin versions for CAPI, providers, Talos, Cilium, Flux, and add‑ons per release branch (e.g., `release/0.1.x`).
- Maintain a **compatibility table** in `docs/` and CI to prevent unsupported combos.

### 8.2 Upgrades

- **Talos nodes:** rolling via Talos APIs; cordon/drain automated.
- **Cilium:** follow official preflight and surge rollout; validate XDP/WG/IPsec after.
- **CAPI providers:** upgrade management cluster first; then rotate ClusterClass templates (template rotation) to propagate safely to fleets.

### 8.3 Capacity & Performance

- Right‑size control planes; consider HPA/VPA for data plane components.
- L7 visibility is CPU‑intensive; scope to critical namespaces.
- Plan storage IOPS/throughput for Rook‑Ceph or cloud disks.

### 8.4 Preflight Checklist

- Provider credentials present; DNS zones delegated; ACME/DNS‑01 ready (if used).
- Kernel features (eBPF/XDP/BBR/WireGuard) verified on images.
- BGP peering approved by network team (if enabled).

### 8.5 Troubleshooting (quick cues)

- **Connectivity:** `cilium status`, `cilium sysdump`; check Hubble UI/CLI.
- **GitOps:** `flux get kustomizations` / `flux logs` for drift/health.
- **Talos:** `talosctl get machines`, `talosctl logs` for node lifecycle.
- **CAPI:** `kubectl get clusters,md,ms,cp` and `clusterctl describe` for lifecycle issues.

---

## 9) Getting Started

```bash
git clone https://github.com/your-org/infraflux.git
cd infraflux
./hack/bootstrap.sh --provider aws   # or azure|gcp|proxmox|metal3
```

**Requirements**: Docker, kind, clusterctl, flux, talosctl, kubectl, provider credentials.

---

## 10) Detailed Roadmap

> Each item includes deliverables, acceptance criteria (AC), and rollback/risks.

### Phase 1 — Core Automation (Weeks 1–3)

1. **Bootstrap Script**

   - _Deliverables:_ `hack/bootstrap.sh`, docs, preflight checks, destroy script.
   - _AC:_ One command brings up mgmt cluster, moves CAPI, installs Flux; idempotent reruns; works on AWS & Proxmox.
   - _Risks:_ Local Docker/kind conflicts; provider credentials. _Rollback:_ destroy script.

2. **CAPI Providers + Talos**

   - _Deliverables:_ `platform/capi/` with pinned versions for CAPA/CAPZ/CAPG/Proxmox/Metal3; Talos bootstrap/control plane.
   - _AC:_ Create/destroy a dev workload cluster from Git; nodes are Talos.

3. **Flux Bootstrap & Repo Wiring**

   - _Deliverables:_ `platform/flux/`, GitSources/Kustomizations pattern; promotion branches.
   - _AC:_ Flux reconciles bootstrap `namespaces`/`helmrepositories` and a sample app.

4. **Cilium Base (All Features On)**

   - _Deliverables:_ `modules/networking/cilium/` HelmRelease + overlays; ClusterClass variables.
   - _AC:_ `cilium status` healthy; Gateway/Ingress route a sample app; Hubble metrics flowing.

5. **Core Add‑ons**

   - _Deliverables:_ cert‑manager (HTTP‑01), ExternalDNS, Sealed Secrets, ESO, Velero (object store), Observability base.
   - _AC:_ Valid certs, DNS created automatically, secret sync works, nightly Velero backups succeed, dashboards/alerts visible.

### Phase 2 — Modular Components (Weeks 4–6)

1. **Alt Ingress/Gateway Modules**

   - _Deliverables:_ Envoy Gateway and Ingress‑NGINX modules (disabled by default).
   - _AC:_ Switching ClusterClass var flips between defaults and alternates without manual edits.

2. **Storage Modules**

   - _Deliverables:_ Cloud CSI classes; Rook‑Ceph for Proxmox/bare‑metal with snapshotting.
   - _AC:_ PVCs provision; snapshots/restore work; performance baselines documented.

3. **Cilium Feature Packs Hardening**

   - _Deliverables:_ Example BGP peering, EgressGateway policies, ClusterMesh tutorial, Tetragon baseline policies.
   - _AC:_ Peers established; egress IP pinning works; multi‑cluster service resolves; runtime alerts generated on test violations.

### Phase 3 — Security Hardening (Weeks 7–9)

1. **Multi‑tenancy & RBAC**

   - _Deliverables:_ Flux impersonation model; per‑namespace SAs; NetworkPolicies.
   - _AC:_ Tenants isolated; Git permissions aligned with namespaces.

2. **Policy Baselines**

   - _Deliverables:_ Gatekeeper/Kyverno constraints; CI policy tests in GitHub Actions.
   - _AC:_ Policy violations block PRs; exemptions audited.

3. **OIDC Integration**

   - _Deliverables:_ Pinniped/Dex setup; oauth2‑proxy example for edge SSO.
   - _AC:_ Cluster login via external IdP; sample app protected by SSO.

4. **Secrets Rotation & Key Management**

   - _Deliverables:_ Sealed Secrets key rotation doc; ESO backend auth rotation runbook.
   - _AC:_ Rotation drill passes; apps continue operating.

### Phase 4 — Scale & Multi‑Cluster (Weeks 10–12)

1. **Cluster Mesh Rollout**

   - _Deliverables:_ Mesh between dev and prod; service export/import examples; trust bootstrap automation.
   - _AC:_ Cross‑cluster traffic works; policies enforce namespace isolation across clusters.

2. **Fleet Sharding**

   - _Deliverables:_ Sharded Flux Kustomizations per team/tenant; tuned intervals and `dependsOn` graphs.
   - _AC:_ Reconciliation latencies within SLOs under load.

3. **DR Drills & Runbooks**

   - _Deliverables:_ Scheduled Velero backups; documented restore to fresh region/provider; periodic drills.
   - _AC:_ RTO/RPO targets achieved; audit trail of drills.

4. **Template Rotation Procedures**

   - _Deliverables:_ Documented ClusterClass template rotation; CI guardrails; canary rollout steps.
   - _AC:_ Safe propagation of changes to fleets without downtime.

### Phase 5 — Nice‑to‑Haves (Ongoing)

- **Crossplane** compositions for DB/bucket/DNS claims tied to app recipes.
- **Cost & capacity dashboards** integrating cloud metrics.
- **Golden‑path app templates** (with CI scaffolding) using the 5‑file Flux pattern.

---

## 11) FAQs & Trade‑offs

- **Why all Cilium features on by default?** Simplicity and consistency. We accept some overhead to avoid component sprawl. Tuning guidance is provided to scope heavy features in prod.
- **Do we need another CLI?** No. We rely only on upstream tools (`kind`, `clusterctl`, `flux`, `talosctl`, `kubectl`).
- **Can we swap components?** Yes. ClusterClass variables and module overlays make swaps a pull request, not a rebuild.
- **How do we avoid lockouts with policies?** Staged policies, break‑glass namespaces, and CI policy tests before merge.

---

## 12) Contributing

- Use the provided folder structure and naming conventions.
- Add `dependsOn` and `healthChecks` for every new Kustomization.
- Pin versions; update the version matrix and changelog.
- Include runbooks for new capabilities and clear rollback steps.

---

## 13) Getting Help

- Check `docs/security.md` and `docs/roadmap.md` for deep dives and current status.
- Common commands: `flux get kustomizations`, `flux logs`, `cilium status`, `talosctl`, `clusterctl describe`.

<!-- markdownlint-enable MD013 -->
