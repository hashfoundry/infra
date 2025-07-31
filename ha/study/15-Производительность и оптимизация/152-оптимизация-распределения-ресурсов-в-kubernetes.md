# 152. Как оптимизировать распределение ресурсов в Kubernetes?

## 🎯 **Что такое оптимизация распределения ресурсов?**

**Оптимизация распределения ресурсов в Kubernetes** — это процесс эффективного управления CPU, памятью и другими ресурсами для обеспечения максимальной производительности при минимальных затратах. Включает настройку requests/limits, QoS классов и автомасштабирования.

## 🏗️ **Основные компоненты управления ресурсами:**

### **1. Resource Requests & Limits**
- Гарантированные ресурсы (requests)
- Максимальные ограничения (limits)
- QoS классы (Guaranteed, Burstable, BestEffort)

### **2. Namespace-уровневые ограничения**
- ResourceQuota для общих лимитов
- LimitRange для значений по умолчанию
- PriorityClass для приоритизации

### **3. Автомасштабирование**
- Horizontal Pod Autoscaler (HPA)
- Vertical Pod Autoscaler (VPA)
- Cluster Autoscaler

### **4. Планирование размещения**
- Node Affinity/Anti-Affinity
- Pod Affinity/Anti-Affinity
- Taints и Tolerations

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущего использования ресурсов:**
```bash
# Общее состояние узлов
kubectl top nodes

# Использование ресурсов по подам
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Анализ ArgoCD ресурсов
kubectl top pods -n argocd
kubectl describe pods -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 10 "Requests\|Limits"

# Анализ мониторинга ресурсов
kubectl top pods -n monitoring
kubectl describe pods -n monitoring -l app.kubernetes.io/name=prometheus | grep -A 10 "Requests\|Limits"
```

### **2. Проверка QoS классов в кластере:**
```bash
# QoS классы всех подов
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,QOS:.status.qosClass

# QoS ArgoCD подов
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,RESTARTS:.status.containerStatuses[*].restartCount

# QoS мониторинга
kubectl get pods -n monitoring -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory
```

### **3. Анализ распределения ресурсов по узлам:**
```bash
# Детальная информация о распределении ресурсов
kubectl describe nodes | grep -A 5 "Allocated resources"

# Проверка доступных ресурсов
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU-CAPACITY:.status.capacity.cpu,MEMORY-CAPACITY:.status.capacity.memory,CPU-ALLOCATABLE:.status.allocatable.cpu,MEMORY-ALLOCATABLE:.status.allocatable.memory

# Поды на каждом узле
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== Node: $node ==="
  kubectl get pods --all-namespaces --field-selector spec.nodeName=$node -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory
done
```

### **4. Оптимизация ArgoCD ресурсов:**
```bash
# Текущие ресурсы ArgoCD
kubectl get deployment argocd-server -n argocd -o yaml | grep -A 10 resources

# Мониторинг производительности ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server | grep -i "memory\|cpu\|performance"

# Проверка автомасштабирования ArgoCD (если настроено)
kubectl get hpa -n argocd
```

### **5. Оптимизация Prometheus и Grafana:**
```bash
# Ресурсы Prometheus
kubectl describe deployment prometheus-server -n monitoring | grep -A 10 "Requests\|Limits"

# Использование хранилища Prometheus
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-server -n monitoring

# Ресурсы Grafana
kubectl describe deployment grafana -n monitoring | grep -A 10 "Requests\|Limits"
```

## 🔄 **Демонстрация оптимизации ресурсов:**

### **1. Создание оптимизированного Deployment:**
```bash
# Создать оптимизированное приложение
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-optimized-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-optimized
  template:
    metadata:
      labels:
        app: resource-optimized
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["resource-optimized"]
              topologyKey: kubernetes.io/hostname
EOF

# Проверить QoS класс
kubectl get pods -l app=resource-optimized -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# Мониторинг ресурсов
kubectl top pods -l app=resource-optimized

# Очистка
kubectl delete deployment resource-optimized-app
```

### **2. Настройка HPA для автомасштабирования:**
```bash
# Создать HPA для оптимизированного приложения
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-demo-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hpa-demo
  template:
    metadata:
      labels:
        app: hpa-demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hpa-demo-svc
  namespace: default
spec:
  selector:
    app: hpa-demo
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-demo
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-demo-app
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
EOF

# Проверить HPA
kubectl get hpa hpa-demo
kubectl describe hpa hpa-demo

# Создать нагрузку для тестирования
kubectl run load-generator --image=busybox -it --rm -- /bin/sh -c "
while true; do
  wget -q -O- http://hpa-demo-svc.default.svc.cluster.local/
  sleep 0.1
done"

# Мониторинг автомасштабирования
watch kubectl get hpa hpa-demo

# Очистка
kubectl delete deployment hpa-demo-app
kubectl delete svc hpa-demo-svc
kubectl delete hpa hpa-demo
```

### **3. Настройка ResourceQuota и LimitRange:**
```bash
# Создать namespace с ограничениями ресурсов
kubectl create namespace resource-test

# Применить ResourceQuota
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: resource-test
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "5"
    pods: "10"
    services: "5"
EOF

# Применить LimitRange
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: resource-test
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
      cpu: "1"
      memory: 2Gi
  - type: Pod
    max:
      cpu: "2"
      memory: 4Gi
EOF

# Проверить ограничения
kubectl describe quota compute-quota -n resource-test
kubectl describe limitrange resource-limits -n resource-test

# Тестировать создание пода
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: resource-test
spec:
  containers:
  - name: app
    image: nginx:alpine
    # Ресурсы будут установлены автоматически из LimitRange
EOF

# Проверить примененные ресурсы
kubectl describe pod test-pod -n resource-test | grep -A 10 "Requests\|Limits"

# Очистка
kubectl delete namespace resource-test
```

## 🔧 **Скрипт комплексной оптимизации ресурсов:**

### **1. Создание скрипта анализа:**
```bash
# Создать скрипт resource-optimizer.sh
cat << 'EOF' > resource-optimizer.sh
#!/bin/bash

echo "🔧 Комплексная оптимизация ресурсов HA кластера"
echo "=============================================="

echo -e "\n📊 1. АНАЛИЗ ИСПОЛЬЗОВАНИЯ УЗЛОВ:"
kubectl top nodes

echo -e "\n📊 2. РАСПРЕДЕЛЕНИЕ РЕСУРСОВ ПО УЗЛАМ:"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== Node: $node ==="
  kubectl describe node $node | grep -A 5 "Allocated resources"
done

echo -e "\n📊 3. ТОП ПОДОВ ПО РЕСУРСАМ:"
echo "CPU:"
kubectl top pods --all-namespaces --sort-by=cpu | head -10
echo -e "\nMemory:"
kubectl top pods --all-namespaces --sort-by=memory | head -10

echo -e "\n📊 4. QOS КЛАССЫ ПОДОВ:"
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,QOS:.status.qosClass | sort -k3

echo -e "\n⚠️  5. ПОДЫ БЕЗ RESOURCE REQUESTS:"
kubectl get pods --all-namespaces -o json | \
jq -r '.items[] | select(.spec.containers[].resources.requests == null) | "\(.metadata.namespace)/\(.metadata.name)"'

echo -e "\n⚠️  6. ПОДЫ БЕЗ RESOURCE LIMITS:"
kubectl get pods --all-namespaces -o json | \
jq -r '.items[] | select(.spec.containers[].resources.limits == null) | "\(.metadata.namespace)/\(.metadata.name)"'

echo -e "\n📊 7. ARGOCD РЕСУРСЫ:"
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory,CPU-LIM:.spec.containers[*].resources.limits.cpu,MEM-LIM:.spec.containers[*].resources.limits.memory

echo -e "\n📊 8. МОНИТОРИНГ РЕСУРСЫ:"
kubectl get pods -n monitoring -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory

echo -e "\n📊 9. HPA СТАТУС:"
kubectl get hpa --all-namespaces

echo -e "\n📊 10. RESOURCE QUOTAS:"
kubectl get resourcequota --all-namespaces

echo -e "\n💡 РЕКОМЕНДАЦИИ:"
echo "1. Установите resource requests для всех подов"
echo "2. Используйте resource limits для предотвращения noisy neighbor"
echo "3. Настройте HPA для динамических нагрузок"
echo "4. Применяйте ResourceQuota для изоляции namespace"
echo "5. Мониторьте QoS классы и оптимизируйте их"

echo -e "\n✅ Анализ завершен!"
EOF

chmod +x resource-optimizer.sh
```

### **2. Запуск оптимизации:**
```bash
# Выполнить анализ
./resource-optimizer.sh

# Сохранить отчет
./resource-optimizer.sh > resource-optimization-report-$(date +%Y%m%d-%H%M%S).txt
```

## 📊 **Архитектура управления ресурсами:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Resource Management                     │
├─────────────────────────────────────────────────────────────┤
│  Cluster Level                                              │
│  ├── Node Resources (CPU, Memory, Storage)                 │
│  ├── Cluster Autoscaler (Node scaling)                     │
│  └── Resource Monitoring (Prometheus, Metrics Server)      │
├─────────────────────────────────────────────────────────────┤
│  Namespace Level                                            │
│  ├── ResourceQuota (Total limits per namespace)            │
│  ├── LimitRange (Default and min/max values)               │
│  └── PriorityClass (Pod scheduling priority)               │
├─────────────────────────────────────────────────────────────┤
│  Workload Level                                             │
│  ├── Deployment/StatefulSet (Resource specifications)      │
│  ├── HPA (Horizontal scaling based on metrics)             │
│  ├── VPA (Vertical scaling recommendations)                │
│  └── PDB (Pod Disruption Budget)                           │
├─────────────────────────────────────────────────────────────┤
│  Pod Level                                                  │
│  ├── Resource Requests (Guaranteed resources)              │
│  ├── Resource Limits (Maximum usage)                       │
│  ├── QoS Classes (Guaranteed, Burstable, BestEffort)       │
│  └── Affinity/Anti-Affinity (Placement preferences)        │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Мониторинг и алерты для ресурсов:**

### **1. Критические метрики для мониторинга:**
```bash
# Высокое использование CPU узлов (>80%)
kubectl top nodes | awk 'NR>1 && $3+0 > 80 {print "⚠️ High CPU on node " $1 ": " $3}'

# Высокое использование памяти узлов (>85%)
kubectl top nodes | awk 'NR>1 && $5+0 > 85 {print "⚠️ High Memory on node " $1 ": " $5}'

# Поды с частыми перезапусками (>5)
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount | awk '$3+0 > 5 {print "⚠️ High restarts: " $1 "/" $2 " (" $3 " restarts)"}'

# OOMKilled события
kubectl get events --all-namespaces --field-selector reason=OOMKilling

# Поды в состоянии Pending из-за ресурсов
kubectl get events --all-namespaces --field-selector reason=FailedScheduling
```

### **2. Prometheus запросы для ресурсов:**
```bash
# Доступ к Prometheus для проверки метрик
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &

# Ключевые запросы:
# CPU утилизация кластера:
# 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory утилизация кластера:
# (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# CPU requests vs limits:
# sum(kube_pod_container_resource_requests{resource="cpu"}) / sum(kube_pod_container_resource_limits{resource="cpu"}) * 100

# Memory requests vs limits:
# sum(kube_pod_container_resource_requests{resource="memory"}) / sum(kube_pod_container_resource_limits{resource="memory"}) * 100
```

## 🏭 **Оптимизация в вашем HA кластере:**

### **1. ArgoCD оптимизация:**
```bash
# Проверка текущих ресурсов ArgoCD
kubectl get deployment argocd-server -n argocd -o yaml | grep -A 15 resources

# Рекомендуемая оптимизация ArgoCD Server
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server-optimized
  namespace: argocd
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-optimized
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-server-optimized
    spec:
      containers:
      - name: argocd-server
        image: quay.io/argoproj/argocd:latest
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values: ["argocd-server-optimized"]
              topologyKey: kubernetes.io/hostname
EOF

# Не применять в продакшене без тестирования!
kubectl delete deployment argocd-server-optimized -n argocd
```

### **2. Мониторинг стек оптимизация:**
```bash
# Проверка ресурсов Prometheus
kubectl describe deployment prometheus-server -n monitoring | grep -A 15 "Requests\|Limits"

# Проверка использования хранилища
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-server -n monitoring | grep -E "Capacity|Used"

# Оптимизация retention для Prometheus
kubectl get configmap prometheus-server -n monitoring -o yaml | grep retention
```

### **3. Load Balancer оптимизация:**
```bash
# NGINX Ingress Controller ресурсы
kubectl describe deployment ingress-nginx-controller -n ingress-nginx | grep -A 15 "Requests\|Limits"

# Мониторинг производительности Ingress
kubectl top pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep -E "upstream_response_time|request_time" | tail -10
```

## 🎯 **Best Practices для оптимизации ресурсов:**

### **1. Планирование ресурсов:**
- Анализируйте реальное использование перед установкой requests/limits
- Используйте профилирование приложений для точной настройки
- Мониторьте тренды использования ресурсов
- Применяйте постепенную оптимизацию

### **2. QoS стратегии:**
- **Guaranteed** для критически важных приложений (ArgoCD, мониторинг)
- **Burstable** для приложений с переменной нагрузкой
- **BestEffort** только для некритичных batch задач

### **3. Автомасштабирование:**
- Настройте HPA для динамических нагрузок
- Используйте VPA для рекомендаций по ресурсам
- Мониторьте эффективность автомасштабирования
- Настройте правильные метрики для scaling

### **4. Мониторинг и алерты:**
- Отслеживайте CPU/Memory утилизацию узлов
- Мониторьте QoS классы подов
- Настройте алерты на OOMKilled события
- Анализируйте эффективность использования ресурсов

**Эффективная оптимизация ресурсов — ключ к стабильной и экономичной работе Kubernetes кластера!**
