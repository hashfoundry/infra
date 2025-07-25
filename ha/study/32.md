# 32. Как работает Service Discovery в Kubernetes?

## 🎯 **Что такое Service Discovery?**

**Service Discovery** — это механизм, который позволяет приложениям автоматически находить и подключаться к другим сервисам без необходимости знать их точные сетевые адреса. В Kubernetes это реализуется через DNS и переменные окружения.

## 🏗️ **Компоненты Service Discovery:**

### **1. DNS-based Discovery**
- CoreDNS для разрешения имен
- Автоматические DNS записи для Services
- FQDN формат: `service.namespace.svc.cluster.local`

### **2. Environment Variables**
- Автоматические переменные для Services
- Формат: `{SERVICE_NAME}_SERVICE_HOST`
- Формат: `{SERVICE_NAME}_SERVICE_PORT`

### **3. Service Registry**
- Endpoints API
- EndpointSlices (новая версия)
- Автоматическое обновление

## 📊 **Практические примеры из вашего HA кластера:**

### **1. DNS Service Discovery в действии:**
```bash
# Проверить CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get service kube-dns -n kube-system

# Существующие Services для discovery
kubectl get services -n argocd
kubectl get services -n monitoring

# Тестирование DNS discovery
kubectl run discovery-test --image=busybox -it --rm -- sh

# Внутри Pod'а:
# nslookup argocd-server.argocd.svc.cluster.local
# nslookup prometheus-server.monitoring.svc.cluster.local
# nslookup grafana.monitoring.svc.cluster.local
```

### **2. Создание Services для демонстрации Discovery:**
```bash
# Создать несколько Services для тестирования
cat << EOF | kubectl apply -f -
# Frontend Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
# Backend Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 80
EOF

# Проверить созданные Services
kubectl get services
kubectl get endpoints

kubectl delete deployment frontend backend
kubectl delete service frontend-service backend-service
```

### **3. Environment Variables Discovery:**
```bash
# Pod с environment variables
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: env-discovery-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: env-discovery
  template:
    metadata:
      labels:
        app: env-discovery
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sleep', '3600']
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  selector:
    app: env-discovery
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить environment variables
kubectl exec deployment/env-discovery-app -- env | grep SERVICE

# Переменные для kubernetes service
kubectl exec deployment/env-discovery-app -- env | grep KUBERNETES

kubectl delete deployment env-discovery-app
kubectl delete service test-service
```

## 🔄 **DNS Discovery механизмы:**

### **1. Service DNS Records:**
```bash
# Создать Services в разных namespace'ах
kubectl create namespace app-ns
kubectl create namespace db-ns

# Service в app-ns
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: app-ns
spec:
  replicas: 2
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
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: app-ns
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Service в db-ns
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: db-ns
spec:
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
      - name: db
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "testdb"
        - name: POSTGRES_USER
          value: "testuser"
        - name: POSTGRES_PASSWORD
          value: "testpass"
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: db-ns
spec:
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Тестирование cross-namespace discovery
kubectl run dns-test -n app-ns --image=busybox -it --rm -- sh

# Внутри Pod'а в app-ns:
# nslookup web-service                           # Тот же namespace
# nslookup web-service.app-ns                    # Полное имя namespace
# nslookup web-service.app-ns.svc.cluster.local # FQDN
# nslookup db-service.db-ns.svc.cluster.local   # Cross-namespace

kubectl delete namespace app-ns db-ns
```

### **2. Headless Service Discovery:**
```bash
# Headless Service для прямого доступа к Pod'ам
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-cluster
spec:
  serviceName: web-headless
  replicas: 3
  selector:
    matchLabels:
      app: web-cluster
  template:
    metadata:
      labels:
        app: web-cluster
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None  # Headless
  selector:
    app: web-cluster
  ports:
  - port: 80
    targetPort: 80
EOF

# DNS discovery для отдельных Pod'ов
kubectl run dns-test --image=busybox -it --rm -- sh

# Внутри Pod'а:
# nslookup web-headless                                    # Все Pod'ы
# nslookup web-cluster-0.web-headless                     # Конкретный Pod
# nslookup web-cluster-1.web-headless.default.svc.cluster.local

kubectl delete statefulset web-cluster
kubectl delete service web-headless
```

### **3. SRV Records для Service Discovery:**
```bash
# Создать Service с именованными портами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-port-app
  template:
    metadata:
      labels:
        app: multi-port-app
    spec:
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
---
apiVersion: v1
kind: Service
metadata:
  name: multi-port-service
spec:
  selector:
    app: multi-port-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
EOF

# SRV records для именованных портов
kubectl run dns-test --image=busybox -it --rm -- sh

# Внутри Pod'а:
# nslookup -type=SRV _http._tcp.multi-port-service.default.svc.cluster.local
# nslookup -type=SRV _https._tcp.multi-port-service.default.svc.cluster.local

kubectl delete deployment multi-port-app
kubectl delete service multi-port-service
```

## 📈 **Service Registry и Endpoints:**

### **1. Endpoints API:**
```bash
# Создать Service и проверить Endpoints
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: endpoint-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: endpoint-demo
  template:
    metadata:
      labels:
        app: endpoint-demo
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: endpoint-service
spec:
  selector:
    app: endpoint-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить Endpoints
kubectl get endpoints endpoint-service
kubectl describe endpoints endpoint-service

# Endpoints обновляются автоматически при изменении Pod'ов
kubectl scale deployment endpoint-demo --replicas=5
kubectl get endpoints endpoint-service

kubectl scale deployment endpoint-demo --replicas=1
kubectl get endpoints endpoint-service

kubectl delete deployment endpoint-demo
kubectl delete service endpoint-service
```

### **2. EndpointSlices (новая версия):**
```bash
# Проверить EndpointSlices
kubectl get endpointslices

# EndpointSlices для ArgoCD
kubectl get endpointslices -n argocd
kubectl describe endpointslice -n argocd

# EndpointSlices для monitoring
kubectl get endpointslices -n monitoring
kubectl describe endpointslice -n monitoring

# Сравнение с Endpoints
kubectl get endpoints -n argocd
kubectl get endpointslices -n argocd -o yaml
```

### **3. Manual Endpoints (без selector):**
```bash
# Service без selector с manual endpoints
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service
subsets:
- addresses:
  - ip: 8.8.8.8
  - ip: 8.8.4.4
  ports:
  - port: 80
EOF

# Проверить manual endpoints
kubectl get service external-service
kubectl get endpoints external-service
kubectl describe endpoints external-service

# DNS resolution для manual endpoints
kubectl run dns-test --image=busybox -it --rm -- nslookup external-service

kubectl delete service external-service
kubectl delete endpoints external-service
```

## 🏭 **Production Service Discovery patterns:**

### **1. Microservices Discovery:**
```bash
# Микросервисная архитектура с Service Discovery
cat << EOF | kubectl apply -f -
# User Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: nginx
        ports:
        - containerPort: 80
        env:
        - name: ORDER_SERVICE_URL
          value: "http://order-service.default.svc.cluster.local:8080"
        - name: PAYMENT_SERVICE_URL
          value: "http://payment-service.default.svc.cluster.local:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  selector:
    app: user-service
  ports:
  - port: 8080
    targetPort: 80
---
# Order Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: nginx
        ports:
        - containerPort: 80
        env:
        - name: USER_SERVICE_URL
          value: "http://user-service.default.svc.cluster.local:8080"
        - name: PAYMENT_SERVICE_URL
          value: "http://payment-service.default.svc.cluster.local:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector:
    app: order-service
  ports:
  - port: 8080
    targetPort: 80
---
# Payment Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
      - name: payment-service
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
spec:
  selector:
    app: payment-service
  ports:
  - port: 8080
    targetPort: 80
EOF

# Проверить Service Discovery между микросервисами
kubectl get services
kubectl get endpoints

# Тестирование межсервисной коммуникации
kubectl exec deployment/user-service -- wget -qO- order-service:8080
kubectl exec deployment/order-service -- wget -qO- payment-service:8080

kubectl delete deployment user-service order-service payment-service
kubectl delete service user-service order-service payment-service
```

### **2. Database Discovery pattern:**
```bash
# Database cluster с Service Discovery
cat << EOF | kubectl apply -f -
# Master Database
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-master
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db-master
  template:
    metadata:
      labels:
        app: db-master
        role: master
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "proddb"
        - name: POSTGRES_USER
          value: "produser"
        - name: POSTGRES_PASSWORD
          value: "prodpass"
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: db-master
spec:
  selector:
    app: db-master
    role: master
  ports:
  - port: 5432
    targetPort: 5432
---
# Read Replicas
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-replica
spec:
  replicas: 2
  selector:
    matchLabels:
      app: db-replica
  template:
    metadata:
      labels:
        app: db-replica
        role: replica
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "proddb"
        - name: POSTGRES_USER
          value: "produser"
        - name: POSTGRES_PASSWORD
          value: "prodpass"
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: db-replica
spec:
  selector:
    app: db-replica
    role: replica
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Application использует разные Services для read/write
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-db
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-with-db
  template:
    metadata:
      labels:
        app: app-with-db
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sleep', '3600']
        env:
        - name: DB_WRITE_HOST
          value: "db-master.default.svc.cluster.local"
        - name: DB_READ_HOST
          value: "db-replica.default.svc.cluster.local"
        - name: DB_PORT
          value: "5432"
EOF

# Проверить Service Discovery для database
kubectl exec deployment/app-with-db -- nslookup db-master
kubectl exec deployment/app-with-db -- nslookup db-replica

kubectl delete deployment db-master db-replica app-with-db
kubectl delete service db-master db-replica
```

## 🚨 **Service Discovery Troubleshooting:**

### **1. DNS Resolution проблемы:**
```bash
# Создать Pod для диагностики DNS
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-troubleshoot
spec:
  containers:
  - name: troubleshoot
    image: nicolaka/netshoot
    command: ['sleep', '3600']
EOF

# Комплексная диагностика DNS
kubectl exec -it dns-troubleshoot -- bash

# Внутри Pod'а:
# cat /etc/resolv.conf
# nslookup kubernetes.default.svc.cluster.local
# dig kubernetes.default.svc.cluster.local
# host kubernetes.default.svc.cluster.local

kubectl delete pod dns-troubleshoot
```

### **2. Endpoints проблемы:**
```bash
# Service без Endpoints
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broken-service
spec:
  selector:
    app: nonexistent-app  # Неправильный selector
  ports:
  - port: 80
    targetPort: 80
EOF

# Диагностика отсутствующих Endpoints
kubectl get service broken-service
kubectl get endpoints broken-service
kubectl describe service broken-service

# Исправление selector'а
kubectl patch service broken-service -p '{"spec":{"selector":{"app":"existing-app"}}}'

kubectl delete service broken-service
```

### **3. CoreDNS проблемы:**
```bash
# Проверить статус CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# CoreDNS конфигурация
kubectl get configmap coredns -n kube-system -o yaml

# Тестирование CoreDNS напрямую
kubectl run dns-test --image=busybox -it --rm -- nslookup kubernetes.default.svc.cluster.local 10.96.0.10
```

## 🎯 **Service Discovery Best Practices:**

### **1. DNS naming conventions:**
```bash
# Используйте FQDN для надежности
DATABASE_URL="postgresql://db-service.database.svc.cluster.local:5432/mydb"

# Короткие имена только в том же namespace
CACHE_URL="redis-service:6379"

# Cross-namespace всегда с полным именем
API_URL="http://api-service.backend.svc.cluster.local:8080"
```

### **2. Environment variables pattern:**
```yaml
env:
- name: DATABASE_HOST
  value: "postgres-service.database.svc.cluster.local"
- name: DATABASE_PORT
  value: "5432"
- name: REDIS_HOST
  value: "redis-service"
- name: REDIS_PORT
  value: "6379"
```

### **3. Health checks для Service Discovery:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

### **4. Мониторинг Service Discovery:**
```bash
# Метрики CoreDNS в Prometheus:
# coredns_dns_requests_total
# coredns_dns_responses_total
# coredns_dns_request_duration_seconds

# Метрики Endpoints:
# kube_endpoint_info
# kube_service_info
# kube_endpointslice_info
```

**Service Discovery обеспечивает автоматическое обнаружение и подключение к сервисам в динамической среде Kubernetes!**
