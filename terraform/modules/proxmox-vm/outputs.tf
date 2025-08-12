output "vm_names" {
  description = "Names of created VMs"
  value       = proxmox_vm_qemu.vm[*].name
}

output "vm_ids" {
  description = "VM IDs"
  value       = proxmox_vm_qemu.vm[*].vmid
}

output "vm_ips" {
  description = "VM IP addresses (when available)"
  value       = proxmox_vm_qemu.vm[*].default_ipv4_address
}

output "vm_objects" {
  description = "Full VM objects for advanced use"
  value       = proxmox_vm_qemu.vm
}
