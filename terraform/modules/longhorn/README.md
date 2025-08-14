# Longhorn (Terraform Helm)

Installs Longhorn via Helm. Optionally configures backups to an S3-compatible target (MinIO) by setting `backup_target` and providing `backupTargetCredentialSecret` via a Kubernetes Secret.

Inputs

- namespace (string) — default `longhorn-system`
- chart_version (string) — chart version, default `1.7.2`
- backup_target (string|null) — e.g., `s3://infraflux-longhorn@us-east-1/`
- backup_credentials_secret (string|null) — name of Secret in `longhorn-system` containing S3 creds

Notes

- Ensure Talos image includes iscsi and util-linux extensions per roadmap.
- For MinIO, use path-style and region like `us-east-1`.
- Credentials are managed via ESO in the platform layer; this module only references the Secret name.# Longhorn module (stub)

Installs Longhorn and default StorageClass.
