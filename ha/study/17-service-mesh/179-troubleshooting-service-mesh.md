# 179. Troubleshooting service mesh

## 🎯 **Что такое troubleshooting service mesh?**

**Troubleshooting service mesh** - это систематический подход к диагностике и устранению проблем в control plane, data plane, сетевой связности, конфигурации и производительности через istioctl, Envoy admin interface, метрики, логи и distributed tracing для быстрого выявления root cause и восстановления работоспособности mesh.

## 🏗️ **Основные категории проблем:**

### **1. Control Plane Issues**
- Istiod pod failures
- Configuration sync problems
- Certificate management errors
- Resource exhaustion

### **2. Data Plane Issues**
- Sidecar injection problems
- Envoy configuration errors
- Upstream connection failures
- Circuit breaker activation

### **3. Network Connectivity**
- Service-to-service communication
- DNS resolution problems
- Load balancing issues
- mTLS connectivity failures

### **4. Configuration Problems**
- VirtualService conflicts
- DestinationRule overlaps
- Gateway misconfigurations
- Policy validation errors

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Комплексный диагностический скрипт:**
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
    kubectl get pods -n istio-system -l app=istiod -o wide
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
    
    # Проверка ресурсов
    echo "=== Resource Usage ==="
    kubectl top pods -n istio-system --containers
    
    # Проверка endpoints
    echo "=== Istiod Endpoints ==="
    kubectl get endpoints istiod -n istio-system -o yaml
    
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
        echo ""
        echo "Проверка pod annotations:"
        kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.metadata.annotations}' | jq '.'
        
        # Проверка webhook
        echo "Проверка sidecar injector webhook:"
        kubectl get mutatingwebhookconfiguration istio-sidecar-injector -o yaml | grep -A 5 -B 5 "namespaceSelector"
    else
        echo "✅ Istio sidecar найден"
        
        # Статус sidecar
        echo "Статус sidecar контейнера:"
        kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[?(@.name=="istio-proxy")]}' | jq '.'
    fi
    
    # Proxy status
    echo "=== Proxy Status ==="
    istioctl proxy-status $POD_NAME.$NAMESPACE
    
    # Proxy configuration
    echo "=== Proxy Configuration ==="
    echo "Clusters:"
    istioctl proxy-config cluster $POD_NAME -n $NAMESPACE | head -10
    echo ""
    echo "Listeners:"
    istioctl proxy-config listener $POD_NAME -n $NAMESPACE | head -10
    echo ""
    echo "Routes:"
    istioctl proxy-config route $POD_NAME -n $NAMESPACE | head -10
    
    # Envoy admin interface
    echo "=== Envoy Admin Interface ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep -E "(circuit_breakers|upstream_rq_retry|upstream_rq_timeout)" | head -10
    
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
    kubectl get endpoints $SERVICE -n $NAMESPACE -o yaml
    
    # Connectivity test
    echo "=== Connectivity Test ==="
    local response_code=$(kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE.$NAMESPACE.svc.cluster.local:8080/health 2>/dev/null || echo "000")
    echo "HTTP response code: $response_code"
    
    # mTLS connectivity
    echo "=== mTLS Connectivity ==="
    istioctl authn tls-check $SERVICE.$NAMESPACE.svc.cluster.local
    
    # Envoy clusters health
    echo "=== Envoy Clusters Health ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET clusters | grep -E "(health_flags|outlier_detection)" | head -10
    
    echo "✅ Connectivity проверка завершена"
}

# Проверка конфигурации
check_configuration() {
    echo "⚙️ Проверка конфигурации"
    
    # VirtualService
    echo "=== VirtualService ==="
    kubectl get virtualservice -n $NAMESPACE -o yaml
    
    # DestinationRule
    echo "=== DestinationRule ==="
    kubectl get destinationrule -n $NAMESPACE -o yaml
    
    # Gateway
    echo "=== Gateway ==="
    kubectl get gateway -n $NAMESPACE -o yaml
    
    # ServiceEntry
    echo "=== ServiceEntry ==="
    kubectl get serviceentry -n $NAMESPACE
    
    # PeerAuthentication
    echo "=== PeerAuthentication ==="
    kubectl get peerauthentication -n $NAMESPACE -o yaml
    kubectl get peerauthentication -n istio-system -o yaml
    
    # AuthorizationPolicy
    echo "=== AuthorizationPolicy ==="
    kubectl get authorizationpolicy -n $NAMESPACE -o yaml
    
    # Configuration validation
    echo "=== Configuration Validation ==="
    istioctl analyze -n $NAMESPACE
    
    # Pilot configuration dump
    echo "=== Pilot Configuration Dump ==="
    if [ -n "$POD_NAME" ]; then
        kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET config_dump > /tmp/config_dump_${POD_NAME}.json
        echo "Configuration dump сохранен в /tmp/config_dump_${POD_NAME}.json"
    fi
    
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
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep -E "(memory|cpu|connections|requests)" | head -10
    
    # Circuit breaker status
    echo "=== Circuit Breaker Status ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep circuit_breakers
    
    # Connection pool stats
    echo "=== Connection Pool Stats ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep upstream_cx | head -10
    
    # Request latency
    echo "=== Request Latency Stats ==="
    kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET stats | grep histogram | head -10
    
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
    kubectl get authorizationpolicy -n $NAMESPACE
    
    # Security events
    echo "=== Security Events ==="
    kubectl get events -n $NAMESPACE --field-selector reason=Denied | head -10
    
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
        kubectl logs $POD_NAME -n $NAMESPACE --tail=1000 > $log_dir/application.log 2>/dev/null || echo "Application logs недоступны"
    fi
    
    # Gateway logs
    echo "Сбор gateway логов..."
    kubectl logs -n istio-system -l app=istio-ingressgateway --tail=1000 > $log_dir/gateway.log
    
    # Configuration dump
    echo "Сбор configuration dump..."
    if [ -n "$POD_NAME" ]; then
        kubectl exec $POD_NAME -n $NAMESPACE -c istio-proxy -- pilot-agent request GET config_dump > $log_dir/config_dump.json 2>/dev/null || echo "Config dump недоступен"
    fi
    
    # Events
    echo "Сбор events..."
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' > $log_dir/events.log
    kubectl get events -n istio-system --sort-by='.lastTimestamp' > $log_dir/istio-events.log
    
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
        kubectl top pods -n istio-system 2>/dev/null || echo "Metrics server недоступен"
        kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics server недоступен"
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

chmod +x istio-troubleshoot.sh
```

### **2. Специализированные диагностические скрипты:**

#### **mTLS диагностика:**
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
    kubectl get peerauthentication -n $namespace -o yaml
    kubectl get peerauthentication -n istio-system -o yaml
    
    # Проверка DestinationRule TLS settings
    echo "=== DestinationRule TLS Settings ==="
    kubectl get destinationrule -n $namespace -o yaml | grep -A 10 tls
    
    # Проверка сертификатов
    echo "=== Certificate Check ==="
    local pod=$(kubectl get pods -n $namespace -l app=$service -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$pod" ]; then
        # Проверка наличия сертификатов
        echo "Файлы сертификатов:"
        kubectl exec $pod -n $namespace -c istio-proxy -- ls -la /var/run/secrets/workload-spiffe-credentials/
        
        # Проверка срока действия
        echo "Срок действия сертификата:"
        kubectl exec $pod -n $namespace -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -noout -dates
        
        # Проверка SPIFFE ID
        echo "SPIFFE Identity:"
        kubectl exec $pod -n $namespace -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -text -noout | grep "Subject Alternative Name"
        
        # Проверка CA
        echo "CA Certificate:"
        kubectl exec $pod -n $namespace -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/ca.pem -text -noout | grep -A 2 "Subject:"
    fi
    
    # TLS check
    echo "=== TLS Check ==="
    istioctl authn tls-check $service.$namespace.svc.cluster.local
    
    # Envoy TLS configuration
    echo "=== Envoy TLS Configuration ==="
    if [ -n "$pod" ]; then
        kubectl exec $pod -n $namespace -c istio-proxy -- pilot-agent request GET config_dump | jq '.configs[] | select(.["@type"] | contains("type.googleapis.com/envoy.admin.v3.ClustersConfigDump")) | .dynamic_active_clusters[] | select(.cluster.transport_socket.typed_config.common_tls_context) | {name: .cluster.name, tls: .cluster.transport_socket.typed_config.common_tls_context}' | head -5
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
    kubectl exec $source_pod -n $source_namespace -- curl -s -o /dev/null -w "%{http_code}" http://$target_service.$target_namespace.svc.cluster.local:8080/ 2>/dev/null || echo "Failed"
    
    # Тест с mTLS через Envoy
    echo "Тест через Envoy sidecar (с mTLS):"
    kubectl exec $source_pod -n $source_namespace -c istio-proxy -- curl -s -o /dev/null -w "%{http_code}" http://$target_service.$target_namespace.svc.cluster.local:8080/ 2>/dev/null || echo "Failed"
    
    # Проверка TLS handshake
    echo "Проверка TLS handshake:"
    kubectl exec $source_pod -n $source_namespace -c istio-proxy -- openssl s_client -connect $target_service.$target_namespace.svc.cluster.local:8080 -cert /var/run/secrets/workload-spiffe-credentials/cert.pem -key /var/run/secrets/workload-spiffe-credentials/key.pem -CAfile /var/run/secrets/workload-spiffe-credentials/ca.pem < /dev/null 2>&1 | grep -E "(Verify return code|subject|issuer)"
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
        echo "diagnose: $0 diagnose <service> <namespace>"
        echo "test: $0 test <source-pod> <source-namespace> <target-service> <target-namespace>"
        exit 1
        ;;
esac
```

### **3. Автоматизированный health check:**
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

# Gateway
health_check "Ingress Gateway" "kubectl get pods -n istio-system -l app=istio-ingressgateway --no-headers" "Running"

echo ""
echo "🏥 Проверка здоровья завершена"
```

## 🚨 **Мониторинг и алертинг для troubleshooting:**

### **1. Prometheus правила для диагностики:**
```yaml
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
    
    - alert: IstioHighMemoryUsage
      expr: container_memory_usage_bytes{container="istio-proxy"} / container_spec_memory_limit_bytes{container="istio-proxy"} > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage in Istio proxy"
        description: "Istio proxy memory usage is above 80%"
```

### **2. Grafana dashboard для troubleshooting:**
```bash
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-troubleshooting-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  istio-troubleshooting.json: |
    {
      "dashboard": {
        "title": "Istio Troubleshooting Dashboard",
        "panels": [
          {
            "title": "Control Plane Health",
            "type": "stat",
            "targets": [
              {
                "expr": "up{job=\"istiod\"}",
                "legendFormat": "Istiod"
              }
            ]
          },
          {
            "title": "Proxy Sync Status",
            "type": "table",
            "targets": [
              {
                "expr": "pilot_proxy_convergence_time",
                "legendFormat": "{{proxy}}"
              }
            ]
          },
          {
            "title": "Configuration Errors",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(pilot_k8s_cfg_events{type=\"Warning\"}[5m])",
                "legendFormat": "Config Warnings"
              }
            ]
          },
          {
            "title": "Sidecar Injection Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(sidecar_injection_success_total[5m])",
                "legendFormat": "Success"
              },
              {
                "expr": "rate(sidecar_injection_failure_total[5m])",
                "legendFormat": "Failures"
              }
            ]
          }
        ]
      }
    }
EOF
```

## 🎯 **Best Practices для troubleshooting:**

### **1. Систематический подход:**
- Начинать с control plane проверки
- Проверять data plane конфигурацию
- Тестировать network connectivity
- Анализировать security policies

### **2. Инструменты диагностики:**
- Использовать istioctl для быстрой диагностики
- Анализировать Envoy admin interface
- Мониторить метрики в реальном времени
- Собирать и анализировать логи

### **3. Профилактические меры:**
- Регулярно запускать health checks
- Мониторить key metrics
- Настроить proper alerting
- Документировать known issues

### **4. Escalation procedures:**
- Определить критичность проблемы
- Собрать diagnostic data
- Применить temporary workarounds
- Планировать permanent fixes

**Эффективный troubleshooting service mesh требует систематического подхода и использования правильных инструментов диагностики!**
