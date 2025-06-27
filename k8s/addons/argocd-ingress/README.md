# ArgoCD Ingress

This Helm chart provides Ingress configuration for ArgoCD server to enable external access through NGINX Ingress Controller.

## Overview

This chart creates an Ingress resource that routes external traffic to the ArgoCD server service, allowing access to the ArgoCD web UI through a domain name instead of port-forwarding or LoadBalancer services.

## Prerequisites

- Kubernetes cluster with NGINX Ingress Controller installed
- ArgoCD installed and running in the cluster
- DNS configuration or `/etc/hosts` entry for the domain

## Installation

### Using Helm directly

```bash
# Install the chart
helm install argocd-ingress . -n argocd

# Upgrade the chart
helm upgrade argocd-ingress . -n argocd

# Uninstall the chart
helm uninstall argocd-ingress -n argocd
```

### Using Makefile

```bash
# Install
make install

# Upgrade
make upgrade

# Uninstall
make uninstall

# Generate templates
make template

# Lint the chart
make lint
```

## Configuration

### Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Target namespace for ArgoCD | `argocd` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.annotations` | Ingress annotations | SSL redirect enabled |
| `ingress.hosts[0].host` | Hostname for ArgoCD | `argocd.hashfoundry.local` |
| `ingress.hosts[0].paths[0].path` | Path for routing | `/` |
| `ingress.hosts[0].paths[0].pathType` | Path type | `Prefix` |
| `ingress.hosts[0].paths[0].backend.service.name` | ArgoCD service name | `argocd-server` |
| `ingress.hosts[0].paths[0].backend.service.port` | ArgoCD service port | `80` |

### Custom Values

Create a custom values file to override defaults:

```yaml
# custom-values.yaml
ingress:
  hosts:
    - host: argocd.example.com
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: argocd-server
              port: 80
  tls:
    - secretName: argocd-tls
      hosts:
        - argocd.example.com
```

Then install with custom values:

```bash
helm install argocd-ingress . -n argocd -f custom-values.yaml
```

## Access

After installation, ArgoCD will be accessible at:

- **URL**: `https://argocd.hashfoundry.local`
- **Default credentials**: 
  - Username: `admin`
  - Password: Get from secret: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

### DNS Configuration

Add to your `/etc/hosts` file (or configure DNS):

```
<NGINX_INGRESS_IP> argocd.hashfoundry.local
```

Get the NGINX Ingress IP:

```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

## Troubleshooting

### Common Issues

1. **502 Bad Gateway**: Check if ArgoCD server is running and accessible
2. **404 Not Found**: Verify hostname and DNS configuration
3. **SSL Issues**: Check ingress annotations and TLS configuration

### Debugging Commands

```bash
# Check ingress status
kubectl get ingress -n argocd

# Describe ingress for events
kubectl describe ingress argocd-server-ingress -n argocd

# Check ArgoCD server service
kubectl get svc -n argocd argocd-server

# Check ArgoCD server pods
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

## Security Considerations

- The chart enables SSL redirect by default
- Consider adding TLS certificates for production use
- Review and customize ingress annotations based on security requirements
- Ensure proper network policies are in place if required

## Integration with ArgoCD Applications

This Ingress can be managed as an ArgoCD Application for GitOps workflow:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-ingress
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <your-repo>
    targetRevision: HEAD
    path: k8s/addons/argocd-ingress
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
