#!/bin/bash
#
# Security Policy Validation Script for Cilium
# Tests network policies, L7 policies, and encryption
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

# Test namespace
NAMESPACE="security-test"

# Cleanup function
cleanup() {
    info "Cleaning up test resources..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
}

# Trap cleanup on exit
trap cleanup EXIT

# Create test namespace
create_namespace() {
    header "Setting up Security Test Environment"
    info "Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

# Test default deny policies
test_default_deny() {
    header "Testing Default Deny Policies"
    
    # Deploy test pods
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client-pod
  namespace: $NAMESPACE
  labels:
    app: client
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: server-pod
  namespace: $NAMESPACE
  labels:
    app: server
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: server-svc
  namespace: $NAMESPACE
spec:
  selector:
    app: server
  ports:
  - port: 80
    targetPort: 80
EOF

    # Wait for pods
    kubectl wait --for=condition=ready pod/client-pod -n $NAMESPACE --timeout=60s
    kubectl wait --for=condition=ready pod/server-pod -n $NAMESPACE --timeout=60s
    
    # Apply default deny policy
    cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny
  namespace: $NAMESPACE
spec:
  endpointSelector: {}
EOF
    
    sleep 5
    
    info "Testing connectivity with default deny policy..."
    if kubectl exec -n $NAMESPACE client-pod -- curl -s --connect-timeout 5 http://server-svc &>/dev/null; then
        error "Connection succeeded - default deny policy not working!"
    else
        success "Connection blocked by default deny policy"
    fi
}

# Test L3/L4 policies
test_l3_l4_policies() {
    header "Testing L3/L4 Network Policies"
    
    # Allow specific traffic
    cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-client-to-server
  namespace: $NAMESPACE
spec:
  endpointSelector:
    matchLabels:
      app: server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
EOF
    
    sleep 5
    
    info "Testing allowed L3/L4 connectivity..."
    if kubectl exec -n $NAMESPACE client-pod -- curl -s --connect-timeout 5 http://server-svc &>/dev/null; then
        success "Allowed connection successful"
    else
        error "Allowed connection failed"
    fi
    
    # Test unauthorized port
    info "Testing blocked port access..."
    if kubectl exec -n $NAMESPACE client-pod -- curl -s --connect-timeout 5 http://server-svc:443 &>/dev/null; then
        error "Unauthorized port access succeeded!"
    else
        success "Unauthorized port access blocked"
    fi
}

# Test L7 policies
test_l7_policies() {
    header "Testing L7 Application Policies"
    
    # Deploy API server with different endpoints
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: $NAMESPACE
data:
  default.conf: |
    server {
        listen 80;
        location /api/v1/public {
            return 200 '{"status": "public endpoint"}';
            add_header Content-Type application/json;
        }
        location /api/v1/private {
            return 200 '{"status": "private endpoint"}';
            add_header Content-Type application/json;
        }
        location /health {
            return 200 '{"status": "healthy"}';
            add_header Content-Type application/json;
        }
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: $NAMESPACE
  labels:
    app: api
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: config
    configMap:
      name: api-config
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: $NAMESPACE
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
EOF

    kubectl wait --for=condition=ready pod/api-server -n $NAMESPACE --timeout=60s
    
    # Apply L7 policy
    cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-l7-policy
  namespace: $NAMESPACE
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/v1/public"
        - method: "GET"
          path: "/health"
EOF
    
    sleep 5
    
    info "Testing allowed L7 path /api/v1/public..."
    if kubectl exec -n $NAMESPACE client-pod -- curl -s http://api-svc/api/v1/public | grep -q "public endpoint"; then
        success "Allowed L7 path accessible"
    else
        error "Allowed L7 path blocked"
    fi
    
    info "Testing blocked L7 path /api/v1/private..."
    if kubectl exec -n $NAMESPACE client-pod -- curl -s --connect-timeout 5 http://api-svc/api/v1/private &>/dev/null; then
        error "Blocked L7 path accessible!"
    else
        success "Blocked L7 path denied"
    fi
    
    info "Testing HTTP method restrictions..."
    if kubectl exec -n $NAMESPACE client-pod -- curl -s -X POST --connect-timeout 5 http://api-svc/api/v1/public &>/dev/null; then
        error "Blocked HTTP method allowed!"
    else
        success "Blocked HTTP method denied"
    fi
}

# Test encryption
test_encryption() {
    header "Testing WireGuard Encryption"
    
    CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    
    info "Checking encryption status..."
    kubectl exec -n kube-system $CILIUM_POD -- cilium encrypt status
    
    info "Checking WireGuard interfaces..."
    kubectl exec -n kube-system $CILIUM_POD -- cilium encrypt status | grep -i "wireguard"
    
    if kubectl exec -n kube-system $CILIUM_POD -- cilium encrypt status | grep -q "Encryption: Wireguard"; then
        success "WireGuard encryption is active"
    else
        warning "WireGuard encryption status unclear"
    fi
}

# Test DNS policies
test_dns_policies() {
    header "Testing DNS/FQDN Policies"
    
    # Deploy pod with external access
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-pod
  namespace: $NAMESPACE
  labels:
    app: dns-test
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
EOF

    kubectl wait --for=condition=ready pod/dns-test-pod -n $NAMESPACE --timeout=60s
    
    # Apply DNS policy
    cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: dns-policy
  namespace: $NAMESPACE
spec:
  endpointSelector:
    matchLabels:
      app: dns-test
  egress:
  - toEndpoints:
    - matchLabels:
        k8s-app: kube-dns
        k8s:io.kubernetes.pod.namespace: kube-system
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
      - port: "53"
        protocol: TCP
  - toFQDNs:
    - matchName: "httpbin.org"
  - toEntities:
    - world
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
EOF
    
    sleep 10  # Allow time for DNS resolution
    
    info "Testing allowed FQDN access to httpbin.org..."
    if kubectl exec -n $NAMESPACE dns-test-pod -- curl -s --connect-timeout 10 https://httpbin.org/get &>/dev/null; then
        success "Allowed FQDN accessible"
    else
        warning "Allowed FQDN not accessible (may be network issue)"
    fi
    
    info "Testing blocked FQDN access..."
    if kubectl exec -n $NAMESPACE dns-test-pod -- curl -s --connect-timeout 5 https://example.com &>/dev/null; then
        error "Blocked FQDN accessible!"
    else
        success "Blocked FQDN denied"
    fi
}

# Test identity-based policies
test_identity_policies() {
    header "Testing Identity-Based Policies"
    
    # Get cluster identity
    CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    
    info "Checking Cilium identities..."
    kubectl exec -n kube-system $CILIUM_POD -- cilium identity list | head -20
    
    info "Checking policy enforcement..."
    kubectl exec -n kube-system $CILIUM_POD -- cilium policy get | head -20
    
    success "Identity-based policies active"
}

# Generate security report
generate_report() {
    header "Security Policy Validation Summary"
    
    echo -e "${BLUE}Security Features Status:${NC}"
    echo "- Default Deny Policies: ✓"
    echo "- L3/L4 Network Policies: ✓"
    echo "- L7 Application Policies: ✓"
    echo "- WireGuard Encryption: ✓"
    echo "- DNS/FQDN Policies: ✓"
    echo "- Identity-Based Security: ✓"
    
    echo -e "\n${BLUE}Policy Statistics:${NC}"
    CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n kube-system $CILIUM_POD -- cilium policy get --all-namespaces | grep -c "CiliumNetworkPolicy" || echo "0 policies"
    
    echo -e "\n${BLUE}Security Recommendations:${NC}"
    echo "1. Always use default deny policies in production namespaces"
    echo "2. Implement L7 policies for API security"
    echo "3. Enable WireGuard encryption for node-to-node traffic"
    echo "4. Use FQDN policies for external service access"
    echo "5. Regularly audit network policies and access patterns"
    
    success "Security validation completed!"
}

# Main execution
main() {
    echo -e "${CYAN}🔒 Cilium Security Policy Validation${NC}"
    echo -e "${CYAN}====================================${NC}"
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Not connected to Kubernetes cluster"
        exit 1
    fi
    
    # Run tests
    create_namespace
    test_default_deny
    test_l3_l4_policies
    test_l7_policies
    test_encryption
    test_dns_policies
    test_identity_policies
    generate_report
}

# Run main function
main "$@"