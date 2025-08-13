# Secrets Inventory & Mapping (ESO + 1Password SDK)

Scope: Define secret items and their mapping to Kubernetes Secrets via External Secrets Operator. Do not commit real values.

## 1) Secret sources in 1Password

Vault: `infraflux-prod` (example)

- proxmox/api-token
  - fields: token-id, token-secret, api-url
- cloudflare/api-token
  - fields: token, zone-id
- minio/credentials
  - fields: access-key, secret-key, endpoint, scheme
- argocd/oidc-client
  - fields: client-id, client-secret, issuer-url

## 2) SecretStore (cluster)

Example parameters (SDK provider):

- organization URL: `https://your.1password.com`
- service account token: stored in K8s Secret `op-sdk-token` in namespace `external-secrets` (data key `token`)
- vault: `infraflux-prod`

Kubernetes object names (suggested):

- Namespace: `external-secrets`
- SecretStore: `onepassword-sdk`

## 3) ExternalSecret objects (suggested names)

- `es-proxmox-provider-token` → Secret `proxmox-provider-token`
  - keys: `api_token`, `api_url`
- `es-cloudflare-credentials` → Secret `cloudflare-credentials`
  - keys: `api_token`, `zone_id`
- `es-minio-credentials` → Secret `minio-credentials`
  - keys: `access_key`, `secret_key`, `endpoint`, `scheme`
- `es-argocd-oidc` → Secret `argocd-oidc`
  - keys: `client_id`, `client_secret`, `issuer_url`

## 4) Consumption map (indicative)

- Terraform backend (S3/MinIO): access/secret via environment at runtime (runner), not stored in repo
- Helm values:
  - cert-manager Cloudflare DNS01: reference `cloudflare-credentials`
  - external-dns: reference `cloudflare-credentials`
  - Argo CD: `argocd-oidc` for SSO; disable local admin only after SSO verified
  - Velero: credentials secret matching provider plugin (if not using IRSA-like)

## 5) Notes & pitfalls

- Keep 1Password service account scoped to the single vault used by this cluster
- Prefer token-per-purpose (Cloudflare zones) with least privilege
- Avoid mixing SOPS and ESO to reduce double-management

## References

- External Secrets 1Password SDK: <https://external-secrets.io/latest/provider/1password-sdk/>
- cert-manager Cloudflare DNS-01: <https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/>
- ExternalDNS Cloudflare: <https://kubernetes-sigs.github.io/external-dns/latest/tutorials/cloudflare/>
