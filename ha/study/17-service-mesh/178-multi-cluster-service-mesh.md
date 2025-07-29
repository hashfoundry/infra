# 178. Multi-cluster service mesh

## 🎯 Вопрос
Как реализовать multi-cluster service mesh?

## 💡 Ответ

Multi-cluster service mesh обеспечивает единую плоскость управления и безопасную коммуникацию между сервисами, развернутыми в разных Kubernetes кластерах. Istio поддерживает primary-remote, primary-primary и external control plane модели для создания федеративной mesh архитектуры с cross-cluster service discovery, mTLS и traffic management.

### 🏗️ Архитектура multi-cluster service mesh

#### 1. **Схема multi-cluster топологии**
```
┌─────────────────────────────────────────────────────────────┐
│                Multi-Cluster Service Mesh                  │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Primary Cluster                         │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │              Istio Control Plane                   ││ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ ││ │
│  │  │  │   Istiod    │  │   Pilot     │  │   Citadel   │ ││ │
│  │  │  │ (Primary)   │  │             │  │             │ ││ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘ ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  │                              │                          │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │                Data Plane                          ││ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ ││ │
│  │  │  │  Service A  │  │  Service B  │  │  Gateway    │ ││ │
│  │  │  │   + Envoy   │  │   + Envoy   │  │   + Envoy   │ ││ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘ ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              │ Cross-Cluster Network       │
│                              │                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Remote Cluster                          │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │            Remote Control Plane                    ││ │
│  │  │  ┌─────────────┐                                   ││ │
│  │  │  │   Istiod    │  ◄─── Config Sync                ││ │
│  │  │  │  (Remote)   │                                   ││ │
│  │  │  └─────────────┘                                   ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  │                              │                          │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │                Data Plane                          ││ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ ││ │
│  │  │  │  Service C  │  │  Service D  │  │  Gateway    │ ││ │
│  │  │  │   + Envoy   │  │   + Envoy   │  │   + Envoy   │ ││ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘ ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Multi-cluster модели**
```yaml
# Модели multi-cluster service mesh
multi_cluster_models:
  primary_remote:
    description: "Один primary кластер с control plane, остальные remote"
    use_cases:
      - "Централизованное управление"
      - "Простая конфигурация"
      - "Меньше ресурсов на remote кластерах"
    limitations:
      - "Single point of failure"
      - "Network latency для remote кластеров"
      
  primary_primary:
    description: "Несколько primary кластеров с собственными control plane"
    use_cases:
      - "High availability"
      - "Географически распределенные кластеры"
      - "Независимое управление"
    benefits:
      - "Отказоустойчивость"
      - "Локальное управление"
      - "Лучшая производительность"
      
  external_control_plane:
    description: "Control plane вне Kubernetes кластеров"
    use_cases:
      - "Managed service mesh"
      - "Hybrid cloud deployments"
      - "Legacy system integration"
    considerations:
      - "Дополнительная инфраструктура"
      - "Сетевая связность"
```

### 📊 Примеры из нашего кластера

#### Проверка multi-cluster конфигурации:
```bash
# Проверка кластеров в mesh
istioctl proxy-status --all-namespaces

# Проверка cross-cluster endpoints
kubectl get endpoints --all-namespaces -o wide

# Проверка multi-cluster secrets
kubectl get secrets -n istio-system -l istio/cluster-name

# Проверка network configuration
kubectl get gateways --all-namespaces
kubectl get destinationrules --all-namespaces | grep -i cluster
```

### 🔧 Настройка Primary-Remote модели

#### 1. **Primary кластер конфигурация**
```bash
#!/bin/bash
# setup-primary-cluster.sh

echo "🏗️ Настройка Primary кластера для multi-cluster mesh"

# Переменные
PRIMARY_CLUSTER_NAME="hashfoundry-primary"
PRIMARY_NETWORK="network1"
MESH_ID="mesh1"

# Установка Istio на primary кластер
install_istio_primary() {
    echo "📦 Установка Istio на primary кластер"
    
    # Создание IstioOperator для primary
    cat <<EOF | kubectl apply -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: primary
  namespace: istio-system
spec:
  values:
    global:
      meshID: ${MESH_ID}
      cluster: ${PRIMARY_CLUSTER_NAME}
      network: ${PRIMARY_NETWORK}
    pilot:
      env:
        EXTERNAL_ISTIOD: true
        PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY: true
        PILOT_ENABLE_REMOTE_JWKS_CACHE: true
    istiodRemote:
      enabled: false
  components:
    pilot:
      k8s:
        env:
          - name: PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION
            value: "true"
          - name: PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY
            value: "true"
        service:
          type: LoadBalancer
          ports:
            - port: 15010
              targetPort: 15010
              name: grpc-xds
            - port: 15011
              targetPort: 15011
              name: grpc-xds-tls
            - port: 15012
              targetPort: 15012
              name: grpc-xds-mux
EOF
    
    # Ожидание готовности
    kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=600s
    
    echo "✅ Istio установлен на primary кластер"
}

# Настройка cross-cluster secret
setup_cross_cluster_secret() {
    local remote_cluster_name=$1
    local remote_kubeconfig=$2
    
    echo "🔐 Настройка cross-cluster secret для $remote_cluster_name"
    
    # Создание secret для remote кластера
    kubectl create secret generic cacerts -n istio-system \
        --from-file=root-cert.pem=/tmp/root-cert.pem \
        --from-file=cert-chain.pem=/tmp/cert-chain.pem \
        --from-file=ca-cert.pem=/tmp/ca-cert.pem \
        --from-file=ca-key.pem=/tmp/ca-key.pem
    
    # Создание secret для доступа к remote кластеру
    kubectl create secret generic ${remote_cluster_name} \
        --from-file=${remote_kubeconfig} \
        -n istio-system
    
    kubectl label secret ${remote_cluster_name} istio/cluster=${remote_cluster_name} -n istio-system
    
    echo "✅ Cross-cluster secret создан"
}

# Настройка east-west gateway
setup_east_west_gateway() {
    echo "🌐 Настройка East-West Gateway"
    
    # Установка east-west gateway
    cat <<EOF | kubectl apply -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: eastwest
  namespace: istio-system
spec:
  revision: ""
  components:
    ingressGateways:
      - name: istio-eastwestgateway
        label:
          istio: eastwestgateway
          app: istio-eastwestgateway
        enabled: true
        k8s:
          service:
            type: LoadBalancer
            ports:
              - port: 15021
                targetPort: 15021
                name: status-port
              - port: 15010
                targetPort: 15010
                name: tls
              - port: 15011
                targetPort: 15011
                name: tls-istiod
              - port: 15012
                targetPort: 15012
                name: tls-webhook
EOF
    
    # Настройка Gateway для cross-cluster трафика
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: cross-network-gateway
  namespace: istio-system
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: ISTIO_MUTUAL
      hosts:
        - "*.local"
EOF
    
    echo "✅ East-West Gateway настроен"
}

# Экспорт discovery адреса
export_discovery_address() {
    echo "📡 Экспорт discovery адреса"
    
    # Получение external IP east-west gateway
    local gateway_ip=$(kubectl get svc istio-eastwestgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    echo "Discovery address: ${gateway_ip}:15012"
    echo "Используйте этот адрес для настройки remote кластеров"
    
    # Сохранение в файл для использования в remote кластерах
    echo "${gateway_ip}:15012" > /tmp/discovery-address.txt
    
    echo "✅ Discovery адрес экспортирован"
}

# Основная логика
case "$1" in
    install)
        install_istio_primary
        ;;
    secret)
        setup_cross_cluster_secret $2 $3
        ;;
    gateway)
        setup_east_west_gateway
        ;;
    export)
        export_discovery_address
        ;;
    all)
        install_istio_primary
        setup_east_west_gateway
        export_discovery_address
        ;;
    *)
        echo "Использование: $0 {install|secret|gateway|export|all} [remote-cluster] [kubeconfig]"
        exit 1
        ;;
esac
```

#### 2. **Remote кластер конфигурация**
```bash
#!/bin/bash
# setup-remote-cluster.sh

echo "🔗 Настройка Remote кластера для multi-cluster mesh"

# Переменные
REMOTE_CLUSTER_NAME="hashfoundry-remote"
REMOTE_NETWORK="network2"
MESH_ID="mesh1"
DISCOVERY_ADDRESS=""  # Получить из primary кластера

# Установка Istio на remote кластер
install_istio_remote() {
    local discovery_address=$1
    
    echo "📦 Установка Istio на remote кластер"
    
    # Создание namespace
    kubectl create namespace istio-system
    
    # Создание CA certificates secret
    kubectl create secret generic cacerts -n istio-system \
        --from-file=root-cert.pem=/tmp/root-cert.pem \
        --from-file=cert-chain.pem=/tmp/cert-chain.pem \
        --from-file=ca-cert.pem=/tmp/ca-cert.pem \
        --from-file=ca-key.pem=/tmp/ca-key.pem
    
    # Создание IstioOperator для remote
    cat <<EOF | kubectl apply -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: remote
  namespace: istio-system
spec:
  values:
    global:
      meshID: ${MESH_ID}
      cluster: ${REMOTE_CLUSTER_NAME}
      network: ${REMOTE_NETWORK}
      remotePilotAddress: ${discovery_address}
    istiodRemote:
      enabled: true
    pilot:
      env:
        EXTERNAL_ISTIOD: true
  components:
    pilot:
      enabled: false
    ingressGateways:
      - name: istio-ingressgateway
        enabled: false
EOF
    
    # Ожидание готовности
    kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=600s
    
    echo "✅ Istio установлен на remote кластер"
}

# Настройка east-west gateway для remote
setup_remote_east_west_gateway() {
    echo "🌐 Настройка East-West Gateway для remote кластера"
    
    # Установка east-west gateway
    cat <<EOF | kubectl apply -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: eastwest-remote
  namespace: istio-system
spec:
  revision: ""
  components:
    ingressGateways:
      - name: istio-eastwestgateway
        label:
          istio: eastwestgateway
          app: istio-eastwestgateway
        enabled: true
        k8s:
          service:
            type: LoadBalancer
            ports:
              - port: 15021
                targetPort: 15021
                name: status-port
              - port: 15443
                targetPort: 15443
                name: tls
EOF
    
    # Настройка Gateway
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: cross-network-gateway
  namespace: istio-system
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: ISTIO_MUTUAL
      hosts:
        - "*.local"
EOF
    
    echo "✅ East-West Gateway настроен для remote кластера"
}

# Настройка network endpoint
setup_network_endpoint() {
    echo "🔗 Настройка network endpoint"
    
    # Получение external IP east-west gateway
    local gateway_ip=$(kubectl get svc istio-eastwestgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    # Создание network endpoint
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: cross-network-gateway
  namespace: istio-system
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: ISTIO_MUTUAL
      hosts:
        - "*.local"
---
apiVersion: v1
kind: Service
metadata:
  name: istio-eastwestgateway-${REMOTE_NETWORK}
  namespace: istio-system
  labels:
    istio: eastwestgateway
    topology.istio.io/network: ${REMOTE_NETWORK}
spec:
  type: LoadBalancer
  selector:
    istio: eastwestgateway
  ports:
    - port: 15443
      name: tls
      targetPort: 15443
EOF
    
    echo "Network endpoint: ${gateway_ip}:15443"
    echo "✅ Network endpoint настроен"
}

# Основная логика
case "$1" in
    install)
        install_istio_remote $2
        ;;
    gateway)
        setup_remote_east_west_gateway
        ;;
    endpoint)
        setup_network_endpoint
        ;;
    all)
        install_istio_remote $2
        setup_remote_east_west_gateway
        setup_network_endpoint
        ;;
    *)
        echo "Использование: $0 {install|gateway|endpoint|all} [discovery-address]"
        exit 1
        ;;
esac
```

### 🌐 Cross-cluster service discovery

#### 1. **ServiceEntry для cross-cluster сервисов**
```yaml
# cross-cluster-services.yaml

# ServiceEntry для сервиса в remote кластере
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: remote-service
  namespace: production
spec:
  hosts:
  - remote-service.production.global
  location: MESH_EXTERNAL
  ports:
  - number: 8080
    name: http
    protocol: HTTP
  resolution: DNS
  addresses:
  - 240.0.0.1  # Virtual IP для cross-cluster service
  endpoints:
  - address: remote-service.production.svc.cluster.local
    network: network2
    ports:
      http: 8080
---
# DestinationRule для cross-cluster трафика
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: remote-service-dr
  namespace: production
spec:
  host: remote-service.production.global
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
  subsets:
  - name: remote-cluster
    labels:
      cluster: hashfoundry-remote
    trafficPolicy:
      portLevelSettings:
      - port:
          number: 8080
        connectionPool:
          tcp:
            maxConnections: 50
---
# VirtualService для cross-cluster routing
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: remote-service-vs
  namespace: production
spec:
  hosts:
  - remote-service.production.global
  http:
  - match:
    - headers:
        cluster-preference:
          exact: remote
    route:
    - destination:
        host: remote-service.production.global
        subset: remote-cluster
  - route:
    - destination:
        host: remote-service.production.local
      weight: 80
    - destination:
        host: remote-service.production.global
        subset: remote-cluster
      weight: 20
```

#### 2. **Автоматическое обнаружение сервисов**
```bash
#!/bin/bash
# cross-cluster-discovery.sh

echo "🔍 Настройка cross-cluster service discovery"

# Создание WorkloadEntry для external сервиса
create_workload_entry() {
    local service_name=$1
    local service_ip=$2
    local service_port=$3
    local cluster_name=$4
    
    echo "📝 Создание WorkloadEntry для $service_name"
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: WorkloadEntry
metadata:
  name: ${service_name}-${cluster_name}
  namespace: production
spec:
  address: ${service_ip}
  ports:
    http: ${service_port}
  labels:
    app: ${service_name}
    cluster: ${cluster_name}
  serviceAccount: ${service_name}
EOF
    
    echo "✅ WorkloadEntry создан"
}

# Синхронизация сервисов между кластерами
sync_services() {
    local source_cluster=$1
    local target_cluster=$2
    
    echo "🔄 Синхронизация сервисов из $source_cluster в $target_cluster"
    
    # Получение списка сервисов из source кластера
    kubectl --context=$source_cluster get services --all-namespaces -o json | \
        jq -r '.items[] | select(.metadata.labels.export=="true") | 
        "\(.metadata.namespace) \(.metadata.name) \(.spec.clusterIP) \(.spec.ports[0].port)"' | \
        while read namespace service_name cluster_ip port; do
            echo "Экспорт сервиса: $namespace/$service_name"
            
            # Создание ServiceEntry в target кластере
            cat <<EOF | kubectl --context=$target_cluster apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: ${service_name}-${source_cluster}
  namespace: ${namespace}
  labels:
    source-cluster: ${source_cluster}
spec:
  hosts:
  - ${service_name}.${namespace}.global
  location: MESH_EXTERNAL
  ports:
  - number: ${port}
    name: http
    protocol: HTTP
  resolution: DNS
  endpoints:
  - address: ${service_name}.${namespace}.svc.cluster.local
    network: ${source_cluster}
    ports:
      http: ${port}
EOF
        done
    
    echo "✅ Синхронизация завершена"
}

# Проверка cross-cluster connectivity
test_connectivity() {
    local source_pod=$1
    local target_service=$2
    local target_cluster=$3
    
    echo "🧪 Тестирование connectivity к $target_service в $target_cluster"
    
    # Тест HTTP запроса
    kubectl exec $source_pod -- curl -s -o /dev/null -w "%{http_code}" \
        http://${target_service}.production.global/health
    
    # Тест с mTLS
    kubectl exec $source_pod -- curl -s -o /dev/null -w "%{http_code}" \
        --cert /var/run/secrets/workload-spiffe-credentials/cert.pem \
        --key /var/run/secrets/workload-spiffe-credentials/key.pem \
        --cacert /var/run/secrets/workload-spiffe-credentials/ca.pem \
        https://${target_service}.production.global/health
    
    echo "✅ Connectivity тест завершен"
}

# Мониторинг cross-cluster трафика
monitor_cross_cluster_traffic() {
    echo "📊 Мониторинг cross-cluster трафика"
    
    # Метрики cross-cluster запросов
    kubectl exec -n istio-system deployment/prometheus -- \
        promtool query instant 'sum(rate(istio_requests_total{source_cluster!="unknown",destination_cluster!="unknown",source_cluster!=destination_cluster}[5m])) by (source_cluster, destination_cluster)'
    
    # Latency cross-cluster запросов
    kubectl exec -n istio-system deployment/prometheus -- \
        promtool query instant 'histogram_quantile(0.95, sum(rate(istio_request_duration_milliseconds_bucket{source_cluster!="unknown",destination_cluster!="unknown",source_cluster!=destination_cluster}[5m])) by (le, source_cluster, destination_cluster))'
    
    echo "✅ Мониторинг завершен"
}

# Основная логика
case "$1" in
    workload-entry)
        create_workload_entry $2 $3 $4 $5
        ;;
    sync)
        sync_services $2 $3
        ;;
    test)
        test_connectivity $2 $3 $4
        ;;
    monitor)
        monitor_cross_cluster_traffic
        ;;
    *)
        echo "Использование: $0 {workload-entry|sync|test|monitor} [params...]"
        exit 1
        ;;
esac
```

### 🔐 Multi-cluster security

#### 1. **Cross-cluster mTLS конфигурация**
```yaml
# multi-cluster-security.yaml

# Общий root CA для всех кластеров
apiVersion: v1
kind: Secret
metadata:
  name: cacerts
  namespace: istio-system
type: Opaque
data:
  # Общий root certificate для всех кластеров
  root-cert.pem: LS0tLS1CRUdJTi... # base64 encoded
  cert-chain.pem: LS0tLS1CRUdJTi... # base64 encoded
  ca-cert.pem: LS0tLS1CRUdJTi... # base64 encoded
  ca-key.pem: LS0tLS1CRUdJTi... # base64 encoded
---
# PeerAuthentication для cross-cluster mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: cross-cluster-mtls
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
# AuthorizationPolicy для cross-cluster доступа
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: cross-cluster-access
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-service
  rules:
  - from:
    - source:
        principals: 
        - "cluster.local/ns/production/sa/frontend-service"
        - "hashfoundry-remote.local/ns/production/sa/frontend-service"
  - to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
---
# DestinationRule для cross-cluster mTLS
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: cross-cluster-mtls-dr
  namespace: production
spec:
  host: "*.global"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
  exportTo:
  - "*"
```

### 📊 Мониторинг multi-cluster mesh

#### 1. **Multi-cluster метрики**
```yaml
# multi-cluster-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: multi-cluster-alerts
  namespace: istio-system
spec:
  groups:
  - name: multi-cluster.rules
    rules:
    - alert: CrossClusterConnectivityLoss
      expr: absent(up{job="istio-proxy", cluster!="unknown"}) == 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Cross-cluster connectivity lost"
        description: "No metrics received from remote cluster for 5 minutes"
    
    - alert: CrossClusterHighLatency
      expr: histogram_quantile(0.95, sum(rate(istio_request_duration_milliseconds_bucket{source_cluster!="unknown",destination_cluster!="unknown",source_cluster!=destination_cluster}[5m])) by (le)) > 1000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High cross-cluster latency"
        description: "95th percentile cross-cluster latency is above 1s"
    
    - alert: CrossClusterCertificateExpiry
      expr: (istio_cert_expiry_timestamp{cluster!="unknown"} - time()) / 86400 < 7
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Cross-cluster certificate expiring soon"
        description: "Certificate in cluster {{ $labels.cluster }} expires in less than 7 days"
```

Multi-cluster service mesh обеспечивает единую архитектуру безопасности, управления и наблюдаемости для распределенных микросервисных приложений, развернутых в нескольких Kubernetes кластерах, с автоматическим service discovery, mTLS и intelligent traffic routing.
