# 42. Чем отличается Deployment от ReplicaSet?

## 🎯 **Основные отличия Deployment от ReplicaSet**

**Deployment** — это высокоуровневый контроллер, который управляет ReplicaSet'ами и предоставляет декларативные обновления для Pod'ов. В то время как ReplicaSet обеспечивает только поддержание количества реплик, Deployment добавляет возможности управления версиями и стратегиями развертывания.

## 🏗️ **Архитектурные различия:**

### **1. Иерархия управления:**
- **ReplicaSet**: Напрямую управляет Pod'ами
- **Deployment**: Управляет ReplicaSet'ами, которые управляют Pod'ами

### **2. Функциональные возможности:**
| Функция | ReplicaSet | Deployment |
|---------|------------|------------|
| Поддержание количества реплик | ✅ | ✅ |
| Rolling updates | ❌ | ✅ |
| Rollback | ❌ | ✅ |
| История версий | ❌ | ✅ |
| Стратегии развертывания | ❌ | ✅ |
| Pause/Resume | ❌ | ✅ |

### **3. Управление жизненным циклом:**
- **ReplicaSet**: Статическое управление
- **Deployment**: Динамическое управление с версионированием

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание и сравнение ReplicaSet vs Deployment:**
```bash
# Создать namespace для демонстрации
kubectl create namespace deployment-vs-rs

# Создать ReplicaSet
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  namespace: deployment-vs-rs
  labels:
    app: nginx-rs
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-rs
  template:
    metadata:
      labels:
        app: nginx-rs
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
EOF

# Создать Deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: deployment-vs-rs
  labels:
    app: nginx-deploy
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-deploy
  template:
    metadata:
      labels:
        app: nginx-deploy
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
EOF

# Сравнить созданные ресурсы
echo "=== ReplicaSet ==="
kubectl get rs -n deployment-vs-rs
kubectl get pods -n deployment-vs-rs -l app=nginx-rs

echo "=== Deployment ==="
kubectl get deployment -n deployment-vs-rs
kubectl get rs -n deployment-vs-rs -l app=nginx-deploy
kubectl get pods -n deployment-vs-rs -l app=nginx-deploy

# Проверить owner references
echo "=== Owner References ==="
kubectl get pods -n deployment-vs-rs -l app=nginx-deploy -o yaml | grep -A 10 ownerReferences
```

### **2. Демонстрация обновления образа:**
```bash
# Попытка обновить ReplicaSet (не работает как ожидается)
echo "=== Обновление ReplicaSet ==="
kubectl patch replicaset nginx-replicaset -n deployment-vs-rs -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.21"}]}}}}'

# Проверить, что Pod'ы не обновились
kubectl get pods -n deployment-vs-rs -l app=nginx-rs -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Обновление Deployment (работает корректно)
echo "=== Обновление Deployment ==="
kubectl set image deployment/nginx-deployment nginx=nginx:1.21 -n deployment-vs-rs

# Мониторинг rolling update
kubectl rollout status deployment/nginx-deployment -n deployment-vs-rs

# Проверить обновленные Pod'ы
kubectl get pods -n deployment-vs-rs -l app=nginx-deploy -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Проверить историю ReplicaSet'ов
kubectl get rs -n deployment-vs-rs -l app=nginx-deploy
```

### **3. Демонстрация rollback возможностей:**
```bash
# Проверить историю Deployment
kubectl rollout history deployment/nginx-deployment -n deployment-vs-rs

# Сделать еще одно обновление
kubectl set image deployment/nginx-deployment nginx=nginx:1.22 -n deployment-vs-rs
kubectl rollout status deployment/nginx-deployment -n deployment-vs-rs

# Проверить обновленную историю
kubectl rollout history deployment/nginx-deployment -n deployment-vs-rs

# Откатиться к предыдущей версии
kubectl rollout undo deployment/nginx-deployment -n deployment-vs-rs

# Проверить rollback
kubectl rollout status deployment/nginx-deployment -n deployment-vs-rs
kubectl get pods -n deployment-vs-rs -l app=nginx-deploy -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Откатиться к конкретной ревизии
kubectl rollout undo deployment/nginx-deployment --to-revision=1 -n deployment-vs-rs
```

## 🔧 **Детальное сравнение функциональности:**

### **1. Управление версиями:**
```bash
# Deployment с аннотациями для отслеживания изменений
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: versioned-deployment
  namespace: deployment-vs-rs
  annotations:
    deployment.kubernetes.io/revision: "1"
spec:
  replicas: 3
  revisionHistoryLimit: 10  # Количество старых ReplicaSet'ов для хранения
  selector:
    matchLabels:
      app: versioned-app
  template:
    metadata:
      labels:
        app: versioned-app
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
EOF

# Проверить ревизии
kubectl rollout history deployment/versioned-deployment -n deployment-vs-rs

# Сделать несколько обновлений с аннотациями
kubectl annotate deployment/versioned-deployment kubernetes.io/change-cause="Initial deployment with nginx:1.20" -n deployment-vs-rs

kubectl set image deployment/versioned-deployment app=nginx:1.21 -n deployment-vs-rs
kubectl annotate deployment/versioned-deployment kubernetes.io/change-cause="Updated to nginx:1.21" -n deployment-vs-rs

kubectl set image deployment/versioned-deployment app=nginx:1.22 -n deployment-vs-rs
kubectl annotate deployment/versioned-deployment kubernetes.io/change-cause="Updated to nginx:1.22" -n deployment-vs-rs

# Проверить детальную историю
kubectl rollout history deployment/versioned-deployment -n deployment-vs-rs
kubectl rollout history deployment/versioned-deployment --revision=2 -n deployment-vs-rs
```

### **2. Стратегии развертывания:**
```bash
# Deployment с RollingUpdate стратегией
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-deployment
  namespace: deployment-vs-rs
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # Максимум 1 Pod может быть недоступен
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
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

# Deployment с Recreate стратегией
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-deployment
  namespace: deployment-vs-rs
spec:
  replicas: 3
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
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
EOF

# Сравнить поведение при обновлении
echo "=== Rolling Update ==="
kubectl set image deployment/rolling-deployment app=nginx:1.21 -n deployment-vs-rs &
kubectl get pods -n deployment-vs-rs -l app=rolling-app -w &
WATCH_PID1=$!
sleep 15 && kill $WATCH_PID1

echo "=== Recreate Update ==="
kubectl set image deployment/recreate-deployment app=nginx:1.21 -n deployment-vs-rs &
kubectl get pods -n deployment-vs-rs -l app=recreate-app -w &
WATCH_PID2=$!
sleep 15 && kill $WATCH_PID2
```

### **3. Pause и Resume функциональность:**
```bash
# Создать Deployment для демонстрации pause/resume
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pausable-deployment
  namespace: deployment-vs-rs
spec:
  replicas: 4
  selector:
    matchLabels:
      app: pausable-app
  template:
    metadata:
      labels:
        app: pausable-app
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
EOF

# Приостановить Deployment
kubectl rollout pause deployment/pausable-deployment -n deployment-vs-rs

# Сделать несколько изменений (они не будут применены)
kubectl set image deployment/pausable-deployment app=nginx:1.21 -n deployment-vs-rs
kubectl set env deployment/pausable-deployment VERSION=2.0 -n deployment-vs-rs

# Проверить, что изменения не применились
kubectl get pods -n deployment-vs-rs -l app=pausable-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Возобновить Deployment
kubectl rollout resume deployment/pausable-deployment -n deployment-vs-rs

# Проверить применение изменений
kubectl rollout status deployment/pausable-deployment -n deployment-vs-rs
kubectl get pods -n deployment-vs-rs -l app=pausable-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

## 🏭 **Production сценарии использования:**

### **1. Blue-Green Deployment через Deployment:**
```bash
# Blue версия (текущая production)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  namespace: deployment-vs-rs
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "blue"
        - name: COLOR
          value: "#0000FF"
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: deployment-vs-rs
spec:
  selector:
    app: myapp
    version: blue  # Изначально направляем на blue
  ports:
  - port: 80
    targetPort: 80
EOF

# Green версия (новая версия)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  namespace: deployment-vs-rs
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "green"
        - name: COLOR
          value: "#00FF00"
EOF

# Проверить оба Deployment'а
kubectl get deployments -n deployment-vs-rs -l app=myapp
kubectl get pods -n deployment-vs-rs -l app=myapp --show-labels

# Переключить Service на green версию
kubectl patch service myapp-service -n deployment-vs-rs -p '{"spec":{"selector":{"version":"green"}}}'

# Проверить переключение
kubectl describe service myapp-service -n deployment-vs-rs

# После проверки удалить blue версию
kubectl delete deployment app-blue -n deployment-vs-rs
```

### **2. Canary Deployment:**
```bash
# Основная версия (90% трафика)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
  namespace: deployment-vs-rs
  labels:
    app: canary-app
    track: stable
spec:
  replicas: 9  # 90% трафика
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
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: TRACK
          value: "stable"
EOF

# Canary версия (10% трафика)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
  namespace: deployment-vs-rs
  labels:
    app: canary-app
    track: canary
spec:
  replicas: 1  # 10% трафика
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
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: TRACK
          value: "canary"
---
apiVersion: v1
kind: Service
metadata:
  name: canary-service
  namespace: deployment-vs-rs
spec:
  selector:
    app: canary-app  # Выбирает оба track'а
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить распределение трафика
kubectl get pods -n deployment-vs-rs -l app=canary-app --show-labels
kubectl get endpoints canary-service -n deployment-vs-rs
```

## 🚨 **Troubleshooting различий:**

### **1. Диагностика проблем Deployment vs ReplicaSet:**
```bash
# Проблемы с ReplicaSet
echo "=== ReplicaSet Troubleshooting ==="
kubectl get rs -n deployment-vs-rs
kubectl describe rs nginx-replicaset -n deployment-vs-rs

# Проблемы с Deployment
echo "=== Deployment Troubleshooting ==="
kubectl get deployments -n deployment-vs-rs
kubectl describe deployment nginx-deployment -n deployment-vs-rs

# Проверить статус rollout
kubectl rollout status deployment/nginx-deployment -n deployment-vs-rs

# Проверить события для обоих типов ресурсов
kubectl get events -n deployment-vs-rs --field-selector involvedObject.kind=ReplicaSet
kubectl get events -n deployment-vs-rs --field-selector involvedObject.kind=Deployment

# Проверить связи между ресурсами
kubectl get rs -n deployment-vs-rs -o yaml | grep -A 10 ownerReferences
```

### **2. Сравнение производительности обновлений:**
```bash
# Создать большой Deployment для тестирования
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: performance-test
  namespace: deployment-vs-rs
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2
      maxSurge: 2
  selector:
    matchLabels:
      app: perf-test
  template:
    metadata:
      labels:
        app: perf-test
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 2
EOF

# Измерить время обновления
echo "Starting update at: $(date)"
kubectl set image deployment/performance-test app=nginx:1.21 -n deployment-vs-rs
kubectl rollout status deployment/performance-test -n deployment-vs-rs
echo "Update completed at: $(date)"

# Проверить историю ReplicaSet'ов
kubectl get rs -n deployment-vs-rs -l app=perf-test
```

## 🎯 **Best Practices и рекомендации:**

### **1. Когда использовать Deployment:**
```bash
# ✅ Используйте Deployment для:
# - Stateless приложений
# - Web серверов
# - API сервисов
# - Микросервисов
# - Приложений, требующих rolling updates

# Пример правильного использования Deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
  namespace: deployment-vs-rs
  labels:
    app: web-api
    tier: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: web-api
  template:
    metadata:
      labels:
        app: web-api
        tier: backend
    spec:
      containers:
      - name: api
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
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
```

### **2. Когда НЕ использовать ReplicaSet напрямую:**
```bash
# ❌ НЕ используйте ReplicaSet напрямую для:
# - Production приложений
# - Приложений, требующих обновлений
# - Сложных deployment стратегий

# Вместо этого всегда используйте Deployment
echo "ReplicaSet следует использовать только:"
echo "1. Для понимания внутренней архитектуры Kubernetes"
echo "2. При создании custom controllers"
echo "3. В очень специфических случаях, где Deployment не подходит"
```

### **3. Мониторинг и метрики:**
```bash
# Метрики для Deployment
kubectl get deployment -n deployment-vs-rs -o wide
kubectl top pods -n deployment-vs-rs

# Проверить resource utilization
kubectl describe deployment nginx-deployment -n deployment-vs-rs | grep -A 10 "Conditions"

# Проверить rollout статус
kubectl rollout status deployment/nginx-deployment -n deployment-vs-rs --timeout=300s
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все Deployment'ы
kubectl delete deployments --all -n deployment-vs-rs

# Удалить все ReplicaSet'ы
kubectl delete rs --all -n deployment-vs-rs

# Удалить Service'ы
kubectl delete services --all -n deployment-vs-rs

# Удалить namespace
kubectl delete namespace deployment-vs-rs
```

## 📋 **Сводная таблица различий:**

| Аспект | ReplicaSet | Deployment |
|--------|------------|------------|
| **Основная функция** | Поддержание количества реплик | Управление версиями и обновлениями |
| **Обновления** | Ручное пересоздание Pod'ов | Автоматические rolling updates |
| **Rollback** | Невозможен | Автоматический rollback |
| **История версий** | Нет | Да (configurable) |
| **Стратегии развертывания** | Нет | RollingUpdate, Recreate |
| **Pause/Resume** | Нет | Да |
| **Production готовность** | Нет | Да |
| **Сложность управления** | Низкая | Средняя |
| **Use case** | Базовое понимание | Production приложения |

## 🎯 **Ключевые выводы:**

### **ReplicaSet:**
- Низкоуровневый примитив
- Только поддержание количества реплик
- Не подходит для production
- Важен для понимания архитектуры

### **Deployment:**
- Высокоуровневая абстракция
- Полный lifecycle management
- Production-ready
- Рекомендуется для всех stateless приложений

**Deployment является предпочтительным выбором для управления stateless приложениями в production среде, предоставляя все необходимые возможности для безопасных обновлений и управления версиями!**
