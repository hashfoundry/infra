# 30. Как Kubernetes обрабатывает DNS для Pod'ов?

## 🎯 **Что такое DNS в Kubernetes?**

**DNS в Kubernetes** — это система разрешения имен, которая позволяет Pod'ам находить друг друга и сервисы по именам вместо IP-адресов. Kubernetes использует CoreDNS (или kube-dns в старых версиях) для предоставления DNS-сервисов внутри кластера.

## 🏗️ **Компоненты DNS системы:**

### **1. CoreDNS**
- DNS-сервер кластера
- Работает как Deployment в kube-system
- Обрабатывает DNS-запросы от Pod'ов
- Настраивается через ConfigMap

### **2. DNS Policy**
- ClusterFirst (по умолчанию)
- Default
- ClusterFirstWithHostNet
- None

### **3. DNS Records**
- Service records (A, AAAA, SRV)
- Pod records
- Namespace-based resolution
- External name resolution

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка CoreDNS в кластере:**
```bash
# Проверить CoreDNS Pod'ы
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Подробная информация о CoreDNS
kubectl describe deployment coredns -n kube-system

# CoreDNS конфигурация
kubectl get configmap coredns -n kube-system -o yaml

# CoreDNS Service
kubectl get service kube-dns -n kube-system
```

### **2. DNS в ArgoCD namespace:**
```bash
# ArgoCD Services для DNS resolution
kubectl get services -n argocd

# Тестирование DNS resolution для ArgoCD
kubectl run dns-test --image=busybox -it --rm -- nslookup argocd-server.argocd.svc.cluster.local

# Проверить DNS записи ArgoCD
kubectl run dns-test --image=busybox -it --rm -- nslookup argocd-server.argocd

# Полное доменное имя ArgoCD
kubectl run dns-test --image=busybox -it --rm -- dig argocd-server.argocd.svc.cluster.local
```

### **3. DNS в monitoring namespace:**
```bash
# Monitoring Services
kubectl get services -n monitoring

# DNS resolution для Prometheus
kubectl run dns-test --image=busybox -it --rm -- nslookup prometheus-server.monitoring.svc.cluster.local

# DNS resolution для Grafana
kubectl run dns-test --image=busybox -it --rm -- nslookup grafana.monitoring.svc.cluster.local

# Короткие имена в том же namespace
kubectl run dns-test -n monitoring --image=busybox -it --rm -- nslookup prometheus-server
```

## 🔄 **DNS Resolution схемы:**

### **1. Service DNS Records:**
```bash
# Создать Service для демонстрации DNS
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
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
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# DNS записи для Service:
# web-service.default.svc.cluster.local (полное имя)
# web-service.default.svc (без домена кластера)
# web-service.default (без svc)
# web-service (в том же namespace)

# Тестирование различных форм DNS имен
kubectl run dns-test --image=busybox -it --rm -- nslookup web-service
kubectl run dns-test --image=busybox -it --rm -- nslookup web-service.default
kubectl run dns-test --image=busybox -it --rm -- nslookup web-service.default.svc
kubectl run dns-test --image=busybox -it --rm -- nslookup web-service.default.svc.cluster.local

kubectl delete deployment web-app
kubectl delete service web-service
```

### **2. Pod DNS Records:**
```bash
# Pod DNS записи (если включены)
# <pod-ip-with-dashes>.<namespace>.pod.cluster.local

# Создать Pod для тестирования
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-pod-test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
EOF

# Получить IP Pod'а
POD_IP=$(kubectl get pod dns-pod-test -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"

# Преобразовать IP в DNS формат (заменить . на -)
POD_DNS=$(echo $POD_IP | tr '.' '-')
echo "Pod DNS: $POD_DNS.default.pod.cluster.local"

# Тестировать Pod DNS (может не работать в некоторых кластерах)
kubectl run dns-test --image=busybox -it --rm -- nslookup $POD_DNS.default.pod.cluster.local

kubectl delete pod dns-pod-test
```

### **3. Headless Service DNS:**
```bash
# Headless Service для прямого доступа к Pod'ам
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
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
          value: "testdb"
        - name: POSTGRES_USER
          value: "testuser"
        - name: POSTGRES_PASSWORD
          value: "testpass"
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
EOF

# Headless Service создает DNS записи для каждого Pod'а:
# database-0.database-headless.default.svc.cluster.local
# database-1.database-headless.default.svc.cluster.local
# database-2.database-headless.default.svc.cluster.local

# Тестирование Headless Service DNS
kubectl run dns-test --image=busybox -it --rm -- nslookup database-headless
kubectl run dns-test --image=busybox -it --rm -- nslookup database-0.database-headless

kubectl delete statefulset database
kubectl delete service database-headless
```

## 🔧 **DNS Policies:**

### **1. ClusterFirst (по умолчанию):**
```bash
# Pod с ClusterFirst DNS policy
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: clusterfirst-dns
spec:
  dnsPolicy: ClusterFirst
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
EOF

# Проверить DNS конфигурацию
kubectl exec clusterfirst-dns -- cat /etc/resolv.conf

# Должен показать:
# nameserver <cluster-dns-ip>
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5

kubectl delete pod clusterfirst-dns
```

### **2. Default DNS policy:**
```bash
# Pod с Default DNS policy (использует Node DNS)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: default-dns
spec:
  dnsPolicy: Default
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
EOF

# Использует DNS настройки Node'а
kubectl exec default-dns -- cat /etc/resolv.conf

kubectl delete pod default-dns
```

### **3. Custom DNS конфигурация:**
```bash
# Pod с кастомной DNS конфигурацией
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 8.8.8.8
    - 8.8.4.4
    searches:
    - custom.local
    options:
    - name: ndots
      value: "2"
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
EOF

kubectl exec custom-dns -- cat /etc/resolv.conf

kubectl delete pod custom-dns
```

## 📈 **Мониторинг DNS:**

### **1. CoreDNS метрики:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики CoreDNS:
# coredns_dns_requests_total - общее количество DNS запросов
# coredns_dns_responses_total - общее количество DNS ответов
# coredns_dns_request_duration_seconds - время обработки запросов
# coredns_dns_response_size_bytes - размер DNS ответов
# coredns_forward_requests_total - переадресованные запросы
```

### **2. DNS производительность:**
```bash
# Тестирование DNS производительности
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-perf-test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c']
    args:
    - |
      while true; do
        echo "Testing DNS resolution..."
        time nslookup kubernetes.default.svc.cluster.local
        time nslookup google.com
        sleep 10
      done
EOF

# Мониторить логи для времени DNS resolution
kubectl logs dns-perf-test -f

kubectl delete pod dns-perf-test
```

### **3. DNS отладка:**
```bash
# Создать debug Pod для DNS тестирования
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-debug
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ['sleep', '3600']
EOF

# Комплексное DNS тестирование
kubectl exec -it dns-debug -- bash

# Внутри Pod'а:
# nslookup kubernetes.default.svc.cluster.local
# dig kubernetes.default.svc.cluster.local
# host kubernetes.default.svc.cluster.local
# cat /etc/resolv.conf

kubectl delete pod dns-debug
```

## 🏭 **Production DNS конфигурации:**

### **1. Микросервисная архитектура:**
```bash
# Микросервисы с DNS communication
cat << EOF | kubectl apply -f -
# Frontend Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: default
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
        env:
        - name: BACKEND_URL
          value: "http://backend.default.svc.cluster.local:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
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
        env:
        - name: DATABASE_URL
          value: "postgresql://database.default.svc.cluster.local:5432/appdb"
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 80
EOF

# Тестирование межсервисной коммуникации
kubectl run test-communication --image=busybox -it --rm -- wget -qO- frontend.default.svc.cluster.local

kubectl delete deployment frontend backend
kubectl delete service frontend backend
```

### **2. Cross-namespace DNS:**
```bash
# Создать дополнительный namespace
kubectl create namespace production

# Service в production namespace
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-api
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: prod-api
  template:
    metadata:
      labels:
        app: prod-api
    spec:
      containers:
      - name: api
        image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: prod-api
  namespace: production
spec:
  selector:
    app: prod-api
  ports:
  - port: 80
    targetPort: 80
EOF

# Доступ из default namespace к production
kubectl run cross-ns-test --image=busybox -it --rm -- nslookup prod-api.production.svc.cluster.local

kubectl delete deployment prod-api -n production
kubectl delete service prod-api -n production
kubectl delete namespace production
```

### **3. External DNS integration:**
```bash
# ExternalName Service для внешних ресурсов
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
EOF

# DNS resolution для external service
kubectl run external-test --image=busybox -it --rm -- nslookup external-database.default.svc.cluster.local

kubectl delete service external-database
```

## 🚨 **DNS Troubleshooting:**

### **1. DNS resolution проблемы:**
```bash
# Создать Pod для диагностики DNS проблем
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-troubleshoot
spec:
  containers:
  - name: troubleshoot
    image: busybox
    command: ['sleep', '3600']
EOF

# Пошаговая диагностика DNS
kubectl exec dns-troubleshoot -- cat /etc/resolv.conf
kubectl exec dns-troubleshoot -- nslookup kubernetes.default
kubectl exec dns-troubleshoot -- nslookup kubernetes.default.svc.cluster.local

# Проверить доступность CoreDNS
kubectl exec dns-troubleshoot -- nslookup kube-dns.kube-system.svc.cluster.local

kubectl delete pod dns-troubleshoot
```

### **2. CoreDNS логи:**
```bash
# Проверить логи CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns

# Включить debug логи в CoreDNS (осторожно в production!)
kubectl get configmap coredns -n kube-system -o yaml

# Добавить log plugin в Corefile для debugging:
# .:53 {
#     log
#     errors
#     health
#     ...
# }
```

### **3. DNS cache проблемы:**
```bash
# Очистка DNS cache в Pod'е
kubectl exec <pod-name> -- nscd -i hosts

# Проверка DNS cache timeout
kubectl exec dns-troubleshoot -- cat /etc/resolv.conf | grep options

# Тестирование с различными ndots значениями
kubectl run ndots-test --image=busybox -it --rm -- sh -c 'echo "options ndots:1" >> /etc/resolv.conf && nslookup google.com'
```

## 🎯 **Best Practices для DNS:**

### **1. DNS оптимизация:**
- Используйте полные доменные имена (FQDN) для лучшей производительности
- Настройте правильные ndots значения
- Кэшируйте DNS результаты в приложениях
- Мониторьте DNS метрики

### **2. Security considerations:**
```bash
# Network Policies для ограничения DNS доступа
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-dns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

kubectl delete networkpolicy deny-all-dns
```

### **3. DNS мониторинг:**
```bash
# Алерты на DNS проблемы
cat << EOF
groups:
- name: dns-alerts
  rules:
  - alert: CoreDNSDown
    expr: up{job="coredns"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "CoreDNS is down"
      
  - alert: HighDNSLatency
    expr: histogram_quantile(0.99, coredns_dns_request_duration_seconds_bucket) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High DNS resolution latency"
EOF
```

### **4. DNS конфигурация:**
- Используйте ClusterFirst для большинства Pod'ов
- Настройте кастомные DNS только при необходимости
- Регулярно обновляйте CoreDNS
- Мониторьте DNS производительность и ошибки

**Правильная настройка DNS обеспечивает надежную коммуникацию между компонентами кластера!**
