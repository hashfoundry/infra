# 28. Как реализовать readiness и liveness probes?

## 🎯 **Что такое Health Probes?**

**Health Probes** — это механизмы проверки состояния контейнеров в Kubernetes. Они позволяют определить, когда контейнер готов принимать трафик (readiness) и когда он работает корректно (liveness).

## 🏗️ **Типы Probes:**

### **1. Liveness Probe**
- Проверяет, что контейнер работает
- При неудаче контейнер перезапускается
- Предотвращает "зависшие" контейнеры

### **2. Readiness Probe**
- Проверяет готовность принимать трафик
- При неудаче Pod исключается из Service
- Не влияет на перезапуск контейнера

### **3. Startup Probe (Kubernetes 1.16+)**
- Проверяет успешный запуск контейнера
- Отключает liveness/readiness до успешного старта
- Полезно для медленно стартующих приложений

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка probes в ArgoCD:**
```bash
# Проверить liveness и readiness probes в ArgoCD
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 10 "Liveness:\|Readiness:"

# Подробная информация о probe конфигурации
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}  {.name}:{"\n"}    Liveness: {.livenessProbe}{"\n"}    Readiness: {.readinessProbe}{"\n"}{end}{"\n"}{end}'

# Статус probes
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 5 "Conditions:"
```

### **2. Мониторинг probes:**
```bash
# Prometheus probes
kubectl describe pod -n monitoring -l app=prometheus | grep -A 10 "Liveness:\|Readiness:"

# Grafana probes
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep -A 10 "Liveness:\|Readiness:"

# События связанные с probe failures
kubectl get events -A --field-selector reason=Unhealthy
kubectl get events -A --field-selector reason=ProbeWarning
```

### **3. Создание Pod'а с базовыми probes:**
```bash
# Pod с HTTP probes
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: probes-demo
spec:
  containers:
  - name: web-app
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      successThreshold: 1
      failureThreshold: 3
EOF

# Проверить статус probes
kubectl describe pod probes-demo | grep -A 15 "Conditions:"

kubectl delete pod probes-demo
```

## 🔄 **Типы Probe механизмов:**

### **1. HTTP GET Probe:**
```bash
# Pod с HTTP GET probe
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: http-probe-demo
spec:
  containers:
  - name: web-server
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
        httpHeaders:
        - name: Custom-Header
          value: liveness-check
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
        scheme: HTTP
      initialDelaySeconds: 5
      periodSeconds: 5
EOF

kubectl describe pod http-probe-demo | grep -A 10 "Liveness:\|Readiness:"
kubectl delete pod http-probe-demo
```

### **2. TCP Socket Probe:**
```bash
# Pod с TCP socket probe
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tcp-probe-demo
spec:
  containers:
  - name: tcp-server
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 15
      periodSeconds: 10
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
EOF

kubectl describe pod tcp-probe-demo | grep -A 10 "Liveness:\|Readiness:"
kubectl delete pod tcp-probe-demo
```

### **3. Command/Exec Probe:**
```bash
# Pod с command probe
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: exec-probe-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do sleep 30; done']
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
    readinessProbe:
      exec:
        command:
        - sh
        - -c
        - "test -f /tmp/ready"
      initialDelaySeconds: 5
      periodSeconds: 5
EOF

# Создать файлы для успешных проверок
kubectl exec exec-probe-demo -- touch /tmp/healthy
kubectl exec exec-probe-demo -- touch /tmp/ready

kubectl describe pod exec-probe-demo | grep -A 10 "Liveness:\|Readiness:"
kubectl delete pod exec-probe-demo
```

## 🔧 **Startup Probe (для медленных приложений):**

### **1. Приложение с долгим стартом:**
```bash
# Pod с startup probe для медленного приложения
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: slow-startup-demo
spec:
  containers:
  - name: slow-app
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Starting slow application..."
      sleep 60  # Имитация медленного старта
      echo "Application started"
      while true; do sleep 30; done
    startupProbe:
      exec:
        command:
        - sh
        - -c
        - "ps aux | grep -v grep | grep sleep"
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 10  # 100 секунд на старт
    livenessProbe:
      exec:
        command:
        - sh
        - -c
        - "ps aux | grep -v grep | grep sleep"
      periodSeconds: 10
    readinessProbe:
      exec:
        command:
        - sh
        - -c
        - "ps aux | grep -v grep | grep sleep"
      periodSeconds: 5
EOF

# Startup probe должен пройти первым
kubectl get pod slow-startup-demo -w

kubectl delete pod slow-startup-demo
```

### **2. Database с startup probe:**
```bash
# Имитация базы данных с долгим стартом
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: database-startup-demo
spec:
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
    startupProbe:
      exec:
        command:
        - pg_isready
        - -U
        - testuser
        - -d
        - testdb
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 30  # 150 секунд на старт
    livenessProbe:
      exec:
        command:
        - pg_isready
        - -U
        - testuser
      periodSeconds: 10
    readinessProbe:
      exec:
        command:
        - pg_isready
        - -U
        - testuser
      periodSeconds: 5
EOF

kubectl get pod database-startup-demo -w
kubectl delete pod database-startup-demo
```

## 📈 **Мониторинг Probes:**

### **1. Метрики probes в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики probes:
# prober_probe_success - успешность probe
# kube_pod_container_status_ready - готовность контейнера
# kube_pod_status_ready{condition="Ready"} - готовность Pod'а
# probe_duration_seconds - время выполнения probe
```

### **2. Анализ probe failures:**
```bash
# Pod'ы с неуспешными probes
kubectl get pods -A --field-selector=status.phase=Running -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type==\"Ready\")].status | grep False

# События probe failures
kubectl get events -A --field-selector reason=Unhealthy --sort-by=.metadata.creationTimestamp

# Подробная информация о probe статусе
kubectl describe pods -A | grep -A 5 "Warning.*Unhealthy"
```

### **3. Probe timing анализ:**
```bash
# Создать Pod для анализа probe timing
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: probe-timing-demo
spec:
  containers:
  - name: app
    image: nginx
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 3
      timeoutSeconds: 2
      successThreshold: 1
      failureThreshold: 3
EOF

# Мониторить probe события
kubectl get events --field-selector involvedObject.name=probe-timing-demo -w

kubectl delete pod probe-timing-demo
```

## 🏭 **Production Probe конфигурации:**

### **1. Web Application Deployment:**
```bash
# Production web app с правильными probes
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-with-probes
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
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
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
EOF

# Проверить статус probes
kubectl get pods -l app=web-app
kubectl describe deployment web-app-with-probes

kubectl delete deployment web-app-with-probes
```

### **2. Microservice с health endpoints:**
```bash
# Микросервис с кастомными health endpoints
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: microservice-health
spec:
  replicas: 2
  selector:
    matchLabels:
      app: microservice
  template:
    metadata:
      labels:
        app: microservice
    spec:
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /health/live
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        # Startup probe для медленного старта
        startupProbe:
          httpGet:
            path: /health/startup
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 12  # 60 секунд на старт
EOF

kubectl get pods -l app=microservice
kubectl delete deployment microservice-health
```

### **3. Database StatefulSet с probes:**
```bash
# StatefulSet базы данных с probes
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-with-probes
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
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "appdb"
        - name: POSTGRES_USER
          value: "appuser"
        - name: POSTGRES_PASSWORD
          value: "apppass"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        startupProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 30
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

kubectl get statefulset database-with-probes
kubectl delete statefulset database-with-probes
kubectl delete pvc data-database-with-probes-0
```

## 🚨 **Отладка Probe проблем:**

### **1. Failing Liveness Probe:**
```bash
# Pod с failing liveness probe
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: failing-liveness-demo
spec:
  containers:
  - name: app
    image: nginx
    livenessProbe:
      httpGet:
        path: /nonexistent
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 2
EOF

# Pod будет перезапускаться
kubectl get pod failing-liveness-demo -w

# Анализ причин
kubectl describe pod failing-liveness-demo | grep -A 10 "Events:"
kubectl get events --field-selector involvedObject.name=failing-liveness-demo

kubectl delete pod failing-liveness-demo
```

### **2. Failing Readiness Probe:**
```bash
# Pod с failing readiness probe
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: failing-readiness-demo
  labels:
    app: failing-readiness
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /nonexistent
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: failing-readiness-service
spec:
  selector:
    app: failing-readiness
  ports:
  - port: 80
    targetPort: 80
EOF

# Pod не будет в Service endpoints
kubectl get pod failing-readiness-demo
kubectl get endpoints failing-readiness-service

kubectl delete pod failing-readiness-demo
kubectl delete service failing-readiness-service
```

### **3. Probe timeout проблемы:**
```bash
# Pod с медленными probe responses
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: slow-probe-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do sleep 30; done']
    livenessProbe:
      exec:
        command:
        - sh
        - -c
        - "sleep 10; echo 'alive'"  # Медленный ответ
      initialDelaySeconds: 5
      periodSeconds: 15
      timeoutSeconds: 5  # Timeout меньше времени выполнения
      failureThreshold: 2
EOF

# Probe будет timeout'иться
kubectl describe pod slow-probe-demo | grep -A 10 "Events:"

kubectl delete pod slow-probe-demo
```

## 🎯 **Best Practices для Probes:**

### **1. Правильные параметры timing:**
```bash
# Рекомендуемые значения для разных типов приложений

# Быстрые web приложения:
livenessProbe:
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# Медленные приложения (базы данных):
startupProbe:
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 30  # 300 секунд на старт

livenessProbe:
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

### **2. Выбор типа probe:**
- **HTTP GET**: для web приложений с health endpoints
- **TCP Socket**: для сетевых сервисов без HTTP
- **Exec**: для кастомной логики проверки

### **3. Health endpoint дизайн:**
```bash
# Примеры health endpoints:
# /health/live - liveness (базовая проверка процесса)
# /health/ready - readiness (проверка зависимостей)
# /health/startup - startup (проверка инициализации)

# Health endpoint должен:
# - Быть быстрым (< 1 секунды)
# - Проверять критические зависимости
# - Возвращать HTTP 200 при успехе
# - Не выполнять тяжелые операции
```

### **4. Мониторинг и алерты:**
- Настройте алерты на probe failures
- Мониторьте время выполнения probes
- Отслеживайте частоту перезапусков из-за liveness failures
- Анализируйте readiness probe failures для проблем с зависимостями

**Правильно настроенные probes обеспечивают высокую доступность и надежность приложений!**
