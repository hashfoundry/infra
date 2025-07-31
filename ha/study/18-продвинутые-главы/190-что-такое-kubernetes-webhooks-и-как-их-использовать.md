# 190. Что такое Kubernetes Webhooks и как их использовать?

## 🎯 **Что такое Kubernetes Webhooks?**

**Kubernetes Webhooks** — это HTTP callbacks, которые позволяют внешним системам получать уведомления о событиях в кластере или влиять на поведение Kubernetes API Server. Webhooks обеспечивают расширяемость кластера через Admission Webhooks (валидация и мутация ресурсов) и Conversion Webhooks (конвертация между версиями API).

## 🏗️ **Основные компоненты Webhooks:**

### **1. Admission Webhooks**
- Mutating Admission Webhooks — изменяют объекты перед сохранением
- Validating Admission Webhooks — валидируют объекты без изменения
- Выполняются в admission controller chain

### **2. Webhook Server**
- HTTPS endpoint для обработки webhook requests
- Обработка AdmissionReview objects
- Возврат AdmissionResponse с результатами

### **3. Webhook Configuration**
- MutatingAdmissionWebhook и ValidatingAdmissionWebhook CRDs
- Правила для определения scope webhooks
- Failure policies и timeout settings

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка существующих webhooks:**
```bash
# Mutating admission webhooks
kubectl get mutatingadmissionwebhooks

# Validating admission webhooks  
kubectl get validatingadmissionwebhooks

# Webhook configurations
kubectl describe mutatingadmissionwebhook | head -20
kubectl describe validatingadmissionwebhook | head -20

# Webhook endpoints
kubectl get endpoints --all-namespaces | grep webhook
```

### **2. ArgoCD webhooks:**
```bash
# ArgoCD admission webhooks
kubectl get mutatingadmissionwebhooks | grep argocd
kubectl get validatingadmissionwebhooks | grep argocd

# ArgoCD webhook services
kubectl get svc -n argocd | grep webhook
kubectl describe svc -n argocd | grep -A 10 webhook

# ArgoCD webhook logs
kubectl logs -n argocd -l app.kubernetes.io/component=server | grep webhook
```

### **3. Monitoring webhooks:**
```bash
# Webhook metrics
kubectl get --raw /metrics | grep admission_webhook

# Webhook latency
kubectl get --raw /metrics | grep apiserver_admission_webhook_admission_duration_seconds

# Webhook failures
kubectl get events --all-namespaces --field-selector reason=FailedAdmissionWebhook

# Certificate status
kubectl get secrets --all-namespaces | grep webhook
```

### **4. Webhook testing:**
```bash
# Test webhook response
kubectl create namespace webhook-test --dry-run=client -o yaml

# Check admission controller chain
kubectl get --raw /api/v1 | jq '.resources[] | select(.name == "pods") | .verbs'

# Webhook admission events
kubectl get events --field-selector type=Warning | grep -i admission
```

## 🔄 **Webhook Lifecycle:**

### **1. Webhook registration:**
```bash
# Создание простого validating webhook
cat << EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: example-validator
webhooks:
- name: pod-validator.example.com
  clientConfig:
    url: "https://webhook.example.com/validate"
    caBundle: LS0tLS1CRUdJTi... # Base64 CA cert
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
EOF

# Проверка регистрации
kubectl get validatingadmissionwebhook example-validator
kubectl describe validatingadmissionwebhook example-validator
```

### **2. Mutating webhook example:**
```bash
# Создание mutating webhook
cat << EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: example-mutator
webhooks:
- name: pod-mutator.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/mutate"
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Ignore
  namespaceSelector:
    matchLabels:
      webhook: "enabled"
EOF

# Проверка mutating webhook
kubectl get mutatingadmissionwebhook example-mutator
kubectl describe mutatingadmissionwebhook example-mutator
```

### **3. Webhook testing:**
```bash
# Создание test namespace с webhook label
kubectl create namespace webhook-test
kubectl label namespace webhook-test webhook=enabled

# Test pod creation
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webhook-test-pod
  namespace: webhook-test
spec:
  containers:
  - name: test
    image: nginx:alpine
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 64Mi
EOF

# Проверка результата
kubectl describe pod -n webhook-test webhook-test-pod | grep -A 10 "Events:"

# Очистка
kubectl delete pod -n webhook-test webhook-test-pod
kubectl delete namespace webhook-test
kubectl delete validatingadmissionwebhook example-validator
kubectl delete mutatingadmissionwebhook example-mutator
```

## 📈 **Мониторинг Webhook Operations:**

### **1. Webhook performance:**
```bash
# Admission webhook latency
kubectl get --raw /metrics | grep "apiserver_admission_webhook_admission_duration_seconds"

# Webhook request count
kubectl get --raw /metrics | grep "apiserver_admission_webhook_request_total"

# Webhook rejection count
kubectl get --raw /metrics | grep "apiserver_admission_webhook_rejection_count"

# API server admission latency
kubectl get --raw /metrics | grep "apiserver_admission_controller_admission_duration_seconds"
```

### **2. Webhook health monitoring:**
```bash
# Webhook endpoint availability
kubectl get mutatingadmissionwebhooks -o json | jq '.items[] | {name: .metadata.name, webhooks: [.webhooks[] | {name: .name, service: .clientConfig.service}]}'

# Webhook certificate expiration
kubectl get secrets --all-namespaces -o json | jq '.items[] | select(.metadata.name | contains("webhook")) | {namespace: .metadata.namespace, name: .metadata.name, type: .type}'

# Webhook failure events
kubectl get events --all-namespaces --field-selector type=Warning | grep -E "(webhook|admission)"
```

### **3. Troubleshooting webhooks:**
```bash
# Webhook configuration issues
kubectl get validatingadmissionwebhooks -o yaml | grep -A 10 "failurePolicy"
kubectl get mutatingadmissionwebhooks -o yaml | grep -A 10 "failurePolicy"

# Webhook timeout issues
kubectl get events --field-selector reason=AdmissionWebhookTimeout

# Certificate issues
kubectl get events --field-selector reason=FailedAdmissionWebhook | grep -i certificate
```

## 🏭 **Webhooks в вашем HA кластере:**

### **1. ArgoCD webhook integration:**
```bash
# ArgoCD application webhooks
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, webhooks: (.spec.source.helm.parameters // [] | map(select(.name | contains("webhook"))))}'

# ArgoCD notification webhooks
kubectl get secrets -n argocd | grep webhook
kubectl describe secret -n argocd | grep -A 5 webhook

# ArgoCD webhook events
kubectl get events -n argocd --field-selector involvedObject.kind=Application | grep webhook
```

### **2. Monitoring webhook integration:**
```bash
# Prometheus webhook configuration
kubectl get secrets -n monitoring | grep webhook
kubectl describe configmap -n monitoring | grep -A 10 webhook

# Grafana webhook alerts
kubectl get configmaps -n monitoring -o yaml | grep -A 10 webhook

# Alertmanager webhook receivers
kubectl describe configmap -n monitoring alertmanager-config | grep -A 10 webhook
```

### **3. Security webhook policies:**
```bash
# Pod security webhooks
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.metadata.annotations // {} | keys[] | contains("webhook")) | {namespace: .metadata.namespace, name: .metadata.name}'

# Network policy webhooks
kubectl get networkpolicies --all-namespaces -o json | jq '.items[] | select(.metadata.annotations // {} | keys[] | contains("webhook"))'

# RBAC webhook validation
kubectl auth can-i create pods --as=system:serviceaccount:webhook-system:webhook-service
```

## 🔧 **Создание простого Webhook Server:**

### **1. Mock webhook server:**
```bash
# Создание namespace
kubectl create namespace webhook-system

# Mock webhook deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mock-webhook
  namespace: webhook-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mock-webhook
  template:
    metadata:
      labels:
        app: mock-webhook
    spec:
      containers:
      - name: webhook
        image: nginx:alpine
        ports:
        - containerPort: 8443
        command:
        - /bin/sh
        - -c
        - |
          echo "Mock Webhook Server starting..."
          echo "Listening on port 8443..."
          while true; do
            echo "Processing webhook requests..."
            sleep 30
          done
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: mock-webhook-service
  namespace: webhook-system
spec:
  selector:
    app: mock-webhook
  ports:
  - name: webhook
    port: 443
    targetPort: 8443
    protocol: TCP
EOF

# Проверка deployment
kubectl get pods -n webhook-system
kubectl get svc -n webhook-system
```

### **2. Webhook certificate setup:**
```bash
# Создание self-signed certificate
openssl req -x509 -newkey rsa:2048 -keyout webhook.key -out webhook.crt -days 365 -nodes -subj "/CN=mock-webhook-service.webhook-system.svc"

# Создание secret
kubectl create secret tls webhook-certs -n webhook-system --cert=webhook.crt --key=webhook.key

# CA bundle для webhook config
CA_BUNDLE=$(cat webhook.crt | base64 | tr -d '\n')
echo "CA Bundle: $CA_BUNDLE"

# Очистка файлов
rm webhook.key webhook.crt
```

### **3. Testing webhook functionality:**
```bash
# Test webhook endpoint
kubectl port-forward -n webhook-system svc/mock-webhook-service 8443:443 &

# Simulate webhook request
curl -k https://localhost:8443/health

# Check webhook logs
kubectl logs -n webhook-system -l app=mock-webhook

# Очистка
kubectl delete namespace webhook-system
```

## 🎯 **Архитектура Webhook Framework:**

```
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Webhook Framework               │
├─────────────────────────────────────────────────────────────┤
│  Client Request                                             │
│  ├── kubectl/API client                                    │
│  ├── Resource creation/update                              │
│  └── API request to kube-apiserver                         │
├─────────────────────────────────────────────────────────────┤
│  kube-apiserver                                             │
│  ├── Authentication & Authorization                        │
│  ├── Admission Controller Chain                            │
│  ├── Mutating Admission Webhooks                           │
│  └── Validating Admission Webhooks                         │
├─────────────────────────────────────────────────────────────┤
│  Webhook Server                                             │
│  ├── HTTPS endpoint                                        │
│  ├── AdmissionReview processing                            │
│  ├── Business logic execution                              │
│  └── AdmissionResponse generation                          │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                              │
│  ├── etcd persistence                                      │
│  ├── Object validation                                     │
│  └── Final resource state                                  │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Troubleshooting Webhooks:**

### **1. Webhook registration issues:**
```bash
# Webhook configuration validation
kubectl get mutatingadmissionwebhooks -o yaml | grep -A 10 "clientConfig"
kubectl get validatingadmissionwebhooks -o yaml | grep -A 10 "clientConfig"

# Service endpoint resolution
kubectl get endpoints -n webhook-system webhook-service
kubectl describe service -n webhook-system webhook-service

# Certificate validation
kubectl get secrets -n webhook-system webhook-certs -o yaml | grep -A 5 "tls.crt"
```

### **2. Webhook execution issues:**
```bash
# Webhook timeout errors
kubectl get events --field-selector reason=AdmissionWebhookTimeout
kubectl get events --field-selector type=Warning | grep -i timeout

# Webhook failure events
kubectl get events --field-selector reason=FailedAdmissionWebhook
kubectl describe events | grep -A 10 webhook

# Network connectivity
kubectl exec -n webhook-system deployment/webhook-server -- nslookup kubernetes.default.svc.cluster.local
```

### **3. Performance issues:**
```bash
# Webhook latency analysis
kubectl get --raw /metrics | grep "apiserver_admission_webhook_admission_duration_seconds_bucket"

# Request volume
kubectl get --raw /metrics | grep "apiserver_admission_webhook_request_total"

# Error rates
kubectl get events --all-namespaces --field-selector type=Warning | grep -i webhook | wc -l

# Resource usage
kubectl top pods -n webhook-system
```

## 🎯 **Best Practices для Webhooks:**

### **1. Безопасность:**
- Используйте proper TLS certificates
- Валидируйте webhook requests
- Реализуйте proper RBAC
- Мониторьте webhook access

### **2. Производительность:**
- Оптимизируйте webhook response time
- Используйте appropriate timeouts
- Кэшируйте validation results
- Минимизируйте external calls

### **3. Надежность:**
- Реализуйте health checks
- Используйте proper failure policies
- Обрабатывайте edge cases
- Планируйте disaster recovery

### **4. Операционные аспекты:**
- Документируйте webhook behavior
- Версионируйте webhook APIs
- Тестируйте webhook logic
- Мониторьте webhook metrics

**Webhooks — это мощный механизм для расширения функциональности Kubernetes API Server!**
