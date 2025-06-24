#!/bin/bash

# SSH Host Key Management Script
# Automatically adds all cluster node SSH keys to known_hosts

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to add SSH host keys
add_ssh_host_keys() {
    print_status "Adding SSH host keys to known_hosts..."

    # Check if inventory file exists
    if [ ! -f "ansible/RKE2/inventory/hosts.ini" ]; then
        print_error "Ansible inventory file not found. Please run terraform apply first."
        exit 1
    fi

    # Create .ssh directory if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # Extract IPs from inventory file and add to known_hosts
    grep "ansible_host=" ansible/RKE2/inventory/hosts.ini | awk -F'ansible_host=' '{print $2}' | while read ip; do
        if [ ! -z "$ip" ]; then
            print_status "Adding SSH host key for $ip"
            ssh-keyscan -H "$ip" >>~/.ssh/known_hosts 2>/dev/null || true
        fi
    done

    # Remove duplicate entries
    if [ -f ~/.ssh/known_hosts ]; then
        sort -u ~/.ssh/known_hosts >~/.ssh/known_hosts.tmp
        mv ~/.ssh/known_hosts.tmp ~/.ssh/known_hosts
        chmod 600 ~/.ssh/known_hosts
    fi

    print_success "SSH host keys added successfully"
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    print_status "Testing SSH connectivity to all nodes..."

    grep "ansible_host=" ansible/RKE2/inventory/hosts.ini | while read line; do
        hostname=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk -F'ansible_host=' '{print $2}')

        if [ ! -z "$ip" ]; then
            print_status "Testing connection to $hostname ($ip)..."
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "binghzal@$ip" 'echo "SSH connection successful"' 2>/dev/null; then
                print_success "✓ $hostname ($ip) - Connection successful"
            else
                print_error "✗ $hostname ($ip) - Connection failed"
            fi
        fi
    done
}

# Main execution
case "${1:-}" in
"add-keys")
    add_ssh_host_keys
    ;;
"test")
    test_ssh_connectivity
    ;;
*)
    print_status "SSH Host Key Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  add-keys   - Add all cluster node SSH keys to known_hosts"
    echo "  test       - Test SSH connectivity to all nodes"
    echo ""
    echo "Examples:"
    echo "  $0 add-keys   # Add SSH host keys"
    echo "  $0 test       # Test connectivity"
    ;;
esac
