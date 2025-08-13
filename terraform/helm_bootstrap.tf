# 6.1 Gateway API CRDs (Wiremind chart tracks upstream CRD versions)
resource "helm_release" "gateway_api_crds" {
  name       = "gateway-api-crds"
  repository = "https://charts.wiremind.io"
  chart      = "gateway-api-crds"
  version    = "1.3.0" # matches Gateway API v1.3.0
  namespace  = "kube-system"
  create_namespace = false
}

# 6.2 Cilium
data "template_file" "cilium_values" {
  template = file("${path.module}/templates/cilium-values.yaml.tftpl")
  vars = {
    kubeProxyReplacement = "strict"
    enableWireGuard      = var.enable_wireguard
    lbStart              = var.lb_ip_pool_start
    lbEnd                = var.lb_ip_pool_end
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"
  values     = [data.template_file.cilium_values.rendered]
  depends_on = [helm_release.gateway_api_crds]
}

# 6.3 Argo CD
data "template_file" "argocd_values" {
  template = file("${path.module}/templates/argocd-values.yaml.tftpl")
  vars = {
    baseDomain          = var.base_domain
    authentikIssuerURL  = var.authentik_issuer_url
    authentikClientID   = var.authentik_client_id
  }
}

resource "helm_release" "argocd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  namespace  = "argocd"
  create_namespace = true
  values     = [data.template_file.argocd_values.rendered]
}

# 6.4 Bootstrap root App (app-of-apps) so Argo CD manages platform
resource "kubectl_manifest" "root_app" {
  yaml_body = file("${path.module}/../gitops/argocd/root-app.yaml")
  depends_on = [helm_release.argocd]
}
