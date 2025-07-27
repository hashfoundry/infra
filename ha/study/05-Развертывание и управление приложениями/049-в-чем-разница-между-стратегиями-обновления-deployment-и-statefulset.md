# 49. В чем разница между стратегиями обновления Deployment и StatefulSet?

## 🎯 **Стратегии обновления в Kubernetes**

**Стратегии обновления** определяют, как Kubernetes заменяет старые Pod'ы новыми при изменении конфигурации. Deployment и StatefulSet используют разные подходы из-за различий в их назначении: Deployment для stateless приложений, StatefulSet для stateful приложений с требованиями к порядку и идентичности.

## 🏗️ **Основные различия:**

### **1. Deployment стратегии:**
- **RollingUpdate**: Постепенная замена Pod'ов (по умолчанию)
- **Recreate**: Удаление всех Pod'ов перед созданием новых
- **Параллельное обновление**: Может обновлять несколько Pod'ов одновременно
- **Без гарантий порядка**: Pod'ы создаются и удаляются в произвольном порядке

### **2. StatefulSet стратегии:**
- **RollingUpdate**: Последовательная замена Pod'ов (по умолчанию)
- **OnDelete**: Ручное управление обновлениями
- **Упорядоченное обновление**: Строгий порядок обновления (от большего индекса к меньшему)
- **Сохранение идентичности**: Pod'ы сохраняют имена и PVC при обновлении

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Deployment RollingUpdate стратегия:**
```bash
# Создать namespace для демонстрации
kubectl create namespace update-strategies-demo

# Создать Deployment с RollingUpdate
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-demo
  namespace: update-strategies-demo
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1    # Максимум 1 Pod недоступен
      maxSurge: 2          # Максимум 2 дополнительных Pod'а
  selector:
    matchLabels:
      app: deployment-demo
  template:
    metadata:
      labels:
        app: deployment-demo
        version: "1.0"
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
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
EOF

# Проверить начальное состояние
kubectl get deployment deployment-demo -n update-strategies-demo
kubectl get pods -n update-strategies-demo -l app=deployment-demo -o wide

# Выполнить RollingUpdate обновление
echo "=== Starting Deployment RollingUpdate ==="
kubectl set image deployment/deployment-demo web=nginx:1.21 -n update-strategies-demo

# Мониторинг обновления
kubectl rollout status deployment/deployment-demo -n update-strategies-demo

# Проверить результат
kubectl get pods -n update-strategies-demo -l app=deployment-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
```

### **2. Deployment Recreate стратегия:**
```bash
# Создать Deployment с Recreate стратегией
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-demo
  namespace: update-strategies-demo
spec:
  replicas: 3
  strategy:
    type: Recreate    # Полная замена всех Pod'ов
  selector:
    matchLabels:
      app: recreate-demo
  template:
    metadata:
      labels:
        app: recreate-demo
        version: "1.0"
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
        - name: STRATEGY
          value: "Recreate"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

# Проверить начальное состояние
kubectl get deployment recreate-demo -n update-strategies-demo
kubectl get pods -n update-strategies-demo -l app=recreate-demo -o wide

# Выполнить Recreate обновление
echo "=== Starting Deployment Recreate ==="
kubectl set image deployment/recreate-demo web=nginx:1.21 -n update-strategies-demo

# Мониторинг обновления (будет полный простой)
kubectl rollout status deployment/recreate-demo -n update-strategies-demo

# Проверить результат
kubectl get pods -n update-strategies-demo -l app=recreate-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
```

### **3. StatefulSet RollingUpdate стратегия:**
```bash
# Создать StatefulSet с RollingUpdate
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-demo
  namespace: update-strategies-demo
spec:
  serviceName: statefulset-service
  replicas: 3
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0    # Обновлять все Pod'ы (от большего индекса к меньшему)
  selector:
    matchLabels:
      app: statefulset-demo
  template:
    metadata:
      labels:
        app: statefulset-demo
        version: "1.0"
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
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
---
apiVersion: v1
kind: Service
metadata:
  name: statefulset-service
  namespace: update-strategies-demo
spec:
  clusterIP: None
  selector:
    app: statefulset-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить начальное состояние
kubectl get statefulset statefulset-demo -n update-strategies-demo
kubectl get pods -n update-strategies-demo -l app=statefulset-demo -o wide

# Выполнить StatefulSet RollingUpdate обновление
echo "=== Starting StatefulSet RollingUpdate ==="
kubectl set image statefulset/statefulset-demo web=nginx:1.21 -n update-strategies-demo

# Мониторинг обновления (последовательное: 2 -> 1 -> 0)
kubectl rollout status statefulset/statefulset-demo -n update-strategies-demo

# Проверить результат и порядок обновления
kubectl get pods -n update-strategies-demo -l app=statefulset-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase --sort-by=.metadata.name
```

### **4. StatefulSet OnDelete стратегия:**
```bash
# Создать StatefulSet с OnDelete стратегией
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ondelete-demo
  namespace: update-strategies-demo
spec:
  serviceName: ondelete-service
  replicas: 3
  updateStrategy:
    type: OnDelete    # Ручное управление обновлениями
  selector:
    matchLabels:
      app: ondelete-demo
  template:
    metadata:
      labels:
        app: ondelete-demo
        version: "1.0"
    spec:
      containers:
      - name: web
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "OnDelete StatefulSet v1.0 starting: $(hostname)"
          while true; do
            echo "$(date): OnDelete v1.0 running on $(hostname)"
            sleep 30
          done
        env:
        - name: VERSION
          value: "1.0"
        - name: STRATEGY
          value: "OnDelete"
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: ondelete-service
  namespace: update-strategies-demo
spec:
  clusterIP: None
  selector:
    app: ondelete-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить начальное состояние
kubectl get statefulset ondelete-demo -n update-strategies-demo
kubectl get pods -n update-strategies-demo -l app=ondelete-demo -o wide

# Попытаться обновить образ (не сработает автоматически)
echo "=== Attempting OnDelete Update ==="
kubectl set image statefulset/ondelete-demo web=busybox:1.36 -n update-strategies-demo

# Проверить, что Pod'ы не обновились автоматически
sleep 10
kubectl get pods -n update-strategies-demo -l app=ondelete-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

# Ручное обновление Pod'ов (в порядке StatefulSet: от большего к меньшему)
echo "=== Manual OnDelete Updates ==="
for pod in ondelete-demo-2 ondelete-demo-1 ondelete-demo-0; do
    echo "Manually deleting pod: $pod"
    kubectl delete pod $pod -n update-strategies-demo
    
    # Дождаться пересоздания
    echo "Waiting for pod recreation..."
    kubectl wait --for=condition=Ready pod/$pod -n update-strategies-demo --timeout=60s
    
    # Проверить новый образ
    image=$(kubectl get pod $pod -n update-strategies-demo -o jsonpath='{.spec.containers[0].image}')
    echo "  $pod recreated with image: $image"
    echo
done

# Финальная проверка
kubectl get pods -n update-strategies-demo -l app=ondelete-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
```

## 🔧 **Advanced техники:**

### **1. StatefulSet Partition обновления:**
```bash
# Создать StatefulSet с partition для поэтапного обновления
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: partition-demo
  namespace: update-strategies-demo
spec:
  serviceName: partition-service
  replicas: 5
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 3    # Обновлять только Pod'ы с индексом >= 3
  selector:
    matchLabels:
      app: partition-demo
  template:
    metadata:
      labels:
        app: partition-demo
        version: "1.0"
    spec:
      containers:
      - name: web
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: partition-service
  namespace: update-strategies-demo
spec:
  clusterIP: None
  selector:
    app: partition-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить начальное состояние
kubectl get statefulset partition-demo -n update-strategies-demo
kubectl get pods -n update-strategies-demo -l app=partition-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

# Обновить образ (обновятся только Pod'ы 3 и 4)
echo "=== Updating with partition=3 (only pods 3,4 will update) ==="
kubectl set image statefulset/partition-demo web=nginx:1.21 -n update-strategies-demo

# Дождаться частичного обновления
sleep 30
echo "After partial update:"
kubectl get pods -n update-strategies-demo -l app=partition-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

# Уменьшить partition для обновления Pod'а 2
echo "=== Reducing partition to 2 ==="
kubectl patch statefulset partition-demo -n update-strategies-demo -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'

sleep 20
echo "After partition=2:"
kubectl get pods -n update-strategies-demo -l app=partition-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

# Убрать partition полностью
echo "=== Removing partition (partition=0) ==="
kubectl patch statefulset partition-demo -n update-strategies-demo -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'

sleep 30
echo "After complete update:"
kubectl get pods -n update-strategies-demo -l app=partition-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
```

### **2. Сравнение поведения при сбоях:**
```bash
# Создать скрипт для тестирования поведения при сбоях
cat << 'EOF' > test-failure-behavior.sh
#!/bin/bash

NAMESPACE="update-strategies-demo"
BAD_IMAGE="nginx:nonexistent-tag"

echo "=== Failure Behavior Testing ==="
echo "Testing with bad image: $BAD_IMAGE"
echo

# Тест 1: Deployment с плохим образом
echo "=== Test 1: Deployment with bad image ==="
kubectl set image deployment/deployment-demo web=$BAD_IMAGE -n $NAMESPACE

echo "Waiting 60s to observe behavior..."
sleep 60

echo "Deployment status after bad update:"
kubectl get deployment deployment-demo -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=deployment-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,IMAGE:.spec.containers[0].image

# Откатить Deployment
echo "Rolling back Deployment..."
kubectl rollout undo deployment/deployment-demo -n $NAMESPACE
kubectl rollout status deployment/deployment-demo -n $NAMESPACE

echo
echo "=== Test 2: StatefulSet with bad image ==="
kubectl set image statefulset/statefulset-demo web=$BAD_IMAGE -n $NAMESPACE

echo "Waiting 60s to observe behavior..."
sleep 60

echo "StatefulSet status after bad update:"
kubectl get statefulset statefulset-demo -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=statefulset-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,IMAGE:.spec.containers[0].image

# Откатить StatefulSet
echo "Rolling back StatefulSet..."
kubectl rollout undo statefulset/statefulset-demo -n $NAMESPACE
kubectl rollout status statefulset/statefulset-demo -n $NAMESPACE

echo
echo "=== Failure Behavior Analysis ==="
echo "Deployment behavior:"
echo "  - Continues updating pods in parallel"
echo "  - Maintains maxUnavailable constraint"
echo "  - Old pods remain running if new pods fail"
echo "  - Can be quickly rolled back"
echo
echo "StatefulSet behavior:"
echo "  - Updates pods sequentially (highest index first)"
echo "  - Stops update if any pod fails"
echo "  - Maintains ordered deployment"
echo "  - Rollback also follows sequential order"
EOF

chmod +x test-failure-behavior.sh
./test-failure-behavior.sh
```

## 📊 **Сравнительная таблица стратегий:**

```bash
# Создать comprehensive сравнение
cat << 'EOF'
=== Comprehensive Strategy Comparison ===

ХАРАКТЕРИСТИКА      | DEPLOY ROLLING | DEPLOY RECREATE | STATEFUL ROLLING | STATEFUL ONDELETE
--------------------|----------------|-----------------|------------------|------------------
Порядок обновления  | Параллельный   | Все сразу       | Последовательный | Ручной
Время простоя       | Минимальное    | Полное          | Минимальное      | Контролируемое
Контроль процесса   | Автоматический | Автоматический  | Автоматический   | Ручной
Скорость обновления | Быстрая        | Очень быстрая   | Медленная        | Контролируемая
Сохранение данных   | Не гарантируется| Не гарантируется| Гарантируется    | Гарантируется
Идентичность Pod'ов | Случайная      | Случайная       | Стабильная       | Стабильная
Откат при ошибке    | Автоматический | Ручной          | Останавливается  | Ручной
Использование       | Stateless apps | Legacy apps     | Databases        | Critical systems

=== Detailed Comparison ===

🔄 DEPLOYMENT ROLLINGUPDATE:
  ✅ Преимущества:
    - Нулевое время простоя
    - Быстрое обновление
    - Автоматический откат
    - Параллельная обработка
  ❌ Недостатки:
    - Нет гарантий порядка
    - Возможны временные несоответствия
    - Не подходит для stateful приложений

🔄 DEPLOYMENT RECREATE:
  ✅ Преимущества:
    - Простота реализации
    - Полная замена всех Pod'ов
    - Нет версионных конфликтов
  ❌ Недостатки:
    - Полное время простоя
    - Не подходит для production
    - Потеря доступности сервиса

🔄 STATEFULSET ROLLINGUPDATE:
  ✅ Преимущества:
    - Сохранение порядка и идентичности
    - Безопасность для stateful приложений
    - Поддержка partition обновлений
    - Сохранение данных
  ❌ Недостатки:
    - Медленное обновление
    - Последовательная обработка
    - Остановка при ошибках

🔄 STATEFULSET ONDELETE:
  ✅ Преимущества:
    - Полный контроль процесса
    - Максимальная безопасность
    - Возможность тестирования
    - Гибкость в планировании
  ❌ Недостатки:
    - Требует ручного вмешательства
    - Медленный процесс
    - Сложность автоматизации
EOF
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все ресурсы
kubectl delete namespace update-strategies-demo

# Удалить скрипты
rm -f test-failure-behavior.sh
```

## 📋 **Сводка команд для стратегий обновления:**

### **Deployment команды:**
```bash
# Установить RollingUpdate стратегию
kubectl patch deployment myapp -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1,"maxSurge":2}}}}'

# Установить Recreate стратегию
kubectl patch deployment myapp -p '{"spec":{"strategy":{"type":"Recreate"}}}'

# Проверить стратегию
kubectl get deployment myapp -o jsonpath='{.spec.strategy}'

# Обновить образ
kubectl set image deployment/myapp container=new-image

# Проверить статус rollout
kubectl rollout status deployment/myapp

# Откатить обновление
kubectl rollout undo deployment/myapp
```

### **StatefulSet команды:**
```bash
# Установить RollingUpdate стратегию
kubectl patch statefulset myapp -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":0}}}}'

# Установить OnDelete стратегию
kubectl patch statefulset myapp -p '{"spec":{"updateStrategy":{"type":"OnDelete"}}}'

# Установить partition для частичного обновления
kubectl patch statefulset myapp -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'

# Проверить стратегию
kubectl get statefulset myapp -o jsonpath='{.spec.updateStrategy}'

# Обновить образ
kubectl set image statefulset/myapp container=new-image

# Для OnDelete: ручное удаление Pod'ов
kubectl delete pod myapp-2 myapp-1 myapp-0
```

## 🎯 **Ключевые различия и рекомендации:**

### **1. Выбор стратегии для Deployment:**
- **RollingUpdate**: Для большинства stateless приложений
- **Recreate**: Для legacy приложений или когда нужна полная замена

### **2. Выбор стратегии для StatefulSet:**
- **RollingUpdate**: Для большинства stateful приложений
- **OnDelete**: Для критических систем, требующих ручного контроля

### **3. Параметры настройки:**
- **maxUnavailable**: Контролирует количество недоступных Pod'ов
- **maxSurge**: Контролирует количество дополнительных Pod'ов (только Deployment)
- **partition**: Контролирует частичные обновления (только StatefulSet)

### **4. Мониторинг и безопасность:**
- **Всегда мониторьте** процесс обновления
- **Имейте план отката** для каждой стратегии
- **Тестируйте обновления** в staging среде
- **Настройте health checks** для автоматической проверки

**Правильный выбор стратегии обновления критичен для обеспечения доступности и безопасности приложений в production среде!**
