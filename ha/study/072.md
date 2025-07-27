# 72. Resource Quotas и Limit Ranges в Kubernetes

## 🎯 **Resource Quotas и Limit Ranges в Kubernetes**

**Resource Quotas** и **Limit Ranges** - это механизмы управления ресурсами в Kubernetes, которые обеспечивают контроль использования CPU, памяти, storage и других ресурсов на уровне namespace и объектов. Эти инструменты критически важны для многопользовательских кластеров и production-ready сред.

## 🏗️ **Основные концепции:**

### **Resource Quotas:**
- **Namespace-level limits** - ограничения на уровне namespace
- **Aggregate resource control** - контроль совокупного использования ресурсов
- **Object count limits** - ограничения количества объектов
- **Storage quotas** - квоты на использование storage

### **Limit Ranges:**
- **Individual object limits** - ограничения для отдельных объектов
- **Default values** - значения по умолчанию
- **Min/Max constraints** - минимальные и максимальные ограничения
- **Request/Limit ratios** - соотношения между requests и limits

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих resource quotas и limit ranges:**
```bash
# Проверить существующие resource quotas
kubectl get resourcequota --all-namespaces -o wide

# Проверить limit ranges
kubectl get limitrange --all-namespaces -o wide

# Анализ использования ресурсов в кластере
echo "=== Current Resource Usage in HA Cluster ==="
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Проверить доступные ресурсы на узлах
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### **2. Создание comprehensive resource management strategy:**
```bash
# Создать скрипт для демонстрации resource quotas и limit ranges
cat << 'EOF' > resource-management-demo.sh
#!/bin/bash

echo "=== Resource Quotas and Limit Ranges Demonstration ==="
echo "Demonstrating resource management in HashFoundry HA cluster"
echo

# Функция для создания namespace с resource quotas
create_namespace_with_quotas() {
    local namespace=$1
    local environment=$2
    local cpu_requests=$3
    local memory_requests=$4
    local cpu_limits=$5
    local memory_limits=$6
    local storage_requests=$7
    
    echo "=== Creating Namespace with Resource Quotas: $namespace ==="
    
    # Создать namespace
    cat << NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
  labels:
    environment: $environment
    resource-management: enabled
    app.kubernetes.io/name: hashfoundry
  annotations:
    description: "Namespace with resource quotas for $environment environment"
    resource-policy: "strict"
NS_EOF
    
    # Создать Resource Quota
    cat << RQ_EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${namespace}-quota
  namespace: $namespace
  labels:
    environment: $environment
    quota-type: comprehensive
  annotations:
    description: "Comprehensive resource quota for $namespace"
    created-by: "resource-management-demo"
spec:
  hard:
    # CPU и Memory quotas
    requests.cpu: "$cpu_requests"
    requests.memory: "$memory_requests"
    limits.cpu: "$cpu_limits"
    limits.memory: "$memory_limits"
    
    # Storage quotas
    requests.storage: "$storage_requests"
    persistentvolumeclaims: "10"
    
    # Object count quotas
    pods: "20"
    services: "10"
    secrets: "20"
    configmaps: "20"
    replicationcontrollers: "5"
    deployments.apps: "10"
    statefulsets.apps: "5"
    jobs.batch: "10"
    cronjobs.batch: "5"
    
    # Service-specific quotas
    services.nodeports: "2"
    services.loadbalancers: "1"
    
    # Storage class specific quotas
    do-block-storage.storageclass.storage.k8s.io/requests.storage: "$storage_requests"
    do-block-storage.storageclass.storage.k8s.io/persistentvolumeclaims: "8"
RQ_EOF
    
    echo "✅ Resource quota created for $namespace"
    echo
}

# Функция для создания limit ranges
create_limit_ranges() {
    local namespace=$1
    local environment=$2
    
    echo "=== Creating Limit Ranges for: $namespace ==="
    
    # Создать Limit Range для Pods
    cat << LR_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: ${namespace}-pod-limits
  namespace: $namespace
  labels:
    environment: $environment
    limit-type: pod
  annotations:
    description: "Pod resource limits for $namespace"
    created-by: "resource-management-demo"
spec:
  limits:
  - type: Pod
    max:
      cpu: "2000m"
      memory: "4Gi"
    min:
      cpu: "10m"
      memory: "16Mi"
  - type: Container
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "1000m"
      memory: "2Gi"
    min:
      cpu: "10m"
      memory: "16Mi"
    maxLimitRequestRatio:
      cpu: "10"
      memory: "8"
LR_POD_EOF
    
    # Создать Limit Range для PVC
    cat << LR_PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: ${namespace}-pvc-limits
  namespace: $namespace
  labels:
    environment: $environment
    limit-type: pvc
  annotations:
    description: "PVC resource limits for $namespace"
    created-by: "resource-management-demo"
spec:
  limits:
  - type: PersistentVolumeClaim
    max:
      storage: "50Gi"
    min:
      storage: "1Gi"
    default:
      storage: "10Gi"
    defaultRequest:
      storage: "5Gi"
LR_PVC_EOF
    
    echo "✅ Limit ranges created for $namespace"
    echo
}

# Функция для создания development environment
create_development_environment() {
    echo "=== Creating Development Environment ==="
    
    create_namespace_with_quotas "hashfoundry-dev" "development" "4" "8Gi" "8" "16Gi" "100Gi"
    create_limit_ranges "hashfoundry-dev" "development"
    
    # Создать демонстрационные приложения
    cat << DEV_APPS_EOF | kubectl apply -f -
# Small development application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-app-small
  namespace: hashfoundry-dev
  labels:
    app: dev-app
    size: small
    environment: development
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dev-app
      size: small
  template:
    metadata:
      labels:
        app: dev-app
        size: small
        environment: development
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        env:
        - name: ENVIRONMENT
          value: "development"
        - name: APP_SIZE
          value: "small"
---
# Medium development application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-app-medium
  namespace: hashfoundry-dev
  labels:
    app: dev-app
    size: medium
    environment: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dev-app
      size: medium
  template:
    metadata:
      labels:
        app: dev-app
        size: medium
        environment: development
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        env:
        - name: ENVIRONMENT
          value: "development"
        - name: APP_SIZE
          value: "medium"
---
# Development PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dev-storage
  namespace: hashfoundry-dev
  labels:
    environment: development
    usage: development-data
spec:
  storageClassName: do-block-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
DEV_APPS_EOF
    
    echo "✅ Development environment created with resource constraints"
    echo
}

# Функция для создания production environment
create_production_environment() {
    echo "=== Creating Production Environment ==="
    
    create_namespace_with_quotas "hashfoundry-prod" "production" "10" "20Gi" "20" "40Gi" "500Gi"
    create_limit_ranges "hashfoundry-prod" "production"
    
    # Создать production приложения
    cat << PROD_APPS_EOF | kubectl apply -f -
# Production web application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-web-app
  namespace: hashfoundry-prod
  labels:
    app: web-app
    tier: frontend
    environment: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
      tier: frontend
  template:
    metadata:
      labels:
        app: web-app
        tier: frontend
        environment: production
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: TIER
          value: "frontend"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
# Production API application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-api-app
  namespace: hashfoundry-prod
  labels:
    app: api-app
    tier: backend
    environment: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-app
      tier: backend
  template:
    metadata:
      labels:
        app: api-app
        tier: backend
        environment: production
    spec:
      containers:
      - name: api
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "400m"
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: TIER
          value: "backend"
---
# Production database PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prod-database-storage
  namespace: hashfoundry-prod
  labels:
    environment: production
    usage: database
spec:
  storageClassName: do-block-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
PROD_APPS_EOF
    
    echo "✅ Production environment created with strict resource controls"
    echo
}

# Функция для создания testing environment с ограниченными ресурсами
create_testing_environment() {
    echo "=== Creating Testing Environment ==="
    
    create_namespace_with_quotas "hashfoundry-test" "testing" "2" "4Gi" "4" "8Gi" "50Gi"
    create_limit_ranges "hashfoundry-test" "testing"
    
    # Создать test приложения
    cat << TEST_APPS_EOF | kubectl apply -f -
# Test application with minimal resources
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: hashfoundry-test
  labels:
    app: test-app
    environment: testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
        environment: testing
    spec:
      containers:
      - name: test
        image: busybox:1.35
        command: ["sleep", "3600"]
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
        env:
        - name: ENVIRONMENT
          value: "testing"
---
# Test job
apiVersion: batch/v1
kind: Job
metadata:
  name: test-job
  namespace: hashfoundry-test
  labels:
    app: test-job
    environment: testing
spec:
  template:
    metadata:
      labels:
        app: test-job
        environment: testing
    spec:
      containers:
      - name: test
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Running resource quota test..."
          echo "Available memory: $(cat /proc/meminfo | grep MemAvailable)"
          echo "CPU info: $(cat /proc/cpuinfo | grep processor | wc -l) cores"
          echo "Test completed successfully!"
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
          limits:
            memory: "32Mi"
            cpu: "20m"
      restartPolicy: Never
TEST_APPS_EOF
    
    echo "✅ Testing environment created with minimal resource allocation"
    echo
}

# Функция для демонстрации quota violations
demonstrate_quota_violations() {
    echo "=== Demonstrating Quota Violations ==="
    
    # Попытаться создать приложение, которое превышает quota
    cat << VIOLATION_EOF | kubectl apply -f - || echo "Expected: Quota violation occurred"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-violator
  namespace: hashfoundry-test
  labels:
    app: quota-violator
    purpose: demonstration
spec:
  replicas: 10  # Слишком много реплик для test environment
  selector:
    matchLabels:
      app: quota-violator
  template:
    metadata:
      labels:
        app: quota-violator
        purpose: demonstration
    spec:
      containers:
      - name: violator
        image: nginx:1.21
        resources:
          requests:
            memory: "1Gi"  # Слишком много памяти
            cpu: "500m"    # Слишком много CPU
          limits:
            memory: "2Gi"
            cpu: "1000m"
VIOLATION_EOF
    
    echo "✅ Quota violation demonstration completed"
    echo
}

# Функция для мониторинга resource usage
monitor_resource_usage() {
    echo "=== Monitoring Resource Usage ==="
    
    echo "Resource Quota Status:"
    echo "====================="
    
    for ns in hashfoundry-dev hashfoundry-prod hashfoundry-test; do
        if kubectl get namespace $ns >/dev/null 2>&1; then
            echo "Namespace: $ns"
            echo "  Resource Quota:"
            kubectl get resourcequota -n $ns -o custom-columns="NAME:.metadata.name,CPU_REQUESTS:.status.used.requests\.cpu,.status.hard.requests\.cpu,MEMORY_REQUESTS:.status.used.requests\.memory,.status.hard.requests\.memory" --no-headers 2>/dev/null || echo "    No quota found"
            
            echo "  Limit Range:"
            kubectl get limitrange -n $ns -o custom-columns="NAME:.metadata.name,TYPE:.spec.limits[0].type" --no-headers 2>/dev/null || echo "    No limit range found"
            
            echo "  Current Pods:"
            kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l | xargs echo "    Pod count:"
            
            echo "  Resource Usage:"
            kubectl top pods -n $ns --no-headers 2>/dev/null | awk '{cpu+=$2; mem+=$3} END {print "    Total CPU: " cpu "m, Total Memory: " mem "Mi"}' || echo "    Metrics not available"
            
            echo
        fi
    done
}

# Функция для создания resource monitoring dashboard
create_resource_monitoring() {
    echo "=== Creating Resource Monitoring Dashboard ==="
    
    # Создать ConfigMap с monitoring scripts
    cat << MONITOR_EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: resource-monitoring-scripts
  namespace: kube-system
  labels:
    app: resource-monitoring
    component: scripts
data:
  quota-monitor.sh: |
    #!/bin/bash
    echo "=== Resource Quota Monitoring ==="
    echo "Timestamp: \$(date)"
    echo
    
    for ns in \$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        quota_count=\$(kubectl get resourcequota -n \$ns --no-headers 2>/dev/null | wc -l)
        if [ \$quota_count -gt 0 ]; then
            echo "Namespace: \$ns"
            kubectl describe resourcequota -n \$ns 2>/dev/null | grep -E "(Name:|Used:|Hard:)" | head -20
            echo
        fi
    done
  
  limit-range-monitor.sh: |
    #!/bin/bash
    echo "=== Limit Range Monitoring ==="
    echo "Timestamp: \$(date)"
    echo
    
    for ns in \$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        lr_count=\$(kubectl get limitrange -n \$ns --no-headers 2>/dev/null | wc -l)
        if [ \$lr_count -gt 0 ]; then
            echo "Namespace: \$ns"
            kubectl get limitrange -n \$ns -o yaml 2>/dev/null | grep -A 10 "limits:"
            echo
        fi
    done
  
  resource-usage-report.sh: |
    #!/bin/bash
    echo "=== Resource Usage Report ==="
    echo "Generated: \$(date)"
    echo
    
    echo "Node Resource Allocation:"
    kubectl describe nodes | grep -A 5 "Allocated resources:" | grep -E "(cpu|memory|pods)"
    echo
    
    echo "Top Resource Consuming Pods:"
    kubectl top pods --all-namespaces --sort-by=cpu | head -10
    echo
    
    echo "Top Memory Consuming Pods:"
    kubectl top pods --all-namespaces --sort-by=memory | head -10
MONITOR_EOF
    
    # Создать CronJob для регулярного мониторинга
    cat << CRONJOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: resource-quota-monitor
  namespace: kube-system
  labels:
    app: resource-monitoring
    component: cronjob
spec:
  schedule: "*/15 * * * *"  # Каждые 15 минут
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: resource-monitoring
            component: monitor
        spec:
          serviceAccountName: resource-monitor
          containers:
          - name: monitor
            image: bitnami/kubectl:latest
            command: ["sh", "-c"]
            args:
            - |
              echo "=== Automated Resource Monitoring ==="
              echo "Time: \$(date)"
              echo
              
              # Проверить quota usage
              echo "Resource Quota Usage:"
              for ns in \$(kubectl get namespaces -l resource-management=enabled -o jsonpath='{.items[*].metadata.name}'); do
                  echo "Namespace: \$ns"
                  kubectl get resourcequota -n \$ns -o custom-columns="NAME:.metadata.name,CPU_USED:.status.used.requests\.cpu,CPU_HARD:.status.hard.requests\.cpu,MEM_USED:.status.used.requests\.memory,MEM_HARD:.status.hard.requests\.memory" --no-headers 2>/dev/null || echo "  No quota"
                  echo
              done
              
              # Проверить pods без resource requests
              echo "Pods without resource requests:"
              kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\n"}{end}' | grep -E "\t\t" | head -5
              
              echo "Monitoring completed at \$(date)"
            resources:
              requests:
                memory: "64Mi"
                cpu: "50m"
              limits:
                memory: "128Mi"
                cpu: "100m"
          restartPolicy: OnFailure
---
# ServiceAccount для monitoring
apiVersion: v1
kind: ServiceAccount
metadata:
  name: resource-monitor
  namespace: kube-system
  labels:
    app: resource-monitoring
---
# ClusterRole для monitoring
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-monitor
  labels:
    app: resource-monitoring
rules:
- apiGroups: [""]
  resources: ["namespaces", "pods", "nodes", "resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
---
# ClusterRoleBinding для monitoring
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: resource-monitor
  labels:
    app: resource-monitoring
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: resource-monitor
subjects:
- kind: ServiceAccount
  name: resource-monitor
  namespace: kube-system
CRONJOB_EOF
    
    echo "✅ Resource monitoring dashboard created"
    echo
}

# Основная функция для демонстрации всех возможностей
demonstrate_all_features() {
    echo "=== Full Resource Management Demonstration ==="
    
    create_development_environment
    create_production_environment
    create_testing_environment
    demonstrate_quota_violations
    create_resource_monitoring
    
    sleep 30  # Дать время для создания ресурсов
    
    monitor_resource_usage
    
    echo "=== Resource Management Summary ==="
    echo "✅ Development environment created with generous quotas"
    echo "✅ Production environment created with strict controls"
    echo "✅ Testing environment created with minimal resources"
    echo "✅ Quota violations demonstrated"
    echo "✅ Resource monitoring configured"
    echo
    
    echo "=== Current Resource Quotas Overview ==="
    kubectl get resourcequota --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU_REQUESTS:.status.used.requests\.cpu/.status.hard.requests\.cpu,MEMORY_REQUESTS:.status.used.requests\.memory/.status.hard.requests\.memory"
}

# Основная функция
main() {
    case "$1" in
        "development")
            create_development_environment
            ;;
        "production")
            create_production_environment
            ;;
        "testing")
            create_testing_environment
            ;;
        "violations")
            demonstrate_quota_violations
            ;;
        "monitoring")
            create_resource_monitoring
            ;;
        "monitor")
            monitor_resource_usage
            ;;
        "all"|"")
            demonstrate_all_features
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  development  - Create development environment with quotas"
            echo "  production   - Create production environment with quotas"
            echo "  testing      - Create testing environment with quotas"
            echo "  violations   - Demonstrate quota violations"
            echo "  monitoring   - Create resource monitoring"
            echo "  monitor      - Monitor current resource usage"
            echo "  all          - Full demonstration (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 development"
            echo "  $0 monitor"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x resource-management-demo.sh

# Запустить демонстрацию
./resource-management-demo.sh all
```

## 📋 **Resource Quotas - основные типы:**

### **1. Compute Resource Quotas:**
```bash
# CPU и Memory quotas
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"      # Общий CPU requests
    requests.memory: 20Gi   # Общая Memory requests
    limits.cpu: "20"        # Общий CPU limits
    limits.memory: 40Gi     # Общая Memory limits
```

### **2. Storage Resource Quotas:**
```bash
# Storage quotas
spec:
  hard:
    requests.storage: "100Gi"                    # Общий storage
    persistentvolumeclaims: "10"                 # Количество PVC
    # Storage class specific
    ssd.storageclass.storage.k8s.io/requests.storage: "50Gi"
    ssd.storageclass.storage.k8s.io/persistentvolumeclaims: "5"
```

### **3. Object Count Quotas:**
```bash
# Количество объектов
spec:
  hard:
    pods: "20"                    # Максимум pods
    services: "10"                # Максимум services
    secrets: "20"                 # Максимум secrets
    configmaps: "20"              # Максимум configmaps
    deployments.apps: "10"        # Максимум deployments
    statefulsets.apps: "5"        # Максимум statefulsets
```

## 📋 **Limit Ranges - основные типы:**

### **1. Container Limits:**
```bash
# Ограничения для контейнеров
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:                    # Значения по умолчанию
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:             # Requests по умолчанию
      cpu: "100m"
      memory: "128Mi"
    max:                        # Максимальные значения
      cpu: "1000m"
      memory: "2Gi"
    min:                        # Минимальные значения
      cpu: "10m"
      memory: "16Mi"
    maxLimitRequestRatio:       # Соотношение limit/request
      cpu: "10"
      memory: "8"
```

### **2. Pod Limits:**
```bash
# Ограничения для pods
spec:
  limits:
  - type: Pod
    max:
      cpu: "2000m"
      memory: "4Gi"
    min:
      cpu: "10m"
      memory: "16Mi"
```

### **3. PVC Limits:**
```bash
# Ограничения для PVC
spec:
  limits:
  - type: PersistentVolumeClaim
    max:
      storage: "50Gi"
    min:
      storage: "1Gi"
    default:
      storage: "10Gi"
```

## 🎯 **Практические команды:**

### **Управление Resource Quotas:**
```bash
# Создание и просмотр
kubectl create quota my-quota --hard=cpu=2,memory=4Gi,pods=10
kubectl get resourcequota --all-namespaces
kubectl describe resourcequota <quota-name> -n <namespace>

# Проверка использования
kubectl get resourcequota <quota-name> -n <namespace> -o yaml
kubectl top pods -n <namespace>
```

### **Управление Limit Ranges:**
```bash
# Создание и просмотр
kubectl get limitrange --all-namespaces
kubectl describe limitrange <limit-range-name> -n <namespace>

# Проверка применения
kubectl get pods -n <namespace> -o yaml | grep -A 10 resources
```

### **Мониторинг ресурсов:**
```bash
# Анализ использования
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Проверка quota violations
kubectl get events -n <namespace> | grep -i quota
kubectl describe pod <pod-name> -n <namespace>
```

## 🔧 **Best Practices:**

### **Resource Quotas:**
- **Установить quotas для всех production namespaces**
- **Мониторить использование регулярно**
- **Настроить alerts на превышение 80% quota**
- **Использовать разные quotas для разных сред**

### **Limit Ranges:**
- **Всегда устанавливать default values**
- **Использовать reasonable min/max limits**
- **Настроить maxLimitRequestRatio**
- **Тестировать limits в dev среде**

**Resource Quotas и Limit Ranges обеспечивают эффективное управление ресурсами и предотвращают resource starvation в Kubernetes!**
