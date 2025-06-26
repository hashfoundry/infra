# Argo CD

## Overview

This Helm chart deploys Argo CD, a declarative, GitOps continuous delivery tool for Kubernetes. It is based on the official Argo CD Helm chart and provides additional configuration for different environments.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.2.0+

## Installation

### Manual Installation

#### Development Environment

```bash
cd k8s/addons/argo-cd
helm dep up
kubectl config use-context hashfoundry-dev
helm upgrade --install --create-namespace -n argocd argocd . -f values.yaml -f values.dev.yaml
```

#### Staging Environment

```bash
cd k8s/addons/argo-cd
helm dep up
kubectl config use-context hashfoundry-staging
helm upgrade --install --create-namespace -n argocd argocd . -f values.yaml -f values.staging.yaml
```

#### Production Environment

```bash
cd k8s/addons/argo-cd
helm dep up
kubectl config use-context hashfoundry-prod
helm upgrade --install --create-namespace -n argocd argocd . -f values.yaml -f values.prod.yaml
```

### Using GitHub Actions

You can also use the GitHub Actions workflow to deploy Argo CD:

1. Go to the GitHub repository
2. Navigate to Actions
3. Select the "Deploy Argo CD" workflow
4. Click "Run workflow"
5. Select the environment (dev, staging, or prod)
6. Click "Run workflow"

## Accessing Argo CD

After deployment, you can access the Argo CD UI at:

- Development: https://argocd.dev.hashfoundry.com
- Staging: https://argocd.staging.hashfoundry.com
- Production: https://argocd.hashfoundry.com

### Getting the Initial Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Deploying Applications with Argo CD

After Argo CD is deployed, you can deploy applications using the Argo CD Apps Helm chart:

```bash
cd k8s/addons/argo-cd-apps
helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.dev.yaml
```

This will deploy all applications defined in the values.dev.yaml file.

## Configuration

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `argo-cd.server.replicas` | Number of Argo CD server replicas | `2` |
| `argo-cd.repoServer.replicas` | Number of Argo CD repo server replicas | `2` |
| `argo-cd.applicationSet.replicas` | Number of Argo CD application set replicas | `2` |
| `argo-cd.dex.enabled` | Enable Dex for authentication | `true` |
| `argo-cd.notifications.enabled` | Enable notifications | `true` |

### Environment-Specific Parameters

Each environment (dev, staging, prod) has its own values file with specific configurations:

- `values.dev.yaml`: Development environment configuration
- `values.staging.yaml`: Staging environment configuration
- `values.prod.yaml`: Production environment configuration
