# 71. Multiple Namespaces в Kubernetes

## 🎯 **Multiple Namespaces в Kubernetes**

**Multiple Namespaces** - это стратегия организации ресурсов в Kubernetes кластере с использованием нескольких изолированных пространств имен. Правильное использование namespaces критически важно для безопасности, организации и управления ресурсами в production-ready кластерах.

## 🏗️ **Основные сценарии использования:**

### **Категории применения:**
- **Environment Separation** - разделение сред (dev, staging, prod)
- **Team Isolation** - изоляция команд и проектов
- **Application Boundaries** - границы приложений
- **Security Zones** - зоны безопасности
- **Resource Management** - управление ресурсами

### **Ключевые преимущества:**
- **Isolation** - изоляция ресурсов и конфигураций
- **Security** - контроль доступа и политики безопасности
- **Organization** - логическая организация ресурсов
- **Resource Control** - квоты и лимиты ресурсов

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих namespaces в HA кластере:**
```bash
# Проверить существующие namespaces
kubectl get namespaces -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp,LABELS:.metadata.labels"

# Проверить ресурсы в каждом namespace
echo "=== Current Namespace Usage in HA Cluster ==="
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
    echo "Namespace: $ns"
    echo "  Pods: $(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)"
    echo "  Services: $(kubectl get services -n $ns --no-headers 2>/dev/null | wc -l)"
    echo "  ConfigMaps: $(kubectl get configmaps -n $ns --no-headers 2>/dev/null | wc -l)"
    echo "  Secrets: $(kubectl get secrets -n $ns --no-headers 2>/dev/null | wc -l)"
    echo
done

# Проверить resource quotas по namespaces
kubectl get resourcequota --all-namespaces
```

### **2. Создание comprehensive namespace strategy:**
```bash
# Создать скрипт для демонстрации namespace strategies
cat << 'EOF' > namespace-strategies-demo.sh
#!/bin/bash

echo "=== Multiple Namespaces Strategy Demonstration ==="
echo "Demonstrating different namespace usage patterns"
echo

# Функция для создания environment-based namespaces
create_environment_namespaces() {
    echo "=== Creating Environment-Based Namespaces ==="
    
    # Development namespace
    cat << DEV_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-development
  labels:
    environment: development
    tier: non-production
    team: platform
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: environment
  annotations:
    description: "Development environment for HashFoundry applications"
    contact: "dev-team@hashfoundry.io"
    cost-center: "engineering"
    backup-policy: "none"
    monitoring-level: "basic"
---
# Staging namespace
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-staging
  labels:
    environment: staging
    tier: pre-production
    team: platform
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: environment
  annotations:
    description: "Staging environment for HashFoundry applications"
    contact: "qa-team@hashfoundry.io"
    cost-center: "engineering"
    backup-policy: "weekly"
    monitoring-level: "standard"
---
# Production namespace
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-production
  labels:
    environment: production
    tier: production
    team: platform
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: environment
  annotations:
    description: "Production environment for HashFoundry applications"
    contact: "ops-team@hashfoundry.io"
    cost-center: "operations"
    backup-policy: "daily"
    monitoring-level: "comprehensive"
DEV_EOF
    
    echo "✅ Environment-based namespaces created"
    echo
}

# Функция для создания team-based namespaces
create_team_namespaces() {
    echo "=== Creating Team-Based Namespaces ==="
    
    # Frontend team namespace
    cat << FRONTEND_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: team-frontend
  labels:
    team: frontend
    department: engineering
    access-level: standard
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: team-workspace
  annotations:
    description: "Frontend team workspace"
    team-lead: "frontend-lead@hashfoundry.io"
    slack-channel: "#frontend-team"
    cost-center: "frontend-engineering"
    resource-budget: "medium"
---
# Backend team namespace
apiVersion: v1
kind: Namespace
metadata:
  name: team-backend
  labels:
    team: backend
    department: engineering
    access-level: standard
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: team-workspace
  annotations:
    description: "Backend team workspace"
    team-lead: "backend-lead@hashfoundry.io"
    slack-channel: "#backend-team"
    cost-center: "backend-engineering"
    resource-budget: "high"
---
# DevOps team namespace
apiVersion: v1
kind: Namespace
metadata:
  name: team-devops
  labels:
    team: devops
    department: operations
    access-level: elevated
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: team-workspace
  annotations:
    description: "DevOps team workspace for infrastructure tools"
    team-lead: "devops-lead@hashfoundry.io"
    slack-channel: "#devops-team"
    cost-center: "infrastructure"
    resource-budget: "high"
FRONTEND_EOF
    
    echo "✅ Team-based namespaces created"
    echo
}

# Функция для создания application-based namespaces
create_application_namespaces() {
    echo "=== Creating Application-Based Namespaces ==="
    
    # Web application namespace
    cat << WEB_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-web
  labels:
    application: web-frontend
    component: user-interface
    tier: frontend
    app.kubernetes.io/name: hashfoundry-web
    app.kubernetes.io/component: application
  annotations:
    description: "HashFoundry web frontend application"
    repository: "https://github.com/hashfoundry/web-frontend"
    documentation: "https://docs.hashfoundry.io/web"
    owner: "frontend-team"
    sla: "99.9%"
---
# API namespace
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-api
  labels:
    application: api-backend
    component: api-server
    tier: backend
    app.kubernetes.io/name: hashfoundry-api
    app.kubernetes.io/component: application
  annotations:
    description: "HashFoundry API backend services"
    repository: "https://github.com/hashfoundry/api-backend"
    documentation: "https://docs.hashfoundry.io/api"
    owner: "backend-team"
    sla: "99.95%"
---
# Database namespace
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-database
  labels:
    application: database
    component: data-layer
    tier: data
    app.kubernetes.io/name: hashfoundry-database
    app.kubernetes.io/component: application
  annotations:
    description: "HashFoundry database and data services"
    repository: "https://github.com/hashfoundry/database-configs"
    documentation: "https://docs.hashfoundry.io/database"
    owner: "backend-team"
    sla: "99.99%"
WEB_EOF
    
    echo "✅ Application-based namespaces created"
    echo
}

# Функция для создания security zone namespaces
create_security_zone_namespaces() {
    echo "=== Creating Security Zone Namespaces ==="
    
    # Public zone namespace
    cat << SECURITY_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: security-zone-public
  labels:
    security-zone: public
    access-level: public
    network-policy: permissive
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: security-zone
  annotations:
    description: "Public security zone for internet-facing services"
    security-contact: "security@hashfoundry.io"
    compliance-level: "standard"
    audit-logging: "enabled"
    network-restrictions: "minimal"
---
# Internal zone namespace
apiVersion: v1
kind: Namespace
metadata:
  name: security-zone-internal
  labels:
    security-zone: internal
    access-level: internal
    network-policy: restricted
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: security-zone
  annotations:
    description: "Internal security zone for internal services"
    security-contact: "security@hashfoundry.io"
    compliance-level: "enhanced"
    audit-logging: "enabled"
    network-restrictions: "moderate"
---
# Secure zone namespace
apiVersion: v1
kind: Namespace
metadata:
  name: security-zone-secure
  labels:
    security-zone: secure
    access-level: restricted
    network-policy: strict
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: security-zone
  annotations:
    description: "Secure zone for sensitive data and critical services"
    security-contact: "security@hashfoundry.io"
    compliance-level: "strict"
    audit-logging: "comprehensive"
    network-restrictions: "strict"
SECURITY_EOF
    
    echo "✅ Security zone namespaces created"
    echo
}

# Функция для создания shared services namespaces
create_shared_services_namespaces() {
    echo "=== Creating Shared Services Namespaces ==="
    
    # Monitoring namespace
    cat << SHARED_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: shared-monitoring
  labels:
    service-type: shared
    category: monitoring
    access-level: cluster-wide
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: shared-service
  annotations:
    description: "Shared monitoring and observability services"
    service-owner: "platform-team"
    consumers: "all-teams"
    sla: "99.9%"
    cost-model: "shared"
---
# Logging namespace
apiVersion: v1
kind: Namespace
metadata:
  name: shared-logging
  labels:
    service-type: shared
    category: logging
    access-level: cluster-wide
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: shared-service
  annotations:
    description: "Shared logging and log aggregation services"
    service-owner: "platform-team"
    consumers: "all-teams"
    sla: "99.9%"
    cost-model: "shared"
---
# Security namespace
apiVersion: v1
kind: Namespace
metadata:
  name: shared-security
  labels:
    service-type: shared
    category: security
    access-level: cluster-wide
    app.kubernetes.io/name: hashfoundry
    app.kubernetes.io/component: shared-service
  annotations:
    description: "Shared security services and tools"
    service-owner: "security-team"
    consumers: "all-teams"
    sla: "99.95%"
    cost-model: "shared"
SHARED_EOF
    
    echo "✅ Shared services namespaces created"
    echo
}

# Функция для создания resource quotas для namespaces
create_namespace_resource_quotas() {
    echo "=== Creating Resource Quotas for Namespaces ==="
    
    # Development environment quota (generous for experimentation)
    cat << DEV_QUOTA_EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: hashfoundry-development
  labels:
    environment: development
    quota-type: generous
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    requests.storage: "100Gi"
    persistentvolumeclaims: "20"
    pods: "50"
    services: "20"
    secrets: "50"
    configmaps: "50"
---
# Staging environment quota (moderate)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: hashfoundry-staging
  labels:
    environment: staging
    quota-type: moderate
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    requests.storage: "200Gi"
    persistentvolumeclaims: "15"
    pods: "30"
    services: "15"
    secrets: "30"
    configmaps: "30"
---
# Production environment quota (controlled)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: hashfoundry-production
  labels:
    environment: production
    quota-type: controlled
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    requests.storage: "500Gi"
    persistentvolumeclaims: "25"
    pods: "100"
    services: "30"
    secrets: "100"
    configmaps: "100"
DEV_QUOTA_EOF
    
    # Team quotas
    cat << TEAM_QUOTA_EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: frontend-team-quota
  namespace: team-frontend
  labels:
    team: frontend
    quota-type: team-based
spec:
  hard:
    requests.cpu: "5"
    requests.memory: 10Gi
    limits.cpu: "10"
    limits.memory: 20Gi
    requests.storage: "50Gi"
    persistentvolumeclaims: "10"
    pods: "25"
    services: "10"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: backend-team-quota
  namespace: team-backend
  labels:
    team: backend
    quota-type: team-based
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    requests.storage: "100Gi"
    persistentvolumeclaims: "15"
    pods: "40"
    services: "15"
TEAM_QUOTA_EOF
    
    echo "✅ Resource quotas created for namespaces"
    echo
}

# Функция для создания network policies для namespace isolation
create_namespace_network_policies() {
    echo "=== Creating Network Policies for Namespace Isolation ==="
    
    # Production namespace isolation
    cat << PROD_NP_EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: production-isolation
  namespace: hashfoundry-production
  labels:
    environment: production
    policy-type: isolation
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: staging
    - namespaceSelector:
        matchLabels:
          service-type: shared
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          service-type: shared
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
---
# Secure zone strict policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secure-zone-strict
  namespace: security-zone-secure
  labels:
    security-zone: secure
    policy-type: strict
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          security-zone: internal
    - podSelector:
        matchLabels:
          access-level: authorized
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          service-type: shared
          category: logging
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
PROD_NP_EOF
    
    echo "✅ Network policies created for namespace isolation"
    echo
}

# Функция для демонстрации namespace management
demonstrate_namespace_management() {
    echo "=== Demonstrating Namespace Management ==="
    
    # Создать демонстрационные приложения в разных namespaces
    cat << DEMO_APPS_EOF | kubectl apply -f -
# Development app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-dev
  namespace: hashfoundry-development
  labels:
    app: web-app
    environment: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
      environment: development
  template:
    metadata:
      labels:
        app: web-app
        environment: development
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        env:
        - name: ENVIRONMENT
          value: "development"
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
---
# Staging app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-staging
  namespace: hashfoundry-staging
  labels:
    app: web-app
    environment: staging
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
      environment: staging
  template:
    metadata:
      labels:
        app: web-app
        environment: staging
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "400m"
        env:
        - name: ENVIRONMENT
          value: "staging"
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
---
# Production app
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-production
  namespace: hashfoundry-production
  labels:
    app: web-app
    environment: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
      environment: production
  template:
    metadata:
      labels:
        app: web-app
        environment: production
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
DEMO_APPS_EOF
    
    echo "✅ Demo applications deployed across namespaces"
    echo
}

# Функция для анализа namespace usage
analyze_namespace_usage() {
    echo "=== Analyzing Namespace Usage ==="
    
    echo "Namespace Resource Usage:"
    echo "========================"
    
    for ns in $(kubectl get namespaces -l app.kubernetes.io/name=hashfoundry -o jsonpath='{.items[*].metadata.name}'); do
        echo "Namespace: $ns"
        echo "  Labels: $(kubectl get namespace $ns -o jsonpath='{.metadata.labels}' | tr ',' '\n' | head -3)"
        echo "  Pods: $(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)"
        echo "  CPU Requests: $(kubectl top pods -n $ns --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum "m"}' || echo "N/A")"
        echo "  Memory Requests: $(kubectl top pods -n $ns --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum "Mi"}' || echo "N/A")"
        
        # Проверить resource quota usage
        quota_info=$(kubectl get resourcequota -n $ns --no-headers 2>/dev/null | head -1)
        if [ -n "$quota_info" ]; then
            echo "  Resource Quota: Active"
        else
            echo "  Resource Quota: None"
        fi
        
        echo
    done
}

# Основная функция для демонстрации всех namespace strategies
demonstrate_all_strategies() {
    echo "=== Full Namespace Strategies Demonstration ==="
    
    create_environment_namespaces
    create_team_namespaces
    create_application_namespaces
    create_security_zone_namespaces
    create_shared_services_namespaces
    create_namespace_resource_quotas
    create_namespace_network_policies
    demonstrate_namespace_management
    
    sleep 30  # Дать время для создания ресурсов
    
    analyze_namespace_usage
    
    echo "=== Namespace Strategies Summary ==="
    echo "✅ Environment-based namespaces created"
    echo "✅ Team-based namespaces created"
    echo "✅ Application-based namespaces created"
    echo "✅ Security zone namespaces created"
    echo "✅ Shared services namespaces created"
    echo "✅ Resource quotas implemented"
    echo "✅ Network policies configured"
    echo "✅ Demo applications deployed"
    echo
    
    echo "=== Current Namespace Overview ==="
    kubectl get namespaces -l app.kubernetes.io/name=hashfoundry -o custom-columns="NAME:.metadata.name,LABELS:.metadata.labels.environment,.metadata.labels.team,.metadata.labels.security-zone"
}

# Основная функция
main() {
    case "$1" in
        "environment")
            create_environment_namespaces
            ;;
        "teams")
            create_team_namespaces
            ;;
        "applications")
            create_application_namespaces
            ;;
        "security")
            create_security_zone_namespaces
            ;;
        "shared")
            create_shared_services_namespaces
            ;;
        "quotas")
            create_namespace_resource_quotas
            ;;
        "network")
            create_namespace_network_policies
            ;;
        "demo")
            demonstrate_namespace_management
            ;;
        "analyze")
            analyze_namespace_usage
            ;;
        "all"|"")
            demonstrate_all_strategies
            ;;
        *)
            echo "Usage: $0 [strategy]"
            echo ""
            echo "Strategies:"
            echo "  environment   - Create environment-based namespaces"
            echo "  teams         - Create team-based namespaces"
            echo "  applications  - Create application-based namespaces"
            echo "  security      - Create security zone namespaces"
            echo "  shared        - Create shared services namespaces"
            echo "  quotas        - Create resource quotas"
            echo "  network       - Create network policies"
            echo "  demo          - Deploy demo applications"
            echo "  analyze       - Analyze namespace usage"
            echo "  all           - Full demonstration (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 environment"
            echo "  $0 analyze"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x namespace-strategies-demo.sh

# Запустить демонстрацию
./namespace-strategies-demo.sh all
```

## 📋 **Когда использовать Multiple Namespaces:**

### **1. Environment Separation (Обязательно):**
```bash
# Разделение сред разработки
kubectl create namespace development
kubectl create namespace staging  
kubectl create namespace production

# Проверка изоляции между средами
kubectl get pods -n development
kubectl get pods -n production
```

### **2. Team Isolation (Рекомендуется):**
```bash
# Изоляция команд
kubectl create namespace team-frontend
kubectl create namespace team-backend
kubectl create namespace team-devops

# Назначение ресурсов командам
kubectl label namespace team-frontend team=frontend
kubectl label namespace team-backend team=backend
```

### **3. Application Boundaries (По необходимости):**
```bash
# Разделение приложений
kubectl create namespace app-web
kubectl create namespace app-api
kubectl create namespace app-database

# Логическое разделение компонентов
kubectl get services -n app-web
kubectl get services -n app-api
```

### **4. Security Zones (Критично для production):**
```bash
# Зоны безопасности
kubectl create namespace security-public
kubectl create namespace security-internal
kubectl create namespace security-restricted

# Применение security policies
kubectl label namespace security-restricted security-level=high
```

## 🎯 **Best Practices для Multiple Namespaces:**

### **Naming Conventions:**
```bash
# Consistent naming patterns
<organization>-<environment>     # hashfoundry-production
<team>-<component>              # frontend-web
<application>-<tier>            # myapp-database
<security-zone>-<level>         # secure-zone-high
```

### **Labeling Strategy:**
```bash
# Standard labels для всех namespaces
kubectl label namespace <namespace> \
  environment=<env> \
  team=<team> \
  application=<app> \
  security-level=<level>
```

### **Resource Management:**
```bash
# Resource quotas для каждого namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: <namespace>
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
```

## 📊 **Практические команды:**

### **Управление namespaces:**
```bash
# Создание и управление
kubectl create namespace <name>
kubectl delete namespace <name>
kubectl get namespaces --show-labels

# Работа с ресурсами в namespace
kubectl get all -n <namespace>
kubectl describe namespace <namespace>

# Переключение default namespace
kubectl config set-context --current --namespace=<namespace>
```

### **Мониторинг использования:**
```bash
# Анализ ресурсов по namespaces
kubectl top pods --all-namespaces
kubectl get resourcequota --all-namespaces
kubectl get networkpolicy --all-namespaces

# Проверка изоляции
kubectl auth can-i get pods -n <namespace>
```

**Multiple Namespaces обеспечивают организацию, безопасность и эффективное управление ресурсами в Kubernetes!**
