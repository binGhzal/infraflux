#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created modular infrastructure deployment script
# - [ ] Add dry-run mode support
# - [ ] Add state backup functionality
# - [ ] Add rollback capability
# - [ ] Add terraform workspace support

# Load common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/../lib/common.sh"

# Change to project root and infrastructure directory
PROJECT_ROOT="$(get_project_root)"
cd "${PROJECT_ROOT}/infrastructure"

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."

    # Initialize Terraform
    print_status "Initializing Terraform..."
    if ! terraform init; then
        print_error "Terraform initialization failed"
        return 1
    fi

    # Validate Terraform configuration
    print_status "Validating Terraform configuration..."
    if ! terraform validate; then
        print_error "Terraform validation failed"
        return 1
    fi

    # Run terraform plan
    print_status "Running terraform plan..."
    if ! terraform plan -out=tfplan; then
        print_error "Terraform plan failed"
        return 1
    fi

    # Ask for confirmation unless in auto-approve mode
    if [ "${AUTO_APPROVE:-}" != "true" ]; then
        read -p "Do you want to proceed with terraform apply? (y/N): " confirm
        if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
            print_warning "Terraform deployment cancelled"
            return 0
        fi
    fi

    # Apply the plan
    print_status "Applying Terraform configuration..."
    if terraform apply tfplan; then
        # Clean up plan file
        rm -f tfplan
        print_success "Infrastructure deployed successfully"
        return 0
    else
        print_error "Terraform apply failed"
        return 1
    fi
}

# Run the deployment if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    deploy_infrastructure
    exit $?
fi