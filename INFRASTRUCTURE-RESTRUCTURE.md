# InfraFlux Infrastructure Restructure Plan

## Vision: Pure Infrastructure Platform

InfraFlux will be restructured as a **pure infrastructure platform** that provides:

- Multi-cluster Kubernetes infrastructure
- Multi-environment support (dev/staging/prod)
- Platform infrastructure components (Cilium, monitoring, cert-manager)
- Handoff mechanism to application repos via GitOps

## Separation of Concerns

### InfraFlux Repository (Infrastructure)

- **Terraform**: Infrastructure provisioning (VMs, networks, storage)
- **Cluster Management**: Kubernetes cluster creation and lifecycle
- **Platform Infrastructure**: Core infrastructure components only
- **GitOps Bootstrap**: ArgoCD setup to manage platform and application repos

### PlatformNorthStar Repository (Applications)

- **Application Deployments**: All application workloads
- **Application GitOps**: Application-specific ArgoCD applications
- **Workload Configurations**: Application configurations and secrets
- **Service Deployments**: Business logic and services

## New Directory Structure

```text
infraflux/
├── terraform/
│   ├── modules/
│   │   ├── proxmox-vm/           # Reusable VM module
│   │   ├── talos-cluster/        # Talos cluster module
│   │   ├── cilium-config/        # Cilium infrastructure config
│   │   └── argocd-bootstrap/     # ArgoCD bootstrap module
│   ├── environments/
│   │   ├── dev/                  # Development environment
│   │   ├── staging/              # Staging environment
│   │   └── prod/                 # Production environment
│   └── globals/                  # Global configurations
├── clusters/
│   ├── templates/                # Cluster size templates
│   ├── base/                     # Base cluster configurations
│   └── overlays/                 # Environment-specific overlays
├── platform/
│   ├── infrastructure/           # Core infrastructure components
│   │   ├── cilium/               # Cilium CNI and features
│   │   ├── cert-manager/         # Certificate management
│   │   ├── monitoring/           # Infrastructure monitoring
│   │   └── argocd/               # GitOps platform
│   └── bootstrap/                # Bootstrap configurations
├── config/
│   ├── environments/             # Environment-specific configs
│   └── defaults/                 # Default configurations
├── scripts/
│   ├── deploy.sh                 # Deployment automation
│   ├── destroy.sh                # Cleanup automation
│   └── manage-cluster.sh         # Cluster management
└── docs/
    ├── quick-start.md            # Getting started guide
    ├── configuration.md          # Configuration guide
    └── architecture.md           # Architecture documentation
```

## Key Principles

1. **Everything Configurable**: All values externalized to config files
2. **Environment Isolation**: Complete separation between dev/staging/prod
3. **IaC Best Practices**: Immutable infrastructure, version control
4. **GitOps Native**: Infrastructure and platform managed through Git
5. **Multi-Cluster Ready**: Support for multiple clusters per environment
6. **Handoff Mechanism**: Clean handoff to application repos

## Implementation Plan

### Phase 1: Infrastructure Foundation

1. Create modular Terraform structure
2. Implement environment-specific configurations
3. Set up cluster templates and overlays
4. Create automation scripts

### Phase 2: Platform Infrastructure

1. Cilium base configuration
2. Monitoring infrastructure baseline
3. cert-manager setup
4. ArgoCD bootstrap configuration

### Phase 3: GitOps Integration

1. ArgoCD app-of-apps pattern
2. Integration with PlatformNorthStar repo
3. Environment-specific application deployment
4. Secret management integration

### Phase 4: Multi-Environment Support

1. Development environment setup
2. Staging environment configuration
3. Production environment hardening
4. Cross-environment promotion workflows

## Configuration Philosophy

- **Declarative**: Everything declared in configuration files
- **Version Controlled**: All configurations in Git
- **Environment Specific**: Clean separation of environment concerns
- **Composable**: Modular components that can be combined
- **Testable**: Infrastructure changes can be tested and validated

## Expected Outcomes

- **Time to Cluster**: < 15 minutes for any environment
- **Configuration Changes**: Simple variable updates
- **Environment Consistency**: Identical infrastructure across environments
- **Application Agnostic**: Clean separation from application concerns
- **Multi-Cluster Support**: Easy scaling to multiple clusters
