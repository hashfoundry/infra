# 184. Как работает garbage collection в Kubernetes?

## 🎯 **Что такое Garbage Collection в Kubernetes?**

**Garbage Collection** — это автоматический процесс очистки неиспользуемых ресурсов и объектов в Kubernetes, который обеспечивает эффективное использование ресурсов кластера. Система включает owner references для управления зависимостями, cascading deletion для удаления связанных объектов, и специализированные контроллеры для очистки конкретных типов ресурсов.

## 🏗️ **Основные компоненты Garbage Collection:**

### **1. Owner References**
- Управляют зависимостями между объектами
- Определяют иерархию владения ресурсами
- Обеспечивают автоматическую очистку зависимых объектов

### **2. Cascading Deletion**
- Foreground deletion (удаление dependents перед owner)
- Background deletion (асинхронное удаление dependents)
- Orphan deletion (сохранение dependents)

### **3. Specialized Collectors**
- Pod Garbage Collector (завершенные pods)
- Image Garbage Collector (неиспользуемые образы)
- Volume Garbage Collector (неиспользуемые volumes)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка garbage collection:**
```bash
# Garbage collector статус
kubectl get pods -n kube-system -l component=kube-controller-manager

# Owner references в кластере
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.ownerReferences[*].name}{"\n"}{end}' | head -10

# GC метрики
kubectl get --raw /metrics | grep garbage_collector

# Orphaned объекты
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences == null and .kind != "Namespace") | {kind: .kind, name: .metadata.name, namespace: .metadata.namespace}' | head -5
```

### **2. ArgoCD и owner references:**
```bash
# ArgoCD Applications и их dependents
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.ownerReferences[*].name}{"\n"}{end}'

# Ресурсы созданные ArgoCD
kubectl get all -n monitoring -o json | jq '.items[] | select(.metadata.ownerReferences != null) | {kind: .kind, name: .metadata.name, owner: .metadata.ownerReferences[0].name}'

# ArgoCD managed resources
kubectl get all --all-namespaces -l app.kubernetes.io/instance=monitoring -o json | jq '.items[] | {kind: .kind, name: .metadata.name, namespace: .metadata.namespace}'
```

### **3. Storage garbage collection:**
```bash
# PV/PVC owner references
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.ownerReferences[*].name}{"\n"}{end}'

# PVC в мониторинге
kubectl get pvc -n monitoring -o yaml | grep -A 5 -B 5 ownerReferences

# Неиспользуемые volumes
kubectl get pv --no-headers | awk '$5=="Available" {print $1}'
```

### **4. Pod garbage collection:**
```bash
# Завершенные pods
kubectl get pods --all-namespaces --field-selector status.phase=Succeeded

# Failed pods
kubectl get pods --all-namespaces --field-selector status.phase=Failed

# Pod owner references
kubectl get pods -n monitoring -o json | jq '.items[] | {name: .metadata.name, owner: .metadata.ownerReferences[0].name}'
```

## 🔄 **Типы Deletion Strategies:**

### **1. Background Deletion (по умолчанию):**
```bash
# Background deletion - owner удаляется сразу, dependents асинхронно
kubectl delete deployment test-app --cascade=background

# Проверка процесса
kubectl get deployment test-app  # Удален сразу
kubectl get replicaset -l app=test-app  # Удаляется асинхронно
kubectl get pods -l app=test-app  # Удаляется асинхронно
```

### **2. Foreground Deletion:**
```bash
# Foreground deletion - dependents удаляются перед owner
kubectl delete deployment test-app --cascade=foreground

# Owner остается до удаления всех dependents
kubectl get deployment test-app -o yaml | grep deletionTimestamp
kubectl get replicaset -l app=test-app
kubectl get pods -l app=test-app
```

### **3. Orphan Deletion:**
```bash
# Orphan deletion - dependents остаются без owner
kubectl delete deployment test-app --cascade=orphan

# Owner удален, dependents остаются
kubectl get deployment test-app  # Не найден
kubectl get replicaset -l app=test-app  # Остается без owner
kubectl get pods -l app=test-app  # Остается без owner
```

## 🔧 **Демонстрация Owner References:**

### **1. Создание объектов с owner references:**
```bash
# Создание Deployment (автоматически создает ReplicaSet и Pods с owner references)
kubectl create deployment gc-demo --image=nginx:alpine --replicas=3

# Проверка иерархии owner references
kubectl get deployment gc-demo -o yaml | grep -A 10 metadata
kubectl get replicaset -l app=gc-demo -o yaml | grep -A 10 ownerReferences
kubectl get pods -l app=gc-demo -o yaml | grep -A 10 ownerReferences

# Удаление Deployment (автоматически удалит ReplicaSet и Pods)
kubectl delete deployment gc-demo

# Проверка каскадного удаления
kubectl get replicaset -l app=gc-demo
kubectl get pods -l app=gc-demo
```

### **2. Тестирование orphan deletion:**
```bash
# Создание Deployment
kubectl create deployment orphan-demo --image=nginx:alpine --replicas=2

# Orphan deletion - ReplicaSet и Pods останутся
kubectl delete deployment orphan-demo --cascade=orphan

# Проверка orphaned ресурсов
kubectl get replicaset -l app=orphan-demo
kubectl get pods -l app=orphan-demo

# Ручная очистка orphaned ресурсов
kubectl delete replicaset -l app=orphan-demo
```

### **3. Создание custom owner reference:**
```bash
# ConfigMap как owner
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: owner-demo
  namespace: default
data:
  config: "test"
EOF

# Secret с owner reference на ConfigMap
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: dependent-demo
  namespace: default
  ownerReferences:
  - apiVersion: v1
    kind: ConfigMap
    name: owner-demo
    uid: $(kubectl get configmap owner-demo -o jsonpath='{.metadata.uid}')
    controller: false
    blockOwnerDeletion: false
type: Opaque
data:
  key: $(echo -n "value" | base64)
EOF

# Проверка owner reference
kubectl describe secret dependent-demo | grep -A 5 "Owner References"

# Удаление owner (автоматически удалит dependent)
kubectl delete configmap owner-demo

# Проверка каскадного удаления
kubectl get secret dependent-demo
```

## 📈 **Мониторинг Garbage Collection:**

### **1. GC метрики:**
```bash
# Garbage collector метрики
kubectl get --raw /metrics | grep "garbage_collector_attempt_duration_seconds"

# GC attempts
kubectl get --raw /metrics | grep "garbage_collector_attempts_total"

# Pending deletions
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.deletionTimestamp != null) | {kind: .kind, name: .metadata.name, namespace: .metadata.namespace}'
```

### **2. Анализ owner references:**
```bash
# Подсчет объектов с owner references
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences != null) | {kind: .kind, name: .metadata.name, owner: .metadata.ownerReferences[0].name}' | jq -s 'group_by(.kind) | map({kind: .[0].kind, count: length})'

# Orphaned объекты по типам
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences == null and .kind != "Namespace") | .kind' | sort | uniq -c

# Blocked deletions
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences != null and .metadata.ownerReferences[].blockOwnerDeletion == true) | {kind: .kind, name: .metadata.name}'
```

### **3. Resource usage analysis:**
```bash
# Pod статусы
kubectl get pods --all-namespaces --no-headers | awk '{print $4}' | sort | uniq -c

# Completed jobs старше 24 часов
kubectl get jobs --all-namespaces -o json | jq '.items[] | select(.status.completionTime != null and (.status.completionTime | fromdateiso8601) < (now - 86400)) | {namespace: .metadata.namespace, name: .metadata.name, completed: .status.completionTime}'

# Image usage на nodes
kubectl describe nodes | grep -A 10 "Images:" | grep -E "(Names|Size)"
```

## 🏭 **Garbage Collection в вашем HA кластере:**

### **1. ArgoCD garbage collection:**
```bash
# ArgoCD Applications и их ресурсы
kubectl get applications -n argocd
kubectl describe application monitoring -n argocd | grep -A 10 "Resource Status"

# Ресурсы управляемые ArgoCD
kubectl get all -n monitoring -l app.kubernetes.io/managed-by=argocd

# ArgoCD finalizers и GC
kubectl get applications -n argocd -o yaml | grep -A 5 -B 5 finalizers
```

### **2. Monitoring stack GC:**
```bash
# Prometheus owner references
kubectl get statefulset prometheus-server -n monitoring -o yaml | grep -A 10 ownerReferences

# Grafana dependents
kubectl get all -n monitoring -l app.kubernetes.io/name=grafana -o json | jq '.items[] | {kind: .kind, name: .metadata.name, owner: .metadata.ownerReferences[0].name}'

# PVC garbage collection в мониторинге
kubectl get pvc -n monitoring -o yaml | grep -A 5 -B 5 ownerReferences
```

### **3. Storage garbage collection:**
```bash
# NFS volumes GC
kubectl get pv | grep nfs
kubectl describe pv | grep -A 5 "Reclaim Policy"

# Block storage GC
kubectl get pv | grep do-block-storage
kubectl get pvc --all-namespaces | grep Bound

# Unused PVs
kubectl get pv --no-headers | awk '$5=="Available" {print "Unused PV:", $1}'
```

## 🔄 **Specialized Garbage Collectors:**

### **1. Pod Garbage Collection:**
```bash
# Настройки Pod GC в controller-manager
kubectl describe pod -n kube-system -l component=kube-controller-manager | grep -A 5 -B 5 "terminated-pod-gc-threshold"

# Завершенные pods для очистки
kubectl get pods --all-namespaces --field-selector status.phase=Succeeded --no-headers | wc -l
kubectl get pods --all-namespaces --field-selector status.phase=Failed --no-headers | wc -l

# Manual pod cleanup
kubectl delete pods --all-namespaces --field-selector status.phase=Succeeded --grace-period=0 --force
```

### **2. Image Garbage Collection:**
```bash
# Image usage на nodes
kubectl get nodes -o json | jq '.items[] | {node: .metadata.name, images: (.status.images | length)}'

# Kubelet image GC настройки
kubectl describe node | grep -A 10 "System Info" | grep -E "(Container Runtime|Kubelet)"

# Manual image cleanup (на конкретной node)
kubectl debug node/<node-name> -it --image=alpine -- chroot /host sh -c "docker system prune -f"
```

### **3. Volume Garbage Collection:**
```bash
# Volume attachment status
kubectl get volumeattachments

# Unused PVCs
kubectl get pvc --all-namespaces -o json | jq '.items[] | select(.status.phase == "Bound") | {namespace: .metadata.namespace, name: .metadata.name, volume: .spec.volumeName}'

# Storage class reclaim policies
kubectl get storageclass -o yaml | grep reclaimPolicy
```

## 🎯 **Архитектура Garbage Collection:**

```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Garbage Collection                 │
├─────────────────────────────────────────────────────────────┤
│  Garbage Collector Controller                               │
│  ├── Owner Reference tracking                              │
│  ├── Dependency graph analysis                             │
│  └── Cascading deletion logic                              │
├─────────────────────────────────────────────────────────────┤
│  Deletion Strategies                                        │
│  ├── Foreground (dependents first)                         │
│  ├── Background (owner first, async dependents)            │
│  └── Orphan (owner only, keep dependents)                  │
├─────────────────────────────────────────────────────────────┤
│  Specialized Collectors                                     │
│  ├── Pod GC (completed/failed pods)                        │
│  ├── Image GC (unused container images)                    │
│  ├── Volume GC (unattached volumes)                        │
│  └── Event GC (old cluster events)                         │
├─────────────────────────────────────────────────────────────┤
│  Resource Types                                             │
│  ├── Deployments → ReplicaSets → Pods                      │
│  ├── StatefulSets → Pods → PVCs                           │
│  ├── Jobs → Pods                                           │
│  └── Custom Resources → Dependents                         │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Конфигурация Garbage Collection:**

### **1. Controller Manager настройки:**
```bash
# Проверка GC настроек
kubectl describe pod -n kube-system -l component=kube-controller-manager | grep -A 20 "Command:"

# GC флаги
kubectl logs -n kube-system -l component=kube-controller-manager | grep -E "(garbage|gc)" | head -5

# Concurrent GC syncs
kubectl get pod -n kube-system -l component=kube-controller-manager -o yaml | grep -A 5 -B 5 "concurrent-gc-syncs"
```

### **2. Kubelet GC настройки:**
```bash
# Image GC thresholds
kubectl describe node | grep -A 5 -B 5 "image-gc"

# Container GC настройки
kubectl get --raw /api/v1/nodes/<node-name>/proxy/configz | jq '.kubeletconfig | {imageGCHighThresholdPercent, imageGCLowThresholdPercent}'

# Manual GC trigger
kubectl get --raw /api/v1/nodes/<node-name>/proxy/stats/summary | jq '.node.fs'
```

## 🚨 **Troubleshooting Garbage Collection:**

### **1. Stuck deletions:**
```bash
# Объекты с deletionTimestamp но не удаленные
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.deletionTimestamp != null) | {kind: .kind, name: .metadata.name, namespace: .metadata.namespace, deletionTimestamp: .metadata.deletionTimestamp}'

# Blocked owner deletions
kubectl get all --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences != null and .metadata.ownerReferences[].blockOwnerDeletion == true and .metadata.deletionTimestamp != null)'

# GC controller логи
kubectl logs -n kube-system -l component=kube-controller-manager | grep -i "garbage\|gc" | tail -10
```

### **2. Orphaned resources:**
```bash
# Поиск orphaned pods
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences == null) | {namespace: .metadata.namespace, name: .metadata.name}'

# Orphaned ReplicaSets
kubectl get replicasets --all-namespaces -o json | jq '.items[] | select(.metadata.ownerReferences == null) | {namespace: .metadata.namespace, name: .metadata.name}'

# Manual cleanup orphaned resources
kubectl delete replicasets --all-namespaces --field-selector metadata.ownerReferences=null
```

### **3. GC performance issues:**
```bash
# GC metrics analysis
kubectl get --raw /metrics | grep "garbage_collector_attempt_duration_seconds" | grep -E "(sum|count)"

# High deletion latency
kubectl get events --all-namespaces --field-selector reason=FailedDelete

# Resource pressure
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

## 🎯 **Best Practices для Garbage Collection:**

### **1. Мониторинг:**
- Отслеживайте GC метрики и производительность
- Мониторьте orphaned ресурсы
- Проверяйте stuck deletions

### **2. Конфигурация:**
- Настраивайте подходящие GC thresholds
- Используйте правильные deletion strategies
- Конфигурируйте retention policies

### **3. Профилактика:**
- Правильно настраивайте owner references
- Избегайте circular dependencies
- Тестируйте deletion scenarios

### **4. Оптимизация:**
- Регулярно очищайте completed jobs
- Мониторьте image usage
- Оптимизируйте storage reclaim policies

**Garbage Collection — это критически важный механизм для поддержания чистоты и эффективности Kubernetes кластера!**
