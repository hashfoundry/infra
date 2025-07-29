# 190. Что такое Kubernetes Webhooks и как их использовать?

## 🎯 Вопрос
Что такое Kubernetes Webhooks и как их использовать?

## 💡 Ответ

Kubernetes Webhooks - это HTTP callbacks, которые позволяют внешним системам получать уведомления о событиях в кластере или влиять на поведение Kubernetes API Server. Существует два основных типа webhooks: Admission Webhooks (для валидации и мутации ресурсов) и Conversion Webhooks (для конвертации между версиями API).

### 🏗️ Архитектура Webhooks

#### 1. **Схема Webhook Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Webhook Architecture            │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Client Request                      │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   kubectl   │    │    HTTP     │    │   API       │ │ │
│  │  │   create    │───▶│   Request   │───▶│  Request    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 kube-apiserver                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Authentication│   │Authorization│    │  Admission  │ │ │
│  │  │              │──▶│             │───▶│ Controllers │ │ │
│  │  │              │   │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Admission Webhooks                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  Mutating   │    │ Validating  │    │ Conversion  │ │ │
│  │  │  Admission  │───▶│ Admission   │───▶│  Webhooks   │ │ │
│  │  │  Webhooks   │    │  Webhooks   │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                External Webhook Server                 │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   HTTPS     │    │  Business   │    │   Response  │ │ │
│  │  │  Endpoint   │───▶│    Logic    │───▶│ Generation  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    etcd Storage                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Object    │    │   Persist   │    │   Final     │ │ │
│  │  │ Validation  │───▶│   Object    │───▶│   State     │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Типы Webhooks**
```yaml
# Webhook Types
webhook_types:
  admission_webhooks:
    mutating_admission_webhooks:
      description: "Изменяют объекты перед их сохранением"
      use_cases:
        - "Добавление sidecar контейнеров"
        - "Установка default значений"
        - "Инъекция environment variables"
        - "Добавление labels и annotations"
        - "Модификация security contexts"
      
      execution_order: "Выполняются перед validating webhooks"
      
    validating_admission_webhooks:
      description: "Валидируют объекты без их изменения"
      use_cases:
        - "Проверка compliance policies"
        - "Валидация конфигурации"
        - "Проверка security requirements"
        - "Enforcement naming conventions"
        - "Resource quota validation"
      
      execution_order: "Выполняются после mutating webhooks"
  
  conversion_webhooks:
    description: "Конвертируют между версиями API"
    use_cases:
      - "Миграция между API versions"
      - "Backward compatibility"
      - "Custom Resource versioning"
    
    scenarios:
      - "Storage version conversion"
      - "Client version conversion"

# Webhook Configuration
webhook_configuration:
  mutating_admission_webhook:
    apiVersion: "admissionregistration.k8s.io/v1"
    kind: "MutatingAdmissionWebhook"
    fields:
      - "name: unique webhook name"
      - "clientConfig: webhook endpoint configuration"
      - "rules: resources and operations to intercept"
      - "admissionReviewVersions: supported review versions"
      - "sideEffects: webhook side effects declaration"
      - "failurePolicy: behavior on webhook failure"
      - "timeoutSeconds: webhook timeout"
  
  validating_admission_webhook:
    apiVersion: "admissionregistration.k8s.io/v1"
    kind: "ValidatingAdmissionWebhook"
    fields:
      - "name: unique webhook name"
      - "clientConfig: webhook endpoint configuration"
      - "rules: resources and operations to intercept"
      - "admissionReviewVersions: supported review versions"
      - "sideEffects: webhook side effects declaration"
      - "failurePolicy: behavior on webhook failure"
      - "timeoutSeconds: webhook timeout"

# Webhook Request/Response Flow
request_response_flow:
  admission_review_request:
    structure:
      - "apiVersion: admission.k8s.io/v1"
      - "kind: AdmissionReview"
      - "request: AdmissionRequest object"
    
    admission_request_fields:
      - "uid: unique request identifier"
      - "kind: resource kind being processed"
      - "resource: resource type and version"
      - "name: resource name"
      - "namespace: resource namespace"
      - "operation: CREATE, UPDATE, DELETE"
      - "object: current object state"
      - "oldObject: previous object state (for updates)"
      - "userInfo: user making the request"
  
  admission_review_response:
    structure:
      - "apiVersion: admission.k8s.io/v1"
      - "kind: AdmissionReview"
      - "response: AdmissionResponse object"
    
    admission_response_fields:
      - "uid: matching request uid"
      - "allowed: boolean admission decision"
      - "status: error details if not allowed"
      - "patch: JSON patch for mutations"
      - "patchType: type of patch (JSONPatch)"
      - "warnings: optional warning messages"
```

### 📊 Примеры из нашего кластера

#### Проверка webhooks:
```bash
# Проверка mutating admission webhooks
kubectl get mutatingadmissionwebhooks

# Проверка validating admission webhooks
kubectl get validatingadmissionwebhooks

# Проверка webhook configurations
kubectl describe mutatingadmissionwebhook webhook-name

# Проверка webhook endpoints
kubectl get endpoints -n webhook-namespace

# Проверка webhook logs
kubectl logs -n webhook-namespace -l app=webhook-server
```

### 🔧 Создание Admission Webhook

#### 1. **Mutating Admission Webhook Server**
```go
// mutating-webhook-server.go
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
)

var (
    scheme = runtime.NewScheme()
    codecs = serializer.NewCodecFactory(scheme)
)

// WebhookServer представляет наш webhook server
type WebhookServer struct {
    server *http.Server
}

// PodMutator содержит логику мутации pod'ов
type PodMutator struct{}

// NewWebhookServer создает новый webhook server
func NewWebhookServer(certPath, keyPath string, port int) (*WebhookServer, error) {
    cert, err := tls.LoadX509KeyPair(certPath, keyPath)
    if err != nil {
        return nil, fmt.Errorf("failed to load key pair: %v", err)
    }
    
    server := &http.Server{
        Addr:      fmt.Sprintf(":%d", port),
        TLSConfig: &tls.Config{Certificates: []tls.Certificate{cert}},
    }
    
    return &WebhookServer{server: server}, nil
}

// Start запускает webhook server
func (ws *WebhookServer) Start() error {
    mux := http.NewServeMux()
    mux.HandleFunc("/mutate", ws.handleMutate)
    mux.HandleFunc("/validate", ws.handleValidate)
    mux.HandleFunc("/health", ws.handleHealth)
    
    ws.server.Handler = mux
    
    fmt.Println("Starting webhook server on port", ws.server.Addr)
    return ws.server.ListenAndServeTLS("", "")
}

// Stop останавливает webhook server
func (ws *WebhookServer) Stop() error {
    return ws.server.Shutdown(context.Background())
}

// handleMutate обрабатывает mutating admission requests
func (ws *WebhookServer) handleMutate(w http.ResponseWriter, r *http.Request) {
    fmt.Println("Received mutating admission request")
    
    body, err := ioutil.ReadAll(r.Body)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    var admissionReview admissionv1.AdmissionReview
    if err := json.Unmarshal(body, &admissionReview); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    req := admissionReview.Request
    var response *admissionv1.AdmissionResponse
    
    switch req.Kind.Kind {
    case "Pod":
        response = ws.mutatePod(req)
    default:
        response = &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: true,
        }
    }
    
    admissionReview.Response = response
    admissionReview.Request = nil
    
    respBytes, err := json.Marshal(admissionReview)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    w.Header().Set("Content-Type", "application/json")
    w.Write(respBytes)
}

// mutatePod выполняет мутацию pod'а
func (ws *WebhookServer) mutatePod(req *admissionv1.AdmissionRequest) *admissionv1.AdmissionResponse {
    var pod corev1.Pod
    if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
        return &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: false,
            Result: &metav1.Status{
                Message: fmt.Sprintf("failed to unmarshal pod: %v", err),
            },
        }
    }
    
    // Создание JSON patches для мутации
    var patches []map[string]interface{}
    
    // Добавление sidecar контейнера
    if shouldAddSidecar(&pod) {
        sidecarPatch := createSidecarPatch(&pod)
        patches = append(patches, sidecarPatch...)
    }
    
    // Добавление environment variables
    if shouldAddEnvVars(&pod) {
        envPatch := createEnvVarsPatch(&pod)
        patches = append(patches, envPatch...)
    }
    
    // Добавление labels
    if shouldAddLabels(&pod) {
        labelsPatch := createLabelsPatch(&pod)
        patches = append(patches, labelsPatch...)
    }
    
    // Добавление annotations
    if shouldAddAnnotations(&pod) {
        annotationsPatch := createAnnotationsPatch(&pod)
        patches = append(patches, annotationsPatch...)
    }
    
    // Конвертация patches в JSON
    var patchBytes []byte
    if len(patches) > 0 {
        var err error
        patchBytes, err = json.Marshal(patches)
        if err != nil {
            return &admissionv1.AdmissionResponse{
                UID:     req.UID,
                Allowed: false,
                Result: &metav1.Status{
                    Message: fmt.Sprintf("failed to marshal patches: %v", err),
                },
            }
        }
    }
    
    patchType := admissionv1.PatchTypeJSONPatch
    return &admissionv1.AdmissionResponse{
        UID:       req.UID,
        Allowed:   true,
        Patch:     patchBytes,
        PatchType: &patchType,
    }
}

// shouldAddSidecar определяет, нужно ли добавить sidecar
func shouldAddSidecar(pod *corev1.Pod) bool {
    // Проверяем annotation для включения sidecar
    if pod.Annotations != nil {
        if inject, exists := pod.Annotations["sidecar.example.com/inject"]; exists {
            return inject == "true"
        }
    }
    
    // Проверяем namespace label
    return pod.Namespace == "production"
}

// createSidecarPatch создает patch для добавления sidecar контейнера
func createSidecarPatch(pod *corev1.Pod) []map[string]interface{} {
    sidecarContainer := map[string]interface{}{
        "name":  "logging-sidecar",
        "image": "fluent/fluent-bit:latest",
        "env": []map[string]interface{}{
            {
                "name":  "POD_NAME",
                "valueFrom": map[string]interface{}{
                    "fieldRef": map[string]interface{}{
                        "fieldPath": "metadata.name",
                    },
                },
            },
            {
                "name":  "POD_NAMESPACE",
                "valueFrom": map[string]interface{}{
                    "fieldRef": map[string]interface{}{
                        "fieldPath": "metadata.namespace",
                    },
                },
            },
        },
        "volumeMounts": []map[string]interface{}{
            {
                "name":      "varlog",
                "mountPath": "/var/log",
                "readOnly":  true,
            },
        },
        "resources": map[string]interface{}{
            "requests": map[string]interface{}{
                "cpu":    "10m",
                "memory": "32Mi",
            },
            "limits": map[string]interface{}{
                "cpu":    "50m",
                "memory": "64Mi",
            },
        },
    }
    
    // Добавление volume для логов
    logVolume := map[string]interface{}{
        "name": "varlog",
        "hostPath": map[string]interface{}{
            "path": "/var/log",
        },
    }
    
    patches := []map[string]interface{}{
        {
            "op":    "add",
            "path":  "/spec/containers/-",
            "value": sidecarContainer,
        },
    }
    
    // Добавляем volume если его еще нет
    if !hasVolume(pod, "varlog") {
        if len(pod.Spec.Volumes) == 0 {
            patches = append(patches, map[string]interface{}{
                "op":    "add",
                "path":  "/spec/volumes",
                "value": []map[string]interface{}{logVolume},
            })
        } else {
            patches = append(patches, map[string]interface{}{
                "op":    "add",
                "path":  "/spec/volumes/-",
                "value": logVolume,
            })
        }
    }
    
    return patches
}

// createEnvVarsPatch создает patch для добавления environment variables
func createEnvVarsPatch(pod *corev1.Pod) []map[string]interface{} {
    var patches []map[string]interface{}
    
    envVars := []map[string]interface{}{
        {
            "name":  "CLUSTER_NAME",
            "value": "production-cluster",
        },
        {
            "name":  "ENVIRONMENT",
            "value": "production",
        },
        {
            "name": "NODE_NAME",
            "valueFrom": map[string]interface{}{
                "fieldRef": map[string]interface{}{
                    "fieldPath": "spec.nodeName",
                },
            },
        },
    }
    
    // Добавляем env vars к каждому контейнеру
    for i := range pod.Spec.Containers {
        for _, envVar := range envVars {
            patches = append(patches, map[string]interface{}{
                "op":    "add",
                "path":  fmt.Sprintf("/spec/containers/%d/env/-", i),
                "value": envVar,
            })
        }
    }
    
    return patches
}

// createLabelsPatch создает patch для добавления labels
func createLabelsPatch(pod *corev1.Pod) []map[string]interface{} {
    labels := map[string]string{
        "injected-by":           "mutating-webhook",
        "webhook.example.com/version": "v1.0.0",
        "environment":           pod.Namespace,
    }
    
    var patches []map[string]interface{}
    
    if pod.Labels == nil {
        patches = append(patches, map[string]interface{}{
            "op":    "add",
            "path":  "/metadata/labels",
            "value": labels,
        })
    } else {
        for key, value := range labels {
            patches = append(patches, map[string]interface{}{
                "op":    "add",
                "path":  fmt.Sprintf("/metadata/labels/%s", strings.ReplaceAll(key, "/", "~1")),
                "value": value,
            })
        }
    }
    
    return patches
}

// createAnnotationsPatch создает patch для добавления annotations
func createAnnotationsPatch(pod *corev1.Pod) []map[string]interface{} {
    annotations := map[string]string{
        "webhook.example.com/mutated":    "true",
        "webhook.example.com/timestamp":  fmt.Sprintf("%d", time.Now().Unix()),
        "webhook.example.com/version":    "v1.0.0",
    }
    
    var patches []map[string]interface{}
    
    if pod.Annotations == nil {
        patches = append(patches, map[string]interface{}{
            "op":    "add",
            "path":  "/metadata/annotations",
            "value": annotations,
        })
    } else {
        for key, value := range annotations {
            patches = append(patches, map[string]interface{}{
                "op":    "add",
                "path":  fmt.Sprintf("/metadata/annotations/%s", strings.ReplaceAll(key, "/", "~1")),
                "value": value,
            })
        }
    }
    
    return patches
}

// shouldAddEnvVars определяет, нужно ли добавить env vars
func shouldAddEnvVars(pod *corev1.Pod) bool {
    return pod.Namespace == "production" || pod.Namespace == "staging"
}

// shouldAddLabels определяет, нужно ли добавить labels
func shouldAddLabels(pod *corev1.Pod) bool {
    return true // Всегда добавляем labels
}

// shouldAddAnnotations определяет, нужно ли добавить annotations
func shouldAddAnnotations(pod *corev1.Pod) bool {
    return true // Всегда добавляем annotations
}

// hasVolume проверяет, есть ли volume с указанным именем
func hasVolume(pod *corev1.Pod, volumeName string) bool {
    for _, volume := range pod.Spec.Volumes {
        if volume.Name == volumeName {
            return true
        }
    }
    return false
}

// handleValidate обрабатывает validating admission requests
func (ws *WebhookServer) handleValidate(w http.ResponseWriter, r *http.Request) {
    fmt.Println("Received validating admission request")
    
    body, err := ioutil.ReadAll(r.Body)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    var admissionReview admissionv1.AdmissionReview
    if err := json.Unmarshal(body, &admissionReview); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    req := admissionReview.Request
    var response *admissionv1.AdmissionResponse
    
    switch req.Kind.Kind {
    case "Pod":
        response = ws.validatePod(req)
    case "Service":
        response = ws.validateService(req)
    default:
        response = &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: true,
        }
    }
    
    admissionReview.Response = response
    admissionReview.Request = nil
    
    respBytes, err := json.Marshal(admissionReview)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    w.Header().Set("Content-Type", "application/json")
    w.Write(respBytes)
}

// validatePod выполняет валидацию pod'а
func (ws *WebhookServer) validatePod(req *admissionv1.AdmissionRequest) *admissionv1.AdmissionResponse {
    var pod corev1.Pod
    if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
        return &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: false,
            Result: &metav1.Status{
                Message: fmt.Sprintf("failed to unmarshal pod: %v", err),
            },
        }
    }
    
    // Валидация naming conventions
    if !isValidPodName(pod.Name) {
        return &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: false,
            Result: &metav1.Status{
                Message: "Pod name must follow naming convention: lowercase alphanumeric with hyphens",
            },
        }
    }
    
    // Валидация security context
    if !hasValidSecurityContext(&pod) {
        return &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: false,
            Result: &metav1.Status{
                Message: "Pod must have non-root security context",
            },
        }
    }
    
    // Валидация resource limits
    if !hasResourceLimits(&pod) {
        return &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: false,
            Result: &metav1.Status{
                Message: "All containers must have CPU and memory limits",
            },
        }
    }
    
    // Валидация image registry
    if !hasAllowedImages(&pod) {
        return &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: false,
            Result: &metav1.Status{
                Message: "Images must be from approved registries",
            },
        }
    }
    
    return &admissionv1.AdmissionResponse{
        UID:     req.UID,
        Allowed: true,
    }
}

// validateService выполняет валидацию service
func (ws *WebhookServer) validateService(req *admissionv1.AdmissionRequest) *admissionv1.AdmissionResponse {
    var service corev1.Service
    if err := json.Unmarshal(req.Object.Raw, &service); err != nil {
        return &admissionv1.AdmissionResponse{
            UID:     req.UID,
            Allowed: false,
            Result: &metav1.Status{
                Message: fmt.Sprintf("failed to unmarshal service: %v", err),
            },
        }
    }
    
    // Валидация LoadBalancer services
    if service.Spec.Type == corev1.ServiceTypeLoadBalancer {
        if service.Namespace != "production" {
            return &admissionv1.AdmissionResponse{
                UID:     req.UID,
                Allowed: false,
                Result: &metav1.Status{
                    Message: "LoadBalancer services are only allowed in production namespace",
                },
            }
        }
    }
    
    return &admissionv1.AdmissionResponse{
        UID:     req.UID,
        Allowed: true,
    }
}

// isValidPodName проверяет naming convention
func isValidPodName(name string) bool {
    // Простая проверка: только lowercase, цифры и дефисы
    for _, char := range name {
        if !((char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') || char == '-') {
            return false
        }
    }
    return len(name) > 0 && len(name) <= 63
}

// hasValidSecurityContext проверяет security context
func hasValidSecurityContext(pod *corev1.Pod) bool {
    // Проверяем pod-level security context
    if pod.Spec.SecurityContext != nil {
        if pod.Spec.SecurityContext.RunAsNonRoot != nil && *pod.Spec.SecurityContext.RunAsNonRoot {
            return true
        }
    }
    
    // Проверяем container-level security contexts
    for _, container := range pod.Spec.Containers {
        if container.SecurityContext != nil {
            if container.SecurityContext.RunAsNonRoot != nil && *container.SecurityContext.RunAsNonRoot {
                continue
            }
            if container.SecurityContext.RunAsUser != nil && *container.SecurityContext.RunAsUser != 0 {
                continue
            }
        }
        return false
    }
    
    return true
}

// hasResourceLimits проверяет наличие resource limits
func hasResourceLimits(pod *corev1.Pod) bool {
    for _, container := range pod.Spec.Containers {
        if container.Resources.Limits == nil {
            return false
        }
        
        if _, hasCPU := container.Resources.Limits[corev1.ResourceCPU]; !hasCPU {
            return false
        }
        
        if _, hasMemory := container.Resources.Limits[corev1.ResourceMemory]; !hasMemory {
            return false
        }
    }
    return true
}

// hasAllowedImages проверяет разрешенные image registries
func hasAllowedImages(pod *corev1.Pod) bool {
    allowedRegistries := []string{
        "docker.io",
        "gcr.io",
        "quay.io",
        "registry.company.com",
    }
    
    for _, container := range pod.Spec.Containers {
        allowed := false
        for _, registry := range allowedRegistries {
            if strings.HasPrefix(container.Image, registry) {
                allowed = true
                break
            }
        }
        if !allowed {
            return false
        }
    }
    
    return true
}

// handleHealth обрабатывает health check requests
func (ws *WebhookServer) handleHealth(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("OK"))
}

func main() {
    certPath := "/etc/certs/tls.crt"
    keyPath := "/etc/certs/tls.key"
    port := 8443
    
    webhookServer, err := NewWebhookServer(certPath, keyPath, port)
    if err != nil {
        panic(fmt.Sprintf("Failed to create webhook server: %v", err))
    }
    
    if err := webhookServer.Start(); err != nil {
        panic(fmt.Sprintf("Failed to start webhook server: %v", err))
    }
}
```

#### 2. **Webhook Deployment Manifests**
```yaml
# webhook-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admission-webhook
  namespace: webhook-system
  labels:
    app: admission-webhook
spec:
  replicas: 2
  selector:
    matchLabels:
      app: admission-webhook
  template:
    metadata:
      labels:
        app: admission-webhook
    spec:
      serviceAccountName: admission-webhook
      containers:
      - name: webhook
        image: admission-webhook:latest
        ports:
        - containerPort: 8443
          name: webhook-api
        volumeMounts:
        - name: webhook-tls-certs
          mountPath: /etc/certs
          readOnly: true
        env:
        - name: TLS_CERT_FILE
          value: /etc/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/certs/tls.key
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
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
      volumes:
      - name: webhook-tls-certs
        secret:
          secretName: webhook-tls

---
# webhook-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: admission-webhook-service
  namespace: webhook-system
spec:
  selector:
    app: admission-webhook
  ports:
  - name: webhook-api
    port: 443
    targetPort: 8443
    protocol: TCP

---
# webhook-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admission-webhook
  namespace: webhook-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admission-webhook
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admission-webhook
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admission-webhook
subjects:
- kind: ServiceAccount
  name: admission-webhook
  namespace: webhook-system

---
# mutating-webhook-configuration.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: pod-mutator.example.com
webhooks:
- name: pod-mutator.example.com
  clientConfig:
    service:
      name: admission-webhook-service
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
# validating-webhook-configuration.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: pod-validator.example.com
webhooks:
- name: pod-validator.example.com
  clientConfig:
    service:
      name: admission-webhook-service
      namespace: webhook-system
      path: "/validate"
    caBundle: LS0tLS1CRUdJTi... # Base64 encoded CA certificate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods", "services"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
  namespaceSelector:
    matchExpressions:
    - key: name
      operator: NotIn
      values: ["kube-system", "kube-public"]
```

#### 3. **Webhook Testing и Monitoring**
```bash
#!/bin/bash
# webhook-testing.sh

echo "🧪 Testing Webhook Functionality"

# Тестирование mutating webhook
test_mutating_webhook() {
    echo "=== Testing Mutating Webhook ==="
    
    # Создание тестового pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-mutating-pod
  annotations:
    sidecar.example.com/inject: "true"
spec:
  containers:
  - name: test-container
    image: nginx:alpine
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 64Mi
EOF

    # Проверка результата мутации
    echo "Checking if pod was mutated..."
    kubectl get pod test-mutating-pod -o yaml | grep -A 10 "containers:" | grep "logging-sidecar" && echo "✅ Sidecar injected" || echo "❌ Sidecar not injected"
    
    kubectl get pod test-mutating-pod -o yaml | grep "injected-by: mutating-webhook" && echo "✅ Labels added" || echo "❌ Labels not added"
    
    # Очистка
    kubectl delete pod test-mutating-pod
}

# Тестирование validating webhook
test_validating_webhook() {
    echo "=== Testing Validating Webhook ==="
    
    # Тест с невалидным pod (без resource limits)
    echo "Testing invalid pod (should be rejected)..."
    cat <<EOF | kubectl apply -f - 2>&1 | grep "denied" && echo "✅ Invalid pod rejected" || echo "❌ Invalid pod not rejected"
apiVersion: v1
kind: Pod
metadata:
  name: test-invalid-pod
spec:
  containers:
  - name: test-container
    image: nginx:alpine
    # Нет resource limits - должно быть отклонено
EOF

    # Тест с валидным pod
    echo "Testing valid pod (should be accepted)..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-valid-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: test-container
    image: nginx:alpine
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 64Mi
EOF

    kubectl get pod test-valid-pod >/dev/null 2>&1 && echo "✅ Valid pod accepted" || echo "❌ Valid pod rejected"
    
    # Очистка
    kubectl delete pod test-valid-pod --ignore-not-found
}

# Проверка webhook logs
check_webhook_logs() {
    echo "=== Webhook Logs ==="
    kubectl logs -n webhook-system -l app=admission-webhook --tail=20
}

# Проверка webhook configurations
check_webhook_configs() {
    echo "=== Webhook Configurations ==="
    
    echo "--- Mutating Webhooks ---"
    kubectl get mutatingadmissionwebhooks -o custom-columns=\
NAME:.metadata.name,\
WEBHOOKS:.webhooks[*].name,\
FAILURE_POLICY:.webhooks[*].failurePolicy
    
    echo ""
    echo "--- Validating Webhooks ---"
    kubectl get validatingadmissionwebhooks -o custom-columns=\
NAME:.metadata.name,\
WEBHOOKS:.webhooks[*].name,\
FAILURE_POLICY:.webhooks[*].failurePolicy
}

# Основная функция
main() {
    check_webhook_configs
    echo ""
    test_mutating_webhook
    echo ""
    test_validating_webhook
    echo ""
    check_webhook_logs
}

main "$@"
```

#### 4. **Webhook Certificate Management**
```bash
#!/bin/bash
# generate-webhook-certs.sh

echo "🔐 Generating Webhook Certificates"

NAMESPACE="webhook-system"
SERVICE_NAME="admission-webhook-service"
SECRET_NAME="webhook-tls"

# Создание namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Генерация CA private key
openssl genrsa -out ca.key 2048

# Генерация CA certificate
openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/CN=webhook-ca"

# Генерация server private key
openssl genrsa -out server.key 2048

# Создание CSR config
cat > server.conf <<EOF
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
EOF

# Генерация server CSR
openssl req -new -key server.key -out server.csr -config server.conf

# Подписание server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile server.conf

# Создание Kubernetes secret
kubectl create secret tls $SECRET_NAME \
    --cert=server.crt \
    --key=server.key \
    --namespace=$NAMESPACE

# Получение CA bundle для webhook configuration
CA_BUNDLE=$(cat ca.crt | base64 | tr -d '\n')

echo "CA Bundle for webhook configuration:"
echo $CA_BUNDLE

# Очистка временных файлов
rm -f ca.key ca.crt ca.srl server.key server.csr server.crt server.conf

echo "✅ Certificates generated and secret created"
```

### 📊 Мониторинг Webhooks

#### Проверка webhook метрик:
```bash
# Проверка webhook admission latency
kubectl get --raw /metrics | grep apiserver_admission_webhook_admission_duration_seconds

# Проверка webhook failures
kubectl get --raw /metrics | grep apiserver_admission_webhook_rejection_count

# Проверка webhook timeouts
kubectl get events --all-namespaces | grep "admission webhook"

# Проверка webhook availability
kubectl get endpoints -n webhook-system admission-webhook-service

# Проверка certificate expiration
kubectl get secret -n webhook-system webhook-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

### 🎯 Заключение

Kubernetes Webhooks предоставляют мощный механизм для расширения функциональности API Server. Основные преимущества:

1. **Гибкость** - возможность реализации custom логики валидации и мутации
2. **Безопасность** - enforcement security policies и compliance требований
3. **Автоматизация** - автоматическое добавление sidecar контейнеров и конфигураций
4. **Интеграция** - легкая интеграция с внешними системами

При разработке webhooks важно учитывать:
- **Производительность** - webhooks выполняются синхронно и влияют на latency API requests
- **Надежность** - правильная обработка ошибок и failurePolicy
- **Безопасность** - использование TLS и proper RBAC
- **Мониторинг** - отслеживание метрик и логов для troubleshooting
