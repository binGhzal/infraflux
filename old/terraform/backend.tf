terraform {
  backend "s3" {
    bucket = "infraflux-tfstate" # create this bucket in MinIO
    key    = "k8s/infraflux/terraform.tfstate"
    region = "us-east-1"
    endpoints = {
      s3 = "http://10.0.0.49:9000"
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
    skip_metadata_api_check     = true
  }
}
