# 198. Что такое Device Plugins и как они работают?

## 🎯 **Что такое Device Plugins?**

**Device Plugins** — это механизм расширения Kubernetes, позволяющий подам использовать специализированные аппаратные ресурсы (GPU, FPGA, InfiniBand, сетевые устройства) без изменения основного кода Kubernetes. Они работают через gRPC API и регистрируют свои ресурсы в kubelet.

## 🏗️ **Основные компоненты:**

### **1. Device Plugin API**
- gRPC интерфейс для взаимодействия с kubelet
- Registration Service для регистрации плагинов
- Device Service для управления жизненным циклом устройств
- Health monitoring для контроля состояния устройств

### **2. Kubelet Integration**
- Device Manager для отслеживания регистраций плагинов
- Resource Manager для рекламирования ресурсов в API server
- Pod Manager для конфигурации container runtime
- Automatic device discovery и allocation

### **3. Hardware Abstraction**
- Стандартизированный интерфейс для любых типов устройств
- Поддержка NUMA topology awareness
- Изоляция ресурсов между подами
- Автоматическое управление device files и mounts

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка существующих Device Plugins:**
```bash
# Проверка доступных extended resources на узлах
kubectl get nodes -o json | jq '.items[].status.allocatable' | grep -E "(nvidia|intel|amd)"

# Проверка capacity и allocatable ресурсов
kubectl describe nodes | grep -A 10 "Capacity\|Allocatable"

# Проверка device plugin sockets на узлах
kubectl debug node/<node-name> -it --image=busybox -- ls -la /host/var/lib/kubelet/device-plugins/

# Проверка device plugin pods в кластере
kubectl get pods --all-namespaces | grep -E "(device|gpu|fpga)"

# Проверка extended resources в node status
kubectl get nodes -o yaml | grep -A 5 -B 5 "nvidia.com\|intel.com\|amd.com"
```

### **2. Анализ GPU resources (если доступны):**
```bash
# Проверка NVIDIA GPU resources
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, gpu: .status.allocatable["nvidia.com/gpu"]}'

# Проверка GPU pods
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.containers[].resources.limits["nvidia.com/gpu"]) | {name: .metadata.name, namespace: .metadata.namespace}'

# Проверка GPU utilization
kubectl top nodes --show-capacity

# Проверка device plugin logs
kubectl logs -n kube-system -l app=nvidia-device-plugin --tail=20
```

### **3. Создание тестового Device Plugin:**
```bash
# Создание namespace для device plugin
kubectl create namespace device-plugin-system

# Создание ConfigMap с device plugin конфигурацией
kubectl create configmap device-plugin-config -n device-plugin-system \
  --from-literal=device-count=4 \
  --from-literal=device-prefix=hashfoundry-device

# Проверка созданных ресурсов
kubectl get configmap -n device-plugin-system
kubectl describe configmap device-plugin-config -n device-plugin-system
```

### **4. Мониторинг Device Plugin активности:**
```bash
# Мониторинг через Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &

# Проверка метрик device plugins
# Query: kubelet_device_plugin_registration_total
# Query: kubelet_device_plugin_alloc_duration_seconds

# Проверка логов kubelet для device plugins
kubectl logs -n kube-system -l component=kubelet | grep -i "device\|plugin"

# Мониторинг через Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 &
```

## 🔄 **Реализация Custom Device Plugin:**

### **1. Device Plugin Server Implementation:**
```yaml
# custom-device-plugin.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: custom-device-plugin
  namespace: device-plugin-system
  labels:
    app: custom-device-plugin
spec:
  selector:
    matchLabels:
      app: custom-device-plugin
  template:
    metadata:
      labels:
        app: custom-device-plugin
    spec:
      serviceAccountName: device-plugin-service-account
      hostNetwork: true
      hostPID: true
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: device-plugin
        image: hashfoundry/custom-device-plugin:v1.0.0
        command: ["/usr/bin/custom-device-plugin"]
        args:
        - --resource-name=hashfoundry.com/custom-device
        - --device-count=4
        - --health-check-interval=30s
        - --log-level=info
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: DEVICE_PLUGIN_PATH
          value: "/var/lib/kubelet/device-plugins"
        securityContext:
          privileged: true
          capabilities:
            add:
            - SYS_ADMIN
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: dev
          mountPath: /dev
        - name: sys
          mountPath: /sys
        - name: proc
          mountPath: /proc
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: dev
        hostPath:
          path: /dev
      - name: sys
        hostPath:
          path: /sys
      - name: proc
        hostPath:
          path: /proc
      nodeSelector:
        hashfoundry.com/custom-device: "enabled"

---
# Service для health checks
apiVersion: v1
kind: Service
metadata:
  name: custom-device-plugin
  namespace: device-plugin-system
  labels:
    app: custom-device-plugin
spec:
  selector:
    app: custom-device-plugin
  ports:
  - name: health
    port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP

---
# ServiceAccount и RBAC
apiVersion: v1
kind: ServiceAccount
metadata:
  name: device-plugin-service-account
  namespace: device-plugin-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: device-plugin-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch", "patch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: device-plugin-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: device-plugin-reader
subjects:
- kind: ServiceAccount
  name: device-plugin-service-account
  namespace: device-plugin-system
```

### **2. Device Plugin Go Implementation:**
```go
// main.go
package main

import (
    "context"
    "fmt"
    "net"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "time"

    "google.golang.org/grpc"
    "k8s.io/klog/v2"
    pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"
)

const (
    defaultResourceName = "hashfoundry.com/custom-device"
    defaultDeviceCount  = 4
    kubeletSocket      = pluginapi.KubeletSocket
    devicePluginPath   = pluginapi.DevicePluginPath
)

type CustomDevicePlugin struct {
    resourceName string
    socket       string
    server       *grpc.Server
    devices      map[string]*pluginapi.Device
    stop         chan interface{}
    health       chan *pluginapi.Device
    deviceCount  int
}

func NewCustomDevicePlugin(resourceName string, deviceCount int) *CustomDevicePlugin {
    serverSock := filepath.Join(devicePluginPath, 
        strings.Replace(resourceName, "/", "-", -1)+".sock")
    
    return &CustomDevicePlugin{
        resourceName: resourceName,
        socket:       serverSock,
        devices:      make(map[string]*pluginapi.Device),
        stop:         make(chan interface{}),
        health:       make(chan *pluginapi.Device),
        deviceCount:  deviceCount,
    }
}

func main() {
    klog.Info("Starting HashFoundry Custom Device Plugin")
    
    // Parse command line arguments
    resourceName := getEnvOrDefault("RESOURCE_NAME", defaultResourceName)
    deviceCount := getIntEnvOrDefault("DEVICE_COUNT", defaultDeviceCount)
    
    plugin := NewCustomDevicePlugin(resourceName, deviceCount)
    
    // Start health check server
    go plugin.startHealthServer()
    
    // Discover devices
    if err := plugin.discoverDevices(); err != nil {
        klog.Fatalf("Failed to discover devices: %v", err)
    }
    
    // Start device plugin server
    if err := plugin.Start(); err != nil {
        klog.Fatalf("Failed to start device plugin: %v", err)
    }
    
    // Register with kubelet
    if err := plugin.Register(); err != nil {
        klog.Fatalf("Failed to register device plugin: %v", err)
    }
    
    klog.Info("Device plugin started successfully")
    
    // Start health monitoring
    go plugin.healthMonitor()
    
    // Wait for termination signal
    <-plugin.stop
    
    klog.Info("Shutting down device plugin")
    plugin.Stop()
}

func (dp *CustomDevicePlugin) Start() error {
    if err := dp.cleanup(); err != nil {
        return err
    }
    
    sock, err := net.Listen("unix", dp.socket)
    if err != nil {
        return fmt.Errorf("failed to listen on socket %s: %v", dp.socket, err)
    }
    
    dp.server = grpc.NewServer()
    pluginapi.RegisterDevicePluginServer(dp.server, dp)
    
    go func() {
        if err := dp.server.Serve(sock); err != nil {
            klog.Errorf("Failed to serve: %v", err)
        }
    }()
    
    // Wait for server to start
    conn, err := grpc.Dial(dp.socket, grpc.WithInsecure(), grpc.WithBlock(),
        grpc.WithTimeout(5*time.Second),
        grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
            return net.DialTimeout("unix", addr, timeout)
        }))
    if err != nil {
        return fmt.Errorf("failed to connect to device plugin server: %v", err)
    }
    conn.Close()
    
    klog.Info("Device plugin server started")
    return nil
}

func (dp *CustomDevicePlugin) Register() error {
    conn, err := grpc.Dial(kubeletSocket, grpc.WithInsecure(),
        grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
            return net.DialTimeout("unix", addr, timeout)
        }))
    if err != nil {
        return fmt.Errorf("failed to connect to kubelet: %v", err)
    }
    defer conn.Close()
    
    client := pluginapi.NewRegistrationClient(conn)
    
    request := &pluginapi.RegisterRequest{
        Version:      pluginapi.Version,
        Endpoint:     filepath.Base(dp.socket),
        ResourceName: dp.resourceName,
        Options: &pluginapi.DevicePluginOptions{
            PreStartRequired:                false,
            GetPreferredAllocationAvailable: true,
        },
    }
    
    if _, err := client.Register(context.Background(), request); err != nil {
        return fmt.Errorf("failed to register device plugin: %v", err)
    }
    
    klog.Infof("Device plugin registered with kubelet for resource: %s", dp.resourceName)
    return nil
}

func (dp *CustomDevicePlugin) GetDevicePluginOptions(context.Context, *pluginapi.Empty) (*pluginapi.DevicePluginOptions, error) {
    return &pluginapi.DevicePluginOptions{
        PreStartRequired:                false,
        GetPreferredAllocationAvailable: true,
    }, nil
}

func (dp *CustomDevicePlugin) ListAndWatch(e *pluginapi.Empty, s pluginapi.DevicePlugin_ListAndWatchServer) error {
    klog.Info("Starting ListAndWatch")
    
    if err := s.Send(&pluginapi.ListAndWatchResponse{Devices: dp.getDevices()}); err != nil {
        return fmt.Errorf("failed to send device list: %v", err)
    }
    
    for {
        select {
        case <-dp.stop:
            return nil
        case device := <-dp.health:
            if dev, exists := dp.devices[device.ID]; exists {
                dev.Health = device.Health
                klog.Infof("Device %s health changed to %s", device.ID, device.Health)
                if err := s.Send(&pluginapi.ListAndWatchResponse{Devices: dp.getDevices()}); err != nil {
                    return fmt.Errorf("failed to send device update: %v", err)
                }
            }
        }
    }
}

func (dp *CustomDevicePlugin) Allocate(ctx context.Context, reqs *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
    klog.Infof("Allocate request: %v", reqs)
    
    responses := &pluginapi.AllocateResponse{}
    
    for _, req := range reqs.ContainerRequests {
        response := &pluginapi.ContainerAllocateResponse{}
        
        for _, deviceID := range req.DevicesIDs {
            device, exists := dp.devices[deviceID]
            if !exists {
                return nil, fmt.Errorf("device %s not found", deviceID)
            }
            
            if device.Health != pluginapi.Healthy {
                return nil, fmt.Errorf("device %s is not healthy", deviceID)
            }
            
            // Set environment variables
            if response.Envs == nil {
                response.Envs = make(map[string]string)
            }
            response.Envs["HASHFOUNDRY_DEVICE_ID"] = deviceID
            response.Envs["HASHFOUNDRY_DEVICE_PATH"] = fmt.Sprintf("/dev/hashfoundry-device-%s", deviceID)
            response.Envs["HASHFOUNDRY_DEVICE_COUNT"] = fmt.Sprintf("%d", len(req.DevicesIDs))
            
            // Add device mounts
            devicePath := fmt.Sprintf("/dev/hashfoundry-device-%s", deviceID)
            response.Mounts = append(response.Mounts, &pluginapi.Mount{
                ContainerPath: devicePath,
                HostPath:      devicePath,
                ReadOnly:      false,
            })
            
            // Add device specifications
            response.Devices = append(response.Devices, &pluginapi.DeviceSpec{
                ContainerPath: devicePath,
                HostPath:      devicePath,
                Permissions:   "rw",
            })
            
            // Add annotations for monitoring
            if response.Annotations == nil {
                response.Annotations = make(map[string]string)
            }
            response.Annotations["hashfoundry.com/device-allocated"] = deviceID
            response.Annotations["hashfoundry.com/allocation-time"] = time.Now().Format(time.RFC3339)
            
            klog.Infof("Allocated device %s to container", deviceID)
        }
        
        responses.ContainerResponses = append(responses.ContainerResponses, response)
    }
    
    return responses, nil
}

func (dp *CustomDevicePlugin) GetPreferredAllocation(ctx context.Context, req *pluginapi.PreferredAllocationRequest) (*pluginapi.PreferredAllocationResponse, error) {
    response := &pluginapi.PreferredAllocationResponse{}
    
    for _, containerReq := range req.ContainerRequests {
        containerResp := &pluginapi.ContainerPreferredAllocationResponse{}
        
        // Simple allocation strategy: prefer devices with lower IDs
        availableDevices := containerReq.AvailableDeviceIDs
        mustIncludeDevices := containerReq.MustIncludeDeviceIDs
        allocationSize := int(containerReq.AllocationSize)
        
        // Start with must-include devices
        preferredDevices := make([]string, 0, allocationSize)
        preferredDevices = append(preferredDevices, mustIncludeDevices...)
        
        // Add additional devices if needed
        for _, deviceID := range availableDevices {
            if len(preferredDevices) >= allocationSize {
                break
            }
            
            // Skip if already included
            found := false
            for _, included := range preferredDevices {
                if included == deviceID {
                    found = true
                    break
                }
            }
            
            if !found {
                preferredDevices = append(preferredDevices, deviceID)
            }
        }
        
        containerResp.DeviceIDs = preferredDevices
        response.ContainerResponses = append(response.ContainerResponses, containerResp)
        
        klog.Infof("Preferred allocation for container: %v", preferredDevices)
    }
    
    return response, nil
}

func (dp *CustomDevicePlugin) PreStartContainer(context.Context, *pluginapi.PreStartContainerRequest) (*pluginapi.PreStartContainerResponse, error) {
    return &pluginapi.PreStartContainerResponse{}, nil
}

func (dp *CustomDevicePlugin) discoverDevices() error {
    klog.Infof("Discovering %d devices", dp.deviceCount)
    
    for i := 0; i < dp.deviceCount; i++ {
        deviceID := fmt.Sprintf("device-%d", i)
        device := &pluginapi.Device{
            ID:     deviceID,
            Health: pluginapi.Healthy,
            Topology: &pluginapi.TopologyInfo{
                Nodes: []*pluginapi.NUMANode{
                    {
                        ID: int64(i % 2), // Distribute across NUMA nodes
                    },
                },
            },
        }
        dp.devices[deviceID] = device
        
        // Create device file (simulation)
        devicePath := fmt.Sprintf("/dev/hashfoundry-device-%s", deviceID)
        if err := dp.createDeviceFile(devicePath); err != nil {
            klog.Warningf("Failed to create device file %s: %v", devicePath, err)
        }
        
        klog.Infof("Discovered device: %s", deviceID)
    }
    
    return nil
}

func (dp *CustomDevicePlugin) createDeviceFile(devicePath string) error {
    // Create device file for simulation
    file, err := os.Create(devicePath)
    if err != nil {
        return err
    }
    defer file.Close()
    
    // Write device metadata
    metadata := fmt.Sprintf("HashFoundry Custom Device\nCreated: %s\n", time.Now().Format(time.RFC3339))
    _, err = file.WriteString(metadata)
    return err
}

func (dp *CustomDevicePlugin) getDevices() []*pluginapi.Device {
    devices := make([]*pluginapi.Device, 0, len(dp.devices))
    for _, device := range dp.devices {
        devices = append(devices, device)
    }
    return devices
}

func (dp *CustomDevicePlugin) healthMonitor() {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-dp.stop:
            return
        case <-ticker.C:
            dp.checkDeviceHealth()
        }
    }
}

func (dp *CustomDevicePlugin) checkDeviceHealth() {
    for deviceID, device := range dp.devices {
        healthy := dp.isDeviceHealthy(deviceID)
        
        if healthy && device.Health != pluginapi.Healthy {
            device.Health = pluginapi.Healthy
            dp.health <- device
        } else if !healthy && device.Health != pluginapi.Unhealthy {
            device.Health = pluginapi.Unhealthy
            dp.health <- device
        }
    }
}

func (dp *CustomDevicePlugin) isDeviceHealthy(deviceID string) bool {
    devicePath := fmt.Sprintf("/dev/hashfoundry-device-%s", deviceID)
    if _, err := os.Stat(devicePath); err != nil {
        return false
    }
    
    // Additional health checks can be added here
    // For example: check device responsiveness, temperature, etc.
    
    return true
}

func (dp *CustomDevicePlugin) startHealthServer() {
    http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })
    
    http.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
        if len(dp.devices) > 0 {
            w.WriteHeader(http.StatusOK)
            w.Write([]byte("Ready"))
        } else {
            w.WriteHeader(http.StatusServiceUnavailable)
            w.Write([]byte("Not Ready"))
        }
    })
    
    klog.Info("Starting health server on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        klog.Errorf("Health server failed: %v", err)
    }
}

func (dp *CustomDevicePlugin) cleanup() error {
    if err := os.Remove(dp.socket); err != nil && !os.IsNotExist(err) {
        return fmt.Errorf("failed to remove socket %s: %v", dp.socket, err)
    }
    return nil
}

func (dp *CustomDevicePlugin) Stop() error {
    if dp.server != nil {
        dp.server.Stop()
    }
    close(dp.stop)
    return dp.cleanup()
}

func getEnvOrDefault(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getIntEnvOrDefault(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intValue, err := strconv.Atoi(value); err == nil {
            return intValue
        }
    }
    return defaultValue
}
```

### **3. Тестирование Device Plugin:**
```yaml
# test-device-usage.yaml
apiVersion: v1
kind: Pod
metadata:
  name: device-test-single
  namespace: device-plugin-system
  labels:
    app: device-test
spec:
  containers:
  - name: test-container
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== HashFoundry Device Test ==="
      echo "Environment variables:"
      env | grep HASHFOUNDRY
      echo ""
      echo "Device files:"
      ls -la /dev/hashfoundry-device-* 2>/dev/null || echo "No device files found"
      echo ""
      echo "Device content:"
      for device in /dev/hashfoundry-device-*; do
        if [ -f "$device" ]; then
          echo "--- $device ---"
          cat "$device"
        fi
      done
      echo ""
      echo "Sleeping for monitoring..."
      sleep 3600
    resources:
      limits:
        hashfoundry.com/custom-device: 1
      requests:
        hashfoundry.com/custom-device: 1
  restartPolicy: Never

---
# Multi-device test
apiVersion: v1
kind: Pod
metadata:
  name: device-test-multi
  namespace: device-plugin-system
  labels:
    app: device-test
spec:
  containers:
  - name: test-container
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Multi-Device Test ==="
      echo "Allocated devices: $HASHFOUNDRY_DEVICE_COUNT"
      echo "Device ID: $HASHFOUNDRY_DEVICE_ID"
      echo ""
      echo "Available devices:"
      ls -la /dev/hashfoundry-device-*
      echo ""
      echo "Testing device access..."
      for device in /dev/hashfoundry-device-*; do
        if [ -f "$device" ]; then
          echo "Testing $device..."
          cat "$device" | head -2
        fi
      done
      sleep 3600
    resources:
      limits:
        hashfoundry.com/custom-device: 2
      requests:
        hashfoundry.com/custom-device: 2
  restartPolicy: Never

---
# Deployment with device usage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: device-workload
  namespace: device-plugin-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: device-workload
  template:
    metadata:
      labels:
        app: device-workload
    spec:
      containers:
      - name: workload
        image: nginx:1.21
        resources:
          limits:
            hashfoundry.com/custom-device: 1
          requests:
            hashfoundry.com/custom-device: 1
            cpu: 100m
            memory: 128Mi
        env:
        - name: DEVICE_ID
          value: "$(HASHFOUNDRY_DEVICE_ID)"
        volumeMounts:
        - name: device-info
          mountPath: /usr/share/nginx/html/device
        lifecycle:
          postStart:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                echo "Device allocated: $HASHFOUNDRY_DEVICE_ID" > /usr/share/nginx/html/device/info.txt
                echo "Allocation time: $(date)" >> /usr/share/nginx/html/device/info.txt
      volumes:
      - name: device-info
        emptyDir: {}
```

## 🏭 **Интеграция с ArgoCD и мониторингом:**

### **1. ArgoCD Application для Device Plugin:**
```yaml
# argocd-device-plugin-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: custom-device-plugin
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/custom-device-plugin
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: device-plugin-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### **2. Prometheus мониторинг для Device Plugins:**
```yaml
# device-plugin-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: custom-device-plugin
  namespace: device-plugin-system
spec:
  selector:
    matchLabels:
      app: custom-device-plugin
  endpoints:
  - port: health
    path: /metrics
    interval: 30s

---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: device-plugin-alerts
  namespace: device-plugin-system
spec:
  groups:
  - name: device-plugin.rules
    rules:
    - alert: DevicePluginDown
      expr: up{job="custom-device-plugin"} == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Device plugin is down"
        description: "Custom device plugin has been down for more than 2 minutes"
    
    - alert: DeviceUnhealthy
      expr: kubelet_device_plugin_resource_capacity{resource="hashfoundry.com/custom-device"} != kubelet_device_plugin_resource_allocatable{resource="hashfoundry.com/custom-device"}
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Unhealthy devices detected"
        description: "Some custom devices are marked as unhealthy"
    
    - alert: DeviceAllocationHigh
      expr: (kubelet_device_plugin_resource_capacity{resource="hashfoundry.com/custom-device"} - kubelet_device_plugin_resource_allocatable{resource="hashfoundry.com/custom-device"}) / kubelet_device_plugin_resource_capacity{resource="hashfoundry.com/custom-device"} > 0.8
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High device allocation"
        description: "More than 80% of custom devices are allocated"
```

### **3. Grafana Dashboard для Device Plugins:**
```json
{
  "dashboard": {
    "title": "HashFoundry Device Plugin Dashboard",
    "panels": [
      {
        "title": "Device Plugin Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"custom-device-plugin\"}",
            "legendFormat": "Plugin Status"
          }
        ]
      },
      {
        "title": "Device Capacity vs Allocatable",
        "type": "graph",
        "targets": [
          {
            "expr": "kubelet_device_plugin_resource_capacity{resource=\"hashfoundry.com/custom-device\"}",
            "legendFormat": "Capacity - {{node}}"
          },
          {
            "expr": "kubelet_device_plugin_resource_allocatable{resource=\"hashfoundry.com/custom-device\"}",
            "legendFormat": "Allocatable - {{node}}"
          }
        ]
      },
      {
        "title": "Device Allocation Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(kubelet_device_plugin_alloc_duration_seconds_count[5m])",
            "legendFormat": "Allocations/sec - {{node}}"
          }
        ]
      }
    ]
  }
}
```

### **4. Тестирование и диагностика Device Plugins:**
```bash
#!/bin/bash
# test-device-plugins.sh

echo "🧪 Testing Device Plugins"

test_device_plugin_registration() {
    echo "=== Testing Device Plugin Registration ==="
    
    # Check device plugin registration
    kubectl get nodes -o json | jq '.items[] | {
        name: .metadata.name,
        capacity: .status.capacity,
        allocatable: .status.allocatable
    }' | grep -A 5 -B 5 "hashfoundry.com/custom-device"
    
    # Check device plugin sockets
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        echo "--- Node: $node ---"
        kubectl debug node/$node -it --image=busybox -- \
            ls -la /host/var/lib/kubelet/device-plugins/ | grep hashfoundry || \
            echo "No HashFoundry device plugin socket found"
    done
}

test_device_allocation() {
    echo "=== Testing Device Allocation ==="
    
    # Create test pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: device-allocation-test
  namespace: device-plugin-system
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ["sleep", "300"]
    resources:
      limits:
        hashfoundry.com/custom-device: 1
      requests:
        hashfoundry.com/custom-device: 1
  restartPolicy: Never
EOF

    # Wait for pod to be scheduled
    kubectl wait --for=condition=Ready pod/device-allocation-test -n device-plugin-system --timeout=60s
    
    # Check device allocation
    kubectl describe pod device-allocation-test -n device-plugin-system | grep -A 10 "Environment\|Mounts"
    
    # Check device files in container
    kubectl exec device-allocation-test -n device-plugin-system -- ls -la /dev/hashfoundry-device-*
    
    # Cleanup
    kubectl delete pod device-allocation-test -n device-plugin-system
}

check_device_plugin_health() {
    echo "=== Device Plugin Health Check ==="
    
    # Check device plugin pods
    kubectl get pods -n device-plugin-system -l app=custom-device-plugin
    
    # Check device plugin logs
    kubectl logs -n device-plugin-system -l app=custom-device-plugin --tail=20
    
    # Check device plugin health endpoint
    kubectl port-forward -n device-plugin-system svc/custom-device-plugin 8080:8080 &
    PF_PID=$!
    
    sleep 2
    curl -f http://localhost:8080/healthz && echo "✅ Health check passed" || echo "❌ Health check failed"
    curl -f http://localhost:8080/readyz && echo "✅ Ready check passed" || echo "❌ Ready check failed"
    
    kill $PF_PID
}

monitor_device_metrics() {
    echo "=== Device Plugin Metrics ==="
    
    # Port forward to Prometheus
    kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &
    PROM_PID=$!
    
    sleep 2
    
    # Query device plugin metrics
    echo "Device plugin registration count:"
    curl -s "http://localhost:9090/api/v1/query?query=kubelet_device_plugin_registration_total" | \
        jq -r '.data.result[] | "\(.metric.node): \(.value[1])"'
    
    echo ""
    echo "Device allocation duration:"
    curl -s "http://localhost:9090/api/v1/query?query=kubelet_device_plugin_alloc_duration_seconds" | \
        jq -r '.data.result[] | "\(.metric.node): \(.value[1])s"'
    
    kill $PROM_PID
}

main() {
    test_device_plugin_registration
    echo ""
    test_device_allocation
    echo ""
    check_device_plugin_health
    echo ""
    monitor_device_metrics
}

main "$@"
```

## 🚨 **Troubleshooting Device Plugins:**

### **1. Диагностический скрипт:**
```bash
#!/bin/bash
# diagnose-device-plugins.sh

echo "🔍 Diagnosing Device Plugins"

diagnose_kubelet_device_manager() {
    echo "=== Kubelet Device Manager Diagnosis ==="
    
    # Check kubelet logs for device plugin activity
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        echo "--- Node: $node ---"
        kubectl debug node/$node -it --image=busybox -- \
            grep -i "device.*plugin\|device.*manager" /host/var/log/kubelet.log | tail -10
    done
}

check_device_plugin_sockets() {
    echo "=== Device Plugin Sockets Check ==="
    
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        echo "--- Node: $node ---"
        kubectl debug node/$node -it --image=busybox -- \
            find /host/var/lib/kubelet/device-plugins/ -name "*.sock" -ls
    done
}

verify_device_files() {
    echo "=== Device Files Verification ==="
    
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        echo "--- Node: $node ---"
        kubectl debug node/$node -it --image=busybox -- \
            ls -la /host/dev/hashfoundry-device-* 2>/dev/null || \
            echo "No HashFoundry device files found"
    done
}

check_extended_resources() {
    echo "=== Extended Resources Check ==="
    
    kubectl get nodes -o json | jq '.items[] | {
        name: .metadata.name,
        capacity: .status.capacity | to_entries | map(select(.key | contains("hashfoundry.com"))),
        allocatable: .status.allocatable | to_entries | map(select(.key | contains("hashfoundry.com")))
    }'
}

analyze_pod_allocation_failures() {
    echo "=== Pod Allocation Failures Analysis ==="
    
    # Check for pods with device resource requests that are pending
    kubectl get pods --all-namespaces -o json | jq -r '
        .items[] | 
        select(.status.phase == "Pending") |
        select(.spec.containers[].resources.limits | has("hashfoundry.com/custom-device")) |
        "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[-1].message // "No message")"
    '
    
    # Check events related to device allocation
    kubectl get events --all-namespaces --field-selector reason=FailedScheduling | \
        grep -i "device\|resource"
}

main() {
    diagnose_kubelet_device_manager
    echo ""
    check_device_plugin_sockets
    echo ""
    verify_device_files
    echo ""
    check_extended_resources
    echo ""
    analyze_pod_allocation_failures
}

main "$@"
```

### **2. Device Plugin Lifecycle Management:**
```bash
#!/bin/bash
# device-plugin-lifecycle.sh

echo "🔄 Device Plugin Lifecycle Management"

deploy_device_plugin() {
    echo "=== Deploying Device Plugin ==="
    
    # Label nodes for device plugin
    kubectl label nodes --all hashfoundry.com/custom-device=enabled --overwrite
    
    # Deploy device plugin DaemonSet
    kubectl apply -f custom-device-plugin.yaml
    
    # Wait for device plugin to be ready
    kubectl rollout status daemonset/custom-device-plugin -n device-plugin-system --timeout=300s
    
    # Verify device plugin registration
    sleep 10
    kubectl get nodes -o json | jq '.items[0].status.allocatable' | grep hashfoundry.com
}

update_device_plugin() {
    echo "=== Updating Device Plugin ==="
    
    # Update device plugin image
    kubectl set image daemonset/custom-device-plugin -n device-plugin-system \
        device-plugin=hashfoundry/custom-device-plugin:v1.1.0
    
    # Monitor rollout
    kubectl rollout status daemonset/custom-device-plugin -n device-plugin-system
    
    # Verify update
    kubectl get pods -n device-plugin-system -l app=custom-device-plugin \
        -o jsonpath='{.items[*].spec.containers[0].image}'
}

restart_device_plugin() {
    echo "=== Restarting Device Plugin ==="
    
    # Restart device plugin pods
    kubectl rollout restart daemonset/custom-device-plugin -n device-plugin-system
    
    # Wait for restart to complete
    kubectl rollout status daemonset/custom-device-plugin -n device-plugin-system
    
    # Verify device resources are still available
    kubectl get nodes -o json | jq '.items[].status.allocatable' | grep hashfoundry.com
}

cleanup_device_plugin() {
    echo "=== Cleaning up Device Plugin ==="
    
    # Delete device plugin DaemonSet
    kubectl delete daemonset custom-device-plugin -n device-plugin-system
    
    # Remove node labels
    kubectl label nodes --all hashfoundry.com/custom-device-
    
    # Clean up device files on nodes
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        kubectl debug node/$node -it --image=busybox -- \
            rm -f /host/dev/hashfoundry-device-*
    done
    
    # Verify cleanup
    kubectl get nodes -o json | jq '.items[].status.allocatable' | grep hashfoundry.com || \
        echo "✅ Device resources cleaned up successfully"
}

main() {
    case "${1:-deploy}" in
        deploy)
            deploy_device_plugin
            ;;
        update)
            update_device_plugin
            ;;
        restart)
            restart_device_plugin
            ;;
        cleanup)
            cleanup_device_plugin
            ;;
        *)
            echo "Usage: $0 {deploy|update|restart|cleanup}"
            exit 1
            ;;
    esac
}

main "$@"
```

## 🎯 **Архитектура Device Plugins в HA кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│              HA Cluster Device Plugins Architecture        │
├─────────────────────────────────────────────────────────────┤
│  Application Pods                                          │
│  ├── ML Workloads (GPU requests)                           │
│  ├── Network Functions (SR-IOV)                            │
│  ├── Storage Accelerators (NVMe)                           │
│  └── Custom Hardware (HashFoundry devices)                 │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes API Server (HA)                               │
│  ├── Extended Resource Advertisement                       │
│  ├── Pod Scheduling with Device Constraints                │
│  ├── Resource Quota Management                             │
│  └── RBAC for Device Access                                │
├─────────────────────────────────────────────────────────────┤
│  Worker Nodes (Auto-scaling 3-6 nodes)                    │
│  ├── Node 1                                                │
│  │   ├── kubelet (Device Manager)                          │
│  │   ├── Device Plugin DaemonSet                           │
│  │   ├── Container Runtime (device mounting)               │
│  │   └── Hardware Devices (/dev/*)                         │
│  ├── Node 2                                                │
│  │   ├── kubelet (Device Manager)                          │
│  │   ├── Device Plugin DaemonSet                           │
│  │   ├── Container Runtime (device mounting)               │
│  │   └── Hardware Devices (/dev/*)                         │
│  └── Node N...                                             │
├─────────────────────────────────────────────────────────────┤
│  Device Plugin Communication                               │
│  ├── gRPC Registration (plugin → kubelet)                  │
│  ├── Unix Socket (/var/lib/kubelet/device-plugins/)        │
│  ├── ListAndWatch Stream (device health)                   │
│  ├── Allocate Requests (device assignment)                 │
│  └── Health Monitoring (device status)                     │
├─────────────────────────────────────────────────────────────┤
│  Monitoring & Observability                               │
│  ├── Prometheus (device plugin metrics)                    │
│  ├── Grafana (device utilization dashboards)              │
│  ├── AlertManager (device failure alerts)                  │
│  └── Logs (device plugin + kubelet)                        │
├─────────────────────────────────────────────────────────────┤
│  Hardware Layer                                           │
│  ├── GPU Cards (NVIDIA/AMD)                                │
│  ├── FPGA Accelerators                                     │
│  ├── Network Devices (SR-IOV)                              │
│  ├── Storage Devices (NVMe)                                │
│  └── Custom Hardware (HashFoundry devices)                 │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для Device Plugins:**

### **1. Разработка Device Plugins:**
- Реализуйте все обязательные gRPC методы (ListAndWatch, Allocate)
- Используйте health monitoring для отслеживания состояния устройств
- Поддерживайте NUMA topology awareness для оптимальной производительности
- Реализуйте graceful shutdown и cleanup процедуры

### **2. Deployment и Operations:**
- Развертывайте device plugins как DaemonSet на всех узлах с устройствами
- Используйте nodeSelector для ограничения deployment только на узлы с hardware
- Настройте proper RBAC permissions для device plugin pods
- Мониторьте device plugin health и registration status

### **3. Безопасность:**
- Используйте минимальные привилегии для device plugin containers
- Ограничьте доступ к device files через proper permissions
- Валидируйте device allocation requests
- Логируйте все device operations для аудита

### **4. Производительность и надежность:**
- Оптимизируйте device discovery и health check intervals
- Реализуйте efficient device allocation algorithms
- Используйте device topology information для NUMA-aware scheduling
- Настройте proper resource limits для device plugin pods

### **5. Мониторинг и troubleshooting:**
- Экспортируйте device plugin metrics в Prometheus
- Настройте алерты для device failures и allocation issues
- Логируйте device allocation и deallocation events
- Мониторьте device utilization и performance metrics

**Device Plugins — это мощный механизм для интеграции специализированного hardware в Kubernetes кластер с полной поддержкой scheduling, isolation и monitoring!**
