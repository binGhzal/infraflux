variable "namespace" {
  description = "Namespace to install Argo CD into"
  type        = string
  default     = "argocd"
}

variable "helm_repo" {
  description = "Helm repository for Argo CD"
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "helm_chart" {
  description = "Helm chart name"
  type        = string
  default     = "argo-cd"
}

variable "chart_version" {
  description = "Argo CD chart version"
  type        = string
  default     = "6.7.18"
}

variable "argocd_version" {
  description = "Argo CD image tag (controller/server version)"
  type        = string
  default     = "v2.11.4"
}

variable "enable_gateway" {
  description = "Whether to create Gateway/HTTPRoute to expose Argo CD"
  type        = bool
  default     = false
}

variable "gateway_class" {
  description = "GatewayClass name to use"
  type        = string
  default     = "cilium"
}

variable "gateway_name" {
  description = "Name of the Gateway resource"
  type        = string
  default     = "public"
}

variable "hostname" {
  description = "Hostname for Argo CD"
  type        = string
  default     = "argocd.binghzal.com"
}

variable "tls_secret_name" {
  description = "TLS secret name containing certificate for hostname"
  type        = string
  default     = "wildcard-binghzal-tls"
}

variable "enable_oidc" {
  description = "Enable OIDC configuration for Argo CD (expects secret 'argocd-secret' with key 'oidc.clientSecret')"
  type        = bool
  default     = false
}

variable "oidc" {
  description = "OIDC configuration values (issuer, clientID, requestedScopes/Claims). Client secret comes from K8s secret managed by ESO."
  type = object({
    issuer           = string
    client_id        = string
    requested_scopes = optional(list(string), ["openid", "profile", "email", "groups"])
    requested_claims = optional(map(any), {})
  })
  default = {
    issuer           = "https://auth.example.com/application/o/argocd/"
    client_id        = "argocd"
    requested_scopes = ["openid", "profile", "email", "groups"]
    requested_claims = {}
  }
}
