# 127. Как устранять проблемы с DNS разрешением в Kubernetes

## 🎯 **Как устранять проблемы с DNS разрешением в Kubernetes**

**DNS troubleshooting** в Kubernetes - это критически важный навык, поскольку DNS является основой service discovery и межсервисной коммуникации. Проблемы с DNS могут привести к недоступности сервисов и нарушению работы приложений.

## 🌐 **Архитектура DNS в Kubernetes:**

### **1. CoreDNS Components:**
- **CoreDNS Pods** - основные DNS серверы
- **kube-dns Service** - ClusterIP для DNS запросов
- **DNS ConfigMap** - конфигурация CoreDNS
- **DNS Policy** - политики DNS для подов

### **2. DNS Resolution Flow:**
- **Pod DNS Config** - настройки DNS в поде
- **Search Domains** - домены поиска
- **Nameserver** - DNS серверы
- **FQDN Resolution** - разрешение полных доменных имен

### **3. Common DNS Issues:**
- **Service Discovery Failures** - сервисы не находятся
- **Slow DNS Resolution** - медленное разрешение
- **DNS Timeouts** - таймауты DNS запросов
- **NXDOMAIN Errors** - домен не найден

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive DNS troubleshooting toolkit
cat << 'EOF' > dns-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== DNS Troubleshooting Toolkit ==="
echo "Comprehensive guide for DNS troubleshooting in HashFoundry HA cluster"
echo

# Функция для анализа DNS инфраструктуры
analyze_dns_infrastructure() {
    echo "=== DNS Infrastructure Analysis ==="
    
    echo "1. CoreDNS Pods Status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
    echo
    
    echo "2. CoreDNS Service:"
    kubectl get service -n kube-system kube-dns -o wide
    echo
    
    echo "3. CoreDNS Endpoints:"
    kubectl get endpoints -n kube-system kube-dns
    echo
    
    echo "4. CoreDNS ConfigMap:"
    kubectl get configmap -n kube-system coredns -o yaml | grep -A 20 "Corefile:"
    echo
    
    echo "5. DNS Service ClusterIP:"
    DNS_SERVICE_IP=$(kubectl get service -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')
    echo "DNS Service IP: $DNS_SERVICE_IP"
    echo
    
    echo "6. Cluster DNS Domain:"
    CLUSTER_DOMAIN=$(kubectl get configmap -n kube-system coredns -o jsonpath='{.data.Corefile}' | grep -o 'cluster\.local' | head -1)
    echo "Cluster Domain: ${CLUSTER_DOMAIN:-cluster.local}"
    echo
}

# Функция для проверки DNS конфигурации подов
check_pod_dns_configuration() {
    echo "=== Pod DNS Configuration Analysis ==="
    
    echo "1. Create DNS test pod:"
    cat << DNS_TEST_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-pod
  namespace: default
spec:
  containers:
  - name: dns-test
    image: busybox:1.28
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "10m"
        memory: "16Mi"
  restartPolicy: Never
DNS_TEST_POD_EOF
    
    kubectl wait --for=condition=Ready pod/dns-test-pod --timeout=60s 2>/dev/null
    
    if kubectl get pod dns-test-pod >/dev/null 2>&1; then
        echo "2. Pod DNS configuration:"
        kubectl exec dns-test-pod -- cat /etc/resolv.conf
        echo
        
        echo "3. Pod hostname and domain:"
        kubectl exec dns-test-pod -- hostname
        kubectl exec dns-test-pod -- hostname -f 2>/dev/null || echo "FQDN not available"
        echo
        
        echo "4. DNS search domains:"
        kubectl exec dns-test-pod -- cat /etc/resolv.conf | grep search
        echo
        
        echo "5. Nameserver configuration:"
        kubectl exec dns-test-pod -- cat /etc/resolv.conf | grep nameserver
        echo
    else
        echo "❌ Failed to create DNS test pod"
    fi
}

# Функция для тестирования DNS разрешения
test_dns_resolution() {
    echo "=== DNS Resolution Testing ==="
    
    if kubectl get pod dns-test-pod >/dev/null 2>&1; then
        echo "1. Test internal service resolution:"
        
        # Test kubernetes service
        echo "Testing kubernetes.default.svc.cluster.local:"
        kubectl exec dns-test-pod -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "❌ Failed to resolve kubernetes service"
        echo
        
        # Test kube-dns service
        echo "Testing kube-dns.kube-system.svc.cluster.local:"
        kubectl exec dns-test-pod -- nslookup kube-dns.kube-system.svc.cluster.local 2>/dev/null || echo "❌ Failed to resolve kube-dns service"
        echo
        
        # Test short name resolution
        echo "Testing short name resolution (kubernetes):"
        kubectl exec dns-test-pod -- nslookup kubernetes 2>/dev/null || echo "❌ Failed to resolve short name"
        echo
        
        echo "2. Test external DNS resolution:"
        echo "Testing google.com:"
        kubectl exec dns-test-pod -- nslookup google.com 2>/dev/null || echo "❌ Failed to resolve external domain"
        echo
        
        echo "Testing 8.8.8.8 (Google DNS):"
        kubectl exec dns-test-pod -- nslookup google.com 8.8.8.8 2>/dev/null || echo "❌ Failed to resolve via external DNS"
        echo
        
        echo "3. Test reverse DNS lookup:"
        DNS_SERVICE_IP=$(kubectl get service -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')
        echo "Reverse lookup for DNS service IP ($DNS_SERVICE_IP):"
        kubectl exec dns-test-pod -- nslookup $DNS_SERVICE_IP 2>/dev/null || echo "❌ Reverse lookup failed"
        echo
        
        echo "4. Test DNS query timing:"
        echo "Timing DNS queries:"
        kubectl exec dns-test-pod -- time nslookup kubernetes.default.svc.cluster.local 2>&1 | grep real || echo "❌ Timing test failed"
        echo
    else
        echo "❌ DNS test pod not available"
    fi
}

# Функция для диагностики CoreDNS
diagnose_coredns_issues() {
    echo "=== CoreDNS Diagnostics ==="
    
    echo "1. CoreDNS Pod Logs:"
    COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $COREDNS_PODS; do
        echo "Logs from $pod:"
        kubectl logs -n kube-system $pod --tail=10 | grep -E "(error|Error|ERROR|warn|Warn|WARN)" || echo "No recent errors/warnings"
        echo
    done
    
    echo "2. CoreDNS Resource Usage:"
    kubectl top pods -n kube-system -l k8s-app=kube-dns 2>/dev/null || echo "Metrics not available"
    echo
    
    echo "3. CoreDNS Configuration Validation:"
    kubectl get configmap -n kube-system coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile
    echo "CoreDNS configuration:"
    cat /tmp/Corefile
    echo
    
    echo "4. CoreDNS Health Check:"
    COREDNS_POD=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$COREDNS_POD" ]; then
        echo "Health check for $COREDNS_POD:"
        kubectl exec -n kube-system $COREDNS_POD -- wget -qO- http://localhost:8080/health 2>/dev/null || echo "❌ Health check failed"
        echo
        
        echo "Metrics endpoint:"
        kubectl exec -n kube-system $COREDNS_POD -- wget -qO- http://localhost:9153/metrics 2>/dev/null | head -10 || echo "❌ Metrics not available"
        echo
    fi
}

# Функция для создания comprehensive DNS test suite
create_dns_test_suite() {
    echo "=== Creating DNS Test Suite ==="
    
    echo "1. DNS performance test:"
    cat << DNS_PERF_TEST_EOF > dns-performance-test.yaml
# DNS Performance Test Pod
apiVersion: v1
kind: Pod
metadata:
  name: dns-perf-test
  namespace: default
spec:
  containers:
  - name: dns-perf
    image: busybox:1.28
    command: ["sh", "-c"]
    args:
    - |
      echo "=== DNS Performance Test ==="
      echo "Testing DNS resolution performance..."
      
      # Test internal service resolution speed
      echo "Internal service resolution test:"
      time nslookup kubernetes.default.svc.cluster.local
      time nslookup kube-dns.kube-system.svc.cluster.local
      
      # Test external resolution speed
      echo "External DNS resolution test:"
      time nslookup google.com
      time nslookup github.com
      
      # Concurrent DNS queries test
      echo "Concurrent DNS queries test:"
      for i in \$(seq 1 10); do
        nslookup kubernetes.default.svc.cluster.local &
      done
      wait
      
      echo "DNS performance test completed"
      sleep 3600
    resources:
      requests:
        cpu: "10m"
        memory: "16Mi"
  restartPolicy: Never

DNS_PERF_TEST_EOF
    
    echo "2. DNS load test:"
    cat << DNS_LOAD_TEST_EOF > dns-load-test.yaml
# DNS Load Test Job
apiVersion: batch/v1
kind: Job
metadata:
  name: dns-load-test
  namespace: default
spec:
  parallelism: 5
  completions: 5
  template:
    spec:
      containers:
      - name: dns-load
        image: busybox:1.28
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting DNS load test from \$(hostname)"
          
          # Generate load with multiple DNS queries
          for i in \$(seq 1 100); do
            nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1
            nslookup kube-dns.kube-system.svc.cluster.local >/dev/null 2>&1
            nslookup google.com >/dev/null 2>&1
            
            if [ \$((i % 10)) -eq 0 ]; then
              echo "Completed \$i queries from \$(hostname)"
            fi
          done
          
          echo "DNS load test completed from \$(hostname)"
        resources:
          requests:
            cpu: "10m"
            memory: "16Mi"
      restartPolicy: Never

DNS_LOAD_TEST_EOF
    
    echo "3. DNS troubleshooting script:"
    cat << DNS_TROUBLESHOOT_SCRIPT_EOF > dns-troubleshoot.sh
#!/bin/bash

echo "=== DNS Troubleshooting Script ==="

# Function to test specific service resolution
test_service_resolution() {
    local service_name=\$1
    local namespace=\$2
    local full_name="\${service_name}.\${namespace}.svc.cluster.local"
    
    echo "Testing resolution for \$full_name:"
    
    # Test with nslookup
    kubectl exec dns-test-pod -- nslookup \$full_name 2>/dev/null && echo "✅ nslookup successful" || echo "❌ nslookup failed"
    
    # Test with dig if available
    kubectl exec dns-test-pod -- dig \$full_name 2>/dev/null >/dev/null && echo "✅ dig successful" || echo "❌ dig failed or not available"
    
    # Test short name
    kubectl exec dns-test-pod -- nslookup \$service_name 2>/dev/null && echo "✅ short name resolution successful" || echo "❌ short name resolution failed"
    
    echo
}

# Function to check DNS configuration issues
check_dns_config_issues() {
    echo "Checking for common DNS configuration issues:"
    
    # Check if CoreDNS is running
    COREDNS_RUNNING=\$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep Running | wc -l)
    if [ \$COREDNS_RUNNING -eq 0 ]; then
        echo "❌ No CoreDNS pods are running"
    else
        echo "✅ CoreDNS pods are running (\$COREDNS_RUNNING pods)"
    fi
    
    # Check DNS service
    kubectl get service -n kube-system kube-dns >/dev/null 2>&1 && echo "✅ DNS service exists" || echo "❌ DNS service missing"
    
    # Check DNS endpoints
    DNS_ENDPOINTS=\$(kubectl get endpoints -n kube-system kube-dns -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    if [ \$DNS_ENDPOINTS -eq 0 ]; then
        echo "❌ No DNS endpoints available"
    else
        echo "✅ DNS endpoints available (\$DNS_ENDPOINTS endpoints)"
    fi
    
    echo
}

# Main troubleshooting function
main() {
    check_dns_config_issues
    
    # Test common services
    test_service_resolution "kubernetes" "default"
    test_service_resolution "kube-dns" "kube-system"
    
    # Test external resolution
    echo "Testing external DNS resolution:"
    kubectl exec dns-test-pod -- nslookup google.com 2>/dev/null && echo "✅ External DNS working" || echo "❌ External DNS failed"
    echo
}

main

DNS_TROUBLESHOOT_SCRIPT_EOF
    
    chmod +x dns-troubleshoot.sh
    
    echo "✅ DNS test suite created:"
    echo "  - dns-performance-test.yaml"
    echo "  - dns-load-test.yaml"
    echo "  - dns-troubleshoot.sh"
    echo
}

# Функция для создания DNS monitoring
create_dns_monitoring() {
    echo "=== Creating DNS Monitoring Tools ==="
    
    echo "1. DNS monitoring script:"
    cat << DNS_MONITOR_SCRIPT_EOF > dns-monitor.sh
#!/bin/bash

echo "=== DNS Monitoring Dashboard ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "CoreDNS Status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | awk '{print \$1 " " \$3 " " \$4}'
    echo
    
    echo "DNS Service Status:"
    kubectl get service -n kube-system kube-dns --no-headers | awk '{print \$1 " " \$2 " " \$3}'
    echo
    
    echo "DNS Resolution Test:"
    if kubectl get pod dns-test-pod >/dev/null 2>&1; then
        # Test internal resolution
        kubectl exec dns-test-pod -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 && echo "✅ Internal DNS: OK" || echo "❌ Internal DNS: FAILED"
        
        # Test external resolution
        kubectl exec dns-test-pod -- nslookup google.com >/dev/null 2>&1 && echo "✅ External DNS: OK" || echo "❌ External DNS: FAILED"
    else
        echo "❌ DNS test pod not available"
    fi
    echo
    
    echo "Recent CoreDNS Logs:"
    COREDNS_POD=\$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "\$COREDNS_POD" ]; then
        kubectl logs -n kube-system \$COREDNS_POD --tail=3 --since=1m 2>/dev/null | grep -E "(error|Error|ERROR)" || echo "No recent errors"
    fi
    echo
    
    sleep 30
done

DNS_MONITOR_SCRIPT_EOF
    
    chmod +x dns-monitor.sh
    echo "✅ DNS monitoring script created: dns-monitor.sh"
    echo
    
    echo "2. DNS metrics collection:"
    cat << DNS_METRICS_EOF > dns-metrics-collector.yaml
# DNS Metrics Collector
apiVersion: v1
kind: ConfigMap
metadata:
  name: dns-metrics-config
  namespace: default
data:
  collect-metrics.sh: |
    #!/bin/bash
    
    echo "=== DNS Metrics Collection ==="
    echo "Timestamp: \$(date)"
    echo
    
    # CoreDNS metrics
    COREDNS_POD=\$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "\$COREDNS_POD" ]; then
        echo "CoreDNS Metrics:"
        kubectl exec -n kube-system \$COREDNS_POD -- wget -qO- http://localhost:9153/metrics | grep -E "(coredns_dns_request_duration|coredns_dns_requests_total|coredns_dns_responses_total)" | head -10
        echo
    fi
    
    # DNS query performance
    echo "DNS Query Performance:"
    time kubectl exec dns-test-pod -- nslookup kubernetes.default.svc.cluster.local 2>&1 | grep real
    echo
    
    # DNS cache statistics
    echo "DNS Cache Statistics:"
    kubectl exec -n kube-system \$COREDNS_POD -- wget -qO- http://localhost:9153/metrics | grep -E "(coredns_cache_hits_total|coredns_cache_misses_total)" || echo "Cache metrics not available"
    echo

---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dns-metrics-collector
  namespace: default
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: metrics-collector
            image: busybox:1.28
            command: ["sh", "/scripts/collect-metrics.sh"]
            volumeMounts:
            - name: scripts
              mountPath: /scripts
            resources:
              requests:
                cpu: "10m"
                memory: "16Mi"
          volumes:
          - name: scripts
            configMap:
              name: dns-metrics-config
              defaultMode: 0755
          restartPolicy: OnFailure

DNS_METRICS_EOF
    
    echo "✅ DNS metrics collector created: dns-metrics-collector.yaml"
    echo
}

# Функция для cleanup
cleanup_dns_tests() {
    echo "=== Cleaning up DNS test resources ==="
    
    kubectl delete pod dns-test-pod --ignore-not-found=true
    kubectl delete pod dns-perf-test --ignore-not-found=true
    kubectl delete job dns-load-test --ignore-not-found=true
    kubectl delete cronjob dns-metrics-collector --ignore-not-found=true
    kubectl delete configmap dns-metrics-config --ignore-not-found=true
    
    echo "✅ DNS test resources cleaned up"
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_dns_infrastructure
            ;;
        "check")
            check_pod_dns_configuration
            ;;
        "test")
            test_dns_resolution
            ;;
        "diagnose")
            diagnose_coredns_issues
            ;;
        "suite")
            create_dns_test_suite
            ;;
        "monitor")
            create_dns_monitoring
            ;;
        "cleanup")
            cleanup_dns_tests
            ;;
        "all"|"")
            analyze_dns_infrastructure
            check_pod_dns_configuration
            test_dns_resolution
            diagnose_coredns_issues
            create_dns_test_suite
            create_dns_monitoring
            ;;
        *)
            echo "Usage: $0 [analyze|check|test|diagnose|suite|monitor|cleanup|all]"
            echo ""
            echo "DNS Troubleshooting Options:"
            echo "  analyze   - Analyze DNS infrastructure"
            echo "  check     - Check pod DNS configuration"
            echo "  test      - Test DNS resolution"
            echo "  diagnose  - Diagnose CoreDNS issues"
            echo "  suite     - Create DNS test suite"
            echo "  monitor   - Create DNS monitoring tools"
            echo "  cleanup   - Clean up test resources"
            ;;
    esac
}

main "$@"

EOF

chmod +x dns-troubleshooting-toolkit.sh
./dns-troubleshooting-toolkit.sh all
```

## 🎯 **Основные шаги DNS troubleshooting:**

### **1. Проверка DNS инфраструктуры:**
```bash
# Статус CoreDNS подов
kubectl get pods -n kube-system -l k8s-app=kube-dns

# DNS сервис
kubectl get service -n kube-system kube-dns

# DNS endpoints
kubectl get endpoints -n kube-system kube-dns

# CoreDNS конфигурация
kubectl get configmap -n kube-system coredns -o yaml
```

### **2. Тестирование DNS разрешения:**
```bash
# Создание тестового пода
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- sh

# Внутри пода:
nslookup kubernetes.default.svc.cluster.local
nslookup kube-dns.kube-system.svc.cluster.local
nslookup google.com

# Проверка конфигурации DNS
cat /etc/resolv.conf
```

### **3. Анализ DNS конфигурации пода:**
```bash
# DNS настройки пода
kubectl exec <pod-name> -- cat /etc/resolv.conf

# Проверка search domains
kubectl exec <pod-name> -- cat /etc/resolv.conf | grep search

# Nameserver configuration
kubectl exec <pod-name> -- cat /etc/resolv.conf | grep nameserver
```

## 🔧 **Распространенные проблемы и решения:**

### **1. CoreDNS не запускается:**
```bash
# Проверка логов CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns

# Проверка ресурсов
kubectl describe pods -n kube-system -l k8s-app=kube-dns

# Проверка конфигурации
kubectl get configmap -n kube-system coredns -o yaml
```

### **2. Медленное DNS разрешение:**
```bash
# Тестирование времени разрешения
time nslookup kubernetes.default.svc.cluster.local

# Проверка метрик CoreDNS
kubectl exec -n kube-system <coredns-pod> -- wget -qO- http://localhost:9153/metrics

# Анализ cache hit rate
kubectl exec -n kube-system <coredns-pod> -- wget -qO- http://localhost:9153/metrics | grep cache
```

### **3. NXDOMAIN ошибки:**
```bash
# Проверка правильности имени сервиса
kubectl get services --all-namespaces | grep <service-name>

# Проверка endpoints
kubectl get endpoints <service-name>

# Тестирование FQDN
nslookup <service-name>.<namespace>.svc.cluster.local
```

### **4. External DNS не работает:**
```bash
# Проверка upstream DNS серверов
kubectl get configmap -n kube-system coredns -o yaml | grep forward

# Тестирование внешнего DNS
nslookup google.com 8.8.8.8

# Проверка network policies
kubectl get networkpolicies --all-namespaces
```

## 📊 **DNS мониторинг:**

### **Метрики CoreDNS:**
```bash
# Доступ к метрикам
kubectl exec -n kube-system <coredns-pod> -- wget -qO- http://localhost:9153/metrics

# Ключевые метрики:
# - coredns_dns_requests_total
# - coredns_dns_request_duration_seconds
# - coredns_cache_hits_total
# - coredns_cache_misses_total
```

### **Health checks:**
```bash
# CoreDNS health endpoint
kubectl exec -n kube-system <coredns-pod> -- wget -qO- http://localhost:8080/health

# Ready endpoint
kubectl exec -n kube-system <coredns-pod> -- wget -qO- http://localhost:8181/ready
```

**Правильная диагностика DNS проблем критически важна для стабильной работы Kubernetes кластера!**
