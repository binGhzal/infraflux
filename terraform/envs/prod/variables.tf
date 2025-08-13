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
