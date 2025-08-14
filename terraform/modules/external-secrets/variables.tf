variable "namespace" {
  description = "Namespace to install External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "helm_repo" {
  description = "Helm repository URL for External Secrets Operator"
  type        = string
  default     = "https://charts.external-secrets.io"
}

variable "helm_chart" {
  description = "Helm chart name"
  type        = string
  default     = "external-secrets"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "0.10.2"
}

variable "create_crds" {
  description = "Whether to install CRDs via Helm"
  type        = bool
  default     = true
}
