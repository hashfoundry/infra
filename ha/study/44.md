# 44. Как выполнить rolling update и rollback?

## 🎯 **Rolling Update и Rollback в Kubernetes**

**Rolling Update** — это процесс постепенного обновления приложения без простоя, при котором старые Pod'ы заменяются новыми по одному или небольшими группами. **Rollback** — это откат к предыдущей версии приложения в случае проблем с новой версией.

## 🏗️ **Механизм Rolling Update:**

### **1. Принцип работы:**
- Создание нового ReplicaSet с новой версией
- Постепенное масштабирование нового ReplicaSet
- Одновременное уменьшение старого ReplicaSet
- Контроль доступности через maxUnavailable и maxSurge

### **2. Этапы Rolling Update:**
1. **Validation**: Проверка новой конфигурации
2. **Creation**: Создание нового ReplicaSet
3. **Scaling**: Постепенное масштабирование
4. **Health Checks**: Проверка готовности новых Pod'ов
5. **Completion**: Завершение обновления

### **3. Rollback механизм:**
- Сохранение истории ReplicaSet'ов
- Возможность отката к любой предыдущей ревизии
- Автоматический или ручной rollback
- Мониторинг состояния после отката

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Подготовка тестового приложения:**
```bash
# Создать namespace для демонстрации
kubectl create namespace rolling-demo

# Создать начальный Deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: rolling-demo
  labels:
    app: webapp
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "v1.0"
        - name: BUILD_DATE
          value: "$(date)"
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
          timeoutSeconds: 2
          failureThreshold: 2
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: webapp-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: rolling-demo
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>WebApp v1.0</title></head>
    <body style="background-color: #e3f2fd; text-align: center; padding: 50px;">
      <h1>🚀 WebApp Version 1.0</h1>
      <p>Initial Release</p>
      <p>Image: nginx:1.20</p>
      <p>Status: Production Ready</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: rolling-demo
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить начальное состояние
kubectl get deployment webapp -n rolling-demo
kubectl get pods -n rolling-demo -l app=webapp
kubectl get rs -n rolling-demo -l app=webapp

# Проверить rollout history
kubectl rollout history deployment/webapp -n rolling-demo
```

### **2. Выполнение Rolling Update:**
```bash
# Метод 1: Обновление образа через kubectl set image
echo "=== Rolling Update через set image ==="
kubectl set image deployment/webapp web=nginx:1.21 -n rolling-demo

# Мониторинг процесса обновления
kubectl rollout status deployment/webapp -n rolling-demo --watch=true

# Проверить состояние во время обновления
kubectl get pods -n rolling-demo -l app=webapp -w &
WATCH_PID=$!
sleep 15
kill $WATCH_PID

# Проверить результат обновления
kubectl get deployment webapp -n rolling-demo
kubectl get rs -n rolling-demo -l app=webapp
kubectl describe deployment webapp -n rolling-demo

# Метод 2: Обновление через patch
echo "=== Rolling Update через patch ==="
kubectl patch deployment webapp -n rolling-demo -p '{"spec":{"template":{"spec":{"containers":[{"name":"web","image":"nginx:1.22"}]}}}}'

# Мониторинг patch обновления
kubectl rollout status deployment/webapp -n rolling-demo

# Метод 3: Обновление конфигурации и образа одновременно
echo "=== Комплексное обновление ==="

# Обновить ConfigMap
kubectl patch configmap webapp-config -n rolling-demo -p '{"data":{"index.html":"<!DOCTYPE html>\n<html>\n<head><title>WebApp v2.0</title></head>\n<body style=\"background-color: #f3e5f5; text-align: center; padding: 50px;\">\n  <h1>🎉 WebApp Version 2.0</h1>\n  <p>Major Update</p>\n  <p>Image: nginx:1.22</p>\n  <p>Status: Latest Release</p>\n</body>\n</html>"}}'

# Обновить environment variables для перезапуска Pod'ов
kubectl set env deployment/webapp VERSION=v2.0 BUILD_DATE="$(date)" -n rolling-demo

# Мониторинг комплексного обновления
kubectl rollout status deployment/webapp -n rolling-demo
```

### **3. Детальный мониторинг Rolling Update:**
```bash
# Создать мониторинг скрипт
cat << 'EOF' > monitor-rollout.sh
#!/bin/bash

NAMESPACE="rolling-demo"
DEPLOYMENT="webapp"

echo "=== Rolling Update Monitor ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo "Start time: $(date)"
echo

# Функция для получения статуса
get_status() {
    kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.replicas},{.status.readyReplicas},{.status.updatedReplicas},{.status.unavailableReplicas}'
}

# Функция для получения ReplicaSet'ов
get_replicasets() {
    kubectl get rs -n $NAMESPACE -l app=webapp -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas,AGE:.metadata.creationTimestamp --no-headers
}

# Мониторинг в реальном времени
echo "Monitoring rollout progress..."
echo "Format: Total,Ready,Updated,Unavailable"
echo

while true; do
    status=$(get_status)
    echo "$(date '+%H:%M:%S') - Status: $status"
    
    # Проверить завершение rollout
    if kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=1s >/dev/null 2>&1; then
        echo "✅ Rollout completed successfully!"
        break
    fi
    
    sleep 2
done

echo
echo "=== Final ReplicaSet Status ==="
get_replicasets

echo
echo "=== Final Pod Status ==="
kubectl get pods -n $NAMESPACE -l app=webapp -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image,NODE:.spec.nodeName
EOF

chmod +x monitor-rollout.sh

# Запустить мониторинг для следующего обновления
echo "=== Запуск мониторинга для следующего обновления ==="
./monitor-rollout.sh &
MONITOR_PID=$!

# Выполнить обновление
kubectl set image deployment/webapp web=nginx:1.23 -n rolling-demo

# Дождаться завершения мониторинга
wait $MONITOR_PID
```

### **4. Управление историей ревизий:**
```bash
# Добавить аннотации для отслеживания изменений
kubectl annotate deployment/webapp kubernetes.io/change-cause="Updated to nginx:1.23 with monitoring" -n rolling-demo

# Проверить полную историю
kubectl rollout history deployment/webapp -n rolling-demo

# Получить детальную информацию о конкретной ревизии
kubectl rollout history deployment/webapp --revision=1 -n rolling-demo
kubectl rollout history deployment/webapp --revision=2 -n rolling-demo

# Сравнить ревизии
echo "=== Сравнение ревизий ==="
echo "Revision 1:"
kubectl rollout history deployment/webapp --revision=1 -n rolling-demo
echo
echo "Current revision:"
kubectl rollout history deployment/webapp --revision=$(kubectl get deployment webapp -n rolling-demo -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}') -n rolling-demo

# Настроить лимит истории ревизий
kubectl patch deployment webapp -n rolling-demo -p '{"spec":{"revisionHistoryLimit":5}}'
```

## 🔄 **Rollback операции:**

### **1. Простой rollback к предыдущей версии:**
```bash
# Rollback к предыдущей ревизии
echo "=== Rollback к предыдущей версии ==="
kubectl rollout undo deployment/webapp -n rolling-demo

# Мониторинг rollback процесса
kubectl rollout status deployment/webapp -n rolling-demo

# Проверить результат rollback
kubectl get deployment webapp -n rolling-demo
kubectl get pods -n rolling-demo -l app=webapp -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

# Проверить обновленную историю
kubectl rollout history deployment/webapp -n rolling-demo
```

### **2. Rollback к конкретной ревизии:**
```bash
# Rollback к конкретной ревизии
echo "=== Rollback к ревизии 1 ==="
kubectl rollout undo deployment/webapp --to-revision=1 -n rolling-demo

# Мониторинг rollback
kubectl rollout status deployment/webapp -n rolling-demo

# Проверить rollback
kubectl describe deployment webapp -n rolling-demo | grep -A 10 "Pod Template"
kubectl get pods -n rolling-demo -l app=webapp -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

### **3. Автоматический rollback при проблемах:**
```bash
# Создать проблемный Deployment для демонстрации автоматического rollback
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problematic-app
  namespace: rolling-demo
  labels:
    app: problematic-app
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: problematic-app
  template:
    metadata:
      labels:
        app: problematic-app
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
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
EOF

# Дождаться готовности
kubectl rollout status deployment/problematic-app -n rolling-demo

# Создать проблемное обновление (несуществующий образ)
kubectl set image deployment/problematic-app web=nginx:nonexistent-version -n rolling-demo

# Мониторинг проблемного rollout
kubectl rollout status deployment/problematic-app -n rolling-demo --timeout=60s

# Проверить статус
kubectl get deployment problematic-app -n rolling-demo
kubectl get pods -n rolling-demo -l app=problematic-app
kubectl describe deployment problematic-app -n rolling-demo

# Автоматический rollback при проблемах
echo "=== Автоматический rollback ==="
kubectl rollout undo deployment/problematic-app -n rolling-demo
kubectl rollout status deployment/problematic-app -n rolling-demo
```

### **4. Скрипт для автоматического rollback:**
```bash
# Создать скрипт автоматического rollback
cat << 'EOF' > auto-rollback.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"
TIMEOUT="${3:-300}"  # 5 минут по умолчанию

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 <namespace> <deployment> [timeout_seconds]"
    exit 1
fi

echo "=== Auto Rollback Monitor ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo "Timeout: $TIMEOUT seconds"
echo

# Получить текущую ревизию
current_revision=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
echo "Current revision: $current_revision"

# Мониторинг rollout с timeout
echo "Monitoring rollout..."
if ! kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=${TIMEOUT}s; then
    echo "❌ Rollout failed or timed out!"
    echo "🔄 Initiating automatic rollback..."
    
    # Выполнить rollback
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
    
    # Дождаться завершения rollback
    if kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s; then
        echo "✅ Rollback completed successfully!"
        
        # Проверить новую ревизию
        new_revision=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
        echo "Rolled back to revision: $new_revision"
        
        # Показать статус Pod'ов
        echo "Pod status after rollback:"
        kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image
    else
        echo "❌ Rollback also failed!"
        exit 1
    fi
else
    echo "✅ Rollout completed successfully!"
fi
EOF

chmod +x auto-rollback.sh

# Пример использования
# ./auto-rollback.sh rolling-demo problematic-app 60
```

## 🔧 **Advanced Rolling Update техники:**

### **1. Pause и Resume rollout:**
```bash
# Создать Deployment для демонстрации pause/resume
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pausable-app
  namespace: rolling-demo
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  selector:
    matchLabels:
      app: pausable-app
  template:
    metadata:
      labels:
        app: pausable-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
EOF

# Дождаться готовности
kubectl rollout status deployment/pausable-app -n rolling-demo

# Начать обновление и сразу приостановить
echo "=== Pause/Resume Demo ==="
kubectl set image deployment/pausable-app web=nginx:1.21 -n rolling-demo
kubectl rollout pause deployment/pausable-app -n rolling-demo

# Проверить состояние во время паузы
kubectl get deployment pausable-app -n rolling-demo
kubectl get pods -n rolling-demo -l app=pausable-app
kubectl get rs -n rolling-demo -l app=pausable-app

# Сделать дополнительные изменения во время паузы
kubectl set env deployment/pausable-app VERSION=2.0 -n rolling-demo

# Возобновить rollout
echo "Resuming rollout..."
kubectl rollout resume deployment/pausable-app -n rolling-demo

# Мониторинг завершения
kubectl rollout status deployment/pausable-app -n rolling-demo
```

### **2. Canary rollout с ручным управлением:**
```bash
# Создать canary deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary-app
  namespace: rolling-demo
  labels:
    app: canary-app
    track: stable
spec:
  replicas: 8
  selector:
    matchLabels:
      app: canary-app
      track: stable
  template:
    metadata:
      labels:
        app: canary-app
        track: stable
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: TRACK
          value: "stable"
        - name: VERSION
          value: "1.0"
---
apiVersion: v1
kind: Service
metadata:
  name: canary-service
  namespace: rolling-demo
spec:
  selector:
    app: canary-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Создать canary версию
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary-app-new
  namespace: rolling-demo
  labels:
    app: canary-app
    track: canary
spec:
  replicas: 2  # 20% трафика
  selector:
    matchLabels:
      app: canary-app
      track: canary
  template:
    metadata:
      labels:
        app: canary-app
        track: canary
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: TRACK
          value: "canary"
        - name: VERSION
          value: "2.0"
EOF

# Постепенное увеличение canary трафика
echo "=== Canary Rollout Process ==="
echo "Phase 1: 20% canary traffic"
kubectl get pods -n rolling-demo -l app=canary-app --show-labels

sleep 10

echo "Phase 2: 50% canary traffic"
kubectl scale deployment canary-app --replicas=5 -n rolling-demo
kubectl scale deployment canary-app-new --replicas=5 -n rolling-demo

sleep 10

echo "Phase 3: 100% canary traffic"
kubectl scale deployment canary-app --replicas=0 -n rolling-demo
kubectl scale deployment canary-app-new --replicas=10 -n rolling-demo

# Финализация canary rollout
kubectl delete deployment canary-app -n rolling-demo
kubectl patch deployment canary-app-new -n rolling-demo -p '{"spec":{"selector":{"matchLabels":{"app":"canary-app"}},"template":{"metadata":{"labels":{"app":"canary-app"}}}}}'
```

## 🚨 **Troubleshooting Rolling Updates:**

### **1. Диагностика проблем rollout:**
```bash
# Создать диагностический скрипт
cat << 'EOF' > diagnose-rollout.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 <namespace> <deployment>"
    exit 1
fi

echo "=== Rollout Diagnostics ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo

# 1. Deployment статус
echo "1. Deployment Status:"
kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o wide
echo

# 2. ReplicaSet статус
echo "2. ReplicaSet Status:"
kubectl get rs -n $NAMESPACE -l app=$DEPLOYMENT -o wide
echo

# 3. Pod статус
echo "3. Pod Status:"
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IMAGE:.spec.containers[0].image,NODE:.spec.nodeName
echo

# 4. Rollout статус
echo "4. Rollout Status:"
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=10s
echo

# 5. События
echo "5. Recent Events:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$DEPLOYMENT --sort-by='.lastTimestamp' | tail -10
echo

# 6. Deployment условия
echo "6. Deployment Conditions:"
kubectl describe deployment $DEPLOYMENT -n $NAMESPACE | grep -A 10 "Conditions:"
echo

# 7. Pod логи (если есть проблемы)
echo "7. Pod Logs (last 10 lines from each pod):"
for pod in $(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o jsonpath='{.items[*].metadata.name}'); do
    echo "--- Logs from $pod ---"
    kubectl logs $pod -n $NAMESPACE --tail=10 2>/dev/null || echo "No logs available"
    echo
done

# 8. Resource utilization
echo "8. Resource Utilization:"
kubectl top pods -n $NAMESPACE -l app=$DEPLOYMENT 2>/dev/null || echo "Metrics not available"
echo

# 9. Rollout history
echo "9. Rollout History:"
kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE
EOF

chmod +x diagnose-rollout.sh

# Использование диагностики
./diagnose-rollout.sh rolling-demo webapp
```

### **2. Решение типичных проблем:**
```bash
# Проблема 1: Stuck rollout из-за readiness probe
echo "=== Демонстрация stuck rollout ==="
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stuck-app
  namespace: rolling-demo
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: stuck-app
  template:
    metadata:
      labels:
        app: stuck-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /nonexistent  # Неправильный путь
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
EOF

# Попытка обновления
kubectl set image deployment/stuck-app web=nginx:1.21 -n rolling-demo

# Диагностика stuck rollout
kubectl rollout status deployment/stuck-app -n rolling-demo --timeout=30s
kubectl describe deployment stuck-app -n rolling-demo
kubectl get pods -n rolling-demo -l app=stuck-app

# Исправление проблемы
kubectl patch deployment stuck-app -n rolling-demo -p '{"spec":{"template":{"spec":{"containers":[{"name":"web","readinessProbe":{"httpGet":{"path":"/"}}}]}}}}'

# Проверка исправления
kubectl rollout status deployment/stuck-app -n rolling-demo
```

### **3. Мониторинг производительности rollout:**
```bash
# Создать performance monitoring скрипт
cat << 'EOF' > rollout-performance.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 <namespace> <deployment>"
    exit 1
fi

echo "=== Rollout Performance Monitor ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo

# Начальные метрики
start_time=$(date +%s)
initial_ready=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
total_replicas=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')

echo "Initial state: $initial_ready/$total_replicas ready"
echo "Start time: $(date)"
echo

# Мониторинг метрик
while true; do
    current_ready=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    current_updated=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.updatedReplicas}')
    current_unavailable=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.unavailableReplicas}')
    
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    echo "$(date '+%H:%M:%S') [${elapsed}s] Ready: $current_ready/$total_replicas, Updated: $current_updated, Unavailable: $current_unavailable"
    
    # Проверка завершения
    if [ "$current_ready" = "$total_replicas" ] && [ "$current_updated" = "$total_replicas" ]; then
        echo "✅ Rollout completed in ${elapsed} seconds"
        break
    fi
    
    # Timeout после 10 минут
    if [ $elapsed -gt 600 ]; then
        echo "⏰ Timeout reached (10 minutes)"
        break
    fi
    
    sleep 2
done

# Финальные метрики
echo
echo "=== Final Metrics ==="
kubectl get deployment $DEPLOYMENT -n $NAMESPACE
kubectl get rs -n $NAMESPACE -l app=$DEPLOYMENT
kubectl top pods -n $NAMESPACE -l app=$DEPLOYMENT 2>/dev/null || echo "Resource metrics not available"
EOF

chmod +x rollout-performance.sh

# Пример использования для мониторинга следующего rollout
# ./rollout-performance.sh rolling-demo webapp &
# kubectl set image deployment/webapp web=nginx:1.24 -n rolling-demo
```

## 🎯 **Best Practices для Rolling Updates:**

### **1. Конфигурация стратегии:**
```bash
# Оптимальные настройки для разных сценариев
cat << EOF | kubectl apply -f -
# Быстрый rollout (для dev/staging)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fast-rollout
  namespace: rolling-demo
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2      # 50% могут быть недоступны
      maxSurge: 2           # 50% дополнительных Pod'ов
  selector:
    matchLabels:
      app: fast-rollout
  template:
    metadata:
      labels:
        app: fast-rollout
    spec:
      containers:
      - name: web
        image: nginx:1.20
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 2
---
# Консервативный rollout (для production)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: conservative-rollout
  namespace: rolling-demo
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Только 1 Pod недоступен
      maxSurge: 1           # Только 1 дополнительный Pod
  selector:
    matchLabels:
      app: conservative-rollout
  template:
    metadata:
      labels:
        app: conservative-rollout
    spec:
      containers:
      - name: web
        image: nginx:1.20
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 2
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
EOF
```

### **2. Автоматизация rollout процесса:**
```bash
# Создать полный automation скрипт
cat << 'EOF' > automated-rollout.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"
NEW_IMAGE="$3"
TIMEOUT="${4:-300}"

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ] || [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <namespace> <deployment> <new_image> [timeout_seconds]"
    exit 1
fi

echo "=== Automated Rollout ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo "New Image: $NEW_IMAGE"
echo "Timeout: $TIMEOUT seconds"
echo

# Pre-rollout checks
echo "1. Pre-rollout validation..."
if ! kubectl get deployment $DEPLOYMENT -n $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Deployment not found"
    exit 1
fi

current_image=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "Current image: $current_image"

if [ "$current_image" = "$NEW_IMAGE" ]; then
    echo "⚠️  Image is already $NEW_IMAGE, no update needed"
    exit 0
fi

# Check if new image exists (basic validation)
echo "2. Validating new image..."
if ! docker manifest inspect $NEW_IMAGE >/dev/null 2>&1; then
    echo "⚠️  Warning: Cannot validate image $NEW_IMAGE (continuing anyway)"
fi

# Record change cause
change_cause="Updated from $current_image to $NEW_IMAGE at $(date)"
kubectl annotate deployment/$DEPLOYMENT kubernetes.io/change-cause="$change_cause" -n $NAMESPACE

# Execute rollout
echo "3. Starting rollout..."
kubectl set image deployment/$DEPLOYMENT $(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].name}')=$NEW_IMAGE -n $NAMESPACE

# Monitor rollout with timeout
echo "4. Monitoring rollout progress..."
if kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=${TIMEOUT}s; then
    echo "✅ Rollout completed successfully!"
    
    # Post-rollout validation
    echo "5. Post-rollout validation..."
    kubectl get deployment $DEPLOYMENT -n $NAMESPACE
    kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image
    
    echo "✅ Automated rollout completed successfully!"
else
    echo "❌ Rollout failed or timed out!"
    echo "🔄 Initiating automatic rollback..."
    
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
    kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s
    
    echo "✅ Rollback completed"
    exit 1
fi
EOF

chmod +x automated-rollout.sh

# Пример использования
# ./automated-rollout.sh rolling-demo webapp nginx:1.24 300
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все deployments
kubectl delete deployments --all -n rolling-demo

# Удалить все services
kubectl delete services --all -n rolling-demo

# Удалить все configmaps
kubectl delete configmaps --all -n rolling-demo

# Удалить namespace
kubectl delete namespace rolling-demo

# Удалить скрипты
rm -f monitor-rollout.sh auto-rollback.sh diagnose-rollout.sh rollout-performance.sh automated-rollout.sh
```

## 📋 **Сводка команд Rolling Update и Rollback:**

### **Rolling Update команды:**
```bash
# Основные команды обновления
kubectl set image deployment/myapp container=image:tag -n namespace
kubectl patch deployment myapp -p '{"spec":{"template":{"spec":{"containers":[{"name":"container","image":"image:tag"}]}}}}' -n namespace
kubectl set env deployment/myapp ENV_VAR=value -n namespace

# Мониторинг rollout
kubectl rollout status deployment/myapp -n namespace
kubectl rollout status deployment/myapp -n namespace --watch=true
kubectl rollout status deployment/myapp -n namespace --timeout=300s

# Управление rollout
kubectl rollout pause deployment/myapp -n namespace
kubectl rollout resume deployment/myapp -n namespace
kubectl rollout restart deployment/myapp -n namespace
```

### **Rollback команды:**
```bash
# История ревизий
kubectl rollout history deployment/myapp -n namespace
kubectl rollout history deployment/myapp --revision=2 -n namespace

# Rollback операции
kubectl rollout undo deployment/myapp -n namespace
kubectl rollout undo deployment/myapp --to-revision=2 -n namespace

# Проверка rollback
kubectl rollout status deployment/myapp -n namespace
kubectl describe deployment myapp -n namespace
```

### **Диагностика команды:**
```bash
# Статус ресурсов
kubectl get deployment myapp -n namespace -o wide
kubectl get rs -n namespace -l app=myapp
kubectl get pods -n namespace -l app=myapp

# Детальная информация
kubectl describe deployment myapp -n namespace
kubectl describe pods -n namespace -l app=myapp

# События и логи
kubectl get events -n namespace --sort-by='.lastTimestamp'
kubectl logs -n namespace -l app=myapp --tail=50
```

## 🎯 **Ключевые принципы Rolling Update:**

### **1. Безопасность:**
- Всегда настраивайте readiness probes
- Используйте консервативные значения maxUnavailable
- Тестируйте обновления в staging среде
- Имейте план rollback

### **2. Производительность:**
- Оптимизируйте maxSurge для быстрых обновлений
- Настройте appropriate resource limits
- Мониторьте время rollout
- Используйте automation для consistency

### **3. Надежность:**
- Ведите историю изменений через аннотации
- Настройте автоматический rollback при проблемах
- Мониторьте метрики приложения
- Документируйте процедуры rollout

**Rolling Update и Rollback являются критически важными операциями для поддержания непрерывности сервиса при обновлениях приложений в production среде!**
