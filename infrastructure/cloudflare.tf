# TODO: InfraFlux Refactoring Tasks
# - [ ] Consider using separate API tokens for different services
# - [ ] Add Cloudflare zone settings configuration (SSL, security, etc.)
# - [ ] Implement DNS record management for initial cluster setup

# Cloudflare Zone Data Source
data "cloudflare_zone" "main" {
  name = var.cloudflare_domain
}

# Output the existing API token for use in Kubernetes secret
output "cloudflare_api_token" {
  value       = var.cloudflare_api_token
  sensitive   = true
  description = "Cloudflare API token for External-DNS"
}

# Output zone ID for reference
output "cloudflare_zone_id" {
  value       = data.cloudflare_zone.main.id
  description = "Cloudflare zone ID for the main domain"
}