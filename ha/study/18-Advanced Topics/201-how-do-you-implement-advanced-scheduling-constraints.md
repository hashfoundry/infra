# 201. How do you implement advanced scheduling constraints?

## 🎯 Вопрос
How do you implement advanced scheduling constraints?

## 💡 Ответ

Advanced Scheduling Constraints в Kubernetes позволяют точно контролировать размещение подов на узлах с использованием сложных правил affinity, anti-affinity, taints, tolerations, topology spread constraints и custom schedulers. Эти механизмы обеспечивают оптимальное распределение рабочих нагрузок.

### 🏗️ Архитектура Advanced Scheduling

#### 1. **Схема Advanced Scheduling Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│            Advanced Scheduling Architecture                │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   Pod Specification                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Node      │    │    Pod      │    │  Topology   │ │ │
│  │  │  Affinity   │───▶│  Affinity   │───▶│   Spread    │ │ │
│  │  │             │    │             │    │ Constraints │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Scheduler Framework                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Filter    │    │    Score    │    │   Bind      │ │ │
│  │  │   Plugins   │───▶│   Plugins   │───▶│  Plugins    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Constraint Evaluation                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Taints &  │    │  Resource   │    │   Custom    │ │ │
│  │  │ Tolerations │───▶│ Constraints │───▶│ Schedulers  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Node Selection                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Zone A    │    │   Zone B    │    │   Zone C    │ │ │
│  │  │   Node 1    │───▶│   Node 2    │───▶│   Node 3    │ │ │
│  │  │   Node 4    │    │   Node 5    │    │   Node 6    │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Scheduling Constraints Types**
```yaml
# Advanced Scheduling Constraints
scheduling_constraints:
  node_affinity:
    required_during_scheduling:
      description: "Hard constraints that must be satisfied"
      operators:
        - "In, NotIn, Exists, DoesNotExist"
        - "Gt, Lt (for numeric values)"
      use_cases:
        - "GPU nodes for ML workloads"
        - "SSD storage for databases"
        - "Specific instance types"
    
    preferred_during_scheduling:
      description: "Soft constraints with weights"
      weight_range: "1-100"
      behavior: "Scheduler tries to satisfy but not required"
      use_cases:
        - "Prefer newer nodes"
        - "Prefer less utilized zones"
        - "Cost optimization"

  pod_affinity:
    required_during_scheduling:
      description: "Pods must be co-located"
      topology_key: "kubernetes.io/hostname, topology.kubernetes.io/zone"
      use_cases:
        - "Database and cache co-location"
        - "Microservices communication"
        - "Data locality requirements"
    
    preferred_during_scheduling:
      description: "Pods should be co-located"
      weight_range: "1-100"
      use_cases:
        - "Performance optimization"
        - "Network latency reduction"

  pod_anti_affinity:
    required_during_scheduling:
      description: "Pods must not be co-located"
      topology_key: "kubernetes.io/hostname, topology.kubernetes.io/zone"
      use_cases:
        - "High availability"
        - "Fault tolerance"
        - "Resource distribution"
    
    preferred_during_scheduling:
      description: "Pods should not be co-located"
      use_cases:
        - "Load balancing"
        - "Performance isolation"

  topology_spread_constraints:
    max_skew: "Maximum difference in pod count"
    topology_key: "Distribution dimension"
    when_unsatisfiable: "DoNotSchedule, ScheduleAnyway"
    label_selector: "Pods to consider for spreading"
    use_cases:
      - "Even distribution across zones"
      - "Balanced load across nodes"
      - "Compliance requirements"

  taints_and_tolerations:
    taint_effects:
      no_schedule: "New pods won't be scheduled"
      prefer_no_schedule: "Avoid scheduling if possible"
      no_execute: "Existing pods will be evicted"
    
    toleration_operators:
      equal: "Exact match required"
      exists: "Key existence check"
    
    use_cases:
      - "Dedicated nodes for specific workloads"
      - "Node maintenance and upgrades"
      - "Resource isolation"

  custom_schedulers:
    implementation: "Custom scheduling logic"
    use_cases:
      - "Complex business rules"
      - "External system integration"
      - "Specialized algorithms"
    
    scheduler_plugins:
      filter_plugins: "Node filtering logic"
      score_plugins: "Node scoring logic"
      bind_plugins: "Pod binding logic"
```

### 📊 Примеры из нашего кластера

#### Проверка Scheduling Constraints:
```bash
# Проверка node labels и taints
kubectl get nodes --show-labels
kubectl describe nodes | grep -A 5 "Taints\|Labels"

# Проверка pod affinity и anti-affinity
kubectl get pods -o wide --all-namespaces
kubectl describe pod <pod-name> | grep -A 10 "Affinity\|Tolerations"

# Проверка topology spread constraints
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,NODE:.spec.nodeName,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone

# Проверка scheduler events
kubectl get events --all-namespaces | grep -i "schedule\|affinity\|taint"

# Проверка pending pods с причинами
kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o wide
```

### 🛠️ Реализация Advanced Scheduling Constraints

#### 1. **Node Affinity Examples**
```yaml
# node-affinity-examples.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-workload
  namespace: ml-training
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gpu-workload
  template:
    metadata:
      labels:
        app: gpu-workload
    spec:
      affinity:
        nodeAffinity:
          # Hard requirement: must have GPU
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: accelerator
                operator: In
                values: ["nvidia-tesla-v100", "nvidia-tesla-p100"]
              - key: node-type
                operator: In
                values: ["gpu-node"]
          # Soft preference: prefer newer GPU nodes
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: gpu-generation
                operator: In
                values: ["v100", "a100"]
          - weight: 60
            preference:
              matchExpressions:
              - key: node-age
                operator: Lt
                values: ["30"]  # Less than 30 days old
      containers:
      - name: ml-trainer
        image: tensorflow/tensorflow:latest-gpu
        resources:
          limits:
            nvidia.com/gpu: 1
            cpu: 4000m
            memory: 8Gi
          requests:
            nvidia.com/gpu: 1
            cpu: 2000m
            memory: 4Gi

---
# Database workload with SSD requirement
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-cluster
  namespace: production
spec:
  serviceName: database
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: storage-type
                operator: In
                values: ["ssd", "nvme"]
              - key: node-role.kubernetes.io/worker
                operator: Exists
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: storage-performance
                operator: In
                values: ["high", "premium"]
          - weight: 50
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["fra1-1"]  # Prefer specific zone
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "production"
        - name: POSTGRES_USER
          value: "dbuser"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        resources:
          limits:
            cpu: 2000m
            memory: 4Gi
          requests:
            cpu: 1000m
            memory: 2Gi
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

#### 2. **Pod Affinity and Anti-Affinity**
```yaml
# pod-affinity-examples.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: production
spec:
  replicas: 6
  selector:
    matchLabels:
      app: web-frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: web-frontend
        tier: frontend
    spec:
      affinity:
        # Pod anti-affinity for high availability
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: ["web-frontend"]
            topologyKey: kubernetes.io/hostname
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["web-frontend"]
              topologyKey: topology.kubernetes.io/zone
        
        # Pod affinity with cache layer
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["redis-cache"]
              topologyKey: kubernetes.io/hostname
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi

---
# Cache layer with database affinity
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: redis-cache
      tier: cache
  template:
    metadata:
      labels:
        app: redis-cache
        tier: cache
    spec:
      affinity:
        # Anti-affinity for cache instances
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: ["redis-cache"]
            topologyKey: kubernetes.io/hostname
        
        # Affinity with database for data locality
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 90
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["database"]
              topologyKey: topology.kubernetes.io/zone
      containers:
      - name: redis
        image: redis:6-alpine
        ports:
        - containerPort: 6379
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 256Mi

---
# Microservice with complex affinity rules
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: microservices
spec:
  replicas: 4
  selector:
    matchLabels:
      app: order-service
      service: order
  template:
    metadata:
      labels:
        app: order-service
        service: order
        version: v2
    spec:
      affinity:
        # Anti-affinity for service instances
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["order-service"]
              topologyKey: kubernetes.io/hostname
          - weight: 50
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["order-service"]
              topologyKey: topology.kubernetes.io/zone
        
        # Affinity with related services
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 70
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: service
                  operator: In
                  values: ["payment", "inventory"]
              topologyKey: topology.kubernetes.io/zone
      containers:
      - name: order-service
        image: order-service:v2.1.0
        ports:
        - containerPort: 8080
        env:
        - name: SERVICE_VERSION
          value: "v2.1.0"
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 200m
            memory: 256Mi
```

#### 3. **Topology Spread Constraints**
```yaml
# topology-spread-examples.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distributed-app
  namespace: production
spec:
  replicas: 12
  selector:
    matchLabels:
      app: distributed-app
  template:
    metadata:
      labels:
        app: distributed-app
        component: worker
    spec:
      topologySpreadConstraints:
      # Even distribution across zones
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: distributed-app
      # Balanced distribution across nodes
      - maxSkew: 2
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: distributed-app
      # Distribution across instance types
      - maxSkew: 3
        topologyKey: node.kubernetes.io/instance-type
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            component: worker
      containers:
      - name: worker
        image: distributed-worker:latest
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi

---
# Critical service with strict spreading
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-service
  namespace: system
spec:
  replicas: 9
  selector:
    matchLabels:
      app: critical-service
      criticality: high
  template:
    metadata:
      labels:
        app: critical-service
        criticality: high
    spec:
      topologySpreadConstraints:
      # Must be evenly distributed across zones
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: critical-service
        minDomains: 3  # Require at least 3 zones
      # Prefer even distribution across nodes
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            criticality: high
      containers:
      - name: service
        image: critical-service:stable
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### 4. **Taints and Tolerations**
```yaml
# taints-tolerations-examples.yaml
# GPU node taint setup
apiVersion: v1
kind: Node
metadata:
  name: gpu-node-1
  labels:
    accelerator: nvidia-tesla-v100
    node-type: gpu-node
spec:
  taints:
  - key: nvidia.com/gpu
    value: "true"
    effect: NoSchedule
  - key: dedicated
    value: "gpu-workload"
    effect: NoExecute

---
# GPU workload with tolerations
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-training-job
  namespace: ai-research
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ml-training
  template:
    metadata:
      labels:
        app: ml-training
        workload-type: gpu-intensive
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Equal
        value: "true"
        effect: NoSchedule
      - key: dedicated
        operator: Equal
        value: "gpu-workload"
        effect: NoExecute
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
      nodeSelector:
        accelerator: nvidia-tesla-v100
      containers:
      - name: trainer
        image: tensorflow/tensorflow:latest-gpu
        resources:
          limits:
            nvidia.com/gpu: 1
            cpu: 4000m
            memory: 8Gi
          requests:
            nvidia.com/gpu: 1
            cpu: 2000m
            memory: 4Gi

---
# Maintenance node taint
apiVersion: v1
kind: Node
metadata:
  name: worker-node-maintenance
spec:
  taints:
  - key: maintenance
    value: "scheduled"
    effect: NoSchedule
  - key: maintenance
    value: "scheduled"
    effect: NoExecute

---
# System pods with maintenance tolerations
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: monitoring-agent
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: monitoring-agent
  template:
    metadata:
      labels:
        app: monitoring-agent
    spec:
      tolerations:
      # Tolerate all taints for system monitoring
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
      - operator: Exists
        effect: PreferNoSchedule
      containers:
      - name: agent
        image: monitoring-agent:latest
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      hostNetwork: true
      hostPID: true
```

#### 5. **Custom Scheduler Implementation**
```go
// custom-scheduler.go
package main

import (
    "context"
    "fmt"
    "math"
    "time"

    v1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
    "k8s.io/klog/v2"
    "k8s.io/kubernetes/pkg/scheduler"
    "k8s.io/kubernetes/pkg/scheduler/framework"
    "k8s.io/kubernetes/pkg/scheduler/framework/plugins/defaultbinder"
    "k8s.io/kubernetes/pkg/scheduler/framework/plugins/queuesort"
    frameworkruntime "k8s.io/kubernetes/pkg/scheduler/framework/runtime"
    "k8s.io/kubernetes/pkg/scheduler/profile"
)

const (
    SchedulerName = "custom-scheduler"
)

// CustomScheduler implements advanced scheduling logic
type CustomScheduler struct {
    clientset kubernetes.Interface
    scheduler *scheduler.Scheduler
}

// CostAwarePlugin implements cost-based scheduling
type CostAwarePlugin struct {
    handle framework.Handle
}

func (p *CostAwarePlugin) Name() string {
    return "CostAware"
}

// Score implements scoring based on cost efficiency
func (p *CostAwarePlugin) Score(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    node, err := p.handle.SnapshotSharedLister().NodeInfos().Get(nodeName)
    if err != nil {
        return 0, framework.NewStatus(framework.Error, fmt.Sprintf("getting node %q: %v", nodeName, err))
    }

    // Calculate cost score based on instance type and utilization
    score := p.calculateCostScore(node.Node(), pod)
    return score, nil
}

func (p *CostAwarePlugin) calculateCostScore(node *v1.Node, pod *v1.Pod) int64 {
    // Get instance type cost (simplified)
    instanceType := node.Labels["node.kubernetes.io/instance-type"]
    baseCost := getInstanceTypeCost(instanceType)
    
    // Calculate current utilization
    utilization := calculateNodeUtilization(node)
    
    // Score formula: prefer lower cost and higher utilization
    // Score range: 0-100
    costFactor := 1.0 / (baseCost + 1.0)
    utilizationFactor := utilization / 100.0
    
    score := int64((costFactor * 50) + (utilizationFactor * 50))
    return score
}

func getInstanceTypeCost(instanceType string) float64 {
    // Simplified cost mapping
    costs := map[string]float64{
        "s-1vcpu-1gb":   0.007,
        "s-2vcpu-2gb":   0.015,
        "s-2vcpu-4gb":   0.022,
        "s-4vcpu-8gb":   0.048,
        "c-2":           0.021,
        "c-4":           0.042,
        "m-2vcpu-16gb":  0.060,
        "m-4vcpu-32gb":  0.120,
    }
    
    if cost, exists := costs[instanceType]; exists {
        return cost
    }
    return 0.050 // Default cost
}

func calculateNodeUtilization(node *v1.Node) float64 {
    // Simplified utilization calculation
    // In real implementation, use metrics from metrics server
    return 60.0 // Placeholder
}

// ScoreExtensions returns score extensions
func (p *CostAwarePlugin) ScoreExtensions() framework.ScoreExtensions {
    return nil
}

// LocalityAwarePlugin implements locality-aware scheduling
type LocalityAwarePlugin struct {
    handle framework.Handle
}

func (p *LocalityAwarePlugin) Name() string {
    return "LocalityAware"
}

func (p *LocalityAwarePlugin) Filter(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeInfo *framework.NodeInfo) *framework.Status {
    // Check if pod has locality requirements
    if locality, exists := pod.Annotations["scheduler.example.com/locality"]; exists {
        nodeZone := nodeInfo.Node().Labels["topology.kubernetes.io/zone"]
        if locality != nodeZone {
            return framework.NewStatus(framework.Unschedulable, "locality constraint not satisfied")
        }
    }
    
    return nil
}

// WorkloadAwarePlugin implements workload-specific scheduling
type WorkloadAwarePlugin struct {
    handle framework.Handle
}

func (p *WorkloadAwarePlugin) Name() string {
    return "WorkloadAware"
}

func (p *WorkloadAwarePlugin) Score(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    node, err := p.handle.SnapshotSharedLister().NodeInfos().Get(nodeName)
    if err != nil {
        return 0, framework.NewStatus(framework.Error, fmt.Sprintf("getting node %q: %v", nodeName, err))
    }

    score := p.calculateWorkloadScore(node.Node(), pod)
    return score, nil
}

func (p *WorkloadAwarePlugin) calculateWorkloadScore(node *v1.Node, pod *v1.Pod) int64 {
    workloadType := pod.Labels["workload-type"]
    
    switch workloadType {
    case "cpu-intensive":
        return p.scoreCPUIntensive(node, pod)
    case "memory-intensive":
        return p.scoreMemoryIntensive(node, pod)
    case "io-intensive":
        return p.scoreIOIntensive(node, pod)
    case "network-intensive":
        return p.scoreNetworkIntensive(node, pod)
    default:
        return 50 // Neutral score
    }
}

func (p *WorkloadAwarePlugin) scoreCPUIntensive(node *v1.Node, pod *v1.Pod) int64 {
    // Prefer nodes with high CPU capacity and low CPU utilization
    cpuCapacity := node.Status.Capacity.Cpu().MilliValue()
    
    // Simplified scoring based on CPU capacity
    if cpuCapacity >= 4000 { // 4+ cores
        return 90
    } else if cpuCapacity >= 2000 { // 2+ cores
        return 70
    }
    return 30
}

func (p *WorkloadAwarePlugin) scoreMemoryIntensive(node *v1.Node, pod *v1.Pod) int64 {
    // Prefer nodes with high memory capacity
    memoryCapacity := node.Status.Capacity.Memory().Value()
    
    if memoryCapacity >= 16*1024*1024*1024 { // 16GB+
        return 90
    } else if memoryCapacity >= 8*1024*1024*1024 { // 8GB+
        return 70
    }
    return 30
}

func (p *WorkloadAwarePlugin) scoreIOIntensive(node *v1.Node, pod *v1.Pod) int64 {
    // Prefer nodes with SSD storage
    storageType := node.Labels["storage-type"]
    if storageType == "ssd" || storageType == "nvme" {
        return 90
    }
    return 40
}

func (p *WorkloadAwarePlugin) scoreNetworkIntensive(node *v1.Node, pod *v1.Pod) int64 {
    // Prefer nodes with high network bandwidth
    networkType := node.Labels["network-type"]
    if networkType == "high-bandwidth" {
        return 90
    }
    return 50
}

func (p *WorkloadAwarePlugin) ScoreExtensions() framework.ScoreExtensions {
    return nil
}

// Plugin factory functions
func NewCostAwarePlugin(_ runtime.Object, handle framework.Handle) (framework.Plugin, error) {
    return &CostAwarePlugin{handle: handle}, nil
}

func NewLocalityAwarePlugin(_ runtime.Object, handle framework.Handle) (framework.Plugin, error) {
    return &LocalityAwarePlugin{handle: handle}, nil
}

func NewWorkloadAwarePlugin(_ runtime.Object, handle framework.Handle) (framework.Plugin, error) {
    return &WorkloadAwarePlugin{handle: handle}, nil
}

// Main scheduler setup
func main() {
    klog.InitFlags(nil)
    
    config, err := rest.InClusterConfig()
    if err != nil {
        klog.Fatalf("Failed to create config: %v", err)
    }
    
    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        klog.Fatalf("Failed to create clientset: %v", err)
    }
    
    // Create custom scheduler
    customScheduler, err := NewCustomScheduler(clientset)
    if err != nil {
        klog.Fatalf("Failed to create custom scheduler: %v", err)
    }
    
    // Run scheduler
    ctx := context.Background()
    customScheduler.Run(ctx)
}

func NewCustomScheduler(clientset kubernetes.Interface) (*CustomScheduler, error) {
    // Create scheduler configuration
    cfg := &scheduler.Config{
        ComponentConfig: &config.KubeSchedulerConfiguration{
            Profiles: []config.KubeSchedulerProfile{
                {
                    SchedulerName: SchedulerName,
                    Plugins: &config.Plugins{
                        Score: config.PluginSet{
                            Enabled: []config.Plugin{
                                {Name: "CostAware"},
                                {Name: "WorkloadAware"},
                            },
                        },
                        Filter: config.PluginSet{
                            Enabled: []config.Plugin{
                                {Name: "LocalityAware"},
                            },
                        },
                    },
                    PluginConfig: []config.PluginConfig{
                        {
                            Name: "CostAware",
                            Args: runtime.RawExtension{},
                        },
                        {
                            Name: "LocalityAware", 
                            Args: runtime.RawExtension{},
                        },
                        {
                            Name: "WorkloadAware",
                            Args: runtime.RawExtension{},
                        },
                    },
                },
            },
        },
        Client: clientset,
    }
    
    // Register custom plugins
    registry := frameworkruntime.Registry{
        "CostAware":      NewCostAwarePlugin,
        "LocalityAware":  NewLocalityAwarePlugin,
        "WorkloadAware":  NewWorkloadAwarePlugin,
    }
    
    // Create scheduler
    sched, err := scheduler.New(
        cfg.Client,
        cfg.InformerFactory,
        cfg.PodInformer,
        profile.NewRecorderFactory(cfg.EventBroadcaster),
        ctx.Done(),
        scheduler.WithProfiles(cfg.ComponentConfig.Profiles...),
        scheduler.WithFrameworkOutOfTreeRegistry(registry),
    )
    
    if err != nil {
        return nil, fmt.Errorf("failed to create scheduler: %v", err)
    }
    
    return &CustomScheduler{
        clientset: clientset,
        scheduler: sched,
    }, nil
}

func (cs *CustomScheduler) Run(ctx context.Context) {
    klog.Info("Starting custom scheduler")
    cs.scheduler.Run(ctx)
}
```

#### 6. **Custom Scheduler Deployment**
```yaml
# custom-scheduler-deployment.yaml
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
        command:
        - /usr/local/bin/custom-scheduler
        - --config=/etc/kubernetes/scheduler-config.yaml
        - --v=2
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
        volumeMounts:
        - name: config
          mountPath: /etc/kubernetes
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: custom-scheduler-config

---
# ServiceAccount for custom scheduler
apiVersion: v1
kind: ServiceAccount
metadata:
  name: custom-scheduler
  namespace: kube-system

---
# ClusterRole for custom scheduler
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom-scheduler
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch", "update"]
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["endpoints"]
  resourceNames: ["custom-scheduler"]
  verbs: ["get", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["delete", "get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["bindings", "pods/binding"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/status"]
  verbs: ["patch", "update"]
- apiGroups: [""]
  resources: ["replicationcontrollers", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps", "extensions"]
  resources: ["replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "csinodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["create", "get", "list", "update"]

---
# ClusterRoleBinding for custom scheduler
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: custom-scheduler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: custom-scheduler
subjects:
- kind: ServiceAccount
  name: custom-scheduler
  namespace: kube-system

---
# ConfigMap for scheduler configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-scheduler-config
  namespace: kube-system
data:
  scheduler-config.yaml: |
    apiVersion: kubescheduler.config.k8s.io/v1beta3
    kind: KubeSchedulerConfiguration
    profiles:
    - schedulerName: custom-scheduler
      plugins:
        score:
          enabled:
          - name: CostAware
          - name: WorkloadAware
        filter:
          enabled:
          - name: LocalityAware
      pluginConfig:
      - name: CostAware
        args:
          costWeightFactor: 0.5
          utilizationWeightFactor: 0.5
      - name: WorkloadAware
        args:
          enableWorkloadOptimization: true
      - name: LocalityAware
        args:
          enableStrictLocality: false
    leaderElection:
      leaderElect: true
      resourceName: custom-scheduler
      resourceNamespace: kube-system
```

### 🔧 Утилиты для тестирования Advanced Scheduling

#### Скрипт для тестирования scheduling constraints:
```bash
#!/bin/bash
# test-advanced-scheduling.sh

echo "🧪 Testing Advanced Scheduling Constraints"

# Test node affinity
test_node_affinity() {
    echo "=== Testing Node Affinity ==="
    
    # Create test pod with node affinity
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-affinity-test
  namespace: default
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role.kubernetes.io/worker
            operator: Exists
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["fra1-1"]
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

    # Wait for scheduling
    kubectl wait --for=condition=PodScheduled pod/node-affinity-test --timeout=60s
    
    if [ $? -eq 0 ]; then
        echo "✅ Node affinity test passed"
        scheduled_node=$(kubectl get pod node-affinity-test -o jsonpath='{.spec.nodeName}')
        echo "Pod scheduled on node: $scheduled_node"
    else
        echo "❌ Node affinity test failed"
        kubectl describe pod node-affinity-test | grep -A 5 "Events:"
    fi
}

# Test pod anti-affinity
test_pod_anti_affinity() {
    echo "=== Testing Pod Anti-Affinity ==="
    
    # Create deployment with anti-affinity
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: anti-affinity-test
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: anti-affinity-test
  template:
    metadata:
      labels:
        app: anti-affinity-test
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: ["anti-affinity-test"]
            topologyKey: kubernetes.io/hostname
      containers:
      - name: test
        image: busybox
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
EOF

    # Wait for deployment
    kubectl wait --for=condition=available deployment/anti-affinity-test --timeout=120s
    
    if [ $? -eq 0 ]; then
        echo "✅ Pod anti-affinity test passed"
        
        # Check pod distribution
        echo "--- Pod Distribution ---"
        kubectl get pods -l app=anti-affinity-test -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
        
        # Verify no two pods on same node
        nodes=$(kubectl get pods -l app=anti-affinity-test -o jsonpath='{.items[*].spec.nodeName}')
        unique_nodes=$(echo $nodes | tr ' ' '\n' | sort -u | wc -l)
        total_pods=$(kubectl get pods -l app=anti-affinity-test --no-headers | wc -l)
        
        if [ "$unique_nodes" -eq "$total_pods" ]; then
            echo "✅ Anti-affinity constraint satisfied: each pod on different node"
        else
            echo "⚠️  Anti-affinity constraint partially satisfied: $unique_nodes nodes for $total_pods pods"
        fi
    else
        echo "❌ Pod anti-affinity test failed"
        kubectl get pods -l app=anti-affinity-test
    fi
}

# Test topology spread constraints
test_topology_spread() {
    echo "=== Testing Topology Spread Constraints ==="
    
    # Create deployment with topology spread
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: topology-spread-test
  namespace: default
spec:
  replicas: 6
  selector:
    matchLabels:
      app: topology-spread-test
  template:
    metadata:
      labels:
        app: topology-spread-test
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: topology-spread-test
      - maxSkew: 2
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: topology-spread-test
      containers:
      - name: test
        image: busybox
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
EOF

    # Wait for deployment
    kubectl wait --for=condition=available deployment/topology-spread-test --timeout=120s
    
    if [ $? -eq 0 ]; then
        echo "✅ Topology spread test passed"
        
        # Check distribution across zones
        echo "--- Zone Distribution ---"
        kubectl get pods -l app=topology-spread-test -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone
        
        # Count pods per zone
        zones=$(kubectl get pods -l app=topology-spread-test -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' | tr ' ' '\n' | sort | uniq -c)
        echo "Pods per zone:"
        echo "$zones"
    else
        echo "❌ Topology spread test failed"
        kubectl get pods -l app=topology-spread-test
    fi
}

# Test taints and tolerations
test_taints_tolerations() {
    echo "=== Testing Taints and Tolerations ==="
    
    # Add taint to a node (if available)
    nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    test_node=$(echo $nodes | cut -d' ' -f1)
    
    if [ -n "$test_node" ]; then
        echo "Adding test taint to node: $test_node"
        kubectl taint node $test_node test-taint=true:NoSchedule --overwrite
        
        # Create pod without toleration (should not schedule)
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-toleration-test
  namespace: default
spec:
  nodeSelector:
    kubernetes.io/hostname: $test_node
  containers:
  - name: test
    image: busybox
    command: ["sleep", "60"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

        # Wait and check if pod is pending
        sleep 10
        status=$(kubectl get pod no-toleration-test -o jsonpath='{.status.phase}')
        if [ "$status" = "Pending" ]; then
            echo "✅ Taint working: pod without toleration is pending"
        else
            echo "❌ Taint not working: pod scheduled without toleration"
        fi
        
        # Create pod with toleration (should schedule)
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: with-toleration-test
  namespace: default
spec:
  tolerations:
  - key: test-taint
    operator: Equal
    value: "true"
    effect: NoSchedule
  nodeSelector:
    kubernetes.io/hostname: $test_node
  containers:
  - name: test
    image: busybox
    command: ["sleep", "60"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

        # Wait for scheduling
        kubectl wait --for=condition=PodScheduled pod/with-toleration-test --timeout=60s
        
        if [ $? -eq 0 ]; then
            echo "✅ Toleration working: pod with toleration scheduled"
        else
            echo "❌ Toleration not working: pod with toleration not scheduled"
        fi
        
        # Remove test taint
        kubectl taint node $test_node test-taint:NoSchedule- || true
    else
        echo "⚠️  No nodes available for taint testing"
    fi
}

# Test custom scheduler
test_custom_scheduler() {
    echo "=== Testing Custom Scheduler ==="
    
    # Check if custom scheduler is running
    custom_scheduler_pod=$(kubectl get pods -n kube-system -l app=custom-scheduler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$custom_scheduler_pod" ]; then
        echo "✅ Custom scheduler found: $custom_scheduler_pod"
        
        # Create pod with custom scheduler
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: custom-scheduler-test
  namespace: default
  labels:
    workload-type: cpu-intensive
  annotations:
    scheduler.example.com/locality: "fra1-1"
spec:
  schedulerName: custom-scheduler
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: 500m
        memory: 256Mi
EOF

        # Wait for scheduling
        kubectl wait --for=condition=PodScheduled pod/custom-scheduler-test --timeout=60s
        
        if [ $? -eq 0 ]; then
            echo "✅ Custom scheduler test passed"
            scheduled_node=$(kubectl get pod custom-scheduler-test -o jsonpath='{.spec.nodeName}')
            echo "Pod scheduled on node: $scheduled_node"
        else
            echo "❌ Custom scheduler test failed"
            kubectl describe pod custom-scheduler-test | grep -A 5 "Events:"
        fi
    else
        echo "⚠️  Custom scheduler not found, skipping test"
    fi
}

# Performance test
test_scheduling_performance() {
    echo "=== Testing Scheduling Performance ==="
    
    local pod_count=${1:-10}
    echo "Creating $pod_count pods with complex constraints..."
    
    start_time=$(date +%s)
    
    # Create pods with complex scheduling constraints
    for i in $(seq 1 $pod_count); do
        cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: perf-test-$i
  namespace: default
  labels:
    app: perf-test
    batch: performance
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values: ["perf-test"]
          topologyKey: kubernetes.io/hostname
  topologySpreadConstraints:
  - maxSkew: 2
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        batch: performance
  containers:
  - name: test
    image: busybox
    command: ["sleep", "300"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF
    done
    
    # Wait for all pods to be scheduled
    kubectl wait --for=condition=PodScheduled pod -l batch=performance --timeout=300s
    end_time=$(date +%s)
    
    scheduling_time=$((end_time - start_time))
    scheduled_count=$(kubectl get pods -l batch=performance --field-selector=status.phase=Running --no-headers | wc -l)
    
    echo "✅ Performance test completed"
    echo "Scheduled $scheduled_count/$pod_count pods in ${scheduling_time}s"
    echo "Average scheduling time: $(echo "scale=2; $scheduling_time / $pod_count" | bc 2>/dev/null || echo "N/A")s per pod"
}

# Cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up Test Resources ==="
    
    kubectl delete pod node-affinity-test --ignore-not-found=true
    kubectl delete deployment anti-affinity-test --ignore-not-found=true
    kubectl delete deployment topology-spread-test --ignore-not-found=true
    kubectl delete pod no-toleration-test --ignore-not-found=true
    kubectl delete pod with-toleration-test --ignore-not-found=true
    kubectl delete pod custom-scheduler-test --ignore-not-found=true
    kubectl delete pods -l batch=performance --ignore-not-found=true
    
    echo "✅ Cleanup completed"
}

# Main execution
main() {
    echo "Testing Advanced Scheduling Constraints"
    echo ""
    
    test_node_affinity
    echo ""
    
    test_pod_anti_affinity
    echo ""
    
    test_topology_spread
    echo ""
    
    test_taints_tolerations
    echo ""
    
    test_custom_scheduler
    echo ""
    
    test_scheduling_performance 5
    echo ""
    
    read -p "Cleanup test resources? (y/n): " cleanup
    if [ "$cleanup" = "y" ]; then
        cleanup_test_resources
    fi
}

# Check if arguments provided
if [ $# -eq 0 ]; then
    main
else
    main "$@"
fi
```

### 🎯 Заключение

Advanced Scheduling Constraints обеспечивают точное управление размещением подов для оптимизации производительности, доступности и затрат:

**Ключевые механизмы:**
1. **Node Affinity** - привязка к узлам по характеристикам
2. **Pod Affinity/Anti-Affinity** - управление совместным размещением
3. **Topology Spread Constraints** - равномерное распределение
4. **Taints & Tolerations** - изоляция и специализация узлов
5. **Custom Schedulers** - специализированная логика планирования

**Практические применения:**
- **High Availability** - распределение критических сервисов
- **Performance Optimization** - совместное размещение связанных компонентов
- **Resource Isolation** - выделение специализированных узлов
- **Cost Optimization** - эффективное использование ресурсов
- **Compliance** - соблюдение требований размещения данных

Advanced Scheduling Constraints являются мощным инструментом для создания эффективных и надежных Kubernetes кластеров в production среде.
