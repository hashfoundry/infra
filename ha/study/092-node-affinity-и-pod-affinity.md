# 92. Node Affinity и Pod Affinity

## 🎯 **Node Affinity и Pod Affinity**

**Affinity** в Kubernetes - это расширенный механизм планирования, который позволяет определять предпочтения и требования для размещения Pod'ов на определенных узлах (Node Affinity) или относительно других Pod'ов (Pod Affinity), обеспечивая более гибкое и интеллектуальное планирование workloads.

## 🏗️ **Типы Affinity:**

### **1. Node Affinity:**
- **requiredDuringSchedulingIgnoredDuringExecution** - жесткие требования
- **preferredDuringSchedulingIgnoredDuringExecution** - мягкие предпочтения
- **Node selectors** - селекторы узлов
- **Label matching** - сопоставление меток

### **2. Pod Affinity/Anti-Affinity:**
- **podAffinity** - притяжение к другим Pod'ам
- **podAntiAffinity** - отталкивание от других Pod'ов
- **Topology domains** - топологические домены
- **Label selectors** - селекторы меток

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих affinity правил:**
```bash
# Проверить Pod'ы с affinity правилами
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.affinity != null) | {name: .metadata.name, namespace: .metadata.namespace, affinity: .spec.affinity}'
```

### **2. Создание comprehensive affinity toolkit:**
```bash
# Создать скрипт для работы с affinity
cat << 'EOF' > kubernetes-affinity-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Affinity Toolkit ==="
echo "Comprehensive toolkit for Node and Pod Affinity in HashFoundry HA cluster"
echo

# Функция для анализа текущих affinity правил
analyze_current_affinity() {
    echo "=== Current Affinity Analysis ==="
    
    echo "1. Pods with Node Affinity:"
    echo "=========================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.affinity.nodeAffinity != null) | "\(.metadata.namespace)/\(.metadata.name): Node Affinity configured"'
    echo
    
    echo "2. Pods with Pod Affinity:"
    echo "========================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.affinity.podAffinity != null) | "\(.metadata.namespace)/\(.metadata.name): Pod Affinity configured"'
    echo
    
    echo "3. Pods with Pod Anti-Affinity:"
    echo "==============================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.affinity.podAntiAffinity != null) | "\(.metadata.namespace)/\(.metadata.name): Pod Anti-Affinity configured"'
    echo
    
    echo "4. Node Labels for Affinity:"
    echo "============================"
    kubectl get nodes --show-labels | grep -E "(zone|region|instance-type|workload)"
    echo
}

# Функция для создания Node Affinity examples
create_node_affinity_examples() {
    echo "=== Creating Node Affinity Examples ==="
    
    # Подготовить узлы с метками
    echo "Preparing nodes with labels..."
    NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    
    # Добавить метки для демонстрации
    if [ ${#NODES[@]} -ge 1 ]; then
        kubectl label node ${NODES[0]} hashfoundry.io/node-tier=high-performance --overwrite
        kubectl label node ${NODES[0]} hashfoundry.io/storage-type=ssd --overwrite
        echo "Labeled ${NODES[0]} as high-performance with SSD"
    fi
    
    if [ ${#NODES[@]} -ge 2 ]; then
        kubectl label node ${NODES[1]} hashfoundry.io/node-tier=standard --overwrite
        kubectl label node ${NODES[1]} hashfoundry.io/storage-type=hdd --overwrite
        echo "Labeled ${NODES[1]} as standard with HDD"
    fi
    
    if [ ${#NODES[@]} -ge 3 ]; then
        kubectl label node ${NODES[2]} hashfoundry.io/node-tier=budget --overwrite
        kubectl label node ${NODES[2]} hashfoundry.io/storage-type=network --overwrite
        echo "Labeled ${NODES[2]} as budget with network storage"
    fi
    echo
    
    # Создать namespace для примеров
    kubectl create namespace affinity-examples --dry-run=client -o yaml | kubectl apply -f -
    
    # Example 1: Required Node Affinity
    cat << REQUIRED_NODE_AFFINITY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: high-performance-app
  namespace: affinity-examples
  labels:
    app.kubernetes.io/name: "high-performance-app"
    hashfoundry.io/example: "required-node-affinity"
  annotations:
    hashfoundry.io/description: "Example of required node affinity"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "high-performance-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "high-performance-app"
        hashfoundry.io/tier: "high-performance"
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: hashfoundry.io/node-tier
                operator: In
                values:
                - high-performance
              - key: hashfoundry.io/storage-type
                operator: In
                values:
                - ssd
      containers:
      - name: app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        ports:
        - containerPort: 80
REQUIRED_NODE_AFFINITY_EOF
    
    # Example 2: Preferred Node Affinity
    cat << PREFERRED_NODE_AFFINITY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flexible-app
  namespace: affinity-examples
  labels:
    app.kubernetes.io/name: "flexible-app"
    hashfoundry.io/example: "preferred-node-affinity"
  annotations:
    hashfoundry.io/description: "Example of preferred node affinity"
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: "flexible-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "flexible-app"
        hashfoundry.io/tier: "flexible"
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: hashfoundry.io/node-tier
                operator: In
                values:
                - high-performance
          - weight: 50
            preference:
              matchExpressions:
              - key: hashfoundry.io/storage-type
                operator: In
                values:
                - ssd
          - weight: 10
            preference:
              matchExpressions:
              - key: hashfoundry.io/node-tier
                operator: In
                values:
                - standard
      containers:
      - name: app
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
PREFERRED_NODE_AFFINITY_EOF
    
    # Example 3: Combined Node Affinity
    cat << COMBINED_NODE_AFFINITY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-app
  namespace: affinity-examples
  labels:
    app.kubernetes.io/name: "database-app"
    hashfoundry.io/example: "combined-node-affinity"
  annotations:
    hashfoundry.io/description: "Example of combined required and preferred node affinity"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "database-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "database-app"
        hashfoundry.io/component: "database"
        hashfoundry.io/tier: "critical"
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: hashfoundry.io/storage-type
                operator: In
                values:
                - ssd
                - hdd
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: hashfoundry.io/node-tier
                operator: In
                values:
                - high-performance
          - weight: 80
            preference:
              matchExpressions:
              - key: hashfoundry.io/storage-type
                operator: In
                values:
                - ssd
      containers:
      - name: database
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: "hashfoundry"
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_PASSWORD
          value: "password"
        resources:
          requests:
            cpu: "300m"
            memory: "512Mi"
          limits:
            cpu: "1"
            memory: "1Gi"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        emptyDir: {}
COMBINED_NODE_AFFINITY_EOF
    
    echo "✅ Node Affinity examples created"
    echo
}

# Функция для создания Pod Affinity examples
create_pod_affinity_examples() {
    echo "=== Creating Pod Affinity Examples ==="
    
    # Example 1: Pod Affinity (co-location)
    cat << POD_AFFINITY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: affinity-examples
  labels:
    app.kubernetes.io/name: "web-frontend"
    hashfoundry.io/example: "pod-affinity"
  annotations:
    hashfoundry.io/description: "Web frontend that wants to be close to cache"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "web-frontend"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "web-frontend"
        hashfoundry.io/component: "frontend"
        hashfoundry.io/tier: "web"
    spec:
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: hashfoundry.io/component
                  operator: In
                  values:
                  - cache
              topologyKey: kubernetes.io/hostname
      containers:
      - name: frontend
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
  namespace: affinity-examples
  labels:
    app.kubernetes.io/name: "redis-cache"
    hashfoundry.io/example: "pod-affinity"
  annotations:
    hashfoundry.io/description: "Redis cache for web frontend"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "redis-cache"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "redis-cache"
        hashfoundry.io/component: "cache"
        hashfoundry.io/tier: "cache"
    spec:
      containers:
      - name: redis
        image: redis:6-alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
        ports:
        - containerPort: 6379
POD_AFFINITY_EOF
    
    # Example 2: Pod Anti-Affinity (separation)
    cat << POD_ANTI_AFFINITY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distributed-database
  namespace: affinity-examples
  labels:
    app.kubernetes.io/name: "distributed-database"
    hashfoundry.io/example: "pod-anti-affinity"
  annotations:
    hashfoundry.io/description: "Distributed database with anti-affinity for HA"
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: "distributed-database"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "distributed-database"
        hashfoundry.io/component: "database"
        hashfoundry.io/tier: "data"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                - distributed-database
            topologyKey: kubernetes.io/hostname
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - distributed-database
              topologyKey: topology.kubernetes.io/zone
      containers:
      - name: database
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: "distributed"
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_PASSWORD
          value: "password"
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
POD_ANTI_AFFINITY_EOF
    
    # Example 3: Complex Affinity Rules
    cat << COMPLEX_AFFINITY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: microservice-app
  namespace: affinity-examples
  labels:
    app.kubernetes.io/name: "microservice-app"
    hashfoundry.io/example: "complex-affinity"
  annotations:
    hashfoundry.io/description: "Microservice with complex affinity rules"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "microservice-app"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "microservice-app"
        hashfoundry.io/component: "microservice"
        hashfoundry.io/tier: "application"
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: hashfoundry.io/node-tier
                operator: In
                values:
                - high-performance
                - standard
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 50
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: hashfoundry.io/component
                  operator: In
                  values:
                  - cache
                  - database
              topologyKey: kubernetes.io/hostname
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - microservice-app
              topologyKey: kubernetes.io/hostname
      containers:
      - name: microservice
        image: nginx:1.21-alpine
        resources:
          requests:
            cpu: "150m"
            memory: "192Mi"
        ports:
        - containerPort: 80
COMPLEX_AFFINITY_EOF
    
    echo "✅ Pod Affinity examples created"
    echo
}

# Функция для создания affinity analysis tools
create_affinity_analysis_tools() {
    echo "=== Creating Affinity Analysis Tools ==="
    
    cat << AFFINITY_TOOLS_EOF > affinity-analysis-tools.sh
#!/bin/bash

echo "=== Affinity Analysis Tools ==="
echo "Tools for analyzing affinity rules and their effects"
echo

# Function to analyze pod affinity
analyze_pod_affinity() {
    local namespace=\${1:-""}
    local pod_name=\${2:-""}
    
    if [ -n "\$namespace" ] && [ -n "\$pod_name" ]; then
        echo "Analyzing affinity for pod: \$pod_name in namespace: \$namespace"
        echo "=============================================================="
        
        # Get affinity rules
        echo "1. Affinity Rules:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.affinity}' | jq . 2>/dev/null || echo "No affinity rules"
        echo
        
        # Get pod placement
        echo "2. Pod Placement:"
        kubectl get pod "\$pod_name" -n "\$namespace" -o custom-columns="NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase"
        echo
        
        # Check node labels
        NODE=\$(kubectl get pod "\$pod_name" -n "\$namespace" -o jsonpath='{.spec.nodeName}')
        if [ -n "\$NODE" ]; then
            echo "3. Node Labels:"
            kubectl get node "\$NODE" --show-labels
            echo
        fi
        
        # Check co-located pods
        if [ -n "\$NODE" ]; then
            echo "4. Co-located Pods on \$NODE:"
            kubectl get pods --all-namespaces --field-selector spec.nodeName="\$NODE" -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,LABELS:.metadata.labels"
            echo
        fi
    else
        echo "Usage: analyze_pod_affinity <namespace> <pod-name>"
    fi
}

# Function to check affinity violations
check_affinity_violations() {
    echo "=== Checking Affinity Violations ==="
    
    # Check pending pods with affinity
    echo "1. Pending Pods with Affinity:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o json | jq -r '.items[] | select(.spec.affinity != null) | "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[] | select(.type=="PodScheduled") | .reason)"'
    echo
    
    # Check failed scheduling events
    echo "2. Failed Scheduling Events:"
    kubectl get events --all-namespaces --field-selector reason=FailedScheduling | grep -i affinity
    echo
}

# Function to simulate affinity placement
simulate_affinity_placement() {
    echo "=== Simulating Affinity Placement ==="
    
    # Create test pod with node affinity
    cat << TEST_AFFINITY_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: affinity-test-pod
  namespace: default
  labels:
    app: affinity-test
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
  containers:
  - name: test-container
    image: nginx:1.21-alpine
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
TEST_AFFINITY_EOF
    
    echo "Test pod with affinity created. Monitoring placement..."
    
    # Wait and check placement
    sleep 5
    kubectl get pod affinity-test-pod -o wide
    kubectl describe pod affinity-test-pod | grep -A 10 "Events:"
    
    # Cleanup
    kubectl delete pod affinity-test-pod --grace-period=0 --force 2>/dev/null
    echo "Test pod cleaned up"
    echo
}

# Function to generate affinity report
generate_affinity_report() {
    echo "=== Generating Affinity Report ==="
    
    local report_file="affinity-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster Affinity Report"
        echo "======================================"
        echo "Generated: \$(date)"
        echo ""
        
        echo "=== NODE LABELS ==="
        kubectl get nodes --show-labels
        echo ""
        
        echo "=== PODS WITH NODE AFFINITY ==="
        kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.affinity.nodeAffinity != null) | "\(.metadata.namespace)/\(.metadata.name)"'
        echo ""
        
        echo "=== PODS WITH POD AFFINITY ==="
        kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.affinity.podAffinity != null) | "\(.metadata.namespace)/\(.metadata.name)"'
        echo ""
        
        echo "=== PODS WITH POD ANTI-AFFINITY ==="
        kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.affinity.podAntiAffinity != null) | "\(.metadata.namespace)/\(.metadata.name)"'
        echo ""
        
        echo "=== POD DISTRIBUTION ==="
        kubectl get pods --all-namespaces -o wide | awk 'NR>1 {count[\$8]++} END {for (node in count) print node ": " count[node] " pods"}'
        echo ""
        
    } > "\$report_file"
    
    echo "✅ Affinity report generated: \$report_file"
    echo
}

# Main function
main() {
    case "\$1" in
        "analyze")
            analyze_pod_affinity "\$2" "\$3"
            ;;
        "violations")
            check_affinity_violations
            ;;
        "simulate")
            simulate_affinity_placement
            ;;
        "report")
            generate_affinity_report
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  analyze <namespace> <pod>  - Analyze pod affinity"
            echo "  violations                 - Check affinity violations"
            echo "  simulate                   - Simulate affinity placement"
            echo "  report                     - Generate affinity report"
            echo ""
            echo "Examples:"
            echo "  \$0 analyze affinity-examples web-frontend-xxx"
            echo "  \$0 violations"
            echo "  \$0 simulate"
            echo "  \$0 report"
            ;;
    esac
}

# Run main function
main "\$@"

AFFINITY_TOOLS_EOF
    
    chmod +x affinity-analysis-tools.sh
    
    echo "✅ Affinity analysis tools created: affinity-analysis-tools.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_affinity
            ;;
        "node-examples")
            create_node_affinity_examples
            ;;
        "pod-examples")
            create_pod_affinity_examples
            ;;
        "tools")
            create_affinity_analysis_tools
            ;;
        "all"|"")
            analyze_current_affinity
            create_node_affinity_examples
            create_pod_affinity_examples
            create_affinity_analysis_tools
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze        - Analyze current affinity rules"
            echo "  node-examples  - Create node affinity examples"
            echo "  pod-examples   - Create pod affinity examples"
            echo "  tools          - Create affinity analysis tools"
            echo "  all            - Run all actions (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 node-examples"
            echo "  $0 pod-examples"
            echo "  $0 tools"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-affinity-toolkit.sh

# Запустить создание affinity toolkit
./kubernetes-affinity-toolkit.sh all
```

## 📋 **Affinity Types и Use Cases:**

### **Node Affinity Types:**

| **Тип** | **Поведение** | **Use Case** | **Пример** |
|----------|---------------|--------------|------------|
| **Required** | Жесткое требование | Compliance, Hardware | GPU nodes, SSD storage |
| **Preferred** | Мягкое предпочтение | Optimization | High-performance nodes |
| **Combined** | Требование + предпочтение | Flexible placement | Database with preferences |

### **Pod Affinity Scenarios:**

| **Сценарий** | **Тип** | **Цель** | **Пример** |
|--------------|---------|----------|------------|
| **Co-location** | Pod Affinity | Performance | Web + Cache |
| **Separation** | Pod Anti-Affinity | High Availability | Database replicas |
| **Zone Spread** | Anti-Affinity + Topology | Disaster Recovery | Multi-zone apps |

## 🎯 **Практические команды:**

### **Работа с affinity:**
```bash
# Запустить affinity toolkit
./kubernetes-affinity-toolkit.sh all

# Анализ конкретного pod
./affinity-analysis-tools.sh analyze affinity-examples web-frontend-xxx

# Проверить нарушения affinity
./affinity-analysis-tools.sh violations
```

### **Проверка размещения:**
```bash
# Проверить распределение подов по узлам
kubectl get pods --all-namespaces -o wide | awk '{print $8}' | sort | uniq -c

# Проверить affinity правила
kubectl get pods -o json | jq '.items[] | select(.spec.affinity != null) | {name: .metadata.name, affinity: .spec.affinity}'

# Проверить метки узлов
kubectl get nodes --show-labels
```

### **Создание affinity правил:**
```bash
# Node affinity для SSD узлов
kubectl patch deployment my-app -p '{"spec":{"template":{"spec":{"affinity":{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"storage-type","operator":"In","values":["ssd"]}]}]}}}}}}}'

# Pod anti-affinity для HA
kubectl patch deployment my-app -p '{"spec":{"template":{"spec":{"affinity":{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app":"my-app"}},"topologyKey":"kubernetes.io/hostname"}]}}}}}}'
```

## 🔧 **Best Practices для Affinity:**

### **Node Affinity:**
- **Use labels wisely** - используйте осмысленные метки
- **Combine required and preferred** - комбинируйте жесткие и мягкие правила
- **Consider node lifecycle** - учитывайте жизненный цикл узлов
- **Plan for scaling** - планируйте масштабирование

### **Pod Affinity:**
- **Use topology keys** - используйте ключи топологии
- **Balance performance and availability** - балансируйте производительность и доступность
- **Consider resource constraints** - учитывайте ограничения ресурсов
- **Monitor placement** - мониторьте размещение

### **Anti-Affinity:**
- **Ensure high availability** - обеспечивайте высокую доступность
- **Use appropriate topology** - используйте подходящую топологию
- **Consider failure domains** - учитывайте домены сбоев
- **Plan for maintenance** - планируйте обслуживание

## 📊 **Monitoring Affinity:**

### **Ключевые метрики:**
- **Pod placement distribution** - распределение размещения подов
- **Affinity rule violations** - нарушения правил affinity
- **Scheduling failures** - сбои планирования
- **Node utilization balance** - баланс использования узлов

### **Troubleshooting:**
```bash
# Проверить pending pods с affinity
kubectl get pods --field-selector=status.phase=Pending -o json | jq '.items[] | select(.spec.affinity != null)'

# Анализ событий планирования
kubectl get events --field-selector reason=FailedScheduling | grep affinity

# Проверить распределение по зонам
kubectl get pods -o wide | awk '{print $7}' | sort | uniq -c
```

**Правильное использование Affinity обеспечивает оптимальное размещение и высокую доступность приложений!**
