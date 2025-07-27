# 74. Role vs ClusterRole в Kubernetes

## 🎯 **Role vs ClusterRole в Kubernetes**

**Role** и **ClusterRole** - это два типа ролей в RBAC системе Kubernetes, которые определяют разрешения для доступа к ресурсам. Основное различие заключается в области действия (scope): Role работает в рамках конкретного namespace, а ClusterRole действует на уровне всего кластера.

## 🏗️ **Основные различия:**

### **Role (Namespace-scoped):**
- **Область действия**: Только в рамках одного namespace
- **Ресурсы**: Namespace-scoped ресурсы (pods, services, deployments)
- **Использование**: Для изоляции прав в конкретном namespace
- **Безопасность**: Более безопасно для ограниченного доступа

### **ClusterRole (Cluster-scoped):**
- **Область действия**: Весь кластер
- **Ресурсы**: Cluster-scoped ресурсы (nodes, namespaces, clusterroles)
- **Использование**: Для системных операций и кросс-namespace доступа
- **Гибкость**: Может использоваться с RoleBinding для namespace-specific доступа

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих ролей:**
```bash
# Проверить Role и ClusterRole в кластере
kubectl get roles --all-namespaces
kubectl get clusterroles

# Анализ различий в scope
echo "=== Role vs ClusterRole Analysis in HA Cluster ==="
echo "Namespace-scoped Roles:"
kubectl get roles --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,CREATED:.metadata.creationTimestamp"

echo "Cluster-scoped Roles:"
kubectl get clusterroles -o custom-columns="NAME:.metadata.name,CREATED:.metadata.creationTimestamp" | head -10

# Проверить ресурсы, к которым дают доступ
kubectl describe role -n kube-system | head -20
kubectl describe clusterrole cluster-admin | head -20
```

### **2. Создание comprehensive demonstration:**
```bash
# Создать скрипт для демонстрации различий Role vs ClusterRole
cat << 'EOF' > role-vs-clusterrole-demo.sh
#!/bin/bash

echo "=== Role vs ClusterRole Demonstration ==="
echo "Demonstrating differences between Role and ClusterRole in HashFoundry HA cluster"
echo

# Функция для создания namespace-specific roles
create_namespace_roles() {
    local namespace=$1
    
    echo "=== Creating Namespace-Specific Roles for: $namespace ==="
    
    # Pod Manager Role - только для pods в namespace
    cat << POD_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: pod-manager
  labels:
    scope: namespace
    resource-type: pods
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Manage pods only in $namespace namespace"
    scope: "namespace-specific"
    example-usage: "kubectl get pods -n $namespace"
rules:
# Pods - полный доступ только в этом namespace
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/portforward"]
  verbs: ["create"]
---
# Service Manager Role - только для services в namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: service-manager
  labels:
    scope: namespace
    resource-type: services
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Manage services only in $namespace namespace"
    scope: "namespace-specific"
rules:
# Services - полный доступ только в этом namespace
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Deployment Manager Role - только для deployments в namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: deployment-manager
  labels:
    scope: namespace
    resource-type: deployments
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Manage deployments only in $namespace namespace"
    scope: "namespace-specific"
rules:
# Deployments и ReplicaSets - полный доступ только в этом namespace
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments/scale"]
  verbs: ["update", "patch"]
---
# ConfigMap and Secret Reader Role - только чтение в namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: config-reader
  labels:
    scope: namespace
    resource-type: config
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Read configuration only in $namespace namespace"
    scope: "namespace-specific"
rules:
# ConfigMaps и Secrets - только чтение в этом namespace
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
POD_ROLE_EOF
    
    echo "✅ Namespace-specific roles created for $namespace"
    echo "   - pod-manager: Manage pods in $namespace"
    echo "   - service-manager: Manage services in $namespace"
    echo "   - deployment-manager: Manage deployments in $namespace"
    echo "   - config-reader: Read configs in $namespace"
    echo
}

# Функция для создания cluster-wide roles
create_cluster_roles() {
    echo "=== Creating Cluster-Wide Roles ==="
    
    # Node Reader ClusterRole - доступ к nodes (cluster-scoped ресурс)
    cat << NODE_ROLE_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-node-reader
  labels:
    scope: cluster
    resource-type: nodes
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Read access to cluster nodes"
    scope: "cluster-wide"
    example-usage: "kubectl get nodes"
rules:
# Nodes - только чтение (cluster-scoped ресурс)
- apiGroups: [""]
  resources: ["nodes", "nodes/status", "nodes/metrics"]
  verbs: ["get", "list", "watch"]
# Node metrics
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes"]
  verbs: ["get", "list"]
---
# Namespace Manager ClusterRole - управление namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-namespace-manager
  labels:
    scope: cluster
    resource-type: namespaces
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Manage namespaces across the cluster"
    scope: "cluster-wide"
    example-usage: "kubectl create namespace test"
rules:
# Namespaces - полный доступ (cluster-scoped ресурс)
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Storage Manager ClusterRole - управление storage classes и PV
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-storage-manager
  labels:
    scope: cluster
    resource-type: storage
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Manage cluster storage resources"
    scope: "cluster-wide"
    example-usage: "kubectl get storageclass"
rules:
# Storage Classes - полный доступ (cluster-scoped ресурс)
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Persistent Volumes - полный доступ (cluster-scoped ресурс)
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Cross-Namespace Pod Reader ClusterRole - чтение pods во всех namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-cross-namespace-pod-reader
  labels:
    scope: cluster
    resource-type: pods
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Read pods across all namespaces"
    scope: "cluster-wide"
    example-usage: "kubectl get pods --all-namespaces"
rules:
# Pods - только чтение во всех namespaces
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status"]
  verbs: ["get", "list", "watch"]
# Events - только чтение во всех namespaces
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
---
# RBAC Manager ClusterRole - управление RBAC ресурсами
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-rbac-manager
  labels:
    scope: cluster
    resource-type: rbac
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Manage RBAC resources across the cluster"
    scope: "cluster-wide"
    example-usage: "kubectl get clusterroles"
rules:
# RBAC ресурсы - полный доступ (cluster-scoped ресурсы)
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# ServiceAccounts - полный доступ
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
NODE_ROLE_EOF
    
    echo "✅ Cluster-wide roles created:"
    echo "   - hashfoundry-node-reader: Read cluster nodes"
    echo "   - hashfoundry-namespace-manager: Manage namespaces"
    echo "   - hashfoundry-storage-manager: Manage storage resources"
    echo "   - hashfoundry-cross-namespace-pod-reader: Read pods across namespaces"
    echo "   - hashfoundry-rbac-manager: Manage RBAC resources"
    echo
}

# Функция для создания ServiceAccounts для демонстрации
create_demo_service_accounts() {
    local namespace=$1
    
    echo "=== Creating Demo ServiceAccounts for: $namespace ==="
    
    cat << SA_EOF | kubectl apply -f -
# ServiceAccount для namespace-specific операций
apiVersion: v1
kind: ServiceAccount
metadata:
  name: namespace-worker
  namespace: $namespace
  labels:
    scope: namespace
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "ServiceAccount for namespace-specific operations"
    scope: "namespace-only"
---
# ServiceAccount для cluster-wide операций
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-worker
  namespace: $namespace
  labels:
    scope: cluster
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "ServiceAccount for cluster-wide operations"
    scope: "cluster-wide"
---
# ServiceAccount для cross-namespace операций
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cross-namespace-worker
  namespace: $namespace
  labels:
    scope: cross-namespace
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "ServiceAccount for cross-namespace operations"
    scope: "cross-namespace"
SA_EOF
    
    echo "✅ Demo ServiceAccounts created for $namespace"
    echo
}

# Функция для создания RoleBindings и ClusterRoleBindings
create_demo_bindings() {
    local namespace=$1
    
    echo "=== Creating Demo Bindings for: $namespace ==="
    
    # RoleBindings - привязка Role к ServiceAccount в namespace
    cat << RB_EOF | kubectl apply -f -
# Bind namespace Role to namespace ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-worker-pod-manager
  namespace: $namespace
  labels:
    binding-type: role-to-serviceaccount
    scope: namespace
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Bind pod-manager Role to namespace-worker ServiceAccount"
    scope: "namespace-specific"
subjects:
- kind: ServiceAccount
  name: namespace-worker
  namespace: $namespace
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: rbac.authorization.k8s.io
---
# Bind namespace Role to namespace ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-worker-service-manager
  namespace: $namespace
  labels:
    binding-type: role-to-serviceaccount
    scope: namespace
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Bind service-manager Role to namespace-worker ServiceAccount"
subjects:
- kind: ServiceAccount
  name: namespace-worker
  namespace: $namespace
roleRef:
  kind: Role
  name: service-manager
  apiGroup: rbac.authorization.k8s.io
---
# Bind ClusterRole to ServiceAccount using RoleBinding (namespace-scoped)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cross-namespace-worker-pod-reader
  namespace: $namespace
  labels:
    binding-type: clusterrole-to-serviceaccount-namespace
    scope: namespace
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Bind ClusterRole to ServiceAccount but only for this namespace"
    scope: "namespace-scoped-clusterrole"
subjects:
- kind: ServiceAccount
  name: cross-namespace-worker
  namespace: $namespace
roleRef:
  kind: ClusterRole
  name: hashfoundry-cross-namespace-pod-reader
  apiGroup: rbac.authorization.k8s.io
RB_EOF
    
    # ClusterRoleBindings - привязка ClusterRole к ServiceAccount для всего кластера
    cat << CRB_EOF | kubectl apply -f -
# Bind ClusterRole to ServiceAccount for entire cluster
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-worker-node-reader-$namespace
  labels:
    binding-type: clusterrole-to-serviceaccount-cluster
    scope: cluster
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Bind node-reader ClusterRole to cluster-worker ServiceAccount"
    scope: "cluster-wide"
subjects:
- kind: ServiceAccount
  name: cluster-worker
  namespace: $namespace
roleRef:
  kind: ClusterRole
  name: hashfoundry-node-reader
  apiGroup: rbac.authorization.k8s.io
---
# Bind ClusterRole to ServiceAccount for cross-namespace access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cross-namespace-worker-pod-reader-$namespace
  labels:
    binding-type: clusterrole-to-serviceaccount-cluster
    scope: cluster
    app.kubernetes.io/name: hashfoundry-rbac-demo
  annotations:
    description: "Bind cross-namespace-pod-reader ClusterRole to cross-namespace-worker ServiceAccount"
    scope: "cluster-wide"
subjects:
- kind: ServiceAccount
  name: cross-namespace-worker
  namespace: $namespace
roleRef:
  kind: ClusterRole
  name: hashfoundry-cross-namespace-pod-reader
  apiGroup: rbac.authorization.k8s.io
CRB_EOF
    
    echo "✅ Demo bindings created for $namespace:"
    echo "   - RoleBindings: Role -> ServiceAccount (namespace-scoped)"
    echo "   - ClusterRoleBindings: ClusterRole -> ServiceAccount (cluster-scoped)"
    echo "   - Mixed: ClusterRole -> ServiceAccount via RoleBinding (namespace-scoped)"
    echo
}

# Функция для создания demo applications
create_demo_applications() {
    local namespace=$1
    
    echo "=== Creating Demo Applications for: $namespace ==="
    
    # Application для тестирования namespace-scoped прав
    cat << NS_APP_EOF | kubectl apply -f -
# Namespace-scoped demo application
apiVersion: batch/v1
kind: Job
metadata:
  name: namespace-scope-test
  namespace: $namespace
  labels:
    app: rbac-scope-demo
    scope: namespace
    test-type: namespace-scoped
spec:
  template:
    metadata:
      labels:
        app: rbac-scope-demo
        scope: namespace
    spec:
      serviceAccountName: namespace-worker
      restartPolicy: Never
      containers:
      - name: tester
        image: bitnami/kubectl:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "=== Namespace-Scoped RBAC Test ==="
          echo "ServiceAccount: namespace-worker"
          echo "Namespace: $namespace"
          echo "Expected: Can manage pods/services in $namespace only"
          echo
          
          echo "✓ Testing allowed operations in $namespace:"
          kubectl get pods -n $namespace && echo "  ✅ Can get pods in $namespace" || echo "  ❌ Cannot get pods in $namespace"
          kubectl get services -n $namespace && echo "  ✅ Can get services in $namespace" || echo "  ❌ Cannot get services in $namespace"
          
          echo
          echo "✗ Testing forbidden operations:"
          kubectl get nodes 2>/dev/null && echo "  ❌ Should not access nodes" || echo "  ✅ Correctly denied access to nodes"
          kubectl get pods --all-namespaces 2>/dev/null && echo "  ❌ Should not access all namespaces" || echo "  ✅ Correctly denied access to all namespaces"
          kubectl get namespaces 2>/dev/null && echo "  ❌ Should not access namespaces" || echo "  ✅ Correctly denied access to namespaces"
          
          # Попытаться создать pod в другом namespace
          kubectl get pods -n kube-system 2>/dev/null && echo "  ❌ Should not access kube-system" || echo "  ✅ Correctly denied access to kube-system"
          
          echo "Namespace-scoped test completed!"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
# Cluster-scoped demo application
apiVersion: batch/v1
kind: Job
metadata:
  name: cluster-scope-test
  namespace: $namespace
  labels:
    app: rbac-scope-demo
    scope: cluster
    test-type: cluster-scoped
spec:
  template:
    metadata:
      labels:
        app: rbac-scope-demo
        scope: cluster
    spec:
      serviceAccountName: cluster-worker
      restartPolicy: Never
      containers:
      - name: tester
        image: bitnami/kubectl:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "=== Cluster-Scoped RBAC Test ==="
          echo "ServiceAccount: cluster-worker"
          echo "Namespace: $namespace"
          echo "Expected: Can read cluster-wide resources (nodes)"
          echo
          
          echo "✓ Testing allowed cluster operations:"
          kubectl get nodes && echo "  ✅ Can get nodes (cluster resource)" || echo "  ❌ Cannot get nodes"
          kubectl get nodes -o wide && echo "  ✅ Can get detailed node info" || echo "  ❌ Cannot get detailed node info"
          
          echo
          echo "✗ Testing forbidden operations:"
          kubectl get pods -n $namespace 2>/dev/null && echo "  ❌ Should not access namespace pods" || echo "  ✅ Correctly denied access to namespace pods"
          kubectl create namespace test-ns 2>/dev/null && echo "  ❌ Should not create namespaces" || echo "  ✅ Correctly denied namespace creation"
          kubectl get secrets -n kube-system 2>/dev/null && echo "  ❌ Should not access secrets" || echo "  ✅ Correctly denied access to secrets"
          
          echo "Cluster-scoped test completed!"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
# Cross-namespace demo application
apiVersion: batch/v1
kind: Job
metadata:
  name: cross-namespace-test
  namespace: $namespace
  labels:
    app: rbac-scope-demo
    scope: cross-namespace
    test-type: cross-namespace
spec:
  template:
    metadata:
      labels:
        app: rbac-scope-demo
        scope: cross-namespace
    spec:
      serviceAccountName: cross-namespace-worker
      restartPolicy: Never
      containers:
      - name: tester
        image: bitnami/kubectl:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "=== Cross-Namespace RBAC Test ==="
          echo "ServiceAccount: cross-namespace-worker"
          echo "Namespace: $namespace"
          echo "Expected: Can read pods across all namespaces"
          echo
          
          echo "✓ Testing allowed cross-namespace operations:"
          kubectl get pods --all-namespaces && echo "  ✅ Can get pods in all namespaces" || echo "  ❌ Cannot get pods in all namespaces"
          kubectl get pods -n kube-system && echo "  ✅ Can get pods in kube-system" || echo "  ❌ Cannot get pods in kube-system"
          kubectl get events --all-namespaces | head -5 && echo "  ✅ Can get events across namespaces" || echo "  ❌ Cannot get events"
          
          echo
          echo "✗ Testing forbidden operations:"
          kubectl create pod test-pod --image=nginx -n $namespace 2>/dev/null && echo "  ❌ Should not create pods" || echo "  ✅ Correctly denied pod creation"
          kubectl get nodes 2>/dev/null && echo "  ❌ Should not access nodes" || echo "  ✅ Correctly denied access to nodes"
          kubectl get secrets --all-namespaces 2>/dev/null && echo "  ❌ Should not access secrets" || echo "  ✅ Correctly denied access to secrets"
          
          echo "Cross-namespace test completed!"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
NS_APP_EOF
    
    echo "✅ Demo applications created for $namespace"
    echo
}

# Функция для анализа различий между Role и ClusterRole
analyze_role_differences() {
    echo "=== Analyzing Role vs ClusterRole Differences ==="
    
    echo "Role Analysis (Namespace-scoped):"
    echo "================================="
    
    for ns in hashfoundry-dev hashfoundry-prod hashfoundry-test; do
        if kubectl get namespace $ns >/dev/null 2>&1; then
            echo "Namespace: $ns"
            role_count=$(kubectl get roles -n $ns 2>/dev/null | grep -v NAME | wc -l)
            echo "  Roles count: $role_count"
            
            if [ $role_count -gt 0 ]; then
                echo "  Roles:"
                kubectl get roles -n $ns -o custom-columns="NAME:.metadata.name,CREATED:.metadata.creationTimestamp" --no-headers 2>/dev/null | head -3 | sed 's/^/    /'
                
                echo "  Role resources (first role):"
                first_role=$(kubectl get roles -n $ns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                if [ -n "$first_role" ]; then
                    kubectl get role $first_role -n $ns -o jsonpath='{.rules[*].resources}' 2>/dev/null | tr ' ' '\n' | head -3 | sed 's/^/    /'
                fi
            fi
            echo
        fi
    done
    
    echo "ClusterRole Analysis (Cluster-scoped):"
    echo "======================================"
    
    cluster_role_count=$(kubectl get clusterroles 2>/dev/null | grep hashfoundry | wc -l)
    echo "HashFoundry ClusterRoles count: $cluster_role_count"
    
    if [ $cluster_role_count -gt 0 ]; then
        echo "ClusterRoles:"
        kubectl get clusterroles | grep hashfoundry | head -5 | sed 's/^/  /'
        
        echo "ClusterRole resources (first HashFoundry role):"
        first_cluster_role=$(kubectl get clusterroles -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep hashfoundry | head -1)
        if [ -n "$first_cluster_role" ]; then
            kubectl get clusterrole $first_cluster_role -o jsonpath='{.rules[*].resources}' 2>/dev/null | tr ' ' '\n' | head -5 | sed 's/^/  /'
        fi
    fi
    
    echo
    echo "Binding Analysis:"
    echo "================"
    
    echo "RoleBindings (namespace-scoped):"
    for ns in hashfoundry-dev hashfoundry-prod hashfoundry-test; do
        if kubectl get namespace $ns >/dev/null 2>&1; then
            rb_count=$(kubectl get rolebindings -n $ns 2>/dev/null | grep -v NAME | wc -l)
            echo "  $ns: $rb_count RoleBindings"
        fi
    done
    
    echo "ClusterRoleBindings (cluster-scoped):"
    crb_count=$(kubectl get clusterrolebindings 2>/dev/null | grep hashfoundry | wc -l)
    echo "  HashFoundry ClusterRoleBindings: $crb_count"
    
    echo
}

# Функция для тестирования различий в правах
test_scope_differences() {
    echo "=== Testing Scope Differences ==="
    
    echo "Testing Role vs ClusterRole permissions:"
    echo "======================================="
    
    # Тестировать namespace-scoped права
    for ns in hashfoundry-dev hashfoundry-prod hashfoundry-test; do
        if kubectl get namespace $ns >/dev/null 2>&1; then
            echo "Testing in namespace: $ns"
            
            # Проверить ServiceAccount права
            if kubectl get serviceaccount namespace-worker -n $ns >/dev/null 2>&1; then
                echo "  namespace-worker ServiceAccount:"
                kubectl auth can-i get pods --as=system:serviceaccount:$ns:namespace-worker -n $ns >/dev/null 2>&1 && echo "    ✅ Can get pods in $ns" || echo "    ❌ Cannot get pods in $ns"
                kubectl auth can-i get pods --as=system:serviceaccount:$ns:namespace-worker -n kube-system >/dev/null 2>&1 && echo "    ❌ Should not access kube-system" || echo "    ✅ Correctly denied access to kube-system"
                kubectl auth can-i get nodes --as=system:serviceaccount:$ns:namespace-worker >/dev/null 2>&1 && echo "    ❌ Should not access nodes" || echo "    ✅ Correctly denied access to nodes"
            fi
            
            if kubectl get serviceaccount cluster-worker -n $ns >/dev/null 2>&1; then
                echo "  cluster-worker ServiceAccount:"
                kubectl auth can-i get nodes --as=system:serviceaccount:$ns:cluster-worker >/dev/null 2>&1 && echo "    ✅ Can get nodes (cluster resource)" || echo "    ❌ Cannot get nodes"
                kubectl auth can-i get pods --as=system:serviceaccount:$ns:cluster-worker -n $ns >/dev/null 2>&1 && echo "    ❌ Should not access namespace pods" || echo "    ✅ Correctly denied access to namespace pods"
            fi
            
            if kubectl get serviceaccount cross-namespace-worker -n $ns >/dev/null 2>&1; then
                echo "  cross-namespace-worker ServiceAccount:"
                kubectl auth can-i get pods --as=system:serviceaccount:$ns:cross-namespace-worker --all-namespaces >/dev/null 2>&1 && echo "    ✅ Can get pods across namespaces" || echo "    ❌ Cannot get pods across namespaces"
                kubectl auth can-i create pods --as=system:serviceaccount:$ns:cross-namespace-worker -n $ns >/dev/null 2>&1 && echo "    ❌ Should not create pods" || echo "    ✅ Correctly denied pod creation"
            fi
            
            echo
        fi
    done
}

# Основная функция для демонстрации всех различий
demonstrate_all_differences() {
    echo "=== Full Role vs ClusterRole Demonstration ==="
    
    # Создать демонстрацию для разных сред
    environments=("hashfoundry-dev" "hashfoundry-prod" "hashfoundry-test")
    
    # Создать cluster-wide роли
    create_cluster_roles
    
    for namespace in "${environments[@]}"; do
        # Создать namespace если не существует
        kubectl create namespace $namespace 2>/dev/null || echo "Namespace $namespace already exists"
        kubectl label namespace $namespace app.kubernetes.io/name=hashfoundry 2>/dev/null || true
        
        create_namespace_roles $namespace
        create_demo_service_accounts $namespace
        create_demo_bindings $namespace
        create_demo_applications $namespace
    done
    
    sleep 30  # Дать время для создания ресурсов
    
    analyze_role_differences
    test_scope_differences
    
    echo "=== Role vs ClusterRole Summary ==="
    echo "✅ Namespace-specific roles created"
    echo "✅ Cluster-wide roles created"
    echo "✅ Demo ServiceAccounts configured"
    echo "✅ RoleBindings and ClusterRoleBindings established"
    echo "✅ Demo applications deployed"
    echo "✅ Scope differences analyzed"
    echo
    
    echo "=== Current RBAC Overview ==="
    echo "Roles (namespace-scoped):"
    kubectl get roles --all-namespaces | grep hashfoundry | wc -l | xargs echo "  Count:"
    echo "ClusterRoles (cluster-scoped):"
    kubectl get clusterroles | grep hashfoundry | wc -l | xargs echo "  Count:"
}

# Основная функция
main() {
    case "$1" in
        "namespace-roles")
            create_namespace_roles "${2:-hashfoundry-dev}"
            ;;
        "cluster-roles")
            create_cluster_roles
            ;;
        "service-accounts")
            create_demo_service_accounts "${2:-hashfoundry-dev}"
            ;;
        "bindings")
            create_demo_bindings "${2:-hashfoundry-dev}"
            ;;
        "demo-apps")
            create_demo_applications "${2:-hashfoundry-dev}"
            ;;
        "analyze")
            analyze_role_differences
            ;;
        "test")
            test_scope_differences
            ;;
        "all"|"")
            demonstrate_all_differences
            ;;
        *)
            echo "Usage: $0 [action] [namespace]"
            echo ""
            echo "Actions:"
            echo "  namespace-roles  - Create namespace-specific roles"
            echo "  cluster-roles    - Create cluster-wide roles"
            echo "  service-accounts - Create demo ServiceAccounts"
            echo "  bindings         - Create RoleBindings and ClusterRoleBindings"
            echo "  demo-apps        - Create demo applications"
            echo "  analyze          - Analyze role differences"
            echo "  test             - Test scope differences"
            echo "  all              - Full demonstration (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 namespace-roles hashfoundry-prod"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x role-vs-clusterrole-demo.sh

# Запустить демонстрацию
./role-vs-clusterrole-demo.sh all
```

## 📋 **Основные различия в деталях:**

### **1. Область действия (Scope):**

#### **Role - Namespace-scoped:**
```bash
# Role действует только в рамках namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production  # Обязательно указывать namespace
  name: pod-manager
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "create", "delete"]
```

#### **ClusterRole - Cluster-scoped:**
```bash
# ClusterRole действует на уровне всего кластера
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader  # Без namespace
rules:
- apiGroups: [""]
  resources: ["nodes"]  # Cluster-scoped ресурс
  verbs: ["get", "list", "watch"]
```

### **2. Типы ресурсов:**

#### **Role - Namespace-scoped ресурсы:**
```bash
# Ресурсы, которые существуют в namespace
- pods, services, deployments
- configmaps, secrets
- persistentvolumeclaims
- jobs, cronjobs
- ingresses
```

#### **ClusterRole - Cluster-scoped ресурсы:**
```bash
# Ресурсы на уровне кластера
- nodes, namespaces
- clusterroles, clusterrolebindings
- persistentvolumes, storageclasses
- customresourcedefinitions
- podsecuritypolicies
```

### **3. Привязки (Bindings):**

#### **RoleBinding - Namespace-scoped:**
```bash
# Привязывает Role или ClusterRole к субъекту в namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
- kind: User
  name: john.doe
roleRef:
  kind: Role  # Может быть Role или ClusterRole
  name: pod-manager
```

#### **ClusterRoleBinding - Cluster-scoped:**
```bash
# Привязывает ClusterRole к субъекту для всего кластера
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-binding
subjects:
- kind: User
  name: admin
roleRef:
  kind: ClusterRole  # Только ClusterRole
  name: cluster-admin
```

## 🎯 **Практические команды:**

### **Управление Role:**
```bash
# Создание Role
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n development

# Просмотр Role
kubectl get roles -n development
kubectl describe role pod-reader -n development

# Привязка Role
kubectl create rolebinding pod-reader-binding --role=pod-reader --user=john.doe -n development
```

### **Управление ClusterRole:**
```bash
# Создание ClusterRole
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes

# Просмотр ClusterRole
kubectl get clusterroles
kubectl describe clusterrole node-reader

# Привязка ClusterRole
kubectl create clusterrolebinding node-reader-binding --clusterrole=node-reader --user=admin
```

### **Тестирование различий:**
```bash
# Проверка namespace-scoped прав
kubectl auth can-i get pods -n development --as=user:john.doe
kubectl auth can-i get pods -n production --as=user:john.doe

# Проверка cluster-scoped прав
kubectl auth can-i get nodes --as=user:admin
kubectl auth can-i get namespaces --as=user:admin
```

## 🔧 **Best Practices:**

### **Когда использовать Role:**
- **Изоляция по namespace** - ограничить доступ к конкретному namespace
- **Команды разработчиков** - дать права только на их namespace
- **Безопасность** - минимизировать область доступа
- **Тестирование** - изолированные среды

### **Когда использовать ClusterRole:**
- **Системные операции** - управление nodes, namespaces
- **Мониторинг** - доступ к метрикам по всему кластеру
- **Администрирование** - управление RBAC, storage
- **Cross-namespace доступ** - чтение ресурсов во всех namespace

### **Гибридный подход:**
```bash
# ClusterRole с RoleBinding для namespace-specific доступа
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitoring-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: prometheus
roleRef:
  kind: ClusterRole  # ClusterRole используется через RoleBinding
  name: pod-reader   # Доступ только к pods в production namespace
```

**Role и ClusterRole обеспечивают гибкое управление правами доступа с учетом области действия!**
