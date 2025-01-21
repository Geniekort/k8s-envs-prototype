# Infrastructure Prototype: Multi-Environment Kubernetes Deployment

This prototype demonstrates a GitOps-based multi-environment deployment setup using ArgoCD, Kustomize, and Kubernetes. It showcases a scalable approach for managing multiple applications across different environments with automated deployments.

## Features

- **Multi-Environment Support**
  - Development environment for continuous integration
  - Production environment for live deployments
  - Dynamic Preview environments for feature branches/PRs
- **GitOps-based Workflow**
  - ArgoCD for automated deployments
  - App of Apps pattern for managing multiple services
  - Kustomize for environment-specific configurations
- **Application Components**
  - Two sample applications (app1, app2)
  - Shared database service
  - Environment-specific configurations
- **Preview Environment Automation**
  - Dynamic namespace creation
  - Unique URLs per environment
  - Automatic cleanup

## Prerequisites

- Minikube v1.32.0 or higher
- kubectl v1.28.0 or higher
- ArgoCD CLI v2.9.0 or higher
- Kustomize v5.3.0 or higher
- Docker (for running Minikube)

## Cluster Setup

### Development Cluster

1. Make the setup script executable:
   ```bash
   chmod +x scripts/create-dev-cluster.sh
   ```

2. Run the setup script:
   ```bash
   ./scripts/create-dev-cluster.sh
   ```

The script will:
- Start a Minikube cluster with the 'dev' profile
- Install and configure ArgoCD
- Create necessary namespaces
- Deploy all applications via ArgoCD

### Accessing the Development Environment

1. **ArgoCD Dashboard**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Access at: https://localhost:8080
   
   Get the admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. **Applications**:
   ```bash
   # Access app1
   kubectl port-forward svc/app1 -n dev 8081:80
   # Visit: http://localhost:8081

   # Access app2
   kubectl port-forward svc/app2 -n dev 8082:80
   # Visit: http://localhost:8082
   ```

3. **Database**:
   ```bash
   # Port-forward PostgreSQL
   kubectl port-forward svc/db -n dev 5432:5432
   ```
   Connection details:
   - Host: localhost
   - Port: 5432
   - Database: app_dev
   - User: app_dev
   - Password: devpassword

### Cluster Management

```bash
# Switch between clusters
minikube profile dev

# Stop the cluster
minikube stop -p dev

# Delete the cluster
minikube delete -p dev
```

## Project Structure

```
.
├── apps/                      # Application manifests
│   ├── app1/
│   │   ├── base/             # Base Kubernetes manifests
│   │   └── overlays/         # Environment-specific patches
│   │       ├── dev/
│   │       ├── prod/
│   │       └── preview/
│   ├── app2/
│   │   ├── base/
│   │   └── overlays/
│   └── db/
│       ├── base/
│       └── overlays/
├── argocd/                    # ArgoCD configurations
│   ├── apps/                 # Individual app definitions
│   │   ├── dev/
│   │   ├── prod/
│   │   └── preview/
│   └── app-of-apps/          # Root application definitions
└── scripts/                   # Utility scripts
```

## Environment Details

### Development (dev)
- **Purpose**: Continuous integration and testing
- **Namespace**: `dev`
- **URL Pattern**: `*.dev.local`
- **Resource Limits**: Minimal for cost efficiency
- **Cluster**: Minikube with 2 CPUs, 4GB RAM

### Production (prod)
- **Purpose**: Live production workloads
- **Namespace**: `prod`
- **URL Pattern**: `*.prod.local`
- **Resource Limits**: Production-grade resources
- **Cluster**: Separate Minikube instance (TODO)

### Preview
- **Purpose**: Feature branch testing
- **Namespace**: `preview-{branch-name}`
- **URL Pattern**: `*.{branch-name}.preview.local`
- **Resource Limits**: Similar to dev environment
- **Lifecycle**: Automatically created/destroyed with PR lifecycle

## Working with Preview Environments

1. **Create Preview Environment**
   ```bash
   ./scripts/create-preview-env.sh feature-branch-name
   ```

2. **Access Preview Environment**
   ```bash
   # Forward preview environment service
   kubectl port-forward svc/app1 -n preview-feature-branch-name 8080:80
   ```

3. **Cleanup Preview Environment**
   ```bash
   ./scripts/cleanup-preview-env.sh feature-branch-name
   ```

## Adding New Applications

1. Create application base configuration:
   ```bash
   mkdir -p apps/new-app/base
   # Add deployment.yaml, service.yaml, etc.
   ```

2. Create environment overlays:
   ```bash
   mkdir -p apps/new-app/overlays/{dev,prod,preview}
   # Add environment-specific patches
   ```

3. Add ArgoCD application definition:
   ```bash
   # Add new-app.yaml to argocd/apps/{env}/
   ```

4. Update App of Apps configuration if needed

## Troubleshooting

- **ArgoCD Sync Issues**
  ```bash
  argocd app get <app-name>
  argocd app sync <app-name>
  ```

- **Preview Environment Issues**
  ```bash
  kubectl get all -n preview-{branch-name}
  kubectl describe pod <pod-name> -n preview-{branch-name}
  ```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details 