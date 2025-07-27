# 33. В чем разница между ClusterIP и NodePort?

## 🎯 **Основные различия ClusterIP и NodePort**

**ClusterIP** и **NodePort** — это два основных типа Services в Kubernetes, которые обеспечивают разные уровни доступности и области применения.

## 🏗️ **ClusterIP Service:**

### **Характеристики:**
- **Внутренний доступ**: только изнутри кластера
- **Виртуальный IP**: назначается из внутреннего диапазона
- **DNS resolution**: автоматическое разрешение имен
- **По умолчанию**: тип Service по умолчанию

### **NodePort Service:**
- **Внешний доступ**: доступен извне кластера
- **Порт на Node'ах**: открывает порт на всех Node'ах
- **Диапазон портов**: 30000-32767
- **Включает ClusterIP**: автоматически создает ClusterIP

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих Services:**
```bash
# Проверить типы Services в кластере
kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,NODE-PORT:.spec.ports[0].nodePort

# ClusterIP Services в ArgoCD
kubectl get services -n argocd -o wide
kubectl describe service argocd-server -n argocd

# ClusterIP Services в monitoring
kubectl get services -n monitoring -o wide
kubectl describe service prometheus-server -n monitoring
kubectl describe service grafana -n monitoring

# Проверить есть ли NodePort Services
kubectl get services -A --field-selector spec.type=NodePort
```

### **2. Создание ClusterIP Service:**
```bash
# Deployment для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clusterip-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: clusterip-demo
  template:
    metadata:
      labels:
        app: clusterip-demo
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
EOF

# ClusterIP Service (по умолчанию)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: clusterip-service
spec:
  type: ClusterIP  # Можно опустить, так как по умолчанию
  selector:
    app: clusterip-demo
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF

# Проверить ClusterIP Service
kubectl get service clusterip-service
kubectl describe service clusterip-service

# Тестирование доступа изнутри кластера
kubectl run test-pod --image=busybox -it --rm -- wget -qO- clusterip-service

# Попытка доступа извне (не сработает)
CLUSTER_IP=$(kubectl get service clusterip-service -o jsonpath='{.spec.clusterIP}')
echo "ClusterIP: $CLUSTER_IP - доступен только изнутри кластера"

kubectl delete deployment clusterip-demo
kubectl delete service clusterip-service
```

### **3. Создание NodePort Service:**
```bash
# Deployment для NodePort демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeport-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodeport-demo
  template:
    metadata:
      labels:
        app: nodeport-demo
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
EOF

# NodePort Service
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nodeport-service
spec:
  type: NodePort
  selector:
    app: nodeport-demo
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Опционально, иначе автоматически
    protocol: TCP
EOF

# Проверить NodePort Service
kubectl get service nodeport-service
kubectl describe service nodeport-service

# Получить Node IP'ы
kubectl get nodes -o wide

# NodePort доступен на всех Node'ах
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
echo "Service доступен через: http://$NODE_IP:30080"

# Тестирование доступа изнутри кластера (тоже работает)
kubectl run test-pod --image=busybox -it --rm -- wget -qO- nodeport-service

kubectl delete deployment nodeport-demo
kubectl delete service nodeport-service
```

## 🔄 **Сравнительная таблица:**

### **1. Функциональные различия:**
```bash
# Создать оба типа для сравнения
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: comparison-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: comparison-app
  template:
    metadata:
      labels:
        app: comparison-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
---
# ClusterIP Service
apiVersion: v1
kind: Service
metadata:
  name: comparison-clusterip
spec:
  type: ClusterIP
  selector:
    app: comparison-app
  ports:
  - port: 80
    targetPort: 80
---
# NodePort Service
apiVersion: v1
kind: Service
metadata:
  name: comparison-nodeport
spec:
  type: NodePort
  selector:
    app: comparison-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
EOF

# Сравнить характеристики
echo "=== ClusterIP Service ==="
kubectl get service comparison-clusterip -o wide
kubectl describe service comparison-clusterip | grep -E "Type:|IP:|Port:|Endpoints:"

echo -e "\n=== NodePort Service ==="
kubectl get service comparison-nodeport -o wide
kubectl describe service comparison-nodeport | grep -E "Type:|IP:|Port:|NodePort:|Endpoints:"

kubectl delete deployment comparison-app
kubectl delete service comparison-clusterip comparison-nodeport
```

### **2. Доступность и использование:**
```bash
# Таблица сравнения
cat << 'EOF'
+------------------+------------------+------------------+
| Характеристика   | ClusterIP        | NodePort         |
+------------------+------------------+------------------+
| Доступ извне     | НЕТ              | ДА               |
| Доступ изнутри   | ДА               | ДА               |
| Порт на Node'ах  | НЕТ              | ДА (30000-32767) |
| ClusterIP        | ДА               | ДА (автоматически)|
| DNS resolution   | ДА               | ДА               |
| Load balancing   | ДА               | ДА               |
| Use case         | Внутренние API   | Внешний доступ   |
+------------------+------------------+------------------+
EOF
```

## 🔧 **Практические сценарии использования:**

### **1. ClusterIP для микросервисов:**
```bash
# Микросервисная архитектура с ClusterIP
cat << EOF | kubectl apply -f -
# Frontend (внутренний)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-internal
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend-internal
  template:
    metadata:
      labels:
        app: frontend-internal
    spec:
      containers:
      - name: frontend
        image: nginx
        ports:
        - containerPort: 80
        env:
        - name: BACKEND_URL
          value: "http://backend-service:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: ClusterIP
  selector:
    app: frontend-internal
  ports:
  - port: 80
    targetPort: 80
---
# Backend (внутренний)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-internal
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-internal
  template:
    metadata:
      labels:
        app: backend-internal
    spec:
      containers:
      - name: backend
        image: nginx
        ports:
        - containerPort: 80
        env:
        - name: DATABASE_URL
          value: "postgresql://database-service:5432/mydb"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP
  selector:
    app: backend-internal
  ports:
  - port: 8080
    targetPort: 80
---
# Database (внутренний)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-internal
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database-internal
  template:
    metadata:
      labels:
        app: database-internal
    spec:
      containers:
      - name: database
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "mydb"
        - name: POSTGRES_USER
          value: "user"
        - name: POSTGRES_PASSWORD
          value: "password"
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
spec:
  type: ClusterIP
  selector:
    app: database-internal
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Тестирование внутренней коммуникации
kubectl exec deployment/frontend-internal -- wget -qO- backend-service:8080
kubectl exec deployment/backend-internal -- nc -zv database-service 5432

kubectl delete deployment frontend-internal backend-internal database-internal
kubectl delete service frontend-service backend-service database-service
```

### **2. NodePort для внешнего доступа:**
```bash
# Web приложение с NodePort для внешнего доступа
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-external
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-external
  template:
    metadata:
      labels:
        app: web-external
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: web-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>NodePort Demo</title></head>
    <body>
      <h1>Доступ через NodePort</h1>
      <p>Это приложение доступно извне кластера через NodePort</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: web-external-service
spec:
  type: NodePort
  selector:
    app: web-external
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30082
EOF

# Проверить внешний доступ
kubectl get service web-external-service
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
echo "Приложение доступно по адресу: http://$NODE_IP:30082"

kubectl delete deployment web-external
kubectl delete service web-external-service
kubectl delete configmap web-content
```

### **3. Комбинированное использование:**
```bash
# API Gateway с NodePort + внутренние сервисы с ClusterIP
cat << EOF | kubectl apply -f -
# API Gateway (внешний доступ)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: gateway
        image: nginx
        ports:
        - containerPort: 80
        env:
        - name: USER_SERVICE_URL
          value: "http://user-service:8080"
        - name: ORDER_SERVICE_URL
          value: "http://order-service:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway-service
spec:
  type: NodePort
  selector:
    app: api-gateway
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30083
---
# User Service (внутренний)
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
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  type: ClusterIP
  selector:
    app: user-service
  ports:
  - port: 8080
    targetPort: 80
---
# Order Service (внутренний)
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
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  type: ClusterIP
  selector:
    app: order-service
  ports:
  - port: 8080
    targetPort: 80
EOF

# Проверить архитектуру
kubectl get services -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,NODE-PORT:.spec.ports[0].nodePort

# Внешний доступ через API Gateway
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
echo "API Gateway доступен: http://$NODE_IP:30083"

# Внутренняя коммуникация
kubectl exec deployment/api-gateway -- wget -qO- user-service:8080
kubectl exec deployment/api-gateway -- wget -qO- order-service:8080

kubectl delete deployment api-gateway user-service order-service
kubectl delete service api-gateway-service user-service order-service
```

## 📈 **Производительность и безопасность:**

### **1. Производительность ClusterIP vs NodePort:**
```bash
# Тестирование производительности
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: perf-test-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: perf-test-app
  template:
    metadata:
      labels:
        app: perf-test-app
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
---
# ClusterIP для внутреннего тестирования
apiVersion: v1
kind: Service
metadata:
  name: perf-clusterip
spec:
  type: ClusterIP
  selector:
    app: perf-test-app
  ports:
  - port: 80
    targetPort: 80
---
# NodePort для внешнего тестирования
apiVersion: v1
kind: Service
metadata:
  name: perf-nodeport
spec:
  type: NodePort
  selector:
    app: perf-test-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30084
EOF

# Тестирование производительности изнутри кластера
kubectl run perf-test --image=busybox -it --rm -- sh -c 'time wget -qO- perf-clusterip && time wget -qO- perf-nodeport'

# ClusterIP обычно быстрее для внутреннего трафика
# NodePort добавляет дополнительный hop через kube-proxy

kubectl delete deployment perf-test-app
kubectl delete service perf-clusterip perf-nodeport
```

### **2. Безопасность:**
```bash
# ClusterIP - более безопасный (изолированный)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-internal-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-internal-api
  template:
    metadata:
      labels:
        app: secure-internal-api
    spec:
      containers:
      - name: api
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: secure-internal-api
spec:
  type: ClusterIP  # Недоступен извне
  selector:
    app: secure-internal-api
  ports:
  - port: 8080
    targetPort: 80
EOF

# NodePort - требует дополнительной защиты
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: public-web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: public-web-app
  template:
    metadata:
      labels:
        app: public-web-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        # Добавить security context
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
---
apiVersion: v1
kind: Service
metadata:
  name: public-web-app
  annotations:
    # Ограничения доступа через аннотации
    service.beta.kubernetes.io/load-balancer-source-ranges: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
spec:
  type: NodePort
  selector:
    app: public-web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30085
EOF

kubectl delete deployment secure-internal-api public-web-app
kubectl delete service secure-internal-api public-web-app
```

## 🚨 **Troubleshooting различий:**

### **1. Проблемы доступности:**
```bash
# Создать проблемный сценарий
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: troubleshoot-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: troubleshoot-app
  template:
    metadata:
      labels:
        app: troubleshoot-app
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
  name: troubleshoot-clusterip
spec:
  type: ClusterIP
  selector:
    app: troubleshoot-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Диагностика ClusterIP
echo "=== ClusterIP Troubleshooting ==="
kubectl get service troubleshoot-clusterip
kubectl get endpoints troubleshoot-clusterip

# Тестирование изнутри кластера
kubectl run debug-pod --image=busybox -it --rm -- wget -qO- troubleshoot-clusterip || echo "ClusterIP недоступен изнутри"

# Попытка доступа извне (должна провалиться)
CLUSTER_IP=$(kubectl get service troubleshoot-clusterip -o jsonpath='{.spec.clusterIP}')
echo "Попытка доступа к ClusterIP $CLUSTER_IP извне кластера - должна провалиться"

kubectl delete deployment troubleshoot-app
kubectl delete service troubleshoot-clusterip
```

### **2. NodePort диагностика:**
```bash
# NodePort диагностика
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeport-troubleshoot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodeport-troubleshoot
  template:
    metadata:
      labels:
        app: nodeport-troubleshoot
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
  name: nodeport-troubleshoot
spec:
  type: NodePort
  selector:
    app: nodeport-troubleshoot
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30086
EOF

# Диагностика NodePort
echo "=== NodePort Troubleshooting ==="
kubectl get service nodeport-troubleshoot
kubectl get endpoints nodeport-troubleshoot

# Проверить порт на Node'ах
kubectl get nodes -o wide
echo "Проверить доступность порта 30086 на Node'ах"

# Проверить iptables правила (если есть доступ к Node'ам)
# sudo iptables -t nat -L | grep 30086

kubectl delete deployment nodeport-troubleshoot
kubectl delete service nodeport-troubleshoot
```

## 🎯 **Best Practices:**

### **1. Когда использовать ClusterIP:**
- Внутренние API и микросервисы
- Базы данных и кэши
- Внутренние инструменты мониторинга
- Сервисы без необходимости внешнего доступа

### **2. Когда использовать NodePort:**
- Разработка и тестирование
- Простой внешний доступ без LoadBalancer
- Legacy приложения
- Временные решения

### **3. Альтернативы NodePort для production:**
```bash
# Вместо NodePort используйте:
# 1. LoadBalancer (в cloud)
# 2. Ingress Controller
# 3. Service Mesh (Istio, Linkerd)

# Пример Ingress вместо NodePort
cat << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service  # ClusterIP Service
            port:
              number: 80
EOF
```

**ClusterIP обеспечивает внутреннюю коммуникацию, а NodePort предоставляет простой внешний доступ с компромиссами в безопасности и производительности!**
