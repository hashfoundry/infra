# 180. Service mesh в production

## 🎯 **Что такое service mesh в production?**

**Service mesh в production** - это enterprise-grade развертывание с высокой доступностью, автоматическим масштабированием, comprehensive мониторингом, security hardening и disaster recovery процедурами через поэтапную миграцию, canary deployments, SLI/SLO мониторинг и операционные runbooks для обеспечения надежности критически важных микросервисных приложений.

## 🏗️ **Основные требования production:**

### **1. High Availability**
- Multi-zone control plane deployment
- Automatic failover mechanisms
- Circuit breakers и retry policies
- Load balancing strategies

### **2. Performance & Scalability**
- P99 latency < 100ms overhead
- Support 10k+ RPS per service
- Horizontal auto-scaling
- Resource optimization

### **3. Security & Compliance**
- mTLS everywhere
- Zero-trust policies
- Audit logging
- Compliance standards (SOC 2, GDPR)

### **4. Observability**
- Golden signals monitoring
- SLI/SLO tracking
- End-to-end tracing
- Comprehensive alerting

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Production-ready Istio deployment:**
```bash
#!/bin/bash
# deploy-production-istio.sh

echo "🚀 Production Istio Deployment"

# Создание production IstioOperator
kubectl apply -f - << EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: production
  namespace: istio-system
spec:
  values:
    global:
      meshID: hashfoundry-production-mesh
      cluster: hashfoundry-production
      network: production-network
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1Gi
    pilot:
      env:
        PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION: true
        PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY: true
        PILOT_TRACE_SAMPLING: 1.0
        PILOT_ENABLE_STATUS: true
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
          - type: Resource
            resource:
              name: memory
              target:
                type: Utilization
                averageUtilization: 80
        podDisruptionBudget:
          minAvailable: 2
        env:
          - name: PILOT_ENABLE_STATUS
            value: "true"
          - name: PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION
            value: "true"
        nodeSelector:
          node-role: control-plane
        tolerations:
        - key: node-role
          operator: Equal
          value: control-plane
          effect: NoSchedule
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
          metrics:
          - type: Resource
            resource:
              name: cpu
              target:
                type: Utilization
                averageUtilization: 70
        podDisruptionBudget:
          minAvailable: 2
        service:
          type: LoadBalancer
          loadBalancerSourceRanges:
          - "10.0.0.0/8"
          - "172.16.0.0/12"
          - "192.168.0.0/16"
        nodeSelector:
          node-role: worker
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
        podDisruptionBudget:
          minAvailable: 1
        nodeSelector:
          node-role: worker
EOF

# Ожидание готовности
kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=600s

echo "✅ Production Istio развернут"
```

### **2. Поэтапная миграция на service mesh:**
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
    
    # Создание production namespace с labels
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | \
    kubectl apply -f -
    
    kubectl label namespace $NAMESPACE \
        environment=production \
        istio-injection=enabled \
        --overwrite
    
    # Настройка network policies
    kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: istio-mesh-policy
  namespace: $NAMESPACE
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
          environment: production
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    - namespaceSelector:
        matchLabels:
          environment: production
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
EOF
    
    # Настройка default security policies
    kubectl apply -f - << EOF
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
    
    echo "✅ Phase 1 завершена"
}

# Phase 2: Pilot services (некритичные)
phase2_pilot_services() {
    echo "🧪 Phase 2: Pilot services"
    
    local pilot_services=("logging-service" "metrics-collector" "health-checker")
    
    for service in "${pilot_services[@]}"; do
        echo "Миграция pilot сервиса: $service"
        
        # Проверка существования deployment
        if ! kubectl get deployment $service -n $NAMESPACE >/dev/null 2>&1; then
            echo "⚠️ Deployment $service не найден, пропускаем"
            continue
        fi
        
        # Создание backup конфигурации
        kubectl get deployment $service -n $NAMESPACE -o yaml > /tmp/${service}-backup-$(date +%s).yaml
        
        # Включение sidecar injection
        kubectl patch deployment $service -n $NAMESPACE -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}'
        
        # Ожидание rollout
        kubectl rollout status deployment/$service -n $NAMESPACE --timeout=300s
        
        # Проверка здоровья
        local ready_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
        local desired_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}')
        
        if [ "$ready_replicas" = "$desired_replicas" ]; then
            echo "✅ $service мигрирован успешно"
        else
            echo "❌ Проблемы с миграцией $service"
            kubectl describe deployment $service -n $NAMESPACE
        fi
    done
    
    echo "✅ Phase 2 завершена"
}

# Phase 3: Core services (важные)
phase3_core_services() {
    echo "🏗️ Phase 3: Core services"
    
    local core_services=("user-service" "notification-service" "analytics-service")
    
    for service in "${core_services[@]}"; do
        echo "Миграция core сервиса: $service"
        
        if ! kubectl get deployment $service -n $NAMESPACE >/dev/null 2>&1; then
            echo "⚠️ Deployment $service не найден, пропускаем"
            continue
        fi
        
        # Создание backup
        kubectl get deployment $service -n $NAMESPACE -o yaml > /tmp/${service}-backup-$(date +%s).yaml
        
        # Увеличение replicas для canary
        local current_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}')
        local canary_replicas=$((current_replicas * 2))
        
        kubectl scale deployment $service -n $NAMESPACE --replicas=$canary_replicas
        kubectl rollout status deployment/$service -n $NAMESPACE
        
        # Включение sidecar для новых pods
        kubectl patch deployment $service -n $NAMESPACE -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}'
        
        # Постепенное обновление
        kubectl patch deployment $service -n $NAMESPACE -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":"25%","maxUnavailable":"25%"}}}}'
        kubectl rollout status deployment/$service -n $NAMESPACE --timeout=600s
        
        # Мониторинг метрик в течение 5 минут
        echo "Мониторинг метрик для $service..."
        for i in {1..5}; do
            sleep 60
            echo "Минута $i: Проверка метрик..."
            
            # Проверка error rate через kubectl (если Prometheus недоступен)
            local pod_count=$(kubectl get pods -n $NAMESPACE -l app=$service --field-selector=status.phase=Running | wc -l)
            echo "Running pods: $((pod_count - 1))"  # -1 для header
        done
        
        # Возврат к исходному количеству replicas
        kubectl scale deployment $service -n $NAMESPACE --replicas=$current_replicas
        
        echo "✅ $service мигрирован успешно"
    done
    
    echo "✅ Phase 3 завершена"
}

# Phase 4: Critical services (критичные)
phase4_critical_services() {
    echo "🔥 Phase 4: Critical services"
    
    local critical_services=("payment-service" "auth-service" "order-service")
    
    for service in "${critical_services[@]}"; do
        echo "Миграция критичного сервиса: $service"
        
        if ! kubectl get deployment $service -n $NAMESPACE >/dev/null 2>&1; then
            echo "⚠️ Deployment $service не найден, создаем demo deployment"
            
            # Создание demo deployment для демонстрации
            kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $service
  namespace: $NAMESPACE
  labels:
    app: $service
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $service
      version: blue
  template:
    metadata:
      labels:
        app: $service
        version: blue
    spec:
      containers:
      - name: $service
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "$service"
        - name: VERSION
          value: "blue"
---
apiVersion: v1
kind: Service
metadata:
  name: $service
  namespace: $NAMESPACE
spec:
  selector:
    app: $service
  ports:
  - port: 80
    targetPort: 80
EOF
            
            kubectl rollout status deployment/$service -n $NAMESPACE
        fi
        
        # Создание backup
        kubectl get deployment $service -n $NAMESPACE -o yaml > /tmp/${service}-backup-$(date +%s).yaml
        
        # Blue-green deployment
        kubectl label deployment $service -n $NAMESPACE version=blue --overwrite
        
        # Создание green version с sidecar
        kubectl get deployment $service -n $NAMESPACE -o yaml | \
            sed 's/version: blue/version: green/g' | \
            sed 's/name: '$service'/name: '$service'-green/g' | \
            kubectl apply -f -
        
        kubectl patch deployment ${service}-green -n $NAMESPACE -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"},"labels":{"version":"green"}}}}}'
        
        # Ожидание готовности green
        kubectl rollout status deployment/${service}-green -n $NAMESPACE --timeout=600s
        
        # Настройка traffic splitting
        kubectl apply -f - << EOF
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
        
        # Мониторинг в течение 10 минут
        echo "Мониторинг $service в течение 10 минут..."
        for i in {1..10}; do
            sleep 60
            
            # Проверка статуса pods
            local green_pods=$(kubectl get pods -n $NAMESPACE -l app=$service,version=green --field-selector=status.phase=Running | wc -l)
            local blue_pods=$(kubectl get pods -n $NAMESPACE -l app=$service,version=blue --field-selector=status.phase=Running | wc -l)
            
            echo "Минута $i: Green pods: $((green_pods - 1)), Blue pods: $((blue_pods - 1))"
        done
        
        # Переключение на 100% green
        kubectl patch virtualservice ${service}-traffic-split -n $NAMESPACE --type='merge' -p='{"spec":{"http":[{"route":[{"destination":{"host":"'$service'","subset":"green"},"weight":100}]}]}}'
        
        # Ожидание 2 минуты для стабилизации
        sleep 120
        
        # Удаление blue version
        kubectl delete deployment $service -n $NAMESPACE
        
        # Переименование green в основной
        kubectl patch deployment ${service}-green -n $NAMESPACE -p='{"metadata":{"name":"'$service'"}}'
        kubectl patch deployment ${service}-green -n $NAMESPACE -p='{"spec":{"template":{"metadata":{"labels":{"version":"v1"}}}}}'
        
        # Очистка traffic splitting
        kubectl delete virtualservice ${service}-traffic-split -n $NAMESPACE
        kubectl delete destinationrule ${service}-destination -n $NAMESPACE
        
        echo "✅ $service мигрирован на service mesh"
    done
    
    echo "✅ Phase 4 завершена"
}

# Phase 5: Финализация и мониторинг
phase5_finalization() {
    echo "🎯 Phase 5: Финализация"
    
    # Настройка production telemetry
    kubectl apply -f - << EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: production-telemetry
  namespace: $NAMESPACE
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
      environment:
        literal:
          value: "production"
  accessLogging:
  - providers:
    - name: otel
  - format:
      text: |
        [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
        %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT%
        %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%"
        "%REQ(USER-AGENT)%" "%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
        environment="production"
EOF
    
    # Проверка финального статуса
    echo "=== Финальная проверка ==="
    kubectl get pods -n $NAMESPACE
    kubectl get virtualservices -n $NAMESPACE
    kubectl get destinationrules -n $NAMESPACE
    kubectl get peerauthentications -n $NAMESPACE
    
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
        echo ""
        echo "Phases:"
        echo "  phase1 - Подготовка инфраструктуры"
        echo "  phase2 - Pilot services (некритичные)"
        echo "  phase3 - Core services (важные)"
        echo "  phase4 - Critical services (критичные)"
        echo "  phase5 - Финализация"
        echo "  all    - Все фазы"
        exit 1
        ;;
esac
```

### **3. Production SLI/SLO мониторинг:**
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
    
    # Latency SLI P95
    - record: sli:latency:p95:5m
      expr: |
        histogram_quantile(0.95,
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
    
    - alert: ErrorBudgetBurnRateMedium
      expr: |
        (
          1 - sli:availability:rate5m
        ) > (
          (1 - 0.999) * 6  # 6x burn rate for 5% budget in 1 hour
        )
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Medium error budget burn rate"
        description: "Service {{ $labels.destination_service_name }} is burning error budget at {{ $value | humanizePercentage }} rate"
```

### **4. Production security hardening:**
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
# Default deny-all authorization policy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Deny all by default
---
# Allow internal service communication
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-internal-services
  namespace: production
spec:
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/*"]
  - to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
  - when:
    - key: source.namespace
      values: ["production"]
---
# Allow ingress gateway
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ingress-gateway
  namespace: production
spec:
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
---
# Rate limiting
apiVersion: networking.istio.io/v1beta1
kind: EnvoyFilter
metadata:
  name: rate-limit-filter
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
        name: envoy.filters.http.local_ratelimit
        typed_config:
          "@type": type.googleapis.com/udpa.type.v1.TypedStruct
          type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
          value:
            stat_prefix: rate_limiter
            token_bucket:
              max_tokens: 1000
              tokens_per_fill: 1000
              fill_interval: 60s
            filter_enabled:
              runtime_key: rate_limit_enabled
              default_value:
                numerator: 100
                denominator: HUNDRED
            filter_enforced:
              runtime_key: rate_limit_enforced
              default_value:
                numerator: 100
                denominator: HUNDRED
---
# Security scanning policy
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
        paths: ["/health", "/metrics", "/ready"]
```

## 🚨 **Disaster Recovery процедуры:**

### **1. Backup и restore скрипт:**
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
    kubectl get secret cacerts -n istio-system -o yaml > $backup_dir/cacerts.yaml 2>/dev/null || echo "No custom cacerts found"
    
    # Backup custom resources
    kubectl get virtualservices --all-namespaces -o yaml > $backup_dir/virtualservices.yaml
    kubectl get destinationrules --all-namespaces -o yaml > $backup_dir/destinationrules.yaml
    kubectl get gateways --all-namespaces -o yaml > $backup_dir/gateways.yaml
    kubectl get peerauthentications --all-namespaces -o yaml > $backup_dir/peerauthentications.yaml
    kubectl get authorizationpolicies --all-namespaces -o yaml > $backup_dir/authorizationpolicies.yaml
    kubectl get serviceentries --all-namespaces -o yaml > $backup_dir/serviceentries.yaml
    kubectl get envoyfilters --all-namespaces -o yaml > $backup_dir/envoyfilters.yaml
    
    # Backup telemetry configuration
    kubectl get telemetry --all-namespaces -o yaml > $backup_dir/telemetry.yaml 2>/dev/null || echo "No telemetry resources found"
    
    # Create backup manifest
    cat > $backup_dir/backup-manifest.txt << EOF
Istio Backup Created: $(date)
Cluster: $(kubectl config current-context)
Istio Version: $(istioctl version --short 2>/dev/null || echo "Unknown")

Files included:
- istio-operator.yaml
- istio-config.yaml
- cacerts.yaml
- virtualservices.yaml
- destinationrules.yaml
- gateways.yaml
- peerauthentications.yaml
- authorizationpolicies.yaml
- serviceentries.yaml
- envoyfilters.yaml
- telemetry.yaml
EOF
    
    echo "✅ Backup сохранен в $backup_dir"
    echo "📋 Manifest: $backup_dir/backup-manifest.txt"
}

# Restore control plane
restore_control_plane() {
    local backup_dir=$1
    
    if [ -z "$backup_dir" ] || [ ! -d "$backup_dir" ]; then
        echo "❌ Backup directory не найден: $backup_dir"
        exit 1
    fi
    
    echo "🔄 Восстановление control plane из $backup_dir"
    
    # Проверка backup manifest
    if [ -f "$backup_dir/backup-manifest.txt" ]; then
        echo "📋 Backup manifest:"
        cat $backup_dir/backup-manifest.txt
        echo ""
    fi
    
    # Restore certificates first (if exists)
    if [ -f "$backup_dir/cacerts.yaml" ]; then
        echo "Восстановление certificates..."
        kubectl apply -f $backup_dir/cacerts.yaml
    fi
    
    # Restore Istio Operator
    if [ -f "$backup_dir/istio-operator.yaml" ]; then
        echo "Восстановление IstioOperator..."
        kubectl apply -f $backup_dir/istio-operator.yaml
        kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=600s
    fi
    
    # Restore configuration
    if [ -f "$backup_dir/istio-config.yaml" ]; then
        echo "Восстановление Istio config..."
        kubectl apply -f $backup_dir/istio-config.yaml
    fi
    
    # Restore custom resources
    echo "Восстановление custom resources..."
    for resource in virtualservices destinationrules gateways peerauthentications authorizationpolicies serviceentries envoyfilters telemetry; do
        if [ -f "$backup_dir/${resource}.yaml" ]; then
            echo "Восстановление $resource..."
            kubectl apply -f $backup_dir/${resource}.yaml
        fi
    done
    
    echo "✅ Восстановление завершено"
}

# Emergency rollback
emergency_rollback() {
    echo "🚨 Emergency rollback"
    
    # Disable sidecar injection
    kubectl label namespace production istio-injection-
    
    # Remove Istio resources
    kubectl delete virtualservices --all -n production
    kubectl delete destinationrules --all -n production
    kubectl delete peerauthentications --all -n production
    kubectl delete authorizationpolicies --all -n production
    
    # Restart deployments to remove sidecars
    kubectl rollout restart deployment --all -n production
    
    echo "✅ Emergency rollback завершен"
}

# Основная логика
case "$1" in
    backup)
        backup_control_plane
        ;;
    restore)
        restore_control_plane $2
        ;;
    rollback)
        emergency_rollback
        ;;
    *)
        echo "Использование: $0 {backup|restore|rollback} [backup_dir]"
        exit 1
        ;;
esac
```

## 📈 **Мониторинг production service mesh:**

### **1. Production health checks:**
```bash
# Проверка health всех компонентов
kubectl get pods -n istio-system
kubectl get pods -n production

# Proxy status
istioctl proxy-status

# Configuration analysis
istioctl analyze --all-namespaces

# Performance metrics
kubectl top pods -n istio-system --containers
kubectl top pods -n production --containers
```

### **2. SLI/SLO dashboard:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Key SLI metrics:
# - Availability: istio_requests_total success rate
# - Latency: istio_request_duration_milliseconds P99
# - Throughput: istio_requests_total rate
# - Error rate: istio_requests_total 5xx rate
```

## 🏭 **Production в вашем HA кластере:**

### **1. ArgoCD в production mesh:**
```bash
# ArgoCD с production настройками
kubectl get pods -n argocd -o wide
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server

# Production VirtualService для ArgoCD
kubectl get virtualservice -n argocd
kubectl describe virtualservice argocd-server -n argocd

# mTLS для ArgoCD
istioctl authn tls-check argocd-server.argocd.svc.cluster.local
```

### **2. Monitoring stack в production:**
```bash
# Prometheus с sidecars
kubectl get pods -n monitoring -l app=prometheus-server
kubectl exec -n monitoring deployment/prometheus-server -c istio-proxy -- pilot-agent request GET stats | grep istio_requests

# Grafana с sidecars
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl exec -n monitoring deployment/grafana -c istio-proxy -- pilot-agent request GET stats | grep istio_requests
```

### **3. Production traffic policies:**
```bash
# Circuit breaker для критичных сервисов
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: argocd-circuit-breaker
  namespace: argocd
spec:
  host: argocd-server
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
EOF

# Retry policy
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd-retry
  namespace: argocd
spec:
  hosts:
  - argocd-server
  http:
  - route:
    - destination:
        host: argocd-server
    retries:
      attempts: 3
      perTryTimeout: 10s
      retryOn: 5xx,gateway-error,connect-failure,refused-stream
EOF
```

## 🚨 **Production troubleshooting:**

### **1. Common production issues:**
```bash
# High latency
kubectl exec -n production deployment/app -c istio-proxy -- pilot-agent request GET stats | grep duration

# Certificate expiration
kubectl exec -n production deployment/app -c istio-proxy -- openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -noout -dates

# Configuration conflicts
istioctl analyze -n production

# Resource exhaustion
kubectl top pods -n istio-system --containers
kubectl describe pod -n istio-system -l app=istiod
```

### **2. Production debugging:**
```bash
# Enable debug logging
kubectl patch deployment istiod -n istio-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"discovery","args":["discovery","--log_output_level=debug"]}]}}}}'

# Collect debug info
istioctl bug-report --include ns1,ns2

# Proxy debug
kubectl exec -n production deployment/app -c istio-proxy -- pilot-agent request GET config_dump > debug-config.json
```

## 🎯 **Production architecture diagram:**

```
┌─────────────────────────────────────────────────────────────┐
│                Production Service Mesh                     │
├─────────────────────────────────────────────────────────────┤
│  Load Balancer (DigitalOcean)                              │
│  ├── External Traffic                                      │
│  └── SSL Termination                                       │
├─────────────────────────────────────────────────────────────┤
│  Istio Ingress Gateway (HA)                                │
│  ├── 3+ replicas across zones                              │
│  ├── Auto-scaling (3-10 pods)                              │
│  └── PodDisruptionBudget                                   │
├─────────────────────────────────────────────────────────────┤
│  Control Plane (istio-system)                              │
│  ├── Istiod (HA: 3+ replicas)                              │
│  │   ├── Service Discovery                                 │
│  │   ├── Certificate Authority                             │
│  │   └── Configuration Management                          │
│  └── Monitoring Integration                                │
├─────────────────────────────────────────────────────────────┤
│  Data Plane (Production Workloads)                         │
│  ├── ArgoCD (GitOps)                                       │
│  │   ├── Server pods + sidecars                            │
│  │   ├── mTLS enforcement                                  │
│  │   └── Circuit breakers                                  │
│  ├── Monitoring Stack                                      │
│  │   ├── Prometheus + sidecars                             │
│  │   ├── Grafana + sidecars                                │
│  │   └── SLI/SLO tracking                                  │
│  └── Application Services                                  │
│      ├── Microservices + sidecars                          │
│      ├── Zero-trust policies                               │
│      └── Observability                                     │
├─────────────────────────────────────────────────────────────┤
│  Security & Compliance                                      │
│  ├── mTLS everywhere (STRICT mode)                         │
│  ├── Authorization policies                                │
│  ├── Rate limiting                                         │
│  └── Audit logging                                         │
├─────────────────────────────────────────────────────────────┤
│  Disaster Recovery                                          │
│  ├── Configuration backups                                 │
│  ├── Certificate backups                                   │
│  ├── Emergency rollback                                    │
│  └── Multi-zone deployment                                 │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Production configuration:**

### **1. Resource optimization:**
```bash
# Istiod production resources
kubectl patch deployment istiod -n istio-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"discovery","resources":{"requests":{"cpu":"500m","memory":"2Gi"},"limits":{"cpu":"2000m","memory":"4Gi"}}}]}}}}'

# Sidecar resource limits
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-sidecar-injector
  namespace: istio-system
data:
  values: |
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1Gi
EOF
```

### **2. Performance tuning:**
```bash
# Pilot performance settings
kubectl patch deployment istiod -n istio-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"discovery","env":[{"name":"PILOT_PUSH_THROTTLE","value":"100"},{"name":"PILOT_DEBOUNCE_AFTER","value":"100ms"},{"name":"PILOT_DEBOUNCE_MAX","value":"10s"}]}]}}}}'

# Envoy performance
kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1beta1
kind: EnvoyFilter
metadata:
  name: performance-tuning
  namespace: istio-system
spec:
  configPatches:
  - applyTo: BOOTSTRAP
    patch:
      operation: MERGE
      value:
        stats_config:
          stats_tags:
          - tag_name: "custom_tag"
            regex: "^custom_metric_(.+)$"
EOF
```

## 🎯 **Best Practices для production:**

### **1. Deployment:**
- Используйте поэтапную миграцию
- Применяйте canary deployments
- Настройте proper health checks
- Мониторьте SLI/SLO метрики

### **2. Security:**
- Включите STRICT mTLS
- Применяйте zero-trust policies
- Настройте rate limiting
- Ведите audit logs

### **3. Operations:**
- Автоматизируйте backup процедуры
- Подготовьте emergency runbooks
- Мониторьте resource usage
- Планируйте capacity

### **4. Monitoring:**
- Настройте comprehensive alerting
- Отслеживайте golden signals
- Используйте distributed tracing
- Анализируйте error budgets

**Production service mesh требует тщательного планирования, мониторинга и операционной готовности!**
