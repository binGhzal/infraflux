output "talos_endpoint" {
  description = "Kubernetes API VIP endpoint"
  value       = "https://${var.controlplane_vip}:6443"
}
