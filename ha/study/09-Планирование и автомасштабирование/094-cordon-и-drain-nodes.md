# 94. Cordon и Drain Nodes

## 🎯 **Cordon и Drain Nodes**

**Cordon и Drain** - это операции управления узлами в Kubernetes для безопасного вывода узлов из эксплуатации. **Cordon** помечает узел как неподходящий для планирования новых Pod'ов, а **Drain** безопасно выселяет существующие Pod'ы с узла для обслуживания или замены.

## 🏗️ **Операции управления узлами:**

### **1. Cordon (Изоляция):**
- **kubectl cordon** - пометить узел как unschedulable
- **Existing pods** - остаются на узле
- **New pods** - не планируются на узел
- **Reversible** - можно отменить с uncordon

### **2. Drain (Выселение):**
- **kubectl drain** - выселить Pod'ы с узла
- **Graceful termination** - корректное завершение
- **PodDisruptionBudget** - учет бюджетов прерывания
- **Force options** - принудительные опции

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущего состояния узлов:**
```bash
# Проверить состояние узлов
kubectl get nodes
kubectl describe nodes | grep -E "(Unschedulable|Taints)"
```

### **2. Создание comprehensive node management toolkit:**
```bash
# Создать скрипт для управления узлами
cat << 'EOF' > kubernetes-node-management-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Node Management Toolkit ==="
echo "Comprehensive toolkit for cordoning and draining nodes in HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния узлов
analyze_node_status() {
    echo "=== Node Status Analysis ==="
    
    echo "1. Node Overview:"
    echo "================"
    kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,SCHEDULABLE:.spec.unschedulable,TAINTS:.spec.taints[*].effect,VERSION:.status.nodeInfo.kubeletVersion"
    echo
    
    echo "2. Unschedulable Nodes:"
    echo "======================"
    kubectl get nodes --field-selector spec.unschedulable=true -o custom-columns="NAME:.metadata.name,REASON:.metadata.annotations.node\.alpha\.kubernetes\.io/ttl,SINCE:.metadata.creationTimestamp"
    echo
    
    echo "3. Node Resource Usage:"
    echo "======================"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "4. Pods Distribution:"
    echo "===================="
    kubectl get pods --all-namespaces -o wide | awk 'NR>1 {count[$8]++} END {for (node in count) print node ": " count[node] " pods"}'
    echo
    
    echo "5. DaemonSet Pods per Node:"
    echo "=========================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.ownerReferences[]?.kind == "DaemonSet") | "\(.spec.nodeName // "unscheduled")"' | sort | uniq -c
    echo
}

# Функция для безопасного cordon узла
safe_cordon_node() {
    local node_name=${1:-""}
    local reason=${2:-"maintenance"}
    
    if [ -z "$node_name" ]; then
        echo "Usage: safe_cordon_node <node-name> [reason]"
        return 1
    fi
    
    echo "=== Safely Cordoning Node: $node_name ==="
    
    # Проверить текущее состояние узла
    echo "1. Current Node Status:"
    kubectl get node "$node_name" -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,SCHEDULABLE:.spec.unschedulable"
    echo
    
    # Проверить Pod'ы на узле
    echo "2. Pods on Node:"
    kubectl get pods --all-namespaces --field-selector spec.nodeName="$node_name" -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,CONTROLLER:.metadata.ownerReferences[0].kind"
    echo
    
    # Добавить аннотацию с причиной
    kubectl annotate node "$node_name" "hashfoundry.io/cordon-reason=$reason" --overwrite
    kubectl annotate node "$node_name" "hashfoundry.io/cordon-time=$(date -Iseconds)" --overwrite
    
    # Cordon узел
    echo "3. Cordoning Node:"
    if kubectl cordon "$node_name"; then
        echo "✅ Node $node_name successfully cordoned"
        echo "Reason: $reason"
        echo "Time: $(date)"
    else
        echo "❌ Failed to cordon node $node_name"
        return 1
    fi
    echo
    
    # Проверить результат
    echo "4. Post-Cordon Status:"
    kubectl get node "$node_name" -o custom-columns="NAME:.metadata.name,SCHEDULABLE:.spec.unschedulable,ANNOTATIONS:.metadata.annotations"
    echo
}

# Функция для безопасного drain узла
safe_drain_node() {
    local node_name=${1:-""}
    local timeout=${2:-"300s"}
    local force=${3:-"false"}
    
    if [ -z "$node_name" ]; then
        echo "Usage: safe_drain_node <node-name> [timeout] [force]"
        echo "Example: safe_drain_node worker-1 600s false"
        return 1
    fi
    
    echo "=== Safely Draining Node: $node_name ==="
    
    # Pre-drain analysis
    echo "1. Pre-Drain Analysis:"
    echo "====================="
    
    # Проверить PodDisruptionBudgets
    echo "PodDisruptionBudgets that might be affected:"
    kubectl get pdb --all-namespaces -o json | jq -r '.items[] | select(.status.currentHealthy > 0) | "\(.metadata.namespace)/\(.metadata.name): \(.status.currentHealthy)/\(.spec.minAvailable // .spec.maxUnavailable)"'
    echo
    
    # Проверить критичные Pod'ы
    echo "Critical pods on node:"
    kubectl get pods --all-namespaces --field-selector spec.nodeName="$node_name" -o json | jq -r '.items[] | select(.metadata.annotations["scheduler.alpha.kubernetes.io/critical-pod"] == "true" or .spec.priorityClassName == "system-cluster-critical" or .spec.priorityClassName == "system-node-critical") | "\(.metadata.namespace)/\(.metadata.name): \(.spec.priorityClassName // "critical-annotation")"'
    echo
    
    # Проверить StatefulSet Pod'ы
    echo "StatefulSet pods on node:"
    kubectl get pods --all-namespaces --field-selector spec.nodeName="$node_name" -o json | jq -r '.items[] | select(.metadata.ownerReferences[]?.kind == "StatefulSet") | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.ownerReferences[0].name)"'
    echo
    
    # Добавить аннотации для отслеживания
    kubectl annotate node "$node_name" "hashfoundry.io/drain-start=$(date -Iseconds)" --overwrite
    kubectl annotate node "$node_name" "hashfoundry.io/drain-timeout=$timeout" --overwrite
    
    # Построить команду drain
    local drain_cmd="kubectl drain $node_name --ignore-daemonsets --delete-emptydir-data --timeout=$timeout"
    
    if [ "$force" = "true" ]; then
        drain_cmd="$drain_cmd --force --grace-period=0"
        echo "⚠️  Force mode enabled - pods will be forcefully terminated"
    fi
    
    echo "2. Draining Node:"
    echo "================"
    echo "Command: $drain_cmd"
    echo
    
    # Выполнить drain
    if eval "$drain_cmd"; then
        echo "✅ Node $node_name successfully drained"
        kubectl annotate node "$node_name" "hashfoundry.io/drain-complete=$(date -Iseconds)" --overwrite
    else
        echo "❌ Failed to drain node $node_name"
        kubectl annotate node "$node_name" "hashfoundry.io/drain-failed=$(date -Iseconds)" --overwrite
        return 1
    fi
    echo
    
    # Post-drain verification
    echo "3. Post-Drain Verification:"
    echo "=========================="
    kubectl get pods --all-namespaces --field-selector spec.nodeName="$node_name" -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase"
    echo
}

# Функция для uncordon узла
uncordon_node() {
    local node_name=${1:-""}
    
    if [ -z "$node_name" ]; then
        echo "Usage: uncordon_node <node-name>"
        return 1
    fi
    
    echo "=== Uncordoning Node: $node_name ==="
    
    # Проверить текущее состояние
    echo "1. Current Status:"
    kubectl get node "$node_name" -o custom-columns="NAME:.metadata.name,SCHEDULABLE:.spec.unschedulable,READY:.status.conditions[?(@.type=='Ready')].status"
    echo
    
    # Uncordon узел
    echo "2. Uncordoning Node:"
    if kubectl uncordon "$node_name"; then
        echo "✅ Node $node_name successfully uncordoned"
        
        # Добавить аннотацию
        kubectl annotate node "$node_name" "hashfoundry.io/uncordon-time=$(date -Iseconds)" --overwrite
        
        # Удалить старые аннотации
        kubectl annotate node "$node_name" "hashfoundry.io/cordon-reason-" 2>/dev/null || true
        kubectl annotate node "$node_name" "hashfoundry.io/drain-start-" 2>/dev/null || true
        kubectl annotate node "$node_name" "hashfoundry.io/drain-complete-" 2>/dev/null || true
    else
        echo "❌ Failed to uncordon node $node_name"
        return 1
    fi
    echo
    
    # Проверить результат
    echo "3. Post-Uncordon Status:"
    kubectl get node "$node_name" -o custom-columns="NAME:.metadata.name,SCHEDULABLE:.spec.unschedulable,READY:.status.conditions[?(@.type=='Ready')].status"
    echo
    
    # Мониторинг возвращения Pod'ов
    echo "4. Monitoring Pod Scheduling:"
    echo "Waiting for new pods to be scheduled on $node_name..."
    for i in {1..12}; do
        sleep 10
        POD_COUNT=$(kubectl get pods --all-namespaces --field-selector spec.nodeName="$node_name" --no-headers | wc -l)
        echo "  $((i*10))s: $POD_COUNT pods on node"
    done
    echo
}

# Функция для создания maintenance workflow
create_maintenance_workflow() {
    echo "=== Creating Node Maintenance Workflow ==="
    
    cat << MAINTENANCE_WORKFLOW_EOF > node-maintenance-workflow.sh
#!/bin/bash

echo "=== Node Maintenance Workflow ==="
echo "Complete workflow for node maintenance in HashFoundry HA cluster"
echo

# Function for complete maintenance workflow
perform_node_maintenance() {
    local node_name=\${1:-""}
    local maintenance_type=\${2:-"update"}
    local skip_drain=\${3:-"false"}
    
    if [ -z "\$node_name" ]; then
        echo "Usage: perform_node_maintenance <node-name> [maintenance-type] [skip-drain]"
        echo "Maintenance types: update, hardware, emergency"
        return 1
    fi
    
    echo "Starting maintenance workflow for node: \$node_name"
    echo "Maintenance type: \$maintenance_type"
    echo "Skip drain: \$skip_drain"
    echo
    
    # Step 1: Pre-maintenance checks
    echo "=== Step 1: Pre-maintenance Checks ==="
    
    # Check node health
    if ! kubectl get node "\$node_name" >/dev/null 2>&1; then
        echo "❌ Node \$node_name not found"
        return 1
    fi
    
    # Check cluster health
    READY_NODES=\$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
    TOTAL_NODES=\$(kubectl get nodes --no-headers | wc -l)
    
    if [ "\$READY_NODES" -lt 2 ]; then
        echo "⚠️  Warning: Only \$READY_NODES ready nodes available"
        echo "Proceeding with maintenance may affect cluster availability"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
            echo "Maintenance cancelled"
            return 1
        fi
    fi
    
    # Step 2: Cordon node
    echo "=== Step 2: Cordoning Node ==="
    kubectl annotate node "\$node_name" "hashfoundry.io/maintenance-type=\$maintenance_type" --overwrite
    kubectl annotate node "\$node_name" "hashfoundry.io/maintenance-start=\$(date -Iseconds)" --overwrite
    
    if kubectl cordon "\$node_name"; then
        echo "✅ Node \$node_name cordoned successfully"
    else
        echo "❌ Failed to cordon node \$node_name"
        return 1
    fi
    
    # Step 3: Drain node (if not skipped)
    if [ "\$skip_drain" != "true" ]; then
        echo "=== Step 3: Draining Node ==="
        
        # Choose drain strategy based on maintenance type
        case "\$maintenance_type" in
            "emergency")
                echo "Emergency maintenance - using force drain"
                kubectl drain "\$node_name" --ignore-daemonsets --delete-emptydir-data --force --grace-period=0 --timeout=60s
                ;;
            "hardware")
                echo "Hardware maintenance - graceful drain with extended timeout"
                kubectl drain "\$node_name" --ignore-daemonsets --delete-emptydir-data --timeout=600s
                ;;
            *)
                echo "Standard maintenance - normal drain"
                kubectl drain "\$node_name" --ignore-daemonsets --delete-emptydir-data --timeout=300s
                ;;
        esac
        
        if [ \$? -eq 0 ]; then
            echo "✅ Node \$node_name drained successfully"
        else
            echo "❌ Failed to drain node \$node_name"
            echo "Node is cordoned but not drained. Manual intervention may be required."
        fi
    else
        echo "=== Step 3: Skipping Drain (as requested) ==="
    fi
    
    # Step 4: Maintenance instructions
    echo "=== Step 4: Maintenance Ready ==="
    echo "Node \$node_name is ready for maintenance"
    echo
    echo "Maintenance checklist:"
    echo "□ Perform required maintenance tasks"
    echo "□ Verify node health after maintenance"
    echo "□ Run: \$0 complete-maintenance \$node_name"
    echo
    echo "To complete maintenance, run:"
    echo "  \$0 complete-maintenance \$node_name"
    echo
}

# Function to complete maintenance
complete_node_maintenance() {
    local node_name=\${1:-""}
    
    if [ -z "\$node_name" ]; then
        echo "Usage: complete_node_maintenance <node-name>"
        return 1
    fi
    
    echo "=== Completing Maintenance for Node: \$node_name ==="
    
    # Step 1: Verify node is ready
    echo "Step 1: Verifying node readiness..."
    NODE_STATUS=\$(kubectl get node "\$node_name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    
    if [ "\$NODE_STATUS" != "True" ]; then
        echo "⚠️  Warning: Node \$node_name is not in Ready state"
        echo "Current status: \$NODE_STATUS"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
            echo "Maintenance completion cancelled"
            return 1
        fi
    fi
    
    # Step 2: Uncordon node
    echo "Step 2: Uncordoning node..."
    if kubectl uncordon "\$node_name"; then
        echo "✅ Node \$node_name uncordoned successfully"
    else
        echo "❌ Failed to uncordon node \$node_name"
        return 1
    fi
    
    # Step 3: Update annotations
    kubectl annotate node "\$node_name" "hashfoundry.io/maintenance-complete=\$(date -Iseconds)" --overwrite
    kubectl annotate node "\$node_name" "hashfoundry.io/maintenance-type-" 2>/dev/null || true
    kubectl annotate node "\$node_name" "hashfoundry.io/maintenance-start-" 2>/dev/null || true
    
    # Step 4: Monitor pod scheduling
    echo "Step 3: Monitoring pod scheduling..."
    echo "Waiting for pods to be scheduled on \$node_name..."
    
    for i in {1..6}; do
        sleep 10
        POD_COUNT=\$(kubectl get pods --all-namespaces --field-selector spec.nodeName="\$node_name" --no-headers | wc -l)
        echo "  \$((i*10))s: \$POD_COUNT pods scheduled"
    done
    
    echo "✅ Maintenance completed for node \$node_name"
    echo
}

# Main function
case "\$1" in
    "start"|"perform")
        perform_node_maintenance "\$2" "\$3" "\$4"
        ;;
    "complete"|"finish")
        complete_node_maintenance "\$2"
        ;;
    *)
        echo "Usage: \$0 [start|complete] <node-name> [options]"
        echo ""
        echo "Commands:"
        echo "  start <node> [type] [skip-drain]  - Start maintenance workflow"
        echo "  complete <node>                   - Complete maintenance workflow"
        echo ""
        echo "Maintenance types:"
        echo "  update     - Standard update (default)"
        echo "  hardware   - Hardware maintenance"
        echo "  emergency  - Emergency maintenance"
        echo ""
        echo "Examples:"
        echo "  \$0 start worker-1"
        echo "  \$0 start worker-1 hardware"
        echo "  \$0 start worker-1 emergency true"
        echo "  \$0 complete worker-1"
        ;;
esac

MAINTENANCE_WORKFLOW_EOF
    
    chmod +x node-maintenance-workflow.sh
    
    echo "✅ Node maintenance workflow created: node-maintenance-workflow.sh"
    echo
}

# Функция для создания emergency procedures
create_emergency_procedures() {
    echo "=== Creating Emergency Procedures ==="
    
    cat << EMERGENCY_PROC_EOF > emergency-node-procedures.sh
#!/bin/bash

echo "=== Emergency Node Procedures ==="
echo "Emergency procedures for HashFoundry HA cluster"
echo

# Function for emergency node isolation
emergency_isolate_node() {
    local node_name=\${1:-""}
    local reason=\${2:-"emergency"}
    
    if [ -z "\$node_name" ]; then
        echo "Usage: emergency_isolate_node <node-name> [reason]"
        return 1
    fi
    
    echo "🚨 EMERGENCY: Isolating node \$node_name"
    echo "Reason: \$reason"
    echo "Time: \$(date)"
    echo
    
    # Immediate cordon
    kubectl cordon "\$node_name"
    
    # Add emergency annotations
    kubectl annotate node "\$node_name" "hashfoundry.io/emergency-isolation=true" --overwrite
    kubectl annotate node "\$node_name" "hashfoundry.io/emergency-reason=\$reason" --overwrite
    kubectl annotate node "\$node_name" "hashfoundry.io/emergency-time=\$(date -Iseconds)" --overwrite
    
    # Emergency taint
    kubectl taint node "\$node_name" "hashfoundry.io/emergency=true:NoExecute" --overwrite
    
    echo "✅ Node \$node_name isolated for emergency"
    echo "All pods will be evicted immediately"
    echo
}

# Function for emergency cluster status
emergency_cluster_status() {
    echo "🚨 EMERGENCY CLUSTER STATUS"
    echo "=========================="
    echo "Time: \$(date)"
    echo
    
    echo "Node Status:"
    kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,SCHEDULABLE:.spec.unschedulable,EMERGENCY:.metadata.annotations.hashfoundry\.io/emergency-isolation"
    echo
    
    echo "Critical Pods Status:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.priorityClassName == "system-cluster-critical" or .spec.priorityClassName == "system-node-critical") | "\(.metadata.namespace)/\(.metadata.name): \(.status.phase) on \(.spec.nodeName // "unscheduled")"'
    echo
    
    echo "Failed Pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Failed
    echo
    
    echo "Pending Pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending
    echo
}

# Function for emergency recovery
emergency_recovery() {
    echo "🔧 EMERGENCY RECOVERY PROCEDURES"
    echo "==============================="
    
    # Remove emergency taints
    echo "Removing emergency taints..."
    for node in \$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        kubectl taint node "\$node" "hashfoundry.io/emergency-" 2>/dev/null || true
        kubectl annotate node "\$node" "hashfoundry.io/emergency-isolation-" 2>/dev/null || true
    done
    
    # Uncordon all nodes
    echo "Uncordoning all nodes..."
    kubectl get nodes -o jsonpath='{.items[?(@.spec.unschedulable==true)].metadata.name}' | xargs -r kubectl uncordon
    
    echo "✅ Emergency recovery completed"
    echo "Monitor cluster status for stability"
    echo
}

# Main function
case "\$1" in
    "isolate")
        emergency_isolate_node "\$2" "\$3"
        ;;
    "status")
        emergency_cluster_status
        ;;
    "recover")
        emergency_recovery
        ;;
    *)
        echo "Usage: \$0 [isolate|status|recover] [options]"
        echo ""
        echo "Commands:"
        echo "  isolate <node> [reason]  - Emergency isolate node"
        echo "  status                   - Emergency cluster status"
        echo "  recover                  - Emergency recovery"
        echo ""
        echo "Examples:"
        echo "  \$0 isolate worker-1 'hardware failure'"
        echo "  \$0 status"
        echo "  \$0 recover"
        ;;
esac

EMERGENCY_PROC_EOF
    
    chmod +x emergency-node-procedures.sh
    
    echo "✅ Emergency procedures created: emergency-node-procedures.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_node_status
            ;;
        "cordon")
            safe_cordon_node "$2" "$3"
            ;;
        "drain")
            safe_drain_node "$2" "$3" "$4"
            ;;
        "uncordon")
            uncordon_node "$2"
            ;;
        "workflow")
            create_maintenance_workflow
            ;;
        "emergency")
            create_emergency_procedures
            ;;
        "all"|"")
            analyze_node_status
            create_maintenance_workflow
            create_emergency_procedures
            ;;
        *)
            echo "Usage: $0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  analyze                           - Analyze node status"
            echo "  cordon <node> [reason]            - Safely cordon node"
            echo "  drain <node> [timeout] [force]    - Safely drain node"
            echo "  uncordon <node>                   - Uncordon node"
            echo "  workflow                          - Create maintenance workflow"
            echo "  emergency                         - Create emergency procedures"
            echo "  all                               - Create all tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 cordon worker-1 'planned maintenance'"
            echo "  $0 drain worker-1 600s false"
            echo "  $0 uncordon worker-1"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-node-management-toolkit.sh

# Запустить создание node management toolkit
./kubernetes-node-management-toolkit.sh all
```

## 📋 **Node Management Operations:**

### **Cordon vs Drain:**

| **Операция** | **Новые Pod'ы** | **Существующие Pod'ы** | **Use Case** |
|--------------|-----------------|------------------------|--------------|
| **Cordon** | Не планируются | Остаются | Подготовка к обслуживанию |
| **Drain** | Не планируются | Выселяются | Полное освобождение узла |
| **Uncordon** | Планируются | Возвращаются | Возврат в эксплуатацию |

### **Drain Options:**

| **Опция** | **Описание** | **Use Case** |
|-----------|--------------|--------------|
| **--ignore-daemonsets** | Игнорировать DaemonSet Pod'ы | Стандартная практика |
| **--delete-emptydir-data** | Удалить данные emptyDir | Временные данные |
| **--force** | Принудительное удаление | Экстренные ситуации |
| **--grace-period** | Время на корректное завершение | Контроль времени |

## 🎯 **Практические команды:**

### **Базовые операции:**
```bash
# Запустить node management toolkit
./kubernetes-node-management-toolkit.sh analyze

# Cordon узла
./kubernetes-node-management-toolkit.sh cordon worker-1 "planned maintenance"

# Drain узла
./kubernetes-node-management-toolkit.sh drain worker-1 600s false
```

### **Maintenance workflow:**
```bash
# Начать обслуживание
./node-maintenance-workflow.sh start worker-1 hardware

# Завершить обслуживание
./node-maintenance-workflow.sh complete worker-1
```

### **Экстренные процедуры:**
```bash
# Экстренная изоляция
./emergency-node-procedures.sh isolate worker-1 "hardware failure"

# Статус кластера
./emergency-node-procedures.sh status

# Восстановление
./emergency-node-procedures.sh recover
```

## 🔧 **Best Practices для Node Management:**

### **Планирование обслуживания:**
- **Check cluster capacity** - проверьте емкость кластера
- **Verify PodDisruptionBudgets** - проверьте бюджеты прерывания
- **Plan maintenance windows** - планируйте окна обслуживания
- **Communicate with teams** - координируйтесь с командами

### **Безопасное выполнение:**
- **Cordon before drain** - сначала cordon, потом drain
- **Monitor during drain** - мониторьте процесс drain
- **Verify pod migration** - проверьте миграцию Pod'ов
- **Test after uncordon** - тестируйте после uncordon

### **Обработка ошибок:**
- **Handle stuck pods** - обрабатывайте зависшие Pod'ы
- **Respect PDB limits** - соблюдайте лимиты PDB
- **Use appropriate timeouts** - используйте подходящие таймауты
- **Have rollback plan** - имейте план отката

## 📊 **Monitoring Node Operations:**

### **Ключевые метрики:**
- **Node schedulability** - планируемость узлов
- **Pod eviction rate** - скорость выселения Pod'ов
- **Drain duration** - продолжительность drain
- **Failed evictions** - неудачные выселения

### **Troubleshooting:**
```bash
# Проверить stuck pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Анализ PodDisruptionBudgets
kubectl get pdb --all-namespaces

# Проверить события выселения
kubectl get events --field-selector reason=Evicted
```

### **Common Issues:**

| **Проблема** | **Причина** | **Решение** |
|--------------|-------------|-------------|
| **Drain hangs** | PDB ограничения | Проверить PDB, увеличить timeout |
| **Pods stuck** | Finalizers | Принудительное удаление |
| **StatefulSet issues** | Ordered termination | Ручное управление |
| **DaemonSet pods** | Не выселяются | Использовать --ignore-daemonsets |

**Правильное управление узлами обеспечивает безопасное обслуживание без простоев!**
