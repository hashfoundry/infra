# 140. Как устранять распространенные проблемы Kubernetes

## 🎯 **Как устранять распространенные проблемы Kubernetes?**

**Troubleshooting в Kubernetes** требует систематического подхода и знания основных инструментов диагностики. Эффективное устранение неполадок критически важно для поддержания стабильности production кластера.

## 🌐 **Категории проблем Kubernetes:**

### **1. Pod Issues:**
- **CrashLoopBackOff** - циклические перезапуски
- **ImagePullBackOff** - проблемы с образами
- **Pending** - проблемы планирования
- **OOMKilled** - нехватка памяти

### **2. Network Issues:**
- **Service Discovery** - проблемы обнаружения сервисов
- **DNS Resolution** - проблемы DNS
- **Ingress Issues** - проблемы входящего трафика
- **Network Policies** - проблемы сетевых политик

### **3. Storage Issues:**
- **PVC Pending** - проблемы с томами
- **Mount Issues** - проблемы монтирования
- **Storage Classes** - проблемы классов хранения

### **4. Cluster Issues:**
- **Node NotReady** - недоступные узлы
- **Resource Exhaustion** - исчерпание ресурсов
- **API Server Issues** - проблемы API сервера

## 📊 **Практические примеры из вашего HA кластера:**

### **Основные команды диагностики:**

```bash
# Создать comprehensive troubleshooting toolkit
cat << 'EOF' > troubleshooting-toolkit.sh
#!/bin/bash

echo "=== HashFoundry Kubernetes Troubleshooting Toolkit ==="
echo "Timestamp: $(date)"
echo

# Функция для общей диагностики кластера
cluster_health_check() {
    echo "=== Cluster Health Check ==="
    
    echo "1. Cluster Info:"
    kubectl cluster-info
    echo
    
    echo "2. Node Status:"
    kubectl get nodes -o wide
    echo
    
    echo "3. System Pods Status:"
    kubectl get pods -n kube-system
    echo
    
    echo "4. Component Status:"
    kubectl get componentstatuses 2>/dev/null || echo "ComponentStatus API deprecated"
    echo
    
    echo "5. API Server Health:"
    kubectl get --raw='/healthz'
    echo
    
    echo "6. Cluster Events (last 10):"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -10
    echo
}

# Функция для диагностики подов
pod_troubleshooting() {
    local namespace=${1:-"default"}
    local pod_name=${2:-""}
    
    echo "=== Pod Troubleshooting ==="
    echo "Namespace: $namespace"
    echo "Pod: $pod_name"
    echo
    
    if [ -z "$pod_name" ]; then
        echo "All pods in namespace $namespace:"
        kubectl get pods -n $namespace -o wide
        echo
        
        echo "Problematic pods:"
        kubectl get pods -n $namespace --field-selector=status.phase!=Running
        echo
    else
        echo "Pod Details:"
        kubectl describe pod $pod_name -n $namespace
        echo
        
        echo "Pod Logs:"
        kubectl logs $pod_name -n $namespace --tail=50
        echo
        
        echo "Previous Pod Logs (if crashed):"
        kubectl logs $pod_name -n $namespace --previous --tail=50 2>/dev/null || echo "No previous logs"
        echo
    fi
}

# Функция для диагностики сервисов
service_troubleshooting() {
    local namespace=${1:-"default"}
    local service_name=${2:-""}
    
    echo "=== Service Troubleshooting ==="
    echo "Namespace: $namespace"
    echo "Service: $service_name"
    echo
    
    if [ -z "$service_name" ]; then
        echo "All services in namespace $namespace:"
        kubectl get services -n $namespace -o wide
        echo
        
        echo "Endpoints:"
        kubectl get endpoints -n $namespace
        echo
    else
        echo "Service Details:"
        kubectl describe service $service_name -n $namespace
        echo
        
        echo "Service Endpoints:"
        kubectl get endpoints $service_name -n $namespace -o yaml
        echo
    fi
}

# Функция для диагностики сети
network_troubleshooting() {
    echo "=== Network Troubleshooting ==="
    
    echo "1. DNS Configuration:"
    kubectl get configmap coredns -n kube-system -o yaml
    echo
    
    echo "2. DNS Service:"
    kubectl get service kube-dns -n kube-system
    echo
    
    echo "3. Network Policies:"
    kubectl get networkpolicies --all-namespaces
    echo
    
    echo "4. Ingress Controllers:"
    kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
    echo
    
    echo "5. CNI Pods:"
    kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium)"
    echo
}

# Функция для диагностики хранилища
storage_troubleshooting() {
    echo "=== Storage Troubleshooting ==="
    
    echo "1. Storage Classes:"
    kubectl get storageclass
    echo
    
    echo "2. Persistent Volumes:"
    kubectl get pv
    echo
    
    echo "3. Persistent Volume Claims:"
    kubectl get pvc --all-namespaces
    echo
    
    echo "4. Volume Attachments:"
    kubectl get volumeattachment
    echo
}

# Функция для диагностики ресурсов
resource_troubleshooting() {
    echo "=== Resource Troubleshooting ==="
    
    echo "1. Node Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "2. Pod Resource Usage:"
    kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "3. Resource Quotas:"
    kubectl get resourcequota --all-namespaces
    echo
    
    echo "4. Limit Ranges:"
    kubectl get limitrange --all-namespaces
    echo
}

# Main function
main() {
    case "$1" in
        "cluster")
            cluster_health_check
            ;;
        "pod")
            pod_troubleshooting "$2" "$3"
            ;;
        "service")
            service_troubleshooting "$2" "$3"
            ;;
        "network")
            network_troubleshooting
            ;;
        "storage")
            storage_troubleshooting
            ;;
        "resources")
            resource_troubleshooting
            ;;
        "all")
            cluster_health_check
            echo
            network_troubleshooting
            echo
            storage_troubleshooting
            echo
            resource_troubleshooting
            ;;
        *)
            echo "Usage: $0 [cluster|pod|service|network|storage|resources|all] [namespace] [resource-name]"
            echo ""
            echo "Troubleshooting Commands:"
            echo "  cluster                           - Check overall cluster health"
            echo "  pod [namespace] [pod-name]        - Troubleshoot pods"
            echo "  service [namespace] [svc-name]    - Troubleshoot services"
            echo "  network                           - Check network components"
            echo "  storage                           - Check storage components"
            echo "  resources                         - Check resource usage"
            echo "  all                               - Run all checks"
            echo ""
            echo "Examples:"
            echo "  $0 cluster"
            echo "  $0 pod production webapp-pod"
            echo "  $0 service default my-service"
            echo "  $0 all"
            ;;
    esac
}

main "$@"
EOF

chmod +x troubleshooting-toolkit.sh
```

### **Диагностика Pod проблем:**

```bash
# CrashLoopBackOff диагностика
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# ImagePullBackOff диагностика
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Events:"
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>

# Pending pods диагностика
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --field-selector reason=FailedScheduling

# OOMKilled диагностика
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 -B 5 "OOMKilled"
kubectl top pod <pod-name> -n <namespace>
```

### **Debug Pod для диагностики:**

```yaml
# debug-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
  namespace: default
  labels:
    app: debug
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["/bin/bash"]
    args: ["-c", "sleep 3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "SYS_PTRACE"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
  restartPolicy: Never
```

```bash
# Использование debug pod
kubectl apply -f debug-pod.yaml
kubectl exec -it debug-pod -- /bin/bash

# Внутри debug pod:
# Проверка DNS
nslookup kubernetes.default.svc.cluster.local
dig @10.96.0.10 kubernetes.default.svc.cluster.local

# Проверка сетевой связности
ping <service-ip>
telnet <service-ip> <port>
curl -v http://<service-name>.<namespace>.svc.cluster.local

# Проверка сетевых интерфейсов
ip addr show
ip route show
```

### **Диагностика сетевых проблем:**

```bash
# Проверка DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Проверка CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns

# Проверка сетевых политик
kubectl describe networkpolicy <policy-name> -n <namespace>

# Проверка Ingress
kubectl describe ingress <ingress-name> -n <namespace>
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### **Диагностика хранилища:**

```bash
# Проверка PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Проверка PV
kubectl describe pv <pv-name>

# Проверка Storage Class
kubectl describe storageclass <sc-name>

# Проверка CSI драйверов
kubectl get csidriver
kubectl get csistoragecapacity
```

### **Мониторинг событий в реальном времени:**

```bash
# Создать скрипт для мониторинга событий
cat << 'EOF' > event-monitor.sh
#!/bin/bash

echo "=== Real-time Event Monitor ==="
echo "Monitoring events in HashFoundry HA cluster..."
echo "Press Ctrl+C to stop"
echo

# Функция для форматирования событий
format_events() {
    kubectl get events --all-namespaces -w --output-watch-events \
    --output=custom-columns=\
TIME:.lastTimestamp,\
NAMESPACE:.namespace,\
TYPE:.type,\
REASON:.reason,\
OBJECT:.involvedObject.kind/.involvedObject.name,\
MESSAGE:.message
}

# Функция для фильтрации важных событий
filter_important_events() {
    kubectl get events --all-namespaces -w --output-watch-events \
    --field-selector type!=Normal | \
    grep -E "(Warning|Error|Failed|Unhealthy|BackOff)"
}

case "$1" in
    "all")
        format_events
        ;;
    "warnings")
        filter_important_events
        ;;
    *)
        echo "Usage: $0 [all|warnings]"
        echo "  all      - Show all events"
        echo "  warnings - Show only warnings and errors"
        ;;
esac
EOF

chmod +x event-monitor.sh
```

### **Диагностика производительности:**

```bash
# Создать скрипт для анализа производительности
cat << 'EOF' > performance-analysis.sh
#!/bin/bash

echo "=== Performance Analysis ==="

# Функция для анализа ресурсов узлов
analyze_node_resources() {
    echo "1. Node Resource Analysis:"
    
    kubectl describe nodes | grep -A 5 "Allocated resources:" | \
    while read line; do
        echo "$line"
    done
    echo
    
    echo "2. Top Resource Consuming Pods:"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10
    echo
    kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -10
    echo
}

# Функция для анализа медленных подов
analyze_slow_pods() {
    echo "3. Pod Startup Analysis:"
    
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.namespace}{"\t"}{.status.phase}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' | \
    awk '{
        if ($3 == "Running") {
            cmd = "date -d " $4 " +%s"
            cmd | getline creation_time
            close(cmd)
            
            cmd = "date +%s"
            cmd | getline current_time
            close(cmd)
            
            startup_time = current_time - creation_time
            if (startup_time > 300) {  # More than 5 minutes
                print $1 "\t" $2 "\t" startup_time "s"
            }
        }
    }' | head -10
    echo
}

# Функция для анализа сетевой производительности
analyze_network_performance() {
    echo "4. Network Performance Indicators:"
    
    # Проверка DNS latency
    kubectl run dns-test --image=busybox --rm -it --restart=Never -- \
    sh -c 'time nslookup kubernetes.default.svc.cluster.local' 2>/dev/null || echo "DNS test failed"
    echo
}

analyze_node_resources
analyze_slow_pods
analyze_network_performance

echo "✅ Performance analysis completed"
EOF

chmod +x performance-analysis.sh
```

### **Автоматическая диагностика проблем:**

```bash
# Создать скрипт для автоматической диагностики
cat << 'EOF' > auto-diagnose.sh
#!/bin/bash

echo "=== Automatic Problem Diagnosis ==="

# Функция для поиска проблемных подов
find_problematic_pods() {
    echo "1. Problematic Pods:"
    
    # CrashLoopBackOff pods
    echo "   CrashLoopBackOff pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running | \
    grep "CrashLoopBackOff" | head -5
    
    # ImagePullBackOff pods
    echo "   ImagePullBackOff pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running | \
    grep "ImagePullBackOff" | head -5
    
    # Pending pods
    echo "   Pending pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending | head -5
    
    # OOMKilled pods
    echo "   Recently OOMKilled pods:"
    kubectl get events --all-namespaces --field-selector reason=OOMKilling | tail -5
    echo
}

# Функция для поиска проблем с ресурсами
find_resource_issues() {
    echo "2. Resource Issues:"
    
    # Nodes with high resource usage
    echo "   Node resource pressure:"
    kubectl describe nodes | grep -A 3 "Conditions:" | grep -E "(MemoryPressure|DiskPressure|PIDPressure)" | grep "True"
    
    # Failed PVCs
    echo "   Failed PVCs:"
    kubectl get pvc --all-namespaces | grep -v "Bound" | head -5
    echo
}

# Функция для поиска сетевых проблем
find_network_issues() {
    echo "3. Network Issues:"
    
    # Services without endpoints
    echo "   Services without endpoints:"
    kubectl get endpoints --all-namespaces | awk '$3 == "<none>" {print $1 "\t" $2}' | head -5
    
    # Failed ingress
    echo "   Ingress issues:"
    kubectl get ingress --all-namespaces | grep -v "ADDRESS" | awk '$4 == "" {print $1 "\t" $2}' | head -5
    echo
}

# Функция для генерации рекомендаций
generate_recommendations() {
    echo "4. Recommendations:"
    
    # Check for common misconfigurations
    echo "   Common Issues to Check:"
    echo "   - Resource limits and requests"
    echo "   - Image pull policies and registry access"
    echo "   - Service selectors matching pod labels"
    echo "   - Storage class availability"
    echo "   - Network policies blocking traffic"
    echo "   - RBAC permissions"
    echo
}

find_problematic_pods
find_resource_issues
find_network_issues
generate_recommendations

echo "✅ Automatic diagnosis completed"
EOF

chmod +x auto-diagnose.sh
```

### **Команды kubectl для быстрой диагностики:**

```bash
# Быстрая проверка состояния кластера
kubectl get nodes,pods --all-namespaces | grep -v Running

# Проверка событий за последние 30 минут
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | \
awk '$1 > systime()-1800'

# Поиск подов с высоким потреблением ресурсов
kubectl top pods --all-namespaces --sort-by=cpu | head -10
kubectl top pods --all-namespaces --sort-by=memory | head -10

# Проверка подов без resource limits
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits}{"\n"}{end}' | grep "null"

# Проверка failed deployments
kubectl get deployments --all-namespaces | awk '$3 != $4 {print $0}'

# Проверка unhealthy services
kubectl get endpoints --all-namespaces | grep "<none>"

# Проверка pending PVCs
kubectl get pvc --all-namespaces | grep -v "Bound"

# Проверка tainted nodes
kubectl describe nodes | grep -A 3 "Taints:"

# Проверка certificate expiration
kubectl get secrets --all-namespaces -o jsonpath='{range .items[?(@.type=="kubernetes.io/tls")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'
```

### **Логирование и мониторинг для troubleshooting:**

```bash
# Централизованный сбор логов
kubectl logs -f deployment/app-name -n production --all-containers=true

# Мониторинг метрик
kubectl top nodes
kubectl top pods --all-namespaces

# Проверка health checks
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].ready}{"\n"}{end}'

# Анализ restart count
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}' | sort -k2 -nr
```

## 🎯 **Систематический подход к troubleshooting:**

1. **Определить симптомы** - что именно не работает
2. **Собрать информацию** - логи, события, метрики
3. **Изолировать проблему** - определить компонент
4. **Проверить гипотезы** - тестировать возможные причины
5. **Применить решение** - исправить проблему
6. **Проверить результат** - убедиться в устранении
7. **Документировать** - записать решение для будущего

Эффективное troubleshooting требует знания архитектуры Kubernetes и систематического подхода к диагностике проблем в HashFoundry HA кластере.
