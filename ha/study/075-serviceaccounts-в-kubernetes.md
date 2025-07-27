# 75. ServiceAccounts в Kubernetes

## 🎯 **ServiceAccounts в Kubernetes**

**ServiceAccount** - это специальный тип аккаунта в Kubernetes, который предоставляет идентичность для процессов, запущенных в pods. ServiceAccounts являются основой для аутентификации и авторизации приложений в кластере, позволяя им безопасно взаимодействовать с Kubernetes API.

## 🏗️ **Основные концепции:**

### **Ключевые особенности:**
- **Pod Identity** - каждый pod использует ServiceAccount для идентификации
- **API Access** - контролируют доступ к Kubernetes API
- **Token-based Auth** - используют JWT токены для аутентификации
- **RBAC Integration** - интегрируются с системой RBAC для авторизации

### **Компоненты ServiceAccount:**
- **ServiceAccount Object** - основной объект в Kubernetes
- **Secret with Token** - содержит JWT токен для аутентификации
- **CA Certificate** - сертификат для проверки API сервера
- **Namespace** - привязан к конкретному namespace

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих ServiceAccounts:**
```bash
# Проверить ServiceAccounts в кластере
kubectl get serviceaccounts --all-namespaces
kubectl get serviceaccounts -n kube-system

# Анализ default ServiceAccount
echo "=== ServiceAccount Analysis in HA Cluster ==="
kubectl describe serviceaccount default -n default
kubectl describe serviceaccount default -n kube-system

# Проверить токены ServiceAccounts
kubectl get secrets --all-namespaces | grep service-account-token
kubectl get secrets -n default | grep default-token

# Анализ использования ServiceAccounts в pods
kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SERVICE_ACCOUNT:.spec.serviceAccountName"
```

### **2. Создание comprehensive ServiceAccount demonstration:**
```bash
# Создать скрипт для демонстрации ServiceAccounts
cat << 'EOF' > serviceaccount-demo.sh
#!/bin/bash

echo "=== ServiceAccount Demonstration ==="
echo "Demonstrating ServiceAccount functionality in HashFoundry HA cluster"
echo

# Функция для создания ServiceAccounts с различными конфигурациями
create_service_accounts() {
    local namespace=$1
    
    echo "=== Creating ServiceAccounts for: $namespace ==="
    
    # Basic Application ServiceAccount
    cat << BASIC_SA_EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: basic-app-sa
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    sa-type: basic
    purpose: application
  annotations:
    description: "Basic ServiceAccount for applications"
    usage: "Standard application runtime identity"
    security-level: "standard"
automountServiceAccountToken: true
---
# Secure Application ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-app-sa
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    sa-type: secure
    purpose: application
  annotations:
    description: "Secure ServiceAccount with restricted permissions"
    usage: "High-security application runtime"
    security-level: "high"
automountServiceAccountToken: true
---
# API Client ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-client-sa
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    sa-type: api-client
    purpose: api-access
  annotations:
    description: "ServiceAccount for Kubernetes API client applications"
    usage: "Applications that need to interact with K8s API"
    security-level: "elevated"
automountServiceAccountToken: true
---
# Monitoring ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-sa
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    sa-type: monitoring
    purpose: observability
  annotations:
    description: "ServiceAccount for monitoring and observability tools"
    usage: "Prometheus, Grafana, logging agents"
    security-level: "monitoring"
automountServiceAccountToken: true
---
# Deployment ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-sa
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    sa-type: deployment
    purpose: ci-cd
  annotations:
    description: "ServiceAccount for deployment and CI/CD operations"
    usage: "GitOps, CI/CD pipelines, deployment tools"
    security-level: "deployment"
automountServiceAccountToken: true
---
# No-Token ServiceAccount (для безопасности)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-token-sa
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    sa-type: no-token
    purpose: security
  annotations:
    description: "ServiceAccount without automatic token mounting"
    usage: "Applications that don't need K8s API access"
    security-level: "minimal"
automountServiceAccountToken: false
BASIC_SA_EOF
    
    echo "✅ ServiceAccounts created for $namespace:"
    echo "   - basic-app-sa: Standard application ServiceAccount"
    echo "   - secure-app-sa: High-security application ServiceAccount"
    echo "   - api-client-sa: API client ServiceAccount"
    echo "   - monitoring-sa: Monitoring ServiceAccount"
    echo "   - deployment-sa: Deployment ServiceAccount"
    echo "   - no-token-sa: ServiceAccount without token mounting"
    echo
}

# Функция для создания custom secrets для ServiceAccounts
create_custom_secrets() {
    local namespace=$1
    
    echo "=== Creating Custom Secrets for ServiceAccounts in: $namespace ==="
    
    # Custom secret для API client
    cat << CUSTOM_SECRET_EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-client-custom-token
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    secret-type: custom-token
  annotations:
    kubernetes.io/service-account.name: api-client-sa
    description: "Custom token secret for API client ServiceAccount"
type: kubernetes.io/service-account-token
---
# Custom secret для monitoring
apiVersion: v1
kind: Secret
metadata:
  name: monitoring-custom-token
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    secret-type: custom-token
  annotations:
    kubernetes.io/service-account.name: monitoring-sa
    description: "Custom token secret for monitoring ServiceAccount"
type: kubernetes.io/service-account-token
CUSTOM_SECRET_EOF
    
    echo "✅ Custom secrets created for ServiceAccounts"
    echo
}

# Функция для создания RBAC для ServiceAccounts
create_serviceaccount_rbac() {
    local namespace=$1
    
    echo "=== Creating RBAC for ServiceAccounts in: $namespace ==="
    
    # Roles для ServiceAccounts
    cat << SA_ROLES_EOF | kubectl apply -f -
# Basic App Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: basic-app-role
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    role-type: basic-app
rules:
# Минимальные права для обычного приложения
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]
---
# Secure App Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: secure-app-role
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    role-type: secure-app
rules:
# Очень ограниченные права
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
  resourceNames: ["app-config"]  # Только конкретный ConfigMap
---
# API Client Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: api-client-role
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    role-type: api-client
rules:
# Права для работы с K8s API
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
---
# Monitoring Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: monitoring-role
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    role-type: monitoring
rules:
# Права для мониторинга
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
---
# Deployment Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: deployment-role
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    role-type: deployment
rules:
# Права для деплоймента
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
SA_ROLES_EOF
    
    # RoleBindings для ServiceAccounts
    cat << SA_BINDINGS_EOF | kubectl apply -f -
# Basic App RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: basic-app-binding
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    binding-type: basic-app
subjects:
- kind: ServiceAccount
  name: basic-app-sa
  namespace: $namespace
roleRef:
  kind: Role
  name: basic-app-role
  apiGroup: rbac.authorization.k8s.io
---
# Secure App RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secure-app-binding
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    binding-type: secure-app
subjects:
- kind: ServiceAccount
  name: secure-app-sa
  namespace: $namespace
roleRef:
  kind: Role
  name: secure-app-role
  apiGroup: rbac.authorization.k8s.io
---
# API Client RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-client-binding
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    binding-type: api-client
subjects:
- kind: ServiceAccount
  name: api-client-sa
  namespace: $namespace
roleRef:
  kind: Role
  name: api-client-role
  apiGroup: rbac.authorization.k8s.io
---
# Monitoring RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitoring-binding
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    binding-type: monitoring
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: $namespace
roleRef:
  kind: Role
  name: monitoring-role
  apiGroup: rbac.authorization.k8s.io
---
# Deployment RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-binding
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    binding-type: deployment
subjects:
- kind: ServiceAccount
  name: deployment-sa
  namespace: $namespace
roleRef:
  kind: Role
  name: deployment-role
  apiGroup: rbac.authorization.k8s.io
SA_BINDINGS_EOF
    
    echo "✅ RBAC created for ServiceAccounts"
    echo
}

# Функция для создания demo applications с различными ServiceAccounts
create_demo_applications() {
    local namespace=$1
    
    echo "=== Creating Demo Applications with ServiceAccounts in: $namespace ==="
    
    # ConfigMap для демонстрации
    cat << CONFIG_EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
data:
  app.properties: |
    app.name=ServiceAccount Demo
    app.version=1.0.0
    app.environment=$namespace
    logging.level=INFO
  database.properties: |
    db.host=localhost
    db.port=5432
    db.name=demo
CONFIG_EOF
    
    # Basic Application
    cat << BASIC_APP_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: basic-app
  namespace: $namespace
  labels:
    app: basic-app
    sa-demo: basic
spec:
  replicas: 2
  selector:
    matchLabels:
      app: basic-app
  template:
    metadata:
      labels:
        app: basic-app
        sa-demo: basic
    spec:
      serviceAccountName: basic-app-sa
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
        - name: SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: config
          mountPath: /etc/config
        - name: service-account-token
          mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: app-config
      - name: service-account-token
        projected:
          sources:
          - serviceAccountToken:
              path: token
              expirationSeconds: 3600
              audience: api
---
# Secure Application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: $namespace
  labels:
    app: secure-app
    sa-demo: secure
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
        sa-demo: secure
    spec:
      serviceAccountName: secure-app-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        env:
        - name: SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: var-cache
          mountPath: /var/cache/nginx
        - name: var-run
          mountPath: /var/run
      volumes:
      - name: tmp
        emptyDir: {}
      - name: var-cache
        emptyDir: {}
      - name: var-run
        emptyDir: {}
---
# API Client Application
apiVersion: batch/v1
kind: Job
metadata:
  name: api-client-job
  namespace: $namespace
  labels:
    app: api-client
    sa-demo: api-client
spec:
  template:
    metadata:
      labels:
        app: api-client
        sa-demo: api-client
    spec:
      serviceAccountName: api-client-sa
      restartPolicy: Never
      containers:
      - name: api-client
        image: bitnami/kubectl:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "=== ServiceAccount API Client Demo ==="
          echo "ServiceAccount: \$(cat /var/run/secrets/kubernetes.io/serviceaccount/serviceaccount 2>/dev/null || echo 'api-client-sa')"
          echo "Namespace: $namespace"
          echo "Token exists: \$(test -f /var/run/secrets/kubernetes.io/serviceaccount/token && echo 'Yes' || echo 'No')"
          echo
          
          echo "Testing API access with ServiceAccount token:"
          echo "============================================="
          
          # Тестировать разрешенные операции
          echo "✓ Testing allowed operations:"
          kubectl get pods -n $namespace && echo "  ✅ Can get pods" || echo "  ❌ Cannot get pods"
          kubectl get services -n $namespace && echo "  ✅ Can get services" || echo "  ❌ Cannot get services"
          kubectl get configmaps -n $namespace && echo "  ✅ Can get configmaps" || echo "  ❌ Cannot get configmaps"
          
          # Попытаться создать pod
          echo "  Testing pod creation:"
          kubectl run test-pod --image=nginx --dry-run=client -o yaml > /tmp/test-pod.yaml 2>/dev/null && echo "  ✅ Can generate pod manifest" || echo "  ❌ Cannot generate pod manifest"
          
          # Тестировать запрещенные операции
          echo "✗ Testing forbidden operations:"
          kubectl get nodes 2>/dev/null && echo "  ❌ Should not access nodes" || echo "  ✅ Correctly denied access to nodes"
          kubectl get secrets -n kube-system 2>/dev/null && echo "  ❌ Should not access kube-system secrets" || echo "  ✅ Correctly denied access to kube-system"
          
          echo "API client test completed!"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
# No-Token Application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-token-app
  namespace: $namespace
  labels:
    app: no-token-app
    sa-demo: no-token
spec:
  replicas: 1
  selector:
    matchLabels:
      app: no-token-app
  template:
    metadata:
      labels:
        app: no-token-app
        sa-demo: no-token
    spec:
      serviceAccountName: no-token-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1002
        fsGroup: 1002
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        env:
        - name: SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        - name: TOKEN_MOUNTED
          value: "false"
        # Проверить, что токен не монтируется
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting no-token application..."
          echo "ServiceAccount: \$SERVICE_ACCOUNT"
          echo "Token file exists: \$(test -f /var/run/secrets/kubernetes.io/serviceaccount/token && echo 'Yes' || echo 'No')"
          echo "This app runs without K8s API access"
          nginx -g 'daemon off;'
BASIC_APP_EOF
    
    echo "✅ Demo applications created with different ServiceAccounts"
    echo
}

# Функция для анализа ServiceAccount токенов
analyze_serviceaccount_tokens() {
    local namespace=$1
    
    echo "=== Analyzing ServiceAccount Tokens in: $namespace ==="
    
    echo "ServiceAccount Token Analysis:"
    echo "============================="
    
    for sa in $(kubectl get serviceaccounts -n $namespace -o jsonpath='{.items[*].metadata.name}'); do
        echo "ServiceAccount: $sa"
        
        # Проверить automountServiceAccountToken
        automount=$(kubectl get serviceaccount $sa -n $namespace -o jsonpath='{.automountServiceAccountToken}')
        echo "  automountServiceAccountToken: ${automount:-true}"
        
        # Проверить связанные secrets
        secrets=$(kubectl get serviceaccount $sa -n $namespace -o jsonpath='{.secrets[*].name}')
        if [ -n "$secrets" ]; then
            echo "  Secrets:"
            for secret in $secrets; do
                echo "    - $secret"
                # Проверить тип secret
                secret_type=$(kubectl get secret $secret -n $namespace -o jsonpath='{.type}' 2>/dev/null)
                echo "      Type: $secret_type"
            done
        else
            echo "  Secrets: None (using projected tokens)"
        fi
        
        # Проверить использование в pods
        pods_using_sa=$(kubectl get pods -n $namespace -o jsonpath="{.items[?(@.spec.serviceAccountName=='$sa')].metadata.name}")
        if [ -n "$pods_using_sa" ]; then
            echo "  Used by pods: $pods_using_sa"
        else
            echo "  Used by pods: None"
        fi
        
        echo
    done
}

# Функция для тестирования ServiceAccount permissions
test_serviceaccount_permissions() {
    local namespace=$1
    
    echo "=== Testing ServiceAccount Permissions in: $namespace ==="
    
    echo "Permission Testing:"
    echo "=================="
    
    # Тестировать права различных ServiceAccounts
    serviceaccounts=("basic-app-sa" "secure-app-sa" "api-client-sa" "monitoring-sa" "deployment-sa")
    
    for sa in "${serviceaccounts[@]}"; do
        if kubectl get serviceaccount $sa -n $namespace >/dev/null 2>&1; then
            echo "ServiceAccount: $sa"
            
            # Тестировать основные операции
            kubectl auth can-i get pods --as=system:serviceaccount:$namespace:$sa -n $namespace >/dev/null 2>&1 && echo "  ✅ Can get pods" || echo "  ❌ Cannot get pods"
            kubectl auth can-i create pods --as=system:serviceaccount:$namespace:$sa -n $namespace >/dev/null 2>&1 && echo "  ✅ Can create pods" || echo "  ❌ Cannot create pods"
            kubectl auth can-i get secrets --as=system:serviceaccount:$namespace:$sa -n $namespace >/dev/null 2>&1 && echo "  ✅ Can get secrets" || echo "  ❌ Cannot get secrets"
            kubectl auth can-i get nodes --as=system:serviceaccount:$namespace:$sa >/dev/null 2>&1 && echo "  ⚠️  Can get nodes" || echo "  ✅ Cannot get nodes (good)"
            
            echo
        fi
    done
}

# Функция для демонстрации token rotation
demonstrate_token_rotation() {
    local namespace=$1
    
    echo "=== Demonstrating Token Rotation in: $namespace ==="
    
    # Создать ServiceAccount для демонстрации rotation
    cat << TOKEN_ROTATION_EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: token-rotation-demo
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
    demo-type: token-rotation
---
# Создать custom secret для rotation demo
apiVersion: v1
kind: Secret
metadata:
  name: token-rotation-secret
  namespace: $namespace
  labels:
    app.kubernetes.io/name: hashfoundry-sa-demo
  annotations:
    kubernetes.io/service-account.name: token-rotation-demo
type: kubernetes.io/service-account-token
TOKEN_ROTATION_EOF
    
    echo "✅ Token rotation demo ServiceAccount created"
    
    # Показать информацию о токене
    echo "Token Information:"
    echo "=================="
    
    sleep 5  # Дать время для создания токена
    
    if kubectl get secret token-rotation-secret -n $namespace >/dev/null 2>&1; then
        echo "Secret exists: token-rotation-secret"
        
        # Показать метаданные токена (без самого токена для безопасности)
        kubectl get secret token-rotation-secret -n $namespace -o jsonpath='{.metadata.creationTimestamp}' | xargs echo "Created:"
        kubectl get secret token-rotation-secret -n $namespace -o jsonpath='{.data.token}' | wc -c | xargs echo "Token length (base64):"
        
        echo "To rotate token, delete and recreate the secret:"
        echo "kubectl delete secret token-rotation-secret -n $namespace"
        echo "kubectl apply -f token-rotation-secret.yaml"
    else
        echo "Secret not found - may be using projected tokens"
    fi
    
    echo
}

# Основная функция для демонстрации всех возможностей ServiceAccount
demonstrate_all_serviceaccounts() {
    echo "=== Full ServiceAccount Demonstration ==="
    
    # Создать демонстрацию для разных сред
    environments=("hashfoundry-dev" "hashfoundry-prod" "hashfoundry-test")
    
    for namespace in "${environments[@]}"; do
        # Создать namespace если не существует
        kubectl create namespace $namespace 2>/dev/null || echo "Namespace $namespace already exists"
        kubectl label namespace $namespace app.kubernetes.io/name=hashfoundry 2>/dev/null || true
        
        create_service_accounts $namespace
        create_custom_secrets $namespace
        create_serviceaccount_rbac $namespace
        create_demo_applications $namespace
        demonstrate_token_rotation $namespace
    done
    
    sleep 30  # Дать время для создания ресурсов
    
    # Анализировать первый namespace
    analyze_serviceaccount_tokens "hashfoundry-dev"
    test_serviceaccount_permissions "hashfoundry-dev"
    
    echo "=== ServiceAccount Implementation Summary ==="
    echo "✅ ServiceAccounts created with different configurations"
    echo "✅ Custom secrets and tokens configured"
    echo "✅ RBAC permissions assigned"
    echo "✅ Demo applications deployed"
    echo "✅ Token rotation demonstrated"
    echo "✅ Permissions tested"
    echo
    
    echo "=== Current ServiceAccount Overview ==="
    kubectl get serviceaccounts --all-namespaces | grep hashfoundry | wc -l | xargs echo "HashFoundry ServiceAccounts:"
    kubectl get secrets --all-namespaces | grep service-account-token | wc -l | xargs echo "ServiceAccount tokens:"
}

# Основная функция
main() {
    case "$1" in
        "service-accounts")
            create_service_accounts "${2:-hashfoundry-dev}"
            ;;
        "secrets")
            create_custom_secrets "${2:-hashfoundry-dev}"
            ;;
        "rbac")
            create_serviceaccount_rbac "${2:-hashfoundry-dev}"
            ;;
        "demo-apps")
            create_demo_applications "${2:-hashfoundry-dev}"
            ;;
        "analyze")
            analyze_serviceaccount_tokens "${2:-hashfoundry-dev}"
            ;;
        "test")
            test_serviceaccount_permissions "${2:-hashfoundry-dev}"
            ;;
        "rotation")
            demonstrate_token_rotation "${2:-hashfoundry-dev}"
            ;;
        "all"|"")
            demonstrate_all_serviceaccounts
            ;;
        *)
            echo "Usage: $0 [action] [namespace]"
            echo ""
            echo "Actions:"
            echo "  service-accounts - Create ServiceAccounts"
            echo "  secrets          - Create custom secrets"
            echo "  rbac             - Create RBAC for ServiceAccounts"
            echo "  demo-apps        - Create demo applications"
            echo "  analyze          - Analyze ServiceAccount tokens"
            echo "  test             - Test ServiceAccount permissions"
            echo "  rotation         - Demonstrate token rotation"
            echo "  all              - Full demonstration (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze hashfoundry-prod"
            echo "  $0 test"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x serviceaccount-demo.sh

# Запустить демонстрацию
./serviceaccount-demo.sh all
```

## 📋 **Как работают ServiceAccounts:**

### **1. Автоматическое создание:**
```bash
# Каждый namespace имеет default ServiceAccount
kubectl get serviceaccount default -n default
kubectl get serviceaccount default -n kube-system

# Автоматически создается secret с токеном
kubectl get secrets -n default | grep default-token
```

### **2. Монтирование токенов:**
```bash
# Токен автоматически монтируется в pod
# Путь: /var/run/secrets/kubernetes.io/serviceaccount/
# Файлы: token, ca.crt, namespace
```

### **3. API аутентификация:**
```bash
# Использование токена для API запросов
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/namespaces
```

## 🎯 **Практические команды:**

### **Управление ServiceAccounts:**
```bash
# Создание ServiceAccount
kubectl create serviceaccount my-app-sa
kubectl create serviceaccount deployer -n production

# Просмотр ServiceAccounts
kubectl get serviceaccounts --all-namespaces
kubectl describe serviceaccount my-app-sa

# Получение токена
kubectl get secret $(kubectl get serviceaccount my-app-sa -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d
```

### **Использование в Pod:**
```bash
# Pod с custom ServiceAccount
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: nginx
```

### **Тестирование прав:**
```bash
# Проверка прав ServiceAccount
kubectl auth can-i get pods --as=system:serviceaccount:default:my-app-sa
kubectl auth can-i create deployments --as=system:serviceaccount:production:deployer

# Список всех прав
kubectl auth can-i --list --as=system:serviceaccount:default:my-app-sa
```

## 🔧 **Best Practices:**

### **Безопасность:**
- **Создавать отдельные ServiceAccounts для каждого приложения**
- **Использовать принцип минимальных привилегий**
- **Отключать automountServiceAccountToken где не нужно**
- **Регулярно ротировать токены**

### **Управление:**
- **Использовать понятные имена ServiceAccounts**
- **Документировать назначение каждого ServiceAccount**
- **Группировать ServiceAccounts по функциям**
- **Мониторить использование токенов**

### **Интеграция с RBAC:**
- **Создавать специфичные роли для ServiceAccounts**
- **Избегать использования cluster-admin**
- **Тестировать права перед production**
- **Аудировать привязки ролей**

**ServiceAccounts обеспечивают безопасную идентификацию и авторизацию приложений в Kubernetes!**
