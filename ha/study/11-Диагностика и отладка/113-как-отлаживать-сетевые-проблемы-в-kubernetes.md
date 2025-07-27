# 113. Как отлаживать сетевые проблемы в Kubernetes

## 🎯 **Как отлаживать сетевые проблемы в Kubernetes**

**Сетевые проблемы** в Kubernetes могут быть сложными для диагностики из-за многослойной архитектуры. Понимание сетевой модели и методов troubleshooting критически важно для поддержания работоспособности кластера.

## 🌐 **Основные компоненты сети Kubernetes:**

### **1. Pod-to-Pod Communication:**
- **CNI (Container Network Interface)** - сетевой плагин
- **Pod CIDR** - диапазон IP адресов для pods
- **Overlay Network** - виртуальная сеть поверх физической

### **2. Service Networking:**
- **ClusterIP** - внутренний IP сервиса
- **kube-proxy** - маршрутизация трафика к pods
- **iptables/IPVS** - правила балансировки нагрузки

### **3. Ingress & External Access:**
- **Ingress Controller** - управление внешним трафиком
- **LoadBalancer** - внешний балансировщик
- **NodePort** - доступ через порты узлов

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive network troubleshooting toolkit
cat << 'EOF' > network-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== Network Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing network issues in HashFoundry HA cluster"
echo

# Функция для проверки базовой сетевой конфигурации
check_basic_network_config() {
    echo "=== Basic Network Configuration Check ==="
    
    echo "1. Cluster Network Information:"
    kubectl cluster-info
    echo
    
    echo "2. Node Network Status:"
    kubectl get nodes -o wide
    echo
    
    echo "3. CNI Plugin Information:"
    kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium)" || echo "CNI pods not found in kube-system"
    echo
    
    echo "4. Network Policies:"
    kubectl get networkpolicies --all-namespaces
    echo
    
    echo "5. Services Overview:"
    kubectl get services --all-namespaces -o wide
    echo
}

# Функция для диагностики pod-to-pod connectivity
diagnose_pod_to_pod() {
    echo "=== Pod-to-Pod Connectivity Diagnosis ==="
    
    echo "1. Create test pods for connectivity testing:"
    cat << TEST_PODS_EOF > network-test-pods.yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-test-client
  namespace: default
  labels:
    app: network-test
    role: client
spec:
  containers:
  - name: client
    image: busybox:1.28
    command: ['sleep', '3600']
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
---
apiVersion: v1
kind: Pod
metadata:
  name: network-test-server
  namespace: default
  labels:
    app: network-test
    role: server
spec:
  containers:
  - name: server
    image: nginx:1.21
    ports:
    - containerPort: 80
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: network-test-service
  namespace: default
spec:
  selector:
    app: network-test
    role: server
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
TEST_PODS_EOF
    
    echo "✅ Test pods configuration created: network-test-pods.yaml"
    echo "Apply with: kubectl apply -f network-test-pods.yaml"
    echo
    
    echo "2. Pod-to-Pod connectivity tests:"
    cat << POD_TO_POD_TESTS_EOF
# Test direct pod IP connectivity
kubectl exec network-test-client -- ping -c 3 <server-pod-ip>

# Test service connectivity
kubectl exec network-test-client -- wget -qO- http://network-test-service

# Test DNS resolution
kubectl exec network-test-client -- nslookup network-test-service

# Test cross-namespace connectivity
kubectl exec network-test-client -- ping -c 3 <pod-ip-in-other-namespace>

POD_TO_POD_TESTS_EOF
    echo
}

# Функция для диагностики DNS проблем
diagnose_dns_issues() {
    echo "=== DNS Issues Diagnosis ==="
    
    echo "1. CoreDNS Status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    echo
    
    echo "2. CoreDNS Configuration:"
    kubectl get configmap coredns -n kube-system -o yaml
    echo
    
    echo "3. DNS Resolution Tests:"
    cat << DNS_TESTS_EOF
# Test DNS from pod
kubectl exec network-test-client -- nslookup kubernetes.default.svc.cluster.local

# Test external DNS
kubectl exec network-test-client -- nslookup google.com

# Test service DNS
kubectl exec network-test-client -- nslookup network-test-service.default.svc.cluster.local

# Check DNS configuration in pod
kubectl exec network-test-client -- cat /etc/resolv.conf

DNS_TESTS_EOF
    echo
    
    echo "4. Create DNS debug pod:"
    cat << DNS_DEBUG_POD_EOF > dns-debug-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-debug
  namespace: default
spec:
  containers:
  - name: debug
    image: busybox:1.28
    command: ['sleep', '3600']
    env:
    - name: DEBUG_DNS
      value: "true"
  dnsPolicy: Default
  restartPolicy: Never
DNS_DEBUG_POD_EOF
    
    echo "✅ DNS debug pod created: dns-debug-pod.yaml"
    echo
}

# Функция для диагностики service connectivity
diagnose_service_connectivity() {
    echo "=== Service Connectivity Diagnosis ==="
    
    echo "1. Service Endpoints Check:"
    kubectl get endpoints --all-namespaces
    echo
    
    echo "2. Service to Pod mapping:"
    cat << SERVICE_DEBUG_EOF
# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Check service selector
kubectl get service <service-name> -n <namespace> -o yaml

# Check pods matching selector
kubectl get pods -n <namespace> -l <selector-labels>

# Test service from within cluster
kubectl exec <test-pod> -- curl http://<service-name>.<namespace>.svc.cluster.local

SERVICE_DEBUG_EOF
    echo
    
    echo "3. kube-proxy Status:"
    kubectl get pods -n kube-system | grep kube-proxy
    echo
    
    echo "4. iptables rules check (run on nodes):"
    cat << IPTABLES_CHECK_EOF
# Check iptables rules for services
sudo iptables -t nat -L | grep <service-name>

# Check IPVS rules (if using IPVS mode)
sudo ipvsadm -L -n

# Check kube-proxy logs
kubectl logs -n kube-system <kube-proxy-pod>

IPTABLES_CHECK_EOF
    echo
}

# Функция для диагностики ingress проблем
diagnose_ingress_issues() {
    echo "=== Ingress Issues Diagnosis ==="
    
    echo "1. Ingress Controller Status:"
    kubectl get pods -n ingress-nginx || kubectl get pods -n kube-system | grep ingress
    echo
    
    echo "2. Ingress Resources:"
    kubectl get ingress --all-namespaces
    echo
    
    echo "3. Ingress Controller Logs:"
    echo "kubectl logs -n ingress-nginx deployment/ingress-nginx-controller"
    echo
    
    echo "4. Test Ingress Configuration:"
    cat << INGRESS_TEST_EOF > test-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: test.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: network-test-service
            port:
              number: 80
INGRESS_TEST_EOF
    
    echo "✅ Test ingress created: test-ingress.yaml"
    echo
    
    echo "5. Ingress troubleshooting commands:"
    cat << INGRESS_TROUBLESHOOT_EOF
# Check ingress controller service
kubectl get service -n ingress-nginx

# Test ingress from outside
curl -H "Host: test.hashfoundry.local" http://<ingress-ip>/

# Check ingress controller configuration
kubectl exec -n ingress-nginx <controller-pod> -- cat /etc/nginx/nginx.conf

INGRESS_TROUBLESHOOT_EOF
    echo
}

# Функция для диагностики network policies
diagnose_network_policies() {
    echo "=== Network Policies Diagnosis ==="
    
    echo "1. Current Network Policies:"
    kubectl get networkpolicies --all-namespaces -o wide
    echo
    
    echo "2. Test Network Policy:"
    cat << NETWORK_POLICY_TEST_EOF > test-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: network-test
      role: server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: network-test
          role: client
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
NETWORK_POLICY_TEST_EOF
    
    echo "✅ Test network policy created: test-network-policy.yaml"
    echo
    
    echo "3. Network Policy troubleshooting:"
    cat << NP_TROUBLESHOOT_EOF
# Check if CNI supports network policies
kubectl get pods -n kube-system | grep -E "(calico|cilium)"

# Test connectivity before applying policy
kubectl exec network-test-client -- wget -qO- http://network-test-service

# Apply policy and test again
kubectl apply -f test-network-policy.yaml
kubectl exec network-test-client -- wget -qO- http://network-test-service

# Check policy logs (Calico example)
kubectl logs -n kube-system <calico-node-pod>

NP_TROUBLESHOOT_EOF
    echo
}

# Функция для создания comprehensive network test
create_comprehensive_network_test() {
    echo "=== Creating Comprehensive Network Test ==="
    
    cat << COMPREHENSIVE_TEST_EOF > comprehensive-network-test.sh
#!/bin/bash

echo "=== Comprehensive Network Test for HashFoundry HA Cluster ==="
echo

# Function to test pod-to-pod connectivity
test_pod_connectivity() {
    echo "1. Testing Pod-to-Pod Connectivity..."
    
    # Get pod IPs
    CLIENT_POD=\$(kubectl get pod network-test-client -o jsonpath='{.status.podIP}')
    SERVER_POD=\$(kubectl get pod network-test-server -o jsonpath='{.status.podIP}')
    
    echo "Client Pod IP: \$CLIENT_POD"
    echo "Server Pod IP: \$SERVER_POD"
    
    # Test ping
    echo "Testing ping from client to server:"
    kubectl exec network-test-client -- ping -c 3 \$SERVER_POD
    
    # Test HTTP
    echo "Testing HTTP from client to server:"
    kubectl exec network-test-client -- wget -qO- http://\$SERVER_POD
    echo
}

# Function to test service connectivity
test_service_connectivity() {
    echo "2. Testing Service Connectivity..."
    
    # Test service by name
    echo "Testing service by name:"
    kubectl exec network-test-client -- wget -qO- http://network-test-service
    
    # Test service by FQDN
    echo "Testing service by FQDN:"
    kubectl exec network-test-client -- wget -qO- http://network-test-service.default.svc.cluster.local
    echo
}

# Function to test DNS resolution
test_dns_resolution() {
    echo "3. Testing DNS Resolution..."
    
    # Test internal DNS
    echo "Testing internal DNS:"
    kubectl exec network-test-client -- nslookup kubernetes.default.svc.cluster.local
    
    # Test external DNS
    echo "Testing external DNS:"
    kubectl exec network-test-client -- nslookup google.com
    
    # Test service DNS
    echo "Testing service DNS:"
    kubectl exec network-test-client -- nslookup network-test-service.default.svc.cluster.local
    echo
}

# Function to test cross-namespace connectivity
test_cross_namespace() {
    echo "4. Testing Cross-Namespace Connectivity..."
    
    # Create test pod in kube-system namespace
    kubectl run test-pod-kube-system --image=nginx:1.21 -n kube-system --restart=Never
    
    # Wait for pod to be ready
    kubectl wait --for=condition=Ready pod/test-pod-kube-system -n kube-system --timeout=60s
    
    # Get pod IP
    KUBE_SYSTEM_POD=\$(kubectl get pod test-pod-kube-system -n kube-system -o jsonpath='{.status.podIP}')
    
    echo "Testing connectivity to kube-system pod (\$KUBE_SYSTEM_POD):"
    kubectl exec network-test-client -- ping -c 3 \$KUBE_SYSTEM_POD
    
    # Cleanup
    kubectl delete pod test-pod-kube-system -n kube-system
    echo
}

# Function to test external connectivity
test_external_connectivity() {
    echo "5. Testing External Connectivity..."
    
    # Test external ping
    echo "Testing external ping:"
    kubectl exec network-test-client -- ping -c 3 8.8.8.8
    
    # Test external HTTP
    echo "Testing external HTTP:"
    kubectl exec network-test-client -- wget -qO- http://httpbin.org/ip
    echo
}

# Main execution
main() {
    echo "Starting comprehensive network test..."
    echo "Make sure test pods are running: kubectl apply -f network-test-pods.yaml"
    echo
    
    # Wait for pods to be ready
    kubectl wait --for=condition=Ready pod/network-test-client --timeout=60s
    kubectl wait --for=condition=Ready pod/network-test-server --timeout=60s
    
    test_pod_connectivity
    test_service_connectivity
    test_dns_resolution
    test_cross_namespace
    test_external_connectivity
    
    echo "Network test completed!"
}

main

COMPREHENSIVE_TEST_EOF
    
    chmod +x comprehensive-network-test.sh
    echo "✅ Comprehensive network test created: comprehensive-network-test.sh"
    echo
}

# Функция для мониторинга сетевых проблем
monitor_network_issues() {
    echo "=== Network Issues Monitoring ==="
    
    echo "1. Real-time network monitoring script:"
    cat << MONITOR_SCRIPT_EOF > monitor-network-issues.sh
#!/bin/bash

echo "=== Network Issues Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Pods with network issues:"
    kubectl get pods --all-namespaces | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" || echo "No problematic pods"
    echo
    
    echo "Services without endpoints:"
    kubectl get endpoints --all-namespaces | grep "<none>" || echo "All services have endpoints"
    echo
    
    echo "CoreDNS status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | awk '{print \$1 " " \$3}'
    echo
    
    echo "Ingress controller status:"
    kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | awk '{print \$1 " " \$3}' || echo "Ingress controller not found"
    echo
    
    sleep 10
done

MONITOR_SCRIPT_EOF
    
    chmod +x monitor-network-issues.sh
    echo "✅ Network monitoring script created: monitor-network-issues.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "basic")
            check_basic_network_config
            ;;
        "pod-to-pod")
            diagnose_pod_to_pod
            ;;
        "dns")
            diagnose_dns_issues
            ;;
        "service")
            diagnose_service_connectivity
            ;;
        "ingress")
            diagnose_ingress_issues
            ;;
        "policies")
            diagnose_network_policies
            ;;
        "test")
            create_comprehensive_network_test
            ;;
        "monitor")
            monitor_network_issues
            ;;
        "all"|"")
            check_basic_network_config
            diagnose_pod_to_pod
            diagnose_dns_issues
            diagnose_service_connectivity
            diagnose_ingress_issues
            diagnose_network_policies
            create_comprehensive_network_test
            monitor_network_issues
            ;;
        *)
            echo "Usage: $0 [basic|pod-to-pod|dns|service|ingress|policies|test|monitor|all]"
            echo ""
            echo "Network Troubleshooting Options:"
            echo "  basic      - Check basic network configuration"
            echo "  pod-to-pod - Diagnose pod-to-pod connectivity"
            echo "  dns        - Diagnose DNS issues"
            echo "  service    - Diagnose service connectivity"
            echo "  ingress    - Diagnose ingress issues"
            echo "  policies   - Diagnose network policies"
            echo "  test       - Create comprehensive network test"
            echo "  monitor    - Monitor network issues"
            ;;
    esac
}

main "$@"

EOF

chmod +x network-troubleshooting-toolkit.sh
./network-troubleshooting-toolkit.sh all
```

## 🎯 **Пошаговая диагностика сетевых проблем:**

### **Шаг 1: Базовая проверка**
```bash
# Статус кластера
kubectl cluster-info

# Статус узлов
kubectl get nodes -o wide

# CNI pods
kubectl get pods -n kube-system | grep -E "(calico|flannel|weave)"
```

### **Шаг 2: Pod-to-Pod connectivity**
```bash
# Создать тестовые pods
kubectl apply -f network-test-pods.yaml

# Тест ping между pods
kubectl exec network-test-client -- ping <server-pod-ip>

# Тест HTTP
kubectl exec network-test-client -- wget -qO- http://<server-pod-ip>
```

### **Шаг 3: Service connectivity**
```bash
# Проверить endpoints
kubectl get endpoints

# Тест service
kubectl exec network-test-client -- wget -qO- http://network-test-service

# Проверить kube-proxy
kubectl get pods -n kube-system | grep kube-proxy
```

### **Шаг 4: DNS resolution**
```bash
# Тест внутреннего DNS
kubectl exec network-test-client -- nslookup kubernetes.default.svc.cluster.local

# Тест внешнего DNS
kubectl exec network-test-client -- nslookup google.com

# Проверить CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

## 🔧 **Частые сетевые проблемы и решения:**

### **1. Pod не может подключиться к другому Pod:**
- Проверить CNI plugin
- Проверить network policies
- Проверить firewall правила

### **2. Service недоступен:**
- Проверить endpoints
- Проверить selector labels
- Проверить kube-proxy

### **3. DNS не работает:**
- Проверить CoreDNS pods
- Проверить DNS configuration
- Проверить network policies для DNS

### **4. Ingress не работает:**
- Проверить ingress controller
- Проверить ingress rules
- Проверить DNS записи

**Систематический подход к диагностике сети экономит время и нервы!**
