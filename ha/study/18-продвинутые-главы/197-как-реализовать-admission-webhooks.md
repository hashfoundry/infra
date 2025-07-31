# 197. Как реализовать Admission Webhooks?

## 🎯 **Что такое Admission Webhooks?**

**Admission Webhooks** — это механизм расширения Kubernetes API, позволяющий перехватывать и модифицировать запросы к API серверу до их сохранения в etcd. Существует два типа: **Mutating Admission Webhooks** (изменяют объекты) и **Validating Admission Webhooks** (валидируют объекты).

## 🏗️ **Основные компоненты:**

### **1. Mutating Admission Webhooks**
- Изменение объектов перед валидацией
- Добавление default значений и labels
- Инъекция sidecar контейнеров
- Модификация security context
- Применение стандартов организации

### **2. Validating Admission Webhooks**
- Валидация объектов после мутации
- Проверка соответствия политикам безопасности
- Валидация business логики
- Контроль compliance требований
- Предотвращение нарушений стандартов

### **3. Admission Control Flow**
- Authentication и Authorization
- Mutating Admission Controllers
- Object Schema Validation
- Validating Admission Controllers
- Сохранение в etcd

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка существующих Admission Webhooks:**
```bash
# Проверка mutating webhooks в кластере
kubectl get mutatingadmissionwebhooks

# Проверка validating webhooks в кластере
kubectl get validatingadmissionwebhooks

# Проверка webhook configurations
kubectl describe mutatingadmissionwebhook <webhook-name>
kubectl describe validatingadmissionwebhook <webhook-name>

# Проверка webhook endpoints
kubectl get endpoints --all-namespaces | grep webhook

# Проверка webhook pods
kubectl get pods --all-namespaces | grep webhook
```

### **2. Анализ существующих webhooks в кластере:**
```bash
# Проверка ArgoCD webhooks (если есть)
kubectl get mutatingadmissionwebhooks | grep argocd
kubectl get validatingadmissionwebhooks | grep argocd

# Проверка cert-manager webhooks
kubectl get validatingadmissionwebhooks | grep cert-manager

# Проверка metrics server webhooks
kubectl get apiservices | grep metrics

# Проверка admission controller логов
kubectl logs -n kube-system -l component=kube-apiserver | grep admission
```

### **3. Создание namespace для webhook тестирования:**
```bash
# Создание namespace для webhook системы
kubectl create namespace webhook-system

# Создание namespace для тестирования
kubectl create namespace webhook-test
kubectl label namespace webhook-test webhook-enabled=true

# Проверка созданных namespaces
kubectl get namespaces -l webhook-enabled=true
```

### **4. Генерация TLS сертификатов для webhook:**
```bash
# Создание CA ключа и сертификата
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key \
  -subj "/C=US/ST=CA/L=SF/O=HashFoundry/CN=Webhook CA" -out ca.crt

# Создание server ключа
openssl genrsa -out server.key 2048

# Создание CSR конфигурации
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
DNS.1 = webhook-service
DNS.2 = webhook-service.webhook-system
DNS.3 = webhook-service.webhook-system.svc
DNS.4 = webhook-service.webhook-system.svc.cluster.local
EOF

# Генерация CSR и сертификата
openssl req -new -key server.key \
  -subj "/C=US/ST=CA/L=SF/O=HashFoundry/CN=webhook-service.webhook-system.svc" \
  -out server.csr -config server.conf

openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 365 \
  -extensions v3_req -extfile server.conf

# Создание secret с сертификатами
kubectl create secret tls webhook-certs \
  --cert=server.crt --key=server.key -n webhook-system
```

### **5. Мониторинг webhook активности:**
```bash
# Мониторинг через Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &

# Проверка метрик admission webhooks
# Query: apiserver_admission_webhook_admission_duration_seconds
# Query: apiserver_admission_webhook_rejection_count

# Проверка логов API server
kubectl logs -n kube-system -l component=kube-apiserver | grep webhook

# Мониторинг через Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 &
```

## 🔄 **Реализация Mutating Admission Webhook:**

### **1. Webhook Server Implementation:**
```yaml
# mutating-webhook-server.yaml
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
        image: hashfoundry/mutating-webhook:v1.0.0
        ports:
        - containerPort: 8443
          name: webhook-api
        env:
        - name: TLS_CERT_FILE
          value: /etc/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/certs/tls.key
        - name: WEBHOOK_PORT
          value: "8443"
        volumeMounts:
        - name: webhook-certs
          mountPath: /etc/certs
          readOnly: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
      volumes:
      - name: webhook-certs
        secret:
          secretName: webhook-certs
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000

---
# Service для webhook
apiVersion: v1
kind: Service
metadata:
  name: webhook-service
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
  type: ClusterIP

---
# ServiceAccount и RBAC
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webhook-service-account
  namespace: webhook-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: webhook-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: webhook-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: webhook-reader
subjects:
- kind: ServiceAccount
  name: webhook-service-account
  namespace: webhook-system
```

### **2. Mutating Webhook Configuration:**
```yaml
# mutating-webhook-config.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: hashfoundry-mutating-webhook
webhooks:
- name: pod-defaults.hashfoundry.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/mutate/pods"
    caBundle: LS0tLS1CRUdJTi0tLS0t  # Base64 encoded CA cert
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
  namespaceSelector:
    matchLabels:
      webhook-enabled: "true"

- name: deployment-standards.hashfoundry.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/mutate/deployments"
    caBundle: LS0tLS1CRUdJTi0tLS0t  # Base64 encoded CA cert
  rules:
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

- name: service-annotations.hashfoundry.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/mutate/services"
    caBundle: LS0tLS1CRUdJTi0tLS0t  # Base64 encoded CA cert
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["services"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Ignore  # Less critical mutations
  timeoutSeconds: 5
  namespaceSelector:
    matchLabels:
      webhook-enabled: "true"
```

### **3. Webhook Logic Examples:**
```go
// webhook-mutations.go
package main

import (
    "encoding/json"
    "fmt"
    "strings"
    
    admissionv1 "k8s.io/api/admission/v1"
    corev1 "k8s.io/api/core/v1"
    appsv1 "k8s.io/api/apps/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// JSONPatch represents a JSON patch operation
type JSONPatch struct {
    Op    string      `json:"op"`
    Path  string      `json:"path"`
    Value interface{} `json:"value,omitempty"`
}

// Mutate Pod with HashFoundry standards
func mutatePod(req *admissionv1.AdmissionRequest) ([]JSONPatch, error) {
    var pod corev1.Pod
    if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
        return nil, fmt.Errorf("failed to unmarshal pod: %v", err)
    }

    var patches []JSONPatch

    // Add HashFoundry standard labels
    if pod.Labels == nil {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/metadata/labels",
            Value: map[string]string{},
        })
    }
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/labels/app.kubernetes.io~1managed-by",
        Value: "hashfoundry-webhook",
    })
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/labels/hashfoundry.com~1monitoring",
        Value: "enabled",
    })

    // Add security context if missing
    if pod.Spec.SecurityContext == nil {
        patches = append(patches, JSONPatch{
            Op:   "add",
            Path: "/spec/securityContext",
            Value: map[string]interface{}{
                "runAsNonRoot": true,
                "runAsUser":    1000,
                "fsGroup":      2000,
            },
        })
    }

    // Add resource limits to containers without them
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
        
        if container.Resources.Requests == nil {
            patches = append(patches, JSONPatch{
                Op:   "add",
                Path: fmt.Sprintf("/spec/containers/%d/resources/requests", i),
                Value: map[string]interface{}{
                    "cpu":    "100m",
                    "memory": "128Mi",
                },
            })
        }
    }

    // Add monitoring sidecar for production namespaces
    if strings.HasPrefix(pod.Namespace, "prod-") || pod.Namespace == "monitoring" {
        monitoringSidecar := corev1.Container{
            Name:  "monitoring-agent",
            Image: "hashfoundry/monitoring-agent:v1.2.0",
            Ports: []corev1.ContainerPort{
                {ContainerPort: 9090, Name: "metrics"},
            },
            Resources: corev1.ResourceRequirements{
                Requests: corev1.ResourceList{
                    "cpu":    "50m",
                    "memory": "64Mi",
                },
                Limits: corev1.ResourceList{
                    "cpu":    "100m",
                    "memory": "128Mi",
                },
            },
            SecurityContext: &corev1.SecurityContext{
                RunAsNonRoot:             &[]bool{true}[0],
                RunAsUser:                &[]int64{1000}[0],
                AllowPrivilegeEscalation: &[]bool{false}[0],
                ReadOnlyRootFilesystem:   &[]bool{true}[0],
            },
        }
        
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/spec/containers/-",
            Value: monitoringSidecar,
        })
    }

    // Add NFS volume for shared storage if needed
    if hasLabel(pod.Labels, "hashfoundry.com/shared-storage", "enabled") {
        nfsVolume := corev1.Volume{
            Name: "shared-storage",
            VolumeSource: corev1.VolumeSource{
                NFS: &corev1.NFSVolumeSource{
                    Server: "nfs-server.nfs-provisioner.svc.cluster.local",
                    Path:   "/shared",
                },
            },
        }
        
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/spec/volumes/-",
            Value: nfsVolume,
        })
    }

    return patches, nil
}

// Mutate Deployment with HashFoundry standards
func mutateDeployment(req *admissionv1.AdmissionRequest) ([]JSONPatch, error) {
    var deployment appsv1.Deployment
    if err := json.Unmarshal(req.Object.Raw, &deployment); err != nil {
        return nil, fmt.Errorf("failed to unmarshal deployment: %v", err)
    }

    var patches []JSONPatch

    // Add standard annotations
    if deployment.Annotations == nil {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/metadata/annotations",
            Value: map[string]string{},
        })
    }
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/annotations/hashfoundry.com~1webhook-mutated",
        Value: "true",
    })

    // Ensure minimum replicas for production
    if strings.HasPrefix(deployment.Namespace, "prod-") {
        if deployment.Spec.Replicas == nil || *deployment.Spec.Replicas < 2 {
            patches = append(patches, JSONPatch{
                Op:    "replace",
                Path:  "/spec/replicas",
                Value: 2,
            })
        }
    }

    // Add deployment strategy if missing
    if deployment.Spec.Strategy.Type == "" {
        patches = append(patches, JSONPatch{
            Op:   "add",
            Path: "/spec/strategy",
            Value: map[string]interface{}{
                "type": "RollingUpdate",
                "rollingUpdate": map[string]interface{}{
                    "maxUnavailable": "25%",
                    "maxSurge":       "25%",
                },
            },
        })
    }

    // Add Pod Disruption Budget annotation
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/annotations/hashfoundry.com~1pdb-required",
        Value: "true",
    })

    return patches, nil
}

// Mutate Service with HashFoundry standards
func mutateService(req *admissionv1.AdmissionRequest) ([]JSONPatch, error) {
    var service corev1.Service
    if err := json.Unmarshal(req.Object.Raw, &service); err != nil {
        return nil, fmt.Errorf("failed to unmarshal service: %v", err)
    }

    var patches []JSONPatch

    // Add Prometheus monitoring annotations
    if service.Annotations == nil {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/metadata/annotations",
            Value: map[string]string{},
        })
    }
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/annotations/prometheus.io~1scrape",
        Value: "true",
    })
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/annotations/prometheus.io~1port",
        Value: "9090",
    })
    
    patches = append(patches, JSONPatch{
        Op:    "add",
        Path:  "/metadata/annotations/prometheus.io~1path",
        Value: "/metrics",
    })

    // Add HashFoundry service mesh annotations for production
    if strings.HasPrefix(service.Namespace, "prod-") {
        patches = append(patches, JSONPatch{
            Op:    "add",
            Path:  "/metadata/annotations/hashfoundry.com~1service-mesh",
            Value: "enabled",
        })
    }

    return patches, nil
}

// Helper function to check labels
func hasLabel(labels map[string]string, key, value string) bool {
    if labels == nil {
        return false
    }
    return labels[key] == value
}
```

## 🔧 **Реализация Validating Admission Webhook:**

### **1. Validating Webhook Configuration:**
```yaml
# validating-webhook-config.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: hashfoundry-validating-webhook
webhooks:
- name: pod-security.hashfoundry.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/validate/pods"
    caBundle: LS0tLS1CRUdJTi0tLS0t  # Base64 encoded CA cert
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
  namespaceSelector:
    matchLabels:
      webhook-enabled: "true"

- name: deployment-compliance.hashfoundry.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/validate/deployments"
    caBundle: LS0tLS1CRUdJTi0tLS0t  # Base64 encoded CA cert
  rules:
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

- name: service-policy.hashfoundry.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-system
      path: "/validate/services"
    caBundle: LS0tLS1CRUdJTi0tLS0t  # Base64 encoded CA cert
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["services"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 5
  namespaceSelector:
    matchLabels:
      webhook-enabled: "true"
```

### **2. Validation Logic Examples:**
```go
// webhook-validations.go
package main

import (
    "encoding/json"
    "fmt"
    "strings"
    
    admissionv1 "k8s.io/api/admission/v1"
    corev1 "k8s.io/api/core/v1"
    appsv1 "k8s.io/api/apps/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Validate Pod security and compliance
func validatePod(req *admissionv1.AdmissionRequest) (bool, string) {
    var pod corev1.Pod
    if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
        return false, fmt.Sprintf("Failed to parse pod: %v", err)
    }

    // Validate security context
    if pod.Spec.SecurityContext == nil {
        return false, "Pod must have security context defined"
    }
    
    if pod.Spec.SecurityContext.RunAsNonRoot == nil || !*pod.Spec.SecurityContext.RunAsNonRoot {
        return false, "Pod must run as non-root user"
    }

    // Validate container security
    for _, container := range pod.Spec.Containers {
        // Check privileged containers
        if container.SecurityContext != nil && 
           container.SecurityContext.Privileged != nil && 
           *container.SecurityContext.Privileged {
            return false, fmt.Sprintf("Container %s cannot run in privileged mode", container.Name)
        }

        // Check resource limits
        if container.Resources.Limits == nil {
            return false, fmt.Sprintf("Container %s must have resource limits", container.Name)
        }
        
        if container.Resources.Limits.Cpu().IsZero() {
            return false, fmt.Sprintf("Container %s must have CPU limit", container.Name)
        }
        
        if container.Resources.Limits.Memory().IsZero() {
            return false, fmt.Sprintf("Container %s must have memory limit", container.Name)
        }

        // Validate image registry
        if !isAllowedImageRegistry(container.Image) {
            return false, fmt.Sprintf("Container %s uses unauthorized image registry: %s", 
                container.Name, container.Image)
        }

        // Check for latest tag
        if strings.HasSuffix(container.Image, ":latest") {
            return false, fmt.Sprintf("Container %s cannot use 'latest' tag", container.Name)
        }

        // Validate capabilities
        if container.SecurityContext != nil && container.SecurityContext.Capabilities != nil {
            for _, cap := range container.SecurityContext.Capabilities.Add {
                if !isAllowedCapability(string(cap)) {
                    return false, fmt.Sprintf("Container %s uses forbidden capability: %s", 
                        container.Name, cap)
                }
            }
        }
    }

    // Validate host network
    if pod.Spec.HostNetwork {
        return false, "Pod cannot use host network"
    }

    // Validate host PID
    if pod.Spec.HostPID {
        return false, "Pod cannot use host PID namespace"
    }

    // Validate volumes
    for _, volume := range pod.Spec.Volumes {
        if volume.HostPath != nil {
            return false, fmt.Sprintf("Pod cannot use hostPath volume: %s", volume.Name)
        }
    }

    return true, "Pod validation passed"
}

// Validate Deployment compliance
func validateDeployment(req *admissionv1.AdmissionRequest) (bool, string) {
    var deployment appsv1.Deployment
    if err := json.Unmarshal(req.Object.Raw, &deployment); err != nil {
        return false, fmt.Sprintf("Failed to parse deployment: %v", err)
    }

    // Validate replica count for production
    if strings.HasPrefix(deployment.Namespace, "prod-") {
        if deployment.Spec.Replicas == nil || *deployment.Spec.Replicas < 2 {
            return false, "Production deployments must have at least 2 replicas"
        }
    }

    // Validate deployment strategy
    if deployment.Spec.Strategy.Type == appsv1.RecreateDeploymentStrategyType {
        if strings.HasPrefix(deployment.Namespace, "prod-") {
            return false, "Production deployments cannot use Recreate strategy"
        }
    }

    // Validate pod template
    podValid, podMessage := validatePodTemplate(&deployment.Spec.Template)
    if !podValid {
        return false, fmt.Sprintf("Pod template validation failed: %s", podMessage)
    }

    // Validate labels and selectors
    if deployment.Spec.Selector == nil || len(deployment.Spec.Selector.MatchLabels) == 0 {
        return false, "Deployment must have selector with match labels"
    }

    // Validate required labels
    requiredLabels := []string{"app", "version"}
    for _, label := range requiredLabels {
        if _, exists := deployment.Spec.Template.Labels[label]; !exists {
            return false, fmt.Sprintf("Deployment pod template must have label: %s", label)
        }
    }

    return true, "Deployment validation passed"
}

// Validate Service policies
func validateService(req *admissionv1.AdmissionRequest) (bool, string) {
    var service corev1.Service
    if err := json.Unmarshal(req.Object.Raw, &service); err != nil {
        return false, fmt.Sprintf("Failed to parse service: %v", err)
    }

    // Validate LoadBalancer services
    if service.Spec.Type == corev1.ServiceTypeLoadBalancer {
        if !strings.HasPrefix(service.Namespace, "prod-") && 
           service.Namespace != "monitoring" {
            return false, "LoadBalancer services are only allowed in production and monitoring namespaces"
        }
    }

    // Validate NodePort range
    for _, port := range service.Spec.Ports {
        if port.NodePort != 0 {
            if port.NodePort < 30000 || port.NodePort > 32767 {
                return false, fmt.Sprintf("NodePort %d is outside allowed range (30000-32767)", 
                    port.NodePort)
            }
        }
    }

    // Validate port names
    for _, port := range service.Spec.Ports {
        if port.Name == "" && len(service.Spec.Ports) > 1 {
            return false, "Multi-port services must name all ports"
        }
    }

    // Validate selector
    if len(service.Spec.Selector) == 0 && service.Spec.Type != corev1.ServiceTypeExternalName {
        return false, "Service must have selector (except ExternalName services)"
    }

    return true, "Service validation passed"
}

// Helper functions
func isAllowedImageRegistry(image string) bool {
    allowedRegistries := []string{
        "registry.hashfoundry.com/",
        "docker.io/library/",
        "quay.io/",
        "gcr.io/",
        "k8s.gcr.io/",
    }
    
    for _, registry := range allowedRegistries {
        if strings.HasPrefix(image, registry) {
            return true
        }
    }
    return false
}

func isAllowedCapability(capability string) bool {
    allowedCapabilities := []string{
        "NET_BIND_SERVICE",
        "CHOWN", 
        "DAC_OVERRIDE",
        "FOWNER",
        "SETGID",
        "SETUID",
    }
    
    for _, allowed := range allowedCapabilities {
        if capability == allowed {
            return true
        }
    }
    return false
}

func validatePodTemplate(template *corev1.PodTemplateSpec) (bool, string) {
    // Simplified validation for pod templates
    if template.Spec.SecurityContext == nil {
        return false, "Pod template must have security context"
    }
    return true, "Pod template validation passed"
}
```

## 🏭 **Интеграция с ArgoCD и мониторингом:**

### **1. ArgoCD Application для Webhook:**
```yaml
# argocd-webhook-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: admission-webhooks
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/admission-webhooks
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: webhook-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### **2. Prometheus мониторинг для Webhooks:**
```yaml
# webhook-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: admission-webhook
  namespace: webhook-system
spec:
  selector:
    matchLabels:
      app: mutating-webhook
  endpoints:
  - port: webhook-api
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
    path: /metrics

---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: webhook-alerts
  namespace: webhook-system
spec:
  groups:
  - name: webhook.rules
    rules:
    - alert: WebhookDown
      expr: up{job="admission-webhook"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Admission webhook is down"
    
    - alert: WebhookHighLatency
      expr: histogram_quantile(0.99, rate(webhook_request_duration_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High webhook latency"
```

### **3. Тестирование Webhooks:**
```bash
#!/bin/bash
# test-webhooks.sh

echo "🧪 Testing Admission Webhooks"

test_mutating_webhook() {
    echo "=== Testing Mutating Webhook ==="
    
    # Test pod mutation
    cat <<EOF | kubectl apply --dry-run=server -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: webhook-test
spec:
  containers:
  - name: test
    image: nginx:1.20
EOF

    # Test deployment mutation
    cat <<EOF | kubectl apply --dry-run=server -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: webhook-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test
        image: nginx:1.20
EOF
}

test_validating_webhook() {
    echo "=== Testing Validating Webhook ==="
    
    # Test invalid pod (should fail)
    cat <<EOF | kubectl apply --dry-run=server -f - 2>&1 || echo "✅ Validation correctly rejected invalid pod"
apiVersion: v1
kind: Pod
metadata:
  name: invalid-pod
  namespace: webhook-test
spec:
  hostNetwork: true
  containers:
  - name: test
    image: nginx:latest
    securityContext:
      privileged: true
EOF

    # Test valid pod (should pass)
    cat <<EOF | kubectl apply --dry-run=server -f -
apiVersion: v1
kind: Pod
metadata:
  name: valid-pod
  namespace: webhook-test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: test
    image: nginx:1.20
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
EOF
}

check_webhook_status() {
    echo "=== Webhook Status ==="
    
    kubectl get mutatingadmissionwebhooks hashfoundry-mutating-webhook
    kubectl get validatingadmissionwebhooks hashfoundry-validating-webhook
    
    kubectl get pods -n webhook-system -l app=mutating-webhook
    kubectl logs -n webhook-system -l app=mutating-webhook --tail=10
}

main() {
    test_mutating_webhook
    echo ""
    test_validating_webhook
    echo ""
    check_webhook_status
}

main "$@"
```

## 🚨 **Troubleshooting Admission Webhooks:**

### **1. Диагностический скрипт:**
```bash
#!/bin/bash
# diagnose-webhooks.sh

echo "🔍 Diagnosing Admission Webhooks"

diagnose_webhook_config() {
    echo "=== Webhook Configuration ==="
    
    kubectl get mutatingadmissionwebhooks -o yaml
    kubectl get validatingadmissionwebhooks -o yaml
    
    echo ""
    echo "=== Webhook Endpoints ==="
    kubectl get endpoints -n webhook-system webhook-service
    kubectl describe service -n webhook-system webhook-service
}

check_certificates() {
    echo "=== Certificate Check ==="
    
    kubectl get secret webhook-certs -n webhook-system -o yaml
    
    # Verify certificate validity
    kubectl get secret webhook-certs -n webhook-system -o jsonpath='{.data.tls\.crt}' | \
        base64 -d | openssl x509 -text -noout | head -20
}

test_webhook_connectivity() {
    echo "=== Webhook Connectivity ==="
    
    # Port forward to webhook service
    kubectl port-forward -n webhook-system svc/webhook-service 8443:443 &
    PF_PID=$!
    
    sleep 2
    
    # Test webhook health
    curl -k https://localhost:8443/healthz || echo "Health check failed"
    curl -k https://localhost:8443/readyz || echo "Ready check failed"
    
    kill $PF_PID
}

check_webhook_logs() {
    echo "=== Webhook Logs ==="
    
    kubectl logs -n webhook-system -l app=mutating-webhook --tail=20
    
    echo ""
    echo "=== API Server Logs ==="
    kubectl logs -n kube-system -l component=kube-apiserver | grep webhook | tail -10
}

main() {
    diagnose_webhook_config
    echo ""
    check_certificates
    echo ""
    test_webhook_connectivity
    echo ""
    check_webhook_logs
}

main "$@"
```

## 🎯 **Архитектура Admission Webhooks в HA кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│           HA Cluster Admission Webhooks Architecture       │
├─────────────────────────────────────────────────────────────┤
│  Client Requests                                           │
│  ├── kubectl apply                                         │
│  ├── ArgoCD sync                                           │
│  ├── CI/CD pipelines                                       │
│  └── API calls                                             │
├─────────────────────────────────────────────────────────────┤
│  Load Balancer (DigitalOcean)                             │
│  └── kube-apiserver (HA)                                   │
├─────────────────────────────────────────────────────────────┤
│  Admission Control Flow                                    │
│  ├── 1. Authentication & Authorization                     │
│  ├── 2. Mutating Admission Webhooks                        │
│  │   ├── HashFoundry Standards Injection                   │
│  │   ├── Security Context Addition                         │
│  │   ├── Resource Limits Enforcement                       │
│  │   └── Monitoring Sidecar Injection                      │
│  ├── 3. Object Schema Validation                           │
│  ├── 4. Validating Admission Webhooks                      │
│  │   ├── Security Policy Validation                        │
│  │   ├── Compliance Checks                                 │
│  │   ├── Business Logic Validation                         │
│  │   └── Registry Policy Enforcement                       │
│  └── 5. etcd Storage                                       │
├─────────────────────────────────────────────────────────────┤
│  Webhook Infrastructure (HA)                               │
│  ├── Webhook Pods (2+ replicas)                            │
│  ├── TLS Certificates (Secret)                             │
│  ├── Service (ClusterIP)                                   │
│  └── RBAC (ServiceAccount + Roles)                         │
├─────────────────────────────────────────────────────────────┤
│  Monitoring & Observability                               │
│  ├── Prometheus (webhook metrics)                          │
│  ├── Grafana (webhook dashboards)                          │
│  ├── AlertManager (webhook alerts)                         │
│  └── Logs (webhook + API server)                           │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для Admission Webhooks:**

### **1. Безопасность:**
- Используйте TLS сертификаты для всех webhook соединений
- Настройте правильные RBAC разрешения
- Валидируйте все входящие AdmissionReview запросы
- Используйте namespaceSelector для ограничения области действия

### **2. Производительность:**
- Устанавливайте разумные timeouts (5-10 секунд)
- Реализуйте эффективную логику валидации
- Используйте failurePolicy: Ignore для некритичных webhooks
- Мониторьте латентность webhook операций

### **3. Надежность:**
- Развертывайте webhooks в HA конфигурации (2+ реплики)
- Настройте health checks и readiness probes
- Реализуйте graceful shutdown
- Используйте circuit breakers для внешних зависимостей

### **4. Операционные аспекты:**
- Логируйте все webhook операции для аудита
- Мониторьте rejection rate и latency
- Настройте алерты для webhook failures
- Регулярно тестируйте webhook функциональность

**Admission Webhooks — это мощный механизм для обеспечения безопасности, соответствия стандартам и автоматизации в Kubernetes кластере!**
