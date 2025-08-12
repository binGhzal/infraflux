output "kubeconfig_raw" {
  description = "Raw kubeconfig content"
  value       = data.talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to saved kubeconfig file"
  value       = var.save_kubeconfig ? local_file.kubeconfig[0].filename : null
}

output "talos_config" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.cluster.talos_config
  sensitive   = true
}

output "talosconfig_path" {
  description = "Path to saved Talos config file"
  value       = var.save_talosconfig ? local_file.talosconfig[0].filename : null
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://${var.cluster_endpoint}:6443"
}

output "machine_secrets" {
  description = "Talos machine secrets (sensitive)"
  value       = talos_machine_secrets.cluster.machine_secrets
  sensitive   = true
}

output "controlplane_config" {
  description = "Control plane machine configuration"
  value       = data.talos_machine_configuration.controlplane.machine_configuration
  sensitive   = true
}

output "worker_config" {
  description = "Worker machine configuration (if workers exist)"
  value       = var.worker_count > 0 ? data.talos_machine_configuration.worker[0].machine_configuration : null
  sensitive   = true
}
