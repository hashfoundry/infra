# 187. Что такое Kubernetes API Aggregation?

## 🎯 **Что такое Kubernetes API Aggregation?**

**Kubernetes API Aggregation** — это механизм расширения Kubernetes API Server дополнительными API endpoints без изменения основного кода kube-apiserver. Через APIService ресурсы регистрируются внешние API серверы, которые становятся доступными через единую точку входа Kubernetes API, обеспечивая seamless интеграцию custom APIs.

## 🏗️ **Основные компоненты API Aggregation:**

### **1. APIService Resource**
- Регистрирует внешние API серверы в kube-apiserver
- Определяет routing rules для API групп
- Настраивает authentication и authorization delegation

### **2. Extension API Server**
- Внешний сервер, реализующий custom API logic
- Поддерживает Kubernetes API conventions
- Интегрируется с authentication/authorization системой

### **3. kube-aggregator**
- Компонент kube-apiserver для API aggregation
- Выполняет request routing к extension servers
- Обеспечивает transparent proxy functionality

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка API aggregation:**
```bash
# Зарегистрированные APIServices
kubectl get apiservices

# Metrics server как пример aggregated API
kubectl get apiservices v1beta1.metrics.k8s.io
kubectl describe apiservice v1beta1.metrics.k8s.io

# Доступные API группы
kubectl api-versions | grep -v "^v1$"

# API resources для metrics
kubectl api-resources --api-group=metrics.k8s.io
```

### **2. Metrics API в действии:**
```bash
# Использование aggregated metrics API
kubectl top nodes
kubectl top pods --all-namespaces

# Прямой доступ к metrics API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq '.items[0]'

# Metrics server pod
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl describe pod -n kube-system -l k8s-app=metrics-server
```

### **3. Custom metrics для HPA:**
```bash
# Custom metrics APIService (если установлен)
kubectl get apiservices | grep custom.metrics

# External metrics APIService
kubectl get apiservices | grep external.metrics

# HPA с custom metrics
kubectl get hpa --all-namespaces
kubectl describe hpa -n monitoring | grep -A 10 "Metrics"
```

### **4. API aggregation status:**
```bash
# Статус APIServices
kubectl get apiservices -o json | jq '.items[] | {name: .metadata.name, available: .status.conditions[0].status}'

# Service endpoints для aggregated APIs
kubectl get endpoints --all-namespaces | grep -E "(metrics|custom|external)"

# API server connectivity
kubectl get apiservices -o json | jq '.items[] | select(.spec.service != null) | {name: .metadata.name, service: .spec.service}'
```

## 🔄 **API Aggregation vs CRDs:**

### **1. Сравнение подходов:**
```bash
# CRDs в кластере
kubectl get crd | head -10

# APIServices в кластере
kubectl get apiservices | grep -v "^v1"

# Storage comparison
echo "CRDs используют etcd storage:"
kubectl get applications -n argocd -o yaml | grep -A 5 "resourceVersion"

echo "Aggregated APIs могут использовать custom storage:"
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[0] | keys'
```

### **2. Use cases для API Aggregation:**
```bash
# Metrics aggregation
kubectl top nodes --sort-by=cpu
kubectl top pods -n monitoring --sort-by=memory

# Custom business logic APIs
kubectl get --raw "/api/v1" | jq '.resources[] | select(.name == "pods") | .verbs'

# External data integration
kubectl get events --field-selector type=Warning | head -5
```

### **3. Performance comparison:**
```bash
# CRD performance
time kubectl get applications -n argocd

# Aggregated API performance  
time kubectl top nodes

# API response times
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" --v=6 2>&1 | grep "Response Status"
```

## 📈 **Мониторинг API Aggregation:**

### **1. APIService health:**
```bash
# APIService availability
kubectl get apiservices -o json | jq '.items[] | select(.status.conditions[0].status != "True") | .metadata.name'

# Service connectivity
kubectl get apiservices -o json | jq '.items[] | select(.spec.service != null) | {name: .metadata.name, namespace: .spec.service.namespace, service: .spec.service.name}'

# Certificate status
kubectl get apiservices -o json | jq '.items[] | select(.spec.caBundle != null) | .metadata.name'

# Aggregation errors
kubectl get events --all-namespaces --field-selector reason=FailedAPIService
```

### **2. Extension API server monitoring:**
```bash
# Metrics server monitoring
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl logs -n kube-system -l k8s-app=metrics-server | tail -10

# Resource usage
kubectl top pod -n kube-system -l k8s-app=metrics-server

# Service endpoints
kubectl get endpoints -n kube-system metrics-server
kubectl describe service -n kube-system metrics-server
```

### **3. API performance metrics:**
```bash
# API server metrics
kubectl get --raw /metrics | grep "apiserver_request_duration_seconds" | grep "aggregated"

# Request counts
kubectl get --raw /metrics | grep "apiserver_request_total" | grep "metrics.k8s.io"

# Error rates
kubectl get --raw /metrics | grep "apiserver_request_total.*5[0-9][0-9]" | grep "metrics"

# Latency analysis
kubectl get --raw /metrics | grep "apiserver_request_duration_seconds_bucket" | grep "metrics.k8s.io"
```

## 🏭 **API Aggregation в вашем HA кластере:**

### **1. Metrics API integration:**
```bash
# HPA с metrics API
kubectl get hpa --all-namespaces -o yaml | grep -A 10 "metrics:"

# VPA integration (если установлен)
kubectl get vpa --all-namespaces

# Monitoring stack integration
kubectl describe servicemonitor -n monitoring | grep -A 5 "endpoints"

# Custom metrics collection
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/monitoring/pods" | jq '.items[] | {name: .metadata.name, cpu: .containers[0].usage.cpu}'
```

### **2. ArgoCD API extensions:**
```bash
# ArgoCD API resources
kubectl api-resources --api-group=argoproj.io

# ArgoCD CRDs vs potential aggregation
kubectl get crd | grep argoproj.io

# ArgoCD API performance
time kubectl get applications -n argocd
time kubectl get appprojects -n argocd
```

### **3. Storage API integration:**
```bash
# CSI API resources
kubectl api-resources --api-group=storage.k8s.io

# Volume snapshot APIs
kubectl api-resources --api-group=snapshot.storage.k8s.io

# Storage metrics via aggregated APIs
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[] | {name: .metadata.name, storage: .usage}'
```

## 🔧 **Создание простого Extension API Server:**

### **1. APIService registration:**
```bash
# Создание namespace
kubectl create namespace custom-api-system

# Создание APIService
cat << EOF | kubectl apply -f -
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1.example.com
spec:
  group: example.com
  version: v1
  service:
    name: custom-api-server
    namespace: custom-api-system
    port: 443
  groupPriorityMinimum: 100
  versionPriority: 100
  insecureSkipTLSVerify: true
EOF

# Проверка регистрации
kubectl get apiservice v1.example.com
kubectl describe apiservice v1.example.com
```

### **2. Mock API server:**
```bash
# Создание mock service
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: custom-api-server
  namespace: custom-api-system
spec:
  selector:
    app: custom-api-server
  ports:
  - port: 443
    targetPort: 8443
    protocol: TCP
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-api-server
  namespace: custom-api-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-api-server
  template:
    metadata:
      labels:
        app: custom-api-server
    spec:
      containers:
      - name: api-server
        image: nginx:alpine
        ports:
        - containerPort: 8443
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Mock API Server'; sleep 30; done"]
EOF

# Проверка deployment
kubectl get pods -n custom-api-system
kubectl get service -n custom-api-system
```

### **3. Тестирование API:**
```bash
# Проверка API availability
kubectl get apiservice v1.example.com -o yaml | grep -A 5 "conditions"

# Попытка доступа к API
kubectl get --raw "/apis/example.com/v1/"

# Очистка
kubectl delete apiservice v1.example.com
kubectl delete namespace custom-api-system
```

## 🎯 **Архитектура API Aggregation:**

```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes API Aggregation Layer              │
├─────────────────────────────────────────────────────────────┤
│  Client Request                                             │
│  ├── kubectl/HTTP client                                   │
│  ├── Authentication                                        │
│  └── API path routing                                      │
├─────────────────────────────────────────────────────────────┤
│  kube-apiserver (Aggregation Layer)                        │
│  ├── Request authentication                                │
│  ├── Authorization check                                   │
│  ├── APIService lookup                                     │
│  └── Request forwarding                                    │
├─────────────────────────────────────────────────────────────┤
│  Extension API Server                                      │
│  ├── Custom business logic                                 │
│  ├── Custom storage backend                                │
│  ├── Response generation                                   │
│  └── Kubernetes API compliance                             │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Troubleshooting API Aggregation:**

### **1. APIService issues:**
```bash
# APIService status
kubectl get apiservices -o json | jq '.items[] | select(.status.conditions[0].status != "True")'

# Service connectivity
kubectl get apiservices -o json | jq '.items[] | select(.spec.service != null)' | while read apiservice; do
  name=$(echo $apiservice | jq -r '.metadata.name')
  namespace=$(echo $apiservice | jq -r '.spec.service.namespace')
  service=$(echo $apiservice | jq -r '.spec.service.name')
  echo "Testing $name -> $namespace/$service"
  kubectl get endpoints -n $namespace $service
done

# Certificate issues
kubectl get events --all-namespaces --field-selector reason=FailedAPIService

# API server logs
kubectl logs -n kube-system -l component=kube-apiserver | grep -i "aggregat" | tail -10
```

### **2. Extension server issues:**
```bash
# Metrics server troubleshooting
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl logs -n kube-system -l k8s-app=metrics-server | grep ERROR

# Service resolution
kubectl get endpoints -n kube-system metrics-server
kubectl describe service -n kube-system metrics-server

# Network connectivity
kubectl exec -n kube-system deployment/metrics-server -- nslookup kubernetes.default.svc.cluster.local
```

### **3. Performance issues:**
```bash
# API latency
kubectl get --raw /metrics | grep "apiserver_request_duration_seconds.*metrics.k8s.io"

# Request volume
kubectl get --raw /metrics | grep "apiserver_request_total.*metrics.k8s.io"

# Error rates
kubectl get events --all-namespaces --field-selector type=Warning | grep -i "api"

# Resource usage
kubectl top pod -n kube-system -l k8s-app=metrics-server
```

## 🎯 **Best Practices для API Aggregation:**

### **1. Безопасность:**
- Используйте proper TLS certificates
- Настраивайте authentication delegation
- Реализуйте authorization checks
- Валидируйте input data

### **2. Производительность:**
- Оптимизируйте API response times
- Используйте efficient storage backends
- Кэшируйте данные где возможно
- Мониторьте resource usage

### **3. Надежность:**
- Реализуйте health checks
- Используйте proper error handling
- Настраивайте monitoring и alerting
- Планируйте disaster recovery

### **4. Операционные аспекты:**
- Документируйте API schemas
- Версионируйте APIs properly
- Тестируйте backward compatibility
- Мониторьте API usage patterns

**API Aggregation — это мощный механизм для создания enterprise-grade API extensions в Kubernetes!**
