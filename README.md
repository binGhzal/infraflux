# infraflux

**Turnkey, self-maintaining Kubernetes on Proxmox** — Day-0 with Terraform, then hands-off with
Cluster API (CAPMOX) + Talos nodes + Cilium (kube-proxy-free, Gateway API, BGP, Hubble, egress,
bandwidth/BBR, host firewall, L7 policy, DNS/FQDN policy, multicast, transparent encryption) and a
clean **Flux “5-file” app pattern**.

> This README is the project’s user guide. You can copy/paste the snippets into your repo and run
> with it.

---

## Why infraflux?

- **Day-0 once, controllers forever:** Terraform bootstraps a tiny Talos management cluster and
  installs the **Cluster API Operator**. From there, CAPI + **CAPMOX** reconcile VM lifecycle on
  Proxmox; no glue scripts. ([cluster-api-operator.sigs.k8s.io][1], [GitHub][2],
  [cluster-api.sigs.k8s.io][3])
- **Immutable nodes:** Talos is API-driven (no SSH) and has first-class guides for Proxmox + Cilium.
  ([TALOS LINUX][4])
- **Cilium, all the superpowers:** kube-proxy replacement, Gateway API, Ingress, BGP control plane,
  Egress Gateway, Hubble (UI/Relay), Bandwidth Manager + BBR, L7 policy (HTTP/gRPC/Kafka), DNS/FQDN
  egress control, Host Firewall, Multicast, Prometheus metrics, Transparent Encryption
  (WireGuard/IPsec). See the **Cilium values** below. ([Cilium Documentation][5], [cilium.io][6])

---

## Architecture

- **Proxmox** (existing); Terraform **bpg/proxmox** provider uploads Talos image & creates VMs.
  ([Terraform Registry][7])
- **Talos** management cluster (2–3 VMs). Terraform **talos** provider generates machine configs,
  bootstraps, fetches kubeconfig. ([Terraform Registry][8], [Sidero Labs][9])
- **Cluster API Operator** (installed via Helm) manages providers declaratively:
  **Infrastructure=Proxmox (CAPMOX)**, **Bootstrap=Talos**, **ControlPlane=Talos**.
  ([cluster-api-operator.sigs.k8s.io][1], [GitHub][10])
- **Workload clusters** defined as CAPI YAML (Cluster + TalosControlPlane + MachineDeployment +
  ProxmoxMachineTemplates) + **MachineHealthCheck** for auto-remediation.
  ([cluster-api.sigs.k8s.io][3])
- **Cilium** installed via flux with the values here (kube-proxy-free, Gateway API, BGP CP, etc.).
  ([Cilium Documentation][11])
- **Flux** manages apps with the **5-file pattern** (Namespace, HelmRepository, Kustomization,
  Values ConfigMap/Secret, HelmRelease). ([Flux][12])

---

## Prerequisites

- Proxmox API access (token or user/pass) and a storage/network configured.
- Terraform/OpenTofu with providers: `bpg/proxmox`, `siderolabs/talos`, `hashicorp/helm`,
  `hashicorp/kubernetes`. ([Terraform Registry][13])
- Talos image/ISO (use Talos docs for Proxmox specifics). ([TALOS LINUX][4])

---

## Day-0: one `terraform apply`

> Keep Terraform strictly for Day-0; after that, controllers (CAPI/CAPMOX/Talos) own lifecycle.

1. **Provision mgmt cluster (Talos on Proxmox):**

   - Upload Talos ISO/image (`proxmox_virtual_environment_file`) and create 2–3 VMs
     (`proxmox_virtual_environment_vm`). ([Terraform Registry][14])
   - Use the **Talos provider** to apply machine configs, bootstrap, and retrieve kubeconfig.
     ([Terraform Registry][8])

2. **Install Cluster API Operator (Helm):**

   - The Operator Helm chart supports a quickstart for installing CAPI providers declaratively.
     ([cluster-api-operator.sigs.k8s.io][1])

3. **Enable providers:**

   - Apply Operator CRs to enable **Infrastructure=Proxmox (CAPMOX)**, **Bootstrap=Talos**,
     **ControlPlane=Talos**. ([GitHub][2])

4. **Create a workload cluster:**

   - Apply `Cluster`, `TalosControlPlane`, `MachineDeployment`, `ProxmoxMachineTemplate`, and a
     **MachineHealthCheck**. ([cluster-api.sigs.k8s.io][3])

5. **Install Cilium (Helm) on the workload cluster** using the values below (or via
   ClusterResourceSet if you want CAPI to auto-install CNIs across fleets). ([Cilium
   Documentation][11], [cluster-api.sigs.k8s.io][15])

---

## Cilium: “kitchen-sink” Helm values (enable the lot)

> Start here, then prune features you don’t need. Some options require specific kernels/NICs;
> validate in a lab first. Docs linked per feature.

```yaml
# values/cilium-full.yaml  (tested with Cilium 1.18.x+)
# Core
kubeProxyReplacement: true # kube-proxy free (socket LB) :contentReference[oaicite:17]{index=17}
ipam:
  mode: kubernetes
l7Proxy: true # required for L7 policy/Gateway API (default true) :contentReference[oaicite:18]{index=18}

  50-cilium/                 # Cilium via Helm or CRS (flag-gated)
  _root/                     # single inputs.yaml orchestrator
  00-proxmox-foundation/     # upload Talos ISO, optional VM template
  10-mgmt-talos/             # bootstrap Talos mgmt cluster (kubeconfig output)
  20-capi-operator/          # install Operator and Providers (flag-gated)
  30-capmox/                 # CAPMOX ProxmoxCluster + credentials (flag-gated)
  40-clusters/               # Workload cluster stack (flag-gated)
  50-addons/                 # Cilium via Helm or CRS (flag-gated)
gatewayAPI:
  enabled: true # Gateway API data-plane via Envoy :contentReference[oaicite:19]{index=19}
  enableAlpn: true

Staged bootstrap:

- Phase 1: flags enable_* = false; apply 00 + 10 to get mgmt kubeconfig.
- Set kubernetes.kubeconfig in terraform/_root/inputs.yaml to the saved kubeconfig path.
- Phase 2: flip flags as needed to install Operator, CAPMOX, clusters, and addons.
  enableAppProtocol: true
ingressController:
  enabled: true # Cilium Ingress controller (optional) :contentReference[oaicite:20]{index=20}

# L4/L7 Load-Balancing
service:
  lb:
    acceleration: 'best-effort' # allow XDP where possible (depends on NIC/driver)
# (See docs for Envoy LB, L7 options, headers/XFF.) :contentReference[oaicite:21]{index=21}

# BGP Control Plane (advertise LB IPs / Pod CIDRs)
bgpControlPlane:
  enabled: true # Pair with CiliumBGPClusterConfig/PeerConfig CRDs :contentReference[oaicite:22]{index=22}

# Egress Gateway (stable egress IPs)
egressGateway:
  enabled: true # requires bpf.masquerade + kubeProxyReplacement :contentReference[oaicite:23]{index=23}
bpf:
  masquerade: true

# Bandwidth & Latency
bandwidthManager:
  enabled: true # EDT queueing
  bbr: true # enable BBR for Pods :contentReference[oaicite:24]{index=24}

# Observability
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true # Service map (lock down with auth) :contentReference[oaicite:25]{index=25}
prometheus:
  enabled: true # expose agent/Envoy metrics
operator:
  prometheus:
    enabled: true # operator metrics (default true) :contentReference[oaicite:26]{index=26}

# Security & Policy
hostFirewall:
  enabled: true # node-level policies (beta/GA per release notes) :contentReference[oaicite:27]{index=27}
authentication:
  mutual:
    spire:
      enabled: false # example; see docs if using SPIRE mTLS :contentReference[oaicite:28]{index=28}
# L7 policy is on by default when L7 rules exist; see CiliumNetworkPolicy docs. :contentReference[oaicite:29]{index=29}

# DNS / FQDN egress control
dnsProxy:
  enableTransparentMode: true # required for toFQDNs policies visibility/control :contentReference[oaicite:30]{index=30}

# Multicast (beta, validate in lab)
multicast:
  enabled: true # see multicast doc and CLI refs :contentReference[oaicite:31]{index=31}

# Transparent Encryption (choose one)
encryption:
  enabled: true # turn on transparent encryption
  type: wireguard # or "ipsec" per your org’s standards :contentReference[oaicite:32]{index=32}

# Talos-specific bits (when installing on Talos)
cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup
k8sServiceHost: localhost # or your API host if KubePrism not used
k8sServicePort: 7445 # Talos KubePrism default; see Talos doc :contentReference[oaicite:33]{index=33}
```

Install with flux:

Gotcha — let’s make **Cilium itself** follow the exact Flux **5-file** pattern (Namespace,
HelmRepository, Kustomization, Values ConfigMap, HelmRelease). I’ll assume we keep Cilium in
`kube-system` (its default). If you prefer a dedicated `cilium-system` namespace, just swap the
names below.

> API groups are current: `source.toolkit.fluxcd.io/v1`, `kustomize.toolkit.fluxcd.io/v1`,
> `helm.toolkit.fluxcd.io/v2`. ([Flux][1])

---

## Cilium — Flux 5-file set

## 1) Namespace (optional; `kube-system` already exists)

`flux/bootstrap/namespaces/namespace-cilium.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
```

## 2) HelmRepository

`flux/bootstrap/helmrepositories/helmrepository-cilium.yaml`

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: cilium
  namespace: flux-system
spec:
  interval: 15m
  url: https://helm.cilium.io
```

(Flux Source API v1 + HelmRepository spec.) ([Flux][1])

## 3) Kustomization (wires the app folder)

`flux/bootstrap/kustomizations/kustomization-cilium.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cilium
  namespace: flux-system
spec:
  interval: 15m
  path: ./flux/apps/cilium
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: apps/v1
      kind: DaemonSet
      name: cilium
      namespace: kube-system
    - apiVersion: apps/v1
      kind: Deployment
      name: hubble-ui
      namespace: kube-system
```

(Flux Kustomize v1 health checks keep rollouts safe.) ([Flux][2])

## 4) Values ConfigMap (all the Cilium goodies enabled)

`flux/apps/cilium/configmap-cilium-values.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-helm-values
  namespace: kube-system
data:
  values.yaml: |
    # Core / kube-proxy free
    kubeProxyReplacement: true                      # socket-LB datapath :contentReference[oaicite:3]{index=3}
    ipam:
      mode: kubernetes
    l7Proxy: true                                    # needed for L7/Gateway API :contentReference[oaicite:4]{index=4}

    # Gateway API + Ingress
    gatewayAPI:
      enabled: true
      enableAlpn: true
      enableAppProtocol: true                        # Gateway API data-plane via Envoy :contentReference[oaicite:5]{index=5}
    ingressController:
      enabled: true                                  # optional Ingress controller :contentReference[oaicite:6]{index=6}

    # L4/L7 load balancing (allow XDP accel when HW supports it)
    service:
      lb:
        acceleration: "best-effort"                  # native/XDP when available

    # BGP control plane (advertise LB IPs / Pod CIDRs)
    bgpControlPlane:
      enabled: true                                  # configure via CiliumBGP* CRDs :contentReference[oaicite:7]{index=7}

    # Egress Gateway (fixed egress IPs)
    egressGateway:
      enabled: true                                  # route via selected gateway nodes :contentReference[oaicite:8]{index=8}
    bpf:
      masquerade: true

    # Bandwidth & Latency optimization
    bandwidthManager:
      enabled: true                                  # EDT queueing
      bbr: true                                      # BBR for Pods :contentReference[oaicite:9]{index=9}

    # Observability (Hubble + metrics)
    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true                                # service map UI :contentReference[oaicite:10]{index=10}
    prometheus:
      enabled: true                                  # agent/envoy metrics
    operator:
      prometheus:
        enabled: true                                # operator metrics :contentReference[oaicite:11]{index=11}

    # Security & policy
    hostFirewall:
      enabled: true                                  # node-level identity firewall :contentReference[oaicite:12]{index=12}
    dnsProxy:
      enableTransparentMode: true                    # DNS/FQDN egress policy visibility :contentReference[oaicite:13]{index=13}

    # Multicast (validate in lab; beta)
    multicast:
      enabled: true                                  :contentReference[oaicite:14]{index=14}

    # Transparent encryption (pick one)
    encryption:
      enabled: true
      type: wireguard                                # or "ipsec" per policy :contentReference[oaicite:15]{index=15}

    # Talos specifics (API access via KubePrism and cgroups)
    cgroup:
      autoMount:
        enabled: false
      hostRoot: /sys/fs/cgroup
    k8sServiceHost: localhost
    k8sServicePort: 7445                             # Talos KubePrism default :contentReference[oaicite:16]{index=16}
```

(Values keys are from the Cilium Helm chart; see the Helm reference.) ([Cilium Documentation][3])

## 5) HelmRelease (pins chart & consumes values)

`flux/apps/cilium/helmrelease-cilium.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cilium
  namespace: kube-system
spec:
  interval: 15m
  timeout: 10m
  chart:
    spec:
      chart: cilium
      version: '1.18.x' # pin major/minor you’ve validated
      sourceRef:
        kind: HelmRepository
        name: cilium
        namespace: flux-system
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  valuesFrom:
    - kind: ConfigMap
      name: cilium-helm-values
      valuesKey: values.yaml
```

(HelmRelease v2 is the current API.) ([Flux][4])

---

## Where the “extra” Cilium CRDs live (BGP/Egress policies)

A few features are **on by Helm** but need **their own CRDs** to do anything:

- **BGP Control Plane**: create `CiliumBGPClusterConfig` + `CiliumBGPPeerConfig` (and optionally
  `CiliumBGPAdvertisement`) under `flux/apps/cilium/resources/` and reference that folder from the
  same Kustomization (or a second Kustomization if you want stricter ordering). ([Cilium
  Documentation][5])
- **Egress Gateway**: define `CiliumEgressGatewayPolicy` objects in that same `resources/` folder.
  ([Cilium Documentation][6])

> This keeps the **5 core files** intact while letting you version the optional CRs alongside them.

- **Feature docs & caveats:** kube-proxy-free depends on socket-LB; Gateway API requires L7 proxy;
  Egress GW needs masquerade; BBR depends on the bandwidth manager; multicast is evolving; enable
  Prometheus metrics/ServiceMonitors if you run Prometheus Operator. ([Cilium Documentation][5])

> Tip (Talos): Talos’ Cilium guide shows the exact Helm flags and the **KubePrism** API port
> (`7445`). If you don’t use KubePrism, set `k8sServiceHost/Port` to your cluster’s API. ([TALOS
> LINUX][16], [GitHub][17])

---

## Flux: “5-file” app pattern

**Why:** multi-namespace reuse, explicit ordering, and readability. API versions are current as of
Flux v2.6 (2025-05). ([Flux][18])

**Files per app instance:**

1. `bootstrap/namespaces/namespace-<app>.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: podinfo
```

1. `bootstrap/helmrepositories/helmrepository-podinfo.yaml`

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 15m
  url: https://stefanprodan.github.io/podinfo
```

([Flux][12])

1. `apps/podinfo/configmap-podinfo-values.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: podinfo-helm-chart-value-overrides
  namespace: podinfo
data:
  values.yaml: |
    ui:
      message: "Hello from infraflux"
```

1. `bootstrap/kustomizations/kustomization-podinfo.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 15m
  path: ./apps/podinfo
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: podinfo
```

([Flux][19])

1. `apps/podinfo/helmrelease-podinfo.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: podinfo
spec:
  chart:
    spec:
      chart: podinfo
      version: 6.x
      sourceRef:
        kind: HelmRepository
        name: podinfo
        namespace: flux-system
  interval: 15m
  releaseName: podinfo
  valuesFrom:
    - kind: ConfigMap
      name: podinfo-helm-chart-value-overrides
      valuesKey: values.yaml
```

([Flux][20])

> Flux also supports taking Helm values from Secrets/ConfigMaps with merge order semantics, and OCI
> helm sources if you prefer. ([v2-0.docs.fluxcd.io][21], [Flux][22])

---

## Add-ons (sane defaults)

- **Secrets:**

  - **Bootstrap** in Git with SOPS (Age/KMS) or Sealed Secrets. Flux SOPS integration is
    first-class. ([Flux][23])
  - **Runtime/rotation:** **External Secrets Operator** (Vault/Secrets Manager/etc.).
    ([external-secrets.io][24], [GitHub][25])

- **DNS / Certificates:**

  - **ExternalDNS** to reconcile DNS from Gateway/HTTPRoute. ([kubernetes-sigs.github.io][26])
  - **cert-manager** with Gateway API enabled. ([cert-manager][27])

- **Storage:**

  - **Rook-Ceph** on bare-metal, or **Proxmox CSI plugin** if you want to back PVCs by Proxmox
    storage. ([Rook][28], [GitHub][29])
  - **Backups/DR:** **Velero** with **CSI snapshots** (`EnableCSI` feature). ([Velero][30])

- **Self-healing:** **MachineHealthCheck** for every pool. ([cluster-api.sigs.k8s.io][31])

---

## Repo layout

```text
infraflux/
  terraform/
    00-proxmox-foundation/     # storage/network, upload Talos ISO
    10-mgmt-talos/             # Talos VMs + bootstrap + kubeconfig
    20-capi-operator/          # Helm install Cluster API Operator
    30-capmox/                 # ProxmoxCluster + credentials Secret
    40-clusters/               # ClusterClass/templates + MHC
    50-cilium/                 # Helm install (values/cilium-full.yaml)
  flux/
    bootstrap/                 # namespaces/, helmrepositories/, kustomizations/
    apps/
      podinfo/                 # values CM + HelmRelease (5-file pattern)
```

---

## Notes & troubleshooting

- **Talos + Cilium:** follow the Talos “Deploying Cilium” guide closely (KubePrism port, cgroup
  flags). If not using KubePrism, point `k8sServiceHost/Port` at the Kubernetes API. ([TALOS
  LINUX][16])
- **Gateway API:** ensure CRDs are installed and `l7Proxy=true` is set (default). ([Cilium
  Documentation][32])
- **Egress Gateway:** requires `bpf.masquerade=true` and kube-proxy replacement. ([Cilium
  Documentation][33])
- **Metrics:** enable Prometheus metrics via Helm flags; add ServiceMonitors if you run Prometheus
  Operator. ([Cilium Documentation][34])
- **Multicast/BBR:** feature-gated and kernel/NIC dependent; validate before prod. ([Cilium
  Documentation][35])
- **CAPMOX scope:** one Proxmox cluster per workload cluster (multi-Proxmox per single K8s cluster
  is tracked upstream). Plan IPAM/BGP accordingly. ([GitHub][36])

---

## Commands quickstart (indicative)

```bash
# 1) Day-0 apply (mgmt cluster + CAPI Operator + CAPMOX)
cd terraform/_root && cp inputs.example.yaml inputs.yaml # then edit inputs.yaml once
tofu init && tofu plan && tofu apply

# 2) Create a workload cluster (CAPI YAML applied by Terraform or kubectl)
#    ... wait for <cluster>-kubeconfig Secret, write to kubeconfig file

# 3) Install Cilium with all features
helm upgrade --install cilium cilium/cilium -n kube-system -f values/cilium-full.yaml

# 4) Bootstrap Flux for apps (optional)
flux bootstrap git --url=<your-git> --branch=main --path=./flux
```

(Use Flux’s official “Get Started” to bootstrap into your repo/cluster of choice.) ([Flux][37])

---

## References

- **Cilium:** kube-proxy-free, Helm install, Gateway API, BGP CP, Egress GW, Hubble, Bandwidth/BBR,
  metrics, multicast, encryption. ([Cilium Documentation][5])
- **Talos:** Proxmox guide, Cilium on Talos (KubePrism 7445). ([TALOS LINUX][4])
- **Cluster API:** Quick start, Operator Helm chart, ClusterResourceSet (auto-apply add-ons),
  MachineHealthCheck. ([cluster-api.sigs.k8s.io][3], [cluster-api-operator.sigs.k8s.io][1])
- **Flux:** API versions (Helm v2, Source v1, Kustomize v1), guides. ([Flux][20])
- **Add-ons:** ESO, Flux SOPS, Rook-Ceph, Proxmox CSI, Velero CSI. ([external-secrets.io][24],
  [Flux][23], [Rook][28], [GitHub][29], [Velero][30])

---

### License

MIT (or your choice). Contributions welcome!

[1]:
  https://cluster-api-operator.sigs.k8s.io/02_installation/04_helm-chart-installation?utm_source=chatgpt.com
  'Using Helm Charts - Cluster API Operator - Kubernetes'
[2]:
  https://github.com/ionos-cloud/cluster-api-provider-proxmox?utm_source=chatgpt.com
  'Cluster API Provider for Proxmox VE (CAPMOX)'
[3]:
  https://cluster-api.sigs.k8s.io/user/quick-start?utm_source=chatgpt.com
  'Quick Start - The Cluster API Book - Kubernetes'
[4]:
  https://www.talos.dev/v1.10/talos-guides/install/virtualized-platforms/proxmox/?utm_source=chatgpt.com
  'Proxmox'
[5]:
  https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free.html?utm_source=chatgpt.com
  'Kubernetes Without kube-proxy — Cilium 1.18.0 documentation'
[6]:
  https://cilium.io/blog/2025/05/20/cilium-l7-policies/?_hsenc=p2ANqtz-_zZJ5z3ksNiTu3vXCTwb8om87J8KEZO4xs-yyKkGcWoE1Kn8vlTadkb_fDsRFsxKOY7qB1&utm_medium=email&utm_source=chatgpt.com
  'Application-Aware Security Policies with Cilium Layer 7 ...'
[7]:
  https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm?utm_source=chatgpt.com
  'proxmox_virtual_environment_vm | Resources | bpg/proxmox'
[8]:
  https://registry.terraform.io/providers/siderolabs/talos/0.4.0-alpha.0/docs?utm_source=chatgpt.com
  'Docs overview | siderolabs/talos - Terraform Registry'
[9]:
  https://www.siderolabs.com/blog/verified-terraform-provider-for-talos-linux/?utm_source=chatgpt.com
  'Verified Terraform provider for Talos Linux'
[10]:
  https://github.com/kubernetes-sigs/cluster-api-operator?utm_source=chatgpt.com
  'kubernetes-sigs/cluster-api-operator'
[11]:
  https://docs.cilium.io/en/stable/installation/k8s-install-helm.html?utm_source=chatgpt.com
  'Installation using Helm — Cilium 1.18.0 documentation'
[12]:
  https://fluxcd.io/flux/components/source/api/v1/?utm_source=chatgpt.com
  'Source API reference v1'
[13]:
  https://registry.terraform.io/providers/bpg/proxmox/latest/docs?utm_source=chatgpt.com
  'Proxmox Provider - bpg - Terraform Registry'
[14]:
  https://registry.terraform.io/providers/bpg/proxmox/0.58.0/docs/resources/virtual_environment_file?utm_source=chatgpt.com
  'proxmox_virtual_environment_file | Resources | bpg/proxmox'
[15]:
  https://cluster-api.sigs.k8s.io/tasks/cluster-resource-set?utm_source=chatgpt.com
  'ClusterResourceSet - The Cluster API Book'
[16]:
  https://www.talos.dev/latest/kubernetes-guides/network/deploying-cilium/?utm_source=chatgpt.com
  'Deploying Cilium CNI'
[17]:
  https://github.com/siderolabs/talos/issues/9132?utm_source=chatgpt.com
  'Documentation Bug: Cilium install instructions incorrectly ...'
[18]: https://fluxcd.io/blog/2025/05/flux-v2.6.0/?utm_source=chatgpt.com 'Announcing Flux 2.6 GA'
[19]:
  https://fluxcd.io/flux/components/kustomize/kustomizations/?utm_source=chatgpt.com
  'Kustomization'
[20]: https://fluxcd.io/flux/components/helm/api/v2/?utm_source=chatgpt.com 'Helm API reference v2'
[21]:
  https://v2-0.docs.fluxcd.io/flux/guides/helmreleases/?utm_source=chatgpt.com
  'Manage Helm Releases'
[22]: https://fluxcd.io/flux/guides/helmreleases/?utm_source=chatgpt.com 'Manage Helm Releases'
[23]:
  https://fluxcd.io/flux/guides/mozilla-sops/?utm_source=chatgpt.com
  'Manage Kubernetes secrets with SOPS'
[24]: https://external-secrets.io/?utm_source=chatgpt.com 'External Secrets Operator: Introduction'
[25]:
  https://github.com/external-secrets/external-secrets?utm_source=chatgpt.com
  'External Secrets Operator reads information ...'
[26]:
  https://kubernetes-sigs.github.io/external-dns/v0.13.1/tutorials/gateway-api/?utm_source=chatgpt.com
  'Configuring ExternalDNS to use Gateway API Route Sources'
[27]:
  https://cert-manager.io/docs/usage/gateway/?utm_source=chatgpt.com
  'Annotated Gateway resource'
[28]:
  https://rook.io/docs/rook/latest/Getting-Started/quickstart/?utm_source=chatgpt.com
  'Quickstart - Rook Ceph Documentation'
[29]:
  https://github.com/sergelogvinov/proxmox-csi-plugin/blob/main/docs/install.md?utm_source=chatgpt.com
  'proxmox-csi-plugin/docs/install.md at main'
[30]:
  https://velero.io/docs/main/csi/?utm_source=chatgpt.com
  'Container Storage Interface Snapshot Support in Velero'
[31]:
  https://cluster-api.sigs.k8s.io/tasks/automated-machine-management/healthchecking?utm_source=chatgpt.com
  'Configure a MachineHealthCheck - The Cluster API Book'
[32]:
  https://docs.cilium.io/en/latest/network/servicemesh/gateway-api/gateway-api.html?utm_source=chatgpt.com
  'Gateway API Support — Cilium 1.19.0-dev documentation'
[33]:
  https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway.html?utm_source=chatgpt.com
  'Egress Gateway — Cilium 1.18.0 documentation'
[34]:
  https://docs.cilium.io/en/stable/observability/metrics.html?utm_source=chatgpt.com
  'Monitoring & Metrics — Cilium 1.18.0 documentation'
[35]:
  https://docs.cilium.io/en/stable/network/kubernetes/bandwidth-manager.html?utm_source=chatgpt.com
  'Bandwidth Manager — Cilium 1.18.0 documentation'
[36]:
  https://github.com/ionos-cloud/cluster-api-provider-proxmox/issues/370?utm_source=chatgpt.com
  '[Proposal] Support for multi Proxmox Clusters (Datacenters)'
[37]: https://fluxcd.io/flux/get-started/?utm_source=chatgpt.com 'Get Started with Flux'
