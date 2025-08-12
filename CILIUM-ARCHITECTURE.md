# InfraFlux - Unified Cilium Architecture

## Overview

InfraFlux has been architected around **Cilium** as the central nervous system, providing a unified platform for networking, security, and observability. This approach reduces complexity, improves performance, and minimizes breaking points by consolidating multiple functionalities under a single, eBPF-based solution.

## Cilium-Centric Architecture

### Core Principle: "One Tool, Multiple Capabilities"

Instead of deploying separate solutions for networking, security, service mesh, ingress, and observability, InfraFlux leverages Cilium's comprehensive feature set to unify the entire stack.

## Architecture Components

### 🔧 **Cilium Core** - The Foundation

- **CNI**: High-performance, eBPF-based networking
- **Service Mesh**: Sidecar-less service mesh using eBPF
- **Load Balancing**: L4/L7 load balancing with XDP acceleration
- **Ingress Controller**: Built-in Kubernetes ingress with Gateway API support
- **Network Policies**: L3/L4/L7 policy enforcement
- **Encryption**: WireGuard-based node-to-node encryption
- **BGP**: Advanced routing with BGP control plane

### 🔍 **Hubble** - Network Observability

- **Flow Monitoring**: Real-time network flow visibility
- **Service Map**: Automatic service dependency mapping
- **Metrics Export**: Prometheus-compatible metrics
- **Web UI**: Interactive network observability dashboard
- **Security Monitoring**: Network-based security insights

### 🛡️ **Tetragon** - Runtime Security

- **Process Monitoring**: eBPF-based process execution tracking
- **File Access Control**: File system access monitoring and enforcement
- **Network Security**: Runtime network behavior analysis
- **Policy Enforcement**: Real-time security policy enforcement
- **Security Observability**: Comprehensive security event logging

### 📊 **Monitoring Stack** - Cilium-Optimized

- **Prometheus**: Configured for Cilium/Hubble/Tetragon metrics
- **Grafana**: Pre-configured dashboards for Cilium ecosystem
- **AlertManager**: Cilium-specific alerting rules

## Benefits of the Unified Architecture

### 🚀 **Performance**

- **eBPF Efficiency**: In-kernel processing reduces overhead
- **XDP Acceleration**: Wire-speed packet processing for load balancing
- **No Sidecars**: Service mesh without proxy overhead
- **Single Data Plane**: Unified packet processing path

### 🔒 **Security**

- **Zero Trust Networking**: Identity-based security by default
- **Runtime Enforcement**: Real-time security policy enforcement
- **Encrypted Communication**: Transparent WireGuard encryption
- **Deep Visibility**: Complete network and process observability

### 🔄 **Operational Simplicity**

- **Unified Management**: Single control plane for multiple functions
- **Consistent Configuration**: Uniform policy and configuration model
- **Reduced Components**: Fewer moving parts, fewer failure points
- **Integrated Observability**: Built-in monitoring and troubleshooting

## Replaced Components

### What Cilium Replaces:

- ❌ **Traditional CNI plugins** → ✅ Cilium CNI
- ❌ **Separate ingress controllers** → ✅ Cilium Ingress
- ❌ **Service mesh sidecars (Istio/Linkerd)** → ✅ Cilium Service Mesh
- ❌ **External load balancers** → ✅ Cilium L4/L7 Load Balancing
- ❌ **Calico/Falco network policies** → ✅ Cilium Network Policies
- ❌ **Gatekeeper admission control** → ✅ Tetragon Runtime Enforcement
- ❌ **Separate observability tools** → ✅ Hubble + Tetragon

### What Remains:

- ✅ **External-DNS** (enhanced for Cilium integration)
- ✅ **Prometheus/Grafana** (optimized for Cilium metrics)
- ✅ **ArgoCD** (for GitOps deployment)
- ✅ **Longhorn** (for persistent storage)
- ✅ **Cert-Manager** (for TLS certificate management)

## Feature Matrix

| Capability               | Traditional Stack        | Cilium Unified Stack      |
| ------------------------ | ------------------------ | ------------------------- |
| **Networking**           | CNI Plugin               | Cilium CNI with eBPF      |
| **Service Mesh**         | Istio/Linkerd + Sidecars | Cilium sidecar-less mesh  |
| **Ingress**              | NGINX/Traefik            | Cilium Ingress Controller |
| **Load Balancing**       | Cloud LB + kube-proxy    | Cilium L4/L7 LB with XDP  |
| **Network Policies**     | Calico/PSP               | Cilium L3/L4/L7 Policies  |
| **Security Enforcement** | Gatekeeper + PSP         | Tetragon eBPF Enforcement |
| **Observability**        | Multiple tools           | Hubble + Tetragon         |
| **Encryption**           | Separate tool/manual     | Cilium WireGuard          |
| **Service Discovery**    | CoreDNS + external       | Cilium + CoreDNS          |

## Network Security Model

### Default Deny + Explicit Allow

```yaml
# Example: Default deny all traffic
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-all
spec:
  endpointSelector: {}
  egress: []
  ingress: []
```

### Layer 7 HTTP Policies

```yaml
# Example: L7 API security
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: api-security
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
    - toPorts:
        - ports:
            - port: "8080"
          rules:
            http:
              - method: "GET"
                path: "/api/v1/.*"
              - method: "POST"
                path: "/api/v1/users"
```

## Observability Stack

### Hubble Network Observability

- **Real-time Flow Monitoring**: Live network traffic analysis
- **Service Dependencies**: Automatic service map generation
- **Performance Metrics**: Latency, throughput, error rates
- **Security Events**: Policy violations and security incidents

### Tetragon Security Observability

- **Process Execution**: Complete process lifecycle tracking
- **File Access**: Detailed file system access logs
- **Network Behavior**: Runtime network security analysis
- **Compliance Reporting**: Security compliance and audit trails

## Deployment Workflow

### 1. Infrastructure Bootstrap

```bash
# Talos cluster with Cilium CNI
talos gen config infraflux-cluster https://cluster.infraflux.local:6443 \
  --config-patch-control-plane @cilium-patch.yaml
```

### 2. Cilium Installation

```bash
# Comprehensive Cilium installation
helm install cilium cilium/cilium \
  --namespace kube-system \
  --values cilium-values.yaml
```

### 3. Security Enforcement

```bash
# Deploy Tetragon for runtime security
kubectl apply -f tetragon-application.yaml
```

### 4. Network Policies

```bash
# Apply Cilium network policies
kubectl apply -f cilium-network-policies.yaml
```

## Monitoring and Alerting

### Key Metrics to Monitor

- **Cilium Agent Health**: `cilium_agent_status`
- **Network Policy Enforcement**: `cilium_policy_enforcement_status`
- **Service Mesh Performance**: `hubble_flows_processed_total`
- **Security Events**: `tetragon_events_total`
- **Load Balancing**: `cilium_loadbalancer_services`

### Critical Alerts

- Cilium agent down
- Network policy violations
- Tetragon security events
- Service mesh connectivity issues
- Load balancer failures

## Troubleshooting

### Network Issues

```bash
# Check Cilium status
cilium status

# Monitor network flows
hubble observe --namespace default

# Verify connectivity
cilium connectivity test
```

### Security Issues

```bash
# Check Tetragon events
kubectl logs -n kube-system ds/tetragon

# Review security policies
kubectl get ciliumnetworkpolicies

# Monitor security events
tetragon observe
```

## Migration Guide

### From Traditional Stack

1. **Assessment**: Audit current networking and security components
2. **Planning**: Map current features to Cilium capabilities
3. **Preparation**: Update manifests and configurations
4. **Migration**: Gradual rollout with traffic validation
5. **Cleanup**: Remove redundant components

### Compatibility Notes

- **External-DNS**: Configured to work with Cilium LoadBalancer services
- **Prometheus**: Enhanced with Cilium-specific metrics and alerts
- **Existing Workloads**: Transparent migration with zero downtime

## Future Enhancements

### Planned Features

- **Multi-cluster Service Mesh**: Cilium Cluster Mesh for cross-cluster connectivity
- **Advanced BGP**: Dynamic routing with BGP control plane
- **Bandwidth Management**: Traffic shaping and QoS policies
- **Enhanced Encryption**: Transparent encryption for all traffic

### Ecosystem Integration

- **ArgoCD**: Enhanced with Cilium-specific applications
- **Monitoring**: Expanded Cilium and Tetragon dashboards
- **CI/CD**: Integration with security policy validation

---

## Getting Started

1. **Review** the current implementation in `gitops/argocd/apps/`
2. **Deploy** Cilium with the unified configuration
3. **Apply** Tetragon for runtime security
4. **Configure** network policies for your workloads
5. **Monitor** with Hubble and enhanced Grafana dashboards

For detailed implementation, see the `gitops/` directory and the individual application configurations.
