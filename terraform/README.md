# Terraform skeleton

Structure

- envs/prod: environment stack entrypoint
- modules/\*: platform modules (to be implemented)

Backend

- Use S3-compatible (MinIO). Supply credentials at runtime; do not commit secrets.

Init example (manual)

```sh
terraform init \
  -backend-config=../../backend.config.example
```
