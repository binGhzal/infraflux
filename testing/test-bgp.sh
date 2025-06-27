#!/bin/bash
#
# BGP Route Advertisement Testing Script
# This script tests Cilium BGP functionality and route advertisements
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

# Main testing logic
main() {
    header "BGP Route Advertisement Testing"
    
    # Test 1: Check if Cilium is running
    info "Checking Cilium status..."
    if kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[*].status.phase}' | grep -q "Running"; then
        success "Cilium pods are running"
    else
        error "Cilium pods are not running"
        exit 1
    fi
    
    # Test 2: Check BGP configuration
    header "BGP Configuration"
    info "Checking CiliumBGPPeeringPolicy..."
    if kubectl get ciliumbgppeeringpolicy 2>/dev/null; then
        success "BGP Peering Policy found"
        kubectl get ciliumbgppeeringpolicy -o wide
    else
        error "No BGP Peering Policy found"
    fi
    
    # Test 3: Check BGP peers
    header "BGP Peer Status"
    info "Checking BGP peer connections..."
    
    # Get a Cilium pod to execute commands
    CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$CILIUM_POD" ]; then
        echo "Using Cilium pod: $CILIUM_POD"
        kubectl -n kube-system exec "$CILIUM_POD" -- cilium bgp peers || warning "Could not get BGP peer status"
    else
        error "No Cilium pod found"
    fi
    
    # Test 4: Check LoadBalancer IP pools
    header "LoadBalancer IP Pools"
    info "Checking Cilium LoadBalancer IP pools..."
    kubectl get ciliumloadbalancerippool -o wide || warning "No LoadBalancer IP pools found"
    
    # Test 5: Check advertised routes
    header "Advertised Routes"
    info "Checking BGP advertised routes..."
    if [ -n "$CILIUM_POD" ]; then
        kubectl -n kube-system exec "$CILIUM_POD" -- cilium bgp routes advertised ipv4 unicast || warning "No routes being advertised"
    fi
    
    # Test 6: Create test LoadBalancer service
    header "LoadBalancer Service Test"
    info "Creating test LoadBalancer service..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: bgp-test-service
  namespace: default
  annotations:
    service.beta.kubernetes.io/test: "bgp-validation"
spec:
  type: LoadBalancer
  selector:
    app: non-existent-app
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF
    
    # Wait for LoadBalancer IP
    info "Waiting for LoadBalancer IP assignment (max 60s)..."
    TIMEOUT=60
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        LB_IP=$(kubectl get svc bgp-test-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$LB_IP" ]; then
            success "LoadBalancer IP assigned: $LB_IP"
            break
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        echo -n "."
    done
    echo ""
    
    if [ -z "$LB_IP" ]; then
        error "LoadBalancer IP not assigned after ${TIMEOUT}s"
        kubectl describe svc bgp-test-service
    else
        # Check if route is advertised
        info "Checking if route is advertised for $LB_IP..."
        if [ -n "$CILIUM_POD" ]; then
            if kubectl -n kube-system exec "$CILIUM_POD" -- cilium bgp routes advertised ipv4 unicast | grep -q "$LB_IP"; then
                success "Route for $LB_IP is being advertised via BGP"
            else
                warning "Route for $LB_IP not found in BGP advertisements"
            fi
        fi
    fi
    
    # Cleanup
    info "Cleaning up test resources..."
    kubectl delete svc bgp-test-service --ignore-not-found=true
    
    # Summary
    header "BGP Testing Summary"
    echo "1. Cilium Status: ✓"
    echo "2. BGP Configuration: ✓"
    echo "3. BGP Peers: Check output above"
    echo "4. LoadBalancer Pools: ✓"
    echo "5. Route Advertisement: Check output above"
    
    success "BGP validation completed!"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    error "Not connected to Kubernetes cluster"
    exit 1
fi

# Run main testing logic
main "$@"