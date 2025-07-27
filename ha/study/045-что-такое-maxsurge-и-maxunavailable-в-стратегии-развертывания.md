# 45. Что такое maxSurge и maxUnavailable в стратегии развертывания?

## 🎯 **maxSurge и maxUnavailable в Kubernetes**

**maxSurge** и **maxUnavailable** — это ключевые параметры стратегии RollingUpdate, которые контролируют, как Kubernetes выполняет постепенное обновление приложений. Эти параметры определяют баланс между скоростью развертывания и доступностью сервиса.

## 🏗️ **Определения параметров:**

### **1. maxUnavailable:**
- **Определение**: Максимальное количество Pod'ов, которые могут быть недоступны во время обновления
- **Значения**: Абсолютное число (например, 2) или процент (например, 25%)
- **По умолчанию**: 25%
- **Влияние**: Контролирует минимальную доступность сервиса

### **2. maxSurge:**
- **Определение**: Максимальное количество дополнительных Pod'ов, которые могут быть созданы сверх желаемого количества реплик
- **Значения**: Абсолютное число (например, 2) или процент (например, 25%)
- **По умолчанию**: 25%
- **Влияние**: Контролирует скорость развертывания и потребление ресурсов

### **3. Математические ограничения:**
- **maxUnavailable** и **maxSurge** не могут быть одновременно равны 0
- Минимальное количество доступных Pod'ов = replicas - maxUnavailable
- Максимальное количество Pod'ов = replicas + maxSurge

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Базовая демонстрация параметров:**
```bash
# Создать namespace для демонстрации
kubectl create namespace surge-demo

# Deployment с различными настройками maxSurge и maxUnavailable
cat << EOF | kubectl apply -f -
# Консервативная стратегия (медленно, но безопасно)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: conservative-app
  namespace: surge-demo
  labels:
    strategy: conservative
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Только 1 Pod может быть недоступен
      maxSurge: 1           # Только 1 дополнительный Pod
  selector:
    matchLabels:
      app: conservative-app
  template:
    metadata:
      labels:
        app: conservative-app
        strategy: conservative
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
        env:
        - name: STRATEGY
          value: "conservative"
        - name: VERSION
          value: "1.0"
---
# Агрессивная стратегия (быстро, больше ресурсов)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggressive-app
  namespace: surge-demo
  labels:
    strategy: aggressive
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 3      # 50% Pod'ов могут быть недоступны
      maxSurge: 3           # 50% дополнительных Pod'ов
  selector:
    matchLabels:
      app: aggressive-app
  template:
    metadata:
      labels:
        app: aggressive-app
        strategy: aggressive
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
        env:
        - name: STRATEGY
          value: "aggressive"
        - name: VERSION
          value: "1.0"
---
# Сбалансированная стратегия
apiVersion: apps/v1
kind: Deployment
metadata:
  name: balanced-app
  namespace: surge-demo
  labels:
    strategy: balanced
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%    # 25% Pod'ов могут быть недоступны
      maxSurge: 25%         # 25% дополнительных Pod'ов
  selector:
    matchLabels:
      app: balanced-app
  template:
    metadata:
      labels:
        app: balanced-app
        strategy: balanced
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
        env:
        - name: STRATEGY
          value: "balanced"
        - name: VERSION
          value: "1.0"
EOF

# Проверить начальное состояние всех deployments
kubectl get deployments -n surge-demo
kubectl get pods -n surge-demo --show-labels
```

### **2. Сравнение поведения при обновлении:**
```bash
# Создать мониторинг скрипт для сравнения стратегий
cat << 'EOF' > compare-strategies.sh
#!/bin/bash

NAMESPACE="surge-demo"
DEPLOYMENTS=("conservative-app" "aggressive-app" "balanced-app")

echo "=== Comparing Rolling Update Strategies ==="
echo "Timestamp: $(date)"
echo

# Функция для мониторинга одного deployment
monitor_deployment() {
    local deployment=$1
    local duration=$2
    
    echo "=== Monitoring $deployment ==="
    
    for i in $(seq 1 $duration); do
        # Получить текущее состояние
        total=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')
        ready=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
        updated=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.updatedReplicas}')
        unavailable=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.unavailableReplicas}')
        
        # Подсчитать общее количество Pod'ов
        total_pods=$(kubectl get pods -n $NAMESPACE -l app=$deployment --no-headers | wc -l)
        
        echo "$(date '+%H:%M:%S') [$i/${duration}s] $deployment: Total Pods: $total_pods, Ready: ${ready:-0}/$total, Updated: ${updated:-0}, Unavailable: ${unavailable:-0}"
        
        # Проверить завершение
        if [ "${ready:-0}" = "$total" ] && [ "${updated:-0}" = "$total" ]; then
            echo "✅ $deployment rollout completed in ${i} seconds"
            return
        fi
        
        sleep 1
    done
    
    echo "⏰ $deployment monitoring timeout after $duration seconds"
}

# Запустить обновления одновременно
echo "Starting simultaneous updates..."
kubectl set image deployment/conservative-app web=nginx:1.21 -n $NAMESPACE &
kubectl set image deployment/aggressive-app web=nginx:1.21 -n $NAMESPACE &
kubectl set image deployment/balanced-app web=nginx:1.21 -n $NAMESPACE &

# Дать время на начало обновлений
sleep 2

# Мониторинг всех deployments параллельно
for deployment in "${DEPLOYMENTS[@]}"; do
    monitor_deployment $deployment 60 &
done

# Дождаться завершения всех мониторингов
wait

echo
echo "=== Final Status ==="
kubectl get deployments -n $NAMESPACE
kubectl get pods -n $NAMESPACE --show-labels
EOF

chmod +x compare-strategies.sh
./compare-strategies.sh
```

### **3. Детальный анализ влияния параметров:**
```bash
# Создать deployment с экстремальными настройками для демонстрации
cat << EOF | kubectl apply -f -
# Максимальная доступность (maxUnavailable: 0)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zero-downtime-app
  namespace: surge-demo
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0      # Никто не может быть недоступен
      maxSurge: 2           # Создаем дополнительные Pod'ы
  selector:
    matchLabels:
      app: zero-downtime-app
  template:
    metadata:
      labels:
        app: zero-downtime-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 2
---
# Минимальные ресурсы (maxSurge: 0)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-constrained-app
  namespace: surge-demo
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2      # Можем потерять половину
      maxSurge: 0           # Никаких дополнительных Pod'ов
  selector:
    matchLabels:
      app: resource-constrained-app
  template:
    metadata:
      labels:
        app: resource-constrained-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 2
EOF

# Дождаться готовности
kubectl rollout status deployment/zero-downtime-app -n surge-demo
kubectl rollout status deployment/resource-constrained-app -n surge-demo

# Демонстрация различий в поведении
echo "=== Zero Downtime Update (maxUnavailable: 0, maxSurge: 2) ==="
kubectl get pods -n surge-demo -l app=zero-downtime-app -w &
WATCH_PID1=$!

kubectl set image deployment/zero-downtime-app web=nginx:1.21 -n surge-demo
sleep 15
kill $WATCH_PID1

echo
echo "=== Resource Constrained Update (maxUnavailable: 2, maxSurge: 0) ==="
kubectl get pods -n surge-demo -l app=resource-constrained-app -w &
WATCH_PID2=$!

kubectl set image deployment/resource-constrained-app web=nginx:1.21 -n surge-demo
sleep 15
kill $WATCH_PID2
```

### **4. Процентные значения vs абсолютные числа:**
```bash
# Создать deployments с разными способами задания параметров
cat << EOF | kubectl apply -f -
# Процентные значения
apiVersion: apps/v1
kind: Deployment
metadata:
  name: percentage-app
  namespace: surge-demo
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 30%    # 3 Pod'а (30% от 10)
      maxSurge: 20%         # 2 Pod'а (20% от 10)
  selector:
    matchLabels:
      app: percentage-app
  template:
    metadata:
      labels:
        app: percentage-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 2
---
# Абсолютные значения
apiVersion: apps/v1
kind: Deployment
metadata:
  name: absolute-app
  namespace: surge-demo
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 3      # 3 Pod'а (абсолютное значение)
      maxSurge: 2           # 2 Pod'а (абсолютное значение)
  selector:
    matchLabels:
      app: absolute-app
  template:
    metadata:
      labels:
        app: absolute-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 2
EOF

# Сравнить поведение при разном количестве реплик
echo "=== Сравнение процентных и абсолютных значений ==="

# Масштабировать до разных размеров
kubectl scale deployment percentage-app --replicas=5 -n surge-demo
kubectl scale deployment absolute-app --replicas=5 -n surge-demo

echo "При 5 репликах:"
echo "Percentage app (30%/20%): maxUnavailable=1, maxSurge=1"
echo "Absolute app (3/2): maxUnavailable=3, maxSurge=2"

kubectl scale deployment percentage-app --replicas=20 -n surge-demo
kubectl scale deployment absolute-app --replicas=20 -n surge-demo

echo "При 20 репликах:"
echo "Percentage app (30%/20%): maxUnavailable=6, maxSurge=4"
echo "Absolute app (3/2): maxUnavailable=3, maxSurge=2"

# Проверить фактические значения
kubectl describe deployment percentage-app -n surge-demo | grep -A 5 "RollingUpdateStrategy"
kubectl describe deployment absolute-app -n surge-demo | grep -A 5 "RollingUpdateStrategy"
```

## 🔧 **Advanced сценарии использования:**

### **1. Оптимизация для разных типов приложений:**
```bash
# Web сервер (высокая доступность)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: surge-demo
  annotations:
    description: "High availability web server"
spec:
  replicas: 8
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Минимальная потеря доступности
      maxSurge: 2           # Быстрое обновление
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
          failureThreshold: 2
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
---
# Background worker (можно терпеть простои)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: background-worker
  namespace: surge-demo
  annotations:
    description: "Background processing worker"
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 50%    # Можем потерять половину
      maxSurge: 0           # Экономим ресурсы
  selector:
    matchLabels:
      app: background-worker
  template:
    metadata:
      labels:
        app: background-worker
        tier: worker
    spec:
      containers:
      - name: worker
        image: busybox:1.35
        command: ["sleep", "3600"]
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
# API сервис (критичная доступность)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: surge-demo
  annotations:
    description: "Critical API service"
spec:
  replicas: 12
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0      # Zero downtime
      maxSurge: 3           # Быстрое обновление
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        tier: api
    spec:
      containers:
      - name: api
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 2
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 15
EOF

# Проверить различные стратегии
kubectl get deployments -n surge-demo -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas,MAX_UNAVAILABLE:.spec.strategy.rollingUpdate.maxUnavailable,MAX_SURGE:.spec.strategy.rollingUpdate.maxSurge,DESCRIPTION:.metadata.annotations.description
```

### **2. Тестирование граничных случаев:**
```bash
# Создать deployment для тестирования edge cases
cat << EOF | kubectl apply -f -
# Минимальный deployment (1 реплика)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: single-replica
  namespace: surge-demo
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0      # Должен создать дополнительный Pod
      maxSurge: 1
  selector:
    matchLabels:
      app: single-replica
  template:
    metadata:
      labels:
        app: single-replica
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 2
---
# Большой deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: large-deployment
  namespace: surge-demo
spec:
  replicas: 50
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 10%    # 5 Pod'ов
      maxSurge: 20%         # 10 Pod'ов
  selector:
    matchLabels:
      app: large-deployment
  template:
    metadata:
      labels:
        app: large-deployment
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 2
EOF

# Тестирование single replica deployment
echo "=== Testing Single Replica Deployment ==="
kubectl get pods -n surge-demo -l app=single-replica -w &
WATCH_PID=$!

kubectl set image deployment/single-replica web=nginx:1.21 -n surge-demo
sleep 10
kill $WATCH_PID

echo "Single replica должен создать временный дополнительный Pod для zero downtime"

# Тестирование large deployment
echo "=== Testing Large Deployment ==="
kubectl rollout status deployment/large-deployment -n surge-demo
kubectl set image deployment/large-deployment web=nginx:1.21 -n surge-demo

# Мониторинг большого deployment
kubectl rollout status deployment/large-deployment -n surge-demo
```

### **3. Влияние на производительность и ресурсы:**
```bash
# Создать скрипт для анализа потребления ресурсов
cat << 'EOF' > resource-analysis.sh
#!/bin/bash

NAMESPACE="surge-demo"

echo "=== Resource Usage Analysis ==="
echo "Timestamp: $(date)"
echo

# Функция для получения resource usage
get_resource_usage() {
    local app_label=$1
    
    echo "=== $app_label Resource Usage ==="
    
    # Количество Pod'ов
    pod_count=$(kubectl get pods -n $NAMESPACE -l app=$app_label --no-headers | wc -l)
    
    # CPU и Memory requests/limits
    cpu_requests=$(kubectl get pods -n $NAMESPACE -l app=$app_label -o jsonpath='{.items[*].spec.containers[*].resources.requests.cpu}' | tr ' ' '\n' | grep -v '^$' | sed 's/m$//' | awk '{sum += $1} END {print sum "m"}')
    memory_requests=$(kubectl get pods -n $NAMESPACE -l app=$app_label -o jsonpath='{.items[*].spec.containers[*].resources.requests.memory}' | tr ' ' '\n' | grep -v '^$' | sed 's/Mi$//' | awk '{sum += $1} END {print sum "Mi"}')
    
    echo "Pod Count: $pod_count"
    echo "Total CPU Requests: $cpu_requests"
    echo "Total Memory Requests: $memory_requests"
    
    # Deployment конфигурация
    replicas=$(kubectl get deployment $app_label -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    max_unavailable=$(kubectl get deployment $app_label -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')
    max_surge=$(kubectl get deployment $app_label -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}')
    
    echo "Configured Replicas: $replicas"
    echo "Max Unavailable: $max_unavailable"
    echo "Max Surge: $max_surge"
    
    # Расчет максимального потребления ресурсов во время rollout
    if [[ $max_surge =~ % ]]; then
        surge_pods=$(echo "$replicas * ${max_surge%\%} / 100" | bc)
    else
        surge_pods=$max_surge
    fi
    
    max_pods=$((replicas + surge_pods))
    echo "Maximum Pods during rollout: $max_pods"
    echo "Resource overhead during rollout: +${surge_pods} pods"
    echo
}

# Анализ всех deployments
for app in conservative-app aggressive-app balanced-app zero-downtime-app resource-constrained-app; do
    if kubectl get deployment $app -n $NAMESPACE >/dev/null 2>&1; then
        get_resource_usage $app
    fi
done

# Общая статистика по namespace
echo "=== Namespace Total Resources ==="
total_pods=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
echo "Total Pods in namespace: $total_pods"

# Resource quotas (если установлены)
kubectl describe namespace $NAMESPACE | grep -A 10 "Resource Quotas" || echo "No resource quotas set"
EOF

chmod +x resource-analysis.sh
./resource-analysis.sh
```

## 🚨 **Troubleshooting и оптимизация:**

### **1. Диагностика проблем с параметрами:**
```bash
# Создать проблемный deployment для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problematic-surge
  namespace: surge-demo
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 3      # Все Pod'ы могут быть недоступны
      maxSurge: 0           # Никаких дополнительных Pod'ов
  selector:
    matchLabels:
      app: problematic-surge
  template:
    metadata:
      labels:
        app: problematic-surge
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /nonexistent  # Неправильный путь для демонстрации
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 2
EOF

# Попытка обновления проблемного deployment
kubectl set image deployment/problematic-surge web=nginx:1.21 -n surge-demo

# Диагностика проблем
echo "=== Диагностика проблем с maxSurge/maxUnavailable ==="
kubectl rollout status deployment/problematic-surge -n surge-demo --timeout=30s
kubectl describe deployment problematic-surge -n surge-demo
kubectl get pods -n surge-demo -l app=problematic-surge

# Исправление проблемы
kubectl patch deployment problematic-surge -n surge-demo -p '{"spec":{"strategy":{"rollingUpdate":{"maxUnavailable":1,"maxSurge":1}},"template":{"spec":{"containers":[{"name":"web","readinessProbe":{"httpGet":{"path":"/"}}}]}}}}'

kubectl rollout status deployment/problematic-surge -n surge-demo
```

### **2. Оптимизация параметров для разных сценариев:**
```bash
# Создать скрипт для рекомендаций по оптимизации
cat << 'EOF' > optimize-parameters.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 <namespace> <deployment>"
    exit 1
fi

echo "=== Optimization Recommendations ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo

# Получить текущие параметры
replicas=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
max_unavailable=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')
max_surge=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}')

echo "Current Configuration:"
echo "  Replicas: $replicas"
echo "  maxUnavailable: $max_unavailable"
echo "  maxSurge: $max_surge"
echo

# Анализ и рекомендации
echo "Analysis and Recommendations:"

# Проверка на критичность сервиса
if [ "$max_unavailable" = "0" ]; then
    echo "✅ Zero downtime configuration detected"
    echo "   Good for: Critical production services"
    echo "   Trade-off: Higher resource usage during rollouts"
elif [[ $max_unavailable =~ % ]] && [ "${max_unavailable%\%}" -gt 50 ]; then
    echo "⚠️  High unavailability tolerance detected (>50%)"
    echo "   Good for: Background services, batch jobs"
    echo "   Risk: Significant service degradation during rollouts"
else
    echo "✅ Balanced unavailability configuration"
fi

# Проверка surge настроек
if [ "$max_surge" = "0" ]; then
    echo "💰 Resource-constrained configuration detected"
    echo "   Good for: Limited resource environments"
    echo "   Trade-off: Slower rollouts"
elif [[ $max_surge =~ % ]] && [ "${max_surge%\%}" -gt 50 ]; then
    echo "🚀 Fast rollout configuration detected"
    echo "   Good for: Development environments, fast iterations"
    echo "   Trade-off: Higher resource usage"
else
    echo "✅ Balanced surge configuration"
fi

# Рекомендации по типу приложения
echo
echo "Recommendations by Application Type:"
echo
echo "🌐 Web Frontend (High Availability):"
echo "   maxUnavailable: 1 or 10%"
echo "   maxSurge: 1 or 25%"
echo
echo "🔧 API Service (Critical):"
echo "   maxUnavailable: 0"
echo "   maxSurge: 2 or 25%"
echo
echo "⚙️  Background Worker (Fault Tolerant):"
echo "   maxUnavailable: 50%"
echo "   maxSurge: 0"
echo
echo "🧪 Development/Testing:"
echo "   maxUnavailable: 50%"
echo "   maxSurge: 50%"

# Расчет времени rollout
echo
echo "Estimated Rollout Characteristics:"
if [[ $max_unavailable =~ % ]]; then
    unavailable_pods=$(echo "$replicas * ${max_unavailable%\%} / 100" | bc)
else
    unavailable_pods=$max_unavailable
fi

if [[ $max_surge =~ % ]]; then
    surge_pods=$(echo "$replicas * ${max_surge%\%} / 100" | bc)
else
    surge_pods=$max_surge
fi

min_available=$((replicas - unavailable_pods))
max_total=$((replicas + surge_pods))

echo "Minimum available pods during rollout: $min_available"
echo "Maximum total pods during rollout: $max_total"
echo "Service availability: $(echo "scale=1; $min_available * 100 / $replicas" | bc)%"
EOF

chmod +x optimize-parameters.sh

# Пример использования
# ./optimize-parameters.sh surge-demo conservative-app
```

### **3. Автоматическая настройка параметров:**
```bash
# Создать скрипт для автоматической оптимизации
cat << 'EOF' > auto-optimize.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"
APP_TYPE="$3"  # web, api, worker, dev

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ] || [ -z "$APP_TYPE" ]; then
    echo "Usage: $0 <namespace> <deployment> <app_type>"
    echo "App types: web, api, worker, dev"
    exit 1
fi

echo "=== Auto-Optimization for $APP_TYPE application ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo

# Получить текущее количество реплик
replicas=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
echo "Current replicas: $replicas"

# Определить оптимальные параметры по типу приложения
case $APP_TYPE in
    "web")
        max_unavailable="1"
        max_surge="25%"
        description="High availability web frontend"
        ;;
    "api")
        max_unavailable="0"
        max_surge="2"
        description="Critical API service with zero downtime"
        ;;
    "worker")
        max_unavailable="50%"
        max_surge="0"
        description="Background worker with resource constraints"
        ;;
    "dev")
        max_unavailable="50%"
        max_surge="50%"
        description="Development environment with fast rollouts"
        ;;
    *)
        echo "Unknown app type: $APP_TYPE"
        exit 1
        ;;
esac

echo "Recommended settings for $APP_TYPE:"
echo "  maxUnavailable: $max_unavailable"
echo "  maxSurge: $max_surge"
echo "  Description: $description"
echo

# Применить оптимизацию
read -p "Apply these settings? (y/N): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p "{
        \"spec\": {
            \"strategy\": {
                \"rollingUpdate\": {
                    \"maxUnavailable\": \"$max_unavailable\",
                    \"maxSurge\": \"$max_surge\"
                }
            }
        },
        \"metadata\": {
            \"annotations\": {
                \"app-type\": \"$APP_TYPE\",
                \"optimization-date\": \"$(date)\",
                \"description\": \"$description\"
            }
        }
    }"
    
    echo "✅ Optimization applied successfully!"
    kubectl describe deployment $DEPLOYMENT -n $NAMESPACE | grep -A 5 "RollingUpdateStrategy"
else
    echo "Optimization cancelled"
fi
EOF

chmod +x auto-optimize.sh

# Примеры использования
# ./auto-optimize.sh surge-demo web-server web
# ./auto-optimize.sh surge-demo api-service api
# ./auto-optimize.sh surge-demo background-worker worker
```

## 📊 **Мониторинг и метрики:**

### **1. Создание dashboard для мониторинга rollouts:**
```bash
# Создать мониторинг Pod для отслеживания rollouts
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rollout-monitor
  namespace: surge-demo
  labels:
    app: rollout-monitor
spec:
  containers:
  - name: monitor
    image: curlimages/curl
    command: ["sleep", "3600"]
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  restartPolicy: Always
EOF

# Создать comprehensive мониторинг скрипт
cat << 'EOF' > rollout-dashboard.sh
#!/bin/bash

NAMESPACE="surge-demo"

echo "=== Kubernetes Rollout Dashboard ==="
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo "========================================"
echo

# Функция для отображения статуса deployment
show_deployment_status() {
    local deployment=$1
    
    # Получить основную информацию
    replicas=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "N/A")
    ready=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    updated=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.updatedReplicas}' 2>/dev/null || echo "0")
    unavailable=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.unavailableReplicas}' 2>/dev/null || echo "0")
    
    # Получить стратегию
    max_unavailable=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null || echo "N/A")
    max_surge=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null || echo "N/A")
    
    # Получить текущее количество Pod'ов
    total_pods=$(kubectl get pods -n $NAMESPACE -l app=$deployment --no-headers 2>/dev/null | wc -l)
    
    # Статус rollout
    rollout_status="Unknown"
    if kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=1s >/dev/null 2>&1; then
        rollout_status="✅ Complete"
    else
        rollout_status="🔄 In Progress"
    fi
    
    # Вычислить доступность
    if [ "$replicas" != "N/A" ] && [ "$replicas" -gt 0 ]; then
        availability=$(echo "scale=1; ${ready:-0} * 100 / $replicas" | bc)
    else
        availability="N/A"
    fi
    
    printf "%-20s | %2s/%-2s | %2s | %2s | %3s | %-12s | %-12s | %-15s | %s%%\n" \
        "$deployment" "$ready" "$replicas" "$updated" "$unavailable" "$total_pods" \
        "$max_unavailable" "$max_surge" "$rollout_status" "$availability"
}

# Заголовок таблицы
printf "%-20s | %-5s | %-2s | %-2s | %-3s | %-12s | %-12s | %-15s | %s\n" \
    "DEPLOYMENT" "READY" "UP" "UN" "TOT" "MAX_UNAVAIL" "MAX_SURGE" "STATUS" "AVAIL%"
echo "-------------------|-------|----|----|-----|--------------|--------------|-----------------|-------"

# Показать статус всех deployments
for deployment in $(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    show_deployment_status $deployment
done

echo
echo "Legend:"
echo "  READY: Ready/Total replicas"
echo "  UP: Updated replicas"
echo "  UN: Unavailable replicas"
echo "  TOT: Total pods (including surge)"
echo "  AVAIL%: Service availability percentage"
echo

# Показать недавние события
echo "=== Recent Events ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10

echo
echo "=== Resource Usage Summary ==="
kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"
EOF

chmod +x rollout-dashboard.sh
./rollout-dashboard.sh
```

### **2. Создание алертов для проблемных rollouts:**
```bash
# Создать скрипт для мониторинга проблемных rollouts
cat << 'EOF' > rollout-alerts.sh
#!/bin/bash

NAMESPACE="surge-demo"
ALERT_THRESHOLD=300  # 5 минут

echo "=== Rollout Alert Monitor ==="
echo "Namespace: $NAMESPACE"
echo "Alert threshold: $ALERT_THRESHOLD seconds"
echo

check_deployment_health() {
    local deployment=$1
    local issues=()
    
    # Получить информацию о deployment
    replicas=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    ready=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    updated=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.updatedReplicas}')
    unavailable=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.unavailableReplicas}')
    
    # Проверить rollout статус
    if ! kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=5s >/dev/null 2>&1; then
        # Получить время последнего обновления
        last_update=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
        
        # Проверить, как долго идет rollout
        creation_time=$(kubectl get rs -n $NAMESPACE -l app=$deployment -o jsonpath='{.items[0].metadata.creationTimestamp}')
        current_time=$(date -u +%s)
        
        if [ -n "$creation_time" ]; then
            creation_timestamp=$(date -d "$creation_time" +%s 2>/dev/null || echo $current_time)
            duration=$((current_time - creation_timestamp))
            
            if [ $duration -gt $ALERT_THRESHOLD ]; then
                issues+=("🚨 ALERT: Rollout stuck for ${duration}s (threshold: ${ALERT_THRESHOLD}s)")
            fi
        fi
        
        # Проверить конкретные проблемы
        if [ "${ready:-0}" -lt "$replicas" ]; then
            issues+=("⚠️  WARNING: Only ${ready:-0}/$replicas pods ready")
        fi
        
        if [ "${unavailable:-0}" -gt 0 ]; then
            issues+=("⚠️  WARNING: ${unavailable} pods unavailable")
        fi
        
        # Проверить Pod'ы в состоянии ошибки
        failed_pods=$(kubectl get pods -n $NAMESPACE -l app=$deployment --field-selector=status.phase=Failed --no-headers | wc -l)
        if [ "$failed_pods" -gt 0 ]; then
            issues+=("❌ ERROR: $failed_pods failed pods")
        fi
        
        pending_pods=$(kubectl get pods -n $NAMESPACE -l app=$deployment --field-selector=status.phase=Pending --no-headers | wc -l)
        if [ "$pending_pods" -gt 0 ]; then
            issues+=("⏳ WARNING: $pending_pods pending pods")
        fi
    fi
    
    # Вывести результаты
    if [ ${#issues[@]} -gt 0 ]; then
        echo "🔍 $deployment:"
        for issue in "${issues[@]}"; do
            echo "   $issue"
        done
        
        # Показать детали проблемных Pod'ов
        echo "   Pod details:"
        kubectl get pods -n $NAMESPACE -l app=$deployment -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount | grep -v "Running.*true" || echo "   No problematic pods found"
        echo
        
        return 1
    else
        echo "✅ $deployment: Healthy"
        return 0
    fi
}

# Проверить все deployments
alert_count=0
for deployment in $(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
    if ! check_deployment_health $deployment; then
        alert_count=$((alert_count + 1))
    fi
done

echo
if [ $alert_count -gt 0 ]; then
    echo "🚨 SUMMARY: $alert_count deployment(s) have issues!"
    exit 1
else
    echo "✅ SUMMARY: All deployments are healthy"
    exit 0
fi
EOF

chmod +x rollout-alerts.sh
./rollout-alerts.sh
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все deployments
kubectl delete deployments --all -n surge-demo

# Удалить все pods
kubectl delete pods --all -n surge-demo

# Удалить namespace
kubectl delete namespace surge-demo

# Удалить скрипты
rm -f compare-strategies.sh resource-analysis.sh optimize-parameters.sh auto-optimize.sh rollout-dashboard.sh rollout-alerts.sh
```

## 📋 **Сводная таблица рекомендаций:**

| Тип приложения | maxUnavailable | maxSurge | Обоснование |
|----------------|----------------|----------|-------------|
| **Web Frontend** | 1 или 10% | 1 или 25% | Высокая доступность, умеренная скорость |
| **API Service** | 0 | 2 или 25% | Zero downtime, быстрое обновление |
| **Background Worker** | 50% | 0 | Экономия ресурсов, простои допустимы |
| **Database** | 1 | 0 | Консервативный подход, данные критичны |
| **Cache Service** | 25% | 25% | Сбалансированный подход |
| **Development** | 50% | 50% | Быстрые итерации, доступность не критична |
| **Single Replica** | 0 | 1 | Обязательно для zero downtime |

## 🎯 **Ключевые принципы оптимизации:**

### **1. Для Production:**
- **Критичные сервисы**: maxUnavailable: 0, maxSurge: 25%
- **Обычные сервисы**: maxUnavailable: 1, maxSurge: 1
- **Всегда тестируйте** настройки в staging среде

### **2. Для Resource-constrained сред:**
- **Минимизируйте maxSurge** для экономии ресурсов
- **Увеличьте maxUnavailable** если допустимы простои
- **Используйте абсолютные значения** для предсказуемости

### **3. Для Development:**
- **Максимизируйте оба параметра** для быстрых rollouts
- **Используйте процентные значения** для гибкости
- **Автоматизируйте** процесс оптимизации

### **4. Мониторинг и алерты:**
- **Отслеживайте время rollout** и устанавливайте пороги
- **Мониторьте доступность сервиса** во время обновлений
- **Настройте автоматические алерты** для stuck rollouts
- **Ведите метрики** успешности rollouts

**Правильная настройка maxSurge и maxUnavailable критически важна для обеспечения баланса между скоростью развертывания, доступностью сервиса и потреблением ресурсов!**
