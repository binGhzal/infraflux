# Argo CD Terraform Module

Installs Argo CD via Helm and optionally exposes it through the Gateway API (Cilium gateway class by default).

## Inputs

- namespace: Namespace to install Argo CD (default: argocd)
- helm_repo: Helm repo (default: argoproj/argo-helm)
- helm_chart: Chart name (default: argo-cd)
- chart_version: Chart version (default pinned)
- argocd_version: Container tag
- enable_gateway: Create Gateway/HTTPRoute if true
- gateway_class: GatewayClass name (default cilium)
- gateway_name: Gateway name (default public)
- hostname: External hostname (default argocd.binghzal.com)
- tls_secret_name: TLS secret for HTTPS termination

## Notes

- The module does not configure SSO. Step 13 will wire OIDC using External Secrets Operator.
- Service type is ClusterIP; exposure is handled by Gateway/HTTPRoute when enabled.
