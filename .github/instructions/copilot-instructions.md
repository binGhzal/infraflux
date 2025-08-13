# Infraflux - Talos Kubernetes Platform

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

Infraflux is a comprehensive Kubernetes platform deployment project that creates a production-ready Talos Linux cluster on Proxmox infrastructure using Infrastructure as Code principles. The platform includes GitOps-managed components via ArgoCD for cert-manager, external-secrets, cilium networking, longhorn storage, velero backups, and more.

## Prerequisites and Tool Installation

Install required tools in this exact order:

```bash
# Install Terraform >= 1.6.0
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Install talosctl (Talos cluster management)
curl -sL https://talos.dev/install | sh

# Verify installations
terraform version    # Should show >= 1.6.0
talosctl version     # Should show >= 1.10.0
kubectl version --client  # Should be available
helm version         # Should be available
```

## Working Effectively

### Repository Structure
```
terraform/           # Infrastructure deployment (Proxmox VMs + Talos cluster)
├── providers.tf     # Terraform provider configurations
├── variables.tf     # All configurable variables
├── talos_cluster.tf # Talos cluster configuration and bootstrapping
├── proxmox_vms.tf   # VM definitions for control-plane and workers
├── helm_bootstrap.tf # Initial platform components (Cilium, ArgoCD)
└── templates/       # Helm values templates for bootstrap components

gitops/              # GitOps managed applications
├── argocd/          # ArgoCD root application configuration
└── apps/            # Platform applications (cert-manager, external-secrets, etc.)

image-factory/       # Talos custom image configuration
└── schematic.yaml   # Custom Talos image with system extensions
```

### Bootstrap and Validate

**CRITICAL TIMING NOTES:**
- terraform init: ~30 seconds - NEVER CANCEL
- terraform plan: ~1-2 seconds with variables  
- terraform apply: 45-60 minutes for full deployment - NEVER CANCEL. Set timeout to 90+ minutes.
- terraform validate: ~1 second
- yamllint gitops/: ~0.1 seconds

```bash
# Always start in terraform directory
cd terraform/

# Initialize Terraform (downloads providers)
terraform init
# Expected time: ~30 seconds

# Validate configuration syntax
terraform validate
# Expected time: ~1 second

# Format Terraform files
terraform fmt

# Check for formatting issues
terraform fmt -check
```

### Configuration Requirements

Create `terraform.tfvars` file from `infraflux.auto.tfvars.example`:

```bash
# Required minimum configuration
cp infraflux.auto.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values:
# - Proxmox connection details
# - Network configuration (VIP, CIDR ranges)
# - Domain names for ingress
# - Authentication provider details
```

**CRITICAL:** Do NOT commit sensitive values. Use actual infrastructure values for deployment.

### Deployment Workflow

```bash
# Plan infrastructure changes
terraform plan -var-file=terraform.tfvars
# Expected time: ~1-2 seconds

# Deploy infrastructure (FULL DEPLOYMENT)
terraform apply -var-file=terraform.tfvars
# Expected time: 45-60 minutes - NEVER CANCEL
# Sets timeout to 90+ minutes when deploying
```

**NEVER CANCEL BUILDS OR LONG-RUNNING COMMANDS**. Talos cluster bootstrapping takes 45+ minutes including VM creation, OS installation, cluster formation, and initial component deployment.

## Validation Without Infrastructure

These validation steps work without actual Proxmox infrastructure:

```bash
# Syntax and configuration validation
cd terraform/
terraform init      # Downloads providers (~30 seconds)
terraform validate  # Validates syntax (~1 second)  
terraform fmt       # Auto-formats code
terraform fmt -check # Checks formatting

# YAML validation
cd ../
yamllint --format github gitops/  # Lints all YAML files (~0.1 seconds)
```

## Validation With Infrastructure

These require actual Proxmox environment and credentials:

## Validation With Infrastructure

These require actual Proxmox environment and credentials:

#### Linting and Code Quality
```bash
# Terraform formatting and validation
cd terraform/
terraform fmt      # Auto-format files
terraform validate # Syntax validation (~1 second)

# YAML linting for GitOps files
cd ../
yamllint --format github gitops/   # Check all GitOps YAML files (~0.1 seconds)
# Note: Will show formatting warnings for missing document start markers
```

#### Post-Deployment Validation
After successful terraform apply:

```bash
# Check terraform outputs (VM IPs)
terraform output

# Verify cluster access
export KUBECONFIG=./kubeconfig
kubectl get nodes
kubectl get pods -A

# Check Talos cluster status  
talosctl --talosconfig=./talosconfig get members
talosctl --talosconfig=./talosconfig health

# Verify ArgoCD deployment
kubectl get applications -n argocd
kubectl get pods -n argocd
```

**Generated Files After Deployment:**
- `kubeconfig` - Kubernetes cluster access credentials
- `talosconfig` - Talos cluster management credentials  
- `.terraform/` - Terraform state and provider cache
- `terraform.tfstate` - Infrastructure state (DO NOT commit to git)

#### Manual Validation Scenarios
**ALWAYS** run these validation scenarios after making changes:

1. **Cluster Connectivity Test**: Access cluster via kubectl and verify all nodes are Ready
2. **Platform Components Test**: Verify ArgoCD is running and all apps are synced
3. **Network Test**: Verify Cilium CNI is operational (`kubectl get ciliumconfig`)
4. **Storage Test**: Verify Longhorn is available (`kubectl get storageclass`)

## Important Code Locations

### Critical Files to Monitor
- `terraform/variables.tf` - All configuration variables
- `terraform/talos_cluster.tf` - Cluster configuration and provider setup  
- `terraform/helm_bootstrap.tf` - Bootstrap component installations
- `gitops/argocd/root-app.yaml` - ArgoCD app-of-apps configuration
- `image-factory/schematic.yaml` - Talos custom image definition

### Provider Dependencies
The configuration uses these specific provider versions:
- proxmox (bpg/proxmox >= 0.57.0) - VM management
- talos (siderolabs/talos >= 0.8.0) - Talos cluster management  
- kubernetes (hashicorp/kubernetes >= 2.29.0) - K8s resource management
- helm (hashicorp/helm >= 2.12.1) - Helm chart deployments
- kubectl (gavinbunney/kubectl >= 1.14.0) - Raw K8s manifest deployment

### Common Issues and Solutions

**Terraform syntax errors:**
- Use multi-line format for variables with multiple attributes
- Proxmox provider expects empty `ipv4` block for DHCP (no explicit dhcp = true)
- Talos machine configurations use data sources, not resources
- Remove deprecated `enabled = true` from CDROM blocks (use `file_id` only)

**Talos configuration:**
- Machine configs use `data.talos_machine_configuration` data source
- Apply configs via `talos_machine_configuration_apply` resource with `machine_configuration_input`
- Kubeconfig via `talos_cluster_kubeconfig` resource
- Provider configurations reference kubeconfig attributes correctly

**GitOps applications:**
- All apps are ArgoCD Applications pointing to upstream Helm charts
- Automatic sync enabled with prune and self-heal
- Custom values passed through `helm.values` blocks

**Development workflow errors:**
- Always run `terraform fmt` before committing
- Never commit `terraform.tfstate` or sensitive `.tfvars` files
- Use `--format github` with yamllint for cleaner CI output

## Deployment Dependencies

**Infrastructure order:**
1. Proxmox VMs created
2. Talos machine configurations generated
3. Talos applied to VMs and cluster bootstrapped  
4. Kubernetes providers configured after cluster ready
5. Bootstrap components (Gateway API, Cilium, ArgoCD) deployed
6. ArgoCD takes over platform component management

**NEVER SKIP VALIDATION**: Always run terraform validate and test kubectl connectivity after any infrastructure changes.

## Platform Components

Post-bootstrap, ArgoCD manages these components:
- **Cilium** - CNI networking with L2 announcements and load balancing
- **cert-manager** - TLS certificate management
- **external-secrets** - 1Password integration for secret management  
- **external-dns** - Cloudflare DNS management
- **longhorn** - Distributed block storage
- **velero** - Cluster backup and disaster recovery
- **onepassword-sdk** - 1Password secret provider

Always verify component health via `kubectl get applications -n argocd` after cluster changes.