# 35. Что такое Endpoints и EndpointSlices?

## 🎯 **Что такое Endpoints и EndpointSlices?**

**Endpoints** и **EndpointSlices** — это объекты Kubernetes, которые содержат информацию о сетевых адресах (IP и порты) Pod'ов, обслуживающих конкретный Service. Они являются связующим звеном между Service и Pod'ами.

## 🏗️ **Основные концепции:**

### **Endpoints (Legacy)**
- Список IP адресов и портов Pod'ов
- Один объект на Service
- Ограничения масштабируемости
- Устаревший подход

### **EndpointSlices (Modern)**
- Разделение на меньшие части (slices)
- Лучшая масштабируемость
- Более эффективная сетевая производительность
- Kubernetes 1.17+ (стабильная версия)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих Endpoints:**
```bash
# Все Endpoints в кластере
kubectl get endpoints -A

# Endpoints в ArgoCD
kubectl get endpoints -n argocd
kubectl describe endpoints argocd-server -n argocd

# Endpoints в monitoring
kubectl get endpoints -n monitoring
kubectl describe endpoints prometheus-server -n monitoring
kubectl describe endpoints grafana -n monitoring

# Подробная информация об Endpoints
kubectl get endpoints -A -o wide
```

### **2. Анализ EndpointSlices:**
```bash
# Все EndpointSlices в кластере
kubectl get endpointslices -A

# EndpointSlices в ArgoCD
kubectl get endpointslices -n argocd
kubectl describe endpointslice -n argocd

# EndpointSlices в monitoring
kubectl get endpointslices -n monitoring
kubectl describe endpointslice -n monitoring

# Сравнение с Endpoints
kubectl get endpoints argocd-server -n argocd -o yaml
kubectl get endpointslices -n argocd -l kubernetes.io/service-name=argocd-server -o yaml
```

### **3. Создание Service и изучение Endpoints:**
```bash
# Deployment с несколькими Pod'ами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: endpoint-demo
spec:
  replicas: 4
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
          name: http
        - containerPort: 443
          name: https
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: endpoint-demo-service
spec:
  selector:
    app: endpoint-demo
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
EOF

# Проверить автоматически созданные Endpoints
kubectl get endpoints endpoint-demo-service
kubectl describe endpoints endpoint-demo-service

# Проверить EndpointSlices
kubectl get endpointslices -l kubernetes.io/service-name=endpoint-demo-service
kubectl describe endpointslice -l kubernetes.io/service-name=endpoint-demo-service

# Посмотреть структуру данных
kubectl get endpoints endpoint-demo-service -o yaml
kubectl get endpointslices -l kubernetes.io/service-name=endpoint-demo-service -o yaml

kubectl delete deployment endpoint-demo
kubectl delete service endpoint-demo-service
```

## 🔄 **Динамическое обновление Endpoints:**

### **1. Масштабирование и Endpoints:**
```bash
# Создать Service для тестирования
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scaling-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: scaling-demo
  template:
    metadata:
      labels:
        app: scaling-demo
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
  name: scaling-service
spec:
  selector:
    app: scaling-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Начальное состояние Endpoints
echo "=== Initial Endpoints ==="
kubectl get endpoints scaling-service
kubectl get endpointslices -l kubernetes.io/service-name=scaling-service

# Масштабирование вверх
kubectl scale deployment scaling-demo --replicas=6
sleep 10

echo -e "\n=== After Scaling Up ==="
kubectl get endpoints scaling-service
kubectl get endpointslices -l kubernetes.io/service-name=scaling-service

# Масштабирование вниз
kubectl scale deployment scaling-demo --replicas=1
sleep 10

echo -e "\n=== After Scaling Down ==="
kubectl get endpoints scaling-service
kubectl get endpointslices -l kubernetes.io/service-name=scaling-service

kubectl delete deployment scaling-demo
kubectl delete service scaling-service
```

### **2. Health Checks и Endpoints:**
```bash
# Pod'ы с health checks
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: health-demo
  template:
    metadata:
      labels:
        app: health-demo
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
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
---
apiVersion: v1
kind: Service
metadata:
  name: health-service
spec:
  selector:
    app: health-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить здоровые Endpoints
echo "=== Healthy Endpoints ==="
kubectl get endpoints health-service
kubectl get pods -l app=health-demo

# Сделать один Pod нездоровым
POD_NAME=$(kubectl get pods -l app=health-demo -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- rm /usr/share/nginx/html/index.html

# Подождать и проверить изменения в Endpoints
sleep 15
echo -e "\n=== After Pod Becomes Unhealthy ==="
kubectl get endpoints health-service
kubectl get pods -l app=health-demo

# Восстановить Pod
kubectl exec $POD_NAME -- sh -c 'echo "<!DOCTYPE html><html><body><h1>Welcome to nginx!</h1></body></html>" > /usr/share/nginx/html/index.html'

sleep 10
echo -e "\n=== After Pod Recovery ==="
kubectl get endpoints health-service

kubectl delete deployment health-demo
kubectl delete service health-service
```

## 📈 **Manual Endpoints (без selector):**

### **1. Service без selector:**
```bash
# Service без selector для внешних ресурсов
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
    protocol: TCP
  - name: redis
    port: 6379
    targetPort: 6379
    protocol: TCP
EOF

# Manual Endpoints
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: external-database
subsets:
- addresses:
  - ip: 10.0.1.100  # External PostgreSQL
  - ip: 10.0.1.101  # External PostgreSQL replica
  ports:
  - name: postgres
    port: 5432
    protocol: TCP
- addresses:
  - ip: 10.0.2.100  # External Redis
  - ip: 10.0.2.101  # External Redis replica
  ports:
  - name: redis
    port: 6379
    protocol: TCP
EOF

# Проверить manual endpoints
kubectl get service external-database
kubectl get endpoints external-database
kubectl describe endpoints external-database

# Тестирование подключения к внешним ресурсам
kubectl run test-external --image=busybox -it --rm -- sh -c '
echo "Testing PostgreSQL connection:"
nc -zv external-database 5432
echo "Testing Redis connection:"
nc -zv external-database 6379
'

kubectl delete service external-database
kubectl delete endpoints external-database
```

### **2. EndpointSlices для внешних сервисов:**
```bash
# Manual EndpointSlices
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: external-api-1
  labels:
    kubernetes.io/service-name: external-api
addressType: IPv4
ports:
- name: http
  port: 80
  protocol: TCP
- name: https
  port: 443
  protocol: TCP
endpoints:
- addresses:
  - "8.8.8.8"
  conditions:
    ready: true
- addresses:
  - "8.8.4.4"
  conditions:
    ready: true
EOF

# Проверить manual EndpointSlices
kubectl get service external-api
kubectl get endpointslices -l kubernetes.io/service-name=external-api
kubectl describe endpointslice external-api-1

# DNS resolution для external service
kubectl run dns-test --image=busybox -it --rm -- nslookup external-api

kubectl delete service external-api
kubectl delete endpointslice external-api-1
```

## 🏭 **Production сценарии:**

### **1. Multi-port Services:**
```bash
# Service с несколькими портами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
spec:
  replicas: 3
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
        - containerPort: 8080
          name: metrics
        - containerPort: 9090
          name: admin
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
  - name: metrics
    port: 8080
    targetPort: metrics
  - name: admin
    port: 9090
    targetPort: admin
EOF

# Проверить Endpoints для всех портов
kubectl get endpoints multi-port-service
kubectl describe endpoints multi-port-service

# EndpointSlices для multi-port
kubectl get endpointslices -l kubernetes.io/service-name=multi-port-service
kubectl describe endpointslice -l kubernetes.io/service-name=multi-port-service

kubectl delete deployment multi-port-app
kubectl delete service multi-port-service
```

### **2. Headless Service Endpoints:**
```bash
# Headless Service для StatefulSet
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
      app: database-cluster
  template:
    metadata:
      labels:
        app: database-cluster
    spec:
      containers:
      - name: database
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "clusterdb"
        - name: POSTGRES_USER
          value: "clusteruser"
        - name: POSTGRES_PASSWORD
          value: "clusterpass"
---
apiVersion: v1
kind: Service
metadata:
  name: database-headless
spec:
  clusterIP: None  # Headless
  selector:
    app: database-cluster
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Headless Service Endpoints
kubectl get endpoints database-headless
kubectl describe endpoints database-headless

# EndpointSlices для headless service
kubectl get endpointslices -l kubernetes.io/service-name=database-headless
kubectl describe endpointslice -l kubernetes.io/service-name=database-headless

# DNS записи для отдельных Pod'ов
kubectl run dns-test --image=busybox -it --rm -- sh -c '
echo "All pods:"
nslookup database-headless
echo "Individual pods:"
nslookup database-cluster-0.database-headless
nslookup database-cluster-1.database-headless
nslookup database-cluster-2.database-headless
'

kubectl delete statefulset database-cluster
kubectl delete service database-headless
```

### **3. Cross-namespace Endpoints:**
```bash
# Service в одном namespace, Pod'ы в другом
kubectl create namespace backend-ns
kubectl create namespace frontend-ns

# Backend в backend-ns
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: backend-ns
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-app
  template:
    metadata:
      labels:
        app: backend-app
    spec:
      containers:
      - name: backend
        image: nginx
        ports:
        - containerPort: 80
EOF

# Service в frontend-ns указывающий на backend-ns
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-proxy
  namespace: frontend-ns
spec:
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Endpoints
metadata:
  name: backend-proxy
  namespace: frontend-ns
subsets:
- addresses:
  - ip: $(kubectl get pods -n backend-ns -l app=backend-app -o jsonpath='{.items[0].status.podIP}')
  - ip: $(kubectl get pods -n backend-ns -l app=backend-app -o jsonpath='{.items[1].status.podIP}')
  ports:
  - port: 80
EOF

# Проверить cross-namespace endpoints
kubectl get endpoints backend-proxy -n frontend-ns
kubectl describe endpoints backend-proxy -n frontend-ns

kubectl delete namespace backend-ns frontend-ns
```

## 🚨 **Troubleshooting Endpoints:**

### **1. Отсутствующие Endpoints:**
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

# Диагностика проблемы
echo "=== Service without Endpoints ==="
kubectl get service broken-service
kubectl get endpoints broken-service
kubectl describe service broken-service

# Создать Pod с правильными labels
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fix-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fix-app
  template:
    metadata:
      labels:
        app: fix-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
EOF

# Исправить selector
kubectl patch service broken-service -p '{"spec":{"selector":{"app":"fix-app"}}}'

# Проверить появление Endpoints
sleep 5
echo -e "\n=== After Fix ==="
kubectl get endpoints broken-service
kubectl describe endpoints broken-service

kubectl delete deployment fix-app
kubectl delete service broken-service
```

### **2. Endpoints vs EndpointSlices диагностика:**
```bash
# Создать большой Service для сравнения
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: large-service-demo
spec:
  replicas: 10
  selector:
    matchLabels:
      app: large-service-demo
  template:
    metadata:
      labels:
        app: large-service-demo
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
  name: large-service
spec:
  selector:
    app: large-service-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Сравнить размеры объектов
echo "=== Endpoints Object ==="
kubectl get endpoints large-service -o yaml | wc -l

echo -e "\n=== EndpointSlices Objects ==="
kubectl get endpointslices -l kubernetes.io/service-name=large-service
kubectl get endpointslices -l kubernetes.io/service-name=large-service -o yaml | wc -l

# Проверить количество EndpointSlices
SLICE_COUNT=$(kubectl get endpointslices -l kubernetes.io/service-name=large-service --no-headers | wc -l)
echo "Number of EndpointSlices: $SLICE_COUNT"

kubectl delete deployment large-service-demo
kubectl delete service large-service
```

### **3. Мониторинг Endpoints изменений:**
```bash
# Создать Service для мониторинга
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitor-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: monitor-demo
  template:
    metadata:
      labels:
        app: monitor-demo
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
  name: monitor-service
spec:
  selector:
    app: monitor-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Мониторинг изменений Endpoints
kubectl get endpoints monitor-service -w &
WATCH_PID=$!

# В другом терминале выполнить изменения
sleep 5
echo "Scaling up..."
kubectl scale deployment monitor-demo --replicas=5

sleep 10
echo "Scaling down..."
kubectl scale deployment monitor-demo --replicas=1

sleep 10
echo "Deleting one pod..."
kubectl delete pod -l app=monitor-demo --force --grace-period=0 | head -1

sleep 10
kill $WATCH_PID

kubectl delete deployment monitor-demo
kubectl delete service monitor-service
```

## 🎯 **Best Practices:**

### **1. Endpoints vs EndpointSlices:**
- **Используйте EndpointSlices** для новых кластеров (Kubernetes 1.17+)
- **Endpoints** для legacy совместимости
- **EndpointSlices** лучше масштабируются для больших Services

### **2. Мониторинг Endpoints:**
```bash
# Метрики в Prometheus:
# kube_endpoint_info - информация об Endpoints
# kube_endpointslice_info - информация об EndpointSlices
# kube_service_info - связь Service с Endpoints

# Проверить метрики
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Полезные запросы:
# kube_endpoint_address_available - доступные адреса
# kube_endpoint_address_not_ready - неготовые адреса
```

### **3. Troubleshooting checklist:**
```bash
# 1. Проверить Service selector
kubectl describe service <service-name>

# 2. Проверить Pod labels
kubectl get pods --show-labels

# 3. Проверить Endpoints
kubectl get endpoints <service-name>

# 4. Проверить Pod readiness
kubectl get pods -o wide

# 5. Проверить EndpointSlices
kubectl get endpointslices -l kubernetes.io/service-name=<service-name>
```

### **4. Performance considerations:**
- EndpointSlices разбивают большие списки на части (по умолчанию 100 endpoints на slice)
- Уменьшают нагрузку на API server
- Более эффективное обновление при изменениях
- Лучшая производительность kube-proxy

**Endpoints и EndpointSlices обеспечивают связь между Services и Pod'ами, с EndpointSlices как современной и масштабируемой альтернативой!**
