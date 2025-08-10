# AWS (CAPA)

## Credentials

- Create an IAM user or role with permissions for EC2, VPC, ELB/NLB, IAM (limited), Route53 (if using ExternalDNS).
- Store keys as a SOPS-encrypted Secret.

## Networking

- Recommended: dedicated VPC with public/private subnets and NAT if needed.
- Specify subnets, security groups, and load balancer type via the provider overlay.

## Overlays

- Edit `clusters/aws/values.example.yaml` and/or Kustomize literals in `clusters/aws/kustomization.yaml`:
  - instance types (`t3.medium`, `t3.large`, etc.)
  - region (`us-east-1`)
  - control plane/worker replicas
  - Kubernetes minor and Talos versions

## Notes

- Use EBS CSI if you want dynamic volumes; Longhorn is default and cloud-agnostic, but you may prefer managed CSI on AWS.
