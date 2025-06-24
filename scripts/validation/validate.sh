#!/bin/bash

# RKE2 Cluster Validation Script
# This script validates that the RKE2 cluster is properly deployed and functional

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get server IPs from Terraform output
get_server_ips() {
    if command -v terraform &>/dev/null && [ -f "terraform.tfstate" ]; then
        terraform output -json rke2_server_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo ""
    fi
}

# Get VIP from Terraform output
get_vip() {
    if command -v terraform &>/dev/null && [ -f "terraform.tfstate" ]; then
        terraform output -raw rke2_cluster_endpoint 2>/dev/null || echo ""
    fi
}

# Test SSH connectivity
test_ssh_connectivity() {
    print_status "Testing SSH connectivity to cluster nodes..."

    local server_ips=$(get_server_ips)
    if [ -z "$server_ips" ]; then
        print_error "Could not get server IPs from Terraform output"
        return 1
    fi

    local first_server=$(echo "$server_ips" | head -1)

    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no binghzal@$first_server 'echo "Connected"' >/dev/null 2>&1; then
        print_success "SSH connectivity to first server ($first_server) successful"
        return 0
    else
        print_error "SSH connectivity to first server ($first_server) failed"
        return 1
    fi
}

# Test cluster nodes
test_cluster_nodes() {
    print_status "Testing cluster node status..."

    local server_ips=$(get_server_ips)
    local first_server=$(echo "$server_ips" | head -1)

    if [ -z "$first_server" ]; then
        print_error "Could not determine first server IP"
        return 1
    fi

    local node_output
    if node_output=$(ssh -o StrictHostKeyChecking=no binghzal@$first_server 'kubectl get nodes --no-headers' 2>/dev/null); then
        local node_count=$(echo "$node_output" | wc -l)
        local ready_count=$(echo "$node_output" | grep -c "Ready" || true)

        print_success "Cluster has $node_count nodes, $ready_count are Ready"

        if [ "$node_count" -eq "$ready_count" ]; then
            print_success "All nodes are in Ready state"
            return 0
        else
            print_warning "Some nodes are not Ready"
            echo "$node_output"
            return 1
        fi
    else
        print_error "Could not get cluster node status"
        return 1
    fi
}

# Test VIP access
test_vip_access() {
    print_status "Testing VIP access..."

    local vip=$(get_vip)
    local server_ips=$(get_server_ips)
    local first_server=$(echo "$server_ips" | head -1)

    if [ -z "$vip" ] || [ -z "$first_server" ]; then
        print_error "Could not determine VIP or first server IP"
        return 1
    fi

    if ssh -o StrictHostKeyChecking=no binghzal@$first_server "kubectl --server=https://$vip:6443 --insecure-skip-tls-verify get nodes >/dev/null 2>&1"; then
        print_success "VIP access ($vip) is working correctly"
        return 0
    else
        print_error "VIP access ($vip) failed"
        return 1
    fi
}

# Test cluster services
test_cluster_services() {
    print_status "Testing cluster system services..."

    local server_ips=$(get_server_ips)
    local first_server=$(echo "$server_ips" | head -1)

    if [ -z "$first_server" ]; then
        print_error "Could not determine first server IP"
        return 1
    fi

    # Test CoreDNS
    if ssh -o StrictHostKeyChecking=no binghzal@$first_server 'kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -q Running' 2>/dev/null; then
        print_success "CoreDNS is running"
    else
        print_warning "CoreDNS status unknown"
    fi

    # Test Canal CNI
    if ssh -o StrictHostKeyChecking=no binghzal@$first_server 'kubectl get pods -n kube-system -l app=canal --no-headers | grep -q Running' 2>/dev/null; then
        print_success "Canal CNI is running"
    else
        print_warning "Canal CNI status unknown"
    fi

    return 0
}

# Display cluster information
display_cluster_info() {
    print_status "Gathering cluster information..."

    local server_ips=$(get_server_ips)
    local agent_ips
    local vip=$(get_vip)

    if command -v terraform &>/dev/null && [ -f "terraform.tfstate" ]; then
        agent_ips=$(terraform output -json rke2_agent_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "")
    fi

    echo ""
    echo "=== RKE2 Cluster Information ==="
    echo "VIP (API Server): https://$vip:6443"
    echo ""
    echo "Server Nodes:"
    for ip in $server_ips; do
        echo "  - $ip"
    done
    echo ""
    echo "Agent Nodes:"
    for ip in $agent_ips; do
        echo "  - $ip"
    done
    echo ""
    echo "Access Methods:"
    echo "1. SSH to any server: ssh binghzal@<server-ip>"
    echo "2. Use kubectl: kubectl get nodes"
    echo "3. Copy kubeconfig: scp binghzal@$(echo "$server_ips" | head -1):.kube/config ~/.kube/config"
    echo ""
    echo "Next Steps:"
    echo "1. Deploy MetalLB via FluxCD/GitOps"
    echo "2. Deploy applications"
    echo "3. Set up monitoring and logging"
}

# Main validation function
main() {
    echo ""
    echo "=== RKE2 Cluster Validation ==="
    echo ""

    local failed=0

    # Run tests
    test_ssh_connectivity || failed=1
    test_cluster_nodes || failed=1
    test_vip_access || failed=1
    test_cluster_services || failed=1

    echo ""

    if [ $failed -eq 0 ]; then
        print_success "All validation tests passed!"
        display_cluster_info
        exit 0
    else
        print_error "Some validation tests failed!"
        display_cluster_info
        exit 1
    fi
}

main "$@"

# Function to check if terraform outputs are available
check_terraform_outputs() {
    print_status "Checking Terraform outputs..."

    if ! terraform output &>/dev/null; then
        print_error "Terraform outputs not available. Run 'terraform apply' first."
        exit 1
    fi

    FIRST_SERVER=$(terraform output -json rke2_server_ips | jq -r '.[0]')
    VIP=$(terraform output -raw rke2_cluster_endpoint)

    if [[ -z "$FIRST_SERVER" || "$FIRST_SERVER" == "null" ]]; then
        print_error "Could not get server IP from Terraform output"
        exit 1
    fi

    print_success "Terraform outputs available"
    echo "  First server: $FIRST_SERVER"
    echo "  Cluster VIP: $VIP"
}

# Function to check node connectivity
check_connectivity() {
    print_status "Checking SSH connectivity to nodes..."

    # Get all server IPs
    SERVER_IPS=$(terraform output -json rke2_server_ips | jq -r '.[]')
    AGENT_IPS=$(terraform output -json rke2_agent_ips | jq -r '.[]')

    failed_connections=0

    for ip in $SERVER_IPS; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ansible@$ip "echo 'Server $ip reachable'" &>/dev/null; then
            print_success "Server $ip is reachable"
        else
            print_error "Server $ip is NOT reachable"
            ((failed_connections++))
        fi
    done

    for ip in $AGENT_IPS; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ansible@$ip "echo 'Agent $ip reachable'" &>/dev/null; then
            print_success "Agent $ip is reachable"
        else
            print_error "Agent $ip is NOT reachable"
            ((failed_connections++))
        fi
    done

    if [[ $failed_connections -gt 0 ]]; then
        print_error "$failed_connections nodes are not reachable"
        exit 1
    fi

    print_success "All nodes are reachable via SSH"
}

# Function to check RKE2 services
check_rke2_services() {
    print_status "Checking RKE2 services..."

    SERVER_IPS=$(terraform output -json rke2_server_ips | jq -r '.[]')
    AGENT_IPS=$(terraform output -json rke2_agent_ips | jq -r '.[]')

    failed_services=0

    # Check server nodes
    for ip in $SERVER_IPS; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ansible@$ip "systemctl is-active rke2-server" &>/dev/null; then
            print_success "RKE2 server service is active on $ip"
        else
            print_error "RKE2 server service is NOT active on $ip"
            ((failed_services++))
        fi
    done

    # Check agent nodes
    for ip in $AGENT_IPS; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ansible@$ip "systemctl is-active rke2-agent" &>/dev/null; then
            print_success "RKE2 agent service is active on $ip"
        else
            print_error "RKE2 agent service is NOT active on $ip"
            ((failed_services++))
        fi
    done

    if [[ $failed_services -gt 0 ]]; then
        print_error "$failed_services RKE2 services are not running properly"
        exit 1
    fi

    print_success "All RKE2 services are running"
}

# Function to check cluster nodes
check_cluster_nodes() {
    print_status "Checking Kubernetes cluster nodes..."

    FIRST_SERVER=$(terraform output -json rke2_server_ips | jq -r '.[0]')

    # Check if kubectl is available and cluster is accessible
    if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get nodes" &>/dev/null; then
        print_error "Cannot access Kubernetes cluster via kubectl"
        exit 1
    fi

    # Get node status
    NODE_STATUS=$(ssh -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get nodes --no-headers" 2>/dev/null)

    if [[ -z "$NODE_STATUS" ]]; then
        print_error "No nodes found in cluster"
        exit 1
    fi

    total_nodes=$(echo "$NODE_STATUS" | wc -l)
    ready_nodes=$(echo "$NODE_STATUS" | grep -c "Ready" || true)

    print_status "Cluster has $total_nodes nodes, $ready_nodes are Ready"

    if [[ $ready_nodes -ne $total_nodes ]]; then
        print_warning "Not all nodes are in Ready state:"
        echo "$NODE_STATUS"
    else
        print_success "All $total_nodes nodes are Ready"
    fi

    # Show node details
    echo ""
    echo "Node details:"
    ssh -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get nodes -o wide" 2>/dev/null
}

# Function to check cluster pods
check_cluster_pods() {
    print_status "Checking system pods..."

    FIRST_SERVER=$(terraform output -json rke2_server_ips | jq -r '.[0]')

    # Check kube-system pods
    SYSTEM_PODS=$(ssh -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get pods -n kube-system --no-headers" 2>/dev/null)

    if [[ -z "$SYSTEM_PODS" ]]; then
        print_error "No system pods found"
        exit 1
    fi

    total_pods=$(echo "$SYSTEM_PODS" | wc -l)
    running_pods=$(echo "$SYSTEM_PODS" | grep -c "Running" || true)

    print_status "kube-system namespace has $total_pods pods, $running_pods are Running"

    if [[ $running_pods -ne $total_pods ]]; then
        print_warning "Not all system pods are Running:"
        echo "$SYSTEM_PODS"
    else
        print_success "All $total_pods system pods are Running"
    fi
}

# Function to check kube-vip
check_kube_vip() {
    print_status "Checking Kube-VIP..."

    FIRST_SERVER=$(terraform output -json rke2_server_ips | jq -r '.[0]')
    VIP=$(terraform output -raw rke2_cluster_endpoint)

    # Check kube-vip pods
    KUBE_VIP_PODS=$(ssh -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip-ds --no-headers" 2>/dev/null)

    if [[ -z "$KUBE_VIP_PODS" ]]; then
        print_warning "No Kube-VIP pods found"
    else
        running_vip_pods=$(echo "$KUBE_VIP_PODS" | grep -c "Running" || true)
        total_vip_pods=$(echo "$KUBE_VIP_PODS" | wc -l)

        if [[ $running_vip_pods -eq $total_vip_pods ]]; then
            print_success "Kube-VIP pods are running ($running_vip_pods/$total_vip_pods)"
        else
            print_warning "Some Kube-VIP pods are not running ($running_vip_pods/$total_vip_pods)"
        fi
    fi

    # Test VIP connectivity
    if curl -k -s --connect-timeout 5 "https://$VIP:6443/healthz" | grep -q "ok"; then
        print_success "Cluster API is accessible via VIP ($VIP)"
    else
        print_warning "Cluster API is not accessible via VIP ($VIP)"
    fi
}

# Function to check MetalLB
check_metallb() {
    print_status "Checking MetalLB..."

    FIRST_SERVER=$(terraform output -json rke2_server_ips | jq -r '.[0]')

    # Check MetalLB namespace exists
    if ssh -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get namespace metallb-system" &>/dev/null; then
        print_success "MetalLB namespace exists"

        # Check MetalLB pods
        METALLB_PODS=$(ssh -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get pods -n metallb-system --no-headers" 2>/dev/null)

        if [[ -n "$METALLB_PODS" ]]; then
            running_metallb_pods=$(echo "$METALLB_PODS" | grep -c "Running" || true)
            total_metallb_pods=$(echo "$METALLB_PODS" | wc -l)

            if [[ $running_metallb_pods -eq $total_metallb_pods ]]; then
                print_success "MetalLB pods are running ($running_metallb_pods/$total_metallb_pods)"
            else
                print_warning "Some MetalLB pods are not running ($running_metallb_pods/$total_metallb_pods)"
            fi
        else
            print_warning "No MetalLB pods found"
        fi

        # Check IP pool
        if ssh -o StrictHostKeyChecking=no ansible@$FIRST_SERVER "kubectl get ipaddresspool -n metallb-system" &>/dev/null; then
            print_success "MetalLB IP address pool is configured"
        else
            print_warning "MetalLB IP address pool is not configured"
        fi
    else
        print_warning "MetalLB namespace does not exist"
    fi
}

# Function to show cluster summary
show_summary() {
    print_status "Cluster Summary:"

    FIRST_SERVER=$(terraform output -json rke2_server_ips | jq -r '.[0]')
    VIP=$(terraform output -raw rke2_cluster_endpoint)
    METALLB_RANGE=$(terraform output -raw metallb_ip_range)

    echo ""
    echo "Cluster Access:"
    echo "  API Server VIP: https://$VIP:6443"
    echo "  SSH to first server: ssh ansible@$FIRST_SERVER"
    echo "  MetalLB IP Range: $METALLB_RANGE"
    echo ""
    echo "Next steps:"
    echo "  1. SSH to first server: ssh ansible@$FIRST_SERVER"
    echo "  2. Test cluster: kubectl get nodes"
    echo "  3. Deploy applications with LoadBalancer services"
}

# Main validation
main() {
    echo "RKE2 Cluster Validation"
    echo "======================="
    echo ""

    check_terraform_outputs
    check_connectivity
    check_rke2_services
    check_cluster_nodes
    check_cluster_pods
    check_kube_vip
    check_metallb

    echo ""
    print_success "Cluster validation completed successfully!"
    show_summary
}

# Run validation
main "$@"
