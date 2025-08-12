# Bootstrap Guide

This guide walks you through setting up InfraFlux from scratch using the fully automated single-node bootstrap approach.

## Prerequisites

- Proxmox VE 8.0+ cluster
- Talos Linux template configured in Proxmox
- OpenTofu/Terraform installed locally
- kubectl installed locally
- Network access to your Proxmox cluster

## Step 1: Prepare Talos Template

Create a Talos VM template in Proxmox:

1. Download Talos ISO from [Talos releases](https://github.com/siderolabs/talos/releases)
2. Create a VM in Proxmox with appropriate specs
3. Install Talos (minimal installation, no configuration needed)
4. Convert the VM to a template
5. Note the template VMID for later use

## Step 2: Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd infraflux

# Navigate to bootstrap module
cd terraform/bootstrap-talos

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific settings:

```hcl
# Proxmox connection
pm_api_url      = "https://your-proxmox:8006/api2/json"
pm_user         = "root@pam"
pm_password     = "your-password"

# VM placement
target_node     = "pve01"
datastore       = "local-lvm"
bridge          = "vmbr0"

# Template reference
talos_template_id = 9100  # Your Talos template VMID

# Network configuration
talos_cluster_endpoint = "10.0.0.100"  # IP where your VM will be accessible
talos_cluster_name     = "bootstrap-cluster"

# VM specifications
bootstrap_node_name = "talos-bootstrap"
cpu_cores          = 2
memory_mb          = 4096
disk_size_gb       = 40
```

## Step 3: Deploy Bootstrap Cluster

```bash
# Initialize Terraform
tofu init

# Review the plan
tofu plan

# Deploy (this will take 5-10 minutes)
tofu apply
```

This single command will:

1. **Create VM**: Clone Talos template and create the bootstrap VM
2. **Configure Talos**: Generate machine configuration and apply it
3. **Bootstrap Cluster**: Initialize single-node Kubernetes cluster
4. **Generate Access**: Create local kubeconfig file

## Step 4: Access Your Cluster

```bash
# Set kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Verify cluster is ready
kubectl get nodes
kubectl get pods -A
```

You should see your single Talos node in Ready state and system pods running.

## Step 5: Deploy GitOps Platform

```bash
# Return to project root
cd ../../

# Deploy ArgoCD
kubectl apply -k gitops/argocd/bootstrap/

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Step 6: Configure GitOps Applications

```bash
# Apply the app-of-apps pattern
kubectl apply -f gitops/argocd/bootstrap/app-of-apps.yaml

# Monitor deployment
kubectl get applications -n argocd -w
```

ArgoCD will now automatically deploy:

- Cluster API Operator and CAPMox provider
- Cilium (networking)
- cert-manager (TLS certificates)
- external-dns (DNS automation)
- Longhorn (storage)
- Monitoring stack (Prometheus, Grafana)
- Kubernetes Dashboard

## Step 7: Verify Platform Services

```bash
# Check all applications are synced
kubectl get applications -n argocd

# Verify core services
kubectl get pods -n kube-system      # Cilium
kubectl get pods -n cert-manager     # cert-manager
kubectl get pods -n longhorn-system  # Longhorn
kubectl get pods -n monitoring       # Prometheus/Grafana
```

## Step 8: Scale Your Cluster

Additional nodes are provisioned via Cluster API (no Terraform needed):

```bash
# Apply cluster scaling manifest
kubectl apply -f clusters/mgmt/additional-nodes.yaml

# Watch nodes join
kubectl get nodes -w
```

CAPMox will automatically:

- Provision VMs in Proxmox
- Configure Talos on new nodes
- Join them to the cluster

## Troubleshooting

### Bootstrap Issues

```bash
# Check Terraform output
tofu output

# Verify VM was created in Proxmox
# Check VM console for Talos boot process
```

### Cluster Issues

```bash
# Check cluster status
kubectl cluster-info

# Check system pods
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd
```

Your InfraFlux platform is now ready for production workloads!
