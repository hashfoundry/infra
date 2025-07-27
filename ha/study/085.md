# 85. Runtime Security Monitoring в Kubernetes

## 🎯 **Runtime Security Monitoring в Kubernetes**

**Runtime Security Monitoring** - это непрерывное отслеживание и анализ поведения контейнеров и pods во время их выполнения для обнаружения аномалий, угроз и нарушений безопасности. Это включает мониторинг системных вызовов, сетевого трафика, файловых операций и процессов.

## 🏗️ **Компоненты Runtime Security:**

### **1. Behavioral Analysis:**
- **System Calls Monitoring** - отслеживание syscalls
- **Process Monitoring** - контроль запуска процессов
- **Network Activity** - анализ сетевых подключений
- **File System Access** - мониторинг файловых операций

### **2. Threat Detection:**
- **Anomaly Detection** - обнаружение аномального поведения
- **Malware Detection** - поиск вредоносного ПО
- **Privilege Escalation** - обнаружение повышения привилегий
- **Data Exfiltration** - предотвращение утечек данных

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущего runtime security:**
```bash
# Проверить security-related pods
kubectl get pods --all-namespaces -l security.kubernetes.io/runtime-monitoring=enabled

# Анализ security events
kubectl get events --all-namespaces --field-selector type=Warning | grep -i security
```

### **2. Создание comprehensive runtime security framework:**
```bash
# Создать скрипт для реализации runtime security monitoring
cat << 'EOF' > runtime-security-implementation.sh
#!/bin/bash

echo "=== Runtime Security Monitoring Implementation ==="
echo "Implementing comprehensive runtime security monitoring in HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния runtime security
analyze_current_runtime_security() {
    echo "=== Current Runtime Security Analysis ==="
    
    echo "1. Security-related Pods:"
    echo "========================"
    kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,IMAGE:.spec.containers[*].image,SECURITY-CONTEXT:.spec.securityContext" | grep -v "<none>"
    echo
    
    echo "2. Security Events:"
    echo "=================="
    kubectl get events --all-namespaces --field-selector type=Warning | grep -i -E "(security|violation|denied|failed)" | head -10
    echo
    
    echo "3. Privileged Containers:"
    echo "========================"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.privileged == true) | "\(.metadata.namespace)/\(.metadata.name): PRIVILEGED"'
    echo
    
    echo "4. Host Network Pods:"
    echo "===================="
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.hostNetwork == true) | "\(.metadata.namespace)/\(.metadata.name): HOST_NETWORK"'
    echo
}

# Функция для установки Falco
install_falco() {
    echo "=== Installing Falco Runtime Security ==="
    
    # Создать namespace для Falco
    cat << FALCO_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: falco-system
  labels:
    app.kubernetes.io/name: "falco"
    hashfoundry.io/component: "runtime-security"
  annotations:
    hashfoundry.io/description: "Falco runtime security monitoring"
FALCO_NS_EOF
    
    # Создать Falco DaemonSet
    cat << FALCO_DAEMONSET_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco-system
  labels:
    app.kubernetes.io/name: "falco"
    app.kubernetes.io/component: "runtime-security"
    hashfoundry.io/security-type: "runtime-monitoring"
  annotations:
    hashfoundry.io/description: "Falco runtime security monitoring DaemonSet"
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: "falco"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "falco"
        app.kubernetes.io/component: "runtime-security"
        hashfoundry.io/security-type: "runtime-monitoring"
    spec:
      serviceAccountName: falco
      hostNetwork: true
      hostPID: true
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
      containers:
      - name: falco
        image: falcosecurity/falco:0.35.1
        securityContext:
          privileged: true
        args:
        - /usr/bin/falco
        - --cri=/run/containerd/containerd.sock
        - --k8s-api=https://kubernetes.default.svc.cluster.local
        - --k8s-api-cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        - --k8s-api-token=/var/run/secrets/kubernetes.io/serviceaccount/token
        env:
        - name: FALCO_K8S_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - mountPath: /host/var/run/docker.sock
          name: docker-socket
          readOnly: true
        - mountPath: /host/run/containerd/containerd.sock
          name: containerd-socket
          readOnly: true
        - mountPath: /host/dev
          name: dev-fs
          readOnly: true
        - mountPath: /host/proc
          name: proc-fs
          readOnly: true
        - mountPath: /host/boot
          name: boot-fs
          readOnly: true
        - mountPath: /host/lib/modules
          name: lib-modules
          readOnly: true
        - mountPath: /host/usr
          name: usr-fs
          readOnly: true
        - mountPath: /host/etc
          name: etc-fs
          readOnly: true
        - mountPath: /etc/falco
          name: falco-config
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8765
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8765
          initialDelaySeconds: 30
          periodSeconds: 15
          timeoutSeconds: 5
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
      - name: containerd-socket
        hostPath:
          path: /run/containerd/containerd.sock
      - name: dev-fs
        hostPath:
          path: /dev
      - name: proc-fs
        hostPath:
          path: /proc
      - name: boot-fs
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr-fs
        hostPath:
          path: /usr
      - name: etc-fs
        hostPath:
          path: /etc
      - name: falco-config
        configMap:
          name: falco-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: falco
  namespace: falco-system
  labels:
    app.kubernetes.io/name: "falco"
  annotations:
    hashfoundry.io/description: "ServiceAccount for Falco"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: falco
  labels:
    app.kubernetes.io/name: "falco"
rules:
- apiGroups: [""]
  resources: ["nodes", "namespaces", "pods", "replicationcontrollers", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["daemonsets", "deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["daemonsets", "deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: falco
  labels:
    app.kubernetes.io/name: "falco"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: falco
subjects:
- kind: ServiceAccount
  name: falco
  namespace: falco-system
FALCO_DAEMONSET_EOF
    
    echo "✅ Falco DaemonSet created"
    echo
}

# Функция для создания Falco конфигурации
create_falco_config() {
    echo "=== Creating Falco Configuration ==="
    
    cat << FALCO_CONFIG_EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-config
  namespace: falco-system
  labels:
    app.kubernetes.io/name: "falco"
    hashfoundry.io/component: "runtime-security-config"
  annotations:
    hashfoundry.io/description: "Falco configuration for HashFoundry security monitoring"
data:
  falco.yaml: |
    # Falco configuration for HashFoundry HA cluster
    rules_file:
      - /etc/falco/falco_rules.yaml
      - /etc/falco/falco_rules.local.yaml
      - /etc/falco/k8s_audit_rules.yaml
      - /etc/falco/rules.d

    time_format_iso_8601: true
    json_output: true
    json_include_output_property: true
    json_include_tags_property: true

    log_stderr: true
    log_syslog: true
    log_level: info

    priority: debug
    buffered_outputs: false

    syscall_event_drops:
      actions:
        - log
        - alert
      rate: 0.03333
      max_burst: 1000

    outputs:
      rate: 1
      max_burst: 1000

    syslog_output:
      enabled: true

    file_output:
      enabled: false

    stdout_output:
      enabled: true

    webserver:
      enabled: true
      listen_port: 8765
      k8s_healthz_endpoint: /healthz
      ssl_enabled: false

    grpc:
      enabled: false

    grpc_output:
      enabled: false

  falco_rules.local.yaml: |
    # HashFoundry specific security rules
    
    # Rule: Detect privilege escalation attempts
    - rule: Privilege Escalation Attempt
      desc: Detect attempts to escalate privileges
      condition: >
        spawned_process and
        (proc.name in (sudo, su, doas) or
         proc.args contains "chmod +s" or
         proc.args contains "setuid")
      output: >
        Privilege escalation attempt detected
        (user=%user.name command=%proc.cmdline container=%container.name
         image=%container.image.repository:%container.image.tag)
      priority: WARNING
      tags: [privilege_escalation, hashfoundry]

    # Rule: Detect suspicious network activity
    - rule: Suspicious Network Activity
      desc: Detect suspicious outbound network connections
      condition: >
        outbound and
        fd.sip != "127.0.0.1" and
        not proc.name in (curl, wget, apt, yum, dnf, pip) and
        fd.sport > 32768
      output: >
        Suspicious network activity detected
        (user=%user.name command=%proc.cmdline connection=%fd.name
         container=%container.name image=%container.image.repository:%container.image.tag)
      priority: WARNING
      tags: [network, suspicious, hashfoundry]

    # Rule: Detect file system modifications in sensitive directories
    - rule: Sensitive Directory Modification
      desc: Detect modifications to sensitive directories
      condition: >
        open_write and
        (fd.name startswith /etc/ or
         fd.name startswith /usr/bin/ or
         fd.name startswith /usr/sbin/ or
         fd.name startswith /bin/ or
         fd.name startswith /sbin/) and
        not proc.name in (apt, yum, dnf, dpkg, rpm)
      output: >
        Sensitive directory modification detected
        (user=%user.name file=%fd.name command=%proc.cmdline
         container=%container.name image=%container.image.repository:%container.image.tag)
      priority: ERROR
      tags: [filesystem, sensitive, hashfoundry]

    # Rule: Detect crypto mining activity
    - rule: Crypto Mining Activity
      desc: Detect potential cryptocurrency mining
      condition: >
        spawned_process and
        (proc.name in (xmrig, cpuminer, cgminer, bfgminer, sgminer) or
         proc.args contains "stratum+tcp" or
         proc.args contains "mining.pool" or
         proc.args contains "cryptonight")
      output: >
        Crypto mining activity detected
        (user=%user.name command=%proc.cmdline container=%container.name
         image=%container.image.repository:%container.image.tag)
      priority: CRITICAL
      tags: [crypto_mining, malware, hashfoundry]

    # Rule: Detect container escape attempts
    - rule: Container Escape Attempt
      desc: Detect attempts to escape container
      condition: >
        spawned_process and
        (proc.args contains "docker" or
         proc.args contains "runc" or
         proc.args contains "kubectl" or
         proc.args contains "/proc/self/exe" or
         proc.args contains "nsenter")
      output: >
        Container escape attempt detected
        (user=%user.name command=%proc.cmdline container=%container.name
         image=%container.image.repository:%container.image.tag)
      priority: CRITICAL
      tags: [container_escape, hashfoundry]

    # Rule: Detect reverse shell activity
    - rule: Reverse Shell Activity
      desc: Detect reverse shell connections
      condition: >
        spawned_process and
        (proc.args contains "nc -e" or
         proc.args contains "ncat -e" or
         proc.args contains "bash -i" or
         proc.args contains "sh -i" or
         proc.args contains "/dev/tcp/")
      output: >
        Reverse shell activity detected
        (user=%user.name command=%proc.cmdline container=%container.name
         image=%container.image.repository:%container.image.tag)
      priority: CRITICAL
      tags: [reverse_shell, malware, hashfoundry]
FALCO_CONFIG_EOF
    
    echo "✅ Falco configuration created"
    echo
}

# Функция для создания runtime security monitoring с Prometheus
create_runtime_monitoring() {
    echo "=== Creating Runtime Security Monitoring ==="
    
    # Создать Falco exporter для Prometheus
    cat << FALCO_EXPORTER_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: falco-exporter
  namespace: falco-system
  labels:
    app.kubernetes.io/name: "falco-exporter"
    app.kubernetes.io/component: "metrics-exporter"
    hashfoundry.io/security-type: "runtime-monitoring"
  annotations:
    hashfoundry.io/description: "Falco metrics exporter for Prometheus"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "falco-exporter"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "falco-exporter"
        app.kubernetes.io/component: "metrics-exporter"
        hashfoundry.io/security-type: "runtime-monitoring"
    spec:
      serviceAccountName: falco-exporter
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: falco-exporter
        image: falcosecurity/falco-exporter:0.8.2
        ports:
        - containerPort: 9376
          name: metrics
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
            cpu: "200m"
        env:
        - name: FALCO_GRPC_HOSTNAME
          value: "falco-grpc.falco-system.svc.cluster.local"
        - name: FALCO_GRPC_PORT
          value: "5060"
        livenessProbe:
          httpGet:
            path: /metrics
            port: 9376
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /metrics
            port: 9376
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: falco-exporter
  namespace: falco-system
  labels:
    app.kubernetes.io/name: "falco-exporter"
  annotations:
    hashfoundry.io/description: "ServiceAccount for Falco exporter"
---
apiVersion: v1
kind: Service
metadata:
  name: falco-exporter
  namespace: falco-system
  labels:
    app.kubernetes.io/name: "falco-exporter"
    app.kubernetes.io/component: "metrics-exporter"
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9376"
    prometheus.io/path: "/metrics"
    hashfoundry.io/description: "Falco metrics service"
spec:
  selector:
    app.kubernetes.io/name: "falco-exporter"
  ports:
  - name: metrics
    port: 9376
    targetPort: 9376
    protocol: TCP
FALCO_EXPORTER_EOF
    
    echo "✅ Falco exporter created"
    echo
}

# Функция для создания security alerts
create_security_alerts() {
    echo "=== Creating Security Alerts ==="
    
    cat << SECURITY_ALERTS_EOF | kubectl apply -f -
# PrometheusRule for runtime security alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: runtime-security-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: "hashfoundry-runtime-security"
    hashfoundry.io/component: "security-alerts"
  annotations:
    hashfoundry.io/description: "Runtime security alerts for HashFoundry cluster"
spec:
  groups:
  - name: runtime-security
    rules:
    - alert: FalcoSecurityViolation
      expr: |
        increase(falco_events_total{priority="Critical"}[5m]) > 0
      for: 0m
      labels:
        severity: critical
        category: runtime-security
      annotations:
        summary: "Critical security violation detected by Falco"
        description: "Falco detected {{ \$value }} critical security violations in the last 5 minutes"
    
    - alert: PrivilegeEscalationAttempt
      expr: |
        increase(falco_events_total{rule="Privilege Escalation Attempt"}[5m]) > 0
      for: 0m
      labels:
        severity: warning
        category: privilege-escalation
      annotations:
        summary: "Privilege escalation attempt detected"
        description: "Detected {{ \$value }} privilege escalation attempts"
    
    - alert: SuspiciousNetworkActivity
      expr: |
        increase(falco_events_total{rule="Suspicious Network Activity"}[5m]) > 5
      for: 2m
      labels:
        severity: warning
        category: network-security
      annotations:
        summary: "Suspicious network activity detected"
        description: "Detected {{ \$value }} suspicious network connections"
    
    - alert: CryptoMiningDetected
      expr: |
        increase(falco_events_total{rule="Crypto Mining Activity"}[5m]) > 0
      for: 0m
      labels:
        severity: critical
        category: malware
      annotations:
        summary: "Cryptocurrency mining detected"
        description: "Detected potential cryptocurrency mining activity"
    
    - alert: ContainerEscapeAttempt
      expr: |
        increase(falco_events_total{rule="Container Escape Attempt"}[5m]) > 0
      for: 0m
      labels:
        severity: critical
        category: container-security
      annotations:
        summary: "Container escape attempt detected"
        description: "Detected attempt to escape container sandbox"
    
    - alert: ReverseShellActivity
      expr: |
        increase(falco_events_total{rule="Reverse Shell Activity"}[5m]) > 0
      for: 0m
      labels:
        severity: critical
        category: malware
      annotations:
        summary: "Reverse shell activity detected"
        description: "Detected reverse shell connection attempt"
    
    - alert: FalcoAgentDown
      expr: |
        up{job="falco"} == 0
      for: 5m
      labels:
        severity: warning
        category: monitoring
      annotations:
        summary: "Falco agent is down"
        description: "Falco security monitoring agent on {{ \$labels.instance }} is not responding"
SECURITY_ALERTS_EOF
    
    echo "✅ Security alerts created"
    echo
}

# Функция для создания security dashboard
create_security_dashboard() {
    echo "=== Creating Security Dashboard ==="
    
    cat << SECURITY_DASHBOARD_EOF > runtime-security-dashboard.json
{
  "dashboard": {
    "id": null,
    "title": "HashFoundry Runtime Security",
    "tags": ["hashfoundry", "security", "runtime"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Security Events Overview",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(falco_events_total[5m]))",
            "legendFormat": "Events/sec"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 5}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Security Events by Priority",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum by (priority) (rate(falco_events_total[5m]))",
            "legendFormat": "{{ priority }}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Security Events Timeline",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum by (rule) (rate(falco_events_total[5m]))",
            "legendFormat": "{{ rule }}"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Top Security Rules Triggered",
        "type": "table",
        "targets": [
          {
            "expr": "topk(10, sum by (rule) (increase(falco_events_total[1h])))",
            "format": "table"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16}
      },
      {
        "id": 5,
        "title": "Security Events by Namespace",
        "type": "bargauge",
        "targets": [
          {
            "expr": "sum by (k8s_ns_name) (rate(falco_events_total[5m]))",
            "legendFormat": "{{ k8s_ns_name }}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
SECURITY_DASHBOARD_EOF
    
    echo "✅ Security dashboard configuration created: runtime-security-dashboard.json"
    echo
}

# Функция для создания мониторинга runtime security
create_runtime_security_monitoring() {
    echo "=== Creating Runtime Security Monitoring Script ==="
    
    cat << MONITORING_SCRIPT_EOF > runtime-security-monitor.sh
#!/bin/bash

echo "=== Runtime Security Monitoring ==="
echo "Monitoring runtime security in HashFoundry HA cluster"
echo

# Функция для проверки Falco status
check_falco_status() {
    echo "1. Falco Agent Status:"
    echo "====================="
    kubectl get pods -n falco-system -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,READY:.status.conditions[?(@.type=='Ready')].status"
    echo
    
    echo "Falco DaemonSet Status:"
    kubectl get daemonset -n falco-system falco -o custom-columns="NAME:.metadata.name,DESIRED:.status.desiredNumberScheduled,CURRENT:.status.currentNumberScheduled,READY:.status.numberReady"
    echo
}

# Функция для проверки security events
check_security_events() {
    echo "2. Recent Security Events:"
    echo "========================="
    
    # Получить логи Falco за последние 10 минут
    echo "Recent Falco alerts:"
    kubectl logs -n falco-system -l app.kubernetes.io/name=falco --since=10m | grep -E "(WARNING|ERROR|CRITICAL)" | tail -20
    echo
}

# Функция для анализа security metrics
analyze_security_metrics() {
    echo "3. Security Metrics Analysis:"
    echo "============================"
    
    # Проверить метрики Falco (если exporter доступен)
    if kubectl get service -n falco-system falco-exporter >/dev/null 2>&1; then
        echo "Falco metrics available at: http://falco-exporter.falco-system.svc.cluster.local:9376/metrics"
        
        # Попытаться получить метрики через port-forward
        kubectl port-forward -n falco-system service/falco-exporter 9376:9376 &
        PF_PID=\$!
        sleep 2
        
        echo "Security events summary:"
        curl -s http://localhost:9376/metrics | grep "falco_events_total" | head -10 || echo "Metrics not accessible"
        
        kill \$PF_PID 2>/dev/null
    else
        echo "Falco exporter not available"
    fi
    echo
}

# Функция для проверки suspicious activities
check_suspicious_activities() {
    echo "4. Suspicious Activities Check:"
    echo "=============================="
    
    # Проверить privileged containers
    echo "Privileged containers:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.privileged == true) | "⚠️  \(.metadata.namespace)/\(.metadata.name): PRIVILEGED"'
    echo
    
    # Проверить containers с host network
    echo "Host network containers:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.hostNetwork == true) | "⚠️  \(.metadata.namespace)/\(.metadata.name): HOST_NETWORK"'
    echo
    
    # Проверить containers с host PID
    echo "Host PID containers:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.hostPID == true) | "⚠️  \(.metadata.namespace)/\(.metadata.name): HOST_PID"'
    echo
}

# Функция для security compliance check
check_security_compliance() {
    echo "5. Security Compliance Check:"
    echo "============================"
    
    # Проверить pods без security context
    echo "Pods without security context:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext == null) | "⚠️  \(.metadata.namespace)/\(.metadata.name): NO_SECURITY_CONTEXT"' | head -10
    echo
    
    # Проверить containers running as root
    echo "Containers running as root:"
    kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.runAsUser == 0) | "⚠️  \(.metadata.namespace)/\(.metadata.name): ROOT_USER"' | head -10
    echo
}

# Функция для генерации security report
generate_security_report() {
    echo "6. Runtime Security Report:"
    echo "=========================="
    
    echo "✅ RUNTIME SECURITY STATUS:"
    echo "- Falco Agents: \$(kubectl get pods -n falco-system -l app.kubernetes.io/name=falco --no-headers | wc -l)"
    echo "- Monitored Nodes: \$(kubectl get nodes --no-headers | wc -l)"
    echo "- Security Policies: Active"
    echo
    
    echo "📊 SECURITY METRICS:"
    echo "- Privileged Containers: \$(kubectl get pods --all-namespaces -o json | jq '[.items[] | select(.spec.containers[]?.securityContext?.privileged == true)] | length')"
    echo "- Host Network Pods: \$(kubectl get pods --all-namespaces -o json | jq '[.items[] | select(.spec.hostNetwork == true)] | length')"
    echo "- Root User Containers: \$(kubectl get pods --all-namespaces -o json | jq '[.items[] | select(.spec.containers[]?.securityContext?.runAsUser == 0)] | length')"
    echo
    
    echo "🔧 RECOMMENDATIONS:"
    echo "1. Regular review of Falco rules and alerts"
    echo "2. Implement automated response to critical threats"
    echo "3. Regular security compliance audits"
    echo "4. Monitor and tune false positive rates"
    echo "5. Integrate with incident response workflows"
    echo
}

# Cleanup function
cleanup_test_resources() {
    echo "Cleaning up test resources..."
    # No test resources to cleanup for monitoring
    echo "✅ Cleanup completed"
}

# Запустить все проверки
check_falco_status
check_security_events
analyze_security_metrics
check_suspicious_activities
check_security_compliance
generate_security_report

# Cleanup при выходе
trap cleanup_test_resources EXIT

MONITORING_SCRIPT_EOF
    
    chmod +x runtime-security-monitor.sh
    
    echo "✅ Runtime security monitoring script created"
    echo "   - Use runtime-security-monitor.sh for security checks"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_runtime_security
            ;;
        "install-falco")
            install_falco
            ;;
        "falco-config")
            create_falco_config
            ;;
        "monitoring")
            create_runtime_monitoring
            ;;
        "alerts")
            create_security_alerts
            ;;
        "dashboard")
            create_security_dashboard
            ;;
        "monitor-script")
            create_runtime_security_monitoring
            ;;
        "all"|"")
            analyze_current_runtime_security
            install_falco
            create_falco_config
            create_runtime_monitoring
            create_security_alerts
            create_security_dashboard
            create_runtime_security_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze              - Analyze current runtime security"
            echo "  install-falco        - Install Falco runtime security"
            echo "  falco-config         - Create Falco configuration"
            echo "  monitoring           - Create runtime monitoring"
            echo "  alerts               - Create security alerts"
            echo "  dashboard            - Create security dashboard"
            echo "  monitor-script       - Create monitoring script"
            echo "  all                  - Full runtime security setup (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 install-falco"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x runtime-security-implementation.sh

# Запустить реализацию runtime security monitoring
./runtime-security-implementation.sh all
```

## 📋 **Архитектура Runtime Security:**

### **Компоненты мониторинга:**

| **Компонент** | **Функция** | **Технология** | **Область покрытия** |
|---------------|-------------|----------------|---------------------|
| **Falco** | Behavioral monitoring | eBPF/syscalls | System calls, processes |
| **Prometheus** | Metrics collection | Time-series DB | Security metrics |
| **Grafana** | Visualization | Dashboard | Security analytics |
| **AlertManager** | Incident response | Notification | Alert routing |

### **Типы угроз:**

#### **Runtime Threats:**
```yaml
# Примеры runtime угроз:
- Privilege Escalation    # Повышение привилегий
- Container Escape       # Побег из контейнера
- Crypto Mining         # Майнинг криптовалют
- Reverse Shell         # Обратные shell подключения
- Data Exfiltration     # Утечка данных
- Malware Execution     # Выполнение вредоносного ПО
```

## 🎯 **Практические команды:**

### **Управление Runtime Security:**
```bash
# Создать runtime security monitoring
./runtime-security-implementation.sh all

# Проверить Falco status
kubectl get pods -n falco-system

# Мониторинг security events
./runtime-security-monitor.sh

# Просмотр Falco логов
kubectl logs -n falco-system -l app.kubernetes.io/name=falco
```

### **Анализ security events:**
```bash
# Поиск критических событий
kubectl logs -n falco-system -l app.kubernetes.io/name=falco | grep CRITICAL

# Анализ privilege escalation
kubectl logs -n falco-system -l app.kubernetes.io/name=falco | grep "Privilege Escalation"

# Проверка crypto mining
kubectl logs -n falco-system -l app.kubernetes.io/name=falco | grep "Crypto Mining"
```

### **Security compliance проверки:**
```bash
# Проверить privileged containers
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.containers[]?.securityContext?.privileged == true)'

# Найти containers running as root
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.containers[]?.securityContext?.runAsUser == 0)'

# Проверить host network usage
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.hostNetwork == true)'
```

## 🔧 **Best Practices для Runtime Security:**

### **Мониторинг и обнаружение:**
- **Comprehensive coverage** - мониторинг всех nodes
- **Real-time detection** - немедленное обнаружение угроз
- **Behavioral analysis** - анализ аномального поведения
- **Threat intelligence** - интеграция с threat feeds

### **Реагирование на инциденты:**
- **Automated response** - автоматическое реагирование
- **Alert prioritization** - приоритизация алертов
- **Incident workflows** - процессы реагирования
- **Forensic capabilities** - возможности расследования

### **Операционные процессы:**
- **Regular rule updates** - обновление правил безопасности
- **False positive tuning** - настройка ложных срабатываний
- **Performance monitoring** - мониторинг производительности
- **Security training** - обучение команды

### **Интеграция и автоматизация:**
- **SIEM integration** - интеграция с SIEM системами
- **Compliance reporting** - отчеты о соответствии
- **Threat hunting** - активный поиск угроз
- **Security orchestration** - оркестрация безопасности

**Runtime Security Monitoring обеспечивает непрерывную защиту от угроз в реальном времени!**
