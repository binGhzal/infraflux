# Terraform repo & CI skeleton (Step 3)

This environment sets up a vanilla Terraform structure with MinIO (S3-compatible) backend and CI workflows.

Structure

- `terraform/envs/prod`: environment entrypoint (`main.tf`, `providers.tf`, `backend.tf`, `versions.tf`, `variables.tf`, `prod.auto.tfvars.example`)
- `terraform/modules/*`: module stubs to be implemented in following steps
- `.github/workflows`: `terraform-plan.yml` and `terraform-apply.yml`

Backend (MinIO)

- Copy `terraform/backend.config.example` to `terraform/backend.config` and adjust:
  - `endpoint`, `bucket`, `key`, `region`
  - Keep: `use_path_style = true`, `skip_credentials_validation = true`, `skip_requesting_account_id = true`, `skip_metadata_api_check = true`, `skip_region_validation = true`
- Provide credentials at runtime via env vars:
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT_URL_S3`

Local init/validate

- From `terraform/envs/prod` run:
  - `terraform init -backend=false`
  - `terraform validate`

CI secrets

- Configure repo secrets:
  - `MINIO_ACCESS_KEY_ID`
  - `MINIO_SECRET_ACCESS_KEY`
  - `MINIO_S3_ENDPOINT` (e.g., `https://minio.example.com`)

Apply workflow

- `terraform-apply.yml` is triggered manually with an `environment` input (e.g., `prod`).
- The job uses environment-protected secrets for MinIO; ensure the environment in GitHub has access to the above secrets.
- The workflow prefers `terraform/backend.config` if present; otherwise, it falls back to `terraform/backend.config.example`.
- Environment variables exported for S3 compatibility: `AWS_S3_FORCE_PATH_STYLE=true`, `AWS_EC2_METADATA_DISABLED=true`, `AWS_DEFAULT_REGION=us-east-1`.

Notes

- Proxmox, Helm, and Kubernetes providers are declared. Kubernetes/Helm will use `var.kubeconfig` once the cluster is bootstrapped in later steps.
- No secrets are committed; state backend config uses example file and env vars.
