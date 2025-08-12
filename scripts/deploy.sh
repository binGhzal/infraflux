#!/bin/bash
# InfraFlux - Infrastructure Platform Deployment Script
# This script provides a complete infrastructure deployment with configuration management

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
PLATFORM_DIR="${SCRIPT_DIR}/../platform"

# Default values
ENVIRONMENT="dev"
CONFIG_FILE=""
DRY_RUN="false"
VERBOSE="false"
SKIP_TERRAFORM="false"
SKIP_PLATFORM="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Usage function
usage() {
    cat << EOF
InfraFlux - Infrastructure Platform Deployment

Usage: $0 [OPTIONS]

OPTIONS:
    -e, --environment ENVIRONMENT    Target environment (dev|staging|prod) [default: dev]
    -c, --config FILE               Custom configuration file
    -d, --dry-run                   Show what would be deployed without making changes
    -v, --verbose                   Enable verbose output
    --skip-terraform               Skip Terraform deployment
    --skip-platform                Skip platform services deployment
    -h, --help                     Show this help message

EXAMPLES:
    # Deploy development environment
    $0 -e dev

    # Deploy production with custom config
    $0 -e prod -c /path/to/custom.yaml

    # Dry run for staging
    $0 -e staging --dry-run

    # Deploy only platform services (skip infrastructure provisioning)
    $0 -e prod --skip-terraform

CONFIGURATION:
    Configuration files are loaded in this order (later files override earlier ones):
    1. ${CONFIG_DIR}/defaults/infrastructure.yaml
    2. ${CONFIG_DIR}/environments/\${ENVIRONMENT}.yaml
    3. Custom config file (if specified with -c)

    Environment-specific configurations are located in:
    - ${CONFIG_DIR}/environments/dev.yaml
    - ${CONFIG_DIR}/environments/staging.yaml
    - ${CONFIG_DIR}/environments/prod.yaml

REQUIREMENTS:
    - terraform or tofu
    - kubectl
    - helm
    - yq (for YAML processing)
    - sops (for secrets management)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --skip-terraform)
                SKIP_TERRAFORM="true"
                shift
                ;;
            --skip-platform)
                SKIP_PLATFORM="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    log_info "Validating environment: ${ENVIRONMENT}"
    
    local env_config="${CONFIG_DIR}/environments/${ENVIRONMENT}.yaml"
    if [[ ! -f "${env_config}" ]]; then
        log_error "Environment configuration not found: ${env_config}"
        log_info "Available environments:"
        ls -1 "${CONFIG_DIR}/environments/" | sed 's/\.yaml$//' | sed 's/^/  - /'
        exit 1
    fi
    
    # Validate required tools
    local required_tools=("kubectl" "helm" "yq")
    if [[ "${SKIP_TERRAFORM}" != "true" ]]; then
        if command -v tofu >/dev/null 2>&1; then
            required_tools+=("tofu")
        elif command -v terraform >/dev/null 2>&1; then
            required_tools+=("terraform")
        else
            log_error "Neither 'tofu' nor 'terraform' found. Please install one of them."
            exit 1
        fi
    fi
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            log_error "Required tool not found: ${tool}"
            exit 1
        fi
    done
    
    log_success "Environment validation completed"
}

# Load and merge configurations
load_configuration() {
    log_info "Loading configuration for environment: ${ENVIRONMENT}"
    
    local default_config="${CONFIG_DIR}/defaults/infrastructure.yaml"
    local env_config="${CONFIG_DIR}/environments/${ENVIRONMENT}.yaml"
    local merged_config="/tmp/infraflux-config-${ENVIRONMENT}.yaml"
    
    # Start with defaults
    cp "${default_config}" "${merged_config}"
    
    # Merge environment-specific configuration
    if [[ -f "${env_config}" ]]; then
        log_verbose "Merging environment config: ${env_config}"
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "${merged_config}" "${env_config}" > "${merged_config}.tmp"
        mv "${merged_config}.tmp" "${merged_config}"
    fi
    
    # Merge custom configuration if provided
    if [[ -n "${CONFIG_FILE}" ]] && [[ -f "${CONFIG_FILE}" ]]; then
        log_verbose "Merging custom config: ${CONFIG_FILE}"
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "${merged_config}" "${CONFIG_FILE}" > "${merged_config}.tmp"
        mv "${merged_config}.tmp" "${merged_config}"
    fi
    
    # Export configuration path for other functions
    export INFRAFLUX_CONFIG="${merged_config}"
    
    log_success "Configuration loaded and merged"
    
    if [[ "${VERBOSE}" == "true" ]]; then
        log_verbose "Final configuration:"
        cat "${merged_config}" | head -50
        echo "..."
    fi
}

# Deploy infrastructure with Terraform
deploy_terraform() {
    if [[ "${SKIP_TERRAFORM}" == "true" ]]; then
        log_info "Skipping Terraform deployment"
        return 0
    fi
    
    log_info "Deploying infrastructure with Terraform for environment: ${ENVIRONMENT}"
    
    local terraform_env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    
    if [[ ! -d "${terraform_env_dir}" ]]; then
        log_error "Terraform environment directory not found: ${terraform_env_dir}"
        exit 1
    fi
    
    cd "${terraform_env_dir}"
    
    # Choose terraform or tofu
    local tf_cmd="terraform"
    if command -v tofu >/dev/null 2>&1; then
        tf_cmd="tofu"
    fi
    
    log_verbose "Using ${tf_cmd} for infrastructure deployment"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would run: ${tf_cmd} init"
    else
        ${tf_cmd} init
    fi
    
    # Plan
    log_info "Planning infrastructure changes..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would run: ${tf_cmd} plan"
    else
        ${tf_cmd} plan
    fi
    
    # Apply
    if [[ "${DRY_RUN}" != "true" ]]; then
        log_info "Applying infrastructure changes..."
        ${tf_cmd} apply -auto-approve
        
        # Extract kubeconfig
        if ${tf_cmd} output -raw kubeconfig >/dev/null 2>&1; then
            ${tf_cmd} output -raw kubeconfig > "${SCRIPT_DIR}/../kubeconfig"
            chmod 600 "${SCRIPT_DIR}/../kubeconfig"
            export KUBECONFIG="${SCRIPT_DIR}/../kubeconfig"
            log_success "Kubeconfig saved to ${SCRIPT_DIR}/../kubeconfig"
        fi
    fi
    
    cd - >/dev/null
    log_success "Terraform deployment completed"
}

# Bootstrap ArgoCD
bootstrap_argocd() {
    log_info "Bootstrapping ArgoCD..."
    
    # Install ArgoCD
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would install ArgoCD"
        return 0
    fi
    
    # Create argocd namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD using Helm
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Create ArgoCD values from configuration
    local argocd_values="/tmp/argocd-values-${ENVIRONMENT}.yaml"
    yq eval '.infrastructure.argocd.config' "${INFRAFLUX_CONFIG}" > "${argocd_values}"
    
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --values "${argocd_values}" \
        --wait
    
    # Apply GitOps configuration
    kubectl apply -f "${PLATFORM_DIR}/gitops/"
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
    
    log_success "ArgoCD bootstrap completed"
}

# Deploy platform services
deploy_platform() {
    if [[ "${SKIP_PLATFORM}" == "true" ]]; then
        log_info "Skipping platform services deployment"
        return 0
    fi
    
    log_info "Deploying platform services for environment: ${ENVIRONMENT}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would deploy platform services"
        return 0
    fi
    
    # Bootstrap ArgoCD first
    bootstrap_argocd
    
    # Apply the app-of-apps pattern
    log_info "Applying app-of-apps pattern..."
    
    # Process the app-of-apps template with environment values
    local app_of_apps="/tmp/app-of-apps-${ENVIRONMENT}.yaml"
    yq eval '.environment.name as $env | (.. | select(. == "{{ .Values.environment }}")) = $env' \
        "${PLATFORM_DIR}/gitops/app-of-apps.yaml" > "${app_of_apps}"
    
    kubectl apply -f "${app_of_apps}"
    
    # Wait for applications to sync
    log_info "Waiting for applications to sync..."
    sleep 30
    
    # Check ArgoCD application status
    local max_attempts=60
    local attempt=0
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        local healthy_apps=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.health.status=="Healthy")].metadata.name}' | wc -w)
        local total_apps=$(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' | wc -w)
        
        log_info "Applications healthy: ${healthy_apps}/${total_apps}"
        
        if [[ ${healthy_apps} -eq ${total_apps} ]] && [[ ${total_apps} -gt 0 ]]; then
            break
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_success "Platform services deployment completed"
}

# Generate access information
generate_access_info() {
    log_info "Generating access information..."
    
    local domain
    domain=$(yq eval '.environment.domain' "${INFRAFLUX_CONFIG}")
    
    cat << EOF

${GREEN}=== InfraFlux Platform Access Information ===${NC}

Environment: ${ENVIRONMENT}
Domain: ${domain}

${BLUE}Kubernetes Access:${NC}
  export KUBECONFIG=${SCRIPT_DIR}/../kubeconfig
  kubectl get nodes

${BLUE}ArgoCD Access:${NC}
  URL: https://argocd.${domain}
  Username: admin
  Password: \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

${BLUE}Platform Services:${NC}
  Cilium Hubble UI: https://hubble.${domain}
  Grafana: https://grafana.${domain}
  Prometheus: https://prometheus.${domain}

${BLUE}Useful Commands:${NC}
  # Check ArgoCD applications
  kubectl get applications -n argocd

  # Check platform pods
  kubectl get pods -A

  # Access ArgoCD CLI
  argocd login argocd.${domain}

${BLUE}Configuration:${NC}
  Merged config: ${INFRAFLUX_CONFIG}

EOF
}

# Cleanup function
cleanup() {
    log_verbose "Cleaning up temporary files..."
    rm -f "/tmp/infraflux-config-${ENVIRONMENT}.yaml"
    rm -f "/tmp/argocd-values-${ENVIRONMENT}.yaml"
    rm -f "/tmp/app-of-apps-${ENVIRONMENT}.yaml"
}

# Main execution
main() {
    log_info "Starting InfraFlux deployment..."
    
    parse_args "$@"
    validate_environment
    load_configuration
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
    fi
    
    deploy_terraform
    deploy_platform
    
    if [[ "${DRY_RUN}" != "true" ]]; then
        generate_access_info
    fi
    
    cleanup
    
    log_success "InfraFlux deployment completed successfully!"
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
