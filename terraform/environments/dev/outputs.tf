output "cluster_info" {
  description = "Development cluster information"
  value = {
    name              = module.talos_cluster.cluster_endpoint
    kubeconfig_path   = module.talos_cluster.kubeconfig_path
    talosconfig_path  = module.talos_cluster.talosconfig_path
    controlplane_ips  = module.controlplane_vms.vm_ips
    controlplane_ids  = module.controlplane_vms.vm_ids
  }
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = module.talos_cluster.kubeconfig_path
}

output "connection_info" {
  description = "Connection information for the cluster"
  value = {
    kubectl_cmd = "export KUBECONFIG=${module.talos_cluster.kubeconfig_path}"
    talos_cmd   = "export TALOSCONFIG=${module.talos_cluster.talosconfig_path}"
  }
}
