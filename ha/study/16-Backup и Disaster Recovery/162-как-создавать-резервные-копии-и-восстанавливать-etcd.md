# 162. Как создавать резервные копии и восстанавливать etcd?

## 🎯 **Что такое backup и restore etcd?**

**Backup и restore etcd** — это критически важные процедуры создания снимков состояния кластера Kubernetes и их восстановления, обеспечивающие возможность полного восстановления всех ресурсов, конфигураций и данных кластера в случае сбоев или катастроф.

## 🏗️ **Основные методы backup etcd:**

### **1. Snapshot backup (Снимок состояния)**
- Создание полного снимка базы данных etcd
- Быстрое восстановление до точки во времени
- Подходит для регулярного резервного копирования
- Размер файла зависит от количества объектов в кластере

### **2. Continuous backup (Непрерывное копирование)**
- Резервное копирование WAL (Write-Ahead Log) файлов
- Минимальная потеря данных (RPO близко к 0)
- Более сложная настройка и восстановление
- Требует больше ресурсов хранения

### **3. Incremental backup (Инкрементальное копирование)**
- Сохранение только изменений с последнего backup
- Экономия места хранения
- Быстрое создание backup
- Сложное восстановление (требует цепочку backup)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ состояния etcd:**
```bash
# Проверка подов etcd в HA кластере
kubectl get pods -n kube-system | grep etcd

# Проверка состояния etcd кластера
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=table

# Проверка здоровья etcd
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint health

# Размер базы данных etcd
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize'
```

### **2. Мониторинг etcd для backup:**
```bash
# Анализ использования etcd
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=table

# Проверка количества ключей
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl get "" --prefix --keys-only | wc -l

# Анализ размера данных по namespace
kubectl get all --all-namespaces | awk '{print $1}' | sort | uniq -c | sort -nr
```

### **3. Проверка конфигурации etcd в HA кластере:**
```bash
# Проверка конфигурации etcd
kubectl describe pod etcd-$(hostname) -n kube-system

# Проверка сертификатов etcd
ls -la /etc/kubernetes/pki/etcd/

# Проверка конфигурации кластера etcd
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl member list --write-out=table
```

## 🔄 **Демонстрация backup и restore процедур:**

### **1. Создание продвинутого backup скрипта:**
```bash
# Создать скрипт advanced-etcd-backup.sh
cat << 'EOF' > advanced-etcd-backup.sh
#!/bin/bash

echo "🚀 Продвинутое резервное копирование etcd для HA кластера"
echo "======================================================="

# Настройка переменных
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/backup/etcd/$BACKUP_DATE"
mkdir -p $BACKUP_DIR

# Конфигурация etcd для HA кластера
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция проверки etcd
check_etcd_health() {
    log "🔍 Проверка состояния etcd..."
    
    # Проверка здоровья etcd
    if ! ETCDCTL_API=3 etcdctl endpoint health \
        --endpoints=$ETCD_ENDPOINTS \
        --cacert=$ETCD_CACERT \
        --cert=$ETCD_CERT \
        --key=$ETCD_KEY >/dev/null 2>&1; then
        log "❌ etcd недоступен или нездоров"
        exit 1
    fi
    
    log "✅ etcd здоров и доступен"
}

# Функция создания snapshot
create_snapshot() {
    log "📦 Создание snapshot etcd..."
    
    SNAPSHOT_FILE="$BACKUP_DIR/etcd-snapshot.db"
    
    # Создание snapshot с таймаутом
    timeout 300 ETCDCTL_API=3 etcdctl snapshot save $SNAPSHOT_FILE \
        --endpoints=$ETCD_ENDPOINTS \
        --cacert=$ETCD_CACERT \
        --cert=$ETCD_CERT \
        --key=$ETCD_KEY
    
    if [ $? -ne 0 ]; then
        log "❌ Ошибка создания snapshot"
        exit 1
    fi
    
    log "✅ Snapshot создан: $SNAPSHOT_FILE"
}

# Функция проверки snapshot
verify_snapshot() {
    log "🔍 Проверка целостности snapshot..."
    
    SNAPSHOT_FILE="$BACKUP_DIR/etcd-snapshot.db"
    
    # Проверка статуса snapshot
    ETCDCTL_API=3 etcdctl snapshot status $SNAPSHOT_FILE --write-out=table
    
    if [ $? -ne 0 ]; then
        log "❌ Snapshot поврежден"
        exit 1
    fi
    
    # Получение информации о snapshot
    SNAPSHOT_INFO=$(ETCDCTL_API=3 etcdctl snapshot status $SNAPSHOT_FILE --write-out=json)
    TOTAL_KEYS=$(echo $SNAPSHOT_INFO | jq '.totalKey')
    TOTAL_SIZE=$(echo $SNAPSHOT_INFO | jq '.totalSize')
    
    log "✅ Snapshot проверен:"
    log "  - Всего ключей: $TOTAL_KEYS"
    log "  - Размер: $TOTAL_SIZE байт"
}

# Функция создания метаданных
create_metadata() {
    log "📊 Создание метаданных backup..."
    
    # Получение информации о кластере
    CLUSTER_INFO=$(kubectl cluster-info --kubeconfig=/etc/kubernetes/admin.conf 2>/dev/null || echo "Cluster info unavailable")
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    NAMESPACE_COUNT=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    POD_COUNT=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    # Информация о etcd
    ETCD_VERSION=$(ETCDCTL_API=3 etcdctl version --endpoints=$ETCD_ENDPOINTS \
        --cacert=$ETCD_CACERT --cert=$ETCD_CERT --key=$ETCD_KEY 2>/dev/null | grep "etcd Version" | cut -d: -f2 | tr -d ' ')
    
    ETCD_CLUSTER_ID=$(ETCDCTL_API=3 etcdctl endpoint status --endpoints=$ETCD_ENDPOINTS \
        --cacert=$ETCD_CACERT --cert=$ETCD_CERT --key=$ETCD_KEY --write-out=json 2>/dev/null | jq -r '.[0].Status.header.cluster_id')
    
    # Создание файла метаданных
    cat << METADATA_EOF > $BACKUP_DIR/backup-metadata.yaml
etcd_backup_metadata:
  timestamp: "$BACKUP_DATE"
  backup_type: "snapshot"
  
  cluster_info:
    cluster_id: "$ETCD_CLUSTER_ID"
    etcd_version: "$ETCD_VERSION"
    kubernetes_nodes: $NODE_COUNT
    namespaces: $NAMESPACE_COUNT
    total_pods: $POD_COUNT
  
  backup_details:
    snapshot_file: "etcd-snapshot.db"
    snapshot_size: "$(du -b $BACKUP_DIR/etcd-snapshot.db | cut -f1)"
    snapshot_keys: "$(ETCDCTL_API=3 etcdctl snapshot status $BACKUP_DIR/etcd-snapshot.db --write-out=json | jq '.totalKey')"
    
  etcd_endpoints: "$ETCD_ENDPOINTS"
  backup_location: "$BACKUP_DIR"
  
  verification:
    integrity_check: "passed"
    created_by: "$(whoami)"
    hostname: "$(hostname)"
METADATA_EOF

    log "✅ Метаданные созданы"
}

# Функция сжатия и шифрования
compress_and_encrypt() {
    log "📦 Сжатие и шифрование backup..."
    
    cd $BACKUP_DIR
    
    # Сжатие snapshot
    gzip etcd-snapshot.db
    
    # Создание архива с метаданными
    tar -czf ../etcd-backup-$BACKUP_DATE.tar.gz .
    
    # Шифрование архива (если настроен GPG)
    if command -v gpg >/dev/null 2>&1 && [ -n "$BACKUP_GPG_KEY" ]; then
        log "🔐 Шифрование backup..."
        gpg --trust-model always --encrypt -r "$BACKUP_GPG_KEY" \
            --output ../etcd-backup-$BACKUP_DATE.tar.gz.gpg \
            ../etcd-backup-$BACKUP_DATE.tar.gz
        rm ../etcd-backup-$BACKUP_DATE.tar.gz
        FINAL_FILE="../etcd-backup-$BACKUP_DATE.tar.gz.gpg"
    else
        FINAL_FILE="../etcd-backup-$BACKUP_DATE.tar.gz"
    fi
    
    # Очистка временной директории
    cd ..
    rm -rf $BACKUP_DATE
    
    BACKUP_SIZE=$(du -h $FINAL_FILE | cut -f1)
    log "✅ Backup завершен: $FINAL_FILE (размер: $BACKUP_SIZE)"
}

# Функция очистки старых backup
cleanup_old_backups() {
    log "🧹 Очистка старых backup..."
    
    # Удаление backup старше 30 дней
    find /backup/etcd -name "etcd-backup-*.tar.gz*" -mtime +30 -delete
    
    # Подсчет оставшихся backup
    BACKUP_COUNT=$(find /backup/etcd -name "etcd-backup-*.tar.gz*" | wc -l)
    log "📊 Осталось backup файлов: $BACKUP_COUNT"
}

# Функция отправки уведомлений
send_notification() {
    local status=$1
    local message=$2
    
    if [ "$status" = "success" ]; then
        log "✅ $message"
    else
        log "❌ $message"
    fi
    
    # Отправка в Slack (если настроен)
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"etcd Backup $status: $message\"}" \
            $SLACK_WEBHOOK_URL >/dev/null 2>&1
    fi
    
    # Отправка метрик в Prometheus (если настроен)
    if [ -n "$PROMETHEUS_PUSHGATEWAY" ]; then
        echo "etcd_backup_status{status=\"$status\"} 1" | \
            curl --data-binary @- $PROMETHEUS_PUSHGATEWAY/metrics/job/etcd_backup >/dev/null 2>&1
    fi
}

# Основная логика выполнения
main() {
    log "🚀 Запуск backup процедуры etcd"
    
    # Проверка прав доступа
    if [ "$EUID" -ne 0 ] && [ ! -r "$ETCD_CACERT" ]; then
        log "❌ Недостаточно прав для доступа к etcd сертификатам"
        exit 1
    fi
    
    # Проверка доступного места
    AVAILABLE_SPACE=$(df /backup | tail -1 | awk '{print $4}')
    if [ $AVAILABLE_SPACE -lt 1048576 ]; then  # 1GB в KB
        log "⚠️ Мало свободного места для backup (< 1GB)"
    fi
    
    # Выполнение backup процедуры
    check_etcd_health
    create_snapshot
    verify_snapshot
    create_metadata
    compress_and_encrypt
    cleanup_old_backups
    
    send_notification "success" "etcd backup completed successfully"
    log "🎉 BACKUP ETCD ЗАВЕРШЕН УСПЕШНО!"
}

# Обработка ошибок
trap 'send_notification "failed" "etcd backup failed"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x advanced-etcd-backup.sh
```

### **2. Создание продвинутого restore скрипта:**
```bash
# Создать скрипт advanced-etcd-restore.sh
cat << 'EOF' > advanced-etcd-restore.sh
#!/bin/bash

echo "🔄 Продвинутое восстановление etcd для HA кластера"
echo "================================================"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция проверки параметров
check_parameters() {
    if [ $# -lt 1 ]; then
        echo "❌ Использование: $0 <backup-file> [restore-type]"
        echo "Типы восстановления:"
        echo "  - single: восстановление одного узла"
        echo "  - cluster: восстановление всего кластера"
        echo "  - test: тестовое восстановление"
        exit 1
    fi
    
    BACKUP_FILE="$1"
    RESTORE_TYPE="${2:-single}"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log "❌ Backup файл не найден: $BACKUP_FILE"
        exit 1
    fi
    
    log "📋 Параметры восстановления:"
    log "  - Backup файл: $BACKUP_FILE"
    log "  - Тип восстановления: $RESTORE_TYPE"
}

# Функция подготовки backup файла
prepare_backup_file() {
    log "📦 Подготовка backup файла..."
    
    WORK_DIR="/tmp/etcd-restore-$(date +%s)"
    mkdir -p $WORK_DIR
    
    # Определение типа файла и извлечение
    if [[ "$BACKUP_FILE" == *.gpg ]]; then
        log "🔐 Расшифровка backup файла..."
        gpg --decrypt "$BACKUP_FILE" > "$WORK_DIR/backup.tar.gz"
        EXTRACT_FILE="$WORK_DIR/backup.tar.gz"
    elif [[ "$BACKUP_FILE" == *.tar.gz ]]; then
        EXTRACT_FILE="$BACKUP_FILE"
    else
        log "❌ Неподдерживаемый формат backup файла"
        exit 1
    fi
    
    # Извлечение архива
    cd $WORK_DIR
    tar -xzf "$EXTRACT_FILE"
    
    # Поиск snapshot файла
    if [ -f "etcd-snapshot.db.gz" ]; then
        gunzip etcd-snapshot.db.gz
        SNAPSHOT_FILE="$WORK_DIR/etcd-snapshot.db"
    elif [ -f "etcd-snapshot.db" ]; then
        SNAPSHOT_FILE="$WORK_DIR/etcd-snapshot.db"
    else
        log "❌ Snapshot файл не найден в backup"
        exit 1
    fi
    
    log "✅ Backup файл подготовлен: $SNAPSHOT_FILE"
}

# Функция проверки snapshot
verify_snapshot() {
    log "🔍 Проверка целостности snapshot..."
    
    # Проверка статуса snapshot
    SNAPSHOT_STATUS=$(ETCDCTL_API=3 etcdctl snapshot status $SNAPSHOT_FILE --write-out=json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log "❌ Snapshot поврежден или недоступен"
        exit 1
    fi
    
    # Извлечение информации о snapshot
    TOTAL_KEYS=$(echo $SNAPSHOT_STATUS | jq '.totalKey')
    TOTAL_SIZE=$(echo $SNAPSHOT_STATUS | jq '.totalSize')
    SNAPSHOT_HASH=$(echo $SNAPSHOT_STATUS | jq -r '.hash')
    
    log "✅ Snapshot проверен:"
    log "  - Всего ключей: $TOTAL_KEYS"
    log "  - Размер: $TOTAL_SIZE байт"
    log "  - Хеш: $SNAPSHOT_HASH"
    
    # Проверка метаданных (если доступны)
    if [ -f "$WORK_DIR/backup-metadata.yaml" ]; then
        log "📊 Информация из метаданных:"
        grep -E "(timestamp|cluster_id|etcd_version)" "$WORK_DIR/backup-metadata.yaml" | sed 's/^/  /'
    fi
}

# Функция тестового восстановления
test_restore() {
    log "🧪 Выполнение тестового восстановления..."
    
    TEST_DIR="/tmp/etcd-test-restore-$(date +%s)"
    
    # Тестовое восстановление
    ETCDCTL_API=3 etcdctl snapshot restore $SNAPSHOT_FILE \
        --name=test-etcd \
        --initial-cluster=test-etcd=https://127.0.0.1:2380 \
        --initial-cluster-token=test-cluster \
        --initial-advertise-peer-urls=https://127.0.0.1:2380 \
        --data-dir=$TEST_DIR
    
    if [ $? -eq 0 ]; then
        log "✅ Тестовое восстановление успешно"
        
        # Проверка содержимого
        if [ -d "$TEST_DIR/member" ]; then
            log "✅ Структура данных etcd корректна"
        fi
        
        # Очистка тестовых данных
        rm -rf $TEST_DIR
        return 0
    else
        log "❌ Ошибка при тестовом восстановлении"
        rm -rf $TEST_DIR
        return 1
    fi
}

# Функция восстановления одного узла
single_node_restore() {
    log "🔄 Восстановление одного узла etcd..."
    
    # Получение информации о текущем узле
    NODE_NAME=$(hostname)
    NODE_IP=$(hostname -I | awk '{print $1}')
    
    # Остановка etcd
    log "⏹️ Остановка etcd..."
    if systemctl is-active --quiet etcd; then
        systemctl stop etcd
    elif systemctl is-active --quiet kubelet; then
        # Для managed кластеров - перемещение манифеста
        mv /etc/kubernetes/manifests/etcd.yaml /tmp/etcd.yaml.backup 2>/dev/null || true
        sleep 10
    fi
    
    # Создание резервной копии текущих данных
    CURRENT_DATA_DIR="/var/lib/etcd"
    if [ -d "$CURRENT_DATA_DIR" ]; then
        log "💾 Создание резервной копии текущих данных..."
        mv $CURRENT_DATA_DIR $CURRENT_DATA_DIR-backup-$(date +%Y%m%d-%H%M%S)
    fi
    
    # Восстановление из snapshot
    log "📦 Восстановление из snapshot..."
    ETCDCTL_API=3 etcdctl snapshot restore $SNAPSHOT_FILE \
        --name=$NODE_NAME \
        --initial-cluster=$NODE_NAME=https://$NODE_IP:2380 \
        --initial-cluster-token=etcd-cluster-1 \
        --initial-advertise-peer-urls=https://$NODE_IP:2380 \
        --data-dir=$CURRENT_DATA_DIR
    
    if [ $? -ne 0 ]; then
        log "❌ Ошибка восстановления snapshot"
        exit 1
    fi
    
    # Установка правильных разрешений
    chown -R etcd:etcd $CURRENT_DATA_DIR 2>/dev/null || true
    
    # Запуск etcd
    log "▶️ Запуск etcd..."
    if [ -f "/tmp/etcd.yaml.backup" ]; then
        mv /tmp/etcd.yaml.backup /etc/kubernetes/manifests/etcd.yaml
        sleep 30
    else
        systemctl start etcd
        sleep 10
    fi
    
    # Проверка состояния
    log "🔍 Проверка состояния etcd..."
    for i in {1..30}; do
        if ETCDCTL_API=3 etcdctl endpoint health \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key >/dev/null 2>&1; then
            log "✅ etcd восстановлен и работает"
            return 0
        fi
        log "⏳ Ожидание запуска etcd... ($i/30)"
        sleep 2
    done
    
    log "❌ etcd не запустился после восстановления"
    return 1
}

# Функция восстановления кластера
cluster_restore() {
    log "🔄 Восстановление кластера etcd..."
    
    # Получение информации о кластере
    declare -A CLUSTER_NODES
    CLUSTER_NODES[etcd-1]="10.0.0.1"
    CLUSTER_NODES[etcd-2]="10.0.0.2"
    CLUSTER_NODES[etcd-3]="10.0.0.3"
    
    # Формирование строки кластера
    INITIAL_CLUSTER=""
    for node in "${!CLUSTER_NODES[@]}"; do
        INITIAL_CLUSTER="${INITIAL_CLUSTER}${node}=https://${CLUSTER_NODES[$node]}:2380,"
    done
    INITIAL_CLUSTER=${INITIAL_CLUSTER%,}
    
    log "🔧 Восстановление на каждом узле кластера..."
    
    for node in "${!CLUSTER_NODES[@]}"; do
        log "📦 Восстановление на узле: $node"
        
        # Восстановление на каждом узле
        ETCDCTL_API=3 etcdctl snapshot restore $SNAPSHOT_FILE \
            --name=$node \
            --initial-cluster=$INITIAL_CLUSTER \
            --initial-cluster-token=etcd-cluster-1 \
            --initial-advertise-peer-urls=https://${CLUSTER_NODES[$node]}:2380 \
            --data-dir=/var/lib/etcd-restore-$node
        
        log "✅ Узел $node восстановлен"
    done
    
    log "🚀 Кластер etcd восстановлен"
}

# Основная логика выполнения
main() {
    check_parameters "$@"
    prepare_backup_file
    verify_snapshot
    
    case $RESTORE_TYPE in
        "test")
            test_restore
            ;;
        "single")
            if test_restore; then
                single_node_restore
            else
                log "❌ Тестовое восстановление не прошло"
                exit 1
            fi
            ;;
        "cluster")
            if test_restore; then
                cluster_restore
            else
                log "❌ Тестовое восстановление не прошло"
                exit 1
            fi
            ;;
        *)
            log "❌ Неизвестный тип восстановления: $RESTORE_TYPE"
            exit 1
            ;;
    esac
    
    # Очистка временных файлов
    rm -rf $WORK_DIR
    
    log "🎉 ВОССТАНОВЛЕНИЕ ETCD ЗАВЕРШЕНО!"
}

# Обработка ошибок
trap 'log "❌ Ошибка при восстановлении etcd"; rm -rf $WORK_DIR; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x advanced-etcd-restore.sh
```

### **3. Создание CronJob для автоматического backup etcd:**
```bash
# Создать манифест etcd-backup-cronjob.yaml
cat << 'EOF' > etcd-backup-cronjob.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: etcd-backup-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: etcd-backup-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: etcd-backup-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: etcd-backup-role
subjects:
- kind: ServiceAccount
  name: etcd-backup-sa
  namespace: kube-system
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etcd-backup-pvc
  namespace: kube-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: do-block-storage
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup-cronjob
  namespace: kube-system
  labels:
    app: etcd-backup
    component: automated-backup
spec:
  schedule: "*/15 * * * *"  # Каждые 15 минут
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: etcd-backup
        spec:
          serviceAccountName: etcd-backup-sa
          hostNetwork: true
          restartPolicy: OnFailure
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
          containers:
          - name: etcd-backup
            image: k8s.gcr.io/etcd:3.5.0-0
            command:
            - /bin/sh
            - -c
            - |
              echo "🚀 Автоматическое резервное копирование etcd"
              
              # Настройка переменных
              BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
              BACKUP_DIR="/backup/etcd"
              mkdir -p $BACKUP_DIR
              
              # Конфигурация etcd
              ETCD_ENDPOINTS="https://127.0.0.1:2379"
              ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
              ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
              ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
              
              # Функция логирования
              log() {
                  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
              }
              
              # Проверка здоровья etcd
              log "🔍 Проверка состояния etcd..."
              if ! ETCDCTL_API=3 etcdctl endpoint health \
                  --endpoints=$ETCD_ENDPOINTS \
                  --cacert=$ETCD_CACERT \
                  --cert=$ETCD_CERT \
                  --key=$ETCD_KEY; then
                  log "❌ etcd недоступен"
                  exit 1
              fi
              
              # Создание snapshot
              SNAPSHOT_FILE="$BACKUP_DIR/etcd-snapshot-$BACKUP_DATE.db"
              log "📦 Создание snapshot: $SNAPSHOT_FILE"
              
              ETCDCTL_API=3 etcdctl snapshot save $SNAPSHOT_FILE \
                  --endpoints=$ETCD_ENDPOINTS \
                  --cacert=$ETCD_CACERT \
                  --cert=$ETCD_CERT \
                  --key=$ETCD_KEY
              
              if [ $? -ne 0 ]; then
                  log "❌ Ошибка создания snapshot"
                  exit 1
              fi
              
              # Проверка snapshot
              log "🔍 Проверка snapshot..."
              ETCDCTL_API=3 etcdctl snapshot status $SNAPSHOT_FILE --write-out=table
              
              # Сжатие snapshot
              log "📦 Сжатие snapshot..."
              gzip $SNAPSHOT_FILE
              
              # Создание метаданных
              METADATA_FILE="$BACKUP_DIR/etcd-metadata-$BACKUP_DATE.yaml"
              cat << METADATA_EOF > $METADATA_FILE
              backup_info:
                timestamp: "$BACKUP_DATE"
                type: "automated-etcd-snapshot"
                snapshot_file: "etcd-snapshot-$BACKUP_DATE.db.gz"
                snapshot_size: "$(du -b $SNAPSHOT_FILE.gz | cut -f1)"
                created_by: "cronjob"
                node: "$(hostname)"
              METADATA_EOF
              
              # Очистка старых backup (старше 7 дней)
              log "🧹 Очистка старых backup..."
              find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" -mtime +7 -delete
              find $BACKUP_DIR -name "etcd-metadata-*.yaml" -mtime +7 -delete
              
              # Статистика
              BACKUP_SIZE=$(du -h $SNAPSHOT_FILE.gz | cut -f1)
              BACKUP_COUNT=$(find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" | wc -l)
              
              log "✅ Backup завершен:"
              log "  - Файл: $SNAPSHOT_FILE.gz"
              log "  - Размер: $BACKUP_SIZE"
              log "  - Всего backup: $BACKUP_COUNT"
              
              # Отправка метрик (если настроен Prometheus)
              if [ -n "$PROMETHEUS_PUSHGATEWAY" ]; then
                  echo "etcd_backup_success 1" | \
                      curl --data-binary @- $PROMETHEUS_PUSHGATEWAY/metrics/job/etcd_backup/instance/$(hostname) || true
              fi
              
              echo "🎉 АВТОМАТИЧЕСКИЙ BACKUP ETCD ЗАВЕРШЕН!"
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
              readOnly: true
            - name: backup-storage
              mountPath: /backup
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 200m
                memory: 256Mi
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
              type: Directory
          - name: backup-storage
            persistentVolumeClaim:
              claimName: etcd-backup-pvc
EOF

# Применить CronJob
kubectl apply -f etcd-backup-cronjob.yaml
```

## 📊 **Архитектура backup и restore etcd:**

```
┌─────────────────────────────────────────────────────────────┐
│                    etcd Backup Architecture                │
├─────────────────────────────────────────────────────────────┤
│  etcd Cluster (HA)                                         │
│  ├── etcd-1 (Leader)                                       │
│  ├── etcd-2 (Follower)                                     │
│  └── etcd-3 (Follower)                                     │
├─────────────────────────────────────────────────────────────┤
│  Backup Strategies                                          │
│  ├── Snapshot Backup (every 15 min)                        │
│  │   ├── Full state snapshot                               │
│  │   ├── Compressed and encrypted                          │
│  │   └── Metadata included                                 │
│  ├── Continuous Backup (WAL files)                         │
│  │   ├── Real-time replication                             │
│  │   ├── Minimal data loss                                 │
│  │   └── Complex recovery                                  │
│  └── Incremental Backup (changes only)                     │
│      ├── Space efficient                                   │
│      ├── Fast creation                                     │
│      └── Chain dependency                                  │
├─────────────────────────────────────────────────────────────┤
│  Restore Procedures                                         │
│  ├── Test Restore (validation)                             │
│  ├── Single Node Restore (development)                     │
│  ├── Cluster Restore (production)                          │
│  └── Point-in-time Recovery (specific timestamp)           │
├─────────────────────────────────────────────────────────────┤
│  Monitoring & Automation                                   │
│  ├── CronJob automation                                    │
│  ├── Health checks                                         │
│  ├── Prometheus metrics                                    │
│  └── Slack notifications                                   │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Матрица backup стратегий:**

### **1. По частоте и критичности:**
| Тип Backup | Частота | RTO | RPO | Размер | Сложность |
|------------|---------|-----|-----|--------|-----------|
| Snapshot | 15 мин | 15 мин | 15 мин | Средний | Низкая |
| Continuous | Реальное время | 5 мин | 1 мин | Большой | Высокая |
| Incremental | 1 час | 30 мин | 1 час | Малый | Средняя |

### **2. Команды для мониторинга backup:**
```bash
# Проверка последних backup
find /backup/etcd -name "etcd-snapshot-*.db.gz" -type f -printf '%T@ %p\n' | sort -n | tail -5

# Размер backup файлов
du -sh /backup/etcd/etcd-snapshot-*.db.gz | tail -10

# Проверка целостности последнего backup
LATEST_BACKUP=$(find /backup/etcd -name "etcd-snapshot-*.db.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
gunzip -c "$LATEST_BACKUP" | ETCDCTL_API=3 etcdctl snapshot status /dev/stdin --write-out=table
```

## 🔧 **Скрипт мониторинга backup etcd:**

### **1. Создание backup monitor:**
```bash
# Создать скрипт etcd-backup-monitor.sh
cat << 'EOF' > etcd-backup-monitor.sh
#!/bin/bash

echo "📊 Мониторинг backup etcd"
echo "========================"

# Функция проверки последнего backup
check_latest_backup() {
    echo "🔍 Проверка последнего backup:"
    
    BACKUP_DIR="/backup/etcd"
    LATEST_BACKUP=$(find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -z "$LATEST_BACKUP" ]; then
        echo "❌ Backup файлы не найдены"
        return 1
    fi
    
    # Возраст последнего backup
    BACKUP_AGE=$(( $(date +%s) - $(stat -c %Y "$LATEST_BACKUP") ))
    BACKUP_AGE_MIN=$((BACKUP_AGE / 60))
    
    echo "📁 Последний backup: $(basename $LATEST_BACKUP)"
    echo "⏰ Возраст: $BACKUP_AGE_MIN минут"
    echo "📏 Размер: $(du -h $LATEST_BACKUP | cut -f1)"
    
    # Проверка возраста (должен быть не старше 30 минут)
    if [ $BACKUP_AGE -gt 1800 ]; then
        echo "⚠️ WARNING: Backup старше 30 минут"
        return 1
    else
        echo "✅ Backup актуален"
        return 0
    fi
}

# Функция проверки целостности
check_backup_integrity() {
    echo -e "\n🔍 Проверка целостности backup:"
    
    LATEST_BACKUP=$(find /backup/etcd -name "etcd-snapshot-*.db.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "$LATEST_BACKUP" ]; then
        echo "📦 Проверка: $(basename $LATEST_BACKUP)"
        
        # Проверка архива
        if gunzip -t "$LATEST_BACKUP" 2>/dev/null; then
            echo "✅ Архив корректен"
            
            # Проверка snapshot
            if gunzip -c "$LATEST_BACKUP" | ETCDCTL_API=3 etcdctl snapshot status /dev/stdin --write-out=table >/dev/null 2>&1; then
                echo "✅ Snapshot корректен"
                return 0
            else
                echo "❌ Snapshot поврежден"
                return 1
            fi
        else
            echo "❌ Архив поврежден"
            return 1
        fi
    else
        echo "❌ Backup файлы не найдены"
        return 1
    fi
}

# Функция статистики backup
backup_statistics() {
    echo -e "\n📊 Статистика backup:"
    
    BACKUP_DIR="/backup/etcd"
    
    # Количество backup файлов
    BACKUP_COUNT=$(find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" | wc -l)
    echo "📁 Всего backup файлов: $BACKUP_COUNT"
    
    # Общий размер backup
    TOTAL_SIZE=$(du -sh $BACKUP_DIR 2>/dev/null | cut -f1)
    echo "💾 Общий размер: $TOTAL_SIZE"
    
    # Средний размер backup
    if [ $BACKUP_COUNT -gt 0 ]; then
        TOTAL_BYTES=$(find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" -exec du -b {} + | awk '{sum += $1} END {print sum}')
        AVERAGE_SIZE=$((TOTAL_BYTES / BACKUP_COUNT))
        echo "📏 Средний размер: $(numfmt --to=iec $AVERAGE_SIZE)"
    fi
    
    # Последние 5 backup
    echo -e "\n📋 Последние backup:"
    find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort -r | head -5 | \
    while read date time size file; do
        size_human=$(numfmt --to=iec $size)
        echo "  $date $time - $(basename $file) ($size_human)"
    done
}

# Функция проверки CronJob
check_cronjob_status() {
    echo -e "\n🔄 Статус CronJob backup:"
    
    # Проверка CronJob
    if kubectl get cronjob etcd-backup-cronjob -n kube-system >/dev/null 2>&1; then
        echo "✅ CronJob существует"
        
        # Статус последнего выполнения
        LAST_SCHEDULE=$(kubectl get cronjob etcd-backup-cronjob -n kube-system -o jsonpath='{.status.lastScheduleTime}')
        echo "⏰ Последнее выполнение: $LAST_SCHEDULE"
        
        # Активные задания
        ACTIVE_JOBS=$(kubectl get jobs -n kube-system -l app=etcd-backup --no-headers | grep -c Running || echo "0")
        echo "🏃 Активных заданий: $ACTIVE_JOBS"
        
        # Последние задания
        echo "📋 Последние задания:"
        kubectl get jobs -n kube-system -l app=etcd-backup --sort-by=.metadata.creationTimestamp | tail -5
    else
        echo "❌ CronJob не найден"
    fi
}

# Основная функция
main() {
    echo "🚀 ЗАПУСК МОНИТОРИНГА BACKUP ETCD"
    echo "================================="
    
    # Выполнение проверок
    check_latest_backup
    check_backup_integrity
    backup_statistics
    check_cronjob_status
    
    echo -e "\n💡 РЕКОМЕНДАЦИИ:"
    echo "1. Backup должен создаваться каждые 15 минут"
    echo "2. Регулярно тестируйте восстановление"
    echo "3. Мониторьте размер backup файлов"
    echo "4. Настройте alerting для сбоев backup"
    
    echo -e "\n✅ МОНИТОРИНГ ЗАВЕРШЕН!"
}

# Запуск мониторинга
main
EOF

chmod +x etcd-backup-monitor.sh
```

## 🎯 **Best Practices для etcd backup и restore:**

### **1. Backup стратегии**
- Создавайте snapshot каждые 15-30 минут
- Используйте сжатие и шифрование backup файлов
- Храните backup в нескольких локациях
- Регулярно тестируйте процедуры восстановления

### **2. Restore процедуры**
- Всегда выполняйте тестовое восстановление
- Создавайте резервную копию текущих данных
- Документируйте процедуры восстановления
- Обучайте команду процедурам emergency restore

### **3. Мониторинг и автоматизация**
- Настройте автоматический backup через CronJob
- Мониторьте успешность backup операций
- Настройте alerting при сбоях backup
- Отслеживайте размер и возраст backup файлов

### **4. Безопасность**
- Шифруйте backup файлы
- Ограничивайте доступ к backup хранилищу
- Используйте отдельные учетные записи для backup
- Регулярно ротируйте ключи шифрования

**Правильное резервное копирование etcd — основа надежности и отказоустойчивости Kubernetes кластера!**
