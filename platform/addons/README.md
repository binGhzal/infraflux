# Platform: Add-ons

Cluster-wide services installed and managed via Flux Kustomizations and HelmReleases.

- Pin chart sources and versions via HelmRepository + HelmRelease
- Manage install order using dependsOn with healthChecks
- Keep namespaces under `bootstrap/namespaces/` (addon kustomizations should not create namespaces)

Included add-ons

- cert-manager: Jetstack controller for X.509 certs and ACME issuers

  - Files: `platform/addons/cert-manager/manifests/*`
  - Flux: `bootstrap/helmrepositories/helmrepository-jetstack.yaml`,
    `bootstrap/kustomizations/kustomization-cert-manager.yaml`
  - Notes: CRDs installed by HelmRelease (`installCRDs: true`). Configure ClusterIssuer/Issuer
    separately.

- ExternalDNS: Syncs Service/Ingress/Gateway routes to DNS providers

  - Files: `platform/addons/external-dns/manifests/*`
  - Flux: `bootstrap/helmrepositories/helmrepository-external-dns.yaml`,
    `bootstrap/kustomizations/kustomization-external-dns.yaml`
  - Notes: Default chart values use `provider: aws` as placeholder and `registry: txt`. Change
    `provider`, credentials, and RBAC for your environment. Common providers: route53, cloudflare,
    google, azure.

- External Secrets Operator (ESO): Syncs secrets from external stores into Kubernetes Secrets
  - Files: `platform/addons/external-secrets/manifests/*`
  - Flux: `bootstrap/helmrepositories/helmrepository-external-secrets.yaml`,
    `bootstrap/kustomizations/kustomization-external-secrets.yaml`
  - Notes: CRDs installed by HelmRelease. Add `ClusterSecretStore`/`SecretStore` + RBAC/credentials
    for your backend (AWS, GCP, Azure, Vault, 1Password, etc.).

Conventions

- Use the Flux 5-file pattern for app/operator installs
- Avoid mixing plain Kustomize with Flux Kustomization spec fields
- Keep provider credentials out of the repo; wire via External Secrets, SOPS, or a secure mechanism

Next candidates

- Sealed Secrets or SOPS, Velero, observability stack (Prometheus/Grafana/Loki/Tempo), Gatekeeper or
  Kyverno add-ons
