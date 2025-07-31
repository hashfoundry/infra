# 188. Как работает Kubernetes Device Plugins?

## 🎯 **Что такое Kubernetes Device Plugins?**

**Kubernetes Device Plugins** — это механизм, который позволяет кластеру обнаруживать, рекламировать и выделять специализированные аппаратные ресурсы (GPU, FPGA, InfiniBand, сетевые устройства) для Pod'ов. Device Plugins работают как DaemonSet и взаимодействуют с kubelet через gRPC API для управления жизненным циклом устройств.

## 🏗️ **Основные компоненты Device Plugins:**

### **1. Device Plugin Framework**
- gRPC интерфейс между kubelet и device plugins
- Регистрация и обнаружение устройств
- Выделение ресурсов для контейнеров

### **2. Device Manager (kubelet)**
- Управляет device plugins на узле
- Отслеживает здоровье устройств
- Выполняет allocation requests

### **3. Extended Resources**
- Кастомные ресурсы в Kubernetes API
- Учитываются scheduler'ом при планировании
- Отображаются в node capacity/allocatable

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка device plugins:**
```bash
# Extended resources на узлах
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, capacity: .status.capacity, allocatable: .status.allocatable}'

# Поиск device plugin pods
kubectl get pods --all-namespaces -l app=nvidia-device-plugin
kubectl get pods --all-namespaces | grep -i device

# Device plugin sockets
kubectl get nodes --no-headers | while read node rest; do
  echo "=== Node: $node ==="
  kubectl debug node/$node -it --image=busybox -- ls -la /host/var/lib/kubelet/device-plugins/ 2>/dev/null || echo "No device plugins found"
done
```

### **2. Metrics server как device plugin:**
```bash
# Metrics server использует device plugin pattern
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl describe pod -n kube-system -l k8s-app=metrics-server

# Metrics API resources
kubectl api-resources --api-group=metrics.k8s.io
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[0]'

# Node metrics через device plugin
kubectl top nodes
kubectl top pods -n monitoring
```

### **3. Storage device plugins:**
```bash
# CSI drivers как device plugins
kubectl get csidrivers
kubectl describe csidriver do.csi.digitalocean.com

# Storage classes
kubectl get storageclass
kubectl describe storageclass do-block-storage

# Volume attachments
kubectl get volumeattachments
```

### **4. Network device plugins:**
```bash
# CNI plugins и network devices
kubectl get pods -n kube-system | grep -E "(cni|network)"
kubectl describe daemonset -n kube-system | grep -A 10 "network"

# Network policies
kubectl get networkpolicies --all-namespaces
kubectl describe nodes | grep -A 5 "PodCIDR"
```

## 🔄 **Device Plugin Lifecycle:**

### **1. Registration phase:**
```bash
# Создание mock device plugin для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mock-device-plugin
  namespace: kube-system
data:
  plugin.sh: |
    #!/bin/bash
    echo "Mock Device Plugin starting..."
    echo "Registering with kubelet..."
    echo "Advertising 4 mock devices..."
    while true; do
      echo "Health check: all devices healthy"
      sleep 30
    done
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: mock-device-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: mock-device-plugin
  template:
    metadata:
      labels:
        app: mock-device-plugin
    spec:
      containers:
      - name: mock-plugin
        image: busybox
        command: ["/bin/sh", "/scripts/plugin.sh"]
        volumeMounts:
        - name: scripts
          mountPath: /scripts
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
      volumes:
      - name: scripts
        configMap:
          name: mock-device-plugin
          defaultMode: 0755
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      hostNetwork: true
EOF

# Проверка deployment
kubectl get pods -n kube-system -l app=mock-device-plugin
kubectl logs -n kube-system -l app=mock-device-plugin
```

### **2. Device discovery:**
```bash
# Проверка extended resources
kubectl describe nodes | grep -A 20 "Capacity:\|Allocatable:"

# Custom resource discovery
kubectl get nodes -o json | jq '.items[] | select(.status.capacity | keys[] | contains("example.com/")) | {name: .metadata.name, devices: .status.capacity}'

# Resource availability
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, available: (.status.allocatable // {} | to_entries | map(select(.key | contains("/"))) | from_entries)}'
```

### **3. Resource allocation:**
```bash
# Создание pod с custom resource
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: device-test
  namespace: default
spec:
  containers:
  - name: test-container
    image: busybox
    command: ["sleep", "3600"]
    resources:
      limits:
        example.com/mock-device: "1"
      requests:
        example.com/mock-device: "1"
  restartPolicy: Never
EOF

# Проверка allocation
kubectl describe pod device-test | grep -A 10 "Limits:\|Requests:"
kubectl get pod device-test -o yaml | grep -A 10 resources

# Очистка
kubectl delete pod device-test
kubectl delete daemonset -n kube-system mock-device-plugin
kubectl delete configmap -n kube-system mock-device-plugin
```

## 📈 **Мониторинг Device Plugins:**

### **1. Device plugin health:**
```bash
# Device plugin pod status
kubectl get pods --all-namespaces | grep -i device
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.metadata.labels.app // "" | contains("device")) | {namespace: .metadata.namespace, name: .metadata.name, status: .status.phase}'

# Device plugin logs
kubectl get pods --all-namespaces | grep device | while read namespace pod rest; do
  echo "=== $namespace/$pod ==="
  kubectl logs -n $namespace $pod --tail=5
done

# Resource usage
kubectl top pods --all-namespaces | grep device
```

### **2. Extended resource monitoring:**
```bash
# Node resource capacity
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, capacity: (.status.capacity // {} | to_entries | map(select(.key | contains("/"))) | from_entries)}'

# Resource allocation status
kubectl describe nodes | grep -E "(Allocated resources|example.com/|nvidia.com/|amd.com/)"

# Pod resource requests
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.containers[]?.resources.limits // {} | keys[] | contains("/")) | {namespace: .metadata.namespace, name: .metadata.name, node: .spec.nodeName}'
```

### **3. Device plugin metrics:**
```bash
# Kubelet device plugin metrics
kubectl get --raw /metrics | grep device_plugin

# Node exporter device metrics
kubectl get --raw "/api/v1/nodes/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')/proxy/metrics" | grep -E "(device|hardware)"

# Custom metrics для devices
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[] | {name: .metadata.name, usage: .usage}'
```

## 🏭 **Device Plugins в вашем HA кластере:**

### **1. Storage device integration:**
```bash
# DigitalOcean CSI driver
kubectl get pods -n kube-system | grep csi
kubectl describe daemonset -n kube-system csi-do-node

# Block storage devices
kubectl get pv | grep do-block-storage
kubectl describe pv | grep -A 10 "Source:"

# Volume metrics
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[] | {name: .metadata.name, storage: (.usage.storage // "N/A")}'
```

### **2. Network device integration:**
```bash
# CNI device plugins
kubectl get pods -n kube-system | grep -E "(cni|cilium|flannel|calico)"
kubectl describe daemonset -n kube-system | grep -A 5 "network"

# Network interface monitoring
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, addresses: .status.addresses}'

# Network policies и devices
kubectl get networkpolicies --all-namespaces
```

### **3. Monitoring device integration:**
```bash
# Prometheus node exporter devices
kubectl get pods -n monitoring | grep node-exporter
kubectl logs -n monitoring -l app=node-exporter | grep device

# Grafana device dashboards
kubectl get configmaps -n monitoring | grep dashboard
kubectl describe configmap -n monitoring | grep -A 5 device

# Custom metrics collection
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
curl -s "http://localhost:9090/api/v1/query?query=node_filesystem_device_error" | jq '.data.result'
```

## 🔧 **Создание простого Device Plugin:**

### **1. Mock device plugin:**
```bash
# Создание namespace
kubectl create namespace device-plugin-system

# Device plugin deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: example-device-plugin
  namespace: device-plugin-system
spec:
  selector:
    matchLabels:
      app: example-device-plugin
  template:
    metadata:
      labels:
        app: example-device-plugin
    spec:
      containers:
      - name: device-plugin
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Starting Example Device Plugin"
          echo "Registering 2 example devices"
          # Mock registration with kubelet
          while true; do
            echo "Device health check: OK"
            sleep 60
          done
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: dev
          mountPath: /dev
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
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: dev
        hostPath:
          path: /dev
      hostNetwork: true
      hostPID: true
EOF

# Проверка deployment
kubectl get pods -n device-plugin-system
kubectl logs -n device-plugin-system -l app=example-device-plugin
```

### **2. Testing device allocation:**
```bash
# Создание test workload
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: device-consumer
  namespace: default
spec:
  containers:
  - name: consumer
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: DEVICE_ID
      value: "example-device-0"
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
  restartPolicy: Never
EOF

# Проверка pod
kubectl describe pod device-consumer
kubectl exec device-consumer -- env | grep DEVICE

# Очистка
kubectl delete pod device-consumer
kubectl delete namespace device-plugin-system
```

## 🎯 **Архитектура Device Plugin Framework:**

```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Device Plugin Framework            │
├─────────────────────────────────────────────────────────────┤
│  Pod Specification                                          │
│  ├── Resource requests/limits                              │
│  ├── Extended resource names                               │
│  └── Device-specific environment                           │
├─────────────────────────────────────────────────────────────┤
│  Kubelet (Device Manager)                                  │
│  ├── Device plugin registration                            │
│  ├── Resource allocation                                   │
│  ├── Health monitoring                                     │
│  └── Container runtime integration                         │
├─────────────────────────────────────────────────────────────┤
│  Device Plugin (gRPC Server)                               │
│  ├── Device discovery                                      │
│  ├── Health monitoring                                     │
│  ├── Resource allocation                                   │
│  └── Container preparation                                 │
├─────────────────────────────────────────────────────────────┤
│  Hardware Devices                                          │
│  ├── GPU devices                                           │
│  ├── Storage devices                                       │
│  ├── Network devices                                       │
│  └── Custom hardware                                       │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Troubleshooting Device Plugins:**

### **1. Plugin registration issues:**
```bash
# Device plugin socket files
kubectl get nodes --no-headers | while read node rest; do
  echo "=== Node: $node ==="
  kubectl debug node/$node -it --image=busybox -- find /host/var/lib/kubelet/device-plugins/ -name "*.sock" 2>/dev/null || echo "No sockets found"
done

# Kubelet logs
kubectl get pods -n kube-system | grep kubelet
kubectl logs -n kube-system -l component=kubelet | grep -i device

# Registration errors
kubectl get events --all-namespaces --field-selector reason=FailedDevicePlugin
```

### **2. Resource allocation issues:**
```bash
# Extended resource availability
kubectl describe nodes | grep -E "(Capacity|Allocatable)" -A 20 | grep -E "(example.com/|nvidia.com/|amd.com/)"

# Pod scheduling failures
kubectl get events --field-selector reason=FailedScheduling | grep -i "insufficient.*example.com"

# Resource conflicts
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.status.phase == "Pending") | {name: .metadata.name, reason: .status.conditions[]?.message}'
```

### **3. Device health issues:**
```bash
# Device plugin health
kubectl get pods --all-namespaces | grep device | while read namespace pod rest; do
  echo "=== $namespace/$pod ==="
  kubectl describe pod -n $namespace $pod | grep -A 10 "Conditions:"
done

# Hardware device status
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, conditions: .status.conditions[] | select(.type == "Ready")}'

# Device metrics
kubectl top nodes
kubectl get --raw /metrics | grep -E "(device|hardware).*error"
```

## 🎯 **Best Practices для Device Plugins:**

### **1. Безопасность:**
- Используйте minimal privileges
- Валидируйте device access
- Мониторьте device usage
- Реализуйте proper cleanup

### **2. Производительность:**
- Оптимизируйте device discovery
- Кэшируйте device information
- Минимизируйте allocation latency
- Мониторьте resource usage

### **3. Надежность:**
- Реализуйте health checks
- Обрабатывайте device failures
- Используйте proper error handling
- Планируйте device maintenance

### **4. Операционные аспекты:**
- Документируйте device requirements
- Версионируйте device plugins
- Тестируйте device allocation
- Мониторьте device lifecycle

**Device Plugins — это ключевой механизм для интеграции специализированного оборудования в Kubernetes!**
