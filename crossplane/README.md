# Crossplane Base

This folder contains pinned provider packages and minimal `ProviderConfig` placeholders.

- Secrets are referenced from the `crossplane-system` namespace and should be SOPS-encrypted.
- Example encrypted files with fake data are under `sops/` and end with `.enc.yaml`.
- Claims (e.g., `PostgresDatabase`) should live alongside application manifests or in
  a `claims/` folder per environment.
