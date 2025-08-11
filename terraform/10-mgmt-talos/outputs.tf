output "mgmt_kubeconfig" {
  description = "Kubeconfig for management cluster"
  value       = try(talos_cluster_kubeconfig.mgmt.kubeconfig_raw, null)
}
