# 79. Принцип минимальных привилегий в Kubernetes RBAC

## 🎯 **Принцип минимальных привилегий в Kubernetes RBAC**

**Principle of Least Privilege (PoLP)** - это фундаментальный принцип безопасности, согласно которому пользователи, процессы и системы должны получать только минимальный набор прав, необходимый для выполнения их функций. В контексте Kubernetes RBAC это означает предоставление точно тех прав доступа, которые требуются для работы, и не более того.

## 🏗️ **Основные принципы PoLP в Kubernetes:**

### **Ключевые концепции:**
- **Минимальные права** - только необходимые разрешения
- **Временные права** - ограничение по времени
- **Контекстные права** - права в конкретном контексте
- **Регулярный аудит** - периодическая проверка и пересмотр

### **Уровни применения:**
- **User Level** - права пользователей
- **ServiceAccount Level** - права приложений
- **Namespace Level** - изоляция по namespace
- **Resource Level** - доступ к конкретным ресурсам

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих прав в кластере:**
```bash
# Проверить привилегированные привязки
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin")'

# Анализ прав ServiceAccounts
kubectl get serviceaccounts --all-namespaces
kubectl get rolebindings --all-namespaces -o wide
```

### **2. Создание comprehensive PoLP implementation:**
```bash
# Создать скрипт для реализации принципа минимальных привилегий
cat << 'EOF' > least-privilege-implementation.sh
#!/bin/bash

echo "=== Principle of Least Privilege Implementation ==="
echo "Implementing PoLP best practices in HashFoundry HA cluster"
echo

# Функция для анализа текущих привилегий
analyze_current_privileges() {
    echo "=== Current Privilege Analysis ==="
    
    echo "1. Cluster-admin bindings (HIGH RISK):"
    echo "======================================"
    kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | "Binding: \(.metadata.name), Subjects: \(.subjects | map(.kind + ":" + .name) | join(", "))"'
    echo
    
    echo "2. ServiceAccounts with cluster-wide permissions:"
    echo "==============================================="
    kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.subjects[]?.kind=="ServiceAccount") | "Binding: \(.metadata.name), Role: \(.roleRef.name), SA: \(.subjects[] | select(.kind=="ServiceAccount") | .namespace + "/" + .name)"'
    echo
    
    echo "3. Overprivileged roles (admin role usage):"
    echo "==========================================="
    kubectl get rolebindings --all-namespaces -o json | jq -r '.items[] | select(.roleRef.name=="admin") | "Namespace: \(.metadata.namespace), Binding: \(.metadata.name), Subjects: \(.subjects | map(.kind + ":" + .name) | join(", "))"'
    echo
    
    echo "4. Cross-namespace access patterns:"
    echo "=================================="
    kubectl get rolebindings --all-namespaces -o json | jq -r '.items[] | select(.subjects[]?.namespace != .metadata.namespace) | "Binding: \(.metadata.namespace)/\(.metadata.name), External Subject: \(.subjects[] | select(.namespace != null) | .namespace + "/" + .name)"'
    echo
}

# Функция для создания least-privilege roles
create_least_privilege_roles() {
    echo "=== Creating Least Privilege Roles ==="
    
    # Application-specific roles
    echo "Creating application-specific roles..."
    
    # Web application role - минимальные права для веб-приложения
    cat << WEBAPP_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-prod
  name: webapp-minimal-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/application: webapp
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Minimal privileges for web application"
    rbac.hashfoundry.io/review-date: "$(date -d '+3 months' +%Y-%m-%d)"
    rbac.hashfoundry.io/justification: "Web app needs only config and secret access"
rules:
# Только чтение собственных ConfigMaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["webapp-config", "webapp-env"]
# Только чтение собственных Secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["webapp-secret", "webapp-tls"]
# Создание events для логирования
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]
# Чтение собственного ServiceAccount
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get"]
  resourceNames: ["webapp-sa"]
---
# Database access role - права только для работы с БД
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-prod
  name: database-minimal-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/application: database
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Minimal privileges for database operations"
    rbac.hashfoundry.io/review-date: "$(date -d '+3 months' +%Y-%m-%d)"
    rbac.hashfoundry.io/justification: "Database needs config, secrets, and PVC access"
rules:
# Доступ к database ConfigMaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["db-config", "db-init-scripts"]
# Доступ к database Secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["db-credentials", "db-tls-certs"]
# Управление PersistentVolumeClaims для данных
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
  resourceNames: ["db-data-pvc", "db-backup-pvc"]
# Events для мониторинга
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]
---
# Monitoring role - права только для мониторинга
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-minimal-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/application: monitoring
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Minimal privileges for monitoring systems"
    rbac.hashfoundry.io/review-date: "$(date -d '+6 months' +%Y-%m-%d)"
    rbac.hashfoundry.io/justification: "Monitoring needs read-only access to metrics"
rules:
# Чтение метрик узлов
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "nodes/stats"]
  verbs: ["get", "list", "watch"]
# Чтение метрик pods
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
# Чтение services и endpoints для service discovery
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]
# Доступ к metrics API
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
# Чтение namespaces для организации метрик
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
# НЕТ доступа к secrets, configmaps, или изменению ресурсов
---
# CI/CD minimal role - права только для деплоя
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-prod
  name: cicd-deploy-minimal-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/application: cicd
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Minimal privileges for CI/CD deployment"
    rbac.hashfoundry.io/review-date: "$(date -d '+1 month' +%Y-%m-%d)"
    rbac.hashfoundry.io/justification: "CI/CD needs deployment and service management"
rules:
# Управление deployments
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
  resourceNames: ["webapp-deployment", "api-deployment"]
# Управление services
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
  resourceNames: ["webapp-service", "api-service"]
# Чтение pods для проверки статуса
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
# Создание ConfigMaps для конфигурации
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
  resourceNames: ["webapp-config", "api-config"]
# Events для логирования деплоя
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]
# НЕТ доступа к secrets, nodes, или cluster-scoped ресурсам
WEBAPP_ROLE_EOF
    
    echo "✅ Least privilege roles created"
    echo
}

# Функция для создания time-limited access
create_time_limited_access() {
    echo "=== Creating Time-Limited Access Patterns ==="
    
    # Создать роль для временного административного доступа
    cat << TEMP_ADMIN_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-prod
  name: temporary-admin-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/access-type: temporary
    rbac.hashfoundry.io/expires: "$(date -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Temporary administrative access - expires in 1 hour"
    rbac.hashfoundry.io/created-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    rbac.hashfoundry.io/expires-at: "$(date -d '+1 hour' -u +%Y-%m-%dT%H:%M:%SZ)"
    rbac.hashfoundry.io/justification: "Emergency troubleshooting access"
    rbac.hashfoundry.io/requested-by: "platform-admin"
rules:
# Полный доступ к namespace для troubleshooting
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
# Роль для временного доступа к логам
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-prod
  name: temporary-log-access-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/access-type: temporary
    rbac.hashfoundry.io/expires: "$(date -d '+30 minutes' +%Y-%m-%dT%H:%M:%SZ)"
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Temporary log access - expires in 30 minutes"
    rbac.hashfoundry.io/created-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    rbac.hashfoundry.io/expires-at: "$(date -d '+30 minutes' -u +%Y-%m-%dT%H:%M:%SZ)"
    rbac.hashfoundry.io/justification: "Debug application issues"
rules:
# Доступ к логам pods
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
# Доступ к events
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
TEMP_ADMIN_EOF
    
    # Создать скрипт для автоматического удаления expired ролей
    cat << CLEANUP_SCRIPT_EOF > cleanup-expired-roles.sh
#!/bin/bash

echo "=== Cleaning up expired RBAC roles ==="

# Найти роли с истекшим сроком действия
current_time=\$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Получить все роли с меткой expires
kubectl get roles --all-namespaces -l rbac.hashfoundry.io/access-type=temporary -o json | jq -r '.items[] | select(.metadata.labels."rbac.hashfoundry.io/expires" < "'"\$current_time"'") | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace role_name; do
    if [ -n "\$namespace" ] && [ -n "\$role_name" ]; then
        echo "Removing expired role: \$role_name in namespace \$namespace"
        kubectl delete role "\$role_name" -n "\$namespace"
        
        # Также удалить связанные RoleBindings
        kubectl get rolebindings -n "\$namespace" -o json | jq -r '.items[] | select(.roleRef.name=="'"\$role_name"'") | .metadata.name' | while read binding_name; do
            echo "Removing associated binding: \$binding_name"
            kubectl delete rolebinding "\$binding_name" -n "\$namespace"
        done
    fi
done

echo "✅ Cleanup completed"
CLEANUP_SCRIPT_EOF
    
    chmod +x cleanup-expired-roles.sh
    
    echo "✅ Time-limited access patterns created"
    echo "   - Use cleanup-expired-roles.sh to remove expired roles"
    echo
}

# Функция для создания context-specific access
create_context_specific_access() {
    echo "=== Creating Context-Specific Access ==="
    
    # Роли для разных сред
    for env in dev staging prod; do
        cat << ENV_SPECIFIC_EOF | kubectl apply -f -
# Environment-specific developer role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-$env
  name: $env-developer-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/environment: $env
    rbac.hashfoundry.io/access-level: developer
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Environment-specific developer access for $env"
    rbac.hashfoundry.io/environment-restrictions: "Only $env environment"
rules:
# Права зависят от среды
$(if [ "$env" = "dev" ]; then
cat << DEV_RULES
# Dev environment - полные права для экспериментов
- apiGroups: ["", "apps", "batch"]
  resources: ["*"]
  verbs: ["*"]
# Но НЕТ доступа к production secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  resourceNames: ["!prod-*", "!production-*"]
DEV_RULES
elif [ "$env" = "staging" ]; then
cat << STAGING_RULES
# Staging environment - ограниченные права
- apiGroups: ["", "apps"]
  resources: ["pods", "services", "deployments", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
  resourceNames: ["staging-*", "test-*"]
STAGING_RULES
else
cat << PROD_RULES
# Production environment - только чтение и ограниченные изменения
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "patch"]
  resourceNames: ["webapp-deployment"]
# НЕТ доступа к secrets в production
PROD_RULES
fi)
---
ENV_SPECIFIC_EOF
    done
    
    echo "✅ Context-specific access created for dev, staging, prod"
    echo
}

# Функция для создания resource-specific access
create_resource_specific_access() {
    echo "=== Creating Resource-Specific Access ==="
    
    # Создать namespace для демонстрации
    kubectl create namespace rbac-demo 2>/dev/null || true
    
    # Роли для конкретных ресурсов
    cat << RESOURCE_SPECIFIC_EOF | kubectl apply -f -
# Pod-only access role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-demo
  name: pod-only-access
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/resource-scope: pods-only
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Access only to specific pods"
rules:
# Доступ только к конкретным pods
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["webapp-pod-*", "api-pod-*"]
# Доступ к логам только этих pods
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
  resourceNames: ["webapp-pod-*", "api-pod-*"]
---
# ConfigMap-only access role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-demo
  name: configmap-only-access
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/resource-scope: configmaps-only
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Access only to application ConfigMaps"
rules:
# Доступ только к конкретным ConfigMaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
  resourceNames: ["app-config", "feature-flags", "env-config"]
---
# Secret read-only access role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-demo
  name: secret-readonly-access
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/resource-scope: secrets-readonly
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "Read-only access to specific secrets"
rules:
# Только чтение конкретных secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["app-secret", "db-readonly-secret"]
# НЕТ доступа к admin secrets или TLS certificates
RESOURCE_SPECIFIC_EOF
    
    echo "✅ Resource-specific access roles created"
    echo
}

# Функция для создания audit и compliance framework
create_audit_framework() {
    echo "=== Creating Audit and Compliance Framework ==="
    
    # Создать роль для аудита RBAC
    cat << AUDIT_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: rbac-auditor-role
  labels:
    rbac.hashfoundry.io/principle: least-privilege
    rbac.hashfoundry.io/purpose: audit
    app.kubernetes.io/name: hashfoundry-rbac
  annotations:
    description: "RBAC auditor role for compliance checking"
rules:
# Чтение всех RBAC ресурсов
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
# Чтение ServiceAccounts
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get", "list", "watch"]
# Чтение namespaces
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
# НЕТ прав на изменение или доступ к другим ресурсам
AUDIT_ROLE_EOF
    
    # Создать скрипт для аудита соблюдения PoLP
    cat << AUDIT_SCRIPT_EOF > polp-audit.sh
#!/bin/bash

echo "=== Principle of Least Privilege Audit ==="
echo "Auditing RBAC compliance in HashFoundry HA cluster"
echo

# Функция для проверки overprivileged bindings
check_overprivileged_bindings() {
    echo "1. Checking for overprivileged bindings:"
    echo "======================================="
    
    # Cluster-admin bindings
    echo "Cluster-admin bindings:"
    kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | "⚠️  HIGH RISK: \(.metadata.name) -> \(.subjects | map(.kind + ":" + (.namespace // "cluster") + "/" + .name) | join(", "))"'
    
    # Admin role bindings
    echo "Admin role bindings:"
    kubectl get rolebindings --all-namespaces -o json | jq -r '.items[] | select(.roleRef.name=="admin") | "⚠️  MEDIUM RISK: \(.metadata.namespace)/\(.metadata.name) -> \(.subjects | map(.kind + ":" + .name) | join(", "))"'
    
    echo
}

# Функция для проверки unused permissions
check_unused_permissions() {
    echo "2. Checking for potentially unused permissions:"
    echo "=============================================="
    
    # Роли с широкими правами
    echo "Roles with wildcard permissions:"
    kubectl get roles --all-namespaces -o json | jq -r '.items[] | select(.rules[] | select(.verbs[] == "*" or .resources[] == "*" or .apiGroups[] == "*")) | "⚠️  \(.metadata.namespace)/\(.metadata.name) has wildcard permissions"'
    
    kubectl get clusterroles -o json | jq -r '.items[] | select(.rules[] | select(.verbs[] == "*" or .resources[] == "*" or .apiGroups[] == "*")) | select(.metadata.name | startswith("system:") | not) | "⚠️  ClusterRole \(.metadata.name) has wildcard permissions"'
    
    echo
}

# Функция для проверки cross-namespace access
check_cross_namespace_access() {
    echo "3. Checking for cross-namespace access:"
    echo "======================================"
    
    kubectl get rolebindings --all-namespaces -o json | jq -r '.items[] | select(.subjects[]? | select(.namespace != null and .namespace != .metadata.namespace)) | "⚠️  Cross-namespace access: \(.metadata.namespace)/\(.metadata.name) references \(.subjects[] | select(.namespace != null) | .namespace + "/" + .name)"'
    
    echo
}

# Функция для проверки ServiceAccount permissions
check_serviceaccount_permissions() {
    echo "4. Checking ServiceAccount permissions:"
    echo "======================================"
    
    # ServiceAccounts с cluster-wide правами
    echo "ServiceAccounts with cluster-wide permissions:"
    kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.subjects[]?.kind=="ServiceAccount") | "SA: \(.subjects[] | select(.kind=="ServiceAccount") | .namespace + "/" + .name) -> ClusterRole: \(.roleRef.name)"'
    
    echo
}

# Функция для генерации рекомендаций
generate_recommendations() {
    echo "5. PoLP Compliance Recommendations:"
    echo "=================================="
    
    echo "✅ RECOMMENDED ACTIONS:"
    echo "1. Review and minimize cluster-admin bindings"
    echo "2. Replace admin role with more specific roles where possible"
    echo "3. Eliminate wildcard permissions in custom roles"
    echo "4. Implement time-limited access for administrative tasks"
    echo "5. Use resource-specific roles instead of broad permissions"
    echo "6. Regular audit and cleanup of unused roles and bindings"
    echo "7. Implement just-in-time access for sensitive operations"
    echo
    
    echo "📋 COMPLIANCE CHECKLIST:"
    echo "□ All ServiceAccounts have minimal required permissions"
    echo "□ No unnecessary cluster-admin bindings exist"
    echo "□ Roles are scoped to specific resources and verbs"
    echo "□ Cross-namespace access is justified and documented"
    echo "□ Temporary access roles have expiration dates"
    echo "□ Regular RBAC audits are performed"
    echo "□ Role assignments are reviewed quarterly"
    echo
}

# Запустить все проверки
check_overprivileged_bindings
check_unused_permissions
check_cross_namespace_access
check_serviceaccount_permissions
generate_recommendations

AUDIT_SCRIPT_EOF
    
    chmod +x polp-audit.sh
    
    echo "✅ Audit framework created"
    echo "   - Use polp-audit.sh to check PoLP compliance"
    echo
}

# Функция для создания best practices examples
create_best_practices_examples() {
    echo "=== Creating Best Practices Examples ==="
    
    # Создать примеры правильного применения PoLP
    cat << BEST_PRACTICES_EOF > polp-best-practices.md
# Principle of Least Privilege - Best Practices

## ✅ GOOD Examples

### 1. Application-Specific ServiceAccount
\`\`\`yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: webapp-minimal-role
rules:
# Only access to own ConfigMap
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
  resourceNames: ["webapp-config"]
# Only access to own Secret
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["webapp-secret"]
\`\`\`

### 2. Time-Limited Administrative Access
\`\`\`yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: emergency-access-role
  annotations:
    rbac.hashfoundry.io/expires-at: "2024-01-01T12:00:00Z"
    rbac.hashfoundry.io/justification: "Emergency debugging"
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
\`\`\`

### 3. Environment-Specific Permissions
\`\`\`yaml
# Development environment - more permissive
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: dev-role
rules:
- apiGroups: ["", "apps"]
  resources: ["*"]
  verbs: ["*"]

# Production environment - restrictive
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: prod-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
\`\`\`

## ❌ BAD Examples

### 1. Overprivileged ServiceAccount
\`\`\`yaml
# DON'T DO THIS
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: webapp-admin
subjects:
- kind: ServiceAccount
  name: webapp-sa
  namespace: production
roleRef:
  kind: ClusterRole
  name: cluster-admin  # TOO MUCH PRIVILEGE!
\`\`\`

### 2. Wildcard Permissions
\`\`\`yaml
# DON'T DO THIS
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bad-role
rules:
- apiGroups: ["*"]     # TOO BROAD!
  resources: ["*"]     # TOO BROAD!
  verbs: ["*"]         # TOO BROAD!
\`\`\`

## 🔧 Implementation Guidelines

1. **Start with minimal permissions** and add only what's needed
2. **Use specific resource names** instead of wildcards
3. **Scope roles to namespaces** unless cluster access is required
4. **Implement time limits** for administrative access
5. **Regular audit and cleanup** of permissions
6. **Document justifications** for all permissions
7. **Use automation** to enforce PoLP policies

_PRACTICES_EOF
    
    echo "✅ Best practices examples created"
    echo "   - See polp-best-practices.md for detailed examples"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_privileges
            ;;
        "create-roles")
            create_least_privilege_roles
            ;;
        "time-limited")
            create_time_limited_access
            ;;
        "context-specific")
            create_context_specific_access
            ;;
        "resource-specific")
            create_resource_specific_access
            ;;
        "audit")
            create_audit_framework
            ;;
        "examples")
            create_best_practices_examples
            ;;
        "all"|"")
            analyze_current_privileges
            create_least_privilege_roles
            create_time_limited_access
            create_context_specific_access
            create_resource_specific_access
            create_audit_framework
            create_best_practices_examples
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze           - Analyze current privilege levels"
            echo "  create-roles      - Create least privilege roles"
            echo "  time-limited      - Create time-limited access patterns"
            echo "  context-specific  - Create context-specific roles"
            echo "  resource-specific - Create resource-specific roles"
            echo "  audit             - Create audit framework"
            echo "  examples          - Create best practices examples"
            echo "  all               - Full PoLP implementation (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 audit"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x least-privilege-implementation.sh

# Запустить реализацию PoLP
./least-privilege-implementation.sh all
```

## 📋 **Основные принципы PoLP в действии:**

### **1. Минимальные права:**
```bash
# ✅ ПРАВИЛЬНО: Конкретные права
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: webapp-role
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
  resourceNames: ["webapp-config"]

# ❌ НЕПРАВИЛЬНО: Широкие права
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

### **2. Временные права:**
```bash
# Роль с ограничением по времени
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: emergency-access
  annotations:
    rbac.hashfoundry.io/expires-at: "2024-01-01T12:00:00Z"
    rbac.hashfoundry.io/justification: "Emergency debugging"
```

### **3. Контекстные права:**
```bash
# Разные права для разных сред
# Dev: полные права для экспериментов
# Staging: ограниченные права для тестирования
# Prod: минимальные права только для работы
```

## 🎯 **Практические команды:**

### **Анализ текущих прав:**
```bash
# Найти overprivileged bindings
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin")'

# Проверить права ServiceAccount
kubectl auth can-i --list --as=system:serviceaccount:default:my-app

# Найти роли с wildcard правами
kubectl get roles --all-namespaces -o json | jq '.items[] | select(.rules[] | select(.verbs[] == "*"))'
```

### **Создание minimal roles:**
```bash
# Создать роль только для чтения pods
kubectl create role pod-reader --verb=get,list,watch --resource=pods

# Создать роль только для конкретного ConfigMap
kubectl create role config-reader --verb=get --resource=configmaps --resource-name=my-config

# Привязать роль к ServiceAccount
kubectl create rolebinding my-app-binding --role=pod-reader --serviceaccount=default:my-app
```

### **Аудит соблюдения PoLP:**
```bash
# Проверить все cluster-admin привязки
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# Найти ServiceAccounts с cluster-wide правами
kubectl get clusterrolebindings -o json | jq '.items[] | select(.subjects[]?.kind=="ServiceAccount")'

# Проверить cross-namespace доступ
kubectl get rolebindings --all-namespaces -o json | jq '.items[] | select(.subjects[]?.namespace != .metadata.namespace)'
```

## 🔧 **Best Practices для PoLP:**

### **Проектирование ролей:**
- **Начинать с минимума** - давать только необходимые права
- **Использовать resourceNames** - ограничивать доступ к конкретным ресурсам
- **Избегать wildcards** - не использовать "*" без крайней необходимости
- **Документировать обоснования** - объяснять зачем нужны права

### **Управление доступом:**
- **Временные права** - использовать expiration dates для административного доступа
- **Контекстные права** - разные права для dev/staging/prod
- **Регулярный аудит** - проверять и очищать неиспользуемые права
- **Автоматизация** - использовать скрипты для контроля соблюдения PoLP

### **Мониторинг и аудит:**
- **Логирование доступа** - включить audit logging
- **Алерты на привилегированный доступ** - мониторить использование cluster-admin
- **Периодический review** - регулярно пересматривать права
- **Compliance отчеты** - генерировать отчеты о соблюдении PoLP

**Принцип минимальных привилегий - основа безопасной архитектуры Kubernetes!**
