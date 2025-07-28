# 151. Какие ключевые метрики производительности для Kubernetes?

## 🎯 Вопрос
Какие ключевые метрики производительности для Kubernetes?

## 💡 Ответ

Мониторинг производительности Kubernetes требует отслеживания метрик на уровне кластера, узлов, подов и приложений для обеспечения оптимальной работы системы.

### 🏗️ Категории метрик производительности

#### 1. **Иерархия метрик**
```
┌─────────────────────────────────────────────────────────┐
│                    Cluster Level                        │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                  Node Level                         │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │                Pod Level                        │ │ │
│  │  │  ┌─────────────────────────────────────────────┐ │ │ │
│  │  │  │            Container Level                  │ │ │ │
│  │  │  │  ┌─────────────────────────────────────────┐ │ │ │ │
│  │  │  │  │         Application Level               │ │ │ │ │
│  │  │  │  └─────────────────────────────────────────┘ │ │ │ │
│  │  │  └─────────────────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

#### 2. **Основные группы метрик**
```yaml
# Классификация метрик производительности
performance_metrics:
  resource_utilization:
    - cpu_usage
    - memory_usage
    - disk_io
    - network_io
  
  cluster_health:
    - node_availability
    - pod_status
    - api_server_latency
    - etcd_performance
  
  application_performance:
    - response_time
    - throughput
    - error_rate
    - saturation
  
  scalability:
    - pod_startup_time
    - scaling_latency
    - resource_allocation_efficiency
```

### 🎯 Метрики уровня кластера

#### 1. **API Server метрики**
```bash
# Проверка производительности API Server
kubectl get --raw /metrics | grep apiserver_request_duration_seconds

# Основные метрики API Server:
# - apiserver_request_duration_seconds - время ответа API
# - apiserver_request_total - общее количество запросов
# - apiserver_current_inflight_requests - текущие запросы в обработке
```

#### 2. **etcd метрики**
```bash
# Проверка производительности etcd
kubectl get --raw /metrics | grep etcd

# Ключевые метрики etcd:
# - etcd_disk_wal_fsync_duration_seconds - время синхронизации WAL
# - etcd_disk_backend_commit_duration_seconds - время коммита
# - etcd_server_leader_changes_seen_total - смены лидера
```

### 📊 Примеры из нашего кластера

#### Проверка метрик через kubectl:
```bash
kubectl top nodes
kubectl top pods --all-namespaces
```

#### Мониторинг API Server:
```bash
kubectl get componentstatuses
```

#### Проверка производительности etcd:
```bash
kubectl logs -n kube-system etcd-master-node
```

### 🖥️ Метрики уровня узлов

#### 1. **Ресурсы узлов**
```yaml
# Основные метрики узлов
node_metrics:
  cpu:
    - node_cpu_utilization_percent
    - node_load_average_1m
    - node_load_average_5m
    - node_load_average_15m
  
  memory:
    - node_memory_utilization_percent
    - node_memory_available_bytes
    - node_memory_cached_bytes
    - node_memory_buffers_bytes
  
  disk:
    - node_disk_utilization_percent
    - node_disk_io_read_bytes_per_sec
    - node_disk_io_write_bytes_per_sec
    - node_disk_io_utilization_percent
  
  network:
    - node_network_receive_bytes_per_sec
    - node_network_transmit_bytes_per_sec
    - node_network_receive_packets_per_sec
    - node_network_transmit_packets_per_sec
```

#### 2. **Мониторинг узлов с Prometheus**
```yaml
# prometheus-node-exporter.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
          hostPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /rootfs
          readOnly: true
        args:
        - '--path.procfs=/host/proc'
        - '--path.sysfs=/host/sys'
        - '--collector.filesystem.ignored-mount-points'
        - '^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)'
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
```

### 🚀 Метрики уровня подов

#### 1. **Ресурсы подов**
```bash
# Мониторинг ресурсов подов
kubectl top pods --containers --all-namespaces

# Детальная информация о ресурсах
kubectl describe pod <pod-name> -n <namespace>

# Проверка лимитов и запросов
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory,CPU-LIM:.spec.containers[*].resources.limits.cpu,MEM-LIM:.spec.containers[*].resources.limits.memory
```

#### 2. **Метрики жизненного цикла подов**
```yaml
# Ключевые метрики подов
pod_metrics:
  lifecycle:
    - pod_startup_time
    - pod_ready_time
    - pod_restart_count
    - pod_termination_time
  
  resource_usage:
    - container_cpu_usage_seconds_total
    - container_memory_usage_bytes
    - container_memory_working_set_bytes
    - container_fs_usage_bytes
  
  network:
    - container_network_receive_bytes_total
    - container_network_transmit_bytes_total
    - container_network_receive_packets_total
    - container_network_transmit_packets_total
```

### 📈 Метрики приложений

#### 1. **Golden Signals (Четыре золотых сигнала)**
```yaml
# Четыре золотых сигнала SRE
golden_signals:
  latency:
    description: "Время ответа на запросы"
    metrics:
      - http_request_duration_seconds
      - grpc_server_handling_seconds
    
  traffic:
    description: "Количество запросов в секунду"
    metrics:
      - http_requests_per_second
      - grpc_server_started_total
    
  errors:
    description: "Процент ошибочных запросов"
    metrics:
      - http_requests_total{status=~"5.."}
      - grpc_server_handled_total{grpc_code!="OK"}
    
  saturation:
    description: "Насыщенность ресурсов"
    metrics:
      - cpu_utilization_percent
      - memory_utilization_percent
      - disk_utilization_percent
```

#### 2. **Пример инструментации приложения**
```javascript
// app-metrics.js
const prometheus = require('prom-client');

// Создание метрик
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestsTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new prometheus.Gauge({
  name: 'active_connections',
  help: 'Number of active connections'
});

// Middleware для сбора метрик
function metricsMiddleware(req, res, next) {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestsTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
}

// Эндпоинт для метрик
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});
```

### 🔍 Специализированные метрики

#### 1. **Метрики Kubernetes компонентов**
```bash
# Scheduler метрики
kubectl get --raw /metrics | grep scheduler_

# Controller Manager метрики
kubectl get --raw /metrics | grep controller_

# Kubelet метрики
curl -k https://node-ip:10250/metrics
```

#### 2. **Метрики сети**
```yaml
# Сетевые метрики
network_metrics:
  pod_to_pod:
    - network_latency_seconds
    - network_packet_loss_percent
    - network_bandwidth_utilization
  
  service_mesh:
    - istio_request_duration_milliseconds
    - istio_request_total
    - istio_tcp_connections_opened_total
  
  ingress:
    - nginx_ingress_controller_requests
    - nginx_ingress_controller_request_duration_seconds
    - nginx_ingress_controller_response_size
```

### 📊 Dashboards и визуализация

#### 1. **Grafana Dashboard для кластера**
```json
{
  "dashboard": {
    "title": "Kubernetes Cluster Performance",
    "panels": [
      {
        "title": "Cluster CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
          }
        ]
      },
      {
        "title": "Cluster Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
          }
        ]
      },
      {
        "title": "Pod Count by Namespace",
        "type": "graph",
        "targets": [
          {
            "expr": "count by (namespace) (kube_pod_info)"
          }
        ]
      },
      {
        "title": "API Server Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(apiserver_request_total[5m])"
          }
        ]
      }
    ]
  }
}
```

#### 2. **Алерты для критических метрик**
```yaml
# prometheus-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-performance-alerts
spec:
  groups:
  - name: kubernetes-performance
    rules:
    - alert: HighCPUUsage
      expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage detected"
        description: "CPU usage is above 80% for more than 5 minutes"
    
    - alert: HighMemoryUsage
      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Memory usage is above 85% for more than 5 minutes"
    
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"
    
    - alert: APIServerHighLatency
      expr: histogram_quantile(0.99, rate(apiserver_request_duration_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "API Server high latency"
        description: "API Server 99th percentile latency is above 1 second"
```

### 🎯 Инструменты для сбора метрик

#### 1. **Prometheus + Grafana стек**
```bash
# Установка Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

#### 2. **Metrics Server**
```bash
# Установка Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Проверка работы
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
```

### 📋 Лучшие практики мониторинга

#### 1. **Принципы эффективного мониторинга**
- ✅ **Мониторьте на всех уровнях** (кластер, узлы, поды, приложения)
- ✅ **Используйте SLI/SLO** для определения целевых показателей
- ✅ **Настройте алерты** для критических метрик
- ✅ **Создайте дашборды** для разных ролей (разработчики, операторы)
- ✅ **Автоматизируйте сбор метрик** с помощью service discovery
- ✅ **Сохраняйте исторические данные** для анализа трендов

#### 2. **Скрипт для проверки производительности**
```bash
#!/bin/bash
# performance-check.sh

echo "🔍 Проверка производительности Kubernetes кластера"

echo "📊 Использование ресурсов узлов:"
kubectl top nodes

echo -e "\n📊 Топ подов по использованию CPU:"
kubectl top pods --all-namespaces --sort-by=cpu | head -10

echo -e "\n📊 Топ подов по использованию памяти:"
kubectl top pods --all-namespaces --sort-by=memory | head -10

echo -e "\n🔍 Статус компонентов кластера:"
kubectl get componentstatuses

echo -e "\n⚠️ Поды с проблемами:"
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

echo -e "\n📈 События кластера (последние 10):"
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10

echo "✅ Проверка завершена"
```

Эффективный мониторинг производительности Kubernetes требует комплексного подхода с отслеживанием метрик на всех уровнях системы и настройкой соответствующих алертов и дашбордов.
