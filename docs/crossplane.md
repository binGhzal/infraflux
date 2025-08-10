# Crossplane

InfraFlux ships a minimal Crossplane skeleton you can opt into.

## Providers

Pinned provider packages live in `crossplane/base/`:

- AWS: `provider-aws.yaml`
- Azure: `provider-azure.yaml`
- GCP: `provider-gcp.yaml`

## ProviderConfig and Secrets

`crossplane/base/providerconfigs.yaml` defines `ProviderConfig` objects referencing Secrets.
Store credentials as SOPS-encrypted Secrets under `sops/`.

## Compositions and Claims

- Compositions live in `crossplane/compositions/`
- Example XR/XRD for Postgres are provided (AWS sample)
- A claim (e.g., `CompositePostgresInstance`) can be created in-cluster by apps

## Recipes integration

Recipes can depend on Crossplane-managed resources by waiting on secrets/config to appear.
Keep sensitive values in SOPS-encrypted Secrets and mount them at runtime.
