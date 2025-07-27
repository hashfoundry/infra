# 87. Управление ресурсами в Kubernetes

## 🎯 **Управление ресурсами в Kubernetes**

**Resource Management** - это критически важный аспект управления Kubernetes кластером, включающий планирование, распределение, мониторинг и оптимизацию вычислительных ресурсов (CPU, память, хранилище) для обеспечения эффективной работы приложений.

## 🏗️ **Типы ресурсов:**

### **1. Compute Resources:**
- **CPU** - процессорное время
- **Memory** - оперативная память
- **Ephemeral Storage** - временное хранилище
- **Extended Resources** - кастомные ресурсы (GPU, FPGA)

### **2. Resource Specifications:**
- **Requests** - минимальные требования
- **Limits** - максимальные ограничения
- **Quality of Service** - классы обслуживания
- **Resource Quotas** - квоты на namespace

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущего использования ресурсов:**
```bash
# Проверить использование ресурсов узлов
kubectl top nodes

# Проверить использование ресурсов pods
kubectl top pods --all-namespaces
```

### **2. Создание comprehensive resource management framework:**
```bash
# Создать скрипт для управления ресурсами
cat << 'EOF' > resource-management-implementation.sh
#!/bin/bash

echo "=== Kubernetes Resource Management Implementation ==="
echo "Implementing comprehensive resource management for HashFoundry HA cluster"
echo

# Функция для анализа текущего использования ресурсов
analyze_current_resource_usage() {
    echo "=== Current Resource Usage Analysis ==="
    
    echo "1. Node Resource Usage:"
    echo "======================"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "2. Pod Resource Usage (Top 20):"
    echo "==============================="
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -20 || echo "Metrics server not available"
    echo
    
    echo "3. Resource Requests vs Limits:"
    echo "==============================="
    kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-REQ:.spec.containers[*].resources.requests.cpu,CPU-LIM:.spec.containers[*].resources.limits.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory,MEM-LIM:.spec.containers[*].resources.limits.memory" | head -20
    echo
    
    echo "4. Pods without Resource Specifications:"
    echo "========================================"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].resources.requests == null or .spec.containers[].resources.limits == null) | "\(.metadata.namespace)/\(.metadata.name): Missing resource specs"' | head -10
    echo
}

# Функция для создания resource quotas
create_resource_quotas() {
    echo "=== Creating Resource Quotas ==="
    
    # Создать namespace для production
    cat << PROD_NAMESPACE_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-prod
  labels:
    app.kubernetes.io/name: "hashfoundry-production"
    hashfoundry.io/environment: "production"
    hashfoundry.io/tier: "critical"
  annotations:
    hashfoundry.io/description: "Production environment for HashFoundry applications"
PROD_NAMESPACE_EOF
    
    # Создать resource quota для production
    cat << PROD_QUOTA_EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: hashfoundry-prod
  labels:
    app.kubernetes.io/name: "hashfoundry-resource-quota"
    hashfoundry.io/environment: "production"
  annotations:
    hashfoundry.io/description: "Resource quota for production environment"
spec:
  hard:
    # Compute resources
    requests.cpu: "8"
    requests.memory: "16Gi"
    limits.cpu: "16"
    limits.memory: "32Gi"
    
    # Storage resources
    requests.storage: "100Gi"
    persistentvolumeclaims: "10"
    
    # Object counts
    pods: "50"
    services: "20"
    secrets: "30"
    configmaps: "30"
    replicationcontrollers: "10"
    
    # Extended resources
    count/deployments.apps: "20"
    count/statefulsets.apps: "10"
    count/jobs.batch: "5"
PROD_QUOTA_EOF
    
    # Создать namespace для staging
    cat << STAGING_NAMESPACE_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-staging
  labels:
    app.kubernetes.io/name: "hashfoundry-staging"
    hashfoundry.io/environment: "staging"
    hashfoundry.io/tier: "non-critical"
  annotations:
    hashfoundry.io/description: "Staging environment for HashFoundry applications"
STAGING_NAMESPACE_EOF
    
    # Создать resource quota для staging
    cat << STAGING_QUOTA_EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: hashfoundry-staging
  labels:
    app.kubernetes.io/name: "hashfoundry-resource-quota"
    hashfoundry.io/environment: "staging"
  annotations:
    hashfoundry.io/description: "Resource quota for staging environment"
spec:
  hard:
    # Compute resources (smaller than production)
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    
    # Storage resources
    requests.storage: "50Gi"
    persistentvolumeclaims: "5"
    
    # Object counts
    pods: "25"
    services: "10"
    secrets: "15"
    configmaps: "15"
    replicationcontrollers: "5"
    
    # Extended resources
    count/deployments.apps: "10"
    count/statefulsets.apps: "5"
    count/jobs.batch: "3"
STAGING_QUOTA_EOF
    
    echo "✅ Resource quotas created for production and staging"
    echo
}

# Функция для создания limit ranges
create_limit_ranges() {
    echo "=== Creating Limit Ranges ==="
    
    # Limit range для production
    cat << PROD_LIMIT_RANGE_EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: hashfoundry-prod
  labels:
    app.kubernetes.io/name: "hashfoundry-limit-range"
    hashfoundry.io/environment: "production"
  annotations:
    hashfoundry.io/description: "Resource limits for production environment"
spec:
  limits:
  # Container limits
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
      ephemeral-storage: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
      ephemeral-storage: "100Mi"
    max:
      cpu: "2"
      memory: "4Gi"
      ephemeral-storage: "10Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
      ephemeral-storage: "50Mi"
  
  # Pod limits
  - type: Pod
    max:
      cpu: "4"
      memory: "8Gi"
      ephemeral-storage: "20Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
      ephemeral-storage: "100Mi"
  
  # PVC limits
  - type: PersistentVolumeClaim
    max:
      storage: "50Gi"
    min:
      storage: "1Gi"
PROD_LIMIT_RANGE_EOF
    
    # Limit range для staging
    cat << STAGING_LIMIT_RANGE_EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: staging-limits
  namespace: hashfoundry-staging
  labels:
    app.kubernetes.io/name: "hashfoundry-limit-range"
    hashfoundry.io/environment: "staging"
  annotations:
    hashfoundry.io/description: "Resource limits for staging environment"
spec:
  limits:
  # Container limits (smaller than production)
  - type: Container
    default:
      cpu: "200m"
      memory: "256Mi"
      ephemeral-storage: "500Mi"
    defaultRequest:
      cpu: "50m"
      memory: "64Mi"
      ephemeral-storage: "50Mi"
    max:
      cpu: "1"
      memory: "2Gi"
      ephemeral-storage: "5Gi"
    min:
      cpu: "25m"
      memory: "32Mi"
      ephemeral-storage: "25Mi"
  
  # Pod limits
  - type: Pod
    max:
      cpu: "2"
      memory: "4Gi"
      ephemeral-storage: "10Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
      ephemeral-storage: "50Mi"
  
  # PVC limits
  - type: PersistentVolumeClaim
    max:
      storage: "20Gi"
    min:
      storage: "500Mi"
STAGING_LIMIT_RANGE_EOF
    
    echo "✅ Limit ranges created for production and staging"
    echo
}

# Функция для создания priority classes
create_priority_classes() {
    echo "=== Creating Priority Classes ==="
    
    # Critical priority class
    cat << CRITICAL_PRIORITY_EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: hashfoundry-critical
  labels:
    app.kubernetes.io/name: "hashfoundry-priority-class"
    hashfoundry.io/priority: "critical"
  annotations:
    hashfoundry.io/description: "Critical priority for system components"
value: 1000000
globalDefault: false
description: "Critical priority class for HashFoundry system components"
CRITICAL_PRIORITY_EOF
    
    # High priority class
    cat << HIGH_PRIORITY_EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: hashfoundry-high
  labels:
    app.kubernetes.io/name: "hashfoundry-priority-class"
    hashfoundry.io/priority: "high"
  annotations:
    hashfoundry.io/description: "High priority for production applications"
value: 100000
globalDefault: false
description: "High priority class for HashFoundry production applications"
HIGH_PRIORITY_EOF
    
    # Normal priority class
    cat << NORMAL_PRIORITY_EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: hashfoundry-normal
  labels:
    app.kubernetes.io/name: "hashfoundry-priority-class"
    hashfoundry.io/priority: "normal"
  annotations:
    hashfoundry.io/description: "Normal priority for regular applications"
value: 10000
globalDefault: true
description: "Normal priority class for HashFoundry regular applications"
NORMAL_PRIORITY_EOF
    
    # Low priority class
    cat << LOW_PRIORITY_EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: hashfoundry-low
  labels:
    app.kubernetes.io/name: "hashfoundry-priority-class"
    hashfoundry.io/priority: "low"
  annotations:
    hashfoundry.io/description: "Low priority for batch jobs and testing"
value: 1000
globalDefault: false
description: "Low priority class for HashFoundry batch jobs and testing"
LOW_PRIORITY_EOF
    
    echo "✅ Priority classes created"
    echo
}

# Функция для создания example applications с правильными resource specs
create_example_applications() {
    echo "=== Creating Example Applications with Resource Management ==="
    
    # Production application example
    cat << PROD_APP_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-api-prod
  namespace: hashfoundry-prod
  labels:
    app.kubernetes.io/name: "hashfoundry-api"
    app.kubernetes.io/component: "backend"
    app.kubernetes.io/version: "v1.0.0"
    hashfoundry.io/environment: "production"
    hashfoundry.io/tier: "critical"
  annotations:
    hashfoundry.io/description: "Production API service with proper resource management"
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: "hashfoundry-api"
      hashfoundry.io/environment: "production"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "hashfoundry-api"
        app.kubernetes.io/component: "backend"
        hashfoundry.io/environment: "production"
        hashfoundry.io/tier: "critical"
    spec:
      priorityClassName: hashfoundry-high
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: api
        image: nginx:1.21
        ports:
        - containerPort: 8080
          name: http
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
            ephemeral-storage: "100Mi"
          limits:
            cpu: "1"
            memory: "1Gi"
            ephemeral-storage: "1Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache/nginx
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "info"
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - hashfoundry-api
              topologyKey: kubernetes.io/hostname
PROD_APP_EOF
    
    # Staging application example
    cat << STAGING_APP_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-api-staging
  namespace: hashfoundry-staging
  labels:
    app.kubernetes.io/name: "hashfoundry-api"
    app.kubernetes.io/component: "backend"
    app.kubernetes.io/version: "v1.0.0-staging"
    hashfoundry.io/environment: "staging"
    hashfoundry.io/tier: "non-critical"
  annotations:
    hashfoundry.io/description: "Staging API service with resource management"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "hashfoundry-api"
      hashfoundry.io/environment: "staging"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "hashfoundry-api"
        app.kubernetes.io/component: "backend"
        hashfoundry.io/environment: "staging"
        hashfoundry.io/tier: "non-critical"
    spec:
      priorityClassName: hashfoundry-normal
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: api
        image: nginx:1.21
        ports:
        - containerPort: 8080
          name: http
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
            ephemeral-storage: "50Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
            ephemeral-storage: "500Mi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        env:
        - name: ENVIRONMENT
          value: "staging"
        - name: LOG_LEVEL
          value: "debug"
      volumes:
      - name: tmp
        emptyDir: {}
STAGING_APP_EOF
    
    echo "✅ Example applications created with proper resource management"
    echo
}

# Функция для создания HPA (Horizontal Pod Autoscaler)
create_hpa() {
    echo "=== Creating Horizontal Pod Autoscalers ==="
    
    # HPA для production
    cat << PROD_HPA_EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hashfoundry-api-prod-hpa
  namespace: hashfoundry-prod
  labels:
    app.kubernetes.io/name: "hashfoundry-api-hpa"
    hashfoundry.io/environment: "production"
  annotations:
    hashfoundry.io/description: "HPA for production API service"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hashfoundry-api-prod
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
PROD_HPA_EOF
    
    # HPA для staging
    cat << STAGING_HPA_EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hashfoundry-api-staging-hpa
  namespace: hashfoundry-staging
  labels:
    app.kubernetes.io/name: "hashfoundry-api-hpa"
    hashfoundry.io/environment: "staging"
  annotations:
    hashfoundry.io/description: "HPA for staging API service"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hashfoundry-api-staging
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 75
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 85
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 20
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
STAGING_HPA_EOF
    
    echo "✅ Horizontal Pod Autoscalers created"
    echo
}

# Функция для создания мониторинга ресурсов
create_resource_monitoring() {
    echo "=== Creating Resource Monitoring ==="
    
    cat << RESOURCE_MONITORING_EOF > resource-monitoring.sh
#!/bin/bash

echo "=== Resource Monitoring Dashboard ==="
echo "Monitoring resource usage in HashFoundry HA cluster"
echo

# Функция для проверки resource quotas
check_resource_quotas() {
    echo "1. Resource Quotas Status:"
    echo "========================="
    
    for namespace in hashfoundry-prod hashfoundry-staging; do
        if kubectl get namespace "\$namespace" >/dev/null 2>&1; then
            echo "Namespace: \$namespace"
            kubectl get resourcequota -n "\$namespace" -o custom-columns="NAME:.metadata.name,CPU-REQ:.status.used.requests\.cpu,CPU-LIM:.status.used.limits\.cpu,MEM-REQ:.status.used.requests\.memory,MEM-LIM:.status.used.limits\.memory,PODS:.status.used.pods"
            echo
        fi
    done
}

# Функция для проверки HPA status
check_hpa_status() {
    echo "2. Horizontal Pod Autoscaler Status:"
    echo "==================================="
    
    kubectl get hpa --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REFERENCE:.spec.scaleTargetRef.name,TARGETS:.status.currentMetrics[*].resource.current.averageUtilization,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,REPLICAS:.status.currentReplicas"
    echo
}

# Функция для проверки top consumers
check_top_consumers() {
    echo "3. Top Resource Consumers:"
    echo "========================="
    
    echo "Top CPU consumers:"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
    
    echo "Top Memory consumers:"
    kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
}

# Функция для проверки resource efficiency
check_resource_efficiency() {
    echo "4. Resource Efficiency Analysis:"
    echo "==============================="
    
    # Pods без resource requests
    echo "Pods without resource requests:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].resources.requests == null) | "\(.metadata.namespace)/\(.metadata.name): No requests"' | head -10
    echo
    
    # Pods без resource limits
    echo "Pods without resource limits:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].resources.limits == null) | "\(.metadata.namespace)/\(.metadata.name): No limits"' | head -10
    echo
    
    # QoS classes distribution
    echo "QoS Classes Distribution:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | "\(.status.qosClass // "Unknown")"' | sort | uniq -c
    echo
}

# Функция для проверки node capacity
check_node_capacity() {
    echo "5. Node Capacity and Allocation:"
    echo "==============================="
    
    kubectl describe nodes | grep -A 5 "Allocated resources:" | head -30
    echo
}

# Функция для генерации отчета
generate_resource_report() {
    echo "6. Resource Management Report:"
    echo "============================="
    
    echo "✅ RESOURCE QUOTAS:"
    kubectl get resourcequota --all-namespaces --no-headers | wc -l | xargs echo "- Total quotas:"
    
    echo "✅ LIMIT RANGES:"
    kubectl get limitrange --all-namespaces --no-headers | wc -l | xargs echo "- Total limit ranges:"
    
    echo "✅ PRIORITY CLASSES:"
    kubectl get priorityclass --no-headers | wc -l | xargs echo "- Total priority classes:"
    
    echo "✅ HORIZONTAL POD AUTOSCALERS:"
    kubectl get hpa --all-namespaces --no-headers | wc -l | xargs echo "- Total HPAs:"
    
    echo
    echo "🔧 RECOMMENDATIONS:"
    echo "1. Ensure all pods have resource requests and limits"
    echo "2. Monitor resource utilization and adjust quotas"
    echo "3. Use appropriate QoS classes for workloads"
    echo "4. Implement HPA for scalable applications"
    echo "5. Regular review of resource allocation efficiency"
    echo
}

# Main execution
case "\$1" in
    "quotas")
        check_resource_quotas
        ;;
    "hpa")
        check_hpa_status
        ;;
    "consumers")
        check_top_consumers
        ;;
    "efficiency")
        check_resource_efficiency
        ;;
    "capacity")
        check_node_capacity
        ;;
    "report")
        generate_resource_report
        ;;
    "all"|"")
        check_resource_quotas
        check_hpa_status
        check_top_consumers
        check_resource_efficiency
        check_node_capacity
        generate_resource_report
        ;;
    *)
        echo "Usage: \$0 [quotas|hpa|consumers|efficiency|capacity|report|all]"
        echo ""
        echo "Options:"
        echo "  quotas      - Check resource quotas"
        echo "  hpa         - Check HPA status"
        echo "  consumers   - Check top resource consumers"
        echo "  efficiency  - Check resource efficiency"
        echo "  capacity    - Check node capacity"
        echo "  report      - Generate resource report"
        echo "  all         - Run all checks (default)"
        ;;
esac

RESOURCE_MONITORING_EOF
    
    chmod +x resource-monitoring.sh
    
    echo "✅ Resource monitoring script created: resource-monitoring.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_resource_usage
            ;;
        "quotas")
            create_resource_quotas
            ;;
        "limits")
            create_limit_ranges
            ;;
        "priorities")
            create_priority_classes
            ;;
        "examples")
            create_example_applications
            ;;
        "hpa")
            create_hpa
            ;;
        "monitoring")
            create_resource_monitoring
            ;;
        "all"|"")
            analyze_current_resource_usage
            create_resource_quotas
            create_limit_ranges
            create_priority_classes
            create_example_applications
            create_hpa
            create_resource_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze      - Analyze current resource usage"
            echo "  quotas       - Create resource quotas"
            echo "  limits       - Create limit ranges"
            echo "  priorities   - Create priority classes"
            echo "  examples     - Create example applications"
            echo "  hpa          - Create horizontal pod autoscalers"
            echo "  monitoring   - Create resource monitoring tools"
            echo "  all          - Create all resource management tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 quotas"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x resource-management-implementation.sh

# Запустить создание resource management framework
./resource-management-implementation.sh all
```

## 📋 **Quality of Service (QoS) классы:**

### **Типы QoS:**

| **QoS Class** | **Условие** | **Приоритет** | **Поведение при нехватке ресурсов** |
|---------------|-------------|---------------|-------------------------------------|
| **Guaranteed** | requests = limits | Высший | Последние для eviction |
| **Burstable** | requests < limits | Средний | Eviction по использованию |
| **BestEffort** | Нет requests/limits | Низший | Первые для eviction |

### **Примеры QoS конфигураций:**

#### **Guaranteed QoS:**
```yaml
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "500m"    # Равно requests
    memory: "1Gi"  # Равно requests
```

#### **Burstable QoS:**
```yaml
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "1"       # Больше requests
    memory: "1Gi"  # Больше requests
```

## 🎯 **Практические команды:**

### **Управление ресурсами:**
```bash
# Создать resource management framework
./resource-management-implementation.sh all

# Проверить использование ресурсов
kubectl top nodes
kubectl top pods --all-namespaces

# Мониторинг ресурсов
./resource-monitoring.sh all
```

### **Анализ resource quotas:**
```bash
# Проверить resource quotas
kubectl get resourcequota --all-namespaces

# Детальная информация о quota
kubectl describe resourcequota -n hashfoundry-prod

# Проверить limit ranges
kubectl get limitrange --all-namespaces
```

### **HPA управление:**
```bash
# Проверить HPA status
kubectl get hpa --all-namespaces

# Детальная информация о HPA
kubectl describe hpa -n hashfoundry-prod

# Проверить metrics для HPA
kubectl top pods -n hashfoundry-prod
```

### **Priority Classes:**
```bash
# Проверить priority classes
kubectl get priorityclass

# Создать pod с priority
kubectl run test-pod --image=nginx --priority-class-name=hashfoundry-high
```

## 🔧 **Best Practices для Resource Management:**

### **Планирование ресурсов:**
- **Right-sizing** - правильный размер ресурсов
- **Resource requests** - всегда указывать requests
- **Resource limits** - устанавливать разумные limits
- **QoS classes** - использовать подходящие QoS

### **Мониторинг и оптимизация:**
- **Continuous monitoring** - постоянный мониторинг
- **Resource utilization** - анализ использования
- **Cost optimization** - оптимизация затрат
- **Performance tuning** - настройка производительности

### **Автоматизация:**
- **HPA implementation** - внедрение автомасштабирования
- **VPA consideration** - рассмотрение VPA
- **Cluster autoscaling** - автомасштабирование кластера
- **Resource policies** - политики управления ресурсами

### **Операционные процессы:**
- **Regular reviews** - регулярные обзоры
- **Capacity planning** - планирование мощности
- **Resource governance** - управление ресурсами
- **Documentation** - документирование процессов

**Эффективное управление ресурсами - основа стабильной работы Kubernetes!**
