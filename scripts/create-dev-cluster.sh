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
    echo -e "${BLUE}➡️  $1${NC}"
}

# Print success message
success() {
    echo -e "${GREEN}✅ $1${NC}"
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
    
    if ! command -v argocd &> /dev/null; then
        echo "❌ argocd CLI is not installed. Please install it first."
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

# Install ArgoCD
install_argocd() {
    step "Installing ArgoCD..."
    
    # Create argocd namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD server to be ready
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
    
    success "ArgoCD installed"
}

# Create dev namespace and set up environment
setup_dev_environment() {
    step "Setting up dev environment..."
    
    # Create dev namespace
    kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
    
    success "Dev environment set up"
}

# Configure ArgoCD and deploy applications
deploy_applications() {
    step "Deploying applications via ArgoCD..."
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # Port forward ArgoCD server (in background)
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &
    PORT_FORWARD_PID=$!
    
    # Wait for port-forward to be ready
    sleep 5
    
    # Login to ArgoCD
    argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure
    
    # Create dev applications
    kubectl apply -f "${PROJECT_ROOT}/argocd/app-of-apps/dev.yaml"
    
    # Kill port-forward
    kill $PORT_FORWARD_PID
    
    success "Applications deployed"
}

# Main execution
main() {
    echo "🚀 Starting dev cluster setup..."
    
    check_prerequisites
    start_minikube
    install_argocd
    setup_dev_environment
    deploy_applications
    
    echo -e "\n${GREEN}🎉 Dev cluster setup completed!${NC}"
    echo -e "\nUseful commands:"
    echo "- Switch to dev cluster:        minikube profile dev"
    echo "- Access ArgoCD UI:            kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "- Get ArgoCD admin password:    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    echo "- Access app1:                 kubectl port-forward svc/app1 -n dev 8081:80"
    echo "- Access app2:                 kubectl port-forward svc/app2 -n dev 8082:80"
}

main 