# ApplicationSet Patterns

This directory contains ArgoCD ApplicationSet definitions for common workload deployment patterns.

## Available Patterns

### Basic Workload Patterns (`workload-patterns.yaml`)

#### Web Applications

- **Generator**: Git directories (`apps/web/*`, `apps/frontend/*`)
- **Use Case**: Frontend applications, static sites, web services
- **Features**: Automatic namespace creation, environment-specific values

#### Microservices

- **Generator**: Git directories (`services/*/deploy`)
- **Use Case**: Microservice architectures with multiple services
- **Features**: Service-specific configuration, image tag parameterization

#### Database Applications

- **Generator**: Cluster + Git file matrix
- **Use Case**: Database deployments across environments
- **Features**: Bitnami charts, persistent storage, monitoring

### Advanced Patterns (`advanced-patterns.yaml`)

#### Environment Promotion

- **Generator**: Matrix (Applications × Environments)
- **Use Case**: Multi-environment deployments (dev/staging/prod)
- **Features**: Resource scaling per environment, cluster targeting

#### Helm Repositories

- **Generator**: Git files (`charts/*/Chart.yaml`)
- **Use Case**: Custom Helm chart deployments
- **Features**: Chart discovery, environment-specific values

#### Feature Branch Previews

- **Generator**: GitHub Pull Requests
- **Use Case**: Preview environments for feature branches
- **Features**: Automatic cleanup, dynamic ingress, PR labeling

## Usage

### 1. Deploy ApplicationSets

```bash
# Deploy all patterns
kubectl apply -f gitops/argocd/applicationsets/

# Deploy specific pattern
kubectl apply -f gitops/argocd/applicationsets/workload-patterns.yaml
```

### 2. Configure Your Repository Structure

For web applications:

```text
your-app-repo/
├── apps/
│   ├── web/
│   │   ├── frontend/
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   └── templates/
│   │   └── api/
│   │       ├── values.yaml
│   │       └── templates/
│   └── backend/
```

For microservices:

```text
microservices-repo/
├── services/
│   ├── user-service/
│   │   ├── deploy/
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   └── values-prod.yaml
│   └── order-service/
│       ├── deploy/
│       └── values-staging.yaml
```

### 3. Environment Configuration

Create environment-specific value files:

```yaml
# values-dev.yaml
replicaCount: 1
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
ingress:
  host: "app-dev.example.com"

# values-prod.yaml
replicaCount: 3
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
ingress:
  host: "app.example.com"
```

## Prerequisites

### Required ArgoCD Projects

```bash
# Create application project
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: applications
  namespace: argocd
spec:
  description: Application workloads
  sourceRepos:
  - 'https://github.com/your-org/*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

# Create preview project for feature branches
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: previews
  namespace: argocd
spec:
  description: Preview environments
  sourceRepos:
  - 'https://github.com/your-org/*'
  destinations:
  - namespace: 'preview-*'
    server: 'https://kubernetes.default.svc'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF
```

### GitHub Token (for PR previews)

```bash
kubectl create secret generic github-token \
  --from-literal=token=your-github-token \
  -n argocd
```

## Customization

### Adding New Patterns

1. Create new ApplicationSet in this directory
2. Define appropriate generators for your use case
3. Configure template with necessary parameters
4. Apply and test with sample applications

### Generator Types

- **Git**: Directory/file-based discovery
- **List**: Static list of parameters
- **Matrix**: Combination of multiple generators
- **Cluster**: Target multiple clusters
- **Pull Request**: GitHub/GitLab PR-based

### Best Practices

1. **Naming**: Use descriptive names with environment prefixes
2. **Projects**: Use separate projects for different application types
3. **Sync Policies**: Enable automated sync with self-heal
4. **Resource Management**: Use appropriate resource requests/limits
5. **Monitoring**: Enable ServiceMonitor for metrics collection
