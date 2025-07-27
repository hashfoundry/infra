# 93. Taints и Tolerations

## 🎯 **Taints и Tolerations**

**Taints и Tolerations** в Kubernetes - это механизм, который позволяет узлам отталкивать определенные Pod'ы (Taints) и Pod'ам преодолевать эти ограничения (Tolerations), обеспечивая контроль над тем, какие workloads могут быть размещены на каких узлах.

## 🏗️ **Компоненты Taints и Tolerations:**

### **1. Taints (Метки-отталкиватели):**
- **NoSchedule** - новые Pod'ы не планируются
- **PreferNoSchedule** - избегать планирования (мягкое ограничение)
- **NoExecute** - существующие Pod'ы выселяются
- **Key=Value:Effect** - формат taint

### **2. Tolerations (Толерантности):**
- **Equal** - точное совпадение
- **Exists** - существование ключа
- **TolerationSeconds** - время до выселения
- **Operator** - оператор сравнения

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих taints и tolerations:**
```bash
# Проверить taints на узлах
kubectl get nodes -o custom-columns="NAME:.metadata.name,TAINTS:.spec.taints[*]"
kubectl describe nodes | grep -A 5 "Taints:"
```

### **2. Создание comprehensive taints и tolerations toolkit:**
```bash
# Создать скрипт для работы с taints и tolerations
cat << 'EOF' > kubernetes-taints-tolerations-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Taints and Tolerations Toolkit ==="
echo "Comprehensive toolkit for Taints and Tolerations in HashFoundry HA cluster"
echo

# Функция для анализа текущих taints и tolerations
analyze_current_taints_tolerations() {
    echo "=== Current Taints and Tolerations Analysis ==="
    
    echo "1. Node Taints:"
    echo "=============="
    kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.spec.taints // [] | map("\(.key)=\(.value // ""):\(.effect)") | join(", "))"'
    echo
    
    echo "2. Pods with Tolerations:"
    echo "========================"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.tolerations != null) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.tolerations | length) tolerations"'
    echo
    
    echo "3. System Pods Tolerations:"
    echo "=========================="
    kubectl get pods -n kube-system -o json | jq -r '.items[] | "\(.metadata.name): \(.spec.tolerations // [] | map("\(.key // "*"):\(.effect // "")") | join(", "))"'
    echo
    
    echo "4. Pods on Tainted Nodes:"
    echo "========================="
    for node in $(kubectl get nodes -o jsonpath='{.items[?(@.spec.taints)].metadata.name}'); do
        echo "Node: $node"
        kubectl get pods --all-namespaces --field-selector spec.nodeName=$node -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TOLERATIONS:.spec.tolerations[*].key"
        echo
    done
}

# Функция для создания taint examples
create_taint_examples() {
    echo "=== Creating Taint Examples ==="
    
    # Получить список узлов
    NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    
    if [ ${#NODES[@]} -ge 3 ]; then
        # Добавить различные типы taints для демонстрации
        echo "Adding demonstration taints to nodes..."
        
        # NoSchedule taint для dedicated workloads
        kubectl taint node ${NODES[0]} hashfoundry.io/dedicated=gpu:NoSchedule --overwrite
        echo "Added NoSchedule taint to ${NODES[0]} for GPU workloads"
        
        # PreferNoSchedule taint для maintenance
        kubectl taint node ${NODES[1]} hashfoundry.io/maintenance=scheduled:PreferNoSchedule --overwrite
        echo "Added PreferNoSchedule taint to ${NODES[1]} for maintenance"
        
        # NoExecute taint для testing (будет удален позже)
        kubectl taint node ${NODES[2]} hashfoundry.io/testing=active:NoExecute --overwrite
        echo "Added NoExecute taint to ${NODES[2]} for testing"
        
        # Показать результат
        echo
        echo "Current node taints:"
        kubectl get nodes -o custom-columns="NAME:.metadata.name,TAINTS:.spec.taints[*]"
        echo
    else
        echo "Need at least 3 nodes for taint examples"
    fi
}

# Функция для создания toleration examples
create_toleration_examples() {
    echo "=== Creating Toleration Examples ==="
    
    # Создать namespace для примеров
    kubectl create namespace taints-tolerations-examples --dry-run=client -o yaml | kubectl apply -f -
    
    # Example 1: Pod with specific toleration
    cat << SPECIFIC_TOLERATION_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-workload
  namespace: taints-tolerations-examples
  labels:
    app.kubernetes.io/name: "gpu-workload"
    hashfoundry.io/example: "specific-toleration"
  annotations:
    hashfoundry.io/description: "GPU workload with specific toleration"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "gpu-workload"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "gpu-workload"
        hashfoundry.io/workload-type: "gpu"
    spec:
      tolerations:
      - key: "hashfoundry.io/dedicated"
        operator: "Equal"
        value: "gpu"
        effect: "NoSchedule"
      containers:
      - name: gpu-app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1"
            memory: "1Gi"
        env:
        - name: WORKLOAD_TYPE
          value: "gpu-intensive"
SPECIFIC_TOLERATION_EOF
    
    # Example 2: Pod with wildcard toleration
    cat << WILDCARD_TOLERATION_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: maintenance-tolerant-app
  namespace: taints-tolerations-examples
  labels:
    app.kubernetes.io/name: "maintenance-tolerant-app"
    hashfoundry.io/example: "wildcard-toleration"
  annotations:
    hashfoundry.io/description: "App that tolerates maintenance taints"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "maintenance-tolerant-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "maintenance-tolerant-app"
        hashfoundry.io/maintenance-tolerant: "true"
    spec:
      tolerations:
      - key: "hashfoundry.io/maintenance"
        operator: "Exists"
        effect: "PreferNoSchedule"
      - key: "node.kubernetes.io/unschedulable"
        operator: "Exists"
        effect: "NoSchedule"
      containers:
      - name: app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
        env:
        - name: MAINTENANCE_TOLERANT
          value: "true"
WILDCARD_TOLERATION_EOF
    
    # Example 3: Pod with time-limited toleration
    cat << TIME_LIMITED_TOLERATION_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: temporary-workload
  namespace: taints-tolerations-examples
  labels:
    app.kubernetes.io/name: "temporary-workload"
    hashfoundry.io/example: "time-limited-toleration"
  annotations:
    hashfoundry.io/description: "Temporary workload with time-limited toleration"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "temporary-workload"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "temporary-workload"
        hashfoundry.io/temporary: "true"
    spec:
      tolerations:
      - key: "hashfoundry.io/testing"
        operator: "Equal"
        value: "active"
        effect: "NoExecute"
        tolerationSeconds: 300  # 5 minutes
      containers:
      - name: temp-app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
        env:
        - name: WORKLOAD_TYPE
          value: "temporary"
TIME_LIMITED_TOLERATION_EOF
    
    # Example 4: System-level tolerations
    cat << SYSTEM_TOLERATION_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: system-monitor
  namespace: taints-tolerations-examples
  labels:
    app.kubernetes.io/name: "system-monitor"
    hashfoundry.io/example: "system-tolerations"
  annotations:
    hashfoundry.io/description: "System monitor with comprehensive tolerations"
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: "system-monitor"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "system-monitor"
        hashfoundry.io/system-component: "monitor"
    spec:
      tolerations:
      # Tolerate all taints (system component)
      - operator: "Exists"
      containers:
      - name: monitor
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
        env:
        - name: COMPONENT_TYPE
          value: "system-monitor"
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
SYSTEM_TOLERATION_EOF
    
    echo "✅ Toleration examples created"
    echo
}

# Функция для создания advanced taint scenarios
create_advanced_taint_scenarios() {
    echo "=== Creating Advanced Taint Scenarios ==="
    
    # Scenario 1: Node maintenance workflow
    cat << MAINTENANCE_WORKFLOW_EOF > node-maintenance-workflow.sh
#!/bin/bash

echo "=== Node Maintenance Workflow ==="
echo "Demonstrating node maintenance with taints"
echo

# Function to prepare node for maintenance
prepare_node_maintenance() {
    local node_name=\${1:-""}
    
    if [ -z "\$node_name" ]; then
        echo "Usage: prepare_node_maintenance <node-name>"
        return 1
    fi
    
    echo "Preparing node \$node_name for maintenance..."
    
    # Step 1: Add PreferNoSchedule taint
    kubectl taint node "\$node_name" maintenance=scheduled:PreferNoSchedule --overwrite
    echo "✅ Added PreferNoSchedule taint"
    
    # Step 2: Wait for new pods to avoid this node
    echo "Waiting 30 seconds for scheduler to avoid this node..."
    sleep 30
    
    # Step 3: Add NoSchedule taint
    kubectl taint node "\$node_name" maintenance=scheduled:NoSchedule --overwrite
    echo "✅ Added NoSchedule taint"
    
    # Step 4: Drain the node (optional)
    echo "To drain the node, run: kubectl drain \$node_name --ignore-daemonsets --delete-emptydir-data"
    
    echo "Node \$node_name is prepared for maintenance"
}

# Function to complete node maintenance
complete_node_maintenance() {
    local node_name=\${1:-""}
    
    if [ -z "\$node_name" ]; then
        echo "Usage: complete_node_maintenance <node-name>"
        return 1
    fi
    
    echo "Completing maintenance for node \$node_name..."
    
    # Remove maintenance taint
    kubectl taint node "\$node_name" maintenance=scheduled:NoSchedule- 2>/dev/null || true
    kubectl taint node "\$node_name" maintenance=scheduled:PreferNoSchedule- 2>/dev/null || true
    
    # Uncordon the node if it was drained
    kubectl uncordon "\$node_name" 2>/dev/null || true
    
    echo "✅ Node \$node_name maintenance completed"
}

# Main function
case "\$1" in
    "prepare")
        prepare_node_maintenance "\$2"
        ;;
    "complete")
        complete_node_maintenance "\$2"
        ;;
    *)
        echo "Usage: \$0 [prepare|complete] <node-name>"
        echo ""
        echo "Commands:"
        echo "  prepare <node>   - Prepare node for maintenance"
        echo "  complete <node>  - Complete node maintenance"
        ;;
esac

MAINTENANCE_WORKFLOW_EOF
    
    chmod +x node-maintenance-workflow.sh
    
    # Scenario 2: Dedicated node pool
    cat << DEDICATED_POOL_EOF > dedicated-node-pool.sh
#!/bin/bash

echo "=== Dedicated Node Pool Management ==="
echo "Managing dedicated node pools with taints"
echo

# Function to create dedicated pool
create_dedicated_pool() {
    local pool_name=\${1:-""}
    local node_selector=\${2:-""}
    
    if [ -z "\$pool_name" ] || [ -z "\$node_selector" ]; then
        echo "Usage: create_dedicated_pool <pool-name> <node-selector>"
        echo "Example: create_dedicated_pool gpu 'gpu=nvidia'"
        return 1
    fi
    
    echo "Creating dedicated pool: \$pool_name"
    
    # Taint nodes matching selector
    for node in \$(kubectl get nodes -l "\$node_selector" -o jsonpath='{.items[*].metadata.name}'); do
        kubectl taint node "\$node" "dedicated=\$pool_name:NoSchedule" --overwrite
        echo "✅ Tainted node \$node for \$pool_name pool"
    done
    
    echo "Dedicated pool \$pool_name created"
}

# Function to remove dedicated pool
remove_dedicated_pool() {
    local pool_name=\${1:-""}
    
    if [ -z "\$pool_name" ]; then
        echo "Usage: remove_dedicated_pool <pool-name>"
        return 1
    fi
    
    echo "Removing dedicated pool: \$pool_name"
    
    # Remove taints from all nodes
    for node in \$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        kubectl taint node "\$node" "dedicated=\$pool_name:NoSchedule-" 2>/dev/null || true
    done
    
    echo "✅ Dedicated pool \$pool_name removed"
}

# Main function
case "\$1" in
    "create")
        create_dedicated_pool "\$2" "\$3"
        ;;
    "remove")
        remove_dedicated_pool "\$2"
        ;;
    *)
        echo "Usage: \$0 [create|remove] [options]"
        echo ""
        echo "Commands:"
        echo "  create <pool-name> <node-selector>  - Create dedicated pool"
        echo "  remove <pool-name>                  - Remove dedicated pool"
        ;;
esac

DEDICATED_POOL_EOF
    
    chmod +x dedicated-node-pool.sh
    
    echo "✅ Advanced taint scenarios created"
    echo
}

# Функция для создания taint analysis tools
create_taint_analysis_tools() {
    echo "=== Creating Taint Analysis Tools ==="
    
    cat << TAINT_TOOLS_EOF > taint-analysis-tools.sh
#!/bin/bash

echo "=== Taint Analysis Tools ==="
echo "Tools for analyzing taints and tolerations"
echo

# Function to analyze node taints
analyze_node_taints() {
    echo "=== Node Taints Analysis ==="
    
    echo "1. All Node Taints:"
    echo "=================="
    kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name):" as \$name | .spec.taints // [] | map("  \(.key)=\(.value // ""):\(.effect)") | if length > 0 then [\$name] + . else [\$name, "  No taints"] end | join("\n")'
    echo
    
    echo "2. Taint Summary:"
    echo "================"
    kubectl get nodes -o json | jq -r '.items[].spec.taints // [] | .[].key' | sort | uniq -c | sort -nr
    echo
    
    echo "3. Nodes by Taint Effects:"
    echo "========================="
    for effect in NoSchedule PreferNoSchedule NoExecute; do
        echo "\$effect:"
        kubectl get nodes -o json | jq -r ".items[] | select(.spec.taints // [] | map(.effect) | contains([\"\$effect\"])) | .metadata.name" | sed 's/^/  /'
    done
    echo
}

# Function to analyze pod tolerations
analyze_pod_tolerations() {
    local namespace=\${1:-""}
    
    if [ -n "\$namespace" ]; then
        echo "=== Pod Tolerations Analysis (Namespace: \$namespace) ==="
        PODS=\$(kubectl get pods -n "\$namespace" -o json)
    else
        echo "=== Pod Tolerations Analysis (All Namespaces) ==="
        PODS=\$(kubectl get pods --all-namespaces -o json)
    fi
    
    echo "1. Pods with Tolerations:"
    echo "========================"
    echo "\$PODS" | jq -r '.items[] | select(.spec.tolerations != null) | "\(.metadata.namespace // "default")/\(.metadata.name): \(.spec.tolerations | length) tolerations"'
    echo
    
    echo "2. Common Tolerations:"
    echo "====================="
    echo "\$PODS" | jq -r '.items[].spec.tolerations // [] | .[].key // "no-key"' | sort | uniq -c | sort -nr
    echo
    
    echo "3. Pods on Tainted Nodes:"
    echo "========================="
    for node in \$(kubectl get nodes -o json | jq -r '.items[] | select(.spec.taints != null) | .metadata.name'); do
        echo "Node \$node:"
        kubectl get pods --all-namespaces --field-selector spec.nodeName=\$node -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name" | tail -n +2 | sed 's/^/  /'
    done
    echo
}

# Function to check taint-toleration compatibility
check_compatibility() {
    local namespace=\${1:-""}
    local pod_name=\${2:-""}
    
    if [ -n "\$namespace" ] && [ -n "\$pod_name" ]; then
        echo "=== Checking Compatibility for \$namespace/\$pod_name ==="
        
        # Get pod tolerations
        echo "Pod Tolerations:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.tolerations}' | jq . 2>/dev/null || echo "No tolerations"
        echo
        
        # Check against all node taints
        echo "Node Compatibility:"
        for node in \$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
            echo "Node \$node:"
            kubectl get node "\$node" -o jsonpath='{.spec.taints}' | jq . 2>/dev/null || echo "  No taints"
        done
        echo
    else
        echo "Usage: check_compatibility <namespace> <pod-name>"
    fi
}

# Function to simulate pod placement
simulate_placement() {
    echo "=== Simulating Pod Placement ==="
    
    # Create test pod without tolerations
    cat << TEST_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: taint-test-pod
  namespace: default
  labels:
    app: taint-test
spec:
  containers:
  - name: test-container
    image: nginx:1.21-alpine
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
TEST_POD_EOF
    
    echo "Test pod created without tolerations. Checking placement..."
    sleep 5
    
    kubectl get pod taint-test-pod -o wide
    kubectl describe pod taint-test-pod | grep -A 5 "Events:"
    
    # Cleanup
    kubectl delete pod taint-test-pod --grace-period=0 --force 2>/dev/null
    echo "Test pod cleaned up"
    echo
}

# Function to generate taint report
generate_taint_report() {
    echo "=== Generating Taint Report ==="
    
    local report_file="taint-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster Taint Report"
        echo "==================================="
        echo "Generated: \$(date)"
        echo ""
        
        echo "=== NODE TAINTS ==="
        kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name):" as \$name | .spec.taints // [] | map("  \(.key)=\(.value // ""):\(.effect)") | if length > 0 then [\$name] + . else [\$name, "  No taints"] end | join("\n")'
        echo ""
        
        echo "=== PODS WITH TOLERATIONS ==="
        kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.tolerations != null) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.tolerations | length) tolerations"'
        echo ""
        
        echo "=== PENDING PODS ==="
        kubectl get pods --all-namespaces --field-selector=status.phase=Pending
        echo ""
        
        echo "=== TAINT EFFECTS SUMMARY ==="
        for effect in NoSchedule PreferNoSchedule NoExecute; do
            echo "\$effect nodes:"
            kubectl get nodes -o json | jq -r ".items[] | select(.spec.taints // [] | map(.effect) | contains([\"\$effect\"])) | .metadata.name" | sed 's/^/  /'
        done
        echo ""
        
    } > "\$report_file"
    
    echo "✅ Taint report generated: \$report_file"
    echo
}

# Main function
main() {
    case "\$1" in
        "nodes")
            analyze_node_taints
            ;;
        "pods")
            analyze_pod_tolerations "\$2"
            ;;
        "compatibility")
            check_compatibility "\$2" "\$3"
            ;;
        "simulate")
            simulate_placement
            ;;
        "report")
            generate_taint_report
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  nodes                        - Analyze node taints"
            echo "  pods [namespace]             - Analyze pod tolerations"
            echo "  compatibility <ns> <pod>     - Check taint-toleration compatibility"
            echo "  simulate                     - Simulate pod placement"
            echo "  report                       - Generate taint report"
            echo ""
            echo "Examples:"
            echo "  \$0 nodes"
            echo "  \$0 pods kube-system"
            echo "  \$0 compatibility default my-pod"
            echo "  \$0 simulate"
            echo "  \$0 report"
            ;;
    esac
}

# Run main function
main "\$@"

TAINT_TOOLS_EOF
    
    chmod +x taint-analysis-tools.sh
    
    echo "✅ Taint analysis tools created: taint-analysis-tools.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_taints_tolerations
            ;;
        "taint-examples")
            create_taint_examples
            ;;
        "toleration-examples")
            create_toleration_examples
            ;;
        "advanced")
            create_advanced_taint_scenarios
            ;;
        "tools")
            create_taint_analysis_tools
            ;;
        "cleanup")
            # Remove demonstration taints
            NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
            for node in "${NODES[@]}"; do
                kubectl taint node "$node" hashfoundry.io/dedicated- 2>/dev/null || true
                kubectl taint node "$node" hashfoundry.io/maintenance- 2>/dev/null || true
                kubectl taint node "$node" hashfoundry.io/testing- 2>/dev/null || true
            done
            echo "✅ Demonstration taints removed"
            ;;
        "all"|"")
            analyze_current_taints_tolerations
            create_taint_examples
            create_toleration_examples
            create_advanced_taint_scenarios
            create_taint_analysis_tools
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze              - Analyze current taints and tolerations"
            echo "  taint-examples       - Create taint examples"
            echo "  toleration-examples  - Create toleration examples"
            echo "  advanced             - Create advanced taint scenarios"
            echo "  tools                - Create taint analysis tools"
            echo "  cleanup              - Remove demonstration taints"
            echo "  all                  - Run all actions (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 taint-examples"
            echo "  $0 tools"
            echo "  $0 cleanup"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-taints-tolerations-toolkit.sh

# Запустить создание taints и tolerations toolkit
./kubernetes-taints-tolerations-toolkit.sh all
```

## 📋 **Taint Effects и Use Cases:**

### **Taint Effects:**

| **Effect** | **Поведение** | **Существующие Pod'ы** | **Use Case** |
|------------|---------------|------------------------|--------------|
| **NoSchedule** | Новые Pod'ы не планируются | Остаются | Dedicated nodes |
| **PreferNoSchedule** | Избегать планирования | Остаются | Soft restrictions |
| **NoExecute** | Выселение Pod'ов | Выселяются | Node maintenance |

### **Toleration Operators:**

| **Operator** | **Поведение** | **Пример** | **Use Case** |
|--------------|---------------|------------|------------|
| **Equal** | Точное совпадение | `key=value` | Specific workloads |
| **Exists** | Существование ключа | `key` exists | Wildcard tolerations |

## 🎯 **Практические команды:**

### **Работа с taints:**
```bash
# Запустить taints toolkit
./kubernetes-taints-tolerations-toolkit.sh all

# Анализ узлов
./taint-analysis-tools.sh nodes

# Анализ подов
./taint-analysis-tools.sh pods kube-system
```

### **Управление taints:**
```bash
# Добавить taint
kubectl taint nodes worker-1 dedicated=gpu:NoSchedule

# Удалить taint
kubectl taint nodes worker-1 dedicated=gpu:NoSchedule-

# Проверить taints
kubectl describe node worker-1 | grep Taints
```

### **Подготовка к обслуживанию:**
```bash
# Подготовить узел к обслуживанию
./node-maintenance-workflow.sh prepare worker-1

# Завершить обслуживание
./node-maintenance-workflow.sh complete worker-1
```

## 🔧 **Best Practices для Taints и Tolerations:**

### **Taints:**
- **Use meaningful keys** - используйте осмысленные ключи
- **Document taint purposes** - документируйте назначение taints
- **Plan taint lifecycle** - планируйте жизненный цикл taints
- **Consider existing workloads** - учитывайте существующие workloads

### **Tolerations:**
- **Match taint requirements** - соответствуйте требованиям taints
- **Use appropriate operators** - используйте подходящие операторы
- **Set toleration seconds** - устанавливайте время толерантности
- **Test compatibility** - тестируйте совместимость

### **Common Scenarios:**
- **Node maintenance** - обслуживание узлов
- **Dedicated workloads** - выделенные workloads
- **Resource isolation** - изоляция ресурсов
- **Gradual migration** - постепенная миграция

## 📊 **Monitoring Taints и Tolerations:**

### **Ключевые метрики:**
- **Tainted nodes count** - количество помеченных узлов
- **Pending pods** - ожидающие Pod'ы
- **Evicted pods** - выселенные Pod'ы
- **Toleration violations** - нарушения толерантности

### **Troubleshooting:**
```bash
# Проверить pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Анализ событий выселения
kubectl get events --field-selector reason=Evicted

# Проверить совместимость
./taint-analysis-tools.sh compatibility default my-pod
```

**Taints и Tolerations обеспечивают гибкое управление размещением workloads и изоляцию ресурсов!**
