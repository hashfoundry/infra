# 43. Какие существуют стратегии развертывания в Kubernetes?

## 🎯 **Стратегии развертывания в Kubernetes**

**Стратегии развертывания** определяют, как Kubernetes обновляет приложения при изменении конфигурации или образов контейнеров. Правильный выбор стратегии критически важен для обеспечения доступности сервиса и минимизации рисков при обновлениях.

## 🏗️ **Основные стратегии развертывания:**

### **1. RollingUpdate (по умолчанию):**
- Постепенная замена старых Pod'ов новыми
- Обеспечивает zero-downtime deployment
- Контролируется параметрами maxUnavailable и maxSurge

### **2. Recreate:**
- Удаление всех старых Pod'ов перед созданием новых
- Простая стратегия с временным downtime
- Подходит для приложений, не поддерживающих параллельные версии

### **3. Blue-Green:**
- Полное переключение между двумя идентичными средами
- Мгновенное переключение трафика
- Требует двойных ресурсов

### **4. Canary:**
- Постепенное перенаправление трафика на новую версию
- Тестирование новой версии на части пользователей
- Возможность быстрого отката

## 📊 **Практические примеры из вашего HA кластера:**

### **1. RollingUpdate стратегия:**
```bash
# Создать namespace для демонстрации
kubectl create namespace deployment-strategies

# RollingUpdate Deployment с детальной конфигурацией
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-update-app
  namespace: deployment-strategies
  labels:
    app: rolling-app
    strategy: rolling-update
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Максимум 1 Pod недоступен
      maxSurge: 2           # Максимум 2 дополнительных Pod'а
  selector:
    matchLabels:
      app: rolling-app
  template:
    metadata:
      labels:
        app: rolling-app
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
          timeoutSeconds: 2
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]
---
apiVersion: v1
kind: Service
metadata:
  name: rolling-service
  namespace: deployment-strategies
spec:
  selector:
    app: rolling-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить начальное состояние
kubectl get deployment rolling-update-app -n deployment-strategies
kubectl get pods -n deployment-strategies -l app=rolling-app

# Выполнить rolling update
echo "=== Начинаем Rolling Update ==="
kubectl set image deployment/rolling-update-app web=nginx:1.21 -n deployment-strategies

# Мониторинг процесса обновления
kubectl rollout status deployment/rolling-update-app -n deployment-strategies --watch=true

# Проверить историю ReplicaSet'ов
kubectl get rs -n deployment-strategies -l app=rolling-app

# Проверить обновленные Pod'ы
kubectl get pods -n deployment-strategies -l app=rolling-app -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
```

### **2. Recreate стратегия:**
```bash
# Recreate Deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-app
  namespace: deployment-strategies
  labels:
    app: recreate-app
    strategy: recreate
spec:
  replicas: 4
  strategy:
    type: Recreate  # Все Pod'ы удаляются, затем создаются новые
  selector:
    matchLabels:
      app: recreate-app
  template:
    metadata:
      labels:
        app: recreate-app
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
        env:
        - name: STRATEGY
          value: "recreate"
---
apiVersion: v1
kind: Service
metadata:
  name: recreate-service
  namespace: deployment-strategies
spec:
  selector:
    app: recreate-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Мониторинг Recreate обновления
echo "=== Начинаем Recreate Update ==="
kubectl get pods -n deployment-strategies -l app=recreate-app -w &
WATCH_PID=$!

# Выполнить обновление
kubectl set image deployment/recreate-app web=nginx:1.21 -n deployment-strategies

# Дать время на обновление
sleep 20
kill $WATCH_PID

# Проверить результат
kubectl get pods -n deployment-strategies -l app=recreate-app
kubectl rollout status deployment/recreate-app -n deployment-strategies
```

### **3. Blue-Green стратегия:**
```bash
# Blue версия (текущая production)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blue-deployment
  namespace: deployment-strategies
  labels:
    app: blue-green-app
    version: blue
spec:
  replicas: 4
  selector:
    matchLabels:
      app: blue-green-app
      version: blue
  template:
    metadata:
      labels:
        app: blue-green-app
        version: blue
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "blue"
        - name: BACKGROUND_COLOR
          value: "#0066CC"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: blue-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: blue-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Blue Version</title></head>
    <body style="background-color: #0066CC; color: white; text-align: center; padding: 50px;">
      <h1>🔵 Blue Version</h1>
      <p>Current Production Version</p>
      <p>Version: 1.20</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: blue-green-service
  namespace: deployment-strategies
spec:
  selector:
    app: blue-green-app
    version: blue  # Изначально направляем на blue
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Green версия (новая версия)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green-deployment
  namespace: deployment-strategies
  labels:
    app: blue-green-app
    version: green
spec:
  replicas: 4
  selector:
    matchLabels:
      app: blue-green-app
      version: green
  template:
    metadata:
      labels:
        app: blue-green-app
        version: green
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "green"
        - name: BACKGROUND_COLOR
          value: "#00CC66"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: green-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: green-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Green Version</title></head>
    <body style="background-color: #00CC66; color: white; text-align: center; padding: 50px;">
      <h1>🟢 Green Version</h1>
      <p>New Version Ready for Production</p>
      <p>Version: 1.21</p>
    </body>
    </html>
EOF

# Проверить оба deployment'а
kubectl get deployments -n deployment-strategies -l app=blue-green-app
kubectl get pods -n deployment-strategies -l app=blue-green-app --show-labels

# Тестирование blue версии
kubectl run test-pod --image=curlimages/curl -it --rm --restart=Never -n deployment-strategies -- curl -s blue-green-service.deployment-strategies.svc.cluster.local

# Переключение на green версию
echo "=== Переключение на Green версию ==="
kubectl patch service blue-green-service -n deployment-strategies -p '{"spec":{"selector":{"version":"green"}}}'

# Тестирование green версии
kubectl run test-pod --image=curlimages/curl -it --rm --restart=Never -n deployment-strategies -- curl -s blue-green-service.deployment-strategies.svc.cluster.local

# Откат на blue версию (если нужно)
# kubectl patch service blue-green-service -n deployment-strategies -p '{"spec":{"selector":{"version":"blue"}}}'

# После успешного тестирования удалить blue версию
kubectl delete deployment blue-deployment -n deployment-strategies
kubectl delete configmap blue-config -n deployment-strategies
```

### **4. Canary стратегия:**
```bash
# Stable версия (основной трафик)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable-deployment
  namespace: deployment-strategies
  labels:
    app: canary-app
    track: stable
spec:
  replicas: 8  # 80% трафика
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
          value: "1.20"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: stable-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: stable-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Stable Version</title></head>
    <body style="background-color: #f0f0f0; text-align: center; padding: 50px;">
      <h1>📊 Stable Version</h1>
      <p>Track: Stable</p>
      <p>Version: 1.20</p>
      <p>Serving 80% of traffic</p>
    </body>
    </html>
EOF

# Canary версия (тестовый трафик)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary-deployment
  namespace: deployment-strategies
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
          value: "1.21"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: canary-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: canary-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Canary Version</title></head>
    <body style="background-color: #fff3cd; text-align: center; padding: 50px;">
      <h1>🐤 Canary Version</h1>
      <p>Track: Canary</p>
      <p>Version: 1.21</p>
      <p>Serving 20% of traffic</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: canary-service
  namespace: deployment-strategies
spec:
  selector:
    app: canary-app  # Выбирает оба track'а
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить распределение трафика
kubectl get pods -n deployment-strategies -l app=canary-app --show-labels
kubectl get endpoints canary-service -n deployment-strategies

# Тестирование распределения трафика
echo "=== Тестирование Canary распределения ==="
for i in {1..20}; do
  kubectl run test-pod-$i --image=curlimages/curl --rm --restart=Never -n deployment-strategies -- curl -s canary-service.deployment-strategies.svc.cluster.local | grep -o "Stable\|Canary" &
done
wait

# Постепенное увеличение canary трафика
echo "=== Увеличение Canary трафика до 50% ==="
kubectl scale deployment stable-deployment --replicas=5 -n deployment-strategies
kubectl scale deployment canary-deployment --replicas=5 -n deployment-strategies

# Полное переключение на canary (если тестирование успешно)
echo "=== Полное переключение на Canary ==="
kubectl scale deployment stable-deployment --replicas=0 -n deployment-strategies
kubectl scale deployment canary-deployment --replicas=10 -n deployment-strategies
```

## 🔧 **Advanced стратегии развертывания:**

### **1. A/B Testing стратегия:**
```bash
# A версия (контрольная группа)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: version-a
  namespace: deployment-strategies
  labels:
    app: ab-test-app
    version: a
spec:
  replicas: 5
  selector:
    matchLabels:
      app: ab-test-app
      version: a
  template:
    metadata:
      labels:
        app: ab-test-app
        version: a
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "A"
        - name: FEATURE_FLAG
          value: "false"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: version-a-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: version-a-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Version A</title></head>
    <body style="background-color: #e3f2fd; text-align: center; padding: 50px;">
      <h1>🅰️ Version A</h1>
      <p>Control Group</p>
      <p>Feature Flag: OFF</p>
      <button style="padding: 10px 20px; background: #2196f3; color: white; border: none;">Old Button</button>
    </body>
    </html>
EOF

# B версия (экспериментальная группа)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: version-b
  namespace: deployment-strategies
  labels:
    app: ab-test-app
    version: b
spec:
  replicas: 5
  selector:
    matchLabels:
      app: ab-test-app
      version: b
  template:
    metadata:
      labels:
        app: ab-test-app
        version: b
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "B"
        - name: FEATURE_FLAG
          value: "true"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: version-b-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: version-b-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Version B</title></head>
    <body style="background-color: #f3e5f5; text-align: center; padding: 50px;">
      <h1>🅱️ Version B</h1>
      <p>Experimental Group</p>
      <p>Feature Flag: ON</p>
      <button style="padding: 10px 20px; background: #9c27b0; color: white; border: none; border-radius: 20px;">New Button</button>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: ab-test-service
  namespace: deployment-strategies
spec:
  selector:
    app: ab-test-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить A/B тестирование
kubectl get pods -n deployment-strategies -l app=ab-test-app --show-labels
```

### **2. Shadow/Dark Launch стратегия:**
```bash
# Production версия (получает реальный трафик)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
  namespace: deployment-strategies
  labels:
    app: shadow-app
    track: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shadow-app
      track: production
  template:
    metadata:
      labels:
        app: shadow-app
        track: production
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: TRACK
          value: "production"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: production-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: production-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Production</title></head>
    <body style="background-color: #e8f5e8; text-align: center; padding: 50px;">
      <h1>🏭 Production Version</h1>
      <p>Serving real traffic</p>
      <p>Version: 1.20</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: production-service
  namespace: deployment-strategies
spec:
  selector:
    app: shadow-app
    track: production
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Shadow версия (получает копию трафика)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shadow-app
  namespace: deployment-strategies
  labels:
    app: shadow-app
    track: shadow
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shadow-app
      track: shadow
  template:
    metadata:
      labels:
        app: shadow-app
        track: shadow
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: TRACK
          value: "shadow"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: shadow-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: shadow-config
  namespace: deployment-strategies
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Shadow</title></head>
    <body style="background-color: #f5f5f5; text-align: center; padding: 50px;">
      <h1>👤 Shadow Version</h1>
      <p>Testing with mirrored traffic</p>
      <p>Version: 1.21</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: shadow-service
  namespace: deployment-strategies
spec:
  selector:
    app: shadow-app
    track: shadow
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить shadow deployment
kubectl get pods -n deployment-strategies -l app=shadow-app --show-labels
```

## 🏭 **Production considerations:**

### **1. Мониторинг стратегий развертывания:**
```bash
# Создать мониторинг Pod для отслеживания deployments
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: deployment-monitor
  namespace: deployment-strategies
spec:
  containers:
  - name: monitor
    image: curlimages/curl
    command: ["sleep", "3600"]
  restartPolicy: Always
EOF

# Скрипт для мониторинга доступности
cat << 'EOF' > monitor-deployments.sh
#!/bin/bash

NAMESPACE="deployment-strategies"
SERVICES=("rolling-service" "recreate-service" "blue-green-service" "canary-service" "production-service")

echo "=== Deployment Strategy Monitoring ==="
echo "Timestamp: $(date)"
echo

for service in "${SERVICES[@]}"; do
    echo "Testing $service:"
    if kubectl get service $service -n $NAMESPACE >/dev/null 2>&1; then
        response=$(kubectl exec -n $NAMESPACE deployment-monitor -- curl -s --connect-timeout 5 $service.$NAMESPACE.svc.cluster.local 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "  ✅ Service is accessible"
            echo "  📊 Response contains: $(echo "$response" | grep -o '<title>[^<]*</title>' | sed 's/<[^>]*>//g')"
        else
            echo "  ❌ Service is not accessible"
        fi
    else
        echo "  ⚠️  Service not found"
    fi
    echo
done
EOF

chmod +x monitor-deployments.sh
./monitor-deployments.sh
```

### **2. Автоматизация rollback:**
```bash
# Создать скрипт для автоматического rollback
cat << 'EOF' > auto-rollback.sh
#!/bin/bash

NAMESPACE="deployment-strategies"
DEPLOYMENT_NAME="$1"
HEALTH_CHECK_URL="$2"
MAX_RETRIES=5
RETRY_INTERVAL=30

if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$HEALTH_CHECK_URL" ]; then
    echo "Usage: $0 <deployment-name> <health-check-url>"
    exit 1
fi

echo "Monitoring deployment: $DEPLOYMENT_NAME"
echo "Health check URL: $HEALTH_CHECK_URL"

for i in $(seq 1 $MAX_RETRIES); do
    echo "Health check attempt $i/$MAX_RETRIES"
    
    if kubectl exec -n $NAMESPACE deployment-monitor -- curl -s --connect-timeout 10 $HEALTH_CHECK_URL >/dev/null 2>&1; then
        echo "✅ Health check passed"
        exit 0
    else
        echo "❌ Health check failed"
        if [ $i -eq $MAX_RETRIES ]; then
            echo "🔄 Initiating rollback..."
            kubectl rollout undo deployment/$DEPLOYMENT_NAME -n $NAMESPACE
            kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE
            echo "✅ Rollback completed"
            exit 1
        fi
        sleep $RETRY_INTERVAL
    fi
done
EOF

chmod +x auto-rollback.sh

# Пример использования
# ./auto-rollback.sh rolling-update-app rolling-service.deployment-strategies.svc.cluster.local
```

## 🚨 **Troubleshooting стратегий развертывания:**

### **1. Диагностика проблем развертывания:**
```bash
# Проверить статус всех deployments
kubectl get deployments -n deployment-strategies -o wide

# Проверить rollout статус
for deployment in $(kubectl get deployments -n deployment-strategies -o jsonpath='{.items[*].metadata.name}'); do
    echo "=== $deployment ==="
    kubectl rollout status deployment/$deployment -n deployment-strategies --timeout=10s
    echo
done

# Проверить события
kubectl get events -n deployment-strategies --sort-by='.lastTimestamp' | tail -20

# Проверить resource utilization
kubectl top pods -n deployment-strategies

# Проверить readiness и liveness probes
kubectl describe pods -n deployment-strategies | grep -A 5 -B 5 "Readiness\|Liveness"
```

### **2. Анализ производительности стратегий:**
```bash
# Создать load testing Pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: load-tester
  namespace: deployment-strategies
spec:
  containers:
  - name: load-test
    image: busybox
    command: ["sleep", "3600"]
  restartPolicy: Always
EOF

# Скрипт для load testing
cat << 'EOF' > load-test.sh
#!/bin/bash

SERVICE_NAME="$1"
NAMESPACE="deployment-strategies"
DURATION=60
CONCURRENT_REQUESTS=10

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name>"
    exit 1
fi

echo "Load testing $SERVICE_NAME for $DURATION seconds with $CONCURRENT_REQUESTS concurrent requests"

for i in $(seq 1 $CONCURRENT_REQUESTS); do
    kubectl exec -n $NAMESPACE load-tester -- sh -c "
        end_time=\$(($(date +%s) + $DURATION))
        success=0
        total=0
        while [ \$(date +%s) -lt \$end_time ]; do
            if wget -q -O- --timeout=5 $SERVICE_NAME.$NAMESPACE.svc.cluster.local >/dev/null 2>&1; then
                success=\$((success + 1))
            fi
            total=\$((total + 1))
            sleep 0.1
        done
        echo \"Worker $i: \$success/\$total successful requests\"
    " &
done

wait
echo "Load test completed"
EOF

chmod +x load-test.sh

# Пример использования
# ./load-test.sh rolling-service
```

## 🎯 **Best Practices для стратегий развертывания:**

### **1. Выбор правильной стратегии:**
```bash
# Матрица выбора стратегии
cat << 'EOF'
=== Матрица выбора стратегии развертывания ===

RollingUpdate:
✅ Stateless приложения
✅ Web сервисы
✅ Микросервисы
✅ Zero-downtime требования
❌ Stateful приложения
❌ Singleton приложения

Recreate:
✅ Stateful приложения
✅ Singleton приложения
✅ Приложения с shared storage
✅ Legacy приложения
❌ High availability требования
❌ Production критичные сервисы

Blue-Green:
✅ Critical production сервисы
✅ Быстрый rollback
✅ Полное тестирование
❌ Ограниченные ресурсы
❌ Stateful приложения

Canary:
✅ Новые features
✅ Risk mitigation
✅ A/B testing
✅ Gradual rollout
❌ Простые обновления
❌ Ограниченный мониторинг
EOF
```

### **2. Конфигурация health checks:**
```bash
# Оптимальные настройки health checks для разных стратегий
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: optimized-health-checks
  namespace: deployment-strategies
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: optimized-app
  template:
    metadata:
      labels:
        app: optimized-app
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        # Быстрая readiness probe для rolling updates
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 2
          timeoutSeconds: 1
          failureThreshold: 2
        # Консервативная liveness probe
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        # Graceful shutdown
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все deployments
kubectl delete deployments --all -n deployment-strategies

# Удалить все services
kubectl delete services --all -n deployment-strategies

# Удалить все configmaps
kubectl delete configmaps --all -n deployment-strategies

# Удалить все pods
kubectl delete pods --all -n deployment-strategies

# Удалить namespace
kubectl delete namespace deployment-strategies

# Удалить скрипты
rm -f monitor-deployments.sh auto-rollback.sh load-test.sh
```

## 📋 **Сравнительная таблица стратегий:**

| Стратегия | Downtime | Ресурсы | Сложность | Rollback | Use Case |
|-----------|----------|---------|-----------|----------|----------|
| **RollingUpdate** | Нет | 1x + surge | Низкая | Быстрый | Stateless apps |
| **Recreate** | Есть | 1x | Очень низкая | Медленный | Stateful apps |
| **Blue-Green** | Нет | 2x | Средняя | Мгновенный | Critical services |
| **Canary** | Нет | 1x + canary | Высокая | Быстрый | Risk mitigation |
| **A/B Testing** | Нет | 2x | Высокая | Быстрый | Feature testing |
| **Shadow** | Нет | 2x | Очень высокая | N/A | Performance testing |

## 🎯 **Ключевые рекомендации:**

### **1. Для Production:**
- Используйте RollingUpdate для большинства stateless приложений
- Настройте правильные health checks
- Мониторьте метрики во время развертывания
- Имейте план автоматического rollback

### **2. Для критичных сервисов:**
- Рассмотрите Blue-Green для мгновенного rollback
- Используйте Canary для постепенного тестирования
- Автоматизируйте процесс развертывания
- Настройте comprehensive мониторинг

### **3. Для экспериментов:**
- A/B Testing для feature flags
- Shadow deployment для performance тестирования
- Canary для новых версий
- Детальная аналитика и метрики

**Правильный выбор стратегии развертывания критически важен для обеспечения надежности и доступности приложений в production среде!**
