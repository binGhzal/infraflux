#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created modular prerequisites check script
# - [ ] Add version checks for required tools
# - [ ] Add check for required Ansible collections
# - [ ] Add check for network connectivity to Proxmox

# Load common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Change to project root
cd "$(get_project_root)"

# Function to check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local has_errors=false

    # Check if terraform is installed
    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install Terraform first."
        has_errors=true
    else
        local terraform_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
        print_status "Terraform version: $terraform_version"
    fi

    # Check if ansible is installed
    if ! command_exists ansible; then
        print_error "Ansible is not installed. Please install Ansible first."
        has_errors=true
    else
        local ansible_version=$(ansible --version | head -n1 | awk '{print $2}')
        print_status "Ansible version: $ansible_version"
    fi

    # Check if jq is installed
    if ! command_exists jq; then
        print_error "jq is not installed. Please install jq first."
        has_errors=true
    fi

    # Check if kubectl is installed
    if ! command_exists kubectl; then
        print_warning "kubectl is not installed. It's recommended for testing the cluster."
    fi

    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_error "terraform.tfvars not found. Please copy terraform.tfvars.example to terraform.tfvars and configure it."
        has_errors=true
    fi

    # Check SSH key configuration
    if [ -f "terraform.tfvars" ]; then
        local ssh_key_file=$(grep ssh_private_key_file terraform.tfvars | cut -d'"' -f2 | sed 's/~/'"$HOME"'/g' 2>/dev/null)
        if [ -n "$ssh_key_file" ] && [ ! -f "$ssh_key_file" ]; then
            print_error "SSH private key file not found: $ssh_key_file"
            has_errors=true
        fi
    fi

    if [ "$has_errors" = true ]; then
        print_error "Prerequisites check failed"
        return 1
    fi

    print_success "Prerequisites check passed"
    return 0
}

# Run the check if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    check_prerequisites
    exit $?
fi