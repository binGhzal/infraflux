#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created modular cluster information display script
# - [ ] Add cluster resource usage information
# - [ ] Add network configuration details
# - [ ] Add storage information
# - [ ] Add security configuration summary

# Load common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Change to project root
cd "$(get_project_root)"

# Function to show cluster information
show_cluster_info() {
    print_status "RKE2 cluster deployment completed!"
    echo ""
    echo "=== Access Information ==="
    
    # Show SSH access information
    if terraform output rke2_server_ips >/dev/null 2>&1; then
        local first_server_ip=$(terraform output -json rke2_server_ips 2>/dev/null | jq -r '.[0]' 2>/dev/null)
        if [ -n "$first_server_ip" ] && [ "$first_server_ip" != "null" ]; then
            local vm_username=$(terraform output -raw vm_username 2>/dev/null || echo "ansible")
            echo "1. SSH to the first server node:"
            echo "   ssh ${vm_username}@${first_server_ip}"
        fi
    fi
    
    echo ""
    echo "2. Kubeconfig has been automatically configured:"
    echo "   Project kubeconfig: ./kubeconfig"
    echo "   Test kubeconfig: ./test-kubeconfig.sh"
    echo "   Test access: kubectl --kubeconfig=./kubeconfig get nodes"
    echo ""
    echo "3. Validation commands:"
    echo "   ./scripts/validate-cluster.sh     # Comprehensive cluster validation"
    echo "   ./test-kubeconfig.sh              # Test kubeconfig structure and connectivity"
    echo "   ./test-cluster.sh                 # Test cluster functionality"
    echo ""
    
    show_cluster_details
    show_next_steps
}

# Function to show detailed cluster information
show_cluster_details() {
    echo "=== Cluster Information ==="
    
    # Show cluster endpoint
    if terraform output rke2_cluster_endpoint >/dev/null 2>&1; then
        local cluster_endpoint=$(terraform output -raw rke2_cluster_endpoint 2>/dev/null)
        echo "- API Server VIP: $cluster_endpoint"
    fi
    
    # Show external endpoint if configured
    if terraform output -raw external_endpoint >/dev/null 2>&1; then
        local external_endpoint=$(terraform output -raw external_endpoint 2>/dev/null)
        if [ -n "$external_endpoint" ] && [ "$external_endpoint" != "" ]; then
            echo "- External Endpoint: $external_endpoint (for remote access)"
        fi
    fi
    
    echo "- Cluster is ready for GitOps deployment"
    echo ""
    
    # Show server IPs
    if terraform output -json rke2_server_ips >/dev/null 2>&1; then
        echo "Server IPs:"
        terraform output -json rke2_server_ips 2>/dev/null | jq -r '.[]' | sed 's/^/  - /' 2>/dev/null
    fi
    
    # Show agent IPs
    if terraform output -json rke2_agent_ips >/dev/null 2>&1; then
        echo ""
        echo "Agent IPs:"
        terraform output -json rke2_agent_ips 2>/dev/null | jq -r '.[]' | sed 's/^/  - /' 2>/dev/null
    fi
    
    echo ""
}

# Function to show next steps
show_next_steps() {
    echo "=== Next Steps ==="
    echo "1. Export kubeconfig for local use:"
    echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
    echo ""
    echo "2. Verify cluster is working:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -A"
    echo ""
    echo "3. Set up GitOps with FluxCD or ArgoCD:"
    echo "   # FluxCD installation example"
    echo "   flux install --export > flux-system.yaml"
    echo "   kubectl apply -f flux-system.yaml"
    echo ""
    echo "4. Deploy applications via GitOps:"
    echo "   - Create your GitOps repository"
    echo "   - Deploy MetalLB via Kustomize/Flux"
    echo "   - Deploy your applications"
    echo ""
    echo "Note: This is a base RKE2 installation."
    echo "All Kubernetes components should be deployed via GitOps!"
}

# Function to show cluster status
show_cluster_status() {
    print_status "Checking cluster status..."
    
    if [ ! -f "kubeconfig" ]; then
        print_error "Kubeconfig not found. Run './scripts/generate-kubeconfig.sh' first"
        return 1
    fi
    
    if ! command_exists kubectl; then
        print_warning "kubectl not available. Install kubectl to see cluster status"
        return 0
    fi
    
    echo ""
    echo "=== Cluster Status ==="
    
    # Show cluster info
    print_status "Cluster Information:"
    kubectl --kubeconfig=./kubeconfig cluster-info 2>/dev/null || print_error "Cannot connect to cluster"
    
    echo ""
    print_status "Node Status:"
    kubectl --kubeconfig=./kubeconfig get nodes -o wide 2>/dev/null || print_error "Cannot get node status"
    
    echo ""
    print_status "System Pods:"
    kubectl --kubeconfig=./kubeconfig get pods -n kube-system 2>/dev/null || print_error "Cannot get system pods"
    
    echo ""
    print_status "Cluster Version:"
    kubectl --kubeconfig=./kubeconfig version --short 2>/dev/null || print_error "Cannot get cluster version"
}

# Run the appropriate function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    case "${1:-info}" in
        "info")
            show_cluster_info
            ;;
        "status")
            show_cluster_status
            ;;
        *)
            show_cluster_info
            ;;
    esac
fi