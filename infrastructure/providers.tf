provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure = true
  ssh {
    agent = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}