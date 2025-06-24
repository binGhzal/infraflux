#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created modular infrastructure destruction script
# - [ ] Add backup functionality before destruction
# - [ ] Add selective resource destruction
# - [ ] Add rollback protection mechanisms
# - [ ] Add cleanup verification

# Load common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Change to project root
cd "$(get_project_root)"

# Function to destroy infrastructure
destroy_infrastructure() {
    print_warning "This will destroy all infrastructure created by Terraform!"
    print_warning "This action cannot be undone!"
    
    # Show what will be destroyed
    show_destruction_plan
    
    # Ask for confirmation unless in auto-approve mode
    if [ "${AUTO_APPROVE:-}" != "true" ]; then
        echo ""
        read -p "Are you sure you want to continue? Type 'yes' to proceed: " confirm
        if [ "$confirm" != "yes" ]; then
            print_warning "Destruction cancelled"
            return 0
        fi
        
        # Second confirmation for safety
        read -p "This is your last chance. Type 'DESTROY' to confirm: " final_confirm
        if [ "$final_confirm" != "DESTROY" ]; then
            print_warning "Destruction cancelled"
            return 0
        fi
    fi

    # Backup important files before destruction
    backup_important_files

    print_status "Destroying infrastructure..."
    if terraform destroy -auto-approve; then
        print_success "Infrastructure destroyed successfully"
        cleanup_after_destruction
        return 0
    else
        print_error "Infrastructure destruction failed"
        return 1
    fi
}

# Function to show what will be destroyed
show_destruction_plan() {
    print_status "Resources that will be destroyed:"
    
    if terraform state list >/dev/null 2>&1; then
        echo ""
        print_status "Terraform resources:"
        terraform state list | sed 's/^/  - /'
        
        # Show IP addresses if available
        if terraform output rke2_server_ips >/dev/null 2>&1; then
            echo ""
            print_status "Server nodes:"
            terraform output -json rke2_server_ips 2>/dev/null | jq -r '.[]' | sed 's/^/  - /' 2>/dev/null
        fi
        
        if terraform output rke2_agent_ips >/dev/null 2>&1; then
            echo ""
            print_status "Agent nodes:"
            terraform output -json rke2_agent_ips 2>/dev/null | jq -r '.[]' | sed 's/^/  - /' 2>/dev/null
        fi
    else
        print_warning "No Terraform state found or cannot read state"
    fi
}

# Function to backup important files
backup_important_files() {
    print_status "Creating backup of important files..."
    
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup kubeconfig if it exists
    if [ -f "kubeconfig" ]; then
        cp "kubeconfig" "$backup_dir/kubeconfig"
        print_status "Backed up kubeconfig to $backup_dir/"
    fi
    
    # Backup terraform.tfvars if it exists
    if [ -f "terraform.tfvars" ]; then
        cp "terraform.tfvars" "$backup_dir/terraform.tfvars"
        print_status "Backed up terraform.tfvars to $backup_dir/"
    fi
    
    # Backup terraform state
    if [ -f "terraform.tfstate" ]; then
        cp "terraform.tfstate" "$backup_dir/terraform.tfstate"
        print_status "Backed up terraform state to $backup_dir/"
    fi
    
    print_success "Backup completed in $backup_dir/"
}

# Function to cleanup after destruction
cleanup_after_destruction() {
    print_status "Cleaning up after destruction..."
    
    # Remove generated files
    local files_to_remove=(
        "ansible.cfg"
        "ansible/RKE2/inventory/hosts.ini"
        "ansible/RKE2/inventory/group_vars/all.yaml"
        "terraform.tfplan"
        "tfplan"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            print_status "Removed $file"
        fi
    done
    
    # Clean up SSH known_hosts entries (optional)
    if [ "${CLEANUP_SSH_KNOWN_HOSTS:-}" = "true" ]; then
        cleanup_ssh_known_hosts
    fi
    
    print_success "Cleanup completed"
}

# Function to cleanup SSH known_hosts entries
cleanup_ssh_known_hosts() {
    print_status "Cleaning up SSH known_hosts entries..."
    
    if [ ! -f ~/.ssh/known_hosts ]; then
        return 0
    fi
    
    # This is a simple approach - in a production environment, you might want
    # to be more selective about which entries to remove
    print_warning "Manual cleanup of ~/.ssh/known_hosts may be required"
    print_status "You may want to review and clean up entries for destroyed VMs"
}

# Function to force destroy (skip confirmations)
force_destroy() {
    print_warning "Force destroying infrastructure without confirmations..."
    AUTO_APPROVE=true destroy_infrastructure
}

# Function to show destruction help
show_destroy_help() {
    echo "Infrastructure Destruction Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --force    Skip confirmation prompts"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Interactive destruction with confirmations"
    echo "  $0 --force        # Destroy without confirmations"
}

# Parse command line arguments
case "${1:-}" in
    "--force")
        force_destroy
        exit $?
        ;;
    "--help")
        show_destroy_help
        exit 0
        ;;
    "")
        # Run interactive destruction if script is executed directly
        if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
            destroy_infrastructure
            exit $?
        fi
        ;;
    *)
        print_error "Unknown option: $1"
        show_destroy_help
        exit 1
        ;;
esac