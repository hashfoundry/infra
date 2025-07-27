# 50. Как настроить автоматическое масштабирование (HPA) в Kubernetes?

## 🎯 **Horizontal Pod Autoscaler (HPA) в Kubernetes**

**HPA (Horizontal Pod Autoscaler)** автоматически масштабирует количество Pod'ов в Deployment, ReplicaSet или StatefulSet на основе наблюдаемых метрик CPU, памяти или пользовательских метрик. Это критически важно для обеспечения производительности и оптимизации ресурсов в production среде.

## 🏗️ **Основные компоненты HPA:**

### **1. Metrics Server:**
- **Сбор метрик**: CPU и память от kubelet
- **API метрик**: Предоставляет metrics.k8s.io API
- **Обязательный компонент**: Без него HPA не работает

### **2. HPA Controller:**
- **Мониторинг метрик**: Каждые 15 секунд (по умолчанию)
- **Принятие решений**: Увеличить/уменьшить количество Pod'ов
- **Алгоритм масштабирования**: На основе целевых значений метрик

### **3. Target Resources:**
- **Deployment**: Наиболее распространенный случай
- **StatefulSet**: Для stateful приложений
- **ReplicaSet**: Прямое управление репликами

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Установка и проверка Metrics Server:**
```bash
# Проверить, установлен ли Metrics Server
kubectl get deployment metrics-server -n kube-system

# Если не установлен, установить Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Для HA кластера может потребоваться дополнительная конфигурация
kubectl patch deployment metrics-server -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"]}]}}}}'

# Дождаться готовности
kubectl rollout status deployment/metrics-server -n kube-system

# Проверить работу metrics API
kubectl top nodes
kubectl top pods -A
```

### **2. Создание приложения для демонстрации HPA:**
```bash
# Создать namespace для демонстрации
kubectl create namespace hpa-demo

# Создать Deployment с resource requests (обязательно для HPA)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
  namespace: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
      - name: php-apache
        image: k8s.gcr.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m      # Обязательно для CPU-based HPA
            memory: 128Mi  # Обязательно для memory-based HPA
          limits:
            cpu: 500m
            memory: 256Mi
        env:
        - name: TARGET_CPU_UTILIZATION_PERCENTAGE
          value: "50"
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
  namespace: hpa-demo
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: php-apache
  type: ClusterIP
EOF

# Проверить развертывание
kubectl get deployment php-apache -n hpa-demo
kubectl get pods -n hpa-demo -l app=php-apache
kubectl get service php-apache -n hpa-demo
```

### **3. Создание базового CPU-based HPA:**
```bash
# Создать HPA с автоматическим масштабированием по CPU
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10 -n hpa-demo

# Альтернативно, создать через YAML
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # 50% CPU utilization
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 минут стабилизации перед scale down
      policies:
      - type: Percent
        value: 50    # Уменьшать не более чем на 50% за раз
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60   # 1 минута стабилизации перед scale up
      policies:
      - type: Percent
        value: 100   # Увеличивать не более чем на 100% за раз
        periodSeconds: 60
      - type: Pods
        value: 2     # Или максимум 2 Pod'а за раз
        periodSeconds: 60
      selectPolicy: Max  # Выбрать максимальное значение из политик
EOF

# Проверить статус HPA
kubectl get hpa php-apache-hpa -n hpa-demo
kubectl describe hpa php-apache-hpa -n hpa-demo
```

### **4. Создание Memory-based HPA:**
```bash
# Создать HPA с масштабированием по памяти
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: memory-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70  # 70% memory utilization
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 600  # 10 минут для памяти
    scaleUp:
      stabilizationWindowSeconds: 120  # 2 минуты для памяти
EOF

# Проверить HPA
kubectl get hpa memory-hpa -n hpa-demo -w
```

### **5. Комбинированный HPA (CPU + Memory):**
```bash
# Создать HPA с несколькими метриками
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: combined-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 2
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
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
        value: 25    # Более консервативное уменьшение
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50    # Умеренное увеличение
        periodSeconds: 60
      - type: Pods
        value: 3     # Максимум 3 Pod'а за раз
        periodSeconds: 60
      selectPolicy: Min  # Выбрать минимальное значение (более консервативно)
EOF

# Мониторинг комбинированного HPA
kubectl get hpa combined-hpa -n hpa-demo -o wide
```

## 🔧 **Advanced HPA конфигурации:**

### **1. HPA с пользовательскими метриками (Custom Metrics):**
```bash
# Создать приложение с пользовательскими метриками
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-metrics-app
  namespace: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-metrics-app
  template:
    metadata:
      labels:
        app: custom-metrics-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        - containerPort: 8080  # Metrics port
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        env:
        - name: CUSTOM_METRIC_TARGET
          value: "100"
---
apiVersion: v1
kind: Service
metadata:
  name: custom-metrics-service
  namespace: hpa-demo
spec:
  selector:
    app: custom-metrics-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 8080
    targetPort: 8080
EOF

# HPA с пользовательскими метриками (требует Prometheus Adapter)
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: custom-metrics-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: custom-metrics-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"  # 100 requests per second per pod
  - type: Object
    object:
      metric:
        name: queue_length
      describedObject:
        apiVersion: v1
        kind: Service
        name: message-queue
      target:
        type: Value
        value: "50"  # Queue length of 50
EOF
```

### **2. HPA для StatefulSet:**
```bash
# Создать StatefulSet для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-cluster
  namespace: hpa-demo
spec:
  serviceName: database-service
  replicas: 2
  selector:
    matchLabels:
      app: database-cluster
  template:
    metadata:
      labels:
        app: database-cluster
    spec:
      containers:
      - name: database
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: testdb
        - name: POSTGRES_USER
          value: testuser
        - name: POSTGRES_PASSWORD
          value: testpass
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
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
          storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: hpa-demo
spec:
  clusterIP: None
  selector:
    app: database-cluster
  ports:
  - port: 5432
    targetPort: 5432
EOF

# HPA для StatefulSet
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: database-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: database-cluster
  minReplicas: 2
  maxReplicas: 6
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
      stabilizationWindowSeconds: 900  # 15 минут для StatefulSet
      policies:
      - type: Pods
        value: 1     # По одному Pod'у за раз для StatefulSet
        periodSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 300  # 5 минут
      policies:
      - type: Pods
        value: 1     # По одному Pod'у за раз
        periodSeconds: 180
EOF
```

## 🧪 **Тестирование HPA:**

### **1. Создание нагрузки для тестирования:**
```bash
# Создать Pod для генерации нагрузки
kubectl run load-generator --rm -i --tty --image=busybox --restart=Never -n hpa-demo -- /bin/sh

# Внутри Pod'а выполнить:
while true; do wget -q -O- http://php-apache.hpa-demo.svc.cluster.local; done

# В другом терминале мониторить HPA
kubectl get hpa -n hpa-demo -w

# Мониторить Pod'ы
kubectl get pods -n hpa-demo -l app=php-apache -w

# Проверить метрики
kubectl top pods -n hpa-demo
```

### **2. Автоматизированный тест нагрузки:**
```bash
# Создать скрипт для автоматического тестирования
cat << 'EOF' > hpa-load-test.sh
#!/bin/bash

NAMESPACE="hpa-demo"
SERVICE="php-apache"
DURATION=600  # 10 minutes

echo "=== HPA Load Testing ==="
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE"
echo "Duration: ${DURATION}s"
echo

# Функция для мониторинга HPA
monitor_hpa() {
    while true; do
        echo "$(date): HPA Status"
        kubectl get hpa -n $NAMESPACE -o custom-columns="NAME:.metadata.name,TARGETS:.status.currentMetrics[*].resource.current.averageUtilization,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,REPLICAS:.status.currentReplicas"
        echo "$(date): Pod Status"
        kubectl get pods -n $NAMESPACE -l app=$SERVICE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CPU:.status.containerStatuses[0].restartCount"
        echo "---"
        sleep 30
    done
}

# Запустить мониторинг в фоне
monitor_hpa &
MONITOR_PID=$!

# Создать нагрузку
echo "Starting load generation..."
kubectl run load-generator-1 --image=busybox --restart=Never -n $NAMESPACE -- /bin/sh -c "while true; do for i in \$(seq 1 100); do wget -q -O- http://$SERVICE.$NAMESPACE.svc.cluster.local & done; sleep 1; done" &
kubectl run load-generator-2 --image=busybox --restart=Never -n $NAMESPACE -- /bin/sh -c "while true; do for i in \$(seq 1 100); do wget -q -O- http://$SERVICE.$NAMESPACE.svc.cluster.local & done; sleep 1; done" &

# Дождаться завершения теста
sleep $DURATION

# Остановить нагрузку
echo "Stopping load generation..."
kubectl delete pod load-generator-1 load-generator-2 -n $NAMESPACE --force --grace-period=0

# Остановить мониторинг
kill $MONITOR_PID

# Финальный статус
echo "=== Final HPA Status ==="
kubectl get hpa -n $NAMESPACE
kubectl describe hpa -n $NAMESPACE

echo "=== Final Pod Status ==="
kubectl get pods -n $NAMESPACE -l app=$SERVICE
EOF

chmod +x hpa-load-test.sh
./hpa-load-test.sh
```

### **3. Тестирование различных сценариев:**
```bash
# Создать comprehensive тест
cat << 'EOF' > comprehensive-hpa-test.sh
#!/bin/bash

NAMESPACE="hpa-demo"

echo "=== Comprehensive HPA Testing ==="
echo

# Тест 1: Постепенное увеличение нагрузки
test_gradual_load() {
    echo "=== Test 1: Gradual Load Increase ==="
    
    for load_level in 10 50 100 200; do
        echo "Setting load level to $load_level requests/second"
        
        # Создать нагрузку
        kubectl run load-test-$load_level --image=busybox --restart=Never -n $NAMESPACE -- /bin/sh -c "
        for i in \$(seq 1 $load_level); do
            wget -q -O- http://php-apache.$NAMESPACE.svc.cluster.local &
        done
        sleep 60
        " &
        
        # Мониторить 2 минуты
        for i in {1..4}; do
            echo "  $(date): Load $load_level - Iteration $i"
            kubectl get hpa -n $NAMESPACE -o custom-columns="NAME:.metadata.name,CPU:.status.currentMetrics[0].resource.current.averageUtilization,REPLICAS:.status.currentReplicas"
            kubectl top pods -n $NAMESPACE -l app=php-apache | head -5
            sleep 30
        done
        
        # Очистить нагрузку
        kubectl delete pod load-test-$load_level -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
        
        # Дождаться стабилизации
        echo "  Waiting for stabilization..."
        sleep 120
    done
}

# Тест 2: Spike нагрузка
test_spike_load() {
    echo "=== Test 2: Spike Load ==="
    
    # Создать внезапную высокую нагрузку
    for i in {1..5}; do
        kubectl run spike-load-$i --image=busybox --restart=Never -n $NAMESPACE -- /bin/sh -c "
        while true; do
            for j in \$(seq 1 500); do
                wget -q -O- http://php-apache.$NAMESPACE.svc.cluster.local &
            done
            sleep 1
        done
        " &
    done
    
    # Мониторить spike
    echo "Monitoring spike for 5 minutes..."
    for i in {1..10}; do
        echo "  $(date): Spike monitoring - Iteration $i"
        kubectl get hpa -n $NAMESPACE
        kubectl get pods -n $NAMESPACE -l app=php-apache --no-headers | wc -l
        sleep 30
    done
    
    # Остановить spike
    for i in {1..5}; do
        kubectl delete pod spike-load-$i -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
    done
    
    # Мониторить scale down
    echo "Monitoring scale down for 10 minutes..."
    for i in {1..20}; do
        echo "  $(date): Scale down monitoring - Iteration $i"
        kubectl get hpa -n $NAMESPACE -o custom-columns="NAME:.metadata.name,CPU:.status.currentMetrics[0].resource.current.averageUtilization,REPLICAS:.status.currentReplicas"
        sleep 30
    done
}

# Тест 3: Memory pressure
test_memory_pressure() {
    echo "=== Test 3: Memory Pressure ==="
    
    # Создать memory-intensive нагрузку
    kubectl run memory-pressure --image=progrium/stress --restart=Never -n $NAMESPACE -- --vm 1 --vm-bytes 100M --timeout 300s &
    
    # Мониторить memory HPA
    for i in {1..10}; do
        echo "  $(date): Memory pressure - Iteration $i"
        kubectl get hpa memory-hpa -n $NAMESPACE -o custom-columns="NAME:.metadata.name,MEMORY:.status.currentMetrics[0].resource.current.averageUtilization,REPLICAS:.status.currentReplicas"
        kubectl top pods -n $NAMESPACE -l app=php-apache
        sleep 30
    done
    
    # Очистить
    kubectl delete pod memory-pressure -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
}

# Выполнить все тесты
test_gradual_load
test_spike_load
test_memory_pressure

echo "=== Comprehensive Testing Complete ==="
kubectl get hpa -n $NAMESPACE
kubectl get pods -n $NAMESPACE
EOF

chmod +x comprehensive-hpa-test.sh
./comprehensive-hpa-test.sh
```

## 🚨 **Troubleshooting HPA:**

### **1. Диагностика проблем HPA:**
```bash
# Создать диагностический скрипт
cat << 'EOF' > diagnose-hpa.sh
#!/bin/bash

NAMESPACE="hpa-demo"

echo "=== HPA Diagnostics ==="
echo

# Проверить Metrics Server
echo "=== Metrics Server Status ==="
kubectl get deployment metrics-server -n kube-system
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Проверить metrics API
echo "=== Metrics API Availability ==="
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[].metadata.name' 2>/dev/null || echo "Metrics API not available"
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq '.items | length' 2>/dev/null || echo "Pod metrics not available"

# Проверить HPA статус
echo "=== HPA Status ==="
for hpa in $(kubectl get hpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
    echo "--- HPA: $hpa ---"
    kubectl describe hpa $hpa -n $NAMESPACE
    echo
done

# Проверить resource requests
echo "=== Resource Requests Check ==="
kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests}{"\n"}{end}'

# Проверить текущие метрики
echo "=== Current Metrics ==="
kubectl top pods -n $NAMESPACE
kubectl top nodes

# Проверить события
echo "=== Recent Events ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10

# Проверить HPA алгоритм
echo "=== HPA Algorithm Details ==="
for hpa in $(kubectl get hpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
    echo "--- HPA Algorithm for $hpa ---"
    kubectl get hpa $hpa -n $NAMESPACE -o jsonpath='{.status}' | jq '.'
    echo
done
EOF

chmod +x diagnose-hpa.sh
./diagnose-hpa.sh
```

### **2. Автоматическое исправление проблем:**
```bash
# Создать скрипт для автоматического исправления
cat << 'EOF' > fix-hpa-issues.sh
#!/bin/bash

NAMESPACE="hpa-demo"

echo "=== HPA Auto-Fix ==="
echo

# Исправление 1: Перезапуск Metrics Server
fix_metrics_server() {
    echo "=== Fixing Metrics Server ==="
    
    # Проверить статус
    if ! kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
        echo "Installing Metrics Server..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    fi
    
    # Перезапустить если не работает
    if ! kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" >/dev/null 2>&1; then
        echo "Restarting Metrics Server..."
        kubectl rollout restart deployment/metrics-server -n kube-system
        kubectl rollout status deployment/metrics-server -n kube-system
    fi
    
    # Дождаться готовности
    echo "Waiting for metrics to be available..."
    for i in {1..30}; do
        if kubectl top nodes >/dev/null 2>&1; then
            echo "Metrics Server is working"
            break
        fi
        echo "  Waiting... ($i/30)"
        sleep 10
    done
}

# Исправление 2: Проверка resource requests
fix_resource_requests() {
    echo "=== Fixing Resource Requests ==="
    
    # Найти Pod'ы без resource requests
    pods_without_requests=$(kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\n"}{end}' | grep -v "m$" | cut -f1)
    
    if [ -n "$pods_without_requests" ]; then
        echo "Found pods without resource requests:"
        echo "$pods_without_requests"
        
        # Добавить resource requests к Deployment'ам
        for deployment in $(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
            echo "Adding resource requests to deployment: $deployment"
            kubectl patch deployment $deployment -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"'$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].name}')'","resources":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"500m","memory":"256Mi"}}}]}}}}'
        done
    else
        echo "All pods have resource requests"
    fi
}

# Исправление 3: Сброс HPA
reset_hpa() {
    echo "=== Resetting HPA ==="
    
    for hpa in $(kubectl get hpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Resetting HPA: $hpa"
        
        # Получить текущую конфигурацию
        kubectl get hpa $hpa -n $NAMESPACE -o yaml > /tmp/hpa-$hpa.yaml
        
        # Удалить и пересоздать
        kubectl delete hpa $hpa -n $NAMESPACE
        sleep 5
        kubectl apply -f /tmp/hpa-$hpa.yaml
        
        # Очистить временный файл
        rm -f /tmp/hpa-$hpa.yaml
    done
}

# Исправление 4: Проверка и исправление поведения
fix_hpa_behavior() {
    echo "=== Fixing HPA Behavior ==="
    
    for hpa in $(kubectl get hpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Optimizing behavior for HPA: $hpa"
        
        # Добавить оптимальное поведение
        kubectl patch hpa $hpa -n $NAMESPACE --type='merge' -p='{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":300,"policies":[{"type":"Percent","value":50,"periodSeconds":60}]},"scaleUp":{"stabilizationWindowSeconds":60,"policies":[{"type":"Percent","value":100,"periodSeconds":60},{"type":"Pods","value":2,"periodSeconds":60}],"selectPolicy":"Max"}}}}'
    done
}

# Выполнить все исправления
fix_metrics_server
fix_resource_requests
reset_hpa
fix_hpa_behavior

echo "=== Auto-Fix Complete ==="
echo "Checking final status..."
kubectl get hpa -n $NAMESPACE
kubectl top pods -n $NAMESPACE
EOF

chmod +x fix-hpa-issues.sh
./fix-hpa-issues.sh
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все ресурсы HPA демонстрации
kubectl delete namespace hpa-demo

# Удалить скрипты
rm -f hpa-load-test.sh comprehensive-hpa-test.sh diagnose-hpa.sh fix-hpa-issues.sh
```

## 📋 **Сводка команд для HPA:**

### **Основные команды:**
```bash
# Создать HPA
kubectl autoscale deployment myapp --cpu-percent=50 --min=1 --max=10

# Проверить статус HPA
kubectl get hpa
kubectl describe hpa myapp

# Обновить HPA
kubectl patch hpa myapp -p '{"spec":{"maxReplicas":20}}'

# Удалить HPA
kubectl delete hpa myapp

# Мониторинг метрик
kubectl top nodes
kubectl top pods
```

### **Advanced команды:**
```bash
# Проверить metrics API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods"

# Проверить HPA алгоритм
kubectl get hpa myapp -o jsonpath='{.status.currentMetrics}'

# Установить поведение масштабирования
kubectl patch hpa myapp --type='merge' -p='{"spec":{"behavior":{"scaleUp":{"stabilizationWindowSeconds":60}}}}'
```

## 🎯 **Best Practices для HPA:**

### **1. Конфигурация ресурсов:**
- **Всегда устанавливайте** resource requests (обязательно для HPA)
- **Используйте реалистичные** resource limits
- **Тестируйте** resource requirements в staging среде

### **2. Настройка метрик:**
- **CPU**: 50-70% для большинства приложений
- **Memory**: 70-80% (более консервативно)
- **Custom metrics**: Специфичные для приложения

### **3. Поведение масштабирования:**
- **Scale up**: Быстрое реагирование (60-120 секунд)
- **Scale down**: Медленное и осторожное (300-600 секунд)
- **Используйте policies** для контроля скорости масштабирования

### **4. Мониторинг и алертинг:**
- **Настройте мониторинг** HPA событий
- **Создайте алерты** на частое масштабирование
- **Отслеживайте** эффективность масштабирования

**HPA является критически важным компонентом для обеспечения производительности и оптимизации ресурсов в production Kubernetes кластерах!**
