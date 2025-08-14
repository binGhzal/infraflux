# Traefik (optional) Gateway API controller

Deploy Traefik with Kubernetes Gateway provider enabled. Off by default.

Inputs:

- namespace (default traefik)
- chart_version

Notes:

- Intended as a fallback to Cilium Gateway API; do not enable both claiming same GatewayClass.
