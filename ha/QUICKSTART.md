# HashFoundry Infrastructure - HA Quick Start

Quick deployment of High Availability Kubernetes cluster in Digital Ocean with ArgoCD.

## HA Configuration Features

- ✅ **3-node cluster** for high availability
- ✅ **Auto-scaling** (3-6 nodes)
- ✅ **Economic variant** (s-1vcpu-2gb) - ~$48/month
- ✅ **Load balancer** managed by ArgoCD
- ✅ **Fault tolerance** at node level

## Requirements

- DigitalOcean API Token
- CLI tools: `terraform`, `kubectl`, `helm`, `doctl`, `envsubst`

**Note**: All scripts now automatically check for required CLI tools and provide installation instructions if any are missing.

## Deployment Options

### Option 1: Full Deployment (Recommended)
```bash
# 1. Initialize configuration
./init.sh

# 2. Edit .env file (set your DO_TOKEN)
nano .env

# 3. Deploy infrastructure and applications
./deploy-terraform.sh && ./deploy-k8s.sh
```

### Option 2: Step-by-Step Deployment
```bash
# 1. Initialize configuration
./init.sh

# 2. Edit .env file (set your DO_TOKEN)
nano .env

# 3. Deploy only Terraform infrastructure
./deploy-terraform.sh

# 4. Deploy only Kubernetes applications
./deploy-k8s.sh
```

### Option 3: Check Status
```bash
# Check everything
./status.sh

# Check only infrastructure
./status.sh --terraform

# Check only applications
./status.sh --kubernetes
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
- ✅ NFS Provisioner for ReadWriteMany storage
- ✅ ArgoCD HA with NFS integration
- ✅ NGINX Ingress Controller
- ✅ HashFoundry React application
- ✅ Load Balancer for external access
- ✅ Automatic application synchronization

## Infrastructure Cleanup

```bash
./cleanup.sh
```

Or manually:

```bash
cd terraform
source ../.env
terraform destroy -var="do_token=$DO_TOKEN" -auto-approve
```

## ArgoCD Password Configuration

ArgoCD password is configured in the `.env` file:

```bash
ARGOCD_ADMIN_PASSWORD=your_custom_password
```

Password changes are applied on the next deployment.
