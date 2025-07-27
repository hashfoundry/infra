# 96. Vertical Pod Autoscaler (VPA)

## 🎯 **Vertical Pod Autoscaler (VPA)**

**Vertical Pod Autoscaler (VPA)** - это компонент Kubernetes, который автоматически настраивает CPU и память запросов и лимитов для контейнеров в Pod'ах на основе исторического использования ресурсов, обеспечивая оптимальное распределение ресурсов без необходимости ручной настройки.

## 🏗️ **Компоненты VPA:**

### **1. VPA Components:**
- **VPA Recommender** - анализирует использование ресурсов
- **VPA Updater** - обновляет Pod'ы с новыми ресурсами
- **VPA Admission Controller** - применяет рекомендации при создании
- **VPA CRD** - пользовательский ресурс для конфигурации

### **2. Update Modes:**
- **Off** - только рекомендации, без изменений
- **Initial** - применяется только при создании Pod'а
- **Recreation** - пересоздает Pod'ы с новыми ресурсами
- **Auto** - автоматическое обновление (экспериментальный)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка VPA в кластере:**
```bash
# Проверить наличие VPA
kubectl get crd | grep verticalpodautoscaler
kubectl get pods -n kube-system | grep vpa
```

### **2. Создание comprehensive VPA toolkit:**
```bash
# Создать скрипт для работы с VPA
cat << 'EOF' > kubernetes-vpa-toolkit.sh
#!/bin/bash

echo "=== Kubernetes VPA Toolkit ==="
echo "Comprehensive toolkit for Vertical Pod Autoscaler in HashFoundry HA cluster"
echo

# Функция для проверки VPA installation
check_vpa_installation() {
    echo "=== VPA Installation Check ==="
    
    echo "1. VPA CRDs:"
    echo "==========="
    kubectl get crd | grep verticalpodautoscaler || echo "VPA CRDs not found"
    echo
    
    echo "2. VPA Components:"
    echo "================="
    kubectl get pods -n kube-system | grep vpa || echo "VPA components not found"
    echo
    
    echo "3. VPA API Versions:"
    echo "==================="
    kubectl api-versions | grep autoscaling || echo "VPA API not available"
    echo
    
    if ! kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
        echo "⚠️  VPA is not installed in this cluster"
        echo "To install VPA, you can use:"
        echo "git clone https://github.com/kubernetes/autoscaler.git"
        echo "cd autoscaler/vertical-pod-autoscaler"
        echo "./hack/vpa-install.sh"
        echo
        return 1
    fi
    
    echo "✅ VPA is installed and available"
    echo
}

# Функция для анализа текущих VPA
analyze_current_vpa() {
    echo "=== Current VPA Analysis ==="
    
    if ! kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
        echo "VPA is not installed in this cluster"
        return 1
    fi
    
    echo "1. Existing VPAs:"
    echo "================"
    kubectl get vpa --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,MODE:.spec.updatePolicy.updateMode,TARGET:.spec.targetRef.name,CPU-REQUEST:.status.recommendation.containerRecommendations[0].target.cpu,MEMORY-REQUEST:.status.recommendation.containerRecommendations[0].target.memory" 2>/dev/null || echo "No VPAs found"
    echo
    
    echo "2. VPA Status Details:"
    echo "====================="
    kubectl get vpa --all-namespaces -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[]? | select(.type=="RecommendationProvided") | .status)"' || echo "No VPA status available"
    echo
    
    echo "3. VPA Recommendations:"
    echo "======================"
    kubectl get vpa --all-namespaces -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name):" as $name | .status.recommendation.containerRecommendations[]? | "  Container: \(.containerName), CPU: \(.target.cpu // "N/A"), Memory: \(.target.memory // "N/A")"' || echo "No recommendations available"
    echo
}

# Функция для создания VPA examples
create_vpa_examples() {
    echo "=== Creating VPA Examples ==="
    
    if ! kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
        echo "❌ VPA is not installed. Cannot create examples."
        echo "Please install VPA first using the installation instructions."
        return 1
    fi
    
    # Создать namespace для примеров
    kubectl create namespace vpa-examples --dry-run=client -o yaml | kubectl apply -f -
    
    # Example 1: VPA in "Off" mode (recommendations only)
    cat << VPA_OFF_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-consumer-off
  namespace: vpa-examples
  labels:
    app.kubernetes.io/name: "resource-consumer-off"
    hashfoundry.io/example: "vpa-off-mode"
  annotations:
    hashfoundry.io/description: "Resource consumer for VPA off mode demonstration"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "resource-consumer-off"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "resource-consumer-off"
        hashfoundry.io/vpa-mode: "off"
    spec:
      containers:
      - name: consumer
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        ports:
        - containerPort: 80
        # Simulate variable resource usage
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Resource consumption simulation'; sleep 30; done & nginx -g 'daemon off;'"]
---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: resource-consumer-off-vpa
  namespace: vpa-examples
  labels:
    app.kubernetes.io/name: "resource-consumer-off-vpa"
    hashfoundry.io/example: "vpa-off-mode"
  annotations:
    hashfoundry.io/description: "VPA in Off mode - provides recommendations only"
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-consumer-off
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
    - containerName: consumer
      minAllowed:
        cpu: "50m"
        memory: "64Mi"
      maxAllowed:
        cpu: "500m"
        memory: "512Mi"
      controlledResources: ["cpu", "memory"]
VPA_OFF_EOF
    
    # Example 2: VPA in "Initial" mode
    cat << VPA_INITIAL_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-consumer-initial
  namespace: vpa-examples
  labels:
    app.kubernetes.io/name: "resource-consumer-initial"
    hashfoundry.io/example: "vpa-initial-mode"
  annotations:
    hashfoundry.io/description: "Resource consumer for VPA initial mode demonstration"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "resource-consumer-initial"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "resource-consumer-initial"
        hashfoundry.io/vpa-mode: "initial"
    spec:
      containers:
      - name: consumer
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
        ports:
        - containerPort: 80
---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: resource-consumer-initial-vpa
  namespace: vpa-examples
  labels:
    app.kubernetes.io/name: "resource-consumer-initial-vpa"
    hashfoundry.io/example: "vpa-initial-mode"
  annotations:
    hashfoundry.io/description: "VPA in Initial mode - applies recommendations only to new pods"
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-consumer-initial
  updatePolicy:
    updateMode: "Initial"
  resourcePolicy:
    containerPolicies:
    - containerName: consumer
      minAllowed:
        cpu: "25m"
        memory: "32Mi"
      maxAllowed:
        cpu: "300m"
        memory: "384Mi"
      controlledResources: ["cpu", "memory"]
VPA_INITIAL_EOF
    
    # Example 3: VPA in "Recreation" mode (careful - will restart pods)
    cat << VPA_RECREATION_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-consumer-recreation
  namespace: vpa-examples
  labels:
    app.kubernetes.io/name: "resource-consumer-recreation"
    hashfoundry.io/example: "vpa-recreation-mode"
  annotations:
    hashfoundry.io/description: "Resource consumer for VPA recreation mode demonstration"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "resource-consumer-recreation"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "resource-consumer-recreation"
        hashfoundry.io/vpa-mode: "recreation"
    spec:
      containers:
      - name: consumer
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "400m"
            memory: "512Mi"
        ports:
        - containerPort: 80
---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: resource-consumer-recreation-vpa
  namespace: vpa-examples
  labels:
    app.kubernetes.io/name: "resource-consumer-recreation-vpa"
    hashfoundry.io/example: "vpa-recreation-mode"
  annotations:
    hashfoundry.io/description: "VPA in Recreation mode - recreates pods with new resource requirements"
    hashfoundry.io/warning: "This mode will restart pods when recommendations change"
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-consumer-recreation
  updatePolicy:
    updateMode: "Recreation"
  resourcePolicy:
    containerPolicies:
    - containerName: consumer
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
      maxAllowed:
        cpu: "1"
        memory: "1Gi"
      controlledResources: ["cpu", "memory"]
      controlledValues: "RequestsAndLimits"
VPA_RECREATION_EOF
    
    echo "✅ VPA examples created"
    echo "⚠️  Note: Recreation mode VPA will restart pods when recommendations change"
    echo
}

# Функция для создания VPA monitoring tools
create_vpa_monitoring_tools() {
    echo "=== Creating VPA Monitoring Tools ==="
    
    cat << VPA_MONITOR_EOF > vpa-monitoring-tools.sh
#!/bin/bash

echo "=== VPA Monitoring Tools ==="
echo "Tools for monitoring Vertical Pod Autoscaler"
echo

# Function to monitor VPA recommendations
monitor_vpa_recommendations() {
    local namespace=\${1:-""}
    local vpa_name=\${2:-""}
    
    if [ -n "\$namespace" ] && [ -n "\$vpa_name" ]; then
        echo "=== Monitoring VPA: \$namespace/\$vpa_name ==="
        
        while true; do
            clear
            echo "VPA Recommendations for \$namespace/\$vpa_name"
            echo "============================================="
            echo "Time: \$(date)"
            echo
            
            # VPA details
            kubectl get vpa "\$vpa_name" -n "\$namespace" -o custom-columns="NAME:.metadata.name,MODE:.spec.updatePolicy.updateMode,TARGET:.spec.targetRef.name,AGE:.metadata.creationTimestamp" 2>/dev/null
            echo
            
            # Current recommendations
            echo "Current Recommendations:"
            kubectl get vpa "\$vpa_name" -n "\$namespace" -o jsonpath='{.status.recommendation}' 2>/dev/null | jq . || echo "No recommendations available yet"
            echo
            
            # Target deployment current resources
            TARGET_DEPLOYMENT=\$(kubectl get vpa "\$vpa_name" -n "\$namespace" -o jsonpath='{.spec.targetRef.name}' 2>/dev/null)
            if [ -n "\$TARGET_DEPLOYMENT" ]; then
                echo "Target Deployment Current Resources:"
                kubectl get deployment "\$TARGET_DEPLOYMENT" -n "\$namespace" -o jsonpath='{.spec.template.spec.containers[0].resources}' 2>/dev/null | jq . || echo "No resource info available"
                echo
                
                echo "Target Deployment Pods:"
                kubectl get pods -n "\$namespace" -l app.kubernetes.io/name="\$TARGET_DEPLOYMENT" -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory" 2>/dev/null
                echo
            fi
            
            # VPA events
            echo "Recent VPA Events:"
            kubectl get events -n "\$namespace" --field-selector involvedObject.name="\$vpa_name" --sort-by='.lastTimestamp' 2>/dev/null | tail -5
            echo
            
            echo "Press Ctrl+C to stop monitoring"
            sleep 15
        done
    else
        echo "Usage: monitor_vpa_recommendations <namespace> <vpa-name>"
        echo "Example: monitor_vpa_recommendations vpa-examples resource-consumer-off-vpa"
    fi
}

# Function to analyze VPA performance
analyze_vpa_performance() {
    echo "=== VPA Performance Analysis ==="
    
    echo "1. All VPAs Status:"
    echo "=================="
    kubectl get vpa --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,MODE:.spec.updatePolicy.updateMode,TARGET:.spec.targetRef.name,AGE:.metadata.creationTimestamp" 2>/dev/null || echo "No VPAs found or VPA not installed"
    echo
    
    echo "2. VPA Recommendations Summary:"
    echo "=============================="
    kubectl get vpa --all-namespaces -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name):" as \$name | .status.recommendation.containerRecommendations[]? | "  \(.containerName): CPU=\(.target.cpu // "N/A"), Memory=\(.target.memory // "N/A")"' || echo "No recommendations available"
    echo
    
    echo "3. VPA vs Current Resources:"
    echo "==========================="
    kubectl get vpa --all-namespaces -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name) -> \(.spec.targetRef.name)"' | while read line; do
        if [ -n "\$line" ]; then
            echo "\$line"
            # This would need more complex logic to compare current vs recommended
        fi
    done 2>/dev/null || echo "No VPA data available"
    echo
    
    echo "4. Resource Utilization:"
    echo "======================="
    kubectl top pods --all-namespaces --containers 2>/dev/null | head -20 || echo "Metrics server not available"
    echo
}

# Function to compare VPA recommendations with current settings
compare_vpa_recommendations() {
    local namespace=\${1:-""}
    local vpa_name=\${2:-""}
    
    if [ -z "\$namespace" ] || [ -z "\$vpa_name" ]; then
        echo "Usage: compare_vpa_recommendations <namespace> <vpa-name>"
        return 1
    fi
    
    echo "=== VPA Recommendations Comparison ==="
    echo "VPA: \$namespace/\$vpa_name"
    echo
    
    # Get target deployment
    TARGET_DEPLOYMENT=\$(kubectl get vpa "\$vpa_name" -n "\$namespace" -o jsonpath='{.spec.targetRef.name}' 2>/dev/null)
    
    if [ -z "\$TARGET_DEPLOYMENT" ]; then
        echo "❌ Could not find target deployment for VPA"
        return 1
    fi
    
    echo "Target Deployment: \$TARGET_DEPLOYMENT"
    echo
    
    # Current resources
    echo "Current Resource Requests:"
    kubectl get deployment "\$TARGET_DEPLOYMENT" -n "\$namespace" -o jsonpath='{.spec.template.spec.containers[0].resources.requests}' 2>/dev/null | jq . || echo "No current requests found"
    echo
    
    # VPA recommendations
    echo "VPA Recommendations:"
    kubectl get vpa "\$vpa_name" -n "\$namespace" -o jsonpath='{.status.recommendation.containerRecommendations[0].target}' 2>/dev/null | jq . || echo "No VPA recommendations available yet"
    echo
    
    # Lower and upper bounds
    echo "VPA Lower Bound:"
    kubectl get vpa "\$vpa_name" -n "\$namespace" -o jsonpath='{.status.recommendation.containerRecommendations[0].lowerBound}' 2>/dev/null | jq . || echo "No lower bound available"
    echo
    
    echo "VPA Upper Bound:"
    kubectl get vpa "\$vpa_name" -n "\$namespace" -o jsonpath='{.status.recommendation.containerRecommendations[0].upperBound}' 2>/dev/null | jq . || echo "No upper bound available"
    echo
}

# Function to generate VPA report
generate_vpa_report() {
    echo "=== Generating VPA Report ==="
    
    local report_file="vpa-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster VPA Report"
        echo "================================="
        echo "Generated: \$(date)"
        echo ""
        
        echo "=== VPA INSTALLATION STATUS ==="
        kubectl get crd | grep verticalpodautoscaler || echo "VPA CRDs not found"
        kubectl get pods -n kube-system | grep vpa || echo "VPA components not found"
        echo ""
        
        echo "=== VPA OVERVIEW ==="
        kubectl get vpa --all-namespaces 2>/dev/null || echo "No VPAs found or VPA not installed"
        echo ""
        
        echo "=== VPA DETAILED STATUS ==="
        kubectl describe vpa --all-namespaces 2>/dev/null || echo "No VPA details available"
        echo ""
        
        echo "=== VPA RECOMMENDATIONS ==="
        kubectl get vpa --all-namespaces -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name):" as \$name | .status.recommendation.containerRecommendations[]? | "  \(.containerName): CPU=\(.target.cpu // "N/A"), Memory=\(.target.memory // "N/A")"' || echo "No recommendations available"
        echo ""
        
        echo "=== RESOURCE UTILIZATION ==="
        kubectl top pods --all-namespaces --containers 2>/dev/null || echo "Metrics server not available"
        echo ""
        
    } > "\$report_file"
    
    echo "✅ VPA report generated: \$report_file"
    echo
}

# Main function
main() {
    case "\$1" in
        "monitor")
            monitor_vpa_recommendations "\$2" "\$3"
            ;;
        "analyze")
            analyze_vpa_performance
            ;;
        "compare")
            compare_vpa_recommendations "\$2" "\$3"
            ;;
        "report")
            generate_vpa_report
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  monitor <namespace> <vpa>     - Monitor VPA recommendations"
            echo "  analyze                       - Analyze VPA performance"
            echo "  compare <namespace> <vpa>     - Compare VPA recommendations with current"
            echo "  report                        - Generate VPA report"
            echo ""
            echo "Examples:"
            echo "  \$0 monitor vpa-examples resource-consumer-off-vpa"
            echo "  \$0 analyze"
            echo "  \$0 compare vpa-examples resource-consumer-off-vpa"
            echo "  \$0 report"
            ;;
    esac
}

# Run main function
main "\$@"

VPA_MONITOR_EOF
    
    chmod +x vpa-monitoring-tools.sh
    
    echo "✅ VPA monitoring tools created: vpa-monitoring-tools.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "check")
            check_vpa_installation
            ;;
        "analyze")
            analyze_current_vpa
            ;;
        "examples")
            create_vpa_examples
            ;;
        "monitoring")
            create_vpa_monitoring_tools
            ;;
        "all"|"")
            check_vpa_installation
            analyze_current_vpa
            create_vpa_examples
            create_vpa_monitoring_tools
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  check      - Check VPA installation status"
            echo "  analyze    - Analyze current VPA status"
            echo "  examples   - Create VPA examples"
            echo "  monitoring - Create VPA monitoring tools"
            echo "  all        - Run all actions (default)"
            echo ""
            echo "Examples:"
            echo "  $0 check"
            echo "  $0 analyze"
            echo "  $0 examples"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-vpa-toolkit.sh

# Запустить создание VPA toolkit
./kubernetes-vpa-toolkit.sh all
```

## 📋 **VPA vs HPA Comparison:**

### **Scaling Dimensions:**

| **Autoscaler** | **Scaling Direction** | **What Changes** | **Use Case** |
|----------------|----------------------|------------------|--------------|
| **HPA** | Horizontal | Количество Pod'ов | Переменная нагрузка |
| **VPA** | Vertical | Ресурсы Pod'а | Оптимизация ресурсов |
| **Cluster Autoscaler** | Cluster | Количество узлов | Емкость кластера |

### **VPA Update Modes:**

| **Mode** | **Behavior** | **Pod Restart** | **Use Case** |
|----------|--------------|-----------------|--------------|
| **Off** | Только рекомендации | Нет | Анализ и планирование |
| **Initial** | При создании Pod'а | Нет | Новые развертывания |
| **Recreation** | Пересоздание Pod'ов | Да | Активная оптимизация |
| **Auto** | Автоматическое (экспериментальный) | Возможно | Будущие версии |

## 🎯 **Практические команды:**

### **Работа с VPA:**
```bash
# Запустить VPA toolkit
./kubernetes-vpa-toolkit.sh all

# Мониторинг VPA
./vpa-monitoring-tools.sh monitor vpa-examples resource-consumer-off-vpa

# Сравнение рекомендаций
./vpa-monitoring-tools.sh compare vpa-examples resource-consumer-off-vpa
```

### **Создание VPA:**
```bash
# Простой VPA в режиме Off
kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Off"
EOF
```

### **Анализ рекомендаций:**
```bash
# Получить рекомендации VPA
kubectl get vpa my-app-vpa -o jsonpath='{.status.recommendation}' | jq .

# Проверить текущие ресурсы
kubectl get deployment my-app -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

## 🔧 **Best Practices для VPA:**

### **Конфигурация:**
- **Start with Off mode** - начинайте с режима Off
- **Set resource policies** - устанавливайте политики ресурсов
- **Define min/max bounds** - определяйте минимальные/максимальные границы
- **Monitor recommendations** - мониторьте рекомендации

### **Production Usage:**
- **Avoid Recreation mode** - избегайте режима Recreation в продакшене
- **Use Initial mode** - используйте режим Initial для новых развертываний
- **Combine with HPA carefully** - осторожно комбинируйте с HPA
- **Test thoroughly** - тщательно тестируйте

### **Monitoring:**
- **Track recommendation accuracy** - отслеживайте точность рекомендаций
- **Monitor resource waste** - мониторьте расход ресурсов
- **Set up alerts** - настройте оповещения
- **Regular review** - регулярно пересматривайте настройки

**VPA помогает оптимизировать использование ресурсов без ручной настройки!**
