# 73. RBAC (Role-Based Access Control) в Kubernetes

## 🎯 **RBAC (Role-Based Access Control) в Kubernetes**

**RBAC** - это система контроля доступа в Kubernetes, основанная на ролях, которая определяет, какие пользователи или сервисы могут выполнять какие действия с какими ресурсами. RBAC является основным механизмом безопасности в production-ready Kubernetes кластерах.

## 🏗️ **Основные компоненты RBAC:**

### **Ключевые объекты:**
- **Role/ClusterRole** - определяют разрешения (что можно делать)
- **RoleBinding/ClusterRoleBinding** - связывают роли с субъектами (кто может делать)
- **ServiceAccount** - идентичность для приложений
- **User/Group** - идентичность для людей

### **Принципы работы:**
- **Least Privilege** - минимальные необходимые права
- **Explicit Allow** - все запрещено по умолчанию
- **Namespace Isolation** - разделение прав по namespace
- **Audit Trail** - отслеживание действий

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей RBAC конфигурации:**
```bash
# Проверить текущие роли и привязки
kubectl get roles,rolebindings --all-namespaces
kubectl get clusterroles,clusterrolebindings

# Анализ ServiceAccounts
kubectl get serviceaccounts --all-namespaces
kubectl get serviceaccounts -n kube-system

# Проверить права текущего пользователя
kubectl auth can-i --list
kubectl auth can-i get pods
kubectl auth can-i create deployments -n kube-system

echo "=== Current RBAC Configuration in HA Cluster ==="
kubectl get clusterroles | grep -E "(admin|edit|view|system)"
kubectl get clusterrolebindings | grep -E "(admin|edit|view|system)"
```

### **2. Создание comprehensive RBAC strategy:**
```bash
# Создать скрипт для демонстрации RBAC
cat << 'EOF' > rbac-demo.sh
#!/bin/bash

echo "=== RBAC (Role-Based Access Control) Demonstration ==="
echo "Demonstrating RBAC implementation in HashFoundry HA cluster"
echo

# Функция для создания namespace-specific roles
create_namespace_roles() {
    local namespace=$1
    local environment=$2
    
    echo "=== Creating Namespace-Specific Roles for: $namespace ==="
    
    # Developer Role - может читать и создавать основные ресурсы
    cat << DEV_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: developer
  labels:
    environment: $environment
    role-type: developer
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Developer role for $namespace namespace"
    rbac.hashfoundry.io/level: "standard"
rules:
# Pods - полный доступ
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/portforward"]
  verbs: ["create"]

# Deployments, ReplicaSets - полный доступ
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Services - полный доступ
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# ConfigMaps и Secrets - ограниченный доступ
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]

# Jobs и CronJobs
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Ingress
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Events - только чтение
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
---
# Operator Role - расширенные права для операций
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: operator
  labels:
    environment: $environment
    role-type: operator
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Operator role for $namespace namespace"
    rbac.hashfoundry.io/level: "elevated"
rules:
# Все права developer плюс дополнительные
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Удаление только для определенных ресурсов
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "deployments", "services", "jobs", "cronjobs"]
  verbs: ["delete"]

# PVC и Storage
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Network Policies
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Resource Quotas и Limit Ranges - только чтение
- apiGroups: [""]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch"]
---
# ReadOnly Role - только чтение
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: readonly
  labels:
    environment: $environment
    role-type: readonly
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Read-only role for $namespace namespace"
    rbac.hashfoundry.io/level: "basic"
rules:
# Только чтение всех ресурсов
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
DEV_ROLE_EOF
    
    echo "✅ Namespace roles created for $namespace"
    echo
}

# Функция для создания cluster-wide roles
create_cluster_roles() {
    echo "=== Creating Cluster-Wide Roles ==="
    
    # Platform Admin Role
    cat << PLATFORM_ADMIN_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-platform-admin
  labels:
    role-type: platform-admin
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Platform administrator role for HashFoundry"
    rbac.hashfoundry.io/level: "admin"
rules:
# Полный доступ к namespace management
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Управление RBAC
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Управление ServiceAccounts
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Управление Resource Quotas и Limit Ranges
- apiGroups: [""]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Управление Network Policies
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Управление Storage Classes и PV
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Мониторинг и метрики
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]

# Nodes - только чтение
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
---
# Security Auditor Role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-security-auditor
  labels:
    role-type: security-auditor
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Security auditor role for compliance and security reviews"
    rbac.hashfoundry.io/level: "auditor"
rules:
# Чтение всех ресурсов для аудита
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]

# Доступ к логам и событиям
- apiGroups: [""]
  resources: ["events", "pods/log"]
  verbs: ["get", "list", "watch"]

# Доступ к RBAC конфигурации
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]

# Доступ к security policies
- apiGroups: ["policy"]
  resources: ["podsecuritypolicies"]
  verbs: ["get", "list", "watch"]
---
# Monitoring Role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-monitoring
  labels:
    role-type: monitoring
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Monitoring role for observability tools"
    rbac.hashfoundry.io/level: "monitoring"
rules:
# Метрики и мониторинг
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "nodes/stats", "nodes/proxy"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods", "services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]

# Доступ к событиям и логам
- apiGroups: [""]
  resources: ["events", "pods/log"]
  verbs: ["get", "list", "watch"]

# Namespace и resource quotas
- apiGroups: [""]
  resources: ["namespaces", "resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch"]
PLATFORM_ADMIN_EOF
    
    echo "✅ Cluster-wide roles created"
    echo
}

# Функция для создания ServiceAccounts
create_service_accounts() {
    local namespace=$1
    local environment=$2
    
    echo "=== Creating ServiceAccounts for: $namespace ==="
    
    # Application ServiceAccount
    cat << SA_EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hashfoundry-app
  namespace: $namespace
  labels:
    environment: $environment
    account-type: application
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "ServiceAccount for HashFoundry applications"
    rbac.hashfoundry.io/purpose: "application-runtime"
automountServiceAccountToken: true
---
# Deployment ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hashfoundry-deployer
  namespace: $namespace
  labels:
    environment: $environment
    account-type: deployment
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "ServiceAccount for deployment operations"
    rbac.hashfoundry.io/purpose: "deployment"
automountServiceAccountToken: true
---
# Monitoring ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hashfoundry-monitor
  namespace: $namespace
  labels:
    environment: $environment
    account-type: monitoring
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "ServiceAccount for monitoring and observability"
    rbac.hashfoundry.io/purpose: "monitoring"
automountServiceAccountToken: true
SA_EOF
    
    echo "✅ ServiceAccounts created for $namespace"
    echo
}

# Функция для создания RoleBindings
create_role_bindings() {
    local namespace=$1
    local environment=$2
    
    echo "=== Creating RoleBindings for: $namespace ==="
    
    # Bind roles to ServiceAccounts
    cat << RB_EOF | kubectl apply -f -
# Bind developer role to deployer ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: hashfoundry-deployer-binding
  namespace: $namespace
  labels:
    environment: $environment
    binding-type: service-account
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Bind developer role to deployer ServiceAccount"
subjects:
- kind: ServiceAccount
  name: hashfoundry-deployer
  namespace: $namespace
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
---
# Bind readonly role to app ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: hashfoundry-app-binding
  namespace: $namespace
  labels:
    environment: $environment
    binding-type: service-account
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Bind readonly role to app ServiceAccount"
subjects:
- kind: ServiceAccount
  name: hashfoundry-app
  namespace: $namespace
roleRef:
  kind: Role
  name: readonly
  apiGroup: rbac.authorization.k8s.io
---
# Bind monitoring cluster role to monitor ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hashfoundry-monitor-binding-$namespace
  labels:
    environment: $environment
    binding-type: cluster-service-account
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Bind monitoring cluster role to monitor ServiceAccount"
subjects:
- kind: ServiceAccount
  name: hashfoundry-monitor
  namespace: $namespace
roleRef:
  kind: ClusterRole
  name: hashfoundry-monitoring
  apiGroup: rbac.authorization.k8s.io
RB_EOF
    
    echo "✅ RoleBindings created for $namespace"
    echo
}

# Функция для создания demo applications с RBAC
create_rbac_demo_applications() {
    local namespace=$1
    local environment=$2
    
    echo "=== Creating Demo Applications with RBAC for: $namespace ==="
    
    # Application с ограниченными правами
    cat << APP_EOF | kubectl apply -f -
# Application Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rbac-demo-app
  namespace: $namespace
  labels:
    app: rbac-demo
    component: application
    environment: $environment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rbac-demo
      component: application
  template:
    metadata:
      labels:
        app: rbac-demo
        component: application
        environment: $environment
    spec:
      serviceAccountName: hashfoundry-app
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: app
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
          value: "$environment"
        - name: SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: app-config
          mountPath: /etc/nginx/conf.d
        - name: service-account-token
          mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          readOnly: true
      volumes:
      - name: app-config
        configMap:
          name: rbac-demo-config
      - name: service-account-token
        projected:
          sources:
          - serviceAccountToken:
              path: token
              expirationSeconds: 3600
---
# Deployment Job с расширенными правами
apiVersion: batch/v1
kind: Job
metadata:
  name: rbac-demo-deployer
  namespace: $namespace
  labels:
    app: rbac-demo
    component: deployer
    environment: $environment
spec:
  template:
    metadata:
      labels:
        app: rbac-demo
        component: deployer
        environment: $environment
    spec:
      serviceAccountName: hashfoundry-deployer
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: deployer
        image: bitnami/kubectl:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "=== RBAC Demo Deployer ==="
          echo "ServiceAccount: \$(cat /var/run/secrets/kubernetes.io/serviceaccount/serviceaccount)"
          echo "Namespace: $namespace"
          echo
          
          echo "Testing RBAC permissions..."
          
          # Тестировать разрешенные операции
          echo "✓ Testing allowed operations:"
          kubectl get pods -n $namespace || echo "❌ Cannot get pods"
          kubectl get services -n $namespace || echo "❌ Cannot get services"
          kubectl get deployments -n $namespace || echo "❌ Cannot get deployments"
          
          # Тестировать запрещенные операции
          echo "✗ Testing forbidden operations:"
          kubectl get nodes 2>/dev/null && echo "❌ Should not access nodes" || echo "✓ Correctly denied access to nodes"
          kubectl get secrets -n kube-system 2>/dev/null && echo "❌ Should not access kube-system secrets" || echo "✓ Correctly denied access to kube-system"
          kubectl delete namespace default 2>/dev/null && echo "❌ Should not delete namespaces" || echo "✓ Correctly denied namespace deletion"
          
          echo "RBAC test completed!"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      restartPolicy: Never
---
# ConfigMap для приложения
apiVersion: v1
kind: ConfigMap
metadata:
  name: rbac-demo-config
  namespace: $namespace
  labels:
    app: rbac-demo
    component: config
    environment: $environment
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /rbac-info {
            access_log off;
            return 200 "RBAC Demo App - Environment: $environment, Namespace: $namespace\n";
            add_header Content-Type text/plain;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
APP_EOF
    
    echo "✅ Demo applications with RBAC created for $namespace"
    echo
}

# Функция для тестирования RBAC permissions
test_rbac_permissions() {
    echo "=== Testing RBAC Permissions ==="
    
    echo "Testing current user permissions:"
    echo "================================"
    
    # Тестировать различные операции
    operations=(
        "get pods"
        "create pods"
        "delete pods"
        "get nodes"
        "create namespaces"
        "get secrets -n kube-system"
        "create clusterroles"
        "get resourcequotas --all-namespaces"
    )
    
    for op in "${operations[@]}"; do
        if kubectl auth can-i $op >/dev/null 2>&1; then
            echo "✅ Allowed: kubectl $op"
        else
            echo "❌ Denied:  kubectl $op"
        fi
    done
    
    echo
    echo "Testing ServiceAccount permissions:"
    echo "=================================="
    
    # Тестировать права ServiceAccounts в разных namespace
    for ns in hashfoundry-dev hashfoundry-prod hashfoundry-test; do
        if kubectl get namespace $ns >/dev/null 2>&1; then
            echo "Namespace: $ns"
            
            # Проверить ServiceAccounts
            sas=$(kubectl get serviceaccounts -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
            for sa in $sas; do
                if [[ $sa == hashfoundry-* ]]; then
                    echo "  ServiceAccount: $sa"
                    
                    # Проверить основные права
                    kubectl auth can-i get pods --as=system:serviceaccount:$ns:$sa -n $ns >/dev/null 2>&1 && echo "    ✅ Can get pods" || echo "    ❌ Cannot get pods"
                    kubectl auth can-i create deployments --as=system:serviceaccount:$ns:$sa -n $ns >/dev/null 2>&1 && echo "    ✅ Can create deployments" || echo "    ❌ Cannot create deployments"
                    kubectl auth can-i delete secrets --as=system:serviceaccount:$ns:$sa -n $ns >/dev/null 2>&1 && echo "    ⚠️  Can delete secrets" || echo "    ✅ Cannot delete secrets"
                fi
            done
            echo
        fi
    done
}

# Функция для создания RBAC monitoring
create_rbac_monitoring() {
    echo "=== Creating RBAC Monitoring ==="
    
    # RBAC Audit CronJob
    cat << AUDIT_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rbac-audit
  namespace: kube-system
  labels:
    app: rbac-audit
    component: security
spec:
  schedule: "0 */6 * * *"  # Каждые 6 часов
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: rbac-audit
            component: security
        spec:
          serviceAccountName: rbac-auditor
          containers:
          - name: auditor
            image: bitnami/kubectl:latest
            command: ["sh", "-c"]
            args:
            - |
              echo "=== RBAC Audit Report ==="
              echo "Generated: \$(date)"
              echo
              
              echo "Cluster Roles Summary:"
              kubectl get clusterroles | grep -E "(hashfoundry|admin|edit|view)" | wc -l | xargs echo "Custom roles count:"
              
              echo "Role Bindings Summary:"
              kubectl get rolebindings --all-namespaces | grep hashfoundry | wc -l | xargs echo "HashFoundry role bindings:"
              
              echo "ServiceAccounts Summary:"
              kubectl get serviceaccounts --all-namespaces | grep hashfoundry | wc -l | xargs echo "HashFoundry service accounts:"
              
              echo "Privileged Bindings Check:"
              kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name' | head -5
              
              echo "Namespace RBAC Coverage:"
              for ns in \$(kubectl get namespaces -l app.kubernetes.io/name=hashfoundry -o jsonpath='{.items[*].metadata.name}'); do
                  role_count=\$(kubectl get roles -n \$ns 2>/dev/null | wc -l)
                  binding_count=\$(kubectl get rolebindings -n \$ns 2>/dev/null | wc -l)
                  echo "  \$ns: \$role_count roles, \$binding_count bindings"
              done
              
              echo "RBAC audit completed at \$(date)"
            resources:
              requests:
                memory: "64Mi"
                cpu: "50m"
              limits:
                memory: "128Mi"
                cpu: "100m"
          restartPolicy: OnFailure
---
# ServiceAccount для RBAC auditing
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbac-auditor
  namespace: kube-system
  labels:
    app: rbac-audit
    component: security
---
# ClusterRoleBinding для auditor
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: rbac-auditor-binding
  labels:
    app: rbac-audit
    component: security
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: hashfoundry-security-auditor
subjects:
- kind: ServiceAccount
  name: rbac-auditor
  namespace: kube-system
AUDIT_EOF
    
    echo "✅ RBAC monitoring created"
    echo
}

# Основная функция для демонстрации всех RBAC возможностей
demonstrate_all_rbac() {
    echo "=== Full RBAC Demonstration ==="
    
    # Создать роли и привязки для разных сред
    environments=("development:hashfoundry-dev" "production:hashfoundry-prod" "testing:hashfoundry-test")
    
    # Создать cluster-wide роли
    create_cluster_roles
    
    for env_ns in "${environments[@]}"; do
        IFS=':' read -r environment namespace <<< "$env_ns"
        
        # Создать namespace если не существует
        kubectl create namespace $namespace 2>/dev/null || echo "Namespace $namespace already exists"
        kubectl label namespace $namespace app.kubernetes.io/name=hashfoundry environment=$environment 2>/dev/null || true
        
        create_namespace_roles $namespace $environment
        create_service_accounts $namespace $environment
        create_role_bindings $namespace $environment
        create_rbac_demo_applications $namespace $environment
    done
    
    create_rbac_monitoring
    
    sleep 30  # Дать время для создания ресурсов
    
    test_rbac_permissions
    
    echo "=== RBAC Implementation Summary ==="
    echo "✅ Cluster-wide roles created"
    echo "✅ Namespace-specific roles created"
    echo "✅ ServiceAccounts configured"
    echo "✅ RoleBindings established"
    echo "✅ Demo applications deployed"
    echo "✅ RBAC monitoring configured"
    echo
    
    echo "=== Current RBAC Overview ==="
    kubectl get clusterroles | grep hashfoundry
    kubectl get roles --all-namespaces | grep hashfoundry
    kubectl get serviceaccounts --all-namespaces | grep hashfoundry
}

# Основная функция
main() {
    case "$1" in
        "cluster-roles")
            create_cluster_roles
            ;;
        "namespace-roles")
            create_namespace_roles "${2:-hashfoundry-dev}" "${3:-development}"
            ;;
        "service-accounts")
            create_service_accounts "${2:-hashfoundry-dev}" "${3:-development}"
            ;;
        "bindings")
            create_role_bindings "${2:-hashfoundry-dev}" "${3:-development}"
            ;;
        "demo-apps")
            create_rbac_demo_applications "${2:-hashfoundry-dev}" "${3:-development}"
            ;;
        "test")
            test_rbac_permissions
            ;;
        "monitoring")
            create_rbac_monitoring
            ;;
        "all"|"")
            demonstrate_all_rbac
            ;;
        *)
            echo "Usage: $0 [action] [namespace] [environment]"
            echo ""
            echo "Actions:"
            echo "  cluster-roles    - Create cluster-wide roles"
            echo "  namespace-roles  - Create namespace-specific roles"
            echo "  service-accounts - Create ServiceAccounts"
            echo "  bindings         - Create RoleBindings"
            echo "  demo-apps        - Create demo applications"
            echo "  test             - Test RBAC permissions"
            echo "  monitoring       - Create RBAC monitoring"
            echo "  all              - Full demonstration (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 test"
            echo "  $0 namespace-roles hashfoundry-prod production"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x rbac-demo.sh

# Запустить демонстрацию
./rbac-demo.sh all
```

## 📋 **Основные компоненты RBAC:**

### **1. Role (Роль в namespace):**
```bash
# Роль для разработчиков
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

### **2. ClusterRole (Роль на уровне кластера):**
```bash
# Cluster-wide роль для мониторинга
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
rules:
- apiGroups: [""]
  resources: ["nodes", "pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
```

### **3. RoleBinding (Привязка роли в namespace):**
```bash
# Привязка роли к пользователю
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
- kind: User
  name: john.doe
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: app-deployer
  namespace: development
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

### **4. ClusterRoleBinding (Cluster-wide привязка):**
```bash
# Cluster-wide привязка роли
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-binding
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: monitoring-reader
  apiGroup: rbac.authorization.k8s.io
```

## 🎯 **Практические команды:**

### **Управление RBAC:**
```bash
# Создание ролей
kubectl create role developer --verb=get,list,watch,create,update,patch,delete --resource=pods,services
kubectl create clusterrole monitoring --verb=get,list,watch --resource=nodes,pods

# Создание привязок
kubectl create rolebinding developer-binding --role=developer --user=john.doe
kubectl create clusterrolebinding monitoring-binding --clusterrole=monitoring --serviceaccount=monitoring:prometheus

# Просмотр RBAC
kubectl get roles,rolebindings --all-namespaces
kubectl get clusterroles,clusterrolebindings
```

### **Тестирование прав:**
```bash
# Проверка прав текущего пользователя
kubectl auth can-i get pods
kubectl auth can-i create deployments -n production
kubectl auth can-i delete nodes

# Проверка прав ServiceAccount
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
kubectl auth can-i create secrets --as=system:serviceaccount:kube-system:default

# Список всех разрешений
kubectl auth can-i --list
kubectl auth can-i --list -n production
```

### **Управление ServiceAccounts:**
```bash
# Создание ServiceAccount
kubectl create serviceaccount my-app
kubectl create serviceaccount deployer -n production

# Просмотр ServiceAccounts
kubectl get serviceaccounts --all-namespaces
kubectl describe serviceaccount my-app

# Получение токена ServiceAccount
kubectl get secret $(kubectl get serviceaccount my-app -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d
```

## 🔧 **Best Practices для RBAC:**

### **Принцип минимальных привилегий:**
- **Предоставлять только необходимые права**
- **Использовать namespace-specific роли где возможно**
- **Избегать cluster-admin для обычных задач**
- **Регулярно аудировать права доступа**

### **Организация ролей:**
- **Создавать роли по функциям, а не по пользователям**
- **Использовать понятные имена ролей**
- **Документировать назначение каждой роли**
- **Группировать похожие права в одной роли**

### **ServiceAccounts:**
- **Создавать отдельные ServiceAccounts для каждого приложения**
- **Не использовать default ServiceAccount в production**
- **Ограничивать automountServiceAccountToken где не нужно**
- **Регулярно ротировать токены**

### **Мониторинг и аудит:**
- **Включить audit logging для RBAC событий**
- **Мониторить неудачные попытки доступа**
- **Регулярно проверять привязки ролей**
- **Автоматизировать проверки compliance**

**RBAC обеспечивает безопасный и контролируемый доступ к ресурсам Kubernetes!**
