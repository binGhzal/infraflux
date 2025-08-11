output "mgmt_kubeconfig" {
  description = "Kubeconfig for management cluster"
  value       = try(data.talos_cluster_kubeconfig.mgmt.kubeconfig, null)
}
