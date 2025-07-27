# 95. Horizontal Pod Autoscaler (HPA)

## 🎯 **Horizontal Pod Autoscaler (HPA)**

**Horizontal Pod Autoscaler (HPA)** - это контроллер Kubernetes, который автоматически масштабирует количество Pod'ов в Deployment, ReplicaSet или StatefulSet на основе наблюдаемых метрик CPU, памяти или пользовательских метрик, обеспечивая автоматическую адаптацию к изменяющейся нагрузке.

## 🏗️ **Компоненты HPA:**

### **1. Metrics Sources:**
- **CPU utilization** - использование процессора
- **Memory utilization** - использование памяти
- **Custom metrics** - пользовательские метрики
- **External metrics** - внешние метрики

### **2. Scaling Behavior:**
- **Scale up** - увеличение количества Pod'ов
- **Scale down** - уменьшение количества Pod'ов
- **Stabilization** - стабилизация масштабирования
- **Policies** - политики масштабирования

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих HPA:**
```bash
# Проверить существующие HPA
kubectl get hpa --all-namespaces
kubectl describe hpa --all-namespaces
```

### **2. Создание comprehensive HPA toolkit:**
```bash
# Создать скрипт для работы с HPA
cat << 'EOF' > kubernetes-hpa-toolkit.sh
#!/bin/bash

echo "=== Kubernetes HPA Toolkit ==="
echo "Comprehensive toolkit for Horizontal Pod Autoscaler in HashFoundry HA cluster"
echo

# Функция для анализа текущих HPA
analyze_current_hpa() {
    echo "=== Current HPA Analysis ==="
    
    echo "1. Existing HPAs:"
    echo "================"
    kubectl get hpa --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REFERENCE:.spec.scaleTargetRef.name,TARGETS:.status.currentMetrics[*].resource.current.averageUtilization,MINPODS:.spec.minReplicas,MAXPODS:.spec.maxReplicas,REPLICAS:.status.currentReplicas"
    echo
    
    echo "2. HPA Status Details:"
    echo "====================="
    kubectl get hpa --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[] | select(.type=="ScalingActive") | .status) - \(.status.conditions[] | select(.type=="AbleToScale") | .status)"'
    echo
    
    echo "3. Metrics Server Status:"
    echo "========================"
    kubectl get pods -n kube-system -l k8s-app=metrics-server -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status"
    echo
    
    echo "4. Resource Requests in Deployments:"
    echo "===================================="
    kubectl get deployments --all-namespaces -o json | jq -r '.items[] | select(.spec.template.spec.containers[].resources.requests != null) | "\(.metadata.namespace)/\(.metadata.name): CPU=\(.spec.template.spec.containers[0].resources.requests.cpu // "none"), Memory=\(.spec.template.spec.containers[0].resources.requests.memory // "none")"'
    echo
}

# Функция для создания basic HPA examples
create_basic_hpa_examples() {
    echo "=== Creating Basic HPA Examples ==="
    
    # Создать namespace для примеров
    kubectl create namespace hpa-examples --dry-run=client -o yaml | kubectl apply -f -
    
    # Example 1: CPU-based HPA
    cat << CPU_HPA_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-intensive-app
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "cpu-intensive-app"
    hashfoundry.io/example: "cpu-hpa"
  annotations:
    hashfoundry.io/description: "CPU intensive application for HPA demonstration"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "cpu-intensive-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "cpu-intensive-app"
        hashfoundry.io/workload-type: "cpu-intensive"
    spec:
      containers:
      - name: app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"
        ports:
        - containerPort: 80
        # Simulate CPU load
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'CPU load simulation'; sleep 1; done & nginx -g 'daemon off;'"]
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cpu-intensive-app-hpa
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "cpu-intensive-app-hpa"
    hashfoundry.io/example: "cpu-hpa"
  annotations:
    hashfoundry.io/description: "CPU-based HPA for cpu-intensive-app"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cpu-intensive-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      selectPolicy: Min
CPU_HPA_EOF
    
    # Example 2: Memory-based HPA
    cat << MEMORY_HPA_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memory-intensive-app
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "memory-intensive-app"
    hashfoundry.io/example: "memory-hpa"
  annotations:
    hashfoundry.io/description: "Memory intensive application for HPA demonstration"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "memory-intensive-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "memory-intensive-app"
        hashfoundry.io/workload-type: "memory-intensive"
    spec:
      containers:
      - name: app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        ports:
        - containerPort: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: memory-intensive-app-hpa
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "memory-intensive-app-hpa"
    hashfoundry.io/example: "memory-hpa"
  annotations:
    hashfoundry.io/description: "Memory-based HPA for memory-intensive-app"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: memory-intensive-app
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
MEMORY_HPA_EOF
    
    # Example 3: Multi-metric HPA
    cat << MULTI_METRIC_HPA_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-application
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "web-application"
    hashfoundry.io/example: "multi-metric-hpa"
  annotations:
    hashfoundry.io/description: "Web application with multi-metric HPA"
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: "web-application"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "web-application"
        hashfoundry.io/workload-type: "web"
    spec:
      containers:
      - name: web
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "300m"
            memory: "256Mi"
        ports:
        - containerPort: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-application-hpa
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "web-application-hpa"
    hashfoundry.io/example: "multi-metric-hpa"
  annotations:
    hashfoundry.io/description: "Multi-metric HPA for web-application"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-application
  minReplicas: 3
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 120
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 3
        periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 600
      policies:
      - type: Percent
        value: 25
        periodSeconds: 60
      selectPolicy: Min
MULTI_METRIC_HPA_EOF
    
    echo "✅ Basic HPA examples created"
    echo
}

# Функция для создания advanced HPA examples
create_advanced_hpa_examples() {
    echo "=== Creating Advanced HPA Examples ==="
    
    # Example 1: Custom metrics HPA (requires custom metrics API)
    cat << CUSTOM_METRICS_HPA_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: queue-processor
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "queue-processor"
    hashfoundry.io/example: "custom-metrics-hpa"
  annotations:
    hashfoundry.io/description: "Queue processor with custom metrics HPA"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "queue-processor"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "queue-processor"
        hashfoundry.io/workload-type: "queue-processor"
    spec:
      containers:
      - name: processor
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "300m"
            memory: "256Mi"
        env:
        - name: QUEUE_NAME
          value: "hashfoundry-queue"
        ports:
        - containerPort: 80
---
# Note: This HPA requires custom metrics API to be available
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: queue-processor-hpa
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "queue-processor-hpa"
    hashfoundry.io/example: "custom-metrics-hpa"
  annotations:
    hashfoundry.io/description: "Custom metrics HPA for queue processor"
    hashfoundry.io/note: "Requires custom metrics API"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: queue-processor
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Custom metrics example (commented out as it requires custom metrics API)
  # - type: Pods
  #   pods:
  #     metric:
  #       name: queue_messages_per_pod
  #     target:
  #       type: AverageValue
  #       averageValue: "10"
CUSTOM_METRICS_HPA_EOF
    
    # Example 2: External metrics HPA
    cat << EXTERNAL_METRICS_HPA_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "api-gateway"
    hashfoundry.io/example: "external-metrics-hpa"
  annotations:
    hashfoundry.io/description: "API Gateway with external metrics HPA"
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: "api-gateway"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "api-gateway"
        hashfoundry.io/workload-type: "api-gateway"
    spec:
      containers:
      - name: gateway
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "150m"
            memory: "192Mi"
          limits:
            cpu: "400m"
            memory: "384Mi"
        ports:
        - containerPort: 80
---
# Note: This HPA requires external metrics API to be available
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
  namespace: hpa-examples
  labels:
    app.kubernetes.io/name: "api-gateway-hpa"
    hashfoundry.io/example: "external-metrics-hpa"
  annotations:
    hashfoundry.io/description: "External metrics HPA for API Gateway"
    hashfoundry.io/note: "Requires external metrics API"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 3
  maxReplicas: 25
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 65
  # External metrics example (commented out as it requires external metrics API)
  # - type: External
  #   external:
  #     metric:
  #       name: requests_per_second
  #       selector:
  #         matchLabels:
  #           service: api-gateway
  #     target:
  #       type: Value
  #       value: "1000"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 180
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 5
        periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 900
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      selectPolicy: Min
EXTERNAL_METRICS_HPA_EOF
    
    echo "✅ Advanced HPA examples created"
    echo
}

# Функция для создания HPA monitoring tools
create_hpa_monitoring_tools() {
    echo "=== Creating HPA Monitoring Tools ==="
    
    cat << HPA_MONITOR_EOF > hpa-monitoring-tools.sh
#!/bin/bash

echo "=== HPA Monitoring Tools ==="
echo "Tools for monitoring Horizontal Pod Autoscaler"
echo

# Function to monitor HPA status
monitor_hpa_status() {
    local namespace=\${1:-""}
    local hpa_name=\${2:-""}
    
    if [ -n "\$namespace" ] && [ -n "\$hpa_name" ]; then
        echo "=== Monitoring HPA: \$namespace/\$hpa_name ==="
        
        while true; do
            clear
            echo "HPA Status for \$namespace/\$hpa_name"
            echo "=================================="
            echo "Time: \$(date)"
            echo
            
            # HPA details
            kubectl get hpa "\$hpa_name" -n "\$namespace" -o custom-columns="NAME:.metadata.name,REFERENCE:.spec.scaleTargetRef.name,TARGETS:.status.currentMetrics[*].resource.current.averageUtilization,MINPODS:.spec.minReplicas,MAXPODS:.spec.maxReplicas,REPLICAS:.status.currentReplicas,AGE:.metadata.creationTimestamp"
            echo
            
            # Current metrics
            echo "Current Metrics:"
            kubectl get hpa "\$hpa_name" -n "\$namespace" -o jsonpath='{.status.currentMetrics}' | jq . 2>/dev/null || echo "No metrics available"
            echo
            
            # Scaling events
            echo "Recent Scaling Events:"
            kubectl get events -n "\$namespace" --field-selector involvedObject.name="\$hpa_name" --sort-by='.lastTimestamp' | tail -5
            echo
            
            # Pod status
            TARGET_DEPLOYMENT=\$(kubectl get hpa "\$hpa_name" -n "\$namespace" -o jsonpath='{.spec.scaleTargetRef.name}')
            echo "Target Deployment Pods:"
            kubectl get pods -n "\$namespace" -l app.kubernetes.io/name="\$TARGET_DEPLOYMENT" -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CPU:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName"
            echo
            
            echo "Press Ctrl+C to stop monitoring"
            sleep 10
        done
    else
        echo "Usage: monitor_hpa_status <namespace> <hpa-name>"
        echo "Example: monitor_hpa_status hpa-examples cpu-intensive-app-hpa"
    fi
}

# Function to analyze HPA performance
analyze_hpa_performance() {
    echo "=== HPA Performance Analysis ==="
    
    echo "1. All HPAs Status:"
    echo "=================="
    kubectl get hpa --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REFERENCE:.spec.scaleTargetRef.name,TARGETS:.status.currentMetrics[*].resource.current.averageUtilization,MINPODS:.spec.minReplicas,MAXPODS:.spec.maxReplicas,REPLICAS:.status.currentReplicas"
    echo
    
    echo "2. HPA Conditions:"
    echo "================="
    kubectl get hpa --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name):" as \$name | .status.conditions[] | "  \(.type): \(.status) - \(.message // "No message")"' | grep -A 10 "/"
    echo
    
    echo "3. Scaling Events (Last 1 hour):"
    echo "================================"
    kubectl get events --all-namespaces --field-selector reason=SuccessfulRescale --sort-by='.lastTimestamp' | grep "\$(date -d '1 hour ago' '+%Y-%m-%d')" || echo "No scaling events in the last hour"
    echo
    
    echo "4. Resource Utilization:"
    echo "======================="
    kubectl top pods --all-namespaces --containers 2>/dev/null | grep -E "(CPU|MEMORY)" || echo "Metrics server not available"
    echo
}

# Function to test HPA scaling
test_hpa_scaling() {
    local namespace=\${1:-"hpa-examples"}
    local deployment=\${2:-"cpu-intensive-app"}
    
    echo "=== Testing HPA Scaling ==="
    echo "Namespace: \$namespace"
    echo "Deployment: \$deployment"
    echo
    
    # Check if deployment exists
    if ! kubectl get deployment "\$deployment" -n "\$namespace" >/dev/null 2>&1; then
        echo "❌ Deployment \$deployment not found in namespace \$namespace"
        return 1
    fi
    
    # Check if HPA exists
    HPA_NAME="\${deployment}-hpa"
    if ! kubectl get hpa "\$HPA_NAME" -n "\$namespace" >/dev/null 2>&1; then
        echo "❌ HPA \$HPA_NAME not found in namespace \$namespace"
        return 1
    fi
    
    echo "1. Initial State:"
    kubectl get hpa "\$HPA_NAME" -n "\$namespace"
    kubectl get pods -n "\$namespace" -l app.kubernetes.io/name="\$deployment" --no-headers | wc -l | xargs echo "Current pods:"
    echo
    
    echo "2. Generating Load..."
    # Create a load generator pod
    cat << LOAD_GEN_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
  namespace: \$namespace
  labels:
    app: load-generator
spec:
  containers:
  - name: load-generator
    image: busybox:1.35
    command: ["/bin/sh"]
    args: ["-c", "while true; do wget -q -O- http://\${deployment}.\${namespace}.svc.cluster.local/; done"]
  restartPolicy: Never
LOAD_GEN_EOF
    
    echo "Load generator started. Monitoring scaling..."
    echo
    
    # Monitor for 5 minutes
    for i in {1..30}; do
        echo "Minute \$((i/6 + 1)): \$(date)"
        kubectl get hpa "\$HPA_NAME" -n "\$namespace" --no-headers
        kubectl get pods -n "\$namespace" -l app.kubernetes.io/name="\$deployment" --no-headers | wc -l | xargs echo "Pods:"
        echo "---"
        sleep 10
    done
    
    # Cleanup
    kubectl delete pod load-generator -n "\$namespace" 2>/dev/null || true
    
    echo "✅ HPA scaling test completed"
    echo
}

# Function to generate HPA report
generate_hpa_report() {
    echo "=== Generating HPA Report ==="
    
    local report_file="hpa-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster HPA Report"
        echo "================================="
        echo "Generated: \$(date)"
        echo ""
        
        echo "=== HPA OVERVIEW ==="
        kubectl get hpa --all-namespaces
        echo ""
        
        echo "=== HPA DETAILED STATUS ==="
        kubectl describe hpa --all-namespaces
        echo ""
        
        echo "=== METRICS SERVER STATUS ==="
        kubectl get pods -n kube-system -l k8s-app=metrics-server
        echo ""
        
        echo "=== RECENT SCALING EVENTS ==="
        kubectl get events --all-namespaces --field-selector reason=SuccessfulRescale --sort-by='.lastTimestamp' | tail -20
        echo ""
        
        echo "=== RESOURCE UTILIZATION ==="
        kubectl top pods --all-namespaces --containers 2>/dev/null || echo "Metrics server not available"
        echo ""
        
    } > "\$report_file"
    
    echo "✅ HPA report generated: \$report_file"
    echo
}

# Main function
main() {
    case "\$1" in
        "monitor")
            monitor_hpa_status "\$2" "\$3"
            ;;
        "analyze")
            analyze_hpa_performance
            ;;
        "test")
            test_hpa_scaling "\$2" "\$3"
            ;;
        "report")
            generate_hpa_report
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  monitor <namespace> <hpa>     - Monitor HPA status"
            echo "  analyze                       - Analyze HPA performance"
            echo "  test [namespace] [deployment] - Test HPA scaling"
            echo "  report                        - Generate HPA report"
            echo ""
            echo "Examples:"
            echo "  \$0 monitor hpa-examples cpu-intensive-app-hpa"
            echo "  \$0 analyze"
            echo "  \$0 test hpa-examples cpu-intensive-app"
            echo "  \$0 report"
            ;;
    esac
}

# Run main function
main "\$@"

HPA_MONITOR_EOF
    
    chmod +x hpa-monitoring-tools.sh
    
    echo "✅ HPA monitoring tools created: hpa-monitoring-tools.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_hpa
            ;;
        "basic-examples")
            create_basic_hpa_examples
            ;;
        "advanced-examples")
            create_advanced_hpa_examples
            ;;
        "monitoring")
            create_hpa_monitoring_tools
            ;;
        "all"|"")
            analyze_current_hpa
            create_basic_hpa_examples
            create_advanced_hpa_examples
            create_hpa_monitoring_tools
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze            - Analyze current HPA status"
            echo "  basic-examples     - Create basic HPA examples"
            echo "  advanced-examples  - Create advanced HPA examples"
            echo "  monitoring         - Create HPA monitoring tools"
            echo "  all                - Create all examples and tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 basic-examples"
            echo "  $0 monitoring"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-hpa-toolkit.sh

# Запустить создание HPA toolkit
./kubernetes-hpa-toolkit.sh all
```

## 📋 **HPA Metrics и Scaling:**

### **Metric Types:**

| **Тип** | **Источник** | **Пример** | **Use Case** |
|----------|--------------|------------|--------------|
| **Resource** | Metrics Server | CPU, Memory | Базовое масштабирование |
| **Pods** | Custom Metrics API | Requests per pod | Специфичные метрики |
| **Object** | Custom Metrics API | Queue length | Объектные метрики |
| **External** | External Metrics API | Cloud metrics | Внешние системы |

### **Scaling Behavior:**

| **Параметр** | **Описание** | **Default** | **Рекомендация** |
|--------------|--------------|-------------|------------------|
| **stabilizationWindowSeconds** | Окно стабилизации | 300s (down), 0s (up) | 60-600s |
| **selectPolicy** | Политика выбора | Max (up), Min (down) | По ситуации |
| **periodSeconds** | Период оценки | 60s | 15-60s |

## 🎯 **Практические команды:**

### **Работа с HPA:**
```bash
# Запустить HPA toolkit
./kubernetes-hpa-toolkit.sh all

# Мониторинг HPA
./hpa-monitoring-tools.sh monitor hpa-examples cpu-intensive-app-hpa

# Тестирование масштабирования
./hpa-monitoring-tools.sh test hpa-examples cpu-intensive-app
```

### **Создание HPA:**
```bash
# Простой CPU-based HPA
kubectl autoscale deployment my-app --cpu-percent=70 --min=2 --max=10

# Проверить HPA
kubectl get hpa
kubectl describe hpa my-app
```

### **Анализ метрик:**
```bash
# Проверить метрики
kubectl top pods
kubectl top nodes

# Проверить Metrics Server
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

## 🔧 **Best Practices для HPA:**

### **Конфигурация:**
- **Set resource requests** - устанавливайте запросы ресурсов
- **Choose appropriate targets** - выбирайте подходящие цели
- **Configure scaling behavior** - настраивайте поведение масштабирования
- **Use multiple metrics** - используйте несколько метрик

### **Мониторинг:**
- **Monitor scaling events** - мониторьте события масштабирования
- **Track resource utilization** - отслеживайте использование ресурсов
- **Set up alerts** - настройте оповещения
- **Regular review** - регулярно пересматривайте настройки

### **Troubleshooting:**
- **Check Metrics Server** - проверьте Metrics Server
- **Verify resource requests** - проверьте запросы ресурсов
- **Review scaling policies** - пересмотрите политики масштабирования
- **Analyze events** - анализируйте события

**HPA обеспечивает автоматическое масштабирование приложений в зависимости от нагрузки!**
