# 162. Как создавать резервные копии и восстанавливать etcd?

## 🎯 Вопрос
Как создавать резервные копии и восстанавливать etcd?

## 💡 Ответ

etcd является критически важным компонентом Kubernetes, хранящим все данные кластера. Правильное резервное копирование и восстановление etcd обеспечивает возможность полного восстановления кластера.

### 🏗️ Архитектура etcd и резервного копирования

#### 1. **Схема резервного копирования etcd**
```
┌─────────────────────────────────────────────────────────────┐
│                    etcd Cluster                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   etcd-1    │  │   etcd-2    │  │   etcd-3    │         │
│  │  (Leader)   │  │ (Follower)  │  │ (Follower)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Backup Strategy                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Snapshot   │  │ Continuous  │  │   Point-in  │         │
│  │   Backup    │  │   Backup    │  │ Time Recovery│         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Типы резервного копирования etcd**
```yaml
# Стратегии резервного копирования etcd
etcd_backup_strategies:
  snapshot_backup:
    description: "Создание снимка состояния etcd"
    frequency: "Каждые 15-30 минут"
    method: "etcdctl snapshot save"
    pros: ["Быстрое восстановление", "Полное состояние"]
    cons: ["Больший размер", "Точка во времени"]
  
  continuous_backup:
    description: "Непрерывное резервное копирование WAL"
    frequency: "Постоянно"
    method: "WAL файлы + snapshot"
    pros: ["Минимальная потеря данных", "Точное восстановление"]
    cons: ["Сложность", "Больше ресурсов"]
  
  incremental_backup:
    description: "Инкрементальное резервное копирование"
    frequency: "Каждый час"
    method: "Изменения с последнего backup"
    pros: ["Экономия места", "Быстрое создание"]
    cons: ["Сложное восстановление", "Зависимость от цепочки"]
```

### 📊 Примеры из нашего кластера

#### Проверка состояния etcd:
```bash
# Проверка подов etcd
kubectl get pods -n kube-system | grep etcd

# Проверка состояния etcd кластера
kubectl exec -n kube-system etcd-<node-name> -- etcdctl endpoint status --write-out=table
```

#### Проверка размера данных etcd:
```bash
# Размер базы данных etcd
kubectl exec -n kube-system etcd-<node-name> -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize'
```

### 💾 Создание резервных копий etcd

#### 1. **Snapshot резервное копирование**
```bash
#!/bin/bash
# etcd-snapshot-backup.sh

echo "📦 Создание snapshot резервной копии etcd"

# Переменные для нашего кластера hashfoundry-ha
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"

# Создание директории для резервных копий
BACKUP_DIR="/backup/etcd/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Создание snapshot
SNAPSHOT_FILE="$BACKUP_DIR/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"

ETCDCTL_API=3 etcdctl snapshot save $SNAPSHOT_FILE \
  --endpoints=$ETCD_ENDPOINTS \
  --cacert=$ETCD_CACERT \
  --cert=$ETCD_CERT \
  --key=$ETCD_KEY

# Проверка целостности snapshot
echo "🔍 Проверка целостности snapshot..."
ETCDCTL_API=3 etcdctl snapshot status $SNAPSHOT_FILE --write-out=table

# Сжатие snapshot
echo "📦 Сжатие snapshot..."
gzip $SNAPSHOT_FILE

echo "✅ Snapshot создан: ${SNAPSHOT_FILE}.gz"
echo "📊 Размер файла: $(du -h ${SNAPSHOT_FILE}.gz | cut -f1)"
```

#### 2. **Автоматизированное резервное копирование**
```yaml
# etcd-backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "*/15 * * * *"  # Каждые 15 минут
  jobTemplate:
    spec:
      template:
        spec:
          hostNetwork: true
          containers:
          - name: etcd-backup
            image: k8s.gcr.io/etcd:3.5.0-0
            command:
            - /bin/sh
            - -c
            - |
              # Создание snapshot etcd
              BACKUP_FILE="/backup/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"
              
              ETCDCTL_API=3 etcdctl snapshot save $BACKUP_FILE \
                --endpoints=https://127.0.0.1:2379 \
                --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                --cert=/etc/kubernetes/pki/etcd/server.crt \
                --key=/etc/kubernetes/pki/etcd/server.key
              
              # Проверка snapshot
              ETCDCTL_API=3 etcdctl snapshot status $BACKUP_FILE
              
              # Сжатие и перемещение в постоянное хранилище
              gzip $BACKUP_FILE
              
              # Очистка старых backup (старше 7 дней)
              find /backup -name "etcd-snapshot-*.db.gz" -mtime +7 -delete
              
              echo "Backup completed: $BACKUP_FILE.gz"
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
              readOnly: true
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
              type: Directory
          - name: backup-storage
            persistentVolumeClaim:
              claimName: etcd-backup-pvc
          restartPolicy: OnFailure
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
```

#### 3. **Резервное копирование с шифрованием**
```bash
#!/bin/bash
# etcd-encrypted-backup.sh

echo "🔐 Создание зашифрованной резервной копии etcd"

# Создание snapshot
SNAPSHOT_FILE="/tmp/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"

ETCDCTL_API=3 etcdctl snapshot save $SNAPSHOT_FILE \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Шифрование с помощью GPG
ENCRYPTED_FILE="/backup/etcd/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db.gpg"
gpg --symmetric --cipher-algo AES256 --output $ENCRYPTED_FILE $SNAPSHOT_FILE

# Удаление незашифрованного файла
rm $SNAPSHOT_FILE

echo "✅ Зашифрованная резервная копия создана: $ENCRYPTED_FILE"
```

### 🔄 Восстановление etcd

#### 1. **Восстановление из snapshot**
```bash
#!/bin/bash
# etcd-restore.sh

echo "🔄 Восстановление etcd из snapshot"

# Параметры восстановления
SNAPSHOT_FILE="/backup/etcd/etcd-snapshot-20240128-120000.db"
RESTORE_DIR="/var/lib/etcd-restore"
CLUSTER_NAME="hashfoundry-ha"

# Остановка etcd (если запущен)
echo "⏹️ Остановка etcd..."
systemctl stop etcd

# Создание резервной копии текущих данных
echo "💾 Создание резервной копии текущих данных..."
mv /var/lib/etcd /var/lib/etcd-backup-$(date +%Y%m%d-%H%M%S)

# Восстановление из snapshot
echo "📦 Восстановление из snapshot..."
ETCDCTL_API=3 etcdctl snapshot restore $SNAPSHOT_FILE \
  --name=etcd-1 \
  --initial-cluster=etcd-1=https://10.0.0.1:2380 \
  --initial-cluster-token=$CLUSTER_NAME \
  --initial-advertise-peer-urls=https://10.0.0.1:2380 \
  --data-dir=$RESTORE_DIR

# Перемещение восстановленных данных
mv $RESTORE_DIR /var/lib/etcd

# Установка правильных разрешений
chown -R etcd:etcd /var/lib/etcd

# Запуск etcd
echo "▶️ Запуск etcd..."
systemctl start etcd

# Проверка состояния
echo "🔍 Проверка состояния etcd..."
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

echo "✅ Восстановление etcd завершено"
```

#### 2. **Восстановление кластера etcd**
```bash
#!/bin/bash
# etcd-cluster-restore.sh

echo "🔄 Восстановление кластера etcd"

# Параметры кластера
SNAPSHOT_FILE="/backup/etcd/etcd-snapshot-20240128-120000.db"
CLUSTER_NAME="hashfoundry-ha"

# Узлы кластера
declare -A NODES
NODES[etcd-1]="10.0.0.1"
NODES[etcd-2]="10.0.0.2"
NODES[etcd-3]="10.0.0.3"

# Формирование строки кластера
INITIAL_CLUSTER=""
for node in "${!NODES[@]}"; do
    INITIAL_CLUSTER="${INITIAL_CLUSTER}${node}=https://${NODES[$node]}:2380,"
done
INITIAL_CLUSTER=${INITIAL_CLUSTER%,}

echo "🔧 Восстановление на каждом узле..."

for node in "${!NODES[@]}"; do
    echo "📦 Восстановление на узле: $node"
    
    # Восстановление на каждом узле
    ETCDCTL_API=3 etcdctl snapshot restore $SNAPSHOT_FILE \
      --name=$node \
      --initial-cluster=$INITIAL_CLUSTER \
      --initial-cluster-token=$CLUSTER_NAME \
      --initial-advertise-peer-urls=https://${NODES[$node]}:2380 \
      --data-dir=/var/lib/etcd-restore-$node
    
    echo "✅ Узел $node восстановлен"
done

echo "🚀 Запуск кластера etcd..."
# Здесь должен быть код для запуска etcd на всех узлах

echo "✅ Кластер etcd восстановлен"
```

#### 3. **Восстановление с проверкой целостности**
```bash
#!/bin/bash
# etcd-restore-with-verification.sh

echo "🔄 Восстановление etcd с проверкой целостности"

SNAPSHOT_FILE="$1"

if [ -z "$SNAPSHOT_FILE" ]; then
    echo "❌ Укажите файл snapshot для восстановления"
    echo "Использование: $0 <snapshot-file>"
    exit 1
fi

# Проверка существования файла
if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo "❌ Файл snapshot не найден: $SNAPSHOT_FILE"
    exit 1
fi

# Проверка целостности snapshot
echo "🔍 Проверка целостности snapshot..."
ETCDCTL_API=3 etcdctl snapshot status $SNAPSHOT_FILE --write-out=table

if [ $? -ne 0 ]; then
    echo "❌ Snapshot поврежден или недоступен"
    exit 1
fi

# Создание тестового восстановления
echo "🧪 Тестовое восстановление..."
TEST_DIR="/tmp/etcd-test-restore-$(date +%s)"
ETCDCTL_API=3 etcdctl snapshot restore $SNAPSHOT_FILE \
  --name=test-etcd \
  --initial-cluster=test-etcd=https://127.0.0.1:2380 \
  --initial-cluster-token=test-cluster \
  --initial-advertise-peer-urls=https://127.0.0.1:2380 \
  --data-dir=$TEST_DIR

if [ $? -eq 0 ]; then
    echo "✅ Тестовое восстановление успешно"
    rm -rf $TEST_DIR
else
    echo "❌ Ошибка при тестовом восстановлении"
    exit 1
fi

# Продолжение с реальным восстановлением
echo "🔄 Начало реального восстановления..."
# Здесь код реального восстановления

echo "✅ Восстановление завершено успешно"
```

### 🎯 Мониторинг и автоматизация

#### 1. **Мониторинг резервного копирования**
```yaml
# etcd-backup-monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: etcd-backup-monitor
  namespace: kube-system
data:
  monitor.sh: |
    #!/bin/bash
    # Мониторинг резервного копирования etcd
    
    BACKUP_DIR="/backup/etcd"
    ALERT_THRESHOLD=3600  # 1 час в секундах
    
    # Поиск последней резервной копии
    LATEST_BACKUP=$(find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -z "$LATEST_BACKUP" ]; then
        echo "❌ ALERT: Резервные копии etcd не найдены!"
        exit 1
    fi
    
    # Проверка возраста последней резервной копии
    BACKUP_AGE=$(( $(date +%s) - $(stat -c %Y "$LATEST_BACKUP") ))
    
    if [ $BACKUP_AGE -gt $ALERT_THRESHOLD ]; then
        echo "⚠️ WARNING: Последняя резервная копия etcd старше $((ALERT_THRESHOLD/60)) минут"
        echo "Последняя копия: $LATEST_BACKUP"
        echo "Возраст: $((BACKUP_AGE/60)) минут"
        exit 1
    fi
    
    echo "✅ Резервное копирование etcd в норме"
    echo "Последняя копия: $LATEST_BACKUP"
    echo "Возраст: $((BACKUP_AGE/60)) минут"
```

#### 2. **Prometheus метрики для etcd backup**
```yaml
# etcd-backup-metrics.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: etcd-backup-metrics
spec:
  selector:
    matchLabels:
      app: etcd-backup
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
# Пример метрик для мониторинга
etcd_backup_metrics:
  etcd_backup_last_success_timestamp:
    description: "Timestamp последнего успешного backup"
    type: "gauge"
  
  etcd_backup_duration_seconds:
    description: "Время выполнения backup в секундах"
    type: "histogram"
  
  etcd_backup_size_bytes:
    description: "Размер backup файла в байтах"
    type: "gauge"
  
  etcd_backup_failures_total:
    description: "Общее количество неудачных backup"
    type: "counter"
```

### 📋 Лучшие практики

#### 1. **Общие принципы**
- ✅ **Регулярные snapshot** каждые 15-30 минут
- ✅ **Тестирование восстановления** ежемесячно
- ✅ **Шифрование резервных копий** для безопасности
- ✅ **Географическое распределение** backup
- ✅ **Мониторинг процесса** резервного копирования
- ✅ **Автоматизация процедур** backup и restore

#### 2. **Чек-лист для etcd backup**
```yaml
etcd_backup_checklist:
  before_backup:
    - "✅ Проверить состояние etcd кластера"
    - "✅ Убедиться в наличии свободного места"
    - "✅ Проверить доступность сертификатов"
    - "✅ Настроить мониторинг процесса"
  
  during_backup:
    - "✅ Создать snapshot с правильными параметрами"
    - "✅ Проверить целостность snapshot"
    - "✅ Зашифровать резервную копию"
    - "✅ Переместить в безопасное хранилище"
  
  after_backup:
    - "✅ Проверить размер и целостность файла"
    - "✅ Обновить метрики мониторинга"
    - "✅ Очистить старые резервные копии"
    - "✅ Документировать процесс"
  
  restore_preparation:
    - "✅ Протестировать процедуру восстановления"
    - "✅ Подготовить план восстановления"
    - "✅ Обучить команду процедурам"
    - "✅ Создать runbook для экстренных случаев"
```

Правильное резервное копирование и восстановление etcd является критически важным для обеспечения отказоустойчивости Kubernetes кластера и должно выполняться регулярно с обязательным тестированием процедур восстановления.
