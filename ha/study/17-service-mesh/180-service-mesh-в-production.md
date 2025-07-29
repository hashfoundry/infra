# 180. Service mesh в production

## 🎯 Вопрос
Какие лучшие практики для развертывания service mesh в production?

## 💡 Ответ

Развертывание service mesh в production требует тщательного планирования архитектуры, постепенной миграции, настройки мониторинга, обеспечения высокой доступности и производительности. Ключевые аспекты включают canary deployments, resource planning, security hardening, disaster recovery и операционные процедуры для поддержания стабильности mesh в критически важных окружениях.

### 🏗️ Production-ready архитектура

#### 1. **Схема production deployment**
```
┌─────────────────────────────────────────────────────────────┐
│              Production Service Mesh Architecture          │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Control Plane (HA)                      │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Istiod    │  │   Istiod    │  │   Istiod    │     │ │
│  │  │ (Primary)   │  │ (Replica)   │  │ (Replica)   │     │ │
│  │  │   Zone-A    │  │   Zone-B    │  │   Zone-C    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  │           │               │               │            │ │
│  │           └───────────────┼───────────────┘            │ │
│  │                           │                            │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │              Load Balancer                         ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  Data Plane                            │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │                Production Zone A                   ││ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ ││ │
│  │  │  │ Service A   │  │ Service B   │  │ Service C   │ ││ │
│  │  │  │ + Envoy     │  │ + Envoy     │  │ + Envoy     │ ││ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘ ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │                Production Zone B                   ││ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ ││ │
│  │  │  │ Service D   │  │ Service E   │  │ Service F   │ ││ │
│  │  │  │ + Envoy     │  │ + Envoy     │  │ + Envoy     │ ││ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘ ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │                Production Zone C                   ││ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ ││ │
│  │  │  │ Service G   │  │ Service H   │  │ Service I   │ ││ │
│  │  │  │ + Envoy     │  │ + Envoy     │  │ + Envoy     │ ││ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘ ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Observability Stack                       │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │ Prometheus  │  │   Jaeger    │  │   Grafana   │     │ │
│  │  │ (Metrics)   │  │ (Tracing)   │  │(Dashboards) │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │    Kiali    │  │ AlertManager│  │    Loki     │     │ │
│  │  │ (Topology)  │  │  (Alerts)   │  │   (Logs)    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Production requirements**
```yaml
# Production requirements для service mesh
production_requirements:
  high_availability:
    control_plane:
      - "Multi-zone deployment"
      - "Leader election"
      - "Automatic failover"
      - "Health checks"
    
    data_plane:
      - "Circuit breakers"
      - "Retry policies"
      - "Timeout configuration"
      - "Load balancing"
  
  performance:
    latency:
      - "P99 < 100ms overhead"
      - "Service discovery < 50ms"
      - "Configuration propagation < 5s"
    
    throughput:
      - "Support 10k+ RPS per service"
      - "Efficient resource utilization"
      - "Horizontal scaling"
    
    resource_usage:
      - "Sidecar memory < 100MB"
      - "Control plane CPU < 2 cores"
      - "Network overhead < 5%"
  
  security:
    encryption:
      - "mTLS everywhere"
      - "Certificate rotation"
      - "Strong cipher suites"
    
    authorization:
      - "Zero-trust policies"
      - "RBAC integration"
      - "Audit logging"
    
    compliance:
      - "SOC 2 compliance"
      - "GDPR compliance"
      - "Industry standards"
  
  observability:
    metrics:
      - "Golden signals monitoring"
      - "SLI/SLO tracking"
      - "Custom business metrics"
    
    tracing:
      - "End-to-end tracing"
      - "Performance analysis"
      - "Error tracking"
    
    logging:
      - "Structured logging"
      - "Log aggregation"
      - "Security events"
  
  operational:
    deployment:
      - "Blue-green deployments"
      - "Canary releases"
      - "Rollback procedures"
    
    maintenance:
      - "Zero-downtime upgrades"
      - "Configuration management"
      - "Disaster recovery"
```

### 📊 Примеры из нашего кластера

#### Production deployment команды:
```bash
# Проверка production readiness
kubectl get pods -n istio-system -o wide
kubectl get nodes --show-labels

# Мониторинг production метрик
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Проверка HA конфигурации
kubectl get pods -n istio-system -l app=istiod --show-labels
kubectl describe service istiod -n istio-system
```

### 🚀 Production deployment стратегия

#### 1. **Поэтапная миграция**
```bash
#!/bin/bash
# production-migration.sh

echo "🚀 Production миграция на Service Mesh"

# Переменные
MIGRATION_PHASE=${1:-"phase1"}
NAMESPACE=${2:-"production"}

# Phase 1: Подготовка инфраструктуры
phase1_infrastructure() {
    echo "📋 Phase 1: Подготовка инфраструктуры"
    
    # Установка Istio в production режиме
    cat <<EOF | kubectl apply -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: production
  namespace: istio-system
spec:
  values:
    global:
      meshID: production-mesh
      cluster: hashfoundry-production
      network: production-network
    pilot:
      env:
        PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION: true
        PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY: true
        PILOT_TRACE_SAMPLING: 1.0
    telemetryV2:
      enabled: true
      prometheus:
        configOverride:
          metric_relabeling_configs:
          - source_labels: [__name__]
            regex: 'istio_.*'
            target_label: __tmp_istio_metric
          - source_labels: [__tmp_istio_metric]
            regex: '.*'
            target_label: __name__
            replacement: '${1}'
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        hpaSpec:
          minReplicas: 3
          maxReplicas: 10
          metrics:
          - type: Resource
            resource:
              name: cpu
              target:
                type: Utilization
                averageUtilization: 70
        podDisruptionBudget:
          minAvailable: 2
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1Gi
        hpaSpec:
          minReplicas: 3
          maxReplicas: 10
        service:
          type: LoadBalancer
          loadBalancerSourceRanges:
          - "10.0.0.0/8"
          - "172.16.0.0/12"
          - "192.168.0.0/16"
    egressGateways:
    - name: istio-egressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        hpaSpec:
          minReplicas: 2
          maxReplicas: 5
EOF
    
    # Ожидание готовности
    kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=600s
    
    echo "✅ Phase 1 завершена"
}

# Phase 2: Pilot services
phase2_pilot_services() {
    echo "🧪 Phase 2: Pilot services"
    
    # Выбор pilot сервисов (некритичные)
    local pilot_services=("logging-service" "metrics-collector" "health-checker")
    
    for service in "${pilot_services[@]}"; do
        echo "Миграция pilot сервиса: $service"
        
        # Включение sidecar injection
        kubectl patch deployment $service -n $NAMESPACE -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}'
        
        # Ожидание rollout
        kubectl rollout status deployment/$service -n $NAMESPACE --timeout=300s
        
        # Проверка здоровья
        kubectl get pods -n $NAMESPACE -l app=$service
        
        # Тестирование connectivity
        local pod=$(kubectl get pods -n $NAMESPACE -l app=$service -o jsonpath='{.items[0].metadata.name}')
        kubectl exec $pod -n $NAMESPACE -c istio-proxy -- curl -s http://health-check:8080/health
        
        echo "✅ $service мигрирован"
    done
    
    echo "✅ Phase 2 завершена"
}

# Phase 3: Core services
phase3_core_services() {
    echo "🏗️ Phase 3: Core services"
    
    # Core services (важные, но не критичные)
    local core_services=("user-service" "notification-service" "analytics-service")
    
    for service in "${core_services[@]}"; do
        echo "Миграция core сервиса: $service"
        
        # Canary deployment
        kubectl patch deployment $service -n $NAMESPACE -p '{"spec":{"replicas":6}}'
        kubectl rollout status deployment/$service -n $NAMESPACE
        
        # Включение sidecar для 50% pods
        kubectl patch deployment $service -n $NAMESPACE -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}'
        
        # Постепенное обновление
        kubectl patch deployment $service -n $NAMESPACE -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":"25%","maxUnavailable":"25%"}}}}'
        kubectl rollout status deployment/$service -n $NAMESPACE --timeout=600s
        
        # Мониторинг метрик
        echo "Мониторинг метрик для $service..."
        sleep 60
        
        # Проверка error rate
        local error_rate=$(kubectl exec -n istio-system deployment/prometheus -- \
            promtool query instant "rate(istio_requests_total{destination_service_name=\"$service\",response_code!~\"2.*\"}[5m])" | \
            grep -o '[0-9.]*' | head -1)
        
        if (( $(echo "$error_rate > 0.01" | bc -l) )); then
            echo "❌ Высокий error rate для $service: $error_rate"
            # Rollback
            kubectl rollout undo deployment/$service -n $NAMESPACE
            exit 1
        fi
        
        echo "✅ $service мигрирован успешно"
    done
    
    echo "✅ Phase 3 завершена"
}

# Phase 4: Critical services
phase4_critical_services() {
    echo "🔥 Phase 4: Critical services"
    
    # Critical services (требуют особой осторожности)
    local critical_services=("payment-service" "auth-service" "order-service")
    
    for service in "${critical_services[@]}"; do
        echo "Миграция критичного сервиса: $service"
        
        # Создание backup
        kubectl get deployment $service -n $NAMESPACE -o yaml > /tmp/${service}-backup.yaml
        
        # Blue-green deployment
        kubectl patch deployment $service -n $NAMESPACE -p '{"metadata":{"labels":{"version":"blue"}}}'
        
        # Создание green version с sidecar
        kubectl get deployment $service -n $NAMESPACE -o yaml | \
            sed 's/version: blue/version: green/g' | \
            sed 's/name: '$service'/name: '$service'-green/g' | \
            kubectl apply -f -
        
        kubectl patch deployment ${service}-green -n $NAMESPACE -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}'
        
        # Ожидание готовности green
        kubectl rollout status deployment/${service}-green -n $NAMESPACE --timeout=600s
        
        # Настройка traffic splitting
        cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${service}-traffic-split
  namespace: $NAMESPACE
spec:
  hosts:
  - $service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: $service
        subset: green
  - route:
    - destination:
        host: $service
        subset: blue
      weight: 90
    - destination:
        host: $service
        subset: green
      weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: ${service}-destination
  namespace: $NAMESPACE
spec:
  host: $service
  subsets:
  - name: blue
    labels:
      version: blue
  - name: green
    labels:
      version: green
EOF
        
        # Мониторинг в течение 30 минут
        echo "Мониторинг $service в течение 30 минут..."
        for i in {1..30}; do
            sleep 60
            
            # Проверка метрик
            local green_error_rate=$(kubectl exec -n istio-system deployment/prometheus -- \
                promtool query instant "rate(istio_requests_total{destination_service_name=\"$service\",destination_version=\"green\",response_code!~\"2.*\"}[5m])")
            
            local green_latency=$(kubectl exec -n istio-system deployment/prometheus -- \
                promtool query instant "histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket{destination_service_name=\"$service\",destination_version=\"green\"}[5m]))")
            
            echo "Минута $i: Error rate: $green_error_rate, P95 latency: $green_latency"
        done
        
        # Переключение на 100% green
        kubectl patch virtualservice ${service}-traffic-split -n $NAMESPACE --type='merge' -p='{"spec":{"http":[{"route":[{"destination":{"host":"'$service'","subset":"green"},"weight":100}]}]}}'
        
        # Удаление blue version
        kubectl delete deployment $service -n $NAMESPACE
        kubectl patch deployment ${service}-green -n $NAMESPACE -p '{"metadata":{"name":"'$service'"}}'
        
        echo "✅ $service мигрирован на service mesh"
    done
    
    echo "✅ Phase 4 завершена"
}

# Phase 5: Финализация
phase5_finalization() {
    echo "🎯 Phase 5: Финализация"
    
    # Включение namespace-wide injection
    kubectl label namespace $NAMESPACE istio-injection=enabled --overwrite
    
    # Настройка production policies
    cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: $NAMESPACE
spec:
  mtls:
    mode: STRICT
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default
  namespace: $NAMESPACE
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
    
    # Настройка observability
    cat <<EOF | kubectl apply -f -
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: production-telemetry
  namespace: $NAMESPACE
spec:
  metrics:
  - providers:
    - name: prometheus
  tracing:
  - providers:
    - name: jaeger
  accessLogging:
  - providers:
    - name: otel
EOF
    
    echo "✅ Phase 5 завершена"
    echo "🎉 Production миграция завершена успешно!"
}

# Основная логика
case "$MIGRATION_PHASE" in
    phase1)
        phase1_infrastructure
        ;;
    phase2)
        phase2_pilot_services
        ;;
    phase3)
        phase3_core_services
        ;;
    phase4)
        phase4_critical_services
        ;;
    phase5)
        phase5_finalization
        ;;
    all)
        phase1_infrastructure
        phase2_pilot_services
        phase3_core_services
        phase4_critical_services
        phase5_finalization
        ;;
    *)
        echo "Использование: $0 {phase1|phase2|phase3|phase4|phase5|all} [namespace]"
        exit 1
        ;;
esac
```

### 📊 Production мониторинг

#### 1. **SLI/SLO конфигурация**
```yaml
# production-slos.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: production-slos
  namespace: istio-system
spec:
  groups:
  - name: sli-slo.rules
    interval: 30s
    rules:
    # Availability SLI
    - record: sli:availability:rate5m
      expr: |
        sum(rate(istio_requests_total{response_code!~"5.*"}[5m])) by (destination_service_name, destination_namespace)
        /
        sum(rate(istio_requests_total[5m])) by (destination_service_name, destination_namespace)
    
    # Latency SLI
    - record: sli:latency:p99:5m
      expr: |
        histogram_quantile(0.99,
          sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (destination_service_name, destination_namespace, le)
        )
    
    # Throughput SLI
    - record: sli:throughput:rate5m
      expr: |
        sum(rate(istio_requests_total[5m])) by (destination_service_name, destination_namespace)
    
    # Error Budget Alerts
    - alert: SLOAvailabilityBreach
      expr: |
        (
          sli:availability:rate5m < 0.999
        ) and (
          sli:availability:rate5m > 0
        )
      for: 2m
      labels:
        severity: critical
        slo: availability
      annotations:
        summary: "Service availability SLO breach"
        description: "Service {{ $labels.destination_service_name }} availability is {{ $value | humanizePercentage }}, below 99.9% SLO"
    
    - alert: SLOLatencyBreach
      expr: |
        sli:latency:p99:5m > 100
      for: 5m
      labels:
        severity: warning
        slo: latency
      annotations:
        summary: "Service latency SLO breach"
        description: "Service {{ $labels.destination_service_name }} P99 latency is {{ $value }}ms, above 100ms SLO"
    
    # Error Budget Burn Rate
    - alert: ErrorBudgetBurnRateHigh
      expr: |
        (
          1 - sli:availability:rate5m
        ) > (
          (1 - 0.999) * 14.4  # 14.4x burn rate for 2% budget in 1 hour
        )
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "High error budget burn rate"
        description: "Service {{ $labels.destination_service_name }} is burning error budget at {{ $value | humanizePercentage }} rate"
```

### 🔒 Production security

#### 1. **Security hardening**
```yaml
# production-security.yaml

# Strict mTLS для всего mesh
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
# Authorization policies
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Deny all by default
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend-service
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/frontend-service"]
  - to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
  - when:
    - key: source.ip
      values: ["10.0.0.0/8"]
---
# Network policies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: istio-mesh-policy
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    - namespaceSelector:
        matchLabels:
          name: production
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    - namespaceSelector:
        matchLabels:
          name: production
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
---
# Security scanning
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: security-scanning
  namespace: production
spec:
  selector:
    matchLabels:
      security-scan: "enabled"
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/security/sa/scanner"]
  - to:
    - operation:
        methods: ["GET"]
        paths: ["/health", "/metrics"]
```

### 🔧 Операционные процедуры

#### 1. **Disaster recovery план**
```bash
#!/bin/bash
# disaster-recovery.sh

echo "🚨 Service Mesh Disaster Recovery"

# Backup control plane
backup_control_plane() {
    echo "💾 Backup control plane конфигурации"
    
    local backup_dir="/backup/istio-$(date +%Y%m%d-%H%M%S)"
    mkdir -p $backup_dir
    
    # Backup Istio configuration
    kubectl get istiooperator -n istio-system -o yaml > $backup_dir/istio-operator.yaml
    kubectl get configmap istio -n istio-system -o yaml > $backup_dir/istio-config.yaml
    
    # Backup certificates
    kubectl get secret cacerts -n istio-system -o yaml > $backup_dir/cacerts.yaml
    
    # Backup custom resources
    kubectl get virtualservices --all-namespaces -o yaml > $backup_dir/virtualservices.yaml
    kubectl get destinationrules --all-namespaces -o yaml > $backup_dir/destinationrules.yaml
    kubectl get gateways --all-namespaces -o yaml > $backup_dir/gateways.yaml
    kubectl get peerauthentications --all-namespaces -o yaml > $backup_dir/peerauthentications.yaml
    kubectl get authorizationpolicies --all-namespaces -o yaml > $backup_dir/authorizationpolicies.yaml
    
    echo "✅ Backup сохранен в $backup_dir"
}

# Restore control plane
restore_control_plane() {
    local backup_dir=$1
    
    echo "🔄 Восстановление control plane из $backup_dir"
    
    # Restore certificates first
    kubectl apply -f $backup_dir/cacerts.yaml
    
    # Restore Istio operator
    kubectl apply -f $backup_dir/istio-operator.yaml
    
    # Wait for control plane
    kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=600s
    
    # Restore configuration
    kubectl apply -f $backup_dir/istio-config.yaml
    
    # Restore custom resources
    kubectl apply -f $backup_dir/virtualservices.yaml
    kubectl apply -f $backup_dir/destinationrules.yaml
    kubectl apply -f $backup_dir/gateways.yaml
    kubectl apply -f $backup_dir/peerauthentications.yaml
    kubectl apply -f $backup_dir/authorizationpolicies.yaml
    
    echo "✅ Control plane восстановлен"
}

# Emergency procedures
emergency_procedures() {
    echo "🚨 Выполнение emergency процедур"
    
    # Disable sidecar injection
    kubectl label namespace production istio-injection-
    
    # Remove problematic configurations
    kubectl delete virtualservices --all -n production
    kubectl delete destinationrules --all -n production
    
    # Restart workloads without sidecars
    kubectl rollout restart deployment --all -n production
    
    echo "✅ Emergency процедуры выполнены"
}

case "$1" in
    backup)
        backup_control_plane
        ;;
    restore)
        restore_control_plane $2
        ;;
    emergency)
        emergency_procedures
        ;;
    *)
        echo "Использование: $0 {backup|restore|emergency} [backup-dir]"
        exit 1
        ;;
esac
```

Service mesh в production требует комплексного подхода к планированию, развертыванию, мониторингу и поддержке для обеспечения надежности, безопасности и производительности критически важных микросервисных приложений.
