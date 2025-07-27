# 137. Что такое admission controllers и webhooks

## 🎯 **Что такое admission controllers и webhooks?**

**Admission Controllers и Webhooks** - это механизмы расширения Kubernetes API, которые позволяют перехватывать, валидировать и модифицировать запросы к API серверу до их сохранения в etcd. Они обеспечивают дополнительную безопасность, политики и автоматизацию в кластере.

## 🌐 **Типы Admission Controllers:**

### **1. Built-in Admission Controllers:**
- **NamespaceLifecycle** - управление жизненным циклом namespace
- **ResourceQuota** - контроль квот ресурсов
- **PodSecurityPolicy** - политики безопасности подов
- **NetworkPolicy** - сетевые политики

### **2. Dynamic Admission Controllers:**
- **ValidatingAdmissionWebhooks** - валидация запросов
- **MutatingAdmissionWebhooks** - модификация запросов
- **Custom Admission Controllers** - пользовательские контроллеры

### **3. Webhook Types:**
- **Mutating Webhooks** - изменяют объекты
- **Validating Webhooks** - проверяют объекты
- **Conversion Webhooks** - конвертируют версии API

## 📊 **Практические примеры из вашего HA кластера:**

### **Анализ текущих admission controllers:**

```bash
# Проверить включенные admission controllers
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Проверить admission controller events
kubectl get events --all-namespaces --field-selector reason=AdmissionWebhook

# Проверить конфигурацию API сервера
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | \
grep -A 10 -B 10 "enable-admission-plugins"
```

### **Создание Mutating Webhook:**

```yaml
# mutating-webhook-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webhook-system
  labels:
    name: webhook-system

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webhook-service-account
  namespace: webhook-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: webhook-cluster-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: webhook-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: webhook-cluster-role
subjects:
- kind: ServiceAccount
  name: webhook-service-account
  namespace: webhook-system

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mutating-webhook
  namespace: webhook-system
  labels:
    app: mutating-webhook
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mutating-webhook
  template:
    metadata:
      labels:
        app: mutating-webhook
    spec:
      serviceAccountName: webhook-service-account
      containers:
      - name: webhook
        image: hashfoundry/mutating-webhook:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8443
          name: webhook-api
        volumeMounts:
        - name: webhook-tls-certs
          mountPath: /etc/webhook/certs
          readOnly: true
        env:
        - name: TLS_CERT_FILE
          value: /etc/webhook/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/webhook/certs/tls.key
        livenessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
      volumes:
      - name: webhook-tls-certs
        secret:
          secretName: webhook-tls-secret

---
apiVersion: v1
kind: Service
metadata:
  name: mutating-webhook-service
  namespace: webhook-system
  labels:
    app: mutating-webhook
spec:
  selector:
    app: mutating-webhook
  ports:
  - name: webhook-api
    port: 443
    targetPort: 8443
    protocol: TCP
```

### **Mutating Webhook Configuration:**

```yaml
# mutating-webhook-configuration.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: hashfoundry-mutating-webhook
spec:
  clientConfig:
    service:
      name: mutating-webhook-service
      namespace: webhook-system
      path: "/mutate"
    caBundle: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t... # Base64 encoded CA certificate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources: ["deployments", "replicasets"]
  namespaceSelector:
    matchLabels:
      webhook: "enabled"
  objectSelector:
    matchExpressions:
    - key: "webhook.hashfoundry.io/skip"
      operator: NotIn
      values: ["true"]
  failurePolicy: Fail
  sideEffects: None
  admissionReviewVersions: ["v1", "v1beta1"]
  timeoutSeconds: 10
```

### **Validating Webhook:**

```yaml
# validating-webhook-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: validating-webhook
  namespace: webhook-system
  labels:
    app: validating-webhook
spec:
  replicas: 2
  selector:
    matchLabels:
      app: validating-webhook
  template:
    metadata:
      labels:
        app: validating-webhook
    spec:
      serviceAccountName: webhook-service-account
      containers:
      - name: webhook
        image: hashfoundry/validating-webhook:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8443
          name: webhook-api
        volumeMounts:
        - name: webhook-tls-certs
          mountPath: /etc/webhook/certs
          readOnly: true
        env:
        - name: TLS_CERT_FILE
          value: /etc/webhook/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/webhook/certs/tls.key
        livenessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
      volumes:
      - name: webhook-tls-certs
        secret:
          secretName: webhook-tls-secret

---
apiVersion: v1
kind: Service
metadata:
  name: validating-webhook-service
  namespace: webhook-system
  labels:
    app: validating-webhook
spec:
  selector:
    app: validating-webhook
  ports:
  - name: webhook-api
    port: 443
    targetPort: 8443
    protocol: TCP
```

### **Validating Webhook Configuration:**

```yaml
# validating-webhook-configuration.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: hashfoundry-validating-webhook
spec:
  clientConfig:
    service:
      name: validating-webhook-service
      namespace: webhook-system
      path: "/validate"
    caBundle: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t... # Base64 encoded CA certificate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources: ["deployments", "replicasets"]
  namespaceSelector:
    matchLabels:
      validation: "enabled"
  objectSelector:
    matchExpressions:
    - key: "webhook.hashfoundry.io/skip"
      operator: NotIn
      values: ["true"]
  failurePolicy: Fail
  sideEffects: None
  admissionReviewVersions: ["v1", "v1beta1"]
  timeoutSeconds: 10
```

### **Создание TLS сертификатов для webhooks:**

```bash
# Создать скрипт для генерации сертификатов
cat << 'EOF' > create-webhook-certs.sh
#!/bin/bash

set -e

# Configuration
NAMESPACE="webhook-system"
SERVICE_NAME="webhook-service"
SECRET_NAME="webhook-tls-secret"

# Create temporary directory
TMPDIR=$(mktemp -d)
echo "Creating certificates in $TMPDIR"

# Create CA private key
openssl genrsa -out $TMPDIR/ca.key 2048

# Create CA certificate
openssl req -new -x509 -key $TMPDIR/ca.key -out $TMPDIR/ca.crt -days 365 -subj "/CN=webhook-ca"

# Create server private key
openssl genrsa -out $TMPDIR/server.key 2048

# Create certificate signing request
cat << CSR_EOF > $TMPDIR/server.conf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $SERVICE_NAME.$NAMESPACE.svc

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SERVICE_NAME
DNS.2 = $SERVICE_NAME.$NAMESPACE
DNS.3 = $SERVICE_NAME.$NAMESPACE.svc
DNS.4 = $SERVICE_NAME.$NAMESPACE.svc.cluster.local
CSR_EOF

# Create certificate signing request
openssl req -new -key $TMPDIR/server.key -out $TMPDIR/server.csr -config $TMPDIR/server.conf

# Create server certificate
openssl x509 -req -in $TMPDIR/server.csr -CA $TMPDIR/ca.crt -CAkey $TMPDIR/ca.key -CAcreateserial -out $TMPDIR/server.crt -days 365 -extensions v3_req -extfile $TMPDIR/server.conf

# Create Kubernetes secret
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls $SECRET_NAME \
    --cert=$TMPDIR/server.crt \
    --key=$TMPDIR/server.key \
    --namespace=$NAMESPACE

# Get CA bundle for webhook configuration
CA_BUNDLE=$(cat $TMPDIR/ca.crt | base64 | tr -d '\n')

echo "CA Bundle for webhook configuration:"
echo "$CA_BUNDLE"

# Save CA bundle to file
echo "$CA_BUNDLE" > ca-bundle.txt

echo "✅ Certificates created successfully"
echo "   Secret: $SECRET_NAME in namespace $NAMESPACE"
echo "   CA Bundle saved to: ca-bundle.txt"

# Cleanup
rm -rf $TMPDIR

EOF

chmod +x create-webhook-certs.sh
```

### **Тестирование webhooks:**

```bash
# Создать скрипт для тестирования webhooks
cat << 'EOF' > test-webhooks.sh
#!/bin/bash

echo "=== Testing Admission Webhooks ==="

# Function to test mutating webhook
test_mutating_webhook() {
    echo "1. Testing Mutating Webhook:"
    
    # Create test pod without labels
    cat << TEST_POD_EOF > test-pod-mutating.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-mutating-pod
  namespace: default
spec:
  containers:
  - name: test-container
    image: nginx:1.21
TEST_POD_EOF
    
    echo "   Creating test pod (should be mutated)..."
    kubectl apply -f test-pod-mutating.yaml --dry-run=server -o yaml > mutated-pod.yaml
    
    echo "   Checking if pod was mutated:"
    if grep -q "environment: hashfoundry-ha" mutated-pod.yaml; then
        echo "   ✅ Mutating webhook working - labels added"
    else
        echo "   ❌ Mutating webhook not working"
    fi
    
    if grep -q "runAsNonRoot: true" mutated-pod.yaml; then
        echo "   ✅ Mutating webhook working - security context added"
    else
        echo "   ❌ Mutating webhook not working"
    fi
    
    rm -f test-pod-mutating.yaml mutated-pod.yaml
}

# Function to test validating webhook
test_validating_webhook() {
    echo "2. Testing Validating Webhook:"
    
    # Test 1: Pod without required labels (should fail)
    cat << TEST_POD_INVALID_EOF > test-pod-invalid.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-invalid-pod
  namespace: default
spec:
  containers:
  - name: test-container
    image: nginx:latest
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
TEST_POD_INVALID_EOF
    
    echo "   Testing pod without required labels (should fail)..."
    if kubectl apply -f test-pod-invalid.yaml --dry-run=server 2>&1 | grep -q "must have label"; then
        echo "   ✅ Validating webhook working - rejected pod without labels"
    else
        echo "   ❌ Validating webhook not working"
    fi
    
    # Test 2: Valid pod (should succeed)
    cat << TEST_POD_VALID_EOF > test-pod-valid.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-valid-pod
  namespace: default
  labels:
    app: test-app
    version: v1.0.0
    environment: test
spec:
  containers:
  - name: test-container
    image: nginx:1.21
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
TEST_POD_VALID_EOF
    
    echo "   Testing valid pod (should succeed)..."
    if kubectl apply -f test-pod-valid.yaml --dry-run=server > /dev/null 2>&1; then
        echo "   ✅ Validating webhook working - accepted valid pod"
    else
        echo "   ❌ Validating webhook not working"
    fi
    
    rm -f test-pod-invalid.yaml test-pod-valid.yaml
}

# Function to check webhook status
check_webhook_status() {
    echo "3. Checking Webhook Status:"
    
    echo "   Mutating webhooks:"
    kubectl get mutatingwebhookconfigurations
    
    echo "   Validating webhooks:"
    kubectl get validatingwebhookconfigurations
    
    echo "   Webhook pods:"
    kubectl get pods -n webhook-system
    
    echo "   Webhook services:"
    kubectl get services -n webhook-system
}

# Main execution
test_mutating_webhook
echo
test_validating_webhook
echo
check_webhook_status

echo
echo "✅ Webhook testing completed"

EOF

chmod +x test-webhooks.sh
```

### **Команды kubectl для работы с admission controllers:**

```bash
# Проверить текущие admission controllers
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Проверить admission controller events
kubectl get events --all-namespaces --field-selector reason=AdmissionWebhook

# Проверить webhook endpoints
kubectl get endpoints -n webhook-system

# Проверить webhook logs
kubectl logs -n webhook-system -l app=mutating-webhook
kubectl logs -n webhook-system -l app=validating-webhook

# Тестирование webhook с dry-run
kubectl apply -f pod.yaml --dry-run=server -o yaml

# Проверить webhook certificates
kubectl get secret webhook-tls-secret -n webhook-system -o yaml

# Проверить webhook configuration
kubectl describe mutatingwebhookconfigurations hashfoundry-mutating-webhook
kubectl describe validatingwebhookconfigurations hashfoundry-validating-webhook

# Проверить webhook health
kubectl get pods -n webhook-system -l app=mutating-webhook
kubectl get pods -n webhook-system -l app=validating-webhook

# Мониторинг webhook метрик
kubectl get --raw /metrics | grep admission_controller

# Проверить certificate expiration
kubectl get secret webhook-tls-secret -n webhook-system -o jsonpath='{.data.tls\.crt}' | \
base64 -d | openssl x509 -noout -dates
```

### **Мониторинг и отладка webhooks:**

```bash
# Создать скрипт для мониторинга webhooks
cat << 'EOF' > monitor-webhooks.sh
#!/bin/bash

echo "=== Webhook Monitoring and Debugging ==="

# Function to check webhook health
check_webhook_health() {
    echo "1. Webhook Health Check:"
    
    # Check mutating webhook pods
    echo "   Mutating webhook pods:"
    kubectl get pods -n webhook-system -l app=mutating-webhook -o wide
    
    # Check validating webhook pods
    echo "   Validating webhook pods:"
    kubectl get pods -n webhook-system -l app=validating-webhook -o wide
    
    # Check webhook endpoints
    echo "   Webhook endpoints:"
    kubectl get endpoints -n webhook-system
    
    echo
}

# Function to check webhook logs
check_webhook_logs() {
    echo "2. Webhook Logs:"
    
    echo "   Mutating webhook logs:"
    kubectl logs -n webhook-system -l app=mutating-webhook --tail=20
    
    echo "   Validating webhook logs:"
    kubectl logs -n webhook-system -l app=validating-webhook --tail=20
    
    echo
}

# Function to check webhook configurations
check_webhook_configurations() {
    echo "3. Webhook Configurations:"
    
    echo "   Mutating webhook configuration:"
    kubectl get mutatingwebhookconfigurations -o yaml
    
    echo "   Validating webhook configuration:"
    kubectl get validatingwebhookconfigurations -o yaml
    
    echo
}

# Function to check webhook certificates
check_webhook_certificates() {
    echo "4. Webhook Certificates:"
    
    echo "   TLS secret:"
    kubectl get secret webhook-tls-secret -n webhook-system -o yaml
    
    echo "   Certificate expiration:"
    kubectl get secret webhook-tls-secret -n webhook-system -o jsonpath='{.data.tls\.crt}' | \
    base64 -d | openssl x509 -noout -dates
    
    echo
}

# Main execution
check_webhook_health
check_webhook_logs
check_webhook_configurations
check_webhook_certificates

echo "✅ Webhook monitoring completed"

EOF

chmod +x monitor-webhooks.sh
```

## 🎯 **Ключевые принципы работы с Admission Controllers:**

1. **Безопасность** - всегда используйте TLS для webhook endpoints
2. **Отказоустойчивость** - настройте failurePolicy правильно
3. **Производительность** - минимизируйте latency webhook calls
4. **Мониторинг** - отслеживайте webhook health и metrics
5. **Тестирование** - используйте dry-run для тестирования
6. **Версионирование** - поддерживайте совместимость API versions

Admission Controllers и Webhooks обеспечивают мощные возможности для автоматизации политик и безопасности в HashFoundry HA кластере.
