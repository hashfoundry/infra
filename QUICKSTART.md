# HashFoundry Infrastructure - Quick Start

Quick deployment of Kubernetes cluster in Digital Ocean with ArgoCD.

## Requirements

- DigitalOcean API Token
- CLI tools: `terraform`, `kubectl`, `helm`, `doctl`, `envsubst`

**Note**: All scripts now automatically check for required CLI tools and provide installation instructions if any are missing.

## Deployment (2 commands)

```bash
# 1. Initialize configuration
./init.sh

# 2. Edit .env file (set your DO_TOKEN)
nano .env

# 3. Deploy entire infrastructure
./deploy.sh
```

## Access to ArgoCD

After deployment:

```bash
# Create port-forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Open in browser: http://localhost:8080
# Login: admin
# Password: admin (or value from .env file)
```

## Status Check

```bash
# Check cluster status
kubectl get nodes

# Check ArgoCD applications
kubectl get applications -n argocd

# Check ingress
kubectl get ingress -A
```

## What gets deployed

- ✅ Kubernetes cluster in Digital Ocean (fra1)
- ✅ NGINX Ingress Controller
- ✅ ArgoCD with pre-configured password
- ✅ HashFoundry React application
- ✅ Load Balancer for external access

## Infrastructure Cleanup

```bash
cd terraform
source config/.env
terraform destroy -var="do_token=$DO_TOKEN" -auto-approve
```

## ArgoCD Password Configuration

ArgoCD password is configured in the `.env` file:

```bash
ARGOCD_ADMIN_PASSWORD=your_custom_password
```

Password changes are applied on the next deployment.
