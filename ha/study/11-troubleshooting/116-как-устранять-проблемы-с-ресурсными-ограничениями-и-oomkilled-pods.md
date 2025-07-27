# 116. Как устранять проблемы с ресурсными ограничениями и OOMKilled Pods

## 🎯 **Как устранять проблемы с ресурсными ограничениями и OOMKilled Pods**

**Resource constraints и OOMKilled** - одни из самых частых проблем в production Kubernetes кластерах. Понимание управления ресурсами и методов диагностики критически важно для стабильной работы приложений.

## 💾 **Основы управления ресурсами в Kubernetes:**

### **1. Resource Types:**
- **CPU** - вычислительные ресурсы (millicores)
- **Memory** - оперативная память (bytes)
- **Storage** - дисковое пространство
- **Ephemeral Storage** - временное хранилище

### **2. Resource Specifications:**
- **Requests** - гарантированные ресурсы
- **Limits** - максимальные ресурсы
- **QoS Classes** - качество обслуживания
- **Resource Quotas** - ограничения namespace

### **3. OOMKilled Scenarios:**
- **Memory Limit Exceeded** - превышение лимита памяти
- **Node Memory Pressure** - нехватка памяти на узле
- **Memory Leaks** - утечки памяти в приложении
- **Insufficient Requests** - неправильные resource requests

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive resource troubleshooting toolkit
cat << 'EOF' > resource-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== Resource Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing resource issues in HashFoundry HA cluster"
echo

# Функция для проверки OOMKilled pods
check_oomkilled_pods() {
    echo "=== OOMKilled Pods Analysis ==="
    
    echo "1. Find OOMKilled pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o wide | grep -i oom || echo "No OOMKilled pods found"
    echo
    
    echo "2. Detailed OOMKilled pods information:"
    OOMKILLED_PODS=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.status.containerStatuses[*].lastState.terminated.reason=="OOMKilled")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
    
    if [ ! -z "$OOMKILLED_PODS" ]; then
        echo "Found OOMKilled pods:"
        echo "$OOMKILLED_PODS"
        echo
        
        while IFS= read -r line; do
            if [ ! -z "$line" ]; then
                NAMESPACE=$(echo $line | awk '{print $1}')
                POD_NAME=$(echo $line | awk '{print $2}')
                echo "--- Analyzing $NAMESPACE/$POD_NAME ---"
                kubectl describe pod $POD_NAME -n $NAMESPACE | grep -A 10 -B 5 -i "oom\|killed\|memory"
                echo
            fi
        done <<< "$OOMKILLED_PODS"
    fi
    
    echo "3. Recent events related to OOM:"
    kubectl get events --all-namespaces --field-selector reason=OOMKilling --sort-by='.lastTimestamp' | tail -10
    echo
}

# Функция для анализа resource usage
analyze_resource_usage() {
    echo "=== Resource Usage Analysis ==="
    
    echo "1. Node resource usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "2. Pod resource usage (top consumers):"
    kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -20 || echo "Metrics server not available"
    echo
    
    echo "3. Node capacity and allocation:"
    kubectl describe nodes | grep -A 5 "Allocated resources"
    echo
    
    echo "4. Resource quotas by namespace:"
    kubectl get resourcequota --all-namespaces
    echo
    
    echo "5. Limit ranges by namespace:"
    kubectl get limitrange --all-namespaces
    echo
}

# Функция для создания resource monitoring dashboard
create_resource_monitoring() {
    echo "=== Creating Resource Monitoring Tools ==="
    
    echo "1. Resource monitoring script:"
    cat << RESOURCE_MONITOR_EOF > resource-monitor.sh
#!/bin/bash

echo "=== Resource Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Node Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "Top Memory Consuming Pods:"
    kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
    
    echo "Top CPU Consuming Pods:"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
    
    echo "OOMKilled Pods (last 5 minutes):"
    kubectl get events --all-namespaces --field-selector reason=OOMKilling | grep "\$(date -d '5 minutes ago' '+%Y-%m-%d %H:%M')" || echo "No recent OOMKilled events"
    echo
    
    sleep 30
done

RESOURCE_MONITOR_EOF
    
    chmod +x resource-monitor.sh
    echo "✅ Resource monitoring script created: resource-monitor.sh"
    echo
    
    echo "2. Memory pressure detection script:"
    cat << MEMORY_PRESSURE_EOF > memory-pressure-detector.sh
#!/bin/bash

echo "=== Memory Pressure Detector ==="
echo

# Function to check node memory pressure
check_node_memory_pressure() {
    echo "Checking node memory pressure..."
    
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.conditions[?(@.type=="MemoryPressure")].status}{"\n"}{end}' | while read node status; do
        if [ "\$status" = "True" ]; then
            echo "⚠️  Node \$node has memory pressure!"
            kubectl describe node \$node | grep -A 10 "Conditions:"
        else
            echo "✅ Node \$node memory pressure: \$status"
        fi
    done
    echo
}

# Function to check pods approaching memory limits
check_pods_memory_limits() {
    echo "Checking pods approaching memory limits..."
    
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.containers[*].resources.limits.memory}{"\n"}{end}' | while read namespace pod limit; do
        if [ ! -z "\$limit" ] && [ "\$limit" != "<no value>" ]; then
            # Get current memory usage
            CURRENT=\$(kubectl top pod \$pod -n \$namespace --no-headers 2>/dev/null | awk '{print \$3}')
            if [ ! -z "\$CURRENT" ]; then
                echo "Pod \$namespace/\$pod: \$CURRENT / \$limit"
            fi
        fi
    done
    echo
}

check_node_memory_pressure
check_pods_memory_limits

MEMORY_PRESSURE_EOF
    
    chmod +x memory-pressure-detector.sh
    echo "✅ Memory pressure detector created: memory-pressure-detector.sh"
    echo
}

# Функция для создания тестовых сценариев
create_resource_test_scenarios() {
    echo "=== Creating Resource Test Scenarios ==="
    
    echo "1. Memory stress test pod:"
    cat << MEMORY_STRESS_EOF > memory-stress-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-stress-test
  namespace: default
  labels:
    test: resource-stress
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "512M", "--vm-hang", "1"]
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  restartPolicy: Never
MEMORY_STRESS_EOF
    
    echo "✅ Memory stress test pod: memory-stress-test.yaml"
    echo
    
    echo "2. OOMKilled simulation pod:"
    cat << OOMKILLED_SIM_EOF > oomkilled-simulation.yaml
apiVersion: v1
kind: Pod
metadata:
  name: oomkilled-simulation
  namespace: default
  labels:
    test: oomkilled-sim
spec:
  containers:
  - name: memory-hog
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "2G", "--vm-hang", "1"]
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"  # Intentionally low to trigger OOM
        cpu: "200m"
  restartPolicy: Never
OOMKILLED_SIM_EOF
    
    echo "✅ OOMKilled simulation pod: oomkilled-simulation.yaml"
    echo
    
    echo "3. CPU stress test pod:"
    cat << CPU_STRESS_EOF > cpu-stress-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress-test
  namespace: default
  labels:
    test: cpu-stress
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "300s"]
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "2000m"
  restartPolicy: Never
CPU_STRESS_EOF
    
    echo "✅ CPU stress test pod: cpu-stress-test.yaml"
    echo
    
    echo "4. Resource quota test:"
    cat << RESOURCE_QUOTA_EOF > resource-quota-test.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: resource-test-namespace
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota-test
  namespace: resource-test-namespace
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range-test
  namespace: resource-test-namespace
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
RESOURCE_QUOTA_EOF
    
    echo "✅ Resource quota test: resource-quota-test.yaml"
    echo
}

# Функция для диагностики resource constraints
diagnose_resource_constraints() {
    echo "=== Resource Constraints Diagnosis ==="
    
    echo "1. Check for pending pods due to resource constraints:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o wide
    echo
    
    echo "2. Analyze pending pod events:"
    PENDING_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
    
    if [ ! -z "$PENDING_PODS" ]; then
        while IFS= read -r line; do
            if [ ! -z "$line" ]; then
                NAMESPACE=$(echo $line | awk '{print $1}')
                POD_NAME=$(echo $line | awk '{print $2}')
                echo "--- Events for $NAMESPACE/$POD_NAME ---"
                kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$POD_NAME | grep -i "insufficient\|resource"
                echo
            fi
        done <<< "$PENDING_PODS"
    fi
    
    echo "3. Check resource quotas status:"
    kubectl get resourcequota --all-namespaces -o wide
    echo
    
    echo "4. Node allocatable resources:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.cpu}{"\t"}{.status.allocatable.memory}{"\n"}{end}' | column -t
    echo
}

# Функция для создания resource optimization recommendations
create_resource_optimization() {
    echo "=== Resource Optimization Recommendations ==="
    
    cat << OPTIMIZATION_GUIDE_EOF > resource-optimization-guide.md
# Resource Optimization Guide

## 🎯 **Memory Optimization**

### **1. Right-sizing Memory Requests/Limits**
\`\`\`bash
# Check current memory usage
kubectl top pods --all-namespaces --sort-by=memory

# Analyze memory usage patterns
kubectl exec <pod> -- cat /proc/meminfo
kubectl exec <pod> -- free -h

# Recommended memory settings
requests.memory: <average_usage * 1.2>
limits.memory: <peak_usage * 1.5>
\`\`\`

### **2. Memory Leak Detection**
\`\`\`bash
# Monitor memory growth over time
watch kubectl top pod <pod-name>

# Check for memory leaks in application
kubectl exec <pod> -- ps aux --sort=-%mem
kubectl exec <pod> -- pmap <pid>
\`\`\`

## 🎯 **CPU Optimization**

### **1. Right-sizing CPU Requests/Limits**
\`\`\`bash
# Check current CPU usage
kubectl top pods --all-namespaces --sort-by=cpu

# Recommended CPU settings
requests.cpu: <average_usage * 1.1>
limits.cpu: <peak_usage * 2>
\`\`\`

### **2. CPU Throttling Detection**
\`\`\`bash
# Check for CPU throttling
kubectl exec <pod> -- cat /sys/fs/cgroup/cpu/cpu.stat
kubectl exec <pod> -- cat /proc/stat
\`\`\`

## 🎯 **QoS Classes Optimization**

### **1. Guaranteed QoS (Highest Priority)**
\`\`\`yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "1Gi"    # Same as requests
    cpu: "500m"      # Same as requests
\`\`\`

### **2. Burstable QoS (Medium Priority)**
\`\`\`yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"    # Higher than requests
    cpu: "1000m"     # Higher than requests
\`\`\`

### **3. BestEffort QoS (Lowest Priority)**
\`\`\`yaml
# No resources specified - not recommended for production
\`\`\`

## 🎯 **Node Resource Management**

### **1. Node Capacity Planning**
\`\`\`bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Capacity:"

# Check node allocatable
kubectl describe nodes | grep -A 5 "Allocatable:"

# Calculate resource utilization
kubectl top nodes
\`\`\`

### **2. Resource Quotas and Limits**
\`\`\`yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
\`\`\`

OPTIMIZATION_GUIDE_EOF
    
    echo "✅ Resource optimization guide created: resource-optimization-guide.md"
    echo
}

# Основная функция
main() {
    case "$1" in
        "oomkilled")
            check_oomkilled_pods
            ;;
        "usage")
            analyze_resource_usage
            ;;
        "monitor")
            create_resource_monitoring
            ;;
        "test")
            create_resource_test_scenarios
            ;;
        "diagnose")
            diagnose_resource_constraints
            ;;
        "optimize")
            create_resource_optimization
            ;;
        "all"|"")
            check_oomkilled_pods
            analyze_resource_usage
            create_resource_monitoring
            create_resource_test_scenarios
            diagnose_resource_constraints
            create_resource_optimization
            ;;
        *)
            echo "Usage: $0 [oomkilled|usage|monitor|test|diagnose|optimize|all]"
            echo ""
            echo "Resource Troubleshooting Options:"
            echo "  oomkilled  - Check OOMKilled pods"
            echo "  usage      - Analyze resource usage"
            echo "  monitor    - Create monitoring tools"
            echo "  test       - Create test scenarios"
            echo "  diagnose   - Diagnose resource constraints"
            echo "  optimize   - Resource optimization guide"
            ;;
    esac
}

main "$@"

EOF

chmod +x resource-troubleshooting-toolkit.sh
./resource-troubleshooting-toolkit.sh all
```

## 🎯 **Пошаговая диагностика ресурсных проблем:**

### **Шаг 1: Найти OOMKilled pods**
```bash
# Поиск OOMKilled pods
kubectl get pods --all-namespaces | grep -i oom

# События OOMKilling
kubectl get events --all-namespaces --field-selector reason=OOMKilling

# Детальная информация
kubectl describe pod <pod-name> | grep -i oom
```

### **Шаг 2: Анализ resource usage**
```bash
# Использование ресурсов узлов
kubectl top nodes

# Топ потребителей памяти
kubectl top pods --all-namespaces --sort-by=memory

# Capacity узлов
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### **Шаг 3: Проверка resource constraints**
```bash
# Pending pods из-за ресурсов
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Resource quotas
kubectl get resourcequota --all-namespaces

# Limit ranges
kubectl get limitrange --all-namespaces
```

### **Шаг 4: Оптимизация ресурсов**
```bash
# Правильные requests/limits
requests.memory: <average_usage * 1.2>
limits.memory: <peak_usage * 1.5>

# QoS класс Guaranteed
resources:
  requests:
    memory: "1Gi"
  limits:
    memory: "1Gi"  # Равно requests
```

## 🔧 **Частые проблемы и решения:**

### **1. OOMKilled pods:**
- Увеличить memory limits
- Оптимизировать приложение
- Проверить memory leaks

### **2. Pending pods:**
- Проверить node capacity
- Увеличить cluster size
- Оптимизировать resource requests

### **3. Memory pressure:**
- Добавить узлы
- Оптимизировать workloads
- Настроить eviction policies

### **4. CPU throttling:**
- Увеличить CPU limits
- Оптимизировать код
- Распределить нагрузку

**Правильное управление ресурсами - основа стабильной работы кластера!**
