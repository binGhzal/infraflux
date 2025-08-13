output "controlplane_vm_ids" {
  description = "Control-plane VM IDs"
  value       = [for vm in proxmox_virtual_environment_vm.cp : vm.vm_id]
}

output "worker_vm_ids" {
  description = "Worker VM IDs"
  value       = [for vm in proxmox_virtual_environment_vm.worker : vm.vm_id]
}

# Best-effort IPs via QEMU agent; may be empty until guest agent reports
output "controlplane_ipv4" {
  description = "Control-plane IPv4 addresses per NIC index (first NIC index 0)"
  value       = [for idx, vm in proxmox_virtual_environment_vm.cp : try(vm.ipv4_addresses[0][0], null)]
}

output "worker_ipv4" {
  description = "Worker IPv4 addresses per NIC index (first NIC index 0)"
  value       = [for idx, vm in proxmox_virtual_environment_vm.worker : try(vm.ipv4_addresses[0][0], null)]
}

