# InfraFlux Restructuring Plan

## Current State → Target State Migration

### Repository Separation Strategy

#### Phase 1: Repository Restructure (Week 1-2)

**Current Mixed Repository:**

```
infraflux/
├── clusters/               # Infrastructure ✅ (Keep)
├── gitops/argocd/         # Platform 📦 (Move to separate repo)
├── terraform/             # Infrastructure ✅ (Keep & Enhance)
├── secrets/               # Mixed ⚠️ (Split)
└── docs/                  # Mixed ⚠️ (Split)
```

**Target Infrastructure Repository:**

```
infraflux/
├── terraform/
│   ├── modules/           # Reusable infrastructure modules
│   ├── environments/      # Environment-specific configurations
│   └── providers/         # Multi-cloud provider configurations
├── kubernetes/
│   ├── base/              # Base Kubernetes configurations
│   ├── overlays/          # Environment overlays
│   └── policies/          # Infrastructure security policies
├── clusters/
│   ├── templates/         # Cluster template definitions
│   ├── management/        # Management cluster configs
│   └── workloads/         # Workload cluster configs
├── configs/
│   ├── talos/             # Talos OS configurations
│   ├── environments/      # Environment-specific settings
│   └── defaults/          # Default configurations
├── scripts/
│   ├── bootstrap/         # Cluster bootstrap scripts
│   ├── validation/        # Infrastructure validation
│   └── automation/        # Infrastructure automation
└── docs/
    ├── infrastructure/    # Infrastructure documentation
    ├── configuration/     # Configuration guides
    └── operations/        # Operational procedures
```

### Component Migration Matrix

| Component              | Current Location                 | Target                    | Repository    | Action      |
| ---------------------- | -------------------------------- | ------------------------- | ------------- | ----------- |
| **Infrastructure**     |                                  |                           |               |
| Terraform modules      | `terraform/`                     | `terraform/modules/`      | InfraFlux     | Refactor    |
| Cluster definitions    | `clusters/`                      | `clusters/templates/`     | InfraFlux     | Enhance     |
| Talos configs          | Mixed                            | `configs/talos/`          | InfraFlux     | Consolidate |
| **Platform**           |                                  |                           |               |
| ArgoCD apps            | `gitops/argocd/`                 | `platform/argocd/`        | Platform Repo | Move        |
| Monitoring stack       | `gitops/argocd/apps/monitoring/` | `platform/observability/` | Platform Repo | Move        |
| Ingress configs        | `gitops/argocd/apps/*/`          | `platform/networking/`    | Platform Repo | Move        |
| **Mixed**              |                                  |                           |               |
| Infrastructure secrets | `secrets/`                       | `configs/secrets/`        | InfraFlux     | Keep        |
| Platform secrets       | `secrets/`                       | `secrets/`                | Platform Repo | Move        |
| Cilium CNI config      | `gitops/argocd/apps/cilium/`     | `kubernetes/base/cilium/` | InfraFlux     | Move        |
| Security policies      | `gitops/argocd/apps/security/`   | Split                     | Both          | Split       |

### Infrastructure-Only Components (Keep & Enhance)

#### 1. Core Infrastructure (Terraform)

```hcl
# terraform/modules/cluster/main.tf
module "proxmox_cluster" {
  source = "./modules/proxmox"

  cluster_name = var.cluster_name
  node_count = var.node_count
  node_config = var.node_config
  network_config = var.network_config
}

module "talos_bootstrap" {
  source = "./modules/talos"

  cluster_nodes = module.proxmox_cluster.nodes
  kubernetes_version = var.kubernetes_version
  cilium_config = var.cilium_config
}
```

#### 2. Kubernetes Base Configuration

```yaml
# kubernetes/base/cilium/values.yaml
cluster:
  name: "${CLUSTER_NAME}"
  id: "${CLUSTER_ID}"

ipam:
  mode: kubernetes

kubeProxyReplacement: "true"
k8sServiceHost: "${API_SERVER_IP}"
k8sServicePort: 6443

# Infrastructure-level configurations only
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: false # UI is platform concern

# Basic network policies for infrastructure
policyEnforcement: "default"
```

#### 3. Cluster Templates

```yaml
# clusters/templates/small/cluster.yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: "${CLUSTER_NAME}"
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.244.0.0/16"]
    services:
      cidrBlocks: ["10.96.0.0/12"]
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    kind: ProxmoxCluster
    name: "${CLUSTER_NAME}"
  controlPlaneRef:
    kind: TalosControlPlane
    apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
    name: "${CLUSTER_NAME}-control-plane"
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxCluster
metadata:
  name: "${CLUSTER_NAME}"
spec:
  controlPlaneEndpoint:
    host: "${CLUSTER_IP}"
    port: 6443
```

### Platform Components (Move to Platform Repo)

#### Platform Repository Structure

```
platform-gitops/
├── argocd/
│   ├── applications/      # Platform applications
│   ├── applicationsets/   # Multi-cluster application deployment
│   └── projects/         # ArgoCD projects
├── observability/
│   ├── prometheus/       # Metrics collection
│   ├── grafana/          # Visualization
│   └── loki/             # Log aggregation
├── networking/
│   ├── ingress/          # Application ingress
│   ├── service-mesh/     # Service mesh configuration
│   └── dns/              # DNS management
├── security/
│   ├── policies/         # Application security policies
│   ├── rbac/            # Role-based access control
│   └── secrets/         # Application secrets
├── storage/
│   ├── longhorn/        # Distributed storage
│   └── backup/          # Backup solutions
└── environments/
    ├── dev/             # Development configurations
    ├── staging/         # Staging configurations
    └── production/      # Production configurations
```

### Implementation Steps

#### Phase 1: Infrastructure Foundation (Weeks 1-2)

1. **Terraform Module Refactoring**

   ```bash
   # Create modular Terraform structure
   mkdir -p terraform/{modules,environments,providers}

   # Refactor existing terraform into modules
   mv terraform/main.tf terraform/modules/proxmox-cluster/

   # Create environment-specific configurations
   cp terraform/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
   ```

2. **Kubernetes Base Configuration**

   ```bash
   # Move Cilium from platform to infrastructure
   mkdir -p kubernetes/base/cilium
   mv gitops/argocd/apps/cilium/values.yaml kubernetes/base/cilium/

   # Create infrastructure overlays
   mkdir -p kubernetes/overlays/{dev,staging,prod}
   ```

3. **Configuration Management**

   ```bash
   # Centralize configurations
   mkdir -p configs/{talos,environments,defaults}

   # Create environment configurations
   touch configs/environments/{dev,staging,prod}.yaml
   ```

#### Phase 2: Platform Separation (Weeks 3-4)

1. **Create Platform Repository**

   ```bash
   # New repository: platform-gitops
   git init platform-gitops
   cd platform-gitops

   # Move platform components
   mkdir -p argocd observability networking security
   ```

2. **Move Platform Components**

   ```bash
   # Move ArgoCD applications (except infrastructure)
   mv ../infraflux/gitops/argocd/apps/monitoring ./observability/
   mv ../infraflux/gitops/argocd/apps/cert-manager ./networking/
   mv ../infraflux/gitops/argocd/apps/external-dns ./networking/
   ```

3. **Update GitOps Workflows**
   ```yaml
   # Platform repo ArgoCD application
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: infrastructure-cluster
   spec:
     source:
       repoURL: https://github.com/org/infraflux
       path: clusters/production
     destination:
       server: https://kubernetes.default.svc
   ```

#### Phase 3: Integration & Testing (Week 5-6)

1. **Infrastructure Output → Platform Input**

   ```yaml
   # Infrastructure outputs cluster info
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: cluster-info
   data:
     cluster-name: "prod-cluster"
     api-server: "https://prod-api.company.com:6443"
     cluster-ca: "LS0tLS..."
   ```

2. **Platform Cluster Registration**
   ```yaml
   # Platform registers with infrastructure clusters
   apiVersion: argoproj.io/v1alpha1
   kind: Cluster
   metadata:
     name: prod-cluster
   spec:
     server: "https://prod-api.company.com:6443"
     config:
       tlsClientConfig:
         caData: "LS0tLS..."
   ```

### Configuration Strategy

#### Environment-Specific Infrastructure

```yaml
# configs/environments/production.yaml
cluster:
  name: "prod-cluster"
  size: "large"
  version: "1.30.0"

compute:
  control_plane:
    count: 3
    cpu: 4
    memory: 8192
    disk: 100
  workers:
    count: 5
    cpu: 8
    memory: 16384
    disk: 200

networking:
  cilium:
    version: "1.16.0"
    encryption: true
    hubble: true
    bgp: true

security:
  pod_security_standards: "restricted"
  network_policies: "default-deny"
  encryption_at_rest: true
```

#### Terraform Variables

```hcl
# terraform/environments/prod/terraform.tfvars
cluster_config = {
  name = "prod-cluster"
  environment = "production"
  size = "large"
}

node_config = {
  control_plane = {
    count = 3
    cpu = 4
    memory = 8192
    disk = 100
  }
  workers = {
    count = 5
    cpu = 8
    memory = 16384
    disk = 200
  }
}

cilium_config = {
  version = "1.16.0"
  encryption = true
  hubble = true
  bgp = true
}
```

### Benefits of This Approach

1. **Clear Separation of Concerns**

   - Infrastructure: VM provisioning, OS, K8s, networking foundation
   - Platform: Applications, monitoring, ingress, policies

2. **Improved GitOps Workflows**

   - Infrastructure changes don't trigger platform redeployments
   - Platform changes don't affect infrastructure
   - Clear ownership and responsibilities

3. **Enhanced Reusability**

   - Infrastructure modules can be reused across organizations
   - Platform configurations can be applied to any InfraFlux cluster
   - Templates enable standardization

4. **Better Configuration Management**

   - Environment-specific infrastructure configurations
   - Hierarchical configuration inheritance
   - Clear configuration validation and testing

5. **Scalability & Maintenance**
   - Easier to onboard new team members
   - Simpler troubleshooting and debugging
   - Reduced blast radius for changes

This restructuring transforms InfraFlux into a true infrastructure platform while enabling flexible platform deployment through a separate GitOps repository.
