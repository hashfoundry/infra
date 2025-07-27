# 115. Как устранять проблемы с DNS в Kubernetes

## 🎯 **Как устранять проблемы с DNS в Kubernetes**

**DNS проблемы** в Kubernetes могут серьезно нарушить работу приложений, так как большинство сервисов полагаются на DNS для обнаружения друг друга. Понимание DNS архитектуры и методов troubleshooting критически важно.

## 🌐 **DNS архитектура в Kubernetes:**

### **1. CoreDNS Components:**
- **CoreDNS pods** - основной DNS сервер
- **kube-dns service** - ClusterIP для DNS
- **DNS policy** - политика DNS для pods
- **Search domains** - домены поиска

### **2. DNS Resolution Flow:**
- **Pod → CoreDNS** - запрос DNS от pod
- **CoreDNS → Upstream** - внешние DNS запросы
- **Service Discovery** - разрешение имен сервисов
- **FQDN Resolution** - полные доменные имена

### **3. DNS Records Types:**
- **A records** - IP адреса сервисов
- **SRV records** - порты сервисов
- **PTR records** - обратное разрешение
- **CNAME records** - алиасы

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive DNS troubleshooting toolkit
cat << 'EOF' > dns-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== DNS Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing DNS issues in HashFoundry HA cluster"
echo

# Функция для проверки CoreDNS статуса
check_coredns_status() {
    echo "=== CoreDNS Status Check ==="
    
    echo "1. CoreDNS Pods Status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
    echo
    
    echo "2. CoreDNS Service:"
    kubectl get service -n kube-system kube-dns
    echo
    
    echo "3. CoreDNS Endpoints:"
    kubectl get endpoints -n kube-system kube-dns
    echo
    
    echo "4. CoreDNS Configuration:"
    kubectl get configmap coredns -n kube-system -o yaml
    echo
    
    echo "5. CoreDNS Logs:"
    echo "Recent CoreDNS logs:"
    kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
    echo
}

# Функция для создания DNS test pod
create_dns_test_pod() {
    echo "=== Creating DNS Test Pod ==="
    
    cat << DNS_TEST_POD_EOF > dns-test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-test
  namespace: default
  labels:
    app: dns-test
spec:
  containers:
  - name: dns-test
    image: busybox:1.28
    command: ['sleep', '3600']
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
      limits:
        cpu: "100m"
        memory: "128Mi"
  dnsPolicy: ClusterFirst
  restartPolicy: Never
DNS_TEST_POD_EOF
    
    echo "✅ DNS test pod configuration created: dns-test-pod.yaml"
    echo "Apply with: kubectl apply -f dns-test-pod.yaml"
    echo
    
    # Apply the pod
    kubectl apply -f dns-test-pod.yaml
    echo "Waiting for DNS test pod to be ready..."
    kubectl wait --for=condition=Ready pod/dns-test --timeout=60s
    echo
}

# Функция для тестирования DNS resolution
test_dns_resolution() {
    echo "=== DNS Resolution Tests ==="
    
    echo "1. Test Kubernetes internal DNS:"
    echo "Testing kubernetes.default.svc.cluster.local:"
    kubectl exec dns-test -- nslookup kubernetes.default.svc.cluster.local
    echo
    
    echo "2. Test service DNS resolution:"
    echo "Testing kube-dns.kube-system.svc.cluster.local:"
    kubectl exec dns-test -- nslookup kube-dns.kube-system.svc.cluster.local
    echo
    
    echo "3. Test external DNS resolution:"
    echo "Testing google.com:"
    kubectl exec dns-test -- nslookup google.com
    echo
    
    echo "4. Test short service names:"
    echo "Testing kubernetes (short name):"
    kubectl exec dns-test -- nslookup kubernetes
    echo
    
    echo "5. Check DNS configuration in pod:"
    echo "DNS configuration (/etc/resolv.conf):"
    kubectl exec dns-test -- cat /etc/resolv.conf
    echo
}

# Функция для диагностики DNS проблем
diagnose_dns_issues() {
    echo "=== DNS Issues Diagnosis ==="
    
    echo "1. Check DNS service IP:"
    DNS_SERVICE_IP=$(kubectl get service kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
    echo "DNS Service IP: $DNS_SERVICE_IP"
    echo
    
    echo "2. Test DNS service connectivity:"
    echo "Testing connectivity to DNS service ($DNS_SERVICE_IP:53):"
    kubectl exec dns-test -- nc -zv $DNS_SERVICE_IP 53
    echo
    
    echo "3. Test DNS queries directly:"
    echo "Direct DNS query to CoreDNS:"
    kubectl exec dns-test -- dig @$DNS_SERVICE_IP kubernetes.default.svc.cluster.local
    echo
    
    echo "4. Check DNS policy:"
    echo "Pod DNS policy:"
    kubectl get pod dns-test -o jsonpath='{.spec.dnsPolicy}'
    echo
    echo
    
    echo "5. Check search domains:"
    echo "Search domains in pod:"
    kubectl exec dns-test -- grep search /etc/resolv.conf
    echo
}

# Функция для тестирования различных DNS policies
test_dns_policies() {
    echo "=== Testing Different DNS Policies ==="
    
    echo "1. ClusterFirst DNS Policy (default):"
    cat << CLUSTERFIRST_POD_EOF > dns-test-clusterfirst.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-clusterfirst
  namespace: default
spec:
  containers:
  - name: test
    image: busybox:1.28
    command: ['sleep', '3600']
  dnsPolicy: ClusterFirst
  restartPolicy: Never
CLUSTERFIRST_POD_EOF
    
    echo "✅ ClusterFirst DNS test pod: dns-test-clusterfirst.yaml"
    echo
    
    echo "2. Default DNS Policy:"
    cat << DEFAULT_POD_EOF > dns-test-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-default
  namespace: default
spec:
  containers:
  - name: test
    image: busybox:1.28
    command: ['sleep', '3600']
  dnsPolicy: Default
  restartPolicy: Never
DEFAULT_POD_EOF
    
    echo "✅ Default DNS test pod: dns-test-default.yaml"
    echo
    
    echo "3. Custom DNS Configuration:"
    cat << CUSTOM_DNS_POD_EOF > dns-test-custom.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-custom
  namespace: default
spec:
  containers:
  - name: test
    image: busybox:1.28
    command: ['sleep', '3600']
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 8.8.8.8
    - 1.1.1.1
    searches:
    - default.svc.cluster.local
    - svc.cluster.local
    - cluster.local
    options:
    - name: ndots
      value: "2"
    - name: edns0
  restartPolicy: Never
CUSTOM_DNS_POD_EOF
    
    echo "✅ Custom DNS test pod: dns-test-custom.yaml"
    echo
}

# Функция для мониторинга DNS performance
monitor_dns_performance() {
    echo "=== DNS Performance Monitoring ==="
    
    echo "1. DNS query timing test:"
    cat << DNS_TIMING_TEST_EOF > dns-timing-test.sh
#!/bin/bash

echo "=== DNS Timing Test ==="
echo

# Function to time DNS queries
time_dns_query() {
    local QUERY=\$1
    local ITERATIONS=\${2:-10}
    
    echo "Testing \$QUERY (\$ITERATIONS iterations):"
    
    for i in \$(seq 1 \$ITERATIONS); do
        START=\$(date +%s%N)
        kubectl exec dns-test -- nslookup \$QUERY > /dev/null 2>&1
        END=\$(date +%s%N)
        DURATION=\$(( (END - START) / 1000000 ))
        echo "Query \$i: \${DURATION}ms"
    done
    echo
}

# Test various DNS queries
time_dns_query "kubernetes.default.svc.cluster.local" 5
time_dns_query "kube-dns.kube-system.svc.cluster.local" 5
time_dns_query "google.com" 5

DNS_TIMING_TEST_EOF
    
    chmod +x dns-timing-test.sh
    echo "✅ DNS timing test script created: dns-timing-test.sh"
    echo
    
    echo "2. DNS monitoring with Prometheus queries:"
    cat << DNS_PROMETHEUS_QUERIES_EOF
# CoreDNS request rate
rate(coredns_dns_requests_total[5m])

# CoreDNS request duration
histogram_quantile(0.95, rate(coredns_dns_request_duration_seconds_bucket[5m]))

# CoreDNS errors
rate(coredns_dns_responses_total{rcode!="NOERROR"}[5m])

# CoreDNS cache hits
rate(coredns_cache_hits_total[5m]) / rate(coredns_dns_requests_total[5m])

DNS_PROMETHEUS_QUERIES_EOF
    echo
}

# Функция для создания DNS debugging scenarios
create_dns_debugging_scenarios() {
    echo "=== Creating DNS Debugging Scenarios ==="
    
    echo "1. Scenario: Service with no endpoints"
    cat << NO_ENDPOINTS_SERVICE_EOF > dns-test-no-endpoints.yaml
apiVersion: v1
kind: Service
metadata:
  name: test-service-no-endpoints
  namespace: default
spec:
  selector:
    app: nonexistent-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
NO_ENDPOINTS_SERVICE_EOF
    
    echo "✅ Service with no endpoints: dns-test-no-endpoints.yaml"
    echo
    
    echo "2. Scenario: Cross-namespace service access"
    cat << CROSS_NAMESPACE_TEST_EOF > dns-test-cross-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dns-test-namespace
---
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-server
  namespace: dns-test-namespace
  labels:
    app: dns-test-server
spec:
  containers:
  - name: server
    image: nginx:1.21
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: dns-test-service
  namespace: dns-test-namespace
spec:
  selector:
    app: dns-test-server
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
CROSS_NAMESPACE_TEST_EOF
    
    echo "✅ Cross-namespace test: dns-test-cross-namespace.yaml"
    echo
    
    echo "3. Test commands for scenarios:"
    cat << SCENARIO_TESTS_EOF
# Test service with no endpoints
kubectl apply -f dns-test-no-endpoints.yaml
kubectl exec dns-test -- nslookup test-service-no-endpoints.default.svc.cluster.local

# Test cross-namespace access
kubectl apply -f dns-test-cross-namespace.yaml
kubectl exec dns-test -- nslookup dns-test-service.dns-test-namespace.svc.cluster.local

# Test short names vs FQDN
kubectl exec dns-test -- nslookup dns-test-service
kubectl exec dns-test -- nslookup dns-test-service.dns-test-namespace

SCENARIO_TESTS_EOF
    echo
}

# Функция для автоматического исправления DNS проблем
auto_fix_dns_issues() {
    echo "=== Auto-fix DNS Issues ==="
    
    echo "1. Common DNS fixes:"
    cat << DNS_FIXES_EOF
# Restart CoreDNS pods
kubectl rollout restart deployment/coredns -n kube-system

# Check CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Verify DNS service
kubectl get service kube-dns -n kube-system

# Check DNS endpoints
kubectl get endpoints kube-dns -n kube-system

# Test DNS from node
dig @<coredns-pod-ip> kubernetes.default.svc.cluster.local

DNS_FIXES_EOF
    echo
    
    echo "2. CoreDNS configuration troubleshooting:"
    cat << COREDNS_CONFIG_EOF
# Default CoreDNS Corefile
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }

COREDNS_CONFIG_EOF
    echo
    
    echo "3. DNS debugging checklist:"
    cat << DNS_CHECKLIST_EOF > dns-debugging-checklist.md
# DNS Debugging Checklist

## ✅ **Step 1: Check CoreDNS Status**
- [ ] CoreDNS pods are running: \`kubectl get pods -n kube-system -l k8s-app=kube-dns\`
- [ ] CoreDNS service exists: \`kubectl get service kube-dns -n kube-system\`
- [ ] CoreDNS endpoints are available: \`kubectl get endpoints kube-dns -n kube-system\`

## ✅ **Step 2: Test Basic DNS Resolution**
- [ ] Internal service resolution: \`nslookup kubernetes.default.svc.cluster.local\`
- [ ] External DNS resolution: \`nslookup google.com\`
- [ ] Short name resolution: \`nslookup kubernetes\`

## ✅ **Step 3: Check DNS Configuration**
- [ ] Pod DNS policy: \`kubectl get pod <pod> -o jsonpath='{.spec.dnsPolicy}'\`
- [ ] DNS config in pod: \`kubectl exec <pod> -- cat /etc/resolv.conf\`
- [ ] Search domains are correct

## ✅ **Step 4: Network Connectivity**
- [ ] DNS service connectivity: \`nc -zv <dns-ip> 53\`
- [ ] CoreDNS pod connectivity: \`ping <coredns-pod-ip>\`
- [ ] Network policies allow DNS traffic

## ✅ **Step 5: Performance Issues**
- [ ] DNS query timing: measure response times
- [ ] CoreDNS resource usage: check CPU/memory
- [ ] DNS cache hit rate: monitor cache performance

## 🔧 **Common Solutions**
1. **CoreDNS not responding**: Restart CoreDNS deployment
2. **External DNS fails**: Check upstream DNS configuration
3. **Service resolution fails**: Verify service and endpoints
4. **Slow DNS queries**: Increase CoreDNS resources or cache TTL
5. **Cross-namespace issues**: Use FQDN or check network policies

DNS_CHECKLIST_EOF
    
    echo "✅ DNS debugging checklist created: dns-debugging-checklist.md"
    echo
}

# Основная функция
main() {
    case "$1" in
        "status")
            check_coredns_status
            ;;
        "create-test")
            create_dns_test_pod
            ;;
        "test")
            test_dns_resolution
            ;;
        "diagnose")
            diagnose_dns_issues
            ;;
        "policies")
            test_dns_policies
            ;;
        "performance")
            monitor_dns_performance
            ;;
        "scenarios")
            create_dns_debugging_scenarios
            ;;
        "fix")
            auto_fix_dns_issues
            ;;
        "all"|"")
            check_coredns_status
            create_dns_test_pod
            test_dns_resolution
            diagnose_dns_issues
            test_dns_policies
            monitor_dns_performance
            create_dns_debugging_scenarios
            auto_fix_dns_issues
            ;;
        *)
            echo "Usage: $0 [status|create-test|test|diagnose|policies|performance|scenarios|fix|all]"
            echo ""
            echo "DNS Troubleshooting Options:"
            echo "  status       - Check CoreDNS status"
            echo "  create-test  - Create DNS test pod"
            echo "  test         - Test DNS resolution"
            echo "  diagnose     - Diagnose DNS issues"
            echo "  policies     - Test different DNS policies"
            echo "  performance  - Monitor DNS performance"
            echo "  scenarios    - Create debugging scenarios"
            echo "  fix          - Auto-fix DNS issues"
            ;;
    esac
}

main "$@"

EOF

chmod +x dns-troubleshooting-toolkit.sh
./dns-troubleshooting-toolkit.sh all
```

## 🎯 **Пошаговая диагностика DNS проблем:**

### **Шаг 1: Проверить CoreDNS**
```bash
# Статус CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# CoreDNS service
kubectl get service kube-dns -n kube-system

# CoreDNS логи
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### **Шаг 2: Создать test pod**
```bash
# Создать DNS test pod
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- sleep 3600

# Проверить DNS конфигурацию в pod
kubectl exec dns-test -- cat /etc/resolv.conf
```

### **Шаг 3: Тестировать DNS resolution**
```bash
# Внутренний DNS
kubectl exec dns-test -- nslookup kubernetes.default.svc.cluster.local

# Внешний DNS
kubectl exec dns-test -- nslookup google.com

# Короткие имена
kubectl exec dns-test -- nslookup kubernetes
```

### **Шаг 4: Диагностировать проблемы**
```bash
# Проверить connectivity к DNS service
DNS_IP=$(kubectl get service kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
kubectl exec dns-test -- nc -zv $DNS_IP 53

# Прямой DNS запрос
kubectl exec dns-test -- dig @$DNS_IP kubernetes.default.svc.cluster.local
```

## 🔧 **Частые DNS проблемы и решения:**

### **1. CoreDNS pods не запускаются:**
```bash
# Проверить ресурсы
kubectl describe pods -n kube-system -l k8s-app=kube-dns

# Перезапустить CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

### **2. Внешний DNS не работает:**
```bash
# Проверить upstream DNS в CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Проверить forward настройки
```

### **3. Service resolution не работает:**
```bash
# Проверить service и endpoints
kubectl get service <service-name>
kubectl get endpoints <service-name>

# Проверить labels
kubectl get pods --show-labels
```

### **4. Медленные DNS запросы:**
```bash
# Увеличить cache TTL в CoreDNS
# Добавить больше ресурсов CoreDNS
# Проверить network latency
```

**Правильная диагностика DNS решает большинство проблем с service discovery!**
