# 26. Как Kubernetes обрабатывает рестарты контейнеров?

## 🎯 **Что такое Container Restarts в Kubernetes?**

**Container Restarts** — это механизм автоматического перезапуска контейнеров при их сбое или завершении. Kubernetes использует restart policies и различные стратегии для обеспечения высокой доступности приложений.

## 🏗️ **Restart Policies:**

### **1. Always (по умолчанию)**
- Контейнер всегда перезапускается при завершении
- Подходит для long-running сервисов
- Используется в Deployments, StatefulSets

### **2. OnFailure**
- Перезапуск только при ошибке (exit code != 0)
- Подходит для batch jobs
- Используется в Jobs

### **3. Never**
- Контейнер никогда не перезапускается
- Подходит для one-time tasks
- Используется в некоторых Jobs

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка restart policies в ArgoCD:**
```bash
# Проверить restart policy ArgoCD Pod'ов
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.restartPolicy}{"\n"}{end}'

# Количество рестартов ArgoCD контейнеров
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount

# Подробная информация о рестартах
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 5 "Restart Count:"
```

### **2. Мониторинг рестартов:**
```bash
# Prometheus рестарты
kubectl get pods -n monitoring -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount

# Grafana рестарты
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep -A 5 "Restart Count:"

# Все Pod'ы с рестартами
kubectl get pods -A --field-selector=status.phase=Running -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount | grep -v " 0$"
```

### **3. Демонстрация restart policies:**
```bash
# Pod с Always restart policy (по умолчанию)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restart-always-demo
spec:
  restartPolicy: Always
  containers:
  - name: failing-app
    image: busybox
    command: ['sh', '-c', 'echo "Starting..."; sleep 10; echo "Exiting with error"; exit 1']
EOF

# Наблюдать за рестартами
kubectl get pod restart-always-demo -w

# Проверить количество рестартов
kubectl get pod restart-always-demo -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount

kubectl delete pod restart-always-demo
```

## 🔄 **Backoff механизм:**

### **1. Exponential Backoff:**
```bash
# Kubernetes использует exponential backoff для рестартов:
# 0s, 10s, 20s, 40s, 80s, 160s, 300s (max)

# Pod для демонстрации backoff
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backoff-demo
spec:
  restartPolicy: Always
  containers:
  - name: crash-app
    image: busybox
    command: ['sh', '-c', 'echo "Crash at $(date)"; exit 1']
EOF

# Наблюдать за увеличением интервалов между рестартами
kubectl get pod backoff-demo -w

# Проверить время последнего рестарта
kubectl describe pod backoff-demo | grep -A 10 "Last State:"

kubectl delete pod backoff-demo
```

### **2. Анализ backoff timing:**
```bash
# Создать Pod с логированием времени
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: timing-demo
spec:
  restartPolicy: Always
  containers:
  - name: timer
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Container started at: $(date)"
      echo "Uptime: $(cat /proc/uptime)"
      sleep 5
      echo "Container crashing at: $(date)"
      exit 1
EOF

# Логи с временными метками
kubectl logs timing-demo -f --timestamps

kubectl delete pod timing-demo
```

## 🔧 **Различные сценарии рестартов:**

### **1. OnFailure restart policy:**
```bash
# Pod с OnFailure policy
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restart-onfailure-demo
spec:
  restartPolicy: OnFailure
  containers:
  - name: batch-job
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Job starting..."
      if [ -f /tmp/success ]; then
        echo "Job completed successfully"
        exit 0
      else
        echo "Job failed, will retry"
        touch /tmp/success
        exit 1
      fi
EOF

# Pod перезапустится один раз, затем завершится успешно
kubectl get pod restart-onfailure-demo -w

kubectl delete pod restart-onfailure-demo
```

### **2. Never restart policy:**
```bash
# Pod с Never policy
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restart-never-demo
spec:
  restartPolicy: Never
  containers:
  - name: one-time-task
    image: busybox
    command: ['sh', '-c', 'echo "One-time task completed"; exit 1']
EOF

# Pod не будет перезапущен
kubectl get pod restart-never-demo

# Статус будет Failed
kubectl describe pod restart-never-demo | grep "Status:"

kubectl delete pod restart-never-demo
```

### **3. Multi-container restart behavior:**
```bash
# Multi-container Pod с разным поведением
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-restart-demo
spec:
  restartPolicy: Always
  containers:
  - name: stable-container
    image: nginx
    ports:
    - containerPort: 80
  - name: failing-container
    image: busybox
    command: ['sh', '-c', 'echo "Failing container"; sleep 30; exit 1']
EOF

# Только failing-container будет перезапускаться
kubectl get pod multi-restart-demo -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount

# Логи failing контейнера
kubectl logs multi-restart-demo -c failing-container

kubectl delete pod multi-restart-demo
```

## 📈 **Мониторинг рестартов:**

### **1. Метрики рестартов в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики рестартов:
# kube_pod_container_status_restarts_total - общее количество рестартов
# rate(kube_pod_container_status_restarts_total[5m]) - частота рестартов
# increase(kube_pod_container_status_restarts_total[1h]) - рестарты за час
# kube_pod_container_status_last_terminated_reason - причина последнего завершения
```

### **2. Анализ причин рестартов:**
```bash
# Pod'ы с высоким количеством рестартов
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount | sort -k3 -nr | head -10

# Причины завершения контейнеров
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.containerStatuses[*].lastState.terminated.reason}{"\n"}{end}' | grep -v "^.*\t$"

# События связанные с рестартами
kubectl get events -A --field-selector reason=BackOff
kubectl get events -A --field-selector reason=Killing
```

### **3. Алерты на рестарты:**
```bash
# Пример Prometheus alert rule для рестартов
cat << EOF
groups:
- name: container-restarts
  rules:
  - alert: HighContainerRestartRate
    expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Container {{ \$labels.container }} in pod {{ \$labels.pod }} is restarting frequently"
      description: "Container {{ \$labels.container }} in pod {{ \$labels.pod }} has restarted {{ \$value }} times in the last 15 minutes"
EOF
```

## 🏭 **Production сценарии рестартов:**

### **1. Deployment с restart strategy:**
```bash
# Deployment с правильной конфигурацией для рестартов
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resilient-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resilient-app
  template:
    metadata:
      labels:
        app: resilient-app
    spec:
      restartPolicy: Always
      containers:
      - name: web-app
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
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
EOF

# Мониторить рестарты
kubectl get pods -l app=resilient-app -w

kubectl delete deployment resilient-app
```

### **2. Job с OnFailure policy:**
```bash
# Job с retry логикой
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: retry-job
spec:
  backoffLimit: 3  # Максимум 3 попытки
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: worker
        image: busybox
        command: ['sh', '-c']
        args:
        - |
          echo "Job attempt started at $(date)"
          # Имитация случайного сбоя
          if [ $((RANDOM % 3)) -eq 0 ]; then
            echo "Job succeeded!"
            exit 0
          else
            echo "Job failed, will retry"
            exit 1
          fi
EOF

# Наблюдать за попытками
kubectl get job retry-job -w
kubectl get pods -l job-name=retry-job

kubectl delete job retry-job
```

### **3. StatefulSet restart behavior:**
```bash
# StatefulSet с контролируемыми рестартами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-with-restart
spec:
  serviceName: database-service
  replicas: 2
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      restartPolicy: Always
      containers:
      - name: database
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "testdb"
        - name: POSTGRES_USER
          value: "testuser"
        - name: POSTGRES_PASSWORD
          value: "testpass"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
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
EOF

# StatefulSet Pod'ы перезапускаются по порядку
kubectl get pods -l app=database -w

kubectl delete statefulset database-with-restart
kubectl delete pvc data-database-with-restart-0 data-database-with-restart-1
```

## 🚨 **Отладка проблем с рестартами:**

### **1. Анализ CrashLoopBackOff:**
```bash
# Pod в CrashLoopBackOff
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crashloop-debug
spec:
  restartPolicy: Always
  containers:
  - name: crashing-app
    image: busybox
    command: ['sh', '-c', 'echo "Starting..."; sleep 2; echo "Crashing!"; exit 1']
EOF

# Диагностика CrashLoopBackOff
kubectl get pod crashloop-debug
kubectl describe pod crashloop-debug | grep -A 10 "State:"
kubectl logs crashloop-debug --previous

# Время между рестартами увеличивается
kubectl get events --field-selector involvedObject.name=crashloop-debug

kubectl delete pod crashloop-debug
```

### **2. Memory/CPU related restarts:**
```bash
# Pod с OOMKilled рестартами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: oom-restart-demo
spec:
  restartPolicy: Always
  containers:
  - name: memory-hog
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Allocating memory..."
        dd if=/dev/zero of=/tmp/memory.dat bs=1M count=200 2>/dev/null
        sleep 10
      done
    resources:
      limits:
        memory: "128Mi"
EOF

# Pod будет убиваться и перезапускаться
kubectl get pod oom-restart-demo -w

# Причина рестарта - OOMKilled
kubectl describe pod oom-restart-demo | grep -A 5 "Last State:"

kubectl delete pod oom-restart-demo
```

### **3. Проблемы с health checks:**
```bash
# Pod с failing liveness probe
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: liveness-restart-demo
spec:
  restartPolicy: Always
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /nonexistent
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 2
EOF

# Pod будет перезапускаться из-за failed liveness probe
kubectl get pod liveness-restart-demo -w

# События покажут причину
kubectl get events --field-selector involvedObject.name=liveness-restart-demo

kubectl delete pod liveness-restart-demo
```

## 🎯 **Best Practices для рестартов:**

### **1. Правильный выбор restart policy:**
- **Always**: для long-running сервисов (web servers, databases)
- **OnFailure**: для batch jobs и tasks
- **Never**: для one-time tasks и debugging

### **2. Graceful shutdown:**
```bash
# Pod с graceful shutdown
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: graceful-shutdown-demo
spec:
  restartPolicy: Always
  terminationGracePeriodSeconds: 30
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      trap 'echo "Received SIGTERM, shutting down gracefully..."; sleep 5; exit 0' TERM
      while true; do
        echo "Application running..."
        sleep 10
      done
EOF

# Тестирование graceful shutdown
kubectl delete pod graceful-shutdown-demo --grace-period=30
```

### **3. Мониторинг и алерты:**
- Настройте алерты на высокую частоту рестартов
- Мониторьте причины завершения контейнеров
- Отслеживайте CrashLoopBackOff состояния
- Анализируйте trends рестартов

### **4. Предотвращение ненужных рестартов:**
- Правильные resource limits
- Корректные health checks
- Graceful shutdown handling
- Proper error handling в приложениях

**Правильное управление рестартами обеспечивает высокую доступность и стабильность приложений!**
