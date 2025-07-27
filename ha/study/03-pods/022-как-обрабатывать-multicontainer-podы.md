# 22. Как обрабатывать multi-container Pod'ы?

## 🎯 **Что такое Multi-container Pod'ы?**

**Multi-container Pod'ы** — это Pod'ы, содержащие несколько контейнеров, которые работают вместе как единое целое. Они разделяют сеть, storage и жизненный цикл, обеспечивая тесную интеграцию между компонентами.

## 🏗️ **Основные характеристики Multi-container Pod'ов:**

### **1. Общие ресурсы**
- Единый IP адрес и сетевое пространство
- Общие volumes для обмена данными
- Одинаковый жизненный цикл
- Планирование на одну Node

### **2. Паттерны взаимодействия**
- Sidecar - вспомогательный контейнер
- Ambassador - прокси для внешних соединений
- Adapter - адаптация данных для основного контейнера

### **3. Координация**
- Контейнеры запускаются одновременно
- Могут взаимодействовать через localhost
- Общие environment variables
- Синхронизация через shared volumes

## 📊 **Практические примеры из вашего HA кластера:**

### **1. ArgoCD multi-container Pod'ы:**
```bash
# Проверить ArgoCD Pod'ы на наличие нескольких контейнеров
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,CONTAINERS:.spec.containers[*].name

# Подробная информация о контейнерах в ArgoCD Pod'ах
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 10 "Containers:"

# Проверить количество контейнеров в каждом Pod'е
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

### **2. Создание простого multi-container Pod'а:**
```bash
# Pod с веб-сервером и логгером
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-demo
spec:
  containers:
  - name: web-server
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  - name: log-processor
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Processing logs at $(date)"
        if [ -f /logs/access.log ]; then
          echo "Found access.log, processing..."
          tail -f /logs/access.log | head -5
        fi
        sleep 30
      done
    volumeMounts:
    - name: shared-logs
      mountPath: /logs
  volumes:
  - name: shared-logs
    emptyDir: {}
EOF

# Проверить статус Pod'а
kubectl get pod multi-container-demo

# Логи каждого контейнера
kubectl logs multi-container-demo -c web-server
kubectl logs multi-container-demo -c log-processor

# Очистка
kubectl delete pod multi-container-demo
```

### **3. Sidecar паттерн - мониторинг:**
```bash
# Pod с основным приложением и sidecar для метрик
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-monitoring
spec:
  containers:
  - name: main-app
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: app-data
      mountPath: /usr/share/nginx/html
  - name: metrics-collector
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Collecting metrics at $(date)"
        echo "CPU: $(cat /proc/loadavg)" > /shared/metrics.txt
        echo "Memory: $(free -m)" >> /shared/metrics.txt
        echo "Disk: $(df -h)" >> /shared/metrics.txt
        sleep 60
      done
    volumeMounts:
    - name: app-data
      mountPath: /shared
  volumes:
  - name: app-data
    emptyDir: {}
EOF

# Проверить метрики
kubectl exec sidecar-monitoring -c main-app -- cat /usr/share/nginx/html/metrics.txt

# Логи sidecar контейнера
kubectl logs sidecar-monitoring -c metrics-collector

# Очистка
kubectl delete pod sidecar-monitoring
```

### **4. Ambassador паттерн - прокси:**
```bash
# Pod с приложением и ambassador прокси
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-demo
spec:
  containers:
  - name: main-app
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Main app connecting to database via ambassador..."
        # Подключение к БД через localhost:5432 (ambassador)
        nc -z localhost 5432 && echo "Database connection OK" || echo "Database connection failed"
        sleep 30
      done
  - name: db-ambassador
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Ambassador proxy starting..."
      # Имитация прокси к внешней БД
      while true; do
        echo "Proxying database connections..."
        # В реальности здесь был бы настоящий прокси
        nc -l -p 5432 -e echo "Database proxy response"
        sleep 1
      done
EOF

kubectl logs ambassador-demo -c main-app
kubectl logs ambassador-demo -c db-ambassador

# Очистка
kubectl delete pod ambassador-demo
```

## 🔄 **Паттерны Multi-container Pod'ов:**

### **1. Sidecar Pattern:**
```bash
# Веб-сервер с sidecar для логов
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-logs
spec:
  containers:
  - name: web-app
    image: nginx
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: log-shipper
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        if [ -f /logs/access.log ]; then
          echo "Shipping logs to central system..."
          tail -n 10 /logs/access.log
        fi
        sleep 10
      done
    volumeMounts:
    - name: logs
      mountPath: /logs
  volumes:
  - name: logs
    emptyDir: {}
EOF

kubectl logs sidecar-logs -c log-shipper
kubectl delete pod sidecar-logs
```

### **2. Adapter Pattern:**
```bash
# Приложение с adapter для форматирования данных
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: adapter-demo
spec:
  containers:
  - name: legacy-app
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "$(date): Legacy data format: USER=john,ACTION=login,STATUS=success" > /data/legacy.log
        sleep 15
      done
    volumeMounts:
    - name: data
      mountPath: /data
  - name: format-adapter
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        if [ -f /data/legacy.log ]; then
          echo "Converting legacy format to JSON..."
          # Простое преобразование формата
          tail -1 /data/legacy.log | sed 's/USER=/{"user":"/; s/,ACTION=/, "action":"/; s/,STATUS=/, "status":"/; s/$/"}/g' > /data/modern.json
          echo "Converted: $(cat /data/modern.json)"
        fi
        sleep 10
      done
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF

kubectl logs adapter-demo -c format-adapter
kubectl delete pod adapter-demo
```

### **3. Init + Main + Sidecar комбинация:**
```bash
# Комплексный Pod с инициализацией, основным приложением и sidecar
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: complex-multi-container
spec:
  initContainers:
  - name: setup
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Setting up application..."
      echo "app_version=1.0" > /config/app.conf
      echo "debug=false" >> /config/app.conf
      echo "Setup completed"
    volumeMounts:
    - name: config
      mountPath: /config
  containers:
  - name: main-app
    image: nginx
    volumeMounts:
    - name: config
      mountPath: /etc/app
    - name: logs
      mountPath: /var/log/nginx
  - name: config-reloader
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Checking for config changes..."
        if [ -f /config/app.conf ]; then
          echo "Current config: $(cat /config/app.conf)"
        fi
        sleep 30
      done
    volumeMounts:
    - name: config
      mountPath: /config
  - name: log-monitor
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Monitoring application logs..."
        if [ -d /logs ]; then
          echo "Log directory size: $(du -sh /logs)"
        fi
        sleep 45
      done
    volumeMounts:
    - name: logs
      mountPath: /logs
  volumes:
  - name: config
    emptyDir: {}
  - name: logs
    emptyDir: {}
EOF

# Проверить все контейнеры
kubectl get pod complex-multi-container -o jsonpath='{.spec.containers[*].name}'

# Логи каждого контейнера
kubectl logs complex-multi-container -c main-app
kubectl logs complex-multi-container -c config-reloader
kubectl logs complex-multi-container -c log-monitor

# Очистка
kubectl delete pod complex-multi-container
```

## 📈 **Мониторинг Multi-container Pod'ов:**

### **1. Статус контейнеров:**
```bash
# Статус всех контейнеров в Pod'е
kubectl get pods -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount

# Подробная информация о каждом контейнере
kubectl describe pod <pod-name> | grep -A 20 "Container Statuses:"
```

### **2. Ресурсы контейнеров:**
```bash
# Использование ресурсов по контейнерам
kubectl top pod <pod-name> --containers

# Метрики в Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики по контейнерам:
# container_cpu_usage_seconds_total{container="container-name"}
# container_memory_usage_bytes{container="container-name"}
# kube_pod_container_status_ready{container="container-name"}
```

### **3. Логи всех контейнеров:**
```bash
# Логи всех контейнеров Pod'а
kubectl logs <pod-name> --all-containers=true

# Логи с префиксом контейнера
kubectl logs <pod-name> --all-containers=true --prefix=true

# Следить за логами всех контейнеров
kubectl logs <pod-name> --all-containers=true -f
```

## 🏭 **Production примеры Multi-container Pod'ов:**

### **1. Deployment с multi-container:**
```bash
# Deployment с веб-сервером и sidecar
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-with-sidecar
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-with-sidecar
  template:
    metadata:
      labels:
        app: web-with-sidecar
    spec:
      containers:
      - name: web-server
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
      - name: content-updater
        image: busybox
        command: ['sh', '-c']
        args:
        - |
          while true; do
            echo "<h1>Updated at $(date)</h1>" > /content/index.html
            echo "<p>Server: $(hostname)</p>" >> /content/index.html
            sleep 60
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"
            cpu: "200m"
        volumeMounts:
        - name: web-content
          mountPath: /content
      volumes:
      - name: web-content
        emptyDir: {}
EOF

# Проверить Deployment
kubectl get deployment web-with-sidecar
kubectl get pods -l app=web-with-sidecar

# Создать Service для тестирования
kubectl expose deployment web-with-sidecar --port=80 --type=ClusterIP

# Тестировать приложение
kubectl run test-client --image=curlimages/curl -it --rm -- curl http://web-with-sidecar

# Очистка
kubectl delete deployment web-with-sidecar
kubectl delete service web-with-sidecar
```

### **2. StatefulSet с multi-container:**
```bash
# StatefulSet с базой данных и backup sidecar
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-with-backup
spec:
  serviceName: database-service
  replicas: 1
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
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: backups
          mountPath: /backups
      - name: backup-agent
        image: busybox
        command: ['sh', '-c']
        args:
        - |
          while true; do
            echo "Creating backup at $(date)"
            # Имитация создания backup
            echo "backup_$(date +%Y%m%d_%H%M%S)" > /backups/latest.backup
            echo "Backup completed"
            sleep 3600  # Каждый час
          done
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
          readOnly: true
        - name: backups
          mountPath: /backups
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
  - metadata:
      name: backups
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl get statefulset database-with-backup
kubectl logs database-with-backup-0 -c backup-agent

# Очистка
kubectl delete statefulset database-with-backup
kubectl delete pvc data-database-with-backup-0 backups-database-with-backup-0
```

## 🚨 **Отладка Multi-container Pod'ов:**

### **1. Проблемы с отдельными контейнерами:**
```bash
# Проверить статус каждого контейнера
kubectl describe pod <pod-name>

# Логи проблемного контейнера
kubectl logs <pod-name> -c <container-name>

# Предыдущие логи
kubectl logs <pod-name> -c <container-name> --previous

# Выполнить команду в конкретном контейнере
kubectl exec <pod-name> -c <container-name> -- <command>
```

### **2. Сетевое взаимодействие между контейнерами:**
```bash
# Создать Pod для тестирования сети между контейнерами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-test
spec:
  containers:
  - name: server
    image: nginx
    ports:
    - containerPort: 80
  - name: client
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Testing connection to nginx..."
        wget -qO- http://localhost:80 && echo "Connection OK" || echo "Connection failed"
        sleep 10
      done
EOF

kubectl logs network-test -c client
kubectl delete pod network-test
```

### **3. Проблемы с shared volumes:**
```bash
# Тестирование shared volumes
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Writing data at $(date)" > /shared/data.txt
        sleep 5
      done
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: reader
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        if [ -f /shared/data.txt ]; then
          echo "Reading: $(cat /shared/data.txt)"
        else
          echo "No data file found"
        fi
        sleep 3
      done
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF

kubectl logs volume-test -c reader
kubectl delete pod volume-test
```

## 🎯 **Best Practices для Multi-container Pod'ов:**

### **1. Дизайн контейнеров:**
- Один процесс на контейнер
- Четкое разделение ответственности
- Минимальные образы для sidecar'ов
- Правильное управление ресурсами

### **2. Взаимодействие:**
- Используйте localhost для сетевого взаимодействия
- Shared volumes для обмена файлами
- Environment variables для конфигурации
- Graceful shutdown для всех контейнеров

### **3. Мониторинг:**
- Отдельные health checks для каждого контейнера
- Мониторинг ресурсов по контейнерам
- Централизованное логирование
- Алерты на проблемы любого контейнера

### **4. Безопасность:**
- Разные Security Contexts при необходимости
- Минимальные привилегии для каждого контейнера
- Изоляция секретов
- Network policies для ограничения трафика

**Multi-container Pod'ы обеспечивают тесную интеграцию компонентов при сохранении модульности!**
