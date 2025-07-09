# Ingress Migration Guide

This document describes the migration from LoadBalancer services to NGINX Ingress Controller for external access to applications.

## Overview

The migration involves:
1. Installing NGINX Ingress Controller
2. Creating Ingress resources for applications
3. Migrating from LoadBalancer to ClusterIP services
4. Updating application configurations

## Benefits of Ingress Architecture

- **Cost Reduction**: Single LoadBalancer instead of multiple ($12/month vs $12/month per service)
- **Centralized Management**: All HTTP/HTTPS traffic through one entry point
- **SSL Termination**: Automatic SSL certificate management
- **Path-based Routing**: Route traffic based on hostnames and paths
- **Advanced Features**: Rate limiting, authentication, redirects

## Migration Steps

### 1. Install NGINX Ingress Controller

```bash
cd k8s/addons/nginx-ingress
make install
```

This creates:
- NGINX Ingress Controller deployment
- LoadBalancer service for external access
- IngressClass resource

### 2. Create Ingress Resources

For each application, create an Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### 3. Update Service Types

Change application services from LoadBalancer to ClusterIP:

```yaml
# Before
service:
  type: LoadBalancer
  port: 80

# After
service:
  type: ClusterIP
  port: 80
```

### 4. Configure DNS

Update DNS records to point to the NGINX Ingress Controller IP:

```bash
# Get Ingress Controller IP
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller

# Update DNS or /etc/hosts
<INGRESS_IP> app.example.com
```

## Current State

### Deployed Components

1. **NGINX Ingress Controller**
   - Namespace: `ingress-nginx`
   - External IP: `134.199.188.21`
   - Ports: 80, 443

2. **ArgoCD Ingress**
   - Host: `argocd.hashfoundry.local`
   - Namespace: `argocd`
   - SSL: Enabled

3. **HashFoundry React App**
   - Dev: `app-dev.hashfoundry.local`
   - Staging: `app-staging.hashfoundry.local`
   - Prod: `app.hashfoundry.local`
   - Service: ClusterIP

### Access URLs

| Service | URL | Status |
|---------|-----|--------|
| ArgoCD UI | `https://argocd.hashfoundry.local` | ✅ Working (ClusterIP + Ingress) |
| React App (Dev) | `https://app-dev.hashfoundry.local` | 🔄 Pending hostname update |
| React App (Staging) | `https://app-staging.hashfoundry.local` | 🔄 Pending deployment |
| React App (Prod) | `https://app.hashfoundry.local` | 🔄 Pending deployment |

## DNS Configuration

Add to `/etc/hosts` or configure DNS:

```
134.199.188.21 argocd.hashfoundry.local
134.199.188.21 app-dev.hashfoundry.local
134.199.188.21 app-staging.hashfoundry.local
134.199.188.21 app.hashfoundry.local
```

## Troubleshooting

### Common Issues

1. **502 Bad Gateway**
   - Check if backend service is running
   - Verify service port configuration
   - Check ingress annotations

2. **404 Not Found**
   - Verify hostname in request
   - Check DNS configuration
   - Verify ingress rules

3. **SSL Issues**
   - Check ingress annotations
   - Verify TLS configuration
   - Check certificate status

### Debugging Commands

```bash
# Check ingress status
kubectl get ingress --all-namespaces

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Check service endpoints
kubectl get endpoints -n <namespace>

# Test connectivity (use HTTPS for SSL redirect)
curl -k -H "Host: <hostname>" https://<ingress-ip>/

# Test specific services
curl -k -H "Host: argocd.hashfoundry.local" https://134.199.188.21/
curl -k -H "Host: app-dev.hashfoundry.local" https://134.199.188.21/
```

### Testing Results ✅

```bash
# ArgoCD UI - Working
$ curl -k -H "Host: argocd.hashfoundry.local" https://134.199.188.21/
<!doctype html><html lang="en"><head><title>Argo CD</title>...

# React App Dev - Working  
$ curl -k -H "Host: app-dev.hashfoundry.local" https://134.199.188.21/
<!doctype html><html lang="en"><head><title>HashFoundry | Pioneering Web3 Technology</title>...

# Wrong hostname - 404 (expected)
$ curl nginx.local
default backend - 404
```

## Rollback Plan

If issues occur, rollback by:

1. Change services back to LoadBalancer type
2. Update DNS to point to individual service IPs
3. Remove ingress resources if needed

```bash
# Rollback service type
kubectl patch svc <service-name> -n <namespace> -p '{"spec":{"type":"LoadBalancer"}}'
```

## Next Steps

1. ✅ NGINX Ingress Controller deployed
2. ✅ ArgoCD Ingress configured
3. ✅ React app service migrated to ClusterIP
4. 🔄 Update React app ingress configuration (Bitnami chart)
5. 🔄 Deploy staging and prod environments
6. 🔄 Configure SSL certificates (Let's Encrypt)
7. 🔄 Set up monitoring and alerting

## Security Considerations

- Enable SSL/TLS for all ingresses
- Configure rate limiting
- Set up Web Application Firewall (WAF) rules
- Implement network policies
- Regular security updates for NGINX Ingress Controller
