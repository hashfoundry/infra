# 189. Что такое Kubernetes CSI и как создавать storage drivers?

## 🎯 **Что такое Kubernetes CSI?**

**Container Storage Interface (CSI)** — это стандартный интерфейс для подключения внешних систем хранения к Kubernetes. CSI позволяет разработчикам создавать storage drivers, которые работают с любой совместимой системой оркестрации контейнеров, обеспечивая единообразный способ управления хранилищем через gRPC API.

## 🏗️ **Основные компоненты CSI:**

### **1. CSI Services**
- Identity Service — идентификация и возможности драйвера
- Controller Service — управление жизненным циклом томов
- Node Service — операции на уровне узлов

### **2. CSI Driver Components**
- Controller Plugin — централизованное управление (Deployment)
- Node Plugin — локальные операции (DaemonSet)
- Sidecar Containers — интеграция с Kubernetes API

### **3. Storage Backend Integration**
- Volume provisioning и deletion
- Snapshot management
- Volume expansion и cloning

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка CSI drivers:**
```bash
# Установленные CSI драйверы
kubectl get csidriver

# DigitalOcean CSI driver
kubectl describe csidriver do.csi.digitalocean.com

# CSI nodes
kubectl get csinodes
kubectl describe csinode | head -20

# Storage classes
kubectl get storageclass
kubectl describe storageclass do-block-storage
```

### **2. CSI pods в кластере:**
```bash
# CSI controller pods
kubectl get pods -n kube-system | grep csi
kubectl describe pod -n kube-system -l app=csi-do-controller

# CSI node pods (DaemonSet)
kubectl get pods -n kube-system -l app=csi-do-node
kubectl logs -n kube-system -l app=csi-do-node | tail -10

# Volume attachments
kubectl get volumeattachments
kubectl describe volumeattachment | head -20
```

### **3. Storage operations:**
```bash
# Persistent volumes
kubectl get pv
kubectl describe pv | grep -A 10 "Source:"

# Volume snapshots (если поддерживается)
kubectl get volumesnapshotclasses
kubectl get volumesnapshots --all-namespaces

# CSI driver capabilities
kubectl get csidriver do.csi.digitalocean.com -o yaml | grep -A 10 "spec:"
```

### **4. Monitoring CSI operations:**
```bash
# CSI metrics
kubectl get --raw /metrics | grep csi

# Storage metrics
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[] | {name: .metadata.name, storage: (.usage.storage // "N/A")}'

# Events related to storage
kubectl get events --all-namespaces --field-selector reason=VolumeMount
kubectl get events --all-namespaces --field-selector reason=SuccessfulAttachVolume
```

## 🔄 **CSI Driver Lifecycle:**

### **1. Driver registration:**
```bash
# Создание простого CSI driver для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: example.csi.driver
spec:
  attachRequired: true
  podInfoOnMount: false
  volumeLifecycleModes:
  - Persistent
  - Ephemeral
  fsGroupPolicy: ReadWriteOnceWithFSType
EOF

# Проверка регистрации
kubectl get csidriver example.csi.driver
kubectl describe csidriver example.csi.driver
```

### **2. Storage class creation:**
```bash
# Создание storage class
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: example-csi-storage
provisioner: example.csi.driver
parameters:
  type: "fast"
  replication: "3"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF

# Проверка storage class
kubectl get storageclass example-csi-storage
kubectl describe storageclass example-csi-storage
```

### **3. Volume operations testing:**
```bash
# Создание PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-test-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: example-csi-storage
EOF

# Проверка PVC status
kubectl get pvc csi-test-pvc
kubectl describe pvc csi-test-pvc

# Очистка
kubectl delete pvc csi-test-pvc
kubectl delete storageclass example-csi-storage
kubectl delete csidriver example.csi.driver
```

## 📈 **Мониторинг CSI Operations:**

### **1. CSI driver health:**
```bash
# Controller plugin status
kubectl get pods -n kube-system | grep csi.*controller
kubectl describe pod -n kube-system -l app=csi-do-controller | grep -A 10 "Conditions:"

# Node plugin status
kubectl get pods -n kube-system | grep csi.*node
kubectl logs -n kube-system -l app=csi-do-node | grep -E "(error|Error|ERROR)" | tail -5

# CSI driver capabilities
kubectl get csidriver -o json | jq '.items[] | {name: .metadata.name, capabilities: .spec}'
```

### **2. Volume operations monitoring:**
```bash
# Volume attachment status
kubectl get volumeattachments -o json | jq '.items[] | {volume: .spec.source.persistentVolumeName, node: .spec.nodeName, attached: .status.attached}'

# PV/PVC binding status
kubectl get pv,pvc --all-namespaces | grep -E "(Bound|Available|Pending)"

# Storage events
kubectl get events --all-namespaces --field-selector type=Warning | grep -i storage
```

### **3. Performance metrics:**
```bash
# Storage I/O metrics
kubectl top pods --all-namespaces --sort-by=memory | head -10

# Node storage usage
kubectl describe nodes | grep -A 10 "Allocated resources:" | grep storage

# Volume usage statistics
kubectl get --raw "/api/v1/nodes" | jq '.items[] | {name: .metadata.name, storage: .status.capacity.storage}'
```

## 🏭 **CSI в вашем HA кластере:**

### **1. DigitalOcean CSI integration:**
```bash
# DO CSI driver components
kubectl get pods -n kube-system | grep csi-do
kubectl describe daemonset -n kube-system csi-do-node

# DO block storage integration
kubectl get pv | grep do-block-storage
kubectl describe pv | grep -A 5 "do.csi.digitalocean.com"

# Storage classes для DO
kubectl get storageclass | grep do-block-storage
kubectl describe storageclass do-block-storage
```

### **2. NFS storage integration:**
```bash
# NFS provisioner как CSI-like solution
kubectl get pods -n kube-system | grep nfs
kubectl describe deployment -n kube-system nfs-provisioner

# NFS storage class
kubectl get storageclass | grep nfs
kubectl describe storageclass nfs-client

# NFS volumes
kubectl get pv | grep nfs
```

### **3. Monitoring stack storage:**
```bash
# Prometheus storage
kubectl get pvc -n monitoring | grep prometheus
kubectl describe pvc -n monitoring prometheus-server

# Grafana storage
kubectl get pvc -n monitoring | grep grafana
kubectl describe pvc -n monitoring grafana

# Storage usage в monitoring namespace
kubectl get pods -n monitoring -o json | jq '.items[] | {name: .metadata.name, volumes: [.spec.volumes[]? | select(.persistentVolumeClaim != null) | .persistentVolumeClaim.claimName]}'
```

## 🔧 **Создание простого CSI Driver:**

### **1. Mock CSI driver deployment:**
```bash
# Создание namespace
kubectl create namespace csi-driver-system

# Mock CSI driver
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mock-csi-controller
  namespace: csi-driver-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mock-csi-controller
  template:
    metadata:
      labels:
        app: mock-csi-controller
    spec:
      containers:
      - name: mock-driver
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Mock CSI Controller starting..."
          echo "Implementing Identity, Controller services..."
          while true; do
            echo "CSI Controller: Managing volumes..."
            sleep 60
          done
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: mock-csi-node
  namespace: csi-driver-system
spec:
  selector:
    matchLabels:
      app: mock-csi-node
  template:
    metadata:
      labels:
        app: mock-csi-node
    spec:
      containers:
      - name: mock-driver
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Mock CSI Node starting on $(hostname)..."
          echo "Implementing Node service..."
          while true; do
            echo "CSI Node: Managing local volumes..."
            sleep 60
          done
        volumeMounts:
        - name: kubelet-dir
          mountPath: /var/lib/kubelet
          mountPropagation: Bidirectional
        securityContext:
          privileged: true
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: kubelet-dir
        hostPath:
          path: /var/lib/kubelet
          type: Directory
      hostNetwork: true
EOF

# Проверка deployment
kubectl get pods -n csi-driver-system
kubectl logs -n csi-driver-system -l app=mock-csi-controller
```

### **2. CSI driver testing:**
```bash
# Тестирование CSI operations
echo "=== CSI Driver Testing ==="

# Check driver pods
kubectl get pods -n csi-driver-system -o wide

# Check logs
kubectl logs -n csi-driver-system -l app=mock-csi-node | head -10

# Simulate volume operations
echo "Simulating volume create operation..."
kubectl exec -n csi-driver-system deployment/mock-csi-controller -- echo "CreateVolume: vol-123, size: 1Gi"

echo "Simulating volume attach operation..."
kubectl exec -n csi-driver-system daemonset/mock-csi-node -- echo "NodeStageVolume: vol-123 -> /var/lib/kubelet/pods/..."

# Очистка
kubectl delete namespace csi-driver-system
```

## 🎯 **Архитектура CSI Framework:**

```
┌─────────────────────────────────────────────────────────────┐
│                    CSI Architecture                        │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes Layer                                          │
│  ├── kubelet (Node Service calls)                         │
│  ├── Controller Manager (Controller Service calls)        │
│  └── API Server (CSI object management)                   │
├─────────────────────────────────────────────────────────────┤
│  CSI Interface (gRPC)                                      │
│  ├── Identity Service (GetPluginInfo, Probe)              │
│  ├── Controller Service (CreateVolume, DeleteVolume)      │
│  └── Node Service (NodeStageVolume, NodePublishVolume)    │
├─────────────────────────────────────────────────────────────┤
│  CSI Driver                                                │
│  ├── Controller Plugin (StatefulSet/Deployment)           │
│  ├── Node Plugin (DaemonSet)                              │
│  └── Sidecar Containers (provisioner, attacher, etc.)    │
├─────────────────────────────────────────────────────────────┤
│  Storage Backend                                           │
│  ├── Block Storage (iSCSI, FC, local disks)              │
│  ├── File Storage (NFS, CephFS, GlusterFS)               │
│  └── Object Storage (S3, Swift, Ceph Object)             │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Troubleshooting CSI Issues:**

### **1. Driver registration issues:**
```bash
# CSI driver registration
kubectl get csidriver
kubectl describe csidriver | grep -A 10 "Events:"

# CSI node registration
kubectl get csinodes
kubectl describe csinode | grep -A 10 "Drivers:"

# Driver pod issues
kubectl get pods --all-namespaces | grep csi
kubectl describe pod -n kube-system -l app=csi-do-controller | grep -A 10 "Events:"
```

### **2. Volume provisioning issues:**
```bash
# PVC provisioning failures
kubectl get events --field-selector reason=ProvisioningFailed
kubectl describe pvc | grep -A 10 "Events:"

# Volume attachment issues
kubectl get volumeattachments
kubectl describe volumeattachment | grep -A 10 "Events:"

# Storage class issues
kubectl describe storageclass | grep -A 5 "Parameters:"
```

### **3. Mount/unmount issues:**
```bash
# Pod mount failures
kubectl get events --field-selector reason=FailedMount
kubectl describe pod | grep -A 10 "Events:" | grep -i mount

# Node service issues
kubectl logs -n kube-system -l app=csi-do-node | grep -E "(error|Error|failed)"

# Kubelet CSI issues
kubectl describe node | grep -A 10 "Events:" | grep -i csi
```

## 🎯 **Best Practices для CSI:**

### **1. Безопасность:**
- Используйте proper RBAC permissions
- Валидируйте storage parameters
- Мониторьте access patterns
- Реализуйте encryption at rest

### **2. Производительность:**
- Оптимизируйте volume provisioning
- Используйте appropriate storage classes
- Мониторьте I/O performance
- Планируйте capacity management

### **3. Надежность:**
- Реализуйте health checks
- Используйте volume snapshots
- Планируйте backup strategies
- Мониторьте storage health

### **4. Операционные аспекты:**
- Документируйте storage requirements
- Версионируйте CSI drivers
- Тестируйте upgrade procedures
- Мониторьте storage usage

**CSI — это стандартный и мощный способ интеграции систем хранения с Kubernetes!**
