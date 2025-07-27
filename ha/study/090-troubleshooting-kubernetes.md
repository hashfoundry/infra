# 90. Troubleshooting Kubernetes

## 🎯 **Troubleshooting Kubernetes**

**Kubernetes Troubleshooting** - это систематический подход к диагностике, анализу и решению проблем в Kubernetes кластере, включающий методологии поиска неисправностей, инструменты диагностики и best practices для быстрого восстановления работоспособности системы.

## 🏗️ **Категории проблем:**

### **1. Cluster-level Issues:**
- **API server problems** - проблемы API сервера
- **etcd issues** - проблемы с etcd
- **Network connectivity** - сетевые проблемы
- **Node failures** - сбои узлов

### **2. Application-level Issues:**
- **Pod failures** - сбои подов
- **Service discovery** - проблемы обнаружения сервисов
- **Resource constraints** - ограничения ресурсов
- **Configuration errors** - ошибки конфигурации

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих проблем:**
```bash
# Проверить общее состояние кластера
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
```

### **2. Создание comprehensive troubleshooting toolkit:**
```bash
# Создать скрипт для troubleshooting
cat << 'EOF' > kubernetes-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Troubleshooting Toolkit ==="
echo "Comprehensive troubleshooting tools for HashFoundry HA cluster"
echo

# Функция для быстрой диагностики кластера
quick_cluster_diagnosis() {
    echo "=== Quick Cluster Diagnosis ==="
    
    echo "1. Cluster API Status:"
    echo "====================="
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ API Server: Accessible"
        kubectl cluster-info
    else
        echo "❌ API Server: Not accessible"
        echo "🔧 Troubleshooting steps:"
        echo "   - Check kube-apiserver pods: kubectl get pods -n kube-system -l component=kube-apiserver"
        echo "   - Check API server logs: kubectl logs -n kube-system -l component=kube-apiserver"
        echo "   - Verify certificates and network connectivity"
        return 1
    fi
    echo
    
    echo "2. Node Status:"
    echo "=============="
    kubectl get nodes -o wide
    
    # Check for NotReady nodes
    NOT_READY_NODES=$(kubectl get nodes --no-headers | grep -v " Ready " | awk '{print $1}')
    if [ -n "$NOT_READY_NODES" ]; then
        echo "⚠️  Found NotReady nodes:"
        for node in $NOT_READY_NODES; do
            echo "   - $node"
            echo "🔧 Troubleshooting: kubectl describe node $node"
        done
    else
        echo "✅ All nodes are Ready"
    fi
    echo
    
    echo "3. System Pods Status:"
    echo "====================="
    kubectl get pods -n kube-system -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"
    
    # Check for failed system pods
    FAILED_SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | awk '{print $1}')
    if [ -n "$FAILED_SYSTEM_PODS" ]; then
        echo "⚠️  Found failed system pods:"
        for pod in $FAILED_SYSTEM_PODS; do
            echo "   - $pod"
            echo "🔧 Troubleshooting: kubectl describe pod $pod -n kube-system"
        done
    else
        echo "✅ All system pods are healthy"
    fi
    echo
}

# Функция для диагностики pod проблем
diagnose_pod_issues() {
    echo "=== Pod Issues Diagnosis ==="
    
    local namespace=${1:-""}
    local pod_name=${2:-""}
    
    if [ -n "$namespace" ] && [ -n "$pod_name" ]; then
        echo "Diagnosing specific pod: $pod_name in namespace: $namespace"
        echo "=========================================================="
        
        # Pod status
        echo "1. Pod Status:"
        kubectl get pod "$pod_name" -n "$namespace" -o wide
        echo
        
        # Pod description
        echo "2. Pod Events and Conditions:"
        kubectl describe pod "$pod_name" -n "$namespace" | tail -20
        echo
        
        # Pod logs
        echo "3. Pod Logs (last 50 lines):"
        kubectl logs "$pod_name" -n "$namespace" --tail=50 2>/dev/null || echo "No logs available"
        echo
        
        # Previous logs if pod restarted
        echo "4. Previous Pod Logs (if restarted):"
        kubectl logs "$pod_name" -n "$namespace" --previous --tail=20 2>/dev/null || echo "No previous logs available"
        echo
        
    else
        echo "Scanning all namespaces for problematic pods..."
        echo "=============================================="
        
        # Find all non-running pods
        echo "1. Non-Running Pods:"
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,REASON:.status.reason,MESSAGE:.status.message"
        echo
        
        # Find pods with high restart count
        echo "2. Pods with High Restart Count (>5):"
        kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.containerStatuses[]?.restartCount > 5) | "\(.metadata.namespace)/\(.metadata.name): \(.status.containerStatuses[0].restartCount) restarts"'
        echo
        
        # Find pending pods
        echo "3. Pending Pods:"
        kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REASON:.status.conditions[?(@.type=='PodScheduled')].reason,MESSAGE:.status.conditions[?(@.type=='PodScheduled')].message"
        echo
    fi
}

# Функция для диагностики сетевых проблем
diagnose_network_issues() {
    echo "=== Network Issues Diagnosis ==="
    
    echo "1. Service Status:"
    echo "=================="
    kubectl get services --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORTS:.spec.ports[*].port"
    echo
    
    echo "2. Endpoints Status:"
    echo "==================="
    kubectl get endpoints --all-namespaces | head -20
    echo
    
    echo "3. Network Policies:"
    echo "==================="
    kubectl get networkpolicies --all-namespaces
    echo
    
    echo "4. Ingress Status:"
    echo "=================="
    kubectl get ingress --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[0].ip"
    echo
    
    echo "5. DNS Resolution Test:"
    echo "======================="
    # Create a test pod for DNS resolution
    cat << DNS_TEST_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-pod
  namespace: default
  labels:
    app: dns-test
spec:
  containers:
  - name: dns-test
    image: busybox:1.35
    command: ['sleep', '3600']
  restartPolicy: Never
DNS_TEST_EOF
    
    # Wait for pod to be ready
    kubectl wait --for=condition=Ready pod/dns-test-pod --timeout=60s 2>/dev/null
    
    if kubectl get pod dns-test-pod >/dev/null 2>&1; then
        echo "Testing DNS resolution..."
        kubectl exec dns-test-pod -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "DNS resolution failed"
        kubectl exec dns-test-pod -- nslookup google.com 2>/dev/null || echo "External DNS resolution failed"
        
        # Cleanup
        kubectl delete pod dns-test-pod --grace-period=0 --force 2>/dev/null
    else
        echo "Could not create DNS test pod"
    fi
    echo
}

# Функция для диагностики ресурсов
diagnose_resource_issues() {
    echo "=== Resource Issues Diagnosis ==="
    
    echo "1. Node Resource Usage:"
    echo "======================"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "2. Pod Resource Usage (Top 20):"
    echo "==============================="
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -20 || echo "Metrics server not available"
    echo
    
    echo "3. Resource Quotas:"
    echo "=================="
    kubectl get resourcequota --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-REQ:.status.used.requests\.cpu,CPU-LIM:.status.used.limits\.cpu,MEM-REQ:.status.used.requests\.memory,MEM-LIM:.status.used.limits\.memory"
    echo
    
    echo "4. Persistent Volume Claims:"
    echo "============================"
    kubectl get pvc --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "5. Events (Last 20):"
    echo "===================="
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
    echo
}

# Функция для диагностики storage проблем
diagnose_storage_issues() {
    echo "=== Storage Issues Diagnosis ==="
    
    echo "1. Persistent Volumes:"
    echo "====================="
    kubectl get pv -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name,CAPACITY:.spec.capacity.storage,STORAGECLASS:.spec.storageClassName,REASON:.status.reason"
    echo
    
    echo "2. Storage Classes:"
    echo "=================="
    kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM-POLICY:.reclaimPolicy,VOLUME-BINDING:.volumeBindingMode"
    echo
    
    echo "3. Failed PVCs:"
    echo "=============="
    kubectl get pvc --all-namespaces --field-selector=status.phase!=Bound -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "4. Volume Snapshots:"
    echo "==================="
    kubectl get volumesnapshots --all-namespaces 2>/dev/null || echo "Volume snapshots not available"
    echo
}

# Функция для создания troubleshooting report
generate_troubleshooting_report() {
    echo "=== Troubleshooting Report ==="
    
    local report_file="troubleshooting-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster Troubleshooting Report"
        echo "=============================================="
        echo "Generated: $(date)"
        echo "Cluster: $(kubectl config current-context)"
        echo ""
        
        echo "=== CLUSTER OVERVIEW ==="
        kubectl get nodes -o wide
        echo ""
        
        echo "=== SYSTEM PODS ==="
        kubectl get pods -n kube-system
        echo ""
        
        echo "=== FAILED PODS ==="
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
        echo ""
        
        echo "=== RECENT EVENTS ==="
        kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50
        echo ""
        
        echo "=== RESOURCE USAGE ==="
        kubectl top nodes 2>/dev/null || echo "Metrics server not available"
        echo ""
        
        echo "=== STORAGE STATUS ==="
        kubectl get pv,pvc --all-namespaces
        echo ""
        
        echo "=== NETWORK STATUS ==="
        kubectl get services,endpoints --all-namespaces | head -30
        echo ""
        
    } > "$report_file"
    
    echo "✅ Troubleshooting report generated: $report_file"
    echo
}

# Функция для создания emergency diagnostic script
create_emergency_diagnostics() {
    echo "=== Creating Emergency Diagnostics ==="
    
    cat << EMERGENCY_DIAG_EOF > emergency-diagnostics.sh
#!/bin/bash

echo "=== EMERGENCY KUBERNETES DIAGNOSTICS ==="
echo "Running emergency diagnostics for HashFoundry HA cluster"
echo "Time: \$(date)"
echo

# Function to collect critical information
collect_critical_info() {
    echo "1. CLUSTER STATUS:"
    echo "=================="
    kubectl cluster-info 2>&1
    echo
    
    echo "2. NODE STATUS:"
    echo "=============="
    kubectl get nodes -o wide 2>&1
    echo
    
    echo "3. CRITICAL PODS:"
    echo "================"
    kubectl get pods -n kube-system 2>&1
    echo
    
    echo "4. FAILED PODS:"
    echo "=============="
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded 2>&1
    echo
    
    echo "5. RECENT EVENTS:"
    echo "================"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' 2>&1 | tail -30
    echo
    
    echo "6. RESOURCE USAGE:"
    echo "=================="
    kubectl top nodes 2>&1 || echo "Metrics server not available"
    echo
}

# Function to check specific components
check_components() {
    echo "7. COMPONENT HEALTH:"
    echo "==================="
    
    # Check API server
    if kubectl get --raw='/healthz' >/dev/null 2>&1; then
        echo "✅ API Server: Healthy"
    else
        echo "❌ API Server: Unhealthy"
    fi
    
    # Check etcd
    ETCD_PODS=\$(kubectl get pods -n kube-system -l component=etcd --no-headers | wc -l)
    ETCD_READY=\$(kubectl get pods -n kube-system -l component=etcd --no-headers | grep Running | wc -l)
    echo "📊 etcd: \$ETCD_READY/\$ETCD_PODS pods ready"
    
    # Check scheduler
    SCHEDULER_PODS=\$(kubectl get pods -n kube-system -l component=kube-scheduler --no-headers | wc -l)
    SCHEDULER_READY=\$(kubectl get pods -n kube-system -l component=kube-scheduler --no-headers | grep Running | wc -l)
    echo "📊 Scheduler: \$SCHEDULER_READY/\$SCHEDULER_PODS pods ready"
    
    # Check controller manager
    CM_PODS=\$(kubectl get pods -n kube-system -l component=kube-controller-manager --no-headers | wc -l)
    CM_READY=\$(kubectl get pods -n kube-system -l component=kube-controller-manager --no-headers | grep Running | wc -l)
    echo "📊 Controller Manager: \$CM_READY/\$CM_PODS pods ready"
    echo
}

# Function to provide immediate actions
suggest_immediate_actions() {
    echo "8. IMMEDIATE ACTIONS:"
    echo "===================="
    
    # Check for common issues
    NOT_READY_NODES=\$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "\$NOT_READY_NODES" -gt 0 ]; then
        echo "🚨 ACTION REQUIRED: \$NOT_READY_NODES nodes are not ready"
        echo "   Run: kubectl describe nodes | grep -A 10 'Conditions:'"
    fi
    
    FAILED_PODS=\$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l)
    if [ "\$FAILED_PODS" -gt 0 ]; then
        echo "🚨 ACTION REQUIRED: \$FAILED_PODS pods are not running"
        echo "   Run: kubectl get pods --all-namespaces --field-selector=status.phase!=Running"
    fi
    
    # Check disk space on nodes
    echo "💾 Check disk space on nodes:"
    echo "   Run: kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, conditions: .status.conditions[] | select(.type==\"DiskPressure\")}"
    
    # Check resource pressure
    echo "🔧 Check resource pressure:"
    echo "   Run: kubectl describe nodes | grep -A 5 'Allocated resources:'"
    echo
}

# Main execution
main() {
    collect_critical_info
    check_components
    suggest_immediate_actions
    
    echo "=== EMERGENCY DIAGNOSTICS COMPLETE ==="
    echo "For detailed troubleshooting, run: ./kubernetes-troubleshooting-toolkit.sh"
    echo
}

# Run main function
main

EMERGENCY_DIAG_EOF
    
    chmod +x emergency-diagnostics.sh
    
    echo "✅ Emergency diagnostics script created: emergency-diagnostics.sh"
    echo
}

# Функция для создания common fixes
create_common_fixes() {
    echo "=== Creating Common Fixes ==="
    
    cat << COMMON_FIXES_EOF > common-kubernetes-fixes.sh
#!/bin/bash

echo "=== Common Kubernetes Fixes ==="
echo "Collection of common fixes for HashFoundry HA cluster"
echo

# Function to fix ImagePullBackOff
fix_image_pull_backoff() {
    echo "=== Fix ImagePullBackOff ==="
    
    local namespace=\${1:-"default"}
    local pod_name=\${2:-""}
    
    if [ -z "\$pod_name" ]; then
        echo "Finding pods with ImagePullBackOff..."
        kubectl get pods -n "\$namespace" --field-selector=status.phase=Pending -o json | jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "ImagePullBackOff") | .metadata.name'
    else
        echo "Fixing ImagePullBackOff for pod: \$pod_name"
        
        # Check image name
        IMAGE=\$(kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.containers[0].image}')
        echo "Image: \$IMAGE"
        
        # Check image pull secrets
        echo "Image pull secrets:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.imagePullSecrets[*].name}'
        echo
        
        # Suggest fixes
        echo "🔧 Possible fixes:"
        echo "1. Check image name and tag: kubectl describe pod \$pod_name -n \$namespace"
        echo "2. Verify image exists: docker pull \$IMAGE"
        echo "3. Check image pull secrets: kubectl get secrets -n \$namespace"
        echo "4. Update image pull policy: kubectl patch deployment <deployment-name> -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"<container-name>\",\"imagePullPolicy\":\"Always\"}]}}}}'"
    fi
    echo
}

# Function to fix CrashLoopBackOff
fix_crash_loop_backoff() {
    echo "=== Fix CrashLoopBackOff ==="
    
    local namespace=\${1:-"default"}
    local pod_name=\${2:-""}
    
    if [ -z "\$pod_name" ]; then
        echo "Finding pods with CrashLoopBackOff..."
        kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "CrashLoopBackOff") | "\(.metadata.namespace)/\(.metadata.name)"'
    else
        echo "Fixing CrashLoopBackOff for pod: \$pod_name"
        
        # Get logs
        echo "Recent logs:"
        kubectl logs "\$pod_name" -n "\$namespace" --tail=20
        echo
        
        echo "Previous logs:"
        kubectl logs "\$pod_name" -n "\$namespace" --previous --tail=20 2>/dev/null || echo "No previous logs"
        echo
        
        # Check resource limits
        echo "Resource limits:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.containers[0].resources}'
        echo
        
        # Suggest fixes
        echo "🔧 Possible fixes:"
        echo "1. Check application logs: kubectl logs \$pod_name -n \$namespace"
        echo "2. Check resource limits: kubectl describe pod \$pod_name -n \$namespace"
        echo "3. Check liveness/readiness probes"
        echo "4. Verify application configuration"
        echo "5. Check dependencies (databases, external services)"
    fi
    echo
}

# Function to fix Pending pods
fix_pending_pods() {
    echo "=== Fix Pending Pods ==="
    
    local namespace=\${1:-""}
    
    if [ -n "\$namespace" ]; then
        PENDING_PODS=\$(kubectl get pods -n "\$namespace" --field-selector=status.phase=Pending --no-headers | awk '{print \$1}')
    else
        PENDING_PODS=\$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers | awk '{print \$2}')
    fi
    
    if [ -z "\$PENDING_PODS" ]; then
        echo "✅ No pending pods found"
        return
    fi
    
    echo "Found pending pods:"
    for pod in \$PENDING_PODS; do
        echo "- \$pod"
        
        # Check scheduling issues
        REASON=\$(kubectl describe pod "\$pod" -n "\$namespace" | grep -A 5 "Events:" | grep "FailedScheduling" | tail -1)
        if [ -n "\$REASON" ]; then
            echo "  Reason: \$REASON"
        fi
    done
    echo
    
    echo "🔧 Common fixes for pending pods:"
    echo "1. Check node resources: kubectl describe nodes"
    echo "2. Check node selectors: kubectl get pods <pod-name> -o yaml | grep nodeSelector"
    echo "3. Check taints and tolerations: kubectl describe nodes | grep Taints"
    echo "4. Check PVC status: kubectl get pvc"
    echo "5. Check resource quotas: kubectl get resourcequota"
    echo
}

# Function to restart deployment
restart_deployment() {
    echo "=== Restart Deployment ==="
    
    local namespace=\${1:-"default"}
    local deployment=\${2:-""}
    
    if [ -z "\$deployment" ]; then
        echo "Available deployments in namespace \$namespace:"
        kubectl get deployments -n "\$namespace"
        echo
        echo "Usage: restart_deployment <namespace> <deployment-name>"
        return
    fi
    
    echo "Restarting deployment: \$deployment in namespace: \$namespace"
    kubectl rollout restart deployment "\$deployment" -n "\$namespace"
    
    echo "Waiting for rollout to complete..."
    kubectl rollout status deployment "\$deployment" -n "\$namespace" --timeout=300s
    
    echo "✅ Deployment restarted successfully"
    echo
}

# Function to fix DNS issues
fix_dns_issues() {
    echo "=== Fix DNS Issues ==="
    
    # Check CoreDNS pods
    echo "CoreDNS pods status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    echo
    
    # Check CoreDNS configuration
    echo "CoreDNS configuration:"
    kubectl get configmap coredns -n kube-system -o yaml | grep -A 20 "Corefile:"
    echo
    
    # Test DNS resolution
    echo "Testing DNS resolution..."
    kubectl run dns-test --image=busybox:1.35 --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "DNS test failed"
    echo
    
    echo "🔧 DNS troubleshooting steps:"
    echo "1. Restart CoreDNS: kubectl rollout restart deployment coredns -n kube-system"
    echo "2. Check CoreDNS logs: kubectl logs -n kube-system -l k8s-app=kube-dns"
    echo "3. Verify DNS service: kubectl get svc kube-dns -n kube-system"
    echo "4. Check kubelet DNS settings on nodes"
    echo
}

# Main menu
main() {
    case "\$1" in
        "image-pull")
            fix_image_pull_backoff "\$2" "\$3"
            ;;
        "crash-loop")
            fix_crash_loop_backoff "\$2" "\$3"
            ;;
        "pending")
            fix_pending_pods "\$2"
            ;;
        "restart")
            restart_deployment "\$2" "\$3"
            ;;
        "dns")
            fix_dns_issues
            ;;
        *)
            echo "Usage: \$0 [fix-type] [options]"
            echo ""
            echo "Available fixes:"
            echo "  image-pull [namespace] [pod-name]  - Fix ImagePullBackOff issues"
            echo "  crash-loop [namespace] [pod-name]  - Fix CrashLoopBackOff issues"
            echo "  pending [namespace]                - Fix pending pods"
            echo "  restart [namespace] [deployment]   - Restart deployment"
            echo "  dns                                - Fix DNS issues"
            echo ""
            echo "Examples:"
            echo "  \$0 image-pull default my-pod"
            echo "  \$0 crash-loop production api-server"
            echo "  \$0 pending"
            echo "  \$0 restart default my-app"
            echo "  \$0 dns"
            ;;
    esac
}

# Run main function
main "\$@"

COMMON_FIXES_EOF
    
    chmod +x common-kubernetes-fixes.sh
    
    echo "✅ Common fixes script created: common-kubernetes-fixes.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "quick")
            quick_cluster_diagnosis
            ;;
        "pods")
            diagnose_pod_issues "$2" "$3"
            ;;
        "network")
            diagnose_network_issues
            ;;
        "resources")
            diagnose_resource_issues
            ;;
        "storage")
            diagnose_storage_issues
            ;;
        "report")
            generate_troubleshooting_report
            ;;
        "emergency")
            create_emergency_diagnostics
            ;;
        "fixes")
            create_common_fixes
            ;;
        "all"|"")
            quick_cluster_diagnosis
            diagnose_pod_issues
            diagnose_network_issues
            diagnose_resource_issues
            diagnose_storage_issues
            generate_troubleshooting_report
            create_emergency_diagnostics
            create_common_fixes
            ;;
        *)
            echo "Usage: $0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  quick                    - Quick cluster diagnosis"
            echo "  pods [namespace] [pod]   - Diagnose pod issues"
            echo "  network                  - Diagnose network issues"
            echo "  resources                - Diagnose resource issues"
            echo "  storage                  - Diagnose storage issues"
            echo "  report                   - Generate troubleshooting report"
            echo "  emergency                - Create emergency diagnostics"
            echo "  fixes                    - Create common fixes toolkit"
            echo "  all                      - Run all diagnostics (default)"
            echo ""
            echo "Examples:"
            echo "  $0 quick"
            echo "  $0 pods default my-pod"
            echo "  $0 network"
            echo "  $0 report"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-troubleshooting-toolkit.sh

# Запустить создание troubleshooting toolkit
./kubernetes-troubleshooting-toolkit.sh all
```

## 📋 **Troubleshooting Methodology:**

### **Systematic Approach:**

| **Этап** | **Действие** | **Команды** | **Цель** |
|----------|--------------|-------------|----------|
| **1. Assess** | Оценка ситуации | `kubectl get nodes`, `kubectl get pods --all-namespaces` | Общее понимание |
| **2. Isolate** | Изоляция проблемы | `kubectl describe`, `kubectl logs` | Локализация |
| **3. Analyze** | Анализ причин | `kubectl get events`, `kubectl top` | Понимание причин |
| **4. Fix** | Исправление | `kubectl apply`, `kubectl restart` | Решение проблемы |
| **5. Verify** | Проверка | `kubectl get`, `kubectl test` | Подтверждение |

## 🎯 **Практические команды:**

### **Быстрая диагностика:**
```bash
# Запустить troubleshooting toolkit
./kubernetes-troubleshooting-toolkit.sh quick

# Диагностика конкретного pod
./kubernetes-troubleshooting-toolkit.sh pods default my-pod

# Экстренная диагностика
./emergency-diagnostics.sh
```

### **Общие проблемы и решения:**
```bash
# Исправить ImagePullBackOff
./common-kubernetes-fixes.sh image-pull default my-pod

# Исправить CrashLoopBackOff
./common-kubernetes-fixes.sh crash-loop production api-server

# Перезапустить deployment
./common-kubernetes-fixes.sh restart default my-app
```

### **Диагностические команды:**
```bash
# Проверить состояние кластера
kubectl cluster-info
kubectl get componentstatuses

# Проверить узлы
kubectl get nodes -o wide
kubectl describe node <node-name>

# Проверить поды
kubectl get pods --all-namespaces
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### **Анализ событий:**
```bash
# Проверить события кластера
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# События конкретного namespace
kubectl get events -n <namespace>

# События конкретного объекта
kubectl describe <resource-type> <resource-name> -n <namespace>
```

## 🔧 **Общие проблемы и решения:**

### **Pod Issues:**

| **Проблема** | **Симптомы** | **Диагностика** | **Решение** |
|--------------|--------------|-----------------|-------------|
| **ImagePullBackOff** | Pod не запускается | `kubectl describe pod` | Проверить image name, registry access |
| **CrashLoopBackOff** | Pod постоянно перезапускается | `kubectl logs --previous` | Проверить application logs, resource limits |
| **Pending** | Pod не планируется | `kubectl describe pod` | Проверить node resources, taints |
| **OOMKilled** | Pod убит из-за памяти | `kubectl describe pod` | Увеличить memory limits |

### **Network Issues:**

| **Проблема** | **Симптомы** | **Диагностика** | **Решение** |
|--------------|--------------|-----------------|-------------|
| **Service не доступен** | Нет подключения к сервису | `kubectl get endpoints` | Проверить selector, pod labels |
| **DNS не работает** | Не резолвятся имена | `nslookup` в pod | Проверить CoreDNS |
| **Ingress не работает** | Внешний доступ недоступен | `kubectl describe ingress` | Проверить ingress controller |
| **Network Policy** | Блокируется трафик | `kubectl get networkpolicies` | Проверить правила |

### **Storage Issues:**

| **Проблема** | **Симптомы** | **Диагностика** | **Решение** |
|--------------|--------------|-----------------|-------------|
| **PVC Pending** | Volume не создается | `kubectl describe pvc` | Проверить StorageClass |
| **Mount failed** | Pod не может примонтировать | `kubectl describe pod` | Проверить permissions, node |
| **Out of space** | Нет места на диске | `df -h` на node | Очистить или увеличить |
| **Performance** | Медленный I/O | `iostat` на node | Проверить storage backend |

## 🚨 **Emergency Response:**

### **Critical Issues Response:**
```bash
# API Server недоступен
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# etcd проблемы
kubectl get pods -n kube-system -l component=etcd
kubectl logs -n kube-system -l component=etcd

# Node NotReady
kubectl describe node <node-name>
ssh <node> "sudo systemctl status kubelet"
```

### **Quick Recovery Actions:**
```bash
# Перезапустить проблемный deployment
kubectl rollout restart deployment <deployment-name> -n <namespace>

# Масштабировать deployment
kubectl scale deployment <deployment-name> --replicas=3 -n <namespace>

# Удалить проблемный pod
kubectl delete pod <pod-name> -n <namespace>

# Очистить failed pods
kubectl delete pods --field-selector=status.phase=Failed --all-namespaces
```

## 📊 **Monitoring и Alerting:**

### **Ключевые метрики для мониторинга:**
- **Node health** - состояние узлов
- **Pod status** - статус подов
- **Resource usage** - использование ресурсов
- **API server latency** - задержка API сервера
- **etcd health** - состояние etcd

### **Настройка алертов:**
```bash
# Проверить Prometheus alerts
kubectl get prometheusrules -n monitoring

# Проверить Alertmanager
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# Тестировать алерты
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

## 🔍 **Advanced Troubleshooting:**

### **Performance Issues:**
```bash
# CPU и Memory usage
kubectl top nodes
kubectl top pods --all-namespaces

# Network latency
kubectl exec -it <pod-name> -- ping <target>

# Disk I/O
kubectl exec -it <pod-name> -- iostat -x 1
```

### **Security Issues:**
```bash
# RBAC проблемы
kubectl auth can-i <verb> <resource> --as=<user>

# Pod Security Standards
kubectl get pods -o json | jq '.items[] | select(.spec.securityContext == null)'

# Network Policies
kubectl get networkpolicies --all-namespaces
```

## 📝 **Best Practices для Troubleshooting:**

### **Подготовка:**
- **Документация** - ведите документацию по архитектуре
- **Monitoring** - настройте comprehensive мониторинг
- **Logging** - централизованное логирование
- **Backup** - регулярные резервные копии

### **Процесс:**
- **Systematic approach** - систематический подход
- **Documentation** - документируйте проблемы и решения
- **Root cause analysis** - анализ первопричин
- **Prevention** - меры предотвращения

### **Инструменты:**
- **kubectl** - основной инструмент диагностики
- **Prometheus/Grafana** - мониторинг и визуализация
- **Jaeger/Zipkin** - трейсинг
- **ELK/EFK Stack** - логирование

### **Команды для экстренных ситуаций:**
```bash
# Быстрая диагностика
./kubernetes-troubleshooting-toolkit.sh quick

# Полный отчет
./kubernetes-troubleshooting-toolkit.sh report

# Экстренная диагностика
./emergency-diagnostics.sh

# Исправление общих проблем
./common-kubernetes-fixes.sh <problem-type>
```

**Эффективное troubleshooting - ключ к поддержанию стабильности Kubernetes кластера!**
