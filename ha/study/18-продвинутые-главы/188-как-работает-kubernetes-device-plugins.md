# 188. Как работает Kubernetes Device Plugins?

## 🎯 Вопрос
Как работает Kubernetes Device Plugins?

## 💡 Ответ

Kubernetes Device Plugins - это механизм, который позволяет кластеру Kubernetes обнаруживать, рекламировать и выделять специализированные аппаратные ресурсы (GPU, FPGA, InfiniBand, специальные сетевые устройства) для Pod'ов. Device Plugins работают как DaemonSet и взаимодействуют с kubelet через gRPC API для управления жизненным циклом устройств.

### 🏗️ Архитектура Device Plugins

#### 1. **Схема Device Plugin Framework**
```
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes Device Plugin Framework          │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Pod Specification                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Resource  │    │   Limits &  │    │   Device    │ │ │
│  │  │   Request   │───▶│   Requests  │───▶│ Allocation  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                      Kubelet                           │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Device    │    │   Resource  │    │   Container │ │ │
│  │  │  Manager    │───▶│  Allocation │───▶│   Runtime   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Device Plugin gRPC                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Registration│    │   Device    │    │  Allocation │ │ │
│  │  │   Service   │───▶│   Service   │───▶│   Service   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  Device Plugin                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Device    │    │   Health    │    │   Resource  │ │ │
│  │  │ Discovery   │───▶│ Monitoring  │───▶│ Management  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Hardware Devices                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │     GPU     │    │    FPGA     │    │ InfiniBand  │ │ │
│  │  │   Devices   │    │   Devices   │    │   Devices   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Device Plugin Lifecycle**
```yaml
# Device Plugin Lifecycle
device_plugin_lifecycle:
  registration_phase:
    description: "Регистрация device plugin в kubelet"
    steps:
      - "Plugin starts and creates gRPC server"
      - "Plugin registers with kubelet via Registration service"
      - "Kubelet validates plugin and adds to device manager"
      - "Plugin starts advertising devices"
    
  discovery_phase:
    description: "Обнаружение и инвентаризация устройств"
    steps:
      - "Plugin scans system for devices"
      - "Plugin creates device list with IDs and health status"
      - "Plugin reports devices to kubelet via ListAndWatch"
      - "Kubelet updates node capacity and allocatable resources"
    
  allocation_phase:
    description: "Выделение устройств для Pod'ов"
    steps:
      - "Scheduler finds node with required devices"
      - "Kubelet calls Allocate on device plugin"
      - "Plugin returns device-specific environment variables"
      - "Container runtime configures container with devices"
    
  monitoring_phase:
    description: "Мониторинг здоровья устройств"
    steps:
      - "Plugin continuously monitors device health"
      - "Plugin reports unhealthy devices to kubelet"
      - "Kubelet updates device availability"
      - "Unhealthy devices excluded from scheduling"

# Device Plugin gRPC Services
grpc_services:
  registration_service:
    endpoint: "/var/lib/kubelet/device-plugins/kubelet.sock"
    methods:
      - "Register(RegisterRequest) returns (Empty)"
    
  device_service:
    endpoint: "unix:///var/lib/kubelet/device-plugins/{resource-name}.sock"
    methods:
      - "GetDevicePluginOptions() returns (DevicePluginOptions)"
      - "ListAndWatch(Empty) returns (stream ListAndWatchResponse)"
      - "Allocate(AllocateRequest) returns (AllocateResponse)"
      - "GetPreferredAllocation(PreferredAllocationRequest) returns (PreferredAllocationResponse)"
      - "PreStartContainer(PreStartContainerRequest) returns (PreStartContainerResponse)"
```

### 📊 Примеры из нашего кластера

#### Проверка device plugins:
```bash
# Проверка device plugins на узлах
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, capacity: .status.capacity, allocatable: .status.allocatable}'

# Проверка extended resources
kubectl describe nodes | grep -A 10 "Capacity:\|Allocatable:"

# Проверка device plugin pods
kubectl get pods --all-namespaces -l app=nvidia-device-plugin

# Проверка device plugin logs
kubectl logs -n kube-system -l app=nvidia-device-plugin
```

### 🔧 Создание Custom Device Plugin

#### 1. **GPU Device Plugin Example**
```go
// gpu-device-plugin.go
package main

import (
    "context"
    "fmt"
    "log"
    "net"
    "os"
    "path/filepath"
    "time"
    
    "google.golang.org/grpc"
    pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"
)

const (
    resourceName = "example.com/gpu"
    serverSock   = pluginapi.DevicePluginPath + "gpu.sock"
    kubeletSock  = pluginapi.KubeletSocket
)

// GPUDevicePlugin представляет наш GPU device plugin
type GPUDevicePlugin struct {
    socket   string
    server   *grpc.Server
    devices  map[string]*pluginapi.Device
    stop     chan interface{}
    health   chan *pluginapi.Device
}

// NewGPUDevicePlugin создает новый GPU device plugin
func NewGPUDevicePlugin() *GPUDevicePlugin {
    return &GPUDevicePlugin{
        socket:  serverSock,
        devices: make(map[string]*pluginapi.Device),
        stop:    make(chan interface{}),
        health:  make(chan *pluginapi.Device),
    }
}

// Start запускает device plugin
func (m *GPUDevicePlugin) Start() error {
    // Обнаружение GPU устройств
    if err := m.discoverGPUs(); err != nil {
        return fmt.Errorf("failed to discover GPUs: %v", err)
    }
    
    // Запуск gRPC сервера
    if err := m.serve(); err != nil {
        return fmt.Errorf("failed to start gRPC server: %v", err)
    }
    
    // Регистрация в kubelet
    if err := m.register(); err != nil {
        return fmt.Errorf("failed to register with kubelet: %v", err)
    }
    
    // Запуск мониторинга здоровья
    go m.healthCheck()
    
    return nil
}

// discoverGPUs обнаруживает GPU устройства в системе
func (m *GPUDevicePlugin) discoverGPUs() error {
    // В реальной реализации здесь будет обращение к NVIDIA ML API,
    // AMD ROCm API или другим системным API для обнаружения GPU
    
    // Симуляция обнаружения GPU устройств
    gpuDevices := []string{"gpu0", "gpu1", "gpu2", "gpu3"}
    
    for _, id := range gpuDevices {
        device := &pluginapi.Device{
            ID:     id,
            Health: pluginapi.Healthy,
        }
        m.devices[id] = device
    }
    
    log.Printf("Discovered %d GPU devices", len(m.devices))
    return nil
}

// serve запускает gRPC сервер
func (m *GPUDevicePlugin) serve() error {
    // Удаление существующего socket файла
    os.Remove(m.socket)
    
    // Создание Unix socket
    sock, err := net.Listen("unix", m.socket)
    if err != nil {
        return err
    }
    
    // Создание gRPC сервера
    m.server = grpc.NewServer()
    pluginapi.RegisterDevicePluginServer(m.server, m)
    
    // Запуск сервера в отдельной горутине
    go func() {
        if err := m.server.Serve(sock); err != nil {
            log.Printf("gRPC server error: %v", err)
        }
    }()
    
    // Ожидание готовности сервера
    conn, err := grpc.Dial(m.socket, grpc.WithInsecure(), grpc.WithBlock(),
        grpc.WithTimeout(5*time.Second),
        grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
            return net.DialTimeout("unix", addr, timeout)
        }))
    if err != nil {
        return err
    }
    conn.Close()
    
    log.Printf("gRPC server started at %s", m.socket)
    return nil
}

// register регистрирует device plugin в kubelet
func (m *GPUDevicePlugin) register() error {
    conn, err := grpc.Dial(kubeletSock, grpc.WithInsecure(),
        grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
            return net.DialTimeout("unix", addr, timeout)
        }))
    if err != nil {
        return err
    }
    defer conn.Close()
    
    client := pluginapi.NewRegistrationClient(conn)
    
    request := &pluginapi.RegisterRequest{
        Version:      pluginapi.Version,
        Endpoint:     filepath.Base(m.socket),
        ResourceName: resourceName,
        Options: &pluginapi.DevicePluginOptions{
            PreStartRequired:                false,
            GetPreferredAllocationAvailable: true,
        },
    }
    
    _, err = client.Register(context.Background(), request)
    if err != nil {
        return err
    }
    
    log.Printf("Registered device plugin with kubelet")
    return nil
}

// healthCheck мониторит здоровье устройств
func (m *GPUDevicePlugin) healthCheck() {
    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            // Проверка здоровья каждого устройства
            for id, device := range m.devices {
                if m.isDeviceHealthy(id) {
                    device.Health = pluginapi.Healthy
                } else {
                    device.Health = pluginapi.Unhealthy
                    log.Printf("Device %s is unhealthy", id)
                    
                    // Отправка уведомления о нездоровом устройстве
                    select {
                    case m.health <- device:
                    default:
                    }
                }
            }
        case <-m.stop:
            return
        }
    }
}

// isDeviceHealthy проверяет здоровье устройства
func (m *GPUDevicePlugin) isDeviceHealthy(deviceID string) bool {
    // В реальной реализации здесь будет проверка:
    // - Доступности устройства
    // - Температуры
    // - Использования памяти
    // - Ошибок драйвера
    
    // Симуляция проверки здоровья
    return true
}

// GetDevicePluginOptions возвращает опции device plugin
func (m *GPUDevicePlugin) GetDevicePluginOptions(context.Context, *pluginapi.Empty) (*pluginapi.DevicePluginOptions, error) {
    return &pluginapi.DevicePluginOptions{
        PreStartRequired:                false,
        GetPreferredAllocationAvailable: true,
    }, nil
}

// ListAndWatch возвращает список устройств и отслеживает изменения
func (m *GPUDevicePlugin) ListAndWatch(e *pluginapi.Empty, s pluginapi.DevicePlugin_ListAndWatchServer) error {
    // Отправка начального списка устройств
    devices := make([]*pluginapi.Device, 0, len(m.devices))
    for _, device := range m.devices {
        devices = append(devices, device)
    }
    
    if err := s.Send(&pluginapi.ListAndWatchResponse{Devices: devices}); err != nil {
        return err
    }
    
    // Отслеживание изменений здоровья устройств
    for {
        select {
        case <-m.stop:
            return nil
        case device := <-m.health:
            // Отправка обновленного списка при изменении здоровья
            devices := make([]*pluginapi.Device, 0, len(m.devices))
            for _, d := range m.devices {
                devices = append(devices, d)
            }
            
            if err := s.Send(&pluginapi.ListAndWatchResponse{Devices: devices}); err != nil {
                return err
            }
            
            log.Printf("Sent device health update for %s", device.ID)
        }
    }
}

// Allocate выделяет устройства для контейнера
func (m *GPUDevicePlugin) Allocate(ctx context.Context, reqs *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
    responses := make([]*pluginapi.ContainerAllocateResponse, len(reqs.ContainerRequests))
    
    for i, req := range reqs.ContainerRequests {
        response := &pluginapi.ContainerAllocateResponse{}
        
        // Настройка environment variables для контейнера
        envs := make(map[string]string)
        
        // Список выделенных устройств
        deviceIDs := make([]string, 0, len(req.DevicesIDs))
        for _, id := range req.DevicesIDs {
            if device, exists := m.devices[id]; exists && device.Health == pluginapi.Healthy {
                deviceIDs = append(deviceIDs, id)
                
                // Добавление device-specific environment variables
                envs[fmt.Sprintf("GPU_%s_DEVICE_ID", id)] = id
                envs[fmt.Sprintf("GPU_%s_MEMORY", id)] = "8192" // MB
                envs[fmt.Sprintf("GPU_%s_COMPUTE_CAPABILITY", id)] = "7.5"
            }
        }
        
        // Общие environment variables
        envs["CUDA_VISIBLE_DEVICES"] = fmt.Sprintf("%v", deviceIDs)
        envs["NVIDIA_VISIBLE_DEVICES"] = fmt.Sprintf("%v", deviceIDs)
        envs["NVIDIA_DRIVER_CAPABILITIES"] = "compute,utility"
        
        // Преобразование в формат protobuf
        for key, value := range envs {
            response.Envs = append(response.Envs, &pluginapi.EnvVar{
                Name:  key,
                Value: value,
            })
        }
        
        // Монтирование device файлов
        for _, id := range deviceIDs {
            response.Devices = append(response.Devices, &pluginapi.DeviceSpec{
                ContainerPath: fmt.Sprintf("/dev/gpu%s", id),
                HostPath:      fmt.Sprintf("/dev/nvidia%s", id),
                Permissions:   "rwm",
            })
        }
        
        // Монтирование библиотек CUDA
        response.Mounts = append(response.Mounts, &pluginapi.Mount{
            ContainerPath: "/usr/local/cuda",
            HostPath:      "/usr/local/cuda",
            ReadOnly:      true,
        })
        
        responses[i] = response
        
        log.Printf("Allocated devices %v for container", deviceIDs)
    }
    
    return &pluginapi.AllocateResponse{ContainerResponses: responses}, nil
}

// GetPreferredAllocation возвращает предпочтительное выделение устройств
func (m *GPUDevicePlugin) GetPreferredAllocation(ctx context.Context, req *pluginapi.PreferredAllocationRequest) (*pluginapi.PreferredAllocationResponse, error) {
    responses := make([]*pluginapi.ContainerPreferredAllocationResponse, len(req.ContainerRequests))
    
    for i, containerReq := range req.ContainerRequests {
        // Простая стратегия: выбираем первые доступные устройства
        available := make([]string, 0)
        for _, id := range containerReq.AvailableDeviceIDs {
            if device, exists := m.devices[id]; exists && device.Health == pluginapi.Healthy {
                available = append(available, id)
            }
        }
        
        // Выбираем нужное количество устройств
        preferred := make([]string, 0)
        needed := int(containerReq.AllocationSize)
        for j := 0; j < needed && j < len(available); j++ {
            preferred = append(preferred, available[j])
        }
        
        responses[i] = &pluginapi.ContainerPreferredAllocationResponse{
            DeviceIDs: preferred,
        }
        
        log.Printf("Preferred allocation for container: %v", preferred)
    }
    
    return &pluginapi.PreferredAllocationResponse{ContainerResponses: responses}, nil
}

// PreStartContainer выполняется перед запуском контейнера
func (m *GPUDevicePlugin) PreStartContainer(ctx context.Context, req *pluginapi.PreStartContainerRequest) (*pluginapi.PreStartContainerResponse, error) {
    // Здесь можно выполнить дополнительную настройку устройств
    // перед запуском контейнера
    
    log.Printf("PreStartContainer called for devices: %v", req.DevicesIDs)
    
    return &pluginapi.PreStartContainerResponse{}, nil
}

// Stop останавливает device plugin
func (m *GPUDevicePlugin) Stop() error {
    if m.server == nil {
        return nil
    }
    
    close(m.stop)
    m.server.Stop()
    
    return os.Remove(m.socket)
}

func main() {
    log.Println("Starting GPU Device Plugin")
    
    plugin := NewGPUDevicePlugin()
    
    if err := plugin.Start(); err != nil {
        log.Fatalf("Failed to start device plugin: %v", err)
    }
    
    // Ожидание сигнала завершения
    select {}
}
```

#### 2. **Device Plugin Deployment**
```yaml
# gpu-device-plugin-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gpu-device-plugin
  namespace: kube-system
  labels:
    app: gpu-device-plugin
spec:
  selector:
    matchLabels:
      app: gpu-device-plugin
  template:
    metadata:
      labels:
        app: gpu-device-plugin
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      nodeSelector:
        accelerator: nvidia-tesla-k80
      containers:
      - name: gpu-device-plugin
        image: gpu-device-plugin:latest
        imagePullPolicy: Always
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: dev
          mountPath: /dev
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
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

---
# ServiceAccount для device plugin
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gpu-device-plugin
  namespace: kube-system

---
# ClusterRole для device plugin
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gpu-device-plugin
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes/status"]
  verbs: ["patch"]

---
# ClusterRoleBinding для device plugin
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gpu-device-plugin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gpu-device-plugin
subjects:
- kind: ServiceAccount
  name: gpu-device-plugin
  namespace: kube-system
```

#### 3. **Pod с использованием GPU**
```yaml
# gpu-workload.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:11.0-runtime-ubuntu18.04
    command: ["nvidia-smi"]
    resources:
      limits:
        example.com/gpu: 2  # Запрос 2 GPU устройств
      requests:
        example.com/gpu: 2
    env:
    - name: NVIDIA_VISIBLE_DEVICES
      value: "all"
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: "compute,utility"

---
# Deployment с GPU workload
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-training-job
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gpu-training
  template:
    metadata:
      labels:
        app: gpu-training
    spec:
      containers:
      - name: training-container
        image: tensorflow/tensorflow:latest-gpu
        command: ["python", "/app/train.py"]
        resources:
          limits:
            example.com/gpu: 1
            memory: "8Gi"
            cpu: "4"
          requests:
            example.com/gpu: 1
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: training-data
          mountPath: /data
        - name: model-output
          mountPath: /output
      volumes:
      - name: training-data
        persistentVolumeClaim:
          claimName: training-data-pvc
      - name: model-output
        persistentVolumeClaim:
          claimName: model-output-pvc
      nodeSelector:
        accelerator: nvidia-tesla-v100
```

### 📊 Мониторинг Device Plugins

#### 1. **Device Plugin Monitoring Script**
```bash
#!/bin/bash
# device-plugin-monitoring.sh

echo "📊 Мониторинг Device Plugins"

# Проверка device plugins
check_device_plugins() {
    echo "=== Device Plugin Pods ==="
    kubectl get pods --all-namespaces -l app=gpu-device-plugin -o wide
    
    echo ""
    echo "=== Device Plugin Logs ==="
    kubectl logs -n kube-system -l app=gpu-device-plugin --tail=20
}

# Проверка extended resources на узлах
check_extended_resources() {
    echo "=== Extended Resources on Nodes ==="
    
    kubectl get nodes -o json | jq -r '
        .items[] | 
        {
            name: .metadata.name,
            capacity: .status.capacity,
            allocatable: .status.allocatable
        } | 
        select(.capacity | keys[] | contains("example.com/")) |
        "\(.name): \(.capacity | to_entries | map(select(.key | contains("example.com/"))) | from_entries)"
    '
}

# Проверка выделения ресурсов
check_resource_allocation() {
    echo "=== Resource Allocation ==="
    
    kubectl get pods --all-namespaces -o json | jq -r '
        .items[] | 
        select(.spec.containers[]?.resources.limits // {} | keys[] | contains("example.com/")) |
        {
            namespace: .metadata.namespace,
            name: .metadata.name,
            node: .spec.nodeName,
            resources: [.spec.containers[].resources.limits // {} | to_entries[] | select(.key | contains("example.com/"))]
        } |
        "\(.namespace)/\(.name) on \(.node): \(.resources | map("\(.key)=\(.value)") | join(", "))"
    '
}

# Проверка device plugin sockets
check_device_sockets() {
    echo "=== Device Plugin Sockets ==="
    
    kubectl get nodes --no-headers | while read node rest; do
        echo "--- Node: $node ---"
        kubectl debug node/$node -it --image=busybox -- ls -la /host/var/lib/kubelet/device-plugins/ 2>/dev/null || echo "Cannot access device-plugins directory"
    done
}

# Тестирование GPU workload
test_gpu_workload() {
    echo "=== Testing GPU Workload ==="
    
    # Создание тестового pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: gpu-test
    image: nvidia/cuda:11.0-runtime-ubuntu18.04
    command: ["nvidia-smi"]
    resources:
      limits:
        example.com/gpu: 1
      requests:
        example.com/gpu: 1
EOF

    # Ожидание завершения
    kubectl wait --for=condition=Ready pod/gpu-test --timeout=60s
    
    # Проверка результатов
    echo "GPU Test Results:"
    kubectl logs gpu-test
    
    # Очистка
    kubectl delete pod gpu-test
}

# Проверка метрик device plugin
check_device_metrics() {
    echo "=== Device Plugin Metrics ==="
    
    # Проверка метрик через kubelet
    kubectl get --raw /api/v1/nodes/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')/proxy/metrics | grep device_plugin
}

# Основная функция
main() {
    check_device_plugins
    echo ""
    check_extended_resources
    echo ""
    check_resource_allocation
    echo ""
    check_device_sockets
    echo ""
    test_gpu_workload
    echo ""
    check_device_metrics
}

main "$@"
```

#### 2. **Device Plugin Health Check**
```go
// device-health-checker.go
package main

import (
    "context"
    "fmt"
    "log"
    "time"
    
    "google.golang.org/grpc"
    pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"
)

// DeviceHealthChecker проверяет здоровье device plugins
type DeviceHealthChecker struct {
    pluginSockets map[string]string
}

// NewDeviceHealthChecker создает новый health checker
func NewDeviceHealthChecker() *DeviceHealthChecker {
    return &DeviceHealthChecker{
        pluginSockets: map[string]string{
            "example.com/gpu": "/var/lib/kubelet/device-plugins/gpu.sock",
        },
