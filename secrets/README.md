# Secrets

Encrypted secrets live here. Use SOPS with age to encrypt any secret material.

1. Generate an age key and create the `sops-age` Kubernetes Secret (see `secrets/age/README.age.md`).
2. Copy `proxmox-credentials.sops.example.yaml` to `proxmox-credentials.sops.yaml` and replace placeholders.
3. Encrypt with `sops --encrypt proxmox-credentials.sops.yaml` before committing.
