#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print step description
step() {
    echo -e "${BLUE}➡️  $1${NC}"
}

# Print success message
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Print warning message
warning() {
    echo -e "${RED}⚠️  $1${NC}"
}

# Check if cluster exists
check_cluster() {
    step "Checking if dev cluster exists..."
    
    if ! minikube profile list | grep -q "dev"; then
        warning "Dev cluster not found. Nothing to delete."
        exit 0
    fi
    
    success "Dev cluster found"
}

# Delete the cluster
delete_cluster() {
    step "Deleting dev cluster..."
    
    # Switch to dev profile first
    minikube profile dev
    
    # Stop the cluster
    minikube stop
    
    # Delete the cluster
    minikube delete --profile dev
    
    success "Dev cluster deleted"
}

# Main execution
main() {
    echo "🗑️  Deleting dev cluster..."
    
    check_cluster
    delete_cluster
    
    echo -e "\n${GREEN}🎉 Dev cluster cleanup completed!${NC}"
}

main 