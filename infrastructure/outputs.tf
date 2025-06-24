# TODO: InfraFlux Refactoring Tasks
# - [x] Created comprehensive outputs for new structure
# - [ ] Add outputs for GitOps configuration
# - [ ] Add network-related outputs
# - [ ] Add security-related outputs

output "rke2_server_ips" {
  description = "IP addresses of RKE2 server nodes"
  value       = [
    for vm in proxmox_virtual_environment_vm.rke2_server :
    vm.ipv4_addresses[1][0]
  ]
}

output "rke2_agent_ips" {
  description = "IP addresses of RKE2 agent nodes"
  value       = [
    for vm in proxmox_virtual_environment_vm.rke2_agent :
    vm.ipv4_addresses[1][0]
  ]
}

output "rke2_cluster_endpoint" {
  description = "RKE2 cluster API endpoint (VIP)"
  value       = var.rke2_config.vip
}

output "external_endpoint" {
  description = "External endpoint for cluster access"
  value       = var.external_endpoint
}

output "vm_username" {
  description = "Username for VM access"
  value       = var.vm_username
}

output "cluster_info" {
  description = "Cluster information summary"
  value = {
    servers_count    = var.rke2_servers.count
    agents_count     = var.rke2_agents.count
    vip_address      = var.rke2_config.vip
    external_endpoint = var.external_endpoint
    rke2_version     = var.rke2_config.rke2_version
    metallb_range    = var.rke2_config.lb_range
  }
}