output "kubeconfig" {
  description = "Raw kubeconfig after bootstrap"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Talos client configuration (talosconfig)"
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}
