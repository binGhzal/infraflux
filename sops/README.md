# SOPS & Age

- Encrypt Kubernetes Secret manifests using `sops` with age recipients.
- Place encrypted files alongside their unencrypted templates and suffix with `.enc.yaml`.
- Do **not** commit plaintext secrets.
