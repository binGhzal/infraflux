# Bootstrap Talos Node

This simplified module creates a single Talos node from a template for bootstrapping. All additional cluster nodes will be managed by Cluster API (CAPMox) through GitOps.

## Quick Start

1. **Configure your settings:**

   ```bash
   cd terraform/bootstrap-talos
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Proxmox details
   ```

2. **Deploy the bootstrap node:**

   ```bash
   tofu init
   tofu apply
   ```

3. **Configure Talos on the bootstrap node** (manual step - see Talos docs)

4. **Deploy GitOps stack** - ArgoCD will automatically manage:
   - Cluster API Operator
   - CAPMox provider and credentials
   - Additional cluster nodes via ClusterClass
   - All platform services (Cilium, cert-manager, etc.)

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `bootstrap_node_name` | Name for the bootstrap node | `"talos-bootstrap"` |
| `bootstrap_vmid` | Optional VMID (auto-assigned if null) | `null` |
| `talos_template_id` | VMID of Talos template to clone | Required |
| `cpu_cores` | vCPU cores | `2` |
| `memory_mb` | Memory in MB | `4096` |
| `disk_size_gb` | Disk size in GB | `40` |
| `iso_path` | Optional ISO to mount (format: storage:iso/file.iso) | `null` |

## After Bootstrap

Once your bootstrap node is running:

1. Configure Talos following the [Talos documentation](https://www.talos.dev/v1.8/introduction/getting-started/)
2. Install ArgoCD using the GitOps manifests in `gitops/argocd/`
3. ArgoCD will automatically deploy and manage all remaining infrastructure

This approach minimizes Terraform complexity and embraces GitOps for automated, declarative infrastructure management.
