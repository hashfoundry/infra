# 84. Admission Controllers в Kubernetes

## 🎯 **Admission Controllers в Kubernetes**

**Admission Controllers** - это плагины, которые перехватывают запросы к Kubernetes API после аутентификации и авторизации, но до сохранения объекта в etcd. Они могут изменять (mutating) или валидировать (validating) запросы, обеспечивая дополнительный уровень безопасности и контроля.

## 🏗️ **Типы Admission Controllers:**

### **1. Mutating Admission Controllers:**
- **Изменяют объекты** - добавляют/модифицируют поля
- **Выполняются первыми** - до validating controllers
- **Примеры**: DefaultStorageClass, NamespaceLifecycle
- **Webhook поддержка** - MutatingAdmissionWebhook

### **2. Validating Admission Controllers:**
- **Валидируют объекты** - принимают или отклоняют
- **Выполняются после mutating** - финальная проверка
- **Примеры**: ResourceQuota, PodSecurityPolicy
- **Webhook поддержка** - ValidatingAdmissionWebhook

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих admission controllers:**
```bash
# Проверить включенные admission controllers
kubectl get --raw /api/v1 | jq '.serverAddressByClientCIDRs'

# Проверить admission webhooks
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations
```

### **2. Создание comprehensive admission controller framework:**
```bash
# Создать скрипт для реализации admission controllers
cat << 'EOF' > admission-controllers-implementation.sh
#!/bin/bash

echo "=== Admission Controllers Implementation ==="
echo "Implementing comprehensive admission controllers in HashFoundry HA cluster"
echo

# Функция для анализа текущих admission controllers
analyze_current_admission_controllers() {
    echo "=== Current Admission Controllers Analysis ==="
    
    echo "1. Enabled Admission Controllers:"
    echo "==============================="
    # Проверить через kube-apiserver flags (если доступно)
    kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -A 10 -B 10 "admission" || echo "API server pods not accessible"
    echo
    
    echo "2. Mutating Admission Webhooks:"
    echo "=============================="
    kubectl get mutatingwebhookconfigurations -o custom-columns="NAME:.metadata.name,WEBHOOKS:.webhooks[*].name,FAILURE-POLICY:.webhooks[*].failurePolicy"
    echo
    
    echo "3. Validating Admission Webhooks:"
    echo "==============================="
    kubectl get validatingwebhookconfigurations -o custom-columns="NAME:.metadata.name,WEBHOOKS:.webhooks[*].name,FAILURE-POLICY:.webhooks[*].failurePolicy"
    echo
    
    echo "4. Admission Controller Events:"
    echo "============================="
    kubectl get events --all-namespaces --field-selector reason=FailedAdmissionWebhook | head -10
    echo
}

# Функция для создания custom mutating admission webhook
create_mutating_webhook() {
    echo "=== Creating Custom Mutating Admission Webhook ==="
    
    # Создать namespace для webhook
    cat << WEBHOOK_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-admission
  labels:
    app.kubernetes.io/name: "hashfoundry-admission-controllers"
    hashfoundry.io/component: "security"
  annotations:
    hashfoundry.io/description: "Namespace for custom admission controllers"
WEBHOOK_NS_EOF
    
    # Создать webhook server
    cat << WEBHOOK_DEPLOYMENT_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: security-mutating-webhook
  namespace: hashfoundry-admission
  labels:
    app.kubernetes.io/name: "security-mutating-webhook"
    app.kubernetes.io/component: "admission-controller"
    hashfoundry.io/security-type: "mutating"
  annotations:
    hashfoundry.io/description: "Security-focused mutating admission webhook"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "security-mutating-webhook"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "security-mutating-webhook"
        app.kubernetes.io/component: "admission-controller"
        hashfoundry.io/security-type: "mutating"
    spec:
      serviceAccountName: admission-webhook-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: webhook
        image: nginx:1.21  # Placeholder - would be custom webhook image
        ports:
        - containerPort: 8443
          name: webhook-api
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: webhook-certs
          mountPath: /etc/certs
          readOnly: true
        - name: tmp
          mountPath: /tmp
        env:
        - name: TLS_CERT_FILE
          value: /etc/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/certs/tls.key
        livenessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: webhook-certs
        secret:
          secretName: webhook-certs
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admission-webhook-sa
  namespace: hashfoundry-admission
  labels:
    app.kubernetes.io/name: "hashfoundry-admission-controllers"
  annotations:
    hashfoundry.io/description: "ServiceAccount for admission webhooks"
---
apiVersion: v1
kind: Service
metadata:
  name: security-mutating-webhook-service
  namespace: hashfoundry-admission
  labels:
    app.kubernetes.io/name: "security-mutating-webhook"
    app.kubernetes.io/component: "admission-controller"
  annotations:
    hashfoundry.io/description: "Service for mutating admission webhook"
spec:
  selector:
    app.kubernetes.io/name: "security-mutating-webhook"
  ports:
  - name: webhook-api
    port: 443
    targetPort: 8443
    protocol: TCP
WEBHOOK_DEPLOYMENT_EOF
    
    # Создать TLS сертификаты для webhook
    cat << CERT_SCRIPT_EOF > generate-webhook-certs.sh
#!/bin/bash

echo "Generating TLS certificates for admission webhook..."

# Создать CA
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=US/ST=CA/L=SF/O=HashFoundry/CN=HashFoundry-CA" -out ca.crt

# Создать server key и CSR
openssl genrsa -out server.key 2048
openssl req -newkey rsa:2048 -nodes -keyout server.key -subj "/C=US/ST=CA/L=SF/O=HashFoundry/CN=security-mutating-webhook-service.hashfoundry-admission.svc" -out server.csr

# Создать server certificate
openssl x509 -req -extfile <(printf "subjectAltName=DNS:security-mutating-webhook-service.hashfoundry-admission.svc,DNS:security-mutating-webhook-service.hashfoundry-admission.svc.cluster.local") -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt

# Создать Kubernetes secret
kubectl create secret tls webhook-certs \\
  --cert=server.crt \\
  --key=server.key \\
  -n hashfoundry-admission

# Получить CA bundle для webhook configuration
CA_BUNDLE=\$(cat ca.crt | base64 | tr -d '\\n')
echo "CA Bundle: \$CA_BUNDLE"

# Cleanup
rm ca.key ca.crt ca.srl server.key server.csr server.crt

echo "✅ Certificates generated and secret created"
CERT_SCRIPT_EOF
    
    chmod +x generate-webhook-certs.sh
    ./generate-webhook-certs.sh
    
    echo "✅ Mutating webhook created"
    echo
}

# Функция для создания validating admission webhook
create_validating_webhook() {
    echo "=== Creating Custom Validating Admission Webhook ==="
    
    # Создать validating webhook server
    cat << VALIDATING_WEBHOOK_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: security-validating-webhook
  namespace: hashfoundry-admission
  labels:
    app.kubernetes.io/name: "security-validating-webhook"
    app.kubernetes.io/component: "admission-controller"
    hashfoundry.io/security-type: "validating"
  annotations:
    hashfoundry.io/description: "Security-focused validating admission webhook"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "security-validating-webhook"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "security-validating-webhook"
        app.kubernetes.io/component: "admission-controller"
        hashfoundry.io/security-type: "validating"
    spec:
      serviceAccountName: admission-webhook-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: webhook
        image: nginx:1.21  # Placeholder - would be custom webhook image
        ports:
        - containerPort: 8443
          name: webhook-api
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: webhook-certs
          mountPath: /etc/certs
          readOnly: true
        - name: tmp
          mountPath: /tmp
        env:
        - name: TLS_CERT_FILE
          value: /etc/certs/tls.crt
        - name: TLS_PRIVATE_KEY_FILE
          value: /etc/certs/tls.key
        livenessProbe:
          httpGet:
            path: /health
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: webhook-certs
        secret:
          secretName: webhook-certs
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: security-validating-webhook-service
  namespace: hashfoundry-admission
  labels:
    app.kubernetes.io/name: "security-validating-webhook"
    app.kubernetes.io/component: "admission-controller"
  annotations:
    hashfoundry.io/description: "Service for validating admission webhook"
spec:
  selector:
    app.kubernetes.io/name: "security-validating-webhook"
  ports:
  - name: webhook-api
    port: 443
    targetPort: 8443
    protocol: TCP
VALIDATING_WEBHOOK_EOF
    
    echo "✅ Validating webhook created"
    echo
}

# Функция для создания webhook configurations
create_webhook_configurations() {
    echo "=== Creating Webhook Configurations ==="
    
    # Получить CA bundle
    CA_BUNDLE=$(kubectl get secret webhook-certs -n hashfoundry-admission -o jsonpath='{.data.ca\.crt}' 2>/dev/null || echo "")
    
    if [ -z "$CA_BUNDLE" ]; then
        echo "⚠️  CA bundle not found, using placeholder"
        CA_BUNDLE="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"  # Placeholder
    fi
    
    # Создать MutatingAdmissionWebhook configuration
    cat << MUTATING_CONFIG_EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: security-mutating-webhook
  labels:
    app.kubernetes.io/name: "hashfoundry-admission-controllers"
    hashfoundry.io/webhook-type: "mutating"
  annotations:
    hashfoundry.io/description: "Mutating webhook for security enhancements"
webhooks:
- name: security-defaults.hashfoundry.io
  clientConfig:
    service:
      name: security-mutating-webhook-service
      namespace: hashfoundry-admission
      path: "/mutate"
    caBundle: $CA_BUNDLE
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources: ["deployments", "statefulsets", "daemonsets"]
  namespaceSelector:
    matchLabels:
      hashfoundry.io/admission-control: "enabled"
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
MUTATING_CONFIG_EOF
    
    # Создать ValidatingAdmissionWebhook configuration
    cat << VALIDATING_CONFIG_EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: security-validating-webhook
  labels:
    app.kubernetes.io/name: "hashfoundry-admission-controllers"
    hashfoundry.io/webhook-type: "validating"
  annotations:
    hashfoundry.io/description: "Validating webhook for security policies"
webhooks:
- name: security-validation.hashfoundry.io
  clientConfig:
    service:
      name: security-validating-webhook-service
      namespace: hashfoundry-admission
      path: "/validate"
    caBundle: $CA_BUNDLE
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources: ["deployments", "statefulsets", "daemonsets"]
  namespaceSelector:
    matchLabels:
      hashfoundry.io/admission-control: "enabled"
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 10
VALIDATING_CONFIG_EOF
    
    echo "✅ Webhook configurations created"
    echo
}

# Функция для создания OPA Gatekeeper
create_opa_gatekeeper() {
    echo "=== Creating OPA Gatekeeper ==="
    
    # Установить OPA Gatekeeper
    cat << GATEKEEPER_EOF | kubectl apply -f -
# OPA Gatekeeper namespace
apiVersion: v1
kind: Namespace
metadata:
  name: gatekeeper-system
  labels:
    app.kubernetes.io/name: "gatekeeper"
    hashfoundry.io/component: "policy-engine"
  annotations:
    hashfoundry.io/description: "OPA Gatekeeper policy engine"
---
# Constraint Template для обязательных labels
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
  labels:
    app.kubernetes.io/name: "gatekeeper-constraint"
    hashfoundry.io/policy-type: "required-labels"
  annotations:
    hashfoundry.io/description: "Constraint template for required labels"
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        type: object
        properties:
          labels:
            type: array
            items:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("Missing required label: %v", [missing])
        }
---
# Constraint для обязательных HashFoundry labels
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: must-have-hashfoundry-labels
  labels:
    app.kubernetes.io/name: "gatekeeper-constraint"
    hashfoundry.io/policy-type: "required-labels"
  annotations:
    hashfoundry.io/description: "Require HashFoundry standard labels"
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
    namespaces: ["hashfoundry-prod", "hashfoundry-staging"]
  parameters:
    labels: ["app.kubernetes.io/name", "app.kubernetes.io/component", "hashfoundry.io/environment"]
---
# Constraint Template для security contexts
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
  labels:
    app.kubernetes.io/name: "gatekeeper-constraint"
    hashfoundry.io/policy-type: "security-context"
  annotations:
    hashfoundry.io/description: "Constraint template for required security contexts"
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        type: object
        properties:
          runAsNonRoot:
            type: boolean
          readOnlyRootFilesystem:
            type: boolean
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext

        violation[{"msg": msg}] {
          input.parameters.runAsNonRoot == true
          not input.review.object.spec.securityContext.runAsNonRoot == true
          msg := "Container must run as non-root user"
        }

        violation[{"msg": msg}] {
          input.parameters.readOnlyRootFilesystem == true
          container := input.review.object.spec.containers[_]
          not container.securityContext.readOnlyRootFilesystem == true
          msg := sprintf("Container %v must have readOnlyRootFilesystem: true", [container.name])
        }
---
# Constraint для security contexts
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredSecurityContext
metadata:
  name: must-have-security-context
  labels:
    app.kubernetes.io/name: "gatekeeper-constraint"
    hashfoundry.io/policy-type: "security-context"
  annotations:
    hashfoundry.io/description: "Require proper security contexts"
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces: ["hashfoundry-prod"]
  parameters:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
GATEKEEPER_EOF
    
    echo "✅ OPA Gatekeeper policies created"
    echo
}

# Функция для создания мониторинга admission controllers
create_admission_monitoring() {
    echo "=== Creating Admission Controllers Monitoring ==="
    
    # Создать ServiceMonitor для admission webhooks
    cat << ADMISSION_MONITORING_EOF | kubectl apply -f -
# PrometheusRule for admission controllers monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: admission-controllers-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: "hashfoundry-admission-monitoring"
    hashfoundry.io/component: "admission-alerts"
  annotations:
    hashfoundry.io/description: "Alerts for admission controllers"
spec:
  groups:
  - name: admission-controllers
    rules:
    - alert: AdmissionWebhookFailure
      expr: |
        increase(apiserver_admission_webhook_admission_duration_seconds_count{type="validating",rejected="true"}[5m]) > 0
      for: 1m
      labels:
        severity: warning
        category: admission-control
      annotations:
        summary: "Admission webhook rejecting requests"
        description: "Admission webhook {{ \$labels.name }} is rejecting requests"
    
    - alert: AdmissionWebhookLatency
      expr: |
        histogram_quantile(0.99, rate(apiserver_admission_webhook_admission_duration_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
        category: admission-control
      annotations:
        summary: "High admission webhook latency"
        description: "Admission webhook latency is above 1 second"
    
    - alert: AdmissionWebhookDown
      expr: |
        up{job="admission-webhook"} == 0
      for: 2m
      labels:
        severity: critical
        category: admission-control
      annotations:
        summary: "Admission webhook is down"
        description: "Admission webhook {{ \$labels.instance }} is not responding"
    
    - alert: GatekeeperViolations
      expr: |
        increase(gatekeeper_violations_total[5m]) > 10
      for: 1m
      labels:
        severity: warning
        category: policy-violation
      annotations:
        summary: "High number of Gatekeeper violations"
        description: "Gatekeeper is reporting {{ \$value }} policy violations"
ADMISSION_MONITORING_EOF
    
    # Создать скрипт для мониторинга admission controllers
    cat << MONITORING_SCRIPT_EOF > admission-controllers-monitor.sh
#!/bin/bash

echo "=== Admission Controllers Monitoring ==="
echo "Monitoring admission controllers in HashFoundry HA cluster"
echo

# Функция для проверки admission webhooks
check_admission_webhooks() {
    echo "1. Admission Webhooks Status:"
    echo "============================"
    
    echo "Mutating Webhooks:"
    kubectl get mutatingwebhookconfigurations -o custom-columns="NAME:.metadata.name,WEBHOOKS:.webhooks[*].name,FAILURE-POLICY:.webhooks[*].failurePolicy"
    echo
    
    echo "Validating Webhooks:"
    kubectl get validatingwebhookconfigurations -o custom-columns="NAME:.metadata.name,WEBHOOKS:.webhooks[*].name,FAILURE-POLICY:.webhooks[*].failurePolicy"
    echo
}

# Функция для проверки webhook endpoints
check_webhook_endpoints() {
    echo "2. Webhook Endpoints Health:"
    echo "==========================="
    
    # Проверить pods admission webhooks
    kubectl get pods -n hashfoundry-admission -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status"
    echo
    
    # Проверить services
    kubectl get services -n hashfoundry-admission -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,PORTS:.spec.ports[*].port"
    echo
}

# Функция для проверки Gatekeeper
check_gatekeeper() {
    echo "3. OPA Gatekeeper Status:"
    echo "========================"
    
    # Проверить Gatekeeper pods
    kubectl get pods -n gatekeeper-system 2>/dev/null || echo "Gatekeeper not installed"
    echo
    
    # Проверить constraints
    echo "Constraint Templates:"
    kubectl get constrainttemplates 2>/dev/null || echo "No constraint templates found"
    echo
    
    echo "Constraints:"
    kubectl get constraints --all-namespaces 2>/dev/null || echo "No constraints found"
    echo
}

# Функция для проверки admission events
check_admission_events() {
    echo "4. Admission Events:"
    echo "==================="
    
    # Проверить события admission webhooks
    kubectl get events --all-namespaces --field-selector reason=FailedAdmissionWebhook | head -10
    echo
    
    # Проверить события Gatekeeper
    kubectl get events --all-namespaces | grep -i gatekeeper | head -10
    echo
}

# Функция для тестирования admission controllers
test_admission_controllers() {
    echo "5. Testing Admission Controllers:"
    echo "================================"
    
    # Создать тестовый namespace с admission control
    cat << TEST_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: admission-test
  labels:
    hashfoundry.io/admission-control: "enabled"
    app.kubernetes.io/name: "admission-test"
  annotations:
    hashfoundry.io/description: "Test namespace for admission controllers"
TEST_NS_EOF
    
    echo "Test namespace created with admission control enabled"
    
    # Тест 1: Pod без обязательных labels (должен быть отклонен)
    echo "Test 1: Creating pod without required labels (should be rejected):"
    cat << TEST_POD_BAD_EOF | kubectl apply -f - 2>&1 || echo "✅ Expected rejection - pod without required labels"
apiVersion: v1
kind: Pod
metadata:
  name: test-bad-pod
  namespace: admission-test
spec:
  containers:
  - name: test
    image: nginx:1.21
TEST_POD_BAD_EOF
    
    # Тест 2: Pod с правильными labels (должен быть принят)
    echo "Test 2: Creating pod with required labels (should be accepted):"
    cat << TEST_POD_GOOD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-good-pod
  namespace: admission-test
  labels:
    app.kubernetes.io/name: "test-app"
    app.kubernetes.io/component: "test"
    hashfoundry.io/environment: "test"
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: test
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
TEST_POD_GOOD_EOF
    
    echo "✅ Admission controller tests completed"
    echo
}

# Функция для генерации отчета
generate_report() {
    echo "6. Admission Controllers Report:"
    echo "==============================="
    
    echo "✅ ADMISSION CONTROL STATUS:"
    echo "- Mutating Webhooks: $(kubectl get mutatingwebhookconfigurations --no-headers | wc -l)"
    echo "- Validating Webhooks: $(kubectl get validatingwebhookconfigurations --no-headers | wc -l)"
    echo "- Gatekeeper Constraints: $(kubectl get constraints --all-namespaces --no-headers 2>/dev/null | wc -l)"
    echo
    
    echo "📋 SECURITY ENHANCEMENTS:"
    echo "1. Automatic security context injection"
    echo "2. Required labels enforcement"
    echo "3. Policy-based validation"
    echo "4. Runtime security checks"
    echo "5. Compliance monitoring"
    echo
    
    echo "🔧 RECOMMENDATIONS:"
    echo "1. Regular review of admission policies"
    echo "2. Monitor webhook performance and availability"
    echo "3. Test admission controllers in staging"
    echo "4. Implement gradual policy rollout"
    echo "5. Maintain webhook certificate rotation"
    echo
}

# Cleanup function
cleanup_test_resources() {
    echo "Cleaning up test resources..."
    kubectl delete namespace admission-test --ignore-not-found=true
    echo "✅ Cleanup completed"
}

# Запустить все проверки
check_admission_webhooks
check_webhook_endpoints
check_gatekeeper
check_admission_events
test_admission_controllers
generate_report

# Cleanup при выходе
trap cleanup_test_resources EXIT

MONITORING_SCRIPT_EOF
    
    chmod +x admission-controllers-monitor.sh
    
    echo "✅ Admission controllers monitoring created"
    echo "   - Use admission-controllers-monitor.sh for compliance checks"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_admission_controllers
            ;;
        "mutating-webhook")
            create_mutating_webhook
            ;;
        "validating-webhook")
            create_validating_webhook
            ;;
        "webhook-configs")
            create_webhook_configurations
            ;;
        "gatekeeper")
            create_opa_gatekeeper
            ;;
        "monitoring")
            create_admission_monitoring
            ;;
        "all"|"")
            analyze_current_admission_controllers
            create_mutating_webhook
            create_validating_webhook
            create_webhook_configurations
            create_opa_gatekeeper
            create_admission_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze              - Analyze current admission controllers"
            echo "  mutating-webhook     - Create mutating admission webhook"
            echo "  validating-webhook   - Create validating admission webhook"
            echo "  webhook-configs      - Create webhook configurations"
            echo "  gatekeeper           - Create OPA Gatekeeper policies"
            echo "  monitoring           - Create admission monitoring"
            echo "  all                  - Full admission controllers setup (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 gatekeeper"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x admission-controllers-implementation.sh

# Запустить реализацию admission controllers
./admission-controllers-implementation.sh all
```

## 📋 **Архитектура Admission Controllers:**

### **Порядок выполнения:**

| **Этап** | **Тип** | **Действие** | **Примеры** |
|----------|---------|--------------|-------------|
| **1** | Authentication | Аутентификация | User/ServiceAccount |
| **2** | Authorization | Авторизация | RBAC, ABAC |
| **3** | Mutating | Изменение объектов | DefaultStorageClass |
| **4** | Validating | Валидация объектов | ResourceQuota |
| **5** | Persistence | Сохранение в etcd | - |

### **Встроенные Admission Controllers:**

#### **Mutating Controllers:**
```yaml
# Примеры встроенных mutating controllers:
- DefaultStorageClass      # Добавляет default StorageClass
- NamespaceLifecycle      # Управляет lifecycle namespace
- ServiceAccount          # Добавляет default ServiceAccount
- DefaultTolerationSeconds # Добавляет toleration для nodes
```

#### **Validating Controllers:**
```yaml
# Примеры встроенных validating controllers:
- ResourceQuota           # Проверяет resource limits
- LimitRanger            # Проверяет resource ranges
- PodSecurityPolicy      # Проверяет pod security (deprecated)
- ValidatingAdmissionWebhook # Custom validation
```

## 🎯 **Практические команды:**

### **Управление Admission Controllers:**
```bash
# Создать admission controllers
./admission-controllers-implementation.sh all

# Проверить webhook configurations
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Мониторинг admission controllers
./admission-controllers-monitor.sh

# Тестирование webhook
kubectl apply --dry-run=server -f test-pod.yaml
```

### **Отладка Admission Controllers:**
```bash
# Проверить события admission
kubectl get events --field-selector reason=FailedAdmissionWebhook

# Логи webhook pods
kubectl logs -n hashfoundry-admission -l app.kubernetes.io/component=admission-controller

# Проверить сертификаты webhook
kubectl get secret webhook-certs -n hashfoundry-admission -o yaml
```

### **OPA Gatekeeper команды:**
```bash
# Проверить constraint templates
kubectl get constrainttemplates

# Проверить constraints
kubectl get constraints --all-namespaces

# Проверить нарушения политик
kubectl get events | grep -i gatekeeper
```

## 🔧 **Best Practices для Admission Controllers:**

### **Безопасность:**
- **TLS сертификаты** - использовать валидные сертификаты
- **Failure Policy** - настроить правильную политику отказов
- **Timeout** - установить разумные таймауты
- **RBAC** - минимальные права для webhook

### **Производительность:**
- **Кэширование** - кэшировать результаты валидации
- **Асинхронность** - избегать блокирующих операций
- **Мониторинг** - отслеживать latency и errors
- **Scaling** - горизонтальное масштабирование webhook

### **Операционные процессы:**
- **Тестирование** - тестировать в staging среде
- **Постепенное внедрение** - начать с warn режима
- **Версионирование** - поддерживать обратную совместимость
- **Документирование** - описывать политики и правила

### **Мониторинг и алертинг:**
- **Метрики** - отслеживать webhook performance
- **Логирование** - детальные логи для отладки
- **Алерты** - уведомления о сбоях webhook
- **Дашборды** - визуализация admission metrics

**Admission Controllers обеспечивают мощный механизм контроля и безопасности в Kubernetes!**
