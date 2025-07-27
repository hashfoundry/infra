# 119. Что делать когда kubectl команды медленные или зависают

## 🎯 **Что делать когда kubectl команды медленные или зависают**

**Медленные kubectl команды** могут указывать на серьезные проблемы в кластере - от проблем с API server до сетевых задержек. Быстрая диагностика и решение этих проблем критически важны для поддержания производительности кластера.

## ⚡ **Причины медленной работы kubectl:**

### **1. API Server Issues:**
- **High CPU/Memory usage** - перегрузка API server
- **Too many requests** - превышение rate limits
- **etcd latency** - медленные запросы к etcd
- **Authentication delays** - проблемы с аутентификацией

### **2. Network Issues:**
- **High latency** - большие задержки сети
- **Packet loss** - потеря пакетов
- **DNS resolution** - медленное разрешение DNS
- **Proxy issues** - проблемы с прокси

### **3. Client-side Issues:**
- **Large responses** - большие объемы данных
- **Inefficient queries** - неэффективные запросы
- **Local caching** - проблемы с кешем
- **Resource constraints** - ограничения ресурсов клиента

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive kubectl performance troubleshooting toolkit
cat << 'EOF' > kubectl-performance-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== kubectl Performance Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing kubectl performance issues in HashFoundry HA cluster"
echo

# Функция для диагностики kubectl performance
diagnose_kubectl_performance() {
    echo "=== kubectl Performance Diagnosis ==="
    
    echo "1. Test basic kubectl connectivity:"
    echo "Testing kubectl cluster-info..."
    time kubectl cluster-info
    echo
    
    echo "2. Test simple kubectl commands with timing:"
    echo "Testing kubectl version..."
    time kubectl version --short
    echo
    
    echo "Testing kubectl get nodes..."
    time kubectl get nodes
    echo
    
    echo "Testing kubectl get pods..."
    time kubectl get pods --all-namespaces
    echo
    
    echo "3. Check kubectl configuration:"
    echo "Current context:"
    kubectl config current-context
    echo
    
    echo "Cluster info:"
    kubectl config view --minify
    echo
    
    echo "4. Test API server responsiveness:"
    API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    echo "API Server: $API_SERVER"
    
    echo "Testing API server health endpoint:"
    time curl -k -s "$API_SERVER/healthz" || echo "❌ API server health check failed"
    echo
    
    echo "Testing API server readiness:"
    time curl -k -s "$API_SERVER/readyz" || echo "❌ API server readiness check failed"
    echo
}

# Функция для проверки API server performance
check_api_server_performance() {
    echo "=== API Server Performance Check ==="
    
    echo "1. API server pods status:"
    kubectl get pods -n kube-system -l component=kube-apiserver -o wide
    echo
    
    echo "2. API server resource usage:"
    kubectl top pods -n kube-system -l component=kube-apiserver 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "3. API server logs (recent errors):"
    API_SERVER_POD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$API_SERVER_POD" ]; then
        echo "Checking logs for $API_SERVER_POD:"
        kubectl logs -n kube-system $API_SERVER_POD --tail=50 | grep -i "error\|timeout\|slow" || echo "No recent errors found"
    fi
    echo
    
    echo "4. API server metrics (if available):"
    if [ ! -z "$API_SERVER_POD" ]; then
        echo "Attempting to get API server metrics..."
        kubectl exec -n kube-system $API_SERVER_POD -- curl -s http://127.0.0.1:8080/metrics | grep -E "(apiserver_request_duration|apiserver_current_inflight)" | head -10 2>/dev/null || echo "Metrics not accessible"
    fi
    echo
    
    echo "5. etcd performance impact:"
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$ETCD_POD" ]; then
        echo "Testing etcd response time:"
        time kubectl exec -n kube-system $ETCD_POD -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            endpoint health 2>/dev/null || echo "❌ etcd health check failed"
    fi
    echo
}

# Функция для проверки network performance
check_network_performance() {
    echo "=== Network Performance Check ==="
    
    echo "1. Test network latency to API server:"
    API_SERVER_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||' | sed 's|:.*||')
    echo "API Server Host: $API_SERVER_HOST"
    
    echo "Ping test to API server:"
    ping -c 5 $API_SERVER_HOST 2>/dev/null || echo "❌ Cannot ping API server"
    echo
    
    echo "2. DNS resolution test:"
    echo "Testing DNS resolution for API server:"
    time nslookup $API_SERVER_HOST || echo "❌ DNS resolution failed"
    echo
    
    echo "3. Network connectivity test:"
    API_SERVER_PORT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|.*:||')
    echo "Testing connectivity to $API_SERVER_HOST:$API_SERVER_PORT"
    nc -zv $API_SERVER_HOST $API_SERVER_PORT 2>/dev/null || echo "❌ Cannot connect to API server port"
    echo
    
    echo "4. Check for proxy configuration:"
    echo "HTTP_PROXY: ${HTTP_PROXY:-not set}"
    echo "HTTPS_PROXY: ${HTTPS_PROXY:-not set}"
    echo "NO_PROXY: ${NO_PROXY:-not set}"
    echo
}

# Функция для оптимизации kubectl performance
optimize_kubectl_performance() {
    echo "=== kubectl Performance Optimization ==="
    
    echo "1. kubectl configuration optimization:"
    cat << KUBECTL_OPTIMIZATION_EOF > kubectl-optimization-tips.md
# kubectl Performance Optimization Tips

## 🚀 **Client-side Optimizations**

### **1. Use Efficient Queries**
\`\`\`bash
# Use field selectors to reduce data transfer
kubectl get pods --field-selector=status.phase=Running

# Use label selectors for targeted queries
kubectl get pods -l app=nginx

# Limit output with --no-headers and custom columns
kubectl get pods --no-headers -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

# Use --chunk-size for large datasets
kubectl get pods --all-namespaces --chunk-size=500
\`\`\`

### **2. Configure kubectl for Better Performance**
\`\`\`bash
# Increase timeout for slow clusters
export KUBECTL_TIMEOUT=60s

# Use compression for large responses
kubectl config set-cluster <cluster-name> --tls-server-name=<server-name> --insecure-skip-tls-verify=false

# Enable client-side caching
mkdir -p ~/.kube/cache
export KUBECTL_CACHE_DIR=~/.kube/cache
\`\`\`

### **3. Use kubectl Efficiently**
\`\`\`bash
# Avoid unnecessary wide output
kubectl get pods -o wide  # Only when needed

# Use specific namespaces instead of --all-namespaces
kubectl get pods -n specific-namespace

# Use watch mode efficiently
kubectl get pods -w --field-selector=status.phase=Pending

# Batch operations when possible
kubectl delete pods pod1 pod2 pod3  # Instead of separate commands
\`\`\`

## 🔧 **Server-side Optimizations**

### **1. API Server Tuning**
\`\`\`yaml
# API server configuration optimizations
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --max-requests-inflight=400
    - --max-mutating-requests-inflight=200
    - --request-timeout=60s
    - --min-request-timeout=1800
    - --default-watch-cache-size=100
\`\`\`

### **2. etcd Performance Tuning**
\`\`\`bash
# etcd performance parameters
--heartbeat-interval=100
--election-timeout=1000
--max-request-bytes=1572864
--quota-backend-bytes=8589934592
\`\`\`

KUBECTL_OPTIMIZATION_EOF
    
    echo "✅ kubectl optimization tips created: kubectl-optimization-tips.md"
    echo
    
    echo "2. Create performance monitoring script:"
    cat << PERFORMANCE_MONITOR_EOF > kubectl-performance-monitor.sh
#!/bin/bash

echo "=== kubectl Performance Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "kubectl Response Times:"
    echo -n "cluster-info: "
    time kubectl cluster-info >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"
    
    echo -n "get nodes: "
    time kubectl get nodes >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"
    
    echo -n "get pods: "
    time kubectl get pods --all-namespaces >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"
    echo
    
    echo "API Server Status:"
    kubectl get pods -n kube-system -l component=kube-apiserver --no-headers | awk '{print \$1 " " \$3}'
    echo
    
    echo "etcd Status:"
    kubectl get pods -n kube-system -l component=etcd --no-headers | awk '{print \$1 " " \$3}'
    echo
    
    sleep 30
done

PERFORMANCE_MONITOR_EOF
    
    chmod +x kubectl-performance-monitor.sh
    echo "✅ kubectl performance monitor created: kubectl-performance-monitor.sh"
    echo
}

# Функция для создания troubleshooting scenarios
create_troubleshooting_scenarios() {
    echo "=== Creating Troubleshooting Scenarios ==="
    
    echo "1. kubectl timeout simulation:"
    cat << TIMEOUT_SIMULATION_EOF > kubectl-timeout-simulation.sh
#!/bin/bash

echo "=== kubectl Timeout Simulation ==="
echo

# Function to test kubectl with different timeouts
test_kubectl_timeout() {
    local TIMEOUT=\$1
    echo "Testing kubectl with \${TIMEOUT}s timeout:"
    
    timeout \$TIMEOUT kubectl get pods --all-namespaces >/dev/null 2>&1
    local EXIT_CODE=\$?
    
    if [ \$EXIT_CODE -eq 0 ]; then
        echo "✅ Command completed within \${TIMEOUT}s"
    elif [ \$EXIT_CODE -eq 124 ]; then
        echo "❌ Command timed out after \${TIMEOUT}s"
    else
        echo "❌ Command failed with exit code \$EXIT_CODE"
    fi
    echo
}

# Test with different timeout values
test_kubectl_timeout 5
test_kubectl_timeout 10
test_kubectl_timeout 30
test_kubectl_timeout 60

echo "Recommendation: Use appropriate timeout values based on cluster size and network conditions"

TIMEOUT_SIMULATION_EOF
    
    chmod +x kubectl-timeout-simulation.sh
    echo "✅ kubectl timeout simulation created: kubectl-timeout-simulation.sh"
    echo
    
    echo "2. Network latency test:"
    cat << NETWORK_LATENCY_TEST_EOF > network-latency-test.sh
#!/bin/bash

echo "=== Network Latency Test ==="
echo

# Get API server details
API_SERVER_HOST=\$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||' | sed 's|:.*||')
API_SERVER_PORT=\$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|.*:||')

echo "API Server: \$API_SERVER_HOST:\$API_SERVER_PORT"
echo

# Test network latency
echo "Network Latency Test:"
ping -c 10 \$API_SERVER_HOST | tail -1
echo

# Test TCP connection time
echo "TCP Connection Test:"
for i in {1..5}; do
    echo -n "Attempt \$i: "
    time nc -zv \$API_SERVER_HOST \$API_SERVER_PORT 2>&1 | grep -o "succeeded"
done
echo

# Test HTTP response time
echo "HTTP Response Time Test:"
for i in {1..5}; do
    echo -n "Attempt \$i: "
    time curl -k -s -o /dev/null \$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')/healthz
done

NETWORK_LATENCY_TEST_EOF
    
    chmod +x network-latency-test.sh
    echo "✅ Network latency test created: network-latency-test.sh"
    echo
}

# Функция для автоматического исправления проблем
auto_fix_kubectl_issues() {
    echo "=== Auto-fix kubectl Issues ==="
    
    echo "1. Common kubectl performance fixes:"
    cat << KUBECTL_FIXES_EOF
# Fix 1: Clear kubectl cache
rm -rf ~/.kube/cache/*

# Fix 2: Reset kubectl configuration
kubectl config view --raw > ~/.kube/config.backup
kubectl config unset current-context
kubectl config use-context <correct-context>

# Fix 3: Increase kubectl timeout
export KUBECTL_TIMEOUT=120s

# Fix 4: Use compression for large responses
kubectl config set-cluster <cluster> --tls-server-name=<server> --certificate-authority=<ca-file>

# Fix 5: Restart API server (if accessible)
kubectl delete pod -n kube-system <api-server-pod>

# Fix 6: Check and fix DNS
nslookup <api-server-host>
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

KUBECTL_FIXES_EOF
    echo
    
    echo "2. kubectl troubleshooting checklist:"
    cat << KUBECTL_CHECKLIST_EOF > kubectl-troubleshooting-checklist.md
# kubectl Performance Troubleshooting Checklist

## ✅ **Step 1: Basic Connectivity**
- [ ] kubectl can connect to cluster: \`kubectl cluster-info\`
- [ ] API server is responding: \`curl -k <api-server>/healthz\`
- [ ] Network connectivity is good: \`ping <api-server-host>\`

## ✅ **Step 2: API Server Health**
- [ ] API server pods are running: \`kubectl get pods -n kube-system -l component=kube-apiserver\`
- [ ] API server logs show no errors: \`kubectl logs -n kube-system <api-server-pod>\`
- [ ] API server resource usage is normal: \`kubectl top pods -n kube-system\`

## ✅ **Step 3: etcd Health**
- [ ] etcd pods are running: \`kubectl get pods -n kube-system -l component=etcd\`
- [ ] etcd cluster is healthy: \`etcdctl endpoint health\`
- [ ] etcd response time is good: time etcd operations

## ✅ **Step 4: Network Performance**
- [ ] Low network latency: \`ping <api-server-host>\`
- [ ] DNS resolution is fast: \`nslookup <api-server-host>\`
- [ ] No proxy issues: check HTTP_PROXY, HTTPS_PROXY

## ✅ **Step 5: Client Configuration**
- [ ] kubectl config is correct: \`kubectl config view\`
- [ ] No client-side caching issues: clear cache
- [ ] Appropriate timeout settings: check KUBECTL_TIMEOUT

## 🔧 **Performance Optimization**
1. **Use efficient queries**: field selectors, label selectors
2. **Limit output**: --no-headers, custom columns
3. **Batch operations**: multiple resources in one command
4. **Configure timeouts**: appropriate for cluster size
5. **Monitor regularly**: track performance trends

KUBECTL_CHECKLIST_EOF
    
    echo "✅ kubectl troubleshooting checklist created: kubectl-troubleshooting-checklist.md"
    echo
}

# Основная функция
main() {
    case "$1" in
        "diagnose")
            diagnose_kubectl_performance
            ;;
        "api-server")
            check_api_server_performance
            ;;
        "network")
            check_network_performance
            ;;
        "optimize")
            optimize_kubectl_performance
            ;;
        "scenarios")
            create_troubleshooting_scenarios
            ;;
        "fix")
            auto_fix_kubectl_issues
            ;;
        "all"|"")
            diagnose_kubectl_performance
            check_api_server_performance
            check_network_performance
            optimize_kubectl_performance
            create_troubleshooting_scenarios
            auto_fix_kubectl_issues
            ;;
        *)
            echo "Usage: $0 [diagnose|api-server|network|optimize|scenarios|fix|all]"
            echo ""
            echo "kubectl Performance Troubleshooting Options:"
            echo "  diagnose    - Diagnose kubectl performance issues"
            echo "  api-server  - Check API server performance"
            echo "  network     - Check network performance"
            echo "  optimize    - Optimize kubectl performance"
            echo "  scenarios   - Create troubleshooting scenarios"
            echo "  fix         - Auto-fix kubectl issues"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubectl-performance-troubleshooting-toolkit.sh
./kubectl-performance-troubleshooting-toolkit.sh all
```

## 🎯 **Пошаговая диагностика медленных kubectl команд:**

### **Шаг 1: Базовая диагностика**
```bash
# Тест connectivity
time kubectl cluster-info

# Тест простых команд
time kubectl version --short
time kubectl get nodes

# Проверка конфигурации
kubectl config current-context
kubectl config view --minify
```

### **Шаг 2: Проверка API server**
```bash
# Статус API server pods
kubectl get pods -n kube-system -l component=kube-apiserver

# Ресурсы API server
kubectl top pods -n kube-system -l component=kube-apiserver

# Логи API server
kubectl logs -n kube-system <api-server-pod> --tail=50
```

### **Шаг 3: Проверка сети**
```bash
# Latency к API server
API_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||' | sed 's|:.*||')
ping -c 5 $API_HOST

# DNS resolution
time nslookup $API_HOST

# TCP connectivity
nc -zv $API_HOST 6443
```

### **Шаг 4: Проверка etcd**
```bash
# etcd health
kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint health

# etcd performance
time kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint status
```

## 🔧 **Оптимизация производительности kubectl:**

### **1. Client-side оптимизации:**
```bash
# Эффективные запросы
kubectl get pods --field-selector=status.phase=Running
kubectl get pods -l app=nginx
kubectl get pods --no-headers -o custom-columns=NAME:.metadata.name

# Настройка timeout
export KUBECTL_TIMEOUT=60s

# Кеширование
mkdir -p ~/.kube/cache
export KUBECTL_CACHE_DIR=~/.kube/cache
```

### **2. Server-side оптимизации:**
```bash
# API server tuning
--max-requests-inflight=400
--max-mutating-requests-inflight=200
--request-timeout=60s

# etcd tuning
--heartbeat-interval=100
--election-timeout=1000
```

### **3. Частые проблемы и решения:**

**Медленные команды:**
- Проверить network latency
- Оптимизировать запросы
- Увеличить timeout

**Timeout ошибки:**
- Проверить API server health
- Проверить etcd performance
- Проверить network connectivity

**Высокая нагрузка на API server:**
- Увеличить ресурсы API server
- Настроить rate limiting
- Оптимизировать клиентские запросы

**Быстрая диагностика и оптимизация kubectl критически важны для эффективной работы с кластером!**
