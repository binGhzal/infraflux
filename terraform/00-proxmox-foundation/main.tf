provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

locals {
  datastore      = var.datastore
  bridge         = var.bridge
  talos_template = var.talos_template
}

resource "null_resource" "upload_talos_image" {
  count = var.upload_talos_image ? 1 : 0

  provisioner "local-exec" {
    command = var.upload_talos_image_cmd
  }
}
