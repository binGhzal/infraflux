# Gateway API CRDs first
resource "helm_release" "gateway_api_crds" {
  name             = "gateway-api-crds"
  repository       = "https://charts.wiremind.io"
  chart            = "gateway-api-crds"
  version          = "1.3.0"
  namespace        = "kube-system"
  create_namespace = false
}

locals {
  cilium_values = templatefile("${path.module}/templates/cilium-values.yaml.tftpl", {
    kubeProxyReplacement = "strict"
    enableWireGuard      = var.enable_wireguard
    lbStart              = var.lb_ip_pool_start
    lbEnd                = var.lb_ip_pool_end
  })

  argocd_values = templatefile("${path.module}/templates/argocd-values.yaml.tftpl", {
    baseDomain         = var.base_domain
    argocdHost         = var.argocd_hostname
    authentikIssuerURL = var.oidc_issuer_url
    authentikClientID  = var.oidc_client_id
  })
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"
  values     = [local.cilium_values]
  depends_on = [helm_release.gateway_api_crds]
}

# Argo CD

resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true
  values           = [local.argocd_values]
  timeout          = 600
}

# Seed the root app
resource "kubectl_manifest" "root_app" {
  yaml_body  = file("${path.module}/../gitops/argocd/root-app.yaml")
  depends_on = [helm_release.argocd]
}
