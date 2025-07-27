# 107. Как устранять распространенные проблемы в Kubernetes

## 🎯 **Как устранять распространенные проблемы в Kubernetes**

**Troubleshooting** в Kubernetes требует систематического подхода и понимания архитектуры системы. Эффективная диагностика проблем критически важна для поддержания стабильности кластера.

## 🔍 **Категории проблем:**

### **1. Pod Issues:**
- **CrashLoopBackOff** - контейнер постоянно перезапускается
- **ImagePullBackOff** - не удается загрузить образ
- **Pending** - Pod не может быть запланирован
- **OOMKilled** - нехватка памяти

### **2. Network Issues:**
- **Service connectivity** - проблемы с доступностью сервисов
- **DNS resolution** - проблемы с разрешением имен
- **Ingress issues** - проблемы с внешним доступом

### **3. Storage Issues:**
- **PVC Pending** - PersistentVolumeClaim в ожидании
- **Mount failures** - ошибки монтирования томов

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive troubleshooting toolkit
cat << 'EOF' > kubernetes-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Troubleshooting Toolkit ==="
echo "Comprehensive troubleshooting guide for HashFoundry HA cluster"
echo

# Функция для диагностики Pod проблем
troubleshoot_pods() {
    echo "=== Pod Troubleshooting ==="
    
    echo "1. Pods in problematic states:"
    echo "============================="
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
    echo
    
    echo "2. Recent Pod events:"
    echo "===================="
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -E "(Failed|Error|Warning)" | tail -10
    echo
    
    echo "3. Pods with high restart count:"
    echo "==============================="
    kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase" | awk 'NR==1 || $3>5'
    echo
    
    echo "4. Resource usage analysis:"
    echo "=========================="
    kubectl top pods --all-namespaces --sort-by=memory | head -10
    echo
}

# Функция для диагностики конкретного Pod
diagnose_pod() {
    local namespace=$1
    local pod_name=$2
    
    if [ -z "$namespace" ] || [ -z "$pod_name" ]; then
        echo "Usage: diagnose_pod <namespace> <pod_name>"
        return 1
    fi
    
    echo "=== Diagnosing Pod: $namespace/$pod_name ==="
    
    echo "1. Pod Status:"
    echo "============="
    kubectl get pod -n "$namespace" "$pod_name" -o wide
    echo
    
    echo "2. Pod Description:"
    echo "=================="
    kubectl describe pod -n "$namespace" "$pod_name"
    echo
    
    echo "3. Pod Events:"
    echo "============="
    kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp'
    echo
    
    echo "4. Container Logs:"
    echo "================="
    kubectl logs -n "$namespace" "$pod_name" --all-containers=true --tail=50
    echo
    
    echo "5. Previous Container Logs (if crashed):"
    echo "========================================"
    kubectl logs -n "$namespace" "$pod_name" --previous --all-containers=true --tail=50 2>/dev/null || echo "No previous logs available"
    echo
    
    echo "6. Resource Requests/Limits:"
    echo "============================"
    kubectl get pod -n "$namespace" "$pod_name" -o jsonpath='{.spec.containers[*].resources}' | jq .
    echo
}

# Функция для диагностики сетевых проблем
troubleshoot_network() {
    echo "=== Network Troubleshooting ==="
    
    echo "1. Service Status:"
    echo "================="
    kubectl get services --all-namespaces | grep -v "ClusterIP.*<none>"
    echo
    
    echo "2. Endpoint Status:"
    echo "=================="
    kubectl get endpoints --all-namespaces | awk 'NR==1 || $3=="<none>"'
    echo
    
    echo "3. DNS Testing:"
    echo "=============="
    cat << DNS_TEST_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-test
  namespace: default
spec:
  containers:
  - name: dns-test
    image: busybox:1.28
    command:
    - sleep
    - "3600"
  restartPolicy: Never
DNS_TEST_EOF
    
    sleep 10
    echo "Testing DNS resolution:"
    kubectl exec dns-test -- nslookup kubernetes.default.svc.cluster.local
    kubectl exec dns-test -- nslookup google.com
    kubectl delete pod dns-test --force --grace-period=0
    echo
    
    echo "4. CoreDNS Status:"
    echo "================="
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10
    echo
    
    echo "5. Network Policies:"
    echo "==================="
    kubectl get networkpolicies --all-namespaces
    echo
}

# Функция для диагностики проблем с хранилищем
troubleshoot_storage() {
    echo "=== Storage Troubleshooting ==="
    
    echo "1. PVC Status:"
    echo "============="
    kubectl get pvc --all-namespaces
    echo
    
    echo "2. PV Status:"
    echo "============"
    kubectl get pv
    echo
    
    echo "3. Storage Classes:"
    echo "=================="
    kubectl get storageclass
    echo
    
    echo "4. Pending PVCs:"
    echo "==============="
    kubectl get pvc --all-namespaces --field-selector=status.phase=Pending
    echo
    
    echo "5. Volume Mount Issues:"
    echo "======================"
    kubectl get events --all-namespaces | grep -i "mount\|volume" | tail -10
    echo
}

# Функция для диагностики узлов
troubleshoot_nodes() {
    echo "=== Node Troubleshooting ==="
    
    echo "1. Node Status:"
    echo "=============="
    kubectl get nodes -o wide
    echo
    
    echo "2. Node Conditions:"
    echo "=================="
    kubectl describe nodes | grep -A 5 "Conditions:"
    echo
    
    echo "3. Node Resource Usage:"
    echo "======================"
    kubectl top nodes
    echo
    
    echo "4. Node Events:"
    echo "=============="
    kubectl get events --all-namespaces --field-selector type=Warning | grep -i node | tail -10
    echo
    
    echo "5. Kubelet Status:"
    echo "================="
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
    echo
}

# Функция для создания диагностических скриптов
create_diagnostic_scripts() {
    echo "=== Creating Diagnostic Scripts ==="
    
    # Script for common Pod issues
    cat << POD_ISSUES_EOF > diagnose-pod-issues.sh
#!/bin/bash

echo "=== Pod Issues Diagnostic Script ==="

# Function to diagnose CrashLoopBackOff
diagnose_crashloop() {
    echo "Pods in CrashLoopBackOff state:"
    kubectl get pods --all-namespaces | grep CrashLoopBackOff | while read ns name ready status restarts age; do
        echo "Diagnosing: \$ns/\$name"
        kubectl describe pod -n "\$ns" "\$name" | grep -A 10 "Last State:"
        kubectl logs -n "\$ns" "\$name" --previous --tail=20 2>/dev/null
        echo "---"
    done
}

# Function to diagnose ImagePullBackOff
diagnose_imagepull() {
    echo "Pods with ImagePullBackOff:"
    kubectl get pods --all-namespaces | grep ImagePullBackOff | while read ns name ready status restarts age; do
        echo "Diagnosing: \$ns/\$name"
        kubectl describe pod -n "\$ns" "\$name" | grep -A 5 "Events:"
        echo "---"
    done
}

# Function to diagnose Pending pods
diagnose_pending() {
    echo "Pending pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending | while read ns name ready status restarts age; do
        if [ "\$ns" != "NAMESPACE" ]; then
            echo "Diagnosing: \$ns/\$name"
            kubectl describe pod -n "\$ns" "\$name" | grep -A 10 "Events:"
            echo "---"
        fi
    done
}

# Function to diagnose OOMKilled pods
diagnose_oom() {
    echo "Pods killed due to OOM:"
    kubectl get events --all-namespaces | grep "OOMKilling" | tail -10
}

case "\$1" in
    "crashloop")
        diagnose_crashloop
        ;;
    "imagepull")
        diagnose_imagepull
        ;;
    "pending")
        diagnose_pending
        ;;
    "oom")
        diagnose_oom
        ;;
    "all"|"")
        diagnose_crashloop
        diagnose_imagepull
        diagnose_pending
        diagnose_oom
        ;;
    *)
        echo "Usage: \$0 [crashloop|imagepull|pending|oom|all]"
        ;;
esac

POD_ISSUES_EOF
    
    chmod +x diagnose-pod-issues.sh
    
    # Script for network connectivity testing
    cat << NETWORK_TEST_EOF > test-network-connectivity.sh
#!/bin/bash

echo "=== Network Connectivity Test ==="

# Function to test service connectivity
test_service_connectivity() {
    local service=\$1
    local namespace=\$2
    local port=\$3
    
    echo "Testing connectivity to \$namespace/\$service:\$port"
    
    kubectl run network-test --image=busybox:1.28 --rm -it --restart=Never -- sh -c "
        echo 'Testing DNS resolution:'
        nslookup \$service.\$namespace.svc.cluster.local
        echo 'Testing connectivity:'
        nc -zv \$service.\$namespace.svc.cluster.local \$port
    "
}

# Function to test external connectivity
test_external_connectivity() {
    echo "Testing external connectivity:"
    kubectl run external-test --image=busybox:1.28 --rm -it --restart=Never -- sh -c "
        echo 'Testing DNS resolution:'
        nslookup google.com
        echo 'Testing HTTP connectivity:'
        wget -qO- http://httpbin.org/ip
    "
}

# Function to test inter-pod connectivity
test_inter_pod_connectivity() {
    echo "Testing inter-pod connectivity:"
    
    # Create test pods
    kubectl run test-client --image=busybox:1.28 -- sleep 3600
    kubectl run test-server --image=nginx:alpine
    
    sleep 10
    
    SERVER_IP=\$(kubectl get pod test-server -o jsonpath='{.status.podIP}')
    echo "Server IP: \$SERVER_IP"
    
    kubectl exec test-client -- wget -qO- "http://\$SERVER_IP"
    
    # Cleanup
    kubectl delete pod test-client test-server --force --grace-period=0
}

case "\$1" in
    "service")
        test_service_connectivity "\$2" "\$3" "\$4"
        ;;
    "external")
        test_external_connectivity
        ;;
    "inter-pod")
        test_inter_pod_connectivity
        ;;
    "all"|"")
        test_external_connectivity
        test_inter_pod_connectivity
        ;;
    *)
        echo "Usage: \$0 [service <name> <namespace> <port>|external|inter-pod|all]"
        ;;
esac

NETWORK_TEST_EOF
    
    chmod +x test-network-connectivity.sh
    
    # Script for resource analysis
    cat << RESOURCE_ANALYSIS_EOF > analyze-cluster-resources.sh
#!/bin/bash

echo "=== Cluster Resource Analysis ==="

# Function to analyze node resources
analyze_node_resources() {
    echo "Node Resource Analysis:"
    echo "======================"
    
    kubectl describe nodes | grep -A 5 "Allocated resources:"
    echo
    
    echo "Node capacity vs usage:"
    kubectl top nodes
    echo
}

# Function to analyze pod resources
analyze_pod_resources() {
    echo "Pod Resource Analysis:"
    echo "====================="
    
    echo "Top CPU consuming pods:"
    kubectl top pods --all-namespaces --sort-by=cpu | head -10
    echo
    
    echo "Top Memory consuming pods:"
    kubectl top pods --all-namespaces --sort-by=memory | head -10
    echo
    
    echo "Pods without resource limits:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits}{"\n"}{end}' | grep -v "map\|cpu\|memory"
    echo
}

# Function to analyze cluster events
analyze_cluster_events() {
    echo "Cluster Events Analysis:"
    echo "======================="
    
    echo "Recent warning events:"
    kubectl get events --all-namespaces --field-selector type=Warning --sort-by='.lastTimestamp' | tail -20
    echo
    
    echo "Event summary by reason:"
    kubectl get events --all-namespaces -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' | sort | uniq -c | sort -nr
    echo
}

case "\$1" in
    "nodes")
        analyze_node_resources
        ;;
    "pods")
        analyze_pod_resources
        ;;
    "events")
        analyze_cluster_events
        ;;
    "all"|"")
        analyze_node_resources
        analyze_pod_resources
        analyze_cluster_events
        ;;
    *)
        echo "Usage: \$0 [nodes|pods|events|all]"
        ;;
esac

RESOURCE_ANALYSIS_EOF
    
    chmod +x analyze-cluster-resources.sh
    
    echo "✅ Diagnostic scripts created:"
    echo "- diagnose-pod-issues.sh"
    echo "- test-network-connectivity.sh"
    echo "- analyze-cluster-resources.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "pods")
            troubleshoot_pods
            ;;
        "pod")
            diagnose_pod "$2" "$3"
            ;;
        "network")
            troubleshoot_network
            ;;
        "storage")
            troubleshoot_storage
            ;;
        "nodes")
            troubleshoot_nodes
            ;;
        "scripts")
            create_diagnostic_scripts
            ;;
        "all"|"")
            troubleshoot_pods
            troubleshoot_network
            troubleshoot_storage
            troubleshoot_nodes
            create_diagnostic_scripts
            ;;
        *)
            echo "Usage: $0 [pods|pod <ns> <name>|network|storage|nodes|scripts|all]"
            echo ""
            echo "Examples:"
            echo "  $0 pods                    # Troubleshoot all pod issues"
            echo "  $0 pod default my-pod     # Diagnose specific pod"
            echo "  $0 network                # Troubleshoot network issues"
            echo "  $0 scripts                # Create diagnostic scripts"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubernetes-troubleshooting-toolkit.sh
./kubernetes-troubleshooting-toolkit.sh scripts
```

## 🎯 **Практические команды для troubleshooting:**

### **Диагностика Pod проблем:**
```bash
# Запустить полную диагностику
./kubernetes-troubleshooting-toolkit.sh all

# Диагностика конкретного Pod
./kubernetes-troubleshooting-toolkit.sh pod default my-pod

# Анализ проблем с Pod
./diagnose-pod-issues.sh all
```

### **Быстрая диагностика:**
```bash
# Проверить проблемные Pod
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Посмотреть события
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Проверить ресурсы узлов
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### **Сетевая диагностика:**
```bash
# Тестировать сетевое подключение
./test-network-connectivity.sh all

# Проверить DNS
kubectl exec -it <pod> -- nslookup kubernetes.default.svc.cluster.local
```

**Систематический подход к troubleshooting значительно ускоряет решение проблем в Kubernetes!**
