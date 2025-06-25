# TODO: InfraFlux Refactoring Tasks
# - [x] Created version constraints file
# - [ ] Add provider version pinning
# - [ ] Add required Terraform version constraints

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  # Uncomment and configure for remote state management
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "infraflux/terraform.tfstate"
  #   region = "us-west-2"
  # }
}