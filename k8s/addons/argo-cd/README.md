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
| `argo-cd.redis-ha.replicas` | Number of Redis HA server replicas | `1` |
| `argo-cd.redis-ha.servers` | Number of Redis HA servers (StatefulSet) | `1` |
| `argo-cd.redis-ha.haproxy.replicas` | Number of Redis HA proxy replicas | `1` |
| `argo-cd.dex.enabled` | Enable Dex for authentication | `true` |
| `argo-cd.notifications.enabled` | Enable notifications | `true` |

### Environment-Specific Parameters

Each environment (dev, staging, prod) has its own values file with specific configurations:

- `values.dev.yaml`: Development environment configuration
- `values.staging.yaml`: Staging environment configuration
- `values.prod.yaml`: Production environment configuration

## Troubleshooting

### Redis HA Anti-Affinity Issues

If you encounter pods stuck in `Pending` status due to anti-affinity rules in single-node clusters, the configuration has been updated to use `preferredDuringSchedulingIgnoredDuringExecution` instead of `requiredDuringSchedulingIgnoredDuringExecution`. This allows pods to be scheduled on the same node when no other nodes are available.

**Key changes made:**
- Redis HA server replicas reduced to 1 for single-node clusters
- Redis HA proxy replicas reduced to 1 for single-node clusters
- Anti-affinity rules changed to "preferred" instead of "required"

**For production environments with multiple nodes:**
You may want to increase the replica counts and use stricter anti-affinity rules:

```yaml
redis-ha:
  replicas: 3
  haproxy:
    replicas: 3
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: redis-ha-haproxy
              release: argocd
          topologyKey: kubernetes.io/hostname
```

### Cleaning Up Old ReplicaSets

If you encounter persistent pending pods after configuration changes, you may need to clean up old ReplicaSets:

```bash
# List all ReplicaSets for HAProxy
kubectl get replicasets -n argocd | grep haproxy

# Delete old ReplicaSets (keep only the current one)
kubectl delete replicaset <old-replicaset-name> -n argocd

# Force scale deployment to desired replicas
kubectl scale deployment argocd-redis-ha-haproxy -n argocd --replicas=1
```

**Note:** Old ReplicaSets may retain outdated anti-affinity configurations even after deployment updates, causing pods to remain in Pending status.

For detailed troubleshooting steps and solutions, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
