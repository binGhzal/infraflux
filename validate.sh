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
