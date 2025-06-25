# TODO: InfraFlux Refactoring Tasks
# - [ ] Consider using separate API tokens for different services
# - [ ] Add Cloudflare zone settings configuration (SSL, security, etc.)
# - [ ] Implement DNS record management for initial cluster setup

# Cloudflare Zone Data Source
data "cloudflare_zone" "main" {
  name = var.cloudflare_domain
}

# API Token for External-DNS
resource "cloudflare_api_token" "external_dns" {
  name = "external-dns-${var.cluster_name}"

  policy {
    permission_groups = [
      "c8fed203ed3043cba015a93ad1616f1f", # Zone:Zone:Read
      "4755a26eedb94da69e1066d98aa820be"  # Zone:DNS:Edit
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.main.id}" = "*"
    }
  }
}

# Output the API token for use in Kubernetes secret
output "cloudflare_api_token" {
  value       = cloudflare_api_token.external_dns.value
  sensitive   = true
  description = "Cloudflare API token for External-DNS"
}

# Output zone ID for reference
output "cloudflare_zone_id" {
  value       = data.cloudflare_zone.main.id
  description = "Cloudflare zone ID for the main domain"
}