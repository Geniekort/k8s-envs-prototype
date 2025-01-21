#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Print step description
step() {
    echo -e "${BLUE}→ $1${NC}"
}

# Print success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    step "Checking prerequisites..."
    
    if ! command -v minikube &> /dev/null; then
        echo "❌ minikube is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kustomize &> /dev/null; then
        echo "❌ kustomize is not installed. Please install it first."
        exit 1
    fi
    
    success "Prerequisites checked"
}

# Start Minikube with specific configuration for dev
start_minikube() {
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
}

# Bootstrap ArgoCD
bootstrap_argocd() {
    step "Bootstrapping ArgoCD..."
    
    # Apply CRDs first
    kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable
    
    # Wait for CRDs to be ready
    kubectl wait --for condition=established --timeout=60s crd/applications.argoproj.io
    kubectl wait --for condition=established --timeout=60s crd/applicationsets.argoproj.io
    kubectl wait --for condition=established --timeout=60s crd/appprojects.argoproj.io
    
    # Apply bootstrap manifests
    kubectl apply -f "${PROJECT_ROOT}/argocd/bootstrap/install.yaml"
    
    # Wait for ArgoCD server to be ready
    step "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
    
    success "ArgoCD bootstrapped"
}

# Main execution
main() {
    echo "Starting dev cluster setup..."
    
    check_prerequisites
    start_minikube
    bootstrap_argocd
    
    echo -e "\n${GREEN}✓ Dev cluster setup completed!${NC}"
    echo -e "\nUseful commands:"
    echo "- Switch to dev cluster:        minikube profile dev"
    echo "- Access ArgoCD UI:            kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "- Get ArgoCD admin password:    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    echo "- Access app1:                 kubectl port-forward svc/app1 -n dev 8081:80"
    echo "- Access app2:                 kubectl port-forward svc/app2 -n dev 8082:80"
}

main 