# Roadmap

This mirrors and expands on the top-level README with concrete deliverables, AC, and owners.

## Version Matrix (to be pinned per release branch)

- Kubernetes: 1.30–1.31
- CAPI Core: v1.7.x; Providers CAPA/CAPZ/CAPG/Proxmox/Metal3 pinned per env
- Talos: v1.7–v1.8
- Cilium: v1.15–v1.18 (Gateway API controller enabled)
- Flux: latest stable v2.x controllers

## Phase 1 — Core Automation (Weeks 1–3)

1. Bootstrap and Move

   - Deliverables: `hack/bootstrap.sh`, destroy.sh, docs
   - AC: one command creates kind, inits CAPI (+Talos providers), provisions Talos mgmt, moves, bootstraps Flux

2. Providers & Talos

   - Deliverables: `platform/capi/` provider manifests pinned, management cluster template(s)
   - AC: Create and delete a dev workload cluster from Git (Talos nodes)

3. GitOps Wiring

   - Deliverables: Flux Kustomizations with dependsOn + healthChecks, bootstrap repos/ks
   - AC: Namespaces + HelmRepositories applied before apps; podinfo deploys healthy

4. Cilium Base

   - Deliverables: `modules/networking/cilium/` HelmRelease; Gateway API enabled; Hubble UI/relay optional
   - AC: Cilium Ready; Gateway/Ingress route podinfo; cilium status healthy

5. Core Add-ons

   - Deliverables: cert-manager, ExternalDNS, Sealed Secrets, ESO, Velero, Observability base
   - AC: Valid certs, DNS automation, secret sync, nightly backups, dashboards

## Phase 2 — Modules (Weeks 4–6)

1. Alt Ingress/Gateway

   - Deliverables: Envoy Gateway and Ingress-NGINX modules (disabled)
   - AC: Flip via ClusterClass var without manual rewiring

2. Storage

   - Deliverables: Cloud CSI classes; Rook-Ceph for Proxmox/bare-metal
   - AC: PVCs provision; snapshots/restore validated

3. Cilium Feature Packs

   - Deliverables: BGP peering examples; EgressGateway; ClusterMesh; Tetragon policies
   - AC: Peer routes advertised; egress IP pinning; mesh service works; runtime alerts on test

## Phase 3 — Security (Weeks 7–9)

1. Multi-tenancy & RBAC

   - Deliverables: Flux impersonation, per-namespace SAs, NetworkPolicies
   - AC: Tenant isolation enforced; Git perms mapped

2. Policy Baselines

   - Deliverables: Gatekeeper/Kyverno constraints; CI policy checks
   - AC: Violations fail PRs; exemptions auditable

3. OIDC

   - Deliverables: Pinniped/Dex; oauth2-proxy example
   - AC: Cluster login via IdP; app protected

4. Secrets Rotation

   - Deliverables: Sealed Secrets key rotation doc; ESO backend auth rotation
   - AC: Rotation drill passes

## Phase 4 — Scale & Multi-cluster (Weeks 10–12)

1. Cluster Mesh

   - Deliverables: Mesh between envs; trust bootstrap automation
   - AC: Cross-cluster routing; isolation policies enforced

2. Fleet Sharding

   - Deliverables: Sharded Flux Kustomizations per tenant; tuned intervals
   - AC: Reconcile SLOs met under load

3. DR Drills

   - Deliverables: Scheduled Velero; restore docs; drills
   - AC: RTO/RPO targets met

4. Template Rotation

   - Deliverables: Documented ClusterClass template rotation procedures
   - AC: Safe rollouts across fleets

## Phase 5 — Optional Enhancements

- Crossplane compositions for managed services
- Cost and capacity dashboards
- Golden-path app templates with CI
