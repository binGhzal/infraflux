# InfraFlux Cilium Ecosystem Implementation Plan

## Overview

This plan transforms InfraFlux from a traditional Kubernetes networking stack to a modern, unified Cilium-based ecosystem with automatic Cloudflare DNS integration. We're implementing this from scratch (no migration needed) to achieve:

- **Unified Networking**: Single eBPF-based solution replacing multiple components
- **Superior Performance**: 40Gbit/s throughput with reduced CPU usage
- **Advanced Observability**: Real-time network visibility with Hubble
- **Automatic DNS**: Cloudflare integration for seamless service discovery
- **Enhanced Security**: Kernel-level policies and transparent encryption

---

## Architecture Transformation

### Current Stack → Cilium Ecosystem

```
BEFORE                           AFTER
├── CNI: Canal/Calico           ├── CNI: Cilium (eBPF-based)
├── kube-proxy: iptables        ├── kube-proxy: Cilium eBPF replacement
├── Load Balancer: MetalLB      ├── Load Balancer: Cilium BGP
├── Ingress: Traefik           ├── Ingress: Cilium Gateway API
├── Service Mesh: None         ├── Service Mesh: Cilium (sidecar-less)
├── DNS: Manual               ├── DNS: External-DNS + Cloudflare
└── Observability: Basic      └── Observability: Hubble + Service Map
```

---

## Phase 1: Infrastructure Foundation

### Task 1.1: Terraform Infrastructure Updates

#### Subtask 1.1.1: Add Cloudflare Provider Configuration

**Purpose**: Enable Terraform to manage Cloudflare DNS resources automatically

**Implementation**:

```hcl
# File: infrastructure/providers.tf
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

**Variables to add**:

```hcl
variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_domain" {
  description = "Primary domain for cluster services (e.g., k8s.example.com)"
  type        = string
}
```

**Expected Outcome**: Terraform can manage Cloudflare DNS records and API tokens

#### Subtask 1.1.2: Create Cloudflare Zone and API Token Resources

**Purpose**: Automate DNS zone management and create secure API token for External-DNS

**Implementation**:

```hcl
# File: infrastructure/cloudflare.tf
data "cloudflare_zone" "main" {
  name = var.cloudflare_domain
}

resource "cloudflare_api_token" "external_dns" {
  name = "external-dns-${var.cluster_name}"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.permissions["Zone:Zone:Read"],
      data.cloudflare_api_token_permission_groups.all.permissions["Zone:DNS:Edit"]
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.main.zone_id}" = "*"
    }
  }
}

# Output API token for Kubernetes secret
output "cloudflare_api_token" {
  value     = cloudflare_api_token.external_dns.value
  sensitive = true
}
```

**Expected Outcome**: Secure API token created for External-DNS with minimal required permissions

#### Subtask 1.1.3: Update Variables for Cilium-Specific Networking

**Purpose**: Configure networking parameters optimized for Cilium eBPF

**Implementation**:

```hcl
# File: infrastructure/variables.tf
variable "cilium_config" {
  description = "Cilium-specific networking configuration"
  type = object({
    pod_cidr           = string
    service_cidr       = string
    bgp_asn           = number
    bgp_peer_asn      = number
    lb_ip_range       = string
    enable_bgp        = bool
    enable_encryption = bool
  })
  default = {
    pod_cidr           = "10.244.0.0/16"
    service_cidr       = "10.96.0.0/12"
    bgp_asn           = 65001
    bgp_peer_asn      = 65000
    lb_ip_range       = "192.168.3.80-192.168.3.90"
    enable_bgp        = true
    enable_encryption = true
  }
}
```

**Expected Outcome**: Networking configuration optimized for Cilium eBPF performance

#### Subtask 1.1.4: Configure Network Security Groups for BGP

**Purpose**: Ensure BGP traffic is allowed for Cilium load balancing

**Implementation**:

```hcl
# File: infrastructure/network.tf
# Update existing security group rules
resource "proxmox_vm_qemu" "rke2_servers" {
  # ... existing config ...

  # Additional network configuration for BGP
  network {
    model  = "virtio"
    bridge = var.network_config.bridge
    # Ensure BGP port 179 is accessible
  }
}
```

**Expected Outcome**: Network infrastructure ready for BGP peering and Cilium communication

### Task 1.2: RKE2 Configuration Overhaul

#### Subtask 1.2.1: Disable Default CNI (Canal/Calico)

**Purpose**: Prevent conflicts with Cilium by disabling default CNI

**Implementation**:

```yaml
# File: configuration/roles/rke2-prepare/templates/rke2-server-config.j2
# RKE2 Server Configuration
node-name: { { inventory_hostname } }
server: https://{{ vip }}:9345
token: { { rke2_token } }

# Disable default CNI - Cilium will be installed via GitOps
disable:
  - rke2-canal
  - rke2-coredns # Will use Cilium's DNS proxy

# Network configuration for Cilium
cluster-cidr: { { cilium_config.pod_cidr } }
service-cidr: { { cilium_config.service_cidr } }
```

**Expected Outcome**: RKE2 starts without CNI, ready for Cilium installation

#### Subtask 1.2.2: Disable kube-proxy Entirely

**Purpose**: Allow Cilium eBPF to handle all service load balancing

**Implementation**:

```yaml
# File: configuration/roles/rke2-prepare/templates/rke2-server-config.j2
disable:
  - rke2-canal
  - rke2-kube-proxy # Cilium will replace this entirely

# Configure for kube-proxy-free operation
kube-proxy-arg:
  - --proxy-mode=disabled
```

**Rationale**: Cilium's eBPF implementation is significantly faster than iptables-based kube-proxy

**Expected Outcome**: No kube-proxy running, all service handling via Cilium eBPF

#### Subtask 1.2.3: Configure Kernel Modules for eBPF

**Purpose**: Ensure optimal eBPF performance and required kernel features

**Implementation**:

```yaml
# File: configuration/roles/prepare-nodes/tasks/main.yaml
- name: Load required kernel modules for Cilium eBPF
  modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - br_netfilter
    - ip_tables
    - iptable_nat
    - xt_socket
    - xt_bpf
    - sch_bpf
  become: yes

- name: Configure sysctl for eBPF optimization
  sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    reload: yes
  loop:
    - { key: "net.core.bpf_jit_enable", value: "1" }
    - { key: "net.core.bpf_jit_kallsyms", value: "1" }
    - { key: "kernel.unprivileged_bpf_disabled", value: "1" }
  become: yes
```

**Expected Outcome**: Kernel optimized for eBPF performance and security

#### Subtask 1.2.4: Update Ansible Templates for Cilium Support

**Purpose**: Ensure all configuration templates support Cilium networking

**Implementation**:

```yaml
# File: configuration/roles/rke2-prepare/vars/main.yaml
cilium_required_ports:
  - { port: 4240, protocol: "tcp", description: "Cilium health checks" }
  - { port: 4244, protocol: "tcp", description: "Hubble server" }
  - { port: 4245, protocol: "tcp", description: "Hubble Relay" }
  - { port: 179, protocol: "tcp", description: "BGP" }
  - { port: 51871, protocol: "udp", description: "WireGuard encryption" }

# Update group vars template
# File: infrastructure/templates/ansible_group_vars.tpl
cilium_config:
  pod_cidr: "${cilium_config.pod_cidr}"
  service_cidr: "${cilium_config.service_cidr}"
  bgp_asn: ${cilium_config.bgp_asn}
  enable_bgp: ${cilium_config.enable_bgp}
  enable_encryption: ${cilium_config.enable_encryption}
```

**Expected Outcome**: All Ansible templates configured for Cilium ecosystem

---

## Phase 2: Core Cilium Deployment

### Task 2.1: Cilium Primary Installation

#### Subtask 2.1.1: Create Cilium GitOps Structure

**Purpose**: Organize Cilium configurations for GitOps deployment

**Implementation**:

```
/gitops/cilium/
├── namespace-cilium.yaml
├── helmrepository-cilium.yaml
├── helmrelease-cilium.yaml
├── configmap-cilium-config.yaml
└── bgp/
    ├── cilium-bgp-peering-policy.yaml
    └── cilium-load-balancer-ip-pool.yaml
```

**Files to create**:

```yaml
# namespace-cilium.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
  labels:
    name: kube-system
    pod-security.kubernetes.io/enforce: privileged

# helmrepository-cilium.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cilium
  namespace: flux-system
spec:
  interval: 1h
  url: https://helm.cilium.io/
```

**Expected Outcome**: Organized GitOps structure for Cilium deployment

#### Subtask 2.1.2: Configure HelmRelease with kube-proxy Replacement

**Purpose**: Deploy Cilium with complete kube-proxy replacement and eBPF optimization

**Implementation**:

```yaml
# File: gitops/cilium/helmrelease-cilium.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: cilium
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: cilium
      version: ">=1.14.0"
      sourceRef:
        kind: HelmRepository
        name: cilium
        namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: cilium-config
      valuesKey: values.yaml
  install:
    timeout: 10m
    remediation:
      retries: 3
  upgrade:
    timeout: 10m
    remediation:
      retries: 3
```

**Expected Outcome**: Cilium deployed with GitOps automation

#### Subtask 2.1.3: Enable BGP Control Plane

**Purpose**: Replace MetalLB with Cilium's native BGP load balancing

**Implementation**:

```yaml
# File: gitops/cilium/configmap-cilium-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
  namespace: flux-system
data:
  values.yaml: |
    # Complete kube-proxy replacement
    kubeProxyReplacement: "strict"

    # BGP Control Plane (replaces MetalLB)
    bgpControlPlane:
      enabled: true

    # Gateway API support (replaces Traefik)
    gatewayAPI:
      enabled: true

    # eBPF optimizations
    bpf:
      masquerade: true
      hostLegacyRouting: false

    # Performance features
    enableBandwidthManager: true
    enableLocalRedirectPolicy: true
    enableSocketLB: true

    # Direct routing for performance
    tunnel: disabled
    autoDirectNodeRoutes: true

    # Security
    encryption:
      enabled: true
      type: "wireguard"

    # Observability
    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
```

**Expected Outcome**: Cilium running with all advanced features enabled

#### Subtask 2.1.4: Configure eBPF Optimizations

**Purpose**: Maximize performance with eBPF kernel features

**Configuration Details**:

- **Socket-based Load Balancing**: Eliminates per-packet translation overhead
- **XDP Load Balancing**: Hardware-level packet processing
- **Direct Server Return**: Optimized traffic flow patterns
- **BPF Masquerading**: Efficient NAT in kernel space

**Expected Outcome**: Maximum network performance with eBPF acceleration

### Task 2.2: BGP Load Balancing Setup

#### Subtask 2.2.1: Create CiliumBGPPeeringPolicy

**Purpose**: Configure BGP peering to advertise LoadBalancer services

**Implementation**:

```yaml
# File: gitops/cilium/bgp/cilium-bgp-peering-policy.yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeeringPolicy
metadata:
  name: main-bgp-policy
spec:
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
  virtualRouters:
    - localASN: 65001
      exportPodCIDR: true
      serviceSelector:
        matchLabels: {} # All LoadBalancer services
      neighbors:
        - peerAddress: "192.168.3.1" # Gateway IP
          peerASN: 65000
          connectRetryTimeSeconds: 120
          holdTimeSeconds: 90
          keepAliveTimeSeconds: 30
        - peerAddress: "192.168.3.2" # Secondary gateway (if available)
          peerASN: 65000
```

**Expected Outcome**: BGP peering established with network infrastructure

#### Subtask 2.2.2: Configure LoadBalancer IP Pools

**Purpose**: Define IP ranges for LoadBalancer services

**Implementation**:

```yaml
# File: gitops/cilium/bgp/cilium-load-balancer-ip-pool.yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: main-pool
spec:
  cidrs:
    - cidr: "192.168.3.80/28" # 192.168.3.80-95
  serviceSelector:
    matchLabels: {} # All LoadBalancer services
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: critical-pool
spec:
  cidrs:
    - cidr: "192.168.3.96/28" # 192.168.3.96-111
  serviceSelector:
    matchLabels:
      priority: "critical"
```

**Expected Outcome**: Structured IP allocation for different service types

#### Subtask 2.2.3: Set up BGP Neighbor Relationships

**Purpose**: Establish reliable BGP peering with network infrastructure

**Configuration Steps**:

1. Verify BGP support on network switches/routers
2. Configure neighbor relationships on infrastructure side
3. Test BGP session establishment
4. Verify route advertisement

**Expected Outcome**: Stable BGP peering with automatic route advertisement

#### Subtask 2.2.4: Test BGP Route Advertisement

**Purpose**: Validate LoadBalancer IP accessibility from external network

**Testing Commands**:

```bash
# Check BGP sessions
kubectl exec -n kube-system ds/cilium -- cilium bgp peers

# Verify route advertisement
kubectl exec -n kube-system ds/cilium -- cilium bgp routes

# Test LoadBalancer service creation
kubectl create service loadbalancer test-lb --tcp=80:80
kubectl get svc test-lb -o wide
```

**Expected Outcome**: LoadBalancer IPs accessible from external network

---

## Phase 3: Gateway API & Ingress

### Task 3.1: Gateway API Implementation

#### Subtask 3.1.1: Enable Cilium Gateway API Support

**Purpose**: Replace Traefik with Cilium's native Gateway API implementation

**Implementation**: Gateway API support is enabled in Cilium configuration (Task 2.1.3)

**Additional Gateway API CRDs**:

```bash
# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v0.8.1/standard-install.yaml
```

**Expected Outcome**: Gateway API CRDs installed and Cilium Gateway controller active

#### Subtask 3.1.2: Create GatewayClass and Gateway Resources

**Purpose**: Define ingress infrastructure for all cluster services

**Implementation**:

```yaml
# File: gitops/gateway-api/gatewayclass.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: cilium
spec:
  controllerName: io.cilium/gateway-controller
---
# File: gitops/gateway-api/gateway-main.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: main-gateway
  namespace: cilium-gateway
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-tls
            kind: Secret
```

**Expected Outcome**: Gateway infrastructure ready for service routing

#### Subtask 3.1.3: Replace Traefik Configurations with HTTPRoutes

**Purpose**: Migrate all ingress configurations to Gateway API

**Example Migration**:

```yaml
# OLD: Traefik Ingress for Authentik
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: authentik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure

# NEW: Gateway API HTTPRoute for Authentik
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: authentik
  namespace: authentik
  annotations:
    external-dns.alpha.kubernetes.io/hostname: auth.yourdomain.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
spec:
  parentRefs:
  - name: main-gateway
    namespace: cilium-gateway
  hostnames:
  - auth.yourdomain.com
  rules:
  - backendRefs:
    - name: authentik
      port: 9000
      weight: 100
```

**Services to migrate**:

- Authentik (auth.domain.com)
- Kubernetes Dashboard (dashboard.domain.com)
- Hubble UI (hubble.domain.com)
- Longhorn UI (storage.domain.com)

**Expected Outcome**: All services accessible via Gateway API with automatic DNS

#### Subtask 3.1.4: Configure SSL Termination

**Purpose**: Automate SSL certificate management with cert-manager

**Implementation**:

```yaml
# File: gitops/cert-manager/clusterissuer-cloudflare.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cloudflare
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-cloudflare
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
        selector:
          dnsZones:
            - "yourdomain.com"
---
# Wildcard certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls
  namespace: cilium-gateway
spec:
  secretName: wildcard-tls
  issuerRef:
    name: letsencrypt-cloudflare
    kind: ClusterIssuer
  dnsNames:
    - "*.yourdomain.com"
    - "yourdomain.com"
```

**Expected Outcome**: Automatic SSL certificates for all services

---

## Phase 4: Observability with Hubble

### Task 4.1: Hubble Stack Deployment

#### Subtask 4.1.1: Enable Hubble in Cilium Configuration

**Purpose**: Activate comprehensive network observability

**Configuration**: Already enabled in Task 2.1.3 Cilium configuration

**Hubble Features**:

- **Flow Monitoring**: Real-time L3-L7 traffic visibility
- **Service Map**: Automatic service dependency discovery
- **Security Monitoring**: Policy violation tracking
- **Performance Metrics**: Latency and throughput analysis

**Expected Outcome**: Hubble server running on all nodes

#### Subtask 4.1.2: Deploy Hubble Relay for Cluster-wide Visibility

**Purpose**: Aggregate Hubble data across all cluster nodes

**Implementation**:

```yaml
# File: gitops/cilium/hubble/hubble-relay.yaml
# Hubble Relay configuration in main Cilium values
hubble:
  relay:
    enabled: true
    replicas: 2
    resources:
      requests:
        cpu: 100m
        memory: 64Mi
      limits:
        cpu: 1000m
        memory: 1Gi
    # Enable cluster-wide visibility
    listenAddress: ""
    peerService: "hubble-peer.kube-system.svc.cluster.local:443"
```

**Expected Outcome**: Centralized access to all cluster network flows

#### Subtask 4.1.3: Deploy Hubble UI with Ingress

**Purpose**: Provide web-based network visualization interface

**Implementation**:

```yaml
# File: gitops/cilium/hubble/hubble-ui-route.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: hubble-ui
  namespace: kube-system
  annotations:
    external-dns.alpha.kubernetes.io/hostname: hubble.yourdomain.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
spec:
  parentRefs:
    - name: main-gateway
      namespace: cilium-gateway
  hostnames:
    - hubble.yourdomain.com
  rules:
    - backendRefs:
        - name: hubble-ui
          port: 80
```

**Features Available**:

- Interactive service map
- Real-time flow visualization
- Security policy testing
- Network performance monitoring

**Expected Outcome**: Hubble UI accessible at hubble.yourdomain.com

#### Subtask 4.1.4: Configure Metrics Export to Prometheus

**Purpose**: Integrate Hubble metrics with monitoring stack

**Implementation**:

```yaml
# File: gitops/cilium/configmap-cilium-config.yaml (addition)
hubble:
  metrics:
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - icmp
      - http
  relay:
    prometheus:
      enabled: true
      port: 9965
```

**Metrics Available**:

- Network flow rates
- Protocol distribution
- Security policy violations
- Service response times
- Error rates and drops

**Expected Outcome**: Hubble metrics available in Prometheus

---

## Phase 5: DNS Automation

### Task 5.1: External-DNS with Cloudflare

#### Subtask 5.1.1: Deploy External-DNS with Cloudflare Provider

**Purpose**: Automate DNS record management for all services

**Implementation**:

```yaml
# File: gitops/external-dns/helmrelease-external-dns.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: external-dns
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: external-dns
      version: ">=1.13.0"
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: external-dns-config
      valuesKey: values.yaml
```

**Configuration**:

```yaml
# File: gitops/external-dns/configmap-external-dns-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: external-dns-config
  namespace: flux-system
data:
  values.yaml: |
    provider: cloudflare
    sources:
      - gateway-httproute  # Gateway API support
      - gateway-grpcroute
      - service
      - ingress

    cloudflare:
      proxied: true  # Enable CDN/DDoS protection

    domainFilters:
      - yourdomain.com

    policy: sync
    registry: txt
    txtOwnerId: "infraflux-k8s"

    env:
      - name: CF_API_TOKEN
        valueFrom:
          secretKeyRef:
            name: cloudflare-api-token
            key: api-token
```

**Expected Outcome**: External-DNS automatically managing Cloudflare records

#### Subtask 5.1.2: Configure SealedSecret for Cloudflare API Token

**Purpose**: Securely store Cloudflare API token in Git

**Implementation**:

```bash
# Create secret (run locally)
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token="YOUR_CLOUDFLARE_API_TOKEN" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > gitops/external-dns/sealedsecret-cloudflare-api-token.yaml
```

**SealedSecret Structure**:

```yaml
# File: gitops/external-dns/sealedsecret-cloudflare-api-token.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: cloudflare-api-token
  namespace: external-dns
spec:
  encryptedData:
    api-token: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
  template:
    metadata:
      name: cloudflare-api-token
      namespace: external-dns
```

**Expected Outcome**: Secure API token storage in Git repository

#### Subtask 5.1.3: Update All Services with DNS Annotations

**Purpose**: Enable automatic DNS record creation for all services

**Annotation Pattern**:

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: service.yourdomain.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    external-dns.alpha.kubernetes.io/ttl: "120"
```

**Services to Update**:

- Authentik: `auth.yourdomain.com`
- Dashboard: `dashboard.yourdomain.com`
- Hubble: `hubble.yourdomain.com`
- Longhorn: `storage.yourdomain.com`

**Expected Outcome**: All services automatically get DNS records

#### Subtask 5.1.4: Enable Cloudflare Proxy Features

**Purpose**: Leverage Cloudflare CDN, DDoS protection, and WAF

**Features Enabled**:

- **CDN**: Global content delivery network
- **DDoS Protection**: Automatic attack mitigation
- **SSL/TLS**: Cloudflare SSL with Full (Strict) mode
- **WAF**: Web Application Firewall rules
- **Rate Limiting**: API protection

**Configuration**:

```yaml
# Additional annotations for advanced features
external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
external-dns.alpha.kubernetes.io/cloudflare-origin-direct: "true"
```

**Expected Outcome**: Enterprise-grade edge protection for all services

---

## Phase 6: Service Migration

### Task 6.1: Update Existing Services

#### Subtask 6.1.1: Migrate Authentik to Gateway API

**Purpose**: Move Authentik from Traefik Ingress to Cilium Gateway API

**Implementation**:

```yaml
# File: gitops/authentik/httproute-authentik.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: authentik
  namespace: authentik
  annotations:
    external-dns.alpha.kubernetes.io/hostname: auth.yourdomain.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
spec:
  parentRefs:
    - name: main-gateway
      namespace: cilium-gateway
  hostnames:
    - auth.yourdomain.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: authentik
          port: 9000
          weight: 100
```

**Remove**: Old Traefik ingress configurations

**Expected Outcome**: Authentik accessible via Gateway API with automatic DNS

#### Subtask 6.1.2: Update Kubernetes Dashboard Configuration

**Purpose**: Configure dashboard with enhanced security via Cilium policies

**Implementation**:

```yaml
# File: gitops/kubernetes-dashboard/httproute-dashboard.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  annotations:
    external-dns.alpha.kubernetes.io/hostname: dashboard.yourdomain.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
spec:
  parentRefs:
    - name: main-gateway
      namespace: cilium-gateway
  hostnames:
    - dashboard.yourdomain.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: kubernetes-dashboard-kong-proxy
          port: 8443
```

**Security Policy**:

```yaml
# File: gitops/kubernetes-dashboard/cilium-network-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: dashboard-security
  namespace: kubernetes-dashboard
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: kubernetes-dashboard
  ingress:
    - fromEndpoints:
        - matchLabels:
            io.cilium.k8s.policy.cluster: default
            io.cilium.k8s.policy.serviceaccount: cilium-gateway
      toPorts:
        - ports:
            - port: "8443"
              protocol: TCP
          rules:
            http:
              - method: "GET"
              - method: "POST"
                headers:
                  - "Content-Type: application/json"
```

**Expected Outcome**: Secure dashboard access with L7 network policies

#### Subtask 6.1.3: Configure Longhorn with Cilium Networking

**Purpose**: Ensure storage system works optimally with Cilium

**Network Policy**:

```yaml
# File: gitops/longhorn/cilium-network-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: longhorn-system
  namespace: longhorn-system
spec:
  endpointSelector: {}
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: longhorn-system
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: longhorn-system
    - toEntities:
        - host # For node access
```

**Expected Outcome**: Longhorn functioning with Cilium network policies

#### Subtask 6.1.4: Update cert-manager for Cloudflare DNS-01

**Purpose**: Integrate certificate management with Cloudflare DNS

**Implementation**:

```yaml
# File: gitops/cert-manager/configmap-cert-manager-helm-chart-value-overrides.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cert-manager-helm-chart-value-overrides
  namespace: cert-manager
data:
  values.yaml: |
    installCRDs: true

    # Enable Cloudflare DNS-01 solver
    extraArgs:
      - --dns01-recursive-nameservers-only
      - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53

    # Resource optimization
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 128Mi
```

**ClusterIssuer Configuration**:

```yaml
# File: gitops/cert-manager/clusterissuer-letsencrypt.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
        selector:
          dnsZones:
            - "yourdomain.com"
```

**Expected Outcome**: Automatic SSL certificates via Cloudflare DNS validation

---

## Phase 7: Security & Encryption

### Task 7.1: Advanced Security Setup

#### Subtask 7.1.1: Enable Transparent Encryption (WireGuard)

**Purpose**: Encrypt all cluster traffic without application changes

**Configuration**: Already enabled in Cilium config (Task 2.1.3)

**WireGuard Benefits**:

- **Zero Application Impact**: Transparent to workloads
- **High Performance**: Kernel-level encryption
- **Automatic Key Management**: No manual key distribution
- **Node-to-Node Encryption**: All inter-node traffic encrypted

**Verification**:

```bash
# Check encryption status
kubectl exec -n kube-system ds/cilium -- cilium encrypt status

# Verify WireGuard interfaces
kubectl exec -n kube-system ds/cilium -- wg show
```

**Expected Outcome**: All cluster traffic automatically encrypted

#### Subtask 7.1.2: Configure L7 Network Policies

**Purpose**: Implement application-layer security controls

**Example L7 Policy**:

```yaml
# File: gitops/security/l7-policies.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-access-control
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/v1/*"
              - method: "POST"
                path: "/api/v1/users"
                headers:
                  - "Content-Type: application/json"
              - method: "PUT"
                path: "/api/v1/users/*"
    - fromEndpoints:
        - matchLabels:
            app: admin-console
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
              - method: "POST"
              - method: "PUT"
              - method: "DELETE"
```

**Policy Features**:

- HTTP method restrictions
- Path-based access control
- Header validation
- Protocol-aware filtering

**Expected Outcome**: Granular application-layer security

#### Subtask 7.1.3: Set up Runtime Security Monitoring

**Purpose**: Monitor and alert on security policy violations

**Implementation**:

```yaml
# File: gitops/security/security-monitoring.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  endpointSelector: {}
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: production
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: audit-egress
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      security.policy/audit: "true"
  egress:
    - toFQDNs:
        - matchName: "allowed-api.example.com"
    - toEntities:
        - kube-apiserver
```

**Monitoring Features**:

- Policy violation logging
- Unexpected traffic detection
- Security event alerting
- Compliance reporting

**Expected Outcome**: Comprehensive security monitoring and alerting

#### Subtask 7.1.4: Implement Zero-Trust Networking

**Purpose**: Enforce strict network segmentation and access control

**Zero-Trust Principles**:

```yaml
# File: gitops/security/zero-trust-policies.yaml
# Default deny all traffic
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  endpointSelector: {}
  # No ingress or egress rules = deny all

---
# Explicit allow for required communications
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: web-to-api
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      tier: api
  ingress:
    - fromEndpoints:
        - matchLabels:
            tier: web
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

**Zero-Trust Components**:

- Default deny policies
- Explicit allow rules
- Identity-based access
- Continuous verification

**Expected Outcome**: Zero-trust network architecture with explicit access control

---

## Phase 8: Testing & Validation

### Task 8.1: Comprehensive Testing

#### Subtask 8.1.1: Network Performance Benchmarking

**Purpose**: Validate Cilium performance improvements

**Benchmarking Tools**:

```bash
# Install netperf for testing
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/main/examples/kubernetes/netperf/netperf.yaml

# Run performance tests
kubectl exec -it netperf-client -- netperf -H netperf-server

# Test LoadBalancer performance
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- \
  wget -q -O- http://test-service.default.svc.cluster.local/
```

**Performance Metrics to Measure**:

- Pod-to-pod bandwidth
- Service discovery latency
- LoadBalancer response time
- Policy enforcement overhead

**Expected Results**:

- Near line-rate throughput (40Gbit/s capability)
- Sub-millisecond service discovery
- Minimal policy enforcement overhead

**Expected Outcome**: Performance validation and optimization baseline

#### Subtask 8.1.2: Security Policy Validation

**Purpose**: Verify network policies are correctly enforced

**Security Tests**:

```bash
# Test policy enforcement
kubectl run test-pod --image=busybox --rm -it -- sh
# Try to access restricted services (should fail)

# Test L7 policies
curl -X POST http://api-service/restricted-endpoint
# Should be blocked by L7 policy

# Verify encryption
kubectl exec -n kube-system ds/cilium -- cilium encrypt status
```

**Security Validation**:

- Policy violation blocking
- L7 rule enforcement
- Encryption verification
- Access control validation

**Expected Outcome**: All security policies correctly enforced

#### Subtask 8.1.3: DNS Automation Testing

**Purpose**: Validate automatic DNS record management

**DNS Tests**:

```bash
# Create test LoadBalancer service
kubectl create service loadbalancer test-dns --tcp=80:80
kubectl annotate service test-dns external-dns.alpha.kubernetes.io/hostname=test.yourdomain.com

# Verify DNS record creation
dig test.yourdomain.com
nslookup test.yourdomain.com

# Test Gateway API DNS
kubectl apply -f test-httproute.yaml
# Check automatic DNS record creation
```

**DNS Validation**:

- Automatic record creation
- Record deletion on service removal
- Cloudflare proxy configuration
- SSL certificate provisioning

**Expected Outcome**: Fully automated DNS management working correctly

#### Subtask 8.1.4: Failover and Reliability Testing

**Purpose**: Validate high availability and failover scenarios

**Reliability Tests**:

```bash
# Test node failure scenarios
kubectl drain worker-node-1 --ignore-daemonsets --delete-local-data

# Test BGP failover
# Simulate network partition
iptables -A INPUT -s 192.168.3.1 -j DROP

# Test service failover
kubectl scale deployment test-app --replicas=0
# Verify service remains accessible via other replicas
```

**Failover Scenarios**:

- Node failure recovery
- BGP route failover
- Service endpoint failure
- Network partition recovery

**Expected Outcome**: Robust failover capabilities with minimal downtime

---

## Summary & Expected Benefits

### Performance Improvements

- **40Gbit/s network throughput** (benchmark proven)
- **50-70% lower CPU usage** vs traditional iptables
- **Sub-millisecond service discovery** with eBPF
- **Linear scaling** with cluster growth

### Operational Benefits

- **Unified networking stack** (5+ components → 1)
- **Automatic DNS management** for all services
- **Real-time network visibility** with Hubble
- **Enterprise-grade security** with minimal overhead

### Security Enhancements

- **Transparent encryption** at kernel level
- **L7 network policies** for application security
- **Zero-trust networking** by default
- **Runtime security monitoring** and alerting

### Developer Experience

- **Automatic service discovery** via DNS
- **Simplified ingress** with Gateway API
- **Visual network debugging** with Hubble UI
- **GitOps-managed** infrastructure as code

### Business Impact

- **Reduced operational complexity** and costs
- **Improved security posture** and compliance
- **Faster development cycles** with better tooling
- **Future-proof architecture** with cutting-edge technology

---

## Implementation Timeline

**Total Duration**: 2-3 weeks for complete implementation

- **Week 1**: Infrastructure foundation and core Cilium deployment
- **Week 2**: Service migration and DNS automation
- **Week 3**: Security hardening and comprehensive testing

This plan transforms InfraFlux into a modern, high-performance Kubernetes platform with unified networking, automatic DNS management, and comprehensive observability.
