# Metrics Server

## Overview

This Helm chart deploys the Metrics Server on Kubernetes cluster. Metrics Server is a scalable, efficient source of container resource metrics for Kubernetes built-in autoscaling pipelines.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installation

### Manual Installation

```bash
cd ha/k8s/addons/metrics-server
make install
```

### ArgoCD Installation (Recommended)

Metrics Server is configured to be deployed via ArgoCD as part of the addon ecosystem. It will be automatically deployed when ArgoCD processes the `argo-cd-apps` configuration.

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metrics-server.replicas` | Number of Metrics Server replicas | `2` |
| `metrics-server.resources.requests.cpu` | CPU request | `10m` |
| `metrics-server.resources.requests.memory` | Memory request | `32Mi` |
| `metrics-server.resources.limits.cpu` | CPU limit | `100m` |
| `metrics-server.resources.limits.memory` | Memory limit | `128Mi` |

### High Availability Configuration

- **Replicas**: 2 instances for redundancy
- **Pod Disruption Budget**: Ensures at least 1 pod is always available
- **Anti-affinity**: Distributes pods across different nodes

### Development Environment Considerations

The configuration includes `--kubelet-insecure-tls` flag which may be required for development clusters where kubelet doesn't have properly signed certificates.

## Upgrading

```bash
cd ha/k8s/addons/metrics-server
make upgrade
```

## Uninstalling

```bash
cd ha/k8s/addons/metrics-server
make uninstall
```

## Verification

After installation, verify that Metrics Server is working:

```bash
# Check pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Test metrics collection
kubectl top nodes
kubectl top pods -A
```

## Troubleshooting

### Common Issues

1. **"no metrics known for node"**: Wait 1-2 minutes after installation for metrics collection to start
2. **TLS certificate errors**: The `--kubelet-insecure-tls` flag is included for development environments
3. **Resource constraints**: Adjust resource limits if needed in `values.yaml`

### Debugging Commands

```bash
# Check metrics-server logs
kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server

# Check metrics-server service
kubectl get svc -n kube-system metrics-server

# Test API endpoints
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods"
```

## Integration

Metrics Server enables:
- **HorizontalPodAutoscaler (HPA)**: CPU/Memory based autoscaling
- **VerticalPodAutoscaler (VPA)**: Resource recommendation and adjustment
- **kubectl top**: Resource usage commands
- **Dashboard**: Resource metrics in Kubernetes Dashboard
