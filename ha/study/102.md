# 102. Как работает сбор метрик в Kubernetes

## 🎯 **Как работает сбор метрик в Kubernetes**

**Сбор метрик в Kubernetes** - это комплексная система, включающая несколько компонентов для мониторинга состояния кластера, узлов и приложений. Понимание архитектуры сбора метрик критически важно для эффективного мониторинга.

## 🏗️ **Архитектура сбора метрик:**

### **1. Core Metrics Pipeline:**
- **kubelet** - собирает метрики с узлов
- **cAdvisor** - мониторит контейнеры
- **metrics-server** - агрегирует метрики ресурсов
- **kube-state-metrics** - экспортирует метрики состояния объектов

### **2. Monitoring Pipeline:**
- **Prometheus** - сбор и хранение метрик
- **Node Exporter** - метрики операционной системы
- **Custom Exporters** - специализированные метрики
- **Service Discovery** - автоматическое обнаружение целей

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей системы сбора метрик:**
```bash
# Проверить компоненты сбора метрик
kubectl get pods -n kube-system | grep -E "(metrics-server|prometheus|grafana)"
```

### **2. Создание comprehensive metrics collection analysis toolkit:**
```bash
# Создать скрипт для анализа сбора метрик
cat << 'EOF' > kubernetes-metrics-collection-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Metrics Collection Analysis Toolkit ==="
echo "Comprehensive analysis of metrics collection in HashFoundry HA cluster"
echo

# Функция для анализа Core Metrics Pipeline
analyze_core_metrics_pipeline() {
    echo "=== Core Metrics Pipeline Analysis ==="
    
    echo "1. Metrics Server Status:"
    echo "========================"
    kubectl get pods -n kube-system -l k8s-app=metrics-server -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp"
    echo
    
    echo "2. Metrics Server Configuration:"
    echo "==============================="
    kubectl get deployment metrics-server -n kube-system -o yaml | grep -A 10 -B 5 "args:" || echo "Metrics server not found"
    echo
    
    echo "3. Kubelet Metrics Endpoints:"
    echo "============================"
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        echo "Node: $node"
        kubectl get --raw "/api/v1/nodes/$node/proxy/metrics/cadvisor" 2>/dev/null | head -5 || echo "  cAdvisor metrics not accessible"
        kubectl get --raw "/api/v1/nodes/$node/proxy/metrics" 2>/dev/null | head -5 || echo "  Kubelet metrics not accessible"
        echo
    done
    
    echo "4. kube-state-metrics Status:"
    echo "============================"
    kubectl get pods --all-namespaces -l app.kubernetes.io/name=kube-state-metrics -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status" || echo "kube-state-metrics not found"
    echo
    
    echo "5. Resource Metrics API:"
    echo "======================="
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" 2>/dev/null | jq '.items[].metadata.name' || echo "Resource Metrics API not available"
    echo
}

# Функция для анализа Monitoring Pipeline
analyze_monitoring_pipeline() {
    echo "=== Monitoring Pipeline Analysis ==="
    
    echo "1. Prometheus Instances:"
    echo "======================="
    kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,AGE:.metadata.creationTimestamp" || echo "Prometheus not found"
    echo
    
    echo "2. Prometheus Configuration:"
    echo "==========================="
    kubectl get configmaps --all-namespaces -l app.kubernetes.io/name=prometheus -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,DATA-KEYS:.data" || echo "Prometheus ConfigMaps not found"
    echo
    
    echo "3. Node Exporter Status:"
    echo "======================="
    kubectl get pods --all-namespaces -l app.kubernetes.io/name=node-exporter -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName" || echo "Node Exporter not found"
    echo
    
    echo "4. Service Monitors:"
    echo "==================="
    kubectl get servicemonitors --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SELECTOR:.spec.selector.matchLabels,ENDPOINTS:.spec.endpoints[*].port" 2>/dev/null || echo "ServiceMonitors not available (Prometheus Operator not installed)"
    echo
    
    echo "5. Prometheus Targets:"
    echo "====================="
    # Попытка получить targets из Prometheus API (если доступен)
    PROMETHEUS_POD=$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    PROMETHEUS_NAMESPACE=$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -n "$PROMETHEUS_POD" ] && [ -n "$PROMETHEUS_NAMESPACE" ]; then
        echo "Prometheus Pod: $PROMETHEUS_NAMESPACE/$PROMETHEUS_POD"
        kubectl port-forward -n "$PROMETHEUS_NAMESPACE" "$PROMETHEUS_POD" 9090:9090 &
        PF_PID=$!
        sleep 3
        curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[].labels.job' 2>/dev/null | sort | uniq || echo "Cannot access Prometheus API"
        kill $PF_PID 2>/dev/null
    else
        echo "Prometheus not accessible"
    fi
    echo
}

# Функция для анализа метрик endpoints
analyze_metrics_endpoints() {
    echo "=== Metrics Endpoints Analysis ==="
    
    echo "1. Services with Metrics Endpoints:"
    echo "=================================="
    kubectl get services --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations."prometheus.io/scrape" == "true") | "\(.metadata.namespace)/\(.metadata.name):\(.metadata.annotations."prometheus.io/port" // "default")"' || echo "No services with Prometheus annotations found"
    echo
    
    echo "2. Pods with Metrics Annotations:"
    echo "================================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations."prometheus.io/scrape" == "true") | "\(.metadata.namespace)/\(.metadata.name):\(.metadata.annotations."prometheus.io/port" // "default")"' || echo "No pods with Prometheus annotations found"
    echo
    
    echo "3. Custom Resource Definitions for Monitoring:"
    echo "=============================================="
    kubectl get crd | grep -E "(servicemonitor|prometheusrule|alertmanager)" || echo "No monitoring CRDs found"
    echo
    
    echo "4. Metrics Server API Endpoints:"
    echo "==============================="
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1" 2>/dev/null | jq '.resources[].name' || echo "Metrics API not available"
    echo
}

# Функция для создания metrics collection flow diagram
create_metrics_flow_diagram() {
    echo "=== Creating Metrics Collection Flow Diagram ==="
    
    cat << FLOW_DIAGRAM_EOF > metrics-collection-flow.md
# Kubernetes Metrics Collection Flow

## 📊 Core Metrics Pipeline

\`\`\`
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Container     │    │      Node       │
│   Metrics       │    │   Metrics       │    │    Metrics      │
│                 │    │   (cAdvisor)    │    │   (kubelet)     │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │                      │                      │
          ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                        kubelet                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  cAdvisor   │  │   kubelet   │  │    Resource Manager     │  │
│  │  :4194      │  │   :10250    │  │                         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   metrics-server                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Resource Metrics API (/apis/metrics.k8s.io/v1beta1)   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                 kubectl top / HPA                              │
└─────────────────────────────────────────────────────────────────┘
\`\`\`

## 🔍 Monitoring Pipeline

\`\`\`
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  kube-state-    │    │  Node Exporter  │    │ Custom Exporters│
│  metrics        │    │  :9100          │    │  (various)      │
│  :8080          │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │                      │                      │
          ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Prometheus                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Service Discovery + Scraping                          │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │    │
│  │  │ Kubernetes  │  │ Static      │  │ File-based      │  │    │
│  │  │ SD          │  │ Config      │  │ SD              │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Time Series Database                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Grafana / AlertManager                      │
└─────────────────────────────────────────────────────────────────┘
\`\`\`

## 🔧 Metrics Collection Components

### Core Components:
- **kubelet**: Collects node and container metrics
- **cAdvisor**: Container resource usage and performance metrics
- **metrics-server**: Aggregates resource metrics for HPA/VPA
- **kube-state-metrics**: Kubernetes object state metrics

### Monitoring Stack:
- **Prometheus**: Time-series database and monitoring system
- **Node Exporter**: Hardware and OS metrics
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and management

### API Endpoints:
- \`/metrics\` - Prometheus format metrics
- \`/apis/metrics.k8s.io/v1beta1\` - Resource Metrics API
- \`/api/v1/nodes/{node}/proxy/metrics\` - Node metrics proxy

FLOW_DIAGRAM_EOF
    
    echo "✅ Metrics collection flow diagram created: metrics-collection-flow.md"
    echo
}

# Функция для создания metrics collection test script
create_metrics_collection_test() {
    echo "=== Creating Metrics Collection Test Script ==="
    
    cat << TEST_SCRIPT_EOF > test-metrics-collection.sh
#!/bin/bash

echo "=== Kubernetes Metrics Collection Test ==="
echo "Testing metrics collection components in HashFoundry HA cluster"
echo

# Function to test metrics-server
test_metrics_server() {
    echo "1. Testing Metrics Server:"
    echo "========================="
    
    # Check if metrics-server is running
    METRICS_SERVER_POD=\$(kubectl get pods -n kube-system -l k8s-app=metrics-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "\$METRICS_SERVER_POD" ]; then
        echo "✅ Metrics Server pod found: \$METRICS_SERVER_POD"
        
        # Test Resource Metrics API
        echo "Testing Resource Metrics API..."
        kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" >/dev/null 2>&1
        if [ \$? -eq 0 ]; then
            echo "✅ Resource Metrics API accessible"
            echo "Node metrics count: \$(kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items | length')"
        else
            echo "❌ Resource Metrics API not accessible"
        fi
        
        # Test kubectl top
        echo "Testing kubectl top commands..."
        kubectl top nodes >/dev/null 2>&1
        if [ \$? -eq 0 ]; then
            echo "✅ kubectl top nodes working"
        else
            echo "❌ kubectl top nodes not working"
        fi
        
        kubectl top pods --all-namespaces >/dev/null 2>&1
        if [ \$? -eq 0 ]; then
            echo "✅ kubectl top pods working"
        else
            echo "❌ kubectl top pods not working"
        fi
    else
        echo "❌ Metrics Server not found"
    fi
    echo
}

# Function to test kubelet metrics
test_kubelet_metrics() {
    echo "2. Testing Kubelet Metrics:"
    echo "=========================="
    
    for node in \$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        echo "Testing node: \$node"
        
        # Test kubelet metrics endpoint
        kubectl get --raw "/api/v1/nodes/\$node/proxy/metrics" >/dev/null 2>&1
        if [ \$? -eq 0 ]; then
            echo "  ✅ Kubelet metrics accessible"
            KUBELET_METRICS_COUNT=\$(kubectl get --raw "/api/v1/nodes/\$node/proxy/metrics" | grep -c "^[a-zA-Z]")
            echo "  Metrics count: \$KUBELET_METRICS_COUNT"
        else
            echo "  ❌ Kubelet metrics not accessible"
        fi
        
        # Test cAdvisor metrics endpoint
        kubectl get --raw "/api/v1/nodes/\$node/proxy/metrics/cadvisor" >/dev/null 2>&1
        if [ \$? -eq 0 ]; then
            echo "  ✅ cAdvisor metrics accessible"
            CADVISOR_METRICS_COUNT=\$(kubectl get --raw "/api/v1/nodes/\$node/proxy/metrics/cadvisor" | grep -c "^container_")
            echo "  Container metrics count: \$CADVISOR_METRICS_COUNT"
        else
            echo "  ❌ cAdvisor metrics not accessible"
        fi
        echo
    done
}

# Function to test kube-state-metrics
test_kube_state_metrics() {
    echo "3. Testing kube-state-metrics:"
    echo "============================="
    
    KSM_POD=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=kube-state-metrics -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    KSM_NAMESPACE=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=kube-state-metrics -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -n "\$KSM_POD" ] && [ -n "\$KSM_NAMESPACE" ]; then
        echo "✅ kube-state-metrics found: \$KSM_NAMESPACE/\$KSM_POD"
        
        # Test metrics endpoint
        kubectl port-forward -n "\$KSM_NAMESPACE" "\$KSM_POD" 8080:8080 &
        PF_PID=\$!
        sleep 3
        
        curl -s "http://localhost:8080/metrics" >/dev/null 2>&1
        if [ \$? -eq 0 ]; then
            echo "✅ kube-state-metrics endpoint accessible"
            METRICS_COUNT=\$(curl -s "http://localhost:8080/metrics" | grep -c "^kube_")
            echo "Kubernetes state metrics count: \$METRICS_COUNT"
        else
            echo "❌ kube-state-metrics endpoint not accessible"
        fi
        
        kill \$PF_PID 2>/dev/null
    else
        echo "❌ kube-state-metrics not found"
    fi
    echo
}

# Function to test Prometheus (if available)
test_prometheus() {
    echo "4. Testing Prometheus:"
    echo "====================="
    
    PROMETHEUS_POD=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    PROMETHEUS_NAMESPACE=\$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -n "\$PROMETHEUS_POD" ] && [ -n "\$PROMETHEUS_NAMESPACE" ]; then
        echo "✅ Prometheus found: \$PROMETHEUS_NAMESPACE/\$PROMETHEUS_POD"
        
        # Test Prometheus API
        kubectl port-forward -n "\$PROMETHEUS_NAMESPACE" "\$PROMETHEUS_POD" 9090:9090 &
        PF_PID=\$!
        sleep 3
        
        curl -s "http://localhost:9090/api/v1/targets" >/dev/null 2>&1
        if [ \$? -eq 0 ]; then
            echo "✅ Prometheus API accessible"
            TARGETS_COUNT=\$(curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets | length')
            echo "Active targets count: \$TARGETS_COUNT"
            
            # Test query API
            curl -s "http://localhost:9090/api/v1/query?query=up" >/dev/null 2>&1
            if [ \$? -eq 0 ]; then
                echo "✅ Prometheus query API working"
            else
                echo "❌ Prometheus query API not working"
            fi
        else
            echo "❌ Prometheus API not accessible"
        fi
        
        kill \$PF_PID 2>/dev/null
    else
        echo "❌ Prometheus not found"
    fi
    echo
}

# Function to generate test report
generate_test_report() {
    echo "5. Generating Test Report:"
    echo "========================="
    
    REPORT_FILE="metrics-collection-test-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Kubernetes Metrics Collection Test Report"
        echo "========================================"
        echo "Cluster: hashfoundry-ha"
        echo "Date: \$(date)"
        echo ""
        
        echo "=== COMPONENT STATUS ==="
        echo "Metrics Server: \$(kubectl get pods -n kube-system -l k8s-app=metrics-server >/dev/null 2>&1 && echo "✅ Running" || echo "❌ Not Found")"
        echo "kube-state-metrics: \$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=kube-state-metrics >/dev/null 2>&1 && echo "✅ Running" || echo "❌ Not Found")"
        echo "Prometheus: \$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=prometheus >/dev/null 2>&1 && echo "✅ Running" || echo "❌ Not Found")"
        echo ""
        
        echo "=== API ENDPOINTS ==="
        echo "Resource Metrics API: \$(kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" >/dev/null 2>&1 && echo "✅ Accessible" || echo "❌ Not Accessible")"
        echo "kubectl top nodes: \$(kubectl top nodes >/dev/null 2>&1 && echo "✅ Working" || echo "❌ Not Working")"
        echo "kubectl top pods: \$(kubectl top pods --all-namespaces >/dev/null 2>&1 && echo "✅ Working" || echo "❌ Not Working")"
        echo ""
        
        echo "=== METRICS COUNTS ==="
        echo "Nodes: \$(kubectl get nodes --no-headers | wc -l)"
        echo "Pods: \$(kubectl get pods --all-namespaces --no-headers | wc -l)"
        echo "Services: \$(kubectl get services --all-namespaces --no-headers | wc -l)"
        echo ""
        
    } > "\$REPORT_FILE"
    
    echo "✅ Test report generated: \$REPORT_FILE"
}

# Main test function
main() {
    echo "Starting metrics collection tests..."
    echo
    
    test_metrics_server
    test_kubelet_metrics
    test_kube_state_metrics
    test_prometheus
    generate_test_report
    
    echo "✅ Metrics collection tests completed"
}

# Run main function
main

TEST_SCRIPT_EOF
    
    chmod +x test-metrics-collection.sh
    
    echo "✅ Metrics collection test script created: test-metrics-collection.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "core")
            analyze_core_metrics_pipeline
            ;;
        "monitoring")
            analyze_monitoring_pipeline
            ;;
        "endpoints")
            analyze_metrics_endpoints
            ;;
        "flow")
            create_metrics_flow_diagram
            ;;
        "test")
            create_metrics_collection_test
            ./test-metrics-collection.sh
            ;;
        "all"|"")
            analyze_core_metrics_pipeline
            analyze_monitoring_pipeline
            analyze_metrics_endpoints
            create_metrics_flow_diagram
            create_metrics_collection_test
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  core        - Analyze core metrics pipeline"
            echo "  monitoring  - Analyze monitoring pipeline"
            echo "  endpoints   - Analyze metrics endpoints"
            echo "  flow        - Create metrics flow diagram"
            echo "  test        - Create and run metrics collection test"
            echo "  all         - Run all analyses and create tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0 core"
            echo "  $0 test"
            echo "  $0 flow"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-metrics-collection-toolkit.sh

# Запустить создание Metrics Collection toolkit
./kubernetes-metrics-collection-toolkit.sh all
```

## 📋 **Компоненты сбора метрик:**

### **Core Metrics Pipeline:**

| **Компонент** | **Функция** | **Порт** | **API Endpoint** |
|---------------|-------------|----------|------------------|
| **kubelet** | Сбор метрик узла | 10250 | `/metrics`, `/metrics/cadvisor` |
| **cAdvisor** | Метрики контейнеров | 4194 | `/metrics` |
| **metrics-server** | Агрегация ресурсов | 443 | `/apis/metrics.k8s.io/v1beta1` |
| **kube-state-metrics** | Состояние объектов | 8080 | `/metrics` |

### **Monitoring Pipeline:**

| **Компонент** | **Функция** | **Порт** | **Формат метрик** |
|---------------|-------------|----------|-------------------|
| **Prometheus** | Сбор и хранение | 9090 | Prometheus format |
| **Node Exporter** | Метрики ОС | 9100 | Prometheus format |
| **Grafana** | Визуализация | 3000 | Dashboard UI |
| **AlertManager** | Управление алертами | 9093 | Alert routing |

## 🎯 **Практические команды:**

### **Анализ сбора метрик:**
```bash
# Запустить полный анализ
./kubernetes-metrics-collection-toolkit.sh all

# Тестировать сбор метрик
./test-metrics-collection.sh

# Проверить core pipeline
./kubernetes-metrics-collection-toolkit.sh core
```

### **Проверка компонентов:**
```bash
# Проверить metrics-server
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top nodes

# Проверить kubelet метрики
kubectl get --raw "/api/v1/nodes/<node-name>/proxy/metrics"

# Проверить Resource Metrics API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

### **Диагностика проблем:**
```bash
# Проверить логи metrics-server
kubectl logs -n kube-system -l k8s-app=metrics-server

# Проверить доступность API
kubectl get apiservices | grep metrics

# Проверить сертификаты
kubectl describe apiservice v1beta1.metrics.k8s.io
```

## 🔧 **Best Practices для сбора метрик:**

### **Архитектурные принципы:**
- **Separation of concerns** - разделение ответственности
- **Scalable collection** - масштабируемый сбор
- **Reliable storage** - надежное хранение
- **Efficient querying** - эффективные запросы

### **Конфигурация:**
- **Proper resource limits** - правильные лимиты ресурсов
- **Retention policies** - политики хранения
- **Service discovery** - автоматическое обнаружение
- **Security considerations** - вопросы безопасности

**Понимание архитектуры сбора метрик критически важно для эффективного мониторинга Kubernetes!**
