# Secrets (SOPS & age)

InfraFlux uses **SOPS** with **age** recipients for secret encryption in Git.

## Setup

1. Generate a key:
   ```bash
   age-keygen -o sops/keys/agekey.txt
   Add the public key to sops/.sops.yaml under creation_rules.age.
   Usage
   Create a Kubernetes Secret manifest (do not commit plaintext).
   Run sops --encrypt --in-place my-secret.enc.yaml.
   Keep the *.enc.yaml file; the CI/runner or operator decrypts at apply time.
   Conventions
   Encrypted files must match sops/.sops.yaml rules.
   Store cloud provider creds here, never in plain YAML.
   ```

---

## `docs/crossplane.md`

```markdown
# Crossplane (optional)

Use Crossplane to model cloud resources (RDS, S3, Cloud DNS, etc.) as Kubernetes CRDs and reconcile them via GitOps.

## Base installation

`crossplane/base/` declares provider packages:

- `provider-aws`, `provider-azure`, `provider-gcp`

> The coding agent should pin tested versions and add `ProviderConfig` & creds (SOPS).

## Compositions

- `crossplane/compositions/` holds XRDs and provider-specific Compositions.
- Example: `XPostgresDatabase` + `Composition` for AWS RDS.

## Flow

1. Install provider(s) and set `ProviderConfig`.
2. Apply XRD + Composition(s).
3. Create Claim (e.g., `PostgresDatabase`) in the app namespace; Crossplane provisions per composition.
```
