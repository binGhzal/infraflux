# Architecture

```text
+--------------------+        Git (this repo)        +--------------------+
|  Developer/Agent   | ----------------------------> |   Flux Controllers |
+--------------------+   (mgmt cluster)               +--------------------+
        |
        | Kustomizations / HelmReleases
        v
+--------------------+
|     Workloads      |
|  (CAPI + Talos +   |
|  Cilium + Apps)    |
+--------------------+
```

## Layers

- Management: Flux, Cluster API core + providers (CAPA/CAPZ/CAPG/CAPMOX), optional Crossplane.
- Workload: CAPI-created clusters; Talos nodes; Cilium networking; Flux delivers recipes.

## Why this design

- Portability: CAPI abstracts provider details
- Determinism: Talos eliminates OS drift
- Simplicity: Cilium with kube-proxy replacement reduces moving parts
- GitOps: Flux reconciles application/infrastructure state from Git
