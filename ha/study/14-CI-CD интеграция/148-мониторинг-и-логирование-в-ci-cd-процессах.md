# 148. Мониторинг и логирование в CI/CD процессах

## 🎯 **Основные концепции:**

| Аспект | Традиционный подход | Современный CI/CD мониторинг |
|--------|---------------------|------------------------------|
| **Видимость процессов** | Ограниченная | Полная observability |
| **Сбор метрик** | Ручной | Автоматизированный |
| **Алертинг** | Реактивный | Проактивный |
| **Анализ трендов** | Отсутствует | Детальная аналитика |
| **DORA метрики** | Не отслеживаются | Автоматический расчет |
| **Логирование** | Неструктурированное | Структурированное с контекстом |
| **Дашборды** | Статические отчеты | Интерактивные real-time дашборды |
| **Интеграция** | Изолированные системы | Единая платформа мониторинга |
| **Время реакции** | Часы/дни | Минуты/секунды |
| **Корреляция событий** | Ручная | Автоматическая |
| **Capacity planning** | Интуитивный | Data-driven |
| **Troubleshooting** | Сложный | Упрощенный с контекстом |

## 🏆 **Мониторинг и логирование CI/CD - что это такое?**

**Мониторинг и логирование CI/CD процессов** — это комплексная система наблюдения за всеми этапами конвейера доставки программного обеспечения, включающая сбор метрик производительности, отслеживание DORA показателей, структурированное логирование событий и автоматический алертинг для обеспечения надежности и непрерывного улучшения процессов разработки.

### **Ключевые компоненты системы мониторинга:**
1. **Metrics Collection** - сбор метрик производительности пайплайнов
2. **DORA Metrics** - отслеживание ключевых показателей DevOps
3. **Structured Logging** - централизованное логирование с контекстом
4. **Real-time Dashboards** - визуализация состояния CI/CD процессов
5. **Proactive Alerting** - уведомления о проблемах и аномалиях
6. **Trend Analysis** - анализ трендов для оптимизации

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующего мониторинга:**
```bash
# Проверка Prometheus для сбора метрик
kubectl get pods -n monitoring | grep prometheus

# Анализ ServiceMonitor'ов для CI/CD компонентов
kubectl get servicemonitors -A -o json | jq -r '
  .items[] | 
  select(.metadata.name | test("argocd|jenkins|gitlab")) | 
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.selector.matchLabels)"
'

# Проверка метрик ArgoCD
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring &
curl -s "http://localhost:9090/api/v1/query?query=argocd_app_info" | jq '.data.result[].metric'

# Анализ логов ArgoCD Application Controller
kubectl logs -f deployment/argocd-application-controller -n argocd --tail=100

# Проверка событий развертываний
kubectl get events --sort-by=.metadata.creationTimestamp -A | grep -E "(Deploy|Rollout|Sync)"

# Анализ Grafana дашбордов
kubectl get configmaps -n monitoring | grep dashboard

# Проверка алертов
kubectl get prometheusrules -A | grep -E "(argocd|cicd|deploy)"
```

### **2. Мониторинг ArgoCD приложений:**
```bash
# Статус всех ArgoCD приложений
kubectl get applications -n argocd -o json | jq -r '
  .items[] | 
  "\(.metadata.name): \(.status.health.status) / \(.status.sync.status)"
'

# История синхронизаций
kubectl get applications -n argocd -o json | jq -r '
  .items[] | 
  "\(.metadata.name): Last sync: \(.status.operationState.finishedAt // "Never")"
'

# Анализ ресурсов приложений
kubectl get applications -n argocd -o json | jq -r '
  .items[] | 
  "\(.metadata.name): \(.status.resources | length) resources"
'

# Проверка метрик синхронизации
kubectl exec -n monitoring deployment/prometheus-server -- \
  promtool query instant 'argocd_app_sync_total'

# Мониторинг времени синхронизации
kubectl exec -n monitoring deployment/prometheus-server -- \
  promtool query instant 'argocd_app_reconcile_bucket'
```

### **3. Анализ производительности пайплайнов:**
```bash
# Проверка времени развертывания через kubectl events
kubectl get events -A --sort-by=.metadata.creationTimestamp | \
  grep -E "(Deployment|ReplicaSet)" | \
  tail -20

# Анализ ресурсов во время развертывания
kubectl top pods -A --sort-by=cpu

# Мониторинг сетевой активности
kubectl get networkpolicies -A
kubectl get services -A --field-selector spec.type=LoadBalancer

# Проверка storage I/O во время CI/CD
kubectl get pvc -A -o json | jq -r '
  .items[] | 
  "\(.metadata.namespace)/\(.metadata.name): \(.status.phase) - \(.spec.resources.requests.storage)"
'
```

## 🛠️ **Comprehensive CI/CD Monitoring Implementation:**

### **1. Prometheus Configuration для CI/CD метрик:**
```yaml
# k8s/monitoring/prometheus-cicd-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-cicd-config
  namespace: monitoring
data:
  cicd-rules.yml: |
    groups:
    - name: cicd.rules
      interval: 30s
      rules:
      # DORA Metrics
      - record: dora:deployment_frequency
        expr: |
          increase(argocd_app_sync_total{phase="Succeeded"}[24h])
      
      - record: dora:lead_time_seconds
        expr: |
          histogram_quantile(0.95, 
            rate(argocd_app_reconcile_bucket[5m])
          )
      
      - record: dora:change_failure_rate
        expr: |
          (
            rate(argocd_app_sync_total{phase="Failed"}[24h]) /
            rate(argocd_app_sync_total[24h])
          ) * 100
      
      - record: dora:mttr_seconds
        expr: |
          avg_over_time(
            (time() - argocd_app_health_status{health_status!="Healthy"} > 0)[24h:]
          )
      
      # Pipeline Performance Metrics
      - record: cicd:pipeline_duration_seconds
        expr: |
          histogram_quantile(0.95,
            rate(argocd_app_reconcile_bucket[5m])
          )
      
      - record: cicd:sync_success_rate
        expr: |
          (
            rate(argocd_app_sync_total{phase="Succeeded"}[5m]) /
            rate(argocd_app_sync_total[5m])
          ) * 100
      
      - record: cicd:apps_out_of_sync
        expr: |
          count(argocd_app_info{sync_status!="Synced"})
      
      - record: cicd:apps_unhealthy
        expr: |
          count(argocd_app_info{health_status!="Healthy"})
      
      # Resource Utilization
      - record: cicd:controller_cpu_usage
        expr: |
          rate(container_cpu_usage_seconds_total{
            pod=~"argocd-application-controller-.*",
            container="argocd-application-controller"
          }[5m])
      
      - record: cicd:controller_memory_usage
        expr: |
          container_memory_usage_bytes{
            pod=~"argocd-application-controller-.*",
            container="argocd-application-controller"
          }
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
  namespaceSelector:
    matchNames:
    - argocd
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
  namespaceSelector:
    matchNames:
    - argocd
```

### **2. Grafana Dashboard для DORA метрик:**
```yaml
# k8s/monitoring/dora-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dora-metrics-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dora-metrics.json: |
    {
      "dashboard": {
        "id": null,
        "title": "DORA Metrics - HashFoundry CI/CD",
        "tags": ["dora", "cicd", "devops"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Deployment Frequency",
            "type": "stat",
            "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
            "targets": [
              {
                "expr": "dora:deployment_frequency",
                "legendFormat": "Deployments per day",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "short",
                "color": {"mode": "thresholds"},
                "thresholds": {
                  "steps": [
                    {"color": "red", "value": 0},
                    {"color": "yellow", "value": 1},
                    {"color": "green", "value": 5}
                  ]
                }
              }
            }
          },
          {
            "id": 2,
            "title": "Lead Time for Changes",
            "type": "stat",
            "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
            "targets": [
              {
                "expr": "dora:lead_time_seconds",
                "legendFormat": "Lead time (95th percentile)",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "s",
                "color": {"mode": "thresholds"},
                "thresholds": {
                  "steps": [
                    {"color": "green", "value": 0},
                    {"color": "yellow", "value": 300},
                    {"color": "red", "value": 900}
                  ]
                }
              }
            }
          },
          {
            "id": 3,
            "title": "Change Failure Rate",
            "type": "stat",
            "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
            "targets": [
              {
                "expr": "dora:change_failure_rate",
                "legendFormat": "Failure rate %",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "percent",
                "color": {"mode": "thresholds"},
                "thresholds": {
                  "steps": [
                    {"color": "green", "value": 0},
                    {"color": "yellow", "value": 5},
                    {"color": "red", "value": 15}
                  ]
                }
              }
            }
          },
          {
            "id": 4,
            "title": "Mean Time to Recovery",
            "type": "stat",
            "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
            "targets": [
              {
                "expr": "dora:mttr_seconds",
                "legendFormat": "MTTR",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "s",
                "color": {"mode": "thresholds"},
                "thresholds": {
                  "steps": [
                    {"color": "green", "value": 0},
                    {"color": "yellow", "value": 3600},
                    {"color": "red", "value": 14400}
                  ]
                }
              }
            }
          },
          {
            "id": 5,
            "title": "Deployment Trends",
            "type": "graph",
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
            "targets": [
              {
                "expr": "increase(argocd_app_sync_total{phase=\"Succeeded\"}[1h])",
                "legendFormat": "Successful deployments",
                "refId": "A"
              },
              {
                "expr": "increase(argocd_app_sync_total{phase=\"Failed\"}[1h])",
                "legendFormat": "Failed deployments",
                "refId": "B"
              }
            ],
            "yAxes": [
              {"label": "Deployments", "min": 0},
              {"show": false}
            ]
          },
          {
            "id": 6,
            "title": "Application Health Status",
            "type": "piechart",
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
            "targets": [
              {
                "expr": "count by (health_status) (argocd_app_info)",
                "legendFormat": "{{health_status}}",
                "refId": "A"
              }
            ]
          },
          {
            "id": 7,
            "title": "Sync Performance",
            "type": "graph",
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16},
            "targets": [
              {
                "expr": "histogram_quantile(0.50, rate(argocd_app_reconcile_bucket[5m]))",
                "legendFormat": "50th percentile",
                "refId": "A"
              },
              {
                "expr": "histogram_quantile(0.95, rate(argocd_app_reconcile_bucket[5m]))",
                "legendFormat": "95th percentile",
                "refId": "B"
              },
              {
                "expr": "histogram_quantile(0.99, rate(argocd_app_reconcile_bucket[5m]))",
                "legendFormat": "99th percentile",
                "refId": "C"
              }
            ],
            "yAxes": [
              {"label": "Duration (seconds)", "min": 0},
              {"show": false}
            ]
          }
        ],
        "time": {"from": "now-24h", "to": "now"},
        "refresh": "30s"
      }
    }
```

### **3. Structured Logging для CI/CD процессов:**
```yaml
# k8s/monitoring/fluentd-cicd-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-cicd-config
  namespace: monitoring
data:
  fluent.conf: |
    # ArgoCD Application Controller logs
    <source>
      @type tail
      path /var/log/containers/*argocd-application-controller*.log
      pos_file /var/log/fluentd-argocd-controller.log.pos
      tag argocd.controller
      format json
      time_key time
      time_format %Y-%m-%dT%H:%M:%S.%NZ
    </source>
    
    # ArgoCD Server logs
    <source>
      @type tail
      path /var/log/containers/*argocd-server*.log
      pos_file /var/log/fluentd-argocd-server.log.pos
      tag argocd.server
      format json
      time_key time
      time_format %Y-%m-%dT%H:%M:%S.%NZ
    </source>
    
    # Parse ArgoCD logs
    <filter argocd.**>
      @type parser
      key_name log
      reserve_data true
      <parse>
        @type json
      </parse>
    </filter>
    
    # Enrich with Kubernetes metadata
    <filter argocd.**>
      @type kubernetes_metadata
      @log_level warn
      skip_labels true
      skip_container_metadata true
      skip_master_url true
      skip_namespace_metadata true
    </filter>
    
    # Add CI/CD context
    <filter argocd.**>
      @type record_transformer
      <record>
        component "cicd"
        system "argocd"
        environment "#{ENV['CLUSTER_ENV'] || 'production'}"
        cluster "#{ENV['CLUSTER_NAME'] || 'hashfoundry-ha'}"
      </record>
    </filter>
    
    # Extract deployment events
    <filter argocd.controller>
      @type grep
      <regexp>
        key log
        pattern /sync|deploy|health|reconcile/i
      </regexp>
    </filter>
    
    # Parse deployment metrics from logs
    <filter argocd.controller>
      @type parser
      key_name log
      reserve_data true
      <parse>
        @type regexp
        expression /.*app=(?<app_name>[^\s]+).*operation=(?<operation>[^\s]+).*phase=(?<phase>[^\s]+).*duration=(?<duration_ms>\d+)ms.*/
      </parse>
    </filter>
    
    # Send to Elasticsearch
    <match argocd.**>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      index_name cicd-logs-%Y.%m.%d
      type_name _doc
      include_tag_key true
      tag_key @log_name
      flush_interval 5s
      <buffer>
        @type file
        path /var/log/fluentd-buffers/argocd
        flush_mode interval
        flush_interval 5s
        chunk_limit_size 10MB
        queue_limit_length 32
        retry_max_interval 30
        retry_forever true
      </buffer>
    </match>
    
    # Send metrics to Prometheus
    <match argocd.controller>
      @type prometheus
      <metric>
        name argocd_deployment_duration_seconds
        type histogram
        desc ArgoCD deployment duration
        key duration_ms
        buckets 100,500,1000,5000,10000,30000,60000
        <labels>
          app_name ${app_name}
          operation ${operation}
          phase ${phase}
        </labels>
      </metric>
    </match>
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-cicd
  namespace: monitoring
spec:
  selector:
    matchLabels:
      name: fluentd-cicd
  template:
    metadata:
      labels:
        name: fluentd-cicd
    spec:
      serviceAccountName: fluentd
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.16-debian-elasticsearch7-1
        env:
        - name: FLUENT_ELASTICSEARCH_HOST
          value: "elasticsearch.logging.svc.cluster.local"
        - name: FLUENT_ELASTICSEARCH_PORT
          value: "9200"
        - name: CLUSTER_NAME
          value: "hashfoundry-ha"
        - name: CLUSTER_ENV
          value: "production"
        resources:
          limits:
            memory: 512Mi
            cpu: 200m
          requests:
            memory: 256Mi
            cpu: 100m
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluentd-config
          mountPath: /fluentd/etc/fluent.conf
          subPath: fluent.conf
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluentd-config
        configMap:
          name: fluentd-cicd-config
```

### **4. Alerting Rules для CI/CD:**
```yaml
# k8s/monitoring/cicd-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cicd-alerts
  namespace: monitoring
spec:
  groups:
  - name: cicd.alerts
    rules:
    # DORA Metrics Alerts
    - alert: LowDeploymentFrequency
      expr: dora:deployment_frequency < 1
      for: 24h
      labels:
        severity: warning
        component: cicd
        dora_metric: deployment_frequency
      annotations:
        summary: "Low deployment frequency detected"
        description: "Only {{ $value }} deployments in the last 24 hours. Target: >1 per day"
        runbook_url: "https://docs.hashfoundry.com/runbooks/low-deployment-frequency"
    
    - alert: HighChangeFailureRate
      expr: dora:change_failure_rate > 15
      for: 1h
      labels:
        severity: critical
        component: cicd
        dora_metric: change_failure_rate
      annotations:
        summary: "High change failure rate"
        description: "Change failure rate is {{ $value }}%. Target: <15%"
        runbook_url: "https://docs.hashfoundry.com/runbooks/high-failure-rate"
    
    - alert: LongLeadTime
      expr: dora:lead_time_seconds > 3600
      for: 30m
      labels:
        severity: warning
        component: cicd
        dora_metric: lead_time
      annotations:
        summary: "Lead time is too long"
        description: "Lead time is {{ $value | humanizeDuration }}. Target: <1 hour"
        runbook_url: "https://docs.hashfoundry.com/runbooks/long-lead-time"
    
    - alert: HighMTTR
      expr: dora:mttr_seconds > 14400
      for: 15m
      labels:
        severity: critical
        component: cicd
        dora_metric: mttr
      annotations:
        summary: "Mean Time to Recovery is too high"
        description: "MTTR is {{ $value | humanizeDuration }}. Target: <4 hours"
        runbook_url: "https://docs.hashfoundry.com/runbooks/high-mttr"
    
    # ArgoCD Specific Alerts
    - alert: ArgoCDApplicationOutOfSync
      expr: cicd:apps_out_of_sync > 0
      for: 10m
      labels:
        severity: warning
        component: argocd
      annotations:
        summary: "ArgoCD applications out of sync"
        description: "{{ $value }} applications are out of sync"
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-out-of-sync"
    
    - alert: ArgoCDApplicationUnhealthy
      expr: cicd:apps_unhealthy > 0
      for: 5m
      labels:
        severity: critical
        component: argocd
      annotations:
        summary: "ArgoCD applications unhealthy"
        description: "{{ $value }} applications are in unhealthy state"
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-unhealthy"
    
    - alert: ArgoCDControllerHighCPU
      expr: cicd:controller_cpu_usage > 0.8
      for: 15m
      labels:
        severity: warning
        component: argocd
      annotations:
        summary: "ArgoCD controller high CPU usage"
        description: "ArgoCD controller CPU usage is {{ $value | humanizePercentage }}"
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-high-cpu"
    
    - alert: ArgoCDControllerHighMemory
      expr: cicd:controller_memory_usage > 2000000000  # 2GB
      for: 15m
      labels:
        severity: warning
        component: argocd
      annotations:
        summary: "ArgoCD controller high memory usage"
        description: "ArgoCD controller memory usage is {{ $value | humanizeBytes }}"
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-high-memory"
    
    # Pipeline Performance Alerts
    - alert: SlowSyncPerformance
      expr: cicd:pipeline_duration_seconds > 300
      for: 10m
      labels:
        severity: warning
        component: cicd
      annotations:
        summary: "Slow sync performance detected"
        description: "95th percentile sync duration is {{ $value }}s. Target: <300s"
        runbook_url: "https://docs.hashfoundry.com/runbooks/slow-sync"
    
    - alert: LowSyncSuccessRate
      expr: cicd:sync_success_rate < 95
      for: 15m
      labels:
        severity: critical
        component: cicd
      annotations:
        summary: "Low sync success rate"
        description: "Sync success rate is {{ $value }}%. Target: >95%"
        runbook_url: "https://docs.hashfoundry.com/runbooks/low-success-rate"
```

### **5. Webhook Integration для внешних CI/CD систем:**
```yaml
# k8s/monitoring/webhook-receiver.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cicd-webhook-receiver
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cicd-webhook-receiver
  template:
    metadata:
      labels:
        app: cicd-webhook-receiver
    spec:
      containers:
      - name: webhook-receiver
        image: hashfoundry/webhook-receiver:latest
        ports:
        - containerPort: 8080
        env:
        - name: PROMETHEUS_PUSHGATEWAY_URL
          value: "http://prometheus-pushgateway.monitoring.svc.cluster.local:9091"
        - name: ELASTICSEARCH_URL
          value: "http://elasticsearch.logging.svc.cluster.local:9200"
        - name: WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: webhook-secrets
              key: webhook-secret
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: cicd-webhook-receiver
  namespace: monitoring
spec:
  selector:
    app: cicd-webhook-receiver
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cicd-webhook-receiver
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - webhooks.hashfoundry.com
    secretName: webhook-receiver-tls
  rules:
  - host: webhooks.hashfoundry.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: cicd-webhook-receiver
            port:
              number: 80
```

## 🎓 **Заключение:**

**Мониторинг и логирование CI/CD процессов** обеспечивают полную видимость конвейера доставки и позволяют принимать data-driven решения для улучшения процессов разработки.

### **🔑 Ключевые преимущества:**
1. **DORA Metrics** - автоматический расчет ключевых DevOps показателей
2. **Proactive Alerting** - раннее обнаружение проблем и аномалий
3. **Trend Analysis** - выявление паттернов и возможностей для оптимизации
4. **Root Cause Analysis** - быстрая диагностика проблем с контекстом
5. **Performance Optimization** - data-driven улучшение производительности
6. **Compliance & Audit** - полная трассируемость изменений

### **🛠️ Основные инструменты:**
- **Prometheus** - сбор метрик и алертинг
- **Grafana** - визуализация и дашборды
- **Fluentd/Loki** - централизованное логирование
- **Elasticsearch** - поиск и анализ логов
- **AlertManager** - управление уведомлениями
- **Jaeger** - distributed tracing для сложных пайплайнов

### **📊 DORA Metrics:**
- **Deployment Frequency** - частота развертываний
- **Lead Time for Changes** - время от коммита до продакшена
- **Change Failure Rate** - процент неудачных изменений
- **Mean Time to Recovery** - среднее время восстановления

### **🎯 Основные команды для изучения в вашем HA кластере:**
```bash
# Анализ существующего мониторинга
kubectl get pods -n monitoring | grep prometheus
kubectl get servicemonitors -A | grep argocd

# Проверка метрик ArgoCD
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Затем в браузере: http://localhost:9090

# Мониторинг приложений ArgoCD
kubectl get applications -n argocd
kubectl logs -f deployment/argocd-application-controller -n argocd

# Анализ событий развертываний
kubectl get events --sort-by=.metadata.creationTimestamp -A | grep -E "(Deploy|Sync)"

# Проверка алертов
kubectl get prometheusrules -A | grep cicd

# Анализ производительности
kubectl top pods -A --sort-by=cpu
kubectl top nodes
```

### **🚀 Следующие шаги:**
1. Настройте сбор DORA метрик для вашего HA кластера
2. Создайте дашборды для визуализации CI/CD процессов
3. Внедрите структурированное логирование для всех компонентов
4. Настройте проактивные алерты для критических метрик
5. Интегрируйте внешние CI/CD системы через webhooks
6. Регулярно анализируйте тренды для оптимизации процессов

### **💡 Лучшие практики:**
- **Автоматизируйте сбор метрик** - не полагайтесь на ручные процессы
- **Используйте стандартные метрики** - DORA metrics как основа
- **Настройте корреляцию событий** - связывайте логи с метриками
- **Создавайте контекстные алерты** - избегайте ложных срабатываний
- **Регулярно пересматривайте пороги** - адаптируйте под изменения
- **Документируйте runbook'и** - обеспечьте быструю реакцию на инциденты

**Помните:** Эффективный мониторинг CI/CD - это не только сбор данных, но и их правильная интерпретация для непрерывного улучшения процессов доставки!
