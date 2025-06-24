# Nginx

## Overview

This Helm chart deploys Nginx web server on Kubernetes. It is based on the Bitnami Nginx Helm chart and provides additional configuration for different environments.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installation

### Development Environment

```bash
helm install nginx . -f values.dev.yaml -n nginx-dev
```

### Staging Environment

```bash
helm install nginx . -f values.staging.yaml -n nginx-staging
```

### Production Environment

```bash
helm install nginx . -f values.prod.yaml -n nginx-prod
```

## Configuration

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nginx.replicaCount` | Number of Nginx replicas | `2` |
| `nginx.image.registry` | Nginx image registry | `docker.io` |
| `nginx.image.repository` | Nginx image repository | `bitnami/nginx` |
| `nginx.image.tag` | Nginx image tag | `latest` |
| `nginx.service.type` | Kubernetes service type | `ClusterIP` |
| `nginx.service.port` | Service port | `80` |
| `nginx.ingress.enabled` | Enable ingress | `false` |
| `nginx.metrics.enabled` | Enable metrics | `true` |

### Environment-Specific Parameters

Each environment (dev, staging, prod) has its own values file with specific configurations:

- `values.dev.yaml`: Development environment configuration
- `values.staging.yaml`: Staging environment configuration
- `values.prod.yaml`: Production environment configuration

## Upgrading

To upgrade the release:

```bash
helm upgrade nginx . -f values.<env>.yaml -n nginx-<env>
```

## Uninstalling

To uninstall/delete the deployment:

```bash
helm uninstall nginx -n nginx-<env>
```
