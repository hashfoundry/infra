# 101. Ключевые метрики для мониторинга в Kubernetes

## 🎯 **Ключевые метрики для мониторинга в Kubernetes**

**Мониторинг метрик** в Kubernetes критически важен для обеспечения производительности, надежности и безопасности кластера. Правильный набор метрик позволяет заблаговременно выявлять проблемы и оптимизировать работу системы.

## 🏗️ **Категории ключевых метрик:**

### **1. Cluster-level метрики:**
- **Node Health** - здоровье узлов
- **Resource Utilization** - использование ресурсов
- **API Server Performance** - производительность API сервера
- **etcd Performance** - производительность etcd

### **2. Application-level метрики:**
- **Pod Performance** - производительность Pod'ов
- **Container Metrics** - метрики контейнеров
- **Service Metrics** - метрики сервисов
- **Custom Application Metrics** - пользовательские метрики приложений

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих метрик кластера:**
```bash
# Проверить доступность metrics-server
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

### **2. Создание comprehensive metrics monitoring toolkit:**
```bash
# Создать скрипт для мониторинга ключевых метрик
cat << 'EOF' > kubernetes-key-metrics-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Key Metrics Monitoring Toolkit ==="
echo "Comprehensive metrics monitoring for HashFoundry HA cluster"
echo

# Функция для мониторинга cluster-level метрик
monitor_cluster_metrics() {
    echo "=== Cluster-Level Metrics ==="
    
    echo "1. Node Health Metrics:"
    echo "======================"
    kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,CPU-PRESSURE:.status.conditions[?(@.type=='MemoryPressure')].status,MEMORY-PRESSURE:.status.conditions[?(@.type=='MemoryPressure')].status,DISK-PRESSURE:.status.conditions[?(@.type=='DiskPressure')].status,PID-PRESSURE:.status.conditions[?(@.type=='PIDPressure')].status"
    echo
    
    echo "2. Node Resource Utilization:"
    echo "============================"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "3. Cluster Resource Summary:"
    echo "==========================="
    echo "Total Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "Ready Nodes: $(kubectl get nodes --no-headers | grep Ready | wc -l)"
    echo "Total Pods: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
    echo "Running Pods: $(kubectl get pods --all-namespaces --no-headers | grep Running | wc -l)"
    echo "Failed Pods: $(kubectl get pods --all-namespaces --no-headers | grep -E '(Failed|Error|CrashLoopBackOff)' | wc -l)"
    echo
    
    echo "4. API Server Metrics:"
    echo "====================="
    kubectl get pods -n kube-system -l component=kube-apiserver -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"
    echo
    
    echo "5. etcd Health:"
    echo "=============="
    kubectl get pods -n kube-system -l component=etcd -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"
    echo
}

# Функция для мониторинга application-level метрик
monitor_application_metrics() {
    echo "=== Application-Level Metrics ==="
    
    echo "1. Pod Resource Usage:"
    echo "====================="
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
    
    echo "2. Container Restart Analysis:"
    echo "============================="
    kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase" | grep -v "0" | head -10
    echo
    
    echo "3. Pod Status Distribution:"
    echo "=========================="
    echo "Running: $(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)"
    echo "Pending: $(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers | wc -l)"
    echo "Failed: $(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers | wc -l)"
    echo "Succeeded: $(kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded --no-headers | wc -l)"
    echo
    
    echo "4. Service Endpoints:"
    echo "===================="
    kubectl get endpoints --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,ENDPOINTS:.subsets[*].addresses[*].ip" | head -10
    echo
    
    echo "5. Persistent Volume Usage:"
    echo "=========================="
    kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name,STORAGECLASS:.spec.storageClassName"
    echo
}

# Функция для мониторинга network метрик
monitor_network_metrics() {
    echo "=== Network Metrics ==="
    
    echo "1. Service Status:"
    echo "================="
    kubectl get services --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORTS:.spec.ports[*].port"
    echo
    
    echo "2. Ingress Status:"
    echo "================="
    kubectl get ingress --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[*].ip,PORTS:.spec.tls[*].secretName" 2>/dev/null || echo "No ingress resources found"
    echo
    
    echo "3. Network Policies:"
    echo "==================="
    kubectl get networkpolicies --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,POD-SELECTOR:.spec.podSelector" 2>/dev/null || echo "No network policies found"
    echo
}

# Функция для мониторинга storage метрик
monitor_storage_metrics() {
    echo "=== Storage Metrics ==="
    
    echo "1. Persistent Volume Claims:"
    echo "==========================="
    kubectl get pvc --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "2. Storage Classes:"
    echo "=================="
    kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM-POLICY:.reclaimPolicy,VOLUME-BINDING-MODE:.volumeBindingMode,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class"
    echo
    
    echo "3. Volume Snapshots:"
    echo "==================="
    kubectl get volumesnapshots --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyToUse,SOURCE:.spec.source.persistentVolumeClaimName,RESTORESIZE:.status.restoreSize" 2>/dev/null || echo "No volume snapshots found"
    echo
}

# Функция для создания metrics collection script
create_metrics_collection_script() {
    echo "=== Creating Metrics Collection Script ==="
    
    cat << METRICS_SCRIPT_EOF > collect-key-metrics.sh
#!/bin/bash

echo "=== Kubernetes Key Metrics Collection ==="
echo "Collecting key metrics from HashFoundry HA cluster"
echo

# Timestamp
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
METRICS_FILE="kubernetes-metrics-\$TIMESTAMP.json"

# Function to collect node metrics
collect_node_metrics() {
    echo "Collecting node metrics..."
    
    {
        echo "{"
        echo "  \"timestamp\": \"\$(date -Iseconds)\","
        echo "  \"cluster_name\": \"hashfoundry-ha\","
        echo "  \"node_metrics\": ["
        
        kubectl get nodes -o json | jq -r '.items[] | {
            name: .metadata.name,
            status: .status.conditions[] | select(.type=="Ready") | .status,
            cpu_capacity: .status.capacity.cpu,
            memory_capacity: .status.capacity.memory,
            pods_capacity: .status.capacity.pods,
            cpu_allocatable: .status.allocatable.cpu,
            memory_allocatable: .status.allocatable.memory,
            pods_allocatable: .status.allocatable.pods,
            kernel_version: .status.nodeInfo.kernelVersion,
            kubelet_version: .status.nodeInfo.kubeletVersion,
            container_runtime: .status.nodeInfo.containerRuntimeVersion
        }' | jq -s '.'
        
        echo "  ],"
    } >> "\$METRICS_FILE"
}

# Function to collect pod metrics
collect_pod_metrics() {
    echo "Collecting pod metrics..."
    
    {
        echo "  \"pod_metrics\": ["
        
        kubectl get pods --all-namespaces -o json | jq -r '.items[] | {
            namespace: .metadata.namespace,
            name: .metadata.name,
            phase: .status.phase,
            ready: (.status.conditions[] | select(.type=="Ready") | .status),
            restarts: (.status.containerStatuses[]?.restartCount // 0),
            cpu_requests: (.spec.containers[]?.resources.requests.cpu // "0"),
            memory_requests: (.spec.containers[]?.resources.requests.memory // "0"),
            cpu_limits: (.spec.containers[]?.resources.limits.cpu // "0"),
            memory_limits: (.spec.containers[]?.resources.limits.memory // "0"),
            node_name: .spec.nodeName,
            creation_timestamp: .metadata.creationTimestamp
        }' | jq -s '.'
        
        echo "  ],"
    } >> "\$METRICS_FILE"
}

# Function to collect service metrics
collect_service_metrics() {
    echo "Collecting service metrics..."
    
    {
        echo "  \"service_metrics\": ["
        
        kubectl get services --all-namespaces -o json | jq -r '.items[] | {
            namespace: .metadata.namespace,
            name: .metadata.name,
            type: .spec.type,
            cluster_ip: .spec.clusterIP,
            external_ip: (.status.loadBalancer.ingress[]?.ip // null),
            ports: [.spec.ports[]? | {port: .port, target_port: .targetPort, protocol: .protocol}],
            selector: .spec.selector
        }' | jq -s '.'
        
        echo "  ],"
    } >> "\$METRICS_FILE"
}

# Function to collect resource utilization
collect_resource_utilization() {
    echo "Collecting resource utilization..."
    
    {
        echo "  \"resource_utilization\": {"
        
        # Node resource usage
        echo "    \"nodes\": ["
        kubectl top nodes --no-headers 2>/dev/null | while read line; do
            if [ -n "\$line" ]; then
                name=\$(echo "\$line" | awk '{print \$1}')
                cpu=\$(echo "\$line" | awk '{print \$2}')
                cpu_percent=\$(echo "\$line" | awk '{print \$3}')
                memory=\$(echo "\$line" | awk '{print \$4}')
                memory_percent=\$(echo "\$line" | awk '{print \$5}')
                
                echo "      {"
                echo "        \"name\": \"\$name\","
                echo "        \"cpu_usage\": \"\$cpu\","
                echo "        \"cpu_percentage\": \"\$cpu_percent\","
                echo "        \"memory_usage\": \"\$memory\","
                echo "        \"memory_percentage\": \"\$memory_percent\""
                echo "      },"
            fi
        done | sed '\$s/,\$//'
        echo "    ],"
        
        # Pod resource usage
        echo "    \"pods\": ["
        kubectl top pods --all-namespaces --no-headers 2>/dev/null | head -20 | while read line; do
            if [ -n "\$line" ]; then
                namespace=\$(echo "\$line" | awk '{print \$1}')
                name=\$(echo "\$line" | awk '{print \$2}')
                cpu=\$(echo "\$line" | awk '{print \$3}')
                memory=\$(echo "\$line" | awk '{print \$4}')
                
                echo "      {"
                echo "        \"namespace\": \"\$namespace\","
                echo "        \"name\": \"\$name\","
                echo "        \"cpu_usage\": \"\$cpu\","
                echo "        \"memory_usage\": \"\$memory\""
                echo "      },"
            fi
        done | sed '\$s/,\$//'
        echo "    ]"
        
        echo "  }"
        echo "}"
    } >> "\$METRICS_FILE"
}

# Main collection function
main() {
    echo "Starting metrics collection..."
    
    # Initialize JSON file
    echo "" > "\$METRICS_FILE"
    
    collect_node_metrics
    collect_pod_metrics
    collect_service_metrics
    collect_resource_utilization
    
    echo "✅ Metrics collected successfully: \$METRICS_FILE"
    
    # Generate summary
    echo ""
    echo "=== Metrics Summary ==="
    echo "Nodes: \$(kubectl get nodes --no-headers | wc -l)"
    echo "Pods: \$(kubectl get pods --all-namespaces --no-headers | wc -l)"
    echo "Services: \$(kubectl get services --all-namespaces --no-headers | wc -l)"
    echo "Namespaces: \$(kubectl get namespaces --no-headers | wc -l)"
    echo "PVs: \$(kubectl get pv --no-headers | wc -l)"
    echo "File size: \$(ls -lh \$METRICS_FILE | awk '{print \$5}')"
}

# Run main function
main

METRICS_SCRIPT_EOF
    
    chmod +x collect-key-metrics.sh
    
    echo "✅ Metrics collection script created: collect-key-metrics.sh"
    echo
}

# Функция для создания metrics dashboard
create_metrics_dashboard() {
    echo "=== Creating Metrics Dashboard ==="
    
    cat << DASHBOARD_EOF > metrics-dashboard.sh
#!/bin/bash

echo "=== Kubernetes Metrics Dashboard ==="
echo "Real-time metrics dashboard for HashFoundry HA cluster"
echo

# Function to display metrics dashboard
display_metrics_dashboard() {
    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                    HashFoundry HA Cluster - Metrics Dashboard              ║"
        echo "╠══════════════════════════════════════════════════════════════════════════════╣"
        echo "║ Time: \$(date)                                                    ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo
        
        # Cluster Overview
        echo "🏥 CLUSTER OVERVIEW"
        echo "=================="
        echo "Nodes: \$(kubectl get nodes --no-headers | wc -l) (\$(kubectl get nodes --no-headers | grep Ready | wc -l) ready)"
        echo "Pods: \$(kubectl get pods --all-namespaces --no-headers | wc -l) (\$(kubectl get pods --all-namespaces --no-headers | grep Running | wc -l) running)"
        echo "Services: \$(kubectl get services --all-namespaces --no-headers | wc -l)"
        echo "PVs: \$(kubectl get pv --no-headers | wc -l)"
        echo
        
        # Resource Utilization
        echo "📊 RESOURCE UTILIZATION"
        echo "======================="
        kubectl top nodes 2>/dev/null | head -5 || echo "Metrics server not available"
        echo
        
        # Top Resource Consumers
        echo "🔥 TOP RESOURCE CONSUMERS"
        echo "========================"
        echo "CPU:"
        kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -3 || echo "Metrics server not available"
        echo
        echo "Memory:"
        kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -3 || echo "Metrics server not available"
        echo
        
        # Health Status
        echo "💚 HEALTH STATUS"
        echo "==============="
        FAILED_PODS=\$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers | wc -l)
        PENDING_PODS=\$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers | wc -l)
        NOT_READY_NODES=\$(kubectl get nodes --no-headers | grep -v Ready | wc -l)
        
        if [ "\$FAILED_PODS" -gt 0 ]; then
            echo "❌ Failed Pods: \$FAILED_PODS"
        fi
        if [ "\$PENDING_PODS" -gt 0 ]; then
            echo "⏳ Pending Pods: \$PENDING_PODS"
        fi
        if [ "\$NOT_READY_NODES" -gt 0 ]; then
            echo "🔴 Not Ready Nodes: \$NOT_READY_NODES"
        fi
        if [ "\$FAILED_PODS" -eq 0 ] && [ "\$PENDING_PODS" -eq 0 ] && [ "\$NOT_READY_NODES" -eq 0 ]; then
            echo "✅ All systems healthy"
        fi
        echo
        
        echo "Press Ctrl+C to exit | Refreshing in 15 seconds..."
        sleep 15
    done
}

# Run dashboard
display_metrics_dashboard

DASHBOARD_EOF
    
    chmod +x metrics-dashboard.sh
    
    echo "✅ Metrics dashboard created: metrics-dashboard.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "cluster")
            monitor_cluster_metrics
            ;;
        "apps")
            monitor_application_metrics
            ;;
        "network")
            monitor_network_metrics
            ;;
        "storage")
            monitor_storage_metrics
            ;;
        "collect")
            create_metrics_collection_script
            ./collect-key-metrics.sh
            ;;
        "dashboard")
            create_metrics_dashboard
            ./metrics-dashboard.sh
            ;;
        "all"|"")
            monitor_cluster_metrics
            monitor_application_metrics
            monitor_network_metrics
            monitor_storage_metrics
            create_metrics_collection_script
            create_metrics_dashboard
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  cluster    - Monitor cluster-level metrics"
            echo "  apps       - Monitor application-level metrics"
            echo "  network    - Monitor network metrics"
            echo "  storage    - Monitor storage metrics"
            echo "  collect    - Create and run metrics collection script"
            echo "  dashboard  - Create and run metrics dashboard"
            echo "  all        - Monitor all metrics and create tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0 cluster"
            echo "  $0 collect"
            echo "  $0 dashboard"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-key-metrics-toolkit.sh

# Запустить создание Key Metrics toolkit
./kubernetes-key-metrics-toolkit.sh all
```

## 📋 **Критические метрики по категориям:**

### **Cluster Health:**

| **Метрика** | **Описание** | **Критический порог** | **Команда kubectl** |
|-------------|--------------|----------------------|---------------------|
| **Node Ready** | Готовность узлов | < 100% | `kubectl get nodes` |
| **API Server Latency** | Задержка API сервера | > 1s | `kubectl get --raw /metrics` |
| **etcd Health** | Здоровье etcd | Недоступен | `kubectl get pods -n kube-system -l component=etcd` |
| **Control Plane CPU** | CPU control plane | > 80% | `kubectl top pods -n kube-system` |

### **Application Performance:**

| **Метрика** | **Описание** | **Критический порог** | **Команда kubectl** |
|-------------|--------------|----------------------|---------------------|
| **Pod CPU Usage** | Использование CPU | > 80% | `kubectl top pods --all-namespaces` |
| **Pod Memory Usage** | Использование памяти | > 90% | `kubectl top pods --sort-by=memory` |
| **Pod Restart Count** | Количество перезапусков | > 5 за час | `kubectl get pods -o wide` |
| **Container OOMKilled** | Убийства по памяти | > 0 | `kubectl describe pod <pod-name>` |

### **Network & Storage:**

| **Метрика** | **Описание** | **Критический порог** | **Команда kubectl** |
|-------------|--------------|----------------------|---------------------|
| **Service Endpoints** | Доступность endpoints | 0 endpoints | `kubectl get endpoints` |
| **PV Usage** | Использование томов | > 85% | `kubectl get pv` |
| **Network Errors** | Сетевые ошибки | > 1% | `kubectl get events` |

## 🎯 **Практические команды:**

### **Мониторинг ключевых метрик:**
```bash
# Запустить полный мониторинг метрик
./kubernetes-key-metrics-toolkit.sh all

# Мониторинг только кластера
./kubernetes-key-metrics-toolkit.sh cluster

# Запустить dashboard метрик
./metrics-dashboard.sh
```

### **Сбор метрик:**
```bash
# Собрать метрики в JSON
./collect-key-metrics.sh

# Проверить топ потребителей ресурсов
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top nodes
```

### **Анализ проблем:**
```bash
# Найти проблемные Pod'ы
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Проверить события
kubectl get events --sort-by='.lastTimestamp'

# Анализ ресурсов
kubectl describe node <node-name>
```

## 🔧 **Best Practices для мониторинга метрик:**

### **Что мониторить:**
- **Golden Signals** - latency, traffic, errors, saturation
- **Resource utilization** - CPU, memory, disk, network
- **Application health** - readiness, liveness probes
- **Business metrics** - custom application metrics

### **Как мониторить:**
- **Use Prometheus** - для сбора метрик
- **Set up alerts** - для критических метрик
- **Create dashboards** - для визуализации
- **Monitor trends** - для планирования емкости

**Правильный мониторинг ключевых метрик - основа надежной работы Kubernetes кластера!**
