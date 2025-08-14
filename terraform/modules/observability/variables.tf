variable "monitoring_namespace" {
  type        = string
  description = "Namespace for kube-prometheus-stack"
  default     = "monitoring"
}

variable "logging_namespace" {
  type        = string
  description = "Namespace for Loki/Promtail"
  default     = "logging"
}

variable "kps_repo" {
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "kps_chart" {
  type        = string
  default     = "kube-prometheus-stack"
}

variable "kps_version" {
  type        = string
  default     = "62.7.0"
}

variable "loki_repo" {
  type        = string
  default     = "https://grafana.github.io/helm-charts"
}

variable "loki_chart" {
  type        = string
  default     = "loki"
}

variable "loki_version" {
  type        = string
  default     = "6.6.2"
}

variable "promtail_repo" {
  type        = string
  default     = "https://grafana.github.io/helm-charts"
}

variable "promtail_chart" {
  type        = string
  default     = "promtail"
}

variable "promtail_version" {
  type        = string
  default     = "6.16.6"
}
