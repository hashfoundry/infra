# 117. Шаги при недоступности сервиса в Kubernetes

## 🎯 **Шаги при недоступности сервиса в Kubernetes**

**Service недоступность** - одна из самых критичных проблем в production среде. Систематический подход к диагностике и решению проблем с сервисами критически важен для быстрого восстановления работоспособности.

## 🌐 **Архитектура Service в Kubernetes:**

### **1. Service Components:**
- **Service Object** - абстракция для группы pods
- **Endpoints** - список IP адресов pods
- **kube-proxy** - маршрутизация трафика
- **iptables/IPVS** - правила балансировки

### **2. Service Types:**
- **ClusterIP** - внутренний доступ
- **NodePort** - доступ через порты узлов
- **LoadBalancer** - внешний балансировщик
- **ExternalName** - DNS CNAME

### **3. Common Issues:**
- **No Endpoints** - нет доступных pods
- **Wrong Selector** - неправильные labels
- **Network Issues** - проблемы с сетью
- **Port Mismatch** - несоответствие портов

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive service troubleshooting toolkit
cat << 'EOF' > service-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== Service Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing service issues in HashFoundry HA cluster"
echo

# Функция для быстрой диагностики сервиса
quick_service_diagnosis() {
    local SERVICE_NAME=$1
    local NAMESPACE=${2:-default}
    
    if [ -z "$SERVICE_NAME" ]; then
        echo "Usage: quick_service_diagnosis <service-name> [namespace]"
        return 1
    fi
    
    echo "=== Quick Service Diagnosis: $NAMESPACE/$SERVICE_NAME ==="
    echo
    
    echo "1. Service Status:"
    kubectl get service $SERVICE_NAME -n $NAMESPACE -o wide
    echo
    
    echo "2. Service Details:"
    kubectl describe service $SERVICE_NAME -n $NAMESPACE
    echo
    
    echo "3. Service Endpoints:"
    kubectl get endpoints $SERVICE_NAME -n $NAMESPACE
    echo
    
    echo "4. Pods matching service selector:"
    SELECTOR=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}' 2>/dev/null)
    if [ ! -z "$SELECTOR" ] && [ "$SELECTOR" != "null" ]; then
        echo "Selector: $SELECTOR"
        # Convert selector to label format
        LABEL_SELECTOR=$(echo $SELECTOR | sed 's/[{}"]//g' | sed 's/:/=/g' | sed 's/,/,/g')
        kubectl get pods -n $NAMESPACE -l "$LABEL_SELECTOR" -o wide
    else
        echo "No selector found for service"
    fi
    echo
    
    echo "5. Recent events:"
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$SERVICE_NAME --sort-by='.lastTimestamp' | tail -10
    echo
}

# Функция для детальной диагностики сервиса
detailed_service_diagnosis() {
    local SERVICE_NAME=$1
    local NAMESPACE=${2:-default}
    
    if [ -z "$SERVICE_NAME" ]; then
        echo "Usage: detailed_service_diagnosis <service-name> [namespace]"
        return 1
    fi
    
    echo "=== Detailed Service Diagnosis: $NAMESPACE/$SERVICE_NAME ==="
    echo
    
    echo "1. Service YAML Configuration:"
    kubectl get service $SERVICE_NAME -n $NAMESPACE -o yaml
    echo
    
    echo "2. Endpoints Details:"
    kubectl describe endpoints $SERVICE_NAME -n $NAMESPACE
    echo
    
    echo "3. Network Policy Check:"
    kubectl get networkpolicies -n $NAMESPACE
    echo
    
    echo "4. kube-proxy Status:"
    kubectl get pods -n kube-system | grep kube-proxy
    echo
    
    echo "5. Service Account and RBAC:"
    kubectl get serviceaccount -n $NAMESPACE
    echo
}

# Функция для тестирования connectivity к сервису
test_service_connectivity() {
    local SERVICE_NAME=$1
    local NAMESPACE=${2:-default}
    local PORT=${3:-80}
    
    if [ -z "$SERVICE_NAME" ]; then
        echo "Usage: test_service_connectivity <service-name> [namespace] [port]"
        return 1
    fi
    
    echo "=== Service Connectivity Tests: $NAMESPACE/$SERVICE_NAME ==="
    echo
    
    # Create test pod if it doesn't exist
    kubectl get pod service-test-client -n $NAMESPACE >/dev/null 2>&1 || {
        echo "Creating test client pod..."
        kubectl run service-test-client --image=busybox:1.28 --restart=Never -n $NAMESPACE -- sleep 3600
        kubectl wait --for=condition=Ready pod/service-test-client -n $NAMESPACE --timeout=60s
    }
    
    echo "1. Test service by name:"
    kubectl exec service-test-client -n $NAMESPACE -- wget -qO- --timeout=5 http://$SERVICE_NAME:$PORT/ || echo "❌ Service not reachable by name"
    echo
    
    echo "2. Test service by FQDN:"
    kubectl exec service-test-client -n $NAMESPACE -- wget -qO- --timeout=5 http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local:$PORT/ || echo "❌ Service not reachable by FQDN"
    echo
    
    echo "3. Test service by ClusterIP:"
    CLUSTER_IP=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    if [ "$CLUSTER_IP" != "None" ] && [ ! -z "$CLUSTER_IP" ]; then
        kubectl exec service-test-client -n $NAMESPACE -- wget -qO- --timeout=5 http://$CLUSTER_IP:$PORT/ || echo "❌ Service not reachable by ClusterIP"
    else
        echo "Service has no ClusterIP (headless service)"
    fi
    echo
    
    echo "4. Test DNS resolution:"
    kubectl exec service-test-client -n $NAMESPACE -- nslookup $SERVICE_NAME.$NAMESPACE.svc.cluster.local
    echo
    
    echo "5. Test port connectivity:"
    kubectl exec service-test-client -n $NAMESPACE -- nc -zv $CLUSTER_IP $PORT || echo "❌ Port $PORT not accessible"
    echo
}

# Функция для проверки endpoints и pods
check_endpoints_and_pods() {
    local SERVICE_NAME=$1
    local NAMESPACE=${2:-default}
    
    if [ -z "$SERVICE_NAME" ]; then
        echo "Usage: check_endpoints_and_pods <service-name> [namespace]"
        return 1
    fi
    
    echo "=== Endpoints and Pods Analysis: $NAMESPACE/$SERVICE_NAME ==="
    echo
    
    echo "1. Service Endpoints:"
    kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o yaml
    echo
    
    echo "2. Check if endpoints exist:"
    ENDPOINTS_COUNT=$(kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    echo "Number of endpoints: $ENDPOINTS_COUNT"
    
    if [ "$ENDPOINTS_COUNT" -eq 0 ]; then
        echo "❌ No endpoints found! Checking for issues..."
        
        echo "3. Service selector:"
        SELECTOR=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}')
        echo "Selector: $SELECTOR"
        
        echo "4. Pods matching selector:"
        if [ ! -z "$SELECTOR" ] && [ "$SELECTOR" != "null" ]; then
            LABEL_SELECTOR=$(echo $SELECTOR | sed 's/[{}"]//g' | sed 's/:/=/g')
            MATCHING_PODS=$(kubectl get pods -n $NAMESPACE -l "$LABEL_SELECTOR" --no-headers | wc -l)
            echo "Pods matching selector: $MATCHING_PODS"
            
            if [ "$MATCHING_PODS" -eq 0 ]; then
                echo "❌ No pods match the service selector!"
                echo "Available pods in namespace:"
                kubectl get pods -n $NAMESPACE --show-labels
            else
                echo "✅ Found matching pods, checking their status:"
                kubectl get pods -n $NAMESPACE -l "$LABEL_SELECTOR" -o wide
                
                echo "5. Check pod readiness:"
                kubectl get pods -n $NAMESPACE -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
            fi
        else
            echo "❌ Service has no selector!"
        fi
    else
        echo "✅ Found $ENDPOINTS_COUNT endpoints"
        kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' | tr ' ' '\n'
    fi
    echo
}

# Функция для создания тестовых сценариев
create_service_test_scenarios() {
    echo "=== Creating Service Test Scenarios ==="
    
    echo "1. Working service scenario:"
    cat << WORKING_SERVICE_EOF > test-working-service.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-server-working
  namespace: default
  labels:
    app: test-server
    version: working
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
  name: test-service-working
  namespace: default
spec:
  selector:
    app: test-server
    version: working
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
WORKING_SERVICE_EOF
    
    echo "✅ Working service scenario: test-working-service.yaml"
    echo
    
    echo "2. Service with no endpoints:"
    cat << NO_ENDPOINTS_SERVICE_EOF > test-no-endpoints-service.yaml
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
    
    echo "✅ No endpoints service scenario: test-no-endpoints-service.yaml"
    echo
    
    echo "3. Service with wrong selector:"
    cat << WRONG_SELECTOR_EOF > test-wrong-selector-service.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-server-wrong-selector
  namespace: default
  labels:
    app: test-server
    version: v1
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
  name: test-service-wrong-selector
  namespace: default
spec:
  selector:
    app: test-server
    version: v2  # Wrong version!
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
WRONG_SELECTOR_EOF
    
    echo "✅ Wrong selector service scenario: test-wrong-selector-service.yaml"
    echo
    
    echo "4. Service with port mismatch:"
    cat << PORT_MISMATCH_EOF > test-port-mismatch-service.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-server-port-mismatch
  namespace: default
  labels:
    app: test-server
    version: port-test
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
  name: test-service-port-mismatch
  namespace: default
spec:
  selector:
    app: test-server
    version: port-test
  ports:
  - port: 80
    targetPort: 8080  # Wrong target port!
  type: ClusterIP
PORT_MISMATCH_EOF
    
    echo "✅ Port mismatch service scenario: test-port-mismatch-service.yaml"
    echo
}

# Функция для автоматического исправления проблем с сервисами
auto_fix_service_issues() {
    echo "=== Auto-fix Service Issues ==="
    
    echo "1. Common service fixes:"
    cat << SERVICE_FIXES_EOF
# Fix 1: Check and fix service selector
kubectl get service <service-name> -o yaml
kubectl patch service <service-name> -p '{"spec":{"selector":{"app":"correct-label"}}}'

# Fix 2: Restart pods to regenerate endpoints
kubectl rollout restart deployment <deployment-name>

# Fix 3: Check and fix port configuration
kubectl patch service <service-name> -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'

# Fix 4: Recreate service if corrupted
kubectl delete service <service-name>
kubectl apply -f <service-yaml>

# Fix 5: Check kube-proxy
kubectl get pods -n kube-system | grep kube-proxy
kubectl logs -n kube-system <kube-proxy-pod>

SERVICE_FIXES_EOF
    echo
    
    echo "2. Service troubleshooting checklist:"
    cat << SERVICE_CHECKLIST_EOF > service-troubleshooting-checklist.md
# Service Troubleshooting Checklist

## ✅ **Step 1: Basic Service Check**
- [ ] Service exists: \`kubectl get service <service-name>\`
- [ ] Service has correct selector: \`kubectl describe service <service-name>\`
- [ ] Service ports are correct: check port and targetPort

## ✅ **Step 2: Endpoints Check**
- [ ] Endpoints exist: \`kubectl get endpoints <service-name>\`
- [ ] Endpoints have IP addresses: \`kubectl describe endpoints <service-name>\`
- [ ] Number of endpoints matches expected pods

## ✅ **Step 3: Pod Check**
- [ ] Pods exist with matching labels: \`kubectl get pods -l <selector>\`
- [ ] Pods are in Ready state: \`kubectl get pods -o wide\`
- [ ] Pods are listening on correct port: \`kubectl exec <pod> -- netstat -tulpn\`

## ✅ **Step 4: Network Connectivity**
- [ ] DNS resolution works: \`nslookup <service-name>\`
- [ ] Service is reachable by name: \`curl http://<service-name>\`
- [ ] Service is reachable by ClusterIP: \`curl http://<cluster-ip>\`

## ✅ **Step 5: Network Policies**
- [ ] No blocking network policies: \`kubectl get networkpolicies\`
- [ ] kube-proxy is running: \`kubectl get pods -n kube-system | grep kube-proxy\`
- [ ] iptables rules are correct: check on nodes

## 🔧 **Common Solutions**
1. **No endpoints**: Fix pod labels or service selector
2. **Wrong ports**: Update service port configuration
3. **DNS issues**: Check CoreDNS status
4. **Network policies**: Update or remove blocking policies
5. **kube-proxy issues**: Restart kube-proxy pods

SERVICE_CHECKLIST_EOF
    
    echo "✅ Service troubleshooting checklist created: service-troubleshooting-checklist.md"
    echo
}

# Функция для мониторинга сервисов
monitor_service_health() {
    echo "=== Service Health Monitoring ==="
    
    echo "1. Service health monitoring script:"
    cat << SERVICE_MONITOR_EOF > service-health-monitor.sh
#!/bin/bash

echo "=== Service Health Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Services without endpoints:"
    kubectl get endpoints --all-namespaces | grep "<none>" || echo "All services have endpoints"
    echo
    
    echo "Services with few endpoints:"
    kubectl get endpoints --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.subsets[*].addresses[*].ip}{"\n"}{end}' | awk 'NF<=3 {print \$1 "/" \$2 " has " (NF-2) " endpoints"}'
    echo
    
    echo "Recent service-related events:"
    kubectl get events --all-namespaces --field-selector reason=FailedToUpdateEndpoint,reason=FailedToCreateEndpoint | tail -5
    echo
    
    sleep 30
done

SERVICE_MONITOR_EOF
    
    chmod +x service-health-monitor.sh
    echo "✅ Service health monitoring script created: service-health-monitor.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "quick")
            quick_service_diagnosis $2 $3
            ;;
        "detailed")
            detailed_service_diagnosis $2 $3
            ;;
        "test")
            test_service_connectivity $2 $3 $4
            ;;
        "endpoints")
            check_endpoints_and_pods $2 $3
            ;;
        "scenarios")
            create_service_test_scenarios
            ;;
        "fix")
            auto_fix_service_issues
            ;;
        "monitor")
            monitor_service_health
            ;;
        "all"|"")
            echo "Service troubleshooting toolkit loaded!"
            echo "Use specific commands:"
            echo "  $0 quick <service-name> [namespace]"
            echo "  $0 detailed <service-name> [namespace]"
            echo "  $0 test <service-name> [namespace] [port]"
            echo "  $0 endpoints <service-name> [namespace]"
            echo "  $0 scenarios"
            echo "  $0 fix"
            echo "  $0 monitor"
            ;;
        *)
            echo "Usage: $0 [quick|detailed|test|endpoints|scenarios|fix|monitor|all] [service-name] [namespace] [port]"
            echo ""
            echo "Service Troubleshooting Options:"
            echo "  quick <svc> [ns]     - Quick service diagnosis"
            echo "  detailed <svc> [ns]  - Detailed service diagnosis"
            echo "  test <svc> [ns] [p]  - Test service connectivity"
            echo "  endpoints <svc> [ns] - Check endpoints and pods"
            echo "  scenarios            - Create test scenarios"
            echo "  fix                  - Auto-fix service issues"
            echo "  monitor              - Monitor service health"
            ;;
    esac
}

main "$@"

EOF

chmod +x service-troubleshooting-toolkit.sh
./service-troubleshooting-toolkit.sh all
```

## 🎯 **Систематический подход к диагностике сервиса:**

### **Шаг 1: Быстрая проверка**
```bash
# Статус сервиса
kubectl get service <service-name> -o wide

# Endpoints сервиса
kubectl get endpoints <service-name>

# Описание сервиса
kubectl describe service <service-name>
```

### **Шаг 2: Проверка endpoints**
```bash
# Детальная информация об endpoints
kubectl describe endpoints <service-name>

# Pods, соответствующие селектору
kubectl get pods -l <selector-labels>

# Готовность pods
kubectl get pods -l <selector-labels> -o wide
```

### **Шаг 3: Тестирование connectivity**
```bash
# Создать test pod
kubectl run test-client --image=busybox:1.28 --rm -it

# Тест по имени сервиса
kubectl exec test-client -- wget -qO- http://<service-name>

# Тест по ClusterIP
kubectl exec test-client -- wget -qO- http://<cluster-ip>
```

### **Шаг 4: Проверка DNS**
```bash
# DNS resolution
kubectl exec test-client -- nslookup <service-name>

# FQDN resolution
kubectl exec test-client -- nslookup <service-name>.<namespace>.svc.cluster.local
```

## 🔧 **Частые проблемы и решения:**

### **1. No Endpoints:**
```bash
# Проверить selector
kubectl get service <service-name> -o jsonpath='{.spec.selector}'

# Проверить labels на pods
kubectl get pods --show-labels

# Исправить selector
kubectl patch service <service-name> -p '{"spec":{"selector":{"app":"correct-label"}}}'
```

### **2. Wrong Port:**
```bash
# Проверить порты
kubectl describe service <service-name>

# Исправить targetPort
kubectl patch service <service-name> -p '{"spec":{"ports":[{"port":80,"targetPort":8080}]}}'
```

### **3. Pod не Ready:**
```bash
# Проверить readiness probe
kubectl describe pod <pod-name>

# Проверить логи
kubectl logs <pod-name>

# Проверить health checks
kubectl exec <pod-name> -- curl localhost:8080/health
```

### **4. Network Policy блокирует:**
```bash
# Проверить network policies
kubectl get networkpolicies

# Временно удалить policy для теста
kubectl delete networkpolicy <policy-name>
```

**Систематический подход к диагностике сервисов экономит время и гарантирует полное решение проблемы!**
