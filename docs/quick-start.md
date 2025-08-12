# InfraFlux - Quick Start Guide

## 🚀 Getting Started

This guide will help you deploy your first Kubernetes cluster with InfraFlux.

## Prerequisites

- **Proxmox VE** cluster with Talos template
- **Terraform/OpenTofu** installed
- **kubectl** installed
- **Helm** installed
- **Git** access to repositories

## Step 1: Clone Repository

```bash
git clone https://github.com/binGhzal/infraflux.git
cd infraflux
```

## Step 2: Configure Environment

### Development Environment (Recommended for first deployment)

```bash
# Edit development configuration
vim config/environments/dev.yaml

# Update Proxmox settings
vim terraform/environments/dev/terraform.tfvars.example
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Edit with your Proxmox details
vim terraform/environments/dev/terraform.tfvars
```

### Key Configuration Items

**Proxmox Settings** (`terraform/environments/dev/terraform.tfvars`):

```hcl
proxmox_api_url      = "https://your-proxmox:8006/api2/json"
proxmox_user         = "terraform@pve"
proxmox_password     = "your-password"
proxmox_node         = "your-node"
proxmox_storage      = "local-lvm"
```

**Network Settings** (`config/environments/dev.yaml`):

```yaml
network:
  subnet: "192.168.1.0/24"
  base_ip: "192.168.1."
  ip_start: 100
  gateway: "192.168.1.1"
```

## Step 3: Deploy Infrastructure

### Quick Deploy (Development)

```bash
# Deploy development environment
./scripts/deploy.sh -e dev
```

### Step-by-Step Deploy

```bash
# 1. Deploy infrastructure only
./scripts/deploy.sh -e dev --skip-platform

# 2. Check cluster is ready
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes

# 3. Deploy platform services
./scripts/deploy.sh -e dev --skip-terraform
```

### Using Platform Manager

```bash
# Deploy complete platform
./scripts/platform-manager.sh deploy -e dev

# Check status
./scripts/platform-manager.sh status -e dev

# Deploy only infrastructure
./scripts/platform-manager.sh deploy-infra -e dev
```

## Step 4: Verify Deployment

### Check Cluster Health

```bash
# Set kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Check nodes
kubectl get nodes

# Check platform services
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd
```

### Access Services

**ArgoCD UI:**

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access at: https://argocd.dev.platform.local
```

**Grafana:**

```bash
# Access at: https://grafana.dev.platform.local
# Default: admin/admin (change in production)
```

## Step 5: Deploy Applications

### Set up PlatformNorthStar

```bash
# Clone application repository
cd ..
git clone https://github.com/binGhzal/PlatformNorthStar.git
cd PlatformNorthStar

# Applications automatically deploy via ArgoCD
# Check deployment status
kubectl get applications -n argocd
```

## Environment Configuration

### Development

- **Purpose**: Development and testing
- **Size**: 1 control plane, 2 workers
- **Security**: Relaxed
- **Domain**: `dev.platform.local`

### Staging

- **Purpose**: Pre-production testing
- **Size**: 3 control plane, 2 workers
- **Security**: Standard
- **Domain**: `staging.platform.local`

### Production

- **Purpose**: Production workloads
- **Size**: 3 control plane, 5+ workers
- **Security**: Hardened
- **Domain**: `platform.company.com`

## Configuration Examples

### Custom Domain

**Update environment config** (`config/environments/prod.yaml`):

```yaml
environment:
  name: "prod"
  domain: "k8s.mycompany.com"
```

### Custom Cluster Size

**Update environment config** (`config/environments/prod.yaml`):

```yaml
clusterOverrides:
  nodes:
    controlPlane:
      count: 5
      cpu: 16
      memory: "32Gi"
    worker:
      count: 10
      cpu: 32
      memory: "64Gi"
```

### Enable Features

**Update environment config** (`config/environments/prod.yaml`):

```yaml
featureOverrides:
  ciliumMesh: true
  tetragon: true
  imageScanning: true
  costMonitoring: true
```

## Troubleshooting

### Common Issues

**1. Terraform fails:**

```bash
# Check Proxmox connectivity
curl -k https://your-proxmox:8006/api2/json/version

# Verify credentials
cd terraform/environments/dev
terraform init
terraform plan
```

**2. Cluster not accessible:**

```bash
# Check kubeconfig
ls -la kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Check cluster status
kubectl cluster-info
```

**3. ArgoCD not deploying:**

```bash
# Check ArgoCD status
kubectl get pods -n argocd

# Check applications
kubectl get applications -n argocd

# Force sync
argocd app sync platform-infrastructure
```

### Debug Commands

```bash
# Infrastructure logs
./scripts/platform-manager.sh status -e dev -v

# Cluster information
kubectl get events --sort-by=.metadata.creationTimestamp

# ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Platform service logs
kubectl logs -n kube-system -l app=cilium
kubectl logs -n cert-manager -l app=cert-manager
```

## Next Steps

1. **Customize Configuration**: Update environment configs for your needs
2. **Deploy Applications**: Use PlatformNorthStar for application workloads
3. **Set up Monitoring**: Configure Grafana dashboards and alerts
4. **Implement Security**: Update default passwords and certificates
5. **Scale Environment**: Add staging and production environments

## Useful Commands

```bash
# Quick deployment
./scripts/deploy.sh -e dev

# Platform management
./scripts/platform-manager.sh deploy -e prod
./scripts/platform-manager.sh status -e prod
./scripts/platform-manager.sh backup -e prod

# Environment promotion
./scripts/platform-manager.sh promote --from staging --to prod

# Dry run
./scripts/deploy.sh -e prod --dry-run
./scripts/platform-manager.sh deploy -e prod --dry-run
```

## Support

- **Documentation**: Check `docs/` directory
- **Issues**: GitHub issues for InfraFlux
- **Configuration**: Example files in each directory
- **Architecture**: See `ARCHITECTURE.md`

Happy building! 🚀
