# 198. What are device plugins and how do they work?

## 🎯 Вопрос
What are device plugins and how do they work?

## 💡 Ответ

Device Plugins - это механизм в Kubernetes, который позволяет подам использовать специализированные аппаратные ресурсы (GPU, FPGA, InfiniBand, специальные сетевые устройства) без изменения основного кода Kubernetes. Они работают через gRPC API и регистрируют свои ресурсы в kubelet.

### 🏗️ Архитектура Device Plugins

#### 1. **Схема Device Plugin Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                Device Plugin Architecture                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Pod Layer                           │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │     Pod     │    │     Pod     │    │     Pod     │ │ │
│  │  │  (GPU App)  │───▶│ (FPGA App)  │───▶│ (Custom HW) │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    kubelet                             │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Device    │    │  Resource   │    │   Pod       │ │ │
│  │  │  Manager    │───▶│  Manager    │───▶│  Manager    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Device Plugin gRPC                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │Registration │    │   Device    │    │   Health    │ │ │
│  │  │   Service   │───▶│   Service   │───▶│  Monitoring │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Device Plugin Implementations            │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    NVIDIA   │    │    Intel    │    │   Custom    │ │ │
│  │  │ GPU Plugin  │───▶│ FPGA Plugin │───▶│ HW Plugin   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Hardware Layer                          │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    GPU      │    │    FPGA     │    │  Network    │ │ │
│  │  │  Hardware   │───▶│  Hardware   │───▶│  Hardware   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Device Plugin API и Workflow**
```yaml
# Device Plugin API and Workflow
device_plugin_api:
  registration_service:
    purpose: "Register device plugin with kubelet"
    endpoint: "/var/lib/kubelet/device-plugins/kubelet.sock"
    method: "Register"
    parameters:
      - "version: v1beta1"
      - "endpoint: plugin socket path"
      - "resourceName: vendor-domain/resource"
      - "options: plugin options"
    
    workflow:
      - "Plugin creates Unix socket"
      - "Plugin calls Register on kubelet"
      - "kubelet validates registration"
      - "kubelet starts monitoring plugin"

  device_service:
    purpose: "Manage device lifecycle"
    methods:
      list_and_watch:
        description: "Stream available devices"
        returns: "List of Device objects"
        monitoring: "Continuous device health"
      
      allocate:
        description: "Allocate devices to container"
        input: "AllocateRequest with device IDs"
        output: "AllocateResponse with env vars, mounts"
        
      get_device_plugin_options:
        description: "Get plugin configuration"
        returns: "DevicePluginOptions"
    
    device_object:
      structure:
        - "ID: unique device identifier"
        - "Health: Healthy/Unhealthy"
        - "Topology: NUMA affinity info"

  kubelet_integration:
    device_manager:
      responsibilities:
        - "Track device plugin registrations"
        - "Monitor device health"
        - "Handle device allocation requests"
        - "Manage device lifecycle"
    
    resource_manager:
      responsibilities:
        - "Advertise device resources to API server"
        - "Track resource usage"
        - "Enforce resource limits"
        - "Handle resource cleanup"
    
    pod_manager:
      responsibilities:
        - "Configure container runtime"
        - "Set environment variables"
        - "Mount device files"
        - "Apply security contexts"

  failure_handling:
    plugin_failure:
      detection: "gRPC connection monitoring"
      response: "Mark devices as unhealthy"
      recovery: "Re-registration on plugin restart"
    
    device_failure:
      detection: "Health monitoring via ListAndWatch"
      response: "Remove device from available pool"
      pod_impact: "Existing pods continue, new pods blocked"
    
    kubelet_restart:
      behavior: "Plugins must re-register"
      socket_cleanup: "Remove stale sockets"
      state_recovery: "Rebuild device state"
```

### 📊 Примеры из нашего кластера

#### Проверка Device Plugins:
```bash
# Проверка доступных device plugins
kubectl get nodes -o json | jq '.items[].status.allocatable'

# Проверка capacity узлов
kubectl describe nodes | grep -A 10 "Capacity\|Allocatable"

# Проверка device plugin sockets
ls -la /var/lib/kubelet/device-plugins/

# Проверка device plugin pods
kubectl get pods --all-namespaces | grep device

# Проверка extended resources
kubectl get nodes -o yaml | grep -A 5 "nvidia.com\|intel.com"
```

### 🛠️ Реализация Device Plugin

#### 1. **Базовая структура Device Plugin**
```go
// device-plugin.go
package main

import (
    "context"
    "fmt"
    "net"
    "os"
    "path/filepath"
    "time"

    "google.golang.org/grpc"
    "k8s.io/klog/v2"
    pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"
)

const (
    resourceName = "example.com/custom-device"
    serverSock   = pluginapi.DevicePluginPath + "custom-device.sock"
    kubeletSock  = pluginapi.KubeletSocket
)

// CustomDevicePlugin implements the device plugin interface
type CustomDevicePlugin struct {
    socket   string
    server   *grpc.Server
    devices  map[string]*pluginapi.Device
    stop     chan interface{}
    health   chan *pluginapi.Device
}

func NewCustomDevicePlugin() *CustomDevicePlugin {
    return &CustomDevicePlugin{
        socket:  serverSock,
        devices: make(map[string]*pluginapi.Device),
        stop:    make(chan interface{}),
        health:  make(chan *pluginapi.Device),
    }
}

func main() {
    klog.Info("Starting Custom Device Plugin")
    
    plugin := NewCustomDevicePlugin()
    
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
    
    // Wait for termination signal
    <-plugin.stop
}

// Start starts the gRPC server
func (dp *CustomDevicePlugin) Start() error {
    // Remove existing socket
    if err := dp.cleanup(); err != nil {
        return err
    }
    
    // Create Unix socket
    sock, err := net.Listen("unix", dp.socket)
    if err != nil {
        return fmt.Errorf("failed to listen on socket %s: %v", dp.socket, err)
    }
    
    // Create gRPC server
    dp.server = grpc.NewServer()
    pluginapi.RegisterDevicePluginServer(dp.server, dp)
    
    // Start server
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

// Register registers the device plugin with kubelet
func (dp *CustomDevicePlugin) Register() error {
    conn, err := grpc.Dial(kubeletSock, grpc.WithInsecure(),
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
        ResourceName: resourceName,
    }
    
    if _, err := client.Register(context.Background(), request); err != nil {
        return fmt.Errorf("failed to register device plugin: %v", err)
    }
    
    klog.Info("Device plugin registered with kubelet")
    return nil
}

// GetDevicePluginOptions returns device plugin options
func (dp *CustomDevicePlugin) GetDevicePluginOptions(context.Context, *pluginapi.Empty) (*pluginapi.DevicePluginOptions, error) {
    return &pluginapi.DevicePluginOptions{
        PreStartRequired:                false,
        GetPreferredAllocationAvailable: false,
    }, nil
}

// ListAndWatch lists devices and updates as they change
func (dp *CustomDevicePlugin) ListAndWatch(e *pluginapi.Empty, s pluginapi.DevicePlugin_ListAndWatchServer) error {
    klog.Info("Starting ListAndWatch")
    
    // Send initial device list
    if err := s.Send(&pluginapi.ListAndWatchResponse{Devices: dp.getDevices()}); err != nil {
        return fmt.Errorf("failed to send device list: %v", err)
    }
    
    // Monitor device health
    for {
        select {
        case <-dp.stop:
            return nil
        case device := <-dp.health:
            // Update device health
            if dev, exists := dp.devices[device.ID]; exists {
                dev.Health = device.Health
                if err := s.Send(&pluginapi.ListAndWatchResponse{Devices: dp.getDevices()}); err != nil {
                    return fmt.Errorf("failed to send device update: %v", err)
                }
            }
        case <-time.After(30 * time.Second):
            // Periodic health check
            dp.checkDeviceHealth()
        }
    }
}

// Allocate allocates devices to a container
func (dp *CustomDevicePlugin) Allocate(ctx context.Context, reqs *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
    klog.Infof("Allocate request: %v", reqs)
    
    responses := &pluginapi.AllocateResponse{}
    
    for _, req := range reqs.ContainerRequests {
        response := &pluginapi.ContainerAllocateResponse{}
        
        // Process each requested device
        for _, deviceID := range req.DevicesIDs {
            device, exists := dp.devices[deviceID]
            if !exists {
                return nil, fmt.Errorf("device %s not found", deviceID)
            }
            
            if device.Health != pluginapi.Healthy {
                return nil, fmt.Errorf("device %s is not healthy", deviceID)
            }
            
            // Add device-specific configuration
            response.Envs = map[string]string{
                "CUSTOM_DEVICE_ID": deviceID,
                "CUSTOM_DEVICE_PATH": fmt.Sprintf("/dev/custom-device-%s", deviceID),
            }
            
            // Add device mounts
            response.Mounts = append(response.Mounts, &pluginapi.Mount{
                ContainerPath: fmt.Sprintf("/dev/custom-device-%s", deviceID),
                HostPath:      fmt.Sprintf("/dev/custom-device-%s", deviceID),
                ReadOnly:      false,
            })
            
            // Add device nodes
            response.Devices = append(response.Devices, &pluginapi.DeviceSpec{
                ContainerPath: fmt.Sprintf("/dev/custom-device-%s", deviceID),
                HostPath:      fmt.Sprintf("/dev/custom-device-%s", deviceID),
                Permissions:   "rw",
            })
        }
        
        responses.ContainerResponses = append(responses.ContainerResponses, response)
    }
    
    return responses, nil
}

// PreStartContainer is called before starting a container (if enabled)
func (dp *CustomDevicePlugin) PreStartContainer(context.Context, *pluginapi.PreStartContainerRequest) (*pluginapi.PreStartContainerResponse, error) {
    return &pluginapi.PreStartContainerResponse{}, nil
}

// GetPreferredAllocation returns preferred device allocation (if enabled)
func (dp *CustomDevicePlugin) GetPreferredAllocation(context.Context, *pluginapi.PreferredAllocationRequest) (*pluginapi.PreferredAllocationResponse, error) {
    return &pluginapi.PreferredAllocationResponse{}, nil
}

// discoverDevices discovers available devices
func (dp *CustomDevicePlugin) discoverDevices() error {
    klog.Info("Discovering devices")
    
    // Simulate device discovery
    // In real implementation, this would scan hardware
    deviceCount := 4
    
    for i := 0; i < deviceCount; i++ {
        deviceID := fmt.Sprintf("device-%d", i)
        device := &pluginapi.Device{
            ID:     deviceID,
            Health: pluginapi.Healthy,
        }
        dp.devices[deviceID] = device
        klog.Infof("Discovered device: %s", deviceID)
    }
    
    return nil
}

// getDevices returns current device list
func (dp *CustomDevicePlugin) getDevices() []*pluginapi.Device {
    devices := make([]*pluginapi.Device, 0, len(dp.devices))
    for _, device := range dp.devices {
        devices = append(devices, device)
    }
    return devices
}

// checkDeviceHealth checks device health
func (dp *CustomDevicePlugin) checkDeviceHealth() {
    for deviceID, device := range dp.devices {
        // Simulate health check
        // In real implementation, this would check actual hardware
        if dp.isDeviceHealthy(deviceID) {
            if device.Health != pluginapi.Healthy {
                device.Health = pluginapi.Healthy
                dp.health <- device
                klog.Infof("Device %s is now healthy", deviceID)
            }
        } else {
            if device.Health != pluginapi.Unhealthy {
                device.Health = pluginapi.Unhealthy
                dp.health <- device
                klog.Infof("Device %s is now unhealthy", deviceID)
            }
        }
    }
}

// isDeviceHealthy checks if device is healthy
func (dp *CustomDevicePlugin) isDeviceHealthy(deviceID string) bool {
    // Simulate health check logic
    // Check if device file exists and is accessible
    devicePath := fmt.Sprintf("/dev/custom-device-%s", deviceID)
    if _, err := os.Stat(devicePath); err != nil {
        return false
    }
    return true
}

// cleanup removes the device plugin socket
func (dp *CustomDevicePlugin) cleanup() error {
    if err := os.Remove(dp.socket); err != nil && !os.IsNotExist(err) {
        return fmt.Errorf("failed to remove socket %s: %v", dp.socket, err)
    }
    return nil
}

// Stop stops the device plugin
func (dp *CustomDevicePlugin) Stop() error {
    if dp.server != nil {
        dp.server.Stop()
    }
    close(dp.stop)
    return dp.cleanup()
}
```

#### 2. **Device Plugin Deployment**
```yaml
# device-plugin-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: custom-device-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: custom-device-plugin
  template:
    metadata:
      labels:
        name: custom-device-plugin
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      serviceAccountName: custom-device-plugin
      hostNetwork: true
      hostPID: true
      containers:
      - name: custom-device-plugin
        image: example/custom-device-plugin:v1.0.0
        command: ["/usr/bin/custom-device-plugin"]
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          privileged: true
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: dev
          mountPath: /dev
        - name: sys
          mountPath: /sys
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
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
      nodeSelector:
        custom-device: "true"

---
# RBAC for device plugin
apiVersion: v1
kind: ServiceAccount
metadata:
  name: custom-device-plugin
  namespace: kube-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom-device-plugin
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: custom-device-plugin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: custom-device-plugin
subjects:
- kind: ServiceAccount
  name: custom-device-plugin
  namespace: kube-system
```

#### 3. **Использование Device Plugin в Pod**
```yaml
# test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-device-test
spec:
  containers:
  - name: test-container
    image: ubuntu:20.04
    command: ["/bin/bash"]
    args: ["-c", "while true; do echo 'Using custom device'; sleep 30; done"]
    resources:
      limits:
        example.com/custom-device: 1
      requests:
        example.com/custom-device: 1
    env:
    - name: CUSTOM_DEVICE_ID
      value: "will-be-set-by-device-plugin"
  restartPolicy: Never

---
# multi-device-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-device-test
spec:
  containers:
  - name: container1
    image: ubuntu:20.04
    command: ["/bin/bash"]
    args: ["-c", "echo 'Container 1 using device'; sleep infinity"]
    resources:
      limits:
        example.com/custom-device: 1
  - name: container2
    image: ubuntu:20.04
    command: ["/bin/bash"]
    args: ["-c", "echo 'Container 2 using device'; sleep infinity"]
    resources:
      limits:
        example.com/custom-device: 2
  restartPolicy: Never
```

### 🔧 Утилиты для тестирования Device Plugins

#### Скрипт для тестирования device plugins:
```bash
#!/bin/bash
# test-device-plugins.sh

echo "🧪 Testing Device Plugins"

# Test device plugin registration
test_device_plugin_registration() {
    echo "=== Testing Device Plugin Registration ==="
    
    # Check if device plugin is running
    echo "--- Device Plugin Pods ---"
    kubectl get pods -n kube-system -l name=custom-device-plugin
    
    # Check device plugin logs
    echo "--- Device Plugin Logs ---"
    kubectl logs -n kube-system -l name=custom-device-plugin --tail=10
    
    # Check node capacity
    echo "--- Node Capacity ---"
    kubectl get nodes -o json | jq '.items[].status.capacity | select(."example.com/custom-device")'
}

# Test device allocation
test_device_allocation() {
    echo "=== Testing Device Allocation ==="
    
    # Create test pod
    echo "--- Creating test pod ---"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: device-test-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "env | grep CUSTOM_DEVICE; ls -la /dev/custom-device-*; sleep 3600"]
    resources:
      limits:
        example.com/custom-device: 1
  restartPolicy: Never
EOF

    # Wait for pod to be scheduled
    echo "Waiting for pod to be scheduled..."
    kubectl wait --for=condition=PodScheduled pod/device-test-pod --timeout=60s
    
    if [ $? -eq 0 ]; then
        echo "✅ Pod scheduled successfully"
        
        # Check pod status
        kubectl get pod device-test-pod -o wide
        
        # Check environment variables
        echo "--- Environment Variables ---"
        kubectl exec device-test-pod -- env | grep CUSTOM_DEVICE || echo "No custom device env vars found"
        
        # Check device mounts
        echo "--- Device Mounts ---"
        kubectl exec device-test-pod -- ls -la /dev/ | grep custom-device || echo "No custom devices found"
    else
        echo "❌ Pod scheduling failed"
        kubectl describe pod device-test-pod
    fi
}

# Test device health monitoring
test_device_health() {
    echo "=== Testing Device Health Monitoring ==="
    
    # Get device plugin pod
    plugin_pod=$(kubectl get pods -n kube-system -l name=custom-device-plugin -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$plugin_pod" ]; then
        echo "--- Device Plugin Health Logs ---"
        kubectl logs -n kube-system $plugin_pod | grep -i "health\|device" | tail -10
    else
        echo "❌ Device plugin pod not found"
    fi
}

# Test multiple device allocation
test_multiple_devices() {
    echo "=== Testing Multiple Device Allocation ==="
    
    # Create pod requesting multiple devices
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-device-test
spec:
  containers:
  - name: test
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "echo 'Allocated devices:'; env | grep CUSTOM_DEVICE; ls -la /dev/custom-device-*; sleep 3600"]
    resources:
      limits:
        example.com/custom-device: 2
  restartPolicy: Never
EOF

    # Wait for pod
    kubectl wait --for=condition=PodScheduled pod/multi-device-test --timeout=60s
    
    if [ $? -eq 0 ]; then
        echo "✅ Multi-device pod scheduled"
        kubectl exec multi-device-test -- ls -la /dev/ | grep custom-device | wc -l
    else
        echo "❌ Multi-device pod scheduling failed"
    fi
}

# Test device plugin failure scenarios
test_failure_scenarios() {
    echo "=== Testing Failure Scenarios ==="
    
    # Scale down device plugin
    echo "--- Scaling down device plugin ---"
    kubectl scale daemonset custom-device-plugin -n kube-system --replicas=0
    
    # Wait for pods to terminate
    sleep 10
    
    # Try to create pod (should fail or remain pending)
    echo "--- Attempting to create pod without device plugin ---"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: failure-test-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    resources:
      limits:
        example.com/custom-device: 1
  restartPolicy: Never
EOF

    # Check pod status
    sleep 5
    status=$(kubectl get pod failure-test-pod -o jsonpath='{.status.phase}')
    if [ "$status" = "Pending" ]; then
        echo "✅ Pod correctly pending without device plugin"
    else
        echo "❌ Unexpected pod status: $status"
    fi
    
    # Scale device plugin back up
    echo "--- Scaling device plugin back up ---"
    kubectl scale daemonset custom-device-plugin -n kube-system --replicas=1
    
    # Wait for device plugin to be ready
    kubectl wait --for=condition=ready pod -l name=custom-device-plugin -n kube-system --timeout=60s
}

# Performance testing
test_performance() {
    echo "=== Testing Performance ==="
    
    local count=${1:-5}
    echo "Creating $count pods with device requests..."
    
    start_time=$(date +%s)
    
    for i in $(seq 1 $count); do
        cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: perf-test-$i
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "60"]
    resources:
      limits:
        example.com/custom-device: 1
  restartPolicy: Never
EOF
    done
    
    # Wait for all pods to be scheduled
    for i in $(seq 1 $count); do
        kubectl wait --for=condition=PodScheduled pod/perf-test-$i --timeout=30s >/dev/null 2>&1
    done
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "✅ Scheduled $count pods in ${duration}s"
    
    # Check how many were actually scheduled
    scheduled=$(kubectl get pods -l app=perf-test --field-selector=status.phase=Running --no-headers | wc -l)
    echo "Pods running: $scheduled/$count"
    
    # Cleanup
    for i in $(seq 1 $count); do
        kubectl delete pod perf-test-$i >/dev/null 2>&1
    done
}

# Cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up Test Resources ==="
    
    kubectl delete pod device-test-pod --ignore-not-found=true
    kubectl delete pod multi-device-test --ignore-not-found=true
    kubectl delete pod failure-test-pod --ignore-not-found=true
    
    echo "✅ Cleanup completed"
}

# Main execution
main() {
    echo "Testing Device Plugins"
    echo ""
    
    # Run tests
    test_device_plugin_registration
    echo ""
    
    test_device_allocation
    echo ""
    
    test_device_health
    echo ""
    
    test_multiple_devices
    echo ""
    
    test_failure_scenarios
    echo ""
    
    test_performance 3
    echo ""
    
    read -p "Cleanup test resources? (y/n): " cleanup
    if [ "$cleanup" = "y" ]; then
        cleanup_test_resources
    fi
}

# Check if arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0"
    echo ""
    echo "Running device plugin tests..."
    main
else
    main "$@"
fi
```

### 🎯 Заключение

Device Plugins предоставляют стандартизированный способ интеграции специализированного оборудования с Kubernetes:

**Ключевые возможности:**
1. **Стандартный API** - единый интерфейс для всех типов устройств
2. **Автоматическое обнаружение** - kubelet автоматически обнаруживает и регистрирует устройства
3. **Мониторинг здоровья** - непрерывный контроль состояния устройств
4. **Изоляция ресурсов** - гарантированное выделение устройств подам

**Архитектурные принципы:**
1. **gRPC коммуникация** - надежный протокол взаимодействия с kubelet
2. **Unix сокеты** - локальная коммуникация через файловую систему
3. **Отказоустойчивость** - автоматическое восстановление при сбоях
4. **Расширяемость** - поддержка любых типов устройств

**Практические применения:**
- **NVIDIA GPU Plugin** - использование GPU для ML/AI нагрузок
- **Intel FPGA Plugin** - программируемые логические устройства
- **SR-IOV Plugin** - высокопроизводительные сетевые интерфейсы
- **Custom Hardware** - специализированные устройства

Device Plugins обеспечивают гибкую и масштабируемую интеграцию аппаратных ресурсов в Kubernetes экосистему.
