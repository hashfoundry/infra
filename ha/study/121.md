# 121. Детальное объяснение Container Network Interface (CNI)

## 🎯 **Детальное объяснение Container Network Interface (CNI)**

**CNI (Container Network Interface)** - это стандартизированный интерфейс для настройки сетевых подключений контейнеров в Linux. CNI является основой сетевой архитектуры Kubernetes и определяет, как pods получают IP адреса и взаимодействуют друг с другом.

## 🌐 **Архитектура CNI:**

### **1. CNI Components:**
- **CNI Specification** - стандарт интерфейса
- **CNI Plugins** - исполняемые файлы для сетевых операций
- **CNI Configuration** - JSON конфигурация сети
- **Container Runtime** - вызывает CNI plugins

### **2. CNI Operations:**
- **ADD** - добавление контейнера в сеть
- **DEL** - удаление контейнера из сети
- **CHECK** - проверка сетевого подключения
- **VERSION** - получение версии plugin

### **3. CNI Plugin Types:**
- **Main Plugins** - основные сетевые plugins
- **IPAM Plugins** - управление IP адресами
- **Meta Plugins** - дополнительные функции

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive CNI analysis toolkit
cat << 'EOF' > cni-analysis-toolkit.sh
#!/bin/bash

echo "=== CNI Analysis Toolkit ==="
echo "Comprehensive guide for understanding CNI in HashFoundry HA cluster"
echo

# Функция для анализа CNI конфигурации
analyze_cni_configuration() {
    echo "=== CNI Configuration Analysis ==="
    
    echo "1. Check CNI configuration directory:"
    CNI_CONFIG_DIR="/etc/cni/net.d"
    if [ -d "$CNI_CONFIG_DIR" ]; then
        echo "CNI config directory exists: $CNI_CONFIG_DIR"
        ls -la "$CNI_CONFIG_DIR"
        echo
        
        echo "2. CNI configuration files:"
        for config_file in "$CNI_CONFIG_DIR"/*.conf "$CNI_CONFIG_DIR"/*.conflist; do
            if [ -f "$config_file" ]; then
                echo "--- Configuration: $(basename $config_file) ---"
                cat "$config_file" | jq . 2>/dev/null || cat "$config_file"
                echo
            fi
        done
    else
        echo "❌ CNI config directory not found: $CNI_CONFIG_DIR"
    fi
    
    echo "3. CNI binary directory:"
    CNI_BIN_DIR="/opt/cni/bin"
    if [ -d "$CNI_BIN_DIR" ]; then
        echo "CNI binary directory: $CNI_BIN_DIR"
        ls -la "$CNI_BIN_DIR"
        echo
        
        echo "Available CNI plugins:"
        for plugin in "$CNI_BIN_DIR"/*; do
            if [ -x "$plugin" ]; then
                PLUGIN_NAME=$(basename "$plugin")
                echo "- $PLUGIN_NAME"
                "$plugin" version 2>/dev/null | head -3 || echo "  (version info not available)"
            fi
        done
    else
        echo "❌ CNI binary directory not found: $CNI_BIN_DIR"
    fi
    echo
}

# Функция для анализа текущего CNI plugin
analyze_current_cni_plugin() {
    echo "=== Current CNI Plugin Analysis ==="
    
    echo "1. Detect CNI plugin from cluster:"
    
    # Check kube-proxy configuration for CNI hints
    echo "Checking kube-proxy configuration:"
    kubectl get configmap -n kube-system kube-proxy -o yaml | grep -A 10 -B 5 "mode\|cluster" || echo "Cannot access kube-proxy config"
    echo
    
    # Check for common CNI plugins
    echo "2. Checking for common CNI plugins:"
    
    # Calico
    kubectl get pods -n kube-system | grep calico && echo "✅ Calico detected" || echo "❌ Calico not found"
    
    # Flannel
    kubectl get pods -n kube-system | grep flannel && echo "✅ Flannel detected" || echo "❌ Flannel not found"
    
    # Weave
    kubectl get pods -n kube-system | grep weave && echo "✅ Weave detected" || echo "❌ Weave not found"
    
    # Cilium
    kubectl get pods -n kube-system | grep cilium && echo "✅ Cilium detected" || echo "❌ Cilium not found"
    
    # AWS VPC CNI
    kubectl get pods -n kube-system | grep aws-node && echo "✅ AWS VPC CNI detected" || echo "❌ AWS VPC CNI not found"
    echo
    
    echo "3. Check CNI-related DaemonSets:"
    kubectl get daemonsets -n kube-system | grep -E "(calico|flannel|weave|cilium|aws-node|kube-proxy)"
    echo
    
    echo "4. Check network-related ConfigMaps:"
    kubectl get configmaps -n kube-system | grep -E "(calico|flannel|weave|cilium|cni)"
    echo
}

# Функция для анализа pod networking
analyze_pod_networking() {
    echo "=== Pod Networking Analysis ==="
    
    echo "1. Create test pods for network analysis:"
    
    # Create test namespace
    kubectl create namespace cni-test 2>/dev/null || echo "Namespace cni-test already exists"
    
    # Create test pods
    cat << TEST_PODS_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-test-1
  namespace: cni-test
  labels:
    app: network-test
spec:
  containers:
  - name: test
    image: busybox:1.28
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
---
apiVersion: v1
kind: Pod
metadata:
  name: network-test-2
  namespace: cni-test
  labels:
    app: network-test
spec:
  containers:
  - name: test
    image: busybox:1.28
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
TEST_PODS_EOF
    
    echo "Waiting for test pods to be ready..."
    kubectl wait --for=condition=Ready pod/network-test-1 -n cni-test --timeout=60s
    kubectl wait --for=condition=Ready pod/network-test-2 -n cni-test --timeout=60s
    
    echo "2. Analyze pod IP allocation:"
    kubectl get pods -n cni-test -o wide
    echo
    
    echo "3. Check pod network interfaces:"
    POD1_IP=$(kubectl get pod network-test-1 -n cni-test -o jsonpath='{.status.podIP}')
    POD2_IP=$(kubectl get pod network-test-2 -n cni-test -o jsonpath='{.status.podIP}')
    
    echo "Pod 1 IP: $POD1_IP"
    echo "Pod 2 IP: $POD2_IP"
    echo
    
    echo "Network interfaces in pod 1:"
    kubectl exec -n cni-test network-test-1 -- ip addr show
    echo
    
    echo "4. Test pod-to-pod connectivity:"
    echo "Testing connectivity from pod 1 to pod 2:"
    kubectl exec -n cni-test network-test-1 -- ping -c 3 $POD2_IP
    echo
    
    echo "Testing connectivity from pod 2 to pod 1:"
    kubectl exec -n cni-test network-test-2 -- ping -c 3 $POD1_IP
    echo
    
    echo "5. Check routing table in pods:"
    echo "Routing table in pod 1:"
    kubectl exec -n cni-test network-test-1 -- ip route show
    echo
}

# Функция для анализа CNI IPAM
analyze_cni_ipam() {
    echo "=== CNI IPAM (IP Address Management) Analysis ==="
    
    echo "1. Check cluster CIDR configuration:"
    
    # Check from kube-controller-manager
    kubectl get pods -n kube-system -l component=kube-controller-manager -o yaml | grep -A 5 -B 5 "cluster-cidr\|service-cluster-ip-range" || echo "Cannot access controller manager config"
    echo
    
    # Check from nodes
    echo "2. Node CIDR allocation:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\t"}{.spec.podCIDRs}{"\n"}{end}' | column -t
    echo
    
    echo "3. Service CIDR information:"
    kubectl cluster-info dump | grep -E "service-cluster-ip-range|cluster-cidr" | head -5 || echo "Cannot determine service CIDR"
    echo
    
    echo "4. Check IP allocation across pods:"
    echo "Pod IP distribution by node:"
    kubectl get pods --all-namespaces -o wide | awk 'NR>1 {print $8, $7}' | sort | uniq -c | sort -nr
    echo
    
    echo "5. IPAM plugin configuration:"
    # Look for IPAM configuration in CNI configs
    CNI_CONFIG_DIR="/etc/cni/net.d"
    if [ -d "$CNI_CONFIG_DIR" ]; then
        for config_file in "$CNI_CONFIG_DIR"/*.conf "$CNI_CONFIG_DIR"/*.conflist; do
            if [ -f "$config_file" ]; then
                echo "IPAM config in $(basename $config_file):"
                cat "$config_file" | jq '.ipam // .plugins[].ipam' 2>/dev/null | grep -v null || echo "No IPAM config found"
                echo
            fi
        done
    fi
}

# Функция для создания CNI troubleshooting guide
create_cni_troubleshooting_guide() {
    echo "=== Creating CNI Troubleshooting Guide ==="
    
    echo "1. CNI troubleshooting procedures:"
    cat << CNI_TROUBLESHOOTING_EOF > cni-troubleshooting-guide.md
# CNI Troubleshooting Guide

## 🔍 **CNI Diagnostics**

### **1. Check CNI Installation**
\`\`\`bash
# Check CNI binaries
ls -la /opt/cni/bin/

# Check CNI configuration
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/*.conf

# Verify CNI plugin versions
/opt/cni/bin/bridge version
/opt/cni/bin/host-local version
\`\`\`

### **2. Analyze CNI Configuration**
\`\`\`bash
# Check CNI config syntax
cat /etc/cni/net.d/10-calico.conflist | jq .

# Verify IPAM configuration
cat /etc/cni/net.d/*.conf | jq '.ipam'

# Check plugin chain
cat /etc/cni/net.d/*.conflist | jq '.plugins[].type'
\`\`\`

### **3. Test CNI Functionality**
\`\`\`bash
# Manual CNI plugin test
export CNI_COMMAND=ADD
export CNI_CONTAINERID=test123
export CNI_NETNS=/var/run/netns/test
export CNI_IFNAME=eth0
export CNI_PATH=/opt/cni/bin

# Create network namespace
ip netns add test

# Run CNI plugin
echo '{"cniVersion":"0.3.1","name":"test","type":"bridge"}' | /opt/cni/bin/bridge

# Cleanup
ip netns del test
\`\`\`

## 🚨 **Common CNI Issues**

### **Issue 1: Pod Cannot Get IP Address**
**Symptoms**: Pod stuck in ContainerCreating
**Diagnosis**:
\`\`\`bash
kubectl describe pod <pod-name>
kubectl logs -n kube-system <cni-pod>
\`\`\`
**Solutions**:
- Check CNI plugin logs
- Verify IPAM pool availability
- Restart CNI DaemonSet

### **Issue 2: Pod-to-Pod Communication Fails**
**Symptoms**: Pods cannot reach each other
**Diagnosis**:
\`\`\`bash
kubectl exec <pod1> -- ping <pod2-ip>
kubectl exec <pod1> -- traceroute <pod2-ip>
\`\`\`
**Solutions**:
- Check network policies
- Verify CNI plugin configuration
- Check node-to-node connectivity

### **Issue 3: DNS Resolution Problems**
**Symptoms**: Pods cannot resolve service names
**Diagnosis**:
\`\`\`bash
kubectl exec <pod> -- nslookup kubernetes.default
kubectl get pods -n kube-system -l k8s-app=kube-dns
\`\`\`
**Solutions**:
- Check CoreDNS configuration
- Verify CNI DNS settings
- Check service CIDR configuration

## 🔧 **CNI Performance Tuning**

### **1. Network Performance Optimization**
\`\`\`bash
# Check network interface statistics
kubectl exec <pod> -- cat /proc/net/dev

# Monitor network performance
kubectl exec <pod> -- iperf3 -c <target-ip>

# Check CNI plugin performance
time kubectl create -f test-pod.yaml
\`\`\`

### **2. IPAM Optimization**
\`\`\`bash
# Check IP allocation efficiency
kubectl get pods --all-namespaces -o wide | awk '{print \$7}' | sort | uniq -c

# Monitor IPAM pool usage
kubectl get ippool -o yaml  # For Calico
\`\`\`

CNI_TROUBLESHOOTING_EOF
    
    echo "✅ CNI troubleshooting guide created: cni-troubleshooting-guide.md"
    echo
    
    echo "2. CNI monitoring script:"
    cat << CNI_MONITOR_EOF > cni-monitor.sh
#!/bin/bash

echo "=== CNI Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "CNI Plugin Status:"
    kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium|aws-node)" | head -5
    echo
    
    echo "Pod IP Allocation:"
    TOTAL_PODS=\$(kubectl get pods --all-namespaces --no-headers | wc -l)
    RUNNING_PODS=\$(kubectl get pods --all-namespaces --no-headers | grep Running | wc -l)
    PENDING_PODS=\$(kubectl get pods --all-namespaces --no-headers | grep Pending | wc -l)
    
    echo "Total Pods: \$TOTAL_PODS"
    echo "Running Pods: \$RUNNING_PODS"
    echo "Pending Pods: \$PENDING_PODS"
    echo
    
    echo "Network Connectivity Test:"
    # Test connectivity between random pods
    POD1=\$(kubectl get pods --all-namespaces -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    POD1_NS=\$(kubectl get pods --all-namespaces -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    POD2_IP=\$(kubectl get pods --all-namespaces -o jsonpath='{.items[1].status.podIP}' 2>/dev/null)
    
    if [ ! -z "\$POD1" ] && [ ! -z "\$POD2_IP" ]; then
        kubectl exec -n \$POD1_NS \$POD1 -- ping -c 1 -W 2 \$POD2_IP >/dev/null 2>&1 && echo "✅ Pod-to-Pod connectivity OK" || echo "❌ Pod-to-Pod connectivity FAILED"
    else
        echo "❌ Cannot test connectivity - insufficient pods"
    fi
    echo
    
    sleep 30
done

CNI_MONITOR_EOF
    
    chmod +x cni-monitor.sh
    echo "✅ CNI monitoring script created: cni-monitor.sh"
    echo
}

# Функция для демонстрации CNI workflow
demonstrate_cni_workflow() {
    echo "=== CNI Workflow Demonstration ==="
    
    echo "1. CNI workflow steps:"
    cat << CNI_WORKFLOW_EOF
# CNI Workflow Process

## 📋 **Step-by-Step CNI Process**

### **1. Container Runtime Calls CNI**
When kubelet creates a pod:
1. Container runtime (containerd/docker) creates container
2. Runtime calls CNI plugin with ADD command
3. CNI plugin configures network for container

### **2. CNI Plugin Execution**
\`\`\`bash
# Environment variables set by runtime:
CNI_COMMAND=ADD
CNI_CONTAINERID=<container-id>
CNI_NETNS=<network-namespace-path>
CNI_IFNAME=eth0
CNI_PATH=/opt/cni/bin

# CNI configuration passed via stdin:
{
  "cniVersion": "0.3.1",
  "name": "k8s-pod-network",
  "type": "calico",
  "ipam": {
    "type": "calico-ipam"
  }
}
\`\`\`

### **3. Network Interface Creation**
1. Create veth pair
2. Move one end to container namespace
3. Configure IP address via IPAM
4. Set up routing rules
5. Configure DNS settings

### **4. IPAM (IP Address Management)**
1. Request IP from IPAM plugin
2. Allocate IP from available pool
3. Update IP allocation database
4. Return IP configuration to main plugin

### **5. Plugin Chain Execution**
For complex setups, multiple plugins execute in sequence:
1. Main plugin (bridge/calico/flannel)
2. IPAM plugin (host-local/calico-ipam)
3. Meta plugins (portmap/bandwidth)

CNI_WORKFLOW_EOF
    echo
    
    echo "2. Create CNI workflow visualization:"
    cat << CNI_VISUALIZATION_EOF > cni-workflow-visualization.md
# CNI Workflow Visualization

\`\`\`
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    kubelet      │    │ Container       │    │   CNI Plugin    │
│                 │    │ Runtime         │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │ 1. Create Pod        │                      │
          ├─────────────────────►│                      │
          │                      │                      │
          │                      │ 2. Call CNI ADD      │
          │                      ├─────────────────────►│
          │                      │                      │
          │                      │                      │ 3. Create netns
          │                      │                      ├──────────────┐
          │                      │                      │              │
          │                      │                      │◄─────────────┘
          │                      │                      │
          │                      │                      │ 4. Call IPAM
          │                      │                      ├──────────────┐
          │                      │                      │              │
          │                      │                      │◄─────────────┘
          │                      │                      │
          │                      │                      │ 5. Configure interface
          │                      │                      ├──────────────┐
          │                      │                      │              │
          │                      │                      │◄─────────────┘
          │                      │                      │
          │                      │ 6. Return result     │
          │                      │◄─────────────────────┤
          │                      │                      │
          │ 7. Pod Ready         │                      │
          │◄─────────────────────┤                      │
          │                      │                      │
\`\`\`

## 🔄 **CNI Plugin Types and Responsibilities**

### **Main Plugins**
- **bridge**: Creates bridge network
- **ipvlan**: Creates ipvlan interface
- **macvlan**: Creates macvlan interface
- **ptp**: Creates point-to-point link

### **IPAM Plugins**
- **host-local**: Allocates IPs from local ranges
- **dhcp**: Gets IPs from DHCP server
- **static**: Uses static IP assignment

### **Meta Plugins**
- **portmap**: Port mapping functionality
- **bandwidth**: Traffic shaping
- **firewall**: Firewall rules
- **tuning**: Interface tuning

CNI_VISUALIZATION_EOF
    
    echo "✅ CNI workflow visualization created: cni-workflow-visualization.md"
    echo
}

# Функция для cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up test resources ==="
    kubectl delete namespace cni-test --ignore-not-found=true
    echo "✅ Test resources cleaned up"
}

# Основная функция
main() {
    case "$1" in
        "config")
            analyze_cni_configuration
            ;;
        "plugin")
            analyze_current_cni_plugin
            ;;
        "networking")
            analyze_pod_networking
            ;;
        "ipam")
            analyze_cni_ipam
            ;;
        "troubleshoot")
            create_cni_troubleshooting_guide
            ;;
        "workflow")
            demonstrate_cni_workflow
            ;;
        "cleanup")
            cleanup_test_resources
            ;;
        "all"|"")
            analyze_cni_configuration
            analyze_current_cni_plugin
            analyze_pod_networking
            analyze_cni_ipam
            create_cni_troubleshooting_guide
            demonstrate_cni_workflow
            ;;
        *)
            echo "Usage: $0 [config|plugin|networking|ipam|troubleshoot|workflow|cleanup|all]"
            echo ""
            echo "CNI Analysis Options:"
            echo "  config       - Analyze CNI configuration"
            echo "  plugin       - Analyze current CNI plugin"
            echo "  networking   - Analyze pod networking"
            echo "  ipam         - Analyze CNI IPAM"
            echo "  troubleshoot - Create troubleshooting guide"
            echo "  workflow     - Demonstrate CNI workflow"
            echo "  cleanup      - Clean up test resources"
            ;;
    esac
}

main "$@"

EOF

chmod +x cni-analysis-toolkit.sh
./cni-analysis-toolkit.sh all
```

## 🎯 **Ключевые концепции CNI:**

### **1. CNI Specification:**
```json
{
  "cniVersion": "0.4.0",
  "name": "k8s-pod-network",
  "type": "calico",
  "ipam": {
    "type": "calico-ipam"
  },
  "kubernetes": {
    "kubeconfig": "/etc/cni/net.d/calico-kubeconfig"
  }
}
```

### **2. CNI Plugin Chain:**
```bash
# Main plugin
/opt/cni/bin/calico

# IPAM plugin
/opt/cni/bin/host-local

# Meta plugins
/opt/cni/bin/portmap
/opt/cni/bin/bandwidth
```

### **3. CNI Environment Variables:**
```bash
CNI_COMMAND=ADD|DEL|CHECK|VERSION
CNI_CONTAINERID=<container-id>
CNI_NETNS=<network-namespace-path>
CNI_IFNAME=eth0
CNI_PATH=/opt/cni/bin
```

## 🔧 **CNI Workflow Process:**

### **Шаг 1: Container Creation**
```bash
# kubelet создает pod
# Container runtime создает container
# Runtime вызывает CNI plugin
```

### **Шаг 2: Network Namespace Setup**
```bash
# Создание network namespace
ip netns add <container-id>

# Создание veth pair
ip link add veth0 type veth peer name eth0

# Перемещение в namespace
ip link set eth0 netns <container-id>
```

### **Шаг 3: IP Address Allocation**
```bash
# IPAM plugin выделяет IP
# Настройка IP на интерфейсе
ip addr add <ip>/<mask> dev eth0

# Настройка маршрутизации
ip route add default via <gateway>
```

### **Шаг 4: DNS Configuration**
```bash
# Настройка DNS в контейнере
echo "nameserver <dns-ip>" > /etc/resolv.conf
```

## 🌐 **CNI в вашем HA кластере:**

### **Проверка текущего CNI:**
```bash
# Определение CNI plugin
kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium)"

# Конфигурация CNI
cat /etc/cni/net.d/*.conf

# CNI binaries
ls -la /opt/cni/bin/
```

### **Анализ сетевой конфигурации:**
```bash
# Pod CIDR
kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'

# Service CIDR
kubectl cluster-info dump | grep service-cluster-ip-range

# IP allocation
kubectl get pods --all-namespaces -o wide
```

**CNI - это основа сетевой архитектуры Kubernetes, обеспечивающая гибкую и расширяемую сетевую модель!**
