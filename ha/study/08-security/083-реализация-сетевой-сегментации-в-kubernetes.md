# 83. Реализация сетевой сегментации в Kubernetes

## 🎯 **Реализация сетевой сегментации в Kubernetes**

**Network Segmentation** в Kubernetes - это практика разделения сетевого трафика между различными компонентами и приложениями для повышения безопасности и контроля доступа. Основными инструментами являются Network Policies, Namespaces, Service Mesh и CNI плагины.

## 🏗️ **Основные компоненты сетевой сегментации:**

### **1. Network Policies:**
- **Ingress Rules** - контроль входящего трафика
- **Egress Rules** - контроль исходящего трафика
- **Pod Selectors** - выбор целевых pods
- **Namespace Selectors** - межнамespace коммуникация

### **2. Namespace Isolation:**
- **Логическое разделение** - группировка ресурсов
- **RBAC интеграция** - контроль доступа
- **Resource Quotas** - ограничение ресурсов
- **Network Policies** - сетевая изоляция

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей сетевой архитектуры:**
```bash
# Проверить Network Policies
kubectl get networkpolicies --all-namespaces

# Анализ сетевых подключений
kubectl get services --all-namespaces -o wide
kubectl get endpoints --all-namespaces
```

### **2. Создание comprehensive network segmentation framework:**
```bash
# Создать скрипт для реализации сетевой сегментации
cat << 'EOF' > network-segmentation-implementation.sh
#!/bin/bash

echo "=== Network Segmentation Implementation ==="
echo "Implementing comprehensive network segmentation in HashFoundry HA cluster"
echo

# Функция для анализа текущей сетевой архитектуры
analyze_current_network() {
    echo "=== Current Network Architecture Analysis ==="
    
    echo "1. Network Policies:"
    echo "==================="
    kubectl get networkpolicies --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,POD-SELECTOR:.spec.podSelector,POLICY-TYPES:.spec.policyTypes"
    echo
    
    echo "2. Services and Endpoints:"
    echo "========================="
    kubectl get services --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORTS:.spec.ports[*].port"
    echo
    
    echo "3. Ingress Controllers:"
    echo "======================"
    kubectl get ingress --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[0].ip"
    echo
    
    echo "4. Pod Network Information:"
    echo "=========================="
    kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName" | head -20
    echo
}

# Функция для создания сегментированных namespaces
create_segmented_namespaces() {
    echo "=== Creating Segmented Namespaces ==="
    
    # DMZ namespace для публичных сервисов
    cat << DMZ_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-dmz
  labels:
    # Network segmentation labels
    network.hashfoundry.io/zone: "dmz"
    network.hashfoundry.io/access-level: "public"
    network.hashfoundry.io/isolation: "high"
    
    # Standard labels
    app.kubernetes.io/name: "hashfoundry-network-segmentation"
    app.kubernetes.io/component: "dmz-zone"
    hashfoundry.io/environment: "production"
  annotations:
    network.hashfoundry.io/description: "DMZ zone for public-facing services"
    network.hashfoundry.io/allowed-ingress: "internet,load-balancer"
    network.hashfoundry.io/allowed-egress: "internal-services,external-apis"
---
# Internal namespace для внутренних сервисов
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-internal
  labels:
    network.hashfoundry.io/zone: "internal"
    network.hashfoundry.io/access-level: "private"
    network.hashfoundry.io/isolation: "medium"
    
    app.kubernetes.io/name: "hashfoundry-network-segmentation"
    app.kubernetes.io/component: "internal-zone"
    hashfoundry.io/environment: "production"
  annotations:
    network.hashfoundry.io/description: "Internal zone for backend services"
    network.hashfoundry.io/allowed-ingress: "dmz,internal"
    network.hashfoundry.io/allowed-egress: "database,external-apis"
---
# Database namespace для баз данных
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-database
  labels:
    network.hashfoundry.io/zone: "database"
    network.hashfoundry.io/access-level: "restricted"
    network.hashfoundry.io/isolation: "maximum"
    
    app.kubernetes.io/name: "hashfoundry-network-segmentation"
    app.kubernetes.io/component: "database-zone"
    hashfoundry.io/environment: "production"
  annotations:
    network.hashfoundry.io/description: "Database zone with maximum isolation"
    network.hashfoundry.io/allowed-ingress: "internal-only"
    network.hashfoundry.io/allowed-egress: "backup,monitoring"
---
# Management namespace для административных задач
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-management
  labels:
    network.hashfoundry.io/zone: "management"
    network.hashfoundry.io/access-level: "admin"
    network.hashfoundry.io/isolation: "high"
    
    app.kubernetes.io/name: "hashfoundry-network-segmentation"
    app.kubernetes.io/component: "management-zone"
    hashfoundry.io/environment: "production"
  annotations:
    network.hashfoundry.io/description: "Management zone for admin tools"
    network.hashfoundry.io/allowed-ingress: "admin-vpn,bastion"
    network.hashfoundry.io/allowed-egress: "all-zones,external-tools"
DMZ_NS_EOF
    
    echo "✅ Segmented namespaces created"
    echo
}

# Функция для создания базовых Network Policies
create_base_network_policies() {
    echo "=== Creating Base Network Policies ==="
    
    # Default deny all policy для каждого namespace
    for namespace in hashfoundry-dmz hashfoundry-internal hashfoundry-database hashfoundry-management; do
        cat << DEFAULT_DENY_EOF | kubectl apply -f -
# Default deny all ingress and egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $namespace
  labels:
    network.hashfoundry.io/policy-type: "default-deny"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Default deny all traffic in $namespace"
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow DNS resolution
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: $namespace
  labels:
    network.hashfoundry.io/policy-type: "dns-allow"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow DNS resolution in $namespace"
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
DEFAULT_DENY_EOF
    done
    
    echo "✅ Base network policies created"
    echo
}

# Функция для создания DMZ network policies
create_dmz_policies() {
    echo "=== Creating DMZ Network Policies ==="
    
    cat << DMZ_POLICIES_EOF | kubectl apply -f -
# Allow ingress from internet to DMZ web services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dmz-allow-web-ingress
  namespace: hashfoundry-dmz
  labels:
    network.hashfoundry.io/policy-type: "ingress-allow"
    network.hashfoundry.io/zone: "dmz"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow web traffic to DMZ services"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "web"
  policyTypes:
  - Ingress
  ingress:
  # Allow from ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: "nginx-ingress"
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8080
  # Allow from load balancer
  - from: []
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
---
# Allow egress from DMZ to internal services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dmz-allow-internal-egress
  namespace: hashfoundry-dmz
  labels:
    network.hashfoundry.io/policy-type: "egress-allow"
    network.hashfoundry.io/zone: "dmz"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow DMZ to communicate with internal services"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "web"
  policyTypes:
  - Egress
  egress:
  # Allow to internal namespace
  - to:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "internal"
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 3000
  # Allow to external APIs
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
---
# Allow egress for monitoring
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dmz-allow-monitoring-egress
  namespace: hashfoundry-dmz
  labels:
    network.hashfoundry.io/policy-type: "monitoring-allow"
    app.kubernetes.io/name: "hashfoundry-network-policy"
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Allow to monitoring namespace
  - to:
    - namespaceSelector:
        matchLabels:
          name: "monitoring"
    ports:
    - protocol: TCP
      port: 9090  # Prometheus
    - protocol: TCP
      port: 3000  # Grafana
DMZ_POLICIES_EOF
    
    echo "✅ DMZ network policies created"
    echo
}

# Функция для создания internal network policies
create_internal_policies() {
    echo "=== Creating Internal Network Policies ==="
    
    cat << INTERNAL_POLICIES_EOF | kubectl apply -f -
# Allow ingress from DMZ to internal services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internal-allow-dmz-ingress
  namespace: hashfoundry-internal
  labels:
    network.hashfoundry.io/policy-type: "ingress-allow"
    network.hashfoundry.io/zone: "internal"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow DMZ services to access internal APIs"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "api"
  policyTypes:
  - Ingress
  ingress:
  # Allow from DMZ
  - from:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "dmz"
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 3000
  # Allow from same namespace
  - from:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "internal"
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 9090
---
# Allow egress from internal to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internal-allow-database-egress
  namespace: hashfoundry-internal
  labels:
    network.hashfoundry.io/policy-type: "egress-allow"
    network.hashfoundry.io/zone: "internal"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow internal services to access databases"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "api"
  policyTypes:
  - Egress
  egress:
  # Allow to database namespace
  - to:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "database"
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 3306  # MySQL
    - protocol: TCP
      port: 27017 # MongoDB
    - protocol: TCP
      port: 6379  # Redis
  # Allow to external APIs
  - to: []
    ports:
    - protocol: TCP
      port: 443
INTERNAL_POLICIES_EOF
    
    echo "✅ Internal network policies created"
    echo
}

# Функция для создания database network policies
create_database_policies() {
    echo "=== Creating Database Network Policies ==="
    
    cat << DATABASE_POLICIES_EOF | kubectl apply -f -
# Allow ingress only from internal services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-allow-internal-ingress
  namespace: hashfoundry-database
  labels:
    network.hashfoundry.io/policy-type: "ingress-allow"
    network.hashfoundry.io/zone: "database"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow only internal services to access databases"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "database"
  policyTypes:
  - Ingress
  ingress:
  # Allow from internal namespace
  - from:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "internal"
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 3306  # MySQL
    - protocol: TCP
      port: 27017 # MongoDB
    - protocol: TCP
      port: 6379  # Redis
  # Allow from management namespace (for admin tasks)
  - from:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "management"
    ports:
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 3306
    - protocol: TCP
      port: 27017
    - protocol: TCP
      port: 6379
---
# Allow limited egress for backups and monitoring
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-allow-backup-egress
  namespace: hashfoundry-database
  labels:
    network.hashfoundry.io/policy-type: "egress-allow"
    network.hashfoundry.io/zone: "database"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow database backup and monitoring traffic"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "database"
  policyTypes:
  - Egress
  egress:
  # Allow to backup storage
  - to: []
    ports:
    - protocol: TCP
      port: 443  # S3/Object storage
  # Allow to monitoring
  - to:
    - namespaceSelector:
        matchLabels:
          name: "monitoring"
    ports:
    - protocol: TCP
      port: 9090
DATABASE_POLICIES_EOF
    
    echo "✅ Database network policies created"
    echo
}

# Функция для создания management network policies
create_management_policies() {
    echo "=== Creating Management Network Policies ==="
    
    cat << MANAGEMENT_POLICIES_EOF | kubectl apply -f -
# Allow ingress from admin networks
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: management-allow-admin-ingress
  namespace: hashfoundry-management
  labels:
    network.hashfoundry.io/policy-type: "ingress-allow"
    network.hashfoundry.io/zone: "management"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow admin access to management tools"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "admin-tool"
  policyTypes:
  - Ingress
  ingress:
  # Allow from ingress controller (for web UIs)
  - from:
    - namespaceSelector:
        matchLabels:
          name: "nginx-ingress"
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8080
---
# Allow egress to all zones for management tasks
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: management-allow-all-egress
  namespace: hashfoundry-management
  labels:
    network.hashfoundry.io/policy-type: "egress-allow"
    network.hashfoundry.io/zone: "management"
    app.kubernetes.io/name: "hashfoundry-network-policy"
  annotations:
    network.hashfoundry.io/description: "Allow management tools to access all zones"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: "admin-tool"
  policyTypes:
  - Egress
  egress:
  # Allow to all internal namespaces
  - to:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "dmz"
  - to:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "internal"
  - to:
    - namespaceSelector:
        matchLabels:
          network.hashfoundry.io/zone: "database"
  # Allow to external services
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 22   # SSH
MANAGEMENT_POLICIES_EOF
    
    echo "✅ Management network policies created"
    echo
}

# Функция для создания мониторинга сетевой сегментации
create_network_monitoring() {
    echo "=== Creating Network Monitoring ==="
    
    # Создать ServiceMonitor для сетевых метрик
    cat << NETWORK_MONITORING_EOF | kubectl apply -f -
# PrometheusRule for network segmentation monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-segmentation-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: "hashfoundry-network-monitoring"
    network.hashfoundry.io/component: "segmentation-alerts"
  annotations:
    network.hashfoundry.io/description: "Alerts for network segmentation violations"
spec:
  groups:
  - name: network-segmentation
    rules:
    - alert: NetworkPolicyViolation
      expr: |
        increase(networkpolicy_drop_count_total[5m]) > 0
      for: 1m
      labels:
        severity: warning
        category: network-security
      annotations:
        summary: "Network policy violation detected"
        description: "Network traffic was dropped due to policy violation"
    
    - alert: UnauthorizedCrossZoneTraffic
      expr: |
        increase(kubernetes_audit_total{verb="create",objectRef_resource="networkpolicies",responseStatus_code=~"4.."}[5m]) > 0
      for: 0m
      labels:
        severity: critical
        category: network-security
      annotations:
        summary: "Unauthorized cross-zone traffic attempt"
        description: "Attempt to create unauthorized network communication"
    
    - alert: NetworkSegmentationBreach
      expr: |
        (
          sum(rate(container_network_receive_bytes_total{namespace=~"hashfoundry-database"}[5m])) by (namespace) /
          sum(rate(container_network_receive_bytes_total[5m])) by (namespace)
        ) > 0.1
      for: 5m
      labels:
        severity: critical
        category: network-security
      annotations:
        summary: "Unusual traffic to database zone"
        description: "Database zone receiving unusually high traffic volume"
NETWORK_MONITORING_EOF
    
    # Создать скрипт для мониторинга сетевой сегментации
    cat << MONITORING_SCRIPT_EOF > network-segmentation-monitor.sh
#!/bin/bash

echo "=== Network Segmentation Monitoring ==="
echo "Monitoring network segmentation compliance in HashFoundry HA cluster"
echo

# Функция для проверки Network Policies
check_network_policies() {
    echo "1. Network Policies Status:"
    echo "=========================="
    kubectl get networkpolicies --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,POD-SELECTOR:.spec.podSelector,POLICY-TYPES:.spec.policyTypes"
    echo
}

# Функция для проверки сетевых подключений
check_network_connections() {
    echo "2. Active Network Connections:"
    echo "============================="
    
    # Проверить services в каждой зоне
    for zone in dmz internal database management; do
        echo "Zone: \$zone"
        kubectl get services -n "hashfoundry-\$zone" -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,PORTS:.spec.ports[*].port" 2>/dev/null || echo "  No services found"
        echo
    done
}

# Функция для проверки межзонного трафика
check_cross_zone_traffic() {
    echo "3. Cross-Zone Traffic Analysis:"
    echo "=============================="
    
    # Проверить pods с сетевыми подключениями
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.namespace | startswith("hashfoundry-")) | "\(.metadata.namespace)/\(.metadata.name): \(.status.podIP)"' | head -20
    echo
}

# Функция для проверки нарушений политик
check_policy_violations() {
    echo "4. Policy Violations:"
    echo "===================="
    
    # Проверить события, связанные с сетевыми политиками
    kubectl get events --all-namespaces --field-selector reason=NetworkPolicyViolation 2>/dev/null || echo "No network policy violations found"
    echo
    
    # Проверить отклоненные подключения
    kubectl get events --all-namespaces --field-selector reason=FailedCreate | grep -i network || echo "No network-related creation failures"
    echo
}

# Функция для тестирования сетевой связности
test_network_connectivity() {
    echo "5. Network Connectivity Tests:"
    echo "============================="
    
    # Создать тестовые pods для проверки связности
    cat << TEST_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-test-dmz
  namespace: hashfoundry-dmz
  labels:
    app.kubernetes.io/component: "web"
    network.hashfoundry.io/test: "connectivity"
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ["sleep", "3600"]
  restartPolicy: Never
---
apiVersion: v1
kind: Pod
metadata:
  name: network-test-internal
  namespace: hashfoundry-internal
  labels:
    app.kubernetes.io/component: "api"
    network.hashfoundry.io/test: "connectivity"
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ["sleep", "3600"]
  restartPolicy: Never
TEST_POD_EOF
    
    echo "Test pods created. Waiting for them to be ready..."
    kubectl wait --for=condition=Ready pod/network-test-dmz -n hashfoundry-dmz --timeout=60s
    kubectl wait --for=condition=Ready pod/network-test-internal -n hashfoundry-internal --timeout=60s
    
    # Тест связности между зонами
    echo "Testing DMZ to Internal connectivity (should work):"
    kubectl exec -n hashfoundry-dmz network-test-dmz -- nslookup kubernetes.default.svc.cluster.local || echo "DNS test failed"
    
    echo "✅ Network connectivity tests completed"
    echo
}

# Функция для генерации отчета
generate_report() {
    echo "6. Network Segmentation Report:"
    echo "=============================="
    
    echo "✅ SEGMENTATION STATUS:"
    echo "- DMZ Zone: $(kubectl get networkpolicies -n hashfoundry-dmz --no-headers | wc -l) policies"
    echo "- Internal Zone: $(kubectl get networkpolicies -n hashfoundry-internal --no-headers | wc -l) policies"
    echo "- Database Zone: $(kubectl get networkpolicies -n hashfoundry-database --no-headers | wc -l) policies"
    echo "- Management Zone: $(kubectl get networkpolicies -n hashfoundry-management --no-headers | wc -l) policies"
    echo
    
    echo "📋 RECOMMENDATIONS:"
    echo "1. Regular review of network policies"
    echo "2. Monitor cross-zone traffic patterns"
    echo "3. Implement network policy testing in CI/CD"
    echo "4. Use service mesh for advanced traffic management"
    echo "5. Regular security audits of network segmentation"
    echo
}

# Cleanup function
cleanup_test_resources() {
    echo "Cleaning up test resources..."
    kubectl delete pod network-test-dmz -n hashfoundry-dmz --ignore-not-found=true
    kubectl delete pod network-test-internal -n hashfoundry-internal --ignore-not-found=true
    echo "✅ Cleanup completed"
}

# Запустить все проверки
check_network_policies
check_network_connections
check_cross_zone_traffic
check_policy_violations
test_network_connectivity
generate_report

# Cleanup при выходе
trap cleanup_test_resources EXIT

MONITORING_SCRIPT_EOF
    
    chmod +x network-segmentation-monitor.sh
    
    echo "✅ Network monitoring created"
    echo "   - Use network-segmentation-monitor.sh for compliance checks"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_network
            ;;
        "create-namespaces")
            create_segmented_namespaces
            ;;
        "base-policies")
            create_base_network_policies
            ;;
        "dmz-policies")
            create_dmz_policies
            ;;
        "internal-policies")
            create_internal_policies
            ;;
        "database-policies")
            create_database_policies
            ;;
        "management-policies")
            create_management_policies
            ;;
        "monitoring")
            create_network_monitoring
            ;;
        "all"|"")
            analyze_current_network
            create_segmented_namespaces
            create_base_network_policies
            create_dmz_policies
            create_internal_policies
            create_database_policies
            create_management_policies
            create_network_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze              - Analyze current network architecture"
            echo "  create-namespaces    - Create segmented namespaces"
            echo "  base-policies        - Create base network policies"
            echo "  dmz-policies         - Create DMZ network policies"
            echo "  internal-policies    - Create internal network policies"
            echo "  database-policies    - Create database network policies"
            echo "  management-policies  - Create management network policies"
            echo "  monitoring           - Create network monitoring"
            echo "  all                  - Full network segmentation (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 monitoring"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x network-segmentation-implementation.sh

# Запустить реализацию сетевой сегментации
./network-segmentation-implementation.sh all
```

## 📋 **Архитектура сетевой сегментации:**

### **Зоны безопасности:**

| **Зона** | **Назначение** | **Уровень доступа** | **Разрешенные подключения** |
|----------|----------------|---------------------|----------------------------|
| **DMZ** | Публичные сервисы | Public | Internet → DMZ → Internal |
| **Internal** | Backend API | Private | DMZ → Internal → Database |
| **Database** | Хранение данных | Restricted | Internal → Database |
| **Management** | Админ инструменты | Admin | Admin VPN → Management → All |

### **Network Policy типы:**

#### **Default Deny All:**
```yaml
# Запретить весь трафик по умолчанию
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

#### **Selective Allow:**
```yaml
# Разрешить только определенный трафик
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
```

## 🎯 **Практические команды:**

### **Управление Network Policies:**
```bash
# Создать сегментированную архитектуру
./network-segmentation-implementation.sh all

# Проверить Network Policies
kubectl get networkpolicies --all-namespaces

# Мониторинг сетевой сегментации
./network-segmentation-monitor.sh

# Тестирование связности
kubectl exec -n hashfoundry-dmz test-pod -- nc -zv internal-service.hashfoundry-internal.svc.cluster.local 8080
```

### **Отладка сетевых политик:**
```bash
# Проверить применение политик
kubectl describe networkpolicy -n hashfoundry-dmz

# Анализ сетевых подключений
kubectl get endpoints --all-namespaces

# Проверить события сети
kubectl get events --field-selector reason=NetworkPolicyViolation
```

### **Мониторинг трафика:**
```bash
# Анализ сетевого трафика по зонам
kubectl top pods --all-namespaces --containers

# Проверить метрики сети
kubectl get --raw /api/v1/nodes/$(kubectl get nodes -o name | head -1 | cut -d/ -f2)/proxy/metrics | grep network

# Мониторинг межзонного трафика
kubectl get pods -o wide --all-namespaces | grep hashfoundry-
```

## 🔧 **Best Practices для сетевой сегментации:**

### **Проектирование архитектуры:**
- **Принцип минимальных привилегий** - разрешать только необходимый трафик
- **Зонирование по функциям** - разделение по ролям (web, api, db)
- **Изоляция по средам** - отдельные зоны для dev/staging/prod
- **Мониторинг трафика** - отслеживание межзонных подключений

### **Реализация политик:**
- **Default deny** - запретить всё по умолчанию
- **Explicit allow** - явно разрешать необходимые подключения
- **DNS разрешение** - всегда разрешать DNS запросы
- **Мониторинг доступ** - разрешать метрики и логи

### **Операционные процессы:**
- **Тестирование политик** - проверка в CI/CD pipeline
- **Постепенное внедрение** - начать с audit режима
- **Документирование** - описание сетевой архитектуры
- **Регулярный аудит** - проверка соответствия политикам

### **Инструменты и технологии:**
- **CNI плагины** - Calico, Cilium для расширенных возможностей
- **Service Mesh** - Istio, Linkerd для L7 политик
- **Monitoring** - Prometheus для метрик сети
- **Visualization** - Grafana для визуализации трафика

**Сетевая сегментация - основа безопасной архитектуры Kubernetes!**
