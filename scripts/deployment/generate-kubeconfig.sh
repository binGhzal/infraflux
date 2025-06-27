#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created modular kubeconfig generation script
# - [ ] Add support for generating multiple kubeconfig contexts
# - [ ] Add automatic kubeconfig validation
# - [ ] Add support for custom kubeconfig paths
# - [ ] Add integration with system kubectl config

# Load common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/../lib/common.sh"

# Change to project root
cd "$(get_project_root)"

# Function to generate kubeconfig
generate_kubeconfig() {
    print_status "Generating kubeconfig file..."

    # Verify prerequisites
    if [ ! -f "configuration/ansible.cfg" ]; then
        print_error "Ansible configuration file not found. Make sure Terraform has been applied successfully."
        return 1
    fi

    if [ ! -f "ansible/RKE2/inventory/hosts.ini" ]; then
        print_error "Ansible inventory file not found. Make sure Terraform has been applied successfully."
        return 1
    fi

    # Change to Ansible directory
    cd ansible/RKE2

    # Run only the kubeconfig manager role
    print_status "Running kubeconfig generation..."
    if ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts.ini -l servers[0] --tags kubeconfig_manager site.yaml; then
        cd ../..

        # Validate the generated kubeconfig
        if [ -f "kubeconfig" ]; then
            print_success "Kubeconfig generated successfully"
            print_status "Kubeconfig location: $(pwd)/kubeconfig"
            
            # Run basic validation
            if validate_kubeconfig; then
                print_success "Kubeconfig validation passed"
                return 0
            else
                print_warning "Kubeconfig validation failed, but file exists"
                return 1
            fi
        else
            print_error "Kubeconfig file was not generated"
            return 1
        fi
    else
        print_error "Failed to generate kubeconfig"
        cd ../..
        return 1
    fi
}

# Function to validate kubeconfig
validate_kubeconfig() {
    print_status "Validating kubeconfig..."
    
    if [ ! -f "kubeconfig" ]; then
        print_error "Kubeconfig file not found"
        return 1
    fi

    # Check if kubectl is available
    if ! command_exists kubectl; then
        print_warning "kubectl not found, skipping kubeconfig validation"
        return 0
    fi

    # Test kubeconfig structure
    if ! kubectl --kubeconfig=./kubeconfig config view >/dev/null 2>&1; then
        print_error "Kubeconfig file is invalid or corrupted"
        return 1
    fi

    # Test cluster connectivity
    print_status "Testing cluster connectivity..."
    if kubectl --kubeconfig=./kubeconfig get nodes --no-headers >/dev/null 2>&1; then
        local node_count=$(kubectl --kubeconfig=./kubeconfig get nodes --no-headers | wc -l)
        print_success "Cluster connectivity test passed - $node_count nodes found"
        return 0
    else
        print_error "Cannot connect to cluster using generated kubeconfig"
        return 1
    fi
}

# Function to show kubeconfig usage information
show_kubeconfig_usage() {
    echo ""
    echo "=== Kubeconfig Usage ==="
    echo "Export kubeconfig:"
    echo "  export KUBECONFIG=\$(pwd)/kubeconfig"
    echo ""
    echo "Test cluster access:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo ""
    echo "Use with specific kubeconfig:"
    echo "  kubectl --kubeconfig=./kubeconfig get nodes"
    echo ""
}

# Run the generation if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if generate_kubeconfig; then
        show_kubeconfig_usage
        exit 0
    else
        exit 1
    fi
fi