# Argo CD (Step 7)

This step installs Argo CD via Helm and optionally exposes it using Gateway API (via Cilium's controller).

## Design notes

- Keep service as ClusterIP and expose via Gateway/HTTPRoute for consistency with Gateway API-first approach.
- Defer SSO configuration to Step 13; placeholders are in values but OIDC is not active yet.

## Module wiring

- Terraform module: `terraform/modules/argocd`
- Enabled in `terraform/envs/prod/main.tf`

## Mermaid — component overview

```mermaid
flowchart LR
  subgraph cluster[Kubernetes Cluster]
    A[Argo CD Server (ClusterIP)]
    G[Gateway (cilium)] -->|HTTPS| A
  end
  U[User] -->|TLS| G
```

## Why this design (90s)

Argo CD is a control-plane component we want to reach via a consistent Gateway API. By installing via Helm and keeping service type ClusterIP, we decouple exposure concerns from the app. Cilium's Gateway API controller is already present, so we rely on Gateway/HTTPRoute rather than standalone Ingress. SSO is staged for later to avoid lockouts; once OIDC is wired through ESO and Authentik, we'll disable local admin.
