# InfraFlux - Infrastructure Architecture

## Mission Statement

InfraFlux provides **production-ready Kubernetes clusters** as infrastructure, following GitOps and Infrastructure as Code principles. This repository focuses solely on the infrastructure layer, delivering secure, performant, and configurable Kubernetes clusters ready for platform and application deployment.

## Architecture Principles

### 1. **Infrastructure-Only Scope**

- VM/Container provisioning
- Operating system management (Talos)
- Kubernetes cluster installation and configuration
- Core networking (Cilium CNI)
- Cluster lifecycle management (CAPI)
- Infrastructure security policies

### 2. **Platform Boundary**

```
┌─────────────────────────────────────────────┐
│               INFRASTRUCTURE               │  ← InfraFlux Repo
│                                            │
│ Terraform → Talos → K8s → Cilium → CAPI   │
│                                            │
│ OUTPUT: Blank, production-ready clusters   │
└─────────────────────────────────────────────┘
                        │
                        ▼ kubeconfig
┌─────────────────────────────────────────────┐
│                PLATFORM                    │  ← Separate Platform Repo
│                                            │
│ ArgoCD → Apps → Monitoring → Security      │
└─────────────────────────────────────────────┘
```

### 3. **Configuration-Driven**

All infrastructure components are highly configurable through:

- Terraform variables (infrastructure layer)
- Helm values (Kubernetes components)
- Environment-specific overlays
- Modular, composable design

## Repository Structure

```
infraflux/
├── terraform/                    # Infrastructure as Code
│   ├── modules/
│   │   ├── proxmox-vm/          # VM provisioning module
│   │   ├── talos-cluster/       # Talos cluster module
│   │   └── networking/          # Network configuration
│   ├── environments/
│   │   ├── dev/                 # Development environment
│   │   ├── staging/             # Staging environment
│   │   └── prod/                # Production environment
│   └── main.tf                  # Root configuration
│
├── kubernetes/                   # Kubernetes configurations
│   ├── base/                    # Base configurations
│   │   ├── cilium/              # CNI configuration
│   │   ├── capi/                # Cluster API setup
│   │   └── policies/            # Base security policies
│   ├── overlays/                # Environment-specific overlays
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── kustomization.yaml
│
├── clusters/                     # Cluster definitions
│   ├── templates/               # Cluster templates
│   │   ├── small/               # Small cluster template
│   │   ├── medium/              # Medium cluster template
│   │   └── large/               # Large cluster template
│   ├── management/              # Management cluster config
│   └── workload/                # Workload cluster configs
│
├── scripts/                     # Automation scripts
│   ├── bootstrap.sh             # Cluster bootstrap
│   ├── generate-configs.sh      # Configuration generation
│   └── validation/              # Validation scripts
│
├── docs/                        # Documentation
│   ├── getting-started.md
│   ├── configuration.md
│   ├── cluster-templates.md
│   └── troubleshooting.md
│
├── .github/                     # CI/CD workflows
│   └── workflows/
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       └── cluster-validation.yml
│
└── configs/                     # Configuration files
    ├── talos/                   # Talos configurations
    ├── terraform.tfvars.example
    └── cluster-defaults.yaml
```

## Core Components

### 1. **Infrastructure Layer (Terraform)**

- **Proxmox Integration**: VM provisioning and management
- **Network Configuration**: VLANs, load balancers, DNS
- **Storage Setup**: Distributed storage configuration
- **Multi-environment**: Dev, staging, production

### 2. **Operating System (Talos)**

- **Immutable OS**: Security and predictability
- **API-driven**: Fully automated configuration
- **Container-optimized**: Minimal attack surface
- **Kubernetes-native**: Built for Kubernetes

### 3. **Kubernetes Base**

- **Cilium CNI**: High-performance networking
- **Security policies**: Pod security standards
- **RBAC**: Role-based access control
- **Network policies**: Zero-trust networking

### 4. **Cluster Management (CAPI)**

- **Cluster lifecycle**: Creation, scaling, upgrades
- **Multi-cluster**: Uniform management across environments
- **Provider abstraction**: Support for multiple infrastructure providers

## Configuration Strategy

### Environment-Specific Configuration

```yaml
# configs/environments/prod.yaml
environment: production
cluster:
  name: "prod-cluster"
  version: "1.30.0"
  nodes:
    control_plane: 3
    workers: 5
  resources:
    control_plane:
      cpu: 4
      memory: 8192
      disk: 100
    workers:
      cpu: 8
      memory: 16384
      disk: 200

networking:
  cilium:
    version: "1.16.0"
    features:
      encryption: true
      hubble: true
      bgp: true
      load_balancer: true

security:
  pod_security_standards: "restricted"
  network_policies: "default-deny"
  encryption_at_rest: true
```

### Modular Terraform Configuration

```hcl
# terraform/environments/prod/main.tf
module "infrastructure" {
  source = "../../modules/proxmox-infrastructure"

  cluster_name = var.cluster_name
  node_count = var.node_count
  node_specs = var.node_specs
  network_config = var.network_config
}

module "talos_cluster" {
  source = "../../modules/talos-cluster"

  nodes = module.infrastructure.nodes
  cluster_config = var.cluster_config
  cilium_config = var.cilium_config
}
```

## GitOps Integration

### Infrastructure → Platform Handoff

```yaml
# Output from InfraFlux (infrastructure)
apiVersion: v1
kind: Secret
metadata:
  name: cluster-access
  namespace: argocd
type: Opaque
data:
  kubeconfig: <base64-encoded-kubeconfig>
  cluster-info: <base64-encoded-cluster-metadata>
```

### Platform Repository Integration

```yaml
# Platform repo consumes InfraFlux clusters
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-stack
spec:
  source:
    repoURL: https://github.com/org/platform-gitops
    path: environments/prod
  destination:
    server: https://prod-cluster.company.com:6443 # From InfraFlux
```

## DevOps Best Practices

### 1. **Immutable Infrastructure**

- All changes through Git
- No manual cluster modifications
- Versioned infrastructure configurations

### 2. **Testing Strategy**

```yaml
# .github/workflows/infrastructure-validation.yml
on:
  pull_request:
    paths: ["terraform/**", "kubernetes/**"]

jobs:
  terraform-plan:
    - terraform plan
    - terraform validate
    - checkov security scan

  kubernetes-validation:
    - kubectl dry-run
    - kustomize build validation
    - policy validation
```

### 3. **Configuration Management**

- Environment-specific variables
- Secrets management (external secrets)
- Configuration validation
- Drift detection

### 4. **Monitoring & Observability**

- Infrastructure health checks
- Cluster validation scripts
- Automated testing pipelines
- Performance benchmarking

## Multi-Cluster Strategy

### Cluster Types

1. **Management Cluster**

   - CAPI controllers
   - Infrastructure monitoring
   - GitOps engines for infrastructure

2. **Workload Clusters**
   - Application hosting
   - Environment-specific (dev/staging/prod)
   - Auto-scaling capabilities

### Cross-Cluster Communication

- Cilium cluster mesh (infrastructure level)
- Service discovery
- Network policies
- Certificate management

## Success Metrics

- **Cluster Provisioning Time**: < 15 minutes for new cluster
- **Configuration Drift**: Zero manual changes
- **Infrastructure Updates**: Automated with rollback capability
- **Multi-Environment Consistency**: Identical infrastructure across environments
- **Developer Self-Service**: Teams can request clusters via Git

## Next Steps

1. **Restructure Current Repository**: Move platform components to separate repo
2. **Enhance Configuration System**: More granular, environment-specific configs
3. **Improve Terraform Modules**: Modular, reusable infrastructure components
4. **Add Multi-Provider Support**: AWS, Azure integration
5. **Implement Cluster Templates**: Standardized cluster definitions

This architecture provides a solid foundation for a multi-cluster Kubernetes operating system while maintaining clear boundaries and following DevOps best practices.
