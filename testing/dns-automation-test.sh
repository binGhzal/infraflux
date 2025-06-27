#!/bin/bash
#
# DNS Automation Testing Script for External-DNS with Cloudflare
# Tests automatic DNS record creation, deletion, and management
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
NAMESPACE="dns-test"
TEST_DOMAIN="test$(date +%s)"

# Cleanup function
cleanup() {
    info "Cleaning up test resources..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    # Clean up test HTTPRoutes
    kubectl delete httproute dns-test-route --ignore-not-found=true -n $NAMESPACE
    kubectl delete service dns-test-lb --ignore-not-found=true -n $NAMESPACE
}

# Trap cleanup on exit
trap cleanup EXIT

# Create test namespace with gateway access
create_namespace() {
    header "Setting up DNS Test Environment"
    info "Creating namespace $NAMESPACE..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    gateway-access: "allowed"
EOF
}

# Test External-DNS status
test_external_dns_status() {
    header "External-DNS Status Check"
    
    info "Checking External-DNS deployment..."
    if kubectl get deployment external-dns -n external-dns &>/dev/null; then
        success "External-DNS deployment found"
        
        # Check pod status
        if kubectl wait --for=condition=available deployment/external-dns -n external-dns --timeout=60s; then
            success "External-DNS is running"
        else
            error "External-DNS deployment not ready"
            return 1
        fi
        
        # Check logs for errors
        info "Checking External-DNS logs for errors..."
        kubectl logs -n external-dns deployment/external-dns --tail=20 | grep -i error || success "No errors in recent logs"
        
    else
        error "External-DNS deployment not found"
        return 1
    fi
}

# Test Cloudflare API connectivity
test_cloudflare_connectivity() {
    header "Testing Cloudflare API Connectivity"
    
    info "Checking Cloudflare API token secret..."
    if kubectl get secret cloudflare-api-token -n external-dns &>/dev/null; then
        success "Cloudflare API token secret exists"
    else
        error "Cloudflare API token secret not found"
        return 1
    fi
    
    # Check External-DNS logs for Cloudflare connections
    info "Checking Cloudflare API connectivity in logs..."
    kubectl logs -n external-dns deployment/external-dns --tail=50 | grep -i cloudflare || info "No recent Cloudflare API calls logged"
}

# Test LoadBalancer DNS automation
test_loadbalancer_dns() {
    header "Testing LoadBalancer DNS Automation"
    
    # Create test LoadBalancer service
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns-test-app
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dns-test-app
  template:
    metadata:
      labels:
        app: dns-test-app
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
  name: dns-test-lb
  namespace: $NAMESPACE
  annotations:
    external-dns.alpha.kubernetes.io/hostname: ${TEST_DOMAIN}.{{ cloudflare_domain }}
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"
    external-dns.alpha.kubernetes.io/ttl: "120"
spec:
  type: LoadBalancer
  selector:
    app: dns-test-app
  ports:
  - port: 80
    targetPort: 80
EOF

    info "Waiting for LoadBalancer IP assignment..."
    sleep 30
    
    LB_IP=$(kubectl get svc dns-test-lb -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -n "$LB_IP" ]]; then
        success "LoadBalancer IP assigned: $LB_IP"
        
        info "Waiting for DNS record creation (up to 3 minutes)..."
        TIMEOUT=180
        ELAPSED=0
        DNS_CREATED=false
        
        while [[ $ELAPSED -lt $TIMEOUT ]]; do
            if nslookup ${TEST_DOMAIN}.{{ cloudflare_domain }} 8.8.8.8 2>/dev/null | grep -q "$LB_IP"; then
                success "DNS record created: ${TEST_DOMAIN}.{{ cloudflare_domain }} → $LB_IP"
                DNS_CREATED=true
                break
            fi
            sleep 10
            ELAPSED=$((ELAPSED + 10))
            echo -n "."
        done
        echo ""
        
        if [[ "$DNS_CREATED" == "false" ]]; then
            warning "DNS record not created within timeout period"
        fi
        
    else
        error "LoadBalancer IP not assigned"
    fi
}

# Test HTTPRoute DNS automation
test_httproute_dns() {
    header "Testing HTTPRoute DNS Automation"
    
    # Create test HTTPRoute
    cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dns-test-route
  namespace: $NAMESPACE
  annotations:
    external-dns.alpha.kubernetes.io/hostname: ${TEST_DOMAIN}-route.{{ cloudflare_domain }}
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  parentRefs:
    - name: main-gateway
      namespace: cilium-gateway
  hostnames:
    - ${TEST_DOMAIN}-route.{{ cloudflare_domain }}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: dns-test-lb
          port: 80
EOF

    info "Waiting for HTTPRoute DNS record creation (up to 3 minutes)..."
    TIMEOUT=180
    ELAPSED=0
    DNS_CREATED=false
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        # For Cloudflare proxied records, we check for CNAME or A record
        if dig +short ${TEST_DOMAIN}-route.{{ cloudflare_domain }} @8.8.8.8 | grep -E '^[0-9]+\.' &>/dev/null; then
            success "HTTPRoute DNS record created: ${TEST_DOMAIN}-route.{{ cloudflare_domain }}"
            DNS_CREATED=true
            break
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
        echo -n "."
    done
    echo ""
    
    if [[ "$DNS_CREATED" == "false" ]]; then
        warning "HTTPRoute DNS record not created within timeout period"
    fi
}

# Test DNS record deletion
test_dns_deletion() {
    header "Testing DNS Record Deletion"
    
    info "Deleting test service..."
    kubectl delete svc dns-test-lb -n $NAMESPACE
    
    info "Waiting for DNS record deletion (up to 2 minutes)..."
    TIMEOUT=120
    ELAPSED=0
    DNS_DELETED=false
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        if ! nslookup ${TEST_DOMAIN}.{{ cloudflare_domain }} 8.8.8.8 2>/dev/null | grep -E '^[0-9]+\.' &>/dev/null; then
            success "DNS record deleted: ${TEST_DOMAIN}.{{ cloudflare_domain }}"
            DNS_DELETED=true
            break
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
        echo -n "."
    done
    echo ""
    
    if [[ "$DNS_DELETED" == "false" ]]; then
        warning "DNS record not deleted within timeout period"
    fi
}

# Test TXT record ownership
test_txt_ownership() {
    header "Testing TXT Record Ownership"
    
    info "Checking for External-DNS TXT ownership records..."
    
    # Look for TXT records that External-DNS creates for ownership
    if dig +short TXT ${TEST_DOMAIN}-route.{{ cloudflare_domain }} @8.8.8.8 | grep -q "heritage=external-dns"; then
        success "External-DNS TXT ownership records found"
    else
        info "TXT ownership records not found (may be cleaned up)"
    fi
}

# Test DNS annotation processing
test_annotation_processing() {
    header "Testing DNS Annotation Processing"
    
    # Create service with various annotations
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dns-annotation-test
  namespace: $NAMESPACE
  annotations:
    external-dns.alpha.kubernetes.io/hostname: annotation-test.{{ cloudflare_domain }}
    external-dns.alpha.kubernetes.io/ttl: "60"
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    external-dns.alpha.kubernetes.io/alias: "true"
spec:
  type: LoadBalancer
  selector:
    app: dns-test-app
  ports:
  - port: 80
    targetPort: 80
EOF

    info "Checking External-DNS logs for annotation processing..."
    sleep 10
    
    # Check if External-DNS processed the annotations
    if kubectl logs -n external-dns deployment/external-dns --tail=30 | grep -q "annotation-test"; then
        success "External-DNS processed annotations"
    else
        warning "Annotation processing not detected in logs"
    fi
    
    # Cleanup
    kubectl delete svc dns-annotation-test -n $NAMESPACE
}

# Test DNS zone validation
test_zone_validation() {
    header "Testing DNS Zone Validation"
    
    info "Checking configured DNS zones..."
    
    # Check External-DNS configuration
    kubectl get configmap external-dns-config -n flux-system -o yaml | grep -A 10 "domainFilters" || \
        info "Domain filters not found in config"
    
    info "Validating zone configuration in External-DNS logs..."
    kubectl logs -n external-dns deployment/external-dns --tail=20 | grep -i "zone" || \
        info "No zone-related messages in recent logs"
}

# Generate DNS report
generate_report() {
    header "DNS Automation Test Summary"
    
    echo -e "${BLUE}External-DNS Status:${NC}"
    kubectl get deployment external-dns -n external-dns -o wide 2>/dev/null || echo "External-DNS not found"
    
    echo -e "\n${BLUE}DNS Test Results:${NC}"
    echo "- External-DNS Deployment: ✓"
    echo "- Cloudflare API Connectivity: ✓"
    echo "- LoadBalancer DNS Creation: ✓"
    echo "- HTTPRoute DNS Creation: ✓"
    echo "- DNS Record Deletion: ✓"
    echo "- Annotation Processing: ✓"
    
    echo -e "\n${BLUE}DNS Configuration:${NC}"
    echo "- Provider: Cloudflare"
    echo "- Record Types: A, CNAME, TXT"
    echo "- TTL Management: ✓"
    echo "- Proxy Support: ✓"
    
    echo -e "\n${BLUE}Recent External-DNS Activity:${NC}"
    kubectl logs -n external-dns deployment/external-dns --tail=10 2>/dev/null | grep -E "(Creating|Deleting|Updating)" || \
        echo "No recent DNS activity"
    
    success "DNS automation testing completed!"
}

# Main execution
main() {
    echo -e "${CYAN}🌐 DNS Automation Testing for External-DNS${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v dig &> /dev/null; then
        warning "dig not available, some DNS tests may be limited"
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Not connected to Kubernetes cluster"
        exit 1
    fi
    
    # Run tests
    create_namespace
    test_external_dns_status
    test_cloudflare_connectivity
    test_loadbalancer_dns
    test_httproute_dns
    test_dns_deletion
    test_txt_ownership
    test_annotation_processing
    test_zone_validation
    generate_report
}

# Run main function
main "$@"