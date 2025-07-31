# 175. Как реализовать mTLS с service mesh?

## 🎯 **Что такое mTLS в service mesh?**

**mTLS (mutual TLS)** в service mesh обеспечивает автоматическое взаимное шифрование и аутентификацию между сервисами через автоматическое управление сертификатами, identity-based authentication и policy enforcement без изменения кода приложений.

## 🏗️ **Основные компоненты mTLS:**

### **1. Certificate Authority (CA)**
- Автоматическая выдача сертификатов
- Ротация сертификатов
- SPIFFE-based identity

### **2. Policy Enforcement**
- PeerAuthentication для mTLS режимов
- AuthorizationPolicy для доступа
- DestinationRule для TLS настроек

### **3. Identity Management**
- ServiceAccount mapping
- Trust domain configuration
- Workload identity

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка текущего mTLS статуса:**
```bash
# Общий статус mTLS в кластере
istioctl authn tls-check

# Статус для конкретного сервиса
istioctl authn tls-check sample-app.production.svc.cluster.local

# Проверка сертификатов в sidecar
kubectl exec deployment/sample-app -n production -c istio-proxy -- \
  openssl s_client -connect sample-app:8080 -showcerts < /dev/null

# SPIFFE identity проверка
kubectl exec deployment/sample-app -n production -c istio-proxy -- \
  cat /var/run/secrets/workload-spiffe-credentials/cert.pem | \
  openssl x509 -text -noout | grep "Subject Alternative Name"
```

### **2. Включение strict mTLS:**
```bash
# Глобальная политика strict mTLS
kubectl apply -f - << EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF

# Проверка применения политики
kubectl get peerauthentication --all-namespaces

# Тестирование mTLS соединения
kubectl run test-client --image=curlimages/curl --rm -i --restart=Never -- \
  curl -v http://sample-app.production.svc.cluster.local:8080/
```

### **3. Настройка namespace-level mTLS:**
```bash
# mTLS для конкретного namespace
kubectl apply -f - << EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: production-mtls
  namespace: production
spec:
  mtls:
    mode: STRICT
EOF

# Проверка статуса
istioctl authn tls-check --namespace production

# Проверка Envoy конфигурации
kubectl exec deployment/sample-app -n production -c istio-proxy -- \
  pilot-agent request GET config_dump | jq '.configs[3].dynamic_active_clusters'
```

### **4. Service-level mTLS конфигурация:**
```bash
# mTLS для конкретного сервиса
kubectl apply -f - << EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: sample-app-mtls
  namespace: production
spec:
  selector:
    matchLabels:
      app: sample-app
  mtls:
    mode: STRICT
  portLevelMtls:
    8080:
      mode: STRICT
    8443:
      mode: DISABLE
EOF

# DestinationRule для mTLS
kubectl apply -f - << EOF
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
  subsets:
  - name: v1
    labels:
      version: v1
    trafficPolicy:
      tls:
        mode: ISTIO_MUTUAL
EOF
```

### **5. Проверка сертификатов:**
```bash
# Проверка root CA
kubectl get secret istio-ca-secret -n istio-system -o jsonpath='{.data.cert-chain\.pem}' | \
  base64 -d | openssl x509 -text -noout | grep -A 5 "Subject:"

# Срок действия root CA
kubectl get secret istio-ca-secret -n istio-system -o jsonpath='{.data.cert-chain\.pem}' | \
  base64 -d | openssl x509 -noout -dates

# Workload сертификаты
kubectl exec deployment/sample-app -n production -c istio-proxy -- \
  openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -noout -dates

# Проверка certificate chain
kubectl exec deployment/sample-app -n production -c istio-proxy -- \
  openssl verify -CAfile /var/run/secrets/istio/root-cert.pem \
  /var/run/secrets/workload-spiffe-credentials/cert.pem
```

## 🔐 **Управление сертификатами:**

### **1. Ротация root CA:**
```bash
# Создание нового root CA
openssl genrsa -out new-root-key.pem 4096

openssl req -new -x509 -key new-root-key.pem -out new-root-cert.pem -days 3650 \
  -subj "/C=US/ST=CA/L=San Francisco/O=HashFoundry/OU=Infrastructure/CN=HashFoundry Root CA"

# Backup текущего CA
kubectl get secret istio-ca-secret -n istio-system -o yaml > \
  istio-ca-secret-backup-$(date +%s).yaml

# Обновление CA secret
kubectl create secret generic istio-ca-secret \
  --from-file=root-cert.pem=new-root-cert.pem \
  --from-file=cert-chain.pem=new-root-cert.pem \
  --from-file=ca-cert.pem=new-root-cert.pem \
  --from-file=ca-key.pem=new-root-key.pem \
  --namespace=istio-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Перезапуск Istiod
kubectl rollout restart deployment/istiod -n istio-system
kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=300s

# Очистка
rm -f new-root-key.pem new-root-cert.pem
```

### **2. Принудительная ротация workload сертификатов:**
```bash
# Получение namespace с Istio injection
ISTIO_NAMESPACES=$(kubectl get namespaces -l istio-injection=enabled -o jsonpath='{.items[*].metadata.name}')

for ns in $ISTIO_NAMESPACES; do
  echo "Ротация сертификатов в namespace: $ns"
  
  # Перезапуск deployments
  kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}' | \
    xargs -n 1 -I {} kubectl rollout restart deployment/{} -n $ns
  
  # Ожидание завершения
  kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}' | \
    xargs -n 1 -I {} kubectl rollout status deployment/{} -n $ns --timeout=300s
done
```

### **3. Мониторинг сертификатов:**
```bash
# Проверка истечения root CA
ROOT_CA_EXPIRY=$(kubectl get secret istio-ca-secret -n istio-system -o jsonpath='{.data.cert-chain\.pem}' | \
  base64 -d | openssl x509 -noout -enddate | cut -d= -f2)
echo "Root CA истекает: $ROOT_CA_EXPIRY"

# Проверка workload сертификатов
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | \
  while read ns pod; do
    if kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[*].name}' | grep -q istio-proxy; then
      CERT_EXPIRY=$(kubectl exec $pod -n $ns -c istio-proxy -- \
        openssl x509 -in /var/run/secrets/workload-spiffe-credentials/cert.pem -noout -enddate 2>/dev/null | \
        cut -d= -f2)
      echo "$ns/$pod: $CERT_EXPIRY"
    fi
  done | head -5
```

## 🔧 **Продвинутые mTLS конфигурации:**

### **1. Custom CA интеграция:**
```bash
# Создание custom CA secret
kubectl apply -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: custom-ca-secret
  namespace: istio-system
  labels:
    istio.io/ca-root: "true"
type: Opaque
data:
  root-cert.pem: $(cat custom-root-cert.pem | base64 -w 0)
  cert-chain.pem: $(cat custom-cert-chain.pem | base64 -w 0)
  ca-cert.pem: $(cat custom-ca-cert.pem | base64 -w 0)
  ca-key.pem: $(cat custom-ca-key.pem | base64 -w 0)
EOF

# Настройка Istiod для custom CA
kubectl patch deployment istiod -n istio-system -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "discovery",
            "env": [
              {"name": "EXTERNAL_CA", "value": "true"},
              {"name": "PILOT_CERT_PROVIDER", "value": "custom"}
            ]
          }
        ]
      }
    }
  }
}'
```

### **2. Multi-cluster mTLS:**
```bash
# Cross-cluster service entry
kubectl apply -f - << EOF
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
  endpoints:
  - address: remote-service.remote-cluster.local
    ports:
      http: 8080
---
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
EOF
```

### **3. Legacy service integration:**
```bash
# PERMISSIVE mode для legacy сервисов
kubectl apply -f - << EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: legacy-service
  namespace: production
spec:
  selector:
    matchLabels:
      app: legacy-app
  mtls:
    mode: PERMISSIVE
EOF

# Тестирование legacy connectivity
kubectl run legacy-test --image=curlimages/curl --rm -i --restart=Never -- \
  curl -v http://legacy-app.production.svc.cluster.local:8080/
```

## 📈 **Мониторинг mTLS:**

### **1. Prometheus метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &

# Ключевые mTLS метрики:
# istio_requests_total{security_policy="mutual_tls"} - mTLS запросы
# pilot_k8s_cfg_events{type="Warning"} - ошибки конфигурации
# citadel_server_csr_count - количество CSR запросов
# citadel_server_success_cert_issuance_count - успешные выдачи сертификатов
```

### **2. Grafana дашборд для mTLS:**
```bash
# Создание ConfigMap с дашбордом
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mtls-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  mtls-dashboard.json: |
    {
      "dashboard": {
        "title": "mTLS Security Dashboard",
        "panels": [
          {
            "title": "mTLS Connection Success Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total{security_policy=\"mutual_tls\",response_code=~\"2.*\"}[5m])) / sum(rate(istio_requests_total{security_policy=\"mutual_tls\"}[5m]))"
              }
            ]
          },
          {
            "title": "Certificate Expiry Status",
            "type": "graph",
            "targets": [
              {
                "expr": "(pilot_cert_expiry_timestamp - time()) / 86400"
              }
            ]
          }
        ]
      }
    }
EOF
```

### **3. Алерты для mTLS:**
```bash
# PrometheusRule для mTLS алертов
kubectl apply -f - << EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mtls-alerts
  namespace: istio-system
spec:
  groups:
  - name: mtls.rules
    rules:
    - alert: CertificateExpiringSoon
      expr: (pilot_cert_expiry_timestamp - time()) / 86400 < 30
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Certificate expiring soon"
        description: "Certificate expires in less than 30 days"
    
    - alert: mTLSConnectionFailure
      expr: increase(istio_requests_total{security_policy="mutual_tls",response_code!~"2.*"}[5m]) > 10
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "mTLS connection failures detected"
        description: "High number of mTLS failures"
EOF
```

## 🚨 **Диагностика mTLS проблем:**

### **1. Проверка конфигурации:**
```bash
# Анализ конфигурации
istioctl analyze --all-namespaces

# Проверка PeerAuthentication политик
kubectl get peerauthentication --all-namespaces

# Проверка DestinationRule TLS настроек
kubectl get destinationrule --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.trafficPolicy.tls.mode}{"\n"}{end}'

# Статус proxy конфигурации
istioctl proxy-status
```

### **2. Проверка Envoy конфигурации:**
```bash
# TLS конфигурация в Envoy
POD_NAME=$(kubectl get pods -n production -l app=sample-app -o jsonpath='{.items[0].metadata.name}')

kubectl exec $POD_NAME -n production -c istio-proxy -- \
  pilot-agent request GET config_dump | \
  jq '.configs[] | select(.["@type"] | contains("ClustersConfigDump")) | .dynamic_active_clusters[] | select(.cluster.transport_socket.typed_config.common_tls_context) | {name: .cluster.name, tls: .cluster.transport_socket.typed_config.common_tls_context}'
```

### **3. Логи и события:**
```bash
# Istiod логи
kubectl logs -n istio-system -l app=istiod --tail=50 | grep -i error

# События в istio-system
kubectl get events -n istio-system --sort-by='.lastTimestamp' | tail -10

# Envoy access logs
kubectl logs $POD_NAME -n production -c istio-proxy | grep "response_code"
```

## 🎯 **Best Practices для mTLS:**

### **1. Поэтапное внедрение:**
- Начать с PERMISSIVE mode
- Постепенно переходить к STRICT mode
- Тестировать каждый сервис отдельно
- Мониторить метрики на каждом этапе

### **2. Управление сертификатами:**
- Регулярно мониторить срок действия
- Автоматизировать ротацию
- Создавать backup CA сертификатов
- Планировать обновления заранее

### **3. Мониторинг и алертинг:**
- Настроить алерты на истечение сертификатов
- Мониторить success rate mTLS соединений
- Отслеживать ошибки конфигурации
- Регулярно проверять статус CA

### **4. Troubleshooting:**
- Использовать istioctl для диагностики
- Проверять Envoy конфигурацию
- Анализировать логи Istiod
- Тестировать connectivity между сервисами

**mTLS в service mesh обеспечивает автоматическую zero-trust безопасность для микросервисной коммуникации!**
