# 27. Что такое классы Quality of Service (QoS) в Kubernetes?

## 🎯 **Что такое QoS Classes?**

**Quality of Service (QoS) Classes** — это система классификации Pod'ов в Kubernetes на основе их resource requests и limits. QoS определяет приоритет Pod'ов при нехватке ресурсов и влияет на решения о том, какие Pod'ы будут evicted первыми.

## 🏗️ **Три класса QoS:**

### **1. Guaranteed (Гарантированный)**
- Requests = Limits для всех контейнеров
- Высший приоритет
- Последние кандидаты на eviction

### **2. Burstable (Пакетный)**
- Requests < Limits или только requests указаны
- Средний приоритет
- Eviction на основе использования ресурсов

### **3. BestEffort (Лучшие усилия)**
- Нет requests и limits
- Низший приоритет
- Первые кандидаты на eviction

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка QoS классов в ArgoCD:**
```bash
# Проверить QoS классы ArgoCD Pod'ов
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# Подробная информация о QoS
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep "QoS Class:"

# Ресурсы ArgoCD Pod'ов
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}  {.name}: requests={.resources.requests} limits={.resources.limits}{"\n"}{end}{"\n"}{end}'
```

### **2. Мониторинг QoS классов:**
```bash
# QoS классы в monitoring namespace
kubectl get pods -n monitoring -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# Prometheus QoS
kubectl describe pod -n monitoring -l app=prometheus | grep "QoS Class:"

# Grafana QoS
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep "QoS Class:"

# Все Pod'ы по QoS классам
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,QOS:.status.qosClass | sort -k3
```

### **3. Создание Pod'ов разных QoS классов:**
```bash
# Guaranteed QoS Pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-qos-demo
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"  # Равно requests
        cpu: "100m"      # Равно requests
EOF

# Проверить QoS класс
kubectl describe pod guaranteed-qos-demo | grep "QoS Class:"

kubectl delete pod guaranteed-qos-demo
```

## 🔄 **Демонстрация всех QoS классов:**

### **1. Guaranteed QoS:**
```bash
# Pod с Guaranteed QoS
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-demo
  labels:
    qos: guaranteed
spec:
  containers:
  - name: web
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "64Mi"   # requests = limits
        cpu: "250m"      # requests = limits
  - name: sidecar
    image: busybox
    command: ['sleep', '3600']
    resources:
      requests:
        memory: "32Mi"
        cpu: "100m"
      limits:
        memory: "32Mi"   # requests = limits
        cpu: "100m"      # requests = limits
EOF

kubectl describe pod guaranteed-demo | grep "QoS Class:"
kubectl delete pod guaranteed-demo
```

### **2. Burstable QoS:**
```bash
# Pod с Burstable QoS
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: burstable-demo
  labels:
    qos: burstable
spec:
  containers:
  - name: web
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"  # limits > requests
        cpu: "500m"      # limits > requests
  - name: sidecar
    image: busybox
    command: ['sleep', '3600']
    resources:
      requests:
        memory: "32Mi"
        # Нет limits - тоже Burstable
EOF

kubectl describe pod burstable-demo | grep "QoS Class:"
kubectl delete pod burstable-demo
```

### **3. BestEffort QoS:**
```bash
# Pod с BestEffort QoS
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-demo
  labels:
    qos: besteffort
spec:
  containers:
  - name: web
    image: nginx
    # Нет resources секции
  - name: sidecar
    image: busybox
    command: ['sleep', '3600']
    # Нет resources секции
EOF

kubectl describe pod besteffort-demo | grep "QoS Class:"
kubectl delete pod besteffort-demo
```

## 🔧 **QoS и Eviction поведение:**

### **1. Демонстрация eviction приоритетов:**
```bash
# Создать Pod'ы всех QoS классов
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-priority
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "100m"
---
apiVersion: v1
kind: Pod
metadata:
  name: burstable-priority
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
---
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-priority
spec:
  containers:
  - name: app
    image: nginx
EOF

# Проверить QoS классы
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# При нехватке ресурсов eviction порядок:
# 1. BestEffort Pod'ы (первыми)
# 2. Burstable Pod'ы (превышающие requests)
# 3. Guaranteed Pod'ы (последними)

kubectl delete pod guaranteed-priority burstable-priority besteffort-priority
```

### **2. Memory pressure simulation:**
```bash
# Pod с высоким потреблением памяти для создания pressure
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-pressure-test
spec:
  containers:
  - name: memory-consumer
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      echo "Creating memory pressure..."
      # Выделяем память постепенно
      for i in $(seq 1 10); do
        dd if=/dev/zero of=/tmp/memory$i.dat bs=50M count=1 2>/dev/null
        echo "Allocated ${i}00MB"
        sleep 5
      done
      sleep 3600
    resources:
      requests:
        memory: "100Mi"
      limits:
        memory: "600Mi"
EOF

# Мониторить использование памяти
kubectl top pod memory-pressure-test

kubectl delete pod memory-pressure-test
```

## 📈 **Мониторинг QoS в Prometheus:**

### **1. Метрики QoS классов:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики QoS:
# kube_pod_status_qos_class{qos_class="Guaranteed"} - Guaranteed Pod'ы
# kube_pod_status_qos_class{qos_class="Burstable"} - Burstable Pod'ы  
# kube_pod_status_qos_class{qos_class="BestEffort"} - BestEffort Pod'ы
# kube_node_status_condition{condition="MemoryPressure"} - memory pressure на Node'ах
```

### **2. Анализ распределения QoS:**
```bash
# Подсчет Pod'ов по QoS классам
kubectl get pods -A -o jsonpath='{range .items[*]}{.status.qosClass}{"\n"}{end}' | sort | uniq -c

# Pod'ы без QoS (обычно системные)
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}' | grep -E "\t$"

# Namespace'ы по QoS распределению
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.status.qosClass}{"\n"}{end}' | sort | uniq -c
```

### **3. Eviction события:**
```bash
# События eviction
kubectl get events -A --field-selector reason=Evicted

# Memory pressure события
kubectl get events -A --field-selector reason=MemoryPressure

# OOMKilled события
kubectl get events -A | grep OOMKilled
```

## 🏭 **Production QoS стратегии:**

### **1. Deployment с Guaranteed QoS:**
```bash
# Critical production service с Guaranteed QoS
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: critical-service
  template:
    metadata:
      labels:
        app: critical-service
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "256Mi"  # Guaranteed QoS
            cpu: "500m"      # Guaranteed QoS
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

kubectl get pods -l app=critical-service -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

kubectl delete deployment critical-service
```

### **2. Deployment с Burstable QoS:**
```bash
# Flexible service с Burstable QoS
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flexible-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flexible-service
  template:
    metadata:
      labels:
        app: flexible-service
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"  # Burstable QoS
            cpu: "1000m"     # Burstable QoS
EOF

kubectl get pods -l app=flexible-service -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

kubectl delete deployment flexible-service
```

### **3. Mixed QoS Deployment:**
```bash
# Deployment с разными QoS для разных контейнеров
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mixed-qos-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mixed-qos-service
  template:
    metadata:
      labels:
        app: mixed-qos-service
    spec:
      containers:
      - name: main-app
        image: nginx
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"  # Этот контейнер Guaranteed
            cpu: "250m"
      - name: sidecar
        image: busybox
        command: ['sleep', '3600']
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"  # Этот контейнер Burstable
            cpu: "200m"
      # Pod будет Burstable (наименьший общий QoS)
EOF

kubectl get pods -l app=mixed-qos-service -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

kubectl delete deployment mixed-qos-service
```

## 🚨 **QoS и Node pressure:**

### **1. Node capacity анализ:**
```bash
# Проверить capacity Node'ов
kubectl describe nodes | grep -A 5 "Capacity:"

# Allocated resources по Node'ам
kubectl describe nodes | grep -A 10 "Allocated resources:"

# Requests vs Limits по Node'ам
kubectl describe nodes | grep -E "(Requests|Limits):" -A 2
```

### **2. Resource pressure мониторинг:**
```bash
# Node conditions
kubectl get nodes -o custom-columns=NAME:.metadata.name,MEMORY-PRESSURE:.status.conditions[?(@.type==\"MemoryPressure\")].status,DISK-PRESSURE:.status.conditions[?(@.type==\"DiskPressure\")].status

# Pod'ы на Node'ах с pressure
kubectl get pods -A -o wide | grep <node-with-pressure>

# Eviction thresholds (в managed кластере ограничено)
kubectl describe nodes | grep -A 5 "Eviction"
```

### **3. QoS-based scheduling:**
```bash
# Создать Pod'ы для тестирования scheduling
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-guaranteed
spec:
  priorityClassName: system-node-critical
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "256Mi"
        cpu: "500m"
      limits:
        memory: "256Mi"
        cpu: "500m"
---
apiVersion: v1
kind: Pod
metadata:
  name: low-priority-besteffort
spec:
  containers:
  - name: app
    image: nginx
EOF

# Guaranteed Pod с высоким priority будет запланирован первым
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName

kubectl delete pod high-priority-guaranteed low-priority-besteffort
```

## 🎯 **Best Practices для QoS:**

### **1. Выбор правильного QoS класса:**

**Guaranteed QoS:**
- Критические системные компоненты
- Базы данных
- Сервисы с предсказуемой нагрузкой
- Production workloads с SLA

**Burstable QoS:**
- Веб-приложения с переменной нагрузкой
- Микросервисы
- Batch processing jobs
- Development/staging workloads

**BestEffort QoS:**
- Batch jobs без SLA
- Experimental workloads
- Background tasks
- Development/testing

### **2. Resource planning:**
```bash
# Анализ текущего использования для планирования QoS
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Рекомендации по ресурсам
# Requests: базовое потребление + 20% буфер
# Limits: пиковое потребление + 50% буфер
```

### **3. Мониторинг и алерты:**
```bash
# Алерты на QoS проблемы
cat << EOF
groups:
- name: qos-alerts
  rules:
  - alert: HighBestEffortPods
    expr: count(kube_pod_status_qos_class{qos_class="BestEffort"}) > 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Too many BestEffort pods"
      
  - alert: NodeMemoryPressure
    expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ \$labels.node }} under memory pressure"
EOF
```

### **4. QoS оптимизация:**
- Регулярно анализируйте фактическое использование ресурсов
- Корректируйте requests/limits на основе метрик
- Используйте Vertical Pod Autoscaler для автоматической оптимизации
- Мониторьте eviction события и корректируйте QoS классы

**QoS классы обеспечивают справедливое распределение ресурсов и предсказуемое поведение при нехватке ресурсов!**
