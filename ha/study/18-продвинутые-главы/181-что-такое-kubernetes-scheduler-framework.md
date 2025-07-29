# 181. Что такое Kubernetes scheduler framework?

## 🎯 Вопрос
Что такое Kubernetes scheduler framework?

## 💡 Ответ

Kubernetes Scheduler Framework - это расширяемая архитектура планировщика, которая позволяет разработчикам создавать custom scheduling plugins для реализации специфической логики размещения pod'ов. Framework предоставляет набор extension points в жизненном цикле планирования, где можно подключить custom логику без изменения core scheduler кода.

### 🏗️ Архитектура Scheduler Framework

#### 1. **Схема Scheduler Framework**
```
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes Scheduler Framework              │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Scheduling Cycle                         │ │
│  │                                                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    Queue    │    │   Filter    │    │    Score    │ │ │
│  │  │   Sort      │───▶│   Plugins   │───▶│   Plugins   │ │ │
│  │  │  Plugins    │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  │         │                   │                   │      │ │
│  │         ▼                   ▼                   ▼      │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   PreFilter │    │   PostFilter│    │   Reserve   │ │ │
│  │  │   Plugins   │    │   Plugins   │    │   Plugins   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Binding Cycle                           │ │
│  │                                                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Permit    │    │   PreBind   │    │    Bind     │ │ │
│  │  │   Plugins   │───▶│   Plugins   │───▶│   Plugins   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  │         │                   │                   │      │ │
│  │         ▼                   ▼                   ▼      │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  PostBind   │    │ Unreserve   │    │   Plugin    │ │ │
│  │  │   Plugins   │    │   Plugins   │    │   Manager   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Extension Points**
```yaml
# Extension points в Scheduler Framework
extension_points:
  scheduling_cycle:
    queue_sort:
      description: "Сортировка pod'ов в очереди планирования"
      interface: "QueueSortPlugin"
      example: "Приоритизация по важности приложения"
    
    pre_filter:
      description: "Предварительная фильтрация и подготовка данных"
      interface: "PreFilterPlugin"
      example: "Проверка ресурсов, подготовка state"
    
    filter:
      description: "Фильтрация узлов по критериям"
      interface: "FilterPlugin"
      example: "NodeResourcesFit, NodeAffinity"
    
    post_filter:
      description: "Действия при отсутствии подходящих узлов"
      interface: "PostFilterPlugin"
      example: "Preemption, cluster autoscaling"
    
    pre_score:
      description: "Подготовка данных для scoring"
      interface: "PreScorePlugin"
      example: "Сбор метрик, расчет весов"
    
    score:
      description: "Оценка узлов для выбора лучшего"
      interface: "ScorePlugin"
      example: "NodeResourcesFit, ImageLocality"
    
    normalize_score:
      description: "Нормализация scores от разных plugins"
      interface: "ScorePlugin"
      example: "Приведение к единой шкале"
    
    reserve:
      description: "Резервирование ресурсов на выбранном узле"
      interface: "ReservePlugin"
      example: "Обновление cache, резервирование"
  
  binding_cycle:
    permit:
      description: "Разрешение или задержка binding"
      interface: "PermitPlugin"
      example: "Ожидание внешних условий"
    
    pre_bind:
      description: "Подготовка к binding"
      interface: "PreBindPlugin"
      example: "Создание volumes, network setup"
    
    bind:
      description: "Привязка pod'а к узлу"
      interface: "BindPlugin"
      example: "Создание Binding объекта"
    
    post_bind:
      description: "Действия после успешного binding"
      interface: "PostBindPlugin"
      example: "Уведомления, метрики"
    
    unreserve:
      description: "Освобождение зарезервированных ресурсов"
      interface: "UnreservePlugin"
      example: "Откат резервирования при ошибке"
```

### 📊 Примеры из нашего кластера

#### Проверка scheduler конфигурации:
```bash
# Проверка scheduler pod'а
kubectl get pods -n kube-system -l component=kube-scheduler

# Проверка scheduler конфигурации
kubectl get configmap -n kube-system kube-scheduler-config -o yaml

# Проверка scheduler logs
kubectl logs -n kube-system -l component=kube-scheduler

# Проверка scheduler metrics
kubectl get --raw /metrics | grep scheduler
```

### 🔧 Создание Custom Scheduler Plugin

#### 1. **Простой Custom Plugin**
```go
// custom-scheduler-plugin.go
package main

import (
    "context"
    "fmt"
    "math"
    
    v1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/kubernetes/pkg/scheduler/framework"
)

// CustomPlugin реализует custom scheduling логику
type CustomPlugin struct {
    handle framework.Handle
}

// Name возвращает имя plugin'а
func (cp *CustomPlugin) Name() string {
    return "CustomPlugin"
}

// Score реализует scoring логику
func (cp *CustomPlugin) Score(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    // Получение информации об узле
    nodeInfo, err := cp.handle.SnapshotSharedLister().NodeInfos().Get(nodeName)
    if err != nil {
        return 0, framework.NewStatus(framework.Error, fmt.Sprintf("getting node %q from Snapshot: %v", nodeName, err))
    }
    
    node := nodeInfo.Node()
    if node == nil {
        return 0, framework.NewStatus(framework.Error, fmt.Sprintf("node %q not found", nodeName))
    }
    
    // Custom scoring логика
    score := cp.calculateCustomScore(pod, node, nodeInfo)
    
    return score, nil
}

// ScoreExtensions возвращает score extensions
func (cp *CustomPlugin) ScoreExtensions() framework.ScoreExtensions {
    return cp
}

// NormalizeScore нормализует scores
func (cp *CustomPlugin) NormalizeScore(ctx context.Context, state *framework.CycleState, pod *v1.Pod, scores framework.NodeScoreList) *framework.Status {
    var highest int64 = 0
    for _, nodeScore := range scores {
        if nodeScore.Score > highest {
            highest = nodeScore.Score
        }
    }
    
    if highest == 0 {
        return nil
    }
    
    // Нормализация к шкале 0-100
    for i, nodeScore := range scores {
        scores[i].Score = nodeScore.Score * framework.MaxNodeScore / highest
    }
    
    return nil
}

// calculateCustomScore реализует custom scoring алгоритм
func (cp *CustomPlugin) calculateCustomScore(pod *v1.Pod, node *v1.Node, nodeInfo *framework.NodeInfo) int64 {
    // Пример: предпочтение узлов с меньшей загрузкой CPU
    allocatedCPU := nodeInfo.Allocatable.MilliCPU - nodeInfo.Requested.MilliCPU
    totalCPU := nodeInfo.Allocatable.MilliCPU
    
    if totalCPU == 0 {
        return 0
    }
    
    // Чем больше свободного CPU, тем выше score
    cpuUtilization := float64(allocatedCPU) / float64(totalCPU)
    score := int64(cpuUtilization * 100)
    
    // Дополнительные факторы
    if hasCustomLabel(node, "preferred-node") {
        score += 20
    }
    
    if hasGPU(node) && needsGPU(pod) {
        score += 30
    }
    
    return score
}

// hasCustomLabel проверяет наличие custom label
func hasCustomLabel(node *v1.Node, label string) bool {
    _, exists := node.Labels[label]
    return exists
}

// hasGPU проверяет наличие GPU на узле
func hasGPU(node *v1.Node) bool {
    _, exists := node.Status.Capacity["nvidia.com/gpu"]
    return exists
}

// needsGPU проверяет, нужен ли GPU для pod'а
func needsGPU(pod *v1.Pod) bool {
    for _, container := range pod.Spec.Containers {
        if _, exists := container.Resources.Requests["nvidia.com/gpu"]; exists {
            return true
        }
    }
    return false
}

// Filter реализует filtering логику
func (cp *CustomPlugin) Filter(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeInfo *framework.NodeInfo) *framework.Status {
    node := nodeInfo.Node()
    if node == nil {
        return framework.NewStatus(framework.Error, "node not found")
    }
    
    // Custom filtering логика
    if !cp.customFilterCheck(pod, node) {
        return framework.NewStatus(framework.Unschedulable, "custom filter failed")
    }
    
    return nil
}

// customFilterCheck реализует custom filtering
func (cp *CustomPlugin) customFilterCheck(pod *v1.Pod, node *v1.Node) bool {
    // Пример: проверка custom requirements
    if podRequirement, exists := pod.Annotations["custom-requirement"]; exists {
        if nodeCapability, exists := node.Labels["custom-capability"]; exists {
            return podRequirement == nodeCapability
        }
        return false
    }
    
    return true
}

// New создает новый instance plugin'а
func New(obj runtime.Object, h framework.Handle) (framework.Plugin, error) {
    return &CustomPlugin{handle: h}, nil
}
```

#### 2. **Plugin Configuration**
```yaml
# scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: custom-scheduler
  plugins:
    score:
      enabled:
      - name: CustomPlugin
      disabled:
      - name: NodeResourcesFit  # Отключаем default plugin
    filter:
      enabled:
      - name: CustomPlugin
  pluginConfig:
  - name: CustomPlugin
    args:
      customParameter: "value"
      weights:
        cpuWeight: 70
        memoryWeight: 20
        customWeight: 10
---
# Deployment для custom scheduler
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-scheduler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-scheduler
  template:
    metadata:
      labels:
        app: custom-scheduler
    spec:
      serviceAccountName: custom-scheduler
      containers:
      - name: kube-scheduler
        image: k8s.gcr.io/kube-scheduler:v1.28.0
        command:
        - kube-scheduler
        - --config=/etc/kubernetes/scheduler-config.yaml
        - --v=2
        volumeMounts:
        - name: config
          mountPath: /etc/kubernetes
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: config
        configMap:
          name: custom-scheduler-config
---
# ServiceAccount для custom scheduler
apiVersion: v1
kind: ServiceAccount
metadata:
  name: custom-scheduler
  namespace: kube-system
---
# ClusterRoleBinding для custom scheduler
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: custom-scheduler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-scheduler
subjects:
- kind: ServiceAccount
  name: custom-scheduler
  namespace: kube-system
```

### 🔧 Практические примеры plugins

#### 1. **GPU Affinity Plugin**
```go
// gpu-affinity-plugin.go
package main

import (
    "context"
    "strconv"
    
    v1 "k8s.io/api/core/v1"
    "k8s.io/kubernetes/pkg/scheduler/framework"
)

type GPUAffinityPlugin struct {
    handle framework.Handle
}

func (gap *GPUAffinityPlugin) Name() string {
    return "GPUAffinityPlugin"
}

func (gap *GPUAffinityPlugin) Score(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    nodeInfo, err := gap.handle.SnapshotSharedLister().NodeInfos().Get(nodeName)
    if err != nil {
        return 0, framework.NewStatus(framework.Error, err.Error())
    }
    
    node := nodeInfo.Node()
    
    // Проверяем, нужен ли GPU для pod'а
    gpuRequest := gap.getGPURequest(pod)
    if gpuRequest == 0 {
        return 50, nil // Нейтральный score для pod'ов без GPU
    }
    
    // Получаем доступные GPU на узле
    availableGPU := gap.getAvailableGPU(node, nodeInfo)
    
    if availableGPU >= gpuRequest {
        // Предпочитаем узлы с большим количеством доступных GPU
        score := int64(float64(availableGPU) / float64(gpuRequest) * 100)
        if score > 100 {
            score = 100
        }
        return score, nil
    }
    
    return 0, nil // Недостаточно GPU
}

func (gap *GPUAffinityPlugin) getGPURequest(pod *v1.Pod) int64 {
    var totalGPU int64
    for _, container := range pod.Spec.Containers {
        if gpuQuantity, exists := container.Resources.Requests["nvidia.com/gpu"]; exists {
            totalGPU += gpuQuantity.Value()
        }
    }
    return totalGPU
}

func (gap *GPUAffinityPlugin) getAvailableGPU(node *v1.Node, nodeInfo *framework.NodeInfo) int64 {
    totalGPU, exists := node.Status.Capacity["nvidia.com/gpu"]
    if !exists {
        return 0
    }
    
    allocatedGPU := nodeInfo.Requested.ScalarResources["nvidia.com/gpu"]
    return totalGPU.Value() - allocatedGPU
}

func (gap *GPUAffinityPlugin) ScoreExtensions() framework.ScoreExtensions {
    return gap
}

func (gap *GPUAffinityPlugin) NormalizeScore(ctx context.Context, state *framework.CycleState, pod *v1.Pod, scores framework.NodeScoreList) *framework.Status {
    return nil // Используем default нормализацию
}
```

#### 2. **Cost Optimization Plugin**
```go
// cost-optimization-plugin.go
package main

import (
    "context"
    "strconv"
    
    v1 "k8s.io/api/core/v1"
    "k8s.io/kubernetes/pkg/scheduler/framework"
)

type CostOptimizationPlugin struct {
    handle framework.Handle
}

func (cop *CostOptimizationPlugin) Name() string {
    return "CostOptimizationPlugin"
}

func (cop *CostOptimizationPlugin) Score(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    nodeInfo, err := cop.handle.SnapshotSharedLister().NodeInfos().Get(nodeName)
    if err != nil {
        return 0, framework.NewStatus(framework.Error, err.Error())
    }
    
    node := nodeInfo.Node()
    
    // Получаем стоимость узла из labels
    costPerHour := cop.getNodeCostPerHour(node)
    if costPerHour == 0 {
        return 50, nil // Нейтральный score если стоимость неизвестна
    }
    
    // Рассчитываем эффективность использования ресурсов
    efficiency := cop.calculateResourceEfficiency(pod, nodeInfo)
    
    // Чем ниже стоимость и выше эффективность, тем выше score
    score := int64((1.0 / costPerHour) * efficiency * 100)
    if score > 100 {
        score = 100
    }
    
    return score, nil
}

func (cop *CostOptimizationPlugin) getNodeCostPerHour(node *v1.Node) float64 {
    if costStr, exists := node.Labels["node.kubernetes.io/cost-per-hour"]; exists {
        if cost, err := strconv.ParseFloat(costStr, 64); err == nil {
            return cost
        }
    }
    
    // Default стоимость на основе instance type
    if instanceType, exists := node.Labels["node.kubernetes.io/instance-type"]; exists {
        return cop.getDefaultCost(instanceType)
    }
    
    return 0
}

func (cop *CostOptimizationPlugin) getDefaultCost(instanceType string) float64 {
    // Примерные стоимости для разных типов инстансов
    costs := map[string]float64{
        "t3.micro":   0.0104,
        "t3.small":   0.0208,
        "t3.medium":  0.0416,
        "t3.large":   0.0832,
        "m5.large":   0.096,
        "m5.xlarge":  0.192,
        "c5.large":   0.085,
        "c5.xlarge":  0.17,
    }
    
    if cost, exists := costs[instanceType]; exists {
        return cost
    }
    
    return 0.1 // Default стоимость
}

func (cop *CostOptimizationPlugin) calculateResourceEfficiency(pod *v1.Pod, nodeInfo *framework.NodeInfo) float64 {
    // Рассчитываем, насколько эффективно pod использует ресурсы узла
    podCPU := cop.getPodCPURequest(pod)
    podMemory := cop.getPodMemoryRequest(pod)
    
    nodeCPU := nodeInfo.Allocatable.MilliCPU
    nodeMemory := nodeInfo.Allocatable.Memory
    
    if nodeCPU == 0 || nodeMemory == 0 {
        return 0
    }
    
    cpuRatio := float64(podCPU) / float64(nodeCPU)
    memoryRatio := float64(podMemory) / float64(nodeMemory)
    
    // Эффективность = среднее использование ресурсов
    efficiency := (cpuRatio + memoryRatio) / 2.0
    
    // Предпочитаем более высокое использование ресурсов
    return efficiency
}

func (cop *CostOptimizationPlugin) getPodCPURequest(pod *v1.Pod) int64 {
    var totalCPU int64
    for _, container := range pod.Spec.Containers {
        if cpuQuantity, exists := container.Resources.Requests[v1.ResourceCPU]; exists {
            totalCPU += cpuQuantity.MilliValue()
        }
    }
    return totalCPU
}

func (cop *CostOptimizationPlugin) getPodMemoryRequest(pod *v1.Pod) int64 {
    var totalMemory int64
    for _, container := range pod.Spec.Containers {
        if memQuantity, exists := container.Resources.Requests[v1.ResourceMemory]; exists {
            totalMemory += memQuantity.Value()
        }
    }
    return totalMemory
}

func (cop *CostOptimizationPlugin) ScoreExtensions() framework.ScoreExtensions {
    return cop
}

func (cop *CostOptimizationPlugin) NormalizeScore(ctx context.Context, state *framework.CycleState, pod *v1.Pod, scores framework.NodeScoreList) *framework.Status {
    return nil
}
```

### 📊 Мониторинг и отладка

#### 1. **Scheduler Metrics**
```bash
#!/bin/bash
# scheduler-monitoring.sh

echo "📊 Мониторинг Kubernetes Scheduler"

# Получение scheduler metrics
get_scheduler_metrics() {
    echo "=== Scheduler Metrics ==="
    
    # Основные метрики планирования
    kubectl get --raw /metrics | grep -E "(scheduler_|scheduling_)"
    
    # Метрики по plugin'ам
    kubectl get --raw /metrics | grep "scheduler_plugin"
    
    # Метрики производительности
    kubectl get --raw /metrics | grep "scheduler_scheduling_duration"
}

# Анализ scheduler events
analyze_scheduler_events() {
    echo "=== Scheduler Events ==="
    
    # События планирования
    kubectl get events --all-namespaces --field-selector reason=Scheduled
    
    # События неудачного планирования
    kubectl get events --all-namespaces --field-selector reason=FailedScheduling
    
    # События preemption
    kubectl get events --all-namespaces --field-selector reason=Preempted
}

# Проверка scheduler performance
check_scheduler_performance() {
    echo "=== Scheduler Performance ==="
    
    # Время планирования
    kubectl get --raw /metrics | grep "scheduler_scheduling_duration_seconds"
    
    # Количество pending pod'ов
    kubectl get pods --all-namespaces --field-selector status.phase=Pending
    
    # Scheduler throughput
    kubectl get --raw /metrics | grep "scheduler_pod_scheduling_attempts_total"
}

# Отладка конкретного pod'а
debug_pod_scheduling() {
    local pod_name=$1
    local namespace=$2
    
    echo "=== Debugging Pod Scheduling: $namespace/$pod_name ==="
    
    # Информация о pod'е
    kubectl describe pod $pod_name -n $namespace
    
    # События связанные с pod'ом
    kubectl get events -n $namespace --field-selector involvedObject.name=$pod_name
    
    # Проверка node selector и affinity
    kubectl get pod $pod_name -n $namespace -o yaml | grep -A 10 -E "(nodeSelector|affinity)"
    
    # Проверка доступных узлов
    kubectl get nodes -o wide
    
    # Проверка taints и tolerations
    kubectl describe nodes | grep -A 5 Taints
}

case "$1" in
    metrics)
        get_scheduler_metrics
        ;;
    events)
        analyze_scheduler_events
        ;;
    performance)
        check_scheduler_performance
        ;;
    debug)
        debug_pod_scheduling $2 $3
        ;;
    all)
        get_scheduler_metrics
        analyze_scheduler_events
        check_scheduler_performance
        ;;
    *)
        echo "Использование: $0 {metrics|events|performance|debug|all} [pod-name] [namespace]"
        exit 1
        ;;
esac
```

### 🔧 Развертывание Custom Scheduler

#### 1. **Скрипт развертывания**
```bash
#!/bin/bash
# deploy-custom-scheduler.sh

echo "🚀 Развертывание Custom Scheduler"

# Сборка custom scheduler
build_scheduler() {
    echo "🔨 Сборка custom scheduler"
    
    # Создание Dockerfile
    cat <<EOF > Dockerfile
FROM golang:1.19-alpine AS builder

WORKDIR /app
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o custom-scheduler .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/custom-scheduler .
CMD ["./custom-scheduler"]
EOF
    
    # Сборка образа
    docker build -t custom-scheduler:latest .
    
    # Push в registry (если нужно)
    # docker tag custom-scheduler:latest your-registry/custom-scheduler:latest
    # docker push your-registry/custom-scheduler:latest
    
    echo "✅ Scheduler собран"
}

# Создание конфигурации
create_config() {
    echo "⚙️ Создание конфигурации"
    
    kubectl create configmap custom-scheduler-config \
        --from-file=scheduler-config.yaml \
        -n kube-system \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Конфигурация создана"
}

# Развертывание scheduler
deploy_scheduler() {
    echo "🚀 Развертывание scheduler"
    
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-scheduler
  namespace: kube-system
  labels:
    app: custom-scheduler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-scheduler
  template:
    metadata:
      labels:
        app: custom-scheduler
    spec:
      serviceAccountName: custom-scheduler
      containers:
      - name: custom-scheduler
        image: custom-scheduler:latest
        imagePullPolicy: IfNotPresent
        command:
        - ./custom-scheduler
        - --config=/etc/kubernetes/scheduler-config.yaml
        - --v=2
        volumeMounts:
        - name: config
          mountPath: /etc/kubernetes
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10259
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10259
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: custom-scheduler-config
EOF
    
    echo "✅ Scheduler развернут"
}

# Тестирование scheduler
test_scheduler() {
    echo "🧪 Тестирование custom scheduler"
    
    # Создание test pod'а
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-custom-scheduler
  namespace: default
spec:
  schedulerName: custom-scheduler
  containers:
  - name: test
    image: nginx:alpine
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
  restartPolicy: Never
EOF
    
    # Ожидание планирования
    echo "Ожидание планирования pod'а..."
    kubectl wait --for=condition=PodScheduled pod/test-custom-scheduler --timeout=60s
    
    # Проверка результата
    kubectl describe pod test-custom-scheduler | grep -E "(Scheduled|Events)"
    
    # Очистка
    kubectl delete pod test-custom-scheduler
    
    echo "✅ Тестирование завершено"
}

case "$1" in
    build)
        build_scheduler
        ;;
    config)
        create_config
        ;;
    deploy)
        deploy_scheduler
        ;;
    test)
        test_scheduler
        ;;
    all)
        build_scheduler
        create_config
        deploy_scheduler
        test_scheduler
        ;;
    *)
        echo "Использование: $0 {build|config|deploy|test|all}"
        exit 1
        ;;
esac
```

Kubernetes Scheduler Framework предоставляет мощную и гибкую архитектуру для создания custom scheduling логики, позволяя оптимизировать размещение workload'ов под специфические требования приложений и инфраструктуры.
