# 176. Управление трафиком в service mesh

## 🎯 Вопрос
Как управлять трафиком в service mesh?

## 💡 Ответ

Управление трафиком в service mesh осуществляется через VirtualService, DestinationRule, Gateway и ServiceEntry ресурсы, которые обеспечивают intelligent routing, load balancing, circuit breaking, retry logic, canary deployments, A/B testing и fault injection без изменения кода приложений.

### 🏗️ Архитектура управления трафиком

#### 1. **Схема traffic management**
```
┌─────────────────────────────────────────────────────────────┐
│                Traffic Management in Service Mesh          │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Gateway                              │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Ingress   │  │    Egress   │  │   Internal  │     │ │
│  │  │   Gateway   │  │   Gateway   │  │   Gateway   │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                VirtualService                          │ │
│  │  • Routing Rules                                       │ │
│  │  • Traffic Splitting                                   │ │
│  │  • Header-based Routing                                │ │
│  │  • Fault Injection                                     │ │
│  │  • Timeout & Retry                                     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               DestinationRule                          │ │
│  │  • Load Balancing                                      │ │
│  │  • Circuit Breaking                                    │ │
│  │  • Connection Pooling                                  │ │
│  │  • TLS Settings                                        │ │
│  │  • Subset Definitions                                  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Service Endpoints                       │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │  Service A  │  │  Service B  │  │  Service C  │     │ │
│  │  │     v1      │  │     v1      │  │     v1      │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │  Service A  │  │  Service B  │  │  Service C  │     │ │
│  │  │     v2      │  │     v2      │  │     v2      │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Компоненты traffic management**
```yaml
# Компоненты управления трафиком
traffic_management_components:
  gateway:
    ingress_gateway: "Входящий трафик из внешних источников"
    egress_gateway: "Исходящий трафик к внешним сервисам"
    internal_gateway: "Внутренний трафик между namespace"
    
  virtual_service:
    routing_rules: "Правила маршрутизации запросов"
    traffic_splitting: "Разделение трафика между версиями"
    header_routing: "Маршрутизация по заголовкам"
    fault_injection: "Внедрение ошибок для тестирования"
    
  destination_rule:
    load_balancing: "Алгоритмы балансировки нагрузки"
    circuit_breaking: "Защита от каскадных сбоев"
    connection_pooling: "Управление соединениями"
    subset_definition: "Определение подмножеств сервисов"
    
  service_entry:
    external_services: "Регистрация внешних сервисов"
    mesh_expansion: "Расширение mesh на внешние сервисы"
    service_discovery: "Обнаружение сервисов"
```

### 📊 Примеры из нашего кластера

#### Проверка traffic management конфигурации:
```bash
# Проверка VirtualService
kubectl get virtualservice --all-namespaces
kubectl describe virtualservice <vs-name> -n <namespace>

# Проверка DestinationRule
kubectl get destinationrule --all-namespaces
kubectl describe destinationrule <dr-name> -n <namespace>

# Проверка Gateway
kubectl get gateway --all-namespaces
kubectl describe gateway <gateway-name> -n <namespace>

# Анализ трафика через Envoy
istioctl proxy-config route <pod-name> -n <namespace>
istioctl proxy-config cluster <pod-name> -n <namespace>
```

### 🚦 VirtualService конфигурации

#### 1. **Базовые routing правила**
```yaml
# basic-virtual-service.yaml

# Простая маршрутизация
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: sample-app-routing
  namespace: production
spec:
  hosts:
  - sample-app
  http:
  - match:
    - uri:
        prefix: "/api/v1"
    route:
    - destination:
        host: sample-app
        subset: v1
  - match:
    - uri:
        prefix: "/api/v2"
    route:
    - destination:
        host: sample-app
        subset: v2
  - route:
    - destination:
        host: sample-app
        subset: v1
---
# Header-based routing
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: header-based-routing
  namespace: production
spec:
  hosts:
  - sample-app
  http:
  - match:
    - headers:
        user-type:
          exact: premium
    route:
    - destination:
        host: sample-app
        subset: premium
  - match:
    - headers:
        version:
          regex: "v2.*"
    route:
    - destination:
        host: sample-app
        subset: v2
  - route:
    - destination:
        host: sample-app
        subset: v1
---
# Canary deployment с weight-based routing
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary-deployment
  namespace: production
spec:
  hosts:
  - sample-app
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: sample-app
        subset: canary
  - route:
    - destination:
        host: sample-app
        subset: stable
      weight: 90
    - destination:
        host: sample-app
        subset: canary
      weight: 10
```

#### 2. **Продвинутые traffic management функции**
```yaml
# advanced-virtual-service.yaml

# Fault injection и timeout
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: fault-injection-demo
  namespace: production
spec:
  hosts:
  - sample-app
  http:
  - match:
    - headers:
        test-fault:
          exact: "true"
    fault:
      delay:
        percentage:
          value: 50
        fixedDelay: 5s
      abort:
        percentage:
          value: 10
        httpStatus: 503
    route:
    - destination:
        host: sample-app
        subset: v1
  - route:
    - destination:
        host: sample-app
        subset: v1
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure,refused-stream
---
# Mirror traffic для testing
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: traffic-mirroring
  namespace: production
spec:
  hosts:
  - sample-app
  http:
  - route:
    - destination:
        host: sample-app
        subset: v1
    mirror:
      host: sample-app
      subset: v2
    mirrorPercentage:
      value: 10
---
# Redirect и rewrite
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: redirect-rewrite
  namespace: production
spec:
  hosts:
  - sample-app
  http:
  - match:
    - uri:
        prefix: "/old-api"
    redirect:
      uri: "/new-api"
      redirectCode: 301
  - match:
    - uri:
        prefix: "/api/v1"
    rewrite:
      uri: "/api/v2"
    route:
    - destination:
        host: sample-app
        subset: v2
```

### ⚖️ DestinationRule конфигурации

#### 1. **Load balancing и connection pooling**
```yaml
# destination-rule-configs.yaml

# Различные алгоритмы load balancing
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: load-balancing-demo
  namespace: production
spec:
  host: sample-app
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN  # ROUND_ROBIN, LEAST_CONN, RANDOM, PASSTHROUGH
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 30s
        keepAlive:
          time: 7200s
          interval: 75s
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 10
        maxRetries: 3
        idleTimeout: 90s
        h2UpgradePolicy: UPGRADE
  subsets:
  - name: v1
    labels:
      version: v1
    trafficPolicy:
      loadBalancer:
        simple: ROUND_ROBIN
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer:
        simple: LEAST_CONN
---
# Circuit breaker конфигурация
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: circuit-breaker
  namespace: production
spec:
  host: sample-app
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 50
      http:
        http1MaxPendingRequests: 25
        maxRequestsPerConnection: 5
    circuitBreaker:
      consecutiveGatewayErrors: 3
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 30
      splitExternalLocalOriginErrors: false
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      circuitBreaker:
        consecutiveGatewayErrors: 2
        baseEjectionTime: 60s
```

### 🌐 Gateway конфигурации

#### 1. **Ingress и Egress Gateway**
```yaml
# gateway-configs.yaml

# Ingress Gateway
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: sample-app-gateway
  namespace: production
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - sample-app.hashfoundry.com
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: sample-app-tls
    hosts:
    - sample-app.hashfoundry.com
---
# VirtualService для Gateway
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: sample-app-gateway-vs
  namespace: production
spec:
  hosts:
  - sample-app.hashfoundry.com
  gateways:
  - sample-app-gateway
  http:
  - match:
    - uri:
        prefix: "/api"
    route:
    - destination:
        host: sample-app
        port:
          number: 8080
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: sample-app-frontend
        port:
          number: 80
---
# Egress Gateway
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: external-api-gateway
  namespace: production
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - api.external-service.com
    tls:
      mode: PASSTHROUGH
---
# ServiceEntry для external сервиса
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-api
  namespace: production
spec:
  hosts:
  - api.external-service.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
---
# VirtualService для Egress
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: external-api-vs
  namespace: production
spec:
  hosts:
  - api.external-service.com
  gateways:
  - external-api-gateway
  - mesh
  tls:
  - match:
    - port: 443
      sniHosts:
      - api.external-service.com
    route:
    - destination:
        host: api.external-service.com
        port:
          number: 443
```

### 🔧 Скрипт управления трафиком

#### 1. **Автоматизация traffic management**
```bash
#!/bin/bash
# traffic-management-automation.sh

echo "🚦 Автоматизация управления трафиком в Service Mesh"

# Переменные
NAMESPACE="production"
SERVICE_NAME="sample-app"
CANARY_VERSION="v2"
STABLE_VERSION="v1"

# Canary deployment
deploy_canary() {
    local canary_weight=${1:-10}
    
    echo "🚀 Развертывание canary с весом $canary_weight%"
    
    # Создание VirtualService для canary
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}-canary
  namespace: ${NAMESPACE}
spec:
  hosts:
  - ${SERVICE_NAME}
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: ${SERVICE_NAME}
        subset: ${CANARY_VERSION}
  - route:
    - destination:
        host: ${SERVICE_NAME}
        subset: ${STABLE_VERSION}
      weight: $((100 - canary_weight))
    - destination:
        host: ${SERVICE_NAME}
        subset: ${CANARY_VERSION}
      weight: ${canary_weight}
EOF
    
    echo "✅ Canary deployment с весом $canary_weight% развернут"
}

# Мониторинг canary метрик
monitor_canary() {
    echo "📊 Мониторинг canary метрик"
    
    # Получение success rate для canary
    local canary_success_rate=$(kubectl exec -n istio-system deployment/prometheus -- \
        promtool query instant 'rate(istio_requests_total{destination_service_name="'${SERVICE_NAME}'",destination_version="'${CANARY_VERSION}'",response_code=~"2.*"}[5m]) / rate(istio_requests_total{destination_service_name="'${SERVICE_NAME}'",destination_version="'${CANARY_VERSION}'"}[5m])' | \
        grep -o '[0-9.]*' | head -1)
    
    # Получение latency для canary
    local canary_latency=$(kubectl exec -n istio-system deployment/prometheus -- \
        promtool query instant 'histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket{destination_service_name="'${SERVICE_NAME}'",destination_version="'${CANARY_VERSION}'"}[5m]))' | \
        grep -o '[0-9.]*' | head -1)
    
    echo "Canary Success Rate: ${canary_success_rate:-N/A}"
    echo "Canary 95th Percentile Latency: ${canary_latency:-N/A}ms"
    
    # Проверка критериев
    if (( $(echo "$canary_success_rate > 0.95" | bc -l) )) && (( $(echo "$canary_latency < 1000" | bc -l) )); then
        echo "✅ Canary метрики в норме"
        return 0
    else
        echo "❌ Canary метрики не соответствуют критериям"
        return 1
    fi
}

# Автоматическое продвижение canary
promote_canary() {
    echo "⬆️ Продвижение canary deployment"
    
    local weights=(10 25 50 75 100)
    
    for weight in "${weights[@]}"; do
        echo "Увеличение canary трафика до $weight%"
        deploy_canary $weight
        
        # Ожидание стабилизации
        sleep 60
        
        # Мониторинг метрик
        if monitor_canary; then
            echo "✅ Метрики стабильны, продолжаем"
        else
            echo "❌ Проблемы с метриками, откат"
            rollback_canary
            return 1
        fi
    done
    
    # Финальное переключение
    finalize_canary_promotion
    
    echo "🎉 Canary deployment успешно завершен"
}

# Откат canary
rollback_canary() {
    echo "🔄 Откат canary deployment"
    
    # Возврат к 100% stable
    deploy_canary 0
    
    echo "✅ Откат завершен"
}

# Финализация canary promotion
finalize_canary_promotion() {
    echo "🏁 Финализация canary promotion"
    
    # Обновление labels для переключения stable/canary
    kubectl patch deployment ${SERVICE_NAME}-${STABLE_VERSION} -n ${NAMESPACE} -p '{"metadata":{"labels":{"version":"old"}}}'
    kubectl patch deployment ${SERVICE_NAME}-${CANARY_VERSION} -n ${NAMESPACE} -p '{"metadata":{"labels":{"version":"v1"}}}'
    
    # Удаление canary VirtualService
    kubectl delete virtualservice ${SERVICE_NAME}-canary -n ${NAMESPACE}
    
    # Создание нового stable VirtualService
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}-stable
  namespace: ${NAMESPACE}
spec:
  hosts:
  - ${SERVICE_NAME}
  http:
  - route:
    - destination:
        host: ${SERVICE_NAME}
        subset: v1
EOF
    
    echo "✅ Canary promotion финализирован"
}

# A/B testing
setup_ab_testing() {
    local feature_flag=${1:-"new-feature"}
    
    echo "🧪 Настройка A/B тестирования для $feature_flag"
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}-ab-test
  namespace: ${NAMESPACE}
spec:
  hosts:
  - ${SERVICE_NAME}
  http:
  - match:
    - headers:
        ${feature_flag}:
          exact: "enabled"
    route:
    - destination:
        host: ${SERVICE_NAME}
        subset: ${CANARY_VERSION}
  - match:
    - cookie:
        regex: ".*${feature_flag}=enabled.*"
    route:
    - destination:
        host: ${SERVICE_NAME}
        subset: ${CANARY_VERSION}
  - route:
    - destination:
        host: ${SERVICE_NAME}
        subset: ${STABLE_VERSION}
      weight: 50
    - destination:
        host: ${SERVICE_NAME}
        subset: ${CANARY_VERSION}
      weight: 50
EOF
    
    echo "✅ A/B тестирование настроено"
}

# Chaos engineering
inject_faults() {
    local fault_type=${1:-"delay"}
    local percentage=${2:-10}
    
    echo "💥 Внедрение fault injection: $fault_type ($percentage%)"
    
    case $fault_type in
        delay)
            cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}-fault-delay
  namespace: ${NAMESPACE}
spec:
  hosts:
  - ${SERVICE_NAME}
  http:
  - fault:
      delay:
        percentage:
          value: ${percentage}
        fixedDelay: 5s
    route:
    - destination:
        host: ${SERVICE_NAME}
        subset: ${STABLE_VERSION}
EOF
            ;;
        abort)
            cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}-fault-abort
  namespace: ${NAMESPACE}
spec:
  hosts:
  - ${SERVICE_NAME}
  http:
  - fault:
      abort:
        percentage:
          value: ${percentage}
        httpStatus: 503
    route:
    - destination:
        host: ${SERVICE_NAME}
        subset: ${STABLE_VERSION}
EOF
            ;;
    esac
    
    echo "✅ Fault injection активирован"
}

# Очистка fault injection
cleanup_faults() {
    echo "🧹 Очистка fault injection"
    
    kubectl delete virtualservice ${SERVICE_NAME}-fault-delay -n ${NAMESPACE} --ignore-not-found
    kubectl delete virtualservice ${SERVICE_NAME}-fault-abort -n ${NAMESPACE} --ignore-not-found
    
    echo "✅ Fault injection очищен"
}

# Основная логика
case "$1" in
    canary)
        deploy_canary ${2:-10}
        ;;
    promote)
        promote_canary
        ;;
    rollback)
        rollback_canary
        ;;
    ab-test)
        setup_ab_testing $2
        ;;
    fault-delay)
        inject_faults "delay" ${2:-10}
        ;;
    fault-abort)
        inject_faults "abort" ${2:-10}
        ;;
    cleanup-faults)
        cleanup_faults
        ;;
    monitor)
        monitor_canary
        ;;
    *)
        echo "Использование: $0 {canary [weight]|promote|rollback|ab-test [flag]|fault-delay [%]|fault-abort [%]|cleanup-faults|monitor}"
        exit 1
        ;;
esac
```

Управление трафиком в service mesh предоставляет мощные возможности для безопасного развертывания, тестирования и оптимизации микросервисных приложений через декларативную конфигурацию без изменения кода приложений.
