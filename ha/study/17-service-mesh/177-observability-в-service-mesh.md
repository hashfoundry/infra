# 177. Observability в service mesh

## 🎯 Вопрос
Как реализовать observability в service mesh?

## 💡 Ответ

Observability в service mesh обеспечивается через автоматический сбор метрик, distributed tracing, access logging и service topology visualization без изменения кода приложений. Istio интегрируется с Prometheus, Jaeger, Grafana и Kiali для полной видимости микросервисной архитектуры.

### 🏗️ Архитектура observability

#### 1. **Схема observability stack**
```
┌─────────────────────────────────────────────────────────────┐
│                Service Mesh Observability                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   Data Collection                       │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Envoy     │  │   Envoy     │  │   Envoy     │     │ │
│  │  │  Sidecar    │  │  Sidecar    │  │  Sidecar    │     │ │
│  │  │             │  │             │  │             │     │ │
│  │  │ • Metrics   │  │ • Metrics   │  │ • Metrics   │     │ │
│  │  │ • Traces    │  │ • Traces    │  │ • Traces    │     │ │
│  │  │ • Logs      │  │ • Logs      │  │ • Logs      │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Data Processing                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │ Prometheus  │  │   Jaeger    │  │    Loki     │     │ │
│  │  │  (Metrics)  │  │  (Traces)   │  │   (Logs)    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Visualization                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Grafana   │  │    Kiali    │  │   Jaeger    │     │ │
│  │  │(Dashboards) │  │ (Topology)  │  │    UI       │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Компоненты observability**
```yaml
# Компоненты observability в service mesh
observability_components:
  metrics:
    prometheus: "Сбор и хранение метрик"
    grafana: "Визуализация метрик и дашборды"
    istio_metrics: "Автоматические метрики сервисов"
    custom_metrics: "Пользовательские метрики приложений"
    
  tracing:
    jaeger: "Distributed tracing система"
    zipkin: "Альтернативная tracing система"
    opentelemetry: "Стандарт для observability"
    trace_sampling: "Настройка sampling rate"
    
  logging:
    envoy_access_logs: "Логи доступа от Envoy"
    application_logs: "Логи приложений"
    loki: "Система агрегации логов"
    fluentd: "Сбор и пересылка логов"
    
  topology:
    kiali: "Визуализация service mesh топологии"
    service_graph: "Граф зависимостей сервисов"
    traffic_flow: "Визуализация потоков трафика"
    health_status: "Статус здоровья сервисов"
```

### 📊 Примеры из нашего кластера

#### Проверка observability компонентов:
```bash
# Проверка Prometheus метрик
kubectl port-forward -n istio-system svc/prometheus 9090:9090
# Открыть http://localhost:9090

# Проверка Grafana дашбордов
kubectl port-forward -n istio-system svc/grafana 3000:3000
# Открыть http://localhost:3000

# Проверка Jaeger tracing
kubectl port-forward -n istio-system svc/jaeger-query 16686:16686
# Открыть http://localhost:16686

# Проверка Kiali topology
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Открыть http://localhost:20001
```

### 📈 Настройка метрик

#### 1. **Prometheus конфигурация**
```yaml
# prometheus-config.yaml

# ServiceMonitor для Istio метрик
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-mesh
  namespace: istio-system
spec:
  selector:
    matchLabels:
      app: istiod
  endpoints:
  - port: http-monitoring
    interval: 15s
    path: /stats/prometheus
---
# ServiceMonitor для Envoy метрик
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-proxy
  namespace: istio-system
spec:
  selector:
    matchLabels:
      app: istio-proxy
  endpoints:
  - port: http-envoy-prom
    interval: 15s
    path: /stats/prometheus
---
# PrometheusRule для Istio алертов
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: istio-alerts
  namespace: istio-system
spec:
  groups:
  - name: istio.rules
    rules:
    - alert: IstioHighRequestLatency
      expr: histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service_name)) > 1000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High request latency detected"
        description: "99th percentile latency is above 1s for {{ $labels.destination_service_name }}"
    
    - alert: IstioHighErrorRate
      expr: rate(istio_requests_total{response_code!~"2.*"}[5m]) / rate(istio_requests_total[5m]) > 0.05
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is above 5% for {{ $labels.destination_service_name }}"
    
    - alert: IstioMeshConfigurationError
      expr: increase(pilot_k8s_cfg_events{type="Warning"}[5m]) > 0
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Istio configuration error"
        description: "Configuration warning detected in Istio control plane"
```

#### 2. **Custom метрики для приложений**
```yaml
# custom-metrics.yaml

# Telemetry v2 конфигурация
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: custom-metrics
  namespace: production
spec:
  metrics:
  - providers:
    - name: prometheus
  - overrides:
    - match:
        metric: ALL_METRICS
      tagOverrides:
        request_id:
          operation: UPSERT
          value: "%{REQUEST_ID}"
        user_id:
          operation: UPSERT
          value: "%{REQUEST_HEADERS['user-id']}"
---
# EnvoyFilter для custom метрик
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: custom-metrics-filter
  namespace: production
spec:
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.wasm
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
          config:
            name: "custom_metrics"
            root_id: "custom_metrics"
            configuration:
              "@type": type.googleapis.com/google.protobuf.StringValue
              value: |
                {
                  "metric_name": "custom_request_total",
                  "labels": ["method", "path", "status_code"],
                  "buckets": [0.5, 1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
                }
```

### 🔍 Distributed Tracing

#### 1. **Jaeger конфигурация**
```yaml
# jaeger-config.yaml

# Jaeger Operator
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-production
  namespace: istio-system
spec:
  strategy: production
  storage:
    type: elasticsearch
    elasticsearch:
      nodeCount: 3
      storage:
        storageClassName: fast-ssd
        size: 100Gi
      redundancyPolicy: SingleRedundancy
  collector:
    maxReplicas: 5
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
  query:
    replicas: 2
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
---
# Istio tracing конфигурация
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      tracing:
        sampling: 1.0
        zipkin:
          address: jaeger-collector.istio-system:9411
    extensionProviders:
    - name: jaeger
      zipkin:
        service: jaeger-collector.istio-system
        port: 9411
---
# Telemetry для tracing
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
```

#### 2. **Скрипт анализа трacing данных**
```bash
#!/bin/bash
# analyze-tracing-data.sh

echo "🔍 Анализ distributed tracing данных"

# Переменные
JAEGER_URL="http://localhost:16686"
SERVICE_NAME="sample-app"
OPERATION_NAME="GET /api/users"

# Получение traces через Jaeger API
get_traces() {
    local service=${1:-$SERVICE_NAME}
    local lookback=${2:-"1h"}
    local limit=${3:-100}
    
    echo "📊 Получение traces для сервиса: $service"
    
    # Запрос к Jaeger API
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
    local service=${1:-$SERVICE_NAME}
    
    echo "⏱️ Анализ latency patterns для $service"
    
    # Получение данных о latency
    local traces=$(get_traces $service "24h" 1000)
    
    # Расчет статистики
    echo "$traces" | jq -r '.duration' | sort -n | awk '
    {
        durations[NR] = $1
        sum += $1
    }
    END {
        count = NR
        avg = sum / count
        
        # Медиана
        if (count % 2 == 1) {
            median = durations[(count + 1) / 2]
        } else {
            median = (durations[count / 2] + durations[count / 2 + 1]) / 2
        }
        
        # 95th percentile
        p95_index = int(count * 0.95)
        p95 = durations[p95_index]
        
        # 99th percentile
        p99_index = int(count * 0.99)
        p99 = durations[p99_index]
        
        printf "Traces analyzed: %d\n", count
        printf "Average latency: %.2f μs\n", avg
        printf "Median latency: %.2f μs\n", median
        printf "95th percentile: %.2f μs\n", p95
        printf "99th percentile: %.2f μs\n", p99
        printf "Min latency: %.2f μs\n", durations[1]
        printf "Max latency: %.2f μs\n", durations[count]
    }'
}

# Поиск медленных traces
find_slow_traces() {
    local service=${1:-$SERVICE_NAME}
    local threshold=${2:-1000000}  # 1 second in microseconds
    
    echo "🐌 Поиск медленных traces (> ${threshold}μs)"
    
    get_traces $service "24h" 1000 | \
        jq --arg threshold "$threshold" '
        select(.duration > ($threshold | tonumber)) | 
        {
            traceID: .traceID,
            duration: .duration,
            operationName: .operationName,
            durationMs: (.duration / 1000)
        }' | \
        jq -s 'sort_by(.duration) | reverse'
}

# Анализ error traces
analyze_errors() {
    local service=${1:-$SERVICE_NAME}
    
    echo "❌ Анализ error traces для $service"
    
    # Поиск traces с ошибками через Jaeger API
    curl -s "${JAEGER_URL}/api/traces?service=${service}&tags=%7B%22error%22%3A%22true%22%7D&lookback=24h&limit=100" | \
        jq '.data[] | {
            traceID: .traceID,
            spans: [.spans[] | select(.tags[] | select(.key == "error" and .value == "true"))],
            errorCount: [.spans[] | select(.tags[] | select(.key == "error" and .value == "true"))] | length
        } | select(.errorCount > 0)'
}

# Анализ service dependencies
analyze_dependencies() {
    local service=${1:-$SERVICE_NAME}
    
    echo "🔗 Анализ зависимостей сервиса $service"
    
    # Получение dependency graph через Jaeger API
    curl -s "${JAEGER_URL}/api/dependencies?endTs=$(date +%s)000&lookback=86400000" | \
        jq --arg service "$service" '
        .data[] | 
        select(.parent == $service or .child == $service) |
        {
            parent: .parent,
            child: .child,
            callCount: .callCount
        }'
}

# Генерация отчета
generate_report() {
    local service=${1:-$SERVICE_NAME}
    
    echo "📋 Генерация отчета по tracing для $service"
    echo "=================================================="
    
    analyze_latency $service
    echo ""
    
    echo "Медленные traces:"
    find_slow_traces $service 500000  # 500ms threshold
    echo ""
    
    echo "Error traces:"
    analyze_errors $service
    echo ""
    
    echo "Service dependencies:"
    analyze_dependencies $service
}

# Основная логика
case "$1" in
    traces)
        get_traces $2 $3 $4
        ;;
    latency)
        analyze_latency $2
        ;;
    slow)
        find_slow_traces $2 $3
        ;;
    errors)
        analyze_errors $2
        ;;
    dependencies)
        analyze_dependencies $2
        ;;
    report)
        generate_report $2
        ;;
    *)
        echo "Использование: $0 {traces|latency|slow|errors|dependencies|report} [service] [params...]"
        exit 1
        ;;
esac
```

### 📊 Grafana дашборды

#### 1. **Service Mesh дашборд**
```json
{
  "dashboard": {
    "title": "Istio Service Mesh Dashboard",
    "tags": ["istio", "service-mesh"],
    "panels": [
      {
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
        ]
      },
      {
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
            "max": 1
          }
        }
      },
      {
        "title": "Request Latency",
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
        ]
      },
      {
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
        ]
      },
      {
        "title": "TCP Connection Metrics",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(istio_tcp_connections_opened_total) by (destination_service_name)",
            "legendFormat": "Opened {{destination_service_name}}"
          },
          {
            "expr": "sum(istio_tcp_connections_closed_total) by (destination_service_name)",
            "legendFormat": "Closed {{destination_service_name}}"
          }
        ]
      },
      {
        "title": "Workload CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{container!=\"POD\",container!=\"istio-proxy\"}[5m])) by (pod)",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Workload Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(container_memory_working_set_bytes{container!=\"POD\",container!=\"istio-proxy\"}) by (pod)",
            "legendFormat": "{{pod}}"
          }
        ],
        "yAxes": [
          {
            "label": "Memory",
            "unit": "bytes"
          }
        ]
      },
      {
        "title": "Istio Proxy Resource Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{container=\"istio-proxy\"}[5m])) by (pod)",
            "legendFormat": "CPU {{pod}}"
          },
          {
            "expr": "sum(container_memory_working_set_bytes{container=\"istio-proxy\"}) by (pod)",
            "legendFormat": "Memory {{pod}}"
          }
        ]
      }
    ]
  }
}
```

### 🔧 Автоматизация observability

#### 1. **Скрипт настройки observability stack**
```bash
#!/bin/bash
# setup-observability.sh

echo "🔧 Настройка observability stack для Service Mesh"

# Установка Prometheus
install_prometheus() {
    echo "📊 Установка Prometheus"
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.retention=30d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=fast-ssd \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi
    
    echo "✅ Prometheus установлен"
}

# Установка Jaeger
install_jaeger() {
    echo "🔍 Установка Jaeger"
    
    kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.41.0/jaeger-operator.yaml
    
    # Ожидание готовности operator
    kubectl wait --for=condition=available deployment/jaeger-operator -n observability --timeout=300s
    
    # Применение Jaeger instance
    kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: istio-system
spec:
  strategy: production
  storage:
    type: elasticsearch
    elasticsearch:
      nodeCount: 3
      storage:
        storageClassName: fast-ssd
        size: 50Gi
EOF
    
    echo "✅ Jaeger установлен"
}

# Установка Kiali
install_kiali() {
    echo "🌐 Установка Kiali"
    
    helm repo add kiali https://kiali.org/helm-charts
    helm repo update
    
    helm install kiali-server kiali/kiali-server \
        --namespace istio-system \
        --set auth.strategy="anonymous" \
        --set external_services.prometheus.url="http://prometheus-kube-prometheus-prometheus.monitoring:9090" \
        --set external_services.grafana.url="http://prometheus-grafana.monitoring:80" \
        --set external_services.jaeger.url="http://jaeger-query.istio-system:16686"
    
    echo "✅ Kiali установлен"
}

# Настройка Istio для observability
configure_istio_observability() {
    echo "⚙️ Настройка Istio для observability"
    
    # Включение tracing
    kubectl apply -f - <<EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tracing-default
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: jaeger
EOF
    
    # Настройка метрик
    kubectl apply -f - <<EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: metrics-default
  namespace: istio-system
spec:
  metrics:
  - providers:
    - name: prometheus
EOF
    
    # Настройка access logs
    kubectl apply -f - <<EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-logs
  namespace: istio-system
spec:
  accessLogging:
  - providers:
    - name: otel
EOF
    
    echo "✅ Istio observability настроен"
}

# Создание ServiceMonitors
create_service_monitors() {
    echo "📈 Создание ServiceMonitors"
    
    # ServiceMonitor для Istio control plane
    kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-system
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - istio-system
  selector:
    matchLabels:
      app: istiod
  endpoints:
  - port: http-monitoring
    interval: 15s
    path: /stats/prometheus
EOF
    
    # ServiceMonitor для Envoy sidecars
    kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-proxy
  namespace: monitoring
spec:
  namespaceSelector:
    any: true
  selector:
    matchLabels:
      app: istio-proxy
  endpoints:
  - port: http-envoy-prom
    interval: 15s
    path: /stats/prometheus
EOF
    
    echo "✅ ServiceMonitors созданы"
}

# Импорт Grafana дашбордов
import_grafana_dashboards() {
    echo "📊 Импорт Grafana дашбордов"
    
    # Получение Grafana admin пароля
    local grafana_password=$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
    
    # Импорт официальных Istio дашбордов
    local dashboards=(
        "7639"  # Istio Control Plane Dashboard
        "7636"  # Istio Service Dashboard
        "7630"  # Istio Workload Dashboard
        "7645"  # Istio Mesh Dashboard
    )
    
    for dashboard_id in "${dashboards[@]}"; do
        echo "Импорт дашборда $dashboard_id"
        
        # Скачивание дашборда
        curl -s "https://grafana.com/api/dashboards/${dashboard_id}/revisions/latest/download" > "/tmp/dashboard-${dashboard_id}.json"
        
        # Импорт в Grafana
        kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
        local port_forward_pid=$!
        
        sleep 5
        
        curl -X POST \
            -H "Content-Type: application/json" \
            -d @/tmp/dashboard-${dashboard_id}.json \
            http://admin:${grafana_password}@localhost:3000/api/dashboards/db
        
        kill $port_forward_pid
        rm "/tmp/dashboard-${dashboard_id}.json"
    done
    
    echo "✅ Grafana дашборды импортированы"
}

# Проверка статуса
check_status() {
    echo "🔍 Проверка статуса observability компонентов"
    
    echo "Prometheus:"
    kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
    
    echo "Jaeger:"
    kubectl get pods -n istio-system -l app.kubernetes.io/name=jaeger
    
    echo "Kiali:"
    kubectl get pods -n istio-system -l app.kubernetes.io/name=kiali
    
    echo "Grafana:"
    kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
}

# Основная логика
case "$1" in
    prometheus)
        install_prometheus
        ;;
    jaeger)
        install_jaeger
        ;;
    kiali)
        install_kiali
        ;;
    configure)
        configure_istio_observability
        ;;
    monitors)
        create_service_monitors
        ;;
    dashboards)
        import_grafana_dashboards
        ;;
    status)
        check_status
        ;;
