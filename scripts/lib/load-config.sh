#!/bin/bash

# TODO: InfraFlux Refactoring Tasks
# - [x] Created configuration loader script
# - [ ] Add configuration validation
# - [ ] Add support for environment-specific configs
# - [ ] Add encrypted configuration support
# - [ ] Add configuration schema validation

# Configuration Loader for InfraFlux
# This script loads configuration from deploy.conf or uses defaults

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# Default configuration values
DEFAULT_AUTO_APPROVE=false
DEFAULT_DRY_RUN=false
DEFAULT_VERBOSE=false
DEFAULT_BACKUP_ENABLED=true
DEFAULT_CLEANUP_SSH_KNOWN_HOSTS=false
DEFAULT_SSH_TIMEOUT=30
DEFAULT_TF_PLAN_FILE="tfplan"
DEFAULT_TF_PARALLELISM=10
DEFAULT_TF_REFRESH=true
DEFAULT_ANSIBLE_TIMEOUT=300
DEFAULT_ANSIBLE_RETRIES=3
DEFAULT_ANSIBLE_VERBOSITY=0
DEFAULT_ANSIBLE_STRATEGY="linear"
DEFAULT_VALIDATION_TIMEOUT=120
DEFAULT_SKIP_VALIDATION=false
DEFAULT_KUBECONFIG_BACKUP=true
DEFAULT_KUBECONFIG_MERGE=false
DEFAULT_KUBECONFIG_CONTEXT="infraflux-rke2"
DEFAULT_EXTERNAL_ENDPOINT=""
DEFAULT_EXTERNAL_PORT="6443"
DEFAULT_SKIP_PREREQUISITES=false
DEFAULT_SKIP_INFRASTRUCTURE=false
DEFAULT_SKIP_ANSIBLE_SETUP=false
DEFAULT_SKIP_RKE2_DEPLOYMENT=false
DEFAULT_SKIP_KUBECONFIG=false
DEFAULT_LOG_FILE=""
DEFAULT_LOG_LEVEL="INFO"
DEFAULT_METRICS_ENABLED=false
DEFAULT_CUSTOM_TERRAFORM_DIR=""
DEFAULT_CUSTOM_ANSIBLE_DIR=""
DEFAULT_CUSTOM_SCRIPTS_DIR=""
DEFAULT_DEV_MODE=false
DEFAULT_TEST_MODE=false
DEFAULT_FORCE_REBUILD=false

# Function to load configuration
load_config() {
    local config_file="${PROJECT_ROOT}/config/deploy.conf"
    
    # Load from config file if it exists
    if [ -f "$config_file" ]; then
        echo "Loading configuration from $config_file" >&2
        source "$config_file"
    else
        echo "Configuration file not found: $config_file" >&2
        echo "Using default values. Copy config/deploy.conf.example to config/deploy.conf to customize." >&2
    fi
    
    # Set defaults for any unset variables
    export AUTO_APPROVE=${AUTO_APPROVE:-$DEFAULT_AUTO_APPROVE}
    export DRY_RUN=${DRY_RUN:-$DEFAULT_DRY_RUN}
    export VERBOSE=${VERBOSE:-$DEFAULT_VERBOSE}
    export BACKUP_ENABLED=${BACKUP_ENABLED:-$DEFAULT_BACKUP_ENABLED}
    export CLEANUP_SSH_KNOWN_HOSTS=${CLEANUP_SSH_KNOWN_HOSTS:-$DEFAULT_CLEANUP_SSH_KNOWN_HOSTS}
    export SSH_TIMEOUT=${SSH_TIMEOUT:-$DEFAULT_SSH_TIMEOUT}
    export TF_PLAN_FILE=${TF_PLAN_FILE:-$DEFAULT_TF_PLAN_FILE}
    export TF_PARALLELISM=${TF_PARALLELISM:-$DEFAULT_TF_PARALLELISM}
    export TF_REFRESH=${TF_REFRESH:-$DEFAULT_TF_REFRESH}
    export ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-$DEFAULT_ANSIBLE_TIMEOUT}
    export ANSIBLE_RETRIES=${ANSIBLE_RETRIES:-$DEFAULT_ANSIBLE_RETRIES}
    export ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY:-$DEFAULT_ANSIBLE_VERBOSITY}
    export ANSIBLE_STRATEGY=${ANSIBLE_STRATEGY:-$DEFAULT_ANSIBLE_STRATEGY}
    export VALIDATION_TIMEOUT=${VALIDATION_TIMEOUT:-$DEFAULT_VALIDATION_TIMEOUT}
    export SKIP_VALIDATION=${SKIP_VALIDATION:-$DEFAULT_SKIP_VALIDATION}
    export KUBECONFIG_BACKUP=${KUBECONFIG_BACKUP:-$DEFAULT_KUBECONFIG_BACKUP}
    export KUBECONFIG_MERGE=${KUBECONFIG_MERGE:-$DEFAULT_KUBECONFIG_MERGE}
    export KUBECONFIG_CONTEXT=${KUBECONFIG_CONTEXT:-$DEFAULT_KUBECONFIG_CONTEXT}
    export EXTERNAL_ENDPOINT=${EXTERNAL_ENDPOINT:-$DEFAULT_EXTERNAL_ENDPOINT}
    export EXTERNAL_PORT=${EXTERNAL_PORT:-$DEFAULT_EXTERNAL_PORT}
    export SKIP_PREREQUISITES=${SKIP_PREREQUISITES:-$DEFAULT_SKIP_PREREQUISITES}
    export SKIP_INFRASTRUCTURE=${SKIP_INFRASTRUCTURE:-$DEFAULT_SKIP_INFRASTRUCTURE}
    export SKIP_ANSIBLE_SETUP=${SKIP_ANSIBLE_SETUP:-$DEFAULT_SKIP_ANSIBLE_SETUP}
    export SKIP_RKE2_DEPLOYMENT=${SKIP_RKE2_DEPLOYMENT:-$DEFAULT_SKIP_RKE2_DEPLOYMENT}
    export SKIP_KUBECONFIG=${SKIP_KUBECONFIG:-$DEFAULT_SKIP_KUBECONFIG}
    export LOG_FILE=${LOG_FILE:-$DEFAULT_LOG_FILE}
    export LOG_LEVEL=${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}
    export METRICS_ENABLED=${METRICS_ENABLED:-$DEFAULT_METRICS_ENABLED}
    export CUSTOM_TERRAFORM_DIR=${CUSTOM_TERRAFORM_DIR:-$DEFAULT_CUSTOM_TERRAFORM_DIR}
    export CUSTOM_ANSIBLE_DIR=${CUSTOM_ANSIBLE_DIR:-$DEFAULT_CUSTOM_ANSIBLE_DIR}
    export CUSTOM_SCRIPTS_DIR=${CUSTOM_SCRIPTS_DIR:-$DEFAULT_CUSTOM_SCRIPTS_DIR}
    export DEV_MODE=${DEV_MODE:-$DEFAULT_DEV_MODE}
    export TEST_MODE=${TEST_MODE:-$DEFAULT_TEST_MODE}
    export FORCE_REBUILD=${FORCE_REBUILD:-$DEFAULT_FORCE_REBUILD}
}

# Function to validate configuration
validate_config() {
    local errors=0
    
    # Validate boolean values
    for var in AUTO_APPROVE DRY_RUN VERBOSE BACKUP_ENABLED CLEANUP_SSH_KNOWN_HOSTS TF_REFRESH SKIP_VALIDATION KUBECONFIG_BACKUP KUBECONFIG_MERGE SKIP_PREREQUISITES SKIP_INFRASTRUCTURE SKIP_ANSIBLE_SETUP SKIP_RKE2_DEPLOYMENT SKIP_KUBECONFIG METRICS_ENABLED DEV_MODE TEST_MODE FORCE_REBUILD; do
        local value=$(eval echo \$$var)
        if [[ "$value" != "true" && "$value" != "false" ]]; then
            echo "ERROR: $var must be 'true' or 'false', got: $value" >&2
            ((errors++))
        fi
    done
    
    # Validate numeric values
    for var in SSH_TIMEOUT TF_PARALLELISM ANSIBLE_TIMEOUT ANSIBLE_RETRIES ANSIBLE_VERBOSITY VALIDATION_TIMEOUT EXTERNAL_PORT; do
        local value=$(eval echo \$$var)
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            echo "ERROR: $var must be a positive integer, got: $value" >&2
            ((errors++))
        fi
    done
    
    # Validate log level
    if [[ "$LOG_LEVEL" != "DEBUG" && "$LOG_LEVEL" != "INFO" && "$LOG_LEVEL" != "WARN" && "$LOG_LEVEL" != "ERROR" ]]; then
        echo "ERROR: LOG_LEVEL must be one of: DEBUG, INFO, WARN, ERROR, got: $LOG_LEVEL" >&2
        ((errors++))
    fi
    
    # Validate Ansible verbosity
    if [[ "$ANSIBLE_VERBOSITY" -lt 0 || "$ANSIBLE_VERBOSITY" -gt 4 ]]; then
        echo "ERROR: ANSIBLE_VERBOSITY must be between 0 and 4, got: $ANSIBLE_VERBOSITY" >&2
        ((errors++))
    fi
    
    return $errors
}

# Function to show current configuration
show_config() {
    echo "=== Current Configuration ==="
    echo "Deployment Options:"
    echo "  AUTO_APPROVE=$AUTO_APPROVE"
    echo "  DRY_RUN=$DRY_RUN"
    echo "  VERBOSE=$VERBOSE"
    echo "  BACKUP_ENABLED=$BACKUP_ENABLED"
    echo ""
    echo "SSH Configuration:"
    echo "  CLEANUP_SSH_KNOWN_HOSTS=$CLEANUP_SSH_KNOWN_HOSTS"
    echo "  SSH_TIMEOUT=$SSH_TIMEOUT"
    echo ""
    echo "Terraform Options:"
    echo "  TF_PLAN_FILE=$TF_PLAN_FILE"
    echo "  TF_PARALLELISM=$TF_PARALLELISM"
    echo "  TF_REFRESH=$TF_REFRESH"
    echo ""
    echo "Ansible Options:"
    echo "  ANSIBLE_TIMEOUT=$ANSIBLE_TIMEOUT"
    echo "  ANSIBLE_RETRIES=$ANSIBLE_RETRIES"
    echo "  ANSIBLE_VERBOSITY=$ANSIBLE_VERBOSITY"
    echo "  ANSIBLE_STRATEGY=$ANSIBLE_STRATEGY"
    echo ""
    echo "External Access:"
    echo "  EXTERNAL_ENDPOINT=$EXTERNAL_ENDPOINT"
    echo "  EXTERNAL_PORT=$EXTERNAL_PORT"
    echo ""
    echo "Deployment Phases:"
    echo "  SKIP_PREREQUISITES=$SKIP_PREREQUISITES"
    echo "  SKIP_INFRASTRUCTURE=$SKIP_INFRASTRUCTURE"
    echo "  SKIP_ANSIBLE_SETUP=$SKIP_ANSIBLE_SETUP"
    echo "  SKIP_RKE2_DEPLOYMENT=$SKIP_RKE2_DEPLOYMENT"
    echo "  SKIP_KUBECONFIG=$SKIP_KUBECONFIG"
    echo ""
}

# Run configuration loading if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    case "${1:-load}" in
        "load")
            load_config
            ;;
        "validate")
            load_config
            validate_config
            ;;
        "show")
            load_config
            show_config
            ;;
        *)
            echo "Usage: $0 [load|validate|show]"
            exit 1
            ;;
    esac
fi