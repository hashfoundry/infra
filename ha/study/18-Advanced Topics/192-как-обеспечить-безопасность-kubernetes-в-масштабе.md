# 192. Как обеспечить безопасность Kubernetes в масштабе?

## 🎯 Вопрос
Как обеспечить безопасность Kubernetes в масштабе?

## 💡 Ответ

Обеспечение безопасности Kubernetes в масштабе требует комплексного подхода, включающего автоматизацию, политики безопасности, мониторинг и культурные изменения. Это критически важно для enterprise окружений с множеством кластеров, команд и приложений.

### 🛡️ Архитектура безопасности в масштабе

#### 1. **Схема Security at Scale Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Security at Scale                  │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Policy Management                      │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    OPA      │    │  Gatekeeper │    │   Kyverno   │ │ │
│  │  │  Policies   │───▶│   Policies  │───▶│  Policies   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Identity & Access Management              │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    RBAC     │    │   Service   │    │   External  │ │ │
│  │  │   Policies  │───▶│  Accounts   │───▶│    IdP      │ │ │
│  │  │             │    │             │    │ Integration │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Runtime Security                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    Falco    │    │   Twistlock │    │   Network   │ │ │
│  │  │  Detection  │───▶│   Runtime   │───▶│  Policies   │ │ │
│  │  │             │    │  Protection │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Supply Chain Security                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Image     │    │   SBOM      │    │   Sigstore  │ │ │
│  │  │  Scanning   │───▶│ Generation  │───▶│   Signing   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Security Layers и Controls**
```yaml
# Security at Scale Framework
security_framework:
  governance_layer:
    policy_management:
      centralized_policies:
        - "Admission control policies"
        - "Network security policies"
        - "RBAC templates"
        - "Security baselines"
      
      policy_distribution:
        - "GitOps-based deployment"
        - "Multi-cluster synchronization"
        - "Version control"
        - "Rollback capabilities"
    
    compliance_automation:
      frameworks:
        - "CIS Kubernetes Benchmark"
        - "NIST Cybersecurity Framework"
        - "SOC 2 Type II"
        - "PCI DSS"
      
      tools:
        - "Falco compliance rules"
        - "OPA policy validation"
        - "Compliance dashboards"
        - "Automated reporting"

  identity_access_layer:
    authentication:
      enterprise_integration:
        - "OIDC integration"
        - "SAML federation"
        - "LDAP/Active Directory"
        - "Multi-factor authentication"
      
      service_identity:
        - "SPIFFE/SPIRE"
        - "Workload identity"
        - "Service mesh mTLS"
        - "Pod identity"
    
    authorization:
      rbac_at_scale:
        - "Role templates"
        - "Namespace isolation"
        - "Cluster-wide policies"
        - "Just-in-time access"
      
      attribute_based_access:
        - "OPA authorization"
        - "Context-aware policies"
        - "Dynamic permissions"
        - "Risk-based access"

  workload_security_layer:
    admission_control:
      policy_engines:
        - "OPA Gatekeeper"
        - "Kyverno"
        - "Polaris"
        - "Falco admission"
      
      security_policies:
        - "Pod security standards"
        - "Resource limits"
        - "Image policies"
        - "Network restrictions"
    
    runtime_protection:
      behavioral_monitoring:
        - "Anomaly detection"
        - "Process monitoring"
        - "Network analysis"
        - "File integrity"
      
      threat_detection:
        - "Runtime alerts"
        - "Incident response"
        - "Forensic analysis"
        - "Threat intelligence"

  infrastructure_security_layer:
    cluster_hardening:
      control_plane:
        - "API server security"
        - "etcd encryption"
        - "Certificate management"
        - "Audit logging"
      
      node_security:
        - "OS hardening"
        - "Container runtime security"
        - "Kernel security modules"
        - "Host-based monitoring"
    
    network_security:
      segmentation:
        - "Network policies"
        - "Service mesh security"
        - "Ingress/egress control"
        - "Zero trust networking"
      
      encryption:
        - "TLS everywhere"
        - "Secrets encryption"
        - "Storage encryption"
        - "Transit encryption"

  supply_chain_security_layer:
    image_security:
      vulnerability_management:
        - "Continuous scanning"
        - "Policy enforcement"
        - "Remediation tracking"
        - "Risk assessment"
      
      image_provenance:
        - "Digital signatures"
        - "SBOM generation"
        - "Build attestation"
        - "Supply chain verification"
    
    artifact_security:
      secure_distribution:
        - "Private registries"
        - "Access controls"
        - "Content trust"
        - "Malware scanning"
```

### 📊 Примеры из нашего кластера

#### Проверка security posture:
```bash
# Проверка security policies
kubectl get policies --all-namespaces

# Проверка RBAC
kubectl get clusterroles,clusterrolebindings

# Проверка network policies
kubectl get networkpolicies --all-namespaces

# Проверка pod security standards
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'

# Проверка admission controllers
kubectl get validatingadmissionwebhooks,mutatingadmissionwebhooks
```

### 🔧 Реализация Security at Scale

#### 1. **Centralized Policy Management**
```yaml
# policy-management-system.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-policies-config
  namespace: security-system
data:
  baseline-security-policy.yaml: |
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: baseline-security
    spec:
      validationFailureAction: enforce
      background: true
      rules:
      - name: require-non-root
        match:
          any:
          - resources:
              kinds:
              - Pod
        validate:
          message: "Containers must run as non-root user"
          pattern:
            spec:
              securityContext:
                runAsNonRoot: true
      
      - name: require-resource-limits
        match:
          any:
          - resources:
              kinds:
              - Pod
        validate:
          message: "All containers must have resource limits"
          pattern:
            spec:
              containers:
              - name: "*"
                resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
      
      - name: disallow-privileged
        match:
          any:
          - resources:
              kinds:
              - Pod
        validate:
          message: "Privileged containers are not allowed"
          pattern:
            spec:
              =(securityContext):
                =(privileged): "false"
              containers:
              - name: "*"
                =(securityContext):
                  =(privileged): "false"

---
# Multi-cluster policy distribution
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: security-policies
  namespace: argocd
spec:
  generators:
  - clusters: {}
  template:
    metadata:
      name: '{{name}}-security-policies'
    spec:
      project: security
      source:
        repoURL: https://github.com/company/security-policies
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

---
# RBAC Template System
apiVersion: v1
kind: ConfigMap
metadata:
  name: rbac-templates
  namespace: security-system
data:
  developer-role-template.yaml: |
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: developer-{{.namespace}}
      namespace: {{.namespace}}
    rules:
    - apiGroups: [""]
      resources: ["pods", "services", "configmaps", "secrets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: ["apps"]
      resources: ["deployments", "replicasets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: [""]
      resources: ["pods/log", "pods/exec"]
      verbs: ["get", "list"]
    
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: developer-{{.namespace}}-binding
      namespace: {{.namespace}}
    subjects:
    - kind: Group
      name: developers-{{.namespace}}
      apiGroup: rbac.authorization.k8s.io
    roleRef:
      kind: Role
      name: developer-{{.namespace}}
      apiGroup: rbac.authorization.k8s.io
```

#### 2. **Automated Security Scanning**
```yaml
# security-scanning-pipeline.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: security-scanning-pipeline
spec:
  params:
  - name: image-url
    type: string
  - name: git-url
    type: string
  - name: git-revision
    type: string
    default: main
  
  tasks:
  - name: source-code-scan
    taskRef:
      name: sonarqube-scanner
    params:
    - name: SONAR_HOST_URL
      value: "https://sonarqube.company.com"
    - name: SONAR_PROJECT_KEY
      value: "$(params.git-url)"
  
  - name: dependency-scan
    taskRef:
      name: dependency-check
    params:
    - name: git-url
      value: "$(params.git-url)"
    - name: git-revision
      value: "$(params.git-revision)"
  
  - name: container-scan
    taskRef:
      name: trivy-scanner
    params:
    - name: IMAGE
      value: "$(params.image-url)"
    - name: FORMAT
      value: "sarif"
  
  - name: policy-validation
    taskRef:
      name: conftest-verify
    params:
    - name: files
      value: "k8s/*.yaml"
    - name: policy
      value: "security-policies/"
  
  - name: sbom-generation
    taskRef:
      name: syft-sbom
    params:
    - name: IMAGE
      value: "$(params.image-url)"
    - name: FORMAT
      value: "spdx-json"
  
  - name: image-signing
    taskRef:
      name: cosign-sign
    params:
    - name: IMAGE
      value: "$(params.image-url)"
    - name: COSIGN_PRIVATE_KEY
      value: "cosign-private-key"

---
# Security Monitoring Dashboard
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-dashboard-config
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "Kubernetes Security Dashboard",
        "panels": [
          {
            "title": "Security Policy Violations",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(rate(gatekeeper_violations_total[5m]))",
                "legendFormat": "Policy Violations/sec"
              }
            ]
          },
          {
            "title": "Failed Authentication Attempts",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(apiserver_audit_total{verb=\"create\",objectRef_resource=\"tokenreviews\",code!~\"2..\"}[5m]))",
                "legendFormat": "Failed Auth/sec"
              }
            ]
          },
          {
            "title": "Privileged Containers",
            "type": "table",
            "targets": [
              {
                "expr": "kube_pod_container_status_running{container!=\"POD\"} * on(pod, namespace) group_left() kube_pod_spec_containers_security_context_privileged",
                "legendFormat": "{{namespace}}/{{pod}}/{{container}}"
              }
            ]
          },
          {
            "title": "Network Policy Coverage",
            "type": "stat",
            "targets": [
              {
                "expr": "(count(kube_namespace_labels) - count(kube_networkpolicy_info)) / count(kube_namespace_labels) * 100",
                "legendFormat": "Unprotected Namespaces %"
              }
            ]
          }
        ]
      }
    }
```

#### 3. **Runtime Security Monitoring**
```yaml
# falco-security-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-custom-rules
  namespace: falco-system
data:
  custom_rules.yaml: |
    - rule: Detect crypto mining
      desc: Detect cryptocurrency mining
      condition: >
        spawned_process and
        (proc.name in (crypto_miners) or
         proc.cmdline contains "stratum" or
         proc.cmdline contains "xmrig" or
         proc.cmdline contains "cryptonight")
      output: >
        Cryptocurrency mining detected (user=%user.name command=%proc.cmdline
        container=%container.name image=%container.image.repository)
      priority: CRITICAL
      tags: [cryptocurrency, mining]
    
    - rule: Detect suspicious network activity
      desc: Detect suspicious outbound network connections
      condition: >
        outbound and
        fd.sip.name != "" and
        not fd.sip.name in (allowed_outbound_domains) and
        (fd.sport in (suspicious_ports) or
         fd.dport in (suspicious_ports))
      output: >
        Suspicious network activity (user=%user.name command=%proc.cmdline
        connection=%fd.name container=%container.name)
      priority: WARNING
      tags: [network, suspicious]
    
    - rule: Detect privilege escalation
      desc: Detect attempts to escalate privileges
      condition: >
        spawned_process and
        (proc.name in (setuid_binaries) or
         proc.cmdline contains "sudo" or
         proc.cmdline contains "su -" or
         proc.aname in (privilege_escalation_binaries))
      output: >
        Privilege escalation attempt (user=%user.name command=%proc.cmdline
        container=%container.name image=%container.image.repository)
      priority: HIGH
      tags: [privilege_escalation]

---
# Security Incident Response
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-response-playbook
data:
  playbook.yaml: |
    incident_types:
      privilege_escalation:
        severity: HIGH
        actions:
          - isolate_container
          - collect_forensics
          - notify_security_team
          - create_incident_ticket
      
      crypto_mining:
        severity: CRITICAL
        actions:
          - terminate_container
          - block_image
          - collect_forensics
          - notify_security_team
          - escalate_to_management
      
      suspicious_network:
        severity: MEDIUM
        actions:
          - monitor_container
          - collect_network_logs
          - notify_security_team
    
    automation_rules:
      - trigger: falco_alert
        condition: priority == "CRITICAL"
        action: auto_isolate
      
      - trigger: policy_violation
        condition: count > 5 in 1m
        action: notify_admin
```

#### 4. **Multi-Cluster Security Management**
```bash
#!/bin/bash
# multi-cluster-security-audit.sh

echo "🔒 Multi-Cluster Security Audit"

CLUSTERS=("prod-us-east" "prod-eu-west" "staging" "dev")

# Security audit function
audit_cluster() {
    local cluster=$1
    echo "=== Auditing cluster: $cluster ==="
    
    # Switch context
    kubectl config use-context $cluster
    
    # Check RBAC
    echo "--- RBAC Analysis ---"
    kubectl get clusterrolebindings -o json | jq -r '
        .items[] | 
        select(.subjects[]?.kind == "User" and .subjects[]?.name != "system:admin") |
        {
            name: .metadata.name,
            role: .roleRef.name,
            users: [.subjects[]? | select(.kind == "User") | .name]
        }
    '
    
    # Check privileged pods
    echo "--- Privileged Pods ---"
    kubectl get pods --all-namespaces -o json | jq -r '
        .items[] |
        select(.spec.securityContext.privileged == true or 
               .spec.containers[].securityContext.privileged == true) |
        "\(.metadata.namespace)/\(.metadata.name)"
    '
    
    # Check network policies
    echo "--- Network Policy Coverage ---"
    total_namespaces=$(kubectl get namespaces --no-headers | wc -l)
    protected_namespaces=$(kubectl get networkpolicies --all-namespaces --no-headers | cut -d' ' -f1 | sort -u | wc -l)
    coverage=$((protected_namespaces * 100 / total_namespaces))
    echo "Network Policy Coverage: $coverage%"
    
    # Check pod security standards
    echo "--- Pod Security Standards ---"
    kubectl get namespaces -o json | jq -r '
        .items[] |
        {
            name: .metadata.name,
            enforce: .metadata.labels["pod-security.kubernetes.io/enforce"] // "none",
            audit: .metadata.labels["pod-security.kubernetes.io/audit"] // "none",
            warn: .metadata.labels["pod-security.kubernetes.io/warn"] // "none"
        }
    '
    
    # Check secrets encryption
    echo "--- Secrets Encryption ---"
    kubectl get secrets --all-namespaces -o json | jq -r '
        .items[] |
        select(.type != "kubernetes.io/service-account-token") |
        "\(.metadata.namespace)/\(.metadata.name): \(.type)"
    ' | head -5
    
    echo ""
}

# Generate security report
generate_security_report() {
    echo "=== Security Report Summary ==="
    
    for cluster in "${CLUSTERS[@]}"; do
        echo "--- $cluster ---"
        kubectl config use-context $cluster
        
        # Count security violations
        violations=$(kubectl get events --all-namespaces | grep -i "security\|violation\|denied" | wc -l)
        echo "Security Events: $violations"
        
        # Count privileged workloads
        privileged=$(kubectl get pods --all-namespaces -o json | jq '[.items[] | select(.spec.securityContext.privileged == true or .spec.containers[].securityContext.privileged == true)] | length')
        echo "Privileged Pods: $privileged"
        
        # Check admission controllers
        admission_controllers=$(kubectl get validatingadmissionwebhooks,mutatingadmissionwebhooks --no-headers | wc -l)
        echo "Admission Controllers: $admission_controllers"
        
        echo ""
    done
}

# Security compliance check
compliance_check() {
    echo "=== CIS Kubernetes Benchmark Check ==="
    
    # Check API server configuration
    echo "--- API Server Security ---"
    kubectl get pods -n kube-system kube-apiserver-* -o yaml | grep -E "(anonymous-auth|authorization-mode|audit-log)" || echo "API server config not accessible"
    
    # Check etcd encryption
    echo "--- etcd Encryption ---"
    kubectl get secrets -n kube-system | grep encryption-config && echo "✅ Encryption config found" || echo "❌ No encryption config"
    
    # Check RBAC
    echo "--- RBAC Configuration ---"
    kubectl auth can-i --list --as=system:anonymous | head -5
    
    # Check network policies
    echo "--- Network Policies ---"
    kubectl get networkpolicies --all-namespaces --no-headers | wc -l | xargs echo "Total Network Policies:"
}

# Main execution
main() {
    for cluster in "${CLUSTERS[@]}"; do
        audit_cluster $cluster
    done
    
    generate_security_report
    compliance_check
}

main "$@"
```

### 📈 Security Metrics и KPIs

#### Security Dashboard Queries:
```bash
# Security metrics collection
kubectl get --raw /metrics | grep -E "(apiserver_audit|gatekeeper|falco)" > security_metrics.txt

# Policy violation trends
kubectl get events --all-namespaces | grep -i "violation" | awk '{print $1}' | sort | uniq -c

# RBAC usage analysis
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | jq '.items | length'

# Container security posture
kubectl get pods --all-namespaces -o json | jq '[.items[] | {name: .metadata.name, namespace: .metadata.namespace, privileged: (.spec.securityContext.privileged // false), runAsRoot: (.spec.securityContext.runAsUser == 0)}]'
```

### 🎯 Заключение

Обеспечение безопасности Kubernetes в масштабе требует:

1. **Автоматизация** - политики как код, автоматическое сканирование, CI/CD интеграция
2. **Централизация** - единые политики, централизованный мониторинг, общие стандарты
3. **Многоуровневая защита** - defense in depth подход
4. **Непрерывный мониторинг** - runtime security, аудит, compliance проверки
5. **Культура безопасности** - обучение команд, shift-left security, DevSecOps

Ключевые принципы:
- **Zero Trust** - никому не доверяй, всегда проверяй
- **Least Privilege** - минимальные необходимые права
- **Automation First** - автоматизация всех security процессов
- **Continuous Compliance** - постоянная проверка соответствия требованиям
