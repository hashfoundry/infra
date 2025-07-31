# 176. Управление трафиком в service mesh

## 🎯 **Что такое traffic management в service mesh?**

**Traffic management** в service mesh обеспечивает intelligent routing, load balancing, circuit breaking, canary deployments, A/B testing и fault injection через декларативную конфигурацию VirtualService, DestinationRule, Gateway и ServiceEntry без изменения кода приложений.

## 🏗️ **Основные компоненты traffic management:**

### **1. VirtualService**
- Routing rules и traffic splitting
- Header-based routing
- Fault injection и timeout/retry

### **2. DestinationRule**
- Load balancing algorithms
- Circuit breaking и connection pooling
- Subset definitions

### **3. Gateway**
- Ingress/Egress traffic management
- TLS termination
- Protocol handling

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Базовая настройка traffic management:**
```bash
# Создание тестового приложения с версиями
kubectl create namespace traffic-demo

kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app-v1
  namespace: traffic-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
      version: v1
  template:
    metadata:
      labels:
        app: sample-app
        version: v1
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "v1"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app-v2
  namespace: traffic-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
      version: v2
  template:
    metadata:
      labels:
        app: sample-app
        version: v2
    spec:
      containers:
      - name: app
        image: nginx:1.22
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "v2"
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  namespace: traffic-demo
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Включение Istio injection
kubectl label namespace traffic-demo istio-injection=enabled
kubectl rollout restart deployment/sample-app-v1 -n traffic-demo
kubectl rollout restart deployment/sample-app-v2 -n traffic-demo
```

### **2. VirtualService для routing:**
```bash
# Базовый routing по версиям
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: sample-app-routing
  namespace: traffic-demo
spec:
  hosts:
  - sample-app
  http:
  - match:
    - headers:
        version:
          exact: "v2"
    route:
    - destination:
        host: sample-app
        subset: v2
  - route:
    - destination:
        host: sample-app
        subset: v1
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: sample-app-subsets
  namespace: traffic-demo
spec:
  host: sample-app
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
EOF

# Тестирование routing
kubectl run test-client --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
  curl -H "version: v2" http://sample-app/

kubectl run test-client --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
  curl http://sample-app/
```

### **3. Canary deployment с weight-based routing:**
```bash
# Canary deployment 90/10
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: sample-app-canary
  namespace: traffic-demo
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
        subset: v2
  - route:
    - destination:
        host: sample-app
        subset: v1
      weight: 90
    - destination:
        host: sample-app
        subset: v2
      weight: 10
EOF

# Тестирование canary
for i in {1..20}; do
  kubectl run test-client-$i --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
    curl -s http://sample-app/ | grep -o "nginx/[0-9.]*" &
done
wait
```

### **4. Circuit breaker и connection pooling:**
```bash
# DestinationRule с circuit breaker
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: sample-app-circuit-breaker
  namespace: traffic-demo
spec:
  host: sample-app
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
      http:
        http1MaxPendingRequests: 5
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveGatewayErrors: 3
      consecutive5xxErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 5
        http:
          http1MaxPendingRequests: 2
EOF

# Тестирование circuit breaker
kubectl run load-test --image=fortio/fortio --rm -i --restart=Never -n traffic-demo -- \
  load -c 20 -qps 50 -t 30s http://sample-app/
```

### **5. Fault injection для chaos engineering:**
```bash
# Fault injection с delay и abort
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: sample-app-fault-injection
  namespace: traffic-demo
spec:
  hosts:
  - sample-app
  http:
  - match:
    - headers:
        test-fault:
          exact: "delay"
    fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 5s
    route:
    - destination:
        host: sample-app
        subset: v1
  - match:
    - headers:
        test-fault:
          exact: "abort"
    fault:
      abort:
        percentage:
          value: 50
        httpStatus: 503
    route:
    - destination:
        host: sample-app
        subset: v1
  - route:
    - destination:
        host: sample-app
        subset: v1
EOF

# Тестирование fault injection
kubectl run test-delay --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
  curl -w "Total time: %{time_total}s\n" -H "test-fault: delay" http://sample-app/

kubectl run test-abort --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
  curl -w "HTTP Code: %{http_code}\n" -H "test-fault: abort" http://sample-app/
```

## 🌐 **Gateway конфигурации:**

### **1. Ingress Gateway setup:**
```bash
# Создание Gateway для внешнего доступа
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: sample-app-gateway
  namespace: traffic-demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - sample-app.hashfoundry.local
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: sample-app-tls
    hosts:
    - sample-app.hashfoundry.local
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: sample-app-gateway-vs
  namespace: traffic-demo
spec:
  hosts:
  - sample-app.hashfoundry.local
  gateways:
  - sample-app-gateway
  http:
  - match:
    - uri:
        prefix: "/v2"
    rewrite:
      uri: "/"
    route:
    - destination:
        host: sample-app
        subset: v2
  - route:
    - destination:
        host: sample-app
        subset: v1
EOF

# Получение Ingress Gateway IP
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Gateway IP: $GATEWAY_IP"

# Тестирование через Gateway
curl -H "Host: sample-app.hashfoundry.local" http://$GATEWAY_IP/
curl -H "Host: sample-app.hashfoundry.local" http://$GATEWAY_IP/v2
```

### **2. Egress Gateway для внешних сервисов:**
```bash
# ServiceEntry для внешнего API
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-api
  namespace: traffic-demo
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: egress-gateway
  namespace: traffic-demo
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.org
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: external-api-vs
  namespace: traffic-demo
spec:
  hosts:
  - httpbin.org
  gateways:
  - egress-gateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - egress-gateway
      port: 80
    route:
    - destination:
        host: httpbin.org
        port:
          number: 80
      weight: 100
EOF

# Тестирование egress
kubectl run egress-test --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
  curl -s http://httpbin.org/ip
```

## 🔄 **Автоматизация traffic management:**

### **1. Скрипт для canary deployment:**
```bash
#!/bin/bash
# canary-deployment.sh

NAMESPACE="traffic-demo"
SERVICE_NAME="sample-app"
STABLE_VERSION="v1"
CANARY_VERSION="v2"

deploy_canary() {
    local weight=${1:-10}
    
    echo "🚀 Развертывание canary с весом $weight%"
    
    kubectl apply -f - << EOF
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
      weight: $((100 - weight))
    - destination:
        host: ${SERVICE_NAME}
        subset: ${CANARY_VERSION}
      weight: ${weight}
EOF
    
    echo "✅ Canary deployment с весом $weight% развернут"
}

monitor_canary() {
    echo "📊 Мониторинг canary метрик"
    
    # Получение success rate
    local success_rate=$(kubectl exec -n istio-system deployment/prometheus -- \
        promtool query instant "
        sum(rate(istio_requests_total{destination_service_name=\"${SERVICE_NAME}\",destination_version=\"${CANARY_VERSION}\",response_code=~\"2.*\"}[5m])) / 
        sum(rate(istio_requests_total{destination_service_name=\"${SERVICE_NAME}\",destination_version=\"${CANARY_VERSION}\"}[5m]))
        " 2>/dev/null | grep -o '[0-9.]*' | head -1)
    
    # Получение latency
    local latency=$(kubectl exec -n istio-system deployment/prometheus -- \
        promtool query instant "
        histogram_quantile(0.95, 
        sum(rate(istio_request_duration_milliseconds_bucket{destination_service_name=\"${SERVICE_NAME}\",destination_version=\"${CANARY_VERSION}\"}[5m])) by (le))
        " 2>/dev/null | grep -o '[0-9.]*' | head -1)
    
    echo "Success Rate: ${success_rate:-N/A}"
    echo "95th Percentile Latency: ${latency:-N/A}ms"
    
    # Простая проверка (в реальности нужны более сложные критерии)
    if [[ -n "$success_rate" ]] && (( $(echo "$success_rate > 0.95" | bc -l 2>/dev/null || echo 0) )); then
        echo "✅ Canary метрики в норме"
        return 0
    else
        echo "❌ Canary метрики не соответствуют критериям"
        return 1
    fi
}

promote_canary() {
    echo "⬆️ Автоматическое продвижение canary"
    
    local weights=(10 25 50 75 100)
    
    for weight in "${weights[@]}"; do
        echo "Увеличение canary трафика до $weight%"
        deploy_canary $weight
        
        sleep 30
        
        if monitor_canary; then
            echo "✅ Метрики стабильны, продолжаем"
        else
            echo "❌ Проблемы с метриками, откат"
            rollback_canary
            return 1
        fi
    done
    
    finalize_promotion
    echo "🎉 Canary deployment успешно завершен"
}

rollback_canary() {
    echo "🔄 Откат canary deployment"
    deploy_canary 0
    echo "✅ Откат завершен"
}

finalize_promotion() {
    echo "🏁 Финализация promotion"
    
    kubectl apply -f - << EOF
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
        subset: ${CANARY_VERSION}
EOF
}

case "$1" in
    deploy)
        deploy_canary ${2:-10}
        ;;
    monitor)
        monitor_canary
        ;;
    promote)
        promote_canary
        ;;
    rollback)
        rollback_canary
        ;;
    *)
        echo "Usage: $0 {deploy [weight]|monitor|promote|rollback}"
        exit 1
        ;;
esac
```

### **2. A/B testing automation:**
```bash
# A/B testing setup
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: sample-app-ab-test
  namespace: traffic-demo
spec:
  hosts:
  - sample-app
  http:
  - match:
    - headers:
        user-group:
          exact: "beta"
    route:
    - destination:
        host: sample-app
        subset: v2
  - match:
    - cookie:
        regex: ".*experiment=beta.*"
    route:
    - destination:
        host: sample-app
        subset: v2
  - route:
    - destination:
        host: sample-app
        subset: v1
      weight: 50
    - destination:
        host: sample-app
        subset: v2
      weight: 50
EOF

# Тестирование A/B
kubectl run ab-test-beta --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
  curl -H "user-group: beta" http://sample-app/

kubectl run ab-test-cookie --image=curlimages/curl --rm -i --restart=Never -n traffic-demo -- \
  curl -H "Cookie: experiment=beta" http://sample-app/
```

## 📈 **Мониторинг traffic management:**

### **1. Ключевые метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &

# Основные метрики для traffic management:
# istio_requests_total - общее количество запросов
# istio_request_duration_milliseconds - latency запросов
# istio_request_bytes - размер запросов
# istio_response_bytes - размер ответов
# envoy_cluster_upstream_rq_retry - количество retry
# envoy_cluster_upstream_rq_timeout - количество timeout
```

### **2. Grafana дашборд:**
```bash
# Создание дашборда для traffic management
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: traffic-management-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  traffic-dashboard.json: |
    {
      "dashboard": {
        "title": "Traffic Management Dashboard",
        "panels": [
          {
            "title": "Request Rate by Version",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total[5m])) by (destination_version)",
                "legendFormat": "{{destination_version}}"
              }
            ]
          },
          {
            "title": "Canary Traffic Distribution",
            "type": "pie",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total[5m])) by (destination_version)"
              }
            ]
          },
          {
            "title": "Circuit Breaker Status",
            "type": "stat",
            "targets": [
              {
                "expr": "envoy_cluster_upstream_rq_pending_overflow"
              }
            ]
          }
        ]
      }
    }
EOF
```

## 🚨 **Диагностика traffic management:**

### **1. Проверка конфигурации:**
```bash
# Анализ VirtualService
kubectl get virtualservice --all-namespaces
istioctl analyze --all-namespaces

# Проверка routing rules
istioctl proxy-config route deployment/sample-app-v1 -n traffic-demo

# Проверка clusters
istioctl proxy-config cluster deployment/sample-app-v1 -n traffic-demo

# Проверка listeners
istioctl proxy-config listener deployment/sample-app-v1 -n traffic-demo
```

### **2. Envoy конфигурация:**
```bash
# Dump Envoy конфигурации
POD_NAME=$(kubectl get pods -n traffic-demo -l app=sample-app,version=v1 -o jsonpath='{.items[0].metadata.name}')

kubectl exec $POD_NAME -n traffic-demo -c istio-proxy -- \
  pilot-agent request GET config_dump | jq '.configs[2].dynamic_route_configs'

# Проверка upstream clusters
kubectl exec $POD_NAME -n traffic-demo -c istio-proxy -- \
  pilot-agent request GET clusters | grep sample-app
```

### **3. Логи и статистика:**
```bash
# Envoy access logs
kubectl logs $POD_NAME -n traffic-demo -c istio-proxy | grep "GET /"

# Envoy статистика
kubectl exec $POD_NAME -n traffic-demo -c istio-proxy -- \
  pilot-agent request GET stats | grep -E "(retry|timeout|circuit_breaker)"

# Istiod логи
kubectl logs -n istio-system -l app=istiod --tail=50 | grep -i "traffic\|route"
```

## 🔧 **Cleanup тестового окружения:**
```bash
# Очистка всех ресурсов
kubectl delete namespace traffic-demo

# Остановка port forwards
pkill -f "kubectl port-forward"

# Удаление скриптов
rm -f canary-deployment.sh
```

## 🎯 **Best Practices для traffic management:**

### **1. Canary Deployments:**
- Начинать с малого процента трафика (5-10%)
- Мониторить ключевые метрики (success rate, latency, errors)
- Автоматизировать rollback при проблемах
- Использовать feature flags для A/B testing

### **2. Circuit Breaking:**
- Настраивать conservative limits
- Мониторить connection pool metrics
- Использовать outlier detection
- Тестировать circuit breaker behavior

### **3. Load Balancing:**
- Выбирать подходящий алгоритм (ROUND_ROBIN, LEAST_CONN)
- Учитывать характеристики workload
- Настраивать health checks
- Мониторить distribution metrics

### **4. Fault Injection:**
- Использовать для chaos engineering
- Тестировать resilience patterns
- Начинать с низких процентов
- Мониторить impact на downstream services

**Traffic management в service mesh обеспечивает sophisticated control над микросервисной коммуникацией!**
