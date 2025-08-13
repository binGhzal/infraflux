# Preflight & Foundations Checklist (Step 1)

Scope: Validate infra assumptions and prepare MinIO + 1Password to unblock Terraform, Talos, and GitOps. Do not proceed to image build until all items are green.

## 1) Proxmox prerequisites (v8.4.1)

- Node and fabric
  - [ ] Proxmox node name = `pve`
  - [ ] Storage: `local` (ISO) exists; `bigdisk` (VM disks) exists
  - [ ] Bridge `vmbr0` configured and reachable from LAN
- API token (least privilege) for Terraform
  - [ ] Create/verify root@pam API token (recommended for CI) with minimal privileges to create/clone VMs and read storages
  - [ ] Store token ID and secret in 1Password (not in Git)
  - [ ] Note API endpoint and realm (pam)
  - [ ] Validate provider auth precedence/envs (api_token > ticket/csrf > user/pass)
  - [ ] SSH access for guest agent power ops if required by modules
  - References: Terraform Registry bpg/proxmox, provider docs

## 2) DHCP reservations (UniFi)

- [ ] Create DHCP reservations for planned control-plane and worker nodes
- [ ] Keep VIP 10.0.1.50 free for Talos API virtual IP (VIP)
- [ ] Reserve 10.0.15.100–10.0.15.250 for Cilium LB IPAM pools (no overlapping DHCP scope)
- References: Talos VIP docs, Cilium LB IPAM docs

## 3) MinIO for state & backups (Synology)

- [ ] Deploy MinIO reachable from LAN (runner and cluster)
- [ ] Create buckets:
  - [ ] `infraflux-velero`
  - [ ] `infraflux-longhorn`
- [ ] Decide scheme and TLS:
  - [ ] http OR https with valid cert
  - [ ] If https, ensure CA trust for runners/controllers; expose `publicUrl` for Velero BSL
- [ ] Record endpoint (e.g., http(s)://10.0.0.49), access key, secret key in 1Password
- [ ] Networking: firewall allows GitHub runner to reach MinIO
- References: velero.io MinIO quickstart

## 4) 1Password for External Secrets Operator (ESO)

- [ ] Create 1Password service account dedicated to this cluster
- [ ] Create vault (e.g., `infraflux-prod`) and restrict scope to required items
- [ ] Record org URL for SDK provider (e.g., `https://your.1password.com`)
- [ ] Plan SecretStore and ExternalSecret mapping (see `docs/secrets.md`)
- References: external-secrets 1Password SDK provider

## Pitfalls (confirm mitigations)

- [ ] Proxmox token scope validated now to avoid late Terraform failures
- [ ] DHCP reservations in place to prevent node IP drift
- [ ] MinIO persistence and correct endpoint scheme (http/https) to avoid backend/init and Velero issues

## Quick validation commands (optional)

- Cilium LB IPAM/L2 readiness (post-cluster):
  - kubectl -n kube-system exec ds/cilium -- cilium-dbg config --all | grep KubeProxyReplacement
  - kubectl get ippools
- Talos VIP / bootstrap flow (post-provision):
  - talosctl config endpoint `VIP`
  - talosctl bootstrap; talosctl kubeconfig .

## Citations

- Proxmox provider (auth, tokens): Terraform Registry; provider GitHub docs
- Talos VIP & KubePrism: [Talos VIP](https://www.talos.dev/v1.10/talos-guides/network/vip/)
- Cilium KPR / LB IPAM / L2: [Cilium docs](https://docs.cilium.io/en/stable/)
- Velero with MinIO: [Velero MinIO quickstart](https://velero.io/docs/main/contributions/minio/)
- ESO 1Password SDK: [External Secrets 1Password SDK](https://external-secrets.io/latest/provider/1password-sdk/)
