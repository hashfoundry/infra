# 182. Как реализовать custom metrics для HPA?

## 🎯 Вопрос
Как реализовать custom metrics для HPA?

## 💡 Ответ

Custom metrics для HPA позволяют масштабировать приложения на основе специфических метрик приложения или внешних систем, а не только CPU/Memory. Это достигается через Metrics API, Custom Metrics API и External Metrics API, которые предоставляют гибкую архитектуру для интеграции любых источников метрик с Kubernetes HPA.

### 🏗️ Архитектура Custom Metrics

#### 1. **Схема Custom Metrics Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│              Custom Metrics Architecture                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    HPA Controller                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Resource  │    │   Custom    │    │  External   │ │ │
│  │  │   Metrics   │    │   Metrics   │    │   Metrics   │ │ │
│  │  │    API      │    │     API     │    │     API     │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│           │                     │                     │      │
│           ▼                     ▼                     ▼      │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Metrics Adapters                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Prometheus  │    │   Custom    │    │  External   │ │ │
│  │  │  Adapter    │    │  Adapter    │    │  Adapter    │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│           │                     │                     │      │
│           ▼                     ▼                     ▼      │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Metrics Sources                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Prometheus  │    │ Application │    │   Cloud     │ │ │
│  │  │   Server    │    │   Metrics   │    │  Provider   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Grafana   │    │   Custom    │    │    SaaS     │ │ │
│  │  │   Metrics   │    │  Exporters  │    │  Services   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Типы Metrics APIs**
```yaml
# Типы Metrics APIs для HPA
metrics_apis:
  resource_metrics:
    description: "Стандартные ресурсные метрики (CPU, Memory)"
    source: "metrics-server"
    examples:
      - "cpu utilization"
      - "memory utilization"
    
  custom_metrics:
    description: "Метрики из кластера (pods, objects)"
    source: "custom metrics adapter"
    examples:
      - "requests per second"
      - "queue length"
      - "database connections"
    
  external_metrics:
    description: "Метрики из внешних систем"
    source: "external metrics adapter"
    examples:
      - "cloud provider metrics"
      - "SaaS service metrics"
      - "external monitoring systems"

# Конфигурация HPA с разными типами метрик
hpa_configuration:
  resource_based:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    spec:
      metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 70
  
  custom_metrics:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    spec:
      metrics:
      - type: Pods
        pods:
          metric:
            name: requests_per_second
          target:
            type: AverageValue
            averageValue: "100"
  
  external_metrics:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    spec:
      metrics:
      - type: External
        external:
          metric:
            name: queue_messages_ready
            selector:
              matchLabels:
                queue: worker_tasks
          target:
            type: AverageValue
            averageValue: "30"
```

### 📊 Примеры из нашего кластера

#### Проверка metrics APIs:
```bash
# Проверка доступных metrics APIs
kubectl api-versions | grep metrics

# Проверка metrics-server
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Проверка custom metrics API
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"

# Проверка external metrics API
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1"
```

### 🔧 Реализация Custom Metrics

#### 1. **Prometheus Adapter для Custom Metrics**
```yaml
# prometheus-adapter-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: adapter-config
  namespace: monitoring
data:
  config.yaml: |
    rules:
    # HTTP requests per second
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
      seriesFilters: []
      resources:
        overrides:
          namespace:
            resource: namespace
          pod:
            resource: pod
      name:
        matches: "^http_requests_total"
        as: "requests_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
    
    # Queue length metric
    - seriesQuery: 'queue_length{namespace!="",pod!=""}'
      seriesFilters: []
      resources:
        overrides:
          namespace:
            resource: namespace
          pod:
            resource: pod
      name:
        matches: "^queue_length"
        as: "queue_length"
      metricsQuery: 'avg(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'
    
    # Database connections
    - seriesQuery: 'db_connections_active{namespace!="",pod!=""}'
      seriesFilters: []
      resources:
        overrides:
          namespace:
            resource: namespace
          pod:
            resource: pod
      name:
        matches: "^db_connections_active"
        as: "database_connections"
      metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'
    
    # Custom business metric
    - seriesQuery: 'business_transactions_per_minute{namespace!="",pod!=""}'
      seriesFilters: []
      resources:
        overrides:
          namespace:
            resource: namespace
          pod:
            resource: pod
      name:
        matches: "^business_transactions_per_minute"
        as: "business_transactions"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)'

---
# Prometheus Adapter Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-adapter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-adapter
  template:
    metadata:
      labels:
        app: prometheus-adapter
    spec:
      serviceAccountName: prometheus-adapter
      containers:
      - name: prometheus-adapter
        image: k8s.gcr.io/prometheus-adapter/prometheus-adapter:v0.11.0
        args:
        - --cert-dir=/var/run/serving-cert
        - --config=/etc/adapter/config.yaml
        - --logtostderr=true
        - --prometheus-url=http://prometheus.monitoring.svc:9090/
        - --metrics-relist-interval=1m
        - --v=4
        - --secure-port=6443
        ports:
        - containerPort: 6443
          name: https
        volumeMounts:
        - name: config
          mountPath: /etc/adapter/
          readOnly: true
        - name: tmp-vol
          mountPath: /tmp
        - name: serving-cert
          mountPath: /var/run/serving-cert
          readOnly: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
      volumes:
      - name: config
        configMap:
          name: adapter-config
      - name: tmp-vol
        emptyDir: {}
      - name: serving-cert
        secret:
          secretName: prometheus-adapter-certs

---
# Service для Prometheus Adapter
apiVersion: v1
kind: Service
metadata:
  name: prometheus-adapter
  namespace: monitoring
spec:
  ports:
  - name: https
    port: 443
    targetPort: 6443
  selector:
    app: prometheus-adapter

---
# APIService для Custom Metrics
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1beta1.custom.metrics.k8s.io
spec:
  service:
    name: prometheus-adapter
    namespace: monitoring
  group: custom.metrics.k8s.io
  version: v1beta1
  insecureSkipTLSVerify: true
  groupPriorityMinimum: 100
  versionPriority: 100
```

#### 2. **Custom Application Metrics**
```go
// custom-metrics-exporter.go
package main

import (
    "fmt"
    "log"
    "math/rand"
    "net/http"
    "time"
    
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

// Custom metrics для приложения
var (
    // HTTP requests per second
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    // Queue length
    queueLength = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "queue_length",
            Help: "Current queue length",
        },
        []string{"queue_name"},
    )
    
    // Database connections
    dbConnectionsActive = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "db_connections_active",
            Help: "Number of active database connections",
        },
        []string{"database"},
    )
    
    // Business transactions
    businessTransactions = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "business_transactions_per_minute",
            Help: "Business transactions processed per minute",
        },
        []string{"transaction_type"},
    )
    
    // Response time histogram
    responseTime = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
    
    // Custom resource utilization
    customResourceUtilization = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "custom_resource_utilization",
            Help: "Custom resource utilization percentage",
        },
        []string{"resource_type"},
    )
)

func init() {
    // Регистрация метрик
    prometheus.MustRegister(httpRequestsTotal)
    prometheus.MustRegister(queueLength)
    prometheus.MustRegister(dbConnectionsActive)
    prometheus.MustRegister(businessTransactions)
    prometheus.MustRegister(responseTime)
    prometheus.MustRegister(customResourceUtilization)
}

// Симуляция метрик приложения
func simulateMetrics() {
    ticker := time.NewTicker(5 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            // Симуляция HTTP requests
            methods := []string{"GET", "POST", "PUT", "DELETE"}
            endpoints := []string{"/api/users", "/api/orders", "/api/products"}
            statuses := []string{"200", "404", "500"}
            
            for i := 0; i < rand.Intn(10)+1; i++ {
                method := methods[rand.Intn(len(methods))]
                endpoint := endpoints[rand.Intn(len(endpoints))]
                status := statuses[rand.Intn(len(statuses))]
                
                httpRequestsTotal.WithLabelValues(method, endpoint, status).Inc()
                
                // Response time
                duration := rand.Float64() * 2.0 // 0-2 seconds
                responseTime.WithLabelValues(method, endpoint).Observe(duration)
            }
            
            // Симуляция queue length
            queueLength.WithLabelValues("worker_queue").Set(float64(rand.Intn(100)))
            queueLength.WithLabelValues("email_queue").Set(float64(rand.Intn(50)))
            
            // Симуляция database connections
            dbConnectionsActive.WithLabelValues("postgres").Set(float64(rand.Intn(20) + 5))
            dbConnectionsActive.WithLabelValues("redis").Set(float64(rand.Intn(10) + 2))
            
            // Симуляция business transactions
            transactionTypes := []string{"payment", "order", "user_registration"}
            for _, txType := range transactionTypes {
                for i := 0; i < rand.Intn(5)+1; i++ {
                    businessTransactions.WithLabelValues(txType).Inc()
                }
            }
            
            // Симуляция custom resource utilization
            customResourceUtilization.WithLabelValues("gpu").Set(float64(rand.Intn(100)))
            customResourceUtilization.WithLabelValues("memory_cache").Set(float64(rand.Intn(100)))
        }
    }
}

// HTTP handler для health check
func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    fmt.Fprintf(w, "OK")
}

// HTTP handler для бизнес-логики
func businessHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    // Симуляция обработки запроса
    time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)
    
    // Запись метрик
    httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
    responseTime.WithLabelValues(r.Method, r.URL.Path).Observe(time.Since(start).Seconds())
    
    w.WriteHeader(http.StatusOK)
    fmt.Fprintf(w, "Business logic processed")
}

func main() {
    // Запуск симуляции метрик
    go simulateMetrics()
    
    // HTTP handlers
    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/api/business", businessHandler)
    http.Handle("/metrics", promhttp.Handler())
    
    log.Println("Starting custom metrics exporter on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

#### 3. **HPA с Custom Metrics**
```yaml
# hpa-custom-metrics.yaml

# HPA на основе HTTP requests per second
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa-rps
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "50"  # 50 RPS per pod
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60

---
# HPA на основе queue length
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: worker-hpa-queue
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: worker
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: queue_length
      target:
        type: AverageValue
        averageValue: "10"  # 10 messages per pod
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 600
      policies:
      - type: Pods
        value: 1
        periodSeconds: 180

---
# HPA с комбинированными метриками
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa-combined
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  minReplicas: 3
  maxReplicas: 50
  metrics:
  # CPU utilization
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Memory utilization
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  # Custom metric: requests per second
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  # Custom metric: database connections
  - type: Pods
    pods:
      metric:
        name: database_connections
      target:
        type: AverageValue
        averageValue: "5"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 5
        periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60

---
# External metrics HPA (например, для SQS queue)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sqs-worker-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sqs-worker
  minReplicas: 1
  maxReplicas: 20
  metrics:
  - type: External
    external:
      metric:
        name: sqs_messages_visible
        selector:
          matchLabels:
            queue: "worker-tasks"
      target:
        type: AverageValue
        averageValue: "5"  # 5 messages per pod
```

### 🔧 External Metrics Adapter

#### 1. **CloudWatch Metrics Adapter**
```yaml
# cloudwatch-adapter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudwatch-adapter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudwatch-adapter
  template:
    metadata:
      labels:
        app: cloudwatch-adapter
    spec:
      serviceAccountName: cloudwatch-adapter
      containers:
      - name: cloudwatch-adapter
        image: chankh/k8s-cloudwatch-adapter:latest
        env:
        - name: AWS_REGION
          value: "us-west-2"
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: access-key-id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: secret-access-key
        ports:
        - containerPort: 6443
          name: https
        volumeMounts:
        - name: tmp-vol
          mountPath: /tmp
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
      volumes:
      - name: tmp-vol
        emptyDir: {}

---
# Service для CloudWatch Adapter
apiVersion: v1
kind: Service
metadata:
  name: cloudwatch-adapter
  namespace: monitoring
spec:
  ports:
  - name: https
    port: 443
    targetPort: 6443
  selector:
    app: cloudwatch-adapter

---
# APIService для External Metrics
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1beta1.external.metrics.k8s.io
spec:
  service:
    name: cloudwatch-adapter
    namespace: monitoring
  group: external.metrics.k8s.io
  version: v1beta1
  insecureSkipTLSVerify: true
  groupPriorityMinimum: 100
  versionPriority: 100
```

### 📊 Мониторинг и отладка HPA

#### 1. **HPA Monitoring Script**
```bash
#!/bin/bash
# hpa-monitoring.sh

echo "📊 Мониторинг HPA с Custom Metrics"

# Проверка HPA статуса
check_hpa_status() {
    echo "=== HPA Status ==="
    
    # Список всех HPA
    kubectl get hpa --all-namespaces
    
    # Детальная информация о HPA
    kubectl describe hpa --all-namespaces
    
    # HPA events
    kubectl get events --all-namespaces --field-selector reason=SuccessfulRescale
    kubectl get events --all-namespaces --field-selector reason=FailedGetScale
}

# Проверка custom metrics
check_custom_metrics() {
    echo "=== Custom Metrics ==="
    
    # Доступные custom metrics
    kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .
    
    # Конкретные метрики
    kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/production/pods/*/requests_per_second" | jq .
    kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/production/pods/*/queue_length" | jq .
}

# Проверка external metrics
check_external_metrics() {
    echo "=== External Metrics ==="
    
    # Доступные external metrics
    kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .
    
    # Конкретные external метрики
    kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/production/sqs_messages_visible" | jq .
}

# Отладка конкретного HPA
debug_hpa() {
    local hpa_name=$1
    local namespace=$2
    
    echo "=== Debugging HPA: $namespace/$hpa_name ==="
    
    # Детальная информация
    kubectl describe hpa $hpa_name -n $namespace
    
    # События HPA
    kubectl get events -n $namespace --field-selector involvedObject.name=$hpa_name
    
    # Текущие метрики
    kubectl get hpa $hpa_name -n $namespace -o yaml | grep -A 20 currentMetrics
    
    # Target deployment
    local target=$(kubectl get hpa $hpa_name -n $namespace -o jsonpath='{.spec.scaleTargetRef.name}')
    kubectl describe deployment $target -n $namespace
    
    # Pods metrics
    kubectl top pods -n $namespace -l app=$target
}

# Тестирование HPA
test_hpa_scaling() {
    local hpa_name=$1
    local namespace=$2
    
    echo "=== Testing HPA Scaling: $namespace/$hpa_name ==="
    
    # Получение target deployment
    local target=$(kubectl get hpa $hpa_name -n $namespace -o jsonpath='{.spec.scaleTargetRef.name}')
    
    echo "Текущее количество реплик:"
    kubectl get deployment $target -n $namespace -o jsonpath='{.spec.replicas}'
    
    echo "Генерация нагрузки..."
    # Здесь можно добавить команды для генерации нагрузки
    
    echo "Мониторинг изменений в течение 5 минут..."
    for i in {1..30}; do
        echo "Минута $i:"
        kubectl get hpa $hpa_name -n $namespace
        kubectl get deployment $target -n $namespace -o jsonpath='{.spec.replicas}'
        sleep 10
    done
}

# Анализ производительности HPA
analyze_hpa_performance() {
    echo "=== HPA Performance Analysis ==="
    
    # HPA controller metrics
    kubectl get --raw /metrics | grep hpa_controller
    
    # Время принятия решений
    kubectl get --raw /metrics | grep hpa_controller_reconcile_duration
    
    # Ошибки HPA
    kubectl get --raw /metrics | grep hpa_controller_reconcile_errors_total
}

case "$1" in
    status)
        check_hpa_status
        ;;
    custom)
        check_custom_metrics
        ;;
    external)
        check_external_metrics
        ;;
    debug)
        debug_hpa $2 $3
        ;;
    test)
        test_hpa_scaling $2 $3
        ;;
    performance)
        analyze_hpa_performance
        ;;
    all)
        check_hpa_status
        check_custom_metrics
        check_external_metrics
        analyze_hpa_performance
        ;;
    *)
        echo "Использование: $0 {status|custom|external|debug|test|performance|all} [hpa-name] [namespace]"
        exit 1
        ;;
esac
```

### 🔧 Развертывание Custom Metrics Stack

#### 1. **Deployment Script**
```bash
#!/bin/bash
# deploy-custom-metrics.sh

echo "🚀 Развертывание Custom Metrics Stack"

# Установка Prometheus Adapter
deploy_prometheus_adapter() {
    echo "📊 Установка Prometheus Adapter"
    
    # Создание namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Создание ServiceAccount и RBAC
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-adapter
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-adapter
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/stats", "namespaces", "pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-adapter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-adapter
subjects:
- kind: ServiceAccount
  name: prometheus-adapter
  namespace: monitoring
EOF
    
    # Создание конфигурации
    kubectl apply -f prometheus-adapter-config.yaml
    
    echo "✅ Prometheus Adapter установлен"
}

# Развертывание sample приложения с метриками
deploy_sample_app() {
    echo "🔧 Развертывание sample приложения"
    
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-metrics-app
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: custom-metrics-app
  template:
    metadata:
      labels:
        app: custom-metrics-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: custom-metrics-exporter:latest
        ports:
        - containerPort: 8080
          name: metrics
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: PORT
          value: "8080"
