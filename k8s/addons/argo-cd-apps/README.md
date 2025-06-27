# ArgoCD Apps

Helm Chart for the ArgoCD declarative setup. Applications defined here are automatically added to ArgoCD (After the first manual deployment of this Chart).

## Overview

This Helm chart deploys Argo CD Applications, which are used to manage the deployment of applications in a GitOps manner. It is designed to work with the Argo CD Helm chart and provides a way to declaratively define applications that should be managed by Argo CD.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.2.0+
- Argo CD installed in the cluster

## Installation

### Manual Installation

#### Development Environment

```bash
cd k8s/addons/argo-cd-apps
helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.dev.yaml
```

#### Staging Environment

```bash
cd k8s/addons/argo-cd-apps
helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.staging.yaml
```

#### Production Environment

```bash
cd k8s/addons/argo-cd-apps
helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.prod.yaml
```

### Using GitHub Actions

You can also use the GitHub Actions workflow to deploy Argo CD Apps:

1. Go to the GitHub repository
2. Navigate to Actions
3. Select the "Deploy Argo CD" workflow
4. Click "Run workflow"
5. Select the environment (dev, staging, or prod)
6. Click "Run workflow"

## Adding New Applications

To add a new application to be managed by Argo CD, you need to add it to the appropriate values file:

```yaml
apps:
  - name: my-new-app
    namespace: my-new-app-namespace
    autosync: true
```

This will create an Argo CD Application that points to the `k8s/apps/my-new-app` directory in your repository.

## Configuration Options

### Application Options

```yaml
apps:
  - name: hashfoundry-react
    namespace: hashfoundry-react-dev
    # Override branch
    targetRevision: <branch>
    # Enable Autosync
    autosync: true
    # Override default valueFiles
    valueFiles:
        - values.yaml
        - values.override.yaml

    # For plain manifests only, default is Helm
    source:
        directory: true
```

### Addon Options

```yaml
addons:
  - name: argo-cd-apps
    namespace: argocd
    autosync: true
```

## Default Values

The default values are defined in `values.yaml`:

```yaml
defaults:
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  source:
    repoURL: git@github.com:hashfoundry/hashfoundry-infra.git
    targetRevision: HEAD
```

These values can be overridden in the environment-specific values files.
