variable "project" {
  description = "Project name prefix for resources"
  type        = string
  default     = "infraflux"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "prod"
}

variable "kubeconfig" {
  description = "Path to kubeconfig file for the cluster (populated post-bootstrap)"
  type        = string
  default     = "../out/kubeconfig"
}

variable "enable_longhorn" {
  type        = bool
  description = "Enable Longhorn installation"
  default     = true
}

variable "longhorn_backup_target" {
  type        = string
  description = "Optional Longhorn backup target (e.g., s3://infraflux-longhorn@us-east-1/)"
  default     = null
}

variable "longhorn_backup_secret" {
  type        = string
  description = "K8s Secret name in longhorn-system with S3 creds for backups"
  default     = null
}

variable "enable_observability" {
  type        = bool
  description = "Install kube-prometheus-stack + Loki/Promtail"
  default     = false
}
