# 1) Preflight & Foundations

1.1 Completed ✅ Validate infra assumptions

1.1.4 Docs: Completed ✅ [Preflight checklist](docs/preflight.md), [Secrets inventory & mapping](docs/secrets.md)
1.1.5 Status: Completed ✅ — Preflight doc authored; secrets mapping drafted; links wired.
1.2 Prepare Synology MinIO for state & backups

- 1.2.1 Deploy MinIO on Synology; create buckets `infraflux-velero` and `infraflux-longhorn`.
- 1.2.2 Note endpoint (e.g., `http(s)://10.0.0.49`), access/secret keys (kept in 1Password).
- 1.2.3 Decide TLS/no-TLS and firewall rules for GH Actions runner connectivity. ([velero.io][5])

  1.3 Prep 1Password for ESO

- 1.3.1 Create 1Password **service account** & vault (e.g., `infraflux-prod`).
- 1.3.2 Plan SecretStore mapping for Proxmox token, Cloudflare token/zone ID, MinIO keys, ArgoCD OIDC client secret.
- 1.3.3 Record org URL for SDK provider. ([external-secrets.io][6])

## Pitfalls (Step 1)

- Using a Proxmox user without needed privileges → Terraform fails late; verify **token scope** early. ([Terraform Registry][1])
- Forgetting DHCP reservations → nodes change IPs; Longhorn/ESO targets get cranky.
- MinIO without persistent storage or wrong endpoint scheme (http/https) → backend init & Velero will misbehave. ([velero.io][5])

---

## 2) Image Build (Talos Image Factory)

2.0 Docs: [Image Factory — schematic & build](docs/image-factory.md)
2.0 Status: In progress — schematic added; doc drafted.

2.1 Author Talos Image Factory schematic (universal image)

- 2.1.1 Include system extensions: `siderolabs/qemu-guest-agent`, `siderolabs/iscsi-tools`, `siderolabs/util-linux-tools`, plus Intel microcode. ([GitHub][7], [factory.talos.dev][8])
- 2.1.2 Choose target = nocloud; pin Talos version (latest stable).
- 2.1.3 Export the image URL/ID for Terraform.

  2.2 Sanity test the image in Proxmox (manual one-off VM)

- 2.2.1 Boot, verify guest agent, verify `iscsiadm` present, verify util-linux tools.
- 2.2.2 Confirm console shows Talos ready.

### Pitfalls (Step 2)

- Missing `iscsi-tools`/`util-linux-tools` → Longhorn won’t mount volumes. ([Longhorn][9])
- Occasional first-boot quirks on PVE—retry or reprovision if hit; keep eye on Talos/Proxmox first-boot notes. ([GitHub][10])

---

## 3) Repo & CI Skeleton (Vanilla Terraform)

3.1 Lay out repo

- 3.1.1 `terraform/modules/*` for: `proxmox-vm`, `talos-cluster`, `cilium`, `argocd`, `external-secrets`, `longhorn`, `cert-manager`, `external-dns`, `observability`.
- 3.1.2 `terraform/envs/prod` with `main.tf`, `providers.tf` (bpg/proxmox, helm, kubernetes), `backend.tf` (S3→MinIO), `versions.tf`, `variables.tf`, `prod.auto.tfvars.example`.
- 3.1.3 `.github/workflows`: `plan.yml` (fmt/validate/plan), `apply.yml` (manual approval).

  3.2 Configure Terraform backend to MinIO

- 3.2.1 `backend "s3"`: endpoint, bucket, access/secret (from 1Password at runtime).
- 3.2.2 Enable locking if supported.

  3.3 Provision a self-hosted GitHub runner (on LAN)

- 3.3.1 Network reachability to Proxmox and MinIO; least-priv secrets.

### Pitfalls (Step 3)

- Storing state in Git by accident—ensure S3 backend works before `apply`.
- Wrong MinIO endpoint scheme (missing `skip_credentials_validation`/`skip_region_validation` flags) → init fails.
- PVE provider mis-config (wrong realm/user) → auth flaps. ([Terraform Registry][1])

---

## 4) Proxmox Module (VMs)

4.1 Build `proxmox-vm` module

- 4.1.1 Inputs: node `pve`, ISO storage `local`, VM disk storage `bigdisk`, bridge `vmbr0`.
- 4.1.2 Parameters: counts (3 CP / 9 workers), vCPU/RAM/disk sizes, extra **Longhorn data disk** on workers (default 200 GiB).
- 4.1.3 Cloud-init or equivalent to pass Talos kernel args if needed; attach the Talos image.
- 4.1.4 Enable QEMU Guest Agent for clean IP detection/shutdown. ([Terraform Registry][1])

  4.2 Outputs to wire next stages

- 4.2.1 Node MACs/IDs for DHCP reservations.
- 4.2.2 VM IP discovery via guest agent (best-effort).

### Pitfalls (Step 4)

- Forgetting `virtio-scsi single`/appropriate disk bus → perf penalties.
- Skipping guest agent → Terraform can’t learn IPs reliably. ([Terraform Registry][1])

---

## 5) Talos Cluster Module (Bootstrap, VIP, KubePrism)

5.1 Generate Talos machine configs

- 5.1.1 `cni.name: none` (install CNI later).
- 5.1.2 **Disable kube-proxy** (we’ll run Cilium KPR). ([docs.cilium.io][11])
- 5.1.3 Configure **VIP = 10.0.1.50** for API HA. ([TALOS LINUX][3])
- 5.1.4 Enable **KubePrism** on all nodes for in-cluster API HA. ([TALOS LINUX][12])

  5.2 Bootstrap etcd & fetch kubeconfig

- 5.2.1 Orchestrate first-control-plane bootstrap, then join remaining CPs, then workers.
- 5.2.2 Export kubeconfig (artifact for Helm/K8s providers). ([TALOS LINUX][13])

### Pitfalls (Step 5)

- Installing CNI before Talos bootstrap is complete → API flaps.
- Not fully disabling kube-proxy when enabling Cilium KPR → undefined routing states. ([docs.cilium.io][11])

---

## 6) CNI, LoadBalancer & Gateway

6.1 Install Cilium via Helm (module `cilium`)

- 6.1.1 Enable **kube-proxy replacement (strict)** + **socket LB**. ([docs.cilium.io][11])
- 6.1.2 Enable **LB IPAM** with pool `10.0.15.100–10.0.15.250`. ([docs.cilium.io][4])
- 6.1.3 Turn on **L2 Announcements** to expose `LoadBalancer` on flat LANs. ([docs.cilium.io][14])
- 6.1.4 Enable **WireGuard** encryption + **Hubble** + UI.
- 6.1.5 Enable **Gateway API** implementation in Cilium. ([docs.cilium.io][15])

  6.2 Optional: Traefik Gateway API fallback (off by default)

- 6.2.1 Install Gateway API CRDs (standard channel) if needed.
- 6.2.2 Deploy Traefik with Kubernetes Gateway provider & RBAC. ([Traefik Docs][16])

### Pitfalls (Step 6)

- KPR strict without meeting socket-LB assumptions can brick traffic; verify flags & kernel support. ([docs.cilium.io][11], [GitHub][17])
- L2 Announcements require flat L2 (gratuitous ARP visible) and a free IP pool. ([docs.cilium.io][14])

---

## 7) Argo CD & GitOps Structure

7.1 Deploy Argo CD (Helm)

- 7.1.1 Values to enable SSO (later), disable local admin only after SSO verified.
- 7.1.2 Expose via Gateway API (Cilium).

  7.2 App-of-Apps + ApplicationSets

- 7.2.1 Parent “root” Application (platform) → installs: Cilium (managed), cert-manager, external-dns, ESO, Longhorn, observability, Kyverno, (optional Traefik). ([Argo CD][18])
- 7.2.2 ApplicationSets: **Git directory generator** for apps, and **matrix** for future env/cluster fan-out. ([Argo CD][19])

### Pitfalls (Step 7)

- App-of-Apps is admin-powerful; restrict who can edit the parent app repo. ([Argo CD][18])
- Ordering: ensure CRDs (ESO, cert-manager) sync **before** dependents (sync waves/health checks).

---

## 8) Secrets: ESO + 1Password SDK

8.1 Install ESO + 1Password **SDK** provider

- 8.1.1 Create `SecretStore` referencing 1Password SDK service token & vault.
- 8.1.2 Create `ExternalSecret` objects for: Proxmox token, Cloudflare token/zone ID, MinIO keys, ArgoCD OIDC secret. ([external-secrets.io][6])

  8.2 Wire workloads to use K8s Secrets **materialized by ESO**

- 8.2.1 Argo CD values reference `${SECRET}` (mounted/generated by ESO).
- 8.2.2 cert-manager Issuer and external-dns values read from ESO-backed secrets.

### Pitfalls (Step 8)

- Mixing SOPS + ESO → confusion; stick to ESO-only to avoid double management.
- Wrong SDK token scope or vault name → SecretStore errors. ([external-secrets.io][6])

---

## 9) DNS, TLS & Certificates

9.1 cert-manager with Cloudflare DNS-01

- 9.1.1 Install cert-manager CRDs & controller.
- 9.1.2 Create ClusterIssuer using **Cloudflare API Token** (scoped to zone). ([cert-manager][20])

  9.2 external-dns (Cloudflare)

- 9.2.1 Configure provider = Cloudflare, zone ID(s), record TTL, and “proxied” behavior as desired. ([Kubernetes SIGs][21], [GitHub][22])

### Pitfalls (Step 9)

- Using global API key instead of token (over-privileged) → security risk. ([cert-manager][20])
- Setting CF records to “proxied” for services that need raw client IP can surprise you; choose per-hostname.

---

## 10) Storage: Longhorn

10.1 Deploy Longhorn via Argo

- 10.1.1 Ensure Talos image includes **iscsi** and **util-linux** extensions.
- 10.1.2 Configure default `StorageClass`; add worker data disk (200 GiB by default).

  10.2 Optional: Longhorn backups to MinIO

- 10.2.1 Set backup target to `s3://infraflux-longhorn` with MinIO creds from ESO.

### Pitfalls (Step 10)

- Missing `iscsid`/`iscsiadm` on hosts → volumes fail to attach. ([Longhorn][9])
- RWX needs NFS client on nodes (plan ahead if you’ll use RWX). ([Longhorn][9])

---

## 11) Observability & Policy

11.1 Monitoring & logs

- 11.1.1 Install **kube-prometheus-stack** (Prometheus/Grafana/Alertmanager).
- 11.1.2 Install **Loki + Promtail**; set **7-day** retention baseline.
- 11.1.3 Enable **Hubble UI**. ([docs.cilium.io][15])

  11.2 Security policies

- 11.2.1 Enable **PSA restricted** cluster-wide except `longhorn-system`.
- 11.2.2 Install **Kyverno** baseline policies (no priv-escalation, no hostPath, image tag pinning optional).

### Pitfalls (Step 11)

- Over-restrictive policies before platform components land → install loops; use sync waves & “soft-fail” first.

---

## 12) Ingress & Gateways

12.1 Primary: **Cilium Gateway API**

- 12.1.1 Create `GatewayClass`/`Gateway` and route objects for Argo CD, Grafana, Longhorn UI, etc. ([docs.cilium.io][15])

  12.2 Fallback: **Traefik** (toggle)

- 12.2.1 Only enable if needed; ensure Gateway API CRDs & RBAC for Traefik are present. ([Traefik Docs][16])

### Pitfalls (Step 12)

- Double controllers claiming the same GatewayClass → undefined routing.
- Mismatch between Gateway API version supported by controller vs CRDs. ([Traefik Docs][16])

---

## 13) SSO: Authentik → Argo CD & Kubernetes API

13.1 Argo CD OIDC

- 13.1.1 In Authentik: create application/provider & groups (`infraflux-admins`, `infraflux-readers`).
- 13.1.2 In Argo values: set OIDC issuer, client ID, client secret (from ESO).
- 13.1.3 Test SSO; **only then** disable local admin. ([integrations.goauthentik.io][23], [Argo CD][24])

  13.2 Kubernetes API OIDC

- 13.2.1 Configure kube-apiserver OIDC flags (issuer URL **HTTPS**, client ID, claim mappings).
- 13.2.2 Create RBAC bindings for groups; generate a time-boxed break-glass kubeconfig and store in 1Password. ([Kubernetes][25])

### Pitfalls (Step 13)

- Issuer URL not HTTPS or mismatch with `.well-known` → auth fails. ([Kubernetes][26])
- Disabling Argo admin before verifying OIDC → lockout risk. ([Argo CD][24])

---

## 14) Backups

14.1 **Velero → MinIO**

- 14.1.1 Install Velero server with S3 plugin; configure `BackupStorageLocation` targeting `infraflux-velero`.
- 14.1.2 Schedule regular backups; document restore drill. ([velero.io][5])

  14.2 etcd snapshots

- 14.2.1 Enable Talos automated etcd snapshots; export to MinIO if desired.

### Pitfalls (Step 14)

- Not testing restore → backups are Schrödinger’s safety net.
- Wrong MinIO credentials or bucket policy → silent backup failures. ([velero.io][27])

---

## 15) GitOps “Day-1” Platform Sync

15.1 Apply parent app (App-of-Apps)

- 15.1.1 Sync order: CRDs (cert-manager, ESO) → controllers → issuers/secretstores → consumers.
- 15.1.2 Verify health checks and sync waves are set to avoid “apply grenade.” ([Argo CD][18])

  15.2 Validate endpoints & certs

- 15.2.1 Confirm `*.binghzal.com` hostnames resolve via external-dns; certs issued via DNS-01. ([Kubernetes SIGs][21], [cert-manager][20])

### Pitfalls (Step 15)

- Missing DNS permissions at Cloudflare → external-dns log spam, no records. ([Kubernetes SIGs][21])
- cert-manager using CF **global API key** instead of token → over-privileged; prefer scoped token. ([cert-manager][20])

---

## 16) Acceptance Tests & Runbooks

16.1 Network/data-plane checks

- 16.1.1 `kubectl get nodes`, pods Ready; no CrashLoop in `kube-system`, `cilium`, `longhorn-system`.
- 16.1.2 Create a `LoadBalancer` Service; verify it receives an IP from `10.0.15.100–250` and is reachable on LAN (ARP shows up). ([docs.cilium.io][4])

  16.2 Ingress/TLS checks

- 16.2.1 Deploy a sample app with `HTTPRoute`; verify Gateway routes & TLS via cert-manager. ([docs.cilium.io][15])

  16.3 Storage checks

- 16.3.1 PVC/PV lifecycle, snapshot/restore via Longhorn UI/CRDs. ([Longhorn][9])

  16.4 Secrets checks

- 16.4.1 ESO pulls from 1Password; K8s Secrets materialize; Argo/CF tokens not in Git. ([external-secrets.io][6])

  16.5 Backups

- 16.5.1 Run a Velero backup, delete a namespace, restore it; confirm success. ([velero.io][5])

### Pitfalls (Step 16)

- Ignoring Cilium Hubble warnings → stealth datapath issues; check flows/metrics. ([docs.cilium.io][15])

---

## 17) Day-2 Ops & Upgrades (brief)

17.1 Version pinning & bumps

- 17.1.1 Track pinned versions for Talos, Cilium, Argo, cert-manager, ESO, Longhorn, external-dns; PR bumps with release notes links.

  17.2 Talos upgrades

- 17.2.1 Use Talos upgrade controller or rolling `talosctl upgrade` with drains; keep KPR flags intact. ([TALOS LINUX][13])

  17.3 Expand later

- 17.3.1 Multi-cluster fan-out: reuse ApplicationSets (matrix generator); add new Proxmox/metal targets as modules. ([Argo CD][28])

### Pitfalls (Step 17)

- Upgrading Cilium without preserving KPR settings → service regression. ([docs.cilium.io][11])

---

## Quick Reference (docs tied to key choices)

- **Proxmox provider (bpg)**: setup & auth. ([Terraform Registry][1], [GitHub][29])
- **Talos VIP & KubePrism**: HA API & in-cluster endpoint. ([TALOS LINUX][3])
- **Cilium KPR / LB IPAM / L2 Announcements / Gateway API**. ([docs.cilium.io][11])
- **Argo CD App-of-Apps & ApplicationSets**. ([Argo CD][18])
- **ESO + 1Password SDK**. ([external-secrets.io][6])
- **cert-manager DNS-01 (Cloudflare)** & **external-dns**. ([cert-manager][20], [Kubernetes SIGs][21])
- **Longhorn prerequisites on Talos**. ([Longhorn][9])
- **Velero with MinIO**. ([velero.io][5])
- **Traefik Gateway API provider** (fallback). ([Traefik Docs][16])
- **Kubernetes API OIDC flags** & Authentik→Argo integration. ([Kubernetes][25], [integrations.goauthentik.io][23])

---

If you want, I can drop this into a **GitHub-ready checklist** or spin out the **OpenAI-style coding-agent prompt + module stubs** next so you can start checking boxes and shipping YAML.

[1]: https://registry.terraform.io/providers/bpg/proxmox/0.6.2/docs?utm_source=chatgpt.com "Docs overview | bpg/proxmox - Terraform Registry"
[3]: https://www.talos.dev/v1.10/talos-guides/network/vip/?utm_source=chatgpt.com "Virtual (shared) IP"
[4]: https://docs.cilium.io/en/stable/network/lb-ipam.html?utm_source=chatgpt.com "LoadBalancer IP Address Management (LB IPAM)"
[5]: https://velero.io/docs/main/contributions/minio/?utm_source=chatgpt.com "Quick start evaluation install with Minio"
[6]: https://external-secrets.io/latest/provider/1password-sdk/?utm_source=chatgpt.com "1Password SDK - External Secrets Operator"
[7]: https://github.com/siderolabs/extensions?utm_source=chatgpt.com "siderolabs/extensions: Talos Linux System ..."
[8]: https://factory.talos.dev/?arch=amd64&board=undefined&cmdline-set=true&extensions=-&extensions=siderolabs%2Fiscsi-tools&extensions=siderolabs%2Fqemu-guest-agent&extensions=siderolabs%2Futil-linux-tools&platform=openstack&secureboot=undefined&target=cloud&version=1.8.2&utm_source=chatgpt.com "Schematic Ready - Image Factory - TALOS LINUX"
[9]: https://longhorn.io/docs/latest/deploy/install/?utm_source=chatgpt.com "Quick Installation - Longhorn | Documentation"
[10]: https://github.com/siderolabs/talos/issues/9852?utm_source=chatgpt.com "Inconsistent first boot with Proxmox #9852 - siderolabs/talos"
[11]: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free.html?utm_source=chatgpt.com "Kubernetes Without kube-proxy"
[12]: https://www.talos.dev/v1.10/kubernetes-guides/configuration/kubeprism/?utm_source=chatgpt.com "KubePrism"
[13]: https://www.talos.dev/v1.10/reference/cli/?utm_source=chatgpt.com "CLI"
[14]: https://docs.cilium.io/en/latest/network/l2-announcements.html?utm_source=chatgpt.com "L2 Announcements / L2 Aware LB (Beta)"
[15]: https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api.html?utm_source=chatgpt.com "Gateway API Support"
[16]: https://doc.traefik.io/traefik/providers/kubernetes-gateway/?utm_source=chatgpt.com "Traefik Kubernetes Gateway API Documentation"
[17]: https://github.com/cilium/cilium/issues/25201?utm_source=chatgpt.com "KubeProxyReplacement = Strict : Can't rollout cilium pods"
[18]: https://argo-cd.readthedocs.io/en/latest/operator-manual/cluster-bootstrapping/?utm_source=chatgpt.com "Cluster Bootstrapping - Declarative GitOps CD for Kubernetes"
[19]: https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/Generators-Git/?utm_source=chatgpt.com "Git Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[20]: https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/?utm_source=chatgpt.com "Cloudflare - cert-manager Documentation"
[21]: https://kubernetes-sigs.github.io/external-dns/v0.14.2/tutorials/cloudflare/?utm_source=chatgpt.com "Setting up ExternalDNS for Services on Cloudflare"
[22]: https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/cloudflare.md?utm_source=chatgpt.com "external-dns/docs/tutorials/cloudflare.md at master"
[23]: https://integrations.goauthentik.io/infrastructure/argocd/?utm_source=chatgpt.com "Integrate with ArgoCD | authentik"
[24]: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/?utm_source=chatgpt.com "Overview - Argo CD - Declarative GitOps CD for Kubernetes"
[25]: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/?utm_source=chatgpt.com "kube-apiserver"
[26]: https://kubernetes.io/docs/reference/access-authn-authz/authentication/?utm_source=chatgpt.com "Authenticating"
[27]: https://velero.io/docs/v1.1.0/api-types/backupstoragelocation/?utm_source=chatgpt.com "Backup Storage Location"
[28]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/?utm_source=chatgpt.com "Generators - Argo CD - Declarative GitOps CD for Kubernetes"
[29]: https://github.com/bpg/terraform-provider-proxmox?utm_source=chatgpt.com "Terraform / OpenTofu Provider for Proxmox VE"
