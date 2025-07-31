# 177. Observability в service mesh

## 🎯 **Что такое observability в service mesh?**

**Observability** в service mesh обеспечивает автоматический сбор метрик, distributed tracing, access logging и service topology visualization через интеграцию с Prometheus, Jaeger, Grafana и Kiali без изменения кода приложений для полной видимости микросервисной архитектуры.

## 🏗️ **Основные компоненты observability:**

### **1. Metrics (Метрики)**
- Prometheus для сбора и хранения
- Grafana для визуализации
- Автоматические Istio метрики

### **2. Tracing (Трассировка)**
- Jaeger для distributed tracing
- OpenTelemetry стандарт
- Trace sampling configuration

### **3. Logging (Логирование)**
- Envoy access logs
- Application logs
- Centralized log aggregation

### **4. Topology (Топология)**
- Kiali для service mesh visualization
- Service dependency graphs
- Real-time traffic flow

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Установка observability stack:**
```bash
# Создание namespace для observability
kubectl create namespace observability

# Установка Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=fast-ssd \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# Установка Jaeger
kubectl apply -f - << EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: istio-system
spec:
  strategy: production
  storage:
    type: memory
    options:
      memory:
        max-traces: 100000
  collector:
    maxReplicas: 3
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
  query:
    replicas: 2
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
EOF

# Установка Kiali
helm repo add kiali https://kiali.org/helm-charts
helm install kiali-server kiali/kiali-server \
  --namespace istio-system \
  --set auth.strategy="anonymous" \
  --set external_services.prometheus.url="http://prometheus-kube-prometheus-prometheus.observability:9090"
```

### **2. Настройка Istio telemetry:**
```bash
# Включение tracing
kubectl apply -f - << EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tracing-default
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: jaeger
  - customTags:
      user_id:
        header:
          name: "user-id"
      request_id:
        header:
          name: "x-request-id"
      version:
        literal:
          value: "v1.0"
EOF

# Настройка метрик
kubectl apply -f - << EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: metrics-default
  namespace: istio-system
spec:
  metrics:
  - providers:
    - name: prometheus
  - overrides:
    - match:
        metric: ALL_METRICS
      tagOverrides:
        request_protocol:
          operation: UPSERT
          value: "%{REQUEST_PROTOCOL}"
        response_flags:
          operation: UPSERT
          value: "%{RESPONSE_FLAGS}"
EOF

# Включение access logs
kubectl apply -f - << EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-logs
  namespace: istio-system
spec:
  accessLogging:
  - providers:
    - name: otel
  - format:
      text: |
        [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
        %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT%
        %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%"
        "%REQ(USER-AGENT)%" "%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
EOF
```

### **3. Создание тестового приложения для observability:**
```bash
# Создание demo приложения
kubectl create namespace observability-demo
kubectl label namespace observability-demo istio-injection=enabled

kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: observability-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      version: v1
  template:
    metadata:
      labels:
        app: frontend
        version: v1
    spec:
      containers:
      - name: frontend
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "frontend"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: observability-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
      - name: backend
        image: httpbin/httpbin:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: observability-demo
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: observability-demo
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
EOF

# Ожидание готовности подов
kubectl wait --for=condition=ready pod -l app=frontend -n observability-demo --timeout=300s
kubectl wait --for=condition=ready pod -l app=backend -n observability-demo --timeout=300s
```

### **4. Генерация трафика для observability:**
```bash
# Создание load generator
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
  namespace: observability-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      containers:
      - name: load-generator
        image: curlimages/curl:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          while true; do
            # Успешные запросы
            curl -s -H "user-id: user-$(( RANDOM % 100 ))" \
                 -H "x-request-id: req-$(date +%s)-$(( RANDOM % 1000 ))" \
                 http://frontend/ > /dev/null
            
            # Запросы к backend
            curl -s -H "user-id: user-$(( RANDOM % 100 ))" \
                 http://backend/status/200 > /dev/null
            
            # Некоторые ошибки для демонстрации
            if [ $(( RANDOM % 10 )) -eq 0 ]; then
              curl -s http://backend/status/500 > /dev/null
            fi
            
            # Медленные запросы
            if [ $(( RANDOM % 20 )) -eq 0 ]; then
              curl -s http://backend/delay/3 > /dev/null
            fi
            
            sleep 1
          done
EOF

# Проверка генерации трафика
kubectl logs -f deployment/load-generator -n observability-demo
```

### **5. Проверка метрик в Prometheus:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090 &

# Ключевые Istio метрики для проверки:
echo "Откройте http://localhost:9090 и выполните запросы:"
echo ""
echo "# Общее количество запросов"
echo "sum(rate(istio_requests_total[5m])) by (destination_service_name)"
echo ""
echo "# Success rate"
echo "sum(rate(istio_requests_total{response_code=~\"2.*\"}[5m])) / sum(rate(istio_requests_total[5m]))"
echo ""
echo "# 95th percentile latency"
echo "histogram_quantile(0.95, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service_name))"
echo ""
echo "# Error rate"
echo "sum(rate(istio_requests_total{response_code!~\"2.*\"}[5m])) by (destination_service_name)"
```

## 🔍 **Distributed Tracing анализ:**

### **1. Настройка Jaeger UI:**
```bash
# Port forward к Jaeger
kubectl port-forward svc/jaeger-query -n istio-system 16686:16686 &

echo "Jaeger UI доступен по адресу: http://localhost:16686"

# Скрипт анализа traces
cat > analyze-traces.sh << 'EOF'
#!/bin/bash

JAEGER_URL="http://localhost:16686"
SERVICE_NAME="frontend.observability-demo"

echo "🔍 Анализ distributed tracing"

# Получение traces через API
get_traces() {
    local service=${1:-$SERVICE_NAME}
    local lookback=${2:-"1h"}
    local limit=${3:-100}
    
    curl -s "${JAEGER_URL}/api/traces?service=${service}&lookback=${lookback}&limit=${limit}" | \
        jq '.data[] | {
            traceID: .traceID,
            spans: .spans | length,
            duration: .spans[0].duration,
            operationName: .spans[0].operationName,
            startTime: .spans[0].startTime
        }'
}

# Анализ latency patterns
analyze_latency() {
    echo "⏱️ Анализ latency patterns"
    
    get_traces $SERVICE_NAME "1h" 1000 | jq -r '.duration' | sort -n | awk '
    {
        durations[NR] = $1
        sum += $1
    }
    END {
        count = NR
        if (count == 0) {
            print "Нет данных для анализа"
            exit
        }
        
        avg = sum / count
        
        # Медиана
        if (count % 2 == 1) {
            median = durations[(count + 1) / 2]
        } else {
            median = (durations[count / 2] + durations[count / 2 + 1]) / 2
        }
        
        # Percentiles
        p95_index = int(count * 0.95)
        p95 = durations[p95_index]
        
        p99_index = int(count * 0.99)
        p99 = durations[p99_index]
        
        printf "Traces analyzed: %d\n", count
        printf "Average latency: %.2f μs (%.2f ms)\n", avg, avg/1000
        printf "Median latency: %.2f μs (%.2f ms)\n", median, median/1000
        printf "95th percentile: %.2f μs (%.2f ms)\n", p95, p95/1000
        printf "99th percentile: %.2f μs (%.2f ms)\n", p99, p99/1000
        printf "Min latency: %.2f μs\n", durations[1]
        printf "Max latency: %.2f μs\n", durations[count]
    }'
}

# Поиск медленных traces
find_slow_traces() {
    local threshold=${1:-1000000}  # 1 second
    
    echo "🐌 Медленные traces (> ${threshold}μs):"
    
    get_traces $SERVICE_NAME "1h" 1000 | \
        jq --arg threshold "$threshold" '
        select(.duration > ($threshold | tonumber)) | 
        {
            traceID: .traceID,
            duration: .duration,
            durationMs: (.duration / 1000),
            operationName: .operationName
        }' | \
        jq -s 'sort_by(.duration) | reverse | .[:10]'
}

# Анализ error traces
analyze_errors() {
    echo "❌ Анализ error traces:"
    
    curl -s "${JAEGER_URL}/api/traces?service=${SERVICE_NAME}&tags=%7B%22error%22%3A%22true%22%7D&lookback=1h&limit=100" | \
        jq '.data[] | {
            traceID: .traceID,
            errorSpans: [.spans[] | select(.tags[] | select(.key == "error" and .value == "true"))],
            errorCount: [.spans[] | select(.tags[] | select(.key == "error" and .value == "true"))] | length
        } | select(.errorCount > 0)'
}

case "$1" in
    latency)
        analyze_latency
        ;;
    slow)
        find_slow_traces $2
        ;;
    errors)
        analyze_errors
        ;;
    all)
        analyze_latency
        echo ""
        find_slow_traces 500000
        echo ""
        analyze_errors
        ;;
    *)
        echo "Usage: $0 {latency|slow [threshold]|errors|all}"
        exit 1
        ;;
esac
EOF

chmod +x analyze-traces.sh

# Запуск анализа
./analyze-traces.sh all
```

### **2. Custom метрики и dashboards:**
```bash
# Создание custom Grafana dashboard
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-observability-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  istio-observability.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Istio Service Mesh Observability",
        "tags": ["istio", "observability"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total[5m])) by (destination_service_name)",
                "legendFormat": "{{destination_service_name}}"
              }
            ],
            "yAxes": [
              {
                "label": "Requests/sec"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Success Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total{response_code=~\"2.*\"}[5m])) / sum(rate(istio_requests_total[5m]))",
                "legendFormat": "Success Rate"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "percentunit",
                "min": 0,
                "max": 1,
                "thresholds": {
                  "steps": [
                    {"color": "red", "value": 0},
                    {"color": "yellow", "value": 0.95},
                    {"color": "green", "value": 0.99}
                  ]
                }
              }
            },
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Request Latency Percentiles",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.50, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service_name))",
                "legendFormat": "p50 {{destination_service_name}}"
              },
              {
                "expr": "histogram_quantile(0.95, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service_name))",
                "legendFormat": "p95 {{destination_service_name}}"
              },
              {
                "expr": "histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service_name))",
                "legendFormat": "p99 {{destination_service_name}}"
              }
            ],
            "yAxes": [
              {
                "label": "Latency (ms)"
              }
            ],
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
          },
          {
            "id": 4,
            "title": "Error Rate by Service",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total{response_code!~\"2.*\"}[5m])) by (destination_service_name) / sum(rate(istio_requests_total[5m])) by (destination_service_name)",
                "legendFormat": "{{destination_service_name}}"
              }
            ],
            "yAxes": [
              {
                "label": "Error Rate",
                "unit": "percentunit"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16}
          },
          {
            "id": 5,
            "title": "Request Size Distribution",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.50, sum(rate(istio_request_bytes_bucket[5m])) by (le))",
                "legendFormat": "p50"
              },
              {
                "expr": "histogram_quantile(0.95, sum(rate(istio_request_bytes_bucket[5m])) by (le))",
                "legendFormat": "p95"
              }
            ],
            "yAxes": [
              {
                "label": "Bytes",
                "unit": "bytes"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16}
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
EOF

# Port forward к Grafana
kubectl port-forward svc/prometheus-grafana -n observability 3000:80 &

echo "Grafana доступен по адресу: http://localhost:3000"
echo "Логин: admin"
echo "Пароль: $(kubectl get secret prometheus-grafana -n observability -o jsonpath='{.data.admin-password}' | base64 -d)"
```

## 📊 **Kiali для service topology:**

### **1. Настройка Kiali:**
```bash
# Port forward к Kiali
kubectl port-forward svc/kiali -n istio-system 20001:20001 &

echo "Kiali доступен по адресу: http://localhost:20001"

# Скрипт для получения service graph через API
cat > kiali-analysis.sh << 'EOF'
#!/bin/bash

KIALI_URL="http://localhost:20001"
NAMESPACE="observability-demo"

echo "🌐 Анализ service topology через Kiali"

# Получение service graph
get_service_graph() {
    local namespace=${1:-$NAMESPACE}
    
    echo "📊 Service Graph для namespace: $namespace"
    
    curl -s "${KIALI_URL}/api/namespaces/${namespace}/graph?duration=60s&graphType=service&injectServiceNodes=true" | \
        jq '.elements.nodes[] | {
            id: .data.id,
            service: .data.service,
            version: .data.version,
            traffic: .data.traffic
        }'
}

# Анализ health status
get_health_status() {
    echo "🏥 Health Status сервисов:"
    
    curl -s "${KIALI_URL}/api/namespaces/${NAMESPACE}/health" | \
        jq 'to_entries[] | {
            service: .key,
            health: .value
        }'
}

# Получение workload информации
get_workloads() {
    echo "⚙️ Workload информация:"
    
    curl -s "${KIALI_URL}/api/namespaces/${NAMESPACE}/workloads" | \
        jq '.workloads[] | {
            name: .name,
            type: .type,
            istioSidecar: .istioSidecar,
            health: .health
        }'
}

# Анализ трафика
analyze_traffic() {
    echo "🚦 Анализ трафика:"
    
    curl -s "${KIALI_URL}/api/namespaces/${NAMESPACE}/graph?duration=300s&graphType=service" | \
        jq '.elements.edges[] | {
            source: .data.source,
            target: .data.target,
            traffic: .data.traffic
        }'
}

case "$1" in
    graph)
        get_service_graph $2
        ;;
    health)
        get_health_status
        ;;
    workloads)
        get_workloads
        ;;
    traffic)
        analyze_traffic
        ;;
    all)
        get_service_graph
        echo ""
        get_health_status
        echo ""
        get_workloads
        echo ""
        analyze_traffic
        ;;
    *)
        echo "Usage: $0 {graph [namespace]|health|workloads|traffic|all}"
        exit 1
        ;;
esac
EOF

chmod +x kiali-analysis.sh

# Запуск анализа
./kiali-analysis.sh all
```

## 🚨 **Алертинг и мониторинг:**

### **1. PrometheusRule для Istio алертов:**
```bash
kubectl apply -f - << EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: istio-observability-alerts
  namespace: observability
spec:
  groups:
  - name: istio.observability.rules
    rules:
    - alert: IstioHighRequestLatency
      expr: histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service_name)) > 1000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High request latency detected"
        description: "99th percentile latency is above 1s for {{ \$labels.destination_service_name }}"
    
    - alert: IstioHighErrorRate
      expr: sum(rate(istio_requests_total{response_code!~"2.*"}[5m])) by (destination_service_name) / sum(rate(istio_requests_total[5m])) by (destination_service_name) > 0.05
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is above 5% for {{ \$labels.destination_service_name }}"
    
    - alert: IstioServiceDown
      expr: up{job="istio-mesh"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Istio service is down"
        description: "Istio service {{ \$labels.instance }} is down"
    
    - alert: IstioConfigurationError
      expr: increase(pilot_k8s_cfg_events{type="Warning"}[5m]) > 0
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Istio configuration error"
        description: "Configuration warning detected in Istio control plane"
    
    - alert: IstioSidecarMissing
      expr: kube_deployment_status_replicas{deployment=~".*"} - on(deployment) kube_deployment_status_replicas{deployment=~".*"} * on(deployment) group_left() label_replace(up{job="istio-mesh"}, "deployment", "\$1", "pod", "(.+)-.+-.+") > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Istio sidecar missing"
        description: "Some pods are missing Istio sidecar injection"
EOF
```

### **2. Автоматизированный мониторинг:**
```bash
# Скрипт для автоматического мониторинга
cat > observability-monitor.sh << 'EOF'
#!/bin/bash

echo "🔍 Автоматический мониторинг observability"

# Проверка health всех компонентов
check_observability_health() {
    echo "🏥 Проверка health observability компонентов"
    
    # Prometheus
    echo "Prometheus:"
    kubectl get pods -n observability -l app.kubernetes.io/name=prometheus
    
    # Grafana
    echo "Grafana:"
    kubectl get pods -n observability -l app.kubernetes.io/name=grafana
    
    # Jaeger
    echo "Jaeger:"
    kubectl get pods -n istio-system -l app.kubernetes.io/name=jaeger
    
    # Kiali
    echo "Kiali:"
    kubectl get pods -n istio-system -l app.kubernetes.io/name=kiali
    
    # Istiod
    echo "Istiod:"
    kubectl get pods -n istio-system -l app=istiod
}

# Проверка метрик
check_metrics() {
    echo "📊 Проверка доступности метрик"
    
    # Проверка Istio метрик в Prometheus
    local metrics_count=$(kubectl exec -n observability deployment/prometheus-kube-prometheus-prometheus -- \
        promtool query instant 'count(count by (__name__)({__name__=~"istio_.*"}))' 2>/dev/null | \
        grep -o '[0-9]*' | head -1)
    
    echo "Доступно Istio метрик: ${metrics_count:-0}"
    
    if [[ "${metrics_count:-0}" -gt 50 ]]; then
        echo "✅ Метрики собираются корректно"
    else
        echo "❌ Проблемы со сбором метрик"
    fi
}

# Проверка tracing
check_tracing() {
    echo "🔍 Проверка distributed tracing"
    
    # Проверка наличия traces в Jaeger
    local traces_count=$(curl -s "http://localhost:16686/api/services" 2>/dev/null | \
        jq '.data | length' 2>/dev/null || echo "0")
    
    echo "Сервисов с traces: ${traces_count:-0}"
    
    if [[ "${traces_count:-0}" -gt 0 ]]; then
        echo "✅ Tracing работает корректно"
    else
        echo "❌ Проблемы с tracing"
    fi
}

# Проверка логов
check_logging() {
    echo "📝 Проверка access logs"
    
    # Проверка наличия access logs в sidecar
    local pods_with_logs=$(kubectl get pods -n observability-demo -o jsonpath='{.items[*].metadata.name}' | \
        xargs -n1 -I{} sh -c 'kubectl logs {} -c istio-proxy -n observability-demo --tail=1 2>/dev/null | wc -l' | \
        awk '{sum+=$1} END {print sum}')
    
    echo "Подов с access logs: ${pods_with_logs:-0}"
    
    if [[ "${pods_with_logs:-0}" -gt 0 ]]; then
        echo "✅ Access logging работает"
    else
        echo "❌ Проблемы с access logging"
    fi
}

# Генерация отчета
generate_report() {
    echo "📋 Генерация отчета observability"
    echo "=================================="
    
    check_observability_health
    echo ""
    
    check_metrics
    echo ""
    
    check_tracing
    echo ""
    
    check_logging
    echo ""
    
    echo "Отчет завершен: $(date)"
}

# Основная логика
case "$1" in
    health)
        check_observability_health
        ;;
    metrics)
        check_metrics
        ;;
    tracing)
        check_tracing
        ;;
    logging)
        check_logging
        ;;
    report)
        generate_report
        ;;
    *)
        echo "Usage: $0 {health|metrics|tracing|logging|report}"
        exit 1
        ;;
esac
EOF

chmod +x observability-monitor.sh

# Запуск мониторинга
./observability-monitor.sh report
```

## 🔧 **Cleanup и завершение:**

### **1. Очистка ресурсов:**
```bash
# Остановка port forwards
pkill -f "kubectl port-forward"

# Удаление demo namespace
kubectl delete namespace observability-demo

# Удаление скриптов
rm -f analyze-traces.sh kiali-analysis.sh observability-monitor.sh

# Опционально: удаление observability stack
# kubectl delete namespace observability
# helm uninstall prometheus -n observability
# helm uninstall kiali-server -n istio-system
# kubectl delete jaeger jaeger -n istio-system
```

## 🎯 **Best Practices для observability:**

### **1. Metrics Collection:**
- Настраивать правильный sampling rate для traces (1-10%)
- Использовать cardinality-aware метрики
- Настраивать retention policies для Prometheus
- Мониторить overhead от observability

### **2. Distributed Tracing:**
- Включать trace context propagation в приложениях
- Использовать meaningful span names и tags
- Настраивать adaptive sampling
- Корректно обрабатывать trace headers

### **3. Logging Strategy:**
- Централизовать access logs через ELK/Loki
- Настраивать structured logging
- Использовать correlation IDs
- Балансировать verbosity и performance

### **4. Dashboard Design:**
- Создавать service-specific dashboards
- Использовать SLI/SLO метрики
- Настраивать meaningful alerts
- Регулярно review и optimize dashboards

### **5. Performance Optimization:**
- Мониторить overhead от sidecar
- Оптимизировать telemetry configuration
- Использовать efficient storage backends
- Настраивать proper resource limits

**Observability в service mesh обеспечивает complete visibility в микросервисную архитектуру!**
