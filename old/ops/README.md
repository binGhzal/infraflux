# Infraflux Ops

## Prereqs

- Proxmox 8.4.1 node "pve" with storages: local (ISO), bigdisk (VM).
- Talos installer ISO built from Image Factory using image-factory/schematic.yaml, uploaded to local:iso/ as:
  talos-installer-<TALOS_VERSION>-<SCHEMATIC_ID>.iso
- DHCP reservations and DNS entries as needed.
- 1Password Service Account token (store as K8s secret `onepassword-service-account` in `external-secrets` ns).
- Cloudflare API token and zone prepared in 1Password.
- MinIO on Synology reachable at http://10.0.0.49:9000 with buckets: infraflux-velero, infraflux-longhorn.

## Deploy

```bash
cd terraform
cp infraflux.auto.tfvars.example infraflux.auto.tfvars
# Fill schematic_id, tokens, domains, etc.

# Export MinIO creds for Terraform backend:
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

terraform init
terraform apply -auto-approve
```

## Post-deploy

- Create K8s secret `onepassword-service-account` with the 1Password SA token:
  kubectl -n external-secrets create secret generic onepassword-service-account --from-literal=token=OP_SA_TOKEN
- Argo CD should sync the External Secrets and replace the stub OIDC secret.
- Create/verify DNS records via ExternalDNS; cert-manager should issue DNS-01 certificates.

## Verify

./ops/smoke.sh
