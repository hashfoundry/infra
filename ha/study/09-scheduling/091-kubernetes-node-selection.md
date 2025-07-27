# 91. Kubernetes Node Selection

## 🎯 **Kubernetes Node Selection**

**Node Selection** в Kubernetes - это процесс выбора подходящего узла для размещения Pod'а, выполняемый планировщиком (kube-scheduler) на основе различных критериев, включая ресурсы, ограничения, предпочтения и политики размещения.

## 🏗️ **Компоненты Node Selection:**

### **1. Scheduler Components:**
- **kube-scheduler** - основной планировщик
- **Scheduling Framework** - расширяемая архитектура
- **Plugins** - модули планирования
- **Profiles** - профили планирования

### **2. Selection Criteria:**
- **Resource requirements** - требования к ресурсам
- **Node constraints** - ограничения узлов
- **Affinity rules** - правила сродства
- **Taints and tolerations** - метки и толерантности

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущего node selection:**
```bash
# Проверить состояние планировщика
kubectl get pods -n kube-system -l component=kube-scheduler
kubectl logs -n kube-system -l component=kube-scheduler --tail=50
```

### **2. Создание comprehensive node selection toolkit:**
```bash
# Создать скрипт для анализа node selection
cat << 'EOF' > node-selection-analysis.sh
#!/bin/bash

echo "=== Kubernetes Node Selection Analysis ==="
echo "Comprehensive analysis of node selection for HashFoundry HA cluster"
echo

# Функция для анализа scheduler configuration
analyze_scheduler_config() {
    echo "=== Scheduler Configuration Analysis ==="
    
    echo "1. Scheduler Pods Status:"
    echo "========================"
    kubectl get pods -n kube-system -l component=kube-scheduler -o wide
    echo
    
    echo "2. Scheduler Configuration:"
    echo "=========================="
    # Get scheduler config if available
    kubectl get configmap -n kube-system kube-scheduler-config -o yaml 2>/dev/null || echo "Default scheduler configuration"
    echo
    
    echo "3. Scheduler Events:"
    echo "=================="
    kubectl get events -n kube-system --field-selector involvedObject.name=kube-scheduler --sort-by='.lastTimestamp' | tail -10
    echo
}

# Функция для анализа node resources
analyze_node_resources() {
    echo "=== Node Resources Analysis ==="
    
    echo "1. Node Capacity and Allocatable:"
    echo "================================"
    kubectl get nodes -o custom-columns="NAME:.metadata.name,CPU-CAPACITY:.status.capacity.cpu,MEMORY-CAPACITY:.status.capacity.memory,CPU-ALLOCATABLE:.status.allocatable.cpu,MEMORY-ALLOCATABLE:.status.allocatable.memory"
    echo
    
    echo "2. Node Resource Usage:"
    echo "======================"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "3. Node Conditions:"
    echo "=================="
    kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.status.conditions[] | select(.type=="Ready" or .type=="DiskPressure" or .type=="MemoryPressure" or .type=="PIDPressure") | "\(.type)=\(.status)")"'
    echo
}

# Функция для анализа pod placement
analyze_pod_placement() {
    echo "=== Pod Placement Analysis ==="
    
    echo "1. Pods Distribution Across Nodes:"
    echo "=================================="
    kubectl get pods --all-namespaces -o wide | awk 'NR>1 {count[$7]++} END {for (node in count) print node ": " count[node] " pods"}'
    echo
    
    echo "2. Pending Pods:"
    echo "==============="
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName,REASON:.status.conditions[?(@.type=='PodScheduled')].reason"
    echo
    
    echo "3. Failed Scheduling Events:"
    echo "============================"
    kubectl get events --all-namespaces --field-selector reason=FailedScheduling --sort-by='.lastTimestamp' | tail -10
    echo
}

# Функция для создания node selector examples
create_node_selector_examples() {
    echo "=== Creating Node Selector Examples ==="
    
    # Label nodes for demonstration
    echo "Labeling nodes for examples..."
    NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    
    if [ ${#NODES[@]} -ge 1 ]; then
        kubectl label node ${NODES[0]} hashfoundry.io/workload-type=compute --overwrite
        echo "Labeled ${NODES[0]} as compute node"
    fi
    
    if [ ${#NODES[@]} -ge 2 ]; then
        kubectl label node ${NODES[1]} hashfoundry.io/workload-type=storage --overwrite
        echo "Labeled ${NODES[1]} as storage node"
    fi
    
    if [ ${#NODES[@]} -ge 3 ]; then
        kubectl label node ${NODES[2]} hashfoundry.io/workload-type=network --overwrite
        echo "Labeled ${NODES[2]} as network node"
    fi
    echo
    
    # Create namespace for examples
    kubectl create namespace node-selection-examples --dry-run=client -o yaml | kubectl apply -f -
    
    # Example 1: Basic Node Selector
    cat << NODE_SELECTOR_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compute-workload
  namespace: node-selection-examples
  labels:
    app.kubernetes.io/name: "compute-workload"
    hashfoundry.io/example: "node-selector"
  annotations:
    hashfoundry.io/description: "Example of basic node selector"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "compute-workload"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "compute-workload"
        hashfoundry.io/workload-type: "compute"
    spec:
      nodeSelector:
        hashfoundry.io/workload-type: "compute"
      containers:
      - name: compute-app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        ports:
        - containerPort: 80
NODE_SELECTOR_EOF
    
    # Example 2: Multiple Node Selectors
    cat << MULTI_SELECTOR_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-workload
  namespace: node-selection-examples
  labels:
    app.kubernetes.io/name: "storage-workload"
    hashfoundry.io/example: "multi-selector"
  annotations:
    hashfoundry.io/description: "Example of multiple node selectors"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "storage-workload"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "storage-workload"
        hashfoundry.io/workload-type: "storage"
    spec:
      nodeSelector:
        hashfoundry.io/workload-type: "storage"
        kubernetes.io/arch: "amd64"
      containers:
      - name: storage-app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
        volumeMounts:
        - name: storage-volume
          mountPath: /data
      volumes:
      - name: storage-volume
        emptyDir: {}
MULTI_SELECTOR_EOF
    
    echo "✅ Node selector examples created"
    echo
}

# Функция для создания advanced scheduling examples
create_advanced_scheduling_examples() {
    echo "=== Creating Advanced Scheduling Examples ==="
    
    # Example 1: Resource-based scheduling
    cat << RESOURCE_SCHEDULING_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-intensive-app
  namespace: node-selection-examples
  labels:
    app.kubernetes.io/name: "resource-intensive-app"
    hashfoundry.io/example: "resource-scheduling"
  annotations:
    hashfoundry.io/description: "Example of resource-based scheduling"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "resource-intensive-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "resource-intensive-app"
        hashfoundry.io/resource-tier: "high"
    spec:
      containers:
      - name: resource-app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1"
            memory: "2Gi"
      nodeSelector:
        hashfoundry.io/workload-type: "compute"
RESOURCE_SCHEDULING_EOF
    
    # Example 2: Zone-aware scheduling
    cat << ZONE_SCHEDULING_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zone-aware-app
  namespace: node-selection-examples
  labels:
    app.kubernetes.io/name: "zone-aware-app"
    hashfoundry.io/example: "zone-scheduling"
  annotations:
    hashfoundry.io/description: "Example of zone-aware scheduling"
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: "zone-aware-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "zone-aware-app"
        hashfoundry.io/zone-preference: "multi"
    spec:
      containers:
      - name: zone-app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: "zone-aware-app"
ZONE_SCHEDULING_EOF
    
    echo "✅ Advanced scheduling examples created"
    echo
}

# Функция для создания scheduling analysis tools
create_scheduling_analysis_tools() {
    echo "=== Creating Scheduling Analysis Tools ==="
    
    cat << ANALYSIS_TOOLS_EOF > scheduling-analysis-tools.sh
#!/bin/bash

echo "=== Scheduling Analysis Tools ==="
echo "Tools for analyzing pod scheduling decisions"
echo

# Function to analyze pod scheduling
analyze_pod_scheduling() {
    local namespace=\${1:-""}
    local pod_name=\${2:-""}
    
    if [ -n "\$namespace" ] && [ -n "\$pod_name" ]; then
        echo "Analyzing scheduling for pod: \$pod_name in namespace: \$namespace"
        echo "================================================================"
        
        # Pod details
        echo "1. Pod Details:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o wide
        echo
        
        # Node selector
        echo "2. Node Selector:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.nodeSelector}' | jq . 2>/dev/null || echo "No node selector"
        echo
        
        # Resource requirements
        echo "3. Resource Requirements:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.containers[*].resources}' | jq . 2>/dev/null || echo "No resource requirements"
        echo
        
        # Scheduling events
        echo "4. Scheduling Events:"
        kubectl describe pod "\$pod_name" -n "\$namespace" | grep -A 10 "Events:"
        echo
        
        # Node information
        NODE=\$(kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.nodeName}')
        if [ -n "\$NODE" ]; then
            echo "5. Assigned Node Information:"
            kubectl describe node "\$NODE" | grep -A 5 "Allocated resources:"
        fi
        echo
    else
        echo "Usage: analyze_pod_scheduling <namespace> <pod-name>"
    fi
}

# Function to simulate scheduling
simulate_scheduling() {
    echo "=== Scheduling Simulation ==="
    
    # Create test pod
    cat << TEST_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: scheduling-test-pod
  namespace: default
  labels:
    app: scheduling-test
spec:
  containers:
  - name: test-container
    image: nginx:1.21-alpine
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
  nodeSelector:
    kubernetes.io/os: "linux"
TEST_POD_EOF
    
    echo "Test pod created. Monitoring scheduling..."
    
    # Wait and check scheduling
    sleep 5
    kubectl get pod scheduling-test-pod -o wide
    kubectl describe pod scheduling-test-pod | grep -A 5 "Events:"
    
    # Cleanup
    kubectl delete pod scheduling-test-pod --grace-period=0 --force 2>/dev/null
    echo "Test pod cleaned up"
    echo
}

# Function to check scheduler health
check_scheduler_health() {
    echo "=== Scheduler Health Check ==="
    
    # Scheduler pods
    echo "1. Scheduler Pods:"
    kubectl get pods -n kube-system -l component=kube-scheduler
    echo
    
    # Scheduler logs
    echo "2. Recent Scheduler Logs:"
    kubectl logs -n kube-system -l component=kube-scheduler --tail=20 | grep -E "(error|Error|ERROR|failed|Failed|FAILED)" || echo "No errors found"
    echo
    
    # Scheduling metrics
    echo "3. Scheduling Metrics:"
    kubectl get --raw /metrics | grep scheduler | head -10 2>/dev/null || echo "Metrics not available"
    echo
}

# Main function
main() {
    case "\$1" in
        "analyze")
            analyze_pod_scheduling "\$2" "\$3"
            ;;
        "simulate")
            simulate_scheduling
            ;;
        "health")
            check_scheduler_health
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  analyze <namespace> <pod>  - Analyze pod scheduling"
            echo "  simulate                   - Simulate scheduling process"
            echo "  health                     - Check scheduler health"
            echo ""
            echo "Examples:"
            echo "  \$0 analyze default my-pod"
            echo "  \$0 simulate"
            echo "  \$0 health"
            ;;
    esac
}

# Run main function
main "\$@"

ANALYSIS_TOOLS_EOF
    
    chmod +x scheduling-analysis-tools.sh
    
    echo "✅ Scheduling analysis tools created: scheduling-analysis-tools.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_scheduler_config
            analyze_node_resources
            analyze_pod_placement
            ;;
        "examples")
            create_node_selector_examples
            create_advanced_scheduling_examples
            ;;
        "tools")
            create_scheduling_analysis_tools
            ;;
        "all"|"")
            analyze_scheduler_config
            analyze_node_resources
            analyze_pod_placement
            create_node_selector_examples
            create_advanced_scheduling_examples
            create_scheduling_analysis_tools
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze    - Analyze current scheduler and node state"
            echo "  examples   - Create node selection examples"
            echo "  tools      - Create scheduling analysis tools"
            echo "  all        - Run all actions (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 examples"
            echo "  $0 tools"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x node-selection-analysis.sh

# Запустить создание node selection toolkit
./node-selection-analysis.sh all
```

## 📋 **Node Selection Process:**

### **Scheduling Phases:**

| **Фаза** | **Описание** | **Критерии** | **Результат** |
|----------|--------------|--------------|---------------|
| **Filtering** | Отбор подходящих узлов | Resources, Taints, Node Selector | Список кандидатов |
| **Scoring** | Оценка узлов | Priorities, Affinity, Spread | Ранжированный список |
| **Binding** | Привязка к узлу | Final selection | Pod assignment |

### **Selection Criteria:**

| **Критерий** | **Тип** | **Приоритет** | **Пример** |
|--------------|---------|---------------|------------|
| **Resource Requirements** | Hard | Высокий | CPU, Memory requests |
| **Node Selector** | Hard | Высокий | `kubernetes.io/os: linux` |
| **Affinity Rules** | Soft/Hard | Средний | Node/Pod affinity |
| **Taints/Tolerations** | Hard | Высокий | NoSchedule, NoExecute |

## 🎯 **Практические команды:**

### **Анализ node selection:**
```bash
# Запустить анализ node selection
./node-selection-analysis.sh analyze

# Создать примеры
./node-selection-analysis.sh examples

# Использовать инструменты анализа
./scheduling-analysis-tools.sh health
```

### **Проверка планирования:**
```bash
# Проверить состояние планировщика
kubectl get pods -n kube-system -l component=kube-scheduler

# Проверить события планирования
kubectl get events --field-selector reason=Scheduled

# Анализ конкретного pod
./scheduling-analysis-tools.sh analyze default my-pod
```

### **Node labeling для selection:**
```bash
# Добавить labels для node selection
kubectl label nodes worker-1 hashfoundry.io/workload-type=compute
kubectl label nodes worker-2 hashfoundry.io/workload-type=storage

# Проверить labels
kubectl get nodes --show-labels
```

## 🔧 **Node Selection Strategies:**

### **1. Resource-based Selection:**
- **CPU/Memory requirements** - требования к ресурсам
- **Storage requirements** - требования к хранилищу
- **Network bandwidth** - пропускная способность сети
- **GPU/Special hardware** - специальное оборудование

### **2. Location-based Selection:**
- **Zone/Region awareness** - осведомленность о зонах
- **Rack diversity** - разнообразие стоек
- **Network topology** - топология сети
- **Latency requirements** - требования к задержке

### **3. Workload-based Selection:**
- **Application type** - тип приложения
- **Performance tier** - уровень производительности
- **Security requirements** - требования безопасности
- **Compliance needs** - требования соответствия

## 📊 **Monitoring Node Selection:**

### **Ключевые метрики:**
- **Scheduling latency** - задержка планирования
- **Failed scheduling attempts** - неудачные попытки
- **Node utilization** - использование узлов
- **Pod distribution** - распределение подов

### **Troubleshooting:**
```bash
# Проверить pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Анализ событий планирования
kubectl get events --field-selector reason=FailedScheduling

# Проверить ресурсы узлов
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Эффективный node selection обеспечивает оптимальное размещение workloads в кластере!**
