#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created modular RKE2 deployment script
# - [ ] Add support for deploying specific roles only
# - [ ] Add progress tracking for long deployments
# - [ ] Add retry mechanism for failed deployments
# - [ ] Add support for custom Ansible tags

# Load common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/../lib/common.sh"

# Change to project root
PROJECT_ROOT="$(get_project_root)"
cd "${PROJECT_ROOT}"

# Function to deploy RKE2 cluster
deploy_rke2() {
    print_status "Deploying RKE2 cluster with Ansible..."

    # Verify prerequisites
    if [ ! -f "configuration/ansible.cfg" ]; then
        print_error "Ansible configuration file not found. Make sure Terraform has been applied successfully."
        return 1
    fi

    if [ ! -f "configuration/inventory/hosts.ini" ]; then
        print_error "Ansible inventory file not found. Make sure Terraform has been applied successfully."
        return 1
    fi

    # Change to Ansible directory
    cd configuration

    # Display inventory information
    print_status "Checking cluster inventory..."
    local server_count=$(grep -c '\[servers\]' inventory/hosts.ini 2>/dev/null || echo "0")
    local agent_count=$(grep -c '\[agents\]' inventory/hosts.ini 2>/dev/null || echo "0")
    print_status "Found $server_count server nodes and $agent_count agent nodes"

# Run the Ansible playbook
    print_status "Running Ansible playbook..."
    if ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts.ini site.yaml; then
        print_success "RKE2 cluster deployed successfully"
        cd ..
        return 0
    else
        print_error "RKE2 deployment failed"
        cd ..
        return 1
    fi
}

# Function to deploy specific Ansible tags
deploy_rke2_with_tags() {
    local tags="$1"
    print_status "Deploying RKE2 cluster with tags: $tags"

    # Verify prerequisites
    if [ ! -f "configuration/ansible.cfg" ]; then
        print_error "Ansible configuration file not found. Make sure Terraform has been applied successfully."
        return 1
    fi

    if [ ! -f "configuration/inventory/hosts.ini" ]; then
        print_error "Ansible inventory file not found. Make sure Terraform has been applied successfully."
        return 1
    fi

    # Change to Ansible directory
    cd configuration

    # Run the Ansible playbook with specific tags
    print_status "Running Ansible playbook with tags: $tags"
    if ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts.ini --tags "$tags" site.yaml; then
        print_success "RKE2 deployment (tags: $tags) completed successfully"
        cd ..
        return 0
    else
        print_error "RKE2 deployment (tags: $tags) failed"
        cd ..
        return 1
    fi
}

# Run the deployment if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ -n "$1" ]; then
        deploy_rke2_with_tags "$1"
    else
        deploy_rke2
    fi
    exit $?
fi