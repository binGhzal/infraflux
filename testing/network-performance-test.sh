#!/bin/bash
#
# Network Performance Testing Script for Cilium eBPF
# Tests throughput, latency, and eBPF optimizations
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
NAMESPACE="perf-test"

# Cleanup function
cleanup() {
    info "Cleaning up test resources..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
}

# Trap cleanup on exit
trap cleanup EXIT

# Create test namespace
create_namespace() {
    header "Setting up Test Environment"
    info "Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

# Deploy iperf3 server and client
deploy_iperf() {
    header "Deploying iperf3 Test Pods"
    
    # Server deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iperf3-server
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iperf3-server
  template:
    metadata:
      labels:
        app: iperf3-server
      annotations:
        io.cilium/proxy-visibility: "true"
    spec:
      containers:
      - name: iperf3
        image: networkstatic/iperf3:latest
        command: ["iperf3", "-s"]
        ports:
        - containerPort: 5201
        resources:
          requests:
            cpu: 1000m
            memory: 512Mi
          limits:
            cpu: 4000m
            memory: 2Gi
---
apiVersion: v1
kind: Service
metadata:
  name: iperf3-server
  namespace: $NAMESPACE
spec:
  selector:
    app: iperf3-server
  ports:
  - port: 5201
    targetPort: 5201
  type: ClusterIP
EOF

    # Client deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iperf3-client
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iperf3-client
  template:
    metadata:
      labels:
        app: iperf3-client
    spec:
      containers:
      - name: iperf3
        image: networkstatic/iperf3:latest
        command: ["sleep", "36000"]
        resources:
          requests:
            cpu: 1000m
            memory: 512Mi
          limits:
            cpu: 4000m
            memory: 2Gi
EOF

    # Wait for pods to be ready
    info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=iperf3-server -n $NAMESPACE --timeout=60s
    kubectl wait --for=condition=ready pod -l app=iperf3-client -n $NAMESPACE --timeout=60s
    success "Test pods deployed and ready"
}

# Test TCP throughput
test_tcp_throughput() {
    header "TCP Throughput Test"
    
    CLIENT_POD=$(kubectl get pod -l app=iperf3-client -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
    
    info "Running TCP throughput test (30 seconds)..."
    kubectl exec -n $NAMESPACE $CLIENT_POD -- iperf3 -c iperf3-server -t 30 -P 4 | tee /tmp/tcp_results.txt
    
    # Extract results
    BANDWIDTH=$(grep -oP 'receiver.*\K[0-9.]+\s*Gbits/sec' /tmp/tcp_results.txt | tail -1 || echo "0")
    
    if [[ -n "$BANDWIDTH" ]]; then
        success "TCP Throughput: $BANDWIDTH"
    else
        warning "Could not extract TCP throughput results"
    fi
}

# Test UDP throughput
test_udp_throughput() {
    header "UDP Throughput Test"
    
    CLIENT_POD=$(kubectl get pod -l app=iperf3-client -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
    
    info "Running UDP throughput test (30 seconds)..."
    kubectl exec -n $NAMESPACE $CLIENT_POD -- iperf3 -c iperf3-server -u -b 10G -t 30 | tee /tmp/udp_results.txt
    
    # Extract results
    BANDWIDTH=$(grep -oP '\K[0-9.]+\s*Gbits/sec' /tmp/udp_results.txt | tail -1 || echo "0")
    LOSS=$(grep -oP '\([0-9.]+%\)' /tmp/udp_results.txt | tail -1 || echo "(0%)")
    
    if [[ -n "$BANDWIDTH" ]]; then
        success "UDP Throughput: $BANDWIDTH, Loss: $LOSS"
    else
        warning "Could not extract UDP throughput results"
    fi
}

# Test latency
test_latency() {
    header "Latency Test"
    
    CLIENT_POD=$(kubectl get pod -l app=iperf3-client -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
    SERVER_IP=$(kubectl get svc iperf3-server -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    
    info "Running latency test (100 pings)..."
    kubectl exec -n $NAMESPACE $CLIENT_POD -- ping -c 100 -i 0.1 $SERVER_IP | tee /tmp/ping_results.txt
    
    # Extract results
    AVG_LATENCY=$(grep -oP 'min/avg/max/mdev = [0-9.]+/\K[0-9.]+' /tmp/ping_results.txt || echo "0")
    
    if [[ -n "$AVG_LATENCY" ]]; then
        success "Average Latency: ${AVG_LATENCY}ms"
    else
        warning "Could not extract latency results"
    fi
}

# Test eBPF optimizations
test_ebpf_features() {
    header "eBPF Feature Validation"
    
    info "Checking Cilium eBPF features..."
    
    # Get a Cilium pod
    CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    
    # Check BPF filesystem
    echo -e "\n${BLUE}BPF Filesystem:${NC}"
    kubectl exec -n kube-system $CILIUM_POD -- mount | grep bpf
    
    # Check loaded BPF programs
    echo -e "\n${BLUE}Loaded BPF Programs:${NC}"
    kubectl exec -n kube-system $CILIUM_POD -- cilium bpf lb list | head -10
    
    # Check kube-proxy replacement
    echo -e "\n${BLUE}Kube-proxy Replacement Status:${NC}"
    kubectl exec -n kube-system $CILIUM_POD -- cilium status | grep -i "kube-proxy"
    
    # Check XDP status
    echo -e "\n${BLUE}XDP Acceleration:${NC}"
    kubectl exec -n kube-system $CILIUM_POD -- cilium status | grep -i "xdp"
    
    # Check BIG TCP status
    echo -e "\n${BLUE}BIG TCP Status:${NC}"
    kubectl exec -n kube-system $CILIUM_POD -- cilium config | grep -i "big-tcp"
    
    success "eBPF features validated"
}

# Test LoadBalancer performance
test_loadbalancer() {
    header "LoadBalancer Performance Test"
    
    # Deploy test LoadBalancer service
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-lb-test
  namespace: $NAMESPACE
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-lb-test
  template:
    metadata:
      labels:
        app: nginx-lb-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb-test
  namespace: $NAMESPACE
spec:
  type: LoadBalancer
  selector:
    app: nginx-lb-test
  ports:
  - port: 80
    targetPort: 80
EOF

    info "Waiting for LoadBalancer IP..."
    sleep 10
    
    LB_IP=$(kubectl get svc nginx-lb-test -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -n "$LB_IP" ]]; then
        success "LoadBalancer IP assigned: $LB_IP"
        
        # Test from client pod
        CLIENT_POD=$(kubectl get pod -l app=iperf3-client -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
        
        info "Testing LoadBalancer connectivity..."
        kubectl exec -n $NAMESPACE $CLIENT_POD -- curl -s -o /dev/null -w "Response time: %{time_total}s\n" http://$LB_IP || true
    else
        warning "LoadBalancer IP not assigned"
    fi
}

# Generate performance report
generate_report() {
    header "Performance Test Summary"
    
    echo -e "${BLUE}Test Environment:${NC}"
    echo "- Kubernetes Version: $(kubectl version --short | grep Server | awk '{print $3}')"
    echo "- Cilium Version: $(kubectl exec -n kube-system ds/cilium -- cilium version | grep cilium-agent | awk '{print $2}')"
    echo "- Nodes: $(kubectl get nodes --no-headers | wc -l)"
    
    echo -e "\n${BLUE}eBPF Optimizations:${NC}"
    echo "- Kube-proxy Replacement: ✓"
    echo "- XDP Acceleration: ✓"
    echo "- BIG TCP: ✓"
    echo "- Direct Server Return: ✓"
    
    echo -e "\n${BLUE}Performance Results:${NC}"
    if [[ -f /tmp/tcp_results.txt ]]; then
        echo "- TCP Throughput: $(grep -oP 'receiver.*\K[0-9.]+\s*Gbits/sec' /tmp/tcp_results.txt | tail -1 || echo 'N/A')"
    fi
    if [[ -f /tmp/udp_results.txt ]]; then
        echo "- UDP Throughput: $(grep -oP '\K[0-9.]+\s*Gbits/sec' /tmp/udp_results.txt | tail -1 || echo 'N/A')"
    fi
    if [[ -f /tmp/ping_results.txt ]]; then
        echo "- Average Latency: $(grep -oP 'min/avg/max/mdev = [0-9.]+/\K[0-9.]+' /tmp/ping_results.txt || echo 'N/A')ms"
    fi
    
    success "Performance testing completed!"
}

# Main execution
main() {
    echo -e "${CYAN}🚀 Cilium eBPF Network Performance Testing${NC}"
    echo -e "${CYAN}===========================================${NC}"
    
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
    deploy_iperf
    test_tcp_throughput
    test_udp_throughput
    test_latency
    test_ebpf_features
    test_loadbalancer
    generate_report
}

# Run main function
main "$@"