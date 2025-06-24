#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created modular cluster validation script
# - [ ] Add more comprehensive cluster health checks
# - [ ] Add network connectivity tests
# - [ ] Add storage validation tests
# - [ ] Add security compliance checks

# Load common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Change to project root
cd "$(get_project_root)"

# Function to validate cluster deployment
validate_cluster() {
    print_status "Validating cluster deployment..."
    
    local validation_failed=false

    # Check if the main validation script exists
    if [ -f "./validate.sh" ]; then
        print_status "Running main validation script..."
        if ./validate.sh; then
            print_success "Main validation script passed"
        else
            print_error "Main validation script failed"
            validation_failed=true
        fi
    else
        print_warning "Main validation script (validate.sh) not found"
    fi

    # Run additional validation checks
    if ! validate_infrastructure; then
        validation_failed=true
    fi

    if ! validate_kubeconfig_access; then
        validation_failed=true
    fi

    if ! validate_cluster_nodes; then
        validation_failed=true
    fi

    if [ "$validation_failed" = true ]; then
        print_error "Cluster validation failed"
        return 1
    else
        print_success "All cluster validation checks passed"
        return 0
    fi
}

# Function to validate infrastructure components
validate_infrastructure() {
    print_status "Validating infrastructure components..."
    
    # Check if Terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        print_error "Terraform state file not found"
        return 1
    fi

    # Check if required outputs exist
    if ! terraform output rke2_server_ips >/dev/null 2>&1; then
        print_error "Terraform outputs not available"
        return 1
    fi

    # Validate server IPs
    local server_ips=$(terraform output -json rke2_server_ips 2>/dev/null)
    if [ -z "$server_ips" ] || [ "$server_ips" = "null" ]; then
        print_error "No server IPs found in Terraform output"
        return 1
    fi

    local server_count=$(echo "$server_ips" | jq -r '. | length' 2>/dev/null)
    print_status "Found $server_count server nodes"

    # Validate agent IPs
    local agent_ips=$(terraform output -json rke2_agent_ips 2>/dev/null)
    if [ -n "$agent_ips" ] && [ "$agent_ips" != "null" ]; then
        local agent_count=$(echo "$agent_ips" | jq -r '. | length' 2>/dev/null)
        print_status "Found $agent_count agent nodes"
    fi

    print_success "Infrastructure validation passed"
    return 0
}

# Function to validate kubeconfig access
validate_kubeconfig_access() {
    print_status "Validating kubeconfig access..."
    
    if [ ! -f "kubeconfig" ]; then
        print_error "Kubeconfig file not found"
        return 1
    fi

    if ! command_exists kubectl; then
        print_warning "kubectl not available, skipping kubeconfig access validation"
        return 0
    fi

    # Test basic cluster access
    if ! kubectl --kubeconfig=./kubeconfig cluster-info >/dev/null 2>&1; then
        print_error "Cannot access cluster using kubeconfig"
        return 1
    fi

    print_success "Kubeconfig access validation passed"
    return 0
}

# Function to validate cluster nodes
validate_cluster_nodes() {
    print_status "Validating cluster nodes..."
    
    if ! command_exists kubectl; then
        print_warning "kubectl not available, skipping node validation"
        return 0
    fi

    if [ ! -f "kubeconfig" ]; then
        print_error "Kubeconfig file not found"
        return 1
    fi

    # Check node status
    local nodes_output=$(kubectl --kubeconfig=./kubeconfig get nodes --no-headers 2>/dev/null)
    if [ -z "$nodes_output" ]; then
        print_error "No nodes found in cluster"
        return 1
    fi

    local total_nodes=$(echo "$nodes_output" | wc -l)
    local ready_nodes=$(echo "$nodes_output" | grep -c "Ready" || echo "0")
    
    print_status "Cluster nodes: $ready_nodes/$total_nodes Ready"
    
    if [ "$ready_nodes" -eq "$total_nodes" ]; then
        print_success "All nodes are in Ready state"
        return 0
    else
        print_error "Some nodes are not in Ready state"
        echo "$nodes_output"
        return 1
    fi
}

# Function to run comprehensive validation
run_comprehensive_validation() {
    print_status "Running comprehensive cluster validation..."
    
    echo "=== Cluster Validation Report ==="
    echo "Timestamp: $(date)"
    echo ""
    
    validate_cluster
    local exit_code=$?
    
    echo ""
    echo "=== Validation Summary ==="
    if [ $exit_code -eq 0 ]; then
        print_success "✅ Cluster validation completed successfully"
        echo "Your RKE2 cluster is ready for use!"
    else
        print_error "❌ Cluster validation failed"
        echo "Please check the errors above and fix them before proceeding."
    fi
    
    return $exit_code
}

# Run the validation if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    run_comprehensive_validation
    exit $?
fi