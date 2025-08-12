variable "pm_api_url" {
  type = string
}

variable "pm_user" {
  type = string
}

variable "pm_password" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "mgmt"
}

variable "controlplane_ips" {
  type = list(string)
}

variable "worker_ips" {
  type    = list(string)
  default = []
}
