# 81. Pod Security Standards в Kubernetes

## 🎯 **Pod Security Standards в Kubernetes**

**Pod Security Standards (PSS)** - это встроенный механизм безопасности Kubernetes, который заменил устаревшие Pod Security Policies. PSS определяет три уровня безопасности для pods: Privileged, Baseline и Restricted. Эти стандарты применяются на уровне namespace и контролируют различные аспекты безопасности pods.

## 🏗️ **Три уровня Pod Security Standards:**

### **1. Privileged (Привилегированный):**
- **Описание**: Неограниченная политика безопасности
- **Использование**: Системные workloads, доверенные пользователи
- **Ограничения**: Отсутствуют

### **2. Baseline (Базовый):**
- **Описание**: Минимально ограничительная политика
- **Использование**: Обычные приложения
- **Ограничения**: Запрещает известные эскалации привилегий

### **3. Restricted (Ограниченный):**
- **Описание**: Строго ограничительная политика
- **Использование**: Критически важные приложения
- **Ограничения**: Следует лучшим практикам безопасности

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих Pod Security Standards:**
```bash
# Проверить Pod Security Standards в namespaces
kubectl get namespaces -o json | jq '.items[] | {name: .metadata.name, labels: .metadata.labels}'

# Проверить pods на соответствие стандартам
kubectl get pods --all-namespaces -o wide
```

### **2. Создание comprehensive Pod Security Standards implementation:**
```bash
# Создать скрипт для реализации Pod Security Standards
cat << 'EOF' > pod-security-standards-implementation.sh
#!/bin/bash

echo "=== Pod Security Standards Implementation ==="
echo "Implementing comprehensive Pod Security Standards in HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния
analyze_current_security() {
    echo "=== Current Pod Security Analysis ==="
    
    echo "1. Namespace security labels:"
    echo "============================"
    kubectl get namespaces -o custom-columns="NAME:.metadata.name,ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce,AUDIT:.metadata.labels.pod-security\.kubernetes\.io/audit,WARN:.metadata.labels.pod-security\.kubernetes\.io/warn"
    echo
    
    echo "2. Pods with security contexts:"
    echo "=============================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext != null) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.securityContext | keys | join(", "))"'
    echo
    
    echo "3. Privileged pods:"
    echo "=================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.privileged == true) | "\(.metadata.namespace)/\(.metadata.name): PRIVILEGED"'
    echo
    
    echo "4. Pods running as root:"
    echo "======================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext?.runAsUser == 0 or (.spec.containers[]?.securityContext?.runAsUser == 0)) | "\(.metadata.namespace)/\(.metadata.name): ROOT USER"'
    echo
}

# Функция для создания namespaces с разными уровнями безопасности
create_security_namespaces() {
    echo "=== Creating Security-Enabled Namespaces ==="
    
    # Privileged namespace для системных компонентов
    cat << PRIVILEGED_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-privileged
  labels:
    # Pod Security Standards
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
    
    # HashFoundry labels
    hashfoundry.io/security-level: "privileged"
    hashfoundry.io/environment: "system"
    app.kubernetes.io/name: "hashfoundry-security"
    app.kubernetes.io/component: "privileged-namespace"
  annotations:
    pod-security.kubernetes.io/enforce-version: "latest"
    pod-security.kubernetes.io/audit-version: "latest"
    pod-security.kubernetes.io/warn-version: "latest"
    hashfoundry.io/description: "Privileged namespace for system workloads"
    hashfoundry.io/use-case: "System daemons, monitoring agents, CNI plugins"
PRIVILEGED_NS_EOF
    
    # Baseline namespace для обычных приложений
    cat << BASELINE_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-baseline
  labels:
    # Pod Security Standards
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
    
    # HashFoundry labels
    hashfoundry.io/security-level: "baseline"
    hashfoundry.io/environment: "application"
    app.kubernetes.io/name: "hashfoundry-security"
    app.kubernetes.io/component: "baseline-namespace"
  annotations:
    pod-security.kubernetes.io/enforce-version: "latest"
    pod-security.kubernetes.io/audit-version: "latest"
    pod-security.kubernetes.io/warn-version: "latest"
    hashfoundry.io/description: "Baseline namespace for standard applications"
    hashfoundry.io/use-case: "Web applications, APIs, databases"
BASELINE_NS_EOF
    
    # Restricted namespace для критических приложений
    cat << RESTRICTED_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-restricted
  labels:
    # Pod Security Standards
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    
    # HashFoundry labels
    hashfoundry.io/security-level: "restricted"
    hashfoundry.io/environment: "production"
    app.kubernetes.io/name: "hashfoundry-security"
    app.kubernetes.io/component: "restricted-namespace"
  annotations:
    pod-security.kubernetes.io/enforce-version: "latest"
    pod-security.kubernetes.io/audit-version: "latest"
    pod-security.kubernetes.io/warn-version: "latest"
    hashfoundry.io/description: "Restricted namespace for critical applications"
    hashfoundry.io/use-case: "Payment processing, sensitive data, compliance workloads"
RESTRICTED_NS_EOF
    
    echo "✅ Security namespaces created"
    echo
}

# Функция для создания примеров pods для каждого уровня
create_security_examples() {
    echo "=== Creating Pod Security Examples ==="
    
    # Privileged pod example
    cat << PRIVILEGED_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-example
  namespace: hashfoundry-privileged
  labels:
    app.kubernetes.io/name: "security-example"
    hashfoundry.io/security-level: "privileged"
  annotations:
    hashfoundry.io/description: "Example of privileged pod"
spec:
  containers:
  - name: privileged-container
    image: nginx:1.21
    securityContext:
      privileged: true
      runAsUser: 0
      capabilities:
        add:
        - SYS_ADMIN
        - NET_ADMIN
    volumeMounts:
    - name: host-root
      mountPath: /host
      readOnly: true
  volumes:
  - name: host-root
    hostPath:
      path: /
      type: Directory
  hostNetwork: true
  hostPID: true
---
PRIVILEGED_POD_EOF
    
    # Baseline pod example
    cat << BASELINE_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: baseline-example
  namespace: hashfoundry-baseline
  labels:
    app.kubernetes.io/name: "security-example"
    hashfoundry.io/security-level: "baseline"
  annotations:
    hashfoundry.io/description: "Example of baseline pod"
spec:
  containers:
  - name: baseline-container
    image: nginx:1.21
    ports:
    - containerPort: 80
    securityContext:
      runAsUser: 1000
      runAsGroup: 3000
      allowPrivilegeEscalation: false
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
---
BASELINE_POD_EOF
    
    # Restricted pod example
    cat << RESTRICTED_POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restricted-example
  namespace: hashfoundry-restricted
  labels:
    app.kubernetes.io/name: "security-example"
    hashfoundry.io/security-level: "restricted"
  annotations:
    hashfoundry.io/description: "Example of restricted pod"
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: restricted-container
    image: nginx:1.21
    ports:
    - containerPort: 8080
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
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
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
RESTRICTED_POD_EOF
    
    echo "✅ Security example pods created"
    echo
}

# Функция для создания Deployment с security contexts
create_secure_deployments() {
    echo "=== Creating Secure Deployments ==="
    
    # Baseline web application
    cat << BASELINE_DEPLOY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-baseline
  namespace: hashfoundry-baseline
  labels:
    app.kubernetes.io/name: "webapp"
    app.kubernetes.io/component: "frontend"
    hashfoundry.io/security-level: "baseline"
  annotations:
    hashfoundry.io/description: "Baseline web application deployment"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "webapp"
      app.kubernetes.io/component: "frontend"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "webapp"
        app.kubernetes.io/component: "frontend"
        hashfoundry.io/security-level: "baseline"
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
BASELINE_DEPLOY_EOF
    
    # Restricted API application
    cat << RESTRICTED_DEPLOY_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-restricted
  namespace: hashfoundry-restricted
  labels:
    app.kubernetes.io/name: "api"
    app.kubernetes.io/component: "backend"
    hashfoundry.io/security-level: "restricted"
  annotations:
    hashfoundry.io/description: "Restricted API application deployment"
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: "api"
      app.kubernetes.io/component: "backend"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "api"
        app.kubernetes.io/component: "backend"
        hashfoundry.io/security-level: "restricted"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: api
        image: node:16-alpine
        command: ["node", "-e", "require('http').createServer((req,res)=>{res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({status:'healthy',security:'restricted'}))}).listen(8080)"]
        ports:
        - containerPort: 8080
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
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: tmp
        emptyDir: {}
---
RESTRICTED_DEPLOY_EOF
    
    echo "✅ Secure deployments created"
    echo
}

# Функция для тестирования Pod Security Standards
test_pod_security_standards() {
    echo "=== Testing Pod Security Standards ==="
    
    # Тест 1: Попытка создать privileged pod в restricted namespace
    echo "Test 1: Attempting to create privileged pod in restricted namespace"
    cat << TEST1_EOF | kubectl apply -f - 2>&1 || echo "✅ Expected failure - privileged pod blocked in restricted namespace"
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged-in-restricted
  namespace: hashfoundry-restricted
spec:
  containers:
  - name: test
    image: nginx:1.21
    securityContext:
      privileged: true
TEST1_EOF
    echo
    
    # Тест 2: Попытка создать pod с root user в restricted namespace
    echo "Test 2: Attempting to create root user pod in restricted namespace"
    cat << TEST2_EOF | kubectl apply -f - 2>&1 || echo "✅ Expected failure - root user blocked in restricted namespace"
apiVersion: v1
kind: Pod
metadata:
  name: test-root-in-restricted
  namespace: hashfoundry-restricted
spec:
  containers:
  - name: test
    image: nginx:1.21
    securityContext:
      runAsUser: 0
TEST2_EOF
    echo
    
    # Тест 3: Создание корректного restricted pod
    echo "Test 3: Creating compliant restricted pod"
    cat << TEST3_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-compliant-restricted
  namespace: hashfoundry-restricted
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
TEST3_EOF
    echo "✅ Compliant restricted pod created successfully"
    echo
}

# Функция для мониторинга Pod Security Standards
create_security_monitoring() {
    echo "=== Creating Security Monitoring ==="
    
    # Создать ServiceMonitor для мониторинга security events
    cat << MONITORING_EOF | kubectl apply -f -
# PrometheusRule for Pod Security Standards monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-security-standards-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: "hashfoundry-security-monitoring"
    hashfoundry.io/component: "pod-security-alerts"
  annotations:
    hashfoundry.io/description: "Alerts for Pod Security Standards violations"
spec:
  groups:
  - name: pod-security-standards
    rules:
    - alert: PrivilegedPodCreated
      expr: |
        increase(kubernetes_audit_total{verb="create",objectRef_resource="pods",objectRef_subresource="",responseStatus_code=~"2.."}[5m]) > 0
        and on() kube_pod_spec_containers_security_context_privileged == 1
      for: 0m
      labels:
        severity: warning
        category: security
      annotations:
        summary: "Privileged pod created"
        description: "A privileged pod has been created in namespace {{ \$labels.namespace }}"
    
    - alert: RootUserPodCreated
      expr: |
        kube_pod_spec_containers_security_context_run_as_user == 0
      for: 0m
      labels:
        severity: warning
        category: security
      annotations:
        summary: "Pod running as root user"
        description: "Pod {{ \$labels.pod }} in namespace {{ \$labels.namespace }} is running as root user"
    
    - alert: PodSecurityStandardViolation
      expr: |
        increase(kubernetes_audit_total{verb="create",objectRef_resource="pods",responseStatus_code=~"4.."}[5m]) > 0
      for: 0m
      labels:
        severity: critical
        category: security
      annotations:
        summary: "Pod Security Standard violation"
        description: "Pod creation blocked due to security policy violation"
MONITORING_EOF
    
    # Создать скрипт для аудита безопасности
    cat << AUDIT_SCRIPT_EOF > pod-security-audit.sh
#!/bin/bash

echo "=== Pod Security Standards Audit ==="
echo "Auditing Pod Security Standards compliance in HashFoundry HA cluster"
echo

# Функция для проверки namespace security labels
check_namespace_security() {
    echo "1. Namespace Security Configuration:"
    echo "==================================="
    kubectl get namespaces -o custom-columns="NAME:.metadata.name,ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce,AUDIT:.metadata.labels.pod-security\.kubernetes\.io/audit,WARN:.metadata.labels.pod-security\.kubernetes\.io/warn" | grep -v "<none>"
    echo
}

# Функция для проверки privileged pods
check_privileged_pods() {
    echo "2. Privileged Pods:"
    echo "=================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.privileged == true) | "⚠️  \(.metadata.namespace)/\(.metadata.name): PRIVILEGED"'
    echo
}

# Функция для проверки root user pods
check_root_user_pods() {
    echo "3. Pods Running as Root:"
    echo "======================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext?.runAsUser == 0 or (.spec.containers[]?.securityContext?.runAsUser == 0)) | "⚠️  \(.metadata.namespace)/\(.metadata.name): ROOT USER"'
    echo
}

# Функция для проверки capabilities
check_capabilities() {
    echo "4. Pods with Added Capabilities:"
    echo "==============================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.capabilities?.add != null) | "⚠️  \(.metadata.namespace)/\(.metadata.name): \(.spec.containers[].securityContext.capabilities.add | join(", "))"'
    echo
}

# Функция для проверки host access
check_host_access() {
    echo "5. Pods with Host Access:"
    echo "========================"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.hostNetwork == true or .spec.hostPID == true or .spec.hostIPC == true) | "⚠️  \(.metadata.namespace)/\(.metadata.name): HOST ACCESS"'
    echo
}

# Функция для генерации рекомендаций
generate_recommendations() {
    echo "6. Security Recommendations:"
    echo "============================"
    echo "✅ RECOMMENDED ACTIONS:"
    echo "1. Apply Pod Security Standards to all namespaces"
    echo "2. Use 'restricted' level for production workloads"
    echo "3. Use 'baseline' level for standard applications"
    echo "4. Reserve 'privileged' level only for system components"
    echo "5. Implement security contexts for all pods"
    echo "6. Use non-root users in containers"
    echo "7. Drop all capabilities and add only required ones"
    echo "8. Enable seccomp and AppArmor profiles"
    echo "9. Use read-only root filesystems where possible"
    echo "10. Regular security audits and compliance checks"
    echo
}

# Запустить все проверки
check_namespace_security
check_privileged_pods
check_root_user_pods
check_capabilities
check_host_access
generate_recommendations

AUDIT_SCRIPT_EOF
    
    chmod +x pod-security-audit.sh
    
    echo "✅ Security monitoring and audit tools created"
    echo "   - Use pod-security-audit.sh for security compliance checks"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_security
            ;;
        "create-namespaces")
            create_security_namespaces
            ;;
        "create-examples")
            create_security_examples
            ;;
        "create-deployments")
            create_secure_deployments
            ;;
        "test")
            test_pod_security_standards
            ;;
        "monitoring")
            create_security_monitoring
            ;;
        "all"|"")
            analyze_current_security
            create_security_namespaces
            create_security_examples
            create_secure_deployments
            test_pod_security_standards
            create_security_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze              - Analyze current security state"
            echo "  create-namespaces    - Create security-enabled namespaces"
            echo "  create-examples      - Create pod security examples"
            echo "  create-deployments   - Create secure deployments"
            echo "  test                 - Test Pod Security Standards"
            echo "  monitoring           - Create security monitoring"
            echo "  all                  - Full implementation (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 test"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x pod-security-standards-implementation.sh

# Запустить реализацию Pod Security Standards
./pod-security-standards-implementation.sh all
```

## 📋 **Детальное сравнение уровней безопасности:**

### **Privileged Level:**
```bash
# Разрешено всё:
- privileged: true
- hostNetwork: true
- hostPID: true
- runAsUser: 0
- capabilities: ALL
```

### **Baseline Level:**
```bash
# Запрещено:
- privileged: true
- hostNetwork: true (кроме hostPort)
- hostPID: true
- hostIPC: true
- Некоторые volume types
- Некоторые capabilities
```

### **Restricted Level:**
```bash
# Требуется:
- runAsNonRoot: true
- allowPrivilegeEscalation: false
- capabilities: drop ALL
- seccompProfile: RuntimeDefault
- readOnlyRootFilesystem: true (рекомендуется)
```

## 🎯 **Практические команды:**

### **Управление Pod Security Standards:**
```bash
# Применить restricted уровень к namespace
kubectl label namespace my-namespace pod-security.kubernetes.io/enforce=restricted

# Проверить соответствие pod стандартам
kubectl get pods -n my-namespace -o json | jq '.items[].spec.securityContext'

# Тестировать создание pod с нарушением
kubectl apply -f privileged-pod.yaml --dry-run=server
```

### **Мониторинг безопасности:**
```bash
# Аудит Pod Security Standards
./pod-security-audit.sh

# Проверить события безопасности
kubectl get events --field-selector reason=FailedCreate

# Мониторинг privileged pods
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.containers[]?.securityContext?.privileged == true)'
```

## 🔧 **Best Practices для Pod Security Standards:**

### **Выбор уровня безопасности:**
- **Privileged**: Только для системных компонентов (CNI, CSI, monitoring agents)
- **Baseline**: Для большинства приложений
- **Restricted**: Для критически важных и production workloads

### **Миграция на Pod Security Standards:**
- **Постепенный переход** - начать с audit и warn режимов
- **Тестирование** - проверить совместимость приложений
- **Обучение команды** - понимание требований безопасности
- **Автоматизация** - использовать CI/CD для проверки соответствия

**Pod Security Standards обеспечивают современный и гибкий подход к безопасности pods в Kubernetes!**
