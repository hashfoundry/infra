# 99. Custom Resources и Operators

## 🎯 **Custom Resources и Operators**

**Custom Resources (CR)** - это расширения Kubernetes API, которые позволяют определять собственные типы ресурсов. **Operators** - это паттерн для автоматизации управления сложными приложениями, комбинирующий Custom Resources с контроллерами для реализации domain-specific логики.

## 🏗️ **Компоненты Custom Resources и Operators:**

### **1. Custom Resource Definition (CRD):**
- **Schema Definition** - определение схемы ресурса
- **API Versioning** - версионирование API
- **Validation** - валидация данных
- **Status Subresource** - подресурс статуса

### **2. Operator Components:**
- **Custom Controller** - пользовательский контроллер
- **Reconciliation Loop** - цикл согласования
- **Event Handling** - обработка событий
- **State Management** - управление состоянием

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих CRDs и Operators:**
```bash
# Проверить существующие CRDs
kubectl get crd
kubectl get crd -o custom-columns="NAME:.metadata.name,GROUP:.spec.group,VERSION:.spec.versions[*].name"
```

### **2. Создание comprehensive Custom Resources и Operators toolkit:**
```bash
# Создать скрипт для работы с Custom Resources и Operators
cat << 'EOF' > kubernetes-custom-resources-operators-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Custom Resources and Operators Toolkit ==="
echo "Comprehensive toolkit for Custom Resources and Operators in HashFoundry HA cluster"
echo

# Функция для анализа существующих CRDs и Operators
analyze_existing_crds_operators() {
    echo "=== Existing CRDs and Operators Analysis ==="
    
    echo "1. Custom Resource Definitions:"
    echo "=============================="
    kubectl get crd -o custom-columns="NAME:.metadata.name,GROUP:.spec.group,SCOPE:.spec.scope,VERSIONS:.spec.versions[*].name,AGE:.metadata.creationTimestamp"
    echo
    
    echo "2. CRDs by Group:"
    echo "================"
    kubectl get crd -o jsonpath='{.items[*].spec.group}' | tr ' ' '\n' | sort | uniq -c | sort -nr
    echo
    
    echo "3. Operator Deployments (common patterns):"
    echo "=========================================="
    kubectl get deployments --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,AVAILABLE:.status.availableReplicas" | grep -E "(operator|controller|manager)" || echo "No obvious operators found"
    echo
    
    echo "4. Custom Resources Instances:"
    echo "============================="
    for crd in $(kubectl get crd -o jsonpath='{.items[*].metadata.name}'); do
        echo "CRD: $crd"
        kubectl get "$crd" --all-namespaces 2>/dev/null | head -5 || echo "  No instances found"
        echo
    done
    
    echo "5. Operator Pods:"
    echo "================"
    kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName" | grep -E "(operator|controller|manager)" || echo "No operator pods found"
    echo
}

# Функция для создания example CRD
create_example_crd() {
    echo "=== Creating Example CRD ==="
    
    # Создать namespace для примеров
    kubectl create namespace custom-resources-examples --dry-run=client -o yaml | kubectl apply -f -
    
    # Example 1: Simple Application CRD
    cat << APPLICATION_CRD_EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.hashfoundry.io
  labels:
    app.kubernetes.io/name: "applications-crd"
    hashfoundry.io/example: "simple-crd"
  annotations:
    hashfoundry.io/description: "Custom Resource Definition for HashFoundry Applications"
spec:
  group: hashfoundry.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              name:
                type: string
                description: "Application name"
              version:
                type: string
                description: "Application version"
                pattern: '^v[0-9]+\.[0-9]+\.[0-9]+$'
              replicas:
                type: integer
                minimum: 1
                maximum: 100
                description: "Number of replicas"
              image:
                type: string
                description: "Container image"
              resources:
                type: object
                properties:
                  cpu:
                    type: string
                    description: "CPU request"
                  memory:
                    type: string
                    description: "Memory request"
              environment:
                type: object
                additionalProperties:
                  type: string
                description: "Environment variables"
            required:
            - name
            - version
            - image
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Running", "Failed", "Succeeded"]
                description: "Application phase"
              replicas:
                type: integer
                description: "Current replicas"
              readyReplicas:
                type: integer
                description: "Ready replicas"
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
                    reason:
                      type: string
                    message:
                      type: string
    additionalPrinterColumns:
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Ready
      type: integer
      jsonPath: .status.readyReplicas
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames:
    - app
    - apps
APPLICATION_CRD_EOF
    
    # Example 2: Database CRD with more complex schema
    cat << DATABASE_CRD_EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.hashfoundry.io
  labels:
    app.kubernetes.io/name: "databases-crd"
    hashfoundry.io/example: "complex-crd"
  annotations:
    hashfoundry.io/description: "Custom Resource Definition for HashFoundry Databases"
spec:
  group: hashfoundry.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              type:
                type: string
                enum: ["postgresql", "mysql", "mongodb", "redis"]
                description: "Database type"
              version:
                type: string
                description: "Database version"
              storage:
                type: object
                properties:
                  size:
                    type: string
                    pattern: '^[0-9]+[KMGT]i$'
                    description: "Storage size"
                  storageClass:
                    type: string
                    description: "Storage class"
                required:
                - size
              backup:
                type: object
                properties:
                  enabled:
                    type: boolean
                    description: "Enable backups"
                  schedule:
                    type: string
                    description: "Backup schedule (cron format)"
                  retention:
                    type: integer
                    minimum: 1
                    maximum: 365
                    description: "Backup retention days"
              monitoring:
                type: object
                properties:
                  enabled:
                    type: boolean
                    description: "Enable monitoring"
                  metrics:
                    type: array
                    items:
                      type: string
                    description: "Metrics to collect"
              users:
                type: array
                items:
                  type: object
                  properties:
                    name:
                      type: string
                    permissions:
                      type: array
                      items:
                        type: string
                  required:
                  - name
            required:
            - type
            - version
            - storage
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Creating", "Running", "Failed", "Deleting"]
              endpoint:
                type: string
                description: "Database endpoint"
              lastBackup:
                type: string
                format: date-time
                description: "Last backup time"
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
                    reason:
                      type: string
                    message:
                      type: string
    additionalPrinterColumns:
    - name: Type
      type: string
      jsonPath: .spec.type
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Storage
      type: string
      jsonPath: .spec.storage.size
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Endpoint
      type: string
      jsonPath: .status.endpoint
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames:
    - db
DATABASE_CRD_EOF
    
    echo "✅ Example CRDs created"
    echo
}

# Функция для создания example Custom Resources
create_example_custom_resources() {
    echo "=== Creating Example Custom Resources ==="
    
    # Example 1: Application instances
    cat << APPLICATION_INSTANCE_EOF | kubectl apply -f -
apiVersion: hashfoundry.io/v1
kind: Application
metadata:
  name: web-frontend
  namespace: custom-resources-examples
  labels:
    app.kubernetes.io/name: "web-frontend"
    hashfoundry.io/example: "application-cr"
  annotations:
    hashfoundry.io/description: "Web frontend application"
spec:
  name: "web-frontend"
  version: "v1.2.3"
  replicas: 3
  image: "nginx:1.21-alpine"
  resources:
    cpu: "100m"
    memory: "128Mi"
  environment:
    ENV: "production"
    LOG_LEVEL: "info"
    FEATURE_FLAGS: "new-ui,analytics"
---
apiVersion: hashfoundry.io/v1
kind: Application
metadata:
  name: api-backend
  namespace: custom-resources-examples
  labels:
    app.kubernetes.io/name: "api-backend"
    hashfoundry.io/example: "application-cr"
  annotations:
    hashfoundry.io/description: "API backend application"
spec:
  name: "api-backend"
  version: "v2.1.0"
  replicas: 5
  image: "node:16-alpine"
  resources:
    cpu: "200m"
    memory: "256Mi"
  environment:
    NODE_ENV: "production"
    API_VERSION: "v2"
    DATABASE_URL: "postgresql://db:5432/app"
APPLICATION_INSTANCE_EOF
    
    # Example 2: Database instances
    cat << DATABASE_INSTANCE_EOF | kubectl apply -f -
apiVersion: hashfoundry.io/v1
kind: Database
metadata:
  name: main-postgresql
  namespace: custom-resources-examples
  labels:
    app.kubernetes.io/name: "main-postgresql"
    hashfoundry.io/component: "database"
    hashfoundry.io/example: "database-cr"
  annotations:
    hashfoundry.io/description: "Main PostgreSQL database"
spec:
  type: "postgresql"
  version: "13.7"
  storage:
    size: "10Gi"
    storageClass: "fast-ssd"
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 30
  monitoring:
    enabled: true
    metrics:
    - "connections"
    - "queries_per_second"
    - "cache_hit_ratio"
  users:
  - name: "app_user"
    permissions: ["SELECT", "INSERT", "UPDATE", "DELETE"]
  - name: "readonly_user"
    permissions: ["SELECT"]
---
apiVersion: hashfoundry.io/v1
kind: Database
metadata:
  name: cache-redis
  namespace: custom-resources-examples
  labels:
    app.kubernetes.io/name: "cache-redis"
    app.kubernetes.io/component: "cache"
    hashfoundry.io/example: "database-cr"
  annotations:
    hashfoundry.io/description: "Redis cache database"
spec:
  type: "redis"
  version: "6.2"
  storage:
    size: "5Gi"
    storageClass: "fast-ssd"
  backup:
    enabled: false
  monitoring:
    enabled: true
    metrics:
    - "memory_usage"
    - "operations_per_second"
    - "keyspace_hits"
DATABASE_INSTANCE_EOF
    
    echo "✅ Example Custom Resources created"
    echo
}

# Функция для создания simple operator example
create_simple_operator_example() {
    echo "=== Creating Simple Operator Example ==="
    
    # Create a simple operator deployment (mock implementation)
    cat << OPERATOR_DEPLOYMENT_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application-operator
  namespace: custom-resources-examples
  labels:
    app.kubernetes.io/name: "application-operator"
    app.kubernetes.io/component: "operator"
    hashfoundry.io/example: "simple-operator"
  annotations:
    hashfoundry.io/description: "Simple Application Operator"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "application-operator"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "application-operator"
        app.kubernetes.io/component: "operator"
    spec:
      serviceAccountName: application-operator
      containers:
      - name: operator
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Operator reconciling...'; sleep 30; done"]
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        env:
        - name: WATCH_NAMESPACE
          value: "custom-resources-examples"
        - name: OPERATOR_NAME
          value: "application-operator"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: application-operator
  namespace: custom-resources-examples
  labels:
    app.kubernetes.io/name: "application-operator"
    hashfoundry.io/example: "simple-operator"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: application-operator
  labels:
    app.kubernetes.io/name: "application-operator"
    hashfoundry.io/example: "simple-operator"
rules:
- apiGroups: ["hashfoundry.io"]
  resources: ["applications", "databases"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: application-operator
  labels:
    app.kubernetes.io/name: "application-operator"
    hashfoundry.io/example: "simple-operator"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: application-operator
subjects:
- kind: ServiceAccount
  name: application-operator
  namespace: custom-resources-examples
OPERATOR_DEPLOYMENT_EOF
    
    echo "✅ Simple Operator example created"
    echo "Note: This is a mock operator for demonstration purposes"
    echo
}

# Функция для создания monitoring tools
create_custom_resources_monitoring() {
    echo "=== Creating Custom Resources Monitoring Tools ==="
    
    cat << CR_MONITOR_EOF > custom-resources-monitoring.sh
#!/bin/bash

echo "=== Custom Resources Monitoring Tools ==="
echo "Tools for monitoring Custom Resources and Operators"
echo

# Function to monitor custom resources
monitor_custom_resources() {
    local crd_name=\${1:-""}
    local namespace=\${2:-""}
    
    if [ -n "\$crd_name" ]; then
        echo "=== Monitoring Custom Resource: \$crd_name ==="
        
        while true; do
            clear
            echo "Custom Resource Status: \$crd_name"
            echo "==============================="
            echo "Time: \$(date)"
            echo
            
            # CRD details
            echo "CRD Information:"
            kubectl get crd "\$crd_name" -o custom-columns="NAME:.metadata.name,GROUP:.spec.group,VERSIONS:.spec.versions[*].name,SCOPE:.spec.scope" 2>/dev/null
            echo
            
            # Custom resource instances
            echo "Custom Resource Instances:"
            if [ -n "\$namespace" ]; then
                kubectl get "\$crd_name" -n "\$namespace" 2>/dev/null || echo "No instances found in namespace \$namespace"
            else
                kubectl get "\$crd_name" --all-namespaces 2>/dev/null || echo "No instances found"
            fi
            echo
            
            # Recent events
            echo "Recent Events:"
            kubectl get events --all-namespaces --field-selector involvedObject.apiVersion=\$(kubectl get crd "\$crd_name" -o jsonpath='{.spec.group}')/\$(kubectl get crd "\$crd_name" -o jsonpath='{.spec.versions[0].name}') --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || echo "No recent events"
            echo
            
            echo "Press Ctrl+C to stop monitoring"
            sleep 15
        done
    else
        echo "Usage: monitor_custom_resources <crd-name> [namespace]"
        echo "Example: monitor_custom_resources applications.hashfoundry.io custom-resources-examples"
    fi
}

# Function to analyze operator health
analyze_operator_health() {
    echo "=== Operator Health Analysis ==="
    
    echo "1. Operator Deployments:"
    echo "======================="
    kubectl get deployments --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,AGE:.metadata.creationTimestamp" | grep -E "(operator|controller|manager)" || echo "No operators found"
    echo
    
    echo "2. Operator Pods:"
    echo "================"
    kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName" | grep -E "(operator|controller|manager)" || echo "No operator pods found"
    echo
    
    echo "3. Operator Logs (last 20 lines):"
    echo "=================================="
    for pod in \$(kubectl get pods --all-namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -E "(operator|controller|manager)"); do
        echo "Pod: \$pod"
        kubectl logs "\$pod" --tail=20 2>/dev/null | head -10 || echo "No logs available"
        echo "---"
    done
    echo
    
    echo "4. CRD Status:"
    echo "============="
    kubectl get crd -o custom-columns="NAME:.metadata.name,ESTABLISHED:.status.conditions[?(@.type=='Established')].status,NAMES-ACCEPTED:.status.conditions[?(@.type=='NamesAccepted')].status"
    echo
}

# Function to validate custom resources
validate_custom_resources() {
    local crd_name=\${1:-""}
    
    if [ -n "\$crd_name" ]; then
        echo "=== Validating Custom Resources: \$crd_name ==="
        
        # Get all instances
        kubectl get "\$crd_name" --all-namespaces -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' | while read instance; do
            if [ -n "\$instance" ]; then
                namespace=\$(echo "\$instance" | cut -d'/' -f1)
                name=\$(echo "\$instance" | cut -d'/' -f2)
                
                echo "Validating: \$namespace/\$name"
                
                # Check if resource is valid
                kubectl get "\$crd_name" "\$name" -n "\$namespace" -o yaml >/dev/null 2>&1
                if [ \$? -eq 0 ]; then
                    echo "  ✅ Valid"
                else
                    echo "  ❌ Invalid"
                fi
                
                # Check status
                status=\$(kubectl get "\$crd_name" "\$name" -n "\$namespace" -o jsonpath='{.status}' 2>/dev/null)
                if [ -n "\$status" ]; then
                    echo "  Status: Available"
                else
                    echo "  Status: No status"
                fi
                echo
            fi
        done
    else
        echo "Usage: validate_custom_resources <crd-name>"
        echo "Example: validate_custom_resources applications.hashfoundry.io"
    fi
}

# Function to generate custom resources report
generate_custom_resources_report() {
    echo "=== Generating Custom Resources Report ==="
    
    local report_file="custom-resources-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster Custom Resources Report"
        echo "=============================================="
        echo "Generated: \$(date)"
        echo ""
        
        echo "=== CUSTOM RESOURCE DEFINITIONS ==="
        kubectl get crd
        echo ""
        
        echo "=== CRD DETAILS ==="
        kubectl describe crd
        echo ""
        
        echo "=== CUSTOM RESOURCE INSTANCES ==="
        for crd in \$(kubectl get crd -o jsonpath='{.items[*].metadata.name}'); do
            echo "CRD: \$crd"
            kubectl get "\$crd" --all-namespaces 2>/dev/null || echo "No instances"
            echo ""
        done
        
        echo "=== OPERATORS ==="
        kubectl get deployments --all-namespaces | grep -E "(operator|controller|manager)" || echo "No operators found"
        echo ""
        
        echo "=== OPERATOR PODS ==="
        kubectl get pods --all-namespaces | grep -E "(operator|controller|manager)" || echo "No operator pods found"
        echo ""
        
    } > "\$report_file"
    
    echo "✅ Custom Resources report generated: \$report_file"
    echo
}

# Main function
main() {
    case "\$1" in
        "monitor")
            monitor_custom_resources "\$2" "\$3"
            ;;
        "analyze")
            analyze_operator_health
            ;;
        "validate")
            validate_custom_resources "\$2"
            ;;
        "report")
            generate_custom_resources_report
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  monitor <crd> [namespace]  - Monitor custom resources"
            echo "  analyze                    - Analyze operator health"
            echo "  validate <crd>             - Validate custom resources"
            echo "  report                     - Generate custom resources report"
            echo ""
            echo "Examples:"
            echo "  \$0 monitor applications.hashfoundry.io"
            echo "  \$0 analyze"
            echo "  \$0 validate databases.hashfoundry.io"
            echo "  \$0 report"
            ;;
    esac
}

# Run main function
main "\$@"

CR_MONITOR_EOF
    
    chmod +x custom-resources-monitoring.sh
    
    echo "✅ Custom Resources monitoring tools created: custom-resources-monitoring.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_existing_crds_operators
            ;;
        "create-crd")
            create_example_crd
            ;;
        "create-cr")
            create_example_custom_resources
            ;;
        "create-operator")
            create_simple_operator_example
            ;;
        "monitoring")
            create_custom_resources_monitoring
            ;;
        "cleanup")
            # Cleanup examples
            kubectl delete namespace custom-resources-examples --grace-period=0 2>/dev/null || true
            kubectl delete crd applications.hashfoundry.io databases.hashfoundry.io 2>/dev/null || true
            kubectl delete clusterrole application-operator 2>/dev/null || true
            kubectl delete clusterrolebinding application-operator 2>/dev/null || true
            echo "✅ Custom Resources examples cleaned up"
            ;;
        "all"|"")
            analyze_existing_crds_operators
            create_example_crd
            create_example_custom_resources
            create_simple_operator_example
            create_custom_resources_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze         - Analyze existing CRDs and operators"
            echo "  create-crd      - Create example CRDs"
            echo "  create-cr       - Create example Custom Resources"
            echo "  create-operator - Create simple operator example"
            echo "  monitoring      - Create monitoring tools"
            echo "  cleanup         - Cleanup examples"
            echo "  all             - Create all examples and tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 create-crd"
            echo "  $0 monitoring"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-custom-resources-operators-toolkit.sh

# Запустить создание Custom Resources и Operators toolkit
./kubernetes-custom-resources-operators-toolkit.sh all
```

## 📋 **CRD vs Native Resources:**

### **Comparison:**

| **Aspect** | **Native Resources** | **Custom Resources** |
|------------|---------------------|---------------------|
| **Definition** | Built-in Kubernetes | User-defined via CRD |
| **API** | Core API | Custom API groups |
| **Validation** | Built-in | Custom OpenAPI schema |
| **Controllers** | Built-in | Custom controllers |

### **Operator Patterns:**

| **Pattern** | **Description** | **Use Case** |
|-------------|-----------------|--------------|
| **Basic** | Simple CRUD operations | Configuration management |
| **Advanced** | Complex lifecycle management | Database operators |
| **Framework-based** | Using Operator SDK/Kubebuilder | Production operators |

## 🎯 **Практические команды:**

### **Работа с Custom Resources:**
```bash
# Запустить Custom Resources toolkit
./kubernetes-custom-resources-operators-toolkit.sh all

# Мониторинг Custom Resources
./custom-resources-monitoring.sh monitor applications.hashfoundry.io

# Анализ операторов
./custom-resources-monitoring.sh analyze
```

### **Управление CRDs:**
```bash
# Проверить CRDs
kubectl get crd

# Описать CRD
kubectl describe crd applications.hashfoundry.io

# Получить Custom Resources
kubectl get applications.hashfoundry.io --all-namespaces
```

### **Работа с Custom Resources:**
```bash
# Создать Custom Resource
kubectl apply -f my-application.yaml

# Проверить статус
kubectl get applications
kubectl describe application my-app
```

## 🔧 **Best Practices для Custom Resources и Operators:**

### **CRD Design:**
- **Use proper versioning** - используйте правильное версионирование
- **Define comprehensive schemas** - определяйте полные схемы
- **Add validation rules** - добавляйте правила валидации
- **Include status subresources** - включайте подресурсы статуса

### **Operator Development:**
- **Follow controller patterns** - следуйте паттернам контроллеров
- **Implement proper reconciliation** - реализуйте правильное согласование
- **Handle errors gracefully** - обрабатывайте ошибки корректно
- **Use finalizers appropriately** - используйте финализаторы правильно

### **Production Considerations:**
- **Monitor operator health** - мониторьте здоровье операторов
- **Implement proper RBAC** - реализуйте правильный RBAC
- **Test thoroughly** - тщательно тестируйте
- **Document APIs** - документируйте API

**Custom Resources и Operators расширяют возможности Kubernetes для управления сложными приложениями!**
