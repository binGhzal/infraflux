#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Refactored monolithic deploy.sh into modular components
# - [x] Added support for external endpoint configuration
# - [ ] Add configuration file support for deployment settings
# - [ ] Add state management for deployment progress
# - [ ] Add dry-run mode support
# - [ ] Add better error handling and rollback mechanisms

# RKE2 Cluster Deployment Script
# This script automates the deployment of RKE2 cluster using Terraform and Ansible
# Now using modular scripts for better maintainability

set -e

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Load common functions
source "${SCRIPTS_DIR}/lib/common.sh"

# Function to show help
show_help() {
    echo "RKE2 Cluster Deployment Script (Modular Version)"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Deploy complete RKE2 cluster (infrastructure + RKE2)"
    echo "  infra      - Deploy only infrastructure (Terraform)"
    echo "  rke2       - Deploy only RKE2 cluster (Ansible)"
    echo "  validate   - Validate cluster deployment"
    echo "  kubeconfig - Generate kubeconfig file"
    echo "  destroy    - Destroy infrastructure"
    echo "  status     - Show cluster status"
    echo "  help       - Show this help message"
    echo ""
    echo "Options:"
    echo "  --auto-approve  Skip confirmation prompts (for automation)"
    echo "  --dry-run       Show what would be done without executing"
    echo ""
    echo "Examples:"
    echo "  $0 deploy              # Full deployment with confirmations"
    echo "  $0 deploy --auto-approve  # Automated deployment"
    echo "  $0 validate            # Validate cluster"
    echo "  $0 destroy             # Destroy everything"
    echo "  $0 status              # Show cluster info"
    echo ""
    echo "Modular Scripts:"
    echo "  ./scripts/deployment/check-prerequisites.sh     # Check system requirements"
    echo "  ./scripts/deployment/deploy-infrastructure.sh   # Deploy Terraform infrastructure"
    echo "  ./scripts/deployment/setup-ansible.sh           # Setup Ansible environment"
    echo "  ./scripts/deployment/deploy-rke2.sh             # Deploy RKE2 cluster"
    echo "  ./scripts/deployment/generate-kubeconfig.sh     # Generate kubeconfig"
    echo "  ./scripts/validation/validate-cluster.sh        # Validate cluster"
    echo "  ./scripts/deployment/show-cluster-info.sh       # Show cluster information"
    echo "  ./scripts/deployment/destroy-infrastructure.sh  # Destroy infrastructure"
}

# Function to deploy complete cluster
deploy_complete() {
    print_status "Starting complete RKE2 cluster deployment..."
    
    # Run all deployment steps
    if ! "${SCRIPTS_DIR}/deployment/check-prerequisites.sh"; then
        print_error "Prerequisites check failed"
        return 1
    fi

    if ! "${SCRIPTS_DIR}/deployment/deploy-infrastructure.sh"; then
        print_error "Infrastructure deployment failed"
        return 1
    fi

    if ! "${SCRIPTS_DIR}/deployment/setup-ansible.sh"; then
        print_error "Ansible setup failed"
        return 1
    fi

    if ! "${SCRIPTS_DIR}/deployment/deploy-rke2.sh"; then
        print_error "RKE2 deployment failed"
        return 1
    fi

    if ! "${SCRIPTS_DIR}/deployment/generate-kubeconfig.sh"; then
        print_error "Kubeconfig generation failed"
        return 1
    fi

    # Show cluster information
    "${SCRIPTS_DIR}/deployment/show-cluster-info.sh" info

    print_success "Complete RKE2 cluster deployment finished successfully!"
    return 0
}

# Function to deploy only infrastructure
deploy_infrastructure_only() {
    print_status "Deploying infrastructure only..."
    
    if ! "${SCRIPTS_DIR}/deployment/check-prerequisites.sh"; then
        print_error "Prerequisites check failed"
        return 1
    fi

    if ! "${SCRIPTS_DIR}/deployment/deploy-infrastructure.sh"; then
        print_error "Infrastructure deployment failed"
        return 1
    fi

    print_success "Infrastructure deployment completed successfully!"
    print_status "Next step: Run '$0 rke2' to deploy the RKE2 cluster"
    return 0
}

# Function to deploy only RKE2
deploy_rke2_only() {
    print_status "Deploying RKE2 cluster only..."
    
    if ! "${SCRIPTS_DIR}/deployment/setup-ansible.sh"; then
        print_error "Ansible setup failed"
        return 1
    fi

    if ! "${SCRIPTS_DIR}/deployment/deploy-rke2.sh"; then
        print_error "RKE2 deployment failed"
        return 1
    fi

    if ! "${SCRIPTS_DIR}/deployment/generate-kubeconfig.sh"; then
        print_error "Kubeconfig generation failed"
        return 1
    fi

    # Show cluster information
    "${SCRIPTS_DIR}/deployment/show-cluster-info.sh" info

    print_success "RKE2 cluster deployment completed successfully!"
    return 0
}

# Function to validate cluster
validate_cluster() {
    print_status "Validating cluster deployment..."
    "${SCRIPTS_DIR}/validation/validate-cluster.sh"
}

# Function to generate kubeconfig
generate_kubeconfig() {
    print_status "Generating kubeconfig..."
    "${SCRIPTS_DIR}/deployment/generate-kubeconfig.sh"
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying infrastructure..."
    "${SCRIPTS_DIR}/deployment/destroy-infrastructure.sh"
}

# Function to show cluster status
show_status() {
    "${SCRIPTS_DIR}/deployment/show-cluster-info.sh" status
}

# Parse command line arguments
AUTO_APPROVE=${AUTO_APPROVE:-false}
DRY_RUN=${DRY_RUN:-false}

# Process options
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            export AUTO_APPROVE=true
            shift
            ;;
        --dry-run)
            export DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Get the command
COMMAND="${1:-}"

# Execute the appropriate command
case "$COMMAND" in
    "deploy")
        deploy_complete
        exit $?
        ;;
    "infra")
        deploy_infrastructure_only
        exit $?
        ;;
    "rke2")
        deploy_rke2_only
        exit $?
        ;;
    "validate")
        validate_cluster
        exit $?
        ;;
    "kubeconfig")
        generate_kubeconfig
        exit $?
        ;;
    "destroy")
        destroy_infrastructure
        exit $?
        ;;
    "status")
        show_status
        exit $?
        ;;
    "help"|"--help"|"-h")
        show_help
        exit 0
        ;;
    "")
        print_error "No command specified"
        echo ""
        show_help
        exit 1
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac