# Cluster Configurations

This directory contains cluster definitions for different environments.

## Structure

- `mgmt/`: Management cluster configurations (Cluster API providers)
- `prod/`: Production cluster templates (deployed via Cluster API)

## Usage

These configurations are applied after the bootstrap cluster is running and Cluster API is deployed via GitOps.

```bash
# Apply management cluster configurations
kubectl apply -f mgmt/

# Deploy production clusters
kubectl apply -f prod/
```

## Notes

- The bootstrap cluster is created via Terraform in `terraform/`
- Additional clusters are managed declaratively via Cluster API
- All cluster configurations use the GitOps approach
