# 48. Как обновлять DaemonSets?

## 🎯 **Обновление DaemonSets в Kubernetes**

**Обновление DaemonSets** — это процесс изменения конфигурации Pod'ов, которые работают на каждом узле кластера. В отличие от обычных Deployment'ов, DaemonSet обновления требуют особого подхода, поскольку затрагивают системные компоненты на всех узлах одновременно.

## 🏗️ **Стратегии обновления DaemonSet:**

### **1. RollingUpdate (по умолчанию):**
- **Постепенное обновление**: Обновляет Pod'ы по одному или группами
- **Контролируемый процесс**: Можно настроить скорость обновления
- **Безопасность**: Минимизирует риск полного отказа сервиса
- **Откат**: Поддерживает автоматический откат при проблемах

### **2. OnDelete:**
- **Ручное управление**: Pod'ы обновляются только при ручном удалении
- **Полный контроль**: Администратор решает, когда обновлять каждый узел
- **Безопасность**: Максимальный контроль над процессом
- **Гибкость**: Можно обновлять узлы в любом порядке

### **3. Параметры RollingUpdate:**
- **maxUnavailable**: Максимальное количество недоступных Pod'ов
- **maxSurge**: Не поддерживается для DaemonSet (всегда 0)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Подготовка тестового DaemonSet:**
```bash
# Создать namespace для демонстрации
kubectl create namespace daemonset-update-demo

# Создать базовый DaemonSet для обновления
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: update-demo
  namespace: daemonset-update-demo
  labels:
    app: update-demo
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: update-demo
  template:
    metadata:
      labels:
        app: update-demo
        version: "1.0"
    spec:
      containers:
      - name: demo-app
        image: nginx:1.20
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.0"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
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
          initialDelaySeconds: 10
          periodSeconds: 10
        volumeMounts:
        - name: config
          mountPath: /usr/share/nginx/html
      volumes:
      - name: config
        configMap:
          name: demo-config
      tolerations:
      - operator: Exists
        effect: NoSchedule
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
  namespace: daemonset-update-demo
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>DaemonSet Demo v1.0</title></head>
    <body style="background-color: #f0f8ff; text-align: center; padding: 50px;">
      <h1>🚀 DaemonSet Update Demo</h1>
      <p>Version: 1.0</p>
      <p>Node: <span id="node"></span></p>
      <p>Image: nginx:1.20</p>
      <script>
        document.getElementById('node').textContent = window.location.hostname;
      </script>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: update-demo-service
  namespace: daemonset-update-demo
spec:
  selector:
    app: update-demo
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Дождаться готовности
kubectl rollout status daemonset/update-demo -n daemonset-update-demo

# Проверить начальное состояние
kubectl get daemonset update-demo -n daemonset-update-demo
kubectl get pods -n daemonset-update-demo -l app=update-demo -o wide
```

### **2. RollingUpdate обновление:**
```bash
# Создать скрипт для мониторинга обновления
cat << 'EOF' > monitor-daemonset-update.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"
DAEMONSET="update-demo"

echo "=== DaemonSet Update Monitor ==="
echo "DaemonSet: $DAEMONSET"
echo "Namespace: $NAMESPACE"
echo

# Функция для отображения статуса
show_update_status() {
    echo "=== Update Status at $(date) ==="
    
    # Статус DaemonSet
    kubectl get daemonset $DAEMONSET -n $NAMESPACE
    
    # Статус Pod'ов
    echo
    echo "Pod Status:"
    kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IMAGE:.spec.containers[0].image,NODE:.spec.nodeName
    
    # Rollout статус
    echo
    echo "Rollout Status:"
    kubectl rollout status daemonset/$DAEMONSET -n $NAMESPACE --timeout=5s 2>&1 || echo "Rollout in progress..."
    
    echo "----------------------------------------"
    echo
}

# Показать начальное состояние
show_update_status

# Мониторинг в реальном времени
if [ "$1" = "watch" ]; then
    while true; do
        sleep 10
        show_update_status
    done
fi
EOF

chmod +x monitor-daemonset-update.sh

# Показать начальное состояние
./monitor-daemonset-update.sh

# Выполнить RollingUpdate обновление образа
echo "=== Starting RollingUpdate ==="
kubectl set image daemonset/update-demo demo-app=nginx:1.21 -n daemonset-update-demo

# Мониторинг обновления
echo "Monitoring update progress..."
for i in {1..30}; do
    echo "=== Check $i ==="
    ./monitor-daemonset-update.sh
    
    # Проверить, завершилось ли обновление
    if kubectl rollout status daemonset/update-demo -n daemonset-update-demo --timeout=5s >/dev/null 2>&1; then
        echo "✅ Update completed successfully!"
        break
    fi
    
    sleep 10
done

# Финальное состояние
echo "=== Final State ==="
./monitor-daemonset-update.sh
```

### **3. Обновление с изменением конфигурации:**
```bash
# Обновить ConfigMap и DaemonSet одновременно
echo "=== Complex Update: Image + Config + Environment ==="

# Обновить ConfigMap
kubectl patch configmap demo-config -n daemonset-update-demo -p '{"data":{"index.html":"<!DOCTYPE html>\n<html>\n<head><title>DaemonSet Demo v2.0</title></head>\n<body style=\"background-color: #e8f5e8; text-align: center; padding: 50px;\">\n  <h1>🎉 DaemonSet Update Demo v2.0</h1>\n  <p>Version: 2.0</p>\n  <p>Node: <span id=\"node\"></span></p>\n  <p>Image: nginx:1.21</p>\n  <p>Features: Enhanced monitoring, improved performance</p>\n  <script>\n    document.getElementById(\"node\").textContent = window.location.hostname;\n  </script>\n</body>\n</html>"}}'

# Обновить DaemonSet с новыми environment variables и labels
kubectl patch daemonset update-demo -n daemonset-update-demo -p '{"spec":{"template":{"metadata":{"labels":{"app":"update-demo","version":"2.0"}},"spec":{"containers":[{"name":"demo-app","env":[{"name":"VERSION","value":"2.0"},{"name":"NODE_NAME","valueFrom":{"fieldRef":{"fieldPath":"spec.nodeName"}}},{"name":"FEATURE_FLAGS","value":"monitoring=true,performance=enhanced"}],"resources":{"requests":{"memory":"96Mi","cpu":"150m"},"limits":{"memory":"192Mi","cpu":"300m"}}}]}}}}'

# Мониторинг комплексного обновления
echo "Monitoring complex update..."
for i in {1..40}; do
    echo "=== Complex Update Check $i ==="
    ./monitor-daemonset-update.sh
    
    # Проверить environment variables в Pod'ах
    echo "Environment Variables:"
    for pod in $(kubectl get pods -n daemonset-update-demo -l app=update-demo -o jsonpath='{.items[*].metadata.name}'); do
        echo "  $pod:"
        kubectl exec $pod -n daemonset-update-demo -- env | grep -E "(VERSION|FEATURE_FLAGS)" | sed 's/^/    /'
    done
    echo
    
    if kubectl rollout status daemonset/update-demo -n daemonset-update-demo --timeout=5s >/dev/null 2>&1; then
        echo "✅ Complex update completed!"
        break
    fi
    
    sleep 15
done
```

### **4. OnDelete стратегия обновления:**
```bash
# Создать DaemonSet с OnDelete стратегией
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ondelete-demo
  namespace: daemonset-update-demo
  labels:
    app: ondelete-demo
spec:
  updateStrategy:
    type: OnDelete
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
      - name: demo-app
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "OnDelete Demo v1.0 starting on node \$(hostname)"
          while true; do
            echo "\$(date): OnDelete Demo v1.0 running on \$(hostname)"
            sleep 30
          done
        env:
        - name: VERSION
          value: "1.0"
        - name: UPDATE_STRATEGY
          value: "OnDelete"
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
      tolerations:
      - operator: Exists
        effect: NoSchedule
EOF

# Дождаться готовности
kubectl rollout status daemonset/ondelete-demo -n daemonset-update-demo

# Показать начальное состояние
echo "=== OnDelete Demo Initial State ==="
kubectl get daemonset ondelete-demo -n daemonset-update-demo
kubectl get pods -n daemonset-update-demo -l app=ondelete-demo -o wide

# Попытаться обновить образ (не сработает автоматически)
echo "=== Attempting OnDelete Update ==="
kubectl set image daemonset/ondelete-demo demo-app=busybox:1.36 -n daemonset-update-demo

# Проверить, что Pod'ы не обновились
echo "Checking if pods updated automatically..."
sleep 10
kubectl get pods -n daemonset-update-demo -l app=ondelete-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

# Ручное обновление Pod'ов
echo "=== Manual Pod Updates ==="
for pod in $(kubectl get pods -n daemonset-update-demo -l app=ondelete-demo -o jsonpath='{.items[*].metadata.name}'); do
    echo "Manually deleting pod: $pod"
    kubectl delete pod $pod -n daemonset-update-demo
    
    # Дождаться пересоздания
    echo "Waiting for pod recreation..."
    sleep 15
    
    # Проверить новый Pod
    new_pods=$(kubectl get pods -n daemonset-update-demo -l app=ondelete-demo --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')
    echo "New pods: $new_pods"
    
    # Проверить образ нового Pod'а
    for new_pod in $new_pods; do
        image=$(kubectl get pod $new_pod -n daemonset-update-demo -o jsonpath='{.spec.containers[0].image}')
        echo "  $new_pod: $image"
    done
    echo
done

# Финальная проверка OnDelete обновления
echo "=== OnDelete Final State ==="
kubectl get daemonset ondelete-demo -n daemonset-update-demo
kubectl get pods -n daemonset-update-demo -l app=ondelete-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,NODE:.spec.nodeName
```

## 🔧 **Advanced техники обновления DaemonSet:**

### **1. Контролируемое обновление с паузами:**
```bash
# Создать скрипт для поэтапного обновления
cat << 'EOF' > staged-daemonset-update.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"
DAEMONSET="update-demo"
NEW_IMAGE="$1"
PAUSE_BETWEEN_NODES="${2:-30}"  # секунд между обновлениями узлов

if [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <new-image> [pause-seconds]"
    exit 1
fi

echo "=== Staged DaemonSet Update ==="
echo "DaemonSet: $DAEMONSET"
echo "New Image: $NEW_IMAGE"
echo "Pause between nodes: ${PAUSE_BETWEEN_NODES}s"
echo

# Получить список узлов с Pod'ами
nodes=$(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u)
total_nodes=$(echo "$nodes" | wc -l)

echo "Nodes to update: $total_nodes"
echo "$nodes"
echo

# Временно изменить стратегию на OnDelete для полного контроля
echo "Changing update strategy to OnDelete..."
kubectl patch daemonset $DAEMONSET -n $NAMESPACE -p '{"spec":{"updateStrategy":{"type":"OnDelete"}}}'

# Обновить образ (не применится автоматически)
echo "Setting new image: $NEW_IMAGE"
kubectl set image daemonset/$DAEMONSET demo-app=$NEW_IMAGE -n $NAMESPACE

# Поэтапное обновление узлов
node_count=0
for node in $nodes; do
    node_count=$((node_count + 1))
    echo "=== Updating node $node_count/$total_nodes: $node ==="
    
    # Найти Pod на этом узле
    pod=$(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET --field-selector spec.nodeName=$node -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$pod" ]; then
        echo "Current pod on $node: $pod"
        
        # Показать текущий образ
        current_image=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
        echo "Current image: $current_image"
        
        # Удалить Pod
        echo "Deleting pod $pod..."
        kubectl delete pod $pod -n $NAMESPACE
        
        # Дождаться пересоздания
        echo "Waiting for pod recreation on $node..."
        while true; do
            new_pod=$(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET --field-selector spec.nodeName=$node,status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            if [ -n "$new_pod" ] && [ "$new_pod" != "$pod" ]; then
                echo "New pod created: $new_pod"
                
                # Проверить новый образ
                new_image=$(kubectl get pod $new_pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
                echo "New image: $new_image"
                
                # Проверить готовность
                if kubectl wait --for=condition=Ready pod/$new_pod -n $NAMESPACE --timeout=60s; then
                    echo "✅ Pod $new_pod is ready on $node"
                    break
                else
                    echo "❌ Pod $new_pod failed to become ready"
                fi
            fi
            sleep 5
        done
        
        # Пауза перед следующим узлом
        if [ $node_count -lt $total_nodes ]; then
            echo "Pausing ${PAUSE_BETWEEN_NODES}s before next node..."
            sleep $PAUSE_BETWEEN_NODES
        fi
    else
        echo "No pod found on node $node"
    fi
    echo
done

# Вернуть RollingUpdate стратегию
echo "Restoring RollingUpdate strategy..."
kubectl patch daemonset $DAEMONSET -n $NAMESPACE -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}}}'

echo "✅ Staged update completed!"
EOF

chmod +x staged-daemonset-update.sh

# Пример использования
# ./staged-daemonset-update.sh nginx:1.22 45
```

### **2. Обновление с проверкой здоровья:**
```bash
# Создать скрипт для обновления с health checks
cat << 'EOF' > health-aware-update.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"
DAEMONSET="update-demo"
NEW_IMAGE="$1"
HEALTH_CHECK_URL="$2"

if [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <new-image> [health-check-url]"
    exit 1
fi

echo "=== Health-Aware DaemonSet Update ==="
echo "DaemonSet: $DAEMONSET"
echo "New Image: $NEW_IMAGE"
echo "Health Check URL: ${HEALTH_CHECK_URL:-'Pod readiness probe'}"
echo

# Функция для проверки здоровья Pod'а
check_pod_health() {
    local pod=$1
    local node=$2
    
    echo "Checking health of pod $pod on node $node..."
    
    # Проверить readiness
    if kubectl wait --for=condition=Ready pod/$pod -n $NAMESPACE --timeout=120s; then
        echo "✅ Pod $pod is ready"
        
        # Дополнительная проверка через HTTP (если указан URL)
        if [ -n "$HEALTH_CHECK_URL" ]; then
            echo "Performing HTTP health check..."
            if kubectl exec $pod -n $NAMESPACE -- wget -qO- --timeout=10 "$HEALTH_CHECK_URL" >/dev/null 2>&1; then
                echo "✅ HTTP health check passed"
                return 0
            else
                echo "❌ HTTP health check failed"
                return 1
            fi
        fi
        
        return 0
    else
        echo "❌ Pod $pod failed readiness check"
        return 1
    fi
}

# Функция для отката Pod'а
rollback_pod() {
    local pod=$1
    local node=$2
    
    echo "🔄 Rolling back pod $pod on node $node..."
    
    # Получить предыдущий образ из истории
    previous_image=$(kubectl rollout history daemonset/$DAEMONSET -n $NAMESPACE | grep -E "nginx:" | tail -2 | head -1 | awk '{print $NF}' || echo "nginx:1.20")
    
    # Удалить проблемный Pod
    kubectl delete pod $pod -n $NAMESPACE --force --grace-period=0
    
    # Временно откатить образ для этого узла (через node selector)
    echo "Temporarily rolling back image to $previous_image"
    # В реальности здесь нужна более сложная логика для отката отдельных узлов
}

# Получить текущее состояние
echo "Current state:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o wide

# Начать обновление
echo "Starting health-aware update..."
kubectl set image daemonset/$DAEMONSET demo-app=$NEW_IMAGE -n $NAMESPACE

# Мониторинг обновления с проверкой здоровья
updated_nodes=()
failed_nodes=()

while true; do
    # Получить статус обновления
    desired=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}')
    updated=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.updatedNumberScheduled}')
    ready=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.numberReady}')
    
    echo "Update progress: $updated/$desired updated, $ready ready"
    
    # Проверить новые Pod'ы
    for pod in $(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o jsonpath='{.items[*].metadata.name}'); do
        node=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
        image=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
        
        # Проверить, является ли это обновленным Pod'ом
        if [[ "$image" == "$NEW_IMAGE" ]] && [[ ! " ${updated_nodes[@]} " =~ " ${node} " ]] && [[ ! " ${failed_nodes[@]} " =~ " ${node} " ]]; then
            echo "Found updated pod $pod on node $node with image $image"
            
            if check_pod_health $pod $node; then
                echo "✅ Node $node successfully updated"
                updated_nodes+=("$node")
            else
                echo "❌ Health check failed for node $node"
                failed_nodes+=("$node")
                rollback_pod $pod $node
            fi
        fi
    done
    
    # Проверить, завершилось ли обновление
    if [ "$updated" = "$desired" ] && [ "$ready" = "$desired" ]; then
        echo "Update completed!"
        break
    fi
    
    # Проверить, есть ли критические ошибки
    if [ ${#failed_nodes[@]} -gt $((desired / 2)) ]; then
        echo "❌ Too many nodes failed health checks. Aborting update."
        kubectl rollout undo daemonset/$DAEMONSET -n $NAMESPACE
        exit 1
    fi
    
    sleep 15
done

# Финальная проверка
echo "=== Final Health Check ==="
all_healthy=true
for pod in $(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o jsonpath='{.items[*].metadata.name}'); do
    node=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
    if ! check_pod_health $pod $node; then
        all_healthy=false
    fi
done

if $all_healthy; then
    echo "✅ All pods are healthy after update"
else
    echo "❌ Some pods failed final health check"
    exit 1
fi
EOF

chmod +x health-aware-update.sh

# Пример использования
# ./health-aware-update.sh nginx:1.23 "http://localhost/"
```

### **3. Canary обновление DaemonSet:**
```bash
# Создать скрипт для canary обновления
cat << 'EOF' > canary-daemonset-update.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"
DAEMONSET="update-demo"
NEW_IMAGE="$1"
CANARY_PERCENTAGE="${2:-25}"  # процент узлов для canary

if [ -z "$NEW_IMAGE" ]; then
    echo "Usage: $0 <new-image> [canary-percentage]"
    exit 1
fi

echo "=== Canary DaemonSet Update ==="
echo "DaemonSet: $DAEMONSET"
echo "New Image: $NEW_IMAGE"
echo "Canary Percentage: $CANARY_PERCENTAGE%"
echo

# Получить список всех узлов
all_nodes=($(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u))
total_nodes=${#all_nodes[@]}
canary_count=$(( (total_nodes * CANARY_PERCENTAGE + 99) / 100 ))  # округление вверх

echo "Total nodes: $total_nodes"
echo "Canary nodes: $canary_count"

# Выбрать узлы для canary
canary_nodes=("${all_nodes[@]:0:$canary_count}")
echo "Canary nodes: ${canary_nodes[*]}"
echo

# Создать временный DaemonSet для canary
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ${DAEMONSET}-canary
  namespace: $NAMESPACE
  labels:
    app: ${DAEMONSET}-canary
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: ${DAEMONSET}-canary
  template:
    metadata:
      labels:
        app: ${DAEMONSET}-canary
        version: "canary"
    spec:
      nodeSelector:
        canary-update: "true"
      containers:
      - name: demo-app
        image: $NEW_IMAGE
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "canary"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
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
          initialDelaySeconds: 10
          periodSeconds: 10
        volumeMounts:
        - name: config
          mountPath: /usr/share/nginx/html
      volumes:
      - name: config
        configMap:
          name: demo-config
      tolerations:
      - operator: Exists
        effect: NoSchedule
EOF

# Пометить canary узлы
echo "Labeling canary nodes..."
for node in "${canary_nodes[@]}"; do
    kubectl label nodes $node canary-update=true
    echo "  Labeled node: $node"
done

# Дождаться развертывания canary
echo "Waiting for canary deployment..."
kubectl rollout status daemonset/${DAEMONSET}-canary -n $NAMESPACE

# Мониторинг canary
echo "=== Canary Monitoring ==="
for i in {1..12}; do  # 2 минуты мониторинга
    echo "Canary check $i/12:"
    
    # Проверить статус canary Pod'ов
    canary_pods=$(kubectl get pods -n $NAMESPACE -l app=${DAEMONSET}-canary --field-selector=status.phase=Running --no-headers | wc -l)
    echo "  Running canary pods: $canary_pods/$canary_count"
    
    # Проверить здоровье canary Pod'ов
    healthy_canary=0
    for pod in $(kubectl get pods -n $NAMESPACE -l app=${DAEMONSET}-canary -o jsonpath='{.items[*].metadata.name}'); do
        if kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}' | grep -q true; then
            healthy_canary=$((healthy_canary + 1))
        fi
    done
    echo "  Healthy canary pods: $healthy_canary/$canary_count"
    
    # Проверить ошибки
    failed_canary=$(kubectl get pods -n $NAMESPACE -l app=${DAEMONSET}-canary --field-selector=status.phase=Failed --no-headers | wc -l)
    if [ "$failed_canary" -gt 0 ]; then
        echo "  ❌ Failed canary pods: $failed_canary"
        echo "Canary deployment failed. Cleaning up..."
        break
    fi
    
    if [ "$healthy_canary" -eq "$canary_count" ]; then
        echo "  ✅ All canary pods are healthy"
        if [ $i -ge 6 ]; then  # Минимум 1 минута успешной работы
            echo "Canary validation successful!"
            canary_success=true
            break
        fi
    fi
    
    sleep 10
done

# Принять решение о продолжении
if [ "${canary_success:-false}" = "true" ]; then
    echo "=== Promoting Canary to Full Deployment ==="
    
    # Удалить canary labels с узлов
    for node in "${canary_nodes[@]}"; do
        kubectl label nodes $node canary-update-
    done
    
    # Удалить canary DaemonSet
    kubectl delete daemonset ${DAEMONSET}-canary -n $NAMESPACE
    
    # Обновить основной DaemonSet
    kubectl set image daemonset/$DAEMONSET demo-app=$NEW_IMAGE -n $NAMESPACE
    
    # Дождаться завершения полного обновления
    kubectl rollout status daemonset/$DAEMONSET -n $NAMESPACE
    
    echo "✅ Canary promotion completed successfully!"
else
    echo "❌ Canary validation failed. Rolling back..."
    
    # Удалить canary labels с узлов
    for node in "${canary_nodes[@]}"; do
        kubectl label nodes $node canary-update-
    done
    
    # Удалить canary DaemonSet
    kubectl delete daemonset ${DAEMONSET}-canary -n $NAMESPACE
    
    echo "Canary rollback completed"
    exit 1
fi
EOF

chmod +x canary-daemonset-update.sh

# Пример использования
# ./canary-daemonset-update.sh nginx:1.24 30
```

## 🚨 **Troubleshooting обновлений DaemonSet:**

### **1. Диагностика проблем обновления:**
```bash
# Создать скрипт для диагностики проблем
cat << 'EOF' > troubleshoot-daemonset-update.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"
DAEMONSET="$1"

if [ -z "$DAEMONSET" ]; then
    echo "Usage: $0 <daemonset-name>"
    exit 1
fi

echo "=== DaemonSet Update Troubleshooting ==="
echo "DaemonSet: $DAEMONSET"
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo

# 1. Проверить статус DaemonSet
echo "1. DaemonSet Status:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE -o wide
echo

# 2. Проверить rollout статус
echo "2. Rollout Status:"
kubectl rollout status daemonset/$DAEMONSET -n $NAMESPACE --timeout=10s 2>&1 || echo "Rollout not progressing"
echo

# 3. Проверить Pod'ы
echo "3. Pod Status:"
kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IMAGE:.spec.containers[0].image,NODE:.spec.nodeName,AGE:.metadata.creationTimestamp
echo

# 4. Проверить проблемные Pod'ы
echo "4. Problematic Pods:"
problematic_pods=$(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET --field-selector=status.phase!=Running --no-headers 2>/dev/null)
if [ -n "$problematic_pods" ]; then
    echo "$problematic_pods"
    echo
    
    # Детали проблемных Pod'ов
    for pod in $(echo "$problematic_pods" | awk '{print $1}'); do
        echo "Details for $pod:"
        kubectl describe pod $pod -n $NAMESPACE | grep -A 10 -E "(Conditions|Events)"
        echo
    done
else
    echo "No problematic pods found"
fi
echo

# 5. Проверить события DaemonSet
echo "5. DaemonSet Events:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$DAEMONSET --sort-by='.lastTimestamp' | tail -10
echo

# 6. Проверить update strategy
echo "6. Update Strategy:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.updateStrategy}' | jq '.' 2>/dev/null || kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.updateStrategy}'
echo
echo

# 7. Проверить node constraints
echo "7. Node Constraints:"
echo "Node Selector:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.nodeSelector}' | jq '.' 2>/dev/null || echo "None"
echo
echo "Tolerations:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.tolerations}' | jq '.' 2>/dev/null || echo "None"
echo
echo "Affinity:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.affinity}' | jq '.' 2>/dev/null || echo "None"
echo

# 8. Проверить ресурсы узлов
echo "8. Node Resources:"
kubectl top nodes 2>/dev/null || echo "Metrics not available"
echo

# 9. Проверить taints узлов
echo "9. Node Taints:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
echo

# 10. Рекомендации
echo "10. Troubleshooting Recommendations:"
desired=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}')
current=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.currentNumberScheduled}')
ready=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.numberReady}')
updated=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.updatedNumberScheduled}')

if [ "$ready" != "$desired" ]; then
    echo "  - Not all pods are ready ($ready/$desired)"
    echo "  - Check pod logs: kubectl logs -l app=$DAEMONSET -n $NAMESPACE"
    echo "  - Check resource constraints and node capacity"
fi

if [ "$updated" != "$desired" ]; then
    echo "  - Update not completed ($updated/$desired updated)"
    echo "  - Check update strategy: kubectl describe daemonset $DAEMONSET -n $NAMESPACE"
    echo "  - Consider manual pod deletion for OnDelete strategy"
fi

if [ "$current" != "$desired" ]; then
    echo "  - Pods not scheduled on all nodes ($current/$desired)"
    echo "  - Check node selectors, taints, and tolerations"
    echo "  - Check node resources and capacity"
fi

echo "  - Force restart: kubectl rollout restart daemonset/$DAEMONSET -n $NAMESPACE"
echo "  - Rollback: kubectl rollout undo daemonset/$DAEMONSET -n $NAMESPACE"
echo "  - Check history: kubectl rollout history daemonset/$DAEMONSET -n $NAMESPACE"
EOF

chmod +x troubleshoot-daemonset-update.sh

# Пример использования
./troubleshoot-daemonset-update.sh update-demo
```

### **2. Автоматическое восстановление застрявших обновлений:**
```bash
# Создать скрипт для автоматического восстановления
cat << 'EOF' > auto-fix-daemonset-update.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"
DAEMONSET="$1"
MAX_WAIT_TIME="${2:-300}"  # 5 минут по умолчанию

if [ -z "$DAEMONSET" ]; then
    echo "Usage: $0 <daemonset-name> [max-wait-seconds]"
    exit 1
fi

echo "=== Auto-Fix DaemonSet Update ==="
echo "DaemonSet: $DAEMONSET"
echo "Max wait time: ${MAX_WAIT_TIME}s"
echo

# Функция для проверки прогресса обновления
check_update_progress() {
    local desired=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}')
    local updated=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.updatedNumberScheduled}')
    local ready=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.status.numberReady}')
    
    echo "Progress: $updated/$desired updated, $ready ready"
    
    # Проверить, завершилось ли обновление
    if [ "$updated" = "$desired" ] && [ "$ready" = "$desired" ]; then
        return 0  # Обновление завершено
    else
        return 1  # Обновление в процессе
    fi
}

# Функция для исправления застрявших Pod'ов
fix_stuck_pods() {
    echo "Fixing stuck pods..."
    
    # Найти Pod'ы в состоянии Pending
    pending_pods=$(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET --field-selector=status.phase=Pending -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$pending_pods" ]; then
        echo "Found pending pods: $pending_pods"
        for pod in $pending_pods; do
            echo "Deleting pending pod: $pod"
            kubectl delete pod $pod -n $NAMESPACE --force --grace-period=0
        done
    fi
    
    # Найти Pod'ы в состоянии Failed
    failed_pods=$(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET --field-selector=status.phase=Failed -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$failed_pods" ]; then
        echo "Found failed pods: $failed_pods"
        for pod in $failed_pods; do
            echo "Deleting failed pod: $pod"
            kubectl delete pod $pod -n $NAMESPACE --force --grace-period=0
        done
    fi
    
    # Найти Pod'ы с высоким количеством перезапусков
    high_restart_pods=$(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$2 > 10 {print $1}')
    if [ -n "$high_restart_pods" ]; then
        echo "Found pods with high restart count: $high_restart_pods"
        for pod in $high_restart_pods; do
            echo "Deleting pod with high restarts: $pod"
            kubectl delete pod $pod -n $NAMESPACE --force --grace-period=0
        done
    fi
}

# Функция для принудительного обновления OnDelete DaemonSet
force_ondelete_update() {
    local strategy=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.updateStrategy.type}')
    
    if [ "$strategy" = "OnDelete" ]; then
        echo "Detected OnDelete strategy. Forcing manual update..."
        
        # Получить текущий образ из spec
        local new_image=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
        
        # Найти Pod'ы со старым образом
        for pod in $(kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o jsonpath='{.items[*].metadata.name}'); do
            local current_image=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
            if [ "$current_image" != "$new_image" ]; then
                echo "Updating pod $pod from $current_image to $new_image"
                kubectl delete pod $pod -n $NAMESPACE
                
                # Дождаться пересоздания
                sleep 10
            fi
        done
    fi
}

# Начальная проверка
echo "Initial state:"
check_update_progress

# Мониторинг обновления с автоматическим исправлением
start_time=$(date +%s)
while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    echo "=== Check at ${elapsed}s ==="
    
    if check_update_progress; then
        echo "✅ Update completed successfully!"
        break
    fi
    
    # Проверить timeout
    if [ $elapsed -gt $MAX_WAIT_TIME ]; then
        echo "⏰ Timeout reached. Applying fixes..."
        
        # Попробовать исправить проблемы
        fix_stuck_pods
        force_ondelete_update
        
        # Дать еще немного времени после исправлений
        echo "Waiting additional 60s after fixes..."
        sleep 60
        
        if check_update_progress; then
            echo "✅ Update completed after fixes!"
            break
        else
            echo "❌ Update still not completed. Manual intervention required."
            echo "Consider:"
            echo "  - kubectl rollout restart daemonset/$DAEMONSET -n $NAMESPACE"
            echo "  - kubectl rollout undo daemonset/$DAEMONSET -n $NAMESPACE"
            echo "  - Check node resources and constraints"
            exit 1
        fi
    fi
    
    # Периодические исправления каждые 60 секунд
    if [ $((elapsed % 60)) -eq 0 ] && [ $elapsed -gt 0 ]; then
        echo "Periodic maintenance check..."
        fix_stuck_pods
    fi
    
    sleep 15
done

echo "Final state:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=$DAEMONSET -o wide
EOF

chmod +x auto-fix-daemonset-update.sh

# Пример использования
# ./auto-fix-daemonset-update.sh update-demo 600
```

## 📊 **Мониторинг и метрики обновлений:**

### **1. Dashboard для мониторинга обновлений:**
```bash
# Создать comprehensive dashboard для обновлений
cat << 'EOF' > update-dashboard.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"

echo "=== DaemonSet Update Dashboard ==="
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo "=================================="
echo

# Функция для отображения статуса обновления
show_update_dashboard() {
    local ds=$1
    
    # Получить статистику
    local desired=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
    local current=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.currentNumberScheduled}' 2>/dev/null || echo "0")
    local updated=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.updatedNumberScheduled}' 2>/dev/null || echo "0")
    local ready=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    local available=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberAvailable}' 2>/dev/null || echo "0")
    local unavailable=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberUnavailable}' 2>/dev/null || echo "0")
    
    # Статус обновления
    local update_status="Unknown"
    local progress_percent=0
    
    if [ "$desired" -gt 0 ]; then
        progress_percent=$(echo "scale=1; $updated * 100 / $desired" | bc 2>/dev/null || echo "0")
    fi
    
    if [ "$updated" = "$desired" ] && [ "$ready" = "$desired" ]; then
        update_status="✅ Complete"
    elif [ "$updated" -lt "$desired" ]; then
        update_status="🔄 Updating ($progress_percent%)"
    elif [ "$ready" -lt "$desired" ]; then
        update_status="⏳ Stabilizing"
    else
        update_status="❓ Unknown"
    fi
    
    # Получить образы
    local current_image=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A")
    
    printf "%-15s | %2s | %2s | %2s | %2s | %2s | %2s | %-20s | %-25s\n" \
        "$ds" "$desired" "$current" "$updated" "$ready" "$available" "$unavailable" "$update_status" "$current_image"
}

# Заголовок таблицы
printf "%-15s | %2s | %2s | %2s | %2s | %2s | %2s | %-20s | %-25s\n" \
    "DAEMONSET" "DS" "CR" "UP" "RD" "AV" "UN" "UPDATE STATUS" "IMAGE"
echo "----------------|----|----|----|----|----|----|----------------------|---------------------------"

# Показать статус всех DaemonSet'ов
for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    show_update_dashboard $ds
done

echo
echo "Legend:"
echo "  DS: Desired pods    CR: Current pods    UP: Updated pods"
echo "  RD: Ready pods      AV: Available pods  UN: Unavailable pods"

# Показать детали обновлений
echo
echo "=== Update Details ==="
for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    echo "🔍 $ds:"
    
    # Rollout history
    echo "  Rollout History:"
    kubectl rollout history daemonset/$ds -n $NAMESPACE | tail -3 | sed 's/^/    /'
    
    # Update strategy
    local strategy=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.spec.updateStrategy.type}')
    echo "  Update Strategy: $strategy"
    
    if [ "$strategy" = "RollingUpdate" ]; then
        local max_unavailable=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.spec.updateStrategy.rollingUpdate.maxUnavailable}')
        echo "  Max Unavailable: ${max_unavailable:-1}"
    fi
    
    # Pod distribution by image
    echo "  Pod Images:"
    kubectl get pods -n $NAMESPACE -l app=$ds -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | sort | uniq -c | sed 's/^/    /'
    
    echo
done

# Показать проблемные обновления
echo "=== Problematic Updates ==="
for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    local desired=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}')
    local updated=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.updatedNumberScheduled}')
    local ready=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberReady}')
    
    if [ "$updated" != "$desired" ] || [ "$ready" != "$desired" ]; then
        echo "⚠️  $ds has update issues:"
        echo "  Progress: $updated/$desired updated, $ready ready"
        
        # Показать проблемные Pod'ы
        kubectl get pods -n $NAMESPACE -l app=$ds --field-selector=status.phase!=Running --no-headers 2>/dev/null | sed 's/^/    /' || echo "    No problematic pods found"
        echo
    fi
done
EOF

chmod +x update-dashboard.sh
./update-dashboard.sh
```

### **2. Continuous мониторинг обновлений:**
```bash
# Создать continuous monitoring скрипт
cat << 'EOF' > continuous-update-monitor.sh
#!/bin/bash

NAMESPACE="daemonset-update-demo"
INTERVAL="${1:-30}"  # секунд между проверками

echo "=== Continuous DaemonSet Update Monitor ==="
echo "Namespace: $NAMESPACE"
echo "Check interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop"
echo

# Функция для логирования
log_event() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Функция для проверки изменений в обновлениях
check_update_changes() {
    local current_state=""
    
    for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        local desired=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}')
        local updated=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.updatedNumberScheduled}')
        local ready=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberReady}')
        local image=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
        
        current_state="${current_state}${ds}:${desired}:${updated}:${ready}:${image} "
    done
    
    if [ "$current_state" != "$previous_state" ]; then
        log_event "Update state change detected:"
        
        for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
            local desired=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}')
            local updated=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.updatedNumberScheduled}')
            local ready=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberReady}')
            
            if [ "$updated" = "$desired" ] && [ "$ready" = "$desired" ]; then
                log_event "  ✅ $ds: Update complete ($ready/$desired ready)"
            elif [ "$updated" -lt "$desired" ]; then
                local progress=$(echo "scale=1; $updated * 100 / $desired" | bc 2>/dev/null || echo "0")
                log_event "  🔄 $ds: Update in progress ($updated/$desired updated, $progress%)"
            elif [ "$ready" -lt "$desired" ]; then
                log_event "  ⏳ $ds: Stabilizing ($ready/$desired ready)"
            else
                log_event "  ❓ $ds: Unknown state ($updated/$desired updated, $ready ready)"
            fi
        done
        
        previous_state="$current_state"
        echo
    fi
}

# Начальное состояние
previous_state=""
check_update_changes

# Continuous monitoring
while true; do
    sleep $INTERVAL
    check_update_changes
done
EOF

chmod +x continuous-update-monitor.sh

# Запустить в фоне для мониторинга
# ./continuous-update-monitor.sh 15 &
# MONITOR_PID=$!
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все DaemonSets
kubectl delete daemonsets --all -n daemonset-update-demo

# Удалить все services
kubectl delete services --all -n daemonset-update-demo

# Удалить все configmaps
kubectl delete configmaps --all -n daemonset-update-demo

# Удалить namespace
kubectl delete namespace daemonset-update-demo

# Удалить labels с узлов
kubectl label nodes --all canary-update-

# Удалить скрипты
rm -f monitor-daemonset-update.sh staged-daemonset-update.sh health-aware-update.sh canary-daemonset-update.sh troubleshoot-daemonset-update.sh auto-fix-daemonset-update.sh update-dashboard.sh continuous-update-monitor.sh
```

## 📋 **Сводка команд обновления DaemonSet:**

### **Основные команды:**
```bash
# Обновить образ
kubectl set image daemonset/myapp container=new-image -n namespace

# Обновить environment variables
kubectl set env daemonset/myapp KEY=VALUE -n namespace

# Patch обновление
kubectl patch daemonset myapp -n namespace -p '{"spec":{"template":{"spec":{"containers":[{"name":"container","image":"new-image"}]}}}}'

# Проверить статус обновления
kubectl rollout status daemonset/myapp -n namespace

# Откатить обновление
kubectl rollout undo daemonset/myapp -n namespace

# Перезапустить DaemonSet
kubectl rollout restart daemonset/myapp -n namespace
```

### **Управление стратегиями обновления:**
```bash
# Изменить на RollingUpdate
kubectl patch daemonset myapp -n namespace -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}}}'

# Изменить на OnDelete
kubectl patch daemonset myapp -n namespace -p '{"spec":{"updateStrategy":{"type":"OnDelete"}}}'

# Проверить стратегию обновления
kubectl get daemonset myapp -n namespace -o jsonpath='{.spec.updateStrategy}'
```

### **Мониторинг и диагностика:**
```bash
# История обновлений
kubectl rollout history daemonset/myapp -n namespace

# Детали ревизии
kubectl rollout history daemonset/myapp -n namespace --revision=2

# События DaemonSet
kubectl get events -n namespace --field-selector involvedObject.name=myapp

# Статус Pod'ов по узлам
kubectl get pods -n namespace -l app=myapp -o wide
```

## 🎯 **Best Practices для обновления DaemonSets:**

### **1. Планирование обновлений:**
- **Тестирование**: Всегда тестируйте обновления в staging среде
- **Backup**: Сохраняйте конфигурации перед обновлениями
- **Rollback plan**: Имейте план отката
- **Maintenance window**: Планируйте обновления в maintenance окна

### **2. Стратегии обновления:**
- **RollingUpdate**: Для большинства случаев, обеспечивает автоматическое обновление
- **OnDelete**: Для критических системных компонентов, требующих ручного контроля
- **Canary**: Для тестирования новых версий на части узлов
- **Staged**: Для поэтапного обновления с паузами

### **3. Мониторинг и безопасность:**
- **Health checks**: Настройте readiness и liveness probes
- **Resource limits**: Установите appropriate resource limits
- **Monitoring**: Мониторьте процесс обновления
- **Alerting**: Настройте алерты для проблем обновления

### **4. Автоматизация:**
- **CI/CD integration**: Интегрируйте с пайплайнами
- **Automated testing**: Автоматизируйте тестирование
- **Health validation**: Автоматическая проверка здоровья
- **Rollback automation**: Автоматический откат при проблемах

**Обновление DaemonSets требует careful planning и proper monitoring, особенно в production среде, где системные компоненты критичны для работы всего кластера!**
