# 34. Как работает балансировка нагрузки в Kubernetes Services?

## 🎯 **Что такое Load Balancing в Kubernetes?**

**Load Balancing** в Kubernetes — это механизм распределения входящего трафика между несколькими Pod'ами, обеспечивающий высокую доступность, масштабируемость и равномерное использование ресурсов.

## 🏗️ **Компоненты Load Balancing:**

### **1. kube-proxy**
- Сетевой прокси на каждом Node
- Реализует Service abstraction
- Управляет iptables/IPVS правилами

### **2. Service Types и балансировка**
- ClusterIP: внутренняя балансировка
- NodePort: балансировка через Node'ы
- LoadBalancer: внешняя балансировка

### **3. Алгоритмы балансировки**
- Round Robin (по умолчанию)
- Session Affinity
- Topology-aware routing

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующей балансировки:**
```bash
# Проверить kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl describe daemonset kube-proxy -n kube-system

# Проверить режим kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep "Using"

# Балансировка в ArgoCD
kubectl get service argocd-server -n argocd
kubectl get endpoints argocd-server -n argocd
kubectl describe service argocd-server -n argocd

# Балансировка в monitoring
kubectl get service prometheus-server -n monitoring
kubectl get endpoints prometheus-server -n monitoring
kubectl describe service prometheus-server -n monitoring
```

### **2. Создание Service с балансировкой:**
```bash
# Deployment с несколькими репликами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-balance-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: load-balance-demo
  template:
    metadata:
      labels:
        app: load-balance-demo
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: load-balance-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: load-balance-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Load Balance Demo</title></head>
    <body>
      <h1>Load Balancing Test</h1>
      <p>Pod Name: <span id="podname"></span></p>
      <p>Pod IP: <span id="podip"></span></p>
      <script>
        document.getElementById('podname').textContent = '$POD_NAME';
        document.getElementById('podip').textContent = '$POD_IP';
      </script>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: load-balance-service
spec:
  selector:
    app: load-balance-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить балансировку
kubectl get service load-balance-service
kubectl get endpoints load-balance-service

# Тестирование балансировки
for i in {1..10}; do
  kubectl run test-$i --image=busybox --rm -it -- wget -qO- load-balance-service | grep "Pod"
done

kubectl delete deployment load-balance-demo
kubectl delete service load-balance-service
kubectl delete configmap load-balance-content
```

### **3. Тестирование алгоритмов балансировки:**
```bash
# Service с Round Robin (по умолчанию)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: round-robin-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: round-robin-app
  template:
    metadata:
      labels:
        app: round-robin-app
    spec:
      containers:
      - name: web
        image: httpd:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "<h1>Pod: $(hostname)</h1><p>IP: $(hostname -i)</p>" > /usr/local/apache2/htdocs/index.html
          httpd-foreground
---
apiVersion: v1
kind: Service
metadata:
  name: round-robin-service
spec:
  selector:
    app: round-robin-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Тестирование Round Robin
echo "=== Round Robin Test ==="
for i in {1..9}; do
  echo "Request $i:"
  kubectl run test-client --image=busybox --rm -it -- wget -qO- round-robin-service
  echo "---"
done

kubectl delete deployment round-robin-app
kubectl delete service round-robin-service
```

## 🔄 **Session Affinity (Sticky Sessions):**

### **1. ClientIP Session Affinity:**
```bash
# Service с session affinity
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: session-affinity-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: session-affinity-app
  template:
    metadata:
      labels:
        app: session-affinity-app
    spec:
      containers:
      - name: web
        image: httpd:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "<h1>Session Pod: $(hostname)</h1><p>IP: $(hostname -i)</p><p>Time: $(date)</p>" > /usr/local/apache2/htdocs/index.html
          httpd-foreground
---
apiVersion: v1
kind: Service
metadata:
  name: session-affinity-service
spec:
  selector:
    app: session-affinity-app
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 часа
  ports:
  - port: 80
    targetPort: 80
EOF

# Тестирование session affinity
echo "=== Session Affinity Test ==="
kubectl run session-test --image=busybox -it --rm -- sh -c '
for i in $(seq 1 5); do
  echo "Request $i from same client:"
  wget -qO- session-affinity-service
  echo "---"
  sleep 1
done'

kubectl describe service session-affinity-service | grep -A 5 "Session Affinity"

kubectl delete deployment session-affinity-app
kubectl delete service session-affinity-service
```

### **2. Сравнение с и без Session Affinity:**
```bash
# Без Session Affinity
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-affinity-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: no-affinity-app
  template:
    metadata:
      labels:
        app: no-affinity-app
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
  name: no-affinity-service
spec:
  selector:
    app: no-affinity-app
  sessionAffinity: None  # По умолчанию
  ports:
  - port: 80
    targetPort: 80
---
# С Session Affinity
apiVersion: v1
kind: Service
metadata:
  name: with-affinity-service
spec:
  selector:
    app: no-affinity-app
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
  ports:
  - port: 80
    targetPort: 80
EOF

# Сравнительное тестирование
echo "=== Without Session Affinity ==="
kubectl run test-no-affinity --image=busybox --rm -it -- sh -c '
for i in $(seq 1 5); do
  wget -qO- no-affinity-service | grep "Server"
done'

echo -e "\n=== With Session Affinity ==="
kubectl run test-with-affinity --image=busybox --rm -it -- sh -c '
for i in $(seq 1 5); do
  wget -qO- with-affinity-service | grep "Server"
done'

kubectl delete deployment no-affinity-app
kubectl delete service no-affinity-service with-affinity-service
```

## 📈 **External Load Balancer (Cloud Provider):**

### **1. LoadBalancer Service в Digital Ocean:**
```bash
# LoadBalancer Service
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-lb-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: external-lb-app
  template:
    metadata:
      labels:
        app: external-lb-app
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
apiVersion: v1
kind: Service
metadata:
  name: external-lb-service
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-name: "hashfoundry-demo-lb"
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/"
    service.beta.kubernetes.io/do-loadbalancer-size-slug: "lb-small"
    service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
spec:
  type: LoadBalancer
  selector:
    app: external-lb-app
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF

# Проверить LoadBalancer
kubectl get service external-lb-service
kubectl describe service external-lb-service

# Ждем получения External IP
kubectl get service external-lb-service -w

# Тестирование внешней балансировки
EXTERNAL_IP=$(kubectl get service external-lb-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External LoadBalancer IP: $EXTERNAL_IP"

# Многоуровневая балансировка:
# 1. Digital Ocean LoadBalancer -> Node'ы
# 2. kube-proxy на Node'ах -> Pod'ы

kubectl delete deployment external-lb-app
kubectl delete service external-lb-service
```

### **2. Health Checks и балансировка:**
```bash
# Service с health checks
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-check-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: health-check-app
  template:
    metadata:
      labels:
        app: health-check-app
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
  name: health-check-service
spec:
  selector:
    app: health-check-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Проверить endpoints (только ready Pod'ы)
kubectl get endpoints health-check-service
kubectl describe endpoints health-check-service

# Симуляция нездорового Pod'а
kubectl exec deployment/health-check-app -- rm /usr/share/nginx/html/index.html

# Проверить изменения в endpoints
sleep 10
kubectl get endpoints health-check-service

kubectl delete deployment health-check-app
kubectl delete service health-check-service
```

## 🏭 **Advanced Load Balancing:**

### **1. Topology-aware routing:**
```bash
# Service с topology-aware routing
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
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
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
  selector:
    app: topology-app
  ports:
  - port: 80
    targetPort: 80
  internalTrafficPolicy: Local  # Предпочитать локальные Pod'ы
EOF

# Проверить распределение Pod'ов по Node'ам
kubectl get pods -l app=topology-app -o wide

# Тестирование topology-aware routing
kubectl describe service topology-service | grep "Internal Traffic Policy"

kubectl delete deployment topology-app
kubectl delete service topology-service
```

### **2. External Traffic Policy:**
```bash
# NodePort с External Traffic Policy
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traffic-policy-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: traffic-policy-app
  template:
    metadata:
      labels:
        app: traffic-policy-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
---
# Service с Cluster traffic policy (по умолчанию)
apiVersion: v1
kind: Service
metadata:
  name: cluster-traffic-service
spec:
  type: NodePort
  selector:
    app: traffic-policy-app
  externalTrafficPolicy: Cluster  # По умолчанию
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30087
---
# Service с Local traffic policy
apiVersion: v1
kind: Service
metadata:
  name: local-traffic-service
spec:
  type: NodePort
  selector:
    app: traffic-policy-app
  externalTrafficPolicy: Local  # Только локальные Pod'ы
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30088
EOF

# Сравнить traffic policies
kubectl describe service cluster-traffic-service | grep "External Traffic Policy"
kubectl describe service local-traffic-service | grep "External Traffic Policy"

# Local policy сохраняет source IP, но может быть неравномерным
kubectl get nodes -o wide

kubectl delete deployment traffic-policy-app
kubectl delete service cluster-traffic-service local-traffic-service
```

### **3. Custom Load Balancing с IPVS:**
```bash
# Проверить режим kube-proxy
kubectl get configmap kube-proxy -n kube-system -o yaml | grep mode

# Если используется IPVS, можно настроить алгоритмы
# Доступные алгоритмы IPVS:
# - rr (round robin)
# - lc (least connection)
# - dh (destination hashing)
# - sh (source hashing)
# - sed (shortest expected delay)
# - nq (never queue)

# Пример конфигурации IPVS (требует обновления kube-proxy)
cat << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    mode: "ipvs"
    ipvs:
      scheduler: "rr"  # round robin
      # scheduler: "lc"  # least connection
      # scheduler: "sh"  # source hashing
EOF
```

## 🚨 **Load Balancing Troubleshooting:**

### **1. Неравномерная балансировка:**
```bash
# Создать сценарий с неравномерной нагрузкой
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: uneven-load-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: uneven-load-app
  template:
    metadata:
      labels:
        app: uneven-load-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: uneven-load-service
spec:
  selector:
    app: uneven-load-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Диагностика балансировки
kubectl get endpoints uneven-load-service
kubectl describe service uneven-load-service

# Проверить состояние Pod'ов
kubectl get pods -l app=uneven-load-app -o wide

# Тестирование распределения нагрузки
echo "=== Load Distribution Test ==="
for i in {1..20}; do
  kubectl run load-test-$i --image=busybox --rm -it -- wget -qO- uneven-load-service | grep -o "Server: [^<]*" || true
done

kubectl delete deployment uneven-load-app
kubectl delete service uneven-load-service
```

### **2. Проблемы с kube-proxy:**
```bash
# Диагностика kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=50

# Проверить iptables правила (если доступ к Node'ам)
# sudo iptables -t nat -L | grep KUBE

# Проверить IPVS правила (если используется IPVS)
# sudo ipvsadm -L -n

# Перезапуск kube-proxy при проблемах
kubectl delete pods -n kube-system -l k8s-app=kube-proxy
```

### **3. Service Discovery и балансировка:**
```bash
# Проверить DNS resolution
kubectl run dns-test --image=busybox -it --rm -- nslookup prometheus-server.monitoring.svc.cluster.local

# Проверить endpoints
kubectl get endpoints -A | grep -E "(prometheus|grafana|argocd)"

# Проверить Service конфигурацию
kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,PORTS:.spec.ports[0].port
```

## 🎯 **Load Balancing Best Practices:**

### **1. Выбор алгоритма балансировки:**
- **Round Robin**: равномерное распределение запросов
- **Session Affinity**: для stateful приложений
- **Topology-aware**: для снижения latency
- **Health Checks**: исключение нездоровых Pod'ов

### **2. Мониторинг балансировки:**
```bash
# Метрики в Prometheus:
# kube_service_info - информация о Services
# kube_endpoint_info - информация об Endpoints
# kube_pod_info - информация о Pod'ах

# Проверить метрики балансировки
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Запросы для мониторинга:
# rate(container_network_receive_bytes_total[5m]) - входящий трафик
# rate(container_network_transmit_bytes_total[5m]) - исходящий трафик
```

### **3. Оптимизация производительности:**
```yaml
# Оптимальная конфигурация Service
apiVersion: v1
kind: Service
metadata:
  name: optimized-service
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  sessionAffinity: None  # Для stateless приложений
  internalTrafficPolicy: Local  # Для снижения latency
```

**Load Balancing в Kubernetes обеспечивает высокую доступность и равномерное распределение нагрузки между Pod'ами через различные механизмы и алгоритмы!**
