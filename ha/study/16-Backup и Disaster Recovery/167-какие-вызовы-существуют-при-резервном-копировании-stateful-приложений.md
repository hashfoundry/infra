# 167. Какие вызовы существуют при резервном копировании stateful приложений?

## 🎯 Вопрос
Какие вызовы существуют при резервном копировании stateful приложений?

## 💡 Ответ

Backup stateful приложений в Kubernetes представляет уникальные вызовы: обеспечение консистентности данных, координация между репликами, управление зависимостями, snapshot'ы persistent volumes и восстановление правильного порядка запуска компонентов.

### 🏗️ Архитектура stateful backup

#### 1. **Схема вызовов stateful backup**
```
┌─────────────────────────────────────────────────────────────┐
│              Stateful Application Backup Challenges        │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Data        │    │ State       │    │ Dependencies│     │
│  │ Consistency │    │ Management  │    │ & Ordering  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Volume      │    │ Application │    │ Cross-Pod   │     │
│  │ Snapshots   │    │ Quiescing   │    │ Coordination│     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Основные вызовы**
```yaml
# Основные вызовы stateful backup
stateful_backup_challenges:
  data_consistency:
    - "Транзакционная целостность"
    - "Консистентность между репликами"
    - "Временная синхронизация"
    - "ACID свойства"
  
  state_management:
    - "Сохранение состояния приложения"
    - "Метаданные и конфигурации"
    - "Сессии и кэши"
    - "Временные файлы"
  
  volume_coordination:
    - "Синхронизация snapshot'ов"
    - "Зависимости между volumes"
    - "Порядок создания backup"
    - "Атомарность операций"
  
  application_awareness:
    - "Quiescing приложений"
    - "Flush буферов"
    - "Остановка записи"
    - "Координация с приложением"
  
  recovery_complexity:
    - "Порядок восстановления"
    - "Инициализация состояния"
    - "Восстановление связей"
    - "Валидация целостности"
```

### 📊 Примеры из нашего кластера

#### Проверка stateful приложений:
```bash
# Поиск stateful приложений
kubectl get statefulsets --all-namespaces
kubectl get pvc --all-namespaces
kubectl get pods --all-namespaces -l app=database

# Проверка volumes и storage
kubectl get pv
kubectl get storageclass
kubectl describe pvc -n production
```

### 🗄️ Вызовы баз данных

#### 1. **PostgreSQL backup вызовы**
```bash
#!/bin/bash
# postgresql-backup-challenges.sh

echo "🗄️ PostgreSQL backup с консистентностью"

# Переменные
POSTGRES_POD="postgres-0"
NAMESPACE="production"
BACKUP_DIR="/backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Вызов 1: Обеспечение консистентности транзакций
ensure_transaction_consistency() {
    echo "🔒 Обеспечение консистентности транзакций"
    
    # Начало backup режима
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
        psql -U postgres -c "SELECT pg_start_backup('velero-backup', true);"
    
    # Ожидание завершения активных транзакций
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
        psql -U postgres -c "SELECT pg_sleep(5);"
    
    # Flush WAL буферов
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
        psql -U postgres -c "SELECT pg_switch_wal();"
    
    echo "✅ Транзакционная консистентность обеспечена"
}

# Вызов 2: Координация между master и replica
coordinate_master_replica() {
    echo "🔄 Координация между master и replica"
    
    # Получение LSN позиции
    local master_lsn=$(kubectl exec -n $NAMESPACE postgres-master-0 -- \
        psql -U postgres -t -c "SELECT pg_current_wal_lsn();")
    
    # Ожидание синхронизации replica
    kubectl exec -n $NAMESPACE postgres-replica-0 -- \
        psql -U postgres -c "SELECT pg_wal_replay_wait_lsn('$master_lsn');"
    
    echo "✅ Master-replica синхронизация завершена"
}

# Вызов 3: Snapshot координация
coordinate_volume_snapshots() {
    echo "📸 Координация volume snapshots"
    
    # Получение всех PVC для PostgreSQL
    local pvcs=$(kubectl get pvc -n $NAMESPACE -l app=postgres -o name)
    
    # Создание snapshot для каждого volume одновременно
    for pvc in $pvcs; do
        local pvc_name=$(echo $pvc | cut -d/ -f2)
        
        cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-snapshot-$pvc_name-$TIMESTAMP
  namespace: $NAMESPACE
spec:
  source:
    persistentVolumeClaimName: $pvc_name
  volumeSnapshotClassName: csi-snapshotter
EOF
    done
    
    echo "✅ Volume snapshots созданы"
}

# Вызов 4: Application-aware backup
application_aware_backup() {
    echo "🎯 Application-aware backup"
    
    # Получение метаданных приложения
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
        psql -U postgres -c "\l+" > $BACKUP_DIR/databases-$TIMESTAMP.txt
    
    # Backup конфигурации
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
        cat /var/lib/postgresql/data/postgresql.conf > $BACKUP_DIR/postgresql-conf-$TIMESTAMP.txt
    
    # Backup пользователей и ролей
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
        pg_dumpall -U postgres --roles-only > $BACKUP_DIR/roles-$TIMESTAMP.sql
    
    echo "✅ Application-aware backup завершен"
}

# Завершение backup режима
finish_backup_mode() {
    echo "🏁 Завершение backup режима"
    
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
        psql -U postgres -c "SELECT pg_stop_backup();"
    
    echo "✅ Backup режим завершен"
}

# Основная логика
case "$1" in
    consistency)
        ensure_transaction_consistency
        ;;
    coordination)
        coordinate_master_replica
        ;;
    snapshots)
        coordinate_volume_snapshots
        ;;
    aware)
        application_aware_backup
        ;;
    full)
        ensure_transaction_consistency
        coordinate_master_replica
        coordinate_volume_snapshots
        application_aware_backup
        finish_backup_mode
        ;;
    *)
        echo "Использование: $0 {consistency|coordination|snapshots|aware|full}"
        exit 1
        ;;
esac
```

#### 2. **MongoDB backup вызовы**
```yaml
# mongodb-backup-challenges.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-backup-config
  namespace: production
data:
  backup-script.sh: |
    #!/bin/bash
    # MongoDB backup с обработкой replica set
    
    echo "🍃 MongoDB backup с replica set координацией"
    
    # Переменные
    MONGODB_PRIMARY="mongodb-0"
    MONGODB_SECONDARY="mongodb-1,mongodb-2"
    NAMESPACE="production"
    
    # Вызов 1: Определение primary узла
    find_primary_node() {
        echo "🔍 Поиск primary узла"
        
        local primary=$(kubectl exec -n $NAMESPACE mongodb-0 -- \
            mongo --eval "rs.isMaster().primary" --quiet)
        
        echo "Primary узел: $primary"
        export MONGODB_PRIMARY=$primary
    }
    
    # Вызов 2: Обеспечение read concern majority
    ensure_read_concern() {
        echo "📖 Обеспечение read concern majority"
        
        kubectl exec -n $NAMESPACE $MONGODB_PRIMARY -- \
            mongo --eval "
                db.adminCommand({
                    setDefaultRWConcern: 1,
                    defaultReadConcern: { level: 'majority' },
                    defaultWriteConcern: { w: 'majority', j: true }
                })
            "
        
        echo "✅ Read concern majority установлен"
    }
    
    # Вызов 3: Координация oplog
    coordinate_oplog() {
        echo "📝 Координация oplog"
        
        # Получение текущей позиции oplog
        local oplog_ts=$(kubectl exec -n $NAMESPACE $MONGODB_PRIMARY -- \
            mongo --eval "db.runCommand({isMaster: 1}).lastWrite.opTime.ts" --quiet)
        
        # Ожидание синхронизации secondary узлов
        for secondary in $(echo $MONGODB_SECONDARY | tr ',' ' '); do
            kubectl exec -n $NAMESPACE $secondary -- \
                mongo --eval "
                    while (db.runCommand({isMaster: 1}).lastWrite.opTime.ts < $oplog_ts) {
                        sleep(100);
                    }
                " --quiet
        done
        
        echo "✅ Oplog синхронизирован"
    }
    
    # Вызов 4: Consistent snapshot
    create_consistent_snapshot() {
        echo "📸 Создание consistent snapshot"
        
        # Блокировка записи
        kubectl exec -n $NAMESPACE $MONGODB_PRIMARY -- \
            mongo --eval "db.fsyncLock()"
        
        # Создание snapshot всех volumes
        local pvcs=$(kubectl get pvc -n $NAMESPACE -l app=mongodb -o name)
        
        for pvc in $pvcs; do
            local pvc_name=$(echo $pvc | cut -d/ -f2)
            
            cat <<EOF | kubectl apply -f -
    apiVersion: snapshot.storage.k8s.io/v1
    kind: VolumeSnapshot
    metadata:
      name: mongodb-snapshot-$pvc_name-$(date +%s)
      namespace: $NAMESPACE
    spec:
      source:
        persistentVolumeClaimName: $pvc_name
      volumeSnapshotClassName: csi-snapshotter
    EOF
        done
        
        # Разблокировка записи
        kubectl exec -n $NAMESPACE $MONGODB_PRIMARY -- \
            mongo --eval "db.fsyncUnlock()"
        
        echo "✅ Consistent snapshot создан"
    }
---
# MongoDB StatefulSet с backup hooks
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: production
spec:
  serviceName: mongodb
  replicas: 3
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
      annotations:
        backup.velero.io/backup-volumes: mongodb-data
        pre.hook.backup.velero.io/command: '["/bin/bash", "-c", "mongo --eval \"db.fsyncLock()\""]'
        post.hook.backup.velero.io/command: '["/bin/bash", "-c", "mongo --eval \"db.fsyncUnlock()\""]'
    spec:
      containers:
      - name: mongodb
        image: mongo:4.4
        command:
        - mongod
        - --replSet=rs0
        - --bind_ip_all
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "admin"
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: password
  volumeClaimTemplates:
  - metadata:
      name: mongodb-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### 🔄 Вызовы StatefulSet

#### 1. **Порядок восстановления**
```bash
#!/bin/bash
# statefulset-recovery-order.sh

echo "🔄 Управление порядком восстановления StatefulSet"

# Вызов 1: Определение зависимостей
analyze_dependencies() {
    echo "🔍 Анализ зависимостей StatefulSet"
    
    # Получение всех StatefulSet
    local statefulsets=$(kubectl get statefulsets --all-namespaces -o json)
    
    # Анализ зависимостей через labels и annotations
    echo "$statefulsets" | jq -r '
        .items[] | 
        select(.metadata.annotations["backup.dependency.order"]) |
        "\(.metadata.namespace)/\(.metadata.name): \(.metadata.annotations["backup.dependency.order"])"
    ' | sort -k2 -n
    
    echo "✅ Зависимости проанализированы"
}

# Вызов 2: Поэтапное восстановление
staged_recovery() {
    echo "🎭 Поэтапное восстановление"
    
    local recovery_stages=(
        "infrastructure:etcd,consul"
        "databases:postgres,mongodb,redis"
        "messaging:kafka,rabbitmq"
        "applications:api,frontend"
    )
    
    for stage in "${recovery_stages[@]}"; do
        local stage_name=$(echo $stage | cut -d: -f1)
        local components=$(echo $stage | cut -d: -f2 | tr ',' ' ')
        
        echo "📋 Восстановление стадии: $stage_name"
        
        for component in $components; do
            echo "🔄 Восстановление компонента: $component"
            
            # Восстановление из backup
            velero restore create ${component}-restore-$(date +%s) \
                --from-backup latest-backup \
                --include-resources statefulsets,persistentvolumeclaims \
                --selector app=$component \
                --wait
            
            # Ожидание готовности
            kubectl wait --for=condition=ready pod -l app=$component --timeout=600s
            
            echo "✅ Компонент $component восстановлен"
        done
        
        echo "✅ Стадия $stage_name завершена"
    done
}

# Вызов 3: Валидация состояния
validate_stateful_recovery() {
    echo "✅ Валидация восстановления stateful приложений"
    
    # Проверка StatefulSet
    local statefulsets=$(kubectl get statefulsets --all-namespaces --no-headers)
    
    while IFS= read -r line; do
        local namespace=$(echo $line | awk '{print $1}')
        local name=$(echo $line | awk '{print $2}')
        local ready=$(echo $line | awk '{print $3}')
        local desired=$(echo $line | awk '{print $4}')
        
        if [ "$ready" = "$desired" ]; then
            echo "✅ StatefulSet $namespace/$name: $ready/$desired готов"
        else
            echo "❌ StatefulSet $namespace/$name: $ready/$desired не готов"
            
            # Диагностика проблем
            kubectl describe statefulset $name -n $namespace
            kubectl get events -n $namespace --field-selector involvedObject.name=$name
        fi
    done <<< "$statefulsets"
}

# Основная логика
case "$1" in
    analyze)
        analyze_dependencies
        ;;
    recover)
        staged_recovery
        ;;
    validate)
        validate_stateful_recovery
        ;;
    full)
        analyze_dependencies
        staged_recovery
        validate_stateful_recovery
        ;;
    *)
        echo "Использование: $0 {analyze|recover|validate|full}"
        exit 1
        ;;
esac
```

### 💾 Вызовы Persistent Volumes

#### 1. **Volume snapshot координация**
```yaml
# volume-snapshot-coordination.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: volume-snapshot-config
  namespace: velero
data:
  snapshot-coordinator.sh: |
    #!/bin/bash
    # Координация volume snapshots для stateful приложений
    
    echo "📸 Координация volume snapshots"
    
    # Вызов 1: Группировка связанных volumes
    group_related_volumes() {
        echo "🔗 Группировка связанных volumes"
        
        # Получение PVC с метками приложений
        kubectl get pvc --all-namespaces -o json | jq -r '
            .items[] | 
            select(.metadata.labels.app) |
            "\(.metadata.labels.app):\(.metadata.namespace)/\(.metadata.name)"
        ' | sort | uniq
    }
    
    # Вызов 2: Атомарное создание snapshots
    create_atomic_snapshots() {
        local app_name=$1
        local timestamp=$(date +%s)
        
        echo "⚛️ Создание атомарных snapshots для $app_name"
        
        # Получение всех PVC для приложения
        local pvcs=$(kubectl get pvc --all-namespaces -l app=$app_name -o json)
        
        # Создание snapshots одновременно
        echo "$pvcs" | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
        while read namespace pvc_name; do
            cat <<EOF | kubectl apply -f - &
    apiVersion: snapshot.storage.k8s.io/v1
    kind: VolumeSnapshot
    metadata:
      name: ${app_name}-${pvc_name}-${timestamp}
      namespace: $namespace
      labels:
        app: $app_name
        snapshot-group: ${app_name}-${timestamp}
    spec:
      source:
        persistentVolumeClaimName: $pvc_name
      volumeSnapshotClassName: csi-snapshotter
    EOF
        done
        
        # Ожидание завершения всех snapshots
        wait
        
        echo "✅ Атомарные snapshots созданы для $app_name"
    }
    
    # Вызов 3: Проверка консистентности snapshots
    verify_snapshot_consistency() {
        local app_name=$1
        local snapshot_group=$2
        
        echo "🔍 Проверка консистентности snapshots"
        
        # Получение всех snapshots в группе
        local snapshots=$(kubectl get volumesnapshots --all-namespaces \
            -l snapshot-group=$snapshot_group -o json)
        
        # Проверка статуса всех snapshots
        local failed_snapshots=$(echo "$snapshots" | jq -r '
            .items[] | 
            select(.status.readyToUse != true) |
            "\(.metadata.namespace)/\(.metadata.name)"
        ')
        
        if [ -z "$failed_snapshots" ]; then
            echo "✅ Все snapshots в группе $snapshot_group готовы"
            return 0
        else
            echo "❌ Неудачные snapshots:"
            echo "$failed_snapshots"
            return 1
        fi
    }
---
# VolumeSnapshotClass с настройками консистентности
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: consistent-snapshots
driver: ebs.csi.aws.com
deletionPolicy: Delete
parameters:
  # Обеспечение консистентности на уровне файловой системы
  fsFreeze: "true"
  # Таймаут для операций snapshot
  timeout: "300s"
  # Группировка snapshots
  snapshotGroup: "enabled"
```

### 🎯 Решения для основных вызовов

#### 1. **Application-aware backup hooks**
```yaml
# application-aware-hooks.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-hooks
  namespace: production
data:
  postgres-pre-hook.sh: |
    #!/bin/bash
    # Pre-backup hook для PostgreSQL
    echo "🔒 PostgreSQL pre-backup hook"
    
    # Начало backup режима
    psql -U postgres -c "SELECT pg_start_backup('velero-backup', true);"
    
    # Flush WAL
    psql -U postgres -c "SELECT pg_switch_wal();"
    
    echo "✅ PostgreSQL готов к backup"
  
  postgres-post-hook.sh: |
    #!/bin/bash
    # Post-backup hook для PostgreSQL
    echo "🔓 PostgreSQL post-backup hook"
    
    # Завершение backup режима
    psql -U postgres -c "SELECT pg_stop_backup();"
    
    echo "✅ PostgreSQL backup режим завершен"
  
  mongodb-pre-hook.sh: |
    #!/bin/bash
    # Pre-backup hook для MongoDB
    echo "🔒 MongoDB pre-backup hook"
    
    # Блокировка записи
    mongo --eval "db.fsyncLock()"
    
    echo "✅ MongoDB готов к backup"
  
  mongodb-post-hook.sh: |
    #!/bin/bash
    # Post-backup hook для MongoDB
    echo "🔓 MongoDB post-backup hook"
    
    # Разблокировка записи
    mongo --eval "db.fsyncUnlock()"
    
    echo "✅ MongoDB backup завершен"
---
# StatefulSet с backup hooks
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
      annotations:
        # Velero backup hooks
        backup.velero.io/backup-volumes: postgres-data
        pre.hook.backup.velero.io/command: '["/scripts/postgres-pre-hook.sh"]'
        pre.hook.backup.velero.io/timeout: '30s'
        post.hook.backup.velero.io/command: '["/scripts/postgres-post-hook.sh"]'
        post.hook.backup.velero.io/timeout: '30s'
        
        # Порядок восстановления
        backup.dependency.order: "1"
        backup.recovery.priority: "high"
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "hashfoundry"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: backup-hooks
          mountPath: /scripts
      volumes:
      - name: backup-hooks
        configMap:
          name: backup-hooks
          defaultMode: 0755
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
```

#### 2. **Мониторинг stateful backup**
```yaml
# stateful-backup-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: stateful-backup-alerts
  namespace: monitoring
spec:
  groups:
  - name: stateful-backup
    rules:
    - alert: StatefulBackupInconsistent
      expr: stateful_backup_consistency_check == 0
      for: 5m
      labels:
        severity: critical
        component: backup
      annotations:
        summary: "Stateful backup consistency check failed"
        description: "Backup consistency check failed for stateful application {{ $labels.app }}"
    
    - alert: StatefulBackupHookTimeout
      expr: stateful_backup_hook_duration_seconds > 300
      for: 0m
      labels:
        severity: warning
        component: backup
      annotations:
        summary: "Stateful backup hook timeout"
        description: "Backup hook for {{ $labels.app }} took {{ $value }} seconds"
    
    - alert: VolumeSnapshotFailed
      expr: volume_snapshot_failed_total > 0
      for: 0m
      labels:
        severity: critical
        component: storage
      annotations:
        summary: "Volume snapshot failed"
        description: "{{ $value }} volume snapshots failed in the last hour"
```

### 🎯 Лучшие практики

#### 1. **Стратегия для stateful приложений**
```yaml
stateful_backup_best_practices:
  planning:
    - "Определить зависимости между компонентами"
    - "Спланировать порядок восстановления"
    - "Настроить application-aware hooks"
    - "Тестировать backup и recovery регулярно"
  
  implementation:
    - "Использовать consistent snapshots"
    - "Координировать backup между репликами"
    - "Обеспечивать транзакционную целостность"
    - "Мониторить процесс backup"
  
  recovery:
    - "Восстанавливать в правильном порядке"
    - "Валидировать целостность данных"
    - "Проверять связи между компонентами"
    - "Документировать процедуры"
```

Понимание и решение вызовов backup stateful приложений критически важно для обеспечения надежности и целостности данных в Kubernetes среде.
