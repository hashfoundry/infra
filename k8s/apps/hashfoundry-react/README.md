# HashFoundry React

## Overview

This Helm chart deploys the HashFoundry React application on Kubernetes. It is based on the Bitnami Nginx Helm chart and provides additional configuration for different environments.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installation

### Development Environment

```bash
helm install hashfoundry-react . -f values.dev.yaml -n hashfoundry-react-dev
```

### Staging Environment

```bash
helm install hashfoundry-react . -f values.staging.yaml -n hashfoundry-react-staging
```

### Production Environment

```bash
helm install hashfoundry-react . -f values.prod.yaml -n hashfoundry-react-prod
```

## Configuration

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nginx.replicaCount` | Number of HashFoundry React replicas | `2` |
| `nginx.image.registry` | Image registry | `docker.io` |
| `nginx.image.repository` | Image repository | `alexhashfoundry/hashfoundry-react` |
| `nginx.image.tag` | Image tag | `a2a2679b096d59206a2c24e53d2c815a25cde7c8` |
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
helm upgrade hashfoundry-react . -f values.<env>.yaml -n hashfoundry-react-<env>
```

## Uninstalling

To uninstall/delete the deployment:

```bash
helm uninstall hashfoundry-react -n hashfoundry-react-<env>
```

## Network Configuration

### LoadBalancer Service

The application is exposed via LoadBalancer service type, which provides external access through DigitalOcean Load Balancer:

- **Development**: Accessible via LoadBalancer IP (automatically assigned)
- **Staging**: Accessible via LoadBalancer IP (automatically assigned)  
- **Production**: Accessible via LoadBalancer IP (automatically assigned)

### Ingress Configuration

**Note**: Ingress is currently disabled (`ingress.enabled: false`) in all environments because no Ingress Controller is installed in the cluster. The application is accessible through LoadBalancer service instead.

To enable Ingress in the future:
1. Install an Ingress Controller (e.g., nginx-ingress)
2. Set `ingress.enabled: true` in the appropriate values file
3. Configure proper hostnames and TLS certificates

## About the Application

The HashFoundry React application is a simple React application packaged in an Nginx container and running on port 80. The Docker image is available at `docker.io/alexhashfoundry/hashfoundry-react:a2a2679b096d59206a2c24e53d2c815a25cde7c8`.
