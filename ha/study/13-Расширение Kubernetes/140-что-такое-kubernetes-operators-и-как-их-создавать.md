# 140. Что такое Kubernetes Operators и как их создавать?

## 🎯 **Основные концепции:**

| Аспект | Обычные Deployments | Kubernetes Operators |
|--------|---------------------|---------------------|
| **Управление** | Статическая конфигурация | Динамическое управление |
| **Логика** | Внешние скрипты | Встроенная в кластер |
| **Состояние** | Декларативное | Декларативное + операционное |
| **Автоматизация** | Ограниченная | Полная автоматизация |
| **Знания** | Общие | Специфичные для приложения |
| **Lifecycle** | Базовый | Полный жизненный цикл |
| **Восстановление** | Ручное | Автоматическое |

## 🤖 **Kubernetes Operators (Операторы)**

**Kubernetes Operator** — это метод упаковки, развертывания и управления Kubernetes приложениями, который расширяет API Kubernetes для создания, настройки и управления экземплярами сложных stateful приложений от имени пользователя Kubernetes.

### **Характеристики Operators:**
- **Встроенные знания** о приложении
- **Автоматизация операций** (backup, upgrade, scaling)
- **Custom Resources** для конфигурации
- **Controllers** для управления состоянием
- **Полный жизненный цикл** приложения

## 🏗️ **Архитектура Operator Pattern**

**Operator Pattern** состоит из Custom Resource Definitions (CRDs) и Controllers, которые следят за состоянием и выполняют операции.

### **Компоненты Operator:**
- **Custom Resource Definition (CRD)** - схема данных
- **Custom Resource (CR)** - экземпляр конфигурации
- **Controller** - логика управления
- **Reconciliation Loop** - цикл сверки состояния

## 📊 **Практические примеры из вашего HA кластера:**

### **1. ArgoCD Operator (уже установлен):**
```bash
# Проверка ArgoCD CRDs
kubectl get crd | grep argoproj

# ArgoCD Applications как Custom Resources
kubectl get applications -n argocd

# Описание ArgoCD Application CRD
kubectl describe crd applications.argoproj.io

# Пример ArgoCD Application CR
kubectl get application hashfoundry-react -n argocd -o yaml
```

### **2. Prometheus Operator (если установлен):**
```bash
# Проверка Prometheus Operator CRDs
kubectl get crd | grep monitoring.coreos.com

# Prometheus instances
kubectl get prometheus -n monitoring

# ServiceMonitor resources
kubectl get servicemonitor -n monitoring

# PrometheusRule resources
kubectl get prometheusrule -n monitoring
```

### **3. Cert-Manager Operator (если установлен):**
```bash
# Проверка Cert-Manager CRDs
kubectl get crd | grep cert-manager.io

# Certificate resources
kubectl get certificates --all-namespaces

# ClusterIssuer resources
kubectl get clusterissuer

# CertificateRequest resources
kubectl get certificaterequests --all-namespaces
```

## 🛠️ **Создание простого Operator:**

### **1. Структура проекта Operator:**
```bash
# Создать структуру проекта
mkdir -p webapp-operator/{cmd,pkg/{apis,controller},deploy}
cd webapp-operator

# Структура файлов
cat << 'EOF'
webapp-operator/
├── cmd/
│   └── manager/
│       └── main.go
├── pkg/
│   ├── apis/
│   │   └── webapp/
│   │       └── v1/
│   │           ├── types.go
│   │           └── register.go
│   └── controller/
│       └── webapp/
│           └── webapp_controller.go
├── deploy/
│   ├── crd.yaml
│   ├── operator.yaml
│   └── rbac.yaml
├── Dockerfile
└── Makefile
EOF
```

### **2. Custom Resource Definition (CRD):**
```yaml
# deploy/crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: webapps.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
                description: "Container image for the web application"
              replicas:
                type: integer
                minimum: 1
                maximum: 10
                description: "Number of replicas"
              port:
                type: integer
                minimum: 1
                maximum: 65535
                description: "Container port"
              resources:
                type: object
                properties:
                  requests:
                    type: object
                    properties:
                      cpu:
                        type: string
                      memory:
                        type: string
                  limits:
                    type: object
                    properties:
                      cpu:
                        type: string
                      memory:
                        type: string
              ingress:
                type: object
                properties:
                  enabled:
                    type: boolean
                  host:
                    type: string
                  tls:
                    type: boolean
            required:
            - image
            - replicas
            - port
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Running", "Failed"]
              replicas:
                type: integer
              readyReplicas:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
                    reason:
                      type: string
                    message:
                      type: string
  scope: Namespaced
  names:
    plural: webapps
    singular: webapp
    kind: WebApp
    shortNames:
    - wa
```

### **3. Go Types Definition:**
```go
// pkg/apis/webapp/v1/types.go
package v1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    corev1 "k8s.io/api/core/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// WebApp represents a web application deployment
type WebApp struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   WebAppSpec   `json:"spec,omitempty"`
    Status WebAppStatus `json:"status,omitempty"`
}

// WebAppSpec defines the desired state of WebApp
type WebAppSpec struct {
    // Image is the container image for the web application
    Image string `json:"image"`

    // Replicas is the number of desired replicas
    Replicas int32 `json:"replicas"`

    // Port is the container port
    Port int32 `json:"port"`

    // Resources defines resource requirements
    Resources corev1.ResourceRequirements `json:"resources,omitempty"`

    // Ingress configuration
    Ingress IngressSpec `json:"ingress,omitempty"`
}

// IngressSpec defines ingress configuration
type IngressSpec struct {
    Enabled bool   `json:"enabled"`
    Host    string `json:"host,omitempty"`
    TLS     bool   `json:"tls,omitempty"`
}

// WebAppStatus defines the observed state of WebApp
type WebAppStatus struct {
    // Phase represents the current phase of the WebApp
    Phase string `json:"phase,omitempty"`

    // Replicas is the number of actual replicas
    Replicas int32 `json:"replicas,omitempty"`

    // ReadyReplicas is the number of ready replicas
    ReadyReplicas int32 `json:"readyReplicas,omitempty"`

    // Conditions represent the latest available observations
    Conditions []WebAppCondition `json:"conditions,omitempty"`
}

// WebAppCondition describes the state of a WebApp at a certain point
type WebAppCondition struct {
    Type               string             `json:"type"`
    Status             corev1.ConditionStatus `json:"status"`
    LastTransitionTime metav1.Time        `json:"lastTransitionTime,omitempty"`
    Reason             string             `json:"reason,omitempty"`
    Message            string             `json:"message,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// WebAppList contains a list of WebApp
type WebAppList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items           []WebApp `json:"items"`
}
```

### **4. Controller Logic:**
```go
// pkg/controller/webapp/webapp_controller.go
package webapp

import (
    "context"
    "fmt"
    "reflect"

    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    networkingv1 "k8s.io/api/networking/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/util/intstr"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/log"

    webappv1 "webapp-operator/pkg/apis/webapp/v1"
)

// WebAppReconciler reconciles a WebApp object
type WebAppReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=example.com,resources=webapps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=example.com,resources=webapps/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete

// Reconcile handles WebApp reconciliation
func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)

    // Fetch the WebApp instance
    webapp := &webappv1.WebApp{}
    err := r.Get(ctx, req.NamespacedName, webapp)
    if err != nil {
        if errors.IsNotFound(err) {
            logger.Info("WebApp resource not found. Ignoring since object must be deleted")
            return ctrl.Result{}, nil
        }
        logger.Error(err, "Failed to get WebApp")
        return ctrl.Result{}, err
    }

    // Reconcile Deployment
    if err := r.reconcileDeployment(ctx, webapp); err != nil {
        logger.Error(err, "Failed to reconcile Deployment")
        return ctrl.Result{}, err
    }

    // Reconcile Service
    if err := r.reconcileService(ctx, webapp); err != nil {
        logger.Error(err, "Failed to reconcile Service")
        return ctrl.Result{}, err
    }

    // Reconcile Ingress if enabled
    if webapp.Spec.Ingress.Enabled {
        if err := r.reconcileIngress(ctx, webapp); err != nil {
            logger.Error(err, "Failed to reconcile Ingress")
            return ctrl.Result{}, err
        }
    }

    // Update status
    if err := r.updateStatus(ctx, webapp); err != nil {
        logger.Error(err, "Failed to update WebApp status")
        return ctrl.Result{}, err
    }

    return ctrl.Result{}, nil
}

// reconcileDeployment ensures the Deployment exists and is up to date
func (r *WebAppReconciler) reconcileDeployment(ctx context.Context, webapp *webappv1.WebApp) error {
    deployment := &appsv1.Deployment{}
    deploymentName := webapp.Name
    
    err := r.Get(ctx, client.ObjectKey{
        Namespace: webapp.Namespace,
        Name:      deploymentName,
    }, deployment)

    if err != nil && errors.IsNotFound(err) {
        // Create new deployment
        deployment = r.newDeployment(webapp)
        if err := ctrl.SetControllerReference(webapp, deployment, r.Scheme); err != nil {
            return err
        }
        return r.Create(ctx, deployment)
    } else if err != nil {
        return err
    }

    // Update existing deployment if needed
    expectedDeployment := r.newDeployment(webapp)
    if !reflect.DeepEqual(deployment.Spec, expectedDeployment.Spec) {
        deployment.Spec = expectedDeployment.Spec
        return r.Update(ctx, deployment)
    }

    return nil
}

// newDeployment creates a new Deployment for the WebApp
func (r *WebAppReconciler) newDeployment(webapp *webappv1.WebApp) *appsv1.Deployment {
    labels := map[string]string{
        "app":        webapp.Name,
        "managed-by": "webapp-operator",
    }

    return &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      webapp.Name,
            Namespace: webapp.Namespace,
            Labels:    labels,
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &webapp.Spec.Replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: labels,
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: labels,
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Name:  "webapp",
                            Image: webapp.Spec.Image,
                            Ports: []corev1.ContainerPort{
                                {
                                    ContainerPort: webapp.Spec.Port,
                                    Protocol:      corev1.ProtocolTCP,
                                },
                            },
                            Resources: webapp.Spec.Resources,
                            LivenessProbe: &corev1.Probe{
                                ProbeHandler: corev1.ProbeHandler{
                                    HTTPGet: &corev1.HTTPGetAction{
                                        Path: "/health",
                                        Port: intstr.FromInt(int(webapp.Spec.Port)),
                                    },
                                },
                                InitialDelaySeconds: 30,
                                PeriodSeconds:       10,
                            },
                            ReadinessProbe: &corev1.Probe{
                                ProbeHandler: corev1.ProbeHandler{
                                    HTTPGet: &corev1.HTTPGetAction{
                                        Path: "/ready",
                                        Port: intstr.FromInt(int(webapp.Spec.Port)),
                                    },
                                },
                                InitialDelaySeconds: 5,
                                PeriodSeconds:       5,
                            },
                        },
                    },
                },
            },
        },
    }
}

// reconcileService ensures the Service exists and is up to date
func (r *WebAppReconciler) reconcileService(ctx context.Context, webapp *webappv1.WebApp) error {
    service := &corev1.Service{}
    serviceName := webapp.Name
    
    err := r.Get(ctx, client.ObjectKey{
        Namespace: webapp.Namespace,
        Name:      serviceName,
    }, service)

    if err != nil && errors.IsNotFound(err) {
        // Create new service
        service = r.newService(webapp)
        if err := ctrl.SetControllerReference(webapp, service, r.Scheme); err != nil {
            return err
        }
        return r.Create(ctx, service)
    } else if err != nil {
        return err
    }

    return nil
}

// newService creates a new Service for the WebApp
func (r *WebAppReconciler) newService(webapp *webappv1.WebApp) *corev1.Service {
    labels := map[string]string{
        "app":        webapp.Name,
        "managed-by": "webapp-operator",
    }

    return &corev1.Service{
        ObjectMeta: metav1.ObjectMeta{
            Name:      webapp.Name,
            Namespace: webapp.Namespace,
            Labels:    labels,
        },
        Spec: corev1.ServiceSpec{
            Selector: labels,
            Ports: []corev1.ServicePort{
                {
                    Port:       80,
                    TargetPort: intstr.FromInt(int(webapp.Spec.Port)),
                    Protocol:   corev1.ProtocolTCP,
                },
            },
            Type: corev1.ServiceTypeClusterIP,
        },
    }
}

// reconcileIngress ensures the Ingress exists and is up to date
func (r *WebAppReconciler) reconcileIngress(ctx context.Context, webapp *webappv1.WebApp) error {
    if !webapp.Spec.Ingress.Enabled {
        return nil
    }

    ingress := &networkingv1.Ingress{}
    ingressName := webapp.Name
    
    err := r.Get(ctx, client.ObjectKey{
        Namespace: webapp.Namespace,
        Name:      ingressName,
    }, ingress)

    if err != nil && errors.IsNotFound(err) {
        // Create new ingress
        ingress = r.newIngress(webapp)
        if err := ctrl.SetControllerReference(webapp, ingress, r.Scheme); err != nil {
            return err
        }
        return r.Create(ctx, ingress)
    } else if err != nil {
        return err
    }

    return nil
}

// newIngress creates a new Ingress for the WebApp
func (r *WebAppReconciler) newIngress(webapp *webappv1.WebApp) *networkingv1.Ingress {
    labels := map[string]string{
        "app":        webapp.Name,
        "managed-by": "webapp-operator",
    }

    pathType := networkingv1.PathTypePrefix
    
    return &networkingv1.Ingress{
        ObjectMeta: metav1.ObjectMeta{
            Name:      webapp.Name,
            Namespace: webapp.Namespace,
            Labels:    labels,
            Annotations: map[string]string{
                "kubernetes.io/ingress.class": "nginx",
            },
        },
        Spec: networkingv1.IngressSpec{
            Rules: []networkingv1.IngressRule{
                {
                    Host: webapp.Spec.Ingress.Host,
                    IngressRuleValue: networkingv1.IngressRuleValue{
                        HTTP: &networkingv1.HTTPIngressRuleValue{
                            Paths: []networkingv1.HTTPIngressPath{
                                {
                                    Path:     "/",
                                    PathType: &pathType,
                                    Backend: networkingv1.IngressBackend{
                                        Service: &networkingv1.IngressServiceBackend{
                                            Name: webapp.Name,
                                            Port: networkingv1.ServiceBackendPort{
                                                Number: 80,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
}

// updateStatus updates the WebApp status
func (r *WebAppReconciler) updateStatus(ctx context.Context, webapp *webappv1.WebApp) error {
    // Get deployment to check status
    deployment := &appsv1.Deployment{}
    err := r.Get(ctx, client.ObjectKey{
        Namespace: webapp.Namespace,
        Name:      webapp.Name,
    }, deployment)
    
    if err != nil {
        return err
    }

    // Update status based on deployment status
    webapp.Status.Replicas = deployment.Status.Replicas
    webapp.Status.ReadyReplicas = deployment.Status.ReadyReplicas

    if deployment.Status.ReadyReplicas == webapp.Spec.Replicas {
        webapp.Status.Phase = "Running"
    } else if deployment.Status.Replicas > 0 {
        webapp.Status.Phase = "Pending"
    } else {
        webapp.Status.Phase = "Failed"
    }

    return r.Status().Update(ctx, webapp)
}

// SetupWithManager sets up the controller with the Manager
func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&webappv1.WebApp{}).
        Owns(&appsv1.Deployment{}).
        Owns(&corev1.Service{}).
        Owns(&networkingv1.Ingress{}).
        Complete(r)
}
```

### **5. Main Controller Manager:**
```go
// cmd/manager/main.go
package main

import (
    "flag"
    "os"

    "k8s.io/apimachinery/pkg/runtime"
    utilruntime "k8s.io/apimachinery/pkg/util/runtime"
    clientgoscheme "k8s.io/client-go/kubernetes/scheme"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/healthz"
    "sigs.k8s.io/controller-runtime/pkg/log/zap"

    webappv1 "webapp-operator/pkg/apis/webapp/v1"
    "webapp-operator/pkg/controller/webapp"
)

var (
    scheme   = runtime.NewScheme()
    setupLog = ctrl.Log.WithName("setup")
)

func init() {
    utilruntime.Must(clientgoscheme.AddToScheme(scheme))
    utilruntime.Must(webappv1.AddToScheme(scheme))
}

func main() {
    var metricsAddr string
    var enableLeaderElection bool
    var probeAddr string

    flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
    flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
    flag.BoolVar(&enableLeaderElection, "leader-elect", false,
        "Enable leader election for controller manager.")
    
    opts := zap.Options{
        Development: true,
    }
    opts.BindFlags(flag.CommandLine)
    flag.Parse()

    ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts)))

    mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
        Scheme:                 scheme,
        MetricsBindAddress:     metricsAddr,
        Port:                   9443,
        HealthProbeBindAddress: probeAddr,
        LeaderElection:         enableLeaderElection,
        LeaderElectionID:       "webapp-operator",
    })
    if err != nil {
        setupLog.Error(err, "unable to start manager")
        os.Exit(1)
    }

    if err = (&webapp.WebAppReconciler{
        Client: mgr.GetClient(),
        Scheme: mgr.GetScheme(),
    }).SetupWithManager(mgr); err != nil {
        setupLog.Error(err, "unable to create controller", "controller", "WebApp")
        os.Exit(1)
    }

    if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
        setupLog.Error(err, "unable to set up health check")
        os.Exit(1)
    }
    if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
        setupLog.Error(err, "unable to set up ready check")
        os.Exit(1)
    }

    setupLog.Info("starting manager")
    if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
        setupLog.Error(err, "problem running manager")
        os.Exit(1)
    }
}
```

### **6. Deployment манифесты:**
```yaml
# deploy/operator.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-operator
  namespace: webapp-operator-system
  labels:
    app: webapp-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp-operator
  template:
    metadata:
      labels:
        app: webapp-operator
    spec:
      serviceAccountName: webapp-operator
      containers:
      - name: manager
        image: webapp-operator:latest
        command:
        - /manager
        args:
        - --leader-elect
        ports:
        - containerPort: 8080
          name: metrics
        - containerPort: 8081
          name: health
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          limits:
            cpu: 500m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-operator
  namespace: webapp-operator-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: webapp-operator
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["example.com"]
  resources: ["webapps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["example.com"]
  resources: ["webapps/status"]
  verbs: ["get", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: webapp-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: webapp-operator
subjects:
- kind: ServiceAccount
  name: webapp-operator
  namespace: webapp-operator-system
```

## 🚀 **Развертывание и тестирование Operator:**

### **1. Развертывание Operator:**
```bash
# Создать namespace
kubectl create namespace webapp-operator-system

# Применить CRD
kubectl apply -f deploy/crd.yaml

# Применить RBAC и Operator
kubectl apply -f deploy/operator.yaml

# Проверить статус
kubectl get pods -n webapp-operator-system
kubectl logs -f deployment/webapp-operator -n webapp-operator-system
```

### **2. Создание WebApp instance:**
```yaml
# example-webapp.yaml
apiVersion: example.com/v1
kind: WebApp
metadata:
  name: my-webapp
  namespace: default
spec:
  image: nginx:alpine
  replicas: 3
  port: 80
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  ingress:
    enabled: true
    host: my-webapp.hashfoundry.local
    tls: false
```

```bash
# Применить WebApp
kubectl apply -f example-webapp.yaml

# Проверить созданные ресурсы
kubectl get webapp my-webapp
kubectl describe webapp my-webapp

# Проверить созданные Deployment, Service, Ingress
kubectl get deployment,service,ingress -l managed-by=webapp-operator

# Проверить статус
kubectl get webapp my-webapp -o jsonpath='{.status}'
```

### **3. Тестирование операций:**
```bash
# Масштабирование
kubectl patch webapp my-webapp --type='merge' -p='{"spec":{"replicas":5}}'

# Обновление образа
kubectl patch webapp my-webapp --type='merge' -p='{"spec":{"image":"nginx:1.21"}}'

# Включение/отключение Ingress
kubectl patch webapp my-webapp --type='merge' -p='{"spec":{"ingress":{"enabled":false}}}'

# Мониторинг изменений
kubectl get webapp my-webapp --watch
kubectl get deployment my-webapp --watch
```

## 📈 **Мониторинг Operator в вашем кластере:**

### **1. Prometheus метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики для Operator:
# controller_runtime_reconcile_total
# controller_runtime_reconcile_errors_total
# controller_runtime_reconcile_time_seconds
# workqueue_adds_total
# workqueue_depth
```

### **2. Grafana дашборд:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Создать дашборд для мониторинга:
# - Reconciliation rate
# - Error rate
# - Reconciliation duration
# - Queue depth
# - Custom Resource count
```

### **3. Логирование Operator:**
```bash
# Просмотр логов Operator
kubectl logs -f deployment/webapp-operator -n webapp-operator-system

# Логи с фильтрацией
kubectl logs deployment/webapp-operator -n webapp-operator-system | grep "WebApp"

# Логи конкретного pod'а
kubectl logs <operator-pod-name> -n webapp-operator-system --previous
```

## 🔧 **Operator Maturity Model:**

### **Уровни зрелости Operator:**

| Уровень | Название | Возможности |
|---------|----------|-------------|
| **1** | **Basic Install** | Автоматическая установка |
| **2** | **Seamless Upgrades** | Обновления без простоя |
| **3** | **Full Lifecycle** | Backup, failure recovery |
| **4** | **Deep Insights** | Метрики, алерты, логи |
| **5** | **Auto Pilot** | Автоматическое масштабирование, тюнинг |

### **Примеры из вашего кластера:**

```bash
# ArgoCD Operator - Level 4 (Deep Insights)
kubectl get applications -n argocd
kubectl describe application hashfoundry-react -n argocd

# Prometheus Operator - Level 5 (Auto Pilot)
kubectl get prometheus -n monitoring
kubectl get servicemonitor -n monitoring

# Cert-Manager Operator - Level 3 (Full Lifecycle)
kubectl get certificates --all-namespaces
kubectl get clusterissuer
```

## 🛠️ **Инструменты для создания Operators:**

### **1. Operator SDK:**
```bash
# Установка Operator SDK
curl -LO https://github.com/operator-framework/operator-sdk/releases/download/v1.32.0/operator-sdk_linux_amd64
chmod +x operator-sdk_linux_amd64
sudo mv operator-sdk_linux_amd64 /usr/local/bin/operator-sdk

# Создание нового Operator проекта
operator-sdk init --domain=hashfoundry.com --repo=github.com/hashfoundry/webapp-operator

# Создание API
operator-sdk create api --group=apps --version=v1 --kind=WebApp --resource --controller

# Генерация манифестов
make manifests

# Сборка и развертывание
make docker-build docker-push IMG=webapp-operator:latest
make deploy IMG=webapp-operator:latest
```

### **2. Kubebuilder:**
```bash
# Установка Kubebuilder
curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)
chmod +x kubebuilder
sudo mv kubebuilder /usr/local/bin/

# Создание проекта
kubebuilder init --domain hashfoundry.com --repo github.com/hashfoundry/webapp-operator

# Создание API
kubebuilder create api --group apps --version v1 --kind WebApp

# Генерация CRDs
make manifests

# Запуск локально
make run
```

### **3. KUDO (Kubernetes Universal Declarative Operator):**
```bash
# Установка KUDO
kubectl krew install kudo

# Создание KUDO Operator
mkdir webapp-kudo-operator
cd webapp-kudo-operator

# operator.yaml
cat << 'EOF' > operator.yaml
apiVersion: kudo.dev/v1beta1
kind: Operator
metadata:
  name: webapp
spec:
  description: "WebApp Operator using KUDO"
  maintainers:
  - name: HashFoundry Team
    email: team@hashfoundry.com
  url: https://github.com/hashfoundry/webapp-kudo-operator
  tasks:
  - name: deploy
    kind: Apply
    spec:
      resources:
      - deployment.yaml
      - service.yaml
  - name: upgrade
    kind: Apply
    spec:
      resources:
      - deployment.yaml
  plans:
    deploy:
      strategy: serial
      phases:
      - name: main
        strategy: parallel
        steps:
        - name: deploy
          tasks:
          - deploy
    upgrade:
      strategy: serial
      phases:
      - name: main
        strategy: serial
        steps:
        - name: upgrade
          tasks:
          - upgrade
EOF

# Установка KUDO Operator
kubectl kudo install ./webapp-kudo-operator
```

## 📊 **Best Practices для Operators:**

### **1. Дизайн и архитектура:**
```bash
# Принципы дизайна Operator:
# - Идемпотентность операций
# - Graceful degradation
# - Observability
# - Security by default
# - Resource efficiency

# Пример идемпотентного контроллера
cat << 'EOF'
func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // 1. Получить текущее состояние
    webapp := &webappv1.WebApp{}
    if err := r.Get(ctx, req.NamespacedName, webapp); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // 2. Определить желаемое состояние
    desiredDeployment := r.buildDeployment(webapp)
    
    // 3. Сравнить и применить изменения только при необходимости
    currentDeployment := &appsv1.Deployment{}
    err := r.Get(ctx, client.ObjectKeyFromObject(desiredDeployment), currentDeployment)
    
    if errors.IsNotFound(err) {
        // Создать новый ресурс
        return ctrl.Result{}, r.Create(ctx, desiredDeployment)
    } else if err != nil {
        return ctrl.Result{}, err
    }
    
    // Обновить только при различиях
    if !equality.Semantic.DeepEqual(currentDeployment.Spec, desiredDeployment.Spec) {
        currentDeployment.Spec = desiredDeployment.Spec
        return ctrl.Result{}, r.Update(ctx, currentDeployment)
    }
    
    return ctrl.Result{}, nil
}
EOF
```

### **2. Безопасность:**
```yaml
# Минимальные RBAC права
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: webapp-operator-minimal
rules:
# Только необходимые ресурсы
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# Только собственные CRDs
- apiGroups: ["example.com"]
  resources: ["webapps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["example.com"]
  resources: ["webapps/status"]
  verbs: ["get", "update", "patch"]

---
# Security Context для Operator Pod
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-operator
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        fsGroup: 65532
      containers:
      - name: manager
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        resources:
          limits:
            cpu: 500m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi
```

### **3. Мониторинг и наблюдаемость:**
```go
// Добавление метрик в контроллер
package webapp

import (
    "github.com/prometheus/client_golang/prometheus"
    "sigs.k8s.io/controller-runtime/pkg/metrics"
)

var (
    webappReconcileTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "webapp_reconcile_total",
            Help: "Total number of WebApp reconciliations",
        },
        []string{"namespace", "name", "result"},
    )
    
    webappReconcileDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "webapp_reconcile_duration_seconds",
            Help: "Duration of WebApp reconciliations",
        },
        []string{"namespace", "name"},
    )
)

func init() {
    metrics.Registry.MustRegister(webappReconcileTotal, webappReconcileDuration)
}

func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    start := time.Now()
    defer func() {
        webappReconcileDuration.WithLabelValues(req.Namespace, req.Name).Observe(time.Since(start).Seconds())
    }()

    // Reconciliation logic...
    
    result := "success"
    if err != nil {
        result = "error"
    }
    webappReconcileTotal.WithLabelValues(req.Namespace, req.Name, result).Inc()
    
    return ctrl.Result{}, err
}
```

### **4. Тестирование Operators:**
```go
// Пример unit теста для контроллера
package webapp

import (
    "context"
    "testing"
    "time"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/types"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"

    webappv1 "webapp-operator/pkg/apis/webapp/v1"
)

var _ = Describe("WebApp Controller", func() {
    Context("When creating a WebApp", func() {
        It("Should create a Deployment", func() {
            ctx := context.Background()
            
            webapp := &webappv1.WebApp{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-webapp",
                    Namespace: "default",
                },
                Spec: webappv1.WebAppSpec{
                    Image:    "nginx:alpine",
                    Replicas: 3,
                    Port:     80,
                },
            }
            
            Expect(k8sClient.Create(ctx, webapp)).Should(Succeed())
            
            // Wait for reconciliation
            Eventually(func() bool {
                deployment := &appsv1.Deployment{}
                err := k8sClient.Get(ctx, types.NamespacedName{
                    Name:      "test-webapp",
                    Namespace: "default",
                }, deployment)
                return err == nil
            }, time.Second*10, time.Millisecond*250).Should(BeTrue())
            
            // Verify deployment properties
            deployment := &appsv1.Deployment{}
            Expect(k8sClient.Get(ctx, types.NamespacedName{
                Name:      "test-webapp",
                Namespace: "default",
            }, deployment)).Should(Succeed())
            
            Expect(*deployment.Spec.Replicas).Should(Equal(int32(3)))
            Expect(deployment.Spec.Template.Spec.Containers[0].Image).Should(Equal("nginx:alpine"))
        })
    })
})
```

## 🏭 **Примеры популярных Operators:**

### **1. Проверка установленных Operators в кластере:**
```bash
# ArgoCD Operator
kubectl get crd | grep argoproj
kubectl get applications -n argocd

# Prometheus Operator
kubectl get crd | grep monitoring.coreos.com
kubectl get prometheus,servicemonitor,prometheusrule -n monitoring

# NGINX Ingress Operator
kubectl get crd | grep ingress
kubectl get ingressclass

# Cert-Manager Operator
kubectl get crd | grep cert-manager
kubectl get certificates,clusterissuer --all-namespaces

# Grafana Operator
kubectl get crd | grep grafana
kubectl get grafana -n monitoring 2>/dev/null || echo "Grafana Operator not installed"
```

### **2. Установка популярных Operators:**
```bash
# Prometheus Operator через Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Cert-Manager Operator
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Grafana Operator
kubectl create -f https://github.com/grafana-operator/grafana-operator/releases/latest/download/grafana-operator-v5.4.2.yaml

# Jaeger Operator
kubectl create namespace observability
kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.48.0/jaeger-operator.yaml -n observability
```

## 🎯 **Когда использовать Operators:**

### **Используйте Operators для:**
- **Stateful приложений** (базы данных, очереди)
- **Сложных lifecycle операций** (backup, restore, upgrade)
- **Автоматизации операционных задач**
- **Приложений с доменной логикой**
- **Интеграции с внешними системами**

```bash
# Примеры из вашего кластера:
kubectl get deployments -n argocd    # ArgoCD - GitOps Operator
kubectl get statefulsets -n monitoring # Prometheus - Monitoring Operator
kubectl get certificates --all-namespaces # Cert-Manager - TLS Operator
```

### **НЕ используйте Operators для:**
- **Простых stateless приложений**
- **Одноразовых задач**
- **Приложений без сложной логики**
- **Когда достаточно Helm charts**

## 🏗️ **Архитектура Operators в вашем кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│                    HashFoundry HA Cluster                  │
├─────────────────────────────────────────────────────────────┤
│  Installed Operators                                        │
│  ├── ArgoCD Operator - GitOps управление                    │
│  │   ├── Applications CRD                                   │
│  │   ├── AppProjects CRD                                    │
│  │   └── ApplicationSets CRD                                │
│  ├── Prometheus Operator - Мониторинг                       │
│  │   ├── Prometheus CRD                                     │
│  │   ├── ServiceMonitor CRD                                 │
│  │   └── PrometheusRule CRD                                 │
│  ├── NGINX Ingress Operator - Входящий трафик               │
│  │   ├── Ingress CRD                                        │
│  │   └── IngressClass CRD                                   │
│  └── Custom WebApp Operator - Приложения                    │
│      ├── WebApp CRD                                         │
│      └── WebAppController                                   │
├─────────────────────────────────────────────────────────────┤
│  Operator Pattern Benefits                                  │
│  ├── Автоматизация операций                                 │
│  ├── Встроенные знания о приложениях                        │
│  ├── Декларативное управление                               │
│  ├── Self-healing capabilities                              │
│  └── Расширение Kubernetes API                              │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Заключение:**

**Kubernetes Operators** предоставляют мощный способ автоматизации управления сложными приложениями в Kubernetes:

**Ключевые преимущества:**
1. **Автоматизация** - полный жизненный цикл приложений
2. **Знания** - встроенная экспертиза о приложении
3. **Расширяемость** - кастомные API для специфичных задач
4. **Надежность** - self-healing и автоматическое восстановление
5. **Декларативность** - управление через Custom Resources

**Практическое применение:**
- **ArgoCD** для GitOps
- **Prometheus** для мониторинга
- **Cert-Manager** для TLS сертификатов
- **Custom Operators** для бизнес-логики

Operators превращают Kubernetes в платформу для автоматизации операционных задач, делая управление сложными приложениями простым и надежным.
