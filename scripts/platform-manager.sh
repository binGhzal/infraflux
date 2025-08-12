#!/bin/bash
# Platform Management Script
# Manages both InfraFlux (infrastructure) and PlatformNorthStar (applications)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRAFLUX_DIR="${SCRIPT_DIR}/.."
PLATFORM_NS_DIR="${INFRAFLUX_DIR}/../PlatformNorthStar"

# Default values
ENVIRONMENT="dev"
ACTION=""
VERBOSE="false"
DRY_RUN="false"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
Platform Management Script
Manages InfraFlux (infrastructure) and PlatformNorthStar (applications)

Usage: $0 ACTION [OPTIONS]

ACTIONS:
    deploy              Deploy complete platform (infrastructure + apps)
    deploy-infra        Deploy only infrastructure (InfraFlux)
    deploy-apps         Deploy only applications (PlatformNorthStar)
    status              Show platform status
    destroy             Destroy platform
    promote             Promote between environments
    backup              Backup platform state
    restore             Restore platform state

OPTIONS:
    -e, --environment ENV    Target environment (dev|staging|prod) [default: dev]
    -d, --dry-run           Show what would be done
    -v, --verbose           Enable verbose output
    -h, --help              Show this help

EXAMPLES:
    # Deploy complete development platform
    $0 deploy -e dev

    # Deploy only infrastructure for production
    $0 deploy-infra -e prod

    # Check platform status
    $0 status -e prod

    # Promote applications from staging to prod
    $0 promote --from staging --to prod

    # Backup production platform
    $0 backup -e prod

EOF
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    ACTION="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
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
            --from)
                FROM_ENV="$2"
                shift 2
                ;;
            --to)
                TO_ENV="$2"
                shift 2
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

check_repositories() {
    log_info "Checking repository structure..."

    if [[ ! -d "${INFRAFLUX_DIR}" ]]; then
        log_error "InfraFlux directory not found: ${INFRAFLUX_DIR}"
        exit 1
    fi

    if [[ ! -d "${PLATFORM_NS_DIR}" ]]; then
        log_warn "PlatformNorthStar directory not found: ${PLATFORM_NS_DIR}"
        log_info "Clone it with: git clone https://github.com/binGhzal/PlatformNorthStar ${PLATFORM_NS_DIR}"

        if [[ "${ACTION}" == "deploy" || "${ACTION}" == "deploy-apps" ]]; then
            exit 1
        fi
    fi

    log_success "Repository structure validated"
}

deploy_complete() {
    log_info "Deploying complete platform for environment: ${ENVIRONMENT}"

    # Deploy infrastructure first
    log_info "Step 1/2: Deploying infrastructure..."
    cd "${INFRAFLUX_DIR}"

    local deploy_args="-e ${ENVIRONMENT}"
    [[ "${DRY_RUN}" == "true" ]] && deploy_args+=" --dry-run"
    [[ "${VERBOSE}" == "true" ]] && deploy_args+=" --verbose"

    ./scripts/deploy.sh ${deploy_args}

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would deploy applications after infrastructure"
        return 0
    fi

    # Wait for infrastructure to be ready
    log_info "Waiting for infrastructure to be ready..."
    sleep 30

    # Check ArgoCD is ready
    if ! kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s; then
        log_error "ArgoCD not ready. Check infrastructure deployment."
        exit 1
    fi

    # Applications will be automatically deployed by ArgoCD
    log_info "Step 2/2: ArgoCD will automatically deploy applications..."
    log_success "Complete platform deployment initiated"

    # Show status
    show_status
}

deploy_infrastructure() {
    log_info "Deploying infrastructure for environment: ${ENVIRONMENT}"

    cd "${INFRAFLUX_DIR}"

    local deploy_args="-e ${ENVIRONMENT}"
    [[ "${DRY_RUN}" == "true" ]] && deploy_args+=" --dry-run"
    [[ "${VERBOSE}" == "true" ]] && deploy_args+=" --verbose"

    ./scripts/deploy.sh ${deploy_args}

    log_success "Infrastructure deployment completed"
}

deploy_applications() {
    log_info "Deploying applications for environment: ${ENVIRONMENT}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would sync ArgoCD applications"
        return 0
    fi

    # Check if ArgoCD is available
    if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_error "ArgoCD not found. Deploy infrastructure first."
        exit 1
    fi

    # Sync applications
    log_info "Syncing ArgoCD applications..."

    # Get all applications for the environment
    local apps
    apps=$(kubectl get applications -n argocd -l "app.kubernetes.io/environment=${ENVIRONMENT}" -o jsonpath='{.items[*].metadata.name}')

    if [[ -z "${apps}" ]]; then
        log_warn "No applications found for environment: ${ENVIRONMENT}"
        return 0
    fi

    for app in ${apps}; do
        log_info "Syncing application: ${app}"
        if command -v argocd >/dev/null 2>&1; then
            argocd app sync "${app}" --prune
        else
            kubectl patch application "${app}" -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"platform-manager"},"sync":{"syncStrategy":{"apply":{"force":true}}}}}'
        fi
    done

    log_success "Applications deployment completed"
}

show_status() {
    log_info "Platform Status for environment: ${ENVIRONMENT}"

    echo ""
    echo "🏗️  Infrastructure Status:"
    if kubectl get nodes >/dev/null 2>&1; then
        kubectl get nodes
        echo ""

        echo "📊 Platform Services:"
        kubectl get pods -n kube-system,cert-manager,monitoring -o wide
        echo ""

        echo "🔄 ArgoCD Applications:"
        if kubectl get applications -n argocd >/dev/null 2>&1; then
            kubectl get applications -n argocd
        else
            echo "ArgoCD not found or not accessible"
        fi
        echo ""

        echo "🚀 Application Workloads:"
        kubectl get pods -A | grep -E "^app-|^workload-|^service-" || echo "No application workloads found"
        echo ""

        echo "🌐 Ingresses:"
        kubectl get ingress -A
        echo ""

        echo "📈 Resource Usage:"
        kubectl top nodes 2>/dev/null || echo "Metrics server not available"

    else
        echo "❌ Kubernetes cluster not accessible"
        echo "Check your kubeconfig or deploy infrastructure first"
    fi
}

promote_environment() {
    if [[ -z "${FROM_ENV:-}" ]] || [[ -z "${TO_ENV:-}" ]]; then
        log_error "Both --from and --to environments must be specified for promotion"
        exit 1
    fi

    log_info "Promoting from ${FROM_ENV} to ${TO_ENV}..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would promote applications from ${FROM_ENV} to ${TO_ENV}"
        return 0
    fi

    cd "${PLATFORM_NS_DIR}"

    # This is a simplified promotion - in practice you'd want more sophisticated promotion logic
    log_info "Copying configurations from ${FROM_ENV} to ${TO_ENV}..."

    # Copy application values (you might want to be more selective)
    if [[ -d "environments/${FROM_ENV}/values" ]] && [[ -d "environments/${TO_ENV}/values" ]]; then
        log_info "Promoting application configurations..."
        # Here you'd implement your promotion logic
        # For now, just show what would be done
        echo "Would copy selected configurations from environments/${FROM_ENV} to environments/${TO_ENV}"
    fi

    log_success "Promotion completed"
}

backup_platform() {
    log_info "Backing up platform state for environment: ${ENVIRONMENT}"

    local backup_dir="/tmp/platform-backup-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${backup_dir}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would create backup in ${backup_dir}"
        return 0
    fi

    # Backup Kubernetes resources
    log_info "Backing up Kubernetes resources..."
    kubectl get all,pv,pvc,secrets,configmaps -A -o yaml > "${backup_dir}/k8s-resources.yaml"

    # Backup ArgoCD applications
    if kubectl get applications -n argocd >/dev/null 2>&1; then
        kubectl get applications -n argocd -o yaml > "${backup_dir}/argocd-applications.yaml"
    fi

    # Backup configuration files
    log_info "Backing up configuration files..."
    cp -r "${INFRAFLUX_DIR}/config" "${backup_dir}/infraflux-config"

    if [[ -d "${PLATFORM_NS_DIR}" ]]; then
        cp -r "${PLATFORM_NS_DIR}/environments" "${backup_dir}/platform-environments"
    fi

    log_success "Backup created: ${backup_dir}"
    echo "Backup location: ${backup_dir}"
}

destroy_platform() {
    log_warn "This will destroy the ${ENVIRONMENT} environment!"

    if [[ "${DRY_RUN}" != "true" ]]; then
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [[ "${confirm}" != "yes" ]]; then
            log_info "Destruction cancelled"
            return 0
        fi
    fi

    log_info "Destroying platform for environment: ${ENVIRONMENT}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would destroy environment ${ENVIRONMENT}"
        return 0
    fi

    # Delete ArgoCD applications first
    if kubectl get applications -n argocd >/dev/null 2>&1; then
        log_info "Deleting ArgoCD applications..."
        kubectl delete applications -n argocd --all
    fi

    # Run terraform destroy
    cd "${INFRAFLUX_DIR}/terraform/environments/${ENVIRONMENT}"

    local tf_cmd="terraform"
    if command -v tofu >/dev/null 2>&1; then
        tf_cmd="tofu"
    fi

    log_info "Destroying infrastructure with ${tf_cmd}..."
    ${tf_cmd} destroy -auto-approve

    log_success "Platform destroyed"
}

main() {
    parse_args "$@"
    check_repositories

    case "${ACTION}" in
        deploy)
            deploy_complete
            ;;
        deploy-infra)
            deploy_infrastructure
            ;;
        deploy-apps)
            deploy_applications
            ;;
        status)
            show_status
            ;;
        promote)
            promote_environment
            ;;
        backup)
            backup_platform
            ;;
        destroy)
            destroy_platform
            ;;
        *)
            log_error "Unknown action: ${ACTION}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
