# InfraFlux

A streamlined Kubernetes infrastructure platform using Talos, Cluster API, and GitOps for automated deployment and management.

## Architecture

**Fully Automated Bootstrap + GitOps Approach:**

- **Bootstrap**: Single Talos node with full automation (VM + cluster configuration)
- **Expansion**: Additional nodes via Cluster API (CAPMox) - no manual provisioning
- **Management**: All services deployed and managed via ArgoCD (GitOps)

This design minimizes manual intervention and embraces automation for scalable, maintainable infrastructure.

## Quick Start

### 1. Bootstrap Talos Cluster (Fully Automated)

```bash
cd terraform/bootstrap-talos
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox and network details
tofu init && tofu apply
```

This single command:

- Creates VM from Talos template
- Generates and applies Talos configuration
- Bootstraps single-node Kubernetes cluster
- Creates local kubeconfig for immediate access

### 2. Access Your Cluster

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

### 3. Deploy GitOps

```bash
# Apply ArgoCD bootstrap
kubectl apply -k gitops/argocd/bootstrap/

# Everything else deploys automatically via ArgoCD:
# - Cluster API Operator & CAPMox provider
# - Cilium, cert-manager, external-dns, monitoring
# - Additional cluster nodes via ClusterClass
```

## Components

### Core Infrastructure

- **Talos**: Immutable Kubernetes OS
- **Cluster API**: Declarative cluster management
- **CAPMox**: Proxmox provider for Cluster API
- **ArgoCD**: GitOps continuous deployment

### Platform Services

- **Cilium**: CNI and network policies
- **cert-manager**: TLS certificate automation
- **external-dns**: DNS record automation
- **Longhorn**: Distributed storage
- **Monitoring**: Prometheus, Grafana, Alertmanager

### Sync Waves & Dependencies

ArgoCD applications deploy in ordered sync waves:

- **Wave -1**: Cluster API providers (infrastructure foundation)
- **Wave 0**: Cilium (networking must be ready first)
- **Wave 1**: cert-manager (TLS for other services)
- **Wave 2**: external-dns, Longhorn (parallel deployment)
- **Wave 3**: Monitoring (depends on storage and networking)
- **Wave 4**: Dashboard (depends on all core services)

## Directory Structure

```text
├── terraform/bootstrap-talos/    # Single Talos node bootstrap
├── gitops/argocd/               # GitOps manifests
│   ├── apps/                    # Application definitions
│   ├── bootstrap/               # ArgoCD installation
│   └── values/                  # Helm values
├── clusters/                    # Cluster definitions
│   ├── mgmt/                    # Management cluster config
│   └── prod/                    # Production cluster config
├── secrets/                     # SOPS-encrypted secrets
└── docs/                        # Documentation
```

## Secrets Management

Secrets are encrypted using SOPS with age:

```bash
# Encrypt a secret
sops -e secrets/example.yaml > secrets/example.secret.yaml

# Edit encrypted secret
sops secrets/example.secret.yaml

# Decrypt for viewing
sops -d secrets/example.secret.yaml
```

See `secrets/README.md` for setup instructions.

## Development Workflow

1. **Infrastructure Changes**: Modify Cluster API manifests in `clusters/`
2. **Application Updates**: Update ArgoCD applications in `gitops/argocd/apps/`
3. **Configuration Changes**: Update Helm values in `gitops/argocd/values/`
4. **Secret Updates**: Use SOPS to encrypt secrets in `secrets/`

All changes are automatically deployed via GitOps - no manual kubectl commands needed.

## Cluster Expansion

Additional clusters are defined declaratively in `clusters/` and managed entirely through Cluster API. No additional Terraform required.

Example:

```bash
# Add a new cluster
kubectl apply -f clusters/prod/prod-cluster.yaml
```

CAPMox will automatically provision VMs and join them to the cluster based on the ClusterClass definition.

## Monitoring

Access the platform dashboard at `https://dashboard.yourdomain.com` (configured via external-dns and cert-manager).

- **Grafana**: Cluster and application metrics
- **Prometheus**: Metrics collection and alerting
- **ArgoCD**: GitOps deployment status
- **Kubernetes Dashboard**: Cluster resource management

## Contributing

1. All infrastructure is declared in Git
2. Changes are deployed via ArgoCD automatically
3. Use sync waves to manage deployment dependencies
4. Encrypt secrets with SOPS before committing
5. Test changes in a development cluster first

For detailed setup and configuration guides, see the `docs/` directory.
