# 154. Как оптимизировать производительность etcd?

## 🎯 Вопрос
Как оптимизировать производительность etcd?

## 💡 Ответ

etcd является критически важным компонентом Kubernetes, и его производительность напрямую влияет на производительность всего кластера. Оптимизация etcd включает настройку хранилища, сети, памяти и конфигурационных параметров.

### 🏗️ Архитектура производительности etcd

#### 1. **Схема компонентов производительности etcd**
```
┌─────────────────────────────────────────────────────────────┐
│                    etcd Performance                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Storage   │  │   Network   │  │   Memory    │         │
│  │     I/O     │  │  Latency    │  │   Usage     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │    CPU      │  │ Compaction  │  │ Clustering  │         │
│  │   Usage     │  │  Strategy   │  │   Topology  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Ключевые метрики производительности**
```yaml
# Критические метрики etcd
etcd_performance_metrics:
  latency_metrics:
    - "etcd_disk_wal_fsync_duration_seconds"
    - "etcd_disk_backend_commit_duration_seconds"
    - "etcd_network_peer_round_trip_time_seconds"
    - "etcd_request_duration_seconds"
  
  throughput_metrics:
    - "etcd_server_proposals_applied_total"
    - "etcd_server_proposals_committed_total"
    - "etcd_server_proposals_pending"
    - "etcd_mvcc_put_total"
  
  resource_metrics:
    - "etcd_mvcc_db_total_size_in_bytes"
    - "process_resident_memory_bytes"
    - "etcd_server_quota_backend_bytes"
    - "etcd_cluster_version"
```

### 📊 Примеры из нашего кластера

#### Проверка производительности etcd:
```bash
# Проверка состояния etcd
kubectl get pods -n kube-system | grep etcd

# Проверка метрик производительности
kubectl exec -n kube-system etcd-<node-name> -- etcdctl endpoint status --write-out=table

# Проверка задержек
kubectl exec -n kube-system etcd-<node-name> -- etcdctl check perf
```

#### Анализ размера базы данных:
```bash
# Размер базы данных etcd
kubectl exec -n kube-system etcd-<node-name> -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize'

# Проверка фрагментации
kubectl exec -n kube-system etcd-<node-name> -- etcdctl defrag --cluster
```

### 💾 Оптимизация хранилища

#### 1. **Настройка дискового I/O**
```yaml
# Оптимизация etcd для SSD
etcd_storage_optimization:
  disk_requirements:
    type: "SSD (предпочтительно NVMe)"
    iops: "> 3000 IOPS"
    latency: "< 10ms для 99-го процентиля"
    bandwidth: "> 100 MB/s"
  
  filesystem_settings:
    filesystem: "ext4 или xfs"
    mount_options: "noatime,nodiratime"
    scheduler: "noop или deadline для SSD"
  
  etcd_flags:
    - "--quota-backend-bytes=8589934592"  # 8GB
    - "--auto-compaction-retention=1h"
    - "--auto-compaction-mode=periodic"
    - "--max-request-bytes=1572864"       # 1.5MB
```

#### 2. **Конфигурация для высокой производительности**
```bash
#!/bin/bash
# etcd-performance-tuning.sh

echo "🔧 Настройка производительности etcd"

# Оптимизация файловой системы
echo "📁 Настройка файловой системы..."
mount -o remount,noatime,nodiratime /var/lib/etcd

# Настройка I/O scheduler для SSD
echo noop > /sys/block/nvme0n1/queue/scheduler

# Увеличение лимитов файловых дескрипторов
echo "📊 Настройка лимитов..."
echo "etcd soft nofile 65536" >> /etc/security/limits.conf
echo "etcd hard nofile 65536" >> /etc/security/limits.conf

# Настройка сетевых параметров
echo "🌐 Настройка сети..."
echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 87380 16777216' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 16777216' >> /etc/sysctl.conf

sysctl -p

echo "✅ Настройка производительности завершена"
```

#### 3. **Мониторинг дискового I/O**
```bash
#!/bin/bash
# etcd-io-monitoring.sh

echo "📊 Мониторинг I/O производительности etcd"

# Проверка задержек диска
echo "💾 Задержки диска:"
iostat -x 1 5 | grep -E "(Device|nvme|sda)"

# Проверка использования диска etcd
echo -e "\n📁 Использование диска etcd:"
du -sh /var/lib/etcd

# Проверка фрагментации
echo -e "\n🔍 Проверка фрагментации:"
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | \
jq '.[] | "DB Size: \(.Status.dbSize), DB Size in Use: \(.Status.dbSizeInUse)"'

echo "✅ Мониторинг завершен"
```

### 🌐 Оптимизация сети

#### 1. **Настройка сетевых параметров**
```yaml
# Оптимизация сети для etcd
etcd_network_optimization:
  cluster_topology:
    same_datacenter: "< 1ms RTT"
    cross_datacenter: "< 50ms RTT"
    bandwidth: "> 100 Mbps"
  
  etcd_flags:
    - "--heartbeat-interval=100"          # 100ms
    - "--election-timeout=1000"           # 1000ms
    - "--max-snapshots=5"
    - "--max-wals=5"
  
  network_tuning:
    tcp_keepalive: "enabled"
    tcp_nodelay: "enabled"
    buffer_sizes: "optimized"
```

#### 2. **Мониторинг сетевой производительности**
```bash
#!/bin/bash
# etcd-network-monitoring.sh

echo "🌐 Мониторинг сетевой производительности etcd"

# Проверка RTT между узлами etcd
ETCD_ENDPOINTS=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[*].status.podIP}')

for endpoint in $ETCD_ENDPOINTS; do
    echo "📡 RTT до $endpoint:"
    ping -c 3 $endpoint | tail -1
done

# Проверка пропускной способности
echo -e "\n📊 Сетевая статистика:"
kubectl exec -n kube-system etcd-$(hostname) -- netstat -i

# Проверка сетевых метрик etcd
echo -e "\n📈 Метрики сети etcd:"
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | \
jq '.[] | "Leader: \(.Status.leader), Term: \(.Status.raftTerm)"'

echo "✅ Сетевой мониторинг завершен"
```

### 🧠 Оптимизация памяти

#### 1. **Настройка использования памяти**
```yaml
# Оптимизация памяти etcd
etcd_memory_optimization:
  recommended_memory: "8GB минимум для production"
  
  etcd_flags:
    - "--quota-backend-bytes=8589934592"  # 8GB квота
    - "--auto-compaction-retention=1h"
    - "--auto-compaction-mode=periodic"
  
  go_settings:
    GOGC: "100"                           # Go GC target percentage
    GOMEMLIMIT: "6GiB"                    # Go memory limit
  
  monitoring:
    - "process_resident_memory_bytes"
    - "go_memstats_alloc_bytes"
    - "etcd_mvcc_db_total_size_in_bytes"
```

#### 2. **Скрипт мониторинга памяти**
```bash
#!/bin/bash
# etcd-memory-monitoring.sh

echo "🧠 Мониторинг использования памяти etcd"

# Использование памяти процессом etcd
echo "📊 Использование памяти etcd:"
ps aux | grep etcd | grep -v grep

# Размер базы данных в памяти
echo -e "\n💾 Размер базы данных:"
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | \
jq '.[] | "DB Size: \(.Status.dbSize / 1024 / 1024)MB, In Use: \(.Status.dbSizeInUse / 1024 / 1024)MB"'

# Проверка фрагментации памяти
echo -e "\n🔍 Фрагментация:"
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | \
jq '.[] | "Fragmentation: \((.Status.dbSize - .Status.dbSizeInUse) / .Status.dbSize * 100)%"'

echo "✅ Мониторинг памяти завершен"
```

### 🔄 Оптимизация компактификации

#### 1. **Настройка автоматической компактификации**
```yaml
# Конфигурация компактификации etcd
etcd_compaction_config:
  auto_compaction:
    mode: "periodic"                      # periodic или revision
    retention: "1h"                       # Сохранять данные за последний час
    
  manual_compaction:
    frequency: "daily"                    # Ежедневная ручная компактификация
    defrag_frequency: "weekly"            # Еженедельная дефрагментация
  
  etcd_flags:
    - "--auto-compaction-mode=periodic"
    - "--auto-compaction-retention=1h"
    - "--quota-backend-bytes=8589934592"
```

#### 2. **Скрипт автоматической компактификации**
```bash
#!/bin/bash
# etcd-compaction.sh

echo "🔄 Компактификация и дефрагментация etcd"

# Получение текущего размера
BEFORE_SIZE=$(kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize')

echo "📊 Размер до компактификации: $((BEFORE_SIZE / 1024 / 1024))MB"

# Компактификация
echo "🔄 Выполнение компактификации..."
REVISION=$(kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.header.revision')
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl compact $REVISION

# Дефрагментация
echo "🔧 Выполнение дефрагментации..."
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl defrag --cluster

# Проверка результата
AFTER_SIZE=$(kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize')
echo "📊 Размер после компактификации: $((AFTER_SIZE / 1024 / 1024))MB"
echo "💾 Освобождено: $(((BEFORE_SIZE - AFTER_SIZE) / 1024 / 1024))MB"

echo "✅ Компактификация завершена"
```

### 📈 Мониторинг производительности

#### 1. **Prometheus метрики для etcd**
```yaml
# etcd-performance-metrics.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: etcd-performance
spec:
  selector:
    matchLabels:
      component: etcd
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
---
# Ключевые метрики производительности
etcd_key_metrics:
  latency:
    - "histogram_quantile(0.99, etcd_disk_wal_fsync_duration_seconds_bucket)"
    - "histogram_quantile(0.99, etcd_disk_backend_commit_duration_seconds_bucket)"
    - "histogram_quantile(0.99, etcd_request_duration_seconds_bucket)"
  
  throughput:
    - "rate(etcd_server_proposals_applied_total[5m])"
    - "rate(etcd_mvcc_put_total[5m])"
    - "rate(etcd_mvcc_delete_total[5m])"
  
  health:
    - "etcd_server_has_leader"
    - "etcd_server_leader_changes_seen_total"
    - "etcd_cluster_version"
```

#### 2. **Grafana dashboard для etcd**
```json
{
  "dashboard": {
    "title": "etcd Performance Dashboard",
    "panels": [
      {
        "title": "etcd Disk Sync Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, etcd_disk_wal_fsync_duration_seconds_bucket)",
            "legendFormat": "99th percentile"
          }
        ]
      },
      {
        "title": "etcd Request Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, etcd_request_duration_seconds_bucket)",
            "legendFormat": "99th percentile"
          }
        ]
      },
      {
        "title": "etcd Database Size",
        "type": "graph",
        "targets": [
          {
            "expr": "etcd_mvcc_db_total_size_in_bytes",
            "legendFormat": "DB Size"
          }
        ]
      }
    ]
  }
}
```

### 🎯 Лучшие практики

#### 1. **Общие принципы оптимизации**
- ✅ **Используйте SSD диски** с высокими IOPS
- ✅ **Настройте автоматическую компактификацию** каждый час
- ✅ **Мониторьте ключевые метрики** постоянно
- ✅ **Регулярно выполняйте дефрагментацию** еженедельно
- ✅ **Оптимизируйте сетевую топологию** для минимальной задержки
- ✅ **Настройте достаточный объем памяти** (минимум 8GB)

#### 2. **Чек-лист производительности etcd**
```yaml
etcd_performance_checklist:
  storage:
    - "✅ SSD диски с > 3000 IOPS"
    - "✅ Задержка диска < 10ms (99-й процентиль)"
    - "✅ Файловая система ext4/xfs с noatime"
    - "✅ I/O scheduler noop/deadline для SSD"
  
  network:
    - "✅ RTT между узлами < 1ms (same DC)"
    - "✅ Пропускная способность > 100 Mbps"
    - "✅ TCP keepalive включен"
    - "✅ Оптимизированные буферы сети"
  
  memory:
    - "✅ Минимум 8GB RAM для production"
    - "✅ Квота backend 8GB"
    - "✅ Мониторинг фрагментации"
    - "✅ Настройка Go GC"
  
  configuration:
    - "✅ Автоматическая компактификация каждый час"
    - "✅ Еженедельная дефрагментация"
    - "✅ Оптимизированные таймауты"
    - "✅ Мониторинг метрик производительности"
```

Правильная оптимизация etcd критически важна для производительности всего Kubernetes кластера и требует комплексного подхода к настройке хранилища, сети, памяти и мониторинга.
