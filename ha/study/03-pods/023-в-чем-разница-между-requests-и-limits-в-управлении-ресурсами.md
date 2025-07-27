# 23. В чем разница между requests и limits в управлении ресурсами?

## 🎯 **Что такое Resource Requests и Limits?**

**Resource Requests** и **Limits** — это механизмы Kubernetes для управления ресурсами контейнеров. Requests определяют минимальные гарантированные ресурсы, а Limits устанавливают максимальные ограничения.

## 🏗️ **Основные различия:**

### **Requests (Запросы)**
- Минимальные гарантированные ресурсы
- Используются Scheduler'ом для размещения Pod'ов
- Резервируются на Node для контейнера
- Влияют на QoS класс Pod'а

### **Limits (Ограничения)**
- Максимальные доступные ресурсы
- Контейнер не может превысить эти значения
- При превышении memory limit - Pod убивается (OOMKilled)
- При превышении CPU limit - процесс throttling

## 📊 **Практические примеры из вашего HA кластера:**

### **1. ArgoCD ресурсы:**
```bash
# Проверить requests и limits ArgoCD компонентов
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 10 "Requests:\|Limits:"

# Подробная информация о ресурсах
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}  {.name}: requests={.resources.requests} limits={.resources.limits}{"\n"}{end}{"\n"}{end}'

# Использование ресурсов ArgoCD Pod'ов
kubectl top pods -n argocd
```

### **2. Мониторинг ресурсы:**
```bash
# Prometheus ресурсы
kubectl describe pod -n monitoring -l app=prometheus | grep -A 10 "Requests:\|Limits:"

# Grafana ресурсы
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep -A 10 "Requests:\|Limits:"

# Общее использование ресурсов в monitoring namespace
kubectl top pods -n monitoring
```

### **3. Создание Pod'а с requests и limits:**
```bash
# Pod с четко определенными ресурсами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: cpu-memory-demo
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    ports:
    - containerPort: 80
EOF

# Проверить размещение Pod'а
kubectl describe pod resource-demo | grep -A 15 "Requests:\|Limits:"

# Использование ресурсов
kubectl top pod resource-demo

# Очистка
kubectl delete pod resource-demo
```

## 🔄 **Типы ресурсов:**

### **1. CPU Resources:**
```bash
# CPU измеряется в millicores (m)
# 1000m = 1 CPU core
# 500m = 0.5 CPU core
# 100m = 0.1 CPU core

# Pod с CPU ресурсами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-demo
spec:
  containers:
  - name: cpu-test
    image: nginx
    resources:
      requests:
        cpu: "100m"    # Минимум 0.1 CPU
      limits:
        cpu: "200m"    # Максимум 0.2 CPU
EOF

kubectl describe pod cpu-demo | grep -A 5 "Requests:\|Limits:"
kubectl delete pod cpu-demo
```

### **2. Memory Resources:**
```bash
# Memory измеряется в байтах
# Ki, Mi, Gi - binary units (1024-based)
# K, M, G - decimal units (1000-based)

# Pod с Memory ресурсами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-demo
spec:
  containers:
  - name: memory-test
    image: nginx
    resources:
      requests:
        memory: "64Mi"   # Минимум 64 MiB
      limits:
        memory: "128Mi"  # Максимум 128 MiB
EOF

kubectl describe pod memory-demo | grep -A 5 "Requests:\|Limits:"
kubectl delete pod memory-demo
```

### **3. Ephemeral Storage:**
```bash
# Временное хранилище для контейнера
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo
spec:
  containers:
  - name: storage-test
    image: nginx
    resources:
      requests:
        ephemeral-storage: "1Gi"
      limits:
        ephemeral-storage: "2Gi"
EOF

kubectl describe pod storage-demo | grep -A 5 "Requests:\|Limits:"
kubectl delete pod storage-demo
```

## 🔧 **Демонстрация поведения ресурсов:**

### **1. CPU Throttling:**
```bash
# Pod с низким CPU limit для демонстрации throttling
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-throttle-demo
spec:
  containers:
  - name: cpu-stress
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Starting CPU intensive task..."
      # Создаем нагрузку на CPU
      while true; do
        echo "CPU working..." > /dev/null
      done
    resources:
      requests:
        cpu: "100m"
      limits:
        cpu: "200m"  # Низкий limit для демонстрации
EOF

# Мониторить использование CPU
kubectl top pod cpu-throttle-demo

# CPU будет ограничен до 200m даже при высокой нагрузке
kubectl delete pod cpu-throttle-demo
```

### **2. Memory OOMKilled:**
```bash
# Pod который превысит memory limit
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-oom-demo
spec:
  containers:
  - name: memory-hog
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Allocating memory..."
      # Попытка выделить больше памяти чем limit
      dd if=/dev/zero of=/tmp/memory.dat bs=1M count=200
      sleep 3600
    resources:
      requests:
        memory: "64Mi"
      limits:
        memory: "128Mi"  # Меньше чем пытаемся выделить
EOF

# Pod будет убит с OOMKilled
kubectl get pod memory-oom-demo -w

# Проверить причину завершения
kubectl describe pod memory-oom-demo | grep -A 5 "Last State:"

kubectl delete pod memory-oom-demo
```

### **3. Requests vs Limits поведение:**
```bash
# Pod с разными requests и limits
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: requests-limits-demo
spec:
  containers:
  - name: flexible-resources
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"  # В 4 раза больше requests
        cpu: "500m"      # В 5 раз больше requests
EOF

# Pod может использовать от requests до limits
kubectl top pod requests-limits-demo

# Scheduler гарантирует только requests
kubectl describe pod requests-limits-demo | grep -A 10 "Requests:\|Limits:"

kubectl delete pod requests-limits-demo
```

## 📈 **Мониторинг ресурсов:**

### **1. Использование ресурсов Node'ов:**
```bash
# Общее использование ресурсов Node'ов
kubectl top nodes

# Подробная информация о ресурсах Node'ов
kubectl describe nodes | grep -A 10 "Allocated resources:"

# Requests и limits по Node'ам
kubectl describe nodes | grep -E "(Requests|Limits):" -A 2
```

### **2. Метрики в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики ресурсов:
# container_memory_usage_bytes - фактическое использование памяти
# container_cpu_usage_seconds_total - использование CPU
# kube_pod_container_resource_requests - requests контейнеров
# kube_pod_container_resource_limits - limits контейнеров
# container_memory_working_set_bytes - рабочий набор памяти
```

### **3. Resource Quotas:**
```bash
# Проверить Resource Quotas в namespace'ах
kubectl get resourcequotas -A

# Подробная информация о квотах
kubectl describe resourcequota -n <namespace>

# Создать Resource Quota для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-quota
  namespace: default
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
EOF

kubectl describe resourcequota demo-quota
kubectl delete resourcequota demo-quota
```

## 🏭 **Production примеры:**

### **1. Deployment с ресурсами:**
```bash
# Production Deployment с правильными ресурсами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: production-app
  template:
    metadata:
      labels:
        app: production-app
    spec:
      containers:
      - name: web-app
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
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
EOF

# Проверить ресурсы всех Pod'ов
kubectl get pods -l app=production-app
kubectl top pods -l app=production-app

# Общее использование ресурсов Deployment'ом
kubectl describe deployment production-app | grep -A 10 "Requests:\|Limits:"

# Очистка
kubectl delete deployment production-app
```

### **2. StatefulSet с ресурсами:**
```bash
# StatefulSet с градуированными ресурсами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-statefulset
spec:
  serviceName: database-service
  replicas: 2
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: database
        image: nginx  # В реальности - образ БД
        ports:
        - containerPort: 5432
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
EOF

kubectl get statefulset database-statefulset
kubectl top pods -l app=database

# Очистка
kubectl delete statefulset database-statefulset
kubectl delete pvc data-database-statefulset-0 data-database-statefulset-1
```

## 🚨 **Проблемы с ресурсами:**

### **1. Pod не может быть запланирован:**
```bash
# Pod с слишком большими requests
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unschedulable-pod
spec:
  containers:
  - name: resource-hungry
    image: nginx
    resources:
      requests:
        memory: "100Gi"  # Больше чем доступно на Node
        cpu: "50"        # Больше чем доступно на Node
EOF

# Pod останется в состоянии Pending
kubectl get pod unschedulable-pod

# Причина в событиях
kubectl describe pod unschedulable-pod | grep -A 5 "Events:"

kubectl delete pod unschedulable-pod
```

### **2. Отладка OOMKilled:**
```bash
# Проверить Pod'ы с OOMKilled
kubectl get pods --field-selector=status.phase=Failed

# Подробная информация о причине завершения
kubectl describe pod <pod-name> | grep -A 10 "Last State:"

# Предыдущие логи Pod'а
kubectl logs <pod-name> --previous
```

### **3. CPU Throttling анализ:**
```bash
# Метрики throttling в Prometheus
# container_cpu_cfs_throttled_seconds_total - время throttling
# rate(container_cpu_cfs_throttled_seconds_total[5m]) - частота throttling

# Проверить текущее использование vs limits
kubectl top pods --containers
```

## 🎯 **QoS Classes:**

### **1. Guaranteed QoS:**
```bash
# Pod с Guaranteed QoS (requests = limits)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-qos
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"  # Равно requests
        cpu: "100m"      # Равно requests
EOF

kubectl describe pod guaranteed-qos | grep "QoS Class:"
kubectl delete pod guaranteed-qos
```

### **2. Burstable QoS:**
```bash
# Pod с Burstable QoS (requests < limits)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: burstable-qos
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"  # Больше requests
        cpu: "200m"      # Больше requests
EOF

kubectl describe pod burstable-qos | grep "QoS Class:"
kubectl delete pod burstable-qos
```

### **3. BestEffort QoS:**
```bash
# Pod с BestEffort QoS (без requests и limits)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-qos
spec:
  containers:
  - name: app
    image: nginx
    # Нет resources секции
EOF

kubectl describe pod besteffort-qos | grep "QoS Class:"
kubectl delete pod besteffort-qos
```

## 🔄 **Best Practices:**

### **1. Правильное планирование ресурсов:**
- Всегда устанавливайте requests для production
- Limits должны быть разумными (не слишком низкими)
- Мониторьте фактическое использование
- Используйте Vertical Pod Autoscaler для оптимизации

### **2. CPU ресурсы:**
- Requests: базовая потребность приложения
- Limits: пиковая нагрузка + буфер
- Избегайте слишком низких CPU limits
- Мониторьте CPU throttling

### **3. Memory ресурсы:**
- Requests: минимальная память для работы
- Limits: максимальная память + буфер для пиков
- Учитывайте memory leaks
- Мониторьте OOMKilled события

### **4. Мониторинг и алерты:**
- Настройте алерты на высокое использование ресурсов
- Мониторьте CPU throttling
- Отслеживайте OOMKilled события
- Анализируйте trends использования ресурсов

**Правильное управление ресурсами обеспечивает стабильность и эффективность кластера!**
