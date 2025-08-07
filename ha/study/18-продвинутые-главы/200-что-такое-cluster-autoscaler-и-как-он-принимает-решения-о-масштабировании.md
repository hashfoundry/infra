# 200. Что такое Cluster Autoscaler и как он принимает решения о масштабировании?

## 🎯 **Что такое Cluster Autoscaler?**

**Cluster Autoscaler** — это компонент Kubernetes, который автоматически изменяет размер кластера (добавляет или удаляет узлы) в зависимости от потребностей в ресурсах. Он анализирует pending Pod'ы и использование ресурсов для принятия решений о масштабировании.

## 🏗️ **Основные функции Cluster Autoscaler:**

### **1. Scale-Up (Увеличение кластера)**
- Обнаружение pending Pod'ов из-за нехватки ресурсов
- Автоматическое добавление новых Node'ов
- Интеграция с cloud provider API

### **2. Scale-Down (Уменьшение кластера)**
- Мониторинг недоиспользуемых Node'ов
- Безопасное удаление пустых Node'ов
- Соблюдение PodDisruptionBudgets

### **3. Resource Optimization**
- Минимизация затрат на инфраструктуру
- Эффективное использование ресурсов
- Балансировка между availability и cost

### 🏗️ Архитектура Cluster Autoscaler

#### 1. **Схема Cluster Autoscaler Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│              Cluster Autoscaler Architecture               │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   Pod Scheduling                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Pending   │    │  Scheduled  │    │ Unscheduled │ │ │
│  │  │    Pods     │───▶│    Pods     │───▶│    Pods     │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Cluster Autoscaler                      │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Scale-Up  │    │ Scale-Down  │    │   Node      │ │ │
│  │  │   Logic     │───▶│   Logic     │───▶│ Management  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Decision Engine                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  Resource   │    │   Policy    │    │  Simulation │ │ │
│  │  │ Monitoring  │───▶│ Evaluation  │───▶│  & Testing  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Cloud Provider API                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    AWS      │    │   Azure     │    │    GCP      │ │ │
│  │  │ Auto Scaling│───▶│ Scale Sets  │───▶│ Instance    │ │ │
│  │  │   Groups    │    │             │    │   Groups    │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  Node Pool                             │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Worker    │    │   Worker    │    │   Worker    │ │ │
│  │  │   Node 1    │───▶│   Node 2    │───▶│   Node N    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Scaling Decision Logic**
```yaml
# Cluster Autoscaler Decision Logic
scaling_decisions:
  scale_up_triggers:
    pending_pods:
      condition: "Pods cannot be scheduled due to insufficient resources"
      evaluation_period: "10 seconds"
      requirements:
        - "Pod has been pending for more than 10 seconds"
        - "No suitable node exists for pod scheduling"
        - "Adding a node would enable pod scheduling"
    
    resource_pressure:
      cpu_threshold: "80%"
      memory_threshold: "80%"
      evaluation_window: "5 minutes"
      
    node_group_constraints:
      min_size: "Minimum nodes per node group"
      max_size: "Maximum nodes per node group"
      desired_capacity: "Target number of nodes"

  scale_down_triggers:
    node_underutilization:
      cpu_threshold: "50%"
      memory_threshold: "50%"
      evaluation_period: "10 minutes"
      grace_period: "10 minutes"
    
    node_emptiness:
      condition: "Node has no non-DaemonSet pods"
      evaluation_period: "10 minutes"
      
    cost_optimization:
      target: "Minimize cluster cost while maintaining SLA"
      strategy: "Remove least utilized nodes first"

  scaling_policies:
    scale_up_policy:
      max_nodes_per_scale: "10"
      scale_up_delay: "0 seconds"
      stabilization_window: "3 minutes"
      
    scale_down_policy:
      max_nodes_per_scale: "1"
      scale_down_delay: "10 minutes"
      stabilization_window: "5 minutes"
      
    node_group_priorities:
      strategy: "Priority-based scaling"
      factors:
        - "Cost per hour"
        - "Resource efficiency"
        - "Availability zone distribution"

  decision_algorithm:
    simulation_phase:
      steps:
        - "Identify unschedulable pods"
        - "Find suitable node groups"
        - "Simulate pod placement"
        - "Calculate resource requirements"
        - "Estimate scaling impact"
    
    validation_phase:
      checks:
        - "Node group limits"
        - "Budget constraints"
        - "Availability zone balance"
        - "Taints and tolerations"
        - "Node selectors and affinity"
    
    execution_phase:
      actions:
        - "Call cloud provider API"
        - "Wait for node readiness"
        - "Update cluster state"
        - "Monitor scaling results"

  constraints_and_policies:
    node_constraints:
      unremovable_nodes:
        - "Nodes with local storage pods"
        - "Nodes with non-replicated pods"
        - "Nodes with PodDisruptionBudget violations"
        - "Nodes with system pods (non-DaemonSet)"
      
      removable_nodes:
        - "Nodes with only DaemonSet pods"
        - "Empty nodes (no pods)"
        - "Nodes with replicated pods that can be rescheduled"
    
    scaling_constraints:
      rate_limiting:
        max_scale_up_rate: "10 nodes per minute"
        max_scale_down_rate: "1 node per minute"
        
      resource_limits:
        max_cluster_size: "1000 nodes"
        max_node_group_size: "100 nodes"
        
      cost_controls:
        budget_limits: "Monthly spending cap"
        instance_types: "Allowed instance types"
```

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка DigitalOcean Auto-scaling:**
```bash
# Проверка кластера и node pools в DigitalOcean
doctl kubernetes cluster get hashfoundry-ha

# Проверка node pool настроек
doctl kubernetes cluster node-pool list hashfoundry-ha

# Текущие Node'ы в кластере
kubectl get nodes -o wide

# Проверка auto-scaling меток на Node'ах
kubectl get nodes --show-labels | grep "doks.digitalocean.com"

# Проверка pending Pod'ов
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```

### **2. ArgoCD и Monitoring на Node'ах:**
```bash
# ArgoCD Pod'ы и их размещение
kubectl get pods -n argocd -o wide

# Monitoring Pod'ы и их размещение
kubectl get pods -n monitoring -o wide

# Resource requests критических сервисов
kubectl describe deployment argocd-server -n argocd | grep -A 10 "Requests"
kubectl describe deployment prometheus-server -n monitoring | grep -A 10 "Requests"

# Использование ресурсов Node'ов
kubectl top nodes
kubectl describe nodes | grep -A 10 "Allocated resources"
```

### **3. Тестирование auto-scaling:**
```bash
# Создание ресурсоемкого Deployment
kubectl create deployment scale-test --image=nginx --replicas=1

# Установка высоких resource requests
kubectl patch deployment scale-test -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"cpu":"1500m","memory":"2Gi"}}}]}}}}'

# Масштабирование для создания pressure
kubectl scale deployment scale-test --replicas=8

# Мониторинг auto-scaling процесса
watch "kubectl get nodes; echo '---'; kubectl get pods -l app=scale-test"

# Очистка
kubectl delete deployment scale-test
```

### **4. Мониторинг в Grafana:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Ключевые метрики для auto-scaling:
# - node_cpu_utilization
# - node_memory_utilization  
# - kube_node_status_ready
# - kube_pod_status_phase{phase="Pending"}
```

### 🛠️ Реализация Cluster Autoscaler

#### 1. **Cluster Autoscaler Deployment**
```yaml
# cluster-autoscaler.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '8085'
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=digitalocean
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=digitalocean:tag=k8s-cluster-autoscaler-enabled
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        - --max-node-provision-time=15m
        - --max-nodes-total=10
        - --cores-total=0:100
        - --memory-total=0:1000
        env:
        - name: DO_TOKEN
          valueFrom:
            secretKeyRef:
              name: cluster-autoscaler-secret
              key: token
        - name: CLUSTER_NAME
          value: "hashfoundry-ha"
        volumeMounts:
        - name: ssl-certs
          mountPath: /etc/ssl/certs/ca-certificates.crt
          readOnly: true
        imagePullPolicy: Always
      volumes:
      - name: ssl-certs
        hostPath:
          path: /etc/ssl/certs/ca-certificates.crt

---
# ServiceAccount for cluster autoscaler
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
  name: cluster-autoscaler
  namespace: kube-system

---
# ClusterRole for cluster autoscaler
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
- apiGroups: [""]
  resources: ["events", "endpoints"]
  verbs: ["create", "patch"]
- apiGroups: [""]
  resources: ["pods/eviction"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/status"]
  verbs: ["update"]
- apiGroups: [""]
  resources: ["endpoints"]
  resourceNames: ["cluster-autoscaler"]
  verbs: ["get", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["watch", "list", "get", "update"]
- apiGroups: [""]
  resources: ["pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["extensions"]
  resources: ["replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["watch", "list"]
- apiGroups: ["apps"]
  resources: ["statefulsets", "replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "csinodes"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "patch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["create"]
- apiGroups: ["coordination.k8s.io"]
  resourceNames: ["cluster-autoscaler"]
  resources: ["leases"]
  verbs: ["get", "update"]

---
# ClusterRoleBinding for cluster autoscaler
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-autoscaler
subjects:
- kind: ServiceAccount
  name: cluster-autoscaler
  namespace: kube-system

---
# Secret for cloud provider credentials
apiVersion: v1
kind: Secret
metadata:
  name: cluster-autoscaler-secret
  namespace: kube-system
type: Opaque
data:
  token: ZG9wX3YxX2JjODg1OTM1OTY0MTRkN2E2YWE1MzVmODQ4OTcyZTFiMGViZmE1NDBhNDVjMWZjMmE5MWU1MzU2YjVmOWEyYzI=  # base64 encoded DO token
```

#### 2. **Node Pool Configuration**
```yaml
# node-pool-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-config
  namespace: kube-system
data:
  nodes.max: "10"
  nodes.min: "3"
  scale-down-enabled: "true"
  scale-down-delay-after-add: "10m"
  scale-down-unneeded-time: "10m"
  scale-down-utilization-threshold: "0.5"
  skip-nodes-with-local-storage: "false"
  skip-nodes-with-system-pods: "false"
  expander: "least-waste"
  balance-similar-node-groups: "true"
  max-node-provision-time: "15m"

---
# Node pool labels for autoscaling
apiVersion: v1
kind: Node
metadata:
  name: worker-node-1
  labels:
    node-pool: "ha-worker-pool"
    k8s-cluster-autoscaler-enabled: "true"
    k8s-cluster-autoscaler-hashfoundry-ha: "owned"
    instance-type: "s-2vcpu-4gb"
    topology.kubernetes.io/zone: "fra1-1"
spec:
  # Node specification
```

#### 3. **Test Workloads для Autoscaling**
```yaml
# test-scaling-workload.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-intensive-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-intensive-app
  template:
    metadata:
      labels:
        app: resource-intensive-app
    spec:
      containers:
      - name: cpu-intensive
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting CPU intensive workload..."
          while true; do
            for i in $(seq 1 4); do
              dd if=/dev/zero of=/dev/null &
            done
            sleep 10
            killall dd
            sleep 5
          done
        resources:
          requests:
            cpu: 1000m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 2Gi

---
# Horizontal Pod Autoscaler for testing
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: resource-intensive-app-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-intensive-app
  minReplicas: 1
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60

---
# Load generator for testing
apiVersion: batch/v1
kind: Job
metadata:
  name: load-generator
  namespace: default
spec:
  parallelism: 5
  completions: 10
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      restartPolicy: Never
      containers:
      - name: load-generator
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Generating load..."
          # Generate CPU load
          for i in $(seq 1 300); do
            echo "Load iteration $i"
            dd if=/dev/zero of=/tmp/test bs=1M count=100 2>/dev/null
            rm /tmp/test
            sleep 1
          done
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
```

### 🔧 Утилиты для мониторинга Cluster Autoscaler

#### Скрипт для мониторинга autoscaling:
```bash
#!/bin/bash
# monitor-cluster-autoscaler.sh

echo "🔍 Monitoring Cluster Autoscaler"

# Monitor cluster autoscaler status
monitor_autoscaler_status() {
    echo "=== Cluster Autoscaler Status ==="
    
    # Check if autoscaler is running
    autoscaler_pod=$(kubectl get pods -n kube-system -l app=cluster-autoscaler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$autoscaler_pod" ]; then
        echo "✅ Cluster Autoscaler pod: $autoscaler_pod"
        
        # Check pod status
        status=$(kubectl get pod $autoscaler_pod -n kube-system -o jsonpath='{.status.phase}')
        echo "Pod status: $status"
        
        # Check recent logs
        echo "--- Recent Autoscaler Logs ---"
        kubectl logs -n kube-system $autoscaler_pod --tail=10 | grep -E "(scale|node|decision)"
    else
        echo "❌ Cluster Autoscaler pod not found"
        return 1
    fi
}

# Monitor node status and capacity
monitor_node_status() {
    echo "=== Node Status and Capacity ==="
    
    # Show current nodes
    echo "--- Current Nodes ---"
    kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,ROLES:.metadata.labels.node-role\\.kubernetes\\.io/worker,AGE:.metadata.creationTimestamp,INSTANCE-TYPE:.metadata.labels.node\\.kubernetes\\.io/instance-type
    
    # Show node resource usage
    echo "--- Node Resource Usage ---"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    
    # Show node capacity and allocatable
    echo "--- Node Capacity ---"
    kubectl describe nodes | grep -A 5 "Capacity:\|Allocatable:" | head -20
}

# Monitor pending pods
monitor_pending_pods() {
    echo "=== Pending Pods Analysis ==="
    
    # Get pending pods
    pending_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers)
    
    if [ -n "$pending_pods" ]; then
        echo "⚠️  Found pending pods:"
        echo "$pending_pods"
        
        # Analyze why pods are pending
        echo "--- Pending Pod Details ---"
        kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REASON:.status.conditions[0].reason,MESSAGE:.status.conditions[0].message
    else
        echo "✅ No pending pods found"
    fi
}

# Monitor scaling events
monitor_scaling_events() {
    echo "=== Scaling Events ==="
    
    # Get recent scaling events
    echo "--- Recent Scaling Events ---"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "scale\|autoscaler\|node" | tail -10
    
    # Check for specific autoscaler events
    echo "--- Autoscaler Specific Events ---"
    kubectl get events --all-namespaces --field-selector source=cluster-autoscaler --sort-by='.lastTimestamp' | tail -5
}

# Monitor resource pressure
monitor_resource_pressure() {
    echo "=== Resource Pressure Analysis ==="
    
    # Calculate cluster resource usage
    echo "--- Cluster Resource Summary ---"
    
    # Get total cluster capacity
    total_cpu=$(kubectl describe nodes | grep "cpu:" | grep "Capacity" | awk '{sum += $2} END {print sum}')
    total_memory=$(kubectl describe nodes | grep "memory:" | grep "Capacity" | awk '{sum += $2} END {print sum}')
    
    # Get allocated resources
    allocated_cpu=$(kubectl describe nodes | grep "cpu" | grep "Allocated resources" -A 10 | grep "cpu" | awk '{sum += $2} END {print sum}')
    allocated_memory=$(kubectl describe nodes | grep "memory" | grep "Allocated resources" -A 10 | grep "memory" | awk '{sum += $2} END {print sum}')
    
    echo "Total CPU: ${total_cpu}m"
    echo "Allocated CPU: ${allocated_cpu}m"
    echo "Total Memory: ${total_memory}Ki"
    echo "Allocated Memory: ${allocated_memory}Ki"
    
    # Check for resource pressure
    if command -v bc >/dev/null 2>&1; then
        cpu_usage=$(echo "scale=2; $allocated_cpu * 100 / $total_cpu" | bc 2>/dev/null || echo "N/A")
        echo "CPU Usage: ${cpu_usage}%"
    fi
}

# Test autoscaling behavior
test_autoscaling() {
    echo "=== Testing Autoscaling Behavior ==="
    
    # Create resource-intensive deployment
    echo "--- Creating test workload ---"
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: autoscaler-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: autoscaler-test
  template:
    metadata:
      labels:
        app: autoscaler-test
    spec:
      containers:
      - name: test
        image: busybox
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 1000m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 2Gi
EOF

    # Wait for deployment
    kubectl wait --for=condition=available deployment/autoscaler-test --timeout=60s
    
    if [ $? -eq 0 ]; then
        echo "✅ Test deployment created"
    else
        echo "❌ Test deployment failed"
        return 1
    fi
    
    # Scale up the deployment to trigger autoscaling
    echo "--- Scaling up test deployment ---"
    kubectl scale deployment autoscaler-test --replicas=10
    
    # Monitor for a few minutes
    echo "--- Monitoring scaling behavior ---"
    for i in $(seq 1 12); do
        echo "Check $i/12:"
        kubectl get pods -l app=autoscaler-test --no-headers | wc -l | xargs echo "Running pods:"
        kubectl get pods -l app=autoscaler-test --field-selector=status.phase=Pending --no-headers | wc -l | xargs echo "Pending pods:"
        kubectl get nodes --no-headers | wc -l | xargs echo "Total nodes:"
        echo "---"
        sleep 30
    done
}

# Generate autoscaling report
generate_autoscaling_report() {
    echo "=== Autoscaling Report ==="
    
    # Cluster overview
    echo "--- Cluster Overview ---"
    echo "Cluster: $(kubectl config current-context)"
    echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "Pods: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
    echo "Pending Pods: $(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers | wc -l)"
    
    # Autoscaler configuration
    echo "--- Autoscaler Configuration ---"
    autoscaler_pod=$(kubectl get pods -n kube-system -l app=cluster-autoscaler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$autoscaler_pod" ]; then
        kubectl describe pod $autoscaler_pod -n kube-system | grep -A 20 "Command:"
    fi
    
    # Recent scaling activity
    echo "--- Recent Scaling Activity ---"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "scale\|autoscaler" | tail -5
    
    # Resource utilization
    echo "--- Resource Utilization ---"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
}

# Cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up Test Resources ==="
    
    kubectl delete deployment autoscaler-test --ignore-not-found=true
    kubectl delete job load-generator --ignore-not-found=true
    
    echo "✅ Cleanup completed"
}

# Main execution
main() {
    local action=${1:-"monitor"}
    
    case $action in
        "monitor")
            echo "Monitoring Cluster Autoscaler"
            echo ""
            
            monitor_autoscaler_status
            echo ""
            
            monitor_node_status
            echo ""
            
            monitor_pending_pods
            echo ""
            
            monitor_scaling_events
            echo ""
            
            monitor_resource_pressure
            ;;
            
        "test")
            echo "Testing Autoscaling Behavior"
            echo ""
            
            test_autoscaling
            echo ""
            
            read -p "Cleanup test resources? (y/n): " cleanup
            if [ "$cleanup" = "y" ]; then
                cleanup_test_resources
            fi
            ;;
            
        "report")
            echo "Generating Autoscaling Report"
            echo ""
            
            generate_autoscaling_report
            ;;
            
        *)
            echo "Usage: $0 [monitor|test|report]"
            echo ""
            echo "Commands:"
            echo "  monitor  - Monitor current autoscaler status"
            echo "  test     - Test autoscaling behavior"
            echo "  report   - Generate comprehensive report"
            ;;
    esac
}

# Execute main function
main "$@"
```

## 🔄 **Алгоритм принятия решений:**

### **1. Scale-Up Decision:**
```bash
# Условия для увеличения кластера:
# 1. Pod'ы в состоянии Pending > 10 секунд
# 2. Нет подходящих Node'ов для размещения
# 3. Добавление Node'а решит проблему
# 4. Не превышены лимиты node pool

# Проверка pending Pod'ов
kubectl describe pod <pending-pod> | grep -A 10 "Events"

# Проверка resource requests
kubectl describe pod <pending-pod> | grep -A 5 "Requests"

# Проверка node capacity
kubectl describe nodes | grep -A 10 "Allocatable"
```

### **2. Scale-Down Decision:**
```bash
# Условия для уменьшения кластера:
# 1. Node недоиспользуется > 10 минут
# 2. Все Pod'ы могут быть перемещены
# 3. Нет нарушений PodDisruptionBudget
# 4. Нет системных Pod'ов (кроме DaemonSet)

# Проверка использования Node'ов
kubectl top nodes

# Проверка Pod'ов на Node'ах
kubectl describe node <node-name> | grep -A 20 "Non-terminated Pods"

# Проверка PodDisruptionBudgets
kubectl get pdb --all-namespaces
```

## 🔧 **Демонстрация Auto-scaling:**

### **1. Создание нагрузки для scale-up:**
```bash
# Deployment с высокими resource requests
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hungry
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-hungry
  template:
    metadata:
      labels:
        app: resource-hungry
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 1500m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 3Gi
EOF

# Масштабирование для создания pressure
kubectl scale deployment resource-hungry --replicas=5

# Мониторинг pending Pod'ов
kubectl get pods -l app=resource-hungry -w
```

### **2. HPA для автоматического scaling:**
```bash
# HorizontalPodAutoscaler
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: resource-hungry-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-hungry
  minReplicas: 1
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF

# Генерация CPU нагрузки
kubectl patch deployment resource-hungry -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","command":["sh","-c","while true; do dd if=/dev/zero of=/dev/null; done"]}]}}}}'

# Мониторинг HPA
kubectl get hpa resource-hungry-hpa -w
```

### **3. Тестирование scale-down:**
```bash
# Уменьшение нагрузки
kubectl scale deployment resource-hungry --replicas=1

# Остановка CPU нагрузки
kubectl patch deployment resource-hungry -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","command":["sleep","3600"]}]}}}}'

# Мониторинг уменьшения кластера (займет ~10-15 минут)
watch "kubectl get nodes; echo '---'; kubectl top nodes"

# Очистка
kubectl delete deployment resource-hungry
kubectl delete hpa resource-hungry-hpa
```

## 📈 **Мониторинг Auto-scaling:**

### **1. DigitalOcean метрики:**
```bash
# Проверка node pool статуса
doctl kubernetes cluster node-pool get hashfoundry-ha ha-worker-pool

# История scaling событий в DigitalOcean
doctl kubernetes cluster node-pool list hashfoundry-ha

# Проверка лимитов auto-scaling
doctl kubernetes cluster get hashfoundry-ha --format ID,Name,Status,AutoUpgrade,SurgeUpgrade,HA
```

### **2. Kubernetes события:**
```bash
# События связанные с Node'ами
kubectl get events --all-namespaces --field-selector involvedObject.kind=Node

# События планировщика
kubectl get events --all-namespaces --field-selector reason=FailedScheduling

# Общие события кластера
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

### **3. Prometheus метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики для auto-scaling:
# - kube_node_status_ready
# - kube_pod_status_phase{phase="Pending"}
# - node_cpu_utilization
# - node_memory_utilization
# - kube_deployment_status_replicas
```

## 🏭 **Auto-scaling в вашем HA кластере:**

### **1. DigitalOcean Integration:**
```bash
# Конфигурация HA кластера
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\\.kubernetes\\.io/instance-type,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone

# Auto-scaling настройки
doctl kubernetes cluster node-pool get hashfoundry-ha ha-worker-pool --format Name,Size,Count,AutoScale,MinNodes,MaxNodes

# Проверка распределения по зонам
kubectl get nodes --show-labels | grep topology.kubernetes.io/zone
```

### **2. ArgoCD и Auto-scaling:**
```bash
# ArgoCD Pod'ы и их размещение
kubectl get pods -n argocd -o wide

# Resource requests ArgoCD
kubectl describe deployment argocd-server -n argocd | grep -A 10 "Requests"

# Влияние ArgoCD на auto-scaling
kubectl top pods -n argocd
```

### **3. Monitoring Stack и Auto-scaling:**
```bash
# Prometheus и Grafana размещение
kubectl get pods -n monitoring -o wide

# Resource usage monitoring stack
kubectl top pods -n monitoring

# PersistentVolumes и auto-scaling
kubectl get pv | grep monitoring
```

## 🚨 **Troubleshooting Auto-scaling:**

### **1. Pod'ы не масштабируются:**
```bash
# Проверка resource requests
kubectl describe pod <pending-pod> | grep -A 5 "Requests"

# Проверка node capacity
kubectl describe nodes | grep -A 10 "Allocatable"

# Проверка taints и tolerations
kubectl describe nodes | grep -A 5 "Taints"

# Проверка node selectors
kubectl describe pod <pending-pod> | grep -A 5 "Node-Selectors"
```

### **2. Кластер не уменьшается:**
```bash
# Проверка PodDisruptionBudgets
kubectl get pdb --all-namespaces

# Проверка системных Pod'ов
kubectl get pods --all-namespaces -o wide | grep -v "kube-system\|default"

# Проверка local storage
kubectl get pods --all-namespaces -o yaml | grep -A 5 "hostPath\|emptyDir"

# Проверка non-replicated Pod'ов
kubectl get pods --all-namespaces --field-selector metadata.ownerReferences=null
```

### **3. Медленное масштабирование:**
```bash
# Проверка DigitalOcean API limits
doctl auth list

# Проверка времени создания Node'ов
kubectl get events --all-namespaces | grep "Started\|Created" | grep node

# Проверка image pull времени
kubectl describe pod <pod-name> | grep -A 10 "Events" | grep "Pulling\|Pulled"
```

## 🎯 **Архитектура Auto-scaling:**

```
┌─────────────────────────────────────────────────────────────┐
│            DigitalOcean Auto-scaling Architecture          │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes Scheduler                                       │
│  ├── Detect pending pods                                   │
│  ├── Evaluate resource requirements                        │
│  └── Trigger scaling decisions                             │
├─────────────────────────────────────────────────────────────┤
│  DigitalOcean Control Plane                                │
│  ├── Monitor node pool utilization                         │
│  ├── Apply auto-scaling policies                           │
│  ├── Manage min/max node limits                            │
│  └── Coordinate with Kubernetes API                        │
├─────────────────────────────────────────────────────────────┤
│  Node Pool Management                                       │
│  ├── Scale-up: Add nodes when needed                       │
│  ├── Scale-down: Remove underutilized nodes                │
│  ├── Health checks and node replacement                    │
│  └── Zone distribution and HA                              │
├─────────────────────────────────────────────────────────────┤
│  Resource Monitoring                                        │
│  ├── CPU and memory utilization                            │
│  ├── Pod scheduling success rate                           │
│  ├── Node availability and health                          │
│  └── Application performance metrics                       │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Best Practices для Auto-scaling:**

### **1. Resource Planning:**
- Устанавливайте правильные resource requests
- Планируйте min/max размеры node pools
- Учитывайте startup время приложений

### **2. Cost Optimization:**
- Используйте подходящие instance types
- Настройте aggressive scale-down для dev
- Мониторьте затраты на инфраструктуру

### **3. High Availability:**
- Распределяйте Node'ы по зонам
- Используйте PodDisruptionBudgets
- Планируйте capacity для критических сервисов

### **4. Monitoring и Alerting:**
- Мониторьте pending Pod'ы
- Настройте алерты на scaling события
- Отслеживайте performance метрики

**Cluster Autoscaler — это ключевой компонент для эффективного управления ресурсами и затратами в production Kubernetes кластерах!**
