# Step 9 — DNS, TLS, and Certificates

This doc covers installing cert-manager and external-dns via Argo CD, and wiring them to ESO-managed Cloudflare tokens.

## What we deploy

- cert-manager (Jetstack Helm chart)
- ClusterIssuer using Cloudflare DNS-01 solver
- external-dns (Helm chart) targeting Cloudflare

## Ordering & Sync Waves

- ExternalSecrets for Cloudflare tokens are annotated with sync-wave: -1
- cert-manager chart installs CRDs/controllers at wave 0
- ClusterIssuer applies at wave 1
- external-dns installs at wave 1

## Secrets via ESO

- Two K8s Secrets named `cloudflare-api-token` are created by ESO in namespaces `cert-manager` and `external-dns`.
- ExternalSecret remoteRef points to 1Password item: `infraflux-prod/Cloudflare external-dns token` (property `api_token`).

## Argo CD Application settings

- CreateNamespace=true for both apps
- Automated prune/selfHeal enabled

## Validation

- cert-manager: check Issuer Ready and certificate issuance
- external-dns: check logs for record creation/updates

## Troubleshooting

- If Issuer is Pending, ensure the ESO Secret exists in `cert-manager` namespace
- Ensure Cloudflare token has Zone.DNS:Edit scope for the target zone(s)
