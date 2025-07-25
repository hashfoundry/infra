# 39. Что такое Network Policies и как они работают?

## 🎯 **Что такое Network Policies?**

**Network Policies** — это ресурсы Kubernetes, которые определяют правила сетевого трафика между Pod'ами. Они работают как firewall на уровне приложений, контролируя входящий (ingress) и исходящий (egress) трафик для выбранных Pod'ов.

## 🏗️ **Основные концепции:**

### **1. Принцип работы:**
- По умолчанию все Pod'ы могут общаться друг с другом
- Network Policy создает ограничения для выбранных Pod'ов
- Правила применяются на уровне CNI (Container Network Interface)
- Требуется поддержка от сетевого плагина (Calico, Cilium, Weave)

### **2. Типы правил:**
- **Ingress**: входящий трафик к Pod'ам
- **Egress**: исходящий трафик от Pod'ов
- **Selectors**: выбор Pod'ов по labels
- **Namespaces**: изоляция между namespace'ами

### **3. Поддерживаемые протоколы:**
- TCP, UDP, SCTP
- Порты и диапазоны портов
- Named ports из Service

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка поддержки Network Policies:**
```bash
# Проверить CNI плагин
kubectl get nodes -o wide
kubectl describe node | grep -i cni

# Проверить существующие Network Policies
kubectl get networkpolicies -A
kubectl get netpol -A

# Проверить поддержку в kube-system
kubectl get pods -n kube-system | grep -E "(calico|cilium|weave|flannel)"

# Если используется Calico, проверить его статус
kubectl get pods -n kube-system -l k8s-app=calico-node
```

### **2. Создание тестовой среды:**
```bash
# Создать namespace'ы для демонстрации
kubectl create namespace frontend
kubectl create namespace backend
kubectl create namespace database

# Frontend приложение
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
  namespace: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
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
          name: frontend-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-content
  namespace: frontend
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Frontend App</title></head>
    <body>
      <h1>🌐 Frontend Application</h1>
      <p>Tier: Web</p>
      <p>Namespace: frontend</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
EOF

# Backend приложение
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      tier: api
  template:
    metadata:
      labels:
        app: backend
        tier: api
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
          name: backend-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-content
  namespace: backend
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Backend API</title></head>
    <body>
      <h1>⚙️ Backend API</h1>
      <p>Tier: API</p>
      <p>Namespace: backend</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
EOF

# Database приложение
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-app
  namespace: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: db
  template:
    metadata:
      labels:
        app: database
        tier: db
    spec:
      containers:
      - name: db
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "appdb"
        - name: POSTGRES_USER
          value: "appuser"
        - name: POSTGRES_PASSWORD
          value: "apppass"
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: database
spec:
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Проверить connectivity до применения Network Policies
echo "=== Testing connectivity before Network Policies ==="

# Тест из frontend к backend
kubectl exec -n frontend deployment/frontend-app -- curl -s backend-service.backend.svc.cluster.local

# Тест из backend к database
kubectl exec -n backend deployment/backend-app -- nc -zv database-service.database.svc.cluster.local 5432

# Тест из frontend к database (не должно быть разрешено в production)
kubectl exec -n frontend deployment/frontend-app -- nc -zv database-service.database.svc.cluster.local 5432
```

### **3. Базовые Network Policies:**
```bash
# 1. Deny All Ingress Policy для database
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: database
spec:
  podSelector: {}  # Применяется ко всем Pod'ам в namespace
  policyTypes:
  - Ingress
  # Нет ingress правил = deny all
EOF

# Проверить, что доступ к database заблокирован
echo "=== Testing after deny-all policy ==="
kubectl exec -n backend deployment/backend-app -- timeout 5 nc -zv database-service.database.svc.cluster.local 5432
kubectl exec -n frontend deployment/frontend-app -- timeout 5 nc -zv database-service.database.svc.cluster.local 5432

# 2. Allow Backend to Database Policy
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: database
spec:
  podSelector:
    matchLabels:
      tier: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: backend
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 5432
EOF

# Добавить label к backend namespace
kubectl label namespace backend name=backend

# Проверить селективный доступ
echo "=== Testing selective access ==="
kubectl exec -n backend deployment/backend-app -- nc -zv database-service.database.svc.cluster.local 5432
kubectl exec -n frontend deployment/frontend-app -- timeout 5 nc -zv database-service.database.svc.cluster.local 5432
```

### **4. Advanced Network Policies:**
```bash
# 1. Frontend isolation policy
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
  namespace: frontend
spec:
  podSelector:
    matchLabels:
      tier: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []  # Разрешить ingress от любого источника
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: backend
    ports:
    - protocol: TCP
      port: 80
  - to: {}  # DNS resolution
    ports:
    - protocol: UDP
      port: 53
EOF

# Добавить labels к namespace'ам
kubectl label namespace frontend name=frontend
kubectl label namespace backend name=backend

# 2. Backend communication policy
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: backend
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
  - to: {}  # DNS resolution
    ports:
    - protocol: UDP
      port: 53
EOF

# Тестирование изолированной архитектуры
echo "=== Testing isolated architecture ==="
kubectl exec -n frontend deployment/frontend-app -- curl -s backend-service.backend.svc.cluster.local
kubectl exec -n backend deployment/backend-app -- nc -zv database-service.database.svc.cluster.local 5432
```

## 🔧 **Специализированные Network Policies:**

### **1. IP Block и CIDR правила:**
```bash
# Policy с IP блоками
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-access-policy
  namespace: frontend
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8  # Внутренний трафик
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0   # Внешний трафик
        except:
        - 169.254.169.254/32  # Исключить metadata service
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
  - to: {}  # DNS
    ports:
    - protocol: UDP
      port: 53
EOF

# Тестирование внешнего доступа
kubectl exec -n frontend deployment/frontend-app -- curl -s --connect-timeout 5 https://httpbin.org/ip
```

### **2. Named Ports в Network Policies:**
```bash
# Приложение с named ports
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
  namespace: backend
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
        - containerPort: 8080
          name: metrics
        - containerPort: 9090
          name: admin
---
apiVersion: v1
kind: Service
metadata:
  name: multi-port-service
  namespace: backend
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
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: multi-port-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: multi-port-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - protocol: TCP
      port: http  # Named port
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: metrics  # Named port
EOF
```

### **3. Time-based и Conditional Policies:**
```bash
# Policy с дополнительными условиями
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: conditional-access
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
      environment: production
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
          environment: production
    - namespaceSelector:
        matchLabels:
          environment: production
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
          environment: production
    ports:
    - protocol: TCP
      port: 5432
EOF

# Добавить environment labels
kubectl label pods -n frontend -l app=frontend environment=production
kubectl label pods -n backend -l app=backend environment=production
kubectl label pods -n database -l app=database environment=production
```

## 🏭 **Production Network Policies:**

### **1. Default Deny All Policy:**
```bash
# Создать production namespace
kubectl create namespace production

# Default deny all policy
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Allow DNS policy
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
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

# Allow specific communication
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web
    ports:
    - protocol: TCP
      port: 8080
EOF
```

### **2. Monitoring и Logging access:**
```bash
# Allow monitoring access
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: production
spec:
  podSelector:
    matchLabels:
      monitoring: "true"
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090  # Prometheus metrics
    - protocol: TCP
      port: 8080  # Health checks
EOF

# Allow logging access
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-logging
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: logging
    ports:
    - protocol: TCP
      port: 24224  # Fluentd
    - protocol: UDP
      port: 514    # Syslog
EOF
```

## 🚨 **Troubleshooting Network Policies:**

### **1. Диагностика Network Policies:**
```bash
# Проверить все Network Policies
kubectl get networkpolicies -A
kubectl describe networkpolicy <policy-name> -n <namespace>

# Проверить labels на Pod'ах
kubectl get pods --show-labels -A

# Проверить labels на namespace'ах
kubectl get namespaces --show-labels

# Проверить селекторы
kubectl get networkpolicy <policy-name> -n <namespace> -o yaml
```

### **2. Тестирование connectivity:**
```bash
# Создать debug Pod для тестирования
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: netpol-debug
  namespace: frontend
  labels:
    app: debug
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
EOF

# Тестирование из debug Pod'а
kubectl exec -n frontend netpol-debug -- nslookup backend-service.backend.svc.cluster.local
kubectl exec -n frontend netpol-debug -- nc -zv backend-service.backend.svc.cluster.local 80
kubectl exec -n frontend netpol-debug -- curl -s --connect-timeout 5 backend-service.backend.svc.cluster.local

# Проверить iptables правила (если доступ к Node'ам)
# sudo iptables -L | grep -i calico
# sudo iptables -t nat -L | grep -i calico
```

### **3. Логирование и мониторинг:**
```bash
# Проверить логи CNI плагина
kubectl logs -n kube-system -l k8s-app=calico-node

# Проверить события
kubectl get events -A --field-selector reason=NetworkPolicyViolation

# Мониторинг Network Policy метрик (если поддерживается)
kubectl port-forward -n kube-system svc/calico-typha 9093:9093
curl http://localhost:9093/metrics | grep network_policy
```

## 🎯 **Best Practices:**

### **1. Дизайн Network Policies:**
- Начинать с default deny all
- Применять принцип least privilege
- Использовать namespace изоляцию
- Документировать все правила

### **2. Тестирование:**
- Автоматизированные тесты connectivity
- Регулярная проверка правил
- Staging environment тестирование
- Rollback планы

### **3. Мониторинг:**
- Логирование заблокированных соединений
- Метрики Network Policy применения
- Алерты на нарушения политик
- Regular audit правил

### **4. Производительность:**
- Минимизация количества правил
- Эффективные селекторы
- Кэширование DNS
- Оптимизация CNI конфигурации

## 🧹 **Очистка тестовых ресурсов:**
```bash
# Удалить все тестовые ресурсы
kubectl delete namespace frontend backend database production
kubectl delete pod netpol-debug -n frontend --ignore-not-found
```

**Network Policies обеспечивают микросегментацию сети в Kubernetes, создавая безопасную и контролируемую среду для приложений!**
