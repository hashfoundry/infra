# HashFoundry Infrastructure

This repository contains the infrastructure code for HashFoundry, including Kubernetes manifests, Helm charts, and GitHub Actions workflows for continuous deployment.

## Repository Structure

```
.
├── .github/workflows/       # GitHub Actions workflows
├── k8s/                     # Kubernetes manifests and Helm charts
│   ├── addons/              # Kubernetes addons
│   │   ├── argo-cd/         # Argo CD Helm chart
│   │   ├── argo-cd-apps/    # Argo CD Applications Helm chart
│   │   ├── nginx-ingress/   # NGINX Ingress Controller Helm chart
│   │   └── argocd-ingress/  # ArgoCD Ingress configuration Helm chart
│   └── apps/                # Application Helm charts
│       └── hashfoundry-react/ # HashFoundry React application
└── terraform/               # Terraform code for infrastructure provisioning
```

## Continuous Deployment with Argo CD

This repository uses Argo CD for continuous deployment of applications to Kubernetes clusters. Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

### Deployment Flow

1. Changes are pushed to the repository
2. Argo CD automatically detects changes and synchronizes applications
3. Argo CD Apps defines the applications to be deployed
4. Argo CD continuously monitors the repository for changes and automatically deploys them to the cluster

### Setting Up Argo CD

To set up Argo CD, follow these steps:

1. Deploy Argo CD to the cluster:

```bash
cd k8s/addons/argo-cd
helm dep up
helm upgrade --install --create-namespace -n argocd argocd . -f values.yaml
```

2. Deploy Argo CD Apps to the cluster:

```bash
cd k8s/addons/argo-cd-apps
helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml
```

3. Access the Argo CD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Then open http://localhost:8080 in your browser.

4. Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Adding a New Application

To add a new application to be managed by Argo CD:

1. Create a new directory in `k8s/apps/` for your application
2. Add your application's Helm chart or Kubernetes manifests to the directory
3. Add your application to the appropriate values file in `k8s/addons/argo-cd-apps/`:

```yaml
apps:
  - name: my-new-app
    namespace: my-new-app-namespace
    autosync: true
```

4. Commit and push your changes
5. Argo CD will automatically deploy your application to the cluster

## GitHub Actions Workflows

This repository includes the following GitHub Actions workflows:

- `deploy_hashfoundry-react.yml`: Deploys the HashFoundry React application to the cluster

### Running a Workflow Manually

To run a workflow manually:

1. Go to the GitHub repository
2. Navigate to Actions
3. Select the workflow you want to run
4. Click "Run workflow"
5. Enter the image tag to deploy
6. Click "Run workflow"

## Ingress Architecture

This infrastructure uses NGINX Ingress Controller for external access to applications and services.

### Components

- **NGINX Ingress Controller**: Provides external access to cluster services and automatically creates a DigitalOcean Load Balancer
- **ArgoCD Ingress**: Enables web access to ArgoCD UI
- **Application Ingresses**: Route traffic to applications (e.g., HashFoundry React app)

### Load Balancer Strategy

The infrastructure uses a single load balancer approach:
- **NGINX Ingress Load Balancer**: Automatically created by Kubernetes when NGINX Ingress Controller is deployed

This approach is efficient and follows Kubernetes best practices.

### Setup

1. Deploy NGINX Ingress Controller:

```bash
cd k8s/addons/nginx-ingress
make install
```

2. Deploy ArgoCD Ingress:

```bash
cd k8s/addons/argocd-ingress
make install
```

### Access URLs

After deployment, services are accessible at:

- **ArgoCD UI**: `https://argocd.hashfoundry.local`
- **React App**: `https://app.hashfoundry.local`

### DNS Configuration

Add to your `/etc/hosts` file (or configure DNS):

```
<NGINX_INGRESS_IP> argocd.hashfoundry.local
<NGINX_INGRESS_IP> app.hashfoundry.local
```

Get the NGINX Ingress IP:

```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

## Complete Infrastructure Deployment

This repository is designed as a complete Infrastructure as Code (IaC) solution that can be deployed with just two commands.

### Prerequisites

1. **Tools Required**:
   - `terraform` (>= 1.0.0)
   - `kubectl`
   - `helm` (>= 3.0)
   - `doctl` (DigitalOcean CLI)
   - `envsubst` (usually included with gettext)

### Quick Start (Two Commands)

To deploy the complete infrastructure from scratch:

```bash
# 1. Initialize configuration files
./init.sh

# 2. Edit .env file with your DigitalOcean API token, then deploy
./deploy.sh
```

### Detailed Setup

1. **Initialize the project**:
   ```bash
   ./init.sh
   ```
   This creates `.env` file from the `.env.example` template.

2. **Configure your environment**:
   Edit the `.env` file and set your DigitalOcean API token:
   ```bash
   # Edit the .env file
   nano .env
   
   # Set your DO_TOKEN
   DO_TOKEN=your_actual_digitalocean_api_token
   ```

3. **Deploy everything**:
   ```bash
   ./deploy.sh
   ```

### ArgoCD Password Configuration

The system now uses a predefined password for ArgoCD admin user:
- **Username**: `admin`
- **Password**: `admin` (configurable in `.env` file)

You can change the password by editing the `ARGOCD_ADMIN_PASSWORD` variable in `.env` file before deployment.

### Manual Deployment (Advanced)

If you prefer manual control, you can still deploy step by step:

```bash
# 1. Deploy infrastructure with Terraform
cd terraform
./terraform.sh init
./terraform.sh apply -auto-approve

# 2. Configure kubectl context
doctl kubernetes cluster kubeconfig save hashfoundry

# 3. Deploy ArgoCD with custom password
cd ../k8s/addons/argo-cd
export ARGOCD_ADMIN_PASSWORD=admin
export ARGOCD_ADMIN_PASSWORD_HASH='$2y$10$scg/i8rGtlstEcSyZTr0Nelkr1S29UJA5gyMZ5YfBaDiqtNNYm.M.'
envsubst < values.yaml | helm upgrade --install --create-namespace -n argocd argocd . -f -

# 4. Deploy ArgoCD Apps
cd ../argo-cd-apps
helm upgrade --install -n argocd argo-cd-apps . -f values.yaml
```

### Infrastructure Components

The complete deployment includes:

1. **DigitalOcean Kubernetes Cluster** (via Terraform)
   - 1 node with s-1vcpu-2gb
   - Kubernetes v1.33.1
   - Located in fra1 region

2. **Core Applications** (via ArgoCD)
   - NGINX Ingress Controller (automatically creates DigitalOcean Load Balancer)
   - ArgoCD Ingress
   - HashFoundry React Application

### Verification

After deployment, verify everything is working:

```bash
# Check cluster status
kubectl get nodes

# Check all applications
kubectl get applications -n argocd

# Check ingress
kubectl get ingress -A

# Get external IP
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

### Cleanup

To destroy the entire infrastructure:

```bash
cd terraform
source config/.env
terraform destroy -var="do_token=$DO_TOKEN" -auto-approve
```
