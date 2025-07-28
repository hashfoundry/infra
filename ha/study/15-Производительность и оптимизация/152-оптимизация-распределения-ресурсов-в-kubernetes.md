# 152. Как оптимизировать распределение ресурсов в Kubernetes?

## 🎯 Вопрос
Как оптимизировать распределение ресурсов в Kubernetes?

## 💡 Ответ

Оптимизация распределения ресурсов в Kubernetes включает правильную настройку requests/limits, использование QoS классов, эффективное планирование и автомасштабирование.

### 🏗️ Основы управления ресурсами

#### 1. **Иерархия управления ресурсами**
```
┌─────────────────────────────────────────────────────────┐
│                    Cluster Level                        │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                Namespace Level                      │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │                Pod Level                        │ │ │
│  │  │  ┌─────────────────────────────────────────────┐ │ │ │
│  │  │  │            Container Level                  │ │ │ │
│  │  │  └─────────────────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

#### 2. **Типы ресурсов**
```yaml
# Классификация ресурсов Kubernetes
resource_types:
  compressible:
    - cpu
    - network_bandwidth
    - disk_bandwidth
    description: "Можно ограничить без завершения процесса"
  
  incompressible:
    - memory
    - storage
    description: "Нельзя ограничить без завершения процесса"
  
  extended:
    - nvidia.com/gpu
    - example.com/custom-resource
    description: "Пользовательские ресурсы"
```

### 🎯 Requests и Limits

#### 1. **Правильная настройка requests/limits**
```yaml
# Оптимизированная конфигурация ресурсов
apiVersion: apps/v1
kind: Deployment
metadata:
  name: optimized-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: optimized-app
  template:
    metadata:
      labels:
        app: optimized-app
    spec:
      containers:
      - name: app
        image: myapp:latest
        resources:
          requests:
            cpu: 100m        # Минимальные требования
            memory: 128Mi
          limits:
            cpu: 500m        # Максимальное использование
            memory: 512Mi
        # Проверки готовности для оптимального планирования
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

#### 2. **Стратегии настройки ресурсов**
```yaml
# Различные стратегии для разных типов приложений
strategies:
  cpu_intensive:
    requests:
      cpu: "1"
      memory: 512Mi
    limits:
      cpu: "2"
      memory: 1Gi
    description: "Для вычислительно-интенсивных задач"
  
  memory_intensive:
    requests:
      cpu: 200m
      memory: 2Gi
    limits:
      cpu: 500m
      memory: 4Gi
    description: "Для приложений с большим потреблением памяти"
  
  burstable:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: "1"
      memory: 1Gi
    description: "Для приложений с переменной нагрузкой"
  
  guaranteed:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 500m
      memory: 1Gi
    description: "Для критически важных приложений"
```

### 📊 Примеры из нашего кластера

#### Анализ использования ресурсов:
```bash
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory
```

#### Проверка QoS классов:
```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass --all-namespaces
```

#### Мониторинг распределения ресурсов:
```bash
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### 🎪 Quality of Service (QoS) классы

#### 1. **Guaranteed QoS**
```yaml
# Guaranteed - высший приоритет
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 500m      # Равны requests
        memory: 1Gi    # Равны requests
```

#### 2. **Burstable QoS**
```yaml
# Burstable - средний приоритет
apiVersion: v1
kind: Pod
metadata:
  name: burstable-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m      # Больше requests
        memory: 512Mi  # Больше requests
```

#### 3. **BestEffort QoS**
```yaml
# BestEffort - низший приоритет
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-pod
spec:
  containers:
  - name: app
    image: nginx
    # Нет requests и limits
```

### 🔧 Namespace-уровневые ограничения

#### 1. **ResourceQuota**
```yaml
# resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
    pods: "50"
    services: "10"
    secrets: "20"
    configmaps: "20"
```

#### 2. **LimitRange**
```yaml
# limit-range.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    min:
      cpu: 50m
      memory: 64Mi
    max:
      cpu: "2"
      memory: 4Gi
  - type: Pod
    max:
      cpu: "4"
      memory: 8Gi
  - type: PersistentVolumeClaim
    min:
      storage: 1Gi
    max:
      storage: 100Gi
```

### 🚀 Автомасштабирование

#### 1. **Horizontal Pod Autoscaler (HPA)**
```yaml
# hpa-optimized.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: optimized-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: optimized-app
  minReplicas: 2
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
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
```

#### 2. **Vertical Pod Autoscaler (VPA)**
```yaml
# vpa-optimized.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: optimized-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: optimized-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: "2"
        memory: 4Gi
      controlledResources: ["cpu", "memory"]
```

### 🎯 Планирование и размещение

#### 1. **Node Affinity для оптимизации**
```yaml
# node-affinity-optimized.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compute-intensive-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: compute-intensive
  template:
    metadata:
      labels:
        app: compute-intensive
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values: ["high-cpu"]
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: zone
                operator: In
                values: ["zone-a"]
      containers:
      - name: app
        image: compute-app:latest
        resources:
          requests:
            cpu: "2"
            memory: 1Gi
          limits:
            cpu: "4"
            memory: 2Gi
```

#### 2. **Pod Anti-Affinity для распределения**
```yaml
# anti-affinity-optimized.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distributed-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: distributed-app
  template:
    metadata:
      labels:
        app: distributed-app
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["distributed-app"]
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: distributed-app:latest
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: "1"
            memory: 1Gi
```

### 📈 Мониторинг и анализ

#### 1. **Скрипт анализа использования ресурсов**
```bash
#!/bin/bash
# resource-analysis.sh

echo "🔍 Анализ использования ресурсов в кластере"

echo "📊 Общее использование узлов:"
kubectl top nodes

echo -e "\n📊 Использование ресурсов по namespace:"
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
    echo "Namespace: $ns"
    kubectl top pods -n $ns --no-headers 2>/dev/null | \
    awk '{cpu+=$2; mem+=$3} END {print "  CPU: " cpu "m, Memory: " mem "Mi"}'
done

echo -e "\n📊 Поды с высоким использованием CPU (>500m):"
kubectl top pods --all-namespaces --no-headers | \
awk '$3 > 500 {print $1 "/" $2 ": " $3}'

echo -e "\n📊 Поды с высоким использованием памяти (>1Gi):"
kubectl top pods --all-namespaces --no-headers | \
awk '$4 > 1000 {print $1 "/" $2 ": " $4 "Mi"}'

echo -e "\n📊 QoS классы подов:"
kubectl get pods --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
QOS:.status.qosClass | \
sort -k3

echo "✅ Анализ завершен"
```

#### 2. **Prometheus запросы для мониторинга**
```yaml
# Полезные Prometheus запросы
prometheus_queries:
  cpu_utilization:
    cluster: "100 * (1 - avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])))"
    node: "100 * (1 - avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])))"
    pod: "rate(container_cpu_usage_seconds_total[5m]) * 100"
  
  memory_utilization:
    cluster: "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))"
    node: "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))"
    pod: "container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100"
  
  resource_efficiency:
    cpu_request_vs_usage: "rate(container_cpu_usage_seconds_total[5m]) / on(pod) kube_pod_container_resource_requests{resource=\"cpu\"}"
    memory_request_vs_usage: "container_memory_working_set_bytes / on(pod) kube_pod_container_resource_requests{resource=\"memory\"}"
```

### 🔧 Оптимизация стратегий

#### 1. **Профилирование приложений**
```bash
#!/bin/bash
# app-profiling.sh

APP_NAME="$1"
NAMESPACE="$2"

if [ -z "$APP_NAME" ] || [ -z "$NAMESPACE" ]; then
    echo "Usage: $0 <app-name> <namespace>"
    exit 1
fi

echo "🔍 Профилирование приложения: $APP_NAME в namespace: $NAMESPACE"

# Текущее использование ресурсов
echo "📊 Текущее использование:"
kubectl top pods -n $NAMESPACE -l app=$APP_NAME

# Конфигурация ресурсов
echo -e "\n⚙️ Конфигурация ресурсов:"
kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}  {.name}: requests={.resources.requests}, limits={.resources.limits}{"\n"}{end}{end}'

# История рестартов
echo -e "\n🔄 История рестартов:"
kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount

# События
echo -e "\n📝 Последние события:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$APP_NAME --sort-by=.metadata.creationTimestamp | tail -5

echo "✅ Профилирование завершено"
```

#### 2. **Рекомендации по оптимизации**
```yaml
# Рекомендации по настройке ресурсов
optimization_recommendations:
  cpu_optimization:
    - "Используйте CPU requests для гарантии ресурсов"
    - "Устанавливайте CPU limits для предотвращения noisy neighbor"
    - "Мониторьте CPU throttling"
    - "Используйте CPU affinity для производительных приложений"
  
  memory_optimization:
    - "Всегда устанавливайте memory limits"
    - "Memory requests должны соответствовать реальному использованию"
    - "Мониторьте OOMKilled события"
    - "Используйте memory-mapped файлы для больших данных"
  
  scheduling_optimization:
    - "Используйте node affinity для специализированных узлов"
    - "Применяйте pod anti-affinity для высокой доступности"
    - "Настройте tolerations для специальных узлов"
    - "Используйте priority classes для критических подов"
```

### 🎯 Продвинутые техники

#### 1. **Priority Classes**
```yaml
# priority-classes.yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "High priority class for critical applications"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: false
description: "Low priority class for batch jobs"
---
# Использование в Pod
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: critical-app:latest
    resources:
      requests:
        cpu: "1"
        memory: 1Gi
      limits:
        cpu: "2"
        memory: 2Gi
```

#### 2. **Resource Quotas с приоритетами**
```yaml
# priority-resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: high-priority-quota
  namespace: production
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high-priority"]
```

### 📋 Лучшие практики

#### 1. **Общие принципы**
- ✅ **Всегда устанавливайте requests** для планирования
- ✅ **Используйте limits** для предотвращения resource starvation
- ✅ **Мониторьте реальное использование** и корректируйте настройки
- ✅ **Применяйте QoS классы** в соответствии с критичностью
- ✅ **Используйте namespace quotas** для изоляции
- ✅ **Настройте автомасштабирование** для динамических нагрузок

#### 2. **Автоматизация оптимизации**
```bash
#!/bin/bash
# optimize-resources.sh

echo "🔧 Автоматическая оптимизация ресурсов"

# Поиск подов без resource requests
echo "⚠️ Поды без resource requests:"
kubectl get pods --all-namespaces -o json | \
jq -r '.items[] | select(.spec.containers[].resources.requests == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Поиск подов с высоким CPU throttling
echo -e "\n⚠️ Поды с CPU throttling:"
kubectl top pods --all-namespaces --containers | \
awk 'NR>1 && $3 > 80 {print $1 "/" $2 ": " $3 "%"}'

# Рекомендации по VPA
echo -e "\n💡 Рекомендации VPA:"
kubectl get vpa --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
CPU_TARGET:.status.recommendation.containerRecommendations[0].target.cpu,\
MEMORY_TARGET:.status.recommendation.containerRecommendations[0].target.memory

echo "✅ Оптимизация завершена"
```

Эффективное распределение ресурсов в Kubernetes требует понимания потребностей приложений, правильной настройки requests/limits и постоянного мониторинга для корректировки конфигурации.
