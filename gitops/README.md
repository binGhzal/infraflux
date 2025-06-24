# InfraFlux GitOps

This directory contains GitOps configurations for deploying essential Kubernetes services using FluxCD.

## Structure

- `bootstrap/` - FluxCD bootstrap configurations
  - `namespaces/` - Namespace definitions  
  - `helmrepositories/` - Helm repository sources
  - `kustomizations/` - FluxCD Kustomization resources
- `<service>/` - Individual service configurations
  - `helmrelease-<service>.yaml` - Helm release definition
  - `configmap-<service>-helm-chart-value-overrides.yaml` - Configuration values

## Services

1. **sealed-secrets** - Encrypted secrets management
2. **longhorn** - Distributed storage system  
3. **cert-manager** - SSL certificate management
4. **traefik** - Ingress controller and load balancer
5. **authentik** - Authentication and authorization
6. **kubernetes-dashboard** - Cluster management UI

## Deployment Order

Services deploy with proper dependencies:
1. sealed-secrets (foundation)
2. longhorn + cert-manager (parallel)
3. traefik (after storage/certs)
4. authentik + kubernetes-dashboard (after ingress)