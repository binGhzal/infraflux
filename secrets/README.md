# Secrets Management

This directory contains example secret files for the InfraFlux platform.

## Required Secrets

### Age Key (SOPS Encryption)

```bash
# Generate age key
age-keygen -o age.key

# Export public key for .sops.yaml
export SOPS_AGE_KEY_FILE=age.key
```

Copy `sops-age.secret.example.yaml` to `sops-age.secret.yaml` and add your age key.

### External DNS (Optional)

If using external-dns with cloud providers, copy and encrypt your DNS provider credentials:

```bash
cp external-dns.secret.sops.example.yaml external-dns.secret.yaml
# Edit with your credentials
sops -e -i external-dns.secret.yaml
```

## Encryption

All secrets use SOPS with age encryption:

```bash
# Encrypt a secret
sops -e -i secret.yaml

# Edit an encrypted secret
sops secret.yaml

# Decrypt for viewing
sops -d secret.yaml
```

## GitOps Integration

Encrypted secrets are safe to commit to Git and will be automatically deployed by ArgoCD with the SOPS operator.
