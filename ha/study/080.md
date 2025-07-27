# 80. Реализация multi-tenancy с помощью namespaces в Kubernetes

## 🎯 **Реализация multi-tenancy с помощью namespaces в Kubernetes**

**Multi-tenancy** - это архитектурный подход, позволяющий нескольким арендаторам (tenants) безопасно использовать общую инфраструктуру Kubernetes. Namespaces служат основным механизмом изоляции для реализации multi-tenancy, обеспечивая логическое разделение ресурсов, сетевую изоляцию и контроль доступа.

## 🏗️ **Основные принципы multi-tenancy:**

### **Уровни изоляции:**
- **Namespace Isolation** - логическое разделение ресурсов
- **Network Isolation** - сетевая изоляция между tenants
- **Resource Isolation** - ограничение ресурсов для каждого tenant
- **Security Isolation** - RBAC и политики безопасности

### **Типы multi-tenancy:**
- **Soft Multi-tenancy** - доверенные tenants, базовая изоляция
- **Hard Multi-tenancy** - недоверенные tenants, строгая изоляция
- **Hybrid Multi-tenancy** - комбинированный подход

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей структуры namespaces:**
```bash
# Проверить существующие namespaces
kubectl get namespaces --show-labels

# Анализ ресурсов по namespaces
kubectl get all --all-namespaces
kubectl top nodes
kubectl top pods --all-namespaces
```

### **2. Создание comprehensive multi-tenancy framework:**
```bash
# Создать скрипт для реализации multi-tenancy
cat << 'EOF' > multi-tenancy-implementation.sh
#!/bin/bash

echo "=== Multi-Tenancy Implementation ==="
echo "Implementing comprehensive multi-tenancy in HashFoundry HA cluster"
echo

# Функция для создания tenant namespaces
create_tenant_namespaces() {
    local tenant_name="$1"
    local environment="$2"
    local tier="${3:-standard}"
    
    echo "=== Creating Tenant Namespaces for: $tenant_name ==="
    
    # Создать namespaces для разных сред
    for env in dev staging prod; do
        local namespace_name="${tenant_name}-${env}"
        
        echo "Creating namespace: $namespace_name"
        
        cat << NAMESPACE_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace_name
  labels:
    # Tenant identification
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/tier: "$tier"
    
    # Multi-tenancy labels
    multitenancy.hashfoundry.io/isolation-level: "namespace"
    multitenancy.hashfoundry.io/network-policy: "enabled"
    multitenancy.hashfoundry.io/resource-quota: "enabled"
    
    # Standard Kubernetes labels
    app.kubernetes.io/name: "hashfoundry-tenant"
    app.kubernetes.io/instance: "$tenant_name"
    app.kubernetes.io/component: "$env-environment"
    app.kubernetes.io/part-of: "hashfoundry-platform"
    app.kubernetes.io/managed-by: "hashfoundry-admin"
    
    # Environment-specific labels
    environment: "$env"
    tier: "$tier"
  annotations:
    # Tenant metadata
    tenant.hashfoundry.io/created-by: "hashfoundry-admin"
    tenant.hashfoundry.io/created-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    tenant.hashfoundry.io/contact: "$tenant_name-admin@hashfoundry.io"
    tenant.hashfoundry.io/description: "$tenant_name $env environment"
    
    # Resource management
    tenant.hashfoundry.io/resource-tier: "$tier"
    tenant.hashfoundry.io/backup-enabled: "true"
    tenant.hashfoundry.io/monitoring-enabled: "true"
    
    # Compliance and governance
    tenant.hashfoundry.io/compliance-level: "$([ "$env" = "prod" ] && echo "high" || echo "standard")"
    tenant.hashfoundry.io/data-classification: "$([ "$env" = "prod" ] && echo "confidential" || echo "internal")"
NAMESPACE_EOF
        
        echo "✅ Namespace $namespace_name created"
    done
    
    echo
}

# Функция для создания resource quotas
create_resource_quotas() {
    local tenant_name="$1"
    local tier="${2:-standard}"
    
    echo "=== Creating Resource Quotas for: $tenant_name ==="
    
    # Определить лимиты ресурсов по tier
    case "$tier" in
        "premium")
            cpu_limit="8"
            memory_limit="16Gi"
            storage_limit="100Gi"
            pod_limit="50"
            service_limit="20"
            ;;
        "standard")
            cpu_limit="4"
            memory_limit="8Gi"
            storage_limit="50Gi"
            pod_limit="25"
            service_limit="10"
            ;;
        "basic")
            cpu_limit="2"
            memory_limit="4Gi"
            storage_limit="20Gi"
            pod_limit="10"
            service_limit="5"
            ;;
        *)
            cpu_limit="2"
            memory_limit="4Gi"
            storage_limit="20Gi"
            pod_limit="10"
            service_limit="5"
            ;;
    esac
    
    for env in dev staging prod; do
        local namespace_name="${tenant_name}-${env}"
        
        # Adjust limits for environment
        local env_cpu_limit="$cpu_limit"
        local env_memory_limit="$memory_limit"
        local env_storage_limit="$storage_limit"
        
        if [ "$env" = "dev" ]; then
            env_cpu_limit=$(echo "$cpu_limit * 0.5" | bc)
            env_memory_limit=$(echo "$memory_limit" | sed 's/Gi//' | awk '{print $1*0.5"Gi"}')
            env_storage_limit=$(echo "$storage_limit" | sed 's/Gi//' | awk '{print $1*0.5"Gi"}')
        elif [ "$env" = "staging" ]; then
            env_cpu_limit=$(echo "$cpu_limit * 0.75" | bc)
            env_memory_limit=$(echo "$memory_limit" | sed 's/Gi//' | awk '{print $1*0.75"Gi"}')
            env_storage_limit=$(echo "$storage_limit" | sed 's/Gi//' | awk '{print $1*0.75"Gi"}')
        fi
        
        cat << QUOTA_EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${tenant_name}-${env}-quota
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/tier: "$tier"
    app.kubernetes.io/name: "hashfoundry-resource-quota"
  annotations:
    tenant.hashfoundry.io/description: "Resource quota for $tenant_name $env environment"
    tenant.hashfoundry.io/tier: "$tier"
spec:
  hard:
    # Compute resources
    requests.cpu: "${env_cpu_limit}"
    requests.memory: "${env_memory_limit}"
    limits.cpu: "$(echo "$env_cpu_limit * 2" | bc)"
    limits.memory: "$(echo "$env_memory_limit" | sed 's/Gi//' | awk '{print $1*2"Gi"}')"
    
    # Storage resources
    requests.storage: "${env_storage_limit}"
    persistentvolumeclaims: "$([ "$env" = "prod" ] && echo "10" || echo "5")"
    
    # Object counts
    pods: "$pod_limit"
    services: "$service_limit"
    secrets: "20"
    configmaps: "20"
    replicationcontrollers: "10"
    
    # Extended resources
    count/deployments.apps: "10"
    count/jobs.batch: "5"
    count/cronjobs.batch: "3"
    count/ingresses.networking.k8s.io: "5"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: ${tenant_name}-${env}-limits
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/tier: "$tier"
    app.kubernetes.io/name: "hashfoundry-limit-range"
  annotations:
    tenant.hashfoundry.io/description: "Resource limits for $tenant_name $env environment"
spec:
  limits:
  # Container limits
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
  
  # Pod limits
  - type: Pod
    max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
  
  # PVC limits
  - type: PersistentVolumeClaim
    max:
      storage: "10Gi"
    min:
      storage: "1Gi"
QUOTA_EOF
        
        echo "✅ Resource quota created for $namespace_name"
    done
    
    echo
}

# Функция для создания network policies
create_network_policies() {
    local tenant_name="$1"
    
    echo "=== Creating Network Policies for: $tenant_name ==="
    
    for env in dev staging prod; do
        local namespace_name="${tenant_name}-${env}"
        
        cat << NETPOL_EOF | kubectl apply -f -
# Default deny all ingress traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${tenant_name}-${env}-deny-all-ingress
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    tenant.hashfoundry.io/description: "Default deny all ingress for $tenant_name $env"
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
# Allow ingress from same namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${tenant_name}-${env}-allow-same-namespace
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    tenant.hashfoundry.io/description: "Allow traffic within $tenant_name $env namespace"
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant.hashfoundry.io/name: "$tenant_name"
          tenant.hashfoundry.io/environment: "$env"
---
# Allow ingress from ingress controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${tenant_name}-${env}-allow-ingress-controller
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    tenant.hashfoundry.io/description: "Allow traffic from ingress controller to $tenant_name $env"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "web"
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: "nginx-ingress"
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
---
# Allow egress to DNS and external services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${tenant_name}-${env}-allow-dns-egress
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    tenant.hashfoundry.io/description: "Allow DNS and external egress for $tenant_name $env"
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # Allow HTTPS to external services
  - to: []
    ports:
    - protocol: TCP
      port: 443
  # Allow HTTP to external services (if needed)
  - to: []
    ports:
    - protocol: TCP
      port: 80
NETPOL_EOF
        
        echo "✅ Network policies created for $namespace_name"
    done
    
    echo
}

# Функция для создания RBAC для tenant
create_tenant_rbac() {
    local tenant_name="$1"
    
    echo "=== Creating RBAC for Tenant: $tenant_name ==="
    
    # Создать ServiceAccounts для tenant
    for env in dev staging prod; do
        local namespace_name="${tenant_name}-${env}"
        
        cat << SA_EOF | kubectl apply -f -
# Tenant admin ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${tenant_name}-admin
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "admin"
    app.kubernetes.io/name: "hashfoundry-tenant-sa"
  annotations:
    tenant.hashfoundry.io/description: "Admin ServiceAccount for $tenant_name $env"
---
# Tenant developer ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${tenant_name}-developer
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "developer"
    app.kubernetes.io/name: "hashfoundry-tenant-sa"
  annotations:
    tenant.hashfoundry.io/description: "Developer ServiceAccount for $tenant_name $env"
---
# Tenant viewer ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${tenant_name}-viewer
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "viewer"
    app.kubernetes.io/name: "hashfoundry-tenant-sa"
  annotations:
    tenant.hashfoundry.io/description: "Viewer ServiceAccount for $tenant_name $env"
SA_EOF
    done
    
    # Создать роли для tenant
    for env in dev staging prod; do
        local namespace_name="${tenant_name}-${env}"
        
        cat << ROLE_EOF | kubectl apply -f -
# Tenant admin role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace_name
  name: ${tenant_name}-admin-role
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "admin"
    app.kubernetes.io/name: "hashfoundry-tenant-rbac"
  annotations:
    tenant.hashfoundry.io/description: "Admin role for $tenant_name $env environment"
rules:
# Full access to namespace resources
- apiGroups: ["", "apps", "batch", "networking.k8s.io"]
  resources: ["*"]
  verbs: ["*"]
# Resource quota and limit range access
- apiGroups: [""]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch"]
# Network policy management
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Tenant developer role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace_name
  name: ${tenant_name}-developer-role
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "developer"
    app.kubernetes.io/name: "hashfoundry-tenant-rbac"
  annotations:
    tenant.hashfoundry.io/description: "Developer role for $tenant_name $env environment"
rules:
# Application resources
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "services", "deployments", "jobs", "cronjobs", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Limited secret access
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
# Events and logs
- apiGroups: [""]
  resources: ["events", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create"]
# Ingress management
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Tenant viewer role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace_name
  name: ${tenant_name}-viewer-role
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "viewer"
    app.kubernetes.io/name: "hashfoundry-tenant-rbac"
  annotations:
    tenant.hashfoundry.io/description: "Viewer role for $tenant_name $env environment"
rules:
# Read-only access to most resources
- apiGroups: ["", "apps", "batch", "networking.k8s.io"]
  resources: ["pods", "services", "deployments", "jobs", "cronjobs", "configmaps", "ingresses"]
  verbs: ["get", "list", "watch"]
# Events and logs
- apiGroups: [""]
  resources: ["events", "pods/log"]
  verbs: ["get", "list", "watch"]
# Resource quotas
- apiGroups: [""]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch"]
ROLE_EOF
        
        # Создать RoleBindings
        cat << BINDING_EOF | kubectl apply -f -
# Admin RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${tenant_name}-admin-binding
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "admin"
    app.kubernetes.io/name: "hashfoundry-tenant-rbac"
subjects:
- kind: ServiceAccount
  name: ${tenant_name}-admin
  namespace: $namespace_name
roleRef:
  kind: Role
  name: ${tenant_name}-admin-role
  apiGroup: rbac.authorization.k8s.io
---
# Developer RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${tenant_name}-developer-binding
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "developer"
    app.kubernetes.io/name: "hashfoundry-tenant-rbac"
subjects:
- kind: ServiceAccount
  name: ${tenant_name}-developer
  namespace: $namespace_name
roleRef:
  kind: Role
  name: ${tenant_name}-developer-role
  apiGroup: rbac.authorization.k8s.io
---
# Viewer RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${tenant_name}-viewer-binding
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    tenant.hashfoundry.io/role: "viewer"
    app.kubernetes.io/name: "hashfoundry-tenant-rbac"
subjects:
- kind: ServiceAccount
  name: ${tenant_name}-viewer
  namespace: $namespace_name
roleRef:
  kind: Role
  name: ${tenant_name}-viewer-role
  apiGroup: rbac.authorization.k8s.io
BINDING_EOF
        
        echo "✅ RBAC created for $namespace_name"
    done
    
    echo
}

# Функция для создания monitoring и observability
create_tenant_monitoring() {
    local tenant_name="$1"
    
    echo "=== Creating Monitoring for Tenant: $tenant_name ==="
    
    for env in dev staging prod; do
        local namespace_name="${tenant_name}-${env}"
        
        cat << MONITORING_EOF | kubectl apply -f -
# ServiceMonitor for tenant applications
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ${tenant_name}-${env}-monitor
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    app.kubernetes.io/name: "hashfoundry-tenant-monitoring"
  annotations:
    tenant.hashfoundry.io/description: "Service monitor for $tenant_name $env applications"
spec:
  selector:
    matchLabels:
      tenant.hashfoundry.io/name: "$tenant_name"
      tenant.hashfoundry.io/environment: "$env"
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
# PrometheusRule for tenant alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ${tenant_name}-${env}-alerts
  namespace: $namespace_name
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    app.kubernetes.io/name: "hashfoundry-tenant-monitoring"
  annotations:
    tenant.hashfoundry.io/description: "Alert rules for $tenant_name $env environment"
spec:
  groups:
  - name: ${tenant_name}-${env}-alerts
    rules:
    - alert: TenantHighCPUUsage
      expr: |
        (
          sum(rate(container_cpu_usage_seconds_total{namespace="$namespace_name"}[5m])) /
          sum(kube_resourcequota{namespace="$namespace_name", resource="requests.cpu"})
        ) * 100 > 80
      for: 5m
      labels:
        severity: warning
        tenant: "$tenant_name"
        environment: "$env"
      annotations:
        summary: "High CPU usage in $tenant_name $env"
        description: "CPU usage is above 80% of quota in namespace $namespace_name"
    
    - alert: TenantHighMemoryUsage
      expr: |
        (
          sum(container_memory_usage_bytes{namespace="$namespace_name"}) /
          sum(kube_resourcequota{namespace="$namespace_name", resource="requests.memory"})
        ) * 100 > 80
      for: 5m
      labels:
        severity: warning
        tenant: "$tenant_name"
        environment: "$env"
      annotations:
        summary: "High memory usage in $tenant_name $env"
        description: "Memory usage is above 80% of quota in namespace $namespace_name"
    
    - alert: TenantPodCrashLooping
      expr: |
        rate(kube_pod_container_status_restarts_total{namespace="$namespace_name"}[15m]) > 0
      for: 5m
      labels:
        severity: critical
        tenant: "$tenant_name"
        environment: "$env"
      annotations:
        summary: "Pod crash looping in $tenant_name $env"
        description: "Pod {{ \$labels.pod }} is crash looping in namespace $namespace_name"
MONITORING_EOF
        
        echo "✅ Monitoring created for $namespace_name"
    done
    
    echo
}

# Функция для создания backup policies
create_tenant_backup() {
    local tenant_name="$1"
    
    echo "=== Creating Backup Policies for Tenant: $tenant_name ==="
    
    for env in dev staging prod; do
        local namespace_name="${tenant_name}-${env}"
        
        # Определить backup schedule по environment
        local backup_schedule
        case "$env" in
            "prod")
                backup_schedule="0 2 * * *"  # Daily at 2 AM
                ;;
            "staging")
                backup_schedule="0 3 * * 0"  # Weekly on Sunday at 3 AM
                ;;
            "dev")
                backup_schedule="0 4 * * 0"  # Weekly on Sunday at 4 AM
                ;;
        esac
        
        cat << BACKUP_EOF | kubectl apply -f -
# Backup schedule for tenant
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: ${tenant_name}-${env}-backup
  namespace: velero
  labels:
    tenant.hashfoundry.io/name: "$tenant_name"
    tenant.hashfoundry.io/environment: "$env"
    app.kubernetes.io/name: "hashfoundry-tenant-backup"
  annotations:
    tenant.hashfoundry.io/description: "Backup schedule for $tenant_name $env environment"
spec:
  schedule: "$backup_schedule"
  template:
    includedNamespaces:
    - $namespace_name
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    ttl: 720h0m0s  # 30 days
    metadata:
      labels:
        tenant.hashfoundry.io/name: "$tenant_name"
        tenant.hashfoundry.io/environment: "$env"
BACKUP_EOF
        
        echo "✅ Backup policy created for $namespace_name"
    done
    
    echo
}

# Функция для создания полного tenant
create_complete_tenant() {
    local tenant_name="$1"
    local tier="${2:-standard}"
    
    echo "=== Creating Complete Tenant: $tenant_name (tier: $tier) ==="
    
    # Создать все компоненты tenant
    create_tenant_namespaces "$tenant_name" "all" "$tier"
    create_resource_quotas "$tenant_name" "$tier"
    create_network_policies "$tenant_name"
    create_tenant_rbac "$tenant_name"
    create_tenant_monitoring "$tenant_name"
    create_tenant_backup "$tenant_name"
    
    echo "✅ Complete tenant $tenant_name created successfully!"
    echo
}

# Функция для управления tenant
manage_tenant() {
    local action="$1"
    local tenant_name="$2"
    local tier="$3"
    
    case "$action" in
        "create")
            create_complete_tenant "$tenant_name" "$tier"
            ;;
        "delete")
            echo "=== Deleting Tenant: $tenant_name ==="
            for env in dev staging prod; do
                local namespace_name="${tenant_name}-${env}"
                echo "Deleting namespace: $namespace_name"
                kubectl delete namespace "$namespace_name" --ignore-not-found=true
            done
            # Delete backup schedules
            kubectl delete schedule -n velero -l tenant.hashfoundry.io/name="$tenant_name" --ignore-not-found=true
            echo "✅ Tenant $tenant_name deleted"
            ;;
        "status")
            echo "=== Tenant Status: $tenant_name ==="
            for env in dev staging prod; do
                local namespace_name="${tenant_name}-${env}"
                if kubectl get namespace "$namespace_name" >/dev/null 2>&1; then
                    echo "Environment: $env"
                    echo "  Namespace: ✅ $namespace_name"
                    echo "  Pods: $(kubectl get pods -n "$namespace_name" --no-headers 2>/dev/null | wc -l)"
                    echo "  Services: $(kubectl get services -n "$namespace_name" --no-headers 2>/dev/null | wc -l)"
                    echo "  Resource Quota:"
                    kubectl get resourcequota -n "$namespace_name" -o custom-columns="NAME:.metadata.name,CPU:.status.used.requests\.cpu,MEMORY:.status.used.requests\.memory" --no-headers 2>/dev/null | sed 's/^/    /'
                    echo
                fi
            done
            ;;
        "list")
            echo "=== All Tenants ==="
            kubectl get namespaces -l tenant.hashfoundry.io/name -o custom-columns="TENANT:.metadata.labels.tenant\.hashfoundry\.io/name,ENVIRONMENT:.metadata.labels.tenant\.hashfoundry\.io/environment,TIER:.metadata.labels.tenant\.hashfoundry\.io/tier,AGE:.metadata.creationTimestamp"
            ;;
        *)
            echo "Usage: manage_tenant <action> <tenant_name> [tier]"
            echo "Actions: create, delete, status, list"
            ;;
    esac
}

# Основная функция
main() {
    case "$1" in
        "create")
            create_complete_tenant "$2" "$3"
            ;;
        "manage")
            manage_tenant "$2" "$3" "$4"
            ;;
        "demo")
            echo "=== Creating Demo Tenants ==="
            create_complete_tenant "acme-corp" "premium"
            create_complete_tenant "startup-inc" "standard"
            create_complete_tenant "small-biz" "basic"
            ;;
        *)
            echo "Usage: $0 [action] [params...]"
            echo ""
            echo "Actions:"
            echo "  create <tenant> [tier]     - Create complete tenant"
            echo "  manage <action> <tenant>   - Manage tenant (create/delete/status/list)"
            echo "  demo                       - Create demo tenants"
            echo ""
            echo "Examples:"
            echo "  $0 create my-company premium"
            echo "  $0 manage status my-company"
            echo "  $0 demo"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x multi-tenancy-implementation.sh

# Запустить демонстрацию multi-tenancy
./multi-tenancy-implementation.sh demo
```

## 📋 **Основные компоненты multi-tenancy:**

### **1. Namespace Isolation:**
```bash
# Создание tenant namespace с метаданными
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-prod
  labels:
    tenant.hashfoundry.io/name: "tenant"
    tenant.hashfoundry.io/environment: "prod"
    tenant.hashfoundry.io/tier: "premium"
  annotations:
    tenant.hashfoundry.io/contact: "tenant-admin@company.com"
```

### **2. Resource Quotas:**
```bash
# Ограничение ресурсов для tenant
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    pods: "25"
    services: "10"
```

### **3. Network Policies:**
```bash
# Изоляция сетевого трафика
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## 🎯 **Практические команды:**

### **Управление tenants:**
```bash
# Создать tenant
./multi-tenancy-implementation.sh create my-company premium

# Проверить статус tenant
./multi-tenancy-implementation.sh manage status my-company

# Список всех tenants
./multi-tenancy-implementation.sh manage list

# Удалить tenant
./multi-tenancy-implementation.sh manage delete my-company
```

### **Мониторинг multi-tenancy:**
```bash
# Проверить использование ресурсов по tenants
kubectl get resourcequotas --all-namespaces -l tenant.hashfoundry.io/name

# Анализ network policies
kubectl get networkpolicies --all-namespaces -l tenant.hashfoundry.io/name

# Проверить RBAC для tenants
kubectl get rolebindings --all-namespaces -l tenant.hashfoundry.io/name
```

## 🔧 **Best Practices для Multi-tenancy:**

### **Безопасность:**
- **Строгая изоляция** - использовать network policies
- **Принцип минимальных привилегий** - ограниченные RBAC права
- **Регулярный аудит** - проверка прав доступа
- **Мониторинг активности** - отслеживание действий tenants

### **Управление ресурсами:**
- **Resource quotas** - ограничение потребления ресурсов
- **Limit ranges** - контроль размеров контейнеров
- **Tier-based allocation** - разные уровни ресурсов
- **Fair sharing** - справедливое распределение

### **Операционные процессы:**
- **Автоматизация** - скрипты для управления tenants
- **Стандартизация** - единые шаблоны и политики
- **Мониторинг** - отслеживание здоровья tenants
- **Backup и recovery** - защита данных tenants

**Multi-tenancy с namespaces обеспечивает эффективное и безопасное разделение ресурсов в Kubernetes!**
