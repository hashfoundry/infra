# HashFoundry Infrastructure

This repository contains the infrastructure code for HashFoundry, including Kubernetes manifests, Helm charts, and GitHub Actions workflows for continuous deployment.

## Repository Structure

```
.
├── .github/workflows/       # GitHub Actions workflows
├── k8s/                     # Kubernetes manifests and Helm charts
│   ├── addons/              # Kubernetes addons (e.g., Argo CD, Ingress NGINX)
│   │   ├── argo-cd/         # Argo CD Helm chart
│   │   └── argo-cd-apps/    # Argo CD Applications Helm chart
│   └── apps/                # Application Helm charts
│       └── hashfoundry-react/ # HashFoundry React application
└── terraform/               # Terraform code for infrastructure provisioning
```

## Continuous Deployment with Argo CD

This repository uses Argo CD for continuous deployment of applications to Kubernetes clusters. Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

### Deployment Flow

1. Changes are pushed to the repository
2. GitHub Actions workflow deploys Argo CD and Argo CD Apps to the Kubernetes cluster
3. Argo CD Apps defines the applications to be deployed
4. Argo CD continuously monitors the repository for changes and automatically deploys them to the cluster

### Setting Up Argo CD

To set up Argo CD, follow these steps:

1. Deploy Argo CD to the cluster:

```bash
cd k8s/addons/argo-cd
helm dep up
kubectl config use-context hashfoundry-dev
helm upgrade --install --create-namespace -n argocd argocd . -f values.yaml -f values.dev.yaml
```

2. Deploy Argo CD Apps to the cluster:

```bash
cd k8s/addons/argo-cd-apps
helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.dev.yaml
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

- `deploy_argocd.yml`: Deploys Argo CD and Argo CD Apps to the cluster
- `deploy_hashfoundry-react.yml`: Deploys the HashFoundry React application to the cluster

### Running a Workflow Manually

To run a workflow manually:

1. Go to the GitHub repository
2. Navigate to Actions
3. Select the workflow you want to run
4. Click "Run workflow"
5. Select the environment (dev, staging, or prod)
6. Click "Run workflow"

## Environments

This repository supports the following environments:

- `dev`: Development environment
- `staging`: Staging environment
- `prod`: Production environment

Each environment has its own values file for each Helm chart.
