# 46. Как приостановить и возобновить развертывание (pause/resume deployment rollout)?

## 🎯 **Pause и Resume в Kubernetes Deployments**

**Pause** и **Resume** — это мощные функции Kubernetes, которые позволяют приостанавливать процесс развертывания для внесения дополнительных изменений или проведения тестирования, а затем возобновлять его. Это особенно полезно для сложных обновлений, требующих поэтапного подхода.

## 🏗️ **Принцип работы Pause/Resume:**

### **1. Pause (Приостановка):**
- Останавливает текущий rollout процесс
- Позволяет вносить дополнительные изменения
- Предотвращает создание новых ReplicaSet'ов
- Сохраняет текущее состояние развертывания

### **2. Resume (Возобновление):**
- Продолжает приостановленный rollout
- Применяет все накопленные изменения одновременно
- Создает новый ReplicaSet с финальной конфигурацией
- Завершает процесс обновления

### **3. Преимущества:**
- **Атомарные обновления**: Несколько изменений применяются как одна операция
- **Тестирование**: Возможность протестировать частичное обновление
- **Контроль**: Полный контроль над процессом развертывания
- **Безопасность**: Возможность остановить проблемное обновление

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Базовая демонстрация Pause/Resume:**
```bash
# Создать namespace для демонстрации
kubectl create namespace pause-demo

# Создать начальный Deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: pause-demo
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
          value: "1.0"
        - name: ENVIRONMENT
          value: "production"
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
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: pause-demo
data:
  default.conf: |
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: pause-demo
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Дождаться готовности deployment
kubectl rollout status deployment/webapp -n pause-demo

# Проверить начальное состояние
kubectl get deployment webapp -n pause-demo
kubectl get pods -n pause-demo -l app=webapp
kubectl rollout history deployment/webapp -n pause-demo
```

### **2. Простой пример Pause/Resume:**
```bash
# Начать обновление образа
echo "=== Начинаем обновление и сразу приостанавливаем ==="
kubectl set image deployment/webapp web=nginx:1.21 -n pause-demo

# Немедленно приостановить rollout
kubectl rollout pause deployment/webapp -n pause-demo

# Проверить состояние во время паузы
kubectl get deployment webapp -n pause-demo
kubectl get pods -n pause-demo -l app=webapp
kubectl get rs -n pause-demo -l app=webapp

# Проверить статус rollout
kubectl rollout status deployment/webapp -n pause-demo --timeout=5s

echo "Deployment приостановлен. Можно вносить дополнительные изменения..."

# Внести дополнительные изменения во время паузы
kubectl set env deployment/webapp VERSION=2.0 ENVIRONMENT=staging -n pause-demo

# Обновить ConfigMap
kubectl patch configmap nginx-config -n pause-demo -p '{"data":{"default.conf":"server {\n    listen 80;\n    location / {\n        root /usr/share/nginx/html;\n        index index.html;\n    }\n    location /health {\n        access_log off;\n        return 200 \"healthy v2.0\\n\";\n        add_header Content-Type text/plain;\n    }\n    location /version {\n        access_log off;\n        return 200 \"nginx:1.21 v2.0\\n\";\n        add_header Content-Type text/plain;\n    }\n}"}}'

# Проверить, что изменения не применились (deployment на паузе)
kubectl describe deployment webapp -n pause-demo | grep -A 10 "Pod Template"

# Возобновить rollout
echo "=== Возобновляем rollout ==="
kubectl rollout resume deployment/webapp -n pause-demo

# Мониторинг завершения rollout
kubectl rollout status deployment/webapp -n pause-demo

# Проверить финальное состояние
kubectl get deployment webapp -n pause-demo
kubectl get pods -n pause-demo -l app=webapp
kubectl describe deployment webapp -n pause-demo | grep -A 15 "Pod Template"
```

### **3. Advanced сценарий с мониторингом:**
```bash
# Создать скрипт для детального мониторинга pause/resume
cat << 'EOF' > monitor-pause-resume.sh
#!/bin/bash

NAMESPACE="pause-demo"
DEPLOYMENT="webapp"

echo "=== Pause/Resume Monitor ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo

# Функция для получения статуса
get_deployment_status() {
    local paused=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.paused}')
    local replicas=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    local ready=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    local updated=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.updatedReplicas}')
    local unavailable=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.unavailableReplicas}')
    local revision=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
    
    echo "Status: Paused=${paused:-false}, Revision=$revision"
    echo "Replicas: Ready=${ready:-0}/$replicas, Updated=${updated:-0}, Unavailable=${unavailable:-0}"
    
    # Показать ReplicaSet'ы
    echo "ReplicaSets:"
    kubectl get rs -n $NAMESPACE -l app=$DEPLOYMENT -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas,AGE:.metadata.creationTimestamp --no-headers | while read line; do
        echo "  $line"
    done
    
    echo
}

# Функция для мониторинга изменений
monitor_changes() {
    local duration=$1
    echo "Monitoring for $duration seconds..."
    
    for i in $(seq 1 $duration); do
        echo "=== Time: ${i}s ==="
        get_deployment_status
        sleep 1
    done
}

# Начальное состояние
echo "=== Initial State ==="
get_deployment_status

# Начать обновление
echo "=== Starting Update ==="
kubectl set image deployment/$DEPLOYMENT web=nginx:1.22 -n $NAMESPACE

# Мониторинг в течение 5 секунд
monitor_changes 5

# Приостановить
echo "=== Pausing Rollout ==="
kubectl rollout pause deployment/$DEPLOYMENT -n $NAMESPACE
get_deployment_status

# Внести дополнительные изменения
echo "=== Making Additional Changes ==="
kubectl set env deployment/$DEPLOYMENT VERSION=3.0 BUILD_DATE="$(date)" -n $NAMESPACE
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"web","resources":{"requests":{"memory":"128Mi","cpu":"150m"}}}]}}}}'

echo "Changes made during pause:"
kubectl describe deployment $DEPLOYMENT -n $NAMESPACE | grep -A 20 "Pod Template"

# Возобновить
echo "=== Resuming Rollout ==="
kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE

# Мониторинг завершения
monitor_changes 30

echo "=== Final State ==="
get_deployment_status
kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE
EOF

chmod +x monitor-pause-resume.sh
./monitor-pause-resume.sh
```

### **4. Сложный сценарий с множественными изменениями:**
```bash
# Создать более сложный deployment для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex-app
  namespace: pause-demo
  labels:
    app: complex-app
spec:
  replicas: 8
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2
      maxSurge: 2
  selector:
    matchLabels:
      app: complex-app
  template:
    metadata:
      labels:
        app: complex-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
        - name: FEATURE_FLAGS
          value: "feature1=false,feature2=false"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
        - name: static-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: config
        configMap:
          name: complex-nginx-config
      - name: static-content
        configMap:
          name: static-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: complex-nginx-config
  namespace: pause-demo
data:
  default.conf: |
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        location /health {
            access_log off;
            return 200 "healthy v1.0\n";
            add_header Content-Type text/plain;
        }
        location /api {
            return 200 "API v1.0\n";
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: static-content
  namespace: pause-demo
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Complex App v1.0</title></head>
    <body style="background-color: #f0f0f0; text-align: center; padding: 50px;">
      <h1>🚀 Complex Application</h1>
      <p>Version: 1.0</p>
      <p>Features: Basic functionality</p>
    </body>
    </html>
EOF

# Дождаться готовности
kubectl rollout status deployment/complex-app -n pause-demo

# Выполнить сложное обновление с паузой
echo "=== Complex Multi-Step Update ==="

# Шаг 1: Начать обновление образа и сразу приостановить
kubectl set image deployment/complex-app web=nginx:1.21 -n pause-demo
kubectl rollout pause deployment/complex-app -n pause-demo

echo "Step 1: Image update paused"
kubectl get pods -n pause-demo -l app=complex-app

# Шаг 2: Обновить environment variables
kubectl set env deployment/complex-app VERSION=2.0 FEATURE_FLAGS="feature1=true,feature2=false" -n pause-demo

# Шаг 3: Обновить resource limits
kubectl patch deployment complex-app -n pause-demo -p '{"spec":{"template":{"spec":{"containers":[{"name":"web","resources":{"requests":{"memory":"128Mi","cpu":"150m"},"limits":{"memory":"256Mi","cpu":"300m"}}}]}}}}'

# Шаг 4: Обновить ConfigMaps
kubectl patch configmap complex-nginx-config -n pause-demo -p '{"data":{"default.conf":"server {\n    listen 80;\n    location / {\n        root /usr/share/nginx/html;\n        index index.html;\n    }\n    location /health {\n        access_log off;\n        return 200 \"healthy v2.0\\n\";\n        add_header Content-Type text/plain;\n    }\n    location /api {\n        return 200 \"API v2.0\\n\";\n        add_header Content-Type text/plain;\n    }\n    location /features {\n        return 200 \"Features: feature1=enabled\\n\";\n        add_header Content-Type text/plain;\n    }\n}"}}'

kubectl patch configmap static-content -n pause-demo -p '{"data":{"index.html":"<!DOCTYPE html>\n<html>\n<head><title>Complex App v2.0</title></head>\n<body style=\"background-color: #e3f2fd; text-align: center; padding: 50px;\">\n  <h1>🎉 Complex Application v2.0</h1>\n  <p>Version: 2.0</p>\n  <p>Features: Enhanced functionality with feature1 enabled</p>\n  <p>Image: nginx:1.21</p>\n</body>\n</html>"}}'

# Шаг 5: Добавить новые labels и annotations
kubectl patch deployment complex-app -n pause-demo -p '{"spec":{"template":{"metadata":{"labels":{"version":"2.0","features":"enhanced"},"annotations":{"update-date":"'$(date)'","update-type":"major"}}}}}'

echo "All changes prepared during pause. Current deployment spec:"
kubectl describe deployment complex-app -n pause-demo | grep -A 25 "Pod Template"

# Шаг 6: Возобновить rollout
echo "=== Resuming complex rollout ==="
kubectl rollout resume deployment/complex-app -n pause-demo

# Мониторинг завершения
kubectl rollout status deployment/complex-app -n pause-demo

# Проверить результат
kubectl get pods -n pause-demo -l app=complex-app --show-labels
kubectl describe deployment complex-app -n pause-demo | grep -A 30 "Pod Template"
```

## 🔧 **Advanced техники Pause/Resume:**

### **1. Условная пауза на основе метрик:**
```bash
# Создать скрипт для автоматической паузы при проблемах
cat << 'EOF' > conditional-pause.sh
#!/bin/bash

NAMESPACE="pause-demo"
DEPLOYMENT="$1"
HEALTH_THRESHOLD=80  # Минимальный процент здоровых Pod'ов

if [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 <deployment-name>"
    exit 1
fi

echo "=== Conditional Pause Monitor ==="
echo "Deployment: $DEPLOYMENT"
echo "Health threshold: $HEALTH_THRESHOLD%"
echo

monitor_health() {
    local replicas=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    local ready=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    
    if [ -z "$ready" ] || [ "$ready" = "null" ]; then
        ready=0
    fi
    
    local health_percentage=0
    if [ "$replicas" -gt 0 ]; then
        health_percentage=$(echo "scale=0; $ready * 100 / $replicas" | bc)
    fi
    
    echo "Health: $ready/$replicas pods ready ($health_percentage%)"
    
    if [ "$health_percentage" -lt "$HEALTH_THRESHOLD" ]; then
        echo "⚠️  Health below threshold! Pausing rollout..."
        kubectl rollout pause deployment/$DEPLOYMENT -n $NAMESPACE
        return 1
    fi
    
    return 0
}

# Начать обновление
kubectl set image deployment/$DEPLOYMENT web=nginx:1.23 -n $NAMESPACE

# Мониторинг здоровья каждые 5 секунд
for i in {1..20}; do
    echo "=== Check $i ==="
    if ! monitor_health; then
        echo "Rollout paused due to health issues"
        break
    fi
    
    # Проверить, завершился ли rollout
    if kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=1s >/dev/null 2>&1; then
        echo "✅ Rollout completed successfully"
        break
    fi
    
    sleep 5
done

# Показать финальное состояние
kubectl get deployment $DEPLOYMENT -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
EOF

chmod +x conditional-pause.sh

# Пример использования
# ./conditional-pause.sh webapp
```

### **2. Пауза с пользовательским подтверждением:**
```bash
# Создать интерактивный скрипт для управления rollout
cat << 'EOF' > interactive-rollout.sh
#!/bin/bash

NAMESPACE="pause-demo"
DEPLOYMENT="$1"
NEW_IMAGE="$2"

if [ -z "$DEPLOYMENT" ] || [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <deployment-name> <new-image>"
    exit 1
fi

echo "=== Interactive Rollout Manager ==="
echo "Deployment: $DEPLOYMENT"
echo "New Image: $NEW_IMAGE"
echo "Namespace: $NAMESPACE"
echo

# Показать текущее состояние
echo "Current state:"
kubectl get deployment $DEPLOYMENT -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT

# Начать обновление и сразу приостановить
echo
echo "Starting rollout and pausing for review..."
kubectl set image deployment/$DEPLOYMENT web=$NEW_IMAGE -n $NAMESPACE
kubectl rollout pause deployment/$DEPLOYMENT -n $NAMESPACE

# Показать изменения
echo
echo "Planned changes:"
kubectl describe deployment $DEPLOYMENT -n $NAMESPACE | grep -A 10 "Pod Template"

# Интерактивное меню
while true; do
    echo
    echo "=== Rollout Control Menu ==="
    echo "1. Resume rollout"
    echo "2. Add environment variable"
    echo "3. Update resource limits"
    echo "4. Show current status"
    echo "5. Rollback and exit"
    echo "6. Exit without changes"
    
    read -p "Choose option (1-6): " choice
    
    case $choice in
        1)
            echo "Resuming rollout..."
            kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE
            kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
            echo "✅ Rollout completed"
            break
            ;;
        2)
            read -p "Enter environment variable (KEY=VALUE): " env_var
            if [[ $env_var =~ ^[A-Z_][A-Z0-9_]*=.+$ ]]; then
                key=$(echo $env_var | cut -d'=' -f1)
                value=$(echo $env_var | cut -d'=' -f2-)
                kubectl set env deployment/$DEPLOYMENT $key="$value" -n $NAMESPACE
                echo "Environment variable added: $env_var"
            else
                echo "Invalid format. Use KEY=VALUE"
            fi
            ;;
        3)
            read -p "Enter memory limit (e.g., 256Mi): " memory
            read -p "Enter CPU limit (e.g., 300m): " cpu
            if [ -n "$memory" ] && [ -n "$cpu" ]; then
                kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"web\",\"resources\":{\"limits\":{\"memory\":\"$memory\",\"cpu\":\"$cpu\"}}}]}}}}"
                echo "Resource limits updated: Memory=$memory, CPU=$cpu"
            else
                echo "Both memory and CPU limits required"
            fi
            ;;
        4)
            kubectl get deployment $DEPLOYMENT -n $NAMESPACE
            kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
            kubectl get rs -n $NAMESPACE -l app=$DEPLOYMENT
            ;;
        5)
            echo "Rolling back..."
            kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
            kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
            echo "✅ Rollback completed"
            break
            ;;
        6)
            echo "Exiting without resuming rollout"
            echo "⚠️  Deployment is still paused. Resume manually with:"
            echo "kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE"
            break
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done
EOF

chmod +x interactive-rollout.sh

# Пример использования
# ./interactive-rollout.sh complex-app nginx:1.24
```

### **3. Автоматизированная пауза для тестирования:**
```bash
# Создать deployment для автоматизированного тестирования
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: pause-demo
  annotations:
    test.automation/enabled: "true"
    test.automation/pause-after-start: "true"
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 2
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: pause-demo
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Создать автоматизированный тестовый скрипт
cat << 'EOF' > automated-test-rollout.sh
#!/bin/bash

NAMESPACE="pause-demo"
DEPLOYMENT="test-app"
SERVICE="test-app-service"

echo "=== Automated Test Rollout ==="
echo "Deployment: $DEPLOYMENT"
echo "Service: $SERVICE"
echo

# Функция для выполнения health check
health_check() {
    local test_name="$1"
    echo "Running $test_name..."
    
    # Проверить доступность сервиса
    if kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -n $NAMESPACE -- curl -s --connect-timeout 5 $SERVICE.$NAMESPACE.svc.cluster.local >/dev/null 2>&1; then
        echo "✅ $test_name: PASSED"
        return 0
    else
        echo "❌ $test_name: FAILED"
        return 1
    fi
}

# Функция для выполнения load test
load_test() {
    local duration=$1
    echo "Running load test for ${duration}s..."
    
    local success=0
    local total=0
    
    for i in $(seq 1 $duration); do
        if kubectl run load-test-$i --image=curlimages/curl --rm --restart=Never -n $NAMESPACE -- curl -s --connect-timeout 2 $SERVICE.$NAMESPACE.svc.cluster.local >/dev/null 2>&1; then
            success=$((success + 1))
        fi
        total=$((total + 1))
        sleep 1
    done
    
    local success_rate=$(echo "scale=1; $success * 100 / $total" | bc)
    echo "Load test results: $success/$total requests successful ($success_rate%)"
    
    if [ $(echo "$success_rate >= 90" | bc) -eq 1 ]; then
        echo "✅ Load test: PASSED"
        return 0
    else
        echo "❌ Load test: FAILED"
        return 1
    fi
}

# Дождаться готовности начального deployment
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

# Начать обновление и приостановить
echo "Starting rollout with automatic pause..."
kubectl set image deployment/$DEPLOYMENT web=nginx:1.21 -n $NAMESPACE
kubectl rollout pause deployment/$DEPLOYMENT -n $NAMESPACE

# Дать время на частичное обновление
sleep 10

# Выполнить тесты во время паузы
echo
echo "=== Running Tests During Pause ==="

# Базовый health check
if ! health_check "Basic Health Check"; then
    echo "❌ Basic health check failed. Rolling back..."
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
    exit 1
fi

# Load test
if ! load_test 10; then
    echo "❌ Load test failed. Rolling back..."
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
    exit 1
fi

# Проверить метрики Pod'ов
echo "Checking pod metrics..."
kubectl top pods -n $NAMESPACE -l app=$DEPLOYMENT 2>/dev/null || echo "Metrics not available"

# Все тесты прошли успешно
echo
echo "✅ All tests passed. Resuming rollout..."
kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE

# Дождаться завершения
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

# Финальная проверка
echo
echo "=== Final Verification ==="
health_check "Final Health Check"
load_test 5

echo "✅ Automated rollout completed successfully"
EOF

chmod +x automated-test-rollout.sh
./automated-test-rollout.sh
```

## 🚨 **Troubleshooting Pause/Resume:**

### **1. Диагностика проблем с паузой:**
```bash
# Создать диагностический скрипт
cat << 'EOF' > diagnose-pause.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 <namespace> <deployment>"
    exit 1
fi

echo "=== Pause/Resume Diagnostics ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo

# 1. Проверить статус паузы
paused=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.paused}')
echo "1. Pause Status: ${paused:-false}"

# 2. Проверить rollout статус
echo "2. Rollout Status:"
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=5s 2>&1 || echo "Rollout not progressing"

# 3. Проверить ReplicaSet'ы
echo "3. ReplicaSets:"
kubectl get rs -n $NAMESPACE -l app=$DEPLOYMENT -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas,AGE:.metadata.creationTimestamp

# 4. Проверить Pod'ы
echo "4. Pods:"
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IMAGE:.spec.containers[0].image

# 5. Проверить события
echo "5. Recent Events:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$DEPLOYMENT --sort-by='.lastTimestamp' | tail -10

# 6. Проверить deployment conditions
echo "6. Deployment Conditions:"
kubectl describe deployment $DEPLOYMENT -n $NAMESPACE | grep -A 10 "Conditions:"

# 7. Проверить pending changes
echo "7. Deployment Spec (check for pending changes):"
kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o yaml | grep -A 20 "spec:"

# 8. Рекомендации
echo "8. Recommendations:"
if [ "$paused" = "true" ]; then
    echo "   - Deployment is paused. Resume with: kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE"
    echo "   - Or rollback with: kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE"
else
    echo "   - Deployment is not paused"
    echo "   - Check if rollout is stuck or completed"
fi
EOF

chmod +x diagnose-pause.sh

# Использование диагностики
./diagnose-pause.sh pause-demo webapp
```

### **2. Восстановление после проблем с паузой:**
```bash
# Создать скрипт для восстановления проблемных deployments
cat << 'EOF' > fix-paused-deployment.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 <namespace> <deployment>"
    exit 1
fi

echo "=== Fixing Paused Deployment ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo

# Проверить текущий статус
paused=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.paused}')
echo "Current pause status: ${paused:-false}"

if [ "$paused" = "true" ]; then
    echo "Deployment is paused. Analyzing situation..."
    
    # Проверить здоровье Pod'ов
    replicas=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    ready=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    
    echo "Pod health: ${ready:-0}/$replicas ready"
    
    # Проверить наличие проблемных Pod'ов
    failed_pods=$(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT --field-selector=status.phase=Failed --no-headers | wc -l)
    pending_pods=$(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT --field-selector=status.phase=Pending --no-headers | wc -l)
    
    echo "Failed pods: $failed_pods"
    echo "Pending pods: $pending_pods"
    
    # Предложить варианты действий
    echo
    echo "Available actions:"
    echo "1. Resume rollout"
    echo "2. Rollback to previous version"
    echo "3. Force restart deployment"
    echo "4. Show detailed diagnostics"
    
    read -p "Choose action (1-4): " action
    
    case $action in
        1)
            echo "Resuming rollout..."
            kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE
            kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
            ;;
        2)
            echo "Rolling back..."
            kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
            kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
            ;;
        3)
            echo "Force restarting deployment..."
            kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE
            kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
            ;;
        4)
            echo "Detailed diagnostics:"
            kubectl describe deployment $DEPLOYMENT -n $NAMESPACE
            kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$DEPLOYMENT
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
else
    echo "Deployment is not paused"
    kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
fi
EOF

chmod +x fix-paused-deployment.sh

# Пример использования
# ./fix-paused-deployment.sh pause-demo webapp
```

## 📊 **Мониторинг и метрики Pause/Resume:**

### **1. Dashboard для отслеживания паузы:**
```bash
# Создать comprehensive dashboard
cat << 'EOF' > pause-dashboard.sh
#!/bin/bash

NAMESPACE="pause-demo"

echo "=== Pause/Resume Dashboard ==="
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo "================================"
echo

# Функция для отображения статуса deployment
show_deployment_status() {
    local deployment=$1
    
    # Получить основную информацию
    local paused=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.paused}' 2>/dev/null || echo "false")
    local replicas=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    local ready=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local updated=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.updatedReplicas}' 2>/dev/null || echo "0")
    local revision=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null || echo "N/A")
    
    # Статус rollout
    local rollout_status="Unknown"
    if [ "$paused" = "true" ]; then
        rollout_status="⏸️  PAUSED"
    elif kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=1s >/dev/null 2>&1; then
        rollout_status="✅ Complete"
    else
        rollout_status="🔄 In Progress"
    fi
    
    # Количество ReplicaSet'ов
    local rs_count=$(kubectl get rs -n $NAMESPACE -l app=$deployment --no-headers 2>/dev/null | wc -l)
    
    printf "%-15s | %-10s | %2s/%-2s | %2s | %-3s | %-15s | %s\n" \
        "$deployment" "$paused" "$ready" "$replicas" "$updated" "$revision" "$rollout_status" "$rs_count"
}

# Заголовок таблицы
printf "%-15s | %-10s | %-5s | %-2s | %-3s | %-15s | %s\n" \
    "DEPLOYMENT" "PAUSED" "READY" "UP" "REV" "STATUS" "RS"
echo "----------------|------------|-------|----|----|-----------------|----------"

# Показать статус всех deployments
for deployment in $(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    show_deployment_status $deployment
done

echo
echo "Legend:"
echo "  PAUSED: true/false"
echo "  READY: Ready/Total replicas"
echo "  UP: Updated replicas"
echo "  REV: Current revision"
echo "  RS: Number of ReplicaSets"

# Показать приостановленные deployments
echo
echo "=== Paused Deployments Details ==="
for deployment in $(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[?(@.spec.paused==true)].metadata.name}' 2>/dev/null); do
    echo "🔍 $deployment (PAUSED):"
    echo "  ReplicaSets:"
    kubectl get rs -n $NAMESPACE -l app=$deployment -o custom-columns="    NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas" --no-headers
    echo "  Recent events:"
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$deployment --sort-by='.lastTimestamp' | tail -3 | sed 's/^/    /'
    echo
done

# Показать активные rollouts
echo "=== Active Rollouts ==="
for deployment in $(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[?(@.spec.paused!=true)].metadata.name}' 2>/dev/null); do
    if ! kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=1s >/dev/null 2>&1; then
        echo "🔄 $deployment: Rollout in progress"
        kubectl get rs -n $NAMESPACE -l app=$deployment -o custom-columns="    NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas" --no-headers
    fi
done
EOF

chmod +x pause-dashboard.sh
./pause-dashboard.sh
```

### **2. Автоматический мониторинг паузы:**
```bash
# Создать continuous monitoring скрипт
cat << 'EOF' > continuous-pause-monitor.sh
#!/bin/bash

NAMESPACE="pause-demo"
INTERVAL=10  # секунд между проверками

echo "=== Continuous Pause Monitor ==="
echo "Namespace: $NAMESPACE"
echo "Check interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop"
echo

# Функция для логирования
log_event() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Функция для проверки изменений
check_deployments() {
    local current_state=$(kubectl get deployments -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.paused}:{.status.readyReplicas}:{.status.updatedReplicas} {end}' 2>/dev/null)
    
    if [ "$current_state" != "$previous_state" ]; then
        log_event "State change detected:"
        
        # Проверить каждый deployment
        for deployment in $(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
            local paused=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.paused}')
            local ready=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
            local replicas=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')
            
            if [ "$paused" = "true" ]; then
                log_event "  ⏸️  $deployment: PAUSED (${ready:-0}/$replicas ready)"
            elif kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=1s >/dev/null 2>&1; then
                log_event "  ✅ $deployment: COMPLETE (${ready:-0}/$replicas ready)"
            else
                log_event "  🔄 $deployment: IN PROGRESS (${ready:-0}/$replicas ready)"
            fi
        done
        
        previous_state="$current_state"
        echo
    fi
}

# Начальное состояние
previous_state=""
check_deployments

# Continuous monitoring
while true; do
    sleep $INTERVAL
    check_deployments
done
EOF

chmod +x continuous-pause-monitor.sh

# Запустить в фоне для мониторинга
# ./continuous-pause-monitor.sh &
# MONITOR_PID=$!
```

## 🎯 **Best Practices для Pause/Resume:**

### **1. Когда использовать Pause/Resume:**
```bash
# Создать guide по использованию
cat << 'EOF'
=== Best Practices для Pause/Resume ===

✅ КОГДА ИСПОЛЬЗОВАТЬ:
1. Комплексные обновления с множественными изменениями
2. Тестирование частичных rollouts
3. Координация обновлений с внешними системами
4. Отладка проблем развертывания
5. Staged rollouts с ручным контролем

❌ КОГДА НЕ ИСПОЛЬЗОВАТЬ:
1. Простые обновления образов
2. Production среды без proper testing
3. Автоматизированные CI/CD пайплайны
4. Критичные security updates

🔧 РЕКОМЕНДАЦИИ:
1. Всегда тестируйте pause/resume в staging
2. Документируйте причину паузы
3. Устанавливайте timeout для автоматического resume
4. Мониторьте состояние во время паузы
5. Имейте план rollback

📋 CHECKLIST ПЕРЕД PAUSE:
□ Проверить текущее состояние deployment
□ Убедиться в наличии rollback плана
□ Подготовить список изменений
□ Настроить мониторинг
□ Уведомить команду о паузе
EOF
```

### **2. Автоматизация с timeout:**
```bash
# Создать скрипт с автоматическим timeout
cat << 'EOF' > timed-pause-rollout.sh
#!/bin/bash

NAMESPACE="$1"
DEPLOYMENT="$2"
NEW_IMAGE="$3"
PAUSE_TIMEOUT="${4:-300}"  # 5 минут по умолчанию

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT" ] || [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <namespace> <deployment> <new-image> [pause-timeout-seconds]"
    exit 1
fi

echo "=== Timed Pause Rollout ==="
echo "Deployment: $DEPLOYMENT"
echo "Namespace: $NAMESPACE"
echo "New Image: $NEW_IMAGE"
echo "Pause Timeout: ${PAUSE_TIMEOUT}s"
echo

# Начать обновление и приостановить
kubectl set image deployment/$DEPLOYMENT web=$NEW_IMAGE -n $NAMESPACE
kubectl rollout pause deployment/$DEPLOYMENT -n $NAMESPACE

echo "Rollout paused. You have $PAUSE_TIMEOUT seconds to make additional changes."
echo "Commands you can run:"
echo "  kubectl set env deployment/$DEPLOYMENT KEY=VALUE -n $NAMESPACE"
echo "  kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{...}'"
echo "  kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE"
echo "  kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE"
echo

# Countdown timer
for i in $(seq $PAUSE_TIMEOUT -1 1); do
    # Проверить, не был ли rollout возобновлен вручную
    paused=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.paused}')
    if [ "$paused" != "true" ]; then
        echo "Rollout was resumed manually"
        break
    fi
    
    # Показать countdown каждые 30 секунд
    if [ $((i % 30)) -eq 0 ]; then
        echo "Time remaining: ${i}s"
    fi
    
    sleep 1
done

# Проверить, нужно ли автоматически возобновить
paused=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.paused}')
if [ "$paused" = "true" ]; then
    echo "Timeout reached. Automatically resuming rollout..."
    kubectl rollout resume deployment/$DEPLOYMENT -n $NAMESPACE
fi

# Дождаться завершения
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
echo "✅ Rollout completed"
EOF

chmod +x timed-pause-rollout.sh

# Пример использования
# ./timed-pause-rollout.sh pause-demo webapp nginx:1.24 120
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все deployments
kubectl delete deployments --all -n pause-demo

# Удалить все services
kubectl delete services --all -n pause-demo

# Удалить все configmaps
kubectl delete configmaps --all -n pause-demo

# Удалить namespace
kubectl delete namespace pause-demo

# Удалить скрипты
rm -f monitor-pause-resume.sh conditional-pause.sh interactive-rollout.sh automated-test-rollout.sh diagnose-pause.sh fix-paused-deployment.sh pause-dashboard.sh continuous-pause-monitor.sh timed-pause-rollout.sh
```

## 📋 **Сводка команд Pause/Resume:**

### **Основные команды:**
```bash
# Приостановить rollout
kubectl rollout pause deployment/myapp -n namespace

# Возобновить rollout
kubectl rollout resume deployment/myapp -n namespace

# Проверить статус паузы
kubectl get deployment myapp -n namespace -o jsonpath='{.spec.paused}'

# Проверить rollout статус
kubectl rollout status deployment/myapp -n namespace

# Внести изменения во время паузы
kubectl set image deployment/myapp container=new-image -n namespace
kubectl set env deployment/myapp KEY=VALUE -n namespace
kubectl patch deployment myapp -n namespace -p '{"spec":{"template":{"spec":{"containers":[{"name":"container","resources":{"limits":{"memory":"256Mi"}}}]}}}}'
```

### **Диагностика:**
```bash
# Проверить ReplicaSet'ы
kubectl get rs -n namespace -l app=myapp

# Проверить события
kubectl get events -n namespace --field-selector involvedObject.name=myapp

# Детальная информация
kubectl describe deployment myapp -n namespace

# История rollout
kubectl rollout history deployment/myapp -n namespace
```

## 🎯 **Ключевые принципы Pause/Resume:**

### **1. Планирование:**
- **Подготовьте список изменений** заранее
- **Тестируйте в staging** среде
- **Документируйте процесс** для команды
- **Имейте план rollback**

### **2. Мониторинг:**
- **Отслеживайте состояние** во время паузы
- **Проверяйте health checks** регулярно
- **Мониторьте ресурсы** и производительность
- **Логируйте все изменения**

### **3. Безопасность:**
- **Не оставляйте deployments** на паузе надолго
- **Используйте timeout** для автоматического resume
- **Тестируйте изменения** перед resume
- **Имейте процедуры восстановления**

### **4. Автоматизация:**
- **Создавайте скрипты** для повторяющихся операций
- **Интегрируйте с CI/CD** пайплайнами
- **Используйте мониторинг** для автоматических действий
- **Документируйте процедуры**

**Pause и Resume — это мощные инструменты для контролируемых обновлений, но требуют careful planning и proper monitoring для безопасного использования в production!**
