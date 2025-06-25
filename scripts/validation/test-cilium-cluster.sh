#!/bin/bash
# Comprehensive Cilium cluster testing script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
}

# Test Cilium status
test_cilium_status() {
    log "Testing Cilium status..."
    
    # Check if Cilium pods are running
    if kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | grep -q "Running"; then
        success "Cilium pods are running"
    else
        error "Cilium pods are not running"
        kubectl get pods -n kube-system -l k8s-app=cilium
        return 1
    fi
    
    # Check Cilium status via CLI
    if kubectl exec -n kube-system ds/cilium -- cilium status --brief; then
        success "Cilium status check passed"
    else
        error "Cilium status check failed"
        return 1
    fi
}

# Test kube-proxy replacement
test_kube_proxy_replacement() {
    log "Testing kube-proxy replacement..."
    
    if kubectl exec -n kube-system ds/cilium -- cilium status | grep -q "KubeProxyReplacement.*Strict"; then
        success "Kube-proxy replacement is enabled in strict mode"
    else
        error "Kube-proxy replacement is not enabled"
        return 1
    fi
}

# Test BGP functionality
test_bgp() {
    log "Testing BGP functionality..."
    
    # Check BGP peers
    if kubectl exec -n kube-system ds/cilium -- cilium bgp peers 2>/dev/null; then
        success "BGP peers are configured"
    else
        warning "BGP peers not found or not configured"
    fi
    
    # Check BGP routes
    if kubectl exec -n kube-system ds/cilium -- cilium bgp routes 2>/dev/null; then
        success "BGP routes are advertised"
    else
        warning "No BGP routes found"
    fi
}

# Test encryption
test_encryption() {
    log "Testing transparent encryption..."
    
    if kubectl exec -n kube-system ds/cilium -- cilium encrypt status | grep -q "Encryption.*Enabled"; then
        success "Transparent encryption is enabled"
        
        # Check WireGuard interfaces
        if kubectl exec -n kube-system ds/cilium -- wg show 2>/dev/null; then
            success "WireGuard interfaces are active"
        else
            warning "WireGuard interfaces not found"
        fi
    else
        error "Transparent encryption is not enabled"
        return 1
    fi
}

# Test Hubble
test_hubble() {
    log "Testing Hubble observability..."
    
    # Check Hubble pods
    if kubectl get pods -n kube-system -l k8s-app=hubble-relay --no-headers | grep -q "Running"; then
        success "Hubble Relay is running"
    else
        error "Hubble Relay is not running"
        return 1
    fi
    
    # Check Hubble UI
    if kubectl get pods -n kube-system -l k8s-app=hubble-ui --no-headers | grep -q "Running"; then
        success "Hubble UI is running"
    else
        warning "Hubble UI is not running"
    fi
    
    # Test Hubble CLI
    if kubectl exec -n kube-system deployment/hubble-relay -- hubble status; then
        success "Hubble CLI is working"
    else
        error "Hubble CLI test failed"
        return 1
    fi
}

# Test network performance
test_network_performance() {
    log "Testing network performance..."
    
    # Deploy test resources
    kubectl apply -f /Users/binghzal/Developer/infraflux/tests/cilium/network-performance-test.yaml
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=netperf-server -n network-test --timeout=60s
    
    # Run performance test
    log "Running netperf bandwidth test..."
    if kubectl exec -n network-test netperf-client -- netperf -H netperf-server.network-test.svc.cluster.local -t TCP_STREAM -l 10; then
        success "Network performance test completed"
    else
        error "Network performance test failed"
        return 1
    fi
    
    # Cleanup
    kubectl delete -f /Users/binghzal/Developer/infraflux/tests/cilium/network-performance-test.yaml --ignore-not-found=true
}

# Test DNS automation
test_dns_automation() {
    log "Testing DNS automation with External-DNS..."
    
    # Check External-DNS pods
    if kubectl get pods -n external-dns --no-headers | grep -q "Running"; then
        success "External-DNS is running"
        
        # Deploy test service
        kubectl apply -f /Users/binghzal/Developer/infraflux/tests/cilium/test-dns-automation.yaml
        
        # Wait for service
        kubectl wait --for=condition=ready pod -l app=test-app -n network-test --timeout=60s
        
        log "Test service deployed. Check DNS records manually."
        success "DNS automation test resources deployed"
        
        # Cleanup after 30 seconds
        sleep 30
        kubectl delete -f /Users/binghzal/Developer/infraflux/tests/cilium/test-dns-automation.yaml --ignore-not-found=true
    else
        error "External-DNS is not running"
        return 1
    fi
}

# Test Gateway API
test_gateway_api() {
    log "Testing Gateway API..."
    
    # Check Gateway API CRDs
    if kubectl get crd gateways.gateway.networking.k8s.io &>/dev/null; then
        success "Gateway API CRDs are installed"
    else
        error "Gateway API CRDs are not installed"
        return 1
    fi
    
    # Check GatewayClass
    if kubectl get gatewayclass cilium &>/dev/null; then
        success "Cilium GatewayClass is configured"
    else
        error "Cilium GatewayClass not found"
        return 1
    fi
    
    # Check Gateway
    if kubectl get gateway main-gateway -n cilium-gateway &>/dev/null; then
        success "Main Gateway is configured"
    else
        error "Main Gateway not found"
        return 1
    fi
}

# Test network policies
test_network_policies() {
    log "Testing Cilium Network Policies..."
    
    # Check if CiliumNetworkPolicy CRD exists
    if kubectl get crd ciliumnetworkpolicies.cilium.io &>/dev/null; then
        success "CiliumNetworkPolicy CRD is installed"
    else
        error "CiliumNetworkPolicy CRD not found"
        return 1
    fi
    
    # List network policies
    policy_count=$(kubectl get ciliumnetworkpolicies --all-namespaces --no-headers | wc -l)
    if [ "$policy_count" -gt 0 ]; then
        success "Found $policy_count Cilium Network Policies"
    else
        warning "No Cilium Network Policies found"
    fi
}

# Main test function
main() {
    log "Starting Cilium cluster validation..."
    
    check_kubectl
    
    # Run tests
    test_cilium_status
    test_kube_proxy_replacement
    test_encryption
    test_hubble
    test_bgp
    test_gateway_api
    test_network_policies
    test_dns_automation
    test_network_performance
    
    success "All Cilium cluster tests completed!"
    log "Check the results above for any warnings or errors."
}

# Run main function
main "$@"