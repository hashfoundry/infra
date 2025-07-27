# 89. Kubernetes в Production

## 🎯 **Kubernetes в Production**

**Production Kubernetes** - это развертывание и эксплуатация Kubernetes кластера в продуктивной среде с учетом требований к надежности, безопасности, производительности, масштабируемости и операционной готовности для критически важных бизнес-приложений.

## 🏗️ **Ключевые области:**

### **1. Infrastructure & Architecture:**
- **High Availability** - высокая доступность
- **Scalability** - масштабируемость
- **Performance** - производительность
- **Network design** - проектирование сети

### **2. Security & Compliance:**
- **RBAC** - контроль доступа
- **Network policies** - сетевые политики
- **Pod security** - безопасность подов
- **Compliance** - соответствие требованиям

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ production readiness:**
```bash
# Проверить production readiness кластера
kubectl get nodes -o wide
kubectl get pods --all-namespaces | grep -v Running
```

### **2. Создание comprehensive production checklist:**
```bash
# Создать скрипт для production readiness
cat << 'EOF' > production-readiness-implementation.sh
#!/bin/bash

echo "=== Kubernetes Production Readiness Implementation ==="
echo "Implementing production-ready configuration for HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния production readiness
analyze_production_readiness() {
    echo "=== Production Readiness Analysis ==="
    
    echo "1. Cluster Architecture Assessment:"
    echo "=================================="
    
    # Проверить HA setup
    echo "Control Plane Nodes:"
    kubectl get nodes -l node-role.kubernetes.io/control-plane -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,VERSION:.status.nodeInfo.kubeletVersion,INTERNAL-IP:.status.addresses[?(@.type=='InternalIP')].address"
    echo
    
    echo "Worker Nodes:"
    kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,VERSION:.status.nodeInfo.kubeletVersion,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type"
    echo
    
    echo "2. Resource Allocation:"
    echo "======================"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "3. Critical System Components:"
    echo "============================="
    for component in kube-system monitoring nginx-ingress; do
        if kubectl get namespace "$component" >/dev/null 2>&1; then
            echo "Namespace: $component"
            kubectl get pods -n "$component" -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"
            echo
        fi
    done
}

# Функция для создания production security policies
create_production_security() {
    echo "=== Creating Production Security Policies ==="
    
    # Создать Pod Security Standards
    cat << PSS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hashfoundry-production
  labels:
    app.kubernetes.io/name: "hashfoundry-production"
    hashfoundry.io/environment: "production"
    hashfoundry.io/security-level: "restricted"
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
  annotations:
    hashfoundry.io/description: "Production namespace with restricted security policies"
PSS_EOF
    
    # Создать Network Policy для production
    cat << NETWORK_POLICY_EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: production-network-policy
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "production-network-policy"
    hashfoundry.io/security-component: "network"
  annotations:
    hashfoundry.io/description: "Network policy for production environment"
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          hashfoundry.io/environment: "production"
    - namespaceSelector:
        matchLabels:
          name: "nginx-ingress"
    - namespaceSelector:
        matchLabels:
          name: "monitoring"
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          hashfoundry.io/environment: "production"
  - to:
    - namespaceSelector:
        matchLabels:
          name: "kube-system"
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
NETWORK_POLICY_EOF
    
    # Создать RBAC для production
    cat << RBAC_EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: production-developer
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "production-rbac"
    hashfoundry.io/role-type: "developer"
  annotations:
    hashfoundry.io/description: "Developer role for production namespace"
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: production-operator
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "production-rbac"
    hashfoundry.io/role-type: "operator"
  annotations:
    hashfoundry.io/description: "Operator role for production namespace"
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: production-developers
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "production-rbac"
  annotations:
    hashfoundry.io/description: "Bind developers to production developer role"
subjects:
- kind: User
  name: developer@hashfoundry.com
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: production-developer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: production-operators
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "production-rbac"
  annotations:
    hashfoundry.io/description: "Bind operators to production operator role"
subjects:
- kind: User
  name: operator@hashfoundry.com
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: operators
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: production-operator
  apiGroup: rbac.authorization.k8s.io
RBAC_EOF
    
    echo "✅ Production security policies created"
    echo
}

# Функция для создания production monitoring
create_production_monitoring() {
    echo "=== Creating Production Monitoring ==="
    
    # Создать ServiceMonitor для production apps
    cat << SERVICE_MONITOR_EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: production-apps-monitor
  namespace: monitoring
  labels:
    app.kubernetes.io/name: "production-monitoring"
    hashfoundry.io/monitoring-target: "production"
  annotations:
    hashfoundry.io/description: "Service monitor for production applications"
spec:
  selector:
    matchLabels:
      hashfoundry.io/environment: "production"
      hashfoundry.io/monitoring: "enabled"
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
  namespaceSelector:
    matchNames:
    - hashfoundry-production
SERVICE_MONITOR_EOF
    
    # Создать PrometheusRule для production alerts
    cat << PROMETHEUS_RULE_EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: production-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: "production-alerts"
    hashfoundry.io/alert-severity: "critical"
  annotations:
    hashfoundry.io/description: "Critical alerts for production environment"
spec:
  groups:
  - name: production.critical
    rules:
    - alert: ProductionPodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="hashfoundry-production"}[5m]) > 0
      for: 5m
      labels:
        severity: critical
        environment: production
      annotations:
        summary: "Production pod is crash looping"
        description: "Pod {{ \$labels.pod }} in namespace {{ \$labels.namespace }} is crash looping"
    
    - alert: ProductionHighMemoryUsage
      expr: (container_memory_usage_bytes{namespace="hashfoundry-production"} / container_spec_memory_limit_bytes) > 0.9
      for: 10m
      labels:
        severity: warning
        environment: production
      annotations:
        summary: "Production pod high memory usage"
        description: "Pod {{ \$labels.pod }} memory usage is above 90%"
    
    - alert: ProductionHighCPUUsage
      expr: (rate(container_cpu_usage_seconds_total{namespace="hashfoundry-production"}[5m]) / container_spec_cpu_quota * container_spec_cpu_period) > 0.8
      for: 15m
      labels:
        severity: warning
        environment: production
      annotations:
        summary: "Production pod high CPU usage"
        description: "Pod {{ \$labels.pod }} CPU usage is above 80%"
    
    - alert: ProductionPodNotReady
      expr: kube_pod_status_ready{namespace="hashfoundry-production", condition="false"} == 1
      for: 5m
      labels:
        severity: critical
        environment: production
      annotations:
        summary: "Production pod not ready"
        description: "Pod {{ \$labels.pod }} has been not ready for more than 5 minutes"
PROMETHEUS_RULE_EOF
    
    echo "✅ Production monitoring created"
    echo
}

# Функция для создания production deployment template
create_production_deployment_template() {
    echo "=== Creating Production Deployment Template ==="
    
    cat << PROD_DEPLOYMENT_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-app-production
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "hashfoundry-app"
    app.kubernetes.io/component: "backend"
    app.kubernetes.io/version: "v1.0.0"
    app.kubernetes.io/part-of: "hashfoundry-platform"
    hashfoundry.io/environment: "production"
    hashfoundry.io/tier: "critical"
    hashfoundry.io/monitoring: "enabled"
  annotations:
    hashfoundry.io/description: "Production-ready application deployment"
    deployment.kubernetes.io/revision: "1"
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: "hashfoundry-app"
      hashfoundry.io/environment: "production"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "hashfoundry-app"
        app.kubernetes.io/component: "backend"
        app.kubernetes.io/version: "v1.0.0"
        hashfoundry.io/environment: "production"
        hashfoundry.io/tier: "critical"
        hashfoundry.io/monitoring: "enabled"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: hashfoundry-app
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx:1.21-alpine
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          runAsGroup: 3000
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
            ephemeral-storage: "100Mi"
          limits:
            cpu: "1"
            memory: "1Gi"
            ephemeral-storage: "1Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
          successThreshold: 1
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: var-cache
          mountPath: /var/cache
        - name: config
          mountPath: /etc/config
          readOnly: true
        - name: secrets
          mountPath: /etc/secrets
          readOnly: true
      volumes:
      - name: tmp
        emptyDir:
          sizeLimit: 100Mi
      - name: var-cache
        emptyDir:
          sizeLimit: 100Mi
      - name: config
        configMap:
          name: hashfoundry-app-config
          defaultMode: 0644
      - name: secrets
        secret:
          secretName: hashfoundry-app-secrets
          defaultMode: 0600
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                - hashfoundry-app
            topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: hashfoundry.io/workload-type
                operator: In
                values:
                - production
      tolerations:
      - key: hashfoundry.io/production
        operator: Equal
        value: "true"
        effect: NoSchedule
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: "hashfoundry-app"
---
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-app-service
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "hashfoundry-app"
    app.kubernetes.io/component: "service"
    hashfoundry.io/environment: "production"
    hashfoundry.io/monitoring: "enabled"
  annotations:
    hashfoundry.io/description: "Production service for HashFoundry app"
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: 9090
    protocol: TCP
  selector:
    app.kubernetes.io/name: "hashfoundry-app"
    hashfoundry.io/environment: "production"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hashfoundry-app
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: "hashfoundry-app"
  annotations:
    hashfoundry.io/description: "ServiceAccount for HashFoundry app"
automountServiceAccountToken: false
PROD_DEPLOYMENT_EOF
    
    echo "✅ Production deployment template created"
    echo
}

# Функция для создания production health checks
create_production_health_checks() {
    echo "=== Creating Production Health Checks ==="
    
    cat << HEALTH_CHECK_EOF > production-health-check.sh
#!/bin/bash

echo "=== Production Health Check ==="
echo "Comprehensive health assessment for HashFoundry production environment"
echo

# Функция для проверки cluster health
check_cluster_health() {
    echo "1. Cluster Health Assessment:"
    echo "============================"
    
    # API server health
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ API server: Healthy"
    else
        echo "❌ API server: Unhealthy"
        return 1
    fi
    
    # Node health
    NOT_READY=\$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    TOTAL_NODES=\$(kubectl get nodes --no-headers | wc -l)
    if [ "\$NOT_READY" -eq 0 ]; then
        echo "✅ Nodes: All \$TOTAL_NODES nodes ready"
    else
        echo "⚠️  Nodes: \$NOT_READY/\$TOTAL_NODES nodes not ready"
    fi
    
    # Control plane health
    CONTROL_PLANE_READY=\$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | grep -c " Ready ")
    TOTAL_CONTROL_PLANE=\$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)
    if [ "\$CONTROL_PLANE_READY" -eq "\$TOTAL_CONTROL_PLANE" ]; then
        echo "✅ Control Plane: All \$TOTAL_CONTROL_PLANE nodes ready"
    else
        echo "❌ Control Plane: Only \$CONTROL_PLANE_READY/\$TOTAL_CONTROL_PLANE nodes ready"
    fi
    echo
}

# Функция для проверки production applications
check_production_applications() {
    echo "2. Production Applications Health:"
    echo "================================="
    
    if kubectl get namespace hashfoundry-production >/dev/null 2>&1; then
        RUNNING_PODS=\$(kubectl get pods -n hashfoundry-production --no-headers | grep -c "Running" || echo "0")
        TOTAL_PODS=\$(kubectl get pods -n hashfoundry-production --no-headers | wc -l)
        
        if [ "\$TOTAL_PODS" -eq 0 ]; then
            echo "⚠️  No production pods found"
        elif [ "\$RUNNING_PODS" -eq "\$TOTAL_PODS" ]; then
            echo "✅ Production Pods: All \$TOTAL_PODS pods running"
        else
            echo "⚠️  Production Pods: \$RUNNING_PODS/\$TOTAL_PODS pods running"
            kubectl get pods -n hashfoundry-production --no-headers | grep -v "Running"
        fi
        
        # Check services
        SERVICES=\$(kubectl get services -n hashfoundry-production --no-headers | wc -l)
        echo "📊 Production Services: \$SERVICES services deployed"
        
        # Check deployments
        kubectl get deployments -n hashfoundry-production -o custom-columns="NAME:.metadata.name,READY:.status.readyReplicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas"
    else
        echo "⚠️  Production namespace not found"
    fi
    echo
}

# Функция для проверки resource utilization
check_resource_utilization() {
    echo "3. Resource Utilization:"
    echo "======================="
    
    # Node resource usage
    echo "Node Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    # Production pods resource usage
    echo "Production Pods Resource Usage:"
    kubectl top pods -n hashfoundry-production 2>/dev/null || echo "Metrics server not available"
    echo
}

# Функция для проверки security compliance
check_security_compliance() {
    echo "4. Security Compliance:"
    echo "======================"
    
    # Check Pod Security Standards
    if kubectl get namespace hashfoundry-production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null | grep -q "restricted"; then
        echo "✅ Pod Security Standards: Restricted mode enabled"
    else
        echo "⚠️  Pod Security Standards: Not properly configured"
    fi
    
    # Check Network Policies
    NETWORK_POLICIES=\$(kubectl get networkpolicies -n hashfoundry-production --no-headers | wc -l)
    if [ "\$NETWORK_POLICIES" -gt 0 ]; then
        echo "✅ Network Policies: \$NETWORK_POLICIES policies active"
    else
        echo "⚠️  Network Policies: No policies found"
    fi
    
    # Check RBAC
    ROLES=\$(kubectl get roles -n hashfoundry-production --no-headers | wc -l)
    ROLEBINDINGS=\$(kubectl get rolebindings -n hashfoundry-production --no-headers | wc -l)
    echo "📊 RBAC: \$ROLES roles, \$ROLEBINDINGS role bindings"
    echo
}

# Функция для проверки monitoring and alerting
check_monitoring_alerting() {
    echo "5. Monitoring and Alerting:"
    echo "=========================="
    
    # Check Prometheus
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus | grep -q Running; then
        echo "✅ Prometheus: Running"
    else
        echo "❌ Prometheus: Not running"
    fi
    
    # Check Grafana
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana | grep -q Running; then
        echo "✅ Grafana: Running"
    else
        echo "❌ Grafana: Not running"
    fi
    
    # Check ServiceMonitors
    SERVICE_MONITORS=\$(kubectl get servicemonitors -n monitoring --no-headers | wc -l)
    echo "📊 Service Monitors: \$SERVICE_MONITORS configured"
    
    # Check PrometheusRules
    PROMETHEUS_RULES=\$(kubectl get prometheusrules -n monitoring --no-headers | wc -l)
    echo "📊 Prometheus Rules: \$PROMETHEUS_RULES configured"
    echo
}

# Функция для проверки backup and DR
check_backup_dr() {
    echo "6. Backup and Disaster Recovery:"
    echo "==============================="
    
    # Check backup systems
    if kubectl get namespace backup-system >/dev/null 2>&1; then
        BACKUP_JOBS=\$(kubectl get cronjobs -n backup-system --no-headers | wc -l)
        echo "✅ Backup System: \$BACKUP_JOBS backup jobs configured"
    else
        echo "⚠️  Backup System: Not configured"
    fi
    
    # Check Velero
    if kubectl get namespace velero >/dev/null 2>&1; then
        if kubectl get pods -n velero -l app.kubernetes.io/name=velero | grep -q Running; then
            echo "✅ Velero: Running"
            SCHEDULES=\$(kubectl get schedules -n velero --no-headers | wc -l)
            echo "📊 Backup Schedules: \$SCHEDULES configured"
        else
            echo "⚠️  Velero: Not running"
        fi
    else
        echo "⚠️  Velero: Not installed"
    fi
    echo
}

# Функция для генерации production readiness score
generate_readiness_score() {
    echo "7. Production Readiness Score:"
    echo "============================="
    
    SCORE=0
    TOTAL_CHECKS=20
    
    # Cluster health (4 points)
    if kubectl cluster-info >/dev/null 2>&1; then SCORE=\$((SCORE + 1)); fi
    NOT_READY=\$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "\$NOT_READY" -eq 0 ]; then SCORE=\$((SCORE + 1)); fi
    CONTROL_PLANE_READY=\$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | grep -c " Ready ")
    TOTAL_CONTROL_PLANE=\$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)
    if [ "\$CONTROL_PLANE_READY" -eq "\$TOTAL_CONTROL_PLANE" ]; then SCORE=\$((SCORE + 1)); fi
    if [ "\$TOTAL_CONTROL_PLANE" -ge 3 ]; then SCORE=\$((SCORE + 1)); fi
    
    # Production applications (4 points)
    if kubectl get namespace hashfoundry-production >/dev/null 2>&1; then SCORE=\$((SCORE + 1)); fi
    RUNNING_PODS=\$(kubectl get pods -n hashfoundry-production --no-headers | grep -c "Running" || echo "0")
    TOTAL_PODS=\$(kubectl get pods -n hashfoundry-production --no-headers | wc -l)
    if [ "\$TOTAL_PODS" -gt 0 ] && [ "\$RUNNING_PODS" -eq "\$TOTAL_PODS" ]; then SCORE=\$((SCORE + 1)); fi
    DEPLOYMENTS=\$(kubectl get deployments -n hashfoundry-production --no-headers | wc -l)
    if [ "\$DEPLOYMENTS" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    SERVICES=\$(kubectl get services -n hashfoundry-production --no-headers | wc -l)
    if [ "\$SERVICES" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    
    # Security (4 points)
    if kubectl get namespace hashfoundry-production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null | grep -q "restricted"; then SCORE=\$((SCORE + 1)); fi
    NETWORK_POLICIES=\$(kubectl get networkpolicies -n hashfoundry-production --no-headers | wc -l)
    if [ "\$NETWORK_POLICIES" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    ROLES=\$(kubectl get roles -n hashfoundry-production --no-headers | wc -l)
    if [ "\$ROLES" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    ROLEBINDINGS=\$(kubectl get rolebindings -n hashfoundry-production --no-headers | wc -l)
    if [ "\$ROLEBINDINGS" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    
    # Monitoring (4 points)
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus | grep -q Running; then SCORE=\$((SCORE + 1)); fi
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana | grep -q Running; then SCORE=\$((SCORE + 1)); fi
    SERVICE_MONITORS=\$(kubectl get servicemonitors -n monitoring --no-headers | wc -l)
    if [ "\$SERVICE_MONITORS" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    PROMETHEUS_RULES=\$(kubectl get prometheusrules -n monitoring --no-headers | wc -l)
    if [ "\$PROMETHEUS_RULES" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    
    # Backup and DR (4 points)
    if kubectl get namespace backup-system >/dev/null 2>&1; then SCORE=\$((SCORE + 1)); fi
    if kubectl get namespace velero >/dev/null 2>&1; then SCORE=\$((SCORE + 1)); fi
    BACKUP_JOBS=\$(kubectl get cronjobs -n backup-system --no-headers | wc -l)
    if [ "\$BACKUP_JOBS" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    SCHEDULES=\$(kubectl get schedules -n velero --no-headers | wc -l)
    if [ "\$SCHEDULES" -gt 0 ]; then SCORE=\$((SCORE + 1)); fi
    
    # Calculate percentage
    PERCENTAGE=\$((SCORE * 100 / TOTAL_CHECKS))
    
    echo "Production Readiness Score: \$SCORE/\$TOTAL_CHECKS (\$PERCENTAGE%)"
    echo
    
    if [ "\$PERCENTAGE" -ge 90 ]; then
        echo "🟢 EXCELLENT: Production ready!"
    elif [ "\$PERCENTAGE" -ge 75 ]; then
        echo "🟡 GOOD: Minor improvements needed"
    elif [ "\$PERCENTAGE" -ge 50 ]; then
        echo "🟠 FAIR: Significant improvements required"
    else
        echo "🔴 POOR: Major work needed before production"
    fi
    echo
}

# Main execution
case "\$1" in
    "cluster")
        check_cluster_health
        ;;
    "apps")
        check_production_applications
        ;;
    "resources")
        check_resource_utilization
        ;;
    "security")
        check_security_compliance
        ;;
    "monitoring")
        check_monitoring_alerting
        ;;
    "backup")
        check_backup_dr
        ;;
    "score")
        generate_readiness_score
        ;;
    "all"|"")
        check_cluster_health
        check_production_applications
        check_resource_utilization
        check_security_compliance
        check_monitoring_alerting
        check_backup_dr
        generate_readiness_score
        ;;
    *)
        echo "Usage: \$0 [cluster|apps|resources|security|monitoring|backup|score|all]"
        echo ""
        echo "Options:"
        echo "  cluster     - Check cluster health"
        echo "  apps        - Check production applications"
        echo "  resources   - Check resource utilization"
        echo "  security    - Check security compliance"
        echo "  monitoring  - Check monitoring and alerting"
        echo "  backup      - Check backup and DR"
        echo "  score       - Generate readiness score"
        echo "  all         - Run all checks (default)"
        ;;
esac

HEALTH_CHECK_EOF
    
    chmod +x production-health-check.sh
    
    echo "✅ Production health check script created: production-health-check.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_production_readiness
            ;;
        "security")
            create_production_security
            ;;
        "monitoring")
            create_production_monitoring
            ;;
        "deployment")
            create_production_deployment_template
            ;;
        "health")
            create_production_health_checks
            ;;
        "all"|"")
            analyze_production_readiness
            create_production_security
            create_production_monitoring
            create_production_deployment_template
            create_production_health_checks
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze      - Analyze production readiness"
            echo "  security     - Create production security policies"
            echo "  monitoring   - Create production monitoring"
            echo "  deployment   - Create production deployment template"
            echo "  health       - Create production health checks"
            echo "  all          - Create all production components (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 security"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x production-readiness-implementation.sh

# Запустить создание production readiness framework
./production-readiness-implementation.sh all
```

## 📋 **Production Checklist:**

### **Infrastructure Requirements:**

| **Компонент** | **Минимум** | **Рекомендуется** | **Enterprise** |
|---------------|-------------|-------------------|----------------|
| **Control Plane** | 1 узел | 3 узла | 5+ узлов |
| **Worker Nodes** | 2 узла | 3+ узла | 5+ узлов |
| **CPU per Node** | 2 vCPU | 4 vCPU | 8+ vCPU |
| **Memory per Node** | 4 GB | 8 GB | 16+ GB |
| **Storage** | Local | Network | Distributed |

### **Security Requirements:**
- **Pod Security Standards** - Restricted mode
- **Network Policies** - Микросегментация
- **RBAC** - Принцип минимальных привилегий
- **Image Security** - Сканирование уязвимостей
- **Secrets Management** - Внешние системы управления

## 🎯 **Практические команды:**

### **Production readiness assessment:**
```bash
# Создать production framework
./production-readiness-implementation.sh all

# Проверить production health
./production-health-check.sh all

# Получить readiness score
./production-health-check.sh score
```

### **Security validation:**
```bash
# Проверить Pod Security Standards
kubectl get namespace hashfoundry-production -o yaml | grep pod-security

# Проверить Network Policies
kubectl get networkpolicies -n hashfoundry-production

# Проверить RBAC
kubectl auth can-i --list --as=developer@hashfoundry.com -n hashfoundry-production
```

### **Performance monitoring:**
```bash
# Проверить resource utilization
kubectl top nodes
kubectl top pods -n hashfoundry-production

# Проверить HPA status
kubectl get hpa -n hashfoundry-production

# Проверить metrics
kubectl get --raw /metrics | grep hashfoundry
```

## 🔧 **Best Practices для Production:**

### **Reliability:**
- **High Availability** - мультизональное развертывание
- **Auto-scaling** - HPA и VPA
- **Health checks** - liveness, readiness, startup probes
- **Circuit breakers** - защита от каскадных сбоев

### **Security:**
- **Zero-trust networking** - сетевые политики
- **Least privilege** - минимальные права доступа
- **Image scanning** - проверка уязвимостей
- **Runtime security** - мониторинг поведения

### **Observability:**
- **Comprehensive monitoring** - метрики, логи, трейсы
- **Alerting** - проактивные уведомления
- **Dashboards** - визуализация состояния
- **SLI/SLO** - индикаторы уровня сервиса

### **Operations:**
- **GitOps** - декларативное управление
- **CI/CD** - автоматизация развертывания
- **Backup & DR** - планы восстановления
- **Documentation** - операционные процедуры

**Production Kubernetes требует комплексного подхода к надежности, безопасности и операционной готовности!**
