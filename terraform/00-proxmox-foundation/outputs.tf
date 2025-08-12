output "talos_template" {
  description = "Name of the Talos VM template or image"
  value       = local.talos_template
}

output "datastore" {
  description = "Proxmox datastore used for templates and disks"
  value       = local.datastore
}

output "bridge" {
  description = "Network bridge for VM networking"
  value       = local.bridge
}
