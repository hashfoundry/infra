# 31. Какие типы Services существуют в Kubernetes?

## 🎯 **Что такое Service в Kubernetes?**

**Service** — это абстракция, которая определяет логический набор Pod'ов и политику доступа к ним. Service обеспечивает стабильную точку входа для доступа к приложениям, независимо от изменений в Pod'ах.

## 🏗️ **Типы Services:**

### **1. ClusterIP (по умолчанию)**
- Внутренний IP в кластере
- Доступен только изнутри кластера
- Используется для межсервисной коммуникации

### **2. NodePort**
- Открывает порт на всех Node'ах
- Доступен извне кластера
- Диапазон портов: 30000-32767

### **3. LoadBalancer**
- Создает внешний Load Balancer
- Автоматически создает NodePort и ClusterIP
- Зависит от cloud provider

### **4. ExternalName**
- DNS CNAME запись
- Перенаправляет на внешний сервис
- Не создает proxy

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих Services:**
```bash
# Все Services в кластере
kubectl get services -A

# Services в ArgoCD namespace
kubectl get services -n argocd
kubectl describe service argocd-server -n argocd

# Services в monitoring namespace
kubectl get services -n monitoring
kubectl describe service prometheus-server -n monitoring
kubectl describe service grafana -n monitoring

# Подробная информация о типах Services
kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip
```

### **2. ClusterIP Service (по умолчанию):**
```bash
# Создать Deployment для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
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
EOF

# ClusterIP Service
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-app-clusterip
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF

# Проверить Service
kubectl get service web-app-clusterip
kubectl describe service web-app-clusterip

# Тестирование доступа изнутри кластера
kubectl run test-pod --image=busybox -it --rm -- wget -qO- web-app-clusterip

kubectl delete deployment web-app
kubectl delete service web-app-clusterip
```

### **3. NodePort Service:**
```bash
# Создать NodePort Service
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeport-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodeport-app
  template:
    metadata:
      labels:
        app: nodeport-app
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
  name: nodeport-service
spec:
  type: NodePort
  selector:
    app: nodeport-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Опционально, иначе автоматически
    protocol: TCP
EOF

# Проверить NodePort Service
kubectl get service nodeport-service
kubectl describe service nodeport-service

# Получить Node IP для доступа
kubectl get nodes -o wide

# Доступ через NodePort: http://<node-ip>:30080
echo "Service доступен на всех Node'ах через порт 30080"

kubectl delete deployment nodeport-app
kubectl delete service nodeport-service
```

## 🔄 **LoadBalancer Service:**

### **1. LoadBalancer в cloud environment:**
```bash
# LoadBalancer Service (работает в cloud providers)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loadbalancer-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: loadbalancer-app
  template:
    metadata:
      labels:
        app: loadbalancer-app
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
  name: loadbalancer-service
spec:
  type: LoadBalancer
  selector:
    app: loadbalancer-app
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF

# Проверить LoadBalancer Service
kubectl get service loadbalancer-service
kubectl describe service loadbalancer-service

# В Digital Ocean создастся Load Balancer
# Ждем получения External IP
kubectl get service loadbalancer-service -w

# Доступ через External IP
EXTERNAL_IP=$(kubectl get service loadbalancer-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Service доступен через: http://$EXTERNAL_IP"

kubectl delete deployment loadbalancer-app
kubectl delete service loadbalancer-service
```

### **2. LoadBalancer с аннотациями (Digital Ocean):**
```bash
# LoadBalancer с Digital Ocean аннотациями
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: do-loadbalancer
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-name: "hashfoundry-lb"
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/health"
    service.beta.kubernetes.io/do-loadbalancer-size-slug: "lb-small"
spec:
  type: LoadBalancer
  selector:
    app: loadbalancer-app
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
EOF

kubectl describe service do-loadbalancer
kubectl delete service do-loadbalancer
```

## 🔧 **ExternalName Service:**

### **1. ExternalName для внешних сервисов:**
```bash
# ExternalName Service
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  type: ExternalName
  externalName: database.example.com
  ports:
  - port: 5432
    protocol: TCP
EOF

# Проверить ExternalName Service
kubectl get service external-database
kubectl describe service external-database

# DNS resolution для external service
kubectl run dns-test --image=busybox -it --rm -- nslookup external-database

kubectl delete service external-database
```

### **2. ExternalName для cloud services:**
```bash
# ExternalName для AWS RDS
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: aws-rds
spec:
  type: ExternalName
  externalName: mydb.cluster-xyz.us-west-2.rds.amazonaws.com
  ports:
  - port: 5432
    protocol: TCP
---
# ExternalName для Google Cloud SQL
apiVersion: v1
kind: Service
metadata:
  name: gcp-sql
spec:
  type: ExternalName
  externalName: 10.1.2.3  # Private IP
  ports:
  - port: 3306
    protocol: TCP
EOF

kubectl get services aws-rds gcp-sql
kubectl delete services aws-rds gcp-sql
```

## 📈 **Headless Services:**

### **1. Headless Service (ClusterIP: None):**
```bash
# StatefulSet с Headless Service
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-cluster
spec:
  serviceName: database-headless
  replicas: 3
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
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "clusterdb"
        - name: POSTGRES_USER
          value: "clusteruser"
        - name: POSTGRES_PASSWORD
          value: "clusterpass"
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: database-headless
spec:
  clusterIP: None  # Headless Service
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
EOF

# Headless Service не имеет ClusterIP
kubectl get service database-headless
kubectl describe service database-headless

# DNS записи для каждого Pod'а
kubectl run dns-test --image=busybox -it --rm -- nslookup database-headless
kubectl run dns-test --image=busybox -it --rm -- nslookup database-0.database-headless

kubectl delete statefulset database-cluster
kubectl delete service database-headless
```

## 🏭 **Production Service конфигурации:**

### **1. Multi-port Service:**
```bash
# Service с несколькими портами
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
      - name: web
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
  type: ClusterIP
  selector:
    app: multi-port-app
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  - name: https
    port: 443
    targetPort: https
    protocol: TCP
EOF

kubectl get service multi-port-service
kubectl describe service multi-port-service

kubectl delete deployment multi-port-app
kubectl delete service multi-port-service
```

### **2. Service с session affinity:**
```bash
# Service с session affinity
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: session-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: session-app
  template:
    metadata:
      labels:
        app: session-app
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
  name: session-service
spec:
  type: ClusterIP
  selector:
    app: session-app
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 часа
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF

kubectl describe service session-service | grep -A 5 "Session Affinity"

kubectl delete deployment session-app
kubectl delete service session-service
```

### **3. Service с топологическими ограничениями:**
```bash
# Service с topology aware routing
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: topology-app
spec:
  replicas: 6
  selector:
    matchLabels:
      app: topology-app
  template:
    metadata:
      labels:
        app: topology-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - topology-app
              topologyKey: kubernetes.io/hostname
---
apiVersion: v1
kind: Service
metadata:
  name: topology-service
spec:
  type: ClusterIP
  selector:
    app: topology-app
  ports:
  - port: 80
    targetPort: 80
  internalTrafficPolicy: Local  # Предпочитать локальные Pod'ы
EOF

kubectl describe service topology-service | grep "Internal Traffic Policy"

kubectl delete deployment topology-app
kubectl delete service topology-service
```

## 🚨 **Service Troubleshooting:**

### **1. Отладка Service connectivity:**
```bash
# Создать проблемный Service
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: debug-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: debug-app
  template:
    metadata:
      labels:
        app: debug-app
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
  name: debug-service
spec:
  type: ClusterIP
  selector:
    app: wrong-label  # Неправильный selector
  ports:
  - port: 80
    targetPort: 80
EOF

# Диагностика проблем
kubectl get service debug-service
kubectl get endpoints debug-service  # Должен быть пустой

# Исправить selector
kubectl patch service debug-service -p '{"spec":{"selector":{"app":"debug-app"}}}'

# Проверить endpoints
kubectl get endpoints debug-service

kubectl delete deployment debug-app
kubectl delete service debug-service
```

### **2. Service DNS resolution:**
```bash
# Тестирование DNS resolution
kubectl run dns-debug --image=busybox -it --rm -- sh

# Внутри Pod'а:
# nslookup kubernetes.default.svc.cluster.local
# nslookup argocd-server.argocd.svc.cluster.local
# nslookup prometheus-server.monitoring.svc.cluster.local
```

### **3. Service port mapping:**
```bash
# Проверка port mapping
kubectl get services -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,PORT:.spec.ports[0].port,TARGET:.spec.ports[0].targetPort,NODE-PORT:.spec.ports[0].nodePort

# Проверка Pod портов
kubectl get pods -o custom-columns=NAME:.metadata.name,PORTS:.spec.containers[0].ports[0].containerPort
```

## 🎯 **Service Best Practices:**

### **1. Выбор типа Service:**
- **ClusterIP**: внутренняя коммуникация между сервисами
- **NodePort**: разработка, тестирование, простой внешний доступ
- **LoadBalancer**: production внешний доступ в cloud
- **ExternalName**: интеграция с внешними сервисами

### **2. Naming conventions:**
```bash
# Хорошие имена Services:
# frontend-service
# backend-api
# database-cluster
# cache-redis
# monitoring-prometheus

# Плохие имена:
# svc1, service, app
```

### **3. Port naming:**
```yaml
ports:
- name: http      # Хорошо
  port: 80
- name: https     # Хорошо
  port: 443
- name: grpc      # Хорошо
  port: 9090
- name: metrics   # Хорошо
  port: 8080
```

### **4. Мониторинг Services:**
```bash
# Метрики Services в Prometheus:
# kube_service_info - информация о Services
# kube_service_spec_type - тип Service
# kube_endpoint_info - информация об Endpoints
# kube_service_status_load_balancer_ingress - LoadBalancer статус
```

**Services обеспечивают стабильную сетевую абстракцию для доступа к приложениям в Kubernetes!**
