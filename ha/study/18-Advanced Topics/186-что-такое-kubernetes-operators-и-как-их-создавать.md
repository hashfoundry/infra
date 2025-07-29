# 186. Что такое Kubernetes Operators и как их создавать?

## 🎯 Вопрос
Что такое Kubernetes Operators и как их создавать?

## 💡 Ответ

Kubernetes Operators - это специализированные контроллеры, которые расширяют функциональность Kubernetes API для управления сложными stateful приложениями. Operators кодируют операционные знания (установка, обновление, резервное копирование, восстановление) в виде кода, автоматизируя жизненный цикл приложений с использованием Custom Resources.

### 🏗️ Архитектура Kubernetes Operators

#### 1. **Схема Operator Pattern**
```
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Operator Pattern               │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Custom Resource Definition               │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    CRD      │    │   Schema    │    │ Validation  │ │ │
│  │  │ Definition  │───▶│ Definition  │───▶│   Rules     │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Custom Resource Instance                 │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Custom    │    │   Desired   │    │   Current   │ │ │
│  │  │  Resource   │───▶│    State    │───▶│    State    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Operator Controller                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Watch     │    │ Reconcile   │    │   Action    │ │ │
│  │  │   Events    │───▶│    Loop     │───▶│ Execution   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Kubernetes Resources                      │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Deployments │    │  Services   │    │ ConfigMaps  │ │ │
│  │  │    Pods     │    │   Secrets   │    │    PVCs     │ │ │
│  │  │    Jobs     │    │   Ingress   │    │   Others    │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Operator Maturity Model**
```yaml
# Operator Capability Levels
operator_maturity_levels:
  level_1_basic_install:
    description: "Автоматизированная установка приложения"
    capabilities:
      - "Provisioning"
      - "Installation"
      - "Configuration"
    examples:
      - "Создание Deployment"
      - "Создание Service"
      - "Создание ConfigMap"
  
  level_2_seamless_upgrades:
    description: "Автоматические обновления"
    capabilities:
      - "Patch management"
      - "Minor version upgrades"
      - "Configuration updates"
    examples:
      - "Rolling updates"
      - "Configuration drift detection"
      - "Health checks"
  
  level_3_full_lifecycle:
    description: "Полное управление жизненным циклом"
    capabilities:
      - "App lifecycle management"
      - "Storage management"
      - "Scaling operations"
    examples:
      - "Backup/Restore"
      - "Failure recovery"
      - "Performance tuning"
  
  level_4_deep_insights:
    description: "Метрики, алерты, анализ логов"
    capabilities:
      - "Metrics collection"
      - "Alerting"
      - "Log analysis"
    examples:
      - "Prometheus integration"
      - "Custom dashboards"
      - "Anomaly detection"
  
  level_5_auto_pilot:
    description: "Автоматическое масштабирование и настройка"
    capabilities:
      - "Auto-scaling"
      - "Auto-tuning"
      - "Abnormality detection"
    examples:
      - "Predictive scaling"
      - "Self-healing"
      - "Performance optimization"

# Operator Development Frameworks
operator_frameworks:
  operator_sdk:
    language: "Go, Ansible, Helm"
    description: "Red Hat Operator SDK"
    features:
      - "Code generation"
      - "Testing framework"
      - "OLM integration"
  
  kubebuilder:
    language: "Go"
    description: "Kubernetes SIG framework"
    features:
      - "Controller scaffolding"
      - "Webhook generation"
      - "CRD generation"
  
  kopf:
    language: "Python"
    description: "Kubernetes Operator Pythonic Framework"
    features:
      - "Event-driven"
      - "Async/await support"
      - "Simple decorators"
  
  shell_operator:
    language: "Shell/Any"
    description: "Flant shell-operator"
    features:
      - "Hook-based"
      - "Multi-language support"
      - "Simple deployment"
```

### 📊 Примеры из нашего кластера

#### Проверка операторов:
```bash
# Проверка установленных CRDs
kubectl get crd

# Проверка операторов в кластере
kubectl get pods --all-namespaces -l app.kubernetes.io/component=controller

# Проверка Operator Lifecycle Manager (если установлен)
kubectl get csv --all-namespaces

# Проверка custom resources
kubectl api-resources --api-group=example.com
```

### 🔧 Создание простого Operator

#### 1. **Custom Resource Definition**
```yaml
# database-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.example.com
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
              type:
                type: string
                enum: ["postgresql", "mysql", "mongodb"]
              version:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 10
              storage:
                type: object
                properties:
                  size:
                    type: string
                  storageClass:
                    type: string
              backup:
                type: object
                properties:
                  enabled:
                    type: boolean
                  schedule:
                    type: string
                  retention:
                    type: string
              monitoring:
                type: object
                properties:
                  enabled:
                    type: boolean
                  scrapeInterval:
                    type: string
            required:
            - type
            - version
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Creating", "Ready", "Updating", "Failed"]
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    reason:
                      type: string
                    message:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
              endpoints:
                type: object
                properties:
                  primary:
                    type: string
                  readonly:
                    type: string
              backupStatus:
                type: object
                properties:
                  lastBackup:
                    type: string
                    format: date-time
                  nextBackup:
                    type: string
                    format: date-time
    subresources:
      status: {}
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames:
    - db

---
# Пример Database Custom Resource
apiVersion: example.com/v1
kind: Database
metadata:
  name: my-postgres
  namespace: production
spec:
  type: postgresql
  version: "13.7"
  replicas: 3
  storage:
    size: "100Gi"
    storageClass: "fast-ssd"
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: "30d"
  monitoring:
    enabled: true
    scrapeInterval: "30s"
```

#### 2. **Database Operator Implementation**
```go
// database-operator.go
package main

import (
    "context"
    "fmt"
    "time"
    
    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/util/intstr"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller"
    "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
    "sigs.k8s.io/controller-runtime/pkg/handler"
    "sigs.k8s.io/controller-runtime/pkg/reconcile"
    "sigs.k8s.io/controller-runtime/pkg/source"
)

// Database представляет Custom Resource
type Database struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    
    Spec   DatabaseSpec   `json:"spec,omitempty"`
    Status DatabaseStatus `json:"status,omitempty"`
}

type DatabaseSpec struct {
    Type        string             `json:"type"`
    Version     string             `json:"version"`
    Replicas    int32              `json:"replicas"`
    Storage     StorageSpec        `json:"storage"`
    Backup      BackupSpec         `json:"backup,omitempty"`
    Monitoring  MonitoringSpec     `json:"monitoring,omitempty"`
}

type StorageSpec struct {
    Size         string `json:"size"`
    StorageClass string `json:"storageClass,omitempty"`
}

type BackupSpec struct {
    Enabled   bool   `json:"enabled"`
    Schedule  string `json:"schedule,omitempty"`
    Retention string `json:"retention,omitempty"`
}

type MonitoringSpec struct {
    Enabled        bool   `json:"enabled"`
    ScrapeInterval string `json:"scrapeInterval,omitempty"`
}

type DatabaseStatus struct {
    Phase         string              `json:"phase,omitempty"`
    Conditions    []DatabaseCondition `json:"conditions,omitempty"`
    Endpoints     DatabaseEndpoints   `json:"endpoints,omitempty"`
    BackupStatus  BackupStatus        `json:"backupStatus,omitempty"`
}

type DatabaseCondition struct {
    Type               string      `json:"type"`
    Status             string      `json:"status"`
    Reason             string      `json:"reason,omitempty"`
    Message            string      `json:"message,omitempty"`
    LastTransitionTime metav1.Time `json:"lastTransitionTime,omitempty"`
}

type DatabaseEndpoints struct {
    Primary  string `json:"primary,omitempty"`
    Readonly string `json:"readonly,omitempty"`
}

type BackupStatus struct {
    LastBackup *metav1.Time `json:"lastBackup,omitempty"`
    NextBackup *metav1.Time `json:"nextBackup,omitempty"`
}

// DatabaseReconciler reconciles Database objects
type DatabaseReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

// Reconcile обрабатывает события Database
func (r *DatabaseReconciler) Reconcile(ctx context.Context, req reconcile.Request) (reconcile.Result, error) {
    // Получение Database объекта
    var database Database
    if err := r.Get(ctx, req.NamespacedName, &database); err != nil {
        return reconcile.Result{}, client.IgnoreNotFound(err)
    }
    
    // Обработка удаления
    if database.DeletionTimestamp != nil {
        return r.handleDeletion(ctx, &database)
    }
    
    // Добавление finalizer
    if !controllerutil.ContainsFinalizer(&database, "database.example.com/finalizer") {
        controllerutil.AddFinalizer(&database, "database.example.com/finalizer")
        return reconcile.Result{Requeue: true}, r.Update(ctx, &database)
    }
    
    // Обновление статуса на Creating
    if database.Status.Phase == "" {
        database.Status.Phase = "Creating"
        if err := r.Status().Update(ctx, &database); err != nil {
            return reconcile.Result{}, err
        }
    }
    
    // Создание ресурсов базы данных
    if err := r.reconcileDatabase(ctx, &database); err != nil {
        r.updateCondition(&database, "Ready", "False", "ReconcileError", err.Error())
        r.Status().Update(ctx, &database)
        return reconcile.Result{RequeueAfter: time.Minute}, err
    }
    
    // Настройка мониторинга
    if database.Spec.Monitoring.Enabled {
        if err := r.reconcileMonitoring(ctx, &database); err != nil {
            return reconcile.Result{}, err
        }
    }
    
    // Настройка backup
    if database.Spec.Backup.Enabled {
        if err := r.reconcileBackup(ctx, &database); err != nil {
            return reconcile.Result{}, err
        }
    }
    
    // Обновление статуса на Ready
    database.Status.Phase = "Ready"
    r.updateCondition(&database, "Ready", "True", "ReconcileSuccess", "Database is ready")
    
    // Обновление endpoints
    database.Status.Endpoints = DatabaseEndpoints{
        Primary:  fmt.Sprintf("%s-primary.%s.svc.cluster.local:5432", database.Name, database.Namespace),
        Readonly: fmt.Sprintf("%s-readonly.%s.svc.cluster.local:5432", database.Name, database.Namespace),
    }
    
    if err := r.Status().Update(ctx, &database); err != nil {
        return reconcile.Result{}, err
    }
    
    return reconcile.Result{RequeueAfter: time.Minute * 5}, nil
}

// reconcileDatabase создает основные ресурсы базы данных
func (r *DatabaseReconciler) reconcileDatabase(ctx context.Context, database *Database) error {
    // Создание StatefulSet
    if err := r.reconcileStatefulSet(ctx, database); err != nil {
        return fmt.Errorf("failed to reconcile StatefulSet: %w", err)
    }
    
    // Создание Services
    if err := r.reconcileServices(ctx, database); err != nil {
        return fmt.Errorf("failed to reconcile Services: %w", err)
    }
    
    // Создание ConfigMap
    if err := r.reconcileConfigMap(ctx, database); err != nil {
        return fmt.Errorf("failed to reconcile ConfigMap: %w", err)
    }
    
    // Создание Secrets
    if err := r.reconcileSecrets(ctx, database); err != nil {
        return fmt.Errorf("failed to reconcile Secrets: %w", err)
    }
    
    return nil
}

// reconcileStatefulSet создает StatefulSet для базы данных
func (r *DatabaseReconciler) reconcileStatefulSet(ctx context.Context, database *Database) error {
    statefulSet := &appsv1.StatefulSet{
        ObjectMeta: metav1.ObjectMeta{
            Name:      database.Name,
            Namespace: database.Namespace,
        },
        Spec: appsv1.StatefulSetSpec{
            Replicas:    &database.Spec.Replicas,
            ServiceName: fmt.Sprintf("%s-headless", database.Name),
            Selector: &metav1.LabelSelector{
                MatchLabels: map[string]string{
                    "app":      database.Name,
                    "database": database.Spec.Type,
                },
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: map[string]string{
                        "app":      database.Name,
                        "database": database.Spec.Type,
                    },
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Name:  database.Spec.Type,
                            Image: r.getDatabaseImage(database),
                            Ports: []corev1.ContainerPort{
                                {
                                    ContainerPort: r.getDatabasePort(database),
                                    Name:          "database",
                                },
                            },
                            Env: r.getDatabaseEnv(database),
                            VolumeMounts: []corev1.VolumeMount{
                                {
                                    Name:      "data",
                                    MountPath: r.getDatabaseDataPath(database),
                                },
                                {
                                    Name:      "config",
                                    MountPath: "/etc/database",
                                },
                            },
                            Resources: r.getDatabaseResources(database),
                            LivenessProbe: &corev1.Probe{
                                ProbeHandler: corev1.ProbeHandler{
                                    TCPSocket: &corev1.TCPSocketAction{
                                        Port: intstr.FromInt(int(r.getDatabasePort(database))),
                                    },
                                },
                                InitialDelaySeconds: 30,
                                PeriodSeconds:       10,
                            },
                            ReadinessProbe: &corev1.Probe{
                                ProbeHandler: corev1.ProbeHandler{
                                    Exec: &corev1.ExecAction{
                                        Command: r.getDatabaseReadinessCommand(database),
                                    },
                                },
                                InitialDelaySeconds: 5,
                                PeriodSeconds:       5,
                            },
                        },
                    },
                    Volumes: []corev1.Volume{
                        {
                            Name: "config",
                            VolumeSource: corev1.VolumeSource{
                                ConfigMap: &corev1.ConfigMapVolumeSource{
                                    LocalObjectReference: corev1.LocalObjectReference{
                                        Name: fmt.Sprintf("%s-config", database.Name),
                                    },
                                },
                            },
                        },
                    },
                },
            },
            VolumeClaimTemplates: []corev1.PersistentVolumeClaim{
                {
                    ObjectMeta: metav1.ObjectMeta{
                        Name: "data",
                    },
                    Spec: corev1.PersistentVolumeClaimSpec{
                        AccessModes: []corev1.PersistentVolumeAccessMode{
                            corev1.ReadWriteOnce,
                        },
                        Resources: corev1.ResourceRequirements{
                            Requests: corev1.ResourceList{
                                corev1.ResourceStorage: resource.MustParse(database.Spec.Storage.Size),
                            },
                        },
                        StorageClassName: &database.Spec.Storage.StorageClass,
                    },
                },
            },
        },
    }
    
    // Установка owner reference
    if err := controllerutil.SetControllerReference(database, statefulSet, r.Scheme); err != nil {
        return err
    }
    
    // Создание или обновление StatefulSet
    return r.createOrUpdate(ctx, statefulSet)
}

// reconcileServices создает Services для базы данных
func (r *DatabaseReconciler) reconcileServices(ctx context.Context, database *Database) error {
    // Headless Service для StatefulSet
    headlessService := &corev1.Service{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-headless", database.Name),
            Namespace: database.Namespace,
        },
        Spec: corev1.ServiceSpec{
            ClusterIP: "None",
            Selector: map[string]string{
                "app": database.Name,
            },
            Ports: []corev1.ServicePort{
                {
                    Port:       r.getDatabasePort(database),
                    TargetPort: intstr.FromString("database"),
                    Name:       "database",
                },
            },
        },
    }
    
    if err := controllerutil.SetControllerReference(database, headlessService, r.Scheme); err != nil {
        return err
    }
    
    if err := r.createOrUpdate(ctx, headlessService); err != nil {
        return err
    }
    
    // Primary Service
    primaryService := &corev1.Service{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-primary", database.Name),
            Namespace: database.Namespace,
        },
        Spec: corev1.ServiceSpec{
            Selector: map[string]string{
                "app":  database.Name,
                "role": "primary",
            },
            Ports: []corev1.ServicePort{
                {
                    Port:       r.getDatabasePort(database),
                    TargetPort: intstr.FromString("database"),
                    Name:       "database",
                },
            },
        },
    }
    
    if err := controllerutil.SetControllerReference(database, primaryService, r.Scheme); err != nil {
        return err
    }
    
    if err := r.createOrUpdate(ctx, primaryService); err != nil {
        return err
    }
    
    // Readonly Service (если есть реплики)
    if database.Spec.Replicas > 1 {
        readonlyService := &corev1.Service{
            ObjectMeta: metav1.ObjectMeta{
                Name:      fmt.Sprintf("%s-readonly", database.Name),
                Namespace: database.Namespace,
            },
            Spec: corev1.ServiceSpec{
                Selector: map[string]string{
                    "app":  database.Name,
                    "role": "replica",
                },
                Ports: []corev1.ServicePort{
                    {
                        Port:       r.getDatabasePort(database),
                        TargetPort: intstr.FromString("database"),
                        Name:       "database",
                    },
                },
            },
        }
        
        if err := controllerutil.SetControllerReference(database, readonlyService, r.Scheme); err != nil {
            return err
        }
        
        if err := r.createOrUpdate(ctx, readonlyService); err != nil {
            return err
        }
    }
    
    return nil
}

// reconcileMonitoring настраивает мониторинг
func (r *DatabaseReconciler) reconcileMonitoring(ctx context.Context, database *Database) error {
    // ServiceMonitor для Prometheus
    serviceMonitor := &monitoringv1.ServiceMonitor{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-monitor", database.Name),
            Namespace: database.Namespace,
        },
        Spec: monitoringv1.ServiceMonitorSpec{
            Selector: metav1.LabelSelector{
                MatchLabels: map[string]string{
                    "app": database.Name,
                },
            },
            Endpoints: []monitoringv1.Endpoint{
                {
                    Port:     "metrics",
                    Interval: database.Spec.Monitoring.ScrapeInterval,
                    Path:     "/metrics",
                },
            },
        },
    }
    
    if err := controllerutil.SetControllerReference(database, serviceMonitor, r.Scheme); err != nil {
        return err
    }
    
    return r.createOrUpdate(ctx, serviceMonitor)
}

// reconcileBackup настраивает резервное копирование
func (r *DatabaseReconciler) reconcileBackup(ctx context.Context, database *Database) error {
    // CronJob для backup
    backupCronJob := &batchv1.CronJob{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-backup", database.Name),
            Namespace: database.Namespace,
        },
        Spec: batchv1.CronJobSpec{
            Schedule: database.Spec.Backup.Schedule,
            JobTemplate: batchv1.JobTemplateSpec{
                Spec: batchv1.JobSpec{
                    Template: corev1.PodTemplateSpec{
                        Spec: corev1.PodSpec{
                            RestartPolicy: corev1.RestartPolicyOnFailure,
                            Containers: []corev1.Container{
                                {
                                    Name:  "backup",
                                    Image: r.getBackupImage(database),
                                    Command: r.getBackupCommand(database),
                                    Env: []corev1.EnvVar{
                                        {
                                            Name:  "DATABASE_URL",
                                            Value: fmt.Sprintf("%s-primary.%s.svc.cluster.local", database.Name, database.Namespace),
                                        },
                                        {
                                            Name: "DATABASE_PASSWORD",
                                            ValueFrom: &corev1.EnvVarSource{
                                                SecretKeyRef: &corev1.SecretKeySelector{
                                                    LocalObjectReference: corev1.LocalObjectReference{
                                                        Name: fmt.Sprintf("%s-secret", database.Name),
                                                    },
                                                    Key: "password",
                                                },
                                            },
                                        },
                                    },
                                    VolumeMounts: []corev1.VolumeMount{
                                        {
                                            Name:      "backup-storage",
                                            MountPath: "/backup",
                                        },
                                    },
                                },
                            },
                            Volumes: []corev1.Volume{
                                {
                                    Name: "backup-storage",
                                    VolumeSource: corev1.VolumeSource{
                                        PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
                                            ClaimName: fmt.Sprintf("%s-backup-pvc", database.Name),
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
    
    if err := controllerutil.SetControllerReference(database, backupCronJob, r.Scheme); err != nil {
        return err
    }
    
    return r.createOrUpdate(ctx, backupCronJob)
}

// Utility methods
func (r *DatabaseReconciler) getDatabaseImage(database *Database) string {
    switch database.Spec.Type {
    case "postgresql":
        return fmt.Sprintf("postgres:%s", database.Spec.Version)
    case "mysql":
        return fmt.Sprintf("mysql:%s", database.Spec.Version)
    case "mongodb":
        return fmt.Sprintf("mongo:%s", database.Spec.Version)
    default:
        return "postgres:13"
    }
}

func (r *DatabaseReconciler) getDatabasePort(database *Database) int32 {
    switch database.Spec.Type {
    case "postgresql":
        return 5432
    case "mysql":
        return 3306
    case "mongodb":
        return 27017
    default:
        return 5432
    }
}

func (r *DatabaseReconciler) updateCondition(database *Database, condType, status, reason, message string) {
    condition := DatabaseCondition{
        Type:               condType,
        Status:             status,
        Reason:             reason,
        Message:            message,
        LastTransitionTime: metav1.Now(),
    }
    
    // Обновление или добавление condition
    for i, cond := range database.Status.Conditions {
        if cond.Type == condType {
            database.Status.Conditions[i] = condition
            return
        }
    }
    
    database.Status.Conditions = append(database.Status.Conditions, condition)
}

func (r *DatabaseReconciler) createOrUpdate(ctx context.Context, obj client.Object) error {
    if err := r.Create(ctx, obj); err != nil {
        if !errors.IsAlreadyExists(err) {
            return err
        }
        return r.Update(ctx, obj)
    }
    return nil
}

func (r *DatabaseReconciler)
