# 77. Стандартные RBAC роли в Kubernetes

## 🎯 **Стандартные RBAC роли в Kubernetes**

**Default RBAC roles** - это предустановленные роли в Kubernetes, которые обеспечивают базовую функциональность системы и предоставляют стандартные уровни доступа. Эти роли создаются автоматически при инициализации кластера и служат основой для построения пользовательских политик безопасности.

## 🏗️ **Категории стандартных ролей:**

### **Системные роли:**
- **cluster-admin** - полный доступ ко всему кластеру
- **admin** - административный доступ к namespace
- **edit** - права на редактирование ресурсов
- **view** - права только на чтение

### **Системные компоненты:**
- **system:*** - роли для системных компонентов Kubernetes
- **system:node** - роли для узлов кластера
- **system:kube-*** - роли для компонентов control plane

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ стандартных ролей:**
```bash
# Проверить все стандартные ClusterRoles
kubectl get clusterroles | grep -E "(cluster-admin|admin|edit|view|system:)"

# Анализ основных ролей
echo "=== Default RBAC Roles Analysis in HA Cluster ==="
kubectl describe clusterrole cluster-admin | head -20
kubectl describe clusterrole admin | head -20
kubectl describe clusterrole edit | head -20
kubectl describe clusterrole view | head -20

# Проверить системные роли
kubectl get clusterroles | grep "system:" | head -10
```

### **2. Создание comprehensive analysis script:**
```bash
# Создать скрипт для анализа стандартных RBAC ролей
cat << 'EOF' > default-rbac-analysis.sh
#!/bin/bash

echo "=== Default RBAC Roles Analysis ==="
echo "Analyzing standard Kubernetes RBAC roles in HashFoundry HA cluster"
echo

# Функция для анализа основных пользовательских ролей
analyze_user_facing_roles() {
    echo "=== User-Facing Default Roles ==="
    
    # Cluster-admin role analysis
    echo "1. cluster-admin (Superuser Role):"
    echo "   Description: Full cluster access with all permissions"
    echo "   Scope: Cluster-wide"
    echo "   Usage: Emergency access, initial setup"
    echo "   Rules:"
    kubectl get clusterrole cluster-admin -o jsonpath='{.rules[*]}' | jq -r '.' 2>/dev/null || echo "   - apiGroups: [\"*\"], resources: [\"*\"], verbs: [\"*\"]"
    echo
    
    # Admin role analysis
    echo "2. admin (Namespace Administrator):"
    echo "   Description: Full access within a namespace"
    echo "   Scope: Namespace-scoped (via RoleBinding)"
    echo "   Usage: Namespace administrators, team leads"
    echo "   Key permissions:"
    kubectl describe clusterrole admin | grep -A 20 "PolicyRule:" | head -15
    echo
    
    # Edit role analysis
    echo "3. edit (Editor Role):"
    echo "   Description: Read/write access to most resources"
    echo "   Scope: Namespace-scoped (via RoleBinding)"
    echo "   Usage: Developers, operators"
    echo "   Key permissions:"
    kubectl describe clusterrole edit | grep -A 15 "PolicyRule:" | head -10
    echo
    
    # View role analysis
    echo "4. view (Read-Only Role):"
    echo "   Description: Read-only access to most resources"
    echo "   Scope: Namespace-scoped (via RoleBinding)"
    echo "   Usage: Monitoring, auditing, read-only users"
    echo "   Key permissions:"
    kubectl describe clusterrole view | grep -A 10 "PolicyRule:" | head -8
    echo
}

# Функция для анализа системных ролей
analyze_system_roles() {
    echo "=== System Component Roles ==="
    
    # Control plane roles
    echo "Control Plane Roles:"
    echo "==================="
    
    system_roles=(
        "system:kube-controller-manager"
        "system:kube-scheduler" 
        "system:kube-proxy"
        "system:kubelet-api-admin"
        "system:node"
        "system:node-bootstrapper"
        "system:node-problem-detector"
    )
    
    for role in "${system_roles[@]}"; do
        if kubectl get clusterrole "$role" >/dev/null 2>&1; then
            echo "• $role:"
            description=$(kubectl get clusterrole "$role" -o jsonpath='{.metadata.annotations.rbac\.authorization\.kubernetes\.io/autoupdate}' 2>/dev/null)
            echo "  Auto-update: ${description:-true}"
            
            # Показать основные права
            rules_count=$(kubectl get clusterrole "$role" -o jsonpath='{.rules}' | jq length 2>/dev/null || echo "N/A")
            echo "  Rules count: $rules_count"
            
            # Показать первое правило как пример
            first_rule=$(kubectl get clusterrole "$role" -o jsonpath='{.rules[0]}' 2>/dev/null)
            if [ -n "$first_rule" ]; then
                echo "  Example rule: $first_rule" | head -c 100
                echo "..."
            fi
            echo
        fi
    done
}

# Функция для анализа discovery ролей
analyze_discovery_roles() {
    echo "=== Discovery and Authentication Roles ==="
    
    discovery_roles=(
        "system:discovery"
        "system:basic-user"
        "system:public-info-viewer"
        "system:unauthenticated"
        "system:authenticated"
    )
    
    for role in "${discovery_roles[@]}"; do
        if kubectl get clusterrole "$role" >/dev/null 2>&1; then
            echo "• $role:"
            
            # Получить правила роли
            rules=$(kubectl get clusterrole "$role" -o jsonpath='{.rules}' 2>/dev/null)
            if [ -n "$rules" ]; then
                echo "  Purpose: API discovery and basic authentication"
                kubectl describe clusterrole "$role" | grep -A 5 "PolicyRule:" | head -5 | sed 's/^/  /'
            fi
            echo
        fi
    done
}

# Функция для анализа addon ролей
analyze_addon_roles() {
    echo "=== Add-on and Extension Roles ==="
    
    # DNS roles
    echo "DNS Roles:"
    dns_roles=$(kubectl get clusterroles | grep -E "(dns|coredns)" | awk '{print $1}')
    for role in $dns_roles; do
        echo "• $role: DNS system component"
    done
    echo
    
    # Metrics roles
    echo "Metrics Roles:"
    metrics_roles=$(kubectl get clusterroles | grep -E "(metrics|monitoring)" | awk '{print $1}')
    for role in $metrics_roles; do
        echo "• $role: Metrics collection and monitoring"
    done
    echo
    
    # Storage roles
    echo "Storage Roles:"
    storage_roles=$(kubectl get clusterroles | grep -E "(storage|volume|pv)" | awk '{print $1}')
    for role in $storage_roles; do
        echo "• $role: Storage management"
    done
    echo
}

# Функция для создания демонстрации использования стандартных ролей
demonstrate_default_roles_usage() {
    echo "=== Demonstrating Default Roles Usage ==="
    
    # Создать namespace для демонстрации
    kubectl create namespace rbac-demo 2>/dev/null || echo "Namespace rbac-demo already exists"
    
    # Создать ServiceAccounts для демонстрации
    cat << SA_EOF | kubectl apply -f -
# ServiceAccount для admin роли
apiVersion: v1
kind: ServiceAccount
metadata:
  name: namespace-admin
  namespace: rbac-demo
  labels:
    rbac-demo: admin
    app.kubernetes.io/name: hashfoundry-rbac-demo
---
# ServiceAccount для edit роли
apiVersion: v1
kind: ServiceAccount
metadata:
  name: namespace-editor
  namespace: rbac-demo
  labels:
    rbac-demo: edit
    app.kubernetes.io/name: hashfoundry-rbac-demo
---
# ServiceAccount для view роли
apiVersion: v1
kind: ServiceAccount
metadata:
  name: namespace-viewer
  namespace: rbac-demo
  labels:
    rbac-demo: view
    app.kubernetes.io/name: hashfoundry-rbac-demo
---
# ServiceAccount для cluster-admin роли
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-administrator
  namespace: rbac-demo
  labels:
    rbac-demo: cluster-admin
    app.kubernetes.io/name: hashfoundry-rbac-demo
SA_EOF
    
    # Создать RoleBindings для namespace-scoped ролей
    cat << RB_EOF | kubectl apply -f -
# Admin RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-binding
  namespace: rbac-demo
  labels:
    rbac-demo: admin
    app.kubernetes.io/name: hashfoundry-rbac-demo
subjects:
- kind: ServiceAccount
  name: namespace-admin
  namespace: rbac-demo
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
---
# Edit RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edit-binding
  namespace: rbac-demo
  labels:
    rbac-demo: edit
    app.kubernetes.io/name: hashfoundry-rbac-demo
subjects:
- kind: ServiceAccount
  name: namespace-editor
  namespace: rbac-demo
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
---
# View RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: view-binding
  namespace: rbac-demo
  labels:
    rbac-demo: view
    app.kubernetes.io/name: hashfoundry-rbac-demo
subjects:
- kind: ServiceAccount
  name: namespace-viewer
  namespace: rbac-demo
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
RB_EOF
    
    # Создать ClusterRoleBinding для cluster-admin
    cat << CRB_EOF | kubectl apply -f -
# Cluster Admin ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-demo-binding
  labels:
    rbac-demo: cluster-admin
    app.kubernetes.io/name: hashfoundry-rbac-demo
subjects:
- kind: ServiceAccount
  name: cluster-administrator
  namespace: rbac-demo
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
CRB_EOF
    
    echo "✅ Default roles demonstration setup created"
    echo
}

# Функция для тестирования прав стандартных ролей
test_default_roles_permissions() {
    echo "=== Testing Default Roles Permissions ==="
    
    echo "Testing namespace-admin (admin role):"
    echo "====================================="
    kubectl auth can-i create pods --as=system:serviceaccount:rbac-demo:namespace-admin -n rbac-demo >/dev/null 2>&1 && echo "✅ Can create pods" || echo "❌ Cannot create pods"
    kubectl auth can-i delete deployments --as=system:serviceaccount:rbac-demo:namespace-admin -n rbac-demo >/dev/null 2>&1 && echo "✅ Can delete deployments" || echo "❌ Cannot delete deployments"
    kubectl auth can-i create roles --as=system:serviceaccount:rbac-demo:namespace-admin -n rbac-demo >/dev/null 2>&1 && echo "✅ Can create roles" || echo "❌ Cannot create roles"
    kubectl auth can-i get secrets --as=system:serviceaccount:rbac-demo:namespace-admin -n rbac-demo >/dev/null 2>&1 && echo "✅ Can get secrets" || echo "❌ Cannot get secrets"
    kubectl auth can-i get nodes --as=system:serviceaccount:rbac-demo:namespace-admin >/dev/null 2>&1 && echo "⚠️  Can get nodes (should not)" || echo "✅ Cannot get nodes (correct)"
    echo
    
    echo "Testing namespace-editor (edit role):"
    echo "===================================="
    kubectl auth can-i create pods --as=system:serviceaccount:rbac-demo:namespace-editor -n rbac-demo >/dev/null 2>&1 && echo "✅ Can create pods" || echo "❌ Cannot create pods"
    kubectl auth can-i update deployments --as=system:serviceaccount:rbac-demo:namespace-editor -n rbac-demo >/dev/null 2>&1 && echo "✅ Can update deployments" || echo "❌ Cannot update deployments"
    kubectl auth can-i create roles --as=system:serviceaccount:rbac-demo:namespace-editor -n rbac-demo >/dev/null 2>&1 && echo "⚠️  Can create roles (should not)" || echo "✅ Cannot create roles (correct)"
    kubectl auth can-i get secrets --as=system:serviceaccount:rbac-demo:namespace-editor -n rbac-demo >/dev/null 2>&1 && echo "⚠️  Can get secrets (limited)" || echo "✅ Cannot get secrets"
    echo
    
    echo "Testing namespace-viewer (view role):"
    echo "===================================="
    kubectl auth can-i get pods --as=system:serviceaccount:rbac-demo:namespace-viewer -n rbac-demo >/dev/null 2>&1 && echo "✅ Can get pods" || echo "❌ Cannot get pods"
    kubectl auth can-i list services --as=system:serviceaccount:rbac-demo:namespace-viewer -n rbac-demo >/dev/null 2>&1 && echo "✅ Can list services" || echo "❌ Cannot list services"
    kubectl auth can-i create pods --as=system:serviceaccount:rbac-demo:namespace-viewer -n rbac-demo >/dev/null 2>&1 && echo "⚠️  Can create pods (should not)" || echo "✅ Cannot create pods (correct)"
    kubectl auth can-i get secrets --as=system:serviceaccount:rbac-demo:namespace-viewer -n rbac-demo >/dev/null 2>&1 && echo "⚠️  Can get secrets (should not)" || echo "✅ Cannot get secrets (correct)"
    echo
    
    echo "Testing cluster-administrator (cluster-admin role):"
    echo "================================================="
    kubectl auth can-i create namespaces --as=system:serviceaccount:rbac-demo:cluster-administrator >/dev/null 2>&1 && echo "✅ Can create namespaces" || echo "❌ Cannot create namespaces"
    kubectl auth can-i get nodes --as=system:serviceaccount:rbac-demo:cluster-administrator >/dev/null 2>&1 && echo "✅ Can get nodes" || echo "❌ Cannot get nodes"
    kubectl auth can-i create clusterroles --as=system:serviceaccount:rbac-demo:cluster-administrator >/dev/null 2>&1 && echo "✅ Can create clusterroles" || echo "❌ Cannot create clusterroles"
    kubectl auth can-i delete persistentvolumes --as=system:serviceaccount:rbac-demo:cluster-administrator >/dev/null 2>&1 && echo "✅ Can delete persistentvolumes" || echo "❌ Cannot delete persistentvolumes"
    echo
}

# Функция для создания сравнительной таблицы ролей
create_roles_comparison() {
    echo "=== Default Roles Comparison ==="
    
    cat << COMPARISON_EOF
Role Comparison Matrix:
======================

| Permission Type    | cluster-admin | admin | edit | view |
|-------------------|---------------|-------|------|------|
| Create Pods       | ✅ Yes        | ✅ Yes | ✅ Yes | ❌ No  |
| Delete Pods       | ✅ Yes        | ✅ Yes | ✅ Yes | ❌ No  |
| View Pods         | ✅ Yes        | ✅ Yes | ✅ Yes | ✅ Yes |
| Create Services   | ✅ Yes        | ✅ Yes | ✅ Yes | ❌ No  |
| Create Secrets    | ✅ Yes        | ✅ Yes | ✅ Yes | ❌ No  |
| View Secrets      | ✅ Yes        | ✅ Yes | ⚠️ Limited | ❌ No  |
| Create Roles      | ✅ Yes        | ✅ Yes | ❌ No  | ❌ No  |
| Create RoleBindings| ✅ Yes       | ✅ Yes | ❌ No  | ❌ No  |
| Access Nodes      | ✅ Yes        | ❌ No  | ❌ No  | ❌ No  |
| Create Namespaces | ✅ Yes        | ❌ No  | ❌ No  | ❌ No  |
| Create ClusterRoles| ✅ Yes       | ❌ No  | ❌ No  | ❌ No  |

Scope:
======
• cluster-admin: Cluster-wide (via ClusterRoleBinding)
• admin: Namespace-scoped (via RoleBinding) or Cluster-wide (via ClusterRoleBinding)
• edit: Namespace-scoped (via RoleBinding) or Cluster-wide (via ClusterRoleBinding)  
• view: Namespace-scoped (via RoleBinding) or Cluster-wide (via ClusterRoleBinding)

Usage Recommendations:
=====================
• cluster-admin: Emergency access, initial cluster setup, platform administrators
• admin: Namespace administrators, team leads, environment managers
• edit: Developers, operators, CI/CD systems
• view: Monitoring systems, auditors, read-only users, dashboards
COMPARISON_EOF
    
    echo
}

# Функция для анализа привязок стандартных ролей
analyze_default_bindings() {
    echo "=== Default Role Bindings Analysis ==="
    
    echo "System ClusterRoleBindings:"
    echo "=========================="
    kubectl get clusterrolebindings | grep -E "(cluster-admin|system:)" | head -10
    echo
    
    echo "User-facing RoleBindings in kube-system:"
    echo "========================================"
    kubectl get rolebindings -n kube-system | head -5
    echo
    
    echo "ClusterRoleBindings for default roles:"
    echo "======================================"
    kubectl get clusterrolebindings -o custom-columns="NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name" | grep -E "(admin|edit|view)" | head -5
    echo
}

# Основная функция
main() {
    case "$1" in
        "user-roles")
            analyze_user_facing_roles
            ;;
        "system-roles")
            analyze_system_roles
            ;;
        "discovery-roles")
            analyze_discovery_roles
            ;;
        "addon-roles")
            analyze_addon_roles
            ;;
        "demo")
            demonstrate_default_roles_usage
            ;;
        "test")
            test_default_roles_permissions
            ;;
        "comparison")
            create_roles_comparison
            ;;
        "bindings")
            analyze_default_bindings
            ;;
        "all"|"")
            analyze_user_facing_roles
            analyze_system_roles
            analyze_discovery_roles
            analyze_addon_roles
            demonstrate_default_roles_usage
            sleep 10  # Дать время для создания ресурсов
            test_default_roles_permissions
            create_roles_comparison
            analyze_default_bindings
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  user-roles     - Analyze user-facing roles (admin, edit, view, cluster-admin)"
            echo "  system-roles   - Analyze system component roles"
            echo "  discovery-roles- Analyze discovery and authentication roles"
            echo "  addon-roles    - Analyze add-on and extension roles"
            echo "  demo           - Create demonstration setup"
            echo "  test           - Test role permissions"
            echo "  comparison     - Show roles comparison matrix"
            echo "  bindings       - Analyze default bindings"
            echo "  all            - Full analysis (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 user-roles"
            echo "  $0 test"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x default-rbac-analysis.sh

# Запустить анализ
./default-rbac-analysis.sh all
```

## 📋 **Основные стандартные роли:**

### **1. Пользовательские роли:**

#### **cluster-admin:**
```bash
# Полный доступ ко всему кластеру
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

#### **admin:**
```bash
# Административный доступ к namespace
# Может управлять всеми ресурсами в namespace
# Может создавать роли и привязки ролей
```

#### **edit:**
```bash
# Права на редактирование большинства ресурсов
# Не может управлять ролями и привязками
# Ограниченный доступ к secrets
```

#### **view:**
```bash
# Права только на чтение
# Может просматривать большинство ресурсов
# Не может просматривать secrets и роли
```

### **2. Системные роли:**

#### **system:node:**
```bash
# Права для kubelet на узлах
# Доступ к pods, services, endpoints
# Может обновлять статус узлов
```

#### **system:kube-controller-manager:**
```bash
# Права для controller manager
# Управление deployments, replicasets
# Управление endpoints, services
```

#### **system:kube-scheduler:**
```bash
# Права для scheduler
# Чтение pods, nodes
# Обновление pod bindings
```

## 🎯 **Практические команды:**

### **Просмотр стандартных ролей:**
```bash
# Список всех ClusterRoles
kubectl get clusterroles

# Основные пользовательские роли
kubectl get clusterroles | grep -E "^(cluster-admin|admin|edit|view)$"

# Системные роли
kubectl get clusterroles | grep "system:"

# Детальная информация о роли
kubectl describe clusterrole admin
```

### **Использование стандартных ролей:**
```bash
# Привязать admin роль к пользователю в namespace
kubectl create rolebinding admin-binding --clusterrole=admin --user=john.doe -n production

# Привязать view роль к ServiceAccount
kubectl create rolebinding viewer-binding --clusterrole=view --serviceaccount=monitoring:prometheus -n default

# Привязать cluster-admin к пользователю (осторожно!)
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=admin
```

### **Проверка прав стандартных ролей:**
```bash
# Проверить права admin роли
kubectl auth can-i --list --as=system:serviceaccount:default:admin-user

# Проверить конкретное право
kubectl auth can-i create pods --as=system:serviceaccount:default:editor -n development

# Проверить права в разных namespace
kubectl auth can-i get secrets --as=system:serviceaccount:default:viewer -n kube-system
```

## 🔧 **Best Practices:**

### **Использование стандартных ролей:**
- **Предпочитать стандартные роли** - использовать встроенные роли когда возможно
- **Комбинировать роли** - использовать несколько RoleBindings для гранулярного доступа
- **Избегать cluster-admin** - использовать только при крайней необходимости
- **Тестировать права** - всегда проверять права перед production

### **Безопасность:**
- **Принцип минимальных привилегий** - начинать с view, повышать по необходимости
- **Регулярный аудит** - проверять кто имеет какие права
- **Временные права** - использовать временные привязки для административных задач
- **Мониторинг использования** - отслеживать использование привилегированных ролей

**Стандартные RBAC роли обеспечивают надежную основу для системы безопасности Kubernetes!**
