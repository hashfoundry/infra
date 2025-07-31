# 192. Как обеспечить безопасность Kubernetes в масштабе?

## 🎯 **Что такое безопасность Kubernetes в масштабе?**

**Безопасность Kubernetes в масштабе** — это комплексный подход к защите множественных кластеров, приложений и команд через автоматизированные политики, централизованное управление и непрерывный мониторинг. Включает Zero Trust архитектуру, Policy as Code, runtime security, и supply chain protection для enterprise окружений.

## 🏗️ **Основные компоненты безопасности:**

### **1. Policy Management**
- Centralized Policy Engine — единая система управления политиками
- Policy as Code — декларативное описание security rules
- Multi-cluster Policy Distribution — синхронизация политик между кластерами

### **2. Identity & Access Management**
- Zero Trust Authentication — постоянная верификация доступа
- RBAC at Scale — масштабируемое управление ролями
- Workload Identity — идентификация для приложений

### **3. Runtime Security**
- Behavioral Monitoring — мониторинг поведения workloads
- Threat Detection — обнаружение угроз в реальном времени
- Incident Response — автоматизированная реакция на инциденты

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Security posture assessment:**
```bash
# Проверка Pod Security Standards
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.securityContext.runAsNonRoot == true) | {namespace: .metadata.namespace, name: .metadata.name}'

# RBAC analysis
kubectl get clusterroles | grep -E "(view|edit|admin|cluster-admin)"
kubectl describe clusterrolebinding cluster-admin

# Network policies coverage
kubectl get networkpolicies --all-namespaces
kubectl get namespaces -o json | jq '.items | length' && kubectl get networkpolicies --all-namespaces -o json | jq '.items | length'

# Security contexts audit
kubectl get pods --all-namespaces -o json | jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name, privileged: (.spec.securityContext.privileged // false), runAsRoot: (.spec.securityContext.runAsUser == 0)}'
```

### **2. ArgoCD security configuration:**
```bash
# ArgoCD RBAC policies
kubectl get configmap -n argocd argocd-rbac-cm -o yaml
kubectl describe configmap -n argocd argocd-rbac-cm

# ArgoCD application security
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, project: .spec.project, source: .spec.source.repoURL}'

# Repository access control
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
kubectl describe secret -n argocd | grep -A 5 "argocd.argoproj.io/secret-type"
```

### **3. Monitoring security events:**
```bash
# Security-related events
kubectl get events --all-namespaces --field-selector type=Warning | grep -E "(security|denied|forbidden|unauthorized)"

# Failed authentication attempts
kubectl get events --all-namespaces --field-selector reason=Forbidden

# Admission controller violations
kubectl get events --all-namespaces --field-selector reason=FailedAdmissionWebhook

# Resource access violations
kubectl get events --all-namespaces | grep -E "(FailedMount|FailedScheduling)" | head -10
```

### **4. Certificate and secrets management:**
```bash
# TLS certificates audit
kubectl get secrets --all-namespaces -o json | jq '.items[] | select(.type == "kubernetes.io/tls") | {namespace: .metadata.namespace, name: .metadata.name}'

# Service account tokens
kubectl get secrets --all-namespaces -o json | jq '.items[] | select(.type == "kubernetes.io/service-account-token") | {namespace: .metadata.namespace, name: .metadata.name}'

# Certificate expiration check
kubectl get secrets --all-namespaces -o json | jq '.items[] | select(.type == "kubernetes.io/tls") | {namespace: .metadata.namespace, name: .metadata.name, cert: .data."tls.crt"}' | head -5
```

## 🔄 **Security Automation Pipeline:**

### **1. Policy enforcement setup:**
```bash
# Pod Security Standards enforcement
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
kubectl label namespace monitoring pod-security.kubernetes.io/enforce=restricted
kubectl label namespace argocd pod-security.kubernetes.io/enforce=restricted

# Network policy template
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
EOF

# Проверка network policies
kubectl get networkpolicies --all-namespaces
kubectl describe networkpolicy -n default default-deny-all
```

### **2. RBAC automation:**
```bash
# Developer role template
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: developer-sa
  namespace: default
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer-sa
  namespace: default
EOF

# Проверка RBAC
kubectl get roles,rolebindings -n default
kubectl describe role -n default developer-role
```

### **3. Security monitoring setup:**
```bash
# Security metrics collection
cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: security-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: security-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: security-alerts
  namespace: monitoring
spec:
  groups:
  - name: security.rules
    rules:
    - alert: HighPrivilegedPods
      expr: |
        count(kube_pod_container_status_running * on(pod, namespace) 
        group_left() kube_pod_spec_containers_security_context_privileged) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Privileged containers detected"
        description: "{{ $value }} privileged containers are running"
    
    - alert: NetworkPolicyViolations
      expr: |
        increase(networkpolicy_violations_total[5m]) > 10
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "High number of network policy violations"
        description: "{{ $value }} network policy violations in the last 5 minutes"
EOF

# Проверка security monitoring
kubectl get servicemonitors -n monitoring | grep security
kubectl get prometheusrules -n monitoring | grep security
```

## 📈 **Security Metrics и Compliance:**

### **1. Security posture metrics:**
```bash
# Pod security compliance
kubectl get pods --all-namespaces -o json | jq '[.items[] | {
  namespace: .metadata.namespace,
  name: .metadata.name,
  runAsNonRoot: (.spec.securityContext.runAsNonRoot // false),
  readOnlyRootFilesystem: (.spec.containers[0].securityContext.readOnlyRootFilesystem // false),
  privileged: (.spec.securityContext.privileged // false)
}] | group_by(.runAsNonRoot) | map({runAsNonRoot: .[0].runAsNonRoot, count: length})'

# RBAC coverage analysis
kubectl get serviceaccounts --all-namespaces -o json | jq '.items | length'
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | jq '.items | length'

# Network policy coverage
total_namespaces=$(kubectl get namespaces --no-headers | wc -l)
protected_namespaces=$(kubectl get networkpolicies --all-namespaces --no-headers | cut -d' ' -f1 | sort -u | wc -l)
echo "Network Policy Coverage: $((protected_namespaces * 100 / total_namespaces))%"
```

### **2. Vulnerability assessment:**
```bash
# Image security scanning simulation
kubectl get pods --all-namespaces -o json | jq '.items[] | {
  namespace: .metadata.namespace,
  name: .metadata.name,
  images: [.spec.containers[].image]
}' | head -10

# Resource limits compliance
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.containers[].resources.limits == null) | {namespace: .metadata.namespace, name: .metadata.name}' | head -5

# Security context audit
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.securityContext.runAsUser == 0 or .spec.containers[].securityContext.runAsUser == 0) | {namespace: .metadata.namespace, name: .metadata.name}' | head -5
```

### **3. Compliance reporting:**
```bash
# CIS Kubernetes Benchmark simulation
echo "=== CIS Kubernetes Benchmark Check ==="

# 1.2.1 - Ensure that anonymous-auth is not set to true
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -E "anonymous-auth" || echo "✅ Anonymous auth check passed"

# 1.2.6 - Ensure that the --kubelet-certificate-authority argument is set as appropriate
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -E "kubelet-certificate-authority" || echo "⚠️  Kubelet certificate authority not found"

# 4.2.1 - Minimize the admission of privileged containers
privileged_count=$(kubectl get pods --all-namespaces -o json | jq '[.items[] | select(.spec.securityContext.privileged == true or .spec.containers[].securityContext.privileged == true)] | length')
echo "Privileged containers: $privileged_count"

# 5.1.3 - Minimize wildcard use in Roles and ClusterRoles
kubectl get clusterroles -o json | jq '.items[] | select(.rules[]?.resources[]? == "*") | .metadata.name' | head -5
```

## 🏭 **Enterprise Security Implementation:**

### **1. Multi-cluster security management:**
```bash
# Security policy distribution via ArgoCD
cat << EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: security-policies
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          security-tier: "production"
  template:
    metadata:
      name: '{{name}}-security'
    spec:
      project: security
      source:
        repoURL: https://github.com/hashfoundry/security-policies
        targetRevision: HEAD
        path: policies/
      destination:
        server: '{{server}}'
        namespace: security-system
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
EOF

# Проверка security ApplicationSet
kubectl get applicationset -n argocd security-policies
kubectl describe applicationset -n argocd security-policies
```

### **2. Automated security scanning:**
```bash
# Security scanning integration
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-scan-config
  namespace: monitoring
data:
  scan-script.sh: |
    #!/bin/bash
    echo "Running security scan..."
    
    # Pod security scan
    kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.securityContext.privileged == true) | {namespace: .metadata.namespace, name: .metadata.name}'
    
    # RBAC audit
    kubectl get clusterrolebindings -o json | jq '.items[] | select(.subjects[]?.name == "system:anonymous") | .metadata.name'
    
    # Network policy check
    kubectl get networkpolicies --all-namespaces --no-headers | wc -l
    
    echo "Security scan completed"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: security-scan
  namespace: monitoring
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: security-scanner
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - /scripts/scan-script.sh
            volumeMounts:
            - name: scan-script
              mountPath: /scripts
          volumes:
          - name: scan-script
            configMap:
              name: security-scan-config
              defaultMode: 0755
          restartPolicy: OnFailure
EOF

# Проверка security scanning
kubectl get cronjobs -n monitoring security-scan
kubectl describe cronjob -n monitoring security-scan
```

### **3. Incident response automation:**
```bash
# Security incident response
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-response
  namespace: monitoring
data:
  response-playbook.yaml: |
    incidents:
      privileged_container:
        severity: HIGH
        actions:
          - isolate_pod
          - collect_logs
          - notify_security_team
      
      rbac_violation:
        severity: MEDIUM
        actions:
          - audit_permissions
          - notify_admin
      
      network_policy_violation:
        severity: MEDIUM
        actions:
          - block_traffic
          - investigate_source
  
  response-script.sh: |
    #!/bin/bash
    INCIDENT_TYPE=$1
    POD_NAME=$2
    NAMESPACE=$3
    
    case $INCIDENT_TYPE in
      "privileged_container")
        echo "Isolating privileged container: $NAMESPACE/$POD_NAME"
        kubectl label pod $POD_NAME -n $NAMESPACE security-incident=true
        kubectl annotate pod $POD_NAME -n $NAMESPACE incident.timestamp="$(date)"
        ;;
      "rbac_violation")
        echo "RBAC violation detected for: $NAMESPACE/$POD_NAME"
        kubectl get rolebindings,clusterrolebindings --all-namespaces | grep $POD_NAME
        ;;
      *)
        echo "Unknown incident type: $INCIDENT_TYPE"
        ;;
    esac
EOF

# Проверка incident response
kubectl get configmap -n monitoring incident-response
kubectl describe configmap -n monitoring incident-response
```

## 🎯 **Security Architecture:**

```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Security at Scale                  │
├─────────────────────────────────────────────────────────────┤
│  Policy Layer                                               │
│  ├── Pod Security Standards (PSS)                          │
│  ├── Network Policies                                      │
│  └── RBAC Policies                                         │
├─────────────────────────────────────────────────────────────┤
│  Identity Layer                                             │
│  ├── Service Account Management                            │
│  ├── OIDC Integration                                      │
│  └── Workload Identity                                     │
├─────────────────────────────────────────────────────────────┤
│  Runtime Layer                                              │
│  ├── Security Context Enforcement                          │
│  ├── Resource Limits                                       │
│  └── Admission Controllers                                 │
├─────────────────────────────────────────────────────────────┤
│  Monitoring Layer                                           │
│  ├── Security Metrics (Prometheus)                         │
│  ├── Audit Logging                                         │
│  └── Incident Response                                     │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer                                       │
│  ├── TLS Encryption                                        │
│  ├── Secrets Management                                    │
│  └── Certificate Rotation                                  │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Security Troubleshooting:**

### **1. Policy violations:**
```bash
# Pod Security Standard violations
kubectl get events --all-namespaces --field-selector reason=FailedCreate | grep -i "security"

# Network policy debugging
kubectl exec -n default deployment/test-app -- nc -zv monitoring-service.monitoring.svc.cluster.local 80

# RBAC permission issues
kubectl auth can-i create pods --as=system:serviceaccount:default:developer-sa
kubectl auth can-i get secrets --as=system:serviceaccount:default:developer-sa
```

### **2. Certificate and TLS issues:**
```bash
# Certificate expiration check
kubectl get secrets --all-namespaces -o json | jq '.items[] | select(.type == "kubernetes.io/tls") | {namespace: .metadata.namespace, name: .metadata.name}'

# Service mesh TLS verification
kubectl exec -n monitoring deployment/prometheus-server -- openssl s_client -connect grafana.monitoring.svc.cluster.local:80 -verify_return_error

# API server certificate check
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -A 5 "tls"
```

### **3. Access control debugging:**
```bash
# Service account token issues
kubectl get serviceaccounts --all-namespaces
kubectl describe serviceaccount -n default developer-sa

# Role binding verification
kubectl describe rolebinding -n default developer-binding
kubectl get clusterrolebindings | grep system:

# Authentication debugging
kubectl get events --all-namespaces --field-selector reason=Forbidden | head -5
```

## 🎯 **Best Practices для Security at Scale:**

### **1. Zero Trust Implementation:**
- Реализуйте принцип "never trust, always verify"
- Используйте mutual TLS для всех коммуникаций
- Применяйте least privilege access
- Мониторьте все security events

### **2. Automation-First подход:**
- Автоматизируйте policy enforcement
- Используйте GitOps для security configurations
- Реализуйте automated incident response
- Интегрируйте security в CI/CD pipelines

### **3. Continuous Compliance:**
- Регулярно аудируйте security posture
- Мониторьте compliance metrics
- Автоматизируйте compliance reporting
- Планируйте regular security reviews

### **4. Defense in Depth:**
- Реализуйте многоуровневую защиту
- Используйте network segmentation
- Применяйте runtime security monitoring
- Планируйте disaster recovery procedures

**Безопасность в масштабе требует комплексного подхода и постоянного совершенствования!**
