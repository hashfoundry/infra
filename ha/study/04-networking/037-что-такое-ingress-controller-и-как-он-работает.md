# 37. Что такое Ingress Controller и как он работает?

## 🎯 **Что такое Ingress Controller?**

**Ingress Controller** — это компонент Kubernetes, который управляет внешним доступом к сервисам в кластере, обычно HTTP и HTTPS. Он реализует правила, определенные в ресурсах Ingress, и обеспечивает маршрутизацию трафика, SSL termination и другие функции.

## 🏗️ **Архитектура Ingress:**

### **1. Компоненты:**
- **Ingress Resource**: декларативное описание правил маршрутизации
- **Ingress Controller**: реализация, которая читает Ingress ресурсы
- **Load Balancer**: точка входа для внешнего трафика

### **2. Популярные Ingress Controllers:**
- **NGINX Ingress Controller**: наиболее популярный
- **Traefik**: современный с автоматическим service discovery
- **HAProxy**: высокая производительность
- **Istio Gateway**: для service mesh

### **3. Принцип работы:**
- Мониторинг Ingress ресурсов через Kubernetes API
- Автоматическая конфигурация reverse proxy
- Обновление правил маршрутизации в реальном времени

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка существующего Ingress Controller:**
```bash
# Проверить наличие Ingress Controller
kubectl get pods -A | grep ingress
kubectl get services -A | grep ingress

# Проверить NGINX Ingress Controller (если установлен)
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx

# Проверить конфигурацию
kubectl describe deployment ingress-nginx-controller -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### **2. Установка NGINX Ingress Controller:**
```bash
# Установка через Helm (если не установлен)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Установка с настройками для Digital Ocean
cat << EOF > ingress-values.yaml
controller:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/do-loadbalancer-name: "hashfoundry-ingress-lb"
      service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
      service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
      service.beta.kubernetes.io/do-loadbalancer-size-slug: "lb-small"
  replicaCount: 2
  resources:
    requests:
      cpu: 100m
      memory: 90Mi
    limits:
      cpu: 200m
      memory: 180Mi
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
EOF

# Установить Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f ingress-values.yaml

# Проверить установку
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx

# Получить External IP
kubectl get service ingress-nginx-controller -n ingress-nginx
```

### **3. Создание базового Ingress:**
```bash
# Создать приложения для демонстрации
cat << EOF | kubectl apply -f -
# Web приложение
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
    <head><title>Web App</title></head>
    <body>
      <h1>Web Application</h1>
      <p>Доступ через Ingress Controller</p>
      <p>Path: /</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
---
# API приложение
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-app
  template:
    metadata:
      labels:
        app: api-app
    spec:
      containers:
      - name: api
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: api-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>API</title></head>
    <body>
      <h1>API Service</h1>
      <p>API endpoint через Ingress</p>
      <p>Path: /api</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api-app
  ports:
  - port: 80
    targetPort: 80
---
# Базовый Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: demo.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
EOF

# Проверить Ingress
kubectl get ingress basic-ingress
kubectl describe ingress basic-ingress

# Получить IP Ingress Controller'а
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress Controller IP: $INGRESS_IP"

# Тестирование
curl -H "Host: demo.hashfoundry.local" http://$INGRESS_IP/
curl -H "Host: demo.hashfoundry.local" http://$INGRESS_IP/api

kubectl delete deployment web-app api-app
kubectl delete service web-service api-service
kubectl delete configmap web-content api-content
kubectl delete ingress basic-ingress
```

## 🔧 **Advanced Ingress конфигурации:**

### **1. Path-based routing:**
```bash
# Приложения с разными путями
cat << EOF | kubectl apply -f -
# Blog приложение
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blog-app
  template:
    metadata:
      labels:
        app: blog-app
    spec:
      containers:
      - name: blog
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: blog-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: blog-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Blog</title></head>
    <body>
      <h1>Blog Application</h1>
      <p>Path: /blog</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: blog-service
spec:
  selector:
    app: blog-app
  ports:
  - port: 80
    targetPort: 80
---
# Shop приложение
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop-app
  template:
    metadata:
      labels:
        app: shop-app
    spec:
      containers:
      - name: shop
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: shop-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: shop-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Shop</title></head>
    <body>
      <h1>Online Shop</h1>
      <p>Path: /shop</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: shop-service
spec:
  selector:
    app: shop-app
  ports:
  - port: 80
    targetPort: 80
---
# Path-based Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: mysite.hashfoundry.local
    http:
      paths:
      - path: /blog(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
      - path: /shop(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: shop-service
            port:
              number: 80
EOF

# Тестирование path-based routing
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -H "Host: mysite.hashfoundry.local" http://$INGRESS_IP/blog
curl -H "Host: mysite.hashfoundry.local" http://$INGRESS_IP/shop

kubectl delete deployment blog-app shop-app
kubectl delete service blog-service shop-service
kubectl delete configmap blog-content shop-content
kubectl delete ingress path-based-ingress
```

### **2. Host-based routing:**
```bash
# Разные приложения для разных доменов
cat << EOF | kubectl apply -f -
# Production приложение
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: prod-app
  template:
    metadata:
      labels:
        app: prod-app
    spec:
      containers:
      - name: prod
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: prod-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prod-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Production</title></head>
    <body>
      <h1>Production Environment</h1>
      <p>Host: prod.hashfoundry.local</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: prod-service
spec:
  selector:
    app: prod-app
  ports:
  - port: 80
    targetPort: 80
---
# Staging приложение
apiVersion: apps/v1
kind: Deployment
metadata:
  name: staging-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: staging-app
  template:
    metadata:
      labels:
        app: staging-app
    spec:
      containers:
      - name: staging
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: staging-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: staging-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Staging</title></head>
    <body style="background-color: lightyellow;">
      <h1>Staging Environment</h1>
      <p>Host: staging.hashfoundry.local</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: staging-service
spec:
  selector:
    app: staging-app
  ports:
  - port: 80
    targetPort: 80
---
# Host-based Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: prod.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prod-service
            port:
              number: 80
  - host: staging.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: staging-service
            port:
              number: 80
EOF

# Тестирование host-based routing
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -H "Host: prod.hashfoundry.local" http://$INGRESS_IP/
curl -H "Host: staging.hashfoundry.local" http://$INGRESS_IP/

kubectl delete deployment prod-app staging-app
kubectl delete service prod-service staging-service
kubectl delete configmap prod-content staging-content
kubectl delete ingress host-based-ingress
```

### **3. Advanced аннотации NGINX:**
```bash
# Ingress с продвинутыми настройками
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: advanced-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: advanced-app
  template:
    metadata:
      labels:
        app: advanced-app
    spec:
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: advanced-service
spec:
  selector:
    app: advanced-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: advanced-ingress
  annotations:
    # Rate limiting
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    
    # CORS
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    
    # Custom headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
    
    # Timeout settings
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    
    # Buffer settings
    nginx.ingress.kubernetes.io/proxy-buffer-size: "4k"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "8"
    
    # Redirect HTTP to HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "false"  # Для демо без SSL
spec:
  ingressClassName: nginx
  rules:
  - host: advanced.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: advanced-service
            port:
              number: 80
EOF

# Проверить advanced конфигурацию
kubectl describe ingress advanced-ingress

# Тестирование
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: advanced.hashfoundry.local" -v http://$INGRESS_IP/

kubectl delete deployment advanced-app
kubectl delete service advanced-service
kubectl delete ingress advanced-ingress
```

## 🏭 **Production конфигурации:**

### **1. SSL/TLS termination:**
```bash
# Создать самоподписанный сертификат для демо
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.hashfoundry.local/O=hashfoundry"

# Создать Secret с сертификатом
kubectl create secret tls secure-tls --key tls.key --cert tls.crt

# HTTPS Ingress
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: secure-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: secure-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Secure App</title></head>
    <body>
      <h1>Secure HTTPS Application</h1>
      <p>SSL/TLS termination в Ingress Controller</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: secure-service
spec:
  selector:
    app: secure-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.hashfoundry.local
    secretName: secure-tls
  rules:
  - host: secure.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 80
EOF

# Тестирование HTTPS
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: secure.hashfoundry.local" https://$INGRESS_IP/

# Очистка
kubectl delete deployment secure-app
kubectl delete service secure-service
kubectl delete configmap secure-content
kubectl delete ingress secure-ingress
kubectl delete secret secure-tls
rm tls.key tls.crt
```

### **2. Load balancing и health checks:**
```bash
# Приложение с health checks
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: health-app
  template:
    metadata:
      labels:
        app: health-app
    spec:
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: health-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: health-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Health App</title></head>
    <body>
      <h1>Application with Health Checks</h1>
      <p>Pod: $(hostname)</p>
    </body>
    </html>
  health: |
    OK
  ready: |
    READY
---
apiVersion: v1
kind: Service
metadata:
  name: health-service
spec:
  selector:
    app: health-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: health-ingress
  annotations:
    # Upstream health checks
    nginx.ingress.kubernetes.io/upstream-health-check: "true"
    nginx.ingress.kubernetes.io/upstream-health-check-path: "/health"
    nginx.ingress.kubernetes.io/upstream-health-check-interval: "10s"
    nginx.ingress.kubernetes.io/upstream-health-check-timeout: "5s"
    
    # Load balancing method
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
    
    # Session affinity
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "INGRESSCOOKIE"
    nginx.ingress.kubernetes.io/session-cookie-expires: "86400"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "86400"
spec:
  ingressClassName: nginx
  rules:
  - host: health.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: health-service
            port:
              number: 80
EOF

# Тестирование load balancing
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

for i in {1..10}; do
  echo "Request $i:"
  curl -H "Host: health.hashfoundry.local" http://$INGRESS_IP/
done

kubectl delete deployment health-app
kubectl delete service health-service
kubectl delete configmap health-content
kubectl delete ingress health-ingress
```

## 🚨 **Troubleshooting Ingress Controller:**

### **1. Диагностика Ingress Controller:**
```bash
# Проверить статус Ingress Controller
kubectl get pods -n ingress-nginx
kubectl describe pod -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Логи Ingress Controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Проверить конфигурацию NGINX
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf

# Проверить upstream серверы
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- nginx -T
```

### **2. Диагностика Ingress ресурсов:**
```bash
# Проверить все Ingress ресурсы
kubectl get ingress -A
kubectl describe ingress <ingress-name>

# Проверить события
kubectl get events --field-selector involvedObject.kind=Ingress

# Проверить аннотации
kubectl get ingress <ingress-name> -o yaml
```

### **3. Network connectivity тестирование:**
```bash
# Создать debug Pod
kubectl run debug-ingress --image=nicolaka/netshoot -it --rm -- bash

# Внутри debug Pod'а:
# nslookup ingress-nginx-controller.ingress-nginx.svc.cluster.local
# curl ingress-nginx-controller.ingress-nginx.svc.cluster.local
# telnet <ingress-ip> 80
# telnet <ingress-ip> 443
```

## 🎯 **Мониторинг Ingress Controller:**

### **1. Метрики NGINX Ingress:**
```bash
# Проверить метрики endpoint
kubectl get service -n ingress-nginx ingress-nginx-controller-metrics

# Port forward для доступа к метрикам
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller-metrics 10254:10254 &

# Получить метрики
curl http://localhost:10254/metrics

# Основные метрики:
# nginx_ingress_controller_requests - количество запросов
# nginx_ingress_controller_request_duration_seconds - время ответа
# nginx_ingress_controller_response_size - размер ответа
# nginx_ingress_controller_ssl_expire_time_seconds - время истечения SSL
```

### **2. Интеграция с Prometheus:**
```bash
# ServiceMonitor для Prometheus (если используется Prometheus Operator)
cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ingress-nginx-controller
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/component: controller
  namespaceSelector:
    matchNames:
    - ingress-nginx
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
EOF

# Проверить в Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Запросы в Prometheus:
# rate(nginx_ingress_controller_requests[5m]) - RPS
# histogram_quantile(0.95, rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])) - 95th percentile latency
```

## 🎯 **Best Practices:**

### **1. Производительность:**
- Настройка worker processes и connections
- Оптимизация buffer sizes
- Использование HTTP/2
- Кэширование статического контента

### **2. Безопасность:**
- Регулярное обновление Ingress Controller
- Настройка rate limiting
- Использование WAF (Web Application Firewall)
- Ограничение доступа по IP

### **3. Высокая доступность:**
- Несколько реплик Ingress Controller
- Anti-affinity правила
- Health checks и readiness probes
- Graceful shutdown

### **4. Мониторинг:**
- Метрики производительности
- Логирование запросов
- Алерты на ошибки и высокую latency
- Dashboard в Grafana

**Ingress Controller обеспечивает гибкую и масштабируемую маршрутизацию HTTP/HTTPS трафика в Kubernetes кластере!**
