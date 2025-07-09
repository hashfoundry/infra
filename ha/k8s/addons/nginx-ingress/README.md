# NGINX Ingress Controller

## Overview

This Helm chart deploys the NGINX Ingress Controller on Kubernetes. It provides HTTP and HTTPS routing for applications in the cluster, replacing individual LoadBalancer services with a single entry point.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installation

### Development Environment

```bash
make deploy-dev
```

### Staging Environment

```bash
make deploy-staging
```

### Production Environment

```bash
make deploy-prod
```

## Configuration

### Key Features

- **Single LoadBalancer**: One DigitalOcean LoadBalancer for all applications
- **SSL Termination**: Automatic HTTPS redirect and SSL handling
- **Real IP Forwarding**: Proper client IP forwarding from DigitalOcean
- **Performance Tuning**: Optimized for single-node cluster
- **Monitoring**: Metrics endpoint enabled

### LoadBalancer Configuration

The ingress controller uses a DigitalOcean LoadBalancer with the following settings:

- **Algorithm**: Round Robin
- **Protocol**: HTTP (SSL termination at ingress level)
- **Type**: Regional Network
- **Name**: `hashfoundry-ingress-lb`

### Resource Allocation

- **Controller**: 100m CPU, 128Mi RAM (requests) / 200m CPU, 256Mi RAM (limits)
- **Default Backend**: 25m CPU, 32Mi RAM (requests) / 50m CPU, 64Mi RAM (limits)

## Usage

Once installed, applications can use Ingress resources instead of LoadBalancer services:

### Before (LoadBalancer):
```yaml
service:
  type: LoadBalancer
  port: 80
```

### After (Ingress):
```yaml
service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Benefits

1. **Cost Savings**: One LoadBalancer instead of multiple ($12/month vs $12/month per service)
2. **SSL Management**: Centralized SSL certificate management
3. **Domain Routing**: Route different domains to different services
4. **Path-based Routing**: Route different paths to different services
5. **Centralized Monitoring**: All HTTP traffic in one place

## Monitoring

The ingress controller exposes metrics on port 10254 that can be scraped by Prometheus:

- Request rate and latency
- Error rates by status code
- Backend health status
- SSL certificate expiration

## Troubleshooting

### Check Ingress Controller Status

```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/nginx-ingress-ingress-nginx-controller
```

### Check LoadBalancer IP

```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

### Test Ingress Rules

```bash
kubectl get ingress --all-namespaces
kubectl describe ingress <ingress-name> -n <namespace>
```

## Migration from LoadBalancer

When migrating applications from LoadBalancer to Ingress:

1. Install nginx-ingress controller
2. Change service type from LoadBalancer to ClusterIP
3. Add Ingress resource with proper host/path rules
4. Update DNS to point to the ingress LoadBalancer IP
5. Remove old LoadBalancer services

## Security

- **SSL Redirect**: Automatic HTTP to HTTPS redirect
- **Security Headers**: Custom security headers can be added
- **Rate Limiting**: Can be configured per ingress
- **IP Whitelisting**: Can be configured per ingress
