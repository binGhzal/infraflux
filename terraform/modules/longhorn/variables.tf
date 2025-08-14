variable "namespace" {
  type        = string
  description = "Namespace for Longhorn"
  default     = "longhorn-system"
}

variable "helm_repo" {
  type        = string
  description = "Longhorn Helm repository URL"
  default     = "https://charts.longhorn.io"
}

variable "helm_chart" {
  type        = string
  description = "Longhorn Helm chart name"
  default     = "longhorn"
}

variable "chart_version" {
  type        = string
  description = "Longhorn chart version"
  default     = "1.7.2"
}

variable "backup_target" {
  type        = string
  description = "Optional backup target e.g., s3://infraflux-longhorn@us-east-1/"
  default     = null
}

variable "backup_credentials_secret" {
  type        = string
  description = "Optional secret name in longhorn namespace that contains S3 credentials for backups"
  default     = null
}
