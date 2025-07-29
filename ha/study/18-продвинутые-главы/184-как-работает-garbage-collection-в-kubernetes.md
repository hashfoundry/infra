# 184. Как работает garbage collection в Kubernetes?

## 🎯 Вопрос
Как работает garbage collection в Kubernetes?

## 💡 Ответ

Garbage Collection в Kubernetes - это автоматический процесс очистки неиспользуемых ресурсов и объектов, который обеспечивает эффективное использование ресурсов кластера. Система включает несколько компонентов: owner references для управления зависимостями, cascading deletion для удаления связанных объектов, и различные контроллеры для очистки конкретных типов ресурсов.

### 🏗️ Архитектура Garbage Collection

#### 1. **Схема Garbage Collection System**
```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Garbage Collection                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Owner References                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Owner     │    │ Dependent   │    │ Ownership   │ │ │
│  │  │  Objects    │───▶│  Objects    │───▶│   Chain     │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Garbage Collector                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Object    │    │ Dependency  │    │  Deletion   │ │ │
│  │  │  Tracking   │───▶│  Analysis   │───▶│  Decision   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Deletion Strategies                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Foreground  │    │ Background  │    │   Orphan    │ │ │
│  │  │  Deletion   │    │  Deletion   │    │  Deletion   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Specialized Collectors                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    Pod      │    │   Image     │    │   Volume    │ │ │
│  │  │  Collector  │    │ Collector   │    │ Collector   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Node      │    │   Event     │    │   Log       │ │ │
│  │  │ Collector   │    │ Collector   │    │ Collector   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Типы Garbage Collection**
```yaml
# Типы garbage collection в Kubernetes
garbage_collection_types:
  owner_reference_based:
    description: "Основан на owner references между объектами"
    components:
      - "Garbage Collector Controller"
      - "Owner Reference tracking"
      - "Dependency graph analysis"
    
    deletion_strategies:
      foreground:
        description: "Удаление dependents перед owner"
        behavior: "Блокирует удаление owner до завершения dependents"
        use_case: "Критичные зависимости"
      
      background:
        description: "Удаление owner, затем dependents асинхронно"
        behavior: "Немедленное удаление owner"
        use_case: "Обычные случаи"
      
      orphan:
        description: "Удаление owner без удаления dependents"
        behavior: "Dependents становятся orphaned"
        use_case: "Сохранение данных"
  
  resource_specific:
    description: "Специализированные collectors для конкретных ресурсов"
    types:
      pod_gc:
        description: "Очистка завершенных pods"
        triggers:
          - "Pod phase: Succeeded/Failed"
          - "Retention policies"
          - "Node capacity limits"
      
      image_gc:
        description: "Очистка неиспользуемых образов"
        triggers:
          - "Disk usage thresholds"
          - "Image age policies"
          - "Reference counting"
      
      volume_gc:
        description: "Очистка неиспользуемых volumes"
        triggers:
          - "PVC deletion"
          - "Retention policies"
          - "Storage quotas"
      
      event_gc:
        description: "Очистка старых events"
        triggers:
          - "Event age (default: 1 hour)"
          - "Event count limits"
          - "Storage pressure"

# Конфигурация garbage collection
gc_configuration:
  kube_controller_manager:
    flags:
      - "--enable-garbage-collector=true"
      - "--concurrent-gc-syncs=20"
      - "--gc-ignored-resources=events.events.k8s.io,events.v1.events.k8s.io"
  
  kubelet:
    flags:
      - "--image-gc-high-threshold=85"
      - "--image-gc-low-threshold=80"
      - "--minimum-image-ttl-duration=2m"
      - "--maximum-dead-containers-per-container=1"
      - "--maximum-dead-containers=240"
```

### 📊 Примеры из нашего кластера

#### Проверка garbage collection:
```bash
# Проверка garbage collector статуса
kubectl get pods -n kube-system -l component=kube-controller-manager

# Проверка owner references
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.ownerReferences[*].name}{"\n"}{end}'

# Проверка orphaned объектов
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences == null) | {kind: .kind, name: .metadata.name, namespace: .metadata.namespace}'

# Мониторинг garbage collection metrics
kubectl get --raw /metrics | grep garbage_collector
```

### 🔧 Owner References и Dependency Management

#### 1. **Owner References Example**
```yaml
# deployment-with-owner-references.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80

---
# ReplicaSet (создается автоматически Deployment)
# Будет иметь ownerReference на Deployment
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-app-7d4b8c8f9d
  namespace: production
  ownerReferences:
  - apiVersion: apps/v1
    kind: Deployment
    name: web-app
    uid: 12345678-1234-1234-1234-123456789012
    controller: true
    blockOwnerDeletion: true
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
      pod-template-hash: 7d4b8c8f9d
  template:
    metadata:
      labels:
        app: web-app
        pod-template-hash: 7d4b8c8f9d
    spec:
      containers:
      - name: web
        image: nginx:alpine

---
# Pod (создается автоматически ReplicaSet)
# Будет иметь ownerReference на ReplicaSet
apiVersion: v1
kind: Pod
metadata:
  name: web-app-7d4b8c8f9d-abc12
  namespace: production
  ownerReferences:
  - apiVersion: apps/v1
    kind: ReplicaSet
    name: web-app-7d4b8c8f9d
    uid: 87654321-4321-4321-4321-210987654321
    controller: true
    blockOwnerDeletion: true
spec:
  containers:
  - name: web
    image: nginx:alpine
    ports:
    - containerPort: 80
```

#### 2. **Custom Resource с Owner References**
```go
// owner-reference-controller.go
package main

import (
    "context"
    "fmt"
    
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
    "sigs.k8s.io/controller-runtime/pkg/reconcile"
)

// MyResourceReconciler управляет owner references
type MyResourceReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

func (r *MyResourceReconciler) Reconcile(ctx context.Context, req reconcile.Request) (reconcile.Result, error) {
    // Получение основного ресурса
    var myResource MyResource
    if err := r.Get(ctx, req.NamespacedName, &myResource); err != nil {
        return reconcile.Result{}, client.IgnoreNotFound(err)
    }
    
    // Создание зависимых ресурсов с owner references
    if err := r.createDependentResources(ctx, &myResource); err != nil {
        return reconcile.Result{}, err
    }
    
    return reconcile.Result{}, nil
}

func (r *MyResourceReconciler) createDependentResources(ctx context.Context, owner *MyResource) error {
    // Создание ConfigMap с owner reference
    configMap := &corev1.ConfigMap{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-config", owner.Name),
            Namespace: owner.Namespace,
        },
        Data: map[string]string{
            "config.yaml": owner.Spec.Configuration,
        },
    }
    
    // Установка owner reference
    if err := controllerutil.SetControllerReference(owner, configMap, r.Scheme); err != nil {
        return fmt.Errorf("failed to set owner reference: %w", err)
    }
    
    if err := r.Create(ctx, configMap); err != nil {
        return fmt.Errorf("failed to create ConfigMap: %w", err)
    }
    
    // Создание Service с owner reference
    service := &corev1.Service{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-service", owner.Name),
            Namespace: owner.Namespace,
        },
        Spec: corev1.ServiceSpec{
            Selector: map[string]string{
                "app": owner.Name,
            },
            Ports: []corev1.ServicePort{
                {
                    Port:       80,
                    TargetPort: intstr.FromInt(8080),
                },
            },
        },
    }
    
    // Установка owner reference
    if err := controllerutil.SetControllerReference(owner, service, r.Scheme); err != nil {
        return fmt.Errorf("failed to set owner reference: %w", err)
    }
    
    if err := r.Create(ctx, service); err != nil {
        return fmt.Errorf("failed to create Service: %w", err)
    }
    
    // Создание Deployment с owner reference
    deployment := &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-deployment", owner.Name),
            Namespace: owner.Namespace,
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &owner.Spec.Replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: map[string]string{
                    "app": owner.Name,
                },
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: map[string]string{
                        "app": owner.Name,
                    },
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Name:  "app",
                            Image: owner.Spec.Image,
                            Ports: []corev1.ContainerPort{
                                {
                                    ContainerPort: 8080,
                                },
                            },
                            VolumeMounts: []corev1.VolumeMount{
                                {
                                    Name:      "config",
                                    MountPath: "/etc/config",
                                },
                            },
                        },
                    },
                    Volumes: []corev1.Volume{
                        {
                            Name: "config",
                            VolumeSource: corev1.VolumeSource{
                                ConfigMap: &corev1.ConfigMapVolumeSource{
                                    LocalObjectReference: corev1.LocalObjectReference{
                                        Name: configMap.Name,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
    
    // Установка owner reference
    if err := controllerutil.SetControllerReference(owner, deployment, r.Scheme); err != nil {
        return fmt.Errorf("failed to set owner reference: %w", err)
    }
    
    if err := r.Create(ctx, deployment); err != nil {
        return fmt.Errorf("failed to create Deployment: %w", err)
    }
    
    return nil
}

// Utility функция для создания owner reference вручную
func createOwnerReference(owner metav1.Object, scheme *runtime.Scheme) metav1.OwnerReference {
    gvk, _ := apiutil.GVKForObject(owner, scheme)
    
    return metav1.OwnerReference{
        APIVersion:         gvk.GroupVersion().String(),
        Kind:               gvk.Kind,
        Name:               owner.GetName(),
        UID:                owner.GetUID(),
        Controller:         &[]bool{true}[0],
        BlockOwnerDeletion: &[]bool{true}[0],
    }
}
```

### 🔧 Deletion Strategies

#### 1. **Foreground Deletion**
```yaml
# foreground-deletion-example.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-config
  namespace: production
data:
  config.yaml: |
    app:
      name: example
      version: 1.0

---
# Deployment с зависимостью от ConfigMap
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  namespace: production
  ownerReferences:
  - apiVersion: v1
    kind: ConfigMap
    name: example-config
    uid: 12345678-1234-1234-1234-123456789012
    controller: false
    blockOwnerDeletion: true
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: example-config

---
# Скрипт для foreground deletion
apiVersion: v1
kind: ConfigMap
metadata:
  name: deletion-script
  namespace: production
data:
  foreground-delete.sh: |
    #!/bin/bash
    
    # Foreground deletion - удаляет dependents перед owner
    kubectl delete configmap example-config --cascade=foreground
    
    # Проверка статуса удаления
    kubectl get configmap example-config -o yaml | grep deletionTimestamp
    kubectl get deployment example-app
```

#### 2. **Background Deletion**
```bash
#!/bin/bash
# background-deletion.sh

echo "🗑️ Background Deletion Example"

# Background deletion (по умолчанию)
delete_with_background() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    echo "Удаление $resource_type/$resource_name с background cascade"
    
    # Background deletion
    kubectl delete $resource_type $resource_name -n $namespace --cascade=background
    
    # Owner удаляется немедленно
    echo "Owner статус:"
    kubectl get $resource_type $resource_name -n $namespace 2>/dev/null || echo "Owner удален"
    
    # Dependents удаляются асинхронно
    echo "Dependents статус:"
    kubectl get all -n $namespace -l app=$resource_name
}

# Orphan deletion
delete_with_orphan() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    echo "Удаление $resource_type/$resource_name с orphan cascade"
    
    # Orphan deletion
    kubectl delete $resource_type $resource_name -n $namespace --cascade=orphan
    
    # Owner удаляется, dependents остаются
    echo "Owner статус:"
    kubectl get $resource_type $resource_name -n $namespace 2>/dev/null || echo "Owner удален"
    
    echo "Orphaned dependents:"
    kubectl get all -n $namespace -l app=$resource_name -o json | \
        jq '.items[] | select(.metadata.ownerReferences == null or (.metadata.ownerReferences | length) == 0)'
}

# Пример использования
case "$1" in
    background)
        delete_with_background deployment example-app production
        ;;
    orphan)
        delete_with_orphan deployment example-app production
        ;;
    *)
        echo "Использование: $0 {background|orphan}"
        exit 1
        ;;
esac
```

### 📊 Specialized Garbage Collectors

#### 1. **Pod Garbage Collection**
```yaml
# pod-gc-configuration.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-controller-manager-config
  namespace: kube-system
data:
  config.yaml: |
    apiVersion: kubecontrolplane.config.k8s.io/v1alpha1
    kind: KubeControllerManagerConfiguration
    controllers:
      - "*"
    podGCController:
      terminatedPodGCThreshold: 100  # Максимум завершенных pods
    nodeLifecycleController:
      podEvictionTimeout: 5m
      nodeMonitorGracePeriod: 40s
      nodeStartupGracePeriod: 60s

---
# CronJob для дополнительной очистки pods
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pod-cleanup
  namespace: kube-system
spec:
  schedule: "0 */6 * * *"  # Каждые 6 часов
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: pod-cleanup
          containers:
          - name: cleanup
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - -c
            - |
              # Удаление Succeeded pods старше 1 часа
              kubectl get pods --all-namespaces --field-selector status.phase=Succeeded \
                -o json | jq -r '.items[] | select(.status.containerStatuses[0].state.terminated.finishedAt < (now - 3600 | strftime("%Y-%m-%dT%H:%M:%SZ"))) | "\(.metadata.namespace) \(.metadata.name)"' | \
                while read namespace pod; do
                  echo "Deleting succeeded pod: $namespace/$pod"
                  kubectl delete pod $pod -n $namespace
                done
              
              # Удаление Failed pods старше 24 часов
              kubectl get pods --all-namespaces --field-selector status.phase=Failed \
                -o json | jq -r '.items[] | select(.status.containerStatuses[0].state.terminated.finishedAt < (now - 86400 | strftime("%Y-%m-%dT%H:%M:%SZ"))) | "\(.metadata.namespace) \(.metadata.name)"' | \
                while read namespace pod; do
                  echo "Deleting failed pod: $namespace/$pod"
                  kubectl delete pod $pod -n $namespace
                done
          restartPolicy: OnFailure
```

#### 2. **Image Garbage Collection**
```yaml
# kubelet-config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
imageGCHighThresholdPercent: 85  # Начать GC при 85% использования диска
imageGCLowThresholdPercent: 80   # Остановить GC при 80% использования диска
imageMinimumGCAge: 2m            # Минимальный возраст образа для GC
imageMaximumGCAge: 0             # Максимальный возраст (0 = без ограничений)

---
# DaemonSet для мониторинга image usage
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-gc-monitor
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: image-gc-monitor
  template:
    metadata:
      labels:
        app: image-gc-monitor
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: monitor
        image: alpine:latest
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "=== Image Usage Report ==="
            df -h /var/lib/docker 2>/dev/null || df -h /var/lib/containerd
            echo ""
            
            echo "=== Docker Images ==="
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null || \
            crictl images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
            echo ""
            
            echo "=== Unused Images ==="
            docker image prune -f --filter "until=24h" 2>/dev/null || \
            crictl rmi --prune
            
            sleep 3600  # Каждый час
          done
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
          readOnly: true
        - name: containerd-sock
          mountPath: /var/run/containerd/containerd.sock
          readOnly: true
        securityContext:
          privileged: true
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
      - name: containerd-sock
        hostPath:
          path: /var/run/containerd/containerd.sock
```

### 📊 Мониторинг Garbage Collection

#### 1. **GC Monitoring Script**
```bash
#!/bin/bash
# gc-monitoring.sh

echo "📊 Мониторинг Garbage Collection"

# Проверка garbage collector статуса
check_gc_status() {
    echo "=== Garbage Collector Status ==="
    
    # Controller manager статус
    kubectl get pods -n kube-system -l component=kube-controller-manager
    
    # GC metrics
    kubectl get --raw /metrics | grep -E "(garbage_collector|gc_)" | head -20
    
    # GC controller logs
    kubectl logs -n kube-system -l component=kube-controller-manager --tail=50 | grep -i garbage
}

# Анализ owner references
analyze_owner_references() {
    echo "=== Owner References Analysis ==="
    
    # Объекты с owner references
    kubectl get all --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.ownerReferences != null) | 
        "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "cluster-scope") owned by \(.metadata.ownerReferences[0].kind)/\(.metadata.ownerReferences[0].name)"
    ' | sort | uniq -c | sort -nr
    
    # Orphaned объекты
    echo "=== Orphaned Objects ==="
    kubectl get all --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.ownerReferences == null and .kind != "Namespace") | 
        "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "cluster-scope")"
    '
}

# Проверка deletion policies
check_deletion_policies() {
    echo "=== Deletion Policies ==="
    
    # Объекты с blockOwnerDeletion
    kubectl get all --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.ownerReferences != null) | 
        select(.metadata.ownerReferences[].blockOwnerDeletion == true) | 
        "\(.kind)/\(.metadata.name) blocks deletion of \(.metadata.ownerReferences[0].kind)/\(.metadata.ownerReferences[0].name)"
    '
    
    # Объекты с finalizers
    kubectl get all --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.finalizers != null and (.metadata.finalizers | length) > 0) | 
        "\(.kind)/\(.metadata.name) has finalizers: \(.metadata.finalizers | join(", "))"
    '
}

# Мониторинг resource usage
monitor_resource_usage() {
    echo "=== Resource Usage Monitoring ==="
    
    # Pod counts по статусам
    echo "Pod Status Distribution:"
    kubectl get pods --all-namespaces --no-headers | awk '{print $4}' | sort | uniq -c
    
    # Завершенные pods
    echo "Completed Pods:"
    kubectl get pods --all-namespaces --field-selector status.phase=Succeeded --no-headers | wc -l
    kubectl get pods --all-namespaces --field-selector status.phase=Failed --no-headers | wc -l
    
    # Image usage на узлах
    echo "Image Usage per Node:"
    kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.status.images | length) images"'
}

# Проверка GC performance
check_gc_performance() {
    echo "=== GC Performance ==="
    
    # GC duration metrics
    kubectl get --raw /metrics | grep "garbage_collector_attempt_duration_seconds"
    
    # GC success/failure rates
    kubectl get --raw /metrics | grep "garbage_collector_attempts_total"
    
    # Pending deletions
    kubectl get all --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.deletionTimestamp != null) | 
        "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "cluster-scope") - deletion pending since \(.metadata.deletionTimestamp)"
    '
}

# Cleanup recommendations
generate_cleanup_recommendations() {
    echo "=== Cleanup Recommendations ==="
    
    # Старые completed jobs
    echo "Old Completed Jobs:"
    kubectl get jobs --all-namespaces -o json | jq -r '
        .items[] | 
        select(.status.completionTime != null) | 
        select(.status.completionTime < (now - 86400 | strftime("%Y-%m-%dT%H:%M:%SZ"))) | 
        "\(.metadata.namespace)/\(.metadata.name) completed \(.status.completionTime)"
    '
    
    # Неиспользуемые ConfigMaps/Secrets
    echo "Potentially Unused ConfigMaps:"
    kubectl get configmaps --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.name != "kube-root-ca.crt") | 
        "\(.metadata.namespace)/\(.metadata.name)"
    ' | while read cm; do
        namespace=$(echo $cm | cut -d'/' -f1)
        name=$(echo $cm | cut -d'/' -f2)
        
        # Проверка использования в pods
        if ! kubectl get pods -n $namespace -o json | jq -e ".items[] | select(.spec.volumes[]?.configMap?.name == \"$name\" or .spec.containers[].envFrom[]?.configMapRef?.name == \"$name\")" > /dev/null 2>&1; then
            echo "  Unused: $cm"
        fi
    done
}

# Генерация отчета
generate_gc_report() {
    local report_file="/tmp/gc-report-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "📊 Генерация отчета о Garbage Collection..."
    
    {
        echo "
