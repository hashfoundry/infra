# 186. Что такое Kubernetes Operators и как их создавать?

## 🎯 **Что такое Kubernetes Operators?**

**Kubernetes Operators** — это специализированные контроллеры, которые расширяют функциональность Kubernetes API для управления сложными stateful приложениями. Operators кодируют операционные знания (установка, обновление, резервное копирование, восстановление) в виде кода, автоматизируя жизненный цикл приложений с использованием Custom Resources.

## 🏗️ **Основные компоненты Operators:**

### **1. Custom Resource Definition (CRD)**
- Определяет новые типы ресурсов в Kubernetes
- Расширяет API Server новыми объектами
- Включает схему валидации и версионирование

### **2. Controller Logic**
- Реализует reconciliation loop
- Отслеживает изменения Custom Resources
- Выполняет операции для достижения желаемого состояния

### **3. Operator Pattern**
- Комбинирует CRD и Controller
- Автоматизирует операционные задачи
- Обеспечивает декларативное управление приложениями

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка существующих operators:**
```bash
# Установленные CRDs
kubectl get crd

# Operators в кластере
kubectl get pods --all-namespaces -l app.kubernetes.io/component=controller

# ArgoCD как пример operator
kubectl get applications -n argocd
kubectl describe crd applications.argoproj.io

# Prometheus Operator (если установлен)
kubectl get servicemonitors --all-namespaces
kubectl get prometheusrules --all-namespaces
```

### **2. ArgoCD Operator в действии:**
```bash
# ArgoCD Applications (Custom Resources)
kubectl get applications -n argocd -o yaml | head -20

# ArgoCD Controller
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-application-controller

# ArgoCD CRD
kubectl describe crd applications.argoproj.io | grep -A 10 "Spec"

# ArgoCD reconciliation
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep reconcile | tail -5
```

### **3. Monitoring stack operators:**
```bash
# Prometheus CRDs
kubectl get crd | grep monitoring.coreos.com

# ServiceMonitor resources
kubectl get servicemonitors -n monitoring
kubectl describe servicemonitor -n monitoring | head -20

# PrometheusRule resources
kubectl get prometheusrules -n monitoring
```

### **4. Storage operators:**
```bash
# Storage CRDs
kubectl get crd | grep storage

# CSI operators
kubectl get pods -n kube-system | grep csi

# Volume snapshots
kubectl get volumesnapshotclasses
kubectl get volumesnapshots --all-namespaces
```

## 🔄 **Operator Maturity Levels:**

### **1. Level 1 - Basic Install:**
```bash
# Простой operator для установки приложения
cat << EOF | kubectl apply -f -
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
              replicas:
                type: integer
                minimum: 1
          status:
            type: object
            properties:
              phase:
                type: string
  scope: Namespaced
  names:
    plural: webapps
    singular: webapp
    kind: WebApp
EOF

# Создание WebApp instance
cat << EOF | kubectl apply -f -
apiVersion: example.com/v1
kind: WebApp
metadata:
  name: demo-app
  namespace: default
spec:
  image: nginx:alpine
  replicas: 3
EOF

# Проверка созданного ресурса
kubectl get webapps
kubectl describe webapp demo-app
```

### **2. Level 2 - Seamless Upgrades:**
```bash
# Обновление WebApp
kubectl patch webapp demo-app --type='merge' -p='{"spec":{"image":"nginx:1.21","replicas":5}}'

# Проверка rolling update
kubectl get pods -l app=demo-app -w

# Проверка статуса обновления
kubectl describe webapp demo-app | grep -A 10 Status
```

### **3. Level 3 - Full Lifecycle:**
```bash
# Создание backup
kubectl annotate webapp demo-app backup.example.com/schedule="0 2 * * *"

# Проверка backup jobs
kubectl get jobs -l backup-for=demo-app

# Scaling операции
kubectl patch webapp demo-app --type='merge' -p='{"spec":{"replicas":10}}'
```

## 📈 **Мониторинг Operators:**

### **1. Operator metrics:**
```bash
# Controller metrics
kubectl get --raw /metrics | grep controller_runtime

# Reconciliation metrics
kubectl get --raw /metrics | grep "controller_runtime_reconcile"

# Error metrics
kubectl get --raw /metrics | grep "controller_runtime_reconcile_errors_total"

# ArgoCD operator metrics
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082 &
curl http://localhost:8082/metrics | grep argocd_app
```

### **2. Operator health:**
```bash
# Controller pod status
kubectl get pods --all-namespaces -l app.kubernetes.io/component=controller

# Controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | tail -10

# Resource status
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, health: .status.health.status}'

# Sync status
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, sync: .status.sync.status}'
```

### **3. Custom Resource status:**
```bash
# Application conditions
kubectl get applications -n argocd -o yaml | grep -A 10 conditions

# Resource events
kubectl get events --all-namespaces --field-selector involvedObject.kind=Application

# Finalizers status
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, finalizers: .metadata.finalizers}'
```

## 🏭 **Operators в вашем HA кластере:**

### **1. ArgoCD Operator:**
```bash
# ArgoCD Applications management
kubectl get applications -n argocd
kubectl describe application monitoring -n argocd | grep -A 20 "Status"

# ArgoCD Projects
kubectl get appprojects -n argocd
kubectl describe appproject default -n argocd

# ArgoCD sync operations
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, lastSync: .status.operationState.finishedAt}'
```

### **2. Monitoring Operators:**
```bash
# Prometheus Operator resources
kubectl get prometheus -n monitoring
kubectl get alertmanager -n monitoring

# ServiceMonitor для мониторинга
kubectl get servicemonitors -n monitoring
kubectl describe servicemonitor prometheus-server -n monitoring

# PrometheusRule для алертов
kubectl get prometheusrules -n monitoring
```

### **3. Storage Operators:**
```bash
# CSI Driver operators
kubectl get csidrivers
kubectl describe csidriver do.csi.digitalocean.com

# Storage classes managed by operators
kubectl get storageclass
kubectl describe storageclass do-block-storage

# Volume snapshots
kubectl get volumesnapshotclasses
```

## 🔧 **Создание простого Operator:**

### **1. Database CRD:**
```bash
# Создание Database CRD
cat << EOF | kubectl apply -f -
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
                enum: ["postgresql", "mysql"]
              version:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 5
              storage:
                type: object
                properties:
                  size:
                    type: string
            required:
            - type
            - version
          status:
            type: object
            properties:
              phase:
                type: string
              ready:
                type: boolean
              endpoint:
                type: string
    subresources:
      status: {}
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames:
    - db
EOF

# Проверка CRD
kubectl get crd databases.example.com
kubectl describe crd databases.example.com
```

### **2. Database instance:**
```bash
# Создание Database instance
cat << EOF | kubectl apply -f -
apiVersion: example.com/v1
kind: Database
metadata:
  name: my-postgres
  namespace: default
spec:
  type: postgresql
  version: "13"
  replicas: 2
  storage:
    size: "10Gi"
EOF

# Проверка созданного ресурса
kubectl get databases
kubectl describe database my-postgres
```

### **3. Простой controller (концептуально):**
```bash
# Controller будет создавать StatefulSet
kubectl get statefulset my-postgres

# Controller будет создавать Service
kubectl get service my-postgres

# Controller будет обновлять status
kubectl get database my-postgres -o yaml | grep -A 10 status
```

## 🎯 **Архитектура Operator Pattern:**

```
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Operator Pattern               │
├─────────────────────────────────────────────────────────────┤
│  Custom Resource Definition (CRD)                          │
│  ├── API Schema definition                                 │
│  ├── Validation rules                                      │
│  └── Versioning strategy                                   │
├─────────────────────────────────────────────────────────────┤
│  Custom Resource (CR)                                      │
│  ├── Desired state specification                          │
│  ├── Configuration parameters                             │
│  └── Status information                                    │
├─────────────────────────────────────────────────────────────┤
│  Operator Controller                                       │
│  ├── Watch CR events                                       │
│  ├── Reconciliation logic                                 │
│  ├── Resource management                                   │
│  └── Status updates                                        │
├─────────────────────────────────────────────────────────────┤
│  Managed Resources                                         │
│  ├── Deployments/StatefulSets                            │
│  ├── Services/ConfigMaps                                  │
│  ├── PVCs/Secrets                                         │
│  └── Other Kubernetes objects                             │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Troubleshooting Operators:**

### **1. Controller issues:**
```bash
# Controller pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep ERROR

# Controller resource usage
kubectl top pod -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Controller events
kubectl get events -n argocd --field-selector involvedObject.kind=Pod

# RBAC issues
kubectl auth can-i create applications --as=system:serviceaccount:argocd:argocd-application-controller -n argocd
```

### **2. Custom Resource issues:**
```bash
# CR validation errors
kubectl get events --field-selector reason=FailedCreate

# CR status problems
kubectl get applications -n argocd -o json | jq '.items[] | select(.status.health.status != "Healthy")'

# Finalizer issues
kubectl get applications -n argocd -o json | jq '.items[] | select(.metadata.deletionTimestamp != null)'

# Reconciliation failures
kubectl describe application monitoring -n argocd | grep -A 10 "Conditions"
```

### **3. Performance issues:**
```bash
# Reconciliation frequency
kubectl get --raw /metrics | grep "controller_runtime_reconcile_total"

# Queue depth
kubectl get --raw /metrics | grep "workqueue_depth"

# Processing time
kubectl get --raw /metrics | grep "controller_runtime_reconcile_time_seconds"

# Memory usage
kubectl top pod -n argocd --sort-by=memory
```

## 🔧 **Best Practices для Operators:**

### **1. Мониторинг:**
```bash
# Operator health checks
kubectl get pods --all-namespaces -l app.kubernetes.io/component=controller --field-selector status.phase!=Running

# Resource drift detection
kubectl get applications -n argocd -o json | jq '.items[] | select(.status.sync.status != "Synced")'

# Performance monitoring
kubectl get --raw /metrics | grep "controller_runtime" | grep -E "(reconcile_total|reconcile_time_seconds)"
```

### **2. Операционные аспекты:**
```bash
# Backup CRDs
kubectl get crd -o yaml > crd-backup.yaml

# Backup Custom Resources
kubectl get applications -n argocd -o yaml > applications-backup.yaml

# Version management
kubectl get crd applications.argoproj.io -o yaml | grep -A 5 versions
```

## 🎯 **Best Practices для Operators:**

### **1. Дизайн:**
- Следуйте принципам декларативного API
- Реализуйте idempotent операции
- Используйте proper status reporting

### **2. Безопасность:**
- Минимизируйте RBAC permissions
- Используйте service accounts
- Валидируйте входные данные

### **3. Надежность:**
- Реализуйте proper error handling
- Используйте exponential backoff
- Мониторьте operator health

### **4. Производительность:**
- Оптимизируйте reconciliation loops
- Используйте efficient watches
- Кэшируйте данные где возможно

**Operators — это мощный паттерн для автоматизации управления сложными приложениями в Kubernetes!**
