variable "namespace" {
  type        = string
  default     = "argocd"
  description = "Namespace where Argo CD is installed"
}

variable "root_app_name" {
  type        = string
  default     = "platform-root"
  description = "Name of the root Application"
}

variable "repo_url" {
  type        = string
  description = "Git repository URL containing the platform apps"
}

variable "revision" {
  type        = string
  default     = "main"
  description = "Git revision/branch"
}

variable "path" {
  type        = string
  default     = "old/gitops/applicationsets"
  description = "Path in the repo to sync (root manifests e.g., ApplicationSets)"
}
