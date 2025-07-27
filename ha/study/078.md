# 78. Диагностика проблем с RBAC правами в Kubernetes

## 🎯 **Диагностика проблем с RBAC правами в Kubernetes**

**RBAC troubleshooting** - это процесс выявления и решения проблем с правами доступа в Kubernetes. Правильная диагностика RBAC проблем критически важна для обеспечения безопасности и функциональности кластера.

## 🏗️ **Основные типы RBAC проблем:**

### **Категории проблем:**
- **Access Denied** - отказ в доступе к ресурсам
- **Insufficient Permissions** - недостаточные права
- **Role Conflicts** - конфликты ролей
- **Binding Issues** - проблемы с привязками ролей

### **Инструменты диагностики:**
- **kubectl auth can-i** - проверка прав доступа
- **kubectl describe** - детальная информация о ролях
- **kubectl get** - просмотр ролей и привязок
- **Audit logs** - логи аудита для анализа

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Базовая диагностика RBAC:**
```bash
# Проверить текущие права пользователя
kubectl auth can-i --list

# Проверить права для конкретного действия
kubectl auth can-i create pods
kubectl auth can-i get secrets -n kube-system

# Проверить права от имени другого пользователя
kubectl auth can-i get pods --as=system:serviceaccount:default:my-app
```

### **2. Создание comprehensive troubleshooting toolkit:**
```bash
# Создать скрипт для диагностики RBAC проблем
cat << 'EOF' > rbac-troubleshooting.sh
#!/bin/bash

echo "=== RBAC Troubleshooting Toolkit ==="
echo "Comprehensive RBAC diagnostics for HashFoundry HA cluster"
echo

# Функция для проверки базовых прав доступа
check_basic_permissions() {
    local user_context="${1:-current-user}"
    
    echo "=== Basic Permissions Check for: $user_context ==="
    
    if [ "$user_context" = "current-user" ]; then
        echo "Checking permissions for current user context..."
        
        # Основные права
        echo "Core Permissions:"
        kubectl auth can-i get pods >/dev/null 2>&1 && echo "✅ Can get pods" || echo "❌ Cannot get pods"
        kubectl auth can-i create pods >/dev/null 2>&1 && echo "✅ Can create pods" || echo "❌ Cannot create pods"
        kubectl auth can-i get services >/dev/null 2>&1 && echo "✅ Can get services" || echo "❌ Cannot get services"
        kubectl auth can-i get nodes >/dev/null 2>&1 && echo "✅ Can get nodes" || echo "❌ Cannot get nodes"
        kubectl auth can-i get secrets >/dev/null 2>&1 && echo "✅ Can get secrets" || echo "❌ Cannot get secrets"
        
        # Административные права
        echo "Administrative Permissions:"
        kubectl auth can-i create namespaces >/dev/null 2>&1 && echo "✅ Can create namespaces" || echo "❌ Cannot create namespaces"
        kubectl auth can-i create clusterroles >/dev/null 2>&1 && echo "✅ Can create clusterroles" || echo "❌ Cannot create clusterroles"
        kubectl auth can-i create clusterrolebindings >/dev/null 2>&1 && echo "✅ Can create clusterrolebindings" || echo "❌ Cannot create clusterrolebindings"
    else
        echo "Checking permissions for: $user_context"
        
        # Проверка прав для указанного пользователя/ServiceAccount
        kubectl auth can-i get pods --as="$user_context" >/dev/null 2>&1 && echo "✅ Can get pods" || echo "❌ Cannot get pods"
        kubectl auth can-i create pods --as="$user_context" >/dev/null 2>&1 && echo "✅ Can create pods" || echo "❌ Cannot create pods"
        kubectl auth can-i get services --as="$user_context" >/dev/null 2>&1 && echo "✅ Can get services" || echo "❌ Cannot get services"
        kubectl auth can-i get nodes --as="$user_context" >/dev/null 2>&1 && echo "✅ Can get nodes" || echo "❌ Cannot get nodes"
    fi
    
    echo
}

# Функция для диагностики конкретной проблемы доступа
diagnose_access_issue() {
    local resource="$1"
    local verb="$2"
    local namespace="$3"
    local user_context="$4"
    
    echo "=== Diagnosing Access Issue ==="
    echo "Resource: $resource"
    echo "Verb: $verb"
    echo "Namespace: ${namespace:-cluster-wide}"
    echo "User: ${user_context:-current-user}"
    echo
    
    # Построить команду проверки
    local check_cmd="kubectl auth can-i $verb $resource"
    if [ -n "$namespace" ]; then
        check_cmd="$check_cmd -n $namespace"
    fi
    if [ -n "$user_context" ]; then
        check_cmd="$check_cmd --as=$user_context"
    fi
    
    echo "Testing access: $check_cmd"
    if eval "$check_cmd" >/dev/null 2>&1; then
        echo "✅ Access GRANTED"
        echo "No issue detected with this permission."
    else
        echo "❌ Access DENIED"
        echo "Investigating the cause..."
        
        # Анализ причин отказа
        analyze_access_denial "$resource" "$verb" "$namespace" "$user_context"
    fi
    
    echo
}

# Функция для анализа причин отказа в доступе
analyze_access_denial() {
    local resource="$1"
    local verb="$2"
    local namespace="$3"
    local user_context="$4"
    
    echo "=== Access Denial Analysis ==="
    
    # Определить тип субъекта
    if [[ "$user_context" == system:serviceaccount:* ]]; then
        # ServiceAccount
        local sa_namespace=$(echo "$user_context" | cut -d: -f3)
        local sa_name=$(echo "$user_context" | cut -d: -f4)
        
        echo "Subject Type: ServiceAccount"
        echo "ServiceAccount: $sa_name"
        echo "ServiceAccount Namespace: $sa_namespace"
        
        # Проверить существование ServiceAccount
        if kubectl get serviceaccount "$sa_name" -n "$sa_namespace" >/dev/null 2>&1; then
            echo "✅ ServiceAccount exists"
            
            # Найти привязки ролей для этого ServiceAccount
            echo "Checking RoleBindings..."
            local rolebindings=$(kubectl get rolebindings --all-namespaces -o json | jq -r ".items[] | select(.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"$sa_name\" and .namespace==\"$sa_namespace\")) | \"\(.metadata.namespace)/\(.metadata.name)\"")
            
            if [ -n "$rolebindings" ]; then
                echo "Found RoleBindings:"
                echo "$rolebindings" | while read binding; do
                    local binding_ns=$(echo "$binding" | cut -d/ -f1)
                    local binding_name=$(echo "$binding" | cut -d/ -f2)
                    echo "  - $binding_name (namespace: $binding_ns)"
                    
                    # Получить роль из привязки
                    local role_name=$(kubectl get rolebinding "$binding_name" -n "$binding_ns" -o jsonpath='{.roleRef.name}')
                    local role_kind=$(kubectl get rolebinding "$binding_name" -n "$binding_ns" -o jsonpath='{.roleRef.kind}')
                    echo "    Role: $role_name ($role_kind)"
                done
            else
                echo "❌ No RoleBindings found for this ServiceAccount"
            fi
            
            # Проверить ClusterRoleBindings
            echo "Checking ClusterRoleBindings..."
            local clusterrolebindings=$(kubectl get clusterrolebindings -o json | jq -r ".items[] | select(.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"$sa_name\" and .namespace==\"$sa_namespace\")) | .metadata.name")
            
            if [ -n "$clusterrolebindings" ]; then
                echo "Found ClusterRoleBindings:"
                echo "$clusterrolebindings" | while read binding; do
                    echo "  - $binding"
                    local role_name=$(kubectl get clusterrolebinding "$binding" -o jsonpath='{.roleRef.name}')
                    echo "    ClusterRole: $role_name"
                done
            else
                echo "❌ No ClusterRoleBindings found for this ServiceAccount"
            fi
            
        else
            echo "❌ ServiceAccount does not exist"
            echo "Solution: Create the ServiceAccount:"
            echo "kubectl create serviceaccount $sa_name -n $sa_namespace"
        fi
        
    else
        # User или Group
        echo "Subject Type: User/Group"
        echo "Subject: $user_context"
        
        # Для пользователей сложнее найти привязки, так как они могут быть в группах
        echo "Note: User/Group binding analysis requires manual inspection"
        echo "Check ClusterRoleBindings and RoleBindings manually"
    fi
    
    echo
    echo "=== Suggested Solutions ==="
    
    # Предложить решения
    if [ -n "$namespace" ]; then
        echo "For namespace-scoped access ($namespace):"
        echo "1. Create a Role with required permissions:"
        cat << ROLE_EXAMPLE
kubectl create role ${resource}-${verb}-role \\
  --verb=$verb \\
  --resource=$resource \\
  -n $namespace
ROLE_EXAMPLE
        
        echo "2. Create a RoleBinding:"
        if [[ "$user_context" == system:serviceaccount:* ]]; then
            local sa_namespace=$(echo "$user_context" | cut -d: -f3)
            local sa_name=$(echo "$user_context" | cut -d: -f4)
            cat << BINDING_EXAMPLE
kubectl create rolebinding ${resource}-${verb}-binding \\
  --role=${resource}-${verb}-role \\
  --serviceaccount=$sa_namespace:$sa_name \\
  -n $namespace
BINDING_EXAMPLE
        else
            cat << BINDING_EXAMPLE
kubectl create rolebinding ${resource}-${verb}-binding \\
  --role=${resource}-${verb}-role \\
  --user=$user_context \\
  -n $namespace
BINDING_EXAMPLE
        fi
    else
        echo "For cluster-wide access:"
        echo "1. Create a ClusterRole with required permissions:"
        cat << CLUSTERROLE_EXAMPLE
kubectl create clusterrole ${resource}-${verb}-clusterrole \\
  --verb=$verb \\
  --resource=$resource
CLUSTERROLE_EXAMPLE
        
        echo "2. Create a ClusterRoleBinding:"
        if [[ "$user_context" == system:serviceaccount:* ]]; then
            local sa_namespace=$(echo "$user_context" | cut -d: -f3)
            local sa_name=$(echo "$user_context" | cut -d: -f4)
            cat << CLUSTERBINDING_EXAMPLE
kubectl create clusterrolebinding ${resource}-${verb}-clusterbinding \\
  --clusterrole=${resource}-${verb}-clusterrole \\
  --serviceaccount=$sa_namespace:$sa_name
CLUSTERBINDING_EXAMPLE
        else
            cat << CLUSTERBINDING_EXAMPLE
kubectl create clusterrolebinding ${resource}-${verb}-clusterbinding \\
  --clusterrole=${resource}-${verb}-clusterrole \\
  --user=$user_context
CLUSTERBINDING_EXAMPLE
        fi
    fi
    
    echo
}

# Функция для проверки конфигурации ролей
check_role_configuration() {
    local role_name="$1"
    local role_type="${2:-Role}"  # Role или ClusterRole
    local namespace="$3"
    
    echo "=== Role Configuration Check ==="
    echo "Role: $role_name"
    echo "Type: $role_type"
    echo "Namespace: ${namespace:-cluster-wide}"
    echo
    
    # Проверить существование роли
    local get_cmd="kubectl get $role_type $role_name"
    if [ "$role_type" = "Role" ] && [ -n "$namespace" ]; then
        get_cmd="$get_cmd -n $namespace"
    fi
    
    if eval "$get_cmd" >/dev/null 2>&1; then
        echo "✅ Role exists"
        
        # Показать правила роли
        echo "Role Rules:"
        local describe_cmd="kubectl describe $role_type $role_name"
        if [ "$role_type" = "Role" ] && [ -n "$namespace" ]; then
            describe_cmd="$describe_cmd -n $namespace"
        fi
        
        eval "$describe_cmd" | grep -A 20 "PolicyRule:"
        
    else
        echo "❌ Role does not exist"
        echo "Available roles:"
        if [ "$role_type" = "Role" ] && [ -n "$namespace" ]; then
            kubectl get roles -n "$namespace"
        else
            kubectl get clusterroles | head -10
        fi
    fi
    
    echo
}

# Функция для проверки привязок ролей
check_role_bindings() {
    local subject_name="$1"
    local subject_type="${2:-ServiceAccount}"  # ServiceAccount, User, Group
    local subject_namespace="$3"
    
    echo "=== Role Bindings Check ==="
    echo "Subject: $subject_name"
    echo "Type: $subject_type"
    echo "Namespace: ${subject_namespace:-N/A}"
    echo
    
    # Поиск RoleBindings
    echo "Searching RoleBindings..."
    local rolebinding_query=".items[] | select(.subjects[]? | select(.kind==\"$subject_type\" and .name==\"$subject_name\""
    if [ -n "$subject_namespace" ]; then
        rolebinding_query="$rolebinding_query and .namespace==\"$subject_namespace\""
    fi
    rolebinding_query="$rolebinding_query)) | \"\(.metadata.namespace)/\(.metadata.name)/\(.roleRef.name)\""
    
    local rolebindings=$(kubectl get rolebindings --all-namespaces -o json | jq -r "$rolebinding_query")
    
    if [ -n "$rolebindings" ]; then
        echo "Found RoleBindings:"
        echo "$rolebindings" | while IFS='/' read binding_ns binding_name role_name; do
            echo "  Namespace: $binding_ns"
            echo "  Binding: $binding_name"
            echo "  Role: $role_name"
            echo "  ---"
        done
    else
        echo "❌ No RoleBindings found"
    fi
    
    # Поиск ClusterRoleBindings
    echo "Searching ClusterRoleBindings..."
    local clusterrolebinding_query=".items[] | select(.subjects[]? | select(.kind==\"$subject_type\" and .name==\"$subject_name\""
    if [ -n "$subject_namespace" ]; then
        clusterrolebinding_query="$clusterrolebinding_query and .namespace==\"$subject_namespace\""
    fi
    clusterrolebinding_query="$clusterrolebinding_query)) | \"\(.metadata.name)/\(.roleRef.name)\""
    
    local clusterrolebindings=$(kubectl get clusterrolebindings -o json | jq -r "$clusterrolebinding_query")
    
    if [ -n "$clusterrolebindings" ]; then
        echo "Found ClusterRoleBindings:"
        echo "$clusterrolebindings" | while IFS='/' read binding_name role_name; do
            echo "  Binding: $binding_name"
            echo "  ClusterRole: $role_name"
            echo "  ---"
        done
    else
        echo "❌ No ClusterRoleBindings found"
    fi
    
    echo
}

# Функция для создания тестовых сценариев
create_test_scenarios() {
    echo "=== Creating RBAC Test Scenarios ==="
    
    # Создать namespace для тестирования
    kubectl create namespace rbac-test 2>/dev/null || echo "Namespace rbac-test already exists"
    
    # Создать тестовые ServiceAccounts
    cat << TEST_SA_EOF | kubectl apply -f -
# ServiceAccount с правами
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-sa-with-rights
  namespace: rbac-test
  labels:
    test-type: with-rights
---
# ServiceAccount без прав
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-sa-no-rights
  namespace: rbac-test
  labels:
    test-type: no-rights
---
# ServiceAccount с ограниченными правами
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-sa-limited-rights
  namespace: rbac-test
  labels:
    test-type: limited-rights
TEST_SA_EOF
    
    # Создать тестовые роли
    cat << TEST_ROLES_EOF | kubectl apply -f -
# Роль с полными правами в namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-test
  name: full-access-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
# Роль только для чтения
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-test
  name: read-only-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
---
# Роль для управления pods
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-test
  name: pod-manager-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]
TEST_ROLES_EOF
    
    # Создать привязки ролей
    cat << TEST_BINDINGS_EOF | kubectl apply -f -
# Привязка полных прав
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: full-access-binding
  namespace: rbac-test
subjects:
- kind: ServiceAccount
  name: test-sa-with-rights
  namespace: rbac-test
roleRef:
  kind: Role
  name: full-access-role
  apiGroup: rbac.authorization.k8s.io
---
# Привязка ограниченных прав
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: limited-access-binding
  namespace: rbac-test
subjects:
- kind: ServiceAccount
  name: test-sa-limited-rights
  namespace: rbac-test
roleRef:
  kind: Role
  name: read-only-role
  apiGroup: rbac.authorization.k8s.io
TEST_BINDINGS_EOF
    
    echo "✅ Test scenarios created in rbac-test namespace"
    echo
}

# Функция для запуска тестов
run_rbac_tests() {
    echo "=== Running RBAC Tests ==="
    
    # Тест 1: ServiceAccount с правами
    echo "Test 1: ServiceAccount with full rights"
    echo "======================================="
    diagnose_access_issue "pods" "create" "rbac-test" "system:serviceaccount:rbac-test:test-sa-with-rights"
    
    # Тест 2: ServiceAccount без прав
    echo "Test 2: ServiceAccount without rights"
    echo "====================================="
    diagnose_access_issue "pods" "create" "rbac-test" "system:serviceaccount:rbac-test:test-sa-no-rights"
    
    # Тест 3: ServiceAccount с ограниченными правами
    echo "Test 3: ServiceAccount with limited rights"
    echo "=========================================="
    diagnose_access_issue "pods" "create" "rbac-test" "system:serviceaccount:rbac-test:test-sa-limited-rights"
    
    # Тест 4: Доступ к cluster-scoped ресурсам
    echo "Test 4: Cluster-scoped resource access"
    echo "======================================"
    diagnose_access_issue "nodes" "get" "" "system:serviceaccount:rbac-test:test-sa-with-rights"
}

# Функция для генерации отчета о RBAC
generate_rbac_report() {
    echo "=== RBAC Security Report ==="
    
    echo "Cluster-wide privileged bindings:"
    echo "================================="
    kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | "ClusterRoleBinding: \(.metadata.name), Subjects: \(.subjects[].name // .subjects[].kind)"'
    echo
    
    echo "ServiceAccounts with cluster-admin:"
    echo "==================================="
    kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin" and .subjects[].kind=="ServiceAccount") | "Binding: \(.metadata.name), SA: \(.subjects[].namespace)/\(.subjects[].name)"'
    echo
    
    echo "Namespaces with admin access:"
    echo "============================"
    kubectl get rolebindings --all-namespaces -o json | jq -r '.items[] | select(.roleRef.name=="admin") | "Namespace: \(.metadata.namespace), Binding: \(.metadata.name), Subject: \(.subjects[].name)"'
    echo
}

# Основная функция
main() {
    case "$1" in
        "check")
            check_basic_permissions "$2"
            ;;
        "diagnose")
            diagnose_access_issue "$2" "$3" "$4" "$5"
            ;;
        "role")
            check_role_configuration "$2" "$3" "$4"
            ;;
        "bindings")
            check_role_bindings "$2" "$3" "$4"
            ;;
        "test-setup")
            create_test_scenarios
            ;;
        "test")
            run_rbac_tests
            ;;
        "report")
            generate_rbac_report
            ;;
        "all"|"")
            check_basic_permissions
            create_test_scenarios
            sleep 5
            run_rbac_tests
            generate_rbac_report
            ;;
        *)
            echo "Usage: $0 [action] [params...]"
            echo ""
            echo "Actions:"
            echo "  check [user]           - Check basic permissions"
            echo "  diagnose <resource> <verb> [namespace] [user] - Diagnose access issue"
            echo "  role <name> [type] [namespace] - Check role configuration"
            echo "  bindings <subject> [type] [namespace] - Check role bindings"
            echo "  test-setup             - Create test scenarios"
            echo "  test                   - Run RBAC tests"
            echo "  report                 - Generate security report"
            echo "  all                    - Full troubleshooting (default)"
            echo ""
            echo "Examples:"
            echo "  $0 check"
            echo "  $0 diagnose pods create default system:serviceaccount:default:my-app"
            echo "  $0 role admin ClusterRole"
            echo "  $0 bindings my-app ServiceAccount default"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x rbac-troubleshooting.sh

# Запустить диагностику
./rbac-troubleshooting.sh all
```

## 📋 **Пошаговая методология troubleshooting:**

### **1. Определение проблемы:**
```bash
# Воспроизвести ошибку
kubectl get pods
# Error: pods is forbidden: User "john" cannot get resource "pods"

# Определить субъект (пользователь/ServiceAccount)
kubectl config current-context
kubectl config view --minify
```

### **2. Проверка базовых прав:**
```bash
# Проверить текущие права
kubectl auth can-i --list

# Проверить конкретное действие
kubectl auth can-i get pods
kubectl auth can-i create deployments -n production

# Проверить права от имени другого субъекта
kubectl auth can-i get pods --as=system:serviceaccount:default:my-app
```

### **3. Анализ ролей и привязок:**
```bash
# Найти роли пользователя
kubectl get rolebindings --all-namespaces -o wide | grep username
kubectl get clusterrolebindings -o wide | grep username

# Проверить содержимое роли
kubectl describe role my-role -n namespace
kubectl describe clusterrole my-clusterrole
```

## 🎯 **Практические команды для диагностики:**

### **Проверка прав доступа:**
```bash
# Базовая проверка
kubectl auth can-i create pods
kubectl auth can-i get secrets -n kube-system
kubectl auth can-i '*' '*' --all-namespaces

# Проверка от имени ServiceAccount
kubectl auth can-i get pods --as=system:serviceaccount:monitoring:prometheus

# Детальный список прав
kubectl auth can-i --list --as=system:serviceaccount:default:my-app
```

### **Анализ ролей:**
```bash
# Поиск ролей по имени
kubectl get roles --all-namespaces | grep my-role
kubectl get clusterroles | grep my-role

# Детальная информация о роли
kubectl describe role my-role -n namespace
kubectl get role my-role -n namespace -o yaml

# Поиск ролей с конкретными правами
kubectl get roles --all-namespaces -o json | jq '.items[] | select(.rules[].resources[] | contains("pods"))'
```

### **Анализ привязок:**
```bash
# Поиск привязок для пользователя
kubectl get rolebindings --all-namespaces -o json | jq '.items[] | select(.subjects[].name=="username")'

# Поиск привязок для ServiceAccount
kubectl get clusterrolebindings -o json | jq '.items[] | select(.subjects[].kind=="ServiceAccount" and .subjects[].name=="my-app")'

# Все привязки роли
kubectl get rolebindings --all-namespaces -o json | jq '.items[] | select(.roleRef.name=="admin")'
```

## 🔧 **Типичные проблемы и решения:**

### **1. Access Denied:**
```bash
# Проблема: User cannot get resource "pods"
# Решение: Создать роль и привязку
kubectl create role pod-reader --verb=get,list,watch --resource=pods
kubectl create rolebinding pod-reader-binding --role=pod-reader --user=username
```

### **2. ServiceAccount без прав:**
```bash
# Проблема: ServiceAccount не может выполнить действие
# Решение: Привязать подходящую роль
kubectl create rolebinding my-app-binding --clusterrole=edit --serviceaccount=default:my-app
```

### **3. Неправильная область действия:**
```bash
# Проблема: Role вместо ClusterRole для cluster-scoped ресурсов
# Решение: Использовать ClusterRole
kubectl create clusterrole node-reader --verb=get,list --resource=nodes
kubectl create clusterrolebinding node-reader-binding --clusterrole=node-reader --user=username
```

### **4. Конфликты ролей:**
```bash
# Проблема: Несколько ролей с противоречивыми правами
# Решение: Проанализировать все привязки и упростить
kubectl get rolebindings --all-namespaces -o json | jq '.items[] | select(.subjects[].name=="username")'
```

## 🛠️ **Инструменты для troubleshooting:**

### **kubectl auth can-i:**
```bash
# Самый важный инструмент для проверки прав
kubectl auth can-i <verb> <resource> [flags]

# Полезные флаги:
--list                    # Показать все права
--as=<user>              # Проверить от имени пользователя
--as-group=<group>       # Проверить от имени группы
-n <namespace>           # Указать namespace
--all-namespaces         # Проверить во всех namespace
```

### **Audit logs:**
```bash
# Включить audit logging в kube-apiserver
--audit-log-path=/var/log/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml

# Анализ audit logs
grep "forbidden" /var/log/audit.log
grep "user.*cannot" /var/log/audit.log
```

**Правильная диагностика RBAC проблем обеспечивает безопасность и функциональность кластера!**
