# 154. Как оптимизировать производительность etcd?

## 🎯 **Что такое оптимизация производительности etcd?**

**Оптимизация производительности etcd** — это комплекс мер по улучшению скорости работы ключевого компонента Kubernetes, который хранит состояние кластера. etcd является критически важным для производительности всего кластера, поэтому его оптимизация напрямую влияет на отзывчивость API Server и стабильность кластера.

## 🏗️ **Основные компоненты производительности etcd:**

### **1. Storage I/O (Дисковый ввод-вывод)**
- SSD диски с высокими IOPS (>3000)
- Низкая задержка диска (<10ms для 99-го процентиля)
- Оптимизированная файловая система

### **2. Network Latency (Сетевая задержка)**
- RTT между узлами etcd (<1ms в одном ЦОД)
- Высокая пропускная способность (>100 Mbps)
- Оптимизированные сетевые буферы

### **3. Memory Management (Управление памятью)**
- Достаточный объем RAM (минимум 8GB)
- Настройка квот базы данных
- Управление фрагментацией

### **4. Compaction Strategy (Стратегия компактификации)**
- Автоматическая компактификация
- Регулярная дефрагментация
- Мониторинг размера базы данных

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка состояния etcd:**
```bash
# Статус etcd подов в кластере
kubectl get pods -n kube-system | grep etcd

# Проверка состояния etcd кластера
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl endpoint status --write-out=table

# Проверка здоровья etcd
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl endpoint health --write-out=table

# Информация о членах кластера
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl member list --write-out=table
```

### **2. Анализ производительности etcd:**
```bash
# Размер базы данных etcd
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl endpoint status --write-out=json | jq '.[] | "DB Size: \(.Status.dbSize / 1024 / 1024)MB, In Use: \(.Status.dbSizeInUse / 1024 / 1024)MB"'

# Проверка производительности
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl check perf

# Анализ фрагментации
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl endpoint status --write-out=json | jq '.[] | "Fragmentation: \((.Status.dbSize - .Status.dbSizeInUse) / .Status.dbSize * 100)%"'
```

### **3. Мониторинг метрик etcd через Prometheus:**
```bash
# Доступ к Prometheus для анализа etcd метрик
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &

# Ключевые метрики etcd:
# etcd_disk_wal_fsync_duration_seconds - время синхронизации WAL
# etcd_disk_backend_commit_duration_seconds - время коммита
# etcd_request_duration_seconds - время обработки запросов
# etcd_mvcc_db_total_size_in_bytes - размер базы данных
# etcd_server_has_leader - наличие лидера
```

### **4. Проверка конфигурации etcd:**
```bash
# Конфигурация etcd из манифеста
kubectl get pod -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -o yaml | grep -A 20 "command:"

# Переменные окружения etcd
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- env | grep ETCD

# Проверка версии etcd
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl version
```

### **5. Анализ событий etcd:**
```bash
# События, связанные с etcd
kubectl get events -n kube-system --field-selector involvedObject.name=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') --sort-by=.metadata.creationTimestamp

# Логи etcd для анализа производительности
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') | grep -E "slow|latency|performance" | tail -10
```

## 🔄 **Демонстрация оптимизации etcd:**

### **1. Компактификация и дефрагментация:**
```bash
# Создать скрипт для компактификации etcd
cat << 'EOF' > etcd-maintenance.sh
#!/bin/bash

echo "🔄 Обслуживание etcd в HA кластере"
echo "================================="

ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

if [ -z "$ETCD_POD" ]; then
    echo "❌ etcd pod не найден"
    exit 1
fi

echo "📊 Состояние до обслуживания:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=table

# Получение текущего размера
BEFORE_SIZE=$(kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize')
echo "💾 Размер базы до компактификации: $((BEFORE_SIZE / 1024 / 1024))MB"

# Компактификация
echo "🔄 Выполнение компактификации..."
REVISION=$(kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.header.revision')
kubectl exec -n kube-system $ETCD_POD -- etcdctl compact $REVISION

if [ $? -eq 0 ]; then
    echo "✅ Компактификация выполнена успешно"
else
    echo "❌ Ошибка при компактификации"
    exit 1
fi

# Дефрагментация (осторожно в продакшене!)
echo "🔧 Выполнение дефрагментации..."
kubectl exec -n kube-system $ETCD_POD -- etcdctl defrag

if [ $? -eq 0 ]; then
    echo "✅ Дефрагментация выполнена успешно"
else
    echo "❌ Ошибка при дефрагментации"
fi

# Проверка результата
AFTER_SIZE=$(kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize')
echo "💾 Размер базы после обслуживания: $((AFTER_SIZE / 1024 / 1024))MB"
echo "📉 Освобождено: $(((BEFORE_SIZE - AFTER_SIZE) / 1024 / 1024))MB"

echo -e "\n📊 Состояние после обслуживания:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=table

echo "✅ Обслуживание etcd завершено"
EOF

chmod +x etcd-maintenance.sh
```

### **2. Мониторинг производительности etcd:**
```bash
# Создать скрипт мониторинга etcd
cat << 'EOF' > etcd-performance-monitor.sh
#!/bin/bash

echo "📊 Мониторинг производительности etcd"
echo "===================================="

ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

if [ -z "$ETCD_POD" ]; then
    echo "❌ etcd pod не найден"
    exit 1
fi

echo "🏥 Здоровье etcd кластера:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint health --write-out=table

echo -e "\n📊 Статус etcd кластера:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=table

echo -e "\n💾 Использование базы данных:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=json | \
jq '.[] | "DB Size: \(.Status.dbSize / 1024 / 1024)MB, In Use: \(.Status.dbSizeInUse / 1024 / 1024)MB, Fragmentation: \((.Status.dbSize - .Status.dbSizeInUse) / .Status.dbSize * 100)%"'

echo -e "\n👥 Члены кластера:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl member list --write-out=table

echo -e "\n⚡ Тест производительности:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl check perf

echo -e "\n📈 Ресурсы etcd pod:"
kubectl top pod $ETCD_POD -n kube-system

echo -e "\n🔍 Последние события etcd:"
kubectl get events -n kube-system --field-selector involvedObject.name=$ETCD_POD --sort-by=.metadata.creationTimestamp | tail -5

echo "✅ Мониторинг завершен"
EOF

chmod +x etcd-performance-monitor.sh
```

### **3. Анализ метрик etcd через Prometheus:**
```bash
# Создать скрипт для анализа метрик etcd
cat << 'EOF' > etcd-metrics-analyzer.sh
#!/bin/bash

echo "📈 Анализ метрик etcd через Prometheus"
echo "====================================="

# Проверка доступности Prometheus
if ! kubectl get svc prometheus-server -n monitoring &>/dev/null; then
    echo "❌ Prometheus не найден в namespace monitoring"
    exit 1
fi

echo "🔗 Настройка port-forward к Prometheus..."
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &
PF_PID=$!
sleep 5

echo "📊 Ключевые метрики etcd:"

# Задержка синхронизации WAL
echo -e "\n💾 Задержка синхронизации WAL (должна быть < 10ms):"
curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,%20etcd_disk_wal_fsync_duration_seconds_bucket)" | \
jq -r '.data.result[] | "99th percentile: \(.value[1])s"'

# Задержка коммита
echo -e "\n🔄 Задержка коммита backend (должна быть < 25ms):"
curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,%20etcd_disk_backend_commit_duration_seconds_bucket)" | \
jq -r '.data.result[] | "99th percentile: \(.value[1])s"'

# Размер базы данных
echo -e "\n📊 Размер базы данных etcd:"
curl -s "http://localhost:9090/api/v1/query?query=etcd_mvcc_db_total_size_in_bytes" | \
jq -r '.data.result[] | "Size: \(.value[1] | tonumber / 1024 / 1024)MB"'

# Наличие лидера
echo -e "\n👑 Статус лидера:"
curl -s "http://localhost:9090/api/v1/query?query=etcd_server_has_leader" | \
jq -r '.data.result[] | "Has leader: \(.value[1])"'

# Количество предложений
echo -e "\n📝 Скорость обработки предложений:"
curl -s "http://localhost:9090/api/v1/query?query=rate(etcd_server_proposals_applied_total[5m])" | \
jq -r '.data.result[] | "Proposals/sec: \(.value[1])"'

# Очистка
kill $PF_PID 2>/dev/null

echo -e "\n✅ Анализ метрик завершен"
EOF

chmod +x etcd-metrics-analyzer.sh
```

## 🔧 **Скрипт комплексной диагностики etcd:**

### **1. Создание диагностического скрипта:**
```bash
# Создать скрипт etcd-diagnostics.sh
cat << 'EOF' > etcd-diagnostics.sh
#!/bin/bash

echo "🔍 Комплексная диагностика etcd в HA кластере"
echo "============================================="

ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

if [ -z "$ETCD_POD" ]; then
    echo "❌ etcd pod не найден"
    exit 1
fi

echo "📊 1. ОБЩАЯ ИНФОРМАЦИЯ:"
echo "etcd Pod: $ETCD_POD"
kubectl get pod $ETCD_POD -n kube-system -o wide

echo -e "\n📊 2. ВЕРСИЯ И КОНФИГУРАЦИЯ:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl version

echo -e "\n📊 3. СОСТОЯНИЕ КЛАСТЕРА:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint health --write-out=table
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=table

echo -e "\n📊 4. ЧЛЕНЫ КЛАСТЕРА:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl member list --write-out=table

echo -e "\n📊 5. ПРОИЗВОДИТЕЛЬНОСТЬ:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl check perf

echo -e "\n📊 6. РАЗМЕР И ФРАГМЕНТАЦИЯ БАЗЫ:"
kubectl exec -n kube-system $ETCD_POD -- etcdctl endpoint status --write-out=json | \
jq '.[] | "DB Size: \(.Status.dbSize / 1024 / 1024)MB, In Use: \(.Status.dbSizeInUse / 1024 / 1024)MB, Fragmentation: \((.Status.dbSize - .Status.dbSizeInUse) / .Status.dbSize * 100)%"'

echo -e "\n📊 7. РЕСУРСЫ POD:"
kubectl top pod $ETCD_POD -n kube-system

echo -e "\n📊 8. КОНФИГУРАЦИЯ КОМАНДЫ:"
kubectl get pod $ETCD_POD -n kube-system -o yaml | grep -A 30 "command:" | head -20

echo -e "\n📊 9. ПОСЛЕДНИЕ СОБЫТИЯ:"
kubectl get events -n kube-system --field-selector involvedObject.name=$ETCD_POD --sort-by=.metadata.creationTimestamp | tail -5

echo -e "\n📊 10. ЛОГИ (последние ошибки):"
kubectl logs $ETCD_POD -n kube-system | grep -i "error\|warn\|slow" | tail -5

echo -e "\n💡 РЕКОМЕНДАЦИИ:"
echo "1. Размер базы должен быть < 8GB"
echo "2. Фрагментация должна быть < 50%"
echo "3. WAL fsync должен быть < 10ms"
echo "4. Backend commit должен быть < 25ms"
echo "5. Регулярно выполняйте компактификацию"

echo -e "\n✅ Диагностика завершена!"
EOF

chmod +x etcd-diagnostics.sh
```

### **2. Запуск диагностики:**
```bash
# Выполнить диагностику
./etcd-diagnostics.sh

# Сохранить отчет
./etcd-diagnostics.sh > etcd-diagnostics-report-$(date +%Y%m%d-%H%M%S).txt
```

## 📊 **Архитектура оптимизации etcd:**

```
┌─────────────────────────────────────────────────────────────┐
│                    etcd Performance Optimization           │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                              │
│  ├── SSD Disks (>3000 IOPS, <10ms latency)                │
│  ├── Filesystem optimization (ext4/xfs, noatime)           │
│  ├── I/O scheduler (noop/deadline for SSD)                 │
│  └── Disk space monitoring (quota management)              │
├─────────────────────────────────────────────────────────────┤
│  Network Layer                                              │
│  ├── Low latency (<1ms RTT same DC, <50ms cross DC)       │
│  ├── High bandwidth (>100 Mbps)                            │
│  ├── TCP optimization (keepalive, nodelay)                 │
│  └── Network buffer tuning                                 │
├─────────────────────────────────────────────────────────────┤
│  Memory Management                                          │
│  ├── Sufficient RAM (8GB+ for production)                  │
│  ├── Database quota (8GB backend quota)                    │
│  ├── Go GC tuning (GOGC, GOMEMLIMIT)                      │
│  └── Memory fragmentation monitoring                       │
├─────────────────────────────────────────────────────────────┤
│  Compaction & Maintenance                                   │
│  ├── Auto-compaction (periodic, 1h retention)              │
│  ├── Regular defragmentation (weekly)                      │
│  ├── Database size monitoring                              │
│  └── Performance metrics tracking                          │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Мониторинг и алерты для etcd:**

### **1. Критические метрики для мониторинга:**
```bash
# Высокая задержка WAL fsync (>10ms)
curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,%20etcd_disk_wal_fsync_duration_seconds_bucket)%20%3E%200.01" | jq '.data.result'

# Высокая задержка backend commit (>25ms)
curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.99,%20etcd_disk_backend_commit_duration_seconds_bucket)%20%3E%200.025" | jq '.data.result'

# Большой размер базы данных (>6GB)
curl -s "http://localhost:9090/api/v1/query?query=etcd_mvcc_db_total_size_in_bytes%20%3E%206442450944" | jq '.data.result'

# Отсутствие лидера
curl -s "http://localhost:9090/api/v1/query?query=etcd_server_has_leader%20%3D%3D%200" | jq '.data.result'

# Частые смены лидера
curl -s "http://localhost:9090/api/v1/query?query=increase(etcd_server_leader_changes_seen_total[1h])%20%3E%203" | jq '.data.result'
```

### **2. Алерты для Prometheus:**
```yaml
# etcd-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: etcd-performance-alerts
  namespace: monitoring
spec:
  groups:
  - name: etcd-performance
    rules:
    - alert: EtcdHighWALFsyncDuration
      expr: histogram_quantile(0.99, etcd_disk_wal_fsync_duration_seconds_bucket) > 0.01
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "etcd WAL fsync duration is high"
        description: "etcd WAL fsync 99th percentile is {{ $value }}s"
    
    - alert: EtcdHighBackendCommitDuration
      expr: histogram_quantile(0.99, etcd_disk_backend_commit_duration_seconds_bucket) > 0.025
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "etcd backend commit duration is high"
        description: "etcd backend commit 99th percentile is {{ $value }}s"
    
    - alert: EtcdDatabaseSizeHigh
      expr: etcd_mvcc_db_total_size_in_bytes > 6442450944
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "etcd database size is high"
        description: "etcd database size is {{ $value | humanize }}B"
    
    - alert: EtcdNoLeader
      expr: etcd_server_has_leader == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "etcd cluster has no leader"
        description: "etcd cluster has no leader for more than 1 minute"
```

## 🏭 **Оптимизация etcd в вашем HA кластере:**

### **1. Проверка текущей конфигурации:**
```bash
# Анализ конфигурации etcd в HA кластере
kubectl get pod -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -o yaml | grep -A 50 "command:"

# Проверка ресурсов etcd
kubectl describe pod -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') | grep -A 10 "Requests\|Limits"

# Проверка volumes etcd
kubectl describe pod -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') | grep -A 20 "Volumes:"
```

### **2. Мониторинг производительности в HA:**
```bash
# Производительность всех узлов etcd
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "=== Node: $node ==="
    kubectl get pod -n kube-system --field-selector spec.nodeName=$node | grep etcd
done

# Статус кластера etcd
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl endpoint status --cluster --write-out=table
```

### **3. Интеграция с мониторингом:**
```bash
# Проверка метрик etcd в Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &

# Доступ к Grafana для дашбордов etcd
kubectl port-forward svc/grafana -n monitoring 3000:80 &

# Импорт дашборда etcd в Grafana (ID: 3070)
```

## 🎯 **Best Practices для оптимизации etcd:**

### **1. Хранилище:**
- Используйте SSD диски с высокими IOPS (>3000)
- Настройте файловую систему с опциями noatime, nodiratime
- Мониторьте задержку диска (<10ms для 99-го процентиля)
- Используйте I/O scheduler noop или deadline для SSD

### **2. Сеть:**
- Обеспечьте низкую задержку между узлами (<1ms в одном ЦОД)
- Настройте высокую пропускную способность (>100 Mbps)
- Оптимизируйте TCP параметры (keepalive, nodelay)
- Мониторьте сетевые метрики

### **3. Память:**
- Выделите достаточно RAM (минимум 8GB для продакшена)
- Настройте квоту базы данных (8GB)
- Мониторьте фрагментацию памяти
- Оптимизируйте Go GC параметры

### **4. Обслуживание:**
- Настройте автоматическую компактификацию каждый час
- Выполняйте дефрагментацию еженедельно
- Мониторьте размер базы данных
- Настройте алерты на критические метрики

**Оптимизация etcd — основа высокой производительности всего Kubernetes кластера!**
