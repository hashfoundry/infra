# 185. Как работает admission controllers в Kubernetes?

## 🎯 Вопрос
Как работает admission controllers в Kubernetes?

## 💡 Ответ

Admission Controllers в Kubernetes - это плагины, которые перехватывают запросы к API Server после аутентификации и авторизации, но до сохранения объекта в etcd. Они могут валидировать, изменять или отклонять запросы, обеспечивая дополнительную безопасность, соблюдение политик и автоматическую настройку ресурсов.

### 🏗️ Архитектура Admission Controllers

#### 1. **Схема Admission Control Process**
```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes API Request Flow                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  Client Request                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   kubectl   │    │     API     │    │   Request   │ │ │
│  │  │   create    │───▶│   Server    │───▶│ Received    │ │ │
│  │  │   object    │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Authentication & Authorization             │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    Auth     │    │    RBAC     │    │   Request   │ │ │
│  │  │ Validation  │───▶│   Check     │───▶│ Authorized  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Admission Controllers                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  Mutating   │    │ Validating  │    │   Object    │ │ │
│  │  │ Admission   │───▶│ Admission   │───▶│ Validated   │ │ │
│  │  │ Webhooks    │    │ Webhooks    │    │& Modified   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  Object Storage                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Object    │    │    etcd     │    │   Response  │ │ │
│  │  │ Persisted   │───▶│   Storage   │───▶│ to Client   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Типы Admission Controllers**
```yaml
# Типы admission controllers
admission_controller_types:
  built_in_controllers:
    description: "Встроенные контроллеры в kube-apiserver"
    examples:
      - "NamespaceLifecycle"
      - "LimitRanger"
      - "ServiceAccount"
      - "DefaultStorageClass"
      - "ResourceQuota"
      - "PodSecurityPolicy"
      - "NodeRestriction"
      - "AlwaysPullImages"
    
    configuration:
      enable_flag: "--enable-admission-plugins"
      disable_flag: "--disable-admission-plugins"
      example: "--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount"
  
  dynamic_controllers:
    description: "Динамические контроллеры через webhooks"
    types:
      mutating_webhooks:
        description: "Изменяют объекты перед сохранением"
        phase: "Mutating Admission"
        use_cases:
          - "Добавление sidecar контейнеров"
          - "Установка default значений"
          - "Инъекция конфигурации"
      
      validating_webhooks:
        description: "Валидируют объекты без изменения"
        phase: "Validating Admission"
        use_cases:
          - "Проверка политик безопасности"
          - "Валидация конфигурации"
          - "Соблюдение стандартов"

# Порядок выполнения admission controllers
execution_order:
  phase_1_mutating:
    description: "Mutating admission controllers"
    order:
      - "Built-in mutating controllers"
      - "Mutating admission webhooks (parallel)"
  
  phase_2_validating:
    description: "Validating admission controllers"
    order:
      - "Built-in validating controllers"
      - "Validating admission webhooks (parallel)"
```

### 📊 Примеры из нашего кластера

#### Проверка admission controllers:
```bash
# Проверка включенных admission controllers
kubectl get pods -n kube-system kube-apiserver-* -o yaml | grep -A 10 -B 5 admission-plugins

# Проверка admission webhooks
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Проверка admission controller logs
kubectl logs -n kube-system -l component=kube-apiserver | grep admission

# Тестирование admission controllers
kubectl auth can-i create pods --as=system:serviceaccount:default:default
```

### 🔧 Built-in Admission Controllers

#### 1. **LimitRanger Example**
```yaml
# limitrange-example.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: production
spec:
  limits:
  # Pod limits
  - type: Pod
    max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
  
  # Container limits
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "1"
      memory: "2Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
  
  # PVC limits
  - type: PersistentVolumeClaim
    max:
      storage: "100Gi"
    min:
      storage: "1Gi"

---
# Test pod - будет изменен LimitRanger
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: production
spec:
  containers:
  - name: app
    image: nginx:alpine
    # LimitRanger добавит default requests/limits
```

#### 2. **ResourceQuota Example**
```yaml
# resourcequota-example.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    # Compute resources
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    
    # Storage resources
    requests.storage: "100Gi"
    persistentvolumeclaims: "10"
    
    # Object counts
    pods: "50"
    services: "20"
    secrets: "30"
    configmaps: "30"
    
    # Specific resource types
    count/deployments.apps: "10"
    count/jobs.batch: "5"

---
# Namespace-specific quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-quota
  namespace: production
spec:
  hard:
    count/pods: "50"
    count/services: "20"
    count/secrets: "30"
    count/configmaps: "30"
    count/persistentvolumeclaims: "10"
  scopes:
  - NotTerminating  # Применяется только к не-terminating pods
```

### 🔧 Custom Admission Webhooks

#### 1. **Mutating Admission Webhook**
```go
// mutating-webhook.go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    
    admissionv1 "k8s.io/api/admission/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
)

// MutatingWebhookServer обрабатывает mutating admission requests
type MutatingWebhookServer struct {
    server *http.Server
}

// Webhook handler для mutating admission
func (mws *MutatingWebhookServer) mutate(w http.ResponseWriter, r *http.Request) {
    var body []byte
    if r.Body != nil {
        if data, err := io.ReadAll(r.Body); err == nil {
            body = data
        }
    }
    
    // Парсинг admission request
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
    
    // Создание mutation patches
    patches := []JSONPatch{}
    
    // 1. Добавление sidecar контейнера
    if shouldInjectSidecar(&pod) {
        sidecarPatch := createSidecarPatch(&pod)
        patches = append(patches, sidecarPatch...)
    }
    
    // 2. Добавление labels
    if pod.Labels == nil {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/metadata/labels",
            Value: map[string]string{},
        })
    }
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/labels/injected-by",
        Value: "mutating-webhook",
    })
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/labels/injection-timestamp",
        Value: time.Now().Format(time.RFC3339),
    })
    
    // 3. Добавление annotations
    if pod.Annotations == nil {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/metadata/annotations",
            Value: map[string]string{},
        })
    }
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/annotations/webhook.example.com~1mutated",
        Value: "true",
    })
    
    // 4. Установка security context
    if pod.Spec.SecurityContext == nil {
        patches = append(patches, createSecurityContextPatch()...)
    }
    
    // 5. Добавление resource limits если их нет
    for i, container := range pod.Spec.Containers {
        if container.Resources.Limits == nil || container.Resources.Requests == nil {
            resourcePatches := createResourcePatch(i, &container)
            patches = append(patches, resourcePatches...)
        }
    }
    
    // Создание admission response
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

// JSONPatch представляет JSON Patch операцию
type JSONPatch struct {
    Op    string      `json:"op"`
    Path  string      `json:"path"`
    Value interface{} `json:"value,omitempty"`
}

// shouldInjectSidecar определяет, нужно ли добавлять sidecar
func shouldInjectSidecar(pod *corev1.Pod) bool {
    // Проверка annotation для инъекции sidecar
    if inject, exists := pod.Annotations["sidecar.example.com/inject"]; exists {
        return inject == "true"
    }
    
    // Проверка namespace label
    // В реальном webhook нужно получить namespace из API
    return false
}

// createSidecarPatch создает patch для добавления sidecar контейнера
func createSidecarPatch(pod *corev1.Pod) []JSONPatch {
    sidecar := corev1.Container{
        Name:  "logging-sidecar",
        Image: "fluent/fluent-bit:latest",
        VolumeMounts: []corev1.VolumeMount{
            {
                Name:      "varlog",
                MountPath: "/var/log",
                ReadOnly:  true,
            },
        },
        Resources: corev1.ResourceRequirements{
            Requests: corev1.ResourceList{
                corev1.ResourceCPU:    resource.MustParse("100m"),
                corev1.ResourceMemory: resource.MustParse("128Mi"),
            },
            Limits: corev1.ResourceList{
                corev1.ResourceCPU:    resource.MustParse("200m"),
                corev1.ResourceMemory: resource.MustParse("256Mi"),
            },
        },
    }
    
    patches := []JSONPatch{
        {
            Op:    "add",
            Path:  "/spec/containers/-",
            Value: sidecar,
        },
    }
    
    // Добавление volume если его нет
    hasVarLogVolume := false
    for _, vol := range pod.Spec.Volumes {
        if vol.Name == "varlog" {
            hasVarLogVolume = true
            break
        }
    }
    
    if !hasVarLogVolume {
        volume := corev1.Volume{
            Name: "varlog",
            VolumeSource: corev1.VolumeSource{
                HostPath: &corev1.HostPathVolumeSource{
                    Path: "/var/log",
                },
            },
        }
        
        if len(pod.Spec.Volumes) == 0 {
            patches = append(patches, JSONPatch{
                Op:    "add",
                Path:  "/spec/volumes",
                Value: []corev1.Volume{volume},
            })
        } else {
            patches = append(patches, JSONPatch{
                Op:    "add",
                Path:  "/spec/volumes/-",
                Value: volume,
            })
        }
    }
    
    return patches
}

// createSecurityContextPatch создает patch для security context
func createSecurityContextPatch() []JSONPatch {
    securityContext := &corev1.PodSecurityContext{
        RunAsNonRoot: &[]bool{true}[0],
        RunAsUser:    &[]int64{1000}[0],
        FSGroup:      &[]int64{2000}[0],
    }
    
    return []JSONPatch{
        {
            Op:    "add",
            Path:  "/spec/securityContext",
            Value: securityContext,
        },
    }
}

// createResourcePatch создает patch для resource limits
func createResourcePatch(containerIndex int, container *corev1.Container) []JSONPatch {
    patches := []JSONPatch{}
    
    if container.Resources.Requests == nil {
        patches = append(patches, JSONPatch{
            Op:   "add",
            Path: fmt.Sprintf("/spec/containers/%d/resources/requests", containerIndex),
            Value: corev1.ResourceList{
                corev1.ResourceCPU:    resource.MustParse("100m"),
                corev1.ResourceMemory: resource.MustParse("128Mi"),
            },
        })
    }
    
    if container.Resources.Limits == nil {
        patches = append(patches, JSONPatch{
            Op:   "add",
            Path: fmt.Sprintf("/spec/containers/%d/resources/limits", containerIndex),
            Value: corev1.ResourceList{
                corev1.ResourceCPU:    resource.MustParse("500m"),
                corev1.ResourceMemory: resource.MustParse("512Mi"),
            },
        })
    }
    
    return patches
}

func main() {
    mws := &MutatingWebhookServer{}
    
    mux := http.NewServeMux()
    mux.HandleFunc("/mutate", mws.mutate)
    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })
    
    server := &http.Server{
        Addr:    ":8443",
        Handler: mux,
    }
    
    log.Println("Starting mutating webhook server on :8443")
    log.Fatal(server.ListenAndServeTLS("/etc/certs/tls.crt", "/etc/certs/tls.key"))
}
```

#### 2. **Validating Admission Webhook**
```go
// validating-webhook.go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "strings"
    
    admissionv1 "k8s.io/api/admission/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// ValidatingWebhookServer обрабатывает validating admission requests
type ValidatingWebhookServer struct {
    server *http.Server
}

// Webhook handler для validating admission
func (vws *ValidatingWebhookServer) validate(w http.ResponseWriter, r *http.Request) {
    var body []byte
    if r.Body != nil {
        if data, err := io.ReadAll(r.Body); err == nil {
            body = data
        }
    }
    
    // Парсинг admission request
    var admissionReview admissionv1.AdmissionReview
    if err := json.Unmarshal(body, &admissionReview); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    req := admissionReview.Request
    allowed := true
    message := ""
    
    // Валидация в зависимости от типа ресурса
    switch req.Kind.Kind {
    case "Pod":
        allowed, message = vws.validatePod(req)
    case "Service":
        allowed, message = vws.validateService(req)
    case "Deployment":
        allowed, message = vws.validateDeployment(req)
    default:
        allowed = true
    }
    
    // Создание admission response
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

// validatePod валидирует Pod объекты
func (vws *ValidatingWebhookServer) validatePod(req *admissionv1.AdmissionRequest) (bool, string) {
    var pod corev1.Pod
    if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
        return false, fmt.Sprintf("Failed to parse pod: %v", err)
    }
    
    // 1. Проверка обязательных labels
    if !vws.hasRequiredLabels(&pod) {
        return false, "Pod must have required labels: app, version, environment"
    }
    
    // 2. Проверка security context
    if !vws.hasSecureSecurityContext(&pod) {
        return false, "Pod must run as non-root user with read-only root filesystem"
    }
    
    // 3. Проверка resource limits
    if !vws.hasResourceLimits(&pod) {
        return false, "All containers must have CPU and memory limits"
    }
    
    // 4. Проверка запрещенных образов
    if vws.hasForbiddenImages(&pod) {
        return false, "Pod contains forbidden container images"
    }
    
    // 5. Проверка network policies
    if !vws.hasNetworkPolicyCompliance(&pod) {
        return false, "Pod must comply with network policy requirements"
    }
    
    return true, "Pod validation passed"
}

// hasRequiredLabels проверяет наличие обязательных labels
func (vws *ValidatingWebhookServer) hasRequiredLabels(pod *corev1.Pod) bool {
    requiredLabels := []string{"app", "version", "environment"}
    
    for _, label := range requiredLabels {
        if _, exists := pod.Labels[label]; !exists {
            return false
        }
    }
    
    // Проверка допустимых значений environment
    env := pod.Labels["environment"]
    allowedEnvs := []string{"development", "staging", "production"}
    
    for _, allowedEnv := range allowedEnvs {
        if env == allowedEnv {
            return true
        }
    }
    
    return false
}

// hasSecureSecurityContext проверяет security context
func (vws *ValidatingWebhookServer) hasSecureSecurityContext(pod *corev1.Pod) bool {
    // Проверка pod security context
    if pod.Spec.SecurityContext == nil {
        return false
    }
    
    if pod.Spec.SecurityContext.RunAsNonRoot == nil || !*pod.Spec.SecurityContext.RunAsNonRoot {
        return false
    }
    
    // Проверка container security contexts
    for _, container := range pod.Spec.Containers {
        if container.SecurityContext == nil {
            return false
        }
        
        if container.SecurityContext.ReadOnlyRootFilesystem == nil || 
           !*container.SecurityContext.ReadOnlyRootFilesystem {
            return false
        }
        
        if container.SecurityContext.AllowPrivilegeEscalation == nil ||
           *container.SecurityContext.AllowPrivilegeEscalation {
            return false
        }
    }
    
    return true
}

// hasResourceLimits проверяет resource limits
func (vws *ValidatingWebhookServer) hasResourceLimits(pod *corev1.Pod) bool {
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

// hasForbiddenImages проверяет запрещенные образы
func (vws *ValidatingWebhookServer) hasForbiddenImages(pod *corev1.Pod) bool {
    forbiddenPrefixes := []string{
        "docker.io/library/",  // Публичные образы без версии
        "latest",              // Latest tag
        "debug",               // Debug образы
    }
    
    for _, container := range pod.Spec.Containers {
        image := container.Image
        
        // Проверка на latest tag
        if !strings.Contains(image, ":") || strings.HasSuffix(image, ":latest") {
            return true
        }
        
        // Проверка запрещенных префиксов
        for _, prefix := range forbiddenPrefixes {
            if strings.Contains(image, prefix) {
                return true
            }
        }
    }
    
    return false
}

// hasNetworkPolicyCompliance проверяет соответствие network policies
func (vws *ValidatingWebhookServer) hasNetworkPolicyCompliance(pod *corev1.Pod) bool {
    // Проверка наличия network policy labels
    if _, hasNetworkPolicy := pod.Labels["network-policy"]; !hasNetworkPolicy {
        return false
    }
    
    // Проверка для production namespace
    if pod.Namespace == "production" {
        if policy, exists := pod.Labels["network-policy"]; exists {
            return policy == "restricted" || policy == "internal"
        }
        return false
    }
    
    return true
}

// validateService валидирует Service объекты
func (vws *ValidatingWebhookServer) validateService(req *admissionv1.AdmissionRequest) (bool, string) {
    var service corev1.Service
    if err := json.Unmarshal(req.Object.Raw, &service); err != nil {
        return false, fmt.Sprintf("Failed to parse service: %v", err)
    }
    
    // Проверка LoadBalancer в production
    if service.Namespace == "production" && service.Spec.Type == corev1.ServiceTypeLoadBalancer {
        return false, "LoadBalancer services are not allowed in production namespace"
    }
    
    return true, "Service validation passed"
}

func main() {
    vws := &ValidatingWebhookServer{}
    
    mux := http.NewServeMux()
    mux.HandleFunc("/validate", vws.validate)
    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })
    
    server := &http.Server{
        Addr:    ":8443",
        Handler: mux,
    }
    
    log.Println("Starting validating webhook server on :8443")
    log.Fatal(server.ListenAndServeTLS("/etc/certs/tls.crt", "/etc/certs/tls.key"))
}
```

### 🔧 Webhook Configuration

#### 1. **MutatingAdmissionWebhook Configuration**
```yaml
# mutating-webhook-config.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: pod-mutator.example.com
webhooks:
- name: pod-mutator.example.com
  clientConfig:
    service:
      name: mutating-webhook-service
      namespace: webhook-system
      path: "/mutate"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
  reinvocationPolicy: Never

---
# ValidatingAdmissionWebhook Configuration
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: pod-validator.example.com
webhooks:
- name: pod-validator.example.com
  clientConfig:
    service:
      name: validating-webhook-service
      namespace: webhook-system
      path: "/validate"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["services"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources: ["deployments"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
```

Admission Controllers обеспечивают мощный механизм для контроля и автоматизации в Kubernetes, позволяя реализовать сложные политики безопасности, соблюдение стандартов и автоматическую конфигурацию ресурсов.
