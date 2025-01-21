#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Print step description
step() { echo -e "${BLUE}→ $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

# Show usage
usage() {
    cat << EOF
Usage: $(basename $0) [OPTIONS]

Creates a Kubernetes cluster with ArgoCD and GitOps setup.

Options:
    -e, --environment <env>   Environment to create (dev or prod)
    -h, --help               Show this help message

Examples:
    $(basename $0) --environment dev    # Create development cluster
    $(basename $0) --environment prod   # Create production cluster
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

# Start cluster
start_cluster() {
    if [[ "$ENV" == "dev" ]]; then
        step "Starting Minikube dev cluster..."
        minikube start \
            --profile dev \
            --cpus 2 \
            --memory 4096 \
            --disk-size 20g \
            --driver docker \
            --addons ingress \
            --addons metrics-server
        success "Minikube dev cluster started"
    else
        step "Using existing production cluster..."
        # Add any production cluster-specific setup here
        success "Production cluster ready"
    fi
}

# Install ArgoCD
install_argocd() {
    step "Installing ArgoCD for $ENV environment..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f "${PROJECT_ROOT}/argocd/bootstrap/${ENV}/install.yaml"
    
    # Wait for ArgoCD server to be ready
    step "Waiting for ArgoCD server to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
    
    # Wait for initial admin secret to be created
    step "Waiting for admin credentials to be created..."
    while ! kubectl -n argocd get secret argocd-initial-admin-secret &> /dev/null; do
        echo "Waiting for admin secret..."
        sleep 5
    done
    
    # Display login credentials
    echo -e "\n${GREEN}ArgoCD Login Credentials:${NC}"
    echo "Username: admin"
    echo -n "Password: "
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    echo -e "\n"
    
    success "ArgoCD installed"
}

# Setup GitOps
setup_gitops() {
    step "Setting up GitOps for $ENV environment..."
    
    # Apply the bootstrap app
    kubectl apply -f "${PROJECT_ROOT}/argocd/bootstrap/${ENV}/bootstrap.yaml"
    
    success "GitOps setup completed"
}

# Main execution
main() {
    echo "Starting $ENV cluster setup..."
    
    check_prerequisites
    start_cluster
    install_argocd
    setup_gitops
    
    echo -e "\n${GREEN}✓ $ENV cluster setup completed!${NC}"
    echo -e "\nUseful commands:"
    echo "- Access ArgoCD UI:            kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "- Get ArgoCD admin password:    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    
    if [[ "$ENV" == "dev" ]]; then
        echo "- Switch to dev cluster:        minikube profile dev"
    fi
}

main 