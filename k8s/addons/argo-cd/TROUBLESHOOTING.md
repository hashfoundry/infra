# ArgoCD Troubleshooting Guide

## Common Issues and Solutions

### 1. Pods Stuck in Pending Status

#### Problem: Redis HA pods stuck in Pending due to anti-affinity rules

**Symptoms:**
```bash
kubectl get pods -n argocd | grep Pending
# Output shows pods like:
# argocd-redis-ha-haproxy-xxx  0/1  Pending
# argocd-redis-ha-server-xxx   0/3  Pending
```

**Root Cause:**
- Single-node cluster with strict anti-affinity rules
- Old ReplicaSets with outdated configurations
- Multiple ReplicaSets competing for scheduling

**Solution Steps:**

1. **Check pod details:**
```bash
kubectl describe pod <pending-pod-name> -n argocd
# Look for "FailedScheduling" events mentioning anti-affinity rules
```

2. **List and clean old ReplicaSets:**
```bash
# List all ReplicaSets
kubectl get replicasets -n argocd | grep redis-ha

# Delete old ReplicaSets (keep only current ones)
kubectl delete replicaset <old-replicaset-name> -n argocd
```

3. **Scale deployment to correct replicas:**
```bash
# For single-node clusters
kubectl scale deployment argocd-redis-ha-haproxy -n argocd --replicas=1
kubectl scale statefulset argocd-redis-ha-server -n argocd --replicas=1
```

4. **Force delete stuck pods:**
```bash
kubectl delete pod <pending-pod-name> -n argocd --force --grace-period=0
```

### 2. Configuration Updates Not Applied

#### Problem: Helm upgrade doesn't apply new anti-affinity settings

**Solution:**
1. **Manual patch deployment:**
```bash
# Remove strict anti-affinity rules
kubectl patch deployment argocd-redis-ha-haproxy -n argocd --type='json' \
  -p='[{"op": "remove", "path": "/spec/template/spec/affinity/podAntiAffinity/requiredDuringSchedulingIgnoredDuringExecution"}]'

# Add preferred anti-affinity rules
kubectl patch deployment argocd-redis-ha-haproxy -n argocd --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/affinity/podAntiAffinity/preferredDuringSchedulingIgnoredDuringExecution", "value": [{"weight": 100, "podAffinityTerm": {"labelSelector": {"matchLabels": {"app": "redis-ha-haproxy", "release": "argocd"}}, "topologyKey": "kubernetes.io/hostname"}}]}]'
```

2. **Restart deployment:**
```bash
kubectl rollout restart deployment argocd-redis-ha-haproxy -n argocd
```

### 3. Multiple Pending Pods After Changes

#### Problem: New pods keep appearing in Pending status

**Root Cause:** Old ReplicaSets are not cleaned up automatically

**Solution:**
```bash
# Get all ReplicaSets for HAProxy
kubectl get rs -n argocd -l app=redis-ha-haproxy

# Delete all old ReplicaSets (keep only the one with desired replicas)
kubectl get rs -n argocd -l app=redis-ha-haproxy -o name | \
  grep -v $(kubectl get deployment argocd-redis-ha-haproxy -n argocd -o jsonpath='{.metadata.labels.pod-template-hash}') | \
  xargs kubectl delete -n argocd

# Force scale to 1 replica
kubectl scale deployment argocd-redis-ha-haproxy -n argocd --replicas=1
```

## Prevention

### 1. Proper Configuration for Single-Node Clusters

Update `values.yaml`:
```yaml
redis-ha:
  replicas: 1
  haproxy:
    replicas: 1
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: redis-ha-haproxy
                release: argocd
            topologyKey: kubernetes.io/hostname
```

### 2. Environment-Specific Configurations

Create environment-specific overrides:

**values.dev.yaml** (single-node):
```yaml
argo-cd:
  redis-ha:
    replicas: 1
    haproxy:
      replicas: 1
```

**values.prod.yaml** (multi-node):
```yaml
argo-cd:
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

## Monitoring Commands

### Check Overall Status
```bash
# Get all pods status
kubectl get pods -n argocd

# Get deployment status
kubectl get deployments -n argocd

# Get ReplicaSet status
kubectl get rs -n argocd
```

### Debug Specific Issues
```bash
# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs <pod-name> -n argocd

# Check deployment configuration
kubectl get deployment argocd-redis-ha-haproxy -n argocd -o yaml
```

## Emergency Recovery

If ArgoCD becomes completely unresponsive:

1. **Scale down problematic components:**
```bash
kubectl scale deployment argocd-redis-ha-haproxy -n argocd --replicas=0
kubectl scale statefulset argocd-redis-ha-server -n argocd --replicas=0
```

2. **Clean up all ReplicaSets:**
```bash
kubectl delete rs -n argocd -l app=redis-ha-haproxy
kubectl delete rs -n argocd -l app=redis-ha
```

3. **Scale back up:**
```bash
kubectl scale statefulset argocd-redis-ha-server -n argocd --replicas=1
kubectl scale deployment argocd-redis-ha-haproxy -n argocd --replicas=1
```

4. **Verify recovery:**
```bash
kubectl get pods -n argocd
kubectl logs -f deployment/argocd-server -n argocd
