# Bootstrap

High-level bootstrap sequence (fill details per environment):

1. terraform/00-proxmox-foundation: upload Talos image, networking, storage.
2. terraform/10-mgmt-talos: provision mgmt Talos cluster (kube-proxy disabled, CNI none).
3. terraform/20-capi-operator: install Cluster API Operator and providers (helm).
4. terraform/30-capmox: configure ProxmoxCluster + credentials/secrets.
5. terraform/40-clusters: define ClusterClass and templates (incl. MHC).
6. terraform/50-argo: install Argo CD and point to argo/apps (app-of-apps).

After Argo syncs:

- platform/\* add-ons roll out via Helm/Kustomize
- clusters/\* environments are reconciled by CAPI

Notes:

- Keep secrets encrypted with SOPS (platform/secrets)
- Use kubeconform CI to validate manifests
- Prefer Gateway API over Ingress where possible
