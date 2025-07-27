# 106. Как настроить алертинг в Kubernetes

## 🎯 **Как настроить алертинг в Kubernetes**

**Алертинг** - критически важная часть мониторинга, которая обеспечивает проактивное уведомление о проблемах в кластере до того, как они повлияют на пользователей.

## 🚨 **Компоненты системы алертинга:**

### **1. Prometheus AlertManager:**
- **Группировка алертов** - объединение похожих алертов
- **Подавление алертов** - предотвращение спама
- **Маршрутизация** - отправка алертов нужным получателям
- **Интеграции** - Slack, email, PagerDuty, webhook

### **2. Типы алертов:**
- **Infrastructure alerts** - проблемы с узлами, дисками
- **Application alerts** - ошибки приложений, производительность
- **Security alerts** - нарушения безопасности
- **Business alerts** - бизнес-метрики

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive alerting setup toolkit
cat << 'EOF' > kubernetes-alerting-setup-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Alerting Setup Toolkit ==="
echo "Comprehensive alerting configuration for HashFoundry HA cluster"
echo

# Функция для создания AlertManager
create_alertmanager() {
    echo "=== Creating AlertManager ==="
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # AlertManager ConfigMap
    cat << ALERTMANAGER_CONFIG_EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
  labels:
    app: alertmanager
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'alertmanager@hashfoundry.com'
      slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
      routes:
      - match:
          severity: critical
        receiver: 'critical-alerts'
      - match:
          severity: warning
        receiver: 'warning-alerts'
      - match:
          alertname: DeadMansSwitch
        receiver: 'null'
    
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://localhost:5001/'
    
    - name: 'critical-alerts'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#critical-alerts'
        title: 'Critical Alert - {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
      email_configs:
      - to: 'admin@hashfoundry.com'
        subject: 'Critical Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
    
    - name: 'warning-alerts'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#warnings'
        title: 'Warning - {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
    
    - name: 'null'
    
    inhibit_rules:
    - source_match:
        severity: 'critical'
      target_match:
        severity: 'warning'
      equal: ['alertname', 'cluster', 'service']
ALERTMANAGER_CONFIG_EOF
    
    # AlertManager Deployment
    cat << ALERTMANAGER_DEPLOYMENT_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
  labels:
    app: alertmanager
spec:
  replicas: 2
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.25.0
        ports:
        - containerPort: 9093
        args:
        - '--config.file=/etc/alertmanager/alertmanager.yml'
        - '--storage.path=/alertmanager'
        - '--web.external-url=http://localhost:9093'
        - '--cluster.listen-address=0.0.0.0:9094'
        - '--cluster.peer=alertmanager-0.alertmanager:9094'
        - '--cluster.peer=alertmanager-1.alertmanager:9094'
        volumeMounts:
        - name: config
          mountPath: /etc/alertmanager
        - name: storage
          mountPath: /alertmanager
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
      volumes:
      - name: config
        configMap:
          name: alertmanager-config
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
  labels:
    app: alertmanager
spec:
  selector:
    app: alertmanager
  ports:
  - port: 9093
    targetPort: 9093
    name: web
  - port: 9094
    targetPort: 9094
    name: cluster
ALERTMANAGER_DEPLOYMENT_EOF
    
    echo "✅ AlertManager created"
    echo
}

# Функция для создания Prometheus rules
create_prometheus_rules() {
    echo "=== Creating Prometheus Alert Rules ==="
    
    cat << PROMETHEUS_RULES_EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: monitoring
  labels:
    app: prometheus
data:
  kubernetes.rules.yml: |
    groups:
    - name: kubernetes.rules
      rules:
      
      # Node alerts
      - alert: NodeDown
        expr: up{job="kubernetes-nodes"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ \$labels.instance }} is down"
          description: "Node {{ \$labels.instance }} has been down for more than 5 minutes"
      
      - alert: NodeHighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on node {{ \$labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes"
      
      - alert: NodeHighMemory
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on node {{ \$labels.instance }}"
          description: "Memory usage is above 85% for more than 5 minutes"
      
      - alert: NodeDiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on node {{ \$labels.instance }}"
          description: "Disk usage is above 85% on {{ \$labels.mountpoint }}"
      
      # Pod alerts
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} is crash looping"
          description: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} has restarted {{ \$value }} times in the last 15 minutes"
      
      - alert: PodNotReady
        expr: kube_pod_status_ready{condition="false"} == 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} not ready"
          description: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} has been in not ready state for more than 10 minutes"
      
      # Deployment alerts
      - alert: DeploymentReplicasMismatch
        expr: kube_deployment_spec_replicas != kube_deployment_status_available_replicas
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Deployment {{ \$labels.namespace }}/{{ \$labels.deployment }} has mismatched replicas"
          description: "Deployment {{ \$labels.namespace }}/{{ \$labels.deployment }} has {{ \$labels.spec_replicas }} desired but {{ \$labels.available_replicas }} available"
      
      # etcd alerts
      - alert: EtcdDown
        expr: up{job="kubernetes-apiservers"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "etcd is down"
          description: "etcd has been down for more than 5 minutes"
      
      - alert: EtcdHighLatency
        expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "etcd high latency"
          description: "etcd 99th percentile latency is {{ \$value }}s"
      
      # API Server alerts
      - alert: APIServerDown
        expr: up{job="kubernetes-apiservers"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "API Server is down"
          description: "API Server has been down for more than 5 minutes"
      
      - alert: APIServerHighLatency
        expr: histogram_quantile(0.99, rate(apiserver_request_duration_seconds_bucket[5m])) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "API Server high latency"
          description: "API Server 99th percentile latency is {{ \$value }}s"
      
      # Storage alerts
      - alert: PersistentVolumeClaimPending
        expr: kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "PVC {{ \$labels.namespace }}/{{ \$labels.persistentvolumeclaim }} is pending"
          description: "PVC {{ \$labels.namespace }}/{{ \$labels.persistentvolumeclaim }} has been pending for more than 10 minutes"
      
      # Dead man's switch
      - alert: DeadMansSwitch
        expr: vector(1)
        labels:
          severity: none
        annotations:
          summary: "Alerting DeadMansSwitch"
          description: "This is a DeadMansSwitch meant to ensure that the entire alerting pipeline is functional"
PROMETHEUS_RULES_EOF
    
    echo "✅ Prometheus alert rules created"
    echo
}

# Функция для создания Grafana alerts
create_grafana_alerts() {
    echo "=== Creating Grafana Alert Rules ==="
    
    cat << GRAFANA_ALERTS_EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-alerts
  namespace: monitoring
  labels:
    app: grafana
data:
  alerts.yaml: |
    groups:
    - name: hashfoundry-alerts
      folder: HashFoundry
      interval: 1m
      rules:
      - uid: cluster-health
        title: Cluster Health Alert
        condition: A
        data:
        - refId: A
          queryType: prometheus
          model:
            expr: up{job="kubernetes-nodes"}
            interval: 1m
        noDataState: NoData
        execErrState: Alerting
        for: 5m
        annotations:
          summary: "Cluster node health check"
          description: "One or more nodes are down"
        labels:
          team: platform
          severity: critical
      
      - uid: high-cpu-usage
        title: High CPU Usage
        condition: B
        data:
        - refId: B
          queryType: prometheus
          model:
            expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
            interval: 1m
        noDataState: NoData
        execErrState: Alerting
        for: 10m
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on {{ \$labels.instance }}"
        labels:
          team: platform
          severity: warning
GRAFANA_ALERTS_EOF
    
    echo "✅ Grafana alert rules created"
    echo
}

# Функция для создания notification channels
create_notification_channels() {
    echo "=== Creating Notification Channels ==="
    
    cat << NOTIFICATION_SCRIPT_EOF > setup-notification-channels.sh
#!/bin/bash

echo "=== Setting up Notification Channels ==="

# Slack webhook setup
cat << SLACK_WEBHOOK_EOF > slack-webhook-test.sh
#!/bin/bash

SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

curl -X POST -H 'Content-type: application/json' \\
    --data '{
        "text": "Test alert from HashFoundry HA cluster",
        "channel": "#alerts",
        "username": "AlertManager",
        "icon_emoji": ":warning:"
    }' \\
    \$SLACK_WEBHOOK_URL

SLACK_WEBHOOK_EOF

chmod +x slack-webhook-test.sh

# Email notification setup
cat << EMAIL_SETUP_EOF > email-notification-setup.sh
#!/bin/bash

echo "Email notification setup for AlertManager"
echo "Configure SMTP settings in AlertManager config:"
echo "smtp_smarthost: 'your-smtp-server:587'"
echo "smtp_from: 'alerts@hashfoundry.com'"
echo "smtp_auth_username: 'your-username'"
echo "smtp_auth_password: 'your-password'"

EMAIL_SETUP_EOF

chmod +x email-notification-setup.sh

# PagerDuty integration
cat << PAGERDUTY_SETUP_EOF > pagerduty-integration.sh
#!/bin/bash

echo "PagerDuty integration setup"
echo "Add to AlertManager config:"
echo "pagerduty_configs:"
echo "- service_key: 'YOUR_PAGERDUTY_SERVICE_KEY'"
echo "  description: '{{ .GroupLabels.alertname }}'"
echo "  severity: '{{ .CommonLabels.severity }}'"

PAGERDUTY_SETUP_EOF

chmod +x pagerduty-integration.sh

echo "✅ Notification channel scripts created"

NOTIFICATION_SCRIPT_EOF
    
    chmod +x setup-notification-channels.sh
    echo "✅ Notification channels setup script created"
    echo
}

# Функция для тестирования алертов
create_alert_testing() {
    echo "=== Creating Alert Testing Tools ==="
    
    cat << ALERT_TEST_EOF > test-alerts.sh
#!/bin/bash

echo "=== Alert Testing Toolkit ==="

# Function to test AlertManager
test_alertmanager() {
    echo "Testing AlertManager..."
    
    # Check AlertManager status
    kubectl get pods -n monitoring -l app=alertmanager
    
    # Test AlertManager API
    kubectl port-forward -n monitoring svc/alertmanager 9093:9093 &
    PF_PID=\$!
    sleep 3
    
    # Send test alert
    curl -XPOST http://localhost:9093/api/v1/alerts -H "Content-Type: application/json" -d '[
        {
            "labels": {
                "alertname": "TestAlert",
                "severity": "warning",
                "instance": "test-instance"
            },
            "annotations": {
                "summary": "This is a test alert",
                "description": "Testing alert functionality"
            },
            "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
            "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%S.%3NZ)'"
        }
    ]'
    
    kill \$PF_PID 2>/dev/null
    echo "Test alert sent to AlertManager"
}

# Function to trigger CPU alert
trigger_cpu_alert() {
    echo "Triggering high CPU alert..."
    
    kubectl run cpu-stress --image=progrium/stress --rm -it --restart=Never -- --cpu 2 --timeout 300s
}

# Function to trigger memory alert
trigger_memory_alert() {
    echo "Triggering high memory alert..."
    
    kubectl run memory-stress --image=progrium/stress --rm -it --restart=Never -- --vm 1 --vm-bytes 1G --timeout 300s
}

# Function to check alert rules
check_alert_rules() {
    echo "Checking Prometheus alert rules..."
    
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
    PF_PID=\$!
    sleep 3
    
    curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.type=="alerting") | {name: .name, state: .state}'
    
    kill \$PF_PID 2>/dev/null
}

# Main function
case "\$1" in
    "alertmanager")
        test_alertmanager
        ;;
    "cpu")
        trigger_cpu_alert
        ;;
    "memory")
        trigger_memory_alert
        ;;
    "rules")
        check_alert_rules
        ;;
    "all"|"")
        test_alertmanager
        check_alert_rules
        ;;
    *)
        echo "Usage: \$0 [alertmanager|cpu|memory|rules|all]"
        ;;
esac

ALERT_TEST_EOF
    
    chmod +x test-alerts.sh
    echo "✅ Alert testing tools created"
    echo
}

# Основная функция
main() {
    case "$1" in
        "alertmanager")
            create_alertmanager
            ;;
        "rules")
            create_prometheus_rules
            ;;
        "grafana")
            create_grafana_alerts
            ;;
        "notifications")
            create_notification_channels
            ;;
        "test")
            create_alert_testing
            ./test-alerts.sh
            ;;
        "all"|"")
            create_alertmanager
            create_prometheus_rules
            create_grafana_alerts
            create_notification_channels
            create_alert_testing
            ;;
        *)
            echo "Usage: $0 [alertmanager|rules|grafana|notifications|test|all]"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubernetes-alerting-setup-toolkit.sh
./kubernetes-alerting-setup-toolkit.sh all
```

## 🎯 **Практические команды:**

### **Настройка алертинга:**
```bash
# Создать полную систему алертинга
./kubernetes-alerting-setup-toolkit.sh all

# Тестировать алерты
./test-alerts.sh all

# Проверить статус AlertManager
kubectl get pods -n monitoring -l app=alertmanager
```

### **Управление алертами:**
```bash
# Просмотр активных алертов
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Открыть http://localhost:9093

# Проверка правил Prometheus
kubectl get configmap prometheus-rules -n monitoring -o yaml
```

**Правильно настроенный алертинг обеспечивает проактивное управление инцидентами!**
