# 103. Разница между metrics-server и Prometheus

## 🎯 **Разница между metrics-server и Prometheus**

**metrics-server** и **Prometheus** - это два разных компонента экосистемы мониторинга Kubernetes, каждый из которых решает свои специфические задачи. Понимание их различий критически важно для правильной архитектуры мониторинга.

## 🏗️ **Основные различия:**

### **1. Назначение:**
- **metrics-server** - Resource Metrics API для автомасштабирования
- **Prometheus** - Полноценная система мониторинга и алертинга

### **2. Область применения:**
- **metrics-server** - HPA, VPA, kubectl top
- **Prometheus** - Мониторинг, алертинг, долгосрочное хранение

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Сравнительный анализ metrics-server и Prometheus:**
```bash
# Проверить наличие обоих компонентов
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus
```

### **2. Создание comprehensive comparison toolkit:**
```bash
# Создать скрипт для сравнения metrics-server и Prometheus
cat << 'EOF' > metrics-server-vs-prometheus-toolkit.sh
#!/bin/bash

echo "=== metrics-server vs Prometheus Comparison Toolkit ==="
echo "Comprehensive comparison analysis for HashFoundry HA cluster"
echo

# Функция для анализа metrics-server
analyze_metrics_server() {
    echo "=== metrics-server Analysis ==="
    
    echo "1. metrics-server Status:"
    echo "========================"
    METRICS_SERVER_POD=$(kubectl get pods -n kube-system -l k8s-app=metrics-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$METRICS_SERVER_POD" ]; then
        echo "✅ metrics-server found: $METRICS_SERVER_POD"
        kubectl get pods -n kube-system -l k8s-app=metrics-server -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp"
    else
        echo "❌ metrics-server not found"
        return 1
    fi
    echo
    
    echo "2. metrics-server Configuration:"
    echo "==============================="
    kubectl get deployment metrics-server -n kube-system -o yaml | grep -A 15 "args:" || echo "Cannot get metrics-server configuration"
    echo
    
    echo "3. Resource Metrics API:"
    echo "======================="
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1" 2>/dev/null | jq '.resources[].name' || echo "Resource Metrics API not available"
    echo
    
    echo "4. metrics-server Capabilities:"
    echo "==============================="
    echo "✓ Provides Resource Metrics API"
    echo "✓ Supports kubectl top commands"
    echo "✓ Enables HPA (Horizontal Pod Autoscaler)"
    echo "✓ Enables VPA (Vertical Pod Autoscaler)"
    echo "✓ Short-term metrics storage (in-memory)"
    echo "✗ No long-term storage"
    echo "✗ No custom metrics"
    echo "✗ No alerting capabilities"
    echo "✗ No visualization"
    echo
    
    echo "5. metrics-server Data Sources:"
    echo "=============================="
    echo "• kubelet Summary API (/stats/summary)"
    echo "• cAdvisor metrics (via kubelet)"
    echo "• Node resource usage"
    echo "• Pod resource usage"
    echo
    
    echo "6. metrics-server Use Cases:"
    echo "==========================="
    echo "• Horizontal Pod Autoscaling (HPA)"
    echo "• Vertical Pod Autoscaling (VPA)"
    echo "• kubectl top nodes/pods"
    echo "• Resource-based scheduling decisions"
    echo "• Basic resource monitoring"
    echo
}

# Функция для анализа Prometheus
analyze_prometheus() {
    echo "=== Prometheus Analysis ==="
    
    echo "1. Prometheus Status:"
    echo "===================="
    PROMETHEUS_POD=$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    PROMETHEUS_NAMESPACE=$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -n "$PROMETHEUS_POD" ] && [ -n "$PROMETHEUS_NAMESPACE" ]; then
        echo "✅ Prometheus found: $PROMETHEUS_NAMESPACE/$PROMETHEUS_POD"
        kubectl get pods -n "$PROMETHEUS_NAMESPACE" -l app.kubernetes.io/name=prometheus -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp"
    else
        echo "❌ Prometheus not found"
        return 1
    fi
    echo
    
    echo "2. Prometheus Configuration:"
    echo "==========================="
    kubectl get configmaps -n "$PROMETHEUS_NAMESPACE" -l app.kubernetes.io/name=prometheus -o custom-columns="NAME:.metadata.name,DATA-KEYS:.data" || echo "Cannot get Prometheus configuration"
    echo
    
    echo "3. Prometheus Targets:"
    echo "====================="
    # Попытка получить targets (требует port-forward)
    echo "Note: Requires port-forward to access Prometheus API"
    echo "Command: kubectl port-forward -n $PROMETHEUS_NAMESPACE $PROMETHEUS_POD 9090:9090"
    echo
    
    echo "4. Prometheus Capabilities:"
    echo "=========================="
    echo "✓ Long-term metrics storage"
    echo "✓ Custom metrics collection"
    echo "✓ Powerful query language (PromQL)"
    echo "✓ Alerting rules and AlertManager integration"
    echo "✓ Service discovery"
    echo "✓ Grafana integration"
    echo "✓ Historical data analysis"
    echo "✓ Multi-dimensional data model"
    echo "✗ Not suitable for real-time autoscaling"
    echo "✗ More complex setup and maintenance"
    echo
    
    echo "5. Prometheus Data Sources:"
    echo "=========================="
    echo "• Application /metrics endpoints"
    echo "• kube-state-metrics"
    echo "• Node Exporter"
    echo "• Custom exporters"
    echo "• ServiceMonitors (Prometheus Operator)"
    echo "• PodMonitors (Prometheus Operator)"
    echo
    
    echo "6. Prometheus Use Cases:"
    echo "======================="
    echo "• Application performance monitoring"
    echo "• Infrastructure monitoring"
    echo "• Alerting and incident response"
    echo "• Capacity planning"
    echo "• SLI/SLO monitoring"
    echo "• Business metrics tracking"
    echo "• Debugging and troubleshooting"
    echo
}

# Функция для создания сравнительной таблицы
create_comparison_table() {
    echo "=== Creating Detailed Comparison Table ==="
    
    cat << COMPARISON_TABLE_EOF > metrics-server-vs-prometheus-comparison.md
# metrics-server vs Prometheus Detailed Comparison

## 📊 Feature Comparison

| **Feature** | **metrics-server** | **Prometheus** |
|-------------|-------------------|----------------|
| **Primary Purpose** | Resource Metrics API | Full monitoring system |
| **Data Storage** | In-memory (short-term) | Persistent (long-term) |
| **Query Language** | None (REST API only) | PromQL |
| **Alerting** | ❌ No | ✅ Yes (with AlertManager) |
| **Visualization** | ❌ No | ✅ Yes (with Grafana) |
| **Custom Metrics** | ❌ No | ✅ Yes |
| **Historical Data** | ❌ No | ✅ Yes |
| **HPA Support** | ✅ Primary use case | ❌ Not directly |
| **Resource Usage** | Low | Higher |
| **Setup Complexity** | Simple | Complex |
| **Scalability** | Limited | High |

## 🎯 Use Case Matrix

| **Use Case** | **metrics-server** | **Prometheus** | **Recommendation** |
|--------------|-------------------|----------------|-------------------|
| **HPA/VPA** | ✅ Perfect | ❌ Not suitable | Use metrics-server |
| **kubectl top** | ✅ Perfect | ❌ Not suitable | Use metrics-server |
| **Application Monitoring** | ❌ Limited | ✅ Perfect | Use Prometheus |
| **Alerting** | ❌ No support | ✅ Perfect | Use Prometheus |
| **Dashboards** | ❌ No support | ✅ Perfect | Use Prometheus + Grafana |
| **Capacity Planning** | ❌ Limited | ✅ Perfect | Use Prometheus |
| **SLI/SLO Monitoring** | ❌ No support | ✅ Perfect | Use Prometheus |
| **Debugging** | ❌ Limited | ✅ Perfect | Use Prometheus |

## 🏗️ Architecture Differences

### metrics-server Architecture:
\`\`\`
┌─────────────────┐    ┌─────────────────┐
│     kubelet     │    │   cAdvisor      │
│   Summary API   │    │   (embedded)    │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          └──────────┬───────────┘
                     │
                     ▼
          ┌─────────────────────┐
          │   metrics-server    │
          │   (aggregation)     │
          └─────────┬───────────┘
                    │
                    ▼
          ┌─────────────────────┐
          │ Resource Metrics API│
          │ /apis/metrics.k8s.io│
          └─────────────────────┘
\`\`\`

### Prometheus Architecture:
\`\`\`
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│Application  │  │kube-state-  │  │Node Exporter│
│/metrics     │  │metrics      │  │             │
└─────┬───────┘  └─────┬───────┘  └─────┬───────┘
      │                │                │
      └────────────────┼────────────────┘
                       │
                       ▼
            ┌─────────────────────┐
            │    Prometheus       │
            │  (scraping + TSDB)  │
            └─────────┬───────────┘
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │Grafana  │ │AlertMgr │ │PromQL   │
    │         │ │         │ │ API     │
    └─────────┘ └─────────┘ └─────────┘
\`\`\`

## 🔧 Configuration Examples

### metrics-server Deployment:
\`\`\`yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - name: metrics-server
        image: k8s.gcr.io/metrics-server/metrics-server:v0.6.1
        args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
\`\`\`

### Prometheus Configuration:
\`\`\`yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
    - job_name: 'kubernetes-apiservers'
      kubernetes_sd_configs:
      - role: endpoints
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
\`\`\`

## 💡 Best Practices

### When to use metrics-server:
- ✅ You need HPA/VPA functionality
- ✅ You want kubectl top commands
- ✅ You need basic resource monitoring
- ✅ You prefer simple, lightweight solution
- ✅ You don't need historical data

### When to use Prometheus:
- ✅ You need comprehensive monitoring
- ✅ You want custom metrics and alerting
- ✅ You need historical data analysis
- ✅ You want to monitor application performance
- ✅ You need SLI/SLO monitoring
- ✅ You want integration with Grafana

### Recommended Architecture:
**Use both together!**
- **metrics-server** for autoscaling and basic resource monitoring
- **Prometheus** for comprehensive monitoring, alerting, and observability

COMPARISON_TABLE_EOF
    
    echo "✅ Detailed comparison table created: metrics-server-vs-prometheus-comparison.md"
    echo
}

# Функция для создания практических тестов
create_practical_tests() {
    echo "=== Creating Practical Tests ==="
    
    cat << PRACTICAL_TESTS_EOF > test-metrics-server-vs-prometheus.sh
#!/bin/bash

echo "=== Practical Tests: metrics-server vs Prometheus ==="
echo "Testing both systems in HashFoundry HA cluster"
echo

# Function to test metrics-server functionality
test_metrics_server_functionality() {
    echo "1. Testing metrics-server Functionality:"
    echo "======================================="
    
    echo "Testing Resource Metrics API..."
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" >/dev/null 2>&1
    if [ \$? -eq 0 ]; then
        echo "✅ Resource Metrics API working"
        echo "Available resources:"
        kubectl get --raw "/apis/metrics.k8s.io/v1beta1" | jq '.resources[].name'
    else
        echo "❌ Resource Metrics API not working"
    fi
    echo
    
    echo "Testing kubectl top commands..."
    kubectl top nodes >/dev/null 2>&1
    if [ \$? -eq 0 ]; then
        echo "✅ kubectl top nodes working"
        kubectl top nodes | head -3
    else
        echo "❌ kubectl top nodes not working"
    fi
    echo
    
    kubectl top pods --all-namespaces >/dev/null 2>&1
    if [ \$? -eq 0 ]; then
        echo "✅ kubectl top pods working"
        kubectl top pods --all-namespaces | head -5
    else
        echo "❌ kubectl top pods not working"
    fi
    echo
    
    echo "Testing HPA compatibility..."
    # Create a test HPA to verify metrics-server integration
    cat << HPA_TEST_EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: test-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: test-deployment
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
HPA_TEST_EOF
    
    sleep 5
    kubectl get hpa test-hpa >/dev/null 2>&1
    if [ \$? -eq 0 ]; then
        echo "✅ HPA creation successful"
        kubectl describe hpa test-hpa | grep -E "(Metrics|Current|Target)"
        kubectl delete hpa test-hpa
    else
        echo "❌ HPA creation failed"
    fi
    echo
}

# Function to test Prometheus functionality
test_prometheus_functionality() {
    echo "2. Testing Prometheus Functionality:"
    echo "==================================="
    
    PROMETHEUS_POD=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    PROMETHEUS_NAMESPACE=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -z "\$PROMETHEUS_POD" ] || [ -z "\$PROMETHEUS_NAMESPACE" ]; then
        echo "❌ Prometheus not found - skipping tests"
        return 1
    fi
    
    echo "✅ Prometheus found: \$PROMETHEUS_NAMESPACE/\$PROMETHEUS_POD"
    
    echo "Testing Prometheus API..."
    kubectl port-forward -n "\$PROMETHEUS_NAMESPACE" "\$PROMETHEUS_POD" 9090:9090 &
    PF_PID=\$!
    sleep 5
    
    # Test basic API connectivity
    curl -s "http://localhost:9090/api/v1/targets" >/dev/null 2>&1
    if [ \$? -eq 0 ]; then
        echo "✅ Prometheus API accessible"
        
        # Test targets
        TARGETS_COUNT=\$(curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets | length')
        echo "Active targets: \$TARGETS_COUNT"
        
        # Test basic queries
        echo "Testing PromQL queries..."
        UP_TARGETS=\$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result | length')
        echo "Up targets: \$UP_TARGETS"
        
        # Test node metrics
        NODE_METRICS=\$(curl -s "http://localhost:9090/api/v1/query?query=node_cpu_seconds_total" | jq '.data.result | length')
        echo "Node CPU metrics: \$NODE_METRICS"
        
        # Test kube-state-metrics
        KUBE_METRICS=\$(curl -s "http://localhost:9090/api/v1/query?query=kube_pod_info" | jq '.data.result | length')
        echo "Kube state metrics: \$KUBE_METRICS"
        
    else
        echo "❌ Prometheus API not accessible"
    fi
    
    kill \$PF_PID 2>/dev/null
    echo
}

# Function to compare data availability
compare_data_availability() {
    echo "3. Comparing Data Availability:"
    echo "=============================="
    
    echo "metrics-server data:"
    echo "-------------------"
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" 2>/dev/null | jq '.items | length' | xargs echo "Node metrics count:"
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" 2>/dev/null | jq '.items | length' | xargs echo "Pod metrics count:"
    echo "Data retention: In-memory only (no historical data)"
    echo "Update frequency: ~15 seconds"
    echo
    
    echo "Prometheus data (if available):"
    echo "------------------------------"
    PROMETHEUS_POD=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    PROMETHEUS_NAMESPACE=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -n "\$PROMETHEUS_POD" ] && [ -n "\$PROMETHEUS_NAMESPACE" ]; then
        kubectl port-forward -n "\$PROMETHEUS_NAMESPACE" "\$PROMETHEUS_POD" 9090:9090 &
        PF_PID=\$!
        sleep 3
        
        SERIES_COUNT=\$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq '.data | length' 2>/dev/null)
        echo "Metric series count: \$SERIES_COUNT"
        echo "Data retention: Configurable (default 15 days)"
        echo "Update frequency: Configurable (default 15 seconds)"
        
        kill \$PF_PID 2>/dev/null
    else
        echo "Prometheus not available for comparison"
    fi
    echo
}

# Function to generate performance comparison
generate_performance_comparison() {
    echo "4. Performance Comparison:"
    echo "========================="
    
    echo "metrics-server resource usage:"
    kubectl top pods -n kube-system -l k8s-app=metrics-server 2>/dev/null || echo "metrics-server resource usage not available"
    echo
    
    echo "Prometheus resource usage:"
    PROMETHEUS_NAMESPACE=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    if [ -n "\$PROMETHEUS_NAMESPACE" ]; then
        kubectl top pods -n "\$PROMETHEUS_NAMESPACE" -l app.kubernetes.io/name=prometheus 2>/dev/null || echo "Prometheus resource usage not available"
    else
        echo "Prometheus not found"
    fi
    echo
}

# Main test function
main() {
    echo "Starting comprehensive comparison tests..."
    echo
    
    test_metrics_server_functionality
    test_prometheus_functionality
    compare_data_availability
    generate_performance_comparison
    
    echo "✅ Comparison tests completed"
    echo
    echo "Summary:"
    echo "========"
    echo "• metrics-server: Lightweight, focused on autoscaling"
    echo "• Prometheus: Comprehensive, focused on monitoring"
    echo "• Recommendation: Use both for complete observability"
}

# Run main function
main

PRACTICAL_TESTS_EOF
    
    chmod +x test-metrics-server-vs-prometheus.sh
    
    echo "✅ Practical tests script created: test-metrics-server-vs-prometheus.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "metrics-server")
            analyze_metrics_server
            ;;
        "prometheus")
            analyze_prometheus
            ;;
        "comparison")
            create_comparison_table
            ;;
        "test")
            create_practical_tests
            ./test-metrics-server-vs-prometheus.sh
            ;;
        "all"|"")
            analyze_metrics_server
            analyze_prometheus
            create_comparison_table
            create_practical_tests
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  metrics-server  - Analyze metrics-server"
            echo "  prometheus      - Analyze Prometheus"
            echo "  comparison      - Create detailed comparison table"
            echo "  test           - Create and run practical tests"
            echo "  all            - Run all analyses and create tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0 metrics-server"
            echo "  $0 comparison"
            echo "  $0 test"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x metrics-server-vs-prometheus-toolkit.sh

# Запустить создание comparison toolkit
./metrics-server-vs-prometheus-toolkit.sh all
```

## 📋 **Ключевые различия:**

### **Архитектурные различия:**

| **Аспект** | **metrics-server** | **Prometheus** |
|------------|-------------------|----------------|
| **Цель** | Resource Metrics API | Полная система мониторинга |
| **Хранение** | В памяти (краткосрочно) | Постоянное (долгосрочно) |
| **Запросы** | REST API | PromQL |
| **Алертинг** | ❌ Нет | ✅ Да |
| **Визуализация** | ❌ Нет | ✅ Да (Grafana) |

### **Функциональные различия:**

| **Функция** | **metrics-server** | **Prometheus** |
|-------------|-------------------|----------------|
| **HPA поддержка** | ✅ Основное назначение | ❌ Не напрямую |
| **kubectl top** | ✅ Да | ❌ Нет |
| **Пользовательские метрики** | ❌ Нет | ✅ Да |
| **Исторические данные** | ❌ Нет | ✅ Да |
| **Сложность настройки** | Простая | Сложная |

## 🎯 **Практические команды:**

### **Сравнительный анализ:**
```bash
# Запустить полное сравнение
./metrics-server-vs-prometheus-toolkit.sh all

# Тестировать оба компонента
./test-metrics-server-vs-prometheus.sh

# Создать сравнительную таблицу
./metrics-server-vs-prometheus-toolkit.sh comparison
```

### **Проверка metrics-server:**
```bash
# Проверить статус
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Тестировать функциональность
kubectl top nodes
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

### **Проверка Prometheus:**
```bash
# Найти Prometheus
kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus

# Проверить targets (требует port-forward)
kubectl port-forward prometheus-pod 9090:9090
curl http://localhost:9090/api/v1/targets
```

## 🔧 **Рекомендации по использованию:**

### **Используйте metrics-server когда:**
- **Нужен HPA/VPA** - автомасштабирование
- **Нужен kubectl top** - базовый мониторинг ресурсов
- **Простота важнее функциональности**
- **Ограниченные ресурсы кластера**

### **Используйте Prometheus когда:**
- **Нужен комплексный мониторинг**
- **Нужны алерты и уведомления**
- **Нужны исторические данные**
- **Нужны пользовательские метрики**
- **Нужна интеграция с Grafana**

### **Лучшая практика:**
**Используйте оба компонента вместе!**
- **metrics-server** для автомасштабирования
- **Prometheus** для полноценного мониторинга

**Понимание различий между metrics-server и Prometheus поможет выбрать правильный инструмент для каждой задачи!**
