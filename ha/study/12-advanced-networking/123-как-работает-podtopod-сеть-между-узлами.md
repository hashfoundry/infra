# 123. Как работает Pod-to-Pod сеть между узлами

## 🎯 **Как работает Pod-to-Pod сеть между узлами**

**Pod-to-Pod networking** между узлами - это фундаментальная возможность Kubernetes, которая позволяет pods на разных nodes общаться друг с другом напрямую. Понимание этого механизма критически важно для troubleshooting сетевых проблем и оптимизации производительности.

## 🌐 **Архитектура межузловой сети:**

### **1. Kubernetes Network Model:**
- **Flat Network Space** - все pods в одном IP пространстве
- **No NAT Required** - прямая связь между pods
- **Unique IP per Pod** - каждый pod имеет уникальный IP
- **Cross-Node Communication** - pods могут общаться между узлами

### **2. Network Components:**
- **CNI Plugin** - управляет сетевой конфигурацией
- **kube-proxy** - обеспечивает service discovery
- **Node Routing** - маршрутизация между узлами
- **Overlay/Underlay** - сетевая инфраструктура

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive pod-to-pod networking analysis toolkit
cat << 'EOF' > pod-to-pod-networking-toolkit.sh
#!/bin/bash

echo "=== Pod-to-Pod Networking Analysis Toolkit ==="
echo "Comprehensive guide for understanding cross-node networking in HashFoundry HA cluster"
echo

# Функция для анализа сетевой топологии кластера
analyze_cluster_network_topology() {
    echo "=== Cluster Network Topology Analysis ==="
    
    echo "1. Node network information:"
    kubectl get nodes -o wide
    echo
    
    echo "2. Node IP addresses and CIDRs:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\t"}{.spec.podCIDR}{"\n"}{end}' | column -t
    echo
    
    echo "3. Cluster CIDR configuration:"
    # Try to get cluster CIDR from various sources
    echo "Checking cluster CIDR from kube-controller-manager..."
    kubectl get pods -n kube-system -l component=kube-controller-manager -o yaml | grep -A 3 -B 3 "cluster-cidr" || echo "Cannot access controller manager config"
    echo
    
    echo "4. Service CIDR information:"
    kubectl cluster-info dump | grep -E "service-cluster-ip-range|service-cidr" | head -3 || echo "Cannot determine service CIDR"
    echo
    
    echo "5. CNI plugin detection:"
    # Check for common CNI plugins
    echo "Detecting CNI plugin..."
    if kubectl get pods -n kube-system | grep -q calico; then
        echo "✅ Calico detected"
        kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
    elif kubectl get pods -n kube-system | grep -q flannel; then
        echo "✅ Flannel detected"
        kubectl get pods -n kube-system -l app=flannel -o wide
    elif kubectl get pods -n kube-system | grep -q cilium; then
        echo "✅ Cilium detected"
        kubectl get pods -n kube-system -l k8s-app=cilium -o wide
    elif kubectl get pods -n kube-system | grep -q weave; then
        echo "✅ Weave detected"
        kubectl get pods -n kube-system -l name=weave-net -o wide
    else
        echo "❓ CNI plugin not clearly identified"
    fi
    echo
}

# Функция для создания тестовых pods на разных узлах
create_cross_node_test_pods() {
    echo "=== Creating Cross-Node Test Pods ==="
    
    # Create test namespace
    kubectl create namespace cross-node-test 2>/dev/null || echo "Namespace already exists"
    
    # Get list of nodes
    NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    NODE_COUNT=${#NODES[@]}
    
    echo "Available nodes: ${NODES[*]}"
    echo "Creating test pods on different nodes..."
    
    # Create pods on different nodes
    for i in $(seq 0 $((NODE_COUNT-1))); do
        NODE_NAME=${NODES[$i]}
        POD_NAME="test-pod-node-$((i+1))"
        
        cat << TEST_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: cross-node-test
  labels:
    app: cross-node-test
    node-index: "$((i+1))"
spec:
  nodeSelector:
    kubernetes.io/hostname: $NODE_NAME
  containers:
  - name: test
    image: busybox:1.28
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
  restartPolicy: Always
TEST_POD_EOF
        
        echo "Created pod $POD_NAME on node $NODE_NAME"
    done
    
    echo
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app=cross-node-test -n cross-node-test --timeout=120s
    
    echo
    echo "Test pods status:"
    kubectl get pods -n cross-node-test -o wide
    echo
}

# Функция для тестирования pod-to-pod connectivity
test_pod_to_pod_connectivity() {
    echo "=== Testing Pod-to-Pod Connectivity ==="
    
    # Get pod information
    PODS=($(kubectl get pods -n cross-node-test -l app=cross-node-test -o jsonpath='{.items[*].metadata.name}'))
    POD_IPS=($(kubectl get pods -n cross-node-test -l app=cross-node-test -o jsonpath='{.items[*].status.podIP}'))
    POD_NODES=($(kubectl get pods -n cross-node-test -l app=cross-node-test -o jsonpath='{.items[*].spec.nodeName}'))
    
    echo "Pod connectivity matrix:"
    echo "Testing connectivity between all pods..."
    echo
    
    # Create connectivity matrix
    printf "%-20s" "From\\To"
    for i in "${!PODS[@]}"; do
        printf "%-15s" "${PODS[$i]}"
    done
    echo
    
    for i in "${!PODS[@]}"; do
        printf "%-20s" "${PODS[$i]}"
        for j in "${!POD_IPS[@]}"; do
            if [ $i -eq $j ]; then
                printf "%-15s" "SELF"
            else
                # Test connectivity
                if kubectl exec -n cross-node-test ${PODS[$i]} -- ping -c 1 -W 2 ${POD_IPS[$j]} >/dev/null 2>&1; then
                    printf "%-15s" "✅ OK"
                else
                    printf "%-15s" "❌ FAIL"
                fi
            fi
        done
        echo
    done
    echo
    
    echo "Detailed connectivity analysis:"
    for i in "${!PODS[@]}"; do
        echo "--- Pod: ${PODS[$i]} (${POD_IPS[$i]}) on node ${POD_NODES[$i]} ---"
        
        # Show network interfaces
        echo "Network interfaces:"
        kubectl exec -n cross-node-test ${PODS[$i]} -- ip addr show 2>/dev/null || echo "Cannot access network interfaces"
        echo
        
        # Show routing table
        echo "Routing table:"
        kubectl exec -n cross-node-test ${PODS[$i]} -- ip route show 2>/dev/null || echo "Cannot access routing table"
        echo
        
        # Test connectivity to other pods
        for j in "${!POD_IPS[@]}"; do
            if [ $i -ne $j ]; then
                echo "Testing connectivity to ${PODS[$j]} (${POD_IPS[$j]}):"
                kubectl exec -n cross-node-test ${PODS[$i]} -- ping -c 3 ${POD_IPS[$j]} 2>/dev/null || echo "❌ Connectivity failed"
                echo
            fi
        done
        echo "----------------------------------------"
        echo
    done
}

# Функция для анализа сетевых маршрутов
analyze_network_routes() {
    echo "=== Network Routes Analysis ==="
    
    echo "1. Node routing tables:"
    NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    
    for node in "${NODES[@]}"; do
        echo "--- Node: $node ---"
        
        # Try to get routing information from node
        echo "Attempting to get routing table from node $node..."
        
        # Create debug pod on specific node
        cat << DEBUG_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: debug-$node
  namespace: cross-node-test
spec:
  nodeSelector:
    kubernetes.io/hostname: $node
  hostNetwork: true
  containers:
  - name: debug
    image: busybox:1.28
    command: ["sleep", "300"]
    securityContext:
      privileged: true
  restartPolicy: Never
DEBUG_POD_EOF
        
        # Wait for debug pod
        kubectl wait --for=condition=Ready pod/debug-$node -n cross-node-test --timeout=60s 2>/dev/null
        
        if kubectl get pod debug-$node -n cross-node-test >/dev/null 2>&1; then
            echo "Node $node routing table:"
            kubectl exec -n cross-node-test debug-$node -- ip route show 2>/dev/null | head -20 || echo "Cannot access routing table"
            echo
            
            echo "Node $node network interfaces:"
            kubectl exec -n cross-node-test debug-$node -- ip addr show 2>/dev/null | grep -E "inet |^[0-9]+:" || echo "Cannot access network interfaces"
            echo
            
            # Cleanup debug pod
            kubectl delete pod debug-$node -n cross-node-test --ignore-not-found=true
        else
            echo "❌ Cannot create debug pod on node $node"
        fi
        echo "----------------------------------------"
        echo
    done
}

# Функция для анализа CNI-specific networking
analyze_cni_specific_networking() {
    echo "=== CNI-Specific Networking Analysis ==="
    
    echo "1. CNI configuration analysis:"
    
    # Check for Calico
    if kubectl get pods -n kube-system | grep -q calico; then
        echo "Analyzing Calico networking..."
        
        echo "Calico node status:"
        kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
        echo
        
        echo "Calico IP pools:"
        kubectl get ippools -o wide 2>/dev/null || echo "Cannot access Calico IP pools (calicoctl may be required)"
        echo
        
        echo "Calico BGP peers:"
        kubectl get bgppeers -o wide 2>/dev/null || echo "Cannot access Calico BGP peers"
        echo
        
    # Check for Flannel
    elif kubectl get pods -n kube-system | grep -q flannel; then
        echo "Analyzing Flannel networking..."
        
        echo "Flannel pods status:"
        kubectl get pods -n kube-system -l app=flannel -o wide
        echo
        
        echo "Flannel configuration:"
        kubectl get configmap -n kube-system kube-flannel-cfg -o yaml 2>/dev/null || echo "Cannot access Flannel configuration"
        echo
        
    # Check for Cilium
    elif kubectl get pods -n kube-system | grep -q cilium; then
        echo "Analyzing Cilium networking..."
        
        echo "Cilium pods status:"
        kubectl get pods -n kube-system -l k8s-app=cilium -o wide
        echo
        
        echo "Cilium endpoints:"
        kubectl get cep --all-namespaces 2>/dev/null | head -10 || echo "Cannot access Cilium endpoints"
        echo
        
    else
        echo "CNI plugin not clearly identified or supported for detailed analysis"
    fi
}

# Функция для создания network troubleshooting guide
create_network_troubleshooting_guide() {
    echo "=== Creating Network Troubleshooting Guide ==="
    
    cat << TROUBLESHOOTING_GUIDE_EOF > pod-to-pod-troubleshooting-guide.md
# Pod-to-Pod Networking Troubleshooting Guide

## 🔍 **Common Issues and Solutions**

### **Issue 1: Pods Cannot Reach Each Other**

#### **Symptoms:**
- Ping fails between pods on different nodes
- Application connectivity issues
- Timeouts in inter-pod communication

#### **Diagnosis Steps:**
\`\`\`bash
# Check pod IPs and nodes
kubectl get pods -o wide

# Test basic connectivity
kubectl exec <pod1> -- ping <pod2-ip>

# Check routing
kubectl exec <pod> -- ip route show

# Verify CNI plugin status
kubectl get pods -n kube-system | grep -E "(calico|flannel|cilium|weave)"
\`\`\`

#### **Common Causes:**
1. **CNI plugin issues**
2. **Network policies blocking traffic**
3. **Node-to-node connectivity problems**
4. **Firewall rules**
5. **Incorrect CIDR configuration**

### **Issue 2: Intermittent Connectivity**

#### **Symptoms:**
- Sporadic connection failures
- High latency between pods
- Packet loss

#### **Diagnosis Steps:**
\`\`\`bash
# Monitor connectivity over time
while true; do
  kubectl exec <pod1> -- ping -c 1 <pod2-ip>
  sleep 1
done

# Check network interface statistics
kubectl exec <pod> -- cat /proc/net/dev

# Monitor CNI plugin logs
kubectl logs -n kube-system <cni-pod> -f
\`\`\`

### **Issue 3: DNS Resolution Problems**

#### **Symptoms:**
- Cannot resolve service names
- DNS timeouts
- Service discovery failures

#### **Diagnosis Steps:**
\`\`\`bash
# Test DNS resolution
kubectl exec <pod> -- nslookup kubernetes.default

# Check CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Verify DNS configuration
kubectl exec <pod> -- cat /etc/resolv.conf
\`\`\`

## 🔧 **Network Flow Analysis**

### **1. Pod Creation Network Flow**
\`\`\`
1. kubelet creates pod
2. Container runtime calls CNI
3. CNI plugin allocates IP
4. Network interface created
5. Routes configured
6. Pod becomes ready
\`\`\`

### **2. Cross-Node Communication Flow**
\`\`\`
Pod A (Node 1) → Node 1 routing → Network fabric → Node 2 routing → Pod B (Node 2)
\`\`\`

### **3. Overlay vs Underlay Networks**

#### **Overlay Networks (VXLAN/GRE):**
- Encapsulation adds overhead
- Works across any IP network
- Examples: Flannel VXLAN, Weave

#### **Underlay Networks (BGP/Direct):**
- No encapsulation overhead
- Requires L3 connectivity
- Examples: Calico BGP, Flannel host-gw

## 🛠️ **Troubleshooting Tools**

### **Network Connectivity Testing:**
\`\`\`bash
# Basic ping test
kubectl exec <pod> -- ping <target-ip>

# TCP connectivity test
kubectl exec <pod> -- nc -zv <target-ip> <port>

# Traceroute
kubectl exec <pod> -- traceroute <target-ip>

# Performance testing
kubectl exec <pod> -- iperf3 -c <target-ip>
\`\`\`

### **Network Interface Analysis:**
\`\`\`bash
# Show interfaces
kubectl exec <pod> -- ip addr show

# Show routes
kubectl exec <pod> -- ip route show

# Show ARP table
kubectl exec <pod> -- arp -a

# Show network statistics
kubectl exec <pod> -- ss -tuln
\`\`\`

### **CNI Plugin Specific Tools:**

#### **Calico:**
\`\`\`bash
# Check node status
calicoctl node status

# Show routes
calicoctl get ippool

# Check BGP peers
calicoctl get bgppeer
\`\`\`

#### **Flannel:**
\`\`\`bash
# Check subnet allocation
cat /run/flannel/subnet.env

# Show bridge configuration
brctl show
\`\`\`

## 📊 **Performance Optimization**

### **1. Network Performance Tuning**
- Choose appropriate CNI plugin
- Optimize MTU settings
- Configure CPU affinity
- Use SR-IOV for high performance

### **2. Monitoring and Alerting**
- Monitor network latency
- Track packet loss
- Alert on connectivity failures
- Monitor CNI plugin health

TROUBLESHOOTING_GUIDE_EOF
    
    echo "✅ Network troubleshooting guide created: pod-to-pod-troubleshooting-guide.md"
    echo
}

# Функция для cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up test resources ==="
    kubectl delete namespace cross-node-test --ignore-not-found=true
    echo "✅ Test resources cleaned up"
}

# Основная функция
main() {
    case "$1" in
        "topology")
            analyze_cluster_network_topology
            ;;
        "create-pods")
            create_cross_node_test_pods
            ;;
        "test-connectivity")
            test_pod_to_pod_connectivity
            ;;
        "routes")
            analyze_network_routes
            ;;
        "cni-analysis")
            analyze_cni_specific_networking
            ;;
        "troubleshoot")
            create_network_troubleshooting_guide
            ;;
        "cleanup")
            cleanup_test_resources
            ;;
        "all"|"")
            analyze_cluster_network_topology
            create_cross_node_test_pods
            test_pod_to_pod_connectivity
            analyze_network_routes
            analyze_cni_specific_networking
            create_network_troubleshooting_guide
            ;;
        *)
            echo "Usage: $0 [topology|create-pods|test-connectivity|routes|cni-analysis|troubleshoot|cleanup|all]"
            echo ""
            echo "Pod-to-Pod Networking Analysis Options:"
            echo "  topology         - Analyze cluster network topology"
            echo "  create-pods      - Create test pods on different nodes"
            echo "  test-connectivity - Test pod-to-pod connectivity"
            echo "  routes           - Analyze network routes"
            echo "  cni-analysis     - CNI-specific networking analysis"
            echo "  troubleshoot     - Create troubleshooting guide"
            echo "  cleanup          - Clean up test resources"
            ;;
    esac
}

main "$@"

EOF

chmod +x pod-to-pod-networking-toolkit.sh
./pod-to-pod-networking-toolkit.sh all
```

## 🎯 **Механизм Pod-to-Pod networking:**

### **1. Сетевая модель Kubernetes:**
```bash
# Проверка сетевой топологии
kubectl get nodes -o wide

# Pod CIDR на каждом узле
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# Cluster CIDR
kubectl cluster-info dump | grep cluster-cidr
```

### **2. Процесс создания pod network:**
```bash
# 1. kubelet создает pod
# 2. Container runtime вызывает CNI
# 3. CNI plugin выделяет IP адрес
# 4. Создается network interface
# 5. Настраивается маршрутизация
```

### **3. Межузловая маршрутизация:**
```bash
# Проверка маршрутов на узле
ip route show

# Проверка сетевых интерфейсов
ip addr show

# Проверка ARP таблицы
arp -a
```

## 🔧 **Различные подходы к межузловой сети:**

### **1. Overlay Networks (VXLAN/GRE):**
```yaml
# Flannel VXLAN конфигурация
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
data:
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan",
        "VNI": 1
      }
    }
```

**Характеристики:**
- ✅ Работает через любую IP сеть
- ✅ Простая настройка
- ❌ Overhead от инкапсуляции
- ❌ Дополнительная нагрузка на CPU

### **2. Native Routing (BGP):**
```yaml
# Calico BGP конфигурация
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true
  asNumber: 64512
```

**Характеристики:**
- ✅ Нет overhead от инкапсуляции
- ✅ Высокая производительность
- ❌ Требует L3 connectivity
- ❌ Сложная конфигурация BGP

### **3. Host Gateway Mode:**
```yaml
# Flannel host-gw конфигурация
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
data:
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "host-gw"
      }
    }
```

**Характеристики:**
- ✅ Высокая производительность
- ✅ Простая маршрутизация
- ❌ Требует L2 connectivity
- ❌ Ограничения масштабируемости

## 🌐 **Тестирование межузловой связности:**

### **Создание тестовых pods:**
```bash
# Pod на первом узле
kubectl run test-pod-1 --image=busybox:1.28 --command -- sleep 3600 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"node1"}}}'

# Pod на втором узле
kubectl run test-pod-2 --image=busybox:1.28 --command -- sleep 3600 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"node2"}}}'
```

### **Тестирование connectivity:**
```bash
# Получить IP адреса pods
POD1_IP=$(kubectl get pod test-pod-1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod test-pod-2 -o jsonpath='{.status.podIP}')

# Тест ping между pods
kubectl exec test-pod-1 -- ping -c 3 $POD2_IP
kubectl exec test-pod-2 -- ping -c 3 $POD1_IP

# Тест TCP connectivity
kubectl exec test-pod-1 -- nc -zv $POD2_IP 80
```

### **Анализ сетевых маршрутов:**
```bash
# Маршруты в pod
kubectl exec test-pod-1 -- ip route show

# Сетевые интерфейсы в pod
kubectl exec test-pod-1 -- ip addr show

# DNS конфигурация
kubectl exec test-pod-1 -- cat /etc/resolv.conf
```

**Pod-to-Pod networking - основа микросервисной архитектуры в Kubernetes!**
