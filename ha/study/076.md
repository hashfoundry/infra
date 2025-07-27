# 76. Создание пользовательских RBAC политик в Kubernetes

## 🎯 **Создание пользовательских RBAC политик в Kubernetes**

**Custom RBAC policies** - это специально разработанные роли и привязки, которые точно соответствуют требованиям безопасности и функциональности вашей организации. Создание пользовательских RBAC политик позволяет реализовать принцип минимальных привилегий и обеспечить гранулярный контроль доступа.

## 🏗️ **Основные принципы создания RBAC политик:**

### **Этапы разработки:**
- **Анализ требований** - определение ролей и обязанностей
- **Проектирование ролей** - создание иерархии прав доступа
- **Реализация политик** - написание YAML манифестов
- **Тестирование** - проверка корректности работы
- **Мониторинг** - отслеживание использования и безопасности

### **Компоненты пользовательских политик:**
- **Custom Roles** - роли для конкретных задач
- **Custom ClusterRoles** - кластерные роли для системных операций
- **Targeted RoleBindings** - точечные привязки ролей
- **Policy Templates** - шаблоны для повторного использования

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих RBAC политик:**
```bash
# Проверить существующие пользовательские роли
kubectl get roles --all-namespaces | grep -v system
kubectl get clusterroles | grep -v system

# Анализ привязок ролей
echo "=== Custom RBAC Policies Analysis in HA Cluster ==="
kubectl get rolebindings --all-namespaces -o wide
kubectl get clusterrolebindings -o wide

# Проверить права текущего пользователя
kubectl auth can-i --list
kubectl auth can-i create customresourcedefinitions
```

### **2. Создание comprehensive custom RBAC framework:**
```bash
# Создать скрипт для создания пользовательских RBAC политик
cat << 'EOF' > custom-rbac-policies.sh
#!/bin/bash

echo "=== Custom RBAC Policies Creation ==="
echo "Creating comprehensive RBAC framework for HashFoundry HA cluster"
echo

# Функция для создания organizational roles
create_organizational_roles() {
    echo "=== Creating Organizational Roles ==="
    
    # Developer Role - для разработчиков
    cat << DEV_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-developer
  labels:
    rbac.hashfoundry.io/role-type: organizational
    rbac.hashfoundry.io/level: developer
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Developer role with development namespace access"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "development-workflow"
rules:
# Development namespace resources
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "pods/portforward"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services", "endpoints", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# Limited secret access
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["dev-*", "app-*"]
# Events for debugging
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch", "create"]
# Metrics access
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
---
# DevOps Engineer Role - для DevOps инженеров
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-devops
  labels:
    rbac.hashfoundry.io/role-type: organizational
    rbac.hashfoundry.io/level: devops
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "DevOps role with deployment and infrastructure access"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "deployment-operations"
rules:
# Full access to application resources
- apiGroups: ["", "apps", "batch", "networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Infrastructure resources
- apiGroups: [""]
  resources: ["nodes", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "volumeattachments"]
  verbs: ["get", "list", "watch"]
# Monitoring and metrics
- apiGroups: ["metrics.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list"]
# Custom resources for operators
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list", "watch"]
# ArgoCD resources
- apiGroups: ["argoproj.io"]
  resources: ["applications", "appprojects"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Security Auditor Role - для аудиторов безопасности
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-security-auditor
  labels:
    rbac.hashfoundry.io/role-type: organizational
    rbac.hashfoundry.io/level: auditor
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Security auditor role with read-only access for compliance"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "security-compliance"
rules:
# Read-only access to all resources for auditing
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Special access to security-related resources
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["policy"]
  resources: ["podsecuritypolicies"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch"]
---
# Platform Administrator Role - для администраторов платформы
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-platform-admin
  labels:
    rbac.hashfoundry.io/role-type: organizational
    rbac.hashfoundry.io/level: admin
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Platform administrator role with infrastructure management access"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "platform-management"
rules:
# Full cluster administration except RBAC
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
# Exclude dangerous RBAC operations
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["cluster-admin", "system:*"]
DEV_ROLE_EOF
    
    echo "✅ Organizational roles created"
    echo
}

# Функция для создания functional roles
create_functional_roles() {
    echo "=== Creating Functional Roles ==="
    
    # Monitoring Role - для систем мониторинга
    cat << MONITORING_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-monitoring
  labels:
    rbac.hashfoundry.io/role-type: functional
    rbac.hashfoundry.io/level: monitoring
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Monitoring systems role for observability tools"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "observability"
rules:
# Metrics and monitoring
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "nodes/stats", "nodes/proxy"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
# Events and logs
- apiGroups: [""]
  resources: ["events", "pods/log"]
  verbs: ["get", "list", "watch"]
# Metrics APIs
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
- apiGroups: ["custom.metrics.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list"]
# Resource quotas and limits
- apiGroups: [""]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch"]
---
# Backup Role - для систем резервного копирования
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-backup
  labels:
    rbac.hashfoundry.io/role-type: functional
    rbac.hashfoundry.io/level: backup
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Backup systems role for data protection"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "data-protection"
rules:
# Read access to all resources for backup
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Volume snapshots
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots", "volumesnapshotcontents", "volumesnapshotclasses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Persistent volumes
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
# CI/CD Role - для систем непрерывной интеграции
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-cicd
  labels:
    rbac.hashfoundry.io/role-type: functional
    rbac.hashfoundry.io/level: cicd
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "CI/CD systems role for automated deployments"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "automated-deployment"
rules:
# Application deployment resources
- apiGroups: ["", "apps", "batch"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Networking for ingress management
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Service accounts for application identity
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# RBAC for application-specific roles
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Custom resources for operators
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list", "watch"]
MONITORING_ROLE_EOF
    
    echo "✅ Functional roles created"
    echo
}

# Функция для создания environment-specific roles
create_environment_roles() {
    local environment=$1
    
    echo "=== Creating Environment-Specific Roles for: $environment ==="
    
    # Environment-specific role
    cat << ENV_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-$environment
  name: $environment-operator
  labels:
    rbac.hashfoundry.io/role-type: environment
    rbac.hashfoundry.io/level: operator
    rbac.hashfoundry.io/environment: $environment
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Environment operator role for $environment"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "$environment-operations"
rules:
# Full access to namespace resources
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
# Environment read-only role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-$environment
  name: $environment-viewer
  labels:
    rbac.hashfoundry.io/role-type: environment
    rbac.hashfoundry.io/level: viewer
    rbac.hashfoundry.io/environment: $environment
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Environment viewer role for $environment"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "$environment-monitoring"
rules:
# Read-only access to namespace resources
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
# Environment deployer role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-$environment
  name: $environment-deployer
  labels:
    rbac.hashfoundry.io/role-type: environment
    rbac.hashfoundry.io/level: deployer
    rbac.hashfoundry.io/environment: $environment
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Environment deployer role for $environment"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "$environment-deployment"
rules:
# Deployment-specific resources
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "services", "configmaps", "secrets", "deployments", "jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# Events for deployment tracking
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch", "create"]
ENV_ROLE_EOF
    
    echo "✅ Environment-specific roles created for $environment"
    echo
}

# Функция для создания application-specific roles
create_application_roles() {
    local namespace=$1
    local app_name=$2
    
    echo "=== Creating Application-Specific Roles for: $app_name in $namespace ==="
    
    # Application-specific role
    cat << APP_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: $app_name-operator
  labels:
    rbac.hashfoundry.io/role-type: application
    rbac.hashfoundry.io/level: operator
    rbac.hashfoundry.io/application: $app_name
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Application operator role for $app_name"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "$app_name-management"
rules:
# Application-specific resources with label selector
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  resourceNames: ["$app_name-*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  resourceNames: ["$app_name-*"]
# Events for application monitoring
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# Metrics for application performance
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods"]
  verbs: ["get", "list"]
---
# Application runtime role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: $app_name-runtime
  labels:
    rbac.hashfoundry.io/role-type: application
    rbac.hashfoundry.io/level: runtime
    rbac.hashfoundry.io/application: $app_name
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Application runtime role for $app_name"
    rbac.hashfoundry.io/created-by: "hashfoundry-admin"
    rbac.hashfoundry.io/purpose: "$app_name-runtime"
rules:
# Minimal runtime permissions
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["$app_name-config", "$app_name-secret"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]
APP_ROLE_EOF
    
    echo "✅ Application-specific roles created for $app_name"
    echo
}

# Функция для создания policy templates
create_policy_templates() {
    echo "=== Creating RBAC Policy Templates ==="
    
    # Template для создания новых ролей
    cat << TEMPLATE_EOF > rbac-policy-template.yaml
# RBAC Policy Template for HashFoundry
# Usage: Replace placeholders with actual values
apiVersion: rbac.authorization.k8s.io/v1
kind: Role  # or ClusterRole for cluster-wide access
metadata:
  namespace: NAMESPACE_PLACEHOLDER  # Remove for ClusterRole
  name: ROLE_NAME_PLACEHOLDER
  labels:
    rbac.hashfoundry.io/role-type: ROLE_TYPE_PLACEHOLDER  # organizational, functional, environment, application
    rbac.hashfoundry.io/level: LEVEL_PLACEHOLDER  # admin, operator, viewer, runtime
    rbac.hashfoundry.io/environment: ENVIRONMENT_PLACEHOLDER  # dev, prod, test
    rbac.hashfoundry.io/application: APPLICATION_PLACEHOLDER  # app name
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "DESCRIPTION_PLACEHOLDER"
    rbac.hashfoundry.io/created-by: "CREATOR_PLACEHOLDER"
    rbac.hashfoundry.io/purpose: "PURPOSE_PLACEHOLDER"
    rbac.hashfoundry.io/review-date: "REVIEW_DATE_PLACEHOLDER"
rules:
# Example rules - customize based on requirements
- apiGroups: ["API_GROUPS_PLACEHOLDER"]  # "", "apps", "batch", etc.
  resources: ["RESOURCES_PLACEHOLDER"]   # "pods", "services", etc.
  verbs: ["VERBS_PLACEHOLDER"]          # "get", "list", "create", etc.
  resourceNames: ["RESOURCE_NAMES_PLACEHOLDER"]  # Optional: specific resource names
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding  # or ClusterRoleBinding
metadata:
  name: BINDING_NAME_PLACEHOLDER
  namespace: NAMESPACE_PLACEHOLDER  # Remove for ClusterRoleBinding
  labels:
    rbac.hashfoundry.io/binding-type: BINDING_TYPE_PLACEHOLDER
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "BINDING_DESCRIPTION_PLACEHOLDER"
subjects:
- kind: SUBJECT_KIND_PLACEHOLDER  # User, Group, ServiceAccount
  name: SUBJECT_NAME_PLACEHOLDER
  namespace: SUBJECT_NAMESPACE_PLACEHOLDER  # For ServiceAccount
  apiGroup: SUBJECT_API_GROUP_PLACEHOLDER  # rbac.authorization.k8s.io for User/Group
roleRef:
  kind: ROLE_KIND_PLACEHOLDER  # Role or ClusterRole
  name: ROLE_NAME_PLACEHOLDER
  apiGroup: rbac.authorization.k8s.io
TEMPLATE_EOF
    
    # Script для генерации ролей из template
    cat << GENERATOR_EOF > generate-rbac-policy.sh
#!/bin/bash

# RBAC Policy Generator for HashFoundry
# Usage: ./generate-rbac-policy.sh [role-type] [role-name] [namespace] [subject-name]

ROLE_TYPE=\${1:-"application"}
ROLE_NAME=\${2:-"custom-role"}
NAMESPACE=\${3:-"default"}
SUBJECT_NAME=\${4:-"default"}

echo "Generating RBAC policy..."
echo "Role Type: \$ROLE_TYPE"
echo "Role Name: \$ROLE_NAME"
echo "Namespace: \$NAMESPACE"
echo "Subject: \$SUBJECT_NAME"

# Copy template and replace placeholders
cp rbac-policy-template.yaml \${ROLE_NAME}-rbac.yaml

# Replace placeholders
sed -i "s/NAMESPACE_PLACEHOLDER/\$NAMESPACE/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/ROLE_NAME_PLACEHOLDER/\$ROLE_NAME/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/ROLE_TYPE_PLACEHOLDER/\$ROLE_TYPE/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/LEVEL_PLACEHOLDER/operator/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/ENVIRONMENT_PLACEHOLDER/dev/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/APPLICATION_PLACEHOLDER/\$ROLE_NAME/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/DESCRIPTION_PLACEHOLDER/Custom role for \$ROLE_NAME/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/CREATOR_PLACEHOLDER/hashfoundry-admin/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/PURPOSE_PLACEHOLDER/\$ROLE_TYPE operations/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/REVIEW_DATE_PLACEHOLDER/\$(date -d '+6 months' +%Y-%m-%d)/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/BINDING_NAME_PLACEHOLDER/\$ROLE_NAME-binding/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/BINDING_TYPE_PLACEHOLDER/\$ROLE_TYPE-binding/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/BINDING_DESCRIPTION_PLACEHOLDER/Binding for \$ROLE_NAME role/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/SUBJECT_KIND_PLACEHOLDER/ServiceAccount/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/SUBJECT_NAME_PLACEHOLDER/\$SUBJECT_NAME/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/SUBJECT_NAMESPACE_PLACEHOLDER/\$NAMESPACE/g" \${ROLE_NAME}-rbac.yaml
sed -i "s/SUBJECT_API_GROUP_PLACEHOLDER//g" \${ROLE_NAME}-rbac.yaml
sed -i "s/ROLE_KIND_PLACEHOLDER/Role/g" \${ROLE_NAME}-rbac.yaml

# Set default rules based on role type
case \$ROLE_TYPE in
    "organizational")
        sed -i "s/API_GROUPS_PLACEHOLDER/\"\", \"apps\", \"batch\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/RESOURCES_PLACEHOLDER/\"pods\", \"services\", \"deployments\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/VERBS_PLACEHOLDER/\"get\", \"list\", \"watch\", \"create\", \"update\", \"patch\"/g" \${ROLE_NAME}-rbac.yaml
        ;;
    "functional")
        sed -i "s/API_GROUPS_PLACEHOLDER/\"\", \"metrics.k8s.io\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/RESOURCES_PLACEHOLDER/\"pods\", \"nodes\", \"services\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/VERBS_PLACEHOLDER/\"get\", \"list\", \"watch\"/g" \${ROLE_NAME}-rbac.yaml
        ;;
    "application")
        sed -i "s/API_GROUPS_PLACEHOLDER/\"\", \"apps\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/RESOURCES_PLACEHOLDER/\"pods\", \"configmaps\", \"secrets\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/VERBS_PLACEHOLDER/\"get\", \"list\", \"watch\"/g" \${ROLE_NAME}-rbac.yaml
        ;;
    *)
        sed -i "s/API_GROUPS_PLACEHOLDER/\"\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/RESOURCES_PLACEHOLDER/\"pods\"/g" \${ROLE_NAME}-rbac.yaml
        sed -i "s/VERBS_PLACEHOLDER/\"get\", \"list\"/g" \${ROLE_NAME}-rbac.yaml
        ;;
esac

sed -i "s/RESOURCE_NAMES_PLACEHOLDER//g" \${ROLE_NAME}-rbac.yaml

echo "Generated: \${ROLE_NAME}-rbac.yaml"
echo "Review and apply with: kubectl apply -f \${ROLE_NAME}-rbac.yaml"
GENERATOR_EOF
    
    chmod +x generate-rbac-policy.sh
    
    echo "✅ RBAC policy templates created"
    echo "   - rbac-policy-template.yaml: Base template"
    echo "   - generate-rbac-policy.sh: Policy generator script"
    echo
}

# Функция для создания comprehensive bindings
create_comprehensive_bindings() {
    echo "=== Creating Comprehensive Role Bindings ==="
    
    # Создать ServiceAccounts для демонстрации
    for env in dev prod test; do
        kubectl create namespace hashfoundry-$env 2>/dev/null || true
        
        # Environment-specific ServiceAccounts
        cat << SA_EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $env-operator
  namespace: hashfoundry-$env
  labels:
    rbac.hashfoundry.io/environment: $env
    rbac.hashfoundry.io/role: operator
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $env-viewer
  namespace: hashfoundry-$env
  labels:
    rbac.hashfoundry.io/environment: $env
    rbac.hashfoundry.io/role: viewer
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $env-deployer
  namespace: hashfoundry-$env
  labels:
    rbac.hashfoundry.io/environment: $env
    rbac.hashfoundry.io/role: deployer
SA_EOF
        
        # Environment-specific bindings
        cat << BINDING_EOF | kubectl apply -f -
# Operator binding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $env-operator-binding
  namespace: hashfoundry-$env
  labels:
    rbac.hashfoundry.io/environment: $env
    rbac.hashfoundry.io/binding-type: operator
subjects:
- kind: ServiceAccount
  name: $env-operator
  namespace: hashfoundry-$env
roleRef:
  kind: Role
  name: $env-operator
  apiGroup: rbac.authorization.k8s.io
# Viewer binding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $env-viewer-binding
  namespace: hashfoundry-$env
  labels:
    rbac.hashfoundry.io/environment: $env
    rbac.hashfoundry.io/binding-type: viewer
subjects:
- kind: ServiceAccount
  name: $env-viewer
  namespace: hashfoundry-$env
roleRef:
  kind: Role
  name: $env-viewer
  apiGroup: rbac.authorization.k8s.io
---
# Deployer binding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $env-deployer-binding
  namespace: hashfoundry-$env
  labels:
    rbac.hashfoundry.io/environment: $env
    rbac.hashfoundry.io/binding-type: deployer
subjects:
- kind: ServiceAccount
  name: $env-deployer
  namespace: hashfoundry-$env
roleRef:
  kind: Role
  name: $env-deployer
  apiGroup: rbac.authorization.k8s.io
BINDING_EOF
    done
    
    echo "✅ Comprehensive role bindings created"
    echo
}

# Основная функция
main() {
    case "$1" in
        "organizational")
            create_organizational_roles
            ;;
        "functional")
            create_functional_roles
            ;;
        "environment")
            create_environment_roles "${2:-dev}"
            ;;
        "application")
            create_application_roles "${2:-default}" "${3:-myapp}"
            ;;
        "templates")
            create_policy_templates
            ;;
        "bindings")
            create_comprehensive_bindings
            ;;
        "all"|"")
            create_organizational_roles
            create_functional_roles
            for env in dev prod test; do
                create_environment_roles $env
            done
            create_application_roles "hashfoundry-dev" "webapp"
            create_policy_templates
            create_comprehensive_bindings
            ;;
        *)
            echo "Usage: $0 [action] [params...]"
            echo "Actions:"
            echo "  organizational - Create organizational roles"
            echo "  functional     - Create functional roles"
            echo "  environment    - Create environment roles [env]"
            echo "  application    - Create application roles [namespace] [app]"
            echo "  templates      - Create policy templates"
            echo "  bindings       - Create comprehensive bindings"
            echo "  all            - Create all policies (default)"
            ;;
    esac
}

main "$@"

EOF

chmod +x custom-rbac-policies.sh
./custom-rbac-policies.sh all
```

## 📋 **Этапы создания пользовательских RBAC политик:**

### **1. Анализ требований:**
```bash
# Определить роли пользователей
# - Разработчики: доступ к dev namespace
# - DevOps: доступ к деплойменту
# - Аудиторы: read-only доступ
# - Администраторы: полный доступ к инфраструктуре
```

### **2. Проектирование иерархии:**
```bash
# Organizational Roles (по организационной структуре)
# Functional Roles (по функциональности)
# Environment Roles (по средам)
# Application Roles (по приложениям)
```

### **3. Реализация и тестирование:**
```bash
# Создание ролей
kubectl apply -f custom-roles.yaml

# Тестирование прав
kubectl auth can-i get pods --as=system:serviceaccount:dev:developer
kubectl auth can-i create deployments --as=system:serviceaccount:prod:devops
```

## 🎯 **Практические команды:**

### **Создание пользовательских ролей:**
```bash
# Создать роль для разработчика
kubectl create role developer --verb=get,list,watch,create,update,patch,delete --resource=pods,services,deployments

# Создать кластерную роль для мониторинга
kubectl create clusterrole monitoring --verb=get,list,watch --resource=nodes,pods,services

# Привязать роль к пользователю
kubectl create rolebinding developer-binding --role=developer --user=john.doe
```

### **Использование шаблонов:**
```bash
# Генерация роли из шаблона
./generate-rbac-policy.sh application webapp hashfoundry-dev webapp-sa

# Применение сгенерированной политики
kubectl apply -f webapp-rbac.yaml
```

## 🔧 **Best Practices:**

### **Принципы проектирования:**
- **Минимальные привилегии** - давать только необходимые права
- **Разделение обязанностей** - разные роли для разных функций
- **Регулярный аудит** - проверка актуальности прав
- **Документирование** - описание назначения каждой роли

**Пользовательские RBAC политики обеспечивают точный контроль доступа в соответствии с требованиями организации!**
