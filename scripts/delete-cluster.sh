#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print functions
step() { echo -e "${BLUE}→ $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

# Show usage
usage() {
    cat << EOF
Usage: $(basename $0) [OPTIONS]

Deletes a Kubernetes cluster and its resources.

Options:
    -e, --environment <env>   Environment to delete (dev or prod)
    -h, --help               Show this help message

Examples:
    $(basename $0) --environment dev    # Delete development cluster
    $(basename $0) --environment prod   # Delete production cluster
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENV="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate environment
if [[ ! "$ENV" =~ ^(dev|prod)$ ]]; then
    error "Environment must be either 'dev' or 'prod'"
fi

# Check prerequisites
check_prerequisites() {
    step "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is required but not installed"
    fi
    
    if [[ "$ENV" == "dev" ]] && ! command -v minikube &> /dev/null; then
        error "minikube is required for dev environment but not installed"
    fi
    
    success "Prerequisites checked"
}

# Delete cluster
delete_cluster() {
    if [[ "$ENV" == "dev" ]]; then
        step "Deleting Minikube dev cluster..."
        minikube delete --profile dev
        success "Minikube dev cluster deleted"
    else
        step "Cleaning up production cluster..."
        # Delete ArgoCD namespace and all its resources
        kubectl delete namespace argocd --ignore-not-found
        success "Production cluster cleaned"
    fi
}

# Main execution
main() {
    echo "Starting $ENV cluster deletion..."
    
    check_prerequisites
    
    # Confirm deletion
    read -p "Are you sure you want to delete the $ENV cluster? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Deletion cancelled"
    fi
    
    delete_cluster
    
    echo -e "\n${GREEN}✓ $ENV cluster deletion completed!${NC}"
}

main 