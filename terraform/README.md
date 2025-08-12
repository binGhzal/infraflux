# Bootstrap Talos Node

This module creates and fully configures a single Talos node for bootstrapping. It handles VM provisioning, Talos configuration, cluster bootstrapping, and kubeconfig generation automatically.

## Quick Start

1. **Configure your settings:**

   ```bash
   cd terraform/bootstrap-talos
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Proxmox and network details
   ```

2. **Deploy and configure the bootstrap cluster:**

   ```bash
   tofu init
   tofu apply
   ```

   This will:
   - Create the VM from your Talos template
   - Generate Talos machine configuration
   - Apply configuration to the node
   - Bootstrap the single-node cluster
   - Generate kubeconfig locally

3. **Use the cluster:**

   ```bash
   export KUBECONFIG=$(pwd)/kubeconfig
   kubectl get nodes
   ```

4. **Deploy GitOps** - ArgoCD will automatically manage additional nodes via Cluster API

## What This Module Does

- **VM Provisioning**: Clones Talos template and creates a single node
- **Talos Configuration**: Generates and applies machine configuration automatically
- **Cluster Bootstrap**: Initializes the Kubernetes cluster
- **Local Access**: Creates kubeconfig file for immediate cluster access
- **GitOps Ready**: Cluster is ready for ArgoCD deployment and Cluster API expansion

## Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `talos_cluster_endpoint` | IP address of the bootstrap node | ✓ |
| `bootstrap_node_name` | Name for the bootstrap node | No (default: "talos-bootstrap") |
| `talos_cluster_name` | Name of the Talos cluster | No (default: "talos-bootstrap") |
| `bootstrap_vmid` | Explicit VMID (auto-assigned if null) | No |
| `talos_template_id` | VMID of Talos template to clone | ✓ |
| `cpu_cores` | vCPU cores | No (default: 2) |
| `memory_mb` | Memory in MB | No (default: 4096) |
| `disk_size_gb` | Disk size in GB | No (default: 40) |
| `cluster_vip` | Optional VIP for HA | No (not needed for single node) |

## Outputs

- `kubeconfig_path`: Path to generated kubeconfig file
- `cluster_endpoint`: Kubernetes API server endpoint
- `talos_client_config`: Talos client configuration (sensitive)

## After Bootstrap

1. Export the kubeconfig: `export KUBECONFIG=$(tofu output -raw kubeconfig_path)`
2. Install ArgoCD using GitOps manifests
3. ArgoCD will deploy Cluster API and manage additional nodes automatically
4. Scale the cluster by applying ClusterClass manifests via GitOps

## Security

- Generated kubeconfig and talosconfig are gitignored
- Machine secrets are managed by Terraform state
- Use remote state backend for production deployments
