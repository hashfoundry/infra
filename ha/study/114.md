# 114. Инструменты для отладки Kubernetes

## 🎯 **Инструменты для отладки Kubernetes**

**Debugging tools** в Kubernetes экосистеме помогают быстро диагностировать и решать проблемы. Знание правильных инструментов и их применения критически важно для эффективного troubleshooting.

## 🛠️ **Категории инструментов отладки:**

### **1. Native Kubernetes Tools:**
- **kubectl** - основной CLI инструмент
- **kubectl debug** - отладка pods
- **kubectl logs** - просмотр логов
- **kubectl describe** - детальная информация

### **2. Monitoring & Observability:**
- **Prometheus** - сбор метрик
- **Grafana** - визуализация
- **Jaeger** - distributed tracing
- **Loki** - log aggregation

### **3. Network Debugging:**
- **tcpdump** - анализ сетевого трафика
- **netstat** - сетевые соединения
- **dig/nslookup** - DNS debugging
- **curl/wget** - HTTP testing

### **4. Specialized Tools:**
- **k9s** - terminal UI для Kubernetes
- **Lens** - desktop IDE для Kubernetes
- **Stern** - multi-pod log tailing
- **Kubectx/Kubens** - context switching

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive debugging tools guide
cat << 'EOF' > kubernetes-debugging-tools-guide.sh
#!/bin/bash

echo "=== Kubernetes Debugging Tools Guide ==="
echo "Comprehensive guide to debugging tools for HashFoundry HA cluster"
echo

# Функция для демонстрации kubectl debugging
demo_kubectl_debugging() {
    echo "=== kubectl Debugging Tools ==="
    
    echo "1. Basic kubectl debugging commands:"
    cat << KUBECTL_DEBUG_EOF
# Get detailed information about resources
kubectl get pods -o wide --show-labels
kubectl describe pod <pod-name>
kubectl get events --sort-by='.lastTimestamp'

# Debug pod issues
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -c <container-name> --tail=100 -f

# Execute commands in pods
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec <pod-name> -- ps aux
kubectl exec <pod-name> -- netstat -tulpn

# Debug networking
kubectl port-forward <pod-name> 8080:80
kubectl proxy --port=8080

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu

KUBECTL_DEBUG_EOF
    echo
    
    echo "2. kubectl debug command (Kubernetes 1.18+):"
    cat << KUBECTL_DEBUG_COMMAND_EOF
# Debug running pod by creating debug container
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# Debug node by creating debug pod
kubectl debug node/<node-name> -it --image=busybox

# Debug with different image
kubectl debug <pod-name> -it --image=ubuntu --share-processes --copy-to=debug-pod

KUBECTL_DEBUG_COMMAND_EOF
    echo
    
    echo "3. Create kubectl debugging aliases:"
    cat << KUBECTL_ALIASES_EOF > kubectl-debug-aliases.sh
#!/bin/bash

# kubectl debugging aliases
alias kdebug='kubectl debug'
alias klogs='kubectl logs --tail=100 -f'
alias kexec='kubectl exec -it'
alias kdesc='kubectl describe'
alias kevents='kubectl get events --sort-by=.lastTimestamp'
alias kpf='kubectl port-forward'
alias ktop='kubectl top'

# Functions for common debugging tasks
klog() {
    kubectl logs \$1 --tail=100 -f
}

kshell() {
    kubectl exec -it \$1 -- /bin/bash
}

kdebugpod() {
    kubectl debug \$1 -it --image=busybox --target=\$2
}

echo "kubectl debugging aliases loaded!"

KUBECTL_ALIASES_EOF
    
    chmod +x kubectl-debug-aliases.sh
    echo "✅ kubectl debugging aliases created: kubectl-debug-aliases.sh"
    echo
}

# Функция для демонстрации k9s
demo_k9s() {
    echo "=== k9s Terminal UI ==="
    
    echo "1. k9s installation and usage:"
    cat << K9S_USAGE_EOF
# Install k9s (macOS)
brew install k9s

# Install k9s (Linux)
curl -sS https://webinstall.dev/k9s | bash

# Launch k9s
k9s

# k9s keyboard shortcuts:
# :pods          - View pods
# :services      - View services
# :deployments   - View deployments
# :nodes         - View nodes
# :events        - View events
# :logs          - View logs
# d              - Describe resource
# l              - View logs
# s              - Shell into pod
# ctrl+d         - Delete resource
# /              - Filter resources
# ?              - Help

K9S_USAGE_EOF
    echo
    
    echo "2. k9s configuration:"
    cat << K9S_CONFIG_EOF > k9s-config.yaml
# ~/.k9s/config.yml
k9s:
  refreshRate: 2
  maxConnRetry: 5
  readOnly: false
  noExitOnCtrlC: false
  ui:
    enableMouse: false
    headless: false
    logoless: false
    crumbsless: false
    reactive: false
    noIcons: false
  skipLatestRevCheck: false
  disablePodCounting: false
  shellPod:
    image: busybox:1.35
    namespace: default
    limits:
      cpu: 100m
      memory: 100Mi
  imageScans:
    enable: false
    exclusions:
      namespaces: []
      labels: {}
  logger:
    tail: 100
    buffer: 5000
    sinceSeconds: -1
    fullScreenLogs: false
    textWrap: false
    showTime: false

K9S_CONFIG_EOF
    
    echo "✅ k9s configuration created: k9s-config.yaml"
    echo
}

# Функция для демонстрации Stern
demo_stern() {
    echo "=== Stern Multi-Pod Log Tailing ==="
    
    echo "1. Stern installation and usage:"
    cat << STERN_USAGE_EOF
# Install stern (macOS)
brew install stern

# Install stern (Linux)
wget https://github.com/stern/stern/releases/download/v1.21.0/stern_1.21.0_linux_amd64.tar.gz
tar -xzf stern_1.21.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/

# Basic usage
stern <pod-query>

# Examples:
stern nginx                    # All pods containing "nginx"
stern --namespace kube-system  # All pods in kube-system namespace
stern --selector app=nginx     # Pods with label app=nginx
stern --tail 50 nginx          # Last 50 lines from nginx pods
stern --since 1h nginx         # Logs from last hour

STERN_USAGE_EOF
    echo
    
    echo "2. Advanced stern usage:"
    cat << STERN_ADVANCED_EOF
# Multiple namespaces
stern --all-namespaces nginx

# Exclude containers
stern --exclude-container istio-proxy nginx

# Output to file
stern nginx > nginx-logs.txt

# JSON output
stern --output json nginx

# Custom template
stern --template '{{.PodName}} {{.ContainerName}} {{.Message}}' nginx

# Follow specific deployment
stern --selector app=hashfoundry-app

STERN_ADVANCED_EOF
    echo
}

# Функция для демонстрации network debugging tools
demo_network_debugging_tools() {
    echo "=== Network Debugging Tools ==="
    
    echo "1. Create network debugging pod:"
    cat << NETDEBUG_POD_EOF > network-debug-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-debug
  namespace: default
  labels:
    app: network-debug
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ['sleep', '3600']
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "NET_RAW"]
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
  restartPolicy: Never
NETDEBUG_POD_EOF
    
    echo "✅ Network debug pod created: network-debug-pod.yaml"
    echo "Apply with: kubectl apply -f network-debug-pod.yaml"
    echo
    
    echo "2. Network debugging commands:"
    cat << NETWORK_DEBUG_COMMANDS_EOF
# DNS debugging
kubectl exec network-debug -- nslookup kubernetes.default.svc.cluster.local
kubectl exec network-debug -- dig @10.96.0.10 kubernetes.default.svc.cluster.local

# Network connectivity
kubectl exec network-debug -- ping 8.8.8.8
kubectl exec network-debug -- telnet <service-ip> <port>
kubectl exec network-debug -- nc -zv <host> <port>

# HTTP testing
kubectl exec network-debug -- curl -v http://<service-name>
kubectl exec network-debug -- wget -qO- http://<service-name>

# Network analysis
kubectl exec network-debug -- netstat -tulpn
kubectl exec network-debug -- ss -tulpn
kubectl exec network-debug -- iptables -L -n

# Packet capture
kubectl exec network-debug -- tcpdump -i any -w capture.pcap
kubectl exec network-debug -- tcpdump -i any host <ip-address>

NETWORK_DEBUG_COMMANDS_EOF
    echo
}

# Функция для демонстрации monitoring tools
demo_monitoring_tools() {
    echo "=== Monitoring and Observability Tools ==="
    
    echo "1. Prometheus queries for debugging:"
    cat << PROMETHEUS_QUERIES_EOF
# Pod CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Pod memory usage
container_memory_usage_bytes

# Pod restart count
kube_pod_container_status_restarts_total

# Node resource usage
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Service availability
up{job="kubernetes-pods"}

# Network errors
rate(container_network_receive_errors_total[5m])

PROMETHEUS_QUERIES_EOF
    echo
    
    echo "2. Grafana dashboard for debugging:"
    cat << GRAFANA_DASHBOARD_EOF > debugging-dashboard.json
{
  "dashboard": {
    "title": "Kubernetes Debugging Dashboard",
    "panels": [
      {
        "title": "Pod CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total[5m])",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Pod Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "container_memory_usage_bytes",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Pod Restart Count",
        "type": "stat",
        "targets": [
          {
            "expr": "kube_pod_container_status_restarts_total",
            "legendFormat": "{{pod}}"
          }
        ]
      }
    ]
  }
}

GRAFANA_DASHBOARD_EOF
    
    echo "✅ Grafana debugging dashboard created: debugging-dashboard.json"
    echo
}

# Функция для демонстрации specialized debugging tools
demo_specialized_tools() {
    echo "=== Specialized Debugging Tools ==="
    
    echo "1. kubectx and kubens:"
    cat << KUBECTX_USAGE_EOF
# Install kubectx and kubens
brew install kubectx

# Switch between contexts
kubectx                    # List contexts
kubectx <context-name>     # Switch context
kubectx -                  # Switch to previous context

# Switch between namespaces
kubens                     # List namespaces
kubens <namespace>         # Switch namespace
kubens -                   # Switch to previous namespace

KUBECTX_USAGE_EOF
    echo
    
    echo "2. Lens Desktop IDE:"
    cat << LENS_USAGE_EOF
# Install Lens
# Download from: https://k8slens.dev/

# Features:
# - Visual cluster management
# - Real-time resource monitoring
# - Built-in terminal
# - Log streaming
# - Resource editing
# - Helm chart management
# - Extension support

LENS_USAGE_EOF
    echo
    
    echo "3. kubectl plugins:"
    cat << KUBECTL_PLUGINS_EOF
# Install krew (kubectl plugin manager)
curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_amd64.tar.gz"
tar zxvf krew-linux_amd64.tar.gz
./krew-linux_amd64 install krew

# Useful debugging plugins
kubectl krew install debug-shell    # Debug shell for pods
kubectl krew install tail           # Tail logs from multiple pods
kubectl krew install tree           # Show resource tree
kubectl krew install who-can        # Show who can perform actions
kubectl krew install outdated       # Find outdated images

# Usage examples
kubectl debug-shell <pod-name>
kubectl tail --selector app=nginx
kubectl tree deployment <deployment-name>
kubectl who-can create pods

KUBECTL_PLUGINS_EOF
    echo
}

# Функция для создания debugging workflow
create_debugging_workflow() {
    echo "=== Creating Debugging Workflow ==="
    
    cat << DEBUG_WORKFLOW_EOF > kubernetes-debugging-workflow.sh
#!/bin/bash

echo "=== Kubernetes Debugging Workflow ==="
echo

# Function for initial problem assessment
assess_problem() {
    echo "1. Initial Problem Assessment"
    echo "=============================="
    
    echo "Checking cluster status..."
    kubectl cluster-info
    
    echo "Checking node status..."
    kubectl get nodes
    
    echo "Checking problematic pods..."
    kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
    
    echo "Checking recent events..."
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
    
    echo
}

# Function for pod-specific debugging
debug_pod() {
    local POD_NAME=\$1
    local NAMESPACE=\${2:-default}
    
    if [ -z "\$POD_NAME" ]; then
        echo "Usage: debug_pod <pod-name> [namespace]"
        return 1
    fi
    
    echo "2. Pod-Specific Debugging: \$NAMESPACE/\$POD_NAME"
    echo "=================================================="
    
    echo "Pod status:"
    kubectl get pod \$POD_NAME -n \$NAMESPACE -o wide
    
    echo "Pod description:"
    kubectl describe pod \$POD_NAME -n \$NAMESPACE
    
    echo "Pod logs:"
    kubectl logs \$POD_NAME -n \$NAMESPACE --tail=50
    
    echo "Pod events:"
    kubectl get events -n \$NAMESPACE --field-selector involvedObject.name=\$POD_NAME
    
    echo
}

# Function for service debugging
debug_service() {
    local SERVICE_NAME=\$1
    local NAMESPACE=\${2:-default}
    
    if [ -z "\$SERVICE_NAME" ]; then
        echo "Usage: debug_service <service-name> [namespace]"
        return 1
    fi
    
    echo "3. Service Debugging: \$NAMESPACE/\$SERVICE_NAME"
    echo "=============================================="
    
    echo "Service status:"
    kubectl get service \$SERVICE_NAME -n \$NAMESPACE -o wide
    
    echo "Service endpoints:"
    kubectl get endpoints \$SERVICE_NAME -n \$NAMESPACE
    
    echo "Pods matching service selector:"
    SELECTOR=\$(kubectl get service \$SERVICE_NAME -n \$NAMESPACE -o jsonpath='{.spec.selector}')
    echo "Selector: \$SELECTOR"
    kubectl get pods -n \$NAMESPACE --selector=\$SELECTOR
    
    echo
}

# Function for network debugging
debug_network() {
    echo "4. Network Debugging"
    echo "==================="
    
    echo "Creating network debug pod..."
    kubectl apply -f network-debug-pod.yaml
    kubectl wait --for=condition=Ready pod/network-debug --timeout=60s
    
    echo "Testing DNS resolution..."
    kubectl exec network-debug -- nslookup kubernetes.default.svc.cluster.local
    
    echo "Testing external connectivity..."
    kubectl exec network-debug -- ping -c 3 8.8.8.8
    
    echo "Testing internal connectivity..."
    kubectl exec network-debug -- wget -qO- http://kubernetes.default.svc.cluster.local
    
    echo
}

# Main debugging workflow
main() {
    case "\$1" in
        "assess")
            assess_problem
            ;;
        "pod")
            debug_pod \$2 \$3
            ;;
        "service")
            debug_service \$2 \$3
            ;;
        "network")
            debug_network
            ;;
        "all"|"")
            assess_problem
            echo "For specific debugging, use:"
            echo "  \$0 pod <pod-name> [namespace]"
            echo "  \$0 service <service-name> [namespace]"
            echo "  \$0 network"
            ;;
        *)
            echo "Usage: \$0 [assess|pod|service|network|all]"
            ;;
    esac
}

main "\$@"

DEBUG_WORKFLOW_EOF
    
    chmod +x kubernetes-debugging-workflow.sh
    echo "✅ Debugging workflow created: kubernetes-debugging-workflow.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "kubectl")
            demo_kubectl_debugging
            ;;
        "k9s")
            demo_k9s
            ;;
        "stern")
            demo_stern
            ;;
        "network")
            demo_network_debugging_tools
            ;;
        "monitoring")
            demo_monitoring_tools
            ;;
        "specialized")
            demo_specialized_tools
            ;;
        "workflow")
            create_debugging_workflow
            ;;
        "all"|"")
            demo_kubectl_debugging
            demo_k9s
            demo_stern
            demo_network_debugging_tools
            demo_monitoring_tools
            demo_specialized_tools
            create_debugging_workflow
            ;;
        *)
            echo "Usage: $0 [kubectl|k9s|stern|network|monitoring|specialized|workflow|all]"
            echo ""
            echo "Kubernetes Debugging Tools:"
            echo "  kubectl      - kubectl debugging commands"
            echo "  k9s          - Terminal UI for Kubernetes"
            echo "  stern        - Multi-pod log tailing"
            echo "  network      - Network debugging tools"
            echo "  monitoring   - Monitoring and observability"
            echo "  specialized  - Specialized debugging tools"
            echo "  workflow     - Complete debugging workflow"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubernetes-debugging-tools-guide.sh
./kubernetes-debugging-tools-guide.sh all
```

## 🎯 **Основные инструменты отладки:**

### **1. kubectl - основной инструмент:**
```bash
# Базовая диагностика
kubectl get pods -o wide --show-labels
kubectl describe pod <pod-name>
kubectl logs <pod-name> --tail=100 -f

# Отладка с kubectl debug
kubectl debug <pod-name> -it --image=busybox
kubectl debug node/<node-name> -it --image=busybox
```

### **2. k9s - терминальный UI:**
```bash
# Установка и запуск
brew install k9s
k9s

# Основные команды в k9s:
# :pods - просмотр pods
# d - describe ресурса
# l - просмотр логов
# s - shell в pod
```

### **3. Stern - мульти-pod логи:**
```bash
# Установка и использование
brew install stern

# Просмотр логов всех nginx pods
stern nginx

# Логи по селектору
stern --selector app=nginx
```

### **4. Network debugging:**
```bash
# Создать debug pod с сетевыми инструментами
kubectl run netdebug --image=nicolaka/netshoot --rm -it

# Тестирование в debug pod
kubectl exec netdebug -- ping <ip>
kubectl exec netdebug -- nslookup <service>
kubectl exec netdebug -- curl <url>
```

## 🔧 **Специализированные инструменты:**

### **Lens Desktop IDE:**
- Визуальное управление кластером
- Встроенный терминал
- Мониторинг в реальном времени

### **kubectl plugins:**
```bash
# Установить krew
kubectl krew install debug-shell
kubectl krew install tail
kubectl krew install tree

# Использование
kubectl debug-shell <pod>
kubectl tail --selector app=nginx
kubectl tree deployment <name>
```

### **Monitoring stack:**
- **Prometheus** - метрики
- **Grafana** - дашборды
- **Jaeger** - трейсинг
- **Loki** - логи

**Правильные инструменты делают debugging быстрым и эффективным!**
