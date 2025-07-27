# 105. Типы логов в Kubernetes

## 🎯 **Типы логов в Kubernetes**

**Kubernetes генерирует различные типы логов** на разных уровнях системы. Понимание этих типов критически важно для эффективного мониторинга, отладки и обеспечения безопасности кластера.

## 📊 **Категории логов в Kubernetes:**

### **1. Application Logs (Логи приложений):**
- **Container stdout/stderr** - стандартные потоки вывода
- **Application-specific logs** - специфичные логи приложений
- **Structured logs** - структурированные логи (JSON, etc.)

### **2. System Logs (Системные логи):**
- **kubelet logs** - логи агента узла
- **Container runtime logs** - логи среды выполнения контейнеров
- **Operating system logs** - логи операционной системы

### **3. Control Plane Logs (Логи плоскости управления):**
- **API Server logs** - логи API сервера
- **etcd logs** - логи базы данных кластера
- **Scheduler logs** - логи планировщика
- **Controller Manager logs** - логи менеджера контроллеров

## 📋 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive logs analysis toolkit
cat << 'EOF' > kubernetes-logs-analysis-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Logs Analysis Toolkit ==="
echo "Comprehensive logs analysis for HashFoundry HA cluster"
echo

# Функция для анализа Application Logs
analyze_application_logs() {
    echo "=== Application Logs Analysis ==="
    
    echo "1. Container Logs (stdout/stderr):"
    echo "================================="
    echo "Recent application logs from all namespaces:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Running | head -10 | while read ns name ready status restarts age; do
        if [ "$ns" != "NAMESPACE" ]; then
            echo "Pod: $ns/$name"
            kubectl logs -n "$ns" "$name" --tail=3 2>/dev/null | head -3
            echo "---"
        fi
    done
    echo
    
    echo "2. Application Log Locations:"
    echo "============================"
    echo "Container logs: /var/log/containers/*.log"
    echo "Pod logs: /var/log/pods/*/*/*.log"
    echo "Docker logs: /var/lib/docker/containers/*/*-json.log"
    echo
    
    echo "3. Log Formats Analysis:"
    echo "======================="
    echo "JSON format logs:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | head -5 | while read ns name; do
        LOG_FILE="/var/log/containers/${name}_${ns}_*.log"
        echo "Checking format for $ns/$name"
        kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | xargs -I {} kubectl debug node/{} -it --image=busybox -- sh -c "head -1 $LOG_FILE 2>/dev/null | jq . >/dev/null 2>&1 && echo 'JSON format' || echo 'Plain text format'" 2>/dev/null || echo "Cannot access logs"
        break
    done
    echo
}

# Функция для анализа System Logs
analyze_system_logs() {
    echo "=== System Logs Analysis ==="
    
    echo "1. kubelet Logs:"
    echo "==============="
    echo "kubelet service status on nodes:"
    kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | head -3 | while read node; do
        echo "Node: $node"
        kubectl debug node/$node -it --image=busybox -- sh -c "journalctl -u kubelet --no-pager -n 3" 2>/dev/null || echo "Cannot access kubelet logs"
        echo "---"
    done
    echo
    
    echo "2. Container Runtime Logs:"
    echo "========================="
    echo "Container runtime information:"
    kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}' | tr ' ' '\n' | sort | uniq
    echo
    
    echo "3. System Log Locations:"
    echo "======================="
    echo "kubelet logs: journalctl -u kubelet"
    echo "containerd logs: journalctl -u containerd"
    echo "docker logs: journalctl -u docker"
    echo "System logs: /var/log/syslog, /var/log/messages"
    echo "Kernel logs: /var/log/kern.log, dmesg"
    echo
}

# Функция для анализа Control Plane Logs
analyze_control_plane_logs() {
    echo "=== Control Plane Logs Analysis ==="
    
    echo "1. API Server Logs:"
    echo "=================="
    kubectl get pods -n kube-system -l component=kube-apiserver -o custom-columns="NAME:.metadata.name,STATUS:.status.phase" | head -3
    kubectl logs -n kube-system -l component=kube-apiserver --tail=3 2>/dev/null | head -5 || echo "API Server logs not accessible via kubectl"
    echo
    
    echo "2. etcd Logs:"
    echo "============"
    kubectl get pods -n kube-system -l component=etcd -o custom-columns="NAME:.metadata.name,STATUS:.status.phase" | head -3
    kubectl logs -n kube-system -l component=etcd --tail=3 2>/dev/null | head -5 || echo "etcd logs not accessible via kubectl"
    echo
    
    echo "3. Scheduler Logs:"
    echo "================="
    kubectl get pods -n kube-system -l component=kube-scheduler -o custom-columns="NAME:.metadata.name,STATUS:.status.phase" | head -3
    kubectl logs -n kube-system -l component=kube-scheduler --tail=3 2>/dev/null | head -5 || echo "Scheduler logs not accessible via kubectl"
    echo
    
    echo "4. Controller Manager Logs:"
    echo "=========================="
    kubectl get pods -n kube-system -l component=kube-controller-manager -o custom-columns="NAME:.metadata.name,STATUS:.status.phase" | head -3
    kubectl logs -n kube-system -l component=kube-controller-manager --tail=3 2>/dev/null | head -5 || echo "Controller Manager logs not accessible via kubectl"
    echo
}

# Функция для анализа Audit Logs
analyze_audit_logs() {
    echo "=== Audit Logs Analysis ==="
    
    echo "1. Audit Log Configuration:"
    echo "=========================="
    kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -A 5 -B 5 "audit" || echo "No audit configuration found in API server"
    echo
    
    echo "2. Audit Log Locations:"
    echo "======================"
    echo "Default audit log: /var/log/audit.log"
    echo "API server audit: /var/log/kube-apiserver-audit.log"
    echo "Custom audit logs: Check API server configuration"
    echo
    
    echo "3. Audit Events Types:"
    echo "====================="
    echo "• RequestReceived - Request received by API server"
    echo "• ResponseStarted - Response headers sent"
    echo "• ResponseComplete - Response body sent"
    echo "• Panic - Internal server error"
    echo
}

# Функция для анализа Event Logs
analyze_event_logs() {
    echo "=== Event Logs Analysis ==="
    
    echo "1. Recent Cluster Events:"
    echo "========================"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -10
    echo
    
    echo "2. Events by Type:"
    echo "================="
    echo "Warning events:"
    kubectl get events --all-namespaces --field-selector type=Warning | head -5
    echo
    echo "Normal events:"
    kubectl get events --all-namespaces --field-selector type=Normal | head -5
    echo
    
    echo "3. Events by Reason:"
    echo "==================="
    kubectl get events --all-namespaces -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' | sort | uniq -c | sort -nr | head -10
    echo
}

# Функция для создания log collection script
create_log_collection_script() {
    echo "=== Creating Log Collection Script ==="
    
    cat << LOG_COLLECTION_EOF > collect-kubernetes-logs.sh
#!/bin/bash

echo "=== Kubernetes Logs Collection ==="
echo "Collecting various types of logs from HashFoundry HA cluster"
echo

TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
LOG_DIR="kubernetes-logs-\$TIMESTAMP"
mkdir -p "\$LOG_DIR"

# Function to collect application logs
collect_application_logs() {
    echo "Collecting application logs..."
    mkdir -p "\$LOG_DIR/application-logs"
    
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | while read ns name; do
        if [ -n "\$ns" ] && [ -n "\$name" ]; then
            kubectl logs -n "\$ns" "\$name" --all-containers=true > "\$LOG_DIR/application-logs/\${ns}_\${name}.log" 2>/dev/null
        fi
    done
}

# Function to collect system logs
collect_system_logs() {
    echo "Collecting system logs..."
    mkdir -p "\$LOG_DIR/system-logs"
    
    kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read node; do
        echo "Collecting logs from node: \$node"
        kubectl debug node/\$node -it --image=busybox -- sh -c "journalctl -u kubelet --no-pager" > "\$LOG_DIR/system-logs/kubelet_\$node.log" 2>/dev/null &
        kubectl debug node/\$node -it --image=busybox -- sh -c "journalctl -u containerd --no-pager" > "\$LOG_DIR/system-logs/containerd_\$node.log" 2>/dev/null &
    done
    wait
}

# Function to collect control plane logs
collect_control_plane_logs() {
    echo "Collecting control plane logs..."
    mkdir -p "\$LOG_DIR/control-plane-logs"
    
    # API Server logs
    kubectl logs -n kube-system -l component=kube-apiserver --all-containers=true > "\$LOG_DIR/control-plane-logs/kube-apiserver.log" 2>/dev/null
    
    # etcd logs
    kubectl logs -n kube-system -l component=etcd --all-containers=true > "\$LOG_DIR/control-plane-logs/etcd.log" 2>/dev/null
    
    # Scheduler logs
    kubectl logs -n kube-system -l component=kube-scheduler --all-containers=true > "\$LOG_DIR/control-plane-logs/kube-scheduler.log" 2>/dev/null
    
    # Controller Manager logs
    kubectl logs -n kube-system -l component=kube-controller-manager --all-containers=true > "\$LOG_DIR/control-plane-logs/kube-controller-manager.log" 2>/dev/null
}

# Function to collect events
collect_events() {
    echo "Collecting events..."
    mkdir -p "\$LOG_DIR/events"
    
    kubectl get events --all-namespaces -o yaml > "\$LOG_DIR/events/all-events.yaml"
    kubectl get events --all-namespaces --field-selector type=Warning -o yaml > "\$LOG_DIR/events/warning-events.yaml"
}

# Function to generate summary
generate_summary() {
    echo "Generating summary..."
    
    cat << SUMMARY_EOF > "\$LOG_DIR/collection-summary.txt"
Kubernetes Logs Collection Summary
=================================
Collection Time: \$(date)
Cluster: hashfoundry-ha

Directory Structure:
- application-logs/: Container and pod logs
- system-logs/: kubelet, containerd, system logs
- control-plane-logs/: API server, etcd, scheduler, controller manager
- events/: Kubernetes events

Statistics:
- Application log files: \$(find "\$LOG_DIR/application-logs" -name "*.log" | wc -l)
- System log files: \$(find "\$LOG_DIR/system-logs" -name "*.log" | wc -l)
- Control plane log files: \$(find "\$LOG_DIR/control-plane-logs" -name "*.log" | wc -l)
- Total size: \$(du -sh "\$LOG_DIR" | cut -f1)

SUMMARY_EOF
}

# Main collection function
main() {
    echo "Starting log collection..."
    
    collect_application_logs
    collect_system_logs
    collect_control_plane_logs
    collect_events
    generate_summary
    
    echo "✅ Log collection completed: \$LOG_DIR"
    echo "Summary:"
    cat "\$LOG_DIR/collection-summary.txt"
}

main

LOG_COLLECTION_EOF
    
    chmod +x collect-kubernetes-logs.sh
    echo "✅ Log collection script created: collect-kubernetes-logs.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "app")
            analyze_application_logs
            ;;
        "system")
            analyze_system_logs
            ;;
        "control-plane")
            analyze_control_plane_logs
            ;;
        "audit")
            analyze_audit_logs
            ;;
        "events")
            analyze_event_logs
            ;;
        "collect")
            create_log_collection_script
            ./collect-kubernetes-logs.sh
            ;;
        "all"|"")
            analyze_application_logs
            analyze_system_logs
            analyze_control_plane_logs
            analyze_audit_logs
            analyze_event_logs
            create_log_collection_script
            ;;
        *)
            echo "Usage: $0 [action]"
            echo "Actions: app, system, control-plane, audit, events, collect, all"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubernetes-logs-analysis-toolkit.sh
./kubernetes-logs-analysis-toolkit.sh all
```

## 📋 **Типы логов по категориям:**

| **Категория** | **Тип лога** | **Расположение** | **Команда kubectl** |
|---------------|--------------|------------------|---------------------|
| **Application** | Container stdout/stderr | `/var/log/containers/` | `kubectl logs <pod>` |
| **Application** | Pod logs | `/var/log/pods/` | `kubectl logs <pod> -c <container>` |
| **System** | kubelet | `journalctl -u kubelet` | `kubectl get nodes` |
| **System** | Container runtime | `journalctl -u containerd` | N/A |
| **Control Plane** | API Server | `/var/log/kube-apiserver.log` | `kubectl logs -n kube-system -l component=kube-apiserver` |
| **Control Plane** | etcd | `/var/log/etcd.log` | `kubectl logs -n kube-system -l component=etcd` |
| **Events** | Cluster events | Kubernetes API | `kubectl get events` |
| **Audit** | API audit | `/var/log/audit.log` | N/A |

## 🎯 **Практические команды:**

### **Анализ логов:**
```bash
# Запустить полный анализ
./kubernetes-logs-analysis-toolkit.sh all

# Собрать все логи
./collect-kubernetes-logs.sh

# Анализ по типам
./kubernetes-logs-analysis-toolkit.sh app
./kubernetes-logs-analysis-toolkit.sh system
```

### **Просмотр логов:**
```bash
# Логи приложений
kubectl logs <pod-name> -n <namespace>
kubectl logs -f <pod-name> --all-containers

# События кластера
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning

# Логи системных компонентов
kubectl logs -n kube-system -l component=kube-apiserver
```

**Понимание различных типов логов критически важно для эффективного мониторинга и отладки Kubernetes!**
