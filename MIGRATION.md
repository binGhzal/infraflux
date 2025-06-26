# Migration Guide: Legacy to Cilium Ecosystem

This guide helps you migrate from the legacy InfraFlux setup (MetalLB + Traefik) to the modern Cilium ecosystem (Gateway API + Cilium BGP).

## 🎯 What's Changed

### Old Architecture vs New Architecture

| Component | Legacy | Modern Cilium Ecosystem |
|-----------|--------|------------------------|
| **CNI** | Canal/Calico | Cilium eBPF |
| **kube-proxy** | Standard kube-proxy | Cilium kube-proxy replacement |
| **Ingress** | Traefik | Gateway API with Cilium |
| **Load Balancing** | MetalLB | Cilium BGP |
| **Network Policies** | Calico policies | Cilium L3/L4/L7 policies |
| **DNS Management** | Manual | External-DNS + Cloudflare |
| **Observability** | Basic | Hubble + Prometheus |
| **Security** | Basic network policies | Zero-trust with eBPF |

### Benefits of Migration

- **🚀 Performance**: 20-50% better network performance with eBPF
- **🔐 Security**: L7 policies and transparent encryption
- **📊 Observability**: Rich network flow monitoring with Hubble
- **☁️ Cloud Integration**: Automatic DNS management with Cloudflare
- **🔮 Future-Proof**: Gateway API is the future of Kubernetes ingress
- **🎛️ Unified Stack**: Single networking solution instead of multiple components

## 🚧 Migration Strategy

### Option 1: Fresh Deployment (Recommended)

The safest approach is to deploy a new cluster with the Cilium ecosystem:

1. **Backup Data**: Export persistent data from existing cluster
2. **Deploy New Cluster**: Use the updated InfraFlux with Cilium
3. **Migrate Applications**: Restore data and update ingress configurations
4. **Validate**: Run comprehensive testing suite
5. **Switch Traffic**: Update DNS records to point to new cluster

### Option 2: In-Place Migration (Advanced)

⚠️ **Warning**: This approach requires downtime and has higher risk.

## 📋 Pre-Migration Checklist

### Backup Everything

```bash
# Backup cluster state
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Backup persistent volumes
kubectl get pv,pvc --all-namespaces -o yaml > storage-backup.yaml

# Backup ConfigMaps and Secrets
kubectl get configmaps,secrets --all-namespaces -o yaml > config-backup.yaml

# Backup custom resources
kubectl get crd -o yaml > crds-backup.yaml
```

### Document Current Configuration

```bash
# Document current ingress routes
kubectl get ingress --all-namespaces -o yaml > ingress-backup.yaml

# Document current services
kubectl get services --all-namespaces -o yaml > services-backup.yaml

# Document MetalLB configuration
kubectl get configmap config -n metallb-system -o yaml > metallb-config.yaml
```

### Prerequisites for New Architecture

1. **Cloudflare Account**: Domain and API token for DNS management
2. **Network Planning**: BGP ASN and IP ranges for Cilium
3. **Certificate Planning**: Decide on Let's Encrypt or custom CA
4. **Application Inventory**: List all applications needing migration

## 🔄 Migration Steps

### Step 1: Prepare New Configuration

Update your `terraform.tfvars` with Cilium configuration:

```hcl
# Add Cilium configuration
cilium_config = {
  lb_ip_range    = "192.168.3.80/28"      # Replace MetalLB range
  bgp_asn        = 64512                  # Your BGP ASN
  bgp_peer_asn   = 64512                  # Gateway BGP ASN
}

# Add Cloudflare configuration
cloudflare_config = {
  domain     = "yourdomain.com"           # Your domain
  zone_id    = "your-cloudflare-zone-id"  # From Cloudflare dashboard
}
```

### Step 2: Deploy New Cluster

```bash
# Deploy infrastructure with Cilium
./deploy.sh deploy

# Verify Cilium ecosystem
./testing/validate-deployment.sh
```

### Step 3: Migrate Applications

#### Convert Ingress to HTTPRoute

**Old Traefik Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

**New Gateway API HTTPRoute:**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app.yourdomain.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
spec:
  parentRefs:
    - name: main-gateway
      namespace: cilium-gateway
  hostnames:
    - app.yourdomain.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: app-service
          port: 80
```

#### Update Service Types

**Old MetalLB LoadBalancer:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
  annotations:
    metallb.universe.tf/address-pool: default
spec:
  type: LoadBalancer
  # ...
```

**New Cilium BGP LoadBalancer:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
  annotations:
    io.cilium/lb-ipam-ips: "192.168.3.81"  # From Cilium range
spec:
  type: LoadBalancer
  # ...
```

### Step 4: Migrate Network Policies

#### Convert Calico to Cilium Policies

**Old Calico NetworkPolicy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-policy
spec:
  podSelector:
    matchLabels:
      app: myapp
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
```

**New Cilium NetworkPolicy:**
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: app-policy
spec:
  endpointSelector:
    matchLabels:
      app: myapp
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
          path: "/api/*"
```

### Step 5: Data Migration

```bash
# Export persistent volumes
kubectl get pv -o yaml > pv-export.yaml

# Copy data using appropriate method:
# - velero for backup/restore
# - rsync for file-based volumes
# - database dump/restore for databases

# Example with Longhorn volumes
kubectl exec -it source-pod -- tar czf - /data | \
kubectl exec -i target-pod -- tar xzf - -C /data
```

### Step 6: DNS Cutover

```bash
# Update DNS records to point to new cluster
# External-DNS will automatically manage these in the new cluster

# Verify DNS propagation
dig app.yourdomain.com
```

### Step 7: Validation

```bash
# Run comprehensive testing
kubectl apply -f testing/cilium-ecosystem-validation.yaml
kubectl apply -f testing/network-connectivity-test.yaml
kubectl apply -f testing/performance-test.yaml

# Monitor application health
kubectl get pods --all-namespaces
kubectl get httproutes --all-namespaces
```

## 🛠️ Troubleshooting Migration Issues

### Common Issues

#### 1. BGP Peering Problems
```bash
# Check BGP status
kubectl exec -n kube-system ds/cilium -- cilium bgp peers

# Verify network gateway BGP configuration
# Ensure ASNs match between Cilium and gateway
```

#### 2. DNS Resolution Issues
```bash
# Check External-DNS logs
kubectl logs -n external-dns deployment/external-dns

# Verify Cloudflare API connectivity
kubectl get events -n external-dns
```

#### 3. HTTPRoute Not Working
```bash
# Check Gateway status
kubectl describe gateway main-gateway -n cilium-gateway

# Verify HTTPRoute status
kubectl describe httproute <route-name> -n <namespace>

# Check Cilium Gateway logs
kubectl logs -n kube-system deployment/cilium-operator
```

#### 4. Application Connectivity Issues
```bash
# Test Cilium connectivity
kubectl exec -n kube-system ds/cilium -- cilium connectivity test

# Check network policies
kubectl get ciliumnetworkpolicies --all-namespaces

# Verify service endpoints
kubectl get endpoints <service-name> -n <namespace>
```

### Rollback Plan

If migration fails, you can rollback to the legacy architecture:

1. **Preserve Original Cluster**: Don't destroy until migration is complete
2. **DNS Rollback**: Point DNS back to original cluster
3. **Data Sync**: Sync any new data back to original cluster
4. **Traffic Validation**: Ensure all services are working

## 📚 Migration Resources

### Configuration Examples

See the `examples/` directory for:
- HTTPRoute examples for common applications
- Cilium NetworkPolicy examples
- Service configuration examples
- External-DNS annotation examples

### Testing Tools

Use the comprehensive testing suite:
```bash
./testing/validate-deployment.sh
kubectl apply -f testing/cilium-ecosystem-validation.yaml
kubectl apply -f testing/network-connectivity-test.yaml
kubectl apply -f testing/performance-test.yaml
```

### Documentation Links

- [Cilium Network Policies](https://docs.cilium.io/en/stable/policy/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [External-DNS with Cloudflare](https://kubernetes-sigs.github.io/external-dns/v0.13.5/tutorials/cloudflare/)
- [Hubble Observability](https://docs.cilium.io/en/stable/observability/hubble/)

## 🎉 Post-Migration Benefits

After successful migration, you'll have:

- **🚀 Better Performance**: eBPF datapath improvements
- **🔐 Enhanced Security**: L7 policies and encryption
- **📊 Rich Observability**: Hubble network monitoring
- **☁️ Automated DNS**: External-DNS integration
- **🔮 Future-Proof Architecture**: Gateway API and Cilium
- **🎯 Simplified Operations**: Unified networking stack

## 💬 Support

If you encounter issues during migration:

1. Check the troubleshooting section above
2. Review the testing tools output
3. Open an issue in the repository with detailed logs
4. Join the community discussions for help

Remember: Take your time with migration and always have a rollback plan! 🛡️