# 175. Как реализовать mTLS с service mesh?

## 🎯 Вопрос
Как реализовать mTLS с service mesh?

## 💡 Ответ

mTLS (mutual TLS) в service mesh обеспечивает автоматическое взаимное шифрование и аутентификацию между сервисами через автоматическое управление сертификатами, identity-based authentication и policy enforcement. Istio автоматически выдает, ротирует и управляет сертификатами для каждого сервиса, обеспечивая zero-trust security модель.

### 🏗️ Архитектура mTLS в Service Mesh

#### 1. **Схема mTLS flow**
```
┌─────────────────────────────────────────────────────────────┐
│                    mTLS in Service Mesh                    │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Control Plane                          │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │              Citadel (CA)                          ││ │
│  │  │  • Certificate Authority                           ││ │
│  │  │  • Certificate Issuance                            ││ │
│  │  │  • Certificate Rotation                            ││ │
│  │  │  • Root CA Management                              ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              │ Certificate Distribution     │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   Data Plane                           │ │
│  │                                                         │ │
│  │  ┌─────────────┐                    ┌─────────────┐     │ │
│  │  │   Service   │                    │   Service   │     │ │
│  │  │      A      │                    │      B      │     │ │
│  │  └─────────────┘                    └─────────────┘     │ │
│  │         │                                   │           │ │
│  │  ┌─────────────┐                    ┌─────────────┐     │ │
│  │  │    Envoy    │◄──── mTLS ────────▶│    Envoy    │     │ │
│  │  │   Sidecar   │    Connection      │   Sidecar   │     │ │
│  │  │             │                    │             │     │ │
│  │  │ ┌─────────┐ │                    │ ┌─────────┐ │     │ │
│  │  │ │Client   │ │                    │ │Server   │ │     │ │
│  │  │ │Cert     │ │                    │ │Cert     │ │     │ │
│  │  │ └─────────┘ │                    │ └─────────┘ │     │ │
│  │  └─────────────┘                    └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **mTLS компоненты**
```yaml
# Компоненты mTLS в service mesh
mtls_components:
  certificate_authority:
    root_ca: "Корневой сертификат для mesh"
    intermediate_ca: "Промежуточные CA для namespace"
    workload_certificates: "Сертификаты для каждого workload"
    
  identity_management:
    spiffe_id: "SPIFFE-based identity для сервисов"
    service_account: "Kubernetes ServiceAccount mapping"
    trust_domain: "Доменное пространство доверия"
    
  policy_enforcement:
    peer_authentication: "Политики mTLS аутентификации"
    authorization_policy: "Правила авторизации"
    destination_rule: "Настройки TLS для destinations"
    
  certificate_lifecycle:
    automatic_issuance: "Автоматическая выдача сертификатов"
    rotation: "Автоматическая ротация"
    revocation: "Отзыв скомпрометированных сертификатов"
    monitoring: "Мониторинг состояния сертификатов"
```

### 📊 Примеры из нашего кластера

#### Проверка mTLS статуса:
```bash
# Проверка общего статуса mTLS
istioctl authn tls-check

# Проверка mTLS для конкретного сервиса
istioctl authn tls-check sample-app.production.svc.cluster.local

# Проверка сертификатов в sidecar
kubectl exec deployment/sample-app -n production -c istio-proxy -- \
  openssl s_client -connect sample-app:8080 -showcerts

# Проверка SPIFFE identity
kubectl exec deployment/sample-app -n production -c istio-proxy -- \
  cat /var/run/secrets/workload-spiffe-credentials/cert.pem | \
  openssl x509 -text -noout | grep "Subject Alternative Name"
```

### 🔐 Настройка mTLS политик

#### 1. **PeerAuthentication конфигурация**
```yaml
# peer-authentication-configs.yaml

# Глобальная политика mTLS для всего mesh
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
# Политика mTLS для конкретного namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: namespace-policy
  namespace: production
spec:
  mtls:
    mode: STRICT
---
# Политика mTLS для конкретного сервиса
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: service-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: sample-app
  mtls:
    mode: STRICT
---
# Политика с исключениями для legacy сервисов
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: legacy-service-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: legacy-app
  mtls:
    mode: PERMISSIVE
  portLevelMtls:
    8080:
      mode: DISABLE
    8443:
      mode: STRICT
---
# Политика для external сервисов
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: external-service-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: external-gateway
  mtls:
    mode: DISABLE
```

#### 2. **DestinationRule для mTLS**
```yaml
# destination-rule-mtls.yaml

# DestinationRule с mTLS настройками
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: sample-app-mtls
  namespace: production
spec:
  host: sample-app.production.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    circuitBreaker:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
  subsets:
  - name: v1
    labels:
      version: v1
    trafficPolicy:
      tls:
        mode: ISTIO_MUTUAL
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      tls:
        mode: ISTIO_MUTUAL
---
# DestinationRule для external сервиса с custom TLS
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: external-service-tls
  namespace: production
spec:
  host: external-api.example.com
  trafficPolicy:
    tls:
      mode: SIMPLE
      caCertificates: /etc/ssl/certs/ca-certificates.crt
      sni: external-api.example.com
---
# DestinationRule для mutual TLS с custom сертификатами
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: custom-mtls
  namespace: production
spec:
  host: secure-service.production.svc.cluster.local
  trafficPolicy:
    tls:
      mode: MUTUAL
      clientCertificate: /etc/certs/client-cert.pem
      privateKey: /etc/certs/client-key.pem
      caCertificates: /etc/certs/ca-cert.pem
```

### 🔧 Управление сертификатами

#### 1. **Скрипт управления mTLS сертификатами**
```bash
#!/bin/bash
# manage-mtls-certificates.sh

echo "🔐 Управление mTLS сертификатами в Service Mesh"

# Проверка статуса CA
check_ca_status() {
    echo "🏛️ Проверка статуса Certificate Authority"
    
    # Проверка root CA сертификата
    echo "=== Root CA Certificate ==="
    kubectl get secret istio-ca-secret -n istio-system -o jsonpath='{.data.cert-chain\.pem}' | \
        base64 -d | openssl x509 -text -noout | grep -A 5 "Subject:"
    
    # Проверка срока действия root CA
    echo "=== Root CA Validity ==="
    kubectl get secret istio-ca-secret -n istio-system -o jsonpath='{.data.cert-chain\.pem}' | \
        base64 -d | openssl x509 -noout -dates
    
    # Проверка Istiod CA статуса
    echo "=== Istiod CA Status ==="
    kubectl get pods -n istio-system -l app=istiod -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}'
    
    # Проверка CA конфигурации
    echo "=== CA Configuration ==="
    kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -A 10 "defaultConfig:"
    
    echo "✅ CA статус проверен"
}

# Проверка workload сертификатов
check_workload_certificates() {
    echo "📋 Проверка workload сертификатов"
    
    # Поиск всех подов с Istio sidecar
    local pods_with_sidecar=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | \
        while read ns pod; do
            if kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[*].name}' | grep -q istio-proxy; then
                echo "$ns $pod"
            fi
        done)
    
    echo "=== Workload Certificates Status ==="
    while read ns pod; do
        if [ -n "$ns" ] && [ -n "$pod" ]; then
            echo "Проверка сертификата для $ns/$pod:"
            
            # Проверка наличия сертификата
            kubectl exec $pod -n $ns -c istio-proxy -- \
                ls -la /var/run/secrets/workload-spiffe-credentials/ 2>/dev/null || echo "Сертификат не найден"
            
            # Проверка срока действия
            kubectl exec $pod -n $ns -c istio-proxy -- \
                openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -noout -dates 2>/dev/null || echo "Не удалось проверить срок действия"
            
            # Проверка SPIFFE ID
            kubectl exec $pod -n $ns -c istio-proxy -- \
                openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -text -noout | \
                grep "Subject Alternative Name" 2>/dev/null || echo "SPIFFE ID не найден"
            
            echo "---"
        fi
    done <<< "$pods_with_sidecar"
    
    echo "✅ Workload сертификаты проверены"
}

# Ротация root CA
rotate_root_ca() {
    echo "🔄 Ротация root CA сертификата"
    
    # Создание нового root CA
    echo "Создание нового root CA..."
    
    # Генерация нового приватного ключа
    openssl genrsa -out new-root-key.pem 4096
    
    # Создание нового root сертификата
    openssl req -new -x509 -key new-root-key.pem -out new-root-cert.pem -days 3650 \
        -subj "/C=US/ST=CA/L=San Francisco/O=HashFoundry/OU=Infrastructure/CN=HashFoundry Root CA"
    
    # Создание certificate chain
    cat new-root-cert.pem > new-cert-chain.pem
    
    # Backup текущего CA
    kubectl get secret istio-ca-secret -n istio-system -o yaml > istio-ca-secret-backup-$(date +%s).yaml
    
    # Обновление CA secret
    kubectl create secret generic istio-ca-secret \
        --from-file=root-cert.pem=new-root-cert.pem \
        --from-file=cert-chain.pem=new-cert-chain.pem \
        --from-file=ca-cert.pem=new-root-cert.pem \
        --from-file=ca-key.pem=new-root-key.pem \
        --namespace=istio-system \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Перезапуск Istiod для применения нового CA
    kubectl rollout restart deployment/istiod -n istio-system
    
    # Ожидание готовности
    kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=300s
    
    # Очистка временных файлов
    rm -f new-root-key.pem new-root-cert.pem new-cert-chain.pem
    
    echo "✅ Root CA ротация завершена"
}

# Принудительная ротация workload сертификатов
force_workload_cert_rotation() {
    echo "🔄 Принудительная ротация workload сертификатов"
    
    # Получение списка всех namespace с Istio injection
    local istio_namespaces=$(kubectl get namespaces -l istio-injection=enabled -o jsonpath='{.items[*].metadata.name}')
    
    for ns in $istio_namespaces; do
        echo "Ротация сертификатов в namespace: $ns"
        
        # Перезапуск всех deployments в namespace
        kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}' | \
            xargs -n 1 -I {} kubectl rollout restart deployment/{} -n $ns
        
        # Ожидание завершения rollout
        kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}' | \
            xargs -n 1 -I {} kubectl rollout status deployment/{} -n $ns --timeout=300s
    done
    
    echo "✅ Workload сертификаты ротированы"
}

# Мониторинг сертификатов
monitor_certificate_expiry() {
    echo "📊 Мониторинг истечения сертификатов"
    
    # Проверка root CA
    echo "=== Root CA Expiry ==="
    local root_ca_expiry=$(kubectl get secret istio-ca-secret -n istio-system -o jsonpath='{.data.cert-chain\.pem}' | \
        base64 -d | openssl x509 -noout -enddate | cut -d= -f2)
    echo "Root CA истекает: $root_ca_expiry"
    
    # Проверка workload сертификатов
    echo "=== Workload Certificates Expiry ==="
    local pods_with_sidecar=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | \
        while read ns pod; do
            if kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[*].name}' | grep -q istio-proxy; then
                echo "$ns $pod"
            fi
        done | head -5)  # Ограничиваем для примера
    
    while read ns pod; do
        if [ -n "$ns" ] && [ -n "$pod" ]; then
            local cert_expiry=$(kubectl exec $pod -n $ns -c istio-proxy -- \
                openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -noout -enddate 2>/dev/null | \
                cut -d= -f2)
            echo "$ns/$pod: $cert_expiry"
        fi
    done <<< "$pods_with_sidecar"
    
    echo "✅ Мониторинг сертификатов завершен"
}

# Диагностика mTLS проблем
diagnose_mtls_issues() {
    echo "🔧 Диагностика mTLS проблем"
    
    # Проверка PeerAuthentication политик
    echo "=== PeerAuthentication Policies ==="
    kubectl get peerauthentication --all-namespaces
    
    # Проверка DestinationRule конфигураций
    echo "=== DestinationRule TLS Settings ==="
    kubectl get destinationrule --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.trafficPolicy.tls.mode}{"\n"}{end}'
    
    # Проверка Envoy конфигурации
    echo "=== Envoy TLS Configuration ==="
    local pod_with_sidecar=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | \
        while read ns pod; do
            if kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[*].name}' | grep -q istio-proxy; then
                echo "$ns $pod"
                break
            fi
        done)
    
    if [ -n "$pod_with_sidecar" ]; then
        local namespace=$(echo $pod_with_sidecar | awk '{print $1}')
        local pod_name=$(echo $pod_with_sidecar | awk '{print $2}')
        
        echo "Проверка Envoy конфигурации для $namespace/$pod_name:"
        kubectl exec $pod_name -n $namespace -c istio-proxy -- \
            pilot-agent request GET config_dump | jq '.configs[] | select(.["@type"] | contains("type.googleapis.com/envoy.admin.v3.ClustersConfigDump")) | .dynamic_active_clusters[] | select(.cluster.transport_socket.typed_config.common_tls_context) | {name: .cluster.name, tls: .cluster.transport_socket.typed_config.common_tls_context}'
    fi
    
    # Проверка логов Istiod
    echo "=== Istiod Logs (последние ошибки) ==="
    kubectl logs -n istio-system -l app=istiod --tail=20 | grep -i error
    
    echo "✅ Диагностика завершена"
}

# Основная логика
case "$1" in
    check-ca)
        check_ca_status
        ;;
    check-workload)
        check_workload_certificates
        ;;
    rotate-ca)
        rotate_root_ca
        ;;
    rotate-workload)
        force_workload_cert_rotation
        ;;
    monitor)
        monitor_certificate_expiry
        ;;
    diagnose)
        diagnose_mtls_issues
        ;;
    full-check)
        check_ca_status
        check_workload_certificates
        monitor_certificate_expiry
        ;;
    *)
        echo "Использование: $0 {check-ca|check-workload|rotate-ca|rotate-workload|monitor|diagnose|full-check}"
        exit 1
        ;;
esac
```

### 🎯 Продвинутые mTLS конфигурации

#### 1. **Custom CA интеграция**
```yaml
# custom-ca-integration.yaml

# Использование external CA
apiVersion: v1
kind: Secret
metadata:
  name: custom-ca-secret
  namespace: istio-system
  labels:
    istio.io/ca-root: "true"
type: Opaque
data:
  # Custom root certificate
  root-cert.pem: LS0tLS1CRUdJTi... # base64 encoded
  # Certificate chain
  cert-chain.pem: LS0tLS1CRUdJTi... # base64 encoded
  # CA certificate
  ca-cert.pem: LS0tLS1CRUdJTi... # base64 encoded
  # CA private key
  ca-key.pem: LS0tLS1CRUdJTi... # base64 encoded
---
# Istiod конфигурация для custom CA
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*circuit_breakers.*"
        - ".*upstream_rq_retry.*"
        - ".*_cx_.*"
    trustDomain: "hashfoundry.local"
    defaultProviders:
      metrics:
      - prometheus
    extensionProviders:
    - name: prometheus
      prometheus: {}
---
# Istiod deployment с custom CA
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  template:
    spec:
      containers:
      - name: discovery
        env:
        - name: EXTERNAL_CA
          value: "true"
        - name: PILOT_CERT_PROVIDER
          value: "custom"
        - name: CUSTOM_CA_CERT_DIR
          value: "/etc/cacerts"
        volumeMounts:
        - name: cacerts
          mountPath: /etc/cacerts
          readOnly: true
      volumes:
      - name: cacerts
        secret:
          secretName: custom-ca-secret
```

#### 2. **Multi-cluster mTLS**
```yaml
# multi-cluster-mtls.yaml

# Cross-cluster service entry
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: remote-service
  namespace: production
spec:
  hosts:
  - remote-service.remote-cluster.local
  location: MESH_EXTERNAL
  ports:
  - number: 8080
    name: http
    protocol: HTTP
  resolution: DNS
  addresses:
  - 10.0.0.100
  endpoints:
  - address: remote-service.remote-cluster.local
    ports:
      http: 8080
---
# DestinationRule для cross-cluster mTLS
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: remote-service-mtls
  namespace: production
spec:
  host: remote-service.remote-cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
  exportTo:
  - "."
---
# PeerAuthentication для cross-cluster
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: cross-cluster-mtls
  namespace: production
spec:
  selector:
    matchLabels:
      app: gateway
  mtls:
    mode: STRICT
```

### 📊 Мониторинг mTLS

#### 1. **Prometheus метрики для mTLS**
```yaml
# mtls-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mtls-monitoring
  namespace: istio-system
spec:
  groups:
  - name: mtls-certificates
    rules:
    - alert: CertificateExpiringSoon
      expr: (istio_cert_expiry_timestamp - time()) / 86400 < 30
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Certificate expiring soon"
        description: "Certificate for {{ $labels.source_workload }} expires in less than 30 days"
    
    - alert: mTLSConnectionFailure
      expr: increase(istio_requests_total{security_policy="mutual_tls",response_code!~"2.*"}[5m]) > 10
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "mTLS connection failures detected"
        description: "High number of mTLS connection failures for {{ $labels.destination_service_name }}"
    
    - alert: CertificateRotationFailure
      expr: increase(pilot_k8s_cfg_events{type="Warning",reason="CertificateRotationFailed"}[10m]) > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Certificate rotation failed"
        description: "Certificate rotation failed for workload"
---
# Grafana Dashboard для mTLS
apiVersion: v1
kind: ConfigMap
metadata:
  name: mtls-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "mTLS Security Dashboard",
        "panels": [
          {
            "title": "Certificate Expiry Status",
            "type": "stat",
            "targets": [
              {
                "expr": "(istio_cert_expiry_timestamp - time()) / 86400"
              }
            ]
          },
          {
            "title": "mTLS Connection Success Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(istio_requests_total{security_policy=\"mutual_tls\",response_code=~\"2.*\"}[5m]) / rate(istio_requests_total{security_policy=\"mutual_tls\"}[5m])"
              }
            ]
          },
          {
            "title": "Certificate Rotation Events",
            "type": "logs",
            "targets": [
              {
                "expr": "{job=\"pilot\"} |= \"certificate\""
              }
            ]
          }
        ]
      }
    }
```

mTLS в service mesh обеспечивает автоматическую и прозрачную безопасность для микросервисной коммуникации, устраняя необходимость в ручном управлении сертификатами и обеспечивая zero-trust security модель с минимальными изменениями в коде приложений.
