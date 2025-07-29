# 183. Что такое finalizers и как они работают?

## 🎯 Вопрос
Что такое finalizers и как они работают?

## 💡 Ответ

Finalizers в Kubernetes - это механизм, который позволяет контроллерам выполнять cleanup операции перед удалением объекта. Они представляют собой список строк в metadata объекта, которые предотвращают физическое удаление объекта до тех пор, пока все finalizers не будут удалены. Это обеспечивает graceful cleanup ресурсов и зависимостей.

### 🏗️ Архитектура Finalizers

#### 1. **Схема работы Finalizers**
```
┌─────────────────────────────────────────────────────────────┐
│                    Finalizers Workflow                     │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Object Deletion Request                  │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   kubectl   │    │     API     │    │   Object    │ │ │
│  │  │   delete    │───▶│   Server    │───▶│   Update    │ │ │
│  │  │   object    │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              DeletionTimestamp Set                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Object    │    │ Finalizers  │    │   Object    │ │ │
│  │  │  Marked     │───▶│   Present   │───▶│  Remains    │ │ │
│  │  │for Deletion │    │             │    │   Active    │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Controllers Processing                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Controller  │    │   Cleanup   │    │  Finalizer  │ │ │
│  │  │  Detects    │───▶│ Operations  │───▶│   Removal   │ │ │
│  │  │ Deletion    │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Object Physical Deletion                  │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    All      │    │   Object    │    │   Object    │ │ │
│  │  │ Finalizers  │───▶│  Physical   │───▶│  Removed    │ │ │
│  │  │  Removed    │    │  Deletion   │    │from etcd    │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Типы Finalizers**
```yaml
# Стандартные finalizers в Kubernetes
standard_finalizers:
  kubernetes_finalizers:
    - "kubernetes.io/pv-protection"      # PersistentVolume protection
    - "kubernetes.io/pvc-protection"     # PersistentVolumeClaim protection
    - "kubernetes.io/service-account-token-cleanup"  # ServiceAccount cleanup
    
  controller_finalizers:
    - "foregroundDeletion"               # Foreground cascading deletion
    - "orphan"                          # Orphan dependents
    
  custom_finalizers:
    - "example.com/cleanup-resources"    # Custom resource cleanup
    - "backup.example.com/backup-data"   # Data backup before deletion
    - "monitoring.example.com/cleanup"   # Monitoring cleanup

# Примеры объектов с finalizers
object_examples:
  persistent_volume:
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: example-pv
      finalizers:
      - "kubernetes.io/pv-protection"
    
  custom_resource:
    apiVersion: example.com/v1
    kind: MyResource
    metadata:
      name: example-resource
      finalizers:
      - "example.com/cleanup-resources"
      - "backup.example.com/backup-data"
    
  namespace:
    apiVersion: v1
    kind: Namespace
    metadata:
      name: example-namespace
      finalizers:
      - "kubernetes"
```

### 📊 Примеры из нашего кластера

#### Проверка finalizers:
```bash
# Проверка объектов с finalizers
kubectl get all --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.finalizers}{"\n"}{end}'

# Проверка PV с finalizers
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.finalizers}{"\n"}{end}'

# Проверка namespace с finalizers
kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.finalizers}{"\n"}{end}'

# Проверка объектов в состоянии Terminating
kubectl get pods --all-namespaces --field-selector status.phase=Terminating
```

### 🔧 Реализация Custom Finalizers

#### 1. **Custom Controller с Finalizers**
```go
// finalizer-controller.go
package main

import (
    "context"
    "fmt"
    "time"
    
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/client-go/kubernetes"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller"
    "sigs.k8s.io/controller-runtime/pkg/handler"
    "sigs.k8s.io/controller-runtime/pkg/reconcile"
    "sigs.k8s.io/controller-runtime/pkg/source"
)

const (
    // Custom finalizer для нашего контроллера
    MyResourceFinalizer = "example.com/my-resource-finalizer"
    BackupFinalizer     = "backup.example.com/backup-finalizer"
    CleanupFinalizer    = "cleanup.example.com/cleanup-finalizer"
)

// MyResourceReconciler reconciles MyResource objects
type MyResourceReconciler struct {
    client.Client
    Scheme     *runtime.Scheme
    KubeClient kubernetes.Interface
}

// Reconcile обрабатывает события MyResource
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req reconcile.Request) (reconcile.Result, error) {
    // Получение объекта
    var myResource MyResource
    if err := r.Get(ctx, req.NamespacedName, &myResource); err != nil {
        return reconcile.Result{}, client.IgnoreNotFound(err)
    }
    
    // Проверка, помечен ли объект для удаления
    if myResource.DeletionTimestamp != nil {
        return r.handleDeletion(ctx, &myResource)
    }
    
    // Обычная обработка объекта
    return r.handleNormalOperation(ctx, &myResource)
}

// handleNormalOperation обрабатывает обычные операции
func (r *MyResourceReconciler) handleNormalOperation(ctx context.Context, myResource *MyResource) (reconcile.Result, error) {
    // Добавление finalizers если их нет
    if !containsFinalizer(myResource.Finalizers, MyResourceFinalizer) {
        myResource.Finalizers = append(myResource.Finalizers, MyResourceFinalizer)
        if err := r.Update(ctx, myResource); err != nil {
            return reconcile.Result{}, err
        }
        return reconcile.Result{Requeue: true}, nil
    }
    
    // Создание или обновление ресурсов
    if err := r.createOrUpdateResources(ctx, myResource); err != nil {
        return reconcile.Result{}, err
    }
    
    // Обновление статуса
    myResource.Status.Phase = "Ready"
    myResource.Status.LastUpdated = metav1.Now()
    if err := r.Status().Update(ctx, myResource); err != nil {
        return reconcile.Result{}, err
    }
    
    return reconcile.Result{RequeueAfter: time.Minute * 5}, nil
}

// handleDeletion обрабатывает удаление объекта
func (r *MyResourceReconciler) handleDeletion(ctx context.Context, myResource *MyResource) (reconcile.Result, error) {
    // Выполнение cleanup операций для каждого finalizer
    
    // Backup finalizer
    if containsFinalizer(myResource.Finalizers, BackupFinalizer) {
        if err := r.performBackup(ctx, myResource); err != nil {
            return reconcile.Result{}, err
        }
        
        // Удаление backup finalizer
        myResource.Finalizers = removeFinalizer(myResource.Finalizers, BackupFinalizer)
        if err := r.Update(ctx, myResource); err != nil {
            return reconcile.Result{}, err
        }
        return reconcile.Result{Requeue: true}, nil
    }
    
    // Cleanup finalizer
    if containsFinalizer(myResource.Finalizers, CleanupFinalizer) {
        if err := r.performCleanup(ctx, myResource); err != nil {
            return reconcile.Result{}, err
        }
        
        // Удаление cleanup finalizer
        myResource.Finalizers = removeFinalizer(myResource.Finalizers, CleanupFinalizer)
        if err := r.Update(ctx, myResource); err != nil {
            return reconcile.Result{}, err
        }
        return reconcile.Result{Requeue: true}, nil
    }
    
    // Main finalizer
    if containsFinalizer(myResource.Finalizers, MyResourceFinalizer) {
        if err := r.performMainCleanup(ctx, myResource); err != nil {
            return reconcile.Result{}, err
        }
        
        // Удаление main finalizer
        myResource.Finalizers = removeFinalizer(myResource.Finalizers, MyResourceFinalizer)
        if err := r.Update(ctx, myResource); err != nil {
            return reconcile.Result{}, err
        }
    }
    
    return reconcile.Result{}, nil
}

// performBackup выполняет backup данных
func (r *MyResourceReconciler) performBackup(ctx context.Context, myResource *MyResource) error {
    fmt.Printf("Performing backup for resource %s/%s\n", myResource.Namespace, myResource.Name)
    
    // Создание backup job
    backupJob := &batchv1.Job{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("backup-%s", myResource.Name),
            Namespace: myResource.Namespace,
        },
        Spec: batchv1.JobSpec{
            Template: corev1.PodTemplateSpec{
                Spec: corev1.PodSpec{
                    RestartPolicy: corev1.RestartPolicyNever,
                    Containers: []corev1.Container{
                        {
                            Name:  "backup",
                            Image: "backup-tool:latest",
                            Command: []string{
                                "/bin/sh",
                                "-c",
                                fmt.Sprintf("backup-data --resource=%s --namespace=%s", 
                                    myResource.Name, myResource.Namespace),
                            },
                            Env: []corev1.EnvVar{
                                {
                                    Name:  "BACKUP_DESTINATION",
                                    Value: myResource.Spec.BackupDestination,
                                },
                            },
                        },
                    },
                },
            },
        },
    }
    
    if err := r.Create(ctx, backupJob); err != nil {
        return fmt.Errorf("failed to create backup job: %w", err)
    }
    
    // Ожидание завершения backup job
    return r.waitForJobCompletion(ctx, backupJob)
}

// performCleanup выполняет cleanup внешних ресурсов
func (r *MyResourceReconciler) performCleanup(ctx context.Context, myResource *MyResource) error {
    fmt.Printf("Performing cleanup for resource %s/%s\n", myResource.Namespace, myResource.Name)
    
    // Cleanup external resources
    if err := r.cleanupExternalResources(ctx, myResource); err != nil {
        return fmt.Errorf("failed to cleanup external resources: %w", err)
    }
    
    // Cleanup monitoring
    if err := r.cleanupMonitoring(ctx, myResource); err != nil {
        return fmt.Errorf("failed to cleanup monitoring: %w", err)
    }
    
    // Cleanup network policies
    if err := r.cleanupNetworkPolicies(ctx, myResource); err != nil {
        return fmt.Errorf("failed to cleanup network policies: %w", err)
    }
    
    return nil
}

// performMainCleanup выполняет основной cleanup
func (r *MyResourceReconciler) performMainCleanup(ctx context.Context, myResource *MyResource) error {
    fmt.Printf("Performing main cleanup for resource %s/%s\n", myResource.Namespace, myResource.Name)
    
    // Удаление связанных Kubernetes ресурсов
    if err := r.deleteRelatedResources(ctx, myResource); err != nil {
        return fmt.Errorf("failed to delete related resources: %w", err)
    }
    
    // Cleanup storage
    if err := r.cleanupStorage(ctx, myResource); err != nil {
        return fmt.Errorf("failed to cleanup storage: %w", err)
    }
    
    return nil
}

// cleanupExternalResources очищает внешние ресурсы
func (r *MyResourceReconciler) cleanupExternalResources(ctx context.Context, myResource *MyResource) error {
    // Cleanup cloud resources
    if myResource.Spec.CloudProvider == "aws" {
        return r.cleanupAWSResources(ctx, myResource)
    } else if myResource.Spec.CloudProvider == "gcp" {
        return r.cleanupGCPResources(ctx, myResource)
    }
    
    return nil
}

// cleanupAWSResources очищает AWS ресурсы
func (r *MyResourceReconciler) cleanupAWSResources(ctx context.Context, myResource *MyResource) error {
    // Удаление S3 buckets
    if myResource.Spec.S3Bucket != "" {
        fmt.Printf("Deleting S3 bucket: %s\n", myResource.Spec.S3Bucket)
        // AWS SDK calls here
    }
    
    // Удаление RDS instances
    if myResource.Spec.RDSInstance != "" {
        fmt.Printf("Deleting RDS instance: %s\n", myResource.Spec.RDSInstance)
        // AWS SDK calls here
    }
    
    return nil
}

// deleteRelatedResources удаляет связанные Kubernetes ресурсы
func (r *MyResourceReconciler) deleteRelatedResources(ctx context.Context, myResource *MyResource) error {
    // Удаление Deployments
    deployments := &appsv1.DeploymentList{}
    if err := r.List(ctx, deployments, client.InNamespace(myResource.Namespace), 
        client.MatchingLabels{"app": myResource.Name}); err != nil {
        return err
    }
    
    for _, deployment := range deployments.Items {
        if err := r.Delete(ctx, &deployment); err != nil {
            return err
        }
    }
    
    // Удаление Services
    services := &corev1.ServiceList{}
    if err := r.List(ctx, services, client.InNamespace(myResource.Namespace),
        client.MatchingLabels{"app": myResource.Name}); err != nil {
        return err
    }
    
    for _, service := range services.Items {
        if err := r.Delete(ctx, &service); err != nil {
            return err
        }
    }
    
    return nil
}

// Utility functions
func containsFinalizer(finalizers []string, finalizer string) bool {
    for _, f := range finalizers {
        if f == finalizer {
            return true
        }
    }
    return false
}

func removeFinalizer(finalizers []string, finalizer string) []string {
    var result []string
    for _, f := range finalizers {
        if f != finalizer {
            result = append(result, f)
        }
    }
    return result
}

func (r *MyResourceReconciler) waitForJobCompletion(ctx context.Context, job *batchv1.Job) error {
    // Ожидание завершения job с timeout
    timeout := time.Minute * 10
    interval := time.Second * 10
    
    for start := time.Now(); time.Since(start) < timeout; {
        var currentJob batchv1.Job
        if err := r.Get(ctx, client.ObjectKeyFromObject(job), &currentJob); err != nil {
            return err
        }
        
        if currentJob.Status.Succeeded > 0 {
            return nil
        }
        
        if currentJob.Status.Failed > 0 {
            return fmt.Errorf("backup job failed")
        }
        
        time.Sleep(interval)
    }
    
    return fmt.Errorf("backup job timeout")
}
```

#### 2. **Custom Resource Definition с Finalizers**
```yaml
# myresource-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myresources.example.com
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
              cloudProvider:
                type: string
                enum: ["aws", "gcp", "azure"]
              s3Bucket:
                type: string
              rdsInstance:
                type: string
              backupDestination:
                type: string
              retentionPolicy:
                type: string
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Ready", "Terminating", "Failed"]
              lastUpdated:
                type: string
                format: date-time
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
  scope: Namespaced
  names:
    plural: myresources
    singular: myresource
    kind: MyResource

---
# Пример MyResource с finalizers
apiVersion: example.com/v1
kind: MyResource
metadata:
  name: example-resource
  namespace: production
  finalizers:
  - "example.com/my-resource-finalizer"
  - "backup.example.com/backup-finalizer"
  - "cleanup.example.com/cleanup-finalizer"
spec:
  cloudProvider: "aws"
  s3Bucket: "my-app-data-bucket"
  rdsInstance: "my-app-database"
  backupDestination: "s3://backup-bucket/my-app/"
  retentionPolicy: "30d"
```

### 🔧 Практические примеры Finalizers

#### 1. **Namespace Finalizer**
```yaml
# namespace-with-finalizer.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: protected-namespace
  finalizers:
  - "kubernetes"
  - "example.com/custom-cleanup"
spec: {}

---
# Custom controller для namespace cleanup
apiVersion: apps/v1
kind: Deployment
metadata:
  name: namespace-controller
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: namespace-controller
  template:
    metadata:
      labels:
        app: namespace-controller
    spec:
      serviceAccountName: namespace-controller
      containers:
      - name: controller
        image: namespace-controller:latest
        env:
        - name: FINALIZER_NAME
          value: "example.com/custom-cleanup"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

#### 2. **PVC Protection Finalizer**
```yaml
# pvc-with-protection.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: protected-pvc
  namespace: production
  finalizers:
  - "kubernetes.io/pvc-protection"
  - "backup.example.com/pvc-backup"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd

---
# Backup controller для PVC
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pvc-backup-controller
  namespace: production
spec:
  schedule: "0 2 * * *"  # Каждый день в 2:00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: pvc-backup:latest
            command:
            - /bin/sh
            - -c
            - |
              # Поиск PVC с backup finalizer
              kubectl get pvc -o json | jq -r '.items[] | select(.metadata.finalizers[]? == "backup.example.com/pvc-backup") | .metadata.name' | while read pvc; do
                echo "Backing up PVC: $pvc"
                # Backup logic here
              done
          restartPolicy: OnFailure
```

### 📊 Мониторинг и отладка Finalizers

#### 1. **Finalizer Monitoring Script**
```bash
#!/bin/bash
# finalizer-monitoring.sh

echo "📊 Мониторинг Finalizers в кластере"

# Поиск объектов с finalizers
find_objects_with_finalizers() {
    echo "=== Объекты с Finalizers ==="
    
    # Все объекты с finalizers
    kubectl get all --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.finalizers != null and (.metadata.finalizers | length) > 0) | 
        "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "cluster-scope"): \(.metadata.finalizers | join(", "))"
    '
    
    # Namespaces с finalizers
    echo "=== Namespaces с Finalizers ==="
    kubectl get namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.finalizers != null and (.metadata.finalizers | length) > 0) | 
        "\(.metadata.name): \(.metadata.finalizers | join(", "))"
    '
    
    # PV/PVC с finalizers
    echo "=== PV/PVC с Finalizers ==="
    kubectl get pv,pvc --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.finalizers != null and (.metadata.finalizers | length) > 0) | 
        "\(.kind)/\(.metadata.name): \(.metadata.finalizers | join(", "))"
    '
}

# Поиск stuck объектов
find_stuck_objects() {
    echo "=== Stuck Objects (Terminating) ==="
    
    # Pods в состоянии Terminating
    kubectl get pods --all-namespaces --field-selector status.phase=Terminating -o wide
    
    # Namespaces в состоянии Terminating
    kubectl get namespaces --field-selector status.phase=Terminating
    
    # Объекты с deletionTimestamp но с finalizers
    kubectl get all --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.deletionTimestamp != null and .metadata.finalizers != null and (.metadata.finalizers | length) > 0) | 
        "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "cluster-scope") - Stuck with finalizers: \(.metadata.finalizers | join(", "))"
    '
}

# Анализ finalizer patterns
analyze_finalizer_patterns() {
    echo "=== Finalizer Patterns Analysis ==="
    
    # Подсчет использования finalizers
    kubectl get all --all-namespaces -o json | jq -r '
        [.items[].metadata.finalizers[]?] | 
        group_by(.) | 
        map({finalizer: .[0], count: length}) | 
        sort_by(.count) | 
        reverse | 
        .[] | 
        "\(.finalizer): \(.count) objects"
    '
}

# Проверка конкретного объекта
check_object_finalizers() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    echo "=== Checking Finalizers for $resource_type/$resource_name ==="
    
    if [ -n "$namespace" ]; then
        kubectl get $resource_type $resource_name -n $namespace -o json | jq '.metadata.finalizers'
        kubectl describe $resource_type $resource_name -n $namespace | grep -A 10 -B 5 -i finalizer
    else
        kubectl get $resource_type $resource_name -o json | jq '.metadata.finalizers'
        kubectl describe $resource_type $resource_name | grep -A 10 -B 5 -i finalizer
    fi
}

# Cleanup stuck finalizers (ОСТОРОЖНО!)
cleanup_stuck_finalizers() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local finalizer=$4
    
    echo "⚠️  ВНИМАНИЕ: Удаление finalizer может привести к утечке ресурсов!"
    echo "Удаление finalizer '$finalizer' из $resource_type/$resource_name"
    
    read -p "Вы уверены? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Операция отменена"
        return 1
    fi
    
    if [ -n "$namespace" ]; then
        kubectl patch $resource_type $resource_name -n $namespace --type='merge' -p='{"metadata":{"finalizers":null}}'
    else
        kubectl patch $resource_type $resource_name --type='merge' -p='{"metadata":{"finalizers":null}}'
    fi
}

# Мониторинг finalizer events
monitor_finalizer_events() {
    echo "=== Finalizer Events Monitoring ==="
    
    # События связанные с finalizers
    kubectl get events --all-namespaces --field-selector reason=FinalizerUpdateFailed
    kubectl get events --all-namespaces --field-selector reason=FailedDelete
    
    # Continuous monitoring
    echo "Мониторинг событий в реальном времени (Ctrl+C для остановки)..."
    kubectl get events --all-namespaces --watch --field-selector involvedObject.kind!=Event | grep -i finalizer
}

# Генерация отчета
generate_finalizer_report() {
    local report_file="/tmp/finalizer-report-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "📊 Генерация отчета о finalizers..."
    
    {
        echo "=== FINALIZER REPORT ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "=== CLUSTER SUMMARY ==="
        kubectl get nodes --no-headers | wc -l | xargs echo "Nodes:"
        kubectl get namespaces --no-headers | wc -l | xargs echo "Namespaces:"
        kubectl get pods --all-namespaces --no-headers | wc -l | xargs echo "Pods:"
        echo ""
        
        echo "=== OBJECTS WITH FINALIZERS ==="
        find_objects_with_finalizers
        echo ""
        
        echo "=== STUCK OBJECTS ==="
        find_stuck_objects
        echo ""
        
        echo "=== FINALIZER PATTERNS ==="
        analyze_finalizer_patterns
        echo ""
        
    } > $report_file
    
    echo "✅ Отчет сохранен в $report_file"
}

case "$1" in
    find)
        find_objects_with_finalizers
        ;;
    stuck)
        find_stuck_objects
        ;;
    patterns)
        analyze_finalizer_patterns
        ;;
    check)
        check_object_finalizers $2 $3 $4
        ;;
    cleanup)
        cleanup_stuck_finalizers $2 $3 $4 $5
        ;;
    events)
        monitor_finalizer_events
        ;;
    report)
        generate_finalizer_report
        ;;
    all)
        find_objects_with_finalizers
        find_stuck_objects
        analyze_finalizer_patterns
