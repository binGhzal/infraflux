#!/bin/bash
set -e

echo "🔍 InfraFlux Cilium Ecosystem Deployment Validation"
echo "==================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    echo -e "ℹ️  $1"
}

# Function to check if a deployment is ready
check_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    info "Checking deployment $deployment in namespace $namespace..."
    if kubectl wait --for=condition=available deployment/$deployment -n $namespace --timeout=${timeout}s > /dev/null 2>&1; then
        success "Deployment $deployment is ready"
        return 0
    else
        error "Deployment $deployment is not ready"
        return 1
    fi
}

# Function to check if a daemonset is ready
check_daemonset() {
    local namespace=$1
    local daemonset=$2
    
    info "Checking daemonset $daemonset in namespace $namespace..."
    local desired=$(kubectl get daemonset $daemonset -n $namespace -o jsonpath='{.status.desiredNumberScheduled}')
    local ready=$(kubectl get daemonset $daemonset -n $namespace -o jsonpath='{.status.numberReady}')
    
    if [ "$desired" = "$ready" ] && [ "$ready" -gt "0" ]; then
        success "DaemonSet $daemonset is ready ($ready/$desired)"
        return 0
    else
        error "DaemonSet $daemonset is not ready ($ready/$desired)"
        return 1
    fi
}

# Function to check service status
check_service() {
    local namespace=$1
    local service=$2
    
    info "Checking service $service in namespace $namespace..."
    if kubectl get service $service -n $namespace > /dev/null 2>&1; then
        success "Service $service exists"
        return 0
    else
        error "Service $service does not exist"
        return 1
    fi
}

echo ""
echo "Phase 1: Infrastructure Components"
echo "=================================="

# Check Cilium
info "Validating Cilium CNI..."
check_daemonset "kube-system" "cilium"
check_deployment "kube-system" "cilium-operator"

# Check if BGP is working
info "Checking BGP peering status..."
if kubectl exec -n kube-system ds/cilium -- cilium bgp peers 2>/dev/null | grep -q "Established"; then
    success "BGP peering is established"
else
    warning "BGP peering status unclear or not established"
fi

echo ""
echo "Phase 2: Gateway API Components"
echo "==============================="

# Check Gateway API CRDs
info "Checking Gateway API CRDs..."
if kubectl get crd gateways.gateway.networking.k8s.io > /dev/null 2>&1; then
    success "Gateway API CRDs are installed"
else
    error "Gateway API CRDs are missing"
fi

# Check GatewayClass
info "Checking GatewayClass..."
if kubectl get gatewayclass cilium > /dev/null 2>&1; then
    success "GatewayClass 'cilium' exists"
else
    error "GatewayClass 'cilium' is missing"
fi

# Check Main Gateway
info "Checking main Gateway..."
if kubectl get gateway main-gateway -n cilium-gateway > /dev/null 2>&1; then
    success "Main Gateway exists"
    # Check if gateway is programmed
    if kubectl get gateway main-gateway -n cilium-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' | grep -q "True"; then
        success "Main Gateway is programmed"
    else
        warning "Main Gateway exists but may not be programmed yet"
    fi
else
    error "Main Gateway is missing"
fi

echo ""
echo "Phase 3: External DNS"
echo "===================="

check_deployment "external-dns" "external-dns"

echo ""
echo "Phase 4: Application Services"
echo "============================="

# Kubernetes Dashboard
info "Validating Kubernetes Dashboard..."
check_deployment "kubernetes-dashboard" "kubernetes-dashboard-api"
check_deployment "kubernetes-dashboard" "kubernetes-dashboard-web"
check_service "kubernetes-dashboard" "kubernetes-dashboard-kong-proxy"

# Longhorn
info "Validating Longhorn..."
check_deployment "longhorn-system" "longhorn-ui"
check_daemonset "longhorn-system" "longhorn-manager"
check_service "longhorn-system" "longhorn-frontend"

# Authentik
info "Validating Authentik..."
check_deployment "authentik" "authentik-server"
check_deployment "authentik" "authentik-worker"
check_service "authentik" "authentik"

# Hubble UI
info "Validating Hubble..."
check_deployment "kube-system" "hubble-relay"
check_deployment "kube-system" "hubble-ui"
check_service "kube-system" "hubble-ui"

echo ""
echo "Phase 5: HTTPRoutes"
echo "=================="

info "Checking HTTPRoutes..."
HTTPROUTES=$(kubectl get httproutes --all-namespaces --no-headers | wc -l)
if [ "$HTTPROUTES" -gt "0" ]; then
    success "Found $HTTPROUTES HTTPRoute(s)"
    kubectl get httproutes --all-namespaces
else
    error "No HTTPRoutes found"
fi

echo ""
echo "Phase 6: Security Policies"
echo "=========================="

info "Checking Cilium Network Policies..."
POLICIES=$(kubectl get ciliumnetworkpolicies --all-namespaces --no-headers | wc -l)
if [ "$POLICIES" -gt "0" ]; then
    success "Found $POLICIES Cilium Network Policy(ies)"
else
    warning "No Cilium Network Policies found"
fi

echo ""
echo "Phase 7: Certificate Management"
echo "==============================="

check_deployment "cert-manager" "cert-manager"
check_deployment "cert-manager" "cert-manager-cainjector"
check_deployment "cert-manager" "cert-manager-webhook"

echo ""
echo "Phase 8: Final Validation"
echo "========================="

# Check cluster health
info "Overall cluster health check..."
NODES_READY=$(kubectl get nodes --no-headers | grep -c " Ready ")
NODES_TOTAL=$(kubectl get nodes --no-headers | wc -l)

if [ "$NODES_READY" = "$NODES_TOTAL" ]; then
    success "All nodes are ready ($NODES_READY/$NODES_TOTAL)"
else
    error "Some nodes are not ready ($NODES_READY/$NODES_TOTAL)"
fi

# Check for failed pods
FAILED_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers | wc -l)
if [ "$FAILED_PODS" = "0" ]; then
    success "No failed pods found"
else
    warning "Found $FAILED_PODS failed pod(s)"
    kubectl get pods --all-namespaces --field-selector=status.phase=Failed
fi

echo ""
echo "==================================================="
echo "🎉 InfraFlux Cilium Ecosystem Validation Complete!"
echo "==================================================="

info "Next steps:"
echo "1. Run 'kubectl apply -f testing/cilium-ecosystem-validation.yaml' for comprehensive tests"
echo "2. Run 'kubectl apply -f testing/network-connectivity-test.yaml' for network validation"
echo "3. Run 'kubectl apply -f testing/performance-test.yaml' for performance validation"
echo "4. Access services via your configured domain names"
echo ""
success "Deployment validation completed successfully!"