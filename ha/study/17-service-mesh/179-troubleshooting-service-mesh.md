# 179. Troubleshooting service mesh

## 🎯 Вопрос
Как диагностировать и устранять проблемы в service mesh?

## 💡 Ответ

Troubleshooting service mesh требует системного подхода к диагностике проблем в control plane, data plane, сетевой связности, конфигурации и производительности. Istio предоставляет богатый набор инструментов для отладки: istioctl, Envoy admin interface, метрики, логи и distributed tracing для быстрого выявления и устранения проблем.

### 🏗️ Методология troubleshooting

#### 1. **Схема диагностики проблем**
```
┌─────────────────────────────────────────────────────────────┐
│                Service Mesh Troubleshooting                │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Problem Categories                       │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │ Control     │  │    Data     │  │  Network    │     │ │
│  │  │ Plane       │  │   Plane     │  │ Connectivity│     │ │
│  │  │ Issues      │  │  Issues     │  │   Issues    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │Configuration│  │Performance  │  │  Security   │     │ │
│  │  │   Issues    │  │   Issues    │  │   Issues    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Diagnostic Tools                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   istioctl  │  │    Envoy    │  │  Prometheus │     │ │
│  │  │             │  │    Admin    │  │   Metrics   │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Jaeger    │  │    Logs     │  │    Kiali    │     │ │
│  │  │   Tracing   │  │  Analysis   │  │  Topology   │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Resolution Process                         │ │
│  │  1. Identify Problem Scope                             │ │
│  │  2. Gather Diagnostic Data                             │ │
│  │  3. Analyze Root Cause                                 │ │
│  │  4. Apply Fix                                          │ │
│  │  5. Verify Resolution                                  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Категории проблем**
```yaml
# Категории проблем в service mesh
problem_categories:
  control_plane:
    istiod_issues:
      - "Pod не запускается"
      - "Configuration sync проблемы"
      - "Certificate management ошибки"
      - "Resource exhaustion"
    
    pilot_issues:
      - "Service discovery проблемы"
      - "Configuration validation ошибки"
      - "xDS API проблемы"
      - "Memory/CPU issues"
  
  data_plane:
    envoy_issues:
      - "Sidecar injection проблемы"
      - "Configuration применение ошибки"
      - "Upstream connection failures"
      - "Circuit breaker активация"
    
    connectivity_issues:
      - "Service-to-service communication"
      - "DNS resolution проблемы"
      - "Load balancing issues"
      - "Timeout/retry проблемы"
  
  configuration:
    resource_conflicts:
      - "VirtualService конфликты"
      - "DestinationRule overlaps"
      - "Gateway configuration ошибки"
      - "Policy conflicts"
    
    validation_errors:
      - "YAML syntax ошибки"
      - "Schema validation failures"
      - "Cross-reference ошибки"
      - "Namespace isolation проблемы"
  
  performance:
    latency_issues:
      - "High request latency"
      - "Slow service discovery"
      - "Configuration propagation delays"
      - "Resource contention"
    
    throughput_issues:
      - "Connection pool exhaustion"
      - "Rate limiting activation"
      - "Resource limits"
      - "Network bandwidth"
  
  security:
    mtls_issues:
      - "Certificate validation failures"
      - "Trust domain mismatches"
      - "CA configuration problems"
      - "Certificate rotation issues"
    
    authorization_issues:
      - "RBAC policy denials"
      - "AuthorizationPolicy misconfigurations"
      - "JWT validation failures"
      - "Identity mapping problems"
```

### 📊 Примеры из нашего кластера

#### Базовые команды диагностики:
```bash
# Проверка статуса Istio компонентов
istioctl version
kubectl get pods -n istio-system

# Проверка конфигурации proxy
istioctl proxy-status
istioctl proxy-config cluster <pod-name> -n <namespace>

# Анализ конфигурации
istioctl analyze
istioctl analyze --all-namespaces

# Проверка сертификатов
istioctl authn tls-check <service>.<namespace>.svc.cluster.local
```

### 🔧 Диагностические инструменты

#### 1. **Комплексный скрипт диагностики**
```bash
#!/bin/bash
# istio-troubleshoot.sh

echo "🔍 Комплексная диагностика Service Mesh"

# Переменные
NAMESPACE=${1:-"production"}
SERVICE=${2:-"sample-app"}
POD_NAME=""

# Функция для получения pod name
get_pod_name() {
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[0].metadata.name}')
    if [ -z "$POD_NAME" ]; then
        echo "❌ Pod для сервиса $SERVICE не найден в namespace $NAMESPACE"
        exit 1
    fi
    echo "🎯 Диагностика pod: $POD_NAME"
}

# Проверка Control Plane
check_control_plane() {
    echo "🏗️ Проверка Control Plane"
    
    # Статус Istiod
    echo "=== Istiod Status ==="
    kubectl get pods -n istio-system -l app=istiod
    kubectl get svc -n istio-system -l app=istiod
    
    # Проверка готовности
    local istiod_ready=$(kubectl get pods -n istio-system -l app=istiod -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    if [ "$istiod_ready" != "True" ]; then
        echo "❌ Istiod не готов"
        kubectl describe pods -n istio-system -l app=istiod
        kubectl logs -n istio-system -l app=istiod --tail=50
    else
        echo "✅ Istiod готов"
    fi
    
    # Проверка версии
    echo "=== Version Check ==="
    istioctl version
    
    # Проверка конфигурации
    echo "=== Configuration Analysis ==="
    istioctl analyze --all-namespaces
    
    echo "✅ Control Plane проверка завершена"
}

# Проверка Data Plane
check_data_plane() {
    echo "🔗 Проверка Data Plane"
    
    get_pod_name
    
    # Статус sidecar injection
    echo "=== Sidecar Injection Status ==="
    local sidecar_count=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}' | grep -c istio-proxy)
    if [ "$sidecar_count" -eq 0 ]; then
        echo "❌ Istio sidecar не найден"
        echo "Проверка namespace injection:"
        kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.istio-injection}'
        echo "Проверка pod annotations:"
        kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.metadata.annotations}'
    else
        echo "✅ Istio sidecar найден"
    fi
    
    # Proxy status
    echo "=== Proxy Status ==="
    istioctl proxy-status $POD_NAME.$NAMESPACE
    
    # Proxy configuration
    echo "=== Proxy Configuration ==="
    istioctl proxy-config cluster $POD_NAME -n $NAMESPACE
    istioctl proxy-config listener $POD_NAME -n $NAMESPACE
    istioctl proxy-config route $POD_NAME -n $NAMESPACE
    
    # Envoy admin interface
    echo "=== Envoy Admin Interface ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep -E "(circuit_breakers|upstream_rq_retry|upstream_rq_timeout)"
    
    echo "✅ Data Plane проверка завершена"
}

# Проверка сетевой связности
check_connectivity() {
    echo "🌐 Проверка сетевой связности"
    
    get_pod_name
    
    # DNS resolution
    echo "=== DNS Resolution ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- nslookup $SERVICE.$NAMESPACE.svc.cluster.local
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- nslookup istiod.istio-system.svc.cluster.local
    
    # Service endpoints
    echo "=== Service Endpoints ==="
    kubectl get endpoints $SERVICE -n $NAMESPACE
    
    # Connectivity test
    echo "=== Connectivity Test ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE.$NAMESPACE.svc.cluster.local:8080/health
    
    # mTLS connectivity
    echo "=== mTLS Connectivity ==="
    istioctl authn tls-check $SERVICE.$NAMESPACE.svc.cluster.local
    
    echo "✅ Connectivity проверка завершена"
}

# Проверка конфигурации
check_configuration() {
    echo "⚙️ Проверка конфигурации"
    
    # VirtualService
    echo "=== VirtualService ==="
    kubectl get virtualservice -n $NAMESPACE
    kubectl describe virtualservice -n $NAMESPACE
    
    # DestinationRule
    echo "=== DestinationRule ==="
    kubectl get destinationrule -n $NAMESPACE
    kubectl describe destinationrule -n $NAMESPACE
    
    # Gateway
    echo "=== Gateway ==="
    kubectl get gateway -n $NAMESPACE
    kubectl describe gateway -n $NAMESPACE
    
    # ServiceEntry
    echo "=== ServiceEntry ==="
    kubectl get serviceentry -n $NAMESPACE
    
    # PeerAuthentication
    echo "=== PeerAuthentication ==="
    kubectl get peerauthentication -n $NAMESPACE
    kubectl get peerauthentication -n istio-system
    
    # AuthorizationPolicy
    echo "=== AuthorizationPolicy ==="
    kubectl get authorizationpolicy -n $NAMESPACE
    
    # Configuration validation
    echo "=== Configuration Validation ==="
    istioctl analyze -n $NAMESPACE
    
    echo "✅ Configuration проверка завершена"
}

# Проверка производительности
check_performance() {
    echo "⚡ Проверка производительности"
    
    get_pod_name
    
    # Resource usage
    echo "=== Resource Usage ==="
    kubectl top pod $POD_NAME -n $NAMESPACE --containers
    
    # Envoy stats
    echo "=== Envoy Performance Stats ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep -E "(memory|cpu|connections|requests)"
    
    # Circuit breaker status
    echo "=== Circuit Breaker Status ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep circuit_breakers
    
    # Connection pool stats
    echo "=== Connection Pool Stats ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep upstream_cx
    
    echo "✅ Performance проверка завершена"
}

# Проверка безопасности
check_security() {
    echo "🔐 Проверка безопасности"
    
    get_pod_name
    
    # Certificate status
    echo "=== Certificate Status ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -text -noout | grep -A 2 "Validity"
    
    # SPIFFE identity
    echo "=== SPIFFE Identity ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -text -noout | grep "Subject Alternative Name"
    
    # mTLS status
    echo "=== mTLS Status ==="
    istioctl authn tls-check $SERVICE.$NAMESPACE.svc.cluster.local
    
    # Authorization policies
    echo "=== Authorization Policies ==="
    kubectl get authorizationpolicy -n $NAMESPACE -o yaml
    
    echo "✅ Security проверка завершена"
}

# Сбор логов
collect_logs() {
    echo "📋 Сбор логов"
    
    local log_dir="/tmp/istio-logs-$(date +%s)"
    mkdir -p $log_dir
    
    # Istiod logs
    echo "Сбор Istiod логов..."
    kubectl logs -n istio-system -l app=istiod --tail=1000 > $log_dir/istiod.log
    
    # Sidecar logs
    if [ -n "$POD_NAME" ]; then
        echo "Сбор sidecar логов..."
        kubectl logs $POD_NAME -n $NAMESPACE -c istio-proxy --tail=1000 > $log_dir/sidecar.log
        
        # Application logs
        echo "Сбор application логов..."
        kubectl logs $POD_NAME -n $NAMESPACE --tail=1000 > $log_dir/application.log
    fi
    
    # Gateway logs
    echo "Сбор gateway логов..."
    kubectl logs -n istio-system -l app=istio-ingressgateway --tail=1000 > $log_dir/gateway.log
    
    # Configuration dump
    echo "Сбор configuration dump..."
    if [ -n "$POD_NAME" ]; then
        kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET config_dump > $log_dir/config_dump.json
    fi
    
    echo "✅ Логи собраны в $log_dir"
}

# Генерация отчета
generate_report() {
    echo "📊 Генерация отчета диагностики"
    
    local report_file="/tmp/istio-diagnostic-report-$(date +%s).txt"
    
    {
        echo "=== ISTIO DIAGNOSTIC REPORT ==="
        echo "Generated: $(date)"
        echo "Namespace: $NAMESPACE"
        echo "Service: $SERVICE"
        echo "Pod: $POD_NAME"
        echo ""
        
        echo "=== CLUSTER INFO ==="
        kubectl cluster-info
        echo ""
        
        echo "=== ISTIO VERSION ==="
        istioctl version
        echo ""
        
        echo "=== CONTROL PLANE STATUS ==="
        kubectl get pods -n istio-system
        echo ""
        
        echo "=== PROXY STATUS ==="
        istioctl proxy-status
        echo ""
        
        echo "=== CONFIGURATION ANALYSIS ==="
        istioctl analyze --all-namespaces
        echo ""
        
        echo "=== RESOURCE USAGE ==="
        kubectl top pods -n istio-system
        kubectl top pods -n $NAMESPACE
        echo ""
        
    } > $report_file
    
    echo "✅ Отчет сохранен в $report_file"
}

# Основная логика
case "$1" in
    control-plane)
        check_control_plane
        ;;
    data-plane)
        check_data_plane
        ;;
    connectivity)
        check_connectivity
        ;;
    config)
        check_configuration
        ;;
    performance)
        check_performance
        ;;
    security)
        check_security
        ;;
    logs)
        collect_logs
        ;;
    report)
        generate_report
        ;;
    all)
        check_control_plane
        check_data_plane
        check_connectivity
        check_configuration
        check_performance
        check_security
        collect_logs
        generate_report
        ;;
    *)
        echo "Использование: $0 {control-plane|data-plane|connectivity|config|performance|security|logs|report|all} [namespace] [service]"
        echo ""
        echo "Примеры:"
        echo "  $0 all production sample-app"
        echo "  $0 connectivity production api-service"
        echo "  $0 logs"
        exit 1
        ;;
esac
```

#### 2. **Специализированные диагностические скрипты**

##### mTLS диагностика
```bash
#!/bin/bash
# diagnose-mtls.sh

echo "🔐 Диагностика mTLS проблем"

diagnose_mtls_issues() {
    local service=$1
    local namespace=$2
    
    echo "🔍 Диагностика mTLS для $service в $namespace"
    
    # Проверка PeerAuthentication
    echo "=== PeerAuthentication Policies ==="
    kubectl get peerauthentication -n $namespace
    kubectl get peerauthentication -n istio-system
    
    # Проверка DestinationRule TLS settings
    echo "=== DestinationRule TLS Settings ==="
    kubectl get destinationrule -n $namespace -o yaml | grep -A 10 tls
    
    # Проверка сертификатов
    echo "=== Certificate Check ==="
    local pod=$(kubectl get pods -n $namespace -l app=$service -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$pod" ]; then
        # Проверка наличия сертификатов
        kubectl exec $pod -n $namespace -c istio-proxy -- ls -la /var/run/secrets/workload-spiffe-credentials/
        
        # Проверка срока действия
        kubectl exec $pod -n $namespace -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -noout -dates
        
        # Проверка SPIFFE ID
        kubectl exec $pod -n $namespace -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -text -noout | grep "Subject Alternative Name"
    fi
    
    # TLS check
    echo "=== TLS Check ==="
    istioctl authn tls-check $service.$namespace.svc.cluster.local
    
    # Envoy TLS configuration
    echo "=== Envoy TLS Configuration ==="
    if [ -n "$pod" ]; then
        kubectl exec $pod -n $namespace -c istio-proxy -- pilot-agent request GET config_dump | jq '.configs[] | select(.["@type"] | contains("type.googleapis.com/envoy.admin.v3.ClustersConfigDump")) | .dynamic_active_clusters[] | select(.cluster.transport_socket.typed_config.common_tls_context) | {name: .cluster.name, tls: .cluster.transport_socket.typed_config.common_tls_context}'
    fi
}

# Тест mTLS connectivity
test_mtls_connectivity() {
    local source_pod=$1
    local source_namespace=$2
    local target_service=$3
    local target_namespace=$4
    
    echo "🧪 Тест mTLS connectivity"
    
    # Тест без mTLS
    echo "Тест HTTP (без mTLS):"
    kubectl exec $source_pod -n $source_namespace -- curl -s -o /dev/null -w "%{http_code}" http://$target_service.$target_namespace.svc.cluster.local:8080/
    
    # Тест с mTLS
    echo "Тест HTTPS (с mTLS):"
    kubectl exec $source_pod -n $source_namespace -- curl -s -o /dev/null -w "%{http_code}" \
        --cert /var/run/secrets/workload-spiffe-credentials/cert.pem \
        --key /var/run/secrets/workload-spiffe-credentials/key.pem \
        --cacert /var/run/secrets/workload-spiffe-credentials/ca.pem \
        https://$target_service.$target_namespace.svc.cluster.local:8080/
}

case "$1" in
    diagnose)
        diagnose_mtls_issues $2 $3
        ;;
    test)
        test_mtls_connectivity $2 $3 $4 $5
        ;;
    *)
        echo "Использование: $0 {diagnose|test} [params...]"
        exit 1
        ;;
esac
```

### 📊 Мониторинг и алерты

#### 1. **Prometheus правила для диагностики**
```yaml
# diagnostic-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: istio-diagnostic-alerts
  namespace: istio-system
spec:
  groups:
  - name: istio-diagnostic.rules
    rules:
    - alert: IstioControlPlaneDown
      expr: up{job="istiod"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Istio control plane is down"
        description: "Istiod is not responding"
    
    - alert: IstioProxyNotReady
      expr: sum(rate(envoy_cluster_upstream_rq_xx{envoy_response_code_class="5"}[5m])) by (envoy_cluster_name) > 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High 5xx error rate in Envoy proxy"
        description: "Cluster {{ $labels.envoy_cluster_name }} has high error rate"
    
    - alert: IstioConfigurationError
      expr: increase(pilot_k8s_cfg_events{type="Warning"}[5m]) > 0
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Istio configuration error detected"
        description: "Configuration warning in Istio pilot"
    
    - alert: IstioSidecarInjectionFailure
      expr: increase(sidecar_injection_failure_total[5m]) > 0
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Sidecar injection failure"
        description: "Failed to inject Istio sidecar"
    
    - alert: IstioCertificateExpiringSoon
      expr: (pilot_cert_expiry_timestamp - time()) / 86400 < 7
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Istio certificate expiring soon"
        description: "Certificate expires in less than 7 days"
```

### 🔧 Автоматизированная диагностика

#### 1. **Health check скрипт**
```bash
#!/bin/bash
# istio-health-check.sh

echo "🏥 Автоматизированная проверка здоровья Istio"

# Функция проверки здоровья
health_check() {
    local component=$1
    local check_command=$2
    local expected_result=$3
    
    echo -n "Проверка $component: "
    
    local result=$(eval $check_command 2>/dev/null)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [[ "$result" == *"$expected_result"* ]]; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAIL"
        echo "  Команда: $check_command"
        echo "  Результат: $result"
        return 1
    fi
}

# Проверки
echo "🔍 Выполнение проверок здоровья..."

# Control Plane
health_check "Istiod Pod" "kubectl get pods -n istio-system -l app=istiod --no-headers" "Running"
health_check "Istiod Service" "kubectl get svc -n istio-system -l app=istiod --no-headers" "ClusterIP"

# Data Plane
health_check "Proxy Status" "istioctl proxy-status" "SYNCED"

# Configuration
health_check "Configuration Analysis" "istioctl analyze --all-namespaces" "No validation issues found"

# Connectivity
health_check "DNS Resolution" "kubectl exec -n istio-system deployment/istiod -- nslookup kubernetes.default.svc.cluster.local" "kubernetes.default.svc.cluster.local"

# Certificates
health_check "Certificate Validity" "kubectl exec -n istio-system deployment/istiod -- openssl x509 -in /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -noout -checkend 604800" ""

echo ""
echo "🏥 Проверка здоровья завершена"
```

Troubleshooting service mesh требует систематического подхода и использования множественных инструментов диагностики для быстрого выявления и устранения проблем в сложной микросервисной архитектуре.
