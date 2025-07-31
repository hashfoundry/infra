# 171. Что такое service mesh и зачем он нужен?

## 🎯 **Что такое service mesh?**

**Service mesh** — это инфраструктурный слой для управления коммуникацией между микросервисами, обеспечивающий security через mTLS, observability через distributed tracing, traffic management через intelligent routing, reliability через circuit breakers, policy enforcement через RBAC и automated certificate management без изменения кода приложений через sidecar proxy pattern.

## 🏗️ **Основные компоненты service mesh:**

### **1. Data Plane (Sidecar Proxies)**
- **Envoy Proxy**: High-performance proxy для traffic interception
- **Traffic Management**: Load balancing, circuit breaking, retries
- **Security**: mTLS termination, certificate management
- **Observability**: Metrics collection, distributed tracing

### **2. Control Plane**
- **Configuration Management**: Service discovery, routing rules
- **Certificate Authority**: Automated certificate lifecycle
- **Policy Enforcement**: Security policies, access control
- **Telemetry Collection**: Metrics aggregation, monitoring

### **3. Service Mesh Features**
- **Zero-trust Security**: Identity-based authentication
- **Traffic Splitting**: Canary deployments, A/B testing
- **Fault Injection**: Chaos engineering, resilience testing
- **Rate Limiting**: Traffic throttling, DDoS protection

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей service mesh готовности:**
```bash
# Проверка наличия Istio в кластере
kubectl get namespace istio-system
kubectl get pods -n istio-system -o wide

# Анализ sidecar injection status
kubectl get namespace -L istio-injection
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}' | grep envoy

# Проверка service mesh конфигурации
kubectl get virtualservices,destinationrules,gateways,peerauthentications,authorizationpolicies --all-namespaces
istioctl proxy-status

# Анализ mTLS статуса
istioctl authn tls-check --all
```

### **2. Диагностика service mesh проблем:**
```bash
# Проверка sidecar proxy конфигурации
kubectl exec deployment/argocd-server -n argocd -c istio-proxy -- pilot-agent request GET config_dump | jq '.configs[0].dynamic_listeners'

# Анализ traffic flow между сервисами
kubectl exec deployment/prometheus-server -n monitoring -c istio-proxy -- pilot-agent request GET stats | grep -E "(inbound|outbound).*cx_"

# Проверка certificate management
kubectl exec deployment/grafana -n monitoring -c istio-proxy -- pilot-agent request GET certs

# Диагностика connectivity issues
istioctl proxy-config cluster deployment/argocd-server.argocd
istioctl proxy-config endpoint deployment/argocd-server.argocd
```

### **3. Мониторинг service mesh метрик:**
```bash
# Проверка control plane health
kubectl get pods -n istio-system -l app=istiod
kubectl top pods -n istio-system

# Анализ sidecar resource usage
kubectl top pods --all-namespaces --containers | grep istio-proxy | head -10

# Проверка traffic metrics
kubectl exec deployment/prometheus-server -n monitoring -c istio-proxy -- pilot-agent request GET stats/prometheus | grep istio_request_total
```

## 🔄 **Демонстрация comprehensive service mesh deployment:**

### **1. Создание production-ready Istio installation:**
```bash
# Создать скрипт istio-production-setup.sh
cat << 'EOF' > istio-production-setup.sh
#!/bin/bash

echo "🚀 Production-Ready Istio Service Mesh Setup"
echo "============================================"

# Настройка переменных
ISTIO_VERSION="1.20.0"
CLUSTER_NAME="hashfoundry-ha"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SETUP_LOG="/var/log/istio-setup-$TIMESTAMP.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $SETUP_LOG
}

# Функция скачивания и установки Istio
download_and_install_istio() {
    log "📦 Скачивание Istio $ISTIO_VERSION"
    
    # Скачивание Istio
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
    cd istio-$ISTIO_VERSION
    export PATH=$PWD/bin:$PATH
    
    # Предварительная проверка кластера
    log "🔍 Предварительная проверка кластера"
    istioctl x precheck
    
    if [ $? -ne 0 ]; then
        log "❌ Кластер не готов для Istio"
        return 1
    fi
    
    log "✅ Istio скачан и кластер готов"
}

# Функция создания production configuration
create_production_config() {
    log "⚙️ Создание production конфигурации"
    
    # Создание IstioOperator для production
    cat > istio-production-config.yaml << ISTIO_CONFIG_EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: production-istio
spec:
  values:
    defaultRevision: default
    global:
      meshID: mesh1
      network: network1
      cluster: $CLUSTER_NAME
      # Production-ready settings
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        # Security settings
        privileged: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 1337
      # Telemetry settings
      defaultConfigVisibilitySettings:
        - "REGISTRY"
        - "WORKLOAD"
        - "PILOT"
      # Logging settings
      logging:
        level: "default:info"
      # Tracing settings
      tracer:
        zipkin:
          address: jaeger-collector.istio-system:9411
    pilot:
      # High availability
      env:
        PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION: true
        PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY: true
        PILOT_TRACE_SAMPLING: 1.0
      # Resource settings
      resources:
        requests:
          cpu: 500m
          memory: 2048Mi
        limits:
          cpu: 1000m
          memory: 4096Mi
      # Scaling settings
      autoscaleEnabled: true
      autoscaleMin: 2
      autoscaleMax: 5
      cpu:
        targetAverageUtilization: 80
    gateways:
      istio-ingressgateway:
        # High availability
        autoscaleEnabled: true
        autoscaleMin: 2
        autoscaleMax: 5
        # Resource settings
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1024Mi
        # Service settings
        type: LoadBalancer
        ports:
        - port: 15021
          targetPort: 15021
          name: status-port
        - port: 80
          targetPort: 8080
          name: http2
        - port: 443
          targetPort: 8443
          name: https
        - port: 15443
          targetPort: 15443
          name: tls
  components:
    pilot:
      k8s:
        # Pod Disruption Budget
        podDisruptionBudget:
          minAvailable: 1
        # Node affinity for HA
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: istiod
                topologyKey: kubernetes.io/hostname
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        # Pod Disruption Budget
        podDisruptionBudget:
          minAvailable: 1
        # Node affinity for HA
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: istio-ingressgateway
                topologyKey: kubernetes.io/hostname
        # Service annotations for DigitalOcean
        serviceAnnotations:
          service.beta.kubernetes.io/do-loadbalancer-name: "hashfoundry-istio-lb"
          service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
          service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/healthz/ready"
          service.beta.kubernetes.io/do-loadbalancer-healthcheck-protocol: "http"
ISTIO_CONFIG_EOF
    
    log "✅ Production конфигурация создана"
}

# Функция установки Istio
install_istio_production() {
    log "🔧 Установка Istio с production конфигурацией"
    
    # Установка с custom конфигурацией
    istioctl install -f istio-production-config.yaml --verify
    
    if [ $? -eq 0 ]; then
        log "✅ Istio установлен успешно"
    else
        log "❌ Ошибка установки Istio"
        return 1
    fi
    
    # Проверка установки
    istioctl verify-install
    
    # Ожидание готовности компонентов
    kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=300s
    kubectl wait --for=condition=available deployment/istio-ingressgateway -n istio-system --timeout=300s
    
    log "✅ Istio компоненты готовы"
}

# Функция установки observability stack
install_observability_stack() {
    log "📊 Установка observability stack"
    
    # Создание namespace для observability
    kubectl create namespace istio-observability --dry-run=client -o yaml | kubectl apply -f -
    
    # Установка Kiali
    kubectl apply -f - << KIALI_CONFIG_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
data:
  config.yaml: |
    auth:
      strategy: anonymous
    deployment:
      accessible_namespaces:
      - "**"
      namespace: istio-system
    external_services:
      prometheus:
        url: "http://prometheus-server.monitoring:80"
      grafana:
        url: "http://grafana.monitoring:80"
      jaeger:
        url: "http://jaeger-query.istio-system:16686"
    server:
      web_root: /kiali
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kiali
  template:
    metadata:
      labels:
        app: kiali
    spec:
      serviceAccountName: kiali
      containers:
      - name: kiali
        image: quay.io/kiali/kiali:v1.75
        imagePullPolicy: Always
        command:
        - "/opt/kiali/kiali"
        - "-config"
        - "/kiali-configuration/config.yaml"
        ports:
        - containerPort: 20001
          protocol: TCP
        resources:
          requests:
            cpu: 10m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 1Gi
        volumeMounts:
        - name: kiali-configuration
          mountPath: "/kiali-configuration"
        - name: kiali-cert
          mountPath: "/kiali-cert"
        - name: kiali-secret
          mountPath: "/kiali-secret"
      volumes:
      - name: kiali-configuration
        configMap:
          name: kiali
      - name: kiali-cert
        secret:
          secretName: istio.kiali-service-account
          optional: true
      - name: kiali-secret
        secret:
          secretName: kiali
          optional: true
---
apiVersion: v1
kind: Service
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
spec:
  ports:
  - name: http
    port: 20001
    protocol: TCP
  selector:
    app: kiali
KIALI_CONFIG_EOF
    
    # Установка Jaeger
    kubectl apply -f - << JAEGER_CONFIG_EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: istio-system
  labels:
    app: jaeger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:1.50
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
        - name: COLLECTOR_ZIPKIN_HOST_PORT
          value: ":9411"
        ports:
        - containerPort: 16686
          protocol: TCP
        - containerPort: 14268
          protocol: TCP
        - containerPort: 14250
          protocol: TCP
        - containerPort: 9411
          protocol: TCP
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-query
  namespace: istio-system
  labels:
    app: jaeger
spec:
  ports:
  - name: query-http
    port: 16686
    protocol: TCP
    targetPort: 16686
  selector:
    app: jaeger
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-collector
  namespace: istio-system
  labels:
    app: jaeger
spec:
  ports:
  - name: jaeger-collector-http
    port: 14268
    protocol: TCP
    targetPort: 14268
  - name: jaeger-collector-grpc
    port: 14250
    protocol: TCP
    targetPort: 14250
  - name: jaeger-collector-zipkin
    port: 9411
    protocol: TCP
    targetPort: 9411
  selector:
    app: jaeger
JAEGER_CONFIG_EOF
    
    # Создание RBAC для Kiali
    kubectl apply -f - << KIALI_RBAC_EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kiali
  labels:
    app: kiali
rules:
- apiGroups: [""]
  resources:
  - configmaps
  - endpoints
  - pods/log
  verbs:
  - get
  - list
  - watch
- apiGroups: [""]
  resources:
  - namespaces
  - pods
  - replicationcontrollers
  - services
  verbs:
  - get
  - list
  - watch
- apiGroups: [""]
  resources:
  - pods/portforward
  verbs:
  - create
  - post
- apiGroups: ["extensions", "apps"]
  resources:
  - daemonsets
  - deployments
  - replicasets
  - statefulsets
  verbs:
  - get
  - list
  - watch
- apiGroups: ["batch"]
  resources:
  - cronjobs
  - jobs
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - networking.istio.io
  - security.istio.io
  - extensions.istio.io
  - telemetry.istio.io
  - gateway.networking.k8s.io
  resources: ["*"]
  verbs:
  - get
  - list
  - watch
  - create
  - delete
  - patch
- apiGroups: ["apps.openshift.io"]
  resources:
  - deploymentconfigs
  verbs:
  - get
  - list
  - watch
- apiGroups: ["project.openshift.io"]
  resources:
  - projects
  verbs:
  - get
- apiGroups: ["route.openshift.io"]
  resources:
  - routes
  verbs:
  - get
  - list
  - watch
- apiGroups: ["authentication.k8s.io"]
  resources:
  - tokenreviews
  verbs:
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kiali
  labels:
    app: kiali
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kiali
subjects:
- kind: ServiceAccount
  name: kiali
  namespace: istio-system
KIALI_RBAC_EOF
    
    # Ожидание готовности observability компонентов
    kubectl wait --for=condition=available deployment/kiali -n istio-system --timeout=300s
    kubectl wait --for=condition=available deployment/jaeger -n istio-system --timeout=300s
    
    log "✅ Observability stack установлен"
}

# Функция настройки namespace для service mesh
configure_namespaces_for_mesh() {
    log "🏷️ Настройка namespaces для service mesh"
    
    # Включение sidecar injection для production namespaces
    local namespaces=("production" "staging" "monitoring" "argocd")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace $ns &>/dev/null; then
            log "Включение sidecar injection для namespace: $ns"
            kubectl label namespace $ns istio-injection=enabled --overwrite
        else
            log "Создание namespace $ns с sidecar injection"
            kubectl create namespace $ns
            kubectl label namespace $ns istio-injection=enabled
        fi
    done
    
    log "✅ Namespaces настроены для service mesh"
}

# Функция создания security policies
create_security_policies() {
    log "🔒 Создание security policies"
    
    # Default PeerAuthentication для strict mTLS
    kubectl apply -f - << PEER_AUTH_EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
# Исключение для health checks
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: health-check-exception
  namespace: istio-system
spec:
  selector:
    matchLabels:
      app: istio-ingressgateway
  mtls:
    mode: PERMISSIVE
  portLevelMtls:
    15021:
      mode: DISABLE
PEER_AUTH_EOF
    
    # Authorization policies для production
    kubectl apply -f - << AUTHZ_POLICIES_EOF
# Default deny-all policy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}
---
# Allow ArgoCD to access applications
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-argocd
  namespace: production
spec:
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/argocd/sa/argocd-server"]
        namespaces: ["argocd"]
  - to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
---
# Allow monitoring access
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-monitoring
  namespace: production
spec:
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/monitoring/sa/prometheus-server"]
        namespaces: ["monitoring"]
  - to:
    - operation:
        methods: ["GET"]
        paths: ["/metrics", "/health", "/ready"]
---
# Allow ingress gateway
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ingress
  namespace: production
spec:
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
AUTHZ_POLICIES_EOF
    
    log "✅ Security policies созданы"
}

# Функция создания traffic management
create_traffic_management() {
    log "🌐 Создание traffic management конфигурации"
    
    # Gateway для external traffic
    kubectl apply -f - << GATEWAY_CONFIG_EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: hashfoundry-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.hashfoundry.local"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: hashfoundry-tls
    hosts:
    - "*.hashfoundry.local"
---
# VirtualService для ArgoCD
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd-vs
  namespace: argocd
spec:
  hosts:
  - argocd.hashfoundry.local
  gateways:
  - istio-system/hashfoundry-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: argocd-server
        port:
          number: 80
    headers:
      request:
        set:
          x-forwarded-proto: https
---
# VirtualService для Grafana
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: grafana-vs
  namespace: monitoring
spec:
  hosts:
  - grafana.hashfoundry.local
  gateways:
  - istio-system/hashfoundry-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: grafana
        port:
          number: 80
---
# VirtualService для Kiali
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: kiali-vs
  namespace: istio-system
spec:
  hosts:
  - kiali.hashfoundry.local
  gateways:
  - hashfoundry-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: kiali
        port:
          number: 20001
GATEWAY_CONFIG_EOF
    
    # DestinationRules для circuit breaking
    kubectl apply -f - << DESTINATION_RULES_EOF
# DestinationRule для ArgoCD с circuit breaking
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: argocd-dr
  namespace: argocd
spec:
  host: argocd-server
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
        consecutiveGatewayErrors: 5
        interval: 30s
        baseEjectionTime: 30s
        maxEjectionPercent: 50
    loadBalancer:
      simple: LEAST_CONN
    outlierDetection:
      consecutiveGatewayErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
---
# DestinationRule для Grafana
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: grafana-dr
  namespace: monitoring
spec:
  host: grafana
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 50
      http:
        http1MaxPendingRequests: 25
        maxRequestsPerConnection: 5
    loadBalancer:
      simple: ROUND_ROBIN
DESTINATION_RULES_EOF
    
    log "✅ Traffic management конфигурация создана"
}

# Функция проверки установки
verify_installation() {
    log "🔍 Проверка установки service mesh"
    
    # Проверка Istio компонентов
    log "Проверка Istio компонентов:"
    kubectl get pods -n istio-system
    
    # Проверка sidecar injection
    log "Проверка sidecar injection:"
    kubectl get namespace -L istio-injection
    
    # Проверка mTLS статуса
    log "Проверка mTLS статуса:"
    istioctl authn tls-check --all
    
    # Проверка proxy статуса
    log "Проверка proxy статуса:"
    istioctl proxy-status
    
    # Проверка конфигурации
    log "Проверка конфигурации:"
    kubectl get virtualservices,destinationrules,gateways,peerauthentications,authorizationpolicies --all-namespaces
    
    # Получение external IP
    local external_ip=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$external_ip" ]; then
        log "✅ Service mesh готов!"
        log "🌐 External IP: $external_ip"
        log "🔗 Kiali: https://kiali.hashfoundry.local"
        log "🔗 ArgoCD: https://argocd.hashfoundry.local"
        log "🔗 Grafana: https://grafana.hashfoundry.local"
        log "📝 Добавьте в /etc/hosts:"
        log "   $external_ip kiali.hashfoundry.local"
        log "   $external_ip argocd.hashfoundry.local"
        log "   $external_ip grafana.hashfoundry.local"
    else
        log "⚠️ External IP еще не назначен, проверьте позже"
    fi
    
    log "✅ Проверка завершена"
}

# Основная логика выполнения
main() {
    case "$1" in
        download)
            download_and_install_istio
            ;;
        config)
            create_production_config
            ;;
        install)
            install_istio_production
            ;;
        observability)
            install_observability_stack
            ;;
        namespaces)
            configure_namespaces_for_mesh
            ;;
        security)
            create_security_policies
            ;;
        traffic)
            create_traffic_management
            ;;
        verify)
            verify_installation
            ;;
        full)
            log "🚀 Запуск полной установки Istio Service Mesh"
            download_and_install_istio
            create_production_config
            install_istio_production
            install_observability_stack
            configure_namespaces_for_mesh
            create_security_policies
            create_traffic_management
            verify_installation
            log "🎉 Istio Service Mesh установлен и настроен!"
            ;;
        *)
            echo "Использование: $0 {download|config|install|observability|namespaces|security|traffic|verify|full}"
            echo "  download      - Скачивание Istio"
            echo "  config        - Создание production конфигурации"
            echo "  install       - Установка Istio"
            echo "  observability - Установка observability stack"
            echo "  namespaces    - Настройка namespaces"
            echo "  security      - Создание security policies"
            echo "  traffic       - Настройка traffic management"
            echo "  verify        - Проверка установки"
            echo "  full          - Полная установка и настройка"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в Istio setup"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x istio-production-setup.sh
```

### **2. Создание comprehensive service mesh monitoring:**
```bash
# Создать скрипт service-mesh-monitor.sh
cat << 'EOF' > service-mesh-monitor.sh
#!/bin/bash

echo "📊 Comprehensive Service Mesh Monitoring"
echo "========================================"

# Настройка переменных
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
MONITOR_LOG="/var/log/service-mesh-monitor-$TIMESTAMP.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $MONITOR_LOG
}

# Функция мониторинга control plane
monitor_control_plane() {
    log "🏥 Мониторинг Control Plane"
    
    local control_plane_report="/tmp/control-plane-status-$TIMESTAMP.json"
    
    # Comprehensive control plane assessment
    cat > $control_plane_report << CONTROL_PLANE_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "control_plane_status": {
    "istiod": {
      "replicas": $(kubectl get deployment istiod -n istio-system -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0"),
      "ready_replicas": $(kubectl get deployment istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"),
      "available_replicas": $(kubectl get deployment istiod -n istio-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0"),
      "resource_usage": {
$(kubectl top pods -n istio-system -l app=istiod --no-headers 2>/dev/null | awk '{print "        \"cpu\": \"" $2 "\", \"memory\": \"" $3 "\""}' | head -1 || echo '        "cpu": "unknown", "memory": "unknown"')
      }
    },
    "ingress_gateway": {
      "replicas": $(kubectl get deployment istio-ingressgateway -n istio-system -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0"),
      "ready_replicas": $(kubectl get deployment istio-ingressgateway -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"),
      "external_ip": "$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")",
      "resource_usage": {
$(kubectl top pods -n istio-system -l app=istio-ingressgateway --no-headers 2>/dev/null | awk '{print "        \"cpu\": \"" $2 "\", \"memory\": \"" $3 "\""}' | head -1 || echo '        "cpu": "unknown", "memory": "unknown"')
      }
    },
    "proxy_status": {
$(istioctl proxy-status 2>/dev/null | tail -n +2 | awk '{print "      \"" $1 "\": {\"cluster\": \"" $2 "\", \"cp\": \"" $3 "\", \"version\": \"" $4 "\"}"}' | paste -sd, - || echo '      "no_proxies": "detected"')
    }
  },
  "health_summary": {
    "control_plane_healthy": $(kubectl get pods -n istio-system -l app=istiod --no-headers | grep Running | wc -l),
    "ingress_healthy": $(kubectl get pods -n istio-system -l app=istio-ingressgateway --no-headers | grep Running | wc -l),
    "total_sidecars": $(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep -c istio-proxy || echo "0")
  }
}
CONTROL_PLANE_REPORT_EOF
    
    log "📄 Control plane report: $control_plane_report"
    
    # Краткая статистика
    local istiod_ready=$(kubectl get deployment istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local gateway_ready=$(kubectl get deployment istio-ingressgateway -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local total_sidecars=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep -c istio-proxy || echo "0")
    
    log "🎯 Control Plane статистика:"
    log "  🏗️ Istiod ready: $istiod_ready"
    log "  🌐 Gateway ready: $gateway_ready"
    log "  🔗 Total sidecars: $total_sidecars"
    
    return 0
}

# Функция мониторинга data plane
monitor_data_plane() {
    log "🔍 Мониторинг Data Plane"
    
    local data_plane_report="/tmp/data-plane-status-$TIMESTAMP.json"
    
    # Анализ sidecar proxies
    cat > $data_plane_report << DATA_PLANE_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "data_plane_status": {
    "sidecar_distribution": {
$(kubectl get pods --all-namespaces -o json | jq -r '
    .items[] | 
    select(.spec.containers[]?.name == "istio-proxy") | 
    .metadata.namespace' | 
    sort | uniq -c | 
    awk '{print "      \"" $2 "\": " $1}' | 
    paste -sd, - || echo '      "no_sidecars": 0')
    },
    "sidecar_resource_usage": [
$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | head -10 | awk '{print "      {\"namespace\": \"" $1 "\", \"pod\": \"" $2 "\", \"cpu\": \"" $4 "\", \"memory\": \"" $5 "\"}"}' | paste -sd, - || echo '      {"no_data": "available"}')
    ],
    "mtls_status": {
$(istioctl authn tls-check --all 2>/dev/null | tail -n +2 | awk '{print "      \"" $1 "\": \"" $2 "\""}' | paste -sd, - || echo '      "no_services": "detected"')
    }
  },
  "performance_metrics": {
    "average_sidecar_cpu": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$4} END {if(NR>0) print sum/NR "m"; else print "0m"}' | sed 's/m$//' || echo "0")m",
    "average_sidecar_memory": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$5} END {if(NR>0) print sum/NR "Mi"; else print "0Mi"}' | sed 's/Mi$//' || echo "0")Mi",
    "total_sidecar_overhead": {
      "cpu": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$4} END {print sum "m"}' | sed 's/m$//' || echo "0")m",
      "memory": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$5} END {print sum "Mi"}' | sed 's/Mi$//' || echo "0")Mi"
    }
  }
}
DATA_PLANE_REPORT_EOF
    
    log "📄 Data plane report: $data_plane_report"
    
    # Краткая статистика
    local total_sidecars=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep -c istio-proxy || echo "0")
    local avg_cpu=$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$4} END {if(NR>0) print sum/NR; else print "0"}' | cut -d'm' -f1 || echo "0")
    local avg_memory=$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$5} END {if(NR>0) print sum/NR; else print "0"}' | cut -d'M' -f1 || echo "0")
    
    log "🎯 Data Plane статистика:"
    log "  🔗 Total sidecars: $total_sidecars"
    log "  ⚡ Avg CPU: ${avg_cpu}m"
    log "  💾 Avg Memory: ${avg_memory}Mi"
    
    return 0
}

# Функция мониторинга traffic flow
monitor_traffic_flow() {
    log "🌐 Мониторинг Traffic Flow"
    
    local traffic_report="/tmp/traffic-flow-$TIMESTAMP.json"
    
    # Анализ traffic patterns
    cat > $traffic_report << TRAFFIC_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "traffic_analysis": {
    "virtual_services": $(kubectl get virtualservices --all-namespaces -o json | jq '.items | length'),
    "destination_rules": $(kubectl get destinationrules --all-namespaces -o json | jq '.items | length'),
    "gateways": $(kubectl get gateways --all-namespaces -o json | jq '.items | length'),
    "service_entries": $(kubectl get serviceentries --all-namespaces -o json | jq '.items | length'),
    "traffic_policies": {
      "circuit_breakers": $(kubectl get destinationrules --all-namespaces -o json | jq '[.items[] | select(.spec.trafficPolicy.outlierDetection)] | length'),
      "load_balancers": $(kubectl get destinationrules --all-namespaces -o json | jq '[.items[] | select(.spec.trafficPolicy.loadBalancer)] | length'),
      "connection_pools": $(kubectl get destinationrules --all-namespaces -o json | jq '[.items[] | select(.spec.trafficPolicy.connectionPool)] | length')
    }
  },
  "security_policies": {
    "peer_authentications": $(kubectl get peerauthentications --all-namespaces -o json | jq '.items | length'),
    "authorization_policies": $(kubectl get authorizationpolicies --all-namespaces -o json | jq '.items | length'),
    "strict_mtls_namespaces": $(kubectl get peerauthentications --all-namespaces -o json | jq '[.items[] | select(.spec.mtls.mode == "STRICT")] | length')
  }
}
TRAFFIC_REPORT_EOF
    
    log "📄 Traffic flow report: $traffic_report"
    
    # Краткая статистика
    local vs_count=$(kubectl get virtualservices --all-namespaces --no-headers | wc -l)
    local dr_count=$(kubectl get destinationrules --all-namespaces --no-headers | wc -l)
    local gw_count=$(kubectl get gateways --all-namespaces --no-headers | wc -l)
    local pa_count=$(kubectl get peerauthentications --all-namespaces --no-headers | wc -l)
    
    log "🎯 Traffic Flow статистика:"
    log "  🛣️ VirtualServices: $vs_count"
    log "  🎯 DestinationRules: $dr_count"
    log "  🚪 Gateways: $gw_count"
    log "  🔒 PeerAuthentications: $pa_count"
    
    return 0
}

# Функция проверки производительности
check_performance_impact() {
    log "⚡ Проверка производительности service mesh"
    
    local performance_report="/tmp/service-mesh-performance-$TIMESTAMP.json"
    
    # Анализ performance impact
    cat > $performance_report << PERFORMANCE_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "performance_analysis": {
    "sidecar_overhead": {
      "total_cpu_usage": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$4} END {print sum "m"}' | sed 's/m$//' || echo "0")m",
      "total_memory_usage": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$5} END {print sum "Mi"}' | sed 's/Mi$//' || echo "0")Mi",
      "average_per_sidecar": {
        "cpu": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$4} END {if(NR>0) print sum/NR "m"; else print "0m"}' | sed 's/m$//' || echo "0")m",
        "memory": "$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$5} END {if(NR>0) print sum/NR "Mi"; else print "0Mi"}' | sed 's/Mi$//' || echo "0")Mi"
      }
    },
    "control_plane_overhead": {
      "istiod_cpu": "$(kubectl top pods -n istio-system -l app=istiod --no-headers 2>/dev/null | awk '{print $2}' | head -1 || echo "unknown")",
      "istiod_memory": "$(kubectl top pods -n istio-system -l app=istiod --no-headers 2>/dev/null | awk '{print $3}' | head -1 || echo "unknown")",
      "gateway_cpu": "$(kubectl top pods -n istio-system -l app=istio-ingressgateway --no-headers 2>/dev/null | awk '{print $2}' | head -1 || echo "unknown")",
      "gateway_memory": "$(kubectl top pods -n istio-system -l app=istio-ingressgateway --no-headers 2>/dev/null | awk '{print $3}' | head -1 || echo "unknown")"
    },
    "latency_analysis": {
      "proxy_processing_time": "estimated_1-5ms",
      "mtls_overhead": "estimated_0.5-2ms",
      "policy_evaluation": "estimated_0.1-1ms"
    }
  },
  "optimization_recommendations": [
$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{if($4+0 > 100) print "    \"High CPU usage in " $1 "/" $2 ": " $4 "\""}' | paste -sd, - || echo '    "No high CPU usage detected"')
  ]
}
PERFORMANCE_REPORT_EOF
    
    log "📄 Performance report: $performance_report"
    
    # Performance recommendations
    local high_cpu_sidecars=$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{if($4+0 > 100) print $1 "/" $2}' | wc -l)
    local high_memory_sidecars=$(kubectl top pods --all-namespaces --containers 2>/dev/null | grep istio-proxy | awk '{if($5+0 > 256) print $1 "/" $2}' | wc -l)
    
    log "🎯 Performance статистика:"
    log "  🔥 High CPU sidecars: $high_cpu_sidecars"
    log "  💾 High Memory sidecars: $high_memory_sidecars"
    
    if [ $high_cpu_sidecars -gt 0 ] || [ $high_memory_sidecars -gt 0 ]; then
        log "⚠️ Рекомендации по оптимизации:"
        log "  - Настройте resource limits для sidecar"
        log "  - Проверьте traffic patterns"
        log "  - Рассмотрите selective sidecar injection"
    fi
    
    return 0
}

# Функция создания comprehensive report
create_comprehensive_report() {
    log "📋 Создание comprehensive service mesh report"
    
    local comprehensive_report="/tmp/service-mesh-comprehensive-$TIMESTAMP.json"
    
    cat > $comprehensive_report << COMPREHENSIVE_REPORT_EOF
{
  "report_metadata": {
    "timestamp": "$(date -Iseconds)",
    "cluster": "$(kubectl config current-context)",
    "istio_version": "$(istioctl version --short 2>/dev/null || echo "unknown")",
    "kubernetes_version": "$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")"
  },
  "service_mesh_overview": {
    "deployment_status": {
      "istio_installed": $(kubectl get namespace istio-system &>/dev/null && echo "true" || echo "false"),
      "control_plane_ready": $(kubectl get deployment istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"),
      "ingress_gateway_ready": $(kubectl get deployment istio-ingressgateway -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"),
      "observability_stack": {
        "kiali_ready": $(kubectl get deployment kiali -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"),
        "jaeger_ready": $(kubectl get deployment jaeger -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      }
    },
    "mesh_adoption": {
      "total_namespaces": $(kubectl get namespaces --no-headers | wc -l),
      "mesh_enabled_namespaces": $(kubectl get namespaces -l istio-injection=enabled --no-headers | wc -l),
      "total_pods": $(kubectl get pods --all-namespaces --no-headers | wc -l),
      "pods_with_sidecar": $(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep -c istio-proxy || echo "0")
    },
    "security_posture": {
      "mtls_enforcement": "$(kubectl get peerauthentication default -n istio-system -o jsonpath='{.spec.mtls.mode}' 2>/dev/null || echo "unknown")",
      "authorization_policies": $(kubectl get authorizationpolicies --all-namespaces --no-headers | wc -l),
      "security_violations": 0
    }
  },
  "health_summary": {
    "overall_status": "$(kubectl get pods -n istio-system --no-headers | grep -v Running | wc -l | awk '{if($1==0) print "healthy"; else print "degraded"}')",
    "critical_issues": [],
    "warnings": [],
    "recommendations": [
      "Monitor sidecar resource usage regularly",
      "Review authorization policies for least privilege",
      "Enable distributed tracing for better observability",
      "Set up proper alerting for service mesh components"
    ]
  }
}
COMPREHENSIVE_REPORT_EOF
    
    log "📄 Comprehensive report: $comprehensive_report"
    
    # Summary
    local mesh_namespaces=$(kubectl get namespaces -l istio-injection=enabled --no-headers | wc -l)
    local total_namespaces=$(kubectl get namespaces --no-headers | wc -l)
    local adoption_rate=$(echo "scale=1; $mesh_namespaces * 100 / $total_namespaces" | bc -l 2>/dev/null || echo "0")
    
    log "🎯 Service Mesh Summary:"
    log "  📊 Mesh adoption: $mesh_namespaces/$total_namespaces namespaces ($adoption_rate%)"
    log "  🏥 Overall health: $(kubectl get pods -n istio-system --no-headers | grep -v Running | wc -l | awk '{if($1==0) print "healthy"; else print "degraded"}')"
    log "  🔒 mTLS mode: $(kubectl get peerauthentication default -n istio-system -o jsonpath='{.spec.mtls.mode}' 2>/dev/null || echo "unknown")"
    
    return 0
}

# Основная логика выполнения
main() {
    case "$1" in
        control-plane)
            monitor_control_plane
            ;;
        data-plane)
            monitor_data_plane
            ;;
        traffic)
            monitor_traffic_flow
            ;;
        performance)
            check_performance_impact
            ;;
        report)
            create_comprehensive_report
            ;;
        all)
            log "🚀 Запуск полного мониторинга service mesh"
            monitor_control_plane
            monitor_data_plane
            monitor_traffic_flow
            check_performance_impact
            create_comprehensive_report
            log "🎉 Мониторинг service mesh завершен!"
            ;;
        *)
            echo "Использование: $0 {control-plane|data-plane|traffic|performance|report|all}"
            echo "  control-plane - Мониторинг control plane"
            echo "  data-plane    - Мониторинг data plane"
            echo "  traffic       - Мониторинг traffic flow"
            echo "  performance   - Проверка производительности"
            echo "  report        - Comprehensive report"
            echo "  all           - Полный мониторинг"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в service mesh monitoring"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x service-mesh-monitor.sh
```

## 📊 **Архитектура service mesh в HA кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│                Service Mesh Architecture                   │
├─────────────────────────────────────────────────────────────┤
│  Control Plane (istio-system namespace)                    │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │   Istiod    │   Gateway   │    Kiali    │   Jaeger    │  │
│  │ ├── Pilot   │ ├── Envoy   │ ├── UI      │ ├── Tracing │  │
│  │ ├── Citadel │ ├── LB      │ ├── Graph   │ ├── Spans   │  │
│  │ ├── Galley  │ ├── TLS     │ └── Metrics │ └── Analysis│  │
│  │ └── Telemetry│ └── Routing │             │             │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Data Plane (Application Namespaces)                       │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐│ │
│  │ │ ArgoCD  │    │Grafana  │    │Prometheus│   │ Apps    ││ │
│  │ │ + Proxy │◄──▶│ + Proxy │◄──▶│ + Proxy  │◄─▶│ + Proxy ││ │
│  │ └─────────┘    └─────────┘    └─────────┘    └─────────┘│ │
│  │        │              │              │              │   │ │
│  │        └──────────────┼──────────────┼──────────────┘   │ │
│  │                       │              │                  │ │
│  │ ┌─────────────────────────────────────────────────────┐ │ │
│  │ │           mTLS Encrypted Communication             │ │ │
│  │ │ ├── Identity-based Authentication                  │ │ │
│  │ │ ├── Policy Enforcement                             │ │ │
│  │ │ ├── Traffic Management                             │ │ │
│  │ │ └── Observability Collection                       │ │ │
│  │ └─────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для service mesh:**

### **1. Security Best Practices**
- Включите strict mTLS для всех namespaces
- Используйте authorization policies с least privilege
- Регулярно ротируйте certificates
- Мониторьте security violations

### **2. Performance Optimization**
- Настройте resource limits для sidecar proxies
- Используйте selective sidecar injection
- Оптимизируйте telemetry collection
- Мониторьте latency overhead

### **3. Operational Excellence**
- Автоматизируйте deployment и configuration
- Настройте comprehensive monitoring
- Используйте GitOps для управления конфигурацией
- Планируйте upgrade strategy

### **4. Observability**
- Настройте distributed tracing
- Используйте service topology visualization
- Мониторьте traffic patterns
- Настройте alerting для критичных метрик

**Service mesh обеспечивает enterprise-grade управление микросервисной коммуникацией с zero-trust security, comprehensive observability и intelligent traffic management!**
