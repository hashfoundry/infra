# 197. How do you implement admission webhooks?

## 🎯 Вопрос
How do you implement admission webhooks?

## 💡 Ответ

Admission Webhooks - это механизм в Kubernetes, который позволяет перехватывать и модифицировать запросы к API серверу до их сохранения в etcd. Существует два типа: Mutating Admission Webhooks (изменяют объекты) и Validating Admission Webhooks (валидируют объекты).

### 🏗️ Архитектура Admission Webhooks

#### 1. **Схема Admission Control Flow**
```
┌─────────────────────────────────────────────────────────────┐
│                Admission Control Flow                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   Client Request                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   kubectl   │    │  Dashboard  │    │   Custom    │ │ │
│  │  │   create    │───▶│   create    │───▶│   Client    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 kube-apiserver                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Authentication │ │Authorization│    │ Admission   │ │ │
│  │  │     &        │─▶│             │───▶│  Control    │ │ │
│  │  │ Authorization│  │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Admission Controllers                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Built-in  │    │  Mutating   │    │ Validating  │ │ │
│  │  │ Controllers │───▶│  Webhooks   │───▶│  Webhooks   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Webhook Servers                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  Security   │    │  Resource   │    │   Policy    │ │ │
│  │  │  Webhook    │───▶│  Webhook    │───▶│  Webhook    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    etcd Storage                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  Validated  │    │  Modified   │    │   Final     │ │ │
│  │  │   Object    │───▶│   Object    │───▶│   Storage   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Типы Admission Webhooks**
```yaml
# Admission Webhooks Types
admission_webhooks:
  mutating_webhooks:
    purpose: "Modify objects before validation"
    execution_order: "Before validating webhooks"
    capabilities:
      - "Add default values"
      - "Inject sidecars"
      - "Add labels/annotations"
      - "Modify resource requests"
      - "Transform configurations"
    
    use_cases:
      - "Istio sidecar injection"
      - "Security policy enforcement"
      - "Resource quota management"
      - "Configuration standardization"
      - "Compliance automation"
    
    configuration:
      resource: "MutatingAdmissionWebhook"
      api_version: "admissionregistration.k8s.io/v1"
      webhook_endpoint: "HTTPS endpoint"
      ca_bundle: "Base64 encoded CA certificate"

  validating_webhooks:
    purpose: "Validate objects after mutation"
    execution_order: "After mutating webhooks"
    capabilities:
      - "Enforce policies"
      - "Validate configurations"
      - "Check compliance"
      - "Verify security rules"
      - "Validate business logic"
    
    use_cases:
      - "OPA Gatekeeper policies"
      - "Security scanning"
      - "Resource validation"
      - "Custom business rules"
      - "Compliance checking"
    
    configuration:
      resource: "ValidatingAdmissionWebhook"
      api_version: "admissionregistration.k8s.io/v1"
      webhook_endpoint: "HTTPS endpoint"
      ca_bundle: "Base64 encoded CA certificate"

  webhook_request_flow:
    admission_request:
      structure:
        - "apiVersion: admission.k8s.io/v1"
        - "kind: AdmissionRequest"
        - "object: The object being created/updated"
        - "oldObject: Previous version (for updates)"
        - "operation: CREATE/UPDATE/DELETE"
        - "userInfo: User making the request"
    
    admission_response:
      structure:
        - "apiVersion: admission.k8s.io/v1"
        - "kind: AdmissionResponse"
        - "allowed: true/false"
        - "result: Status message"
        - "patch: JSONPatch for mutations"
        - "patchType: JSONPatch/MergePatch"

  failure_policies:
    fail_policy:
      options:
        - "Fail: Reject request on webhook failure"
        - "Ignore: Allow request on webhook failure"
      considerations:
        - "Security vs availability trade-off"
        - "Webhook reliability requirements"
        - "Cluster operational impact"
    
    timeout_handling:
      default_timeout: "10 seconds"
      configurable: "1-30 seconds"
      behavior: "Fail or ignore based on failurePolicy"
```

### 📊 Примеры из нашего кластера

#### Проверка Admission Webhooks:
```bash
# Проверка mutating webhooks
kubectl get mutatingadmissionwebhooks

# Проверка validating webhooks
kubectl get validatingadmissionwebhooks

# Проверка webhook configurations
kubectl describe mutatingadmissionwebhook <webhook-name>
kubectl describe validatingadmissionwebhook <webhook-name>

# Проверка webhook endpoints
kubectl get endpoints -n <webhook-namespace>

# Проверка webhook pods
kubectl get pods -n <webhook-namespace> -l app=<webhook-app>
```

### 🛠️ Реализация Admission Webhook

#### 1. **Mutating Admission Webhook**
```go
// mutating-webhook.go
package main

import (
    "context"
    "crypto/tls"
    "encoding/json"
    "fmt"
    "io/ioutil"
    "net/http"
    "strings"

    admissionv1 "k8s.io/api/admission/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/runtime/serializer"
    "k8s.io/klog/v2"
)

var (
    scheme = runtime.NewScheme()
    codecs = serializer.NewCodecFactory(scheme)
)

type WebhookServer struct {
    server *http.Server
}

// Webhook configuration
type WebhookConfig struct {
    CertPath string
    KeyPath  string
    Port     int
}

func main() {
    config := &WebhookConfig{
        CertPath: "/etc/certs/tls.crt",
        KeyPath:  "/etc/certs/tls.key",
        Port:     8443,
    }

    webhookServer := &WebhookServer{
        server: &http.Server{
            Addr:      fmt.Sprintf(":%d", config.Port),
            TLSConfig: &tls.Config{},
        },
    }

    // Define webhook endpoints
    mux := http.NewServeMux()
    mux.HandleFunc("/mutate", webhookServer.mutate)
    mux.HandleFunc("/validate", webhookServer.validate)
    mux.HandleFunc("/health", webhookServer.health)
    webhookServer.server.Handler = mux

    // Start server
    klog.Infof("Starting webhook server on port %d", config.Port)
    if err := webhookServer.server.ListenAndServeTLS(config.CertPath, config.KeyPath); err != nil {
        klog.Fatalf("Failed to start webhook server: %v", err)
    }
}

// Mutating webhook handler
func (ws *WebhookServer) mutate(w http.ResponseWriter, r *http.Request) {
    klog.Info("Handling mutate request")

    body, err := ioutil.ReadAll(r.Body)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    // Parse admission request
    var admissionReview admissionv1.AdmissionReview
    if err := json.Unmarshal(body, &admissionReview); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    req := admissionReview.Request
    var pod corev1.Pod
    if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    // Apply mutations
    patches := []JSONPatch{}
    
    // Add security context if missing
    if pod.Spec.SecurityContext == nil {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/spec/securityContext",
            Value: map[string]interface{}{
                "runAsNonRoot": true,
                "runAsUser":    1000,
            },
        })
    }

    // Add resource limits if missing
    for i, container := range pod.Spec.Containers {
        if container.Resources.Limits == nil {
            patches = append(patches, JSONPatch{
                Op:   "add",
                Path: fmt.Sprintf("/spec/containers/%d/resources/limits", i),
                Value: map[string]interface{}{
                    "cpu":    "500m",
                    "memory": "512Mi",
                },
            })
        }
    }

    // Add monitoring labels
    if pod.Labels == nil {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/metadata/labels",
            Value: map[string]string{},
        })
    }
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/labels/monitoring.example.com~1enabled",
        Value: "true",
    })

    // Add sidecar container for specific namespaces
    if strings.HasPrefix(pod.Namespace, "prod-") {
        sidecar := corev1.Container{
            Name:  "monitoring-sidecar",
            Image: "monitoring/agent:v1.0.0",
            Ports: []corev1.ContainerPort{
                {ContainerPort: 9090, Name: "metrics"},
            },
            Resources: corev1.ResourceRequirements{
                Limits: corev1.ResourceList{
                    "cpu":    "100m",
                    "memory": "128Mi",
                },
            },
        }
        
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/spec/containers/-",
            Value: sidecar,
        })
    }

    // Create admission response
    patchBytes, _ := json.Marshal(patches)
    admissionResponse := &admissionv1.AdmissionResponse{
        UID:     req.UID,
        Allowed: true,
        Patch:   patchBytes,
        PatchType: func() *admissionv1.PatchType {
            pt := admissionv1.PatchTypeJSONPatch
            return &pt
        }(),
    }

    admissionReview.Response = admissionResponse
    respBytes, _ := json.Marshal(admissionReview)
    w.Header().Set("Content-Type", "application/json")
    w.Write(respBytes)
}

// Validating webhook handler
func (ws *WebhookServer) validate(w http.ResponseWriter, r *http.Request) {
    klog.Info("Handling validate request")

    body, err := ioutil.ReadAll(r.Body)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    var admissionReview admissionv1.AdmissionReview
    if err := json.Unmarshal(body, &admissionReview); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    req := admissionReview.Request
    allowed := true
    message := ""

    // Validate based on resource type
    switch req.Kind.Kind {
    case "Pod":
        allowed, message = ws.validatePod(req)
    case "Service":
        allowed, message = ws.validateService(req)
    case "Deployment":
        allowed, message = ws.validateDeployment(req)
    default:
        allowed = true
    }

    admissionResponse := &admissionv1.AdmissionResponse{
        UID:     req.UID,
        Allowed: allowed,
        Result: &metav1.Status{
            Message: message,
        },
    }

    admissionReview.Response = admissionResponse
    respBytes, _ := json.Marshal(admissionReview)
    w.Header().Set("Content-Type", "application/json")
    w.Write(respBytes)
}

// Pod validation logic
func (ws *WebhookServer) validatePod(req *admissionv1.AdmissionRequest) (bool, string) {
    var pod corev1.Pod
    if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
        return false, fmt.Sprintf("Failed to parse pod: %v", err)
    }

    // Validate security context
    if pod.Spec.SecurityContext == nil || pod.Spec.SecurityContext.RunAsNonRoot == nil || !*pod.Spec.SecurityContext.RunAsNonRoot {
        return false, "Pod must run as non-root user"
    }

    // Validate resource limits
    for _, container := range pod.Spec.Containers {
        if container.Resources.Limits == nil {
            return false, fmt.Sprintf("Container %s must have resource limits", container.Name)
        }
        
        if container.Resources.Limits.Cpu().IsZero() {
            return false, fmt.Sprintf("Container %s must have CPU limit", container.Name)
        }
        
        if container.Resources.Limits.Memory().IsZero() {
            return false, fmt.Sprintf("Container %s must have memory limit", container.Name)
        }
    }

    // Validate image registry
    for _, container := range pod.Spec.Containers {
        if !strings.HasPrefix(container.Image, "registry.company.com/") {
            return false, fmt.Sprintf("Container %s uses unauthorized image registry", container.Name)
        }
    }

    // Validate privileged containers
    for _, container := range pod.Spec.Containers {
        if container.SecurityContext != nil && container.SecurityContext.Privileged != nil && *container.SecurityContext.Privileged {
            return false, fmt.Sprintf("Container %s cannot run in privileged mode", container.Name)
        }
    }

    return true, "Pod validation passed"
}

// Service validation logic
func (ws *WebhookServer) validateService(req *admissionv1.AdmissionRequest) (bool, string) {
    var service corev1.Service
    if err := json.Unmarshal(req.Object.Raw, &service); err != nil {
        return false, fmt.Sprintf("Failed to parse service: %v", err)
    }

    // Validate LoadBalancer services
    if service.Spec.Type == corev1.ServiceTypeLoadBalancer {
        if service.Namespace != "production" {
            return false, "LoadBalancer services are only allowed in production namespace"
        }
    }

    // Validate NodePort range
    for _, port := range service.Spec.Ports {
        if port.NodePort != 0 && (port.NodePort < 30000 || port.NodePort > 32767) {
            return false, fmt.Sprintf("NodePort %d is outside allowed range (30000-32767)", port.NodePort)
        }
    }

    return true, "Service validation passed"
}

// Deployment validation logic
func (ws *WebhookServer) validateDeployment(req *admissionv1.AdmissionRequest) (bool, string) {
    // Implementation for deployment validation
    return true, "Deployment validation passed"
}

// Health check handler
func (ws *WebhookServer) health(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("OK"))
}

// JSONPatch represents a JSON patch operation
type JSONPatch struct {
    Op    string      `json:"op"`
    Path  string      `json:"path"`
    Value interface{} `json:"value,omitempty"`
}
```

#### 2. **Webhook Configuration**
```yaml
# mutating-webhook-config.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: example-mutating-webhook
webhooks:
- name: pod-mutator.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/mutate"
    caBundle: LS0tLS1CRUdJTi... # Base64 encoded CA certificate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10

---
# validating-webhook-config.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: example-validating-webhook
webhooks:
- name: pod-validator.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/validate"
    caBundle: LS0tLS1CRUdJTi... # Base64 encoded CA certificate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods", "services"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources: ["deployments"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
  namespaceSelector:
    matchLabels:
      webhook-enabled: "true"

---
# webhook-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook-server
  namespace: webhook-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webhook-server
  template:
    metadata:
      labels:
        app: webhook-server
    spec:
      serviceAccountName: webhook-server
      containers:
      - name: webhook
        image: example/webhook-server:v1.0.0
        ports:
        - containerPort: 8443
        env:
        - name: TLS_CERT_FILE
          value: /etc/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/certs/tls.key
        volumeMounts:
        - name: certs
          mountPath: /etc/certs
          readOnly: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: certs
        secret:
          secretName: webhook-certs

---
# webhook-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webhook-service
  namespace: webhook-system
spec:
  selector:
    app: webhook-server
  ports:
  - port: 443
    targetPort: 8443
    protocol: TCP

---
# webhook-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webhook-server
  namespace: webhook-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: webhook-server
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: webhook-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: webhook-server
subjects:
- kind: ServiceAccount
  name: webhook-server
  namespace: webhook-system
```

#### 3. **Certificate Management**
```bash
#!/bin/bash
# generate-certs.sh

NAMESPACE="webhook-system"
SERVICE="webhook-service"
SECRET="webhook-certs"

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Generate CA private key
openssl genrsa -out ca.key 2048

# Generate CA certificate
openssl req -new -x509 -days 365 -key ca.key -subj "/C=US/ST=CA/L=San Francisco/O=Example/CN=Webhook CA" -out ca.crt

# Generate server private key
openssl genrsa -out server.key 2048

# Create certificate signing request
cat > server.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $SERVICE
DNS.2 = $SERVICE.$NAMESPACE
DNS.3 = $SERVICE.$NAMESPACE.svc
DNS.4 = $SERVICE.$NAMESPACE.svc.cluster.local
EOF

# Generate certificate signing request
openssl req -new -key server.key -subj "/C=US/ST=CA/L=San Francisco/O=Example/CN=$SERVICE.$NAMESPACE.svc" -out server.csr -config server.conf

# Generate server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile server.conf

# Create secret
kubectl create secret tls $SECRET \
    --cert=server.crt \
    --key=server.key \
    --namespace=$NAMESPACE

# Get CA bundle for webhook configuration
CA_BUNDLE=$(cat ca.crt | base64 | tr -d '\n')
echo "CA Bundle for webhook configuration:"
echo $CA_BUNDLE

# Cleanup
rm ca.key ca.crt ca.srl server.key server.crt server.csr server.conf
```

### 🔧 Утилиты для тестирования Admission Webhooks

#### Скрипт для тестирования webhooks:
```bash
#!/bin/bash
# test-admission-webhooks.sh

echo "🧪 Testing Admission Webhooks"

# Test webhook registration
test_webhook_registration() {
    echo "=== Testing Webhook Registration ==="
    
    # Check mutating webhooks
    echo "--- Mutating Webhooks ---"
    kubectl get mutatingadmissionwebhooks
    
    # Check validating webhooks
    echo "--- Validating Webhooks ---"
    kubectl get validatingadmissionwebhooks
    
    # Check webhook endpoints
    echo "--- Webhook Endpoints ---"
    kubectl get endpoints -n webhook-system
}

# Test webhook functionality
test_webhook_functionality() {
    echo "=== Testing Webhook Functionality ==="
    
    # Create test namespace
    kubectl create namespace webhook-test --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace webhook-test webhook-enabled=true
    
    # Test mutating webhook
    echo "--- Testing Mutating Webhook ---"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-mutation
  namespace: webhook-test
spec:
  containers:
  - name: test
    image: nginx:alpine
EOF

    # Check if mutations were applied
    echo "Checking applied mutations..."
    kubectl get pod test-mutation -n webhook-test -o yaml | grep -A 10 "securityContext\|resources\|labels"
    
    # Test validating webhook with invalid pod
    echo "--- Testing Validating Webhook (should fail) ---"
    cat <<EOF | kubectl apply -f - || echo "✅ Validation correctly rejected invalid pod"
apiVersion: v1
kind: Pod
metadata:
  name: test-validation-fail
  namespace: webhook-test
spec:
  containers:
  - name: test
    image: unauthorized-registry.com/nginx:latest
    securityContext:
      privileged: true
EOF

    # Test validating webhook with valid pod
    echo "--- Testing Validating Webhook (should succeed) ---"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-validation-pass
  namespace: webhook-test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: test
    image: registry.company.com/nginx:alpine
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
EOF

    if [ $? -eq 0 ]; then
        echo "✅ Validation correctly accepted valid pod"
    else
        echo "❌ Validation incorrectly rejected valid pod"
    fi
}

# Test webhook performance
test_webhook_performance() {
    echo "=== Testing Webhook Performance ==="
    
    local count=${1:-10}
    echo "Creating $count pods to test webhook performance..."
    
    start_time=$(date +%s)
    
    for i in $(seq 1 $count); do
        cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: perf-test-$i
  namespace: webhook-test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: test
    image: registry.company.com/nginx:alpine
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
EOF
    done
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "✅ Created $count pods in ${duration}s"
    echo "Average: $((duration * 1000 / count))ms per pod"
    
    # Cleanup
    for i in $(seq 1 $count); do
        kubectl delete pod perf-test-$i -n webhook-test >/dev/null 2>&1
    done
}

# Test webhook failure scenarios
test_webhook_failures() {
    echo "=== Testing Webhook Failure Scenarios ==="
    
    # Scale down webhook deployment
    echo "--- Testing webhook unavailability ---"
    kubectl scale deployment webhook-server -n webhook-system --replicas=0
    
    # Wait for pods to terminate
    sleep 10
    
    # Try to create pod (should fail with failurePolicy: Fail)
    echo "Attempting to create pod with webhook unavailable..."
    cat <<EOF | kubectl apply -f - || echo "✅ Request correctly failed when webhook unavailable"
apiVersion: v1
kind: Pod
metadata:
  name: test-failure
  namespace: webhook-test
spec:
  containers:
  - name: test
    image: nginx:alpine
EOF

    # Scale webhook back up
    kubectl scale deployment webhook-server -n webhook-system --replicas=2
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=webhook-server -n webhook-system --timeout=60s
}

# Test webhook logs
test_webhook_logs() {
    echo "=== Checking Webhook Logs ==="
    
    # Get webhook pod logs
    webhook_pods=$(kubectl get pods -n webhook-system -l app=webhook-server -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $webhook_pods; do
        echo "--- Logs from $pod ---"
        kubectl logs -n webhook-system $pod --tail=20
    done
}

# Cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up Test Resources ==="
    
    kubectl delete namespace webhook-test --ignore-not-found=true
    echo "✅ Cleanup completed"
}

# Main execution
main() {
    echo "Testing Admission Webhooks"
    echo ""
    
    # Run tests
    test_webhook_registration
    echo ""
    
    test_webhook_functionality
    echo ""
    
    test_webhook_performance 5
    echo ""
    
    test_webhook_failures
    echo ""
    
    test_webhook_logs
    echo ""
    
    read -p "Cleanup test resources? (y/n): " cleanup
    if [ "$cleanup" = "y" ]; then
        cleanup_test_resources
    fi
}

# Check if arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0"
    echo ""
    echo "Running admission webhook tests..."
    main
else
    main "$@"
fi
```

### 🎯 Заключение

Admission Webhooks предоставляют мощный механизм для контроля и модификации ресурсов в Kubernetes:

**Ключевые возможности:**
1. **Mutating Webhooks** - изменение объектов перед сохранением
2. **Validating Webhooks** - валидация объектов после мутации
3. **Гибкая конфигурация** - точный контроль над тем, какие ресурсы обрабатывать
4. **Интеграция с RBAC** - использование стандартных механизмов авторизации

**Архитектурные принципы:**
1. **HTTPS обязателен** - все webhook endpoints должны использовать TLS
2. **Отказоустойчивость** - настройка failurePolicy для обработки сбоев
3. **Производительность** - минимизация времени обработки запросов
4. **Безопасность** - валидация сертификатов и аутентификация

**Практические применения:**
- **Istio** - автоматическая инъекция sidecar контейнеров
- **OPA Gatekeeper** - применение политик безопасности
- **Falco** - мониторинг безопасности в реальном времени
- **Kustomize** - стандартизация конфигураций

Admission Webhooks являются фундаментальным инструментом для создания безопасных и соответствующих политикам Kubernetes кластеров.
