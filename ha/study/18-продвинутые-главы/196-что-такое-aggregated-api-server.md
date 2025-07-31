# 196. Что такое Aggregated API Server?

## 🎯 **Что такое Aggregated API Server?**

**Aggregated API Server** — это механизм расширения Kubernetes API, позволяющий добавлять пользовательские API серверы, которые интегрируются с основным kube-apiserver. Это обеспечивает единый интерфейс для всех API ресурсов через стандартные инструменты Kubernetes.

## 🏗️ **Основные компоненты:**

### **1. API Aggregation Layer**
- Проксирование запросов к extension API серверам
- Единая точка входа через kube-apiserver
- Автоматическое обнаружение API
- Интеграция с аутентификацией и авторизацией

### **2. APIService Registration**
- Регистрация пользовательских API групп
- Маршрутизация запросов к соответствующим серверам
- Управление приоритетами API версий
- TLS сертификация для безопасности

### **3. Extension API Servers**
- Пользовательские реализации API логики
- Обработка CRUD операций
- Валидация и мутация ресурсов
- Интеграция с хранилищем данных

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка существующих Aggregated API:**
```bash
# Проверка всех APIServices в кластере
kubectl get apiservices

# Проверка metrics server (пример aggregated API)
kubectl get apiservices v1beta1.metrics.k8s.io -o yaml

# Проверка доступных API групп
kubectl api-resources | grep -v "^NAME"

# Проверка API versions
kubectl api-versions | sort

# Проверка custom resource definitions
kubectl get crd
```

### **2. Анализ Metrics Server как пример:**
```bash
# Metrics Server - стандартный пример Aggregated API
kubectl get deployment metrics-server -n kube-system

# Проверка APIService для metrics
kubectl describe apiservice v1beta1.metrics.k8s.io

# Тестирование metrics API
kubectl top nodes
kubectl top pods -n monitoring

# Проверка service для metrics server
kubectl get service metrics-server -n kube-system -o yaml
```

### **3. Проверка ArgoCD как extension API:**
```bash
# ArgoCD использует CRDs, но можно создать aggregated API
kubectl get crd | grep argoproj

# Проверка ArgoCD API ресурсов
kubectl api-resources | grep argoproj

# Проверка applications через API
kubectl get applications -n argocd -o yaml | head -20
```

### **4. Создание тестового Extension API Server:**
```bash
# Создание namespace для тестирования
kubectl create namespace api-extension-test

# Генерация TLS сертификатов для API server
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example-api-server.api-extension-test.svc"

# Создание secret с сертификатами
kubectl create secret tls example-api-server-certs \
  --cert=tls.crt --key=tls.key -n api-extension-test
```

### **5. Мониторинг API aggregation:**
```bash
# Проверка логов kube-apiserver для aggregation
kubectl logs -n kube-system -l component=kube-apiserver | grep -i aggregat

# Проверка метрик API server
kubectl port-forward -n kube-system svc/kube-apiserver 8080:8080 &
curl http://localhost:8080/metrics | grep apiserver_request

# Мониторинг через Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Query: apiserver_request_duration_seconds{verb="GET"}
```

## 🔄 **Создание Extension API Server:**

### **1. APIService и Service конфигурация:**
```yaml
# example-api-server.yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1alpha1.widgets.example.com
spec:
  group: widgets.example.com
  version: v1alpha1
  groupPriorityMinimum: 100
  versionPriority: 100
  service:
    name: example-api-server
    namespace: api-extension-test
    port: 443
  caBundle: LS0tLS1CRUdJTi0tLS0t  # Base64 encoded CA cert
  insecureSkipTLSVerify: false

---
# Service для extension API server
apiVersion: v1
kind: Service
metadata:
  name: example-api-server
  namespace: api-extension-test
  labels:
    app: example-api-server
spec:
  selector:
    app: example-api-server
  ports:
  - name: https
    port: 443
    targetPort: 8443
    protocol: TCP
  type: ClusterIP

---
# Deployment для extension API server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-api-server
  namespace: api-extension-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: example-api-server
  template:
    metadata:
      labels:
        app: example-api-server
    spec:
      serviceAccountName: example-api-server
      containers:
      - name: api-server
        image: example/widget-api-server:v1.0.0
        ports:
        - containerPort: 8443
          name: https
        args:
        - --secure-port=8443
        - --tls-cert-file=/etc/certs/tls.crt
        - --tls-private-key-file=/etc/certs/tls.key
        - --audit-log-path=-
        - --feature-gates=APIPriorityAndFairness=false
        - --audit-log-maxage=0
        - --audit-log-maxbackup=0
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: certs
          mountPath: /etc/certs
          readOnly: true
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
      volumes:
      - name: certs
        secret:
          secretName: example-api-server-certs

---
# ServiceAccount и RBAC
apiVersion: v1
kind: ServiceAccount
metadata:
  name: example-api-server
  namespace: api-extension-test

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: example-api-server
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create"]
- apiGroups: ["authorization.k8s.io"]
  resources: ["subjectaccessreviews"]
  verbs: ["create"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: example-api-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: example-api-server
subjects:
- kind: ServiceAccount
  name: example-api-server
  namespace: api-extension-test

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: example-api-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: example-api-server
  namespace: api-extension-test
```

### **2. Widget Custom Resource Definition:**
```yaml
# widget-crd.yaml (для сравнения с aggregated API)
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: widgets.widgets.example.com
spec:
  group: widgets.example.com
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              size:
                type: string
                enum: ["small", "medium", "large"]
                default: "medium"
              color:
                type: string
                default: "blue"
              replicas:
                type: integer
                minimum: 1
                maximum: 10
                default: 1
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Active", "Failed"]
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
  scope: Namespaced
  names:
    plural: widgets
    singular: widget
    kind: Widget
    shortNames:
    - wg
```

### **3. Тестирование Extension API:**
```bash
# Применение конфигурации
kubectl apply -f example-api-server.yaml

# Проверка deployment
kubectl get pods -n api-extension-test -l app=example-api-server

# Проверка APIService статуса
kubectl get apiservice v1alpha1.widgets.example.com

# Проверка доступности API
kubectl api-resources | grep widgets

# Создание тестового widget
cat <<EOF | kubectl apply -f -
apiVersion: widgets.example.com/v1alpha1
kind: Widget
metadata:
  name: test-widget
  namespace: api-extension-test
spec:
  size: large
  color: red
  replicas: 3
EOF

# Проверка созданного ресурса
kubectl get widgets -n api-extension-test
kubectl describe widget test-widget -n api-extension-test
```

## 🔧 **Мониторинг и диагностика Aggregated API:**

### **1. Проверка состояния APIServices:**
```bash
# Статус всех APIServices
kubectl get apiservices -o wide

# Детальная информация об APIService
kubectl describe apiservice v1alpha1.widgets.example.com

# Проверка условий доступности
kubectl get apiservice v1alpha1.widgets.example.com -o jsonpath='{.status.conditions[*]}'

# Логи extension API server
kubectl logs -n api-extension-test -l app=example-api-server
```

### **2. Диагностика проблем:**
```bash
# Проверка сетевой связности
kubectl get endpoints -n api-extension-test example-api-server

# Проверка сертификатов
kubectl get secret example-api-server-certs -n api-extension-test -o yaml

# Тестирование прямого подключения к API server
kubectl port-forward -n api-extension-test svc/example-api-server 8443:443 &
curl -k https://localhost:8443/healthz

# Проверка RBAC разрешений
kubectl auth can-i create widgets.widgets.example.com --as=system:serviceaccount:api-extension-test:example-api-server
```

### **3. Prometheus метрики для API aggregation:**
```yaml
# api-server-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-api-server
  namespace: api-extension-test
spec:
  selector:
    matchLabels:
      app: example-api-server
  endpoints:
  - port: https
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
    path: /metrics

---
# PrometheusRule для алертов
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: api-server-alerts
  namespace: api-extension-test
spec:
  groups:
  - name: api-server.rules
    rules:
    - alert: APIServerDown
      expr: up{job="example-api-server"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Extension API Server is down"
        description: "Extension API Server has been down for more than 1 minute"
    
    - alert: APIServerHighLatency
      expr: histogram_quantile(0.99, rate(apiserver_request_duration_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High API Server latency"
        description: "99th percentile latency is above 1s"
```

## 🏭 **Интеграция с существующим HA кластером:**

### **1. Использование с ArgoCD:**
```yaml
# argocd-widget-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: widget-api-server
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/widget-api-server
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: api-extension-test
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### **2. Мониторинг через Grafana:**
```json
{
  "dashboard": {
    "title": "Extension API Server Metrics",
    "panels": [
      {
        "title": "API Server Availability",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"example-api-server\"}",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(apiserver_request_total{job=\"example-api-server\"}[5m])",
            "legendFormat": "{{verb}} {{resource}"
          }
        ]
      },
      {
        "title": "Request Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(apiserver_request_duration_seconds_bucket{job=\"example-api-server\"}[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(apiserver_request_total{job=\"example-api-server\",code!~\"2..\"}[5m])",
            "legendFormat": "{{code}}"
          }
        ]
      }
    ]
  }
}
```

### **3. Backup и восстановление:**
```bash
# Backup APIService конфигурации
kubectl get apiservice v1alpha1.widgets.example.com -o yaml > apiservice-backup.yaml

# Backup custom resources
kubectl get widgets --all-namespaces -o yaml > widgets-backup.yaml

# Backup extension API server deployment
kubectl get deployment example-api-server -n api-extension-test -o yaml > api-server-deployment-backup.yaml

# Восстановление
kubectl apply -f apiservice-backup.yaml
kubectl apply -f api-server-deployment-backup.yaml
kubectl apply -f widgets-backup.yaml
```

## 🚨 **Troubleshooting Aggregated API:**

### **1. Общие проблемы и решения:**
```bash
# APIService недоступен
kubectl get apiservice v1alpha1.widgets.example.com -o yaml | grep -A 10 conditions

# Проблемы с сертификатами
kubectl describe secret example-api-server-certs -n api-extension-test

# Проблемы с сетью
kubectl get endpoints example-api-server -n api-extension-test
kubectl describe service example-api-server -n api-extension-test

# Проблемы с RBAC
kubectl auth can-i "*" "*" --as=system:serviceaccount:api-extension-test:example-api-server
```

### **2. Диагностический скрипт:**
```bash
#!/bin/bash
# diagnose-aggregated-api.sh

echo "🔍 Diagnosing Aggregated API Server"

diagnose_apiservice() {
    local apiservice=$1
    
    echo "=== APIService Status ==="
    kubectl get apiservice $apiservice -o yaml
    
    echo ""
    echo "=== Service Endpoints ==="
    service_name=$(kubectl get apiservice $apiservice -o jsonpath='{.spec.service.name}')
    service_namespace=$(kubectl get apiservice $apiservice -o jsonpath='{.spec.service.namespace}')
    
    if [ -n "$service_name" ] && [ -n "$service_namespace" ]; then
        kubectl get endpoints $service_name -n $service_namespace
        kubectl describe service $service_name -n $service_namespace
    fi
    
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -n $service_namespace -l app=$service_name
    
    echo ""
    echo "=== Recent Events ==="
    kubectl get events -n $service_namespace --sort-by='.lastTimestamp' | tail -10
}

test_api_functionality() {
    local group=$1
    local version=$2
    local resource=$3
    
    echo "=== Testing API Functionality ==="
    
    # Test API discovery
    echo "--- API Discovery ---"
    kubectl api-resources --api-group=$group
    
    # Test resource operations
    echo "--- Resource Operations ---"
    kubectl get $resource --all-namespaces 2>&1 || echo "Failed to list resources"
    
    # Test resource creation
    echo "--- Resource Creation Test ---"
    cat <<EOF | kubectl apply --dry-run=client -f - 2>&1 || echo "Failed validation"
apiVersion: $group/$version
kind: Widget
metadata:
  name: test-widget
  namespace: default
spec:
  size: medium
  color: blue
EOF
}

check_certificates() {
    local secret_name=$1
    local namespace=$2
    
    echo "=== Certificate Check ==="
    
    if kubectl get secret $secret_name -n $namespace >/dev/null 2>&1; then
        echo "Certificate secret exists"
        
        # Extract and check certificate
        kubectl get secret $secret_name -n $namespace -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | head -20
    else
        echo "Certificate secret not found"
    fi
}

main() {
    local apiservice=${1:-"v1alpha1.widgets.example.com"}
    local group=${2:-"widgets.example.com"}
    local version=${3:-"v1alpha1"}
    local resource=${4:-"widgets"}
    
    diagnose_apiservice $apiservice
    echo ""
    test_api_functionality $group $version $resource
    echo ""
    check_certificates "example-api-server-certs" "api-extension-test"
}

main "$@"
```

## 🎯 **Архитектура Aggregated API в HA кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│              HA Cluster Aggregated API Architecture        │
├─────────────────────────────────────────────────────────────┤
│  Client Layer                                              │
│  ├── kubectl                                               │
│  ├── ArgoCD UI                                             │
│  ├── Grafana Dashboards                                    │
│  └── Custom Applications                                   │
├─────────────────────────────────────────────────────────────┤
│  Load Balancer (DigitalOcean)                             │
│  ├── NGINX Ingress Controller                              │
│  └── TLS Termination                                       │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes API Layer                                      │
│  ├── kube-apiserver (HA)                                   │
│  │   ├── Core API (/api/v1)                               │
│  │   ├── Extensions API (/apis/)                          │
│  │   └── Aggregation Layer                                │
│  ├── APIService Registry                                   │
│  └── Request Routing                                       │
├─────────────────────────────────────────────────────────────┤
│  Extension API Servers                                     │
│  ├── Metrics Server (HA)                                   │
│  ├── Custom Widget API (HA)                                │
│  ├── ArgoCD API Extensions                                 │
│  └── Monitoring API Extensions                             │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                             │
│  ├── etcd (HA cluster)                                     │
│  ├── NFS Shared Storage                                    │
│  └── Persistent Volumes                                    │
├─────────────────────────────────────────────────────────────┤
│  Monitoring & Observability                               │
│  ├── Prometheus (metrics collection)                       │
│  ├── Grafana (visualization)                              │
│  └── AlertManager (alerting)                              │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для Aggregated API:**

### **1. Безопасность:**
- Используйте TLS сертификаты для всех соединений
- Настройте правильные RBAC разрешения
- Валидируйте все входящие запросы
- Используйте admission webhooks для дополнительной валидации

### **2. Производительность:**
- Реализуйте кэширование для часто запрашиваемых данных
- Используйте connection pooling
- Мониторьте латентность и throughput
- Настройте горизонтальное масштабирование

### **3. Надежность:**
- Развертывайте в HA конфигурации (минимум 2 реплики)
- Настройте health checks и readiness probes
- Реализуйте graceful shutdown
- Используйте circuit breakers для внешних зависимостей

### **4. Мониторинг:**
- Экспортируйте метрики в формате Prometheus
- Настройте алерты для критических состояний
- Логируйте все API операции
- Мониторьте использование ресурсов

**Aggregated API Server — это мощный механизм для расширения Kubernetes API с сохранением единого интерфейса и стандартных инструментов!**
