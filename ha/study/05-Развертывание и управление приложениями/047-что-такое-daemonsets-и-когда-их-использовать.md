# 47. Что такое DaemonSets и когда их использовать?

## 🎯 **DaemonSets в Kubernetes**

**DaemonSet** — это контроллер Kubernetes, который обеспечивает запуск одного экземпляра Pod'а на каждом (или выбранных) узле кластера. В отличие от Deployment, который управляет количеством реплик, DaemonSet гарантирует, что определенный Pod работает на каждом узле.

## 🏗️ **Принцип работы DaemonSet:**

### **1. Основные характеристики:**
- **Один Pod на узел**: Автоматически создает Pod на каждом подходящем узле
- **Автоматическое масштабирование**: При добавлении узлов автоматически создает Pod'ы
- **Node affinity**: Может быть ограничен определенными узлами через селекторы
- **Системные сервисы**: Идеально подходит для системных компонентов

### **2. Жизненный цикл:**
- **Создание**: Pod создается на каждом подходящем узле
- **Обновление**: Поддерживает rolling updates
- **Удаление**: При удалении узла Pod автоматически удаляется
- **Мониторинг**: Автоматически пересоздает упавшие Pod'ы

### **3. Отличия от Deployment:**
- **Deployment**: Управляет количеством реплик в кластере
- **DaemonSet**: Управляет наличием Pod'а на каждом узле
- **Масштабирование**: DaemonSet масштабируется с количеством узлов
- **Размещение**: DaemonSet игнорирует scheduler и размещает Pod'ы принудительно

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Базовый пример DaemonSet:**
```bash
# Создать namespace для демонстрации
kubectl create namespace daemonset-demo

# Создать простой DaemonSet для логирования
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  namespace: daemonset-demo
  labels:
    app: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: log-collector
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          while true; do
            echo "$(date): Collecting logs from node $(hostname)"
            echo "Node info: $(uname -a)"
            echo "Disk usage: $(df -h /)"
            echo "Memory usage: $(free -h)"
            echo "---"
            sleep 30
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
EOF

# Проверить создание DaemonSet
kubectl get daemonset log-collector -n daemonset-demo
kubectl get pods -n daemonset-demo -l app=log-collector -o wide

# Проверить логи с разных узлов
echo "=== Логи с разных узлов ==="
for pod in $(kubectl get pods -n daemonset-demo -l app=log-collector -o jsonpath='{.items[*].metadata.name}'); do
    echo "--- Логи с Pod $pod ---"
    kubectl logs $pod -n daemonset-demo --tail=5
    echo
done
```

### **2. Мониторинг DaemonSet (Node Exporter):**
```bash
# Создать DaemonSet для мониторинга узлов
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: daemonset-demo
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.6.1
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
        ports:
        - containerPort: 9100
          hostPort: 9100
          name: metrics
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          mountPropagation: HostToContainer
          readOnly: true
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
---
apiVersion: v1
kind: Service
metadata:
  name: node-exporter-service
  namespace: daemonset-demo
  labels:
    app: node-exporter
spec:
  selector:
    app: node-exporter
  ports:
  - port: 9100
    targetPort: 9100
    name: metrics
  type: ClusterIP
EOF

# Проверить node-exporter на всех узлах
kubectl get daemonset node-exporter -n daemonset-demo
kubectl get pods -n daemonset-demo -l app=node-exporter -o wide

# Проверить метрики с одного из узлов
NODE_EXPORTER_POD=$(kubectl get pods -n daemonset-demo -l app=node-exporter -o jsonpath='{.items[0].metadata.name}')
echo "Проверяем метрики с Pod: $NODE_EXPORTER_POD"
kubectl exec -n daemonset-demo $NODE_EXPORTER_POD -- wget -qO- localhost:9100/metrics | head -20
```

### **3. Сетевой DaemonSet (CNI плагин симуляция):**
```bash
# Создать DaemonSet для сетевых операций
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: network-agent
  namespace: daemonset-demo
  labels:
    app: network-agent
spec:
  selector:
    matchLabels:
      app: network-agent
  template:
    metadata:
      labels:
        app: network-agent
    spec:
      hostNetwork: true
      containers:
      - name: network-agent
        image: nicolaka/netshoot:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Network Agent starting on node $(hostname)"
          echo "Node IP: $(hostname -I)"
          echo "Network interfaces:"
          ip addr show
          echo "Routing table:"
          ip route show
          echo "DNS configuration:"
          cat /etc/resolv.conf
          echo "Starting network monitoring..."
          while true; do
            echo "$(date): Network check from $(hostname)"
            ping -c 1 8.8.8.8 > /dev/null && echo "Internet connectivity: OK" || echo "Internet connectivity: FAILED"
            echo "Active connections: $(netstat -an | grep ESTABLISHED | wc -l)"
            sleep 60
          done
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        securityContext:
          privileged: true
        volumeMounts:
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
        - name: usr-src
          mountPath: /usr/src
          readOnly: true
      volumes:
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr-src
        hostPath:
          path: /usr/src
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
EOF

# Проверить сетевой агент
kubectl get daemonset network-agent -n daemonset-demo
kubectl get pods -n daemonset-demo -l app=network-agent -o wide

# Проверить сетевую информацию с разных узлов
echo "=== Сетевая информация с узлов ==="
for pod in $(kubectl get pods -n daemonset-demo -l app=network-agent -o jsonpath='{.items[*].metadata.name}'); do
    echo "--- Сетевая информация с Pod $pod ---"
    kubectl logs $pod -n daemonset-demo --tail=10
    echo
done
```

### **4. Storage DaemonSet (CSI драйвер симуляция):**
```bash
# Создать DaemonSet для управления хранилищем
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: storage-agent
  namespace: daemonset-demo
  labels:
    app: storage-agent
spec:
  selector:
    matchLabels:
      app: storage-agent
  template:
    metadata:
      labels:
        app: storage-agent
    spec:
      containers:
      - name: storage-agent
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Storage Agent starting on node $(hostname)"
          echo "Checking storage devices..."
          df -h
          echo "Block devices:"
          lsblk 2>/dev/null || echo "lsblk not available"
          echo "Mount points:"
          mount | grep -E "(ext4|xfs|btrfs)"
          echo "Starting storage monitoring..."
          while true; do
            echo "$(date): Storage check from $(hostname)"
            echo "Root filesystem usage: $(df -h / | tail -1 | awk '{print $5}')"
            echo "Available space: $(df -h / | tail -1 | awk '{print $4}')"
            echo "Inode usage: $(df -i / | tail -1 | awk '{print $5}')"
            sleep 120
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: host-root
          mountPath: /host
          readOnly: true
        - name: dev
          mountPath: /dev
        securityContext:
          privileged: true
      volumes:
      - name: host-root
        hostPath:
          path: /
      - name: dev
        hostPath:
          path: /dev
      tolerations:
      - operator: Exists
        effect: NoSchedule
EOF

# Проверить storage agent
kubectl get daemonset storage-agent -n daemonset-demo
kubectl get pods -n daemonset-demo -l app=storage-agent -o wide

# Проверить информацию о хранилище
STORAGE_POD=$(kubectl get pods -n daemonset-demo -l app=storage-agent -o jsonpath='{.items[0].metadata.name}')
echo "Проверяем хранилище через Pod: $STORAGE_POD"
kubectl logs $STORAGE_POD -n daemonset-demo --tail=15
```

## 🔧 **Advanced конфигурации DaemonSet:**

### **1. DaemonSet с node selector:**
```bash
# Сначала добавить labels к узлам
kubectl get nodes
kubectl label nodes $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') environment=production
kubectl label nodes $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') environment=staging 2>/dev/null || echo "Only one node available"

# Создать DaemonSet только для production узлов
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: production-monitor
  namespace: daemonset-demo
  labels:
    app: production-monitor
spec:
  selector:
    matchLabels:
      app: production-monitor
  template:
    metadata:
      labels:
        app: production-monitor
    spec:
      nodeSelector:
        environment: production
      containers:
      - name: monitor
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Production Monitor starting on node $(hostname)"
          echo "Environment: production"
          while true; do
            echo "$(date): Production monitoring from $(hostname)"
            echo "System load: $(uptime)"
            echo "Memory: $(free -h | grep Mem)"
            sleep 45
          done
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

# Проверить размещение только на production узлах
kubectl get daemonset production-monitor -n daemonset-demo
kubectl get pods -n daemonset-demo -l app=production-monitor -o wide
kubectl get nodes --show-labels | grep environment
```

### **2. DaemonSet с affinity и anti-affinity:**
```bash
# Создать DaemonSet с node affinity
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: affinity-daemon
  namespace: daemonset-demo
  labels:
    app: affinity-daemon
spec:
  selector:
    matchLabels:
      app: affinity-daemon
  template:
    metadata:
      labels:
        app: affinity-daemon
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: ["amd64", "arm64"]
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: environment
                operator: In
                values: ["production"]
      containers:
      - name: affinity-container
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Affinity Daemon starting on node $(hostname)"
          echo "Architecture: $(uname -m)"
          while true; do
            echo "$(date): Affinity check from $(hostname)"
            echo "Node labels: $(cat /etc/hostname)"
            sleep 60
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
      tolerations:
      - operator: Exists
EOF

# Проверить размещение с учетом affinity
kubectl get daemonset affinity-daemon -n daemonset-demo
kubectl get pods -n daemonset-demo -l app=affinity-daemon -o wide
```

### **3. DaemonSet с init containers:**
```bash
# Создать DaemonSet с init container для подготовки
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: init-daemon
  namespace: daemonset-demo
  labels:
    app: init-daemon
spec:
  selector:
    matchLabels:
      app: init-daemon
  template:
    metadata:
      labels:
        app: init-daemon
    spec:
      initContainers:
      - name: setup
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Initializing daemon on node $(hostname)"
          echo "Creating required directories..."
          mkdir -p /shared/logs /shared/config
          echo "Setting up configuration..."
          echo "node=$(hostname)" > /shared/config/node.conf
          echo "initialized=$(date)" >> /shared/config/node.conf
          echo "Initialization complete"
        volumeMounts:
        - name: shared-data
          mountPath: /shared
      containers:
      - name: main-daemon
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Main daemon starting on node $(hostname)"
          echo "Reading configuration..."
          cat /shared/config/node.conf
          while true; do
            echo "$(date): Daemon running on $(cat /shared/config/node.conf | grep node | cut -d= -f2)"
            echo "Log entry" >> /shared/logs/daemon.log
            echo "Log entries: $(wc -l < /shared/logs/daemon.log)"
            sleep 30
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        volumeMounts:
        - name: shared-data
          mountPath: /shared
      volumes:
      - name: shared-data
        emptyDir: {}
      tolerations:
      - operator: Exists
EOF

# Проверить init daemon
kubectl get daemonset init-daemon -n daemonset-demo
kubectl get pods -n daemonset-demo -l app=init-daemon

# Проверить логи init container и main container
INIT_POD=$(kubectl get pods -n daemonset-demo -l app=init-daemon -o jsonpath='{.items[0].metadata.name}')
echo "Логи init container:"
kubectl logs $INIT_POD -n daemonset-demo -c setup
echo "Логи main container:"
kubectl logs $INIT_POD -n daemonset-demo -c main-daemon --tail=10
```

## 🚨 **Мониторинг и управление DaemonSet:**

### **1. Мониторинг состояния DaemonSet:**
```bash
# Создать скрипт для мониторинга DaemonSet
cat << 'EOF' > monitor-daemonsets.sh
#!/bin/bash

NAMESPACE="daemonset-demo"

echo "=== DaemonSet Monitoring Dashboard ==="
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo "=================================="
echo

# Функция для отображения статуса DaemonSet
show_daemonset_status() {
    local ds=$1
    
    # Получить информацию о DaemonSet
    local desired=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
    local current=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.currentNumberScheduled}' 2>/dev/null || echo "0")
    local ready=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    local available=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberAvailable}' 2>/dev/null || echo "0")
    local unavailable=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberUnavailable}' 2>/dev/null || echo "0")
    
    # Статус
    local status="Unknown"
    if [ "$ready" = "$desired" ] && [ "$available" = "$desired" ]; then
        status="✅ Ready"
    elif [ "$unavailable" -gt 0 ]; then
        status="❌ Unavailable"
    else
        status="🔄 Updating"
    fi
    
    printf "%-20s | %2s | %2s | %2s | %2s | %2s | %s\n" \
        "$ds" "$desired" "$current" "$ready" "$available" "$unavailable" "$status"
}

# Заголовок таблицы
printf "%-20s | %2s | %2s | %2s | %2s | %2s | %s\n" \
    "DAEMONSET" "DS" "CR" "RD" "AV" "UN" "STATUS"
echo "--------------------|----|----|----|----|----|---------"

# Показать статус всех DaemonSet'ов
for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    show_daemonset_status $ds
done

echo
echo "Legend:"
echo "  DS: Desired pods"
echo "  CR: Current pods"
echo "  RD: Ready pods"
echo "  AV: Available pods"
echo "  UN: Unavailable pods"

# Показать Pod'ы по узлам
echo
echo "=== Pods by Node ==="
kubectl get pods -n $NAMESPACE -o wide | grep -E "(NAME|daemonset-demo)" | sort -k7

# Показать узлы и их labels
echo
echo "=== Node Labels ==="
kubectl get nodes --show-labels | grep -E "(NAME|environment)"

# Показать проблемные Pod'ы
echo
echo "=== Problematic Pods ==="
kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running 2>/dev/null | grep -v "No resources found" || echo "No problematic pods found"
EOF

chmod +x monitor-daemonsets.sh
./monitor-daemonsets.sh
```

### **2. Health check для DaemonSet:**
```bash
# Создать скрипт для проверки здоровья DaemonSet
cat << 'EOF' > health-check-daemonsets.sh
#!/bin/bash

NAMESPACE="daemonset-demo"

echo "=== DaemonSet Health Check ==="
echo "Namespace: $NAMESPACE"
echo

check_daemonset_health() {
    local ds=$1
    local issues=()
    
    # Получить статистику
    local desired=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.desiredNumberScheduled}')
    local ready=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberReady}')
    local unavailable=$(kubectl get daemonset $ds -n $NAMESPACE -o jsonpath='{.status.numberUnavailable}')
    
    echo "🔍 Checking $ds:"
    echo "  Desired: $desired, Ready: $ready, Unavailable: ${unavailable:-0}"
    
    # Проверки
    if [ "$ready" != "$desired" ]; then
        issues+=("Not all pods are ready ($ready/$desired)")
    fi
    
    if [ "${unavailable:-0}" -gt 0 ]; then
        issues+=("$unavailable pods are unavailable")
    fi
    
    # Проверить Pod'ы в состоянии ошибки
    local failed_pods=$(kubectl get pods -n $NAMESPACE -l app=$ds --field-selector=status.phase=Failed --no-headers | wc -l)
    if [ "$failed_pods" -gt 0 ]; then
        issues+=("$failed_pods pods in Failed state")
    fi
    
    # Проверить pending Pod'ы
    local pending_pods=$(kubectl get pods -n $NAMESPACE -l app=$ds --field-selector=status.phase=Pending --no-headers | wc -l)
    if [ "$pending_pods" -gt 0 ]; then
        issues+=("$pending_pods pods in Pending state")
    fi
    
    # Проверить restart count
    local high_restart_pods=$(kubectl get pods -n $NAMESPACE -l app=$ds -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$2 > 5 {print $1}' | wc -l)
    if [ "$high_restart_pods" -gt 0 ]; then
        issues+=("$high_restart_pods pods with high restart count (>5)")
    fi
    
    # Вывести результаты
    if [ ${#issues[@]} -eq 0 ]; then
        echo "  ✅ Healthy"
    else
        echo "  ❌ Issues found:"
        for issue in "${issues[@]}"; do
            echo "     - $issue"
        done
        
        # Показать детали проблемных Pod'ов
        echo "  Pod details:"
        kubectl get pods -n $NAMESPACE -l app=$ds -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName | grep -v "Running.*true.*0" || echo "     No problematic pods in details"
    fi
    echo
}

# Проверить все DaemonSet'ы
for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
    check_daemonset_health $ds
done

# Общая статистика
echo "=== Summary ==="
total_ds=$(kubectl get daemonsets -n $NAMESPACE --no-headers | wc -l)
healthy_ds=$(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.desiredNumberScheduled}{" "}{.status.numberReady}{"\n"}{end}' | awk '$2 == $3 {count++} END {print count+0}')

echo "Total DaemonSets: $total_ds"
echo "Healthy DaemonSets: $healthy_ds"
echo "Unhealthy DaemonSets: $((total_ds - healthy_ds))"
EOF

chmod +x health-check-daemonsets.sh
./health-check-daemonsets.sh
```

### **3. Автоматическое восстановление DaemonSet:**
```bash
# Создать скрипт для автоматического восстановления
cat << 'EOF' > auto-heal-daemonsets.sh
#!/bin/bash

NAMESPACE="daemonset-demo"
MAX_RESTART_COUNT=10

echo "=== DaemonSet Auto-Healing ==="
echo "Namespace: $NAMESPACE"
echo "Max restart count threshold: $MAX_RESTART_COUNT"
echo

heal_daemonset() {
    local ds=$1
    echo "🔧 Healing DaemonSet: $ds"
    
    # Найти Pod'ы с высоким количеством перезапусков
    local problematic_pods=$(kubectl get pods -n $NAMESPACE -l app=$ds -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk -v max=$MAX_RESTART_COUNT '$2 > max {print $1}')
    
    if [ -n "$problematic_pods" ]; then
        echo "  Found pods with high restart count:"
        for pod in $problematic_pods; do
            restart_count=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
            echo "    - $pod (restarts: $restart_count)"
            
            # Удалить проблемный Pod (DaemonSet пересоздаст его)
            echo "    Deleting pod $pod..."
            kubectl delete pod $pod -n $NAMESPACE --grace-period=0 --force
        done
    else
        echo "  No pods with high restart count found"
    fi
    
    # Проверить Pod'ы в состоянии Failed
    local failed_pods=$(kubectl get pods -n $NAMESPACE -l app=$ds --field-selector=status.phase=Failed -o jsonpath='{.items[*].metadata.name}')
    
    if [ -n "$failed_pods" ]; then
        echo "  Found failed pods:"
        for pod in $failed_pods; do
            echo "    - $pod"
            echo "    Deleting failed pod $pod..."
            kubectl delete pod $pod -n $NAMESPACE --grace-period=0 --force
        done
    else
        echo "  No failed pods found"
    fi
    
    # Проверить Pod'ы в состоянии Pending слишком долго
    local old_pending_pods=$(kubectl get pods -n $NAMESPACE -l app=$ds --field-selector=status.phase=Pending -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.creationTimestamp}{"\n"}{end}' | while read pod_name creation_time; do
        if [ -n "$pod_name" ] && [ -n "$creation_time" ]; then
            creation_timestamp=$(date -d "$creation_time" +%s 2>/dev/null || echo 0)
            current_timestamp=$(date +%s)
            age=$((current_timestamp - creation_timestamp))
            
            # Если Pod pending больше 5 минут
            if [ $age -gt 300 ]; then
                echo $pod_name
            fi
        fi
    done)
    
    if [ -n "$old_pending_pods" ]; then
        echo "  Found old pending pods:"
        for pod in $old_pending_pods; do
            echo "    - $pod"
            echo "    Deleting old pending pod $pod..."
            kubectl delete pod $pod -n $NAMESPACE --grace-period=0 --force
        done
    else
        echo "  No old pending pods found"
    fi
    
    echo "  Healing completed for $ds"
    echo
}

# Выполнить healing для всех DaemonSet'ов
for ds in $(kubectl get daemonsets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
    heal_daemonset $ds
done

# Дождаться стабилизации
echo "Waiting for stabilization..."
sleep 30

# Проверить результат
echo "=== Post-Healing Status ==="
./health-check-daemonsets.sh
EOF

chmod +x auto-heal-daemonsets.sh
./auto-heal-daemonsets.sh
```

## 🎯 **Когда использовать DaemonSets:**

### **1. Системные сервисы:**
```bash
# Примеры системных сервисов, которые должны работать на каждом узле
cat << 'EOF'
=== Типичные случаи использования DaemonSets ===

✅ СИСТЕМНЫЕ КОМПОНЕНТЫ:
1. Логирование (Fluentd, Filebeat, Logstash)
2. Мониторинг (Node Exporter, cAdvisor)
3. Сетевые плагины (CNI драйверы, Calico, Flannel)
4. Хранилище (CSI драйверы, GlusterFS)
5. Безопасность (Falco, антивирусы)

✅ ИНФРАСТРУКТУРНЫЕ СЕРВИСЫ:
1. Backup агенты
2. Системные утилиты
3. Performance мониторинг
4. Compliance сканеры
5. Node maintenance агенты

❌ НЕ ПОДХОДИТ ДЛЯ:
1. Приложений с состоянием
2. Веб-сервисов
3. Баз данных
4. API сервисов
5. Пользовательских приложений

🔧 КРИТЕРИИ ВЫБОРА:
- Нужен ли сервис на каждом узле?
- Является ли сервис системным?
- Требуется ли доступ к host ресурсам?
- Нужно ли масштабирование с узлами?
EOF
```

### **2. Сравнение с другими контроллерами:**
```bash
# Создать сравнительную таблицу
cat << 'EOF' > daemonset-comparison.sh
#!/bin/bash

echo "=== Сравнение контроллеров Kubernetes ==="
echo
printf "%-15s | %-20s | %-20s | %-20s\n" "ХАРАКТЕРИСТИКА" "DAEMONSET" "DEPLOYMENT" "STATEFULSET"
echo "----------------|----------------------|----------------------|----------------------"
printf "%-15s | %-20s | %-20s | %-20s\n" "Размещение" "1 Pod на узел" "Любое размещение" "Упорядоченное"
printf "%-15s | %-20s | %-20s | %-20s\n" "Масштабирование" "По количеству узлов" "Ручное/автоматическое" "Ручное/автоматическое"
printf "%-15s | %-20s | %-20s | %-20s\n" "Идентичность" "По узлу" "Без идентичности" "Стабильная идентичность"
printf "%-15s | %-20s | %-20s | %-20s\n" "Хранилище" "Обычно hostPath" "Любое" "Persistent volumes"
printf "%-15s | %-20s | %-20s | %-20s\n" "Обновления" "Rolling update" "Rolling update" "Ordered rolling"
printf "%-15s | %-20s | %-20s | %-20s\n" "Использование" "Системные сервисы" "Stateless приложения" "Stateful приложения"

echo
echo "=== Примеры использования ==="
echo
echo "DaemonSet:"
echo "  - Логирование: Fluentd на каждом узле"
echo "  - Мониторинг: Node Exporter на каждом узле"
echo "  - Сеть: CNI плагины на каждом узле"
echo
echo "Deployment:"
echo "  - Веб-приложения: Nginx, Apache"
echo "  - API сервисы: REST API, микросервисы"
echo "  - Worker'ы: Обработка очередей"
echo
echo "StatefulSet:"
echo "  - Базы данных: MySQL, PostgreSQL"
echo "  - Кластерные приложения: Elasticsearch, Kafka"
echo "  - Хранилища: Distributed storage systems"
EOF

chmod +x daemonset-comparison.sh
./daemonset-comparison.sh
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все DaemonSets
kubectl delete daemonsets --all -n daemonset-demo

# Удалить все services
kubectl delete services --all -n daemonset-demo

# Удалить namespace
kubectl delete namespace daemonset-demo

# Удалить labels с узлов
kubectl label nodes --all environment-

# Удалить скрипты
rm -f monitor-daemonsets.sh health-check-daemonsets.sh auto-heal-daemonsets.sh daemonset-comparison.sh
```

## 📋 **Сводка команд DaemonSet:**

### **Основные команды:**
```bash
# Создать DaemonSet
kubectl apply -f daemonset.yaml

# Просмотреть DaemonSets
kubectl get daemonsets -n namespace
kubectl get ds -n namespace  # короткая форма

# Детальная информация
kubectl describe daemonset myapp -n namespace

# Просмотреть Pod'ы DaemonSet
kubectl get pods -n namespace -l app=myapp -o wide

# Логи DaemonSet
kubectl logs -l app=myapp -n namespace

# Удалить DaemonSet
kubectl delete daemonset myapp -n namespace
```

### **Мониторинг и диагностика:**
```bash
# Статус DaemonSet
kubectl rollout status daemonset/myapp -n namespace

# События DaemonSet
kubectl get events -n namespace --field-selector involvedObject.name=myapp

# Проверить размещение по узлам
kubectl get pods -n namespace -l app=myapp -o wide

# Проверить tolerations и node selector
kubectl describe daemonset myapp -n namespace | grep -A 10 -E "(Tolerations|Node-Selectors)"
```

### **Управление узлами:**
```bash
# Добавить label к узлу
kubectl label nodes node-name key=value

# Удалить label с узла
kubectl label nodes node-name key-

# Просмотреть labels узлов
kubectl get nodes --show-labels

# Добавить taint к узлу
kubectl taint nodes node-name key=value:effect

# Удалить taint с узла
kubectl taint nodes node-name key:effect-
```

## 🎯 **Best Practices для DaemonSets:**

### **1. Дизайн и архитектура:**
- **Минимальные ресурсы**: DaemonSet Pod'ы должны потреблять минимум ресурсов
- **Tolerations**: Настройте tolerations для работы на всех узлах
- **Security context**: Используйте минимальные привилегии
- **Health checks**: Обязательно настройте readiness и liveness probes

### **2. Мониторинг и логирование:**
- **Централизованные логи**: Собирайте логи со всех узлов
- **Метрики**: Мониторьте производительность на каждом узле
- **Алерты**: Настройте алерты для недоступных Pod'ов
- **Dashboard**: Создайте dashboard для мониторинга состояния

### **3. Обновления и обслуживание:**
- **Rolling updates**: Используйте контролируемые обновления
- **Backup**: Сохраняйте конфигурации перед изменениями
- **Testing**: Тестируйте изменения в staging среде
- **Rollback plan**: Имейте план отката

### **4. Безопасность:**
- **Least privilege**: Минимальные права доступа
- **Network policies**: Ограничьте сетевой доступ
- **Pod security**: Используйте Pod Security Standards
- **Image security**: Сканируйте образы на уязвимости

**DaemonSets — это мощный инструмент для развертывания системных сервисов, но требуют careful planning и proper monitoring для эффективного использования в production кластерах!**
