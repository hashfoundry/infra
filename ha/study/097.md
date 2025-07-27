# 97. Cluster Autoscaler

## 🎯 **Cluster Autoscaler**

**Cluster Autoscaler** - это компонент Kubernetes, который автоматически регулирует размер кластера, добавляя или удаляя узлы в зависимости от потребностей в ресурсах. Он работает с облачными провайдерами для масштабирования node pools когда Pod'ы не могут быть запланированы из-за нехватки ресурсов.

## 🏗️ **Компоненты Cluster Autoscaler:**

### **1. Core Components:**
- **Cluster Autoscaler Pod** - основной контроллер
- **Cloud Provider Integration** - интеграция с облачным провайдером
- **Node Group Management** - управление группами узлов
- **Scaling Policies** - политики масштабирования

### **2. Scaling Logic:**
- **Scale Up** - добавление узлов при нехватке ресурсов
- **Scale Down** - удаление неиспользуемых узлов
- **Node Utilization** - мониторинг использования узлов
- **Pod Scheduling** - анализ планирования Pod'ов

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ Cluster Autoscaler в DigitalOcean:**
```bash
# Проверить настройки автомасштабирования в .env
grep -E "(AUTO_SCALE|MIN_NODES|MAX_NODES)" ha/.env

# Проверить Cluster Autoscaler в кластере
kubectl get pods -n kube-system | grep cluster-autoscaler
kubectl describe configmap cluster-autoscaler-status -n kube-system
```

### **2. Создание comprehensive Cluster Autoscaler toolkit:**
```bash
# Создать скрипт для работы с Cluster Autoscaler
cat << 'EOF' > kubernetes-cluster-autoscaler-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Cluster Autoscaler Toolkit ==="
echo "Comprehensive toolkit for Cluster Autoscaler in HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния Cluster Autoscaler
analyze_cluster_autoscaler() {
    echo "=== Cluster Autoscaler Analysis ==="
    
    echo "1. Cluster Autoscaler Pod Status:"
    echo "================================="
    kubectl get pods -n kube-system -l app=cluster-autoscaler -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,NODE:.spec.nodeName,AGE:.metadata.creationTimestamp"
    echo
    
    echo "2. Cluster Autoscaler Configuration:"
    echo "==================================="
    kubectl get deployment cluster-autoscaler -n kube-system -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null | jq -r '.[]' | grep -E "(min-nodes|max-nodes|scale-down)" || echo "Cluster Autoscaler deployment not found"
    echo
    
    echo "3. Node Groups and Scaling Limits:"
    echo "=================================="
    kubectl get nodes -o custom-columns="NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,UNSCHEDULABLE:.spec.unschedulable,AGE:.metadata.creationTimestamp"
    echo
    
    echo "4. Cluster Autoscaler Status ConfigMap:"
    echo "======================================="
    kubectl get configmap cluster-autoscaler-status -n kube-system -o jsonpath='{.data}' 2>/dev/null | jq . || echo "Status ConfigMap not found"
    echo
    
    echo "5. Recent Scaling Events:"
    echo "========================"
    kubectl get events -n kube-system --field-selector source=cluster-autoscaler --sort-by='.lastTimestamp' | tail -10 || echo "No cluster autoscaler events found"
    echo
}

# Функция для мониторинга ресурсов кластера
monitor_cluster_resources() {
    echo "=== Cluster Resource Monitoring ==="
    
    echo "1. Node Resource Allocation:"
    echo "==========================="
    kubectl describe nodes | grep -A 5 "Allocated resources:" | grep -E "(Resource|cpu|memory|Requests|Limits)" || echo "Resource information not available"
    echo
    
    echo "2. Pending Pods (trigger for scale up):"
    echo "======================================="
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REASON:.status.conditions[?(@.type=='PodScheduled')].reason,MESSAGE:.status.conditions[?(@.type=='PodScheduled')].message"
    echo
    
    echo "3. Node Utilization:"
    echo "==================="
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "4. Unschedulable Nodes:"
    echo "======================"
    kubectl get nodes --field-selector spec.unschedulable=true -o custom-columns="NAME:.metadata.name,REASON:.metadata.annotations.cluster-autoscaler\.kubernetes\.io/scale-down-disabled,SINCE:.metadata.creationTimestamp"
    echo
    
    echo "5. Node Pool Information (DigitalOcean):"
    echo "========================================"
    # This would require doctl CLI tool
    if command -v doctl >/dev/null 2>&1; then
        doctl kubernetes cluster node-pool list hashfoundry-ha 2>/dev/null || echo "doctl not configured or cluster not found"
    else
        echo "doctl CLI not available - install with: snap install doctl"
    fi
    echo
}

# Функция для создания test workloads для демонстрации автомасштабирования
create_scaling_test_workloads() {
    echo "=== Creating Scaling Test Workloads ==="
    
    # Создать namespace для тестов
    kubectl create namespace cluster-autoscaler-test --dry-run=client -o yaml | kubectl apply -f -
    
    # Test 1: Resource-intensive workload to trigger scale up
    cat << SCALE_UP_TEST_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-intensive-scale-test
  namespace: cluster-autoscaler-test
  labels:
    app.kubernetes.io/name: "resource-intensive-scale-test"
    hashfoundry.io/test: "cluster-autoscaler-scale-up"
  annotations:
    hashfoundry.io/description: "Resource intensive workload to test cluster scale up"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "resource-intensive-scale-test"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "resource-intensive-scale-test"
        hashfoundry.io/test-type: "scale-up"
    spec:
      containers:
      - name: resource-consumer
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "1500m"  # High CPU request to trigger scaling
            memory: "2Gi"  # High memory request
          limits:
            cpu: "2"
            memory: "4Gi"
        ports:
        - containerPort: 80
        env:
        - name: TEST_TYPE
          value: "cluster-autoscaler-scale-up"
SCALE_UP_TEST_EOF
    
    # Test 2: Multiple small workloads
    cat << MULTIPLE_PODS_TEST_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multiple-pods-scale-test
  namespace: cluster-autoscaler-test
  labels:
    app.kubernetes.io/name: "multiple-pods-scale-test"
    hashfoundry.io/test: "cluster-autoscaler-multiple-pods"
  annotations:
    hashfoundry.io/description: "Multiple pods to test cluster scaling behavior"
spec:
  replicas: 10
  selector:
    matchLabels:
      app.kubernetes.io/name: "multiple-pods-scale-test"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "multiple-pods-scale-test"
        hashfoundry.io/test-type: "multiple-pods"
    spec:
      containers:
      - name: pod
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1"
            memory: "1Gi"
        ports:
        - containerPort: 80
        env:
        - name: TEST_TYPE
          value: "cluster-autoscaler-multiple-pods"
MULTIPLE_PODS_TEST_EOF
    
    # Test 3: Anti-affinity workload to force node spreading
    cat << ANTI_AFFINITY_TEST_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: anti-affinity-scale-test
  namespace: cluster-autoscaler-test
  labels:
    app.kubernetes.io/name: "anti-affinity-scale-test"
    hashfoundry.io/test: "cluster-autoscaler-anti-affinity"
  annotations:
    hashfoundry.io/description: "Anti-affinity workload to force node spreading"
spec:
  replicas: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: "anti-affinity-scale-test"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "anti-affinity-scale-test"
        hashfoundry.io/test-type: "anti-affinity"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                - anti-affinity-scale-test
            topologyKey: kubernetes.io/hostname
      containers:
      - name: pod
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "800m"
            memory: "1Gi"
          limits:
            cpu: "1"
            memory: "2Gi"
        ports:
        - containerPort: 80
        env:
        - name: TEST_TYPE
          value: "cluster-autoscaler-anti-affinity"
ANTI_AFFINITY_TEST_EOF
    
    echo "✅ Scaling test workloads created"
    echo "⚠️  These workloads may trigger cluster scaling - monitor cluster-autoscaler logs"
    echo
}

# Функция для создания monitoring tools
create_cluster_autoscaler_monitoring() {
    echo "=== Creating Cluster Autoscaler Monitoring Tools ==="
    
    cat << CA_MONITOR_EOF > cluster-autoscaler-monitoring.sh
#!/bin/bash

echo "=== Cluster Autoscaler Monitoring Tools ==="
echo "Tools for monitoring cluster autoscaling behavior"
echo

# Function to monitor cluster autoscaler in real-time
monitor_cluster_autoscaler() {
    echo "=== Real-time Cluster Autoscaler Monitoring ==="
    
    while true; do
        clear
        echo "Cluster Autoscaler Status - \$(date)"
        echo "=================================="
        echo
        
        # Cluster Autoscaler pod status
        echo "1. Cluster Autoscaler Pod:"
        kubectl get pods -n kube-system -l app=cluster-autoscaler --no-headers 2>/dev/null || echo "Cluster Autoscaler not found"
        echo
        
        # Node count and status
        echo "2. Node Status:"
        kubectl get nodes --no-headers | awk '{print \$2}' | sort | uniq -c
        echo "Total nodes: \$(kubectl get nodes --no-headers | wc -l)"
        echo
        
        # Pending pods
        echo "3. Pending Pods:"
        PENDING_COUNT=\$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers | wc -l)
        echo "Pending pods: \$PENDING_COUNT"
        if [ "\$PENDING_COUNT" -gt 0 ]; then
            kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REASON:.status.conditions[?(@.type=='PodScheduled')].reason" | head -5
        fi
        echo
        
        # Resource utilization
        echo "4. Node Resource Utilization:"
        kubectl top nodes 2>/dev/null | head -5 || echo "Metrics server not available"
        echo
        
        # Recent events
        echo "5. Recent Cluster Autoscaler Events:"
        kubectl get events -n kube-system --field-selector source=cluster-autoscaler --sort-by='.lastTimestamp' 2>/dev/null | tail -3 || echo "No recent events"
        echo
        
        echo "Press Ctrl+C to stop monitoring"
        sleep 10
    done
}

# Function to analyze scaling decisions
analyze_scaling_decisions() {
    echo "=== Analyzing Scaling Decisions ==="
    
    echo "1. Cluster Autoscaler Logs (last 50 lines):"
    echo "==========================================="
    kubectl logs -n kube-system -l app=cluster-autoscaler --tail=50 2>/dev/null | grep -E "(scale|node|pod)" || echo "No cluster autoscaler logs available"
    echo
    
    echo "2. Scale Up Events:"
    echo "=================="
    kubectl get events --all-namespaces --field-selector reason=TriggeredScaleUp --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || echo "No scale up events found"
    echo
    
    echo "3. Scale Down Events:"
    echo "===================="
    kubectl get events --all-namespaces --field-selector reason=ScaleDown --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || echo "No scale down events found"
    echo
    
    echo "4. Node Addition/Removal Events:"
    echo "==============================="
    kubectl get events --all-namespaces --field-selector involvedObject.kind=Node --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No node events found"
    echo
}

# Function to test cluster scaling
test_cluster_scaling() {
    local test_type=\${1:-"scale-up"}
    
    echo "=== Testing Cluster Scaling: \$test_type ==="
    
    case "\$test_type" in
        "scale-up")
            echo "Creating workload to trigger scale up..."
            kubectl scale deployment resource-intensive-scale-test -n cluster-autoscaler-test --replicas=3 2>/dev/null || echo "Test deployment not found - run create_scaling_test_workloads first"
            ;;
        "scale-down")
            echo "Reducing workload to trigger scale down..."
            kubectl scale deployment resource-intensive-scale-test -n cluster-autoscaler-test --replicas=0 2>/dev/null
            kubectl scale deployment multiple-pods-scale-test -n cluster-autoscaler-test --replicas=0 2>/dev/null
            kubectl scale deployment anti-affinity-scale-test -n cluster-autoscaler-test --replicas=0 2>/dev/null
            ;;
        *)
            echo "Usage: test_cluster_scaling [scale-up|scale-down]"
            return 1
            ;;
    esac
    
    echo "Monitoring scaling for 5 minutes..."
    for i in {1..30}; do
        echo "Minute \$((i/6 + 1)): \$(date)"
        echo "Nodes: \$(kubectl get nodes --no-headers | wc -l)"
        echo "Pending pods: \$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers | wc -l)"
        echo "---"
        sleep 10
    done
    
    echo "✅ Scaling test completed"
    echo
}

# Function to generate cluster autoscaler report
generate_cluster_autoscaler_report() {
    echo "=== Generating Cluster Autoscaler Report ==="
    
    local report_file="cluster-autoscaler-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster Autoscaler Report"
        echo "========================================"
        echo "Generated: \$(date)"
        echo ""
        
        echo "=== CLUSTER AUTOSCALER STATUS ==="
        kubectl get pods -n kube-system -l app=cluster-autoscaler
        echo ""
        
        echo "=== NODE STATUS ==="
        kubectl get nodes
        echo ""
        
        echo "=== PENDING PODS ==="
        kubectl get pods --all-namespaces --field-selector=status.phase=Pending
        echo ""
        
        echo "=== RESOURCE UTILIZATION ==="
        kubectl top nodes 2>/dev/null || echo "Metrics server not available"
        echo ""
        
        echo "=== RECENT SCALING EVENTS ==="
        kubectl get events --all-namespaces --field-selector source=cluster-autoscaler --sort-by='.lastTimestamp' | tail -20
        echo ""
        
        echo "=== CLUSTER AUTOSCALER LOGS ==="
        kubectl logs -n kube-system -l app=cluster-autoscaler --tail=100 2>/dev/null || echo "Logs not available"
        echo ""
        
    } > "\$report_file"
    
    echo "✅ Cluster Autoscaler report generated: \$report_file"
    echo
}

# Main function
main() {
    case "\$1" in
        "monitor")
            monitor_cluster_autoscaler
            ;;
        "analyze")
            analyze_scaling_decisions
            ;;
        "test")
            test_cluster_scaling "\$2"
            ;;
        "report")
            generate_cluster_autoscaler_report
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  monitor           - Real-time cluster autoscaler monitoring"
            echo "  analyze           - Analyze scaling decisions"
            echo "  test [type]       - Test cluster scaling (scale-up|scale-down)"
            echo "  report            - Generate cluster autoscaler report"
            echo ""
            echo "Examples:"
            echo "  \$0 monitor"
            echo "  \$0 analyze"
            echo "  \$0 test scale-up"
            echo "  \$0 report"
            ;;
    esac
}

# Run main function
main "\$@"

CA_MONITOR_EOF
    
    chmod +x cluster-autoscaler-monitoring.sh
    
    echo "✅ Cluster Autoscaler monitoring tools created: cluster-autoscaler-monitoring.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_cluster_autoscaler
            ;;
        "monitor-resources")
            monitor_cluster_resources
            ;;
        "test-workloads")
            create_scaling_test_workloads
            ;;
        "monitoring-tools")
            create_cluster_autoscaler_monitoring
            ;;
        "cleanup")
            # Cleanup test workloads
            kubectl delete namespace cluster-autoscaler-test --grace-period=0 2>/dev/null || true
            echo "✅ Test workloads cleaned up"
            ;;
        "all"|"")
            analyze_cluster_autoscaler
            monitor_cluster_resources
            create_scaling_test_workloads
            create_cluster_autoscaler_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze           - Analyze cluster autoscaler status"
            echo "  monitor-resources - Monitor cluster resources"
            echo "  test-workloads    - Create test workloads for scaling"
            echo "  monitoring-tools  - Create monitoring tools"
            echo "  cleanup           - Cleanup test workloads"
            echo "  all               - Run all actions (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 test-workloads"
            echo "  $0 cleanup"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-cluster-autoscaler-toolkit.sh

# Запустить создание Cluster Autoscaler toolkit
./kubernetes-cluster-autoscaler-toolkit.sh all
```

## 📋 **Cluster Autoscaler в DigitalOcean:**

### **Конфигурация из .env:**
```bash
# Настройки автомасштабирования из ha/.env
AUTO_SCALE_ENABLED=true
MIN_NODES=3
MAX_NODES=9
```

### **Scaling Triggers:**

| **Trigger** | **Action** | **Condition** | **Time** |
|-------------|------------|---------------|----------|
| **Pending Pods** | Scale Up | Pod'ы не могут быть запланированы | ~1-3 минуты |
| **Low Utilization** | Scale Down | Узел используется <50% | ~10-15 минут |
| **Empty Node** | Scale Down | Нет Pod'ов на узле | ~10 минут |
| **Resource Pressure** | Scale Up | Нехватка CPU/Memory | Немедленно |

## 🎯 **Практические команды:**

### **Мониторинг автомасштабирования:**
```bash
# Запустить Cluster Autoscaler toolkit
./kubernetes-cluster-autoscaler-toolkit.sh all

# Мониторинг в реальном времени
./cluster-autoscaler-monitoring.sh monitor

# Анализ решений масштабирования
./cluster-autoscaler-monitoring.sh analyze
```

### **Тестирование масштабирования:**
```bash
# Создать нагрузку для scale up
./cluster-autoscaler-monitoring.sh test scale-up

# Уменьшить нагрузку для scale down
./cluster-autoscaler-monitoring.sh test scale-down
```

### **Проверка состояния:**
```bash
# Проверить узлы
kubectl get nodes

# Проверить pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Проверить события автомасштабирования
kubectl get events --field-selector source=cluster-autoscaler
```

## 🔧 **Best Practices для Cluster Autoscaler:**

### **Конфигурация:**
- **Set appropriate min/max** - устанавливайте подходящие min/max
- **Configure node pools** - настраивайте пулы узлов
- **Set resource requests** - устанавливайте запросы ресурсов
- **Use PodDisruptionBudgets** - используйте PDB

### **Мониторинг:**
- **Monitor scaling events** - мониторьте события масштабирования
- **Track costs** - отслеживайте расходы
- **Set up alerts** - настройте оповещения
- **Regular review** - регулярно пересматривайте настройки

### **Troubleshooting:**
- **Check pending pods** - проверяйте pending Pod'ы
- **Verify node capacity** - проверяйте емкость узлов
- **Review scaling policies** - пересматривайте политики
- **Monitor cloud provider limits** - мониторьте лимиты провайдера

**Cluster Autoscaler обеспечивает автоматическое масштабирование инфраструктуры!**
