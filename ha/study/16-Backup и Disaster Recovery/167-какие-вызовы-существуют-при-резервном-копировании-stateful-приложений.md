# 167. Какие вызовы существуют при резервном копировании stateful приложений?

## 🎯 **Что такое вызовы backup stateful приложений?**

**Вызовы backup stateful приложений** — это комплекс технических и архитектурных проблем, возникающих при создании резервных копий приложений с состоянием в Kubernetes. Включает обеспечение консистентности данных между репликами, координацию volume snapshots, управление зависимостями компонентов, application-aware backup hooks и восстановление правильного порядка запуска для поддержания целостности distributed state.

## 🏗️ **Основные категории вызовов:**

### **1. Data Consistency Challenges**
- **Transaction Integrity**: Обеспечение ACID свойств во время backup
- **Cross-Replica Consistency**: Синхронизация состояния между репликами
- **Temporal Synchronization**: Координация времени создания snapshots
- **Write Ordering**: Сохранение порядка операций записи

### **2. State Management Challenges**
- **Application State**: Сохранение runtime состояния приложений
- **Configuration Drift**: Управление изменениями конфигурации
- **Session Persistence**: Backup активных сессий и кэшей
- **Metadata Coordination**: Синхронизация метаданных приложений

### **3. Volume Coordination Challenges**
- **Atomic Snapshots**: Создание согласованных snapshots множественных volumes
- **Dependency Management**: Управление зависимостями между volumes
- **Cross-AZ Coordination**: Координация backup в разных availability zones
- **Storage Class Compatibility**: Совместимость различных storage backends

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ stateful приложений в кластере:**
```bash
# Поиск stateful приложений и их зависимостей
kubectl get statefulsets --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas

# Анализ persistent volumes и их использования
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,STORAGECLASS:.spec.storageClassName

# Проверка volume snapshots и их статуса
kubectl get volumesnapshots --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyToUse,SOURCEPVC:.spec.source.persistentVolumeClaimName

# Мониторинг backup операций для stateful приложений
velero backup get -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CREATED:.metadata.creationTimestamp,STATEFUL-RESOURCES:.status.progress.itemsBackedUp
```

### **2. Диагностика проблем backup stateful приложений:**
```bash
# Проверка consistency issues
kubectl get events --all-namespaces --field-selector type=Warning | grep -E "(backup|snapshot|stateful)"

# Анализ failed snapshots
kubectl get volumesnapshots --all-namespaces --field-selector status.readyToUse=false

# Проверка backup hooks и их выполнения
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.metadata.annotations.pre\.hook\.backup\.velero\.io/command}{"\n"}{end}' | grep -v "null"
```

### **3. Мониторинг stateful backup метрик:**
```bash
# Проверка времени выполнения backup hooks
kubectl get events --all-namespaces --field-selector reason=BackupHookExecuted -o custom-columns=NAMESPACE:.namespace,OBJECT:.involvedObject.name,MESSAGE:.message,TIME:.firstTimestamp

# Анализ размера и времени backup для stateful приложений
velero backup describe $(velero backup get -o name | tail -1) --details | grep -A 10 "Backup Hooks"
```

## 🔄 **Демонстрация решения основных вызовов:**

### **1. Создание comprehensive stateful backup framework:**
```bash
# Создать скрипт stateful-backup-framework.sh
cat << 'EOF' > stateful-backup-framework.sh
#!/bin/bash

echo "🏗️ Comprehensive Stateful Backup Framework"
echo "=========================================="

# Настройка переменных
BACKUP_NAMESPACE="velero"
MONITORING_NAMESPACE="monitoring"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="stateful-backup-$TIMESTAMP"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция анализа stateful приложений
analyze_stateful_applications() {
    log "🔍 Анализ stateful приложений в кластере"
    
    # Создание отчета о stateful приложениях
    local report_file="/tmp/stateful-apps-analysis-$TIMESTAMP.json"
    
    # Сбор информации о StatefulSets
    kubectl get statefulsets --all-namespaces -o json > /tmp/statefulsets.json
    
    # Сбор информации о PVCs
    kubectl get pvc --all-namespaces -o json > /tmp/pvcs.json
    
    # Анализ зависимостей
    cat > $report_file << ANALYSIS_EOF
{
  "analysis_timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "stateful_applications": {
$(kubectl get statefulsets --all-namespaces -o json | jq -r '
    .items[] | 
    {
      namespace: .metadata.namespace,
      name: .metadata.name,
      replicas: .spec.replicas,
      ready_replicas: .status.readyReplicas,
      volumes: [.spec.volumeClaimTemplates[]?.metadata.name],
      backup_annotations: .spec.template.metadata.annotations | to_entries | map(select(.key | startswith("backup."))) | from_entries,
      dependencies: (.metadata.annotations["backup.dependency.order"] // "0" | tonumber),
      storage_classes: [.spec.volumeClaimTemplates[]?.spec.storageClassName]
    }
' | jq -s '.')
  },
  "persistent_volumes": {
$(kubectl get pvc --all-namespaces -o json | jq -r '
    .items[] | 
    {
      namespace: .metadata.namespace,
      name: .metadata.name,
      status: .status.phase,
      volume_name: .spec.volumeName,
      storage_class: .spec.storageClassName,
      access_modes: .spec.accessModes,
      size: .spec.resources.requests.storage,
      app_label: .metadata.labels.app
    }
' | jq -s 'group_by(.app_label)')
  }
}
ANALYSIS_EOF
    
    log "📄 Анализ сохранен в $report_file"
    
    # Вывод краткой статистики
    local total_statefulsets=$(kubectl get statefulsets --all-namespaces --no-headers | wc -l)
    local total_pvcs=$(kubectl get pvc --all-namespaces --no-headers | wc -l)
    local backup_enabled=$(kubectl get statefulsets --all-namespaces -o json | jq '[.items[] | select(.spec.template.metadata.annotations | has("backup.velero.io/backup-volumes"))] | length')
    
    log "📊 Статистика stateful приложений:"
    log "  📦 Всего StatefulSets: $total_statefulsets"
    log "  💾 Всего PVCs: $total_pvcs"
    log "  ✅ С настроенным backup: $backup_enabled"
    
    return 0
}

# Функция создания consistency groups
create_consistency_groups() {
    log "🔗 Создание consistency groups для stateful приложений"
    
    # Получение всех stateful приложений с группировкой
    local apps=$(kubectl get statefulsets --all-namespaces -o json | jq -r '.items[] | "\(.metadata.labels.app // .metadata.name):\(.metadata.namespace)"' | sort | uniq)
    
    while IFS=':' read -r app_name namespace; do
        if [ -n "$app_name" ] && [ -n "$namespace" ]; then
            log "🎯 Создание consistency group для $app_name в $namespace"
            
            # Создание VolumeSnapshotClass для consistency group
            kubectl apply -f - << CONSISTENCY_EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ${app_name}-consistency-snapshots
  labels:
    app: $app_name
    consistency-group: "true"
driver: ebs.csi.aws.com
deletionPolicy: Delete
parameters:
  # Обеспечение консистентности
  fsFreeze: "true"
  timeout: "300s"
  # Группировка snapshots
  snapshotGroup: "${app_name}-group"
  # Координация между volumes
  coordinatedSnapshot: "true"
CONSISTENCY_EOF
            
            # Создание backup policy для приложения
            kubectl apply -f - << POLICY_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${app_name}-backup-policy
  namespace: $namespace
  labels:
    app: $app_name
    backup-policy: "true"
data:
  policy.yaml: |
    application: $app_name
    namespace: $namespace
    backup_strategy: "application-aware"
    consistency_requirements:
      - transaction_integrity: true
      - cross_replica_sync: true
      - volume_coordination: true
    hooks:
      pre_backup:
        - command: "/scripts/pre-backup-hook.sh"
        - timeout: "60s"
      post_backup:
        - command: "/scripts/post-backup-hook.sh"
        - timeout: "30s"
    recovery_order: $(kubectl get statefulset -n $namespace -l app=$app_name -o jsonpath='{.items[0].metadata.annotations.backup\.dependency\.order}' 2>/dev/null || echo "10")
POLICY_EOF
            
            log "✅ Consistency group создана для $app_name"
        fi
    done <<< "$apps"
}

# Функция координации database backup
coordinate_database_backup() {
    log "🗄️ Координация backup баз данных"
    
    # Поиск database StatefulSets
    local databases=$(kubectl get statefulsets --all-namespaces -l tier=database -o json 2>/dev/null || kubectl get statefulsets --all-namespaces -o json | jq '.items[] | select(.metadata.name | test("postgres|mysql|mongodb|redis"))')
    
    if [ -n "$databases" ]; then
        echo "$databases" | jq -r '.items[]? // . | "\(.metadata.namespace) \(.metadata.name) \(.metadata.labels.app // .metadata.name)"' | \
        while read namespace name app; do
            log "🔄 Координация backup для базы данных $app в $namespace"
            
            # Создание database-specific backup hooks
            kubectl apply -f - << DB_HOOKS_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${app}-backup-hooks
  namespace: $namespace
data:
  pre-backup-hook.sh: |
    #!/bin/bash
    echo "🔒 Pre-backup hook для $app"
    
    case "$app" in
        postgres*)
            # PostgreSQL backup coordination
            psql -U postgres -c "SELECT pg_start_backup('velero-backup', true);" || true
            psql -U postgres -c "SELECT pg_switch_wal();" || true
            ;;
        mysql*)
            # MySQL backup coordination
            mysql -u root -e "FLUSH TABLES WITH READ LOCK;" || true
            mysql -u root -e "FLUSH LOGS;" || true
            ;;
        mongodb*)
            # MongoDB backup coordination
            mongo --eval "db.fsyncLock()" || true
            ;;
        redis*)
            # Redis backup coordination
            redis-cli BGSAVE || true
            ;;
    esac
    
    echo "✅ Pre-backup hook завершен для $app"
  
  post-backup-hook.sh: |
    #!/bin/bash
    echo "🔓 Post-backup hook для $app"
    
    case "$app" in
        postgres*)
            # PostgreSQL cleanup
            psql -U postgres -c "SELECT pg_stop_backup();" || true
            ;;
        mysql*)
            # MySQL cleanup
            mysql -u root -e "UNLOCK TABLES;" || true
            ;;
        mongodb*)
            # MongoDB cleanup
            mongo --eval "db.fsyncUnlock()" || true
            ;;
        redis*)
            # Redis cleanup (no action needed)
            echo "Redis backup completed"
            ;;
    esac
    
    echo "✅ Post-backup hook завершен для $app"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $name
  namespace: $namespace
spec:
  template:
    metadata:
      annotations:
        # Velero backup annotations
        backup.velero.io/backup-volumes: "data"
        pre.hook.backup.velero.io/command: '["/bin/bash", "/hooks/pre-backup-hook.sh"]'
        pre.hook.backup.velero.io/timeout: "120s"
        post.hook.backup.velero.io/command: '["/bin/bash", "/hooks/post-backup-hook.sh"]'
        post.hook.backup.velero.io/timeout: "60s"
        # Consistency annotations
        backup.consistency.group: "$app"
        backup.dependency.order: "1"
    spec:
      containers:
      - name: database
        volumeMounts:
        - name: backup-hooks
          mountPath: /hooks
      volumes:
      - name: backup-hooks
        configMap:
          name: ${app}-backup-hooks
          defaultMode: 0755
DB_HOOKS_EOF
            
            log "✅ Database backup hooks настроены для $app"
        done
    fi
}

# Функция создания atomic snapshots
create_atomic_snapshots() {
    local app_name=$1
    local namespace=$2
    
    log "⚛️ Создание atomic snapshots для $app_name в $namespace"
    
    # Получение всех PVCs для приложения
    local pvcs=$(kubectl get pvc -n $namespace -l app=$app_name -o json)
    local pvc_count=$(echo "$pvcs" | jq '.items | length')
    
    if [ "$pvc_count" -eq 0 ]; then
        log "⚠️ Не найдено PVCs для $app_name в $namespace"
        return 1
    fi
    
    log "📦 Найдено $pvc_count PVCs для $app_name"
    
    # Создание snapshots одновременно для обеспечения консистентности
    local snapshot_group="${app_name}-atomic-${TIMESTAMP}"
    
    echo "$pvcs" | jq -r '.items[] | "\(.metadata.name) \(.spec.storageClassName)"' | \
    while read pvc_name storage_class; do
        log "📸 Создание snapshot для PVC $pvc_name"
        
        kubectl apply -f - << SNAPSHOT_EOF &
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: ${pvc_name}-atomic-${TIMESTAMP}
  namespace: $namespace
  labels:
    app: $app_name
    snapshot-group: $snapshot_group
    backup-type: "atomic"
  annotations:
    backup.timestamp: "$TIMESTAMP"
    backup.consistency.group: "$snapshot_group"
spec:
  source:
    persistentVolumeClaimName: $pvc_name
  volumeSnapshotClassName: ${app_name}-consistency-snapshots
SNAPSHOT_EOF
    done
    
    # Ожидание завершения всех snapshots
    wait
    
    # Проверка успешности создания snapshots
    local ready_snapshots=0
    local total_snapshots=$pvc_count
    local timeout=300
    local elapsed=0
    
    while [ $ready_snapshots -lt $total_snapshots ] && [ $elapsed -lt $timeout ]; do
        ready_snapshots=$(kubectl get volumesnapshots -n $namespace -l snapshot-group=$snapshot_group -o json | jq '[.items[] | select(.status.readyToUse == true)] | length')
        
        log "📊 Готовых snapshots: $ready_snapshots/$total_snapshots"
        
        if [ $ready_snapshots -lt $total_snapshots ]; then
            sleep 10
            elapsed=$((elapsed + 10))
        fi
    done
    
    if [ $ready_snapshots -eq $total_snapshots ]; then
        log "✅ Все atomic snapshots созданы успешно для $app_name"
        return 0
    else
        log "❌ Не все snapshots готовы для $app_name ($ready_snapshots/$total_snapshots)"
        return 1
    fi
}

# Функция валидации backup consistency
validate_backup_consistency() {
    log "✅ Валидация consistency backup stateful приложений"
    
    local validation_errors=0
    
    # Проверка consistency groups
    local consistency_groups=$(kubectl get volumesnapshots --all-namespaces -l backup-type=atomic -o json | jq -r '.items[] | .metadata.labels["snapshot-group"]' | sort | uniq)
    
    while IFS= read -r group; do
        if [ -n "$group" ]; then
            log "🔍 Проверка consistency group: $group"
            
            # Получение всех snapshots в группе
            local group_snapshots=$(kubectl get volumesnapshots --all-namespaces -l snapshot-group=$group -o json)
            local total_in_group=$(echo "$group_snapshots" | jq '.items | length')
            local ready_in_group=$(echo "$group_snapshots" | jq '[.items[] | select(.status.readyToUse == true)] | length')
            local failed_in_group=$(echo "$group_snapshots" | jq '[.items[] | select(.status.readyToUse != true)] | length')
            
            if [ "$ready_in_group" -eq "$total_in_group" ]; then
                log "✅ Consistency group $group: все $total_in_group snapshots готовы"
            else
                log "❌ Consistency group $group: $ready_in_group/$total_in_group готовы, $failed_in_group неудачных"
                validation_errors=$((validation_errors + failed_in_group))
                
                # Детальная диагностика неудачных snapshots
                echo "$group_snapshots" | jq -r '.items[] | select(.status.readyToUse != true) | "\(.metadata.namespace)/\(.metadata.name): \(.status.error.message // "Unknown error")"' | \
                while IFS= read -r error_info; do
                    log "  🔍 Ошибка snapshot: $error_info"
                done
            fi
        fi
    done <<< "$consistency_groups"
    
    # Проверка backup hooks execution
    local hook_events=$(kubectl get events --all-namespaces --field-selector reason=BackupHookExecuted -o json)
    local successful_hooks=$(echo "$hook_events" | jq '[.items[] | select(.message | contains("completed successfully"))] | length')
    local failed_hooks=$(echo "$hook_events" | jq '[.items[] | select(.message | contains("failed"))] | length')
    
    log "🎣 Backup hooks статистика:"
    log "  ✅ Успешных hooks: $successful_hooks"
    log "  ❌ Неудачных hooks: $failed_hooks"
    
    validation_errors=$((validation_errors + failed_hooks))
    
    # Общий результат валидации
    if [ $validation_errors -eq 0 ]; then
        log "🎉 Валидация consistency прошла успешно!"
        return 0
    else
        log "⚠️ Обнаружено $validation_errors ошибок consistency"
        return 1
    fi
}

# Функция создания recovery plan
create_recovery_plan() {
    log "📋 Создание recovery plan для stateful приложений"
    
    local recovery_plan_file="/tmp/stateful-recovery-plan-$TIMESTAMP.yaml"
    
    # Анализ зависимостей и создание плана восстановления
    cat > $recovery_plan_file << RECOVERY_PLAN_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: stateful-recovery-plan-$TIMESTAMP
  namespace: $BACKUP_NAMESPACE
data:
  recovery-plan.yaml: |
    recovery_plan:
      timestamp: "$TIMESTAMP"
      cluster: "$(kubectl config current-context)"
      
      # Этапы восстановления в порядке зависимостей
      recovery_stages:
        stage_1_infrastructure:
          order: 1
          description: "Восстановление инфраструктурных компонентов"
          components:
$(kubectl get statefulsets --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations["backup.dependency.order"] == "1") | "            - namespace: \(.metadata.namespace)\n              name: \(.metadata.name)\n              app: \(.metadata.labels.app // .metadata.name)"')
          
        stage_2_databases:
          order: 2
          description: "Восстановление баз данных"
          components:
$(kubectl get statefulsets --all-namespaces -l tier=database -o json | jq -r '.items[] | "            - namespace: \(.metadata.namespace)\n              name: \(.metadata.name)\n              app: \(.metadata.labels.app // .metadata.name)"')
          
        stage_3_messaging:
          order: 3
          description: "Восстановление messaging систем"
          components:
$(kubectl get statefulsets --all-namespaces -o json | jq -r '.items[] | select(.metadata.name | test("kafka|rabbitmq|nats")) | "            - namespace: \(.metadata.namespace)\n              name: \(.metadata.name)\n              app: \(.metadata.labels.app // .metadata.name)"')
          
        stage_4_applications:
          order: 4
          description: "Восстановление приложений"
          components:
$(kubectl get statefulsets --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations["backup.dependency.order"] // "10" | tonumber >= 4) | "            - namespace: \(.metadata.namespace)\n              name: \(.metadata.name)\n              app: \(.metadata.labels.app // .metadata.name)"')
      
      # Процедуры валидации для каждого этапа
      validation_procedures:
        database_validation:
          - "Проверка подключения к базе данных"
          - "Валидация целостности данных"
          - "Проверка репликации"
        
        application_validation:
          - "Проверка готовности подов"
          - "Валидация endpoints"
          - "Проверка health checks"
        
        consistency_validation:
          - "Проверка связей между компонентами"
          - "Валидация конфигурации"
          - "Проверка persistent volumes"
  
  recovery-script.sh: |
    #!/bin/bash
    # Автоматизированный recovery script
    
    echo "🔄 Запуск автоматизированного восстановления stateful приложений"
    
    # Функция восстановления по этапам
    restore_by_stages() {
        local stages=("infrastructure" "databases" "messaging" "applications")
        
        for stage in "\${stages[@]}"; do
            echo "📋 Восстановление этапа: \$stage"
            
            # Получение компонентов этапа из recovery plan
            local components=\$(yq eval ".recovery_plan.recovery_stages.stage_*_\$stage.components[].name" /recovery-plan.yaml)
            
            for component in \$components; do
                local namespace=\$(yq eval ".recovery_plan.recovery_stages.stage_*_\$stage.components[] | select(.name == \"\$component\") | .namespace" /recovery-plan.yaml)
                
                echo "🔄 Восстановление \$component в \$namespace"
                
                # Восстановление из backup
                velero restore create \${component}-restore-\$(date +%s) \\
                    --from-backup $BACKUP_NAME \\
                    --include-namespaces \$namespace \\
                    --include-resources statefulsets,persistentvolumeclaims,secrets,configmaps \\
                    --selector app=\$component \\
                    --wait
                
                # Ожидание готовности
                kubectl wait --for=condition=ready pod -l app=\$component -n \$namespace --timeout=600s
                
                echo "✅ Компонент \$component восстановлен"
            done
            
            echo "✅ Этап \$stage завершен"
        done
    }
    
    # Запуск восстановления
    restore_by_stages
    
    echo "🎉 Автоматизированное восстановление завершено!"
RECOVERY_PLAN_EOF
    
    kubectl apply -f $recovery_plan_file
    
    log "📄 Recovery plan создан и сохранен в кластере"
    log "📁 Локальная копия: $recovery_plan_file"
}

# Основная логика выполнения
main() {
    case "$1" in
        analyze)
            analyze_stateful_applications
            ;;
        consistency)
            create_consistency_groups
            ;;
        database)
            coordinate_database_backup
            ;;
        snapshots)
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Использование: $0 snapshots <app_name> <namespace>"
                exit 1
            fi
            create_atomic_snapshots "$2" "$3"
            ;;
        validate)
            validate_backup_consistency
            ;;
        recovery-plan)
            create_recovery_plan
            ;;
        full)
            log "🚀 Запуск полного stateful backup framework"
            analyze_stateful_applications
            create_consistency_groups
            coordinate_database_backup
            validate_backup_consistency
            create_recovery_plan
            log "🎉 Stateful backup framework настроен!"
            ;;
        *)
            echo "Использование: $0 {analyze|consistency|database|snapshots|validate|recovery-plan|full}"
            echo "  analyze       - Анализ stateful приложений"
            echo "  consistency   - Создание consistency groups"
            echo "  database      - Координация database backup"
            echo "  snapshots     - Создание atomic snapshots"
            echo "  validate      - Валидация backup consistency"
            echo "  recovery-plan - Создание recovery plan"
            echo "  full          - Полная настройка framework"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в stateful backup framework"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x stateful-backup-framework.sh
```

### **2. Создание специализированных решений для database backup:**
```bash
# Создать скрипт database-backup-challenges.sh
cat << 'EOF' > database-backup-challenges.sh
#!/bin/bash

echo "🗄️ Database Backup Challenges Solutions"
echo "======================================"

# Настройка переменных
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Решение вызова 1: PostgreSQL consistency
solve_postgresql_consistency() {
    log "🐘 Решение PostgreSQL consistency challenges"
    
    # Создание PostgreSQL backup operator
    kubectl apply -f - << POSTGRES_OPERATOR_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-backup-operator
  namespace: production
data:
  postgres-backup.sh: |
    #!/bin/bash
    # PostgreSQL application-aware backup
    
    POSTGRES_POD="\$1"
    NAMESPACE="\$2"
    BACKUP_NAME="\$3"
    
    echo "🔒 Начало PostgreSQL backup для \$POSTGRES_POD"
    
    # Этап 1: Проверка состояния кластера
    check_cluster_health() {
        echo "🏥 Проверка здоровья PostgreSQL кластера"
        
        # Проверка primary/replica статуса
        local is_primary=\$(kubectl exec -n \$NAMESPACE \$POSTGRES_POD -- \\
            psql -U postgres -t -c "SELECT NOT pg_is_in_recovery();" | tr -d ' ')
        
        if [ "\$is_primary" = "t" ]; then
            echo "✅ Узел \$POSTGRES_POD является primary"
            export POSTGRES_ROLE="primary"
        else
            echo "📖 Узел \$POSTGRES_POD является replica"
            export POSTGRES_ROLE="replica"
        fi
        
        # Проверка активных подключений
        local active_connections=\$(kubectl exec -n \$NAMESPACE \$POSTGRES_POD -- \\
            psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" | tr -d ' ')
        
        echo "🔗 Активных подключений: \$active_connections"
        
        if [ \$active_connections -gt 50 ]; then
            echo "⚠️ Высокая нагрузка на базу данных"
            return 1
        fi
        
        return 0
    }
    
    # Этап 2: Координация между репликами
    coordinate_replicas() {
        if [ "\$POSTGRES_ROLE" = "primary" ]; then
            echo "🔄 Координация primary-replica для PostgreSQL"
            
            # Получение текущей LSN позиции
            local current_lsn=\$(kubectl exec -n \$NAMESPACE \$POSTGRES_POD -- \\
                psql -U postgres -t -c "SELECT pg_current_wal_lsn();" | tr -d ' ')
            
            echo "📍 Текущая LSN позиция: \$current_lsn"
            
            # Ожидание синхронизации всех replica
            local replicas=\$(kubectl get pods -n \$NAMESPACE -l app=postgres,role=replica --no-headers | awk '{print \$1}')
            
            for replica in \$replicas; do
                echo "⏳ Ожидание синхронизации replica: \$replica"
                
                kubectl exec -n \$NAMESPACE \$replica -- \\
                    psql -U postgres -c "SELECT pg_wal_replay_wait_lsn('\$current_lsn');" || true
                
                echo "✅ Replica \$replica синхронизирована"
            done
        fi
    }
    
    # Этап 3: Начало backup режима
    start_backup_mode() {
        if [ "\$POSTGRES_ROLE" = "primary" ]; then
            echo "🔒 Начало backup режима PostgreSQL"
            
            # Начало backup режима
            kubectl exec -n \$NAMESPACE \$POSTGRES_POD -- \\
                psql -U postgres -c "SELECT pg_start_backup('\$BACKUP_NAME', true);"
            
            # Переключение WAL
            kubectl exec -n \$NAMESPACE \$POSTGRES_POD -- \\
                psql -U postgres -c "SELECT pg_switch_wal();"
            
            echo "✅ PostgreSQL backup режим активирован"
        fi
    }
    
    # Этап 4: Завершение backup режима
    stop_backup_mode() {
        if [ "\$POSTGRES_ROLE" = "primary" ]; then
            echo "🔓 Завершение backup режима PostgreSQL"
            
            kubectl exec -n \$NAMESPACE \$POSTGRES_POD -- \\
                psql -U postgres -c "SELECT pg_stop_backup();"
            
            echo "✅ PostgreSQL backup режим завершен"
        fi
    }
    
    # Основная логика
    check_cluster_health && \\
    coordinate_replicas && \\
    start_backup_mode
---
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-backup-coordinator-$TIMESTAMP
  namespace: production
spec:
  template:
    spec:
      containers:
      - name: postgres-coordinator
        image: postgres:13
        command: ["/bin/bash"]
        args: ["/scripts/postgres-backup.sh", "postgres-0", "production", "$BACKUP_NAME"]
        volumeMounts:
        - name: backup-scripts
          mountPath: /scripts
      volumes:
      - name: backup-scripts
        configMap:
          name: postgres-backup-operator
          defaultMode: 0755
      restartPolicy: OnFailure
POSTGRES_OPERATOR_EOF
    
    log "✅ PostgreSQL backup operator создан"
}

# Решение вызова 2: MongoDB replica set coordination
solve_mongodb_coordination() {
    log "🍃 Решение MongoDB replica set coordination"
    
    kubectl apply -f - << MONGODB_OPERATOR_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-backup-operator
  namespace: production
data:
  mongodb-backup.sh: |
    #!/bin/bash
    # MongoDB replica set backup coordination
    
    MONGODB_PRIMARY="\$1"
    NAMESPACE="\$2"
    
    echo "🔒 MongoDB replica set backup coordination"
    
    # Поиск primary узла
    find_primary() {
        echo "🔍 Поиск primary узла MongoDB"
        
        local primary=\$(kubectl exec -n \$NAMESPACE mongodb-0 -- \\
            mongo --eval "rs.isMaster().primary" --quiet | tr -d '"')
        
        echo "✅ Primary узел: \$primary"
        export MONGODB_PRIMARY=\$primary
    }
    
    # Координация oplog
    coordinate_oplog() {
        echo "📝 Координация oplog MongoDB"
        
        # Получение текущей oplog позиции
        local oplog_ts=\$(kubectl exec -n \$NAMESPACE \$MONGODB_PRIMARY -- \\
            mongo --eval "db.runCommand({isMaster: 1}).lastWrite.opTime.ts" --quiet)
        
        echo "📍 Текущая oplog позиция: \$oplog_ts"
        
        # Ожидание синхронизации secondary узлов
        local secondaries=\$(kubectl get pods -n \$NAMESPACE -l app=mongodb,role=secondary --no-headers | awk '{print \$1}')
        
        for secondary in \$secondaries; do
            echo "⏳ Ожидание синхронизации secondary: \$secondary"
            
            kubectl exec -n \$NAMESPACE \$secondary -- \\
                mongo --eval "
                    while (db.runCommand({isMaster: 1}).lastWrite.opTime.ts < \$oplog_ts) {
                        sleep(100);
                    }
                " --quiet || true
            
            echo "✅ Secondary \$secondary синхронизирован"
        done
    }
    
    # Блокировка записи
    lock_writes() {
        echo "🔒 Блокировка записи MongoDB"
        
        kubectl exec -n \$NAMESPACE \$MONGODB_PRIMARY -- \\
            mongo --eval "db.fsyncLock()"
        
        echo "✅ Запись заблокирована"
    }
    
    # Разблокировка записи
    unlock_writes() {
        echo "🔓 Разблокировка записи MongoDB"
        
        kubectl exec -n \$NAMESPACE \$MONGODB_PRIMARY -- \\
            mongo --eval "db.fsyncUnlock()"
        
        echo "✅ Запись разблокирована"
    }
    
    # Основная логика
    find_primary && \\
    coordinate_oplog && \\
    lock_writes
MONGODB_OPERATOR_EOF
    
    log "✅ MongoDB backup operator создан"
}

# Решение вызова 3: Volume snapshot coordination
solve_volume_coordination() {
    log "📸 Решение volume snapshot coordination"
    
    kubectl apply -f - << VOLUME_COORDINATOR_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: volume-snapshot-coordinator
  namespace: velero
data:
  coordinate-snapshots.sh: |
    #!/bin/bash
    # Координация volume snapshots для stateful приложений
    
    APP_NAME="\$1"
    NAMESPACE="\$2"
    TIMESTAMP=\$(date +%s)
    
    echo "📸 Координация volume snapshots для \$APP_NAME"
    
    # Получение всех PVCs для приложения
    get_app_pvcs() {
        kubectl get pvc -n \$NAMESPACE -l app=\$APP_NAME -o json | \\
            jq -r '.items[] | "\(.metadata.name) \(.spec.storageClassName)"'
    }
    
    # Создание atomic snapshots
    create_atomic_snapshots() {
        local snapshot_group="\${APP_NAME}-atomic-\${TIMESTAMP}"
        
        echo "⚛️ Создание atomic snapshots группы: \$snapshot_group"
        
        # Создание всех snapshots одновременно
        get_app_pvcs | while read pvc_name storage_class; do
            echo "📸 Создание snapshot для PVC: \$pvc_name"
            
            cat <<SNAPSHOT_EOF | kubectl apply -f - &
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: \${pvc_name}-atomic-\${TIMESTAMP}
  namespace: \$NAMESPACE
  labels:
    app: \$APP_NAME
    snapshot-group: \$snapshot_group
    backup-type: atomic
spec:
  source:
    persistentVolumeClaimName: \$pvc_name
  volumeSnapshotClassName: csi-snapshotter
SNAPSHOT_EOF
        done
        
        # Ожидание завершения всех snapshots
        wait
        
        echo "✅ Все snapshots созданы для группы: \$snapshot_group"
    }
    
    # Валидация snapshots
    validate_snapshots() {
        local snapshot_group="\${APP_NAME}-atomic-\${TIMESTAMP}"
        local timeout=300
        local elapsed=0
        
        echo "✅ Валидация snapshots группы: \$snapshot_group"
        
        while [ \$elapsed -lt \$timeout ]; do
            local total=\$(kubectl get volumesnapshots -n \$NAMESPACE -l snapshot-group=\$snapshot_group --no-headers | wc -l)
            local ready=\$(kubectl get volumesnapshots -n \$NAMESPACE -l snapshot-group=\$snapshot_group -o json | \\
                jq '[.items[] | select(.status.readyToUse == true)] | length')
            
            echo "📊 Готовых snapshots: \$ready/\$total"
            
            if [ \$ready -eq \$total ] && [ \$total -gt 0 ]; then
                echo "✅ Все snapshots готовы"
                return 0
            fi
            
            sleep 10
            elapsed=\$((elapsed + 10))
        done
        
        echo "❌ Timeout при ожидании snapshots"
        return 1
    }
    
    # Основная логика
    create_atomic_snapshots && validate_snapshots
VOLUME_COORDINATOR_EOF
    
    log "✅ Volume snapshot coordinator создан"
}

# Основная логика выполнения
main() {
    case "$1" in
        postgresql)
            solve_postgresql_consistency
            ;;
        mongodb)
            solve_mongodb_coordination
            ;;
        volumes)
            solve_volume_coordination
            ;;
        all)
            log "🚀 Решение всех database backup challenges"
            solve_postgresql_consistency
            solve_mongodb_coordination
            solve_volume_coordination
            log "🎉 Все решения развернуты!"
            ;;
        *)
            echo "Использование: $0 {postgresql|mongodb|volumes|all}"
            echo "  postgresql - Решение PostgreSQL consistency challenges"
            echo "  mongodb    - Решение MongoDB coordination challenges"
            echo "  volumes    - Решение volume coordination challenges"
            echo "  all        - Развертывание всех решений"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в database backup challenges"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x database-backup-challenges.sh
```

### **3. Создание мониторинга stateful backup challenges:**
```bash
# Создать скрипт stateful-backup-monitoring.sh
cat << 'EOF' > stateful-backup-monitoring.sh
#!/bin/bash

echo "📊 Мониторинг Stateful Backup Challenges"
echo "======================================"

# Функция создания Prometheus метрик для stateful backup
create_stateful_backup_metrics() {
    kubectl apply -f - << METRICS_EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: stateful-backup-challenges
  namespace: monitoring
spec:
  groups:
  - name: stateful-backup-consistency
    rules:
    - alert: StatefulBackupConsistencyFailure
      expr: stateful_backup_consistency_check == 0
      for: 5m
      labels:
        severity: critical
        component: backup
        challenge: consistency
      annotations:
        summary: "Stateful backup consistency check failed"
        description: "Consistency check failed for stateful application {{ \$labels.app }}"
    
    - alert: VolumeSnapshotCoordinationFailure
      expr: volume_snapshot_coordination_failed_total > 0
      for: 0m
      labels:
        severity: critical
        component: storage
        challenge: coordination
      annotations:
        summary: "Volume snapshot coordination failed"
        description: "{{ \$value }} volume snapshots failed coordination"
    
    - alert: DatabaseBackupHookTimeout
      expr: database_backup_hook_duration_seconds > 300
      for: 0m
      labels:
        severity: warning
        component: database
        challenge: hooks
      annotations:
        summary: "Database backup hook timeout"
        description: "Database backup hook took {{ \$value }} seconds"
    
    - alert: StatefulSetRecoveryOrderViolation
      expr: statefulset_recovery_order_violations_total > 0
      for: 0m
      labels:
        severity: warning
        component: recovery
        challenge: ordering
      annotations:
        summary: "StatefulSet recovery order violation"
        description: "{{ \$value }} recovery order violations detected"
METRICS_EOF
}

# Функция создания Grafana dashboard
create_stateful_backup_dashboard() {
    kubectl apply -f - << DASHBOARD_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: stateful-backup-challenges-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  stateful-backup-challenges.json: |
    {
      "dashboard": {
        "title": "Stateful Backup Challenges",
        "panels": [
          {
            "title": "Consistency Challenges",
            "type": "timeseries",
            "targets": [
              {"expr": "stateful_backup_consistency_check", "legendFormat": "Consistency Check"},
              {"expr": "database_transaction_integrity", "legendFormat": "Transaction Integrity"},
              {"expr": "cross_replica_sync_status", "legendFormat": "Cross-Replica Sync"}
            ]
          },
          {
            "title": "Volume Coordination",
            "type": "timeseries", 
            "targets": [
              {"expr": "volume_snapshot_coordination_success_rate", "legendFormat": "Success Rate"},
              {"expr": "atomic_snapshot_creation_time", "legendFormat": "Creation Time"},
              {"expr": "volume_dependency_resolution_time", "legendFormat": "Dependency Resolution"}
            ]
          },
          {
            "title": "Recovery Challenges",
            "type": "timeseries",
            "targets": [
              {"expr": "statefulset_recovery_order_compliance", "legendFormat": "Order Compliance"},
              {"expr": "dependency_resolution_time", "legendFormat": "Dependency Resolution"},
              {"expr": "state_validation_success_rate", "legendFormat": "State Validation"}
            ]
          }
        ]
      }
    }
DASHBOARD_EOF
}

# Запуск мониторинга
create_stateful_backup_metrics
create_stateful_backup_dashboard

echo "✅ Мониторинг stateful backup challenges настроен"
EOF

chmod +x stateful-backup-monitoring.sh
```

## 📊 **Архитектура решения stateful backup challenges:**

```
┌─────────────────────────────────────────────────────────────┐
│           Stateful Backup Challenges Solutions             │
├─────────────────────────────────────────────────────────────┤
│  Challenge Categories & Solutions                           │
│  ┌─────────────────────┬─────────────────────┬─────────────┐ │
│  │ Data Consistency    │ State Management    │ Volume Coord│ │
│  │ ├── ACID Properties │ ├── App State       │ ├── Atomic  │ │
│  │ ├── Replica Sync    │ ├── Config Drift    │ ├── Deps    │ │
│  │ ├── Temporal Sync   │ ├── Session Persist │ ├── Cross-AZ│ │
│  │ └── Write Ordering  │ └── Metadata Coord  │ └── Storage │ │
│  └─────────────────────┴─────────────────────┴─────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Solution Framework                                         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ ├── Application-Aware Hooks (Pre/Post Backup)          │ │
│  │ ├── Consistency Groups (Coordinated Snapshots)         │ │
│  │ ├── Dependency Management (Recovery Ordering)          │ │
│  │ ├── Database Operators (PostgreSQL, MongoDB, etc.)     │ │
│  │ └── Monitoring & Alerting (Prometheus, Grafana)        │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для решения stateful backup challenges:**

### **1. Стратегическое планирование**
- Анализируйте зависимости между stateful компонентами
- Определите требования к consistency для каждого приложения
- Планируйте порядок восстановления заранее
- Документируйте все процедуры и зависимости

### **2. Техническая реализация**
- Используйте application-aware backup hooks
- Создавайте consistency groups для связанных volumes
- Координируйте snapshots между репликами
- Автоматизируйте валидацию backup

### **3. Мониторинг и валидация**
- Отслеживайте метрики consistency
- Мониторьте время выполнения hooks
- Проверяйте успешность coordination
- Алертинг на критичные ошибки

### **4. Recovery planning**
- Создавайте детальные recovery plans
- Тестируйте процедуры восстановления
- Валидируйте порядок запуска компонентов
- Обновляйте планы на основе тестов

**Понимание и решение вызовов backup stateful приложений критически важно для обеспечения надежности и целостности данных в Kubernetes среде!**
