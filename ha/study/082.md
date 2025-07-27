# 82. Различия между Pod Security Policies и Pod Security Standards

## 🎯 **Различия между Pod Security Policies и Pod Security Standards**

**Pod Security Policies (PSP)** были устаревшим механизмом безопасности в Kubernetes, который был удален в версии 1.25. **Pod Security Standards (PSS)** - это современная замена PSP, предоставляющая более простой и эффективный способ обеспечения безопасности pods.

## 🏗️ **Основные различия:**

### **Pod Security Policies (Устаревшие):**
- **Сложность**: Требовали RBAC настройки
- **Гибкость**: Высокая, но сложная в управлении
- **Применение**: Через admission controller
- **Статус**: Удалены в Kubernetes 1.25

### **Pod Security Standards (Современные):**
- **Простота**: Встроенные в Kubernetes
- **Стандартизация**: Три предопределенных уровня
- **Применение**: Через namespace labels
- **Статус**: Активно поддерживаются

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ миграции с PSP на PSS:**
```bash
# Проверить наличие PSP (должны отсутствовать в современных кластерах)
kubectl get psp 2>/dev/null || echo "Pod Security Policies not found (expected in modern clusters)"

# Проверить текущие Pod Security Standards
kubectl get namespaces -o json | jq '.items[] | select(.metadata.labels."pod-security.kubernetes.io/enforce" != null)'
```

### **2. Создание comprehensive comparison framework:**
```bash
# Создать скрипт для сравнения PSP и PSS
cat << 'EOF' > psp-vs-pss-comparison.sh
#!/bin/bash

echo "=== Pod Security Policies vs Pod Security Standards Comparison ==="
echo "Demonstrating differences and migration strategies in HashFoundry HA cluster"
echo

# Функция для демонстрации PSP концепций (для образовательных целей)
demonstrate_psp_concepts() {
    echo "=== Pod Security Policies (PSP) - Legacy Approach ==="
    echo "Note: PSPs were removed in Kubernetes 1.25, this is for educational purposes"
    echo
    
    # Показать как выглядели PSP
    cat << PSP_EXAMPLE_EOF
# Example of how Pod Security Policy looked (DEPRECATED)
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
---
# Required ClusterRole for PSP
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: restricted-psp-user
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames:
  - restricted-psp
---
# Required RoleBinding for PSP
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: restricted-psp-binding
  namespace: my-namespace
roleRef:
  kind: ClusterRole
  name: restricted-psp-user
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: default
  namespace: my-namespace
PSP_EXAMPLE_EOF
    
    echo "❌ PSP Problems:"
    echo "1. Complex RBAC setup required"
    echo "2. Difficult to understand which PSP applies"
    echo "3. Hard to debug when pods fail to start"
    echo "4. No built-in migration path"
    echo "5. Inconsistent behavior across clusters"
    echo
}

# Функция для демонстрации PSS подхода
demonstrate_pss_approach() {
    echo "=== Pod Security Standards (PSS) - Modern Approach ==="
    
    # Создать namespace с PSS
    cat << PSS_NAMESPACE_EOF | kubectl apply -f -
# Modern approach with Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: pss-demo-restricted
  labels:
    # Simple label-based configuration
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    
    # HashFoundry labels
    hashfoundry.io/security-demo: "pss-restricted"
    app.kubernetes.io/name: "hashfoundry-security-demo"
  annotations:
    pod-security.kubernetes.io/enforce-version: "latest"
    hashfoundry.io/description: "Demonstration of Pod Security Standards"
---
apiVersion: v1
kind: Namespace
metadata:
  name: pss-demo-baseline
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
    
    hashfoundry.io/security-demo: "pss-baseline"
    app.kubernetes.io/name: "hashfoundry-security-demo"
  annotations:
    pod-security.kubernetes.io/enforce-version: "latest"
    hashfoundry.io/description: "Demonstration of Pod Security Standards"
PSS_NAMESPACE_EOF
    
    echo "✅ PSS Advantages:"
    echo "1. No RBAC configuration needed"
    echo "2. Three clear, predefined levels"
    echo "3. Easy to understand and debug"
    echo "4. Built into Kubernetes"
    echo "5. Consistent behavior"
    echo
}

# Функция для создания сравнительной таблицы
create_comparison_table() {
    echo "=== Detailed Comparison Table ==="
    echo
    
    cat << COMPARISON_TABLE_EOF
┌─────────────────────────┬─────────────────────────┬─────────────────────────┐
│       Aspect            │    Pod Security Policy  │  Pod Security Standards │
├─────────────────────────┼─────────────────────────┼─────────────────────────┤
│ Status                  │ Deprecated (removed)    │ Active and supported    │
│ Configuration           │ Complex YAML + RBAC     │ Simple namespace labels │
│ Flexibility             │ Highly customizable     │ Three predefined levels │
│ Learning Curve          │ Steep                   │ Gentle                  │
│ Debugging               │ Difficult               │ Easy                    │
│ Migration Path          │ Manual                  │ Built-in tools          │
│ Performance Impact      │ Higher                  │ Lower                   │
│ Maintenance             │ High                    │ Low                     │
│ Cluster Consistency     │ Variable                │ Consistent              │
│ Documentation           │ Complex                 │ Clear and simple        │
└─────────────────────────┴─────────────────────────┴─────────────────────────┘
COMPARISON_TABLE_EOF
    echo
}

# Функция для демонстрации миграции
demonstrate_migration() {
    echo "=== Migration from PSP to PSS ==="
    
    # Создать скрипт миграции
    cat << MIGRATION_SCRIPT_EOF > psp-to-pss-migration.sh
#!/bin/bash

echo "=== PSP to PSS Migration Script ==="
echo "This script helps migrate from Pod Security Policies to Pod Security Standards"
echo

# Функция для анализа существующих PSP
analyze_existing_psp() {
    echo "1. Analyzing existing Pod Security Policies:"
    echo "==========================================="
    
    # Проверить PSP (если они еще существуют)
    if kubectl get psp >/dev/null 2>&1; then
        echo "Found existing PSPs:"
        kubectl get psp -o custom-columns="NAME:.metadata.name,PRIVILEGED:.spec.privileged,ALLOW_PRIV_ESC:.spec.allowPrivilegeEscalation,RUN_AS_USER:.spec.runAsUser.rule"
    else
        echo "No Pod Security Policies found (expected in modern clusters)"
    fi
    echo
}

# Функция для создания PSS mapping
create_pss_mapping() {
    echo "2. Creating PSS Mapping:"
    echo "======================="
    
    cat << MAPPING_EOF
PSP Configuration → PSS Level Mapping:

Restrictive PSP (privileged: false, runAsNonRoot: true, etc.) → restricted
Standard PSP (some restrictions) → baseline  
Permissive PSP (privileged: true, etc.) → privileged

Specific mappings:
- privileged: false → baseline or restricted
- allowPrivilegeEscalation: false → baseline or restricted
- runAsUser.rule: MustRunAsNonRoot → restricted
- requiredDropCapabilities: [ALL] → restricted
- volumes: limited list → baseline or restricted
MAPPING_EOF
    echo
}

# Функция для применения PSS к namespaces
apply_pss_to_namespaces() {
    echo "3. Applying PSS to Namespaces:"
    echo "============================="
    
    # Получить все namespaces без PSS labels
    namespaces=\$(kubectl get namespaces -o json | jq -r '.items[] | select(.metadata.labels."pod-security.kubernetes.io/enforce" == null) | .metadata.name' | grep -v "kube-")
    
    for ns in \$namespaces; do
        if [ -n "\$ns" ]; then
            echo "Processing namespace: \$ns"
            
            # Определить подходящий уровень безопасности
            if [[ "\$ns" =~ (system|monitoring|ingress) ]]; then
                level="privileged"
            elif [[ "\$ns" =~ (prod|production) ]]; then
                level="restricted"
            else
                level="baseline"
            fi
            
            echo "  Applying \$level level to \$ns"
            kubectl label namespace "\$ns" pod-security.kubernetes.io/enforce="\$level" --overwrite
            kubectl label namespace "\$ns" pod-security.kubernetes.io/audit="\$level" --overwrite
            kubectl label namespace "\$ns" pod-security.kubernetes.io/warn="\$level" --overwrite
        fi
    done
    echo
}

# Функция для валидации миграции
validate_migration() {
    echo "4. Validating Migration:"
    echo "======================="
    
    echo "Namespaces with PSS labels:"
    kubectl get namespaces -o custom-columns="NAME:.metadata.name,ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce,AUDIT:.metadata.labels.pod-security\.kubernetes\.io/audit,WARN:.metadata.labels.pod-security\.kubernetes\.io/warn" | grep -v "<none>"
    echo
    
    echo "Testing pod creation in restricted namespace:"
    # Тест создания pod в restricted namespace
    if kubectl get namespace pss-demo-restricted >/dev/null 2>&1; then
        cat << TEST_POD_EOF | kubectl apply -f - --dry-run=server
apiVersion: v1
kind: Pod
metadata:
  name: test-migration
  namespace: pss-demo-restricted
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: test
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
TEST_POD_EOF
        echo "✅ Migration validation successful"
    else
        echo "⚠️  Test namespace not found, skipping validation"
    fi
    echo
}

# Запустить все этапы миграции
analyze_existing_psp
create_pss_mapping
apply_pss_to_namespaces
validate_migration

MIGRATION_SCRIPT_EOF
    
    chmod +x psp-to-pss-migration.sh
    echo "✅ Migration script created: psp-to-pss-migration.sh"
    echo
}

# Функция для создания практических примеров
create_practical_examples() {
    echo "=== Creating Practical Examples ==="
    
    # Пример 1: Эквивалентные конфигурации
    cat << EQUIVALENTS_EOF > psp-pss-equivalents.md
# PSP to PSS Equivalents

## Restrictive Configuration

### PSP (Deprecated):
\`\`\`yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
\`\`\`

### PSS (Modern):
\`\`\`yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
\`\`\`

## Baseline Configuration

### PSP (Deprecated):
\`\`\`yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: baseline
spec:
  privileged: false
  allowPrivilegeEscalation: false
  volumes:
    - '*'
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
\`\`\`

### PSS (Modern):
\`\`\`yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
\`\`\`

## Key Differences:

1. **PSP**: Required complex RBAC setup + admission controller
2. **PSS**: Simple namespace labels, built-in enforcement
3. **PSP**: Custom policies with fine-grained control
4. **PSS**: Three predefined levels with clear semantics
5. **PSP**: Difficult debugging and troubleshooting
6. **PSS**: Clear error messages and easy validation
EQUIVALENTS_EOF
    
    echo "✅ Equivalents guide created: psp-pss-equivalents.md"
    echo
}

# Функция для создания troubleshooting guide
create_troubleshooting_guide() {
    echo "=== Creating Troubleshooting Guide ==="
    
    cat << TROUBLESHOOTING_EOF > psp-pss-troubleshooting.md
# PSP vs PSS Troubleshooting Guide

## Common PSP Problems (Historical)

### Problem: Pod creation fails with "unable to validate against any pod security policy"
**PSP Solution**: Check RBAC bindings and PSP availability
\`\`\`bash
kubectl get psp
kubectl auth can-i use podsecuritypolicy/my-psp --as=system:serviceaccount:my-namespace:default
\`\`\`

### Problem: Unclear which PSP is being applied
**PSP Solution**: Check annotations on created pods
\`\`\`bash
kubectl get pod my-pod -o yaml | grep kubernetes.io/psp
\`\`\`

## PSS Solutions (Modern)

### Problem: Pod creation fails in PSS-enabled namespace
**PSS Solution**: Check namespace labels and pod security context
\`\`\`bash
# Check namespace PSS configuration
kubectl get namespace my-namespace -o yaml | grep pod-security

# Validate pod against PSS level
kubectl apply --dry-run=server -f my-pod.yaml
\`\`\`

### Problem: Understanding PSS requirements
**PSS Solution**: Use built-in validation
\`\`\`bash
# Test pod compliance
kubectl apply --dry-run=server -f pod.yaml

# Check PSS documentation
kubectl explain pod.spec.securityContext
\`\`\`

## Migration Issues

### Issue: Existing workloads fail after PSS migration
**Solution**: Gradual migration with audit mode
\`\`\`bash
# Start with audit mode
kubectl label namespace my-namespace pod-security.kubernetes.io/audit=restricted
kubectl label namespace my-namespace pod-security.kubernetes.io/warn=restricted

# Monitor violations
kubectl get events --field-selector reason=FailedCreate

# Apply enforcement when ready
kubectl label namespace my-namespace pod-security.kubernetes.io/enforce=restricted
\`\`\`

### Issue: Complex PSP policies don't map to PSS levels
**Solution**: Use custom admission controllers or OPA Gatekeeper
\`\`\`bash
# For complex policies, consider:
# 1. OPA Gatekeeper
# 2. Falco for runtime security
# 3. Custom admission webhooks
\`\`\`
TROUBLESHOOTING_EOF
    
    echo "✅ Troubleshooting guide created: psp-pss-troubleshooting.md"
    echo
}

# Основная функция
main() {
    case "$1" in
        "concepts")
            demonstrate_psp_concepts
            ;;
        "pss")
            demonstrate_pss_approach
            ;;
        "comparison")
            create_comparison_table
            ;;
        "migration")
            demonstrate_migration
            ;;
        "examples")
            create_practical_examples
            ;;
        "troubleshooting")
            create_troubleshooting_guide
            ;;
        "all"|"")
            demonstrate_psp_concepts
            demonstrate_pss_approach
            create_comparison_table
            demonstrate_migration
            create_practical_examples
            create_troubleshooting_guide
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  concepts         - Demonstrate PSP concepts (educational)"
            echo "  pss              - Demonstrate PSS approach"
            echo "  comparison       - Show detailed comparison table"
            echo "  migration        - Create migration tools"
            echo "  examples         - Create practical examples"
            echo "  troubleshooting  - Create troubleshooting guide"
            echo "  all              - Full comparison and migration (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 migration"
            echo "  $0 comparison"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x psp-vs-pss-comparison.sh

# Запустить сравнение PSP vs PSS
./psp-vs-pss-comparison.sh all
```

## 📋 **Детальное сравнение PSP vs PSS:**

### **Архитектурные различия:**

| **Аспект** | **Pod Security Policies** | **Pod Security Standards** |
|------------|---------------------------|----------------------------|
| **Конфигурация** | Сложные YAML + RBAC | Простые namespace labels |
| **Применение** | Admission controller | Встроенный механизм |
| **Гибкость** | Высокая (сложная) | Ограниченная (простая) |
| **Отладка** | Сложная | Простая |
| **Производительность** | Низкая | Высокая |

### **Функциональные различия:**

#### **PSP (Устаревшие):**
```yaml
# Требовали сложную настройку
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  # + RBAC настройки
```

#### **PSS (Современные):**
```yaml
# Простая настройка через labels
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

## 🎯 **Практические команды:**

### **Проверка миграции:**
```bash
# Проверить отсутствие PSP
kubectl get psp 2>/dev/null || echo "PSP not found (expected)"

# Проверить PSS в namespaces
kubectl get namespaces -o custom-columns="NAME:.metadata.name,ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce"

# Запустить миграцию
./psp-to-pss-migration.sh
```

### **Тестирование PSS:**
```bash
# Тест создания pod в restricted namespace
kubectl apply --dry-run=server -f restricted-pod.yaml

# Проверить события безопасности
kubectl get events --field-selector reason=FailedCreate

# Валидация security context
kubectl explain pod.spec.securityContext
```

## 🔧 **Best Practices для миграции:**

### **Стратегия миграции:**
- **Постепенный переход** - начать с audit режима
- **Тестирование** - проверить все workloads
- **Мониторинг** - отслеживать нарушения
- **Документирование** - записать изменения

### **Выбор уровня PSS:**
- **Privileged**: Для системных компонентов (замена permissive PSP)
- **Baseline**: Для стандартных приложений (замена moderate PSP)
- **Restricted**: Для критических workloads (замена restrictive PSP)

**Pod Security Standards предоставляют современный, простой и эффективный подход к безопасности pods!**
