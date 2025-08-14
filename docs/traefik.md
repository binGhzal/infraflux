# Traefik (optional) Gateway API

- Enables Kubernetes Gateway provider (experimental channel)
- Off by default; uncomment module in `terraform/envs/prod/main.tf` to enable

Verification:

- Traefik Deployment Ready in `traefik` namespace
- Gateway API resources recognized by Traefik when enabled
