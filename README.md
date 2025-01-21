# Infrastructure Prototype

This repository contains a GitOps-based infrastructure setup using ArgoCD for both development and production environments.

## Project Structure

```
.
├── apps/                          # Application definitions
│   ├── app1/                     # First application
│   │   ├── base/                # Base Kubernetes manifests
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/            # Environment-specific overlays
│   │       ├── dev/            # Development environment
│   │       │   ├── index.html
│   │       │   ├── nginx-config.yaml
│   │       │   ├── resource-patch.yaml
│   │       │   └── kustomization.yaml
│   │       └── prod/           # Production environment
│   │           ├── index.html
│   │           ├── nginx-config.yaml
│   │           ├── resource-patch.yaml
│   │           └── kustomization.yaml
│   └── app2/                     # Second application (same structure as app1)
├── argocd/                        # ArgoCD configuration
│   ├── bootstrap/               # Bootstrap applications
│   │   ├── dev/               # Development bootstrap
│   │   │   ├── bootstrap.yaml  # Bootstrap Application pointing to dev apps
│   │   │   └── install.yaml    # ArgoCD installation manifest
│   │   │   └── app-of-apps.yaml # App of Apps manifest, points to dev apps in /argocd/apps/dev
│   │   └── prod/              # Production bootstrap
│   │       ├── bootstrap.yaml  # Bootstrap Application pointing to prod apps
│   │       └── install.yaml    # ArgoCD installation manifest
│   │       └── app-of-apps.yaml # App of Apps manifest, points to prod apps in /argocd/apps/prod
│   └── apps/                   # ArgoCD Application definitions
│       ├── dev/              # Development applications
│       │   ├── app1.yaml     # Points to app1/overlays/dev
│       │   └── app2.yaml     # Points to app2/overlays/dev
│       └── prod/             # Production applications
│           ├── app1.yaml     # Points to app1/overlays/prod
│           └── app2.yaml     # Points to app2/overlays/prod
└── scripts/                       # Utility scripts
    ├── create-cluster.sh        # Cluster creation script
    ├── delete-cluster.sh        # Cluster deletion script
    └── port-forward.sh         # Port forwarding utility
```

## ArgoCD Bootstrap Process

The setup uses a two-level GitOps approach:

1. **Bootstrap Level** (`argocd/bootstrap/{env}/bootstrap.yaml`):
   - Installed directly via kubectl during cluster creation
   - Points to the environment-specific apps directory (`argocd/apps/{env}/`)
   - Manages all Application resources for the environment
   - Self-manages ArgoCD through the `install.yaml`

2. **Application Level** (`argocd/apps/{env}/*.yaml`):
   - Managed by the bootstrap Application
   - Each Application points to its respective overlay (`apps/{app}/overlays/{env}`)
   - Automatically syncs when changes are made to the overlay
   - Includes environment-specific configurations

### Bootstrap Configuration Example
```yaml
# argocd/bootstrap/{env}/bootstrap.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap-{env}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Geniekort/k8s-envs-prototype.git
    targetRevision: main
    path: argocd/apps/{env}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Setup Instructions

1. Create a cluster (dev or prod):
   ```bash
   ./scripts/create-cluster.sh --environment dev   # For development
   # or
   ./scripts/create-cluster.sh --environment prod  # For production
   ```

2. Access services:
   ```bash
   ./scripts/port-forward.sh
   ```
   This will show a menu to:
   - Access ArgoCD UI
   - Forward ports for applications
   - Show service credentials

3. Delete cluster:
   ```bash
   ./scripts/delete-cluster.sh --environment dev   # For development
   # or
   ./scripts/delete-cluster.sh --environment prod  # For production
   ```

## Environment Differences

### Development
- Uses Minikube with dev profile
- Single replica per application
- NodePort services for direct access
- Lower resource limits

### Production
- Uses Minikube with prod profile
- Multiple replicas for high availability
- ClusterIP services
- Higher resource limits and requests

## Applications

### App1 & App2
- Simple nginx-based web applications
- Environment-specific configurations
- Resource limits and scaling based on environment
- Configurable through overlays

## GitOps Workflow

1. ArgoCD is installed via bootstrap application
2. Bootstrap application manages environment-specific applications
3. Each application is deployed using Kustomize overlays
4. Changes to the repository automatically sync to the cluster 