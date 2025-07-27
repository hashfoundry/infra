# 134. Какие компоненты входят в состав Kubernetes Operator

## 🎯 **Какие компоненты входят в состав Kubernetes Operator?**

**Kubernetes Operator** состоит из нескольких ключевых компонентов, которые работают вместе для автоматизации управления приложениями. Понимание этих компонентов критически важно для разработки и эксплуатации операторов.

## 🌐 **Основные компоненты Operator:**

### **1. Custom Resource Definition (CRD):**
- **API Schema** - определение структуры данных
- **Validation Rules** - правила валидации
- **Versions** - управление версиями API
- **Subresources** - дополнительные ресурсы (status, scale)

### **2. Controller:**
- **Watch Loop** - отслеживание изменений
- **Reconciliation Logic** - логика приведения к желаемому состоянию
- **Event Handling** - обработка событий
- **Error Handling** - обработка ошибок

### **3. Custom Resources (CR):**
- **Desired State** - желаемое состояние
- **Status** - текущее состояние
- **Metadata** - метаданные ресурса

### **4. Supporting Components:**
- **RBAC** - права доступа
- **Webhooks** - валидация и мутация
- **Metrics** - метрики и мониторинг
- **Logging** - логирование

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive operator components learning toolkit
cat << 'EOF' > operator-components-toolkit.sh
#!/bin/bash

echo "=== Operator Components Learning Toolkit ==="
echo "Detailed breakdown of Kubernetes Operator components in HashFoundry HA cluster"
echo

# Функция для демонстрации CRD компонентов
demonstrate_crd_components() {
    echo "=== CRD Components Demonstration ==="
    
    echo "1. Complete CRD with all components:"
    cat << COMPLETE_CRD_EOF > complete-crd-example.yaml
# Complete CRD Example with All Components
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.platform.hashfoundry.io
  labels:
    app: application-operator
    component: crd
  annotations:
    controller-gen.kubebuilder.io/version: v0.9.2
spec:
  group: platform.hashfoundry.io
  versions:
  # Version v1alpha1 - deprecated
  - name: v1alpha1
    served: true
    storage: false
    deprecated: true
    deprecationWarning: "platform.hashfoundry.io/v1alpha1 is deprecated, use v1"
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              replicas:
                type: integer
          status:
            type: object
    additionalPrinterColumns:
    - name: Image
      type: string
      jsonPath: .spec.image
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  
  # Version v1 - current storage version
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        required:
        - spec
        properties:
          # Spec section - desired state
          spec:
            type: object
            required:
            - name
            - image
            - environment
            properties:
              # Basic application properties
              name:
                type: string
                minLength: 3
                maxLength: 63
                pattern: '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
                description: "Application name (DNS-1123 compliant)"
              
              image:
                type: string
                pattern: '^[a-z0-9]+(([._]|__|[-]*)[a-z0-9]+)*(/[a-z0-9]+(([._]|__|[-]*)[a-z0-9]+)*)*:[a-zA-Z0-9_][a-zA-Z0-9._-]{0,127}$'
                description: "Container image with tag"
              
              replicas:
                type: integer
                minimum: 1
                maximum: 100
                default: 1
                description: "Number of application replicas"
              
              environment:
                type: string
                enum: ["development", "staging", "production"]
                description: "Deployment environment"
              
              # Resource management
              resources:
                type: object
                properties:
                  requests:
                    type: object
                    properties:
                      cpu:
                        type: string
                        pattern: '^[0-9]+m?$'
                        description: "CPU request (e.g., 100m, 1)"
                      memory:
                        type: string
                        pattern: '^[0-9]+[KMGT]i?$'
                        description: "Memory request (e.g., 128Mi, 1Gi)"
                  limits:
                    type: object
                    properties:
                      cpu:
                        type: string
                        pattern: '^[0-9]+m?$'
                        description: "CPU limit"
                      memory:
                        type: string
                        pattern: '^[0-9]+[KMGT]i?$'
                        description: "Memory limit"
              
              # Networking configuration
              networking:
                type: object
                properties:
                  ports:
                    type: array
                    minItems: 1
                    maxItems: 10
                    items:
                      type: object
                      required:
                      - name
                      - port
                      properties:
                        name:
                          type: string
                          pattern: '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
                        port:
                          type: integer
                          minimum: 1
                          maximum: 65535
                        protocol:
                          type: string
                          enum: ["TCP", "UDP"]
                          default: "TCP"
                  ingress:
                    type: object
                    properties:
                      enabled:
                        type: boolean
                        default: false
                      host:
                        type: string
                        format: hostname
                      path:
                        type: string
                        default: "/"
                      tls:
                        type: boolean
                        default: false
                      annotations:
                        type: object
                        additionalProperties:
                          type: string
              
              # Storage configuration
              storage:
                type: object
                properties:
                  volumes:
                    type: array
                    items:
                      type: object
                      required:
                      - name
                      - size
                      properties:
                        name:
                          type: string
                          pattern: '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
                        size:
                          type: string
                          pattern: '^[0-9]+[KMGT]i$'
                        storageClass:
                          type: string
                        accessMode:
                          type: string
                          enum: ["ReadWriteOnce", "ReadOnlyMany", "ReadWriteMany"]
                          default: "ReadWriteOnce"
                        mountPath:
                          type: string
              
              # Configuration management
              configuration:
                type: object
                properties:
                  configMaps:
                    type: array
                    items:
                      type: object
                      required:
                      - name
                      properties:
                        name:
                          type: string
                        data:
                          type: object
                          additionalProperties:
                            type: string
                        mountPath:
                          type: string
                  secrets:
                    type: array
                    items:
                      type: object
                      required:
                      - name
                      properties:
                        name:
                          type: string
                        data:
                          type: object
                          additionalProperties:
                            type: string
                        mountPath:
                          type: string
                  env:
                    type: array
                    items:
                      type: object
                      required:
                      - name
                      - value
                      properties:
                        name:
                          type: string
                        value:
                          type: string
              
              # Scaling configuration
              scaling:
                type: object
                properties:
                  horizontal:
                    type: object
                    properties:
                      enabled:
                        type: boolean
                        default: false
                      minReplicas:
                        type: integer
                        minimum: 1
                        default: 1
                      maxReplicas:
                        type: integer
                        minimum: 1
                        default: 10
                      targetCPUUtilization:
                        type: integer
                        minimum: 1
                        maximum: 100
                        default: 80
                      targetMemoryUtilization:
                        type: integer
                        minimum: 1
                        maximum: 100
                  vertical:
                    type: object
                    properties:
                      enabled:
                        type: boolean
                        default: false
                      updateMode:
                        type: string
                        enum: ["Off", "Initial", "Recreation", "Auto"]
                        default: "Auto"
              
              # Health checks
              health:
                type: object
                properties:
                  livenessProbe:
                    type: object
                    properties:
                      enabled:
                        type: boolean
                        default: true
                      path:
                        type: string
                        default: "/health"
                      port:
                        type: integer
                      initialDelaySeconds:
                        type: integer
                        default: 30
                      periodSeconds:
                        type: integer
                        default: 10
                  readinessProbe:
                    type: object
                    properties:
                      enabled:
                        type: boolean
                        default: true
                      path:
                        type: string
                        default: "/ready"
                      port:
                        type: integer
                      initialDelaySeconds:
                        type: integer
                        default: 5
                      periodSeconds:
                        type: integer
                        default: 5
              
              # Security configuration
              security:
                type: object
                properties:
                  runAsNonRoot:
                    type: boolean
                    default: true
                  runAsUser:
                    type: integer
                    minimum: 1
                  fsGroup:
                    type: integer
                    minimum: 1
                  seccompProfile:
                    type: object
                    properties:
                      type:
                        type: string
                        enum: ["RuntimeDefault", "Localhost", "Unconfined"]
                        default: "RuntimeDefault"
                  capabilities:
                    type: object
                    properties:
                      add:
                        type: array
                        items:
                          type: string
                      drop:
                        type: array
                        items:
                          type: string
                        default: ["ALL"]
          
          # Status section - current state
          status:
            type: object
            properties:
              # Overall status
              phase:
                type: string
                enum: ["Pending", "Creating", "Running", "Updating", "Scaling", "Failed", "Deleting"]
                description: "Current phase of the application"
              
              message:
                type: string
                description: "Human-readable message about the current status"
              
              reason:
                type: string
                description: "Machine-readable reason for the current status"
              
              # Replica status
              replicas:
                type: integer
                description: "Total number of replicas"
              
              readyReplicas:
                type: integer
                description: "Number of ready replicas"
              
              availableReplicas:
                type: integer
                description: "Number of available replicas"
              
              updatedReplicas:
                type: integer
                description: "Number of updated replicas"
              
              # Network status
              endpoints:
                type: array
                items:
                  type: object
                  properties:
                    name:
                      type: string
                    url:
                      type: string
                    type:
                      type: string
                      enum: ["internal", "external", "ingress"]
              
              # Resource status
              resourceUsage:
                type: object
                properties:
                  cpu:
                    type: string
                  memory:
                    type: string
                  storage:
                    type: string
              
              # Conditions
              conditions:
                type: array
                items:
                  type: object
                  required:
                  - type
                  - status
                  properties:
                    type:
                      type: string
                      description: "Type of condition"
                    status:
                      type: string
                      enum: ["True", "False", "Unknown"]
                      description: "Status of the condition"
                    reason:
                      type: string
                      description: "Machine-readable reason"
                    message:
                      type: string
                      description: "Human-readable message"
                    lastTransitionTime:
                      type: string
                      format: date-time
                      description: "Last time the condition transitioned"
                    lastUpdateTime:
                      type: string
                      format: date-time
                      description: "Last time the condition was updated"
              
              # Observed generation
              observedGeneration:
                type: integer
                description: "Most recent generation observed by the controller"
              
              # Last update time
              lastUpdateTime:
                type: string
                format: date-time
                description: "Last time the status was updated"
    
    # Subresources configuration
    subresources:
      # Status subresource
      status: {}
      
      # Scale subresource
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
        labelSelectorPath: .status.labelSelector
    
    # Additional printer columns for kubectl output
    additionalPrinterColumns:
    - name: Image
      type: string
      description: "Container image"
      jsonPath: .spec.image
    - name: Replicas
      type: integer
      description: "Desired replicas"
      jsonPath: .spec.replicas
    - name: Ready
      type: integer
      description: "Ready replicas"
      jsonPath: .status.readyReplicas
    - name: Phase
      type: string
      description: "Current phase"
      jsonPath: .status.phase
    - name: Environment
      type: string
      description: "Deployment environment"
      jsonPath: .spec.environment
    - name: Age
      type: date
      description: "Creation time"
      jsonPath: .metadata.creationTimestamp
  
  # Resource scope
  scope: Namespaced
  
  # Resource names
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames:
    - app
    - apps
    categories:
    - platform
    - hashfoundry
  
  # Conversion strategy (for multi-version support)
  conversion:
    strategy: None

COMPLETE_CRD_EOF
    
    echo "✅ Complete CRD example created: complete-crd-example.yaml"
    echo
}

# Функция для демонстрации Controller компонентов
demonstrate_controller_components() {
    echo "=== Controller Components Demonstration ==="
    
    echo "1. Controller structure and components:"
    cat << CONTROLLER_STRUCTURE_EOF > controller-structure.go
// Controller Structure and Components Example
package main

import (
    "context"
    "fmt"
    "time"
    
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/client-go/tools/record"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller"
    "sigs.k8s.io/controller-runtime/pkg/handler"
    "sigs.k8s.io/controller-runtime/pkg/reconcile"
    "sigs.k8s.io/controller-runtime/pkg/source"
    "sigs.k8s.io/controller-runtime/pkg/log"
)

// ApplicationReconciler is the main controller struct
type ApplicationReconciler struct {
    // Client for interacting with Kubernetes API
    client.Client
    
    // Scheme for runtime object conversion
    Scheme *runtime.Scheme
    
    // Event recorder for creating events
    Recorder record.EventRecorder
    
    // Custom configuration
    Config ApplicationControllerConfig
}

// ApplicationControllerConfig holds controller configuration
type ApplicationControllerConfig struct {
    // Reconciliation interval
    ReconcileInterval time.Duration
    
    // Maximum concurrent reconciles
    MaxConcurrentReconciles int
    
    // Enable metrics
    EnableMetrics bool
    
    // Default resource limits
    DefaultResources ResourceLimits
}

// ResourceLimits defines default resource constraints
type ResourceLimits struct {
    CPU    string
    Memory string
}

// Application represents our custom resource
type Application struct {
    metav1.TypeMeta   \`json:",inline"\`
    metav1.ObjectMeta \`json:"metadata,omitempty"\`
    
    Spec   ApplicationSpec   \`json:"spec,omitempty"\`
    Status ApplicationStatus \`json:"status,omitempty"\`
}

// ApplicationSpec defines the desired state
type ApplicationSpec struct {
    Name        string                 \`json:"name"\`
    Image       string                 \`json:"image"\`
    Replicas    int32                  \`json:"replicas,omitempty"\`
    Environment string                 \`json:"environment"\`
    Resources   *ResourceRequirements  \`json:"resources,omitempty"\`
    Networking  *NetworkingConfig      \`json:"networking,omitempty"\`
    Storage     *StorageConfig         \`json:"storage,omitempty"\`
    Scaling     *ScalingConfig         \`json:"scaling,omitempty"\`
    Health      *HealthConfig          \`json:"health,omitempty"\`
    Security    *SecurityConfig        \`json:"security,omitempty"\`
}

// ApplicationStatus defines the observed state
type ApplicationStatus struct {
    Phase              string             \`json:"phase,omitempty"\`
    Message            string             \`json:"message,omitempty"\`
    Reason             string             \`json:"reason,omitempty"\`
    Replicas           int32              \`json:"replicas,omitempty"\`
    ReadyReplicas      int32              \`json:"readyReplicas,omitempty"\`
    AvailableReplicas  int32              \`json:"availableReplicas,omitempty"\`
    UpdatedReplicas    int32              \`json:"updatedReplicas,omitempty"\`
    Endpoints          []EndpointStatus   \`json:"endpoints,omitempty"\`
    ResourceUsage      *ResourceUsage     \`json:"resourceUsage,omitempty"\`
    Conditions         []Condition        \`json:"conditions,omitempty"\`
    ObservedGeneration int64              \`json:"observedGeneration,omitempty"\`
    LastUpdateTime     *metav1.Time       \`json:"lastUpdateTime,omitempty"\`
}

// Reconcile is the main reconciliation function
func (r *ApplicationReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)
    
    // 1. Fetch the Application instance
    app := &Application{}
    if err := r.Get(ctx, req.NamespacedName, app); err != nil {
        if client.IgnoreNotFound(err) == nil {
            // Application was deleted
            logger.Info("Application deleted", "name", req.Name, "namespace", req.Namespace)
            return ctrl.Result{}, nil
        }
        logger.Error(err, "Failed to get Application")
        return ctrl.Result{}, err
    }
    
    // 2. Initialize status if needed
    if app.Status.Phase == "" {
        app.Status.Phase = "Pending"
        app.Status.ObservedGeneration = app.Generation
        if err := r.updateStatus(ctx, app); err != nil {
            return ctrl.Result{}, err
        }
    }
    
    // 3. Reconcile components
    if err := r.reconcileComponents(ctx, app); err != nil {
        logger.Error(err, "Failed to reconcile components")
        r.updateStatusWithError(ctx, app, "Failed", err.Error())
        return ctrl.Result{RequeueAfter: time.Minute}, err
    }
    
    // 4. Update status
    if err := r.updateApplicationStatus(ctx, app); err != nil {
        return ctrl.Result{}, err
    }
    
    // 5. Schedule next reconciliation
    return ctrl.Result{RequeueAfter: r.Config.ReconcileInterval}, nil
}

// reconcileComponents handles the reconciliation of all application components
func (r *ApplicationReconciler) reconcileComponents(ctx context.Context, app *Application) error {
    logger := log.FromContext(ctx)
    
    // Update status to Creating/Updating
    if app.Status.Phase == "Pending" {
        app.Status.Phase = "Creating"
    } else {
        app.Status.Phase = "Updating"
    }
    
    // 1. Reconcile Deployment
    if err := r.reconcileDeployment(ctx, app); err != nil {
        logger.Error(err, "Failed to reconcile Deployment")
        return err
    }
    
    // 2. Reconcile Service
    if err := r.reconcileService(ctx, app); err != nil {
        logger.Error(err, "Failed to reconcile Service")
        return err
    }
    
    // 3. Reconcile ConfigMaps
    if err := r.reconcileConfigMaps(ctx, app); err != nil {
        logger.Error(err, "Failed to reconcile ConfigMaps")
        return err
    }
    
    // 4. Reconcile Secrets
    if err := r.reconcileSecrets(ctx, app); err != nil {
        logger.Error(err, "Failed to reconcile Secrets")
        return err
    }
    
    // 5. Reconcile PersistentVolumeClaims
    if err := r.reconcilePVCs(ctx, app); err != nil {
        logger.Error(err, "Failed to reconcile PVCs")
        return err
    }
    
    // 6. Reconcile Ingress (if enabled)
    if app.Spec.Networking != nil && app.Spec.Networking.Ingress != nil && app.Spec.Networking.Ingress.Enabled {
        if err := r.reconcileIngress(ctx, app); err != nil {
            logger.Error(err, "Failed to reconcile Ingress")
            return err
        }
    }
    
    // 7. Reconcile HorizontalPodAutoscaler (if enabled)
    if app.Spec.Scaling != nil && app.Spec.Scaling.Horizontal != nil && app.Spec.Scaling.Horizontal.Enabled {
        if err := r.reconcileHPA(ctx, app); err != nil {
            logger.Error(err, "Failed to reconcile HPA")
            return err
        }
    }
    
    // 8. Reconcile VerticalPodAutoscaler (if enabled)
    if app.Spec.Scaling != nil && app.Spec.Scaling.Vertical != nil && app.Spec.Scaling.Vertical.Enabled {
        if err := r.reconcileVPA(ctx, app); err != nil {
            logger.Error(err, "Failed to reconcile VPA")
            return err
        }
    }
    
    return nil
}

// reconcileDeployment ensures the Deployment exists and matches the spec
func (r *ApplicationReconciler) reconcileDeployment(ctx context.Context, app *Application) error {
    // Implementation would create/update Deployment based on Application spec
    // This includes:
    // - Container image and configuration
    // - Resource requests and limits
    // - Environment variables
    // - Volume mounts
    // - Security context
    // - Health checks
    return nil
}

// reconcileService ensures the Service exists and matches the spec
func (r *ApplicationReconciler) reconcileService(ctx context.Context, app *Application) error {
    // Implementation would create/update Service based on Application spec
    return nil
}

// reconcileConfigMaps ensures ConfigMaps exist and match the spec
func (r *ApplicationReconciler) reconcileConfigMaps(ctx context.Context, app *Application) error {
    // Implementation would create/update ConfigMaps
    return nil
}

// reconcileSecrets ensures Secrets exist and match the spec
func (r *ApplicationReconciler) reconcileSecrets(ctx context.Context, app *Application) error {
    // Implementation would create/update Secrets
    return nil
}

// reconcilePVCs ensures PersistentVolumeClaims exist and match the spec
func (r *ApplicationReconciler) reconcilePVCs(ctx context.Context, app *Application) error {
    // Implementation would create/update PVCs
    return nil
}

// reconcileIngress ensures Ingress exists and matches the spec
func (r *ApplicationReconciler) reconcileIngress(ctx context.Context, app *Application) error {
    // Implementation would create/update Ingress
    return nil
}

// reconcileHPA ensures HorizontalPodAutoscaler exists and matches the spec
func (r *ApplicationReconciler) reconcileHPA(ctx context.Context, app *Application) error {
    // Implementation would create/update HPA
    return nil
}

// reconcileVPA ensures VerticalPodAutoscaler exists and matches the spec
func (r *ApplicationReconciler) reconcileVPA(ctx context.Context, app *Application) error {
    // Implementation would create/update VPA
    return nil
}

// updateApplicationStatus updates the Application status based on current state
func (r *ApplicationReconciler) updateApplicationStatus(ctx context.Context, app *Application) error {
    // Implementation would:
    // 1. Check Deployment status
    // 2. Update replica counts
    // 3. Check endpoint availability
    // 4. Update resource usage
    // 5. Update conditions
    // 6. Set overall phase
    
    app.Status.Phase = "Running"
    app.Status.ObservedGeneration = app.Generation
    now := metav1.Now()
    app.Status.LastUpdateTime = &now
    
    return r.updateStatus(ctx, app)
}

// updateStatus updates the Application status
func (r *ApplicationReconciler) updateStatus(ctx context.Context, app *Application) error {
    return r.Status().Update(ctx, app)
}

// updateStatusWithError updates status with error information
func (r *ApplicationReconciler) updateStatusWithError(ctx context.Context, app *Application, phase, message string) {
    app.Status.Phase = phase
    app.Status.Message = message
    app.Status.ObservedGeneration = app.Generation
    now := metav1.Now()
    app.Status.LastUpdateTime = &now
    
    // Add condition
    condition := Condition{
        Type:               "Ready",
        Status:             "False",
        Reason:             "ReconciliationFailed",
        Message:            message,
        LastTransitionTime: now,
        LastUpdateTime:     now,
    }
    
    app.Status.Conditions = updateCondition(app.Status.Conditions, condition)
    
    r.updateStatus(ctx, app)
}

// SetupWithManager sets up the controller with the Manager
func (r *ApplicationReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&Application{}).
        Owns(&appsv1.Deployment{}).
        Owns(&corev1.Service{}).
        Owns(&corev1.ConfigMap{}).
        Owns(&corev1.Secret{}).
        Owns(&corev1.PersistentVolumeClaim{}).
        Owns(&networkingv1.Ingress{}).
        Owns(&autoscalingv2.HorizontalPodAutoscaler{}).
        WithOptions(controller.Options{
            MaxConcurrentReconciles: r.Config.MaxConcurrentReconciles,
        }).
        Complete(r)
}

// Helper function to update conditions
func updateCondition(conditions []Condition, newCondition Condition) []Condition {
    for i, condition := range conditions {
        if condition.Type == newCondition.Type {
            if condition.Status != newCondition.Status {
                newCondition.LastTransitionTime = newCondition.LastUpdateTime
            } else {
                newCondition.LastTransitionTime = condition.LastTransitionTime
            }
            conditions[i] = newCondition
            return conditions
        }
    }
    return append(conditions, newCondition)
}

CONTROLLER_STRUCTURE_EOF
    
    echo "✅ Controller structure example created: controller-structure.go"
    echo
}

# Функция для демонстрации RBAC компонентов
demonstrate_rbac_components() {
    echo "=== RBAC Components Demonstration ==="
    
    echo "1. Complete RBAC configuration for operator:"
    cat << RBAC_CONFIG_EOF > operator-rbac.yaml
# Service Account for the Operator
apiVersion: v1
kind: ServiceAccount
metadata:
  name: application-operator
  namespace: platform-system
  labels:
    app: application-operator
    component: serviceaccount

---
# ClusterRole for the Operator
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: application-operator-manager
  labels:
    app: application-operator
    component: clusterrole
rules:
# Custom Resource permissions
- apiGroups:
  - platform.hashfoundry.io
  resources:
  - applications
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch

# Custom Resource status permissions
- apiGroups:
  - platform.hashfoundry.io
  resources:
  - applications/status
  verbs:
  - get
  - patch
  - update

# Custom Resource finalizers permissions
- apiGroups:
  - platform.hashfoundry.io
  resources:
  - applications/finalizers
  verbs:
  - update

# Core resource permissions
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - configmaps
  - secrets
  - persistentvolumeclaims
  - events
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch

# Apps resource permissions
- apiGroups:
  - apps
  resources:
  - deployments
  - replicasets
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch

# Networking resource permissions
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch

# Autoscaling resource permissions
- apiGroups:
  - autoscaling
  resources:
  - horizontalpodautoscalers
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch

# VPA resource permissions (if using VPA)
