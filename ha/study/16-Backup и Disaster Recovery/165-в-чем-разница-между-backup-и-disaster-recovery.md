# 165. В чем разница между backup и disaster recovery?

## 🎯 Вопрос
В чем разница между backup и disaster recovery?

## 💡 Ответ

Backup и Disaster Recovery (DR) - это взаимосвязанные, но различные концепции. Backup фокусируется на создании копий данных для защиты от потери, а DR представляет собой комплексную стратегию восстановления всей IT-инфраструктуры после катастрофических сбоев.

### 🏗️ Сравнение концепций

#### 1. **Схема различий Backup vs DR**
```
┌─────────────────────────────────────────────────────────────┐
│                    Backup vs Disaster Recovery             │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐         │
│  │       BACKUP        │    │   DISASTER RECOVERY │         │
│  │                     │    │                     │         │
│  │  • Data Protection  │    │  • Business Continuity │     │
│  │  • Point-in-time    │    │  • Infrastructure    │         │
│  │  • File/DB copies   │    │  • Process & People  │         │
│  │  • Storage focused  │    │  • End-to-end solution │     │
│  │                     │    │                     │         │
│  │  RTO: Hours/Days    │    │  RTO: Minutes/Hours │         │
│  │  RPO: Hours         │    │  RPO: Minutes       │         │
│  └─────────────────────┘    └─────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Ключевые различия**
```yaml
# Ключевые различия между Backup и DR
backup_vs_dr_differences:
  scope:
    backup:
      - "Защита данных"
      - "Файлы и базы данных"
      - "Точечное восстановление"
      - "Локальные копии"
    disaster_recovery:
      - "Восстановление бизнеса"
      - "Вся IT-инфраструктура"
      - "Непрерывность операций"
      - "Альтернативные площадки"
  
  objectives:
    backup:
      - "Предотвращение потери данных"
      - "Восстановление файлов"
      - "Защита от ошибок"
      - "Соответствие политикам"
    disaster_recovery:
      - "Минимизация простоя"
      - "Восстановление сервисов"
      - "Защита от катастроф"
      - "Обеспечение SLA"
  
  implementation:
    backup:
      - "Scheduled jobs"
      - "Storage systems"
      - "Backup software"
      - "Retention policies"
    disaster_recovery:
      - "Failover procedures"
      - "Alternative sites"
      - "Communication plans"
      - "Testing protocols"
```

### 📊 Примеры из нашего кластера

#### Проверка backup и DR компонентов:
```bash
# Backup компоненты
kubectl get pods -n velero
kubectl get backups -n velero
kubectl get schedules -n velero

# DR компоненты
kubectl get nodes --show-labels | grep disaster-recovery
kubectl cluster-info dump | grep -i "disaster\|failover"

# Мониторинг обеих систем
kubectl get events --field-selector type=Warning | grep -E "(backup|restore|failover)"
```

### 💾 Backup - Защита данных

#### 1. **Характеристики Backup**
```yaml
# backup-characteristics.yaml
backup_characteristics:
  primary_purpose: "Data Protection"
  
  scope:
    - "Application data"
    - "Configuration files"
    - "Database contents"
    - "User files"
  
  frequency:
    - "Daily incremental"
    - "Weekly full"
    - "Real-time for critical data"
    - "On-demand manual"
  
  storage_locations:
    - "Local storage"
    - "Network attached storage"
    - "Cloud object storage"
    - "Tape libraries"
  
  recovery_scenarios:
    - "Accidental file deletion"
    - "Data corruption"
    - "Application errors"
    - "User mistakes"
  
  metrics:
    rpo: "1-24 hours"
    rto: "1-8 hours"
    retention: "30 days - 7 years"
    automation: "High"
---
# Пример backup конфигурации
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: data-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"                  # Ежедневно в 2:00
  template:
    includedNamespaces:
    - production
    - staging
    includedResources:
    - persistentvolumes
    - persistentvolumeclaims
    - configmaps
    - secrets
    excludedResources:
    - events
    storageLocation: default
    ttl: 720h                            # 30 дней хранения
```

#### 2. **Скрипт backup операций**
```bash
#!/bin/bash
# backup-operations.sh

echo "💾 Backup операции"

# Создание backup данных приложения
create_application_backup() {
    local app_name=$1
    local namespace=${2:-default}
    
    echo "📦 Создание backup приложения: $app_name"
    
    # Backup через Velero
    velero backup create ${app_name}-backup-$(date +%Y%m%d-%H%M%S) \
        --include-namespaces $namespace \
        --selector app=$app_name \
        --wait
    
    echo "✅ Backup создан для $app_name"
}

# Backup базы данных
create_database_backup() {
    local db_type=$1
    local db_name=$2
    
    echo "🗄️ Создание backup базы данных: $db_name"
    
    case $db_type in
        postgres)
            kubectl exec -n production postgres-0 -- \
                pg_dump -U postgres $db_name > /backup/${db_name}-$(date +%Y%m%d).sql
            ;;
        mysql)
            kubectl exec -n production mysql-0 -- \
                mysqldump -u root -p$MYSQL_ROOT_PASSWORD $db_name > /backup/${db_name}-$(date +%Y%m%d).sql
            ;;
        mongodb)
            kubectl exec -n production mongodb-0 -- \
                mongodump --db $db_name --out /backup/${db_name}-$(date +%Y%m%d)
            ;;
    esac
    
    echo "✅ Database backup создан для $db_name"
}

# Backup конфигураций
create_config_backup() {
    echo "⚙️ Создание backup конфигураций"
    
    # Backup всех ConfigMaps
    kubectl get configmaps --all-namespaces -o yaml > /backup/configmaps-$(date +%Y%m%d).yaml
    
    # Backup всех Secrets (без sensitive данных)
    kubectl get secrets --all-namespaces -o yaml | \
        sed 's/data:/data: <REDACTED>/g' > /backup/secrets-$(date +%Y%m%d).yaml
    
    # Backup RBAC
    kubectl get clusterroles,clusterrolebindings,roles,rolebindings --all-namespaces -o yaml > \
        /backup/rbac-$(date +%Y%m%d).yaml
    
    echo "✅ Конфигурации сохранены"
}

# Проверка целостности backup
verify_backup_integrity() {
    local backup_name=$1
    
    echo "🔍 Проверка целостности backup: $backup_name"
    
    # Проверка через Velero
    velero backup describe $backup_name
    
    # Проверка размера и контрольных сумм
    if [ -f "/backup/${backup_name}.tar.gz" ]; then
        echo "Размер backup: $(du -h /backup/${backup_name}.tar.gz | cut -f1)"
        echo "Контрольная сумма: $(sha256sum /backup/${backup_name}.tar.gz)"
    fi
    
    echo "✅ Проверка завершена"
}

# Основная логика
case "$1" in
    app)
        create_application_backup "$2" "$3"
        ;;
    database)
        create_database_backup "$2" "$3"
        ;;
    config)
        create_config_backup
        ;;
    verify)
        verify_backup_integrity "$2"
        ;;
    *)
        echo "Использование: $0 {app <name> [namespace]|database <type> <name>|config|verify <backup-name>}"
        exit 1
        ;;
esac
```

### 🚨 Disaster Recovery - Восстановление бизнеса

#### 1. **Характеристики DR**
```yaml
# dr-characteristics.yaml
disaster_recovery_characteristics:
  primary_purpose: "Business Continuity"
  
  scope:
    - "Entire infrastructure"
    - "Applications and services"
    - "Network connectivity"
    - "User access"
    - "Business processes"
  
  scenarios:
    - "Data center failure"
    - "Natural disasters"
    - "Cyber attacks"
    - "Hardware failures"
    - "Network outages"
  
  components:
    - "Alternative infrastructure"
    - "Failover procedures"
    - "Communication plans"
    - "Recovery teams"
    - "Testing protocols"
  
  strategies:
    hot_standby:
      description: "Real-time replication"
      rto: "< 1 hour"
      rpo: "< 15 minutes"
      cost: "High"
    
    warm_standby:
      description: "Periodic synchronization"
      rto: "< 4 hours"
      rpo: "< 1 hour"
      cost: "Medium"
    
    cold_standby:
      description: "Backup restoration"
      rto: "< 24 hours"
      rpo: "< 24 hours"
      cost: "Low"
  
  metrics:
    rpo: "5 minutes - 4 hours"
    rto: "15 minutes - 24 hours"
    availability: "99.9% - 99.99%"
    automation: "Critical"
---
# DR план конфигурация
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-plan
  namespace: disaster-recovery
data:
  plan.yaml: |
    disaster_recovery_plan:
      activation_triggers:
        - "Primary site unavailable > 5 minutes"
        - "Critical services down > 10 minutes"
        - "Data corruption detected"
        - "Security breach confirmed"
      
      recovery_procedures:
        phase_1_assessment:
          duration: "5 minutes"
          actions:
            - "Assess incident scope"
            - "Confirm DR site availability"
            - "Notify stakeholders"
        
        phase_2_activation:
          duration: "10 minutes"
          actions:
            - "Activate DR cluster"
            - "Restore from latest backup"
            - "Update DNS records"
        
        phase_3_verification:
          duration: "15 minutes"
          actions:
            - "Test critical services"
            - "Verify data integrity"
            - "Confirm user access"
        
        phase_4_communication:
          duration: "5 minutes"
          actions:
            - "Notify users of recovery"
            - "Update status pages"
            - "Document incident"
```

#### 2. **Скрипт DR операций**
```bash
#!/bin/bash
# dr-operations.sh

echo "🚨 Disaster Recovery операции"

# Переменные
PRIMARY_SITE="fra1"
DR_SITE="ams3"
NOTIFICATION_WEBHOOK="$SLACK_WEBHOOK_URL"

# Оценка инцидента
assess_incident() {
    echo "🔍 Оценка инцидента"
    
    local incident_type=$1
    local severity=$2
    
    # Проверка доступности primary site
    if ! ping -c 3 primary-cluster-endpoint &>/dev/null; then
        echo "❌ Primary site недоступен"
        return 1
    fi
    
    # Проверка критичных сервисов
    critical_services=("api" "database" "auth")
    failed_services=0
    
    for service in "${critical_services[@]}"; do
        if ! curl -f -s "https://${service}.hashfoundry.com/health" &>/dev/null; then
            echo "❌ Сервис $service недоступен"
            ((failed_services++))
        fi
    done
    
    if [ $failed_services -gt 1 ]; then
        echo "🚨 Критичные сервисы недоступны: $failed_services"
        return 1
    fi
    
    echo "✅ Инцидент оценен"
    return 0
}

# Активация DR
activate_dr() {
    echo "🚨 Активация Disaster Recovery"
    
    # Уведомление о начале DR
    send_notification "🚨 DR ACTIVATION: Starting disaster recovery procedures"
    
    # Переключение на DR кластер
    kubectl config use-context do-${DR_SITE}-hashfoundry-dr
    
    # Масштабирование DR кластера
    scale_dr_infrastructure
    
    # Восстановление сервисов
    restore_services
    
    # Переключение трафика
    switch_traffic_to_dr
    
    # Проверка работоспособности
    verify_dr_services
    
    send_notification "✅ DR ACTIVATION: Disaster recovery completed successfully"
}

# Масштабирование DR инфраструктуры
scale_dr_infrastructure() {
    echo "📈 Масштабирование DR инфраструктуры"
    
    # Увеличение узлов кластера
    doctl kubernetes cluster node-pool update hashfoundry-dr dr-worker-pool \
        --count 6 \
        --auto-scale \
        --min-nodes 3 \
        --max-nodes 12
    
    # Ожидание готовности узлов
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Масштабирование системных компонентов
    kubectl scale deployment -n kube-system coredns --replicas=3
    kubectl scale deployment -n kube-system metrics-server --replicas=2
    
    echo "✅ DR инфраструктура масштабирована"
}

# Восстановление сервисов
restore_services() {
    echo "🔄 Восстановление сервисов"
    
    # Восстановление из backup
    latest_backup=$(velero backup get -o json | \
        jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
    
    if [ "$latest_backup" != "null" ]; then
        echo "📦 Восстановление из backup: $latest_backup"
        velero restore create dr-restore-$(date +%s) \
            --from-backup $latest_backup \
            --wait
    fi
    
    # Применение критичных конфигураций
    kubectl apply -f /dr-configs/critical-services.yaml
    
    # Ожидание готовности сервисов
    kubectl wait --for=condition=available deployment --all --timeout=600s
    
    echo "✅ Сервисы восстановлены"
}

# Переключение трафика на DR
switch_traffic_to_dr() {
    echo "🌐 Переключение трафика на DR"
    
    # Получение IP адреса DR load balancer
    DR_LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    # Обновление DNS записей
    domains=("api.hashfoundry.com" "app.hashfoundry.com" "monitoring.hashfoundry.com")
    
    for domain in "${domains[@]}"; do
        doctl compute domain records update hashfoundry.com \
            --record-type A \
            --record-name ${domain%%.*} \
            --record-data $DR_LB_IP \
            --record-ttl 300
        
        echo "✅ DNS обновлен: $domain -> $DR_LB_IP"
    done
}

# Проверка DR сервисов
verify_dr_services() {
    echo "✅ Проверка DR сервисов"
    
    # Проверка кластера
    kubectl cluster-info
    kubectl get nodes
    
    # Проверка критичных подов
    kubectl get pods --all-namespaces | grep -E "(api|database|auth)"
    
    # Тестирование доступности
    test_services=(
        "https://api.hashfoundry.com/health"
        "https://app.hashfoundry.com"
        "https://monitoring.hashfoundry.com"
    )
    
    for service in "${test_services[@]}"; do
        if curl -f -s "$service" &>/dev/null; then
            echo "✅ $service доступен"
        else
            echo "❌ $service недоступен"
        fi
    done
    
    echo "✅ DR сервисы проверены"
}

# Возврат к primary site
failback_to_primary() {
    echo "🔄 Возврат к primary site"
    
    # Проверка готовности primary site
    if ! assess_incident "failback" "low"; then
        echo "❌ Primary site не готов для failback"
        return 1
    fi
    
    # Синхронизация данных
    sync_data_to_primary
    
    # Переключение трафика обратно
    switch_traffic_to_primary
    
    # Масштабирование DR обратно
    scale_down_dr
    
    send_notification "✅ FAILBACK: Successfully returned to primary site"
}

# Синхронизация данных
sync_data_to_primary() {
    echo "🔄 Синхронизация данных с primary"
    
    # Создание backup текущего состояния DR
    velero backup create failback-sync-$(date +%s) \
        --include-namespaces production,staging \
        --wait
    
    # Восстановление в primary кластере
    kubectl config use-context do-${PRIMARY_SITE}-hashfoundry-ha
    velero restore create failback-restore-$(date +%s) \
        --from-backup failback-sync-$(date +%s) \
        --wait
    
    echo "✅ Данные синхронизированы"
}

# Отправка уведомлений
send_notification() {
    local message="$1"
    echo "📢 $message"
    
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\", \"channel\":\"#ops-alerts\"}" \
            "$NOTIFICATION_WEBHOOK"
    fi
}

# Основная логика
case "$1" in
    assess)
        assess_incident "$2" "$3"
        ;;
    activate)
        activate_dr
        ;;
    verify)
        verify_dr_services
        ;;
    failback)
        failback_to_primary
        ;;
    *)
        echo "Использование: $0 {assess <type> <severity>|activate|verify|failback}"
        exit 1
        ;;
esac
```

### 📊 Сравнительная таблица

#### 1. **Детальное сравнение**
```yaml
# Детальное сравнение Backup vs DR
detailed_comparison:
  purpose:
    backup: "Защита и восстановление данных"
    disaster_recovery: "Обеспечение непрерывности бизнеса"
  
  scope:
    backup:
      - "Файлы и базы данных"
      - "Конфигурации приложений"
      - "Пользовательские данные"
    disaster_recovery:
      - "Вся IT-инфраструктура"
      - "Бизнес-процессы"
      - "Коммуникации"
      - "Персонал и процедуры"
  
  frequency:
    backup:
      - "Ежедневно/еженедельно"
      - "По расписанию"
      - "Автоматически"
    disaster_recovery:
      - "По требованию"
      - "При инцидентах"
      - "Тестирование регулярно"
  
  cost:
    backup:
      - "Низкая-средняя"
      - "Стоимость хранения"
      - "Backup ПО"
    disaster_recovery:
      - "Средняя-высокая"
      - "Дублирование инфраструктуры"
      - "Процедуры и обучение"
  
  complexity:
    backup:
      - "Низкая-средняя"
      - "Настройка расписания"
      - "Мониторинг выполнения"
    disaster_recovery:
      - "Высокая"
      - "Координация команд"
      - "Комплексное планирование"
  
  testing:
    backup:
      - "Восстановление файлов"
      - "Проверка целостности"
      - "Тестирование restore"
    disaster_recovery:
      - "Полное переключение"
      - "Тестирование процедур"
      - "Симуляция катастроф"
```

### 🎯 Интеграция Backup и DR

#### 1. **Совместная стратегия**
```yaml
# Интегрированная стратегия Backup + DR
integrated_strategy:
  data_protection_layers:
    layer_1_backup:
      - "Ежедневные инкрементальные backup"
      - "Еженедельные полные backup"
      - "Мгновенные snapshots"
    
    layer_2_replication:
      - "Синхронная репликация критичных данных"
      - "Асинхронная репликация остальных данных"
      - "Cross-region репликация"
    
    layer_3_dr:
      - "Hot standby для критичных систем"
      - "Warm standby для важных систем"
      - "Cold standby для остальных систем"
  
  recovery_scenarios:
    file_corruption:
      solution: "Backup restore"
      rto: "1-4 hours"
      rpo: "24 hours"
    
    application_failure:
      solution: "Backup + configuration restore"
      rto: "2-8 hours"
      rpo: "4 hours"
    
    site_disaster:
      solution: "DR activation"
      rto: "15 minutes - 4 hours"
      rpo: "5 minutes - 1 hour"
  
  best_practices:
    - "Backup поддерживает DR стратегию"
    - "DR включает backup как компонент"
    - "Регулярное тестирование обеих систем"
    - "Документирование всех процедур"
    - "Обучение команды обеим подходам"
```

#### 2. **Чек-лист интеграции**
```yaml
backup_dr_integration_checklist:
  planning:
    - "✅ Определены RTO/RPO для каждого сервиса"
    - "✅ Выбраны подходящие стратегии backup и DR"
    - "✅ Спланированы бюджеты на обе системы"
    - "✅ Определены роли и ответственности"
  
  implementation:
    - "✅ Настроены автоматические backup"
    - "✅ Развернута DR инфраструктура"
    - "✅ Созданы процедуры восстановления"
    - "✅ Настроен мониторинг обеих систем"
  
  testing:
    - "✅ Регулярно тестируется восстановление из backup"
    - "✅ Проводятся DR учения"
    - "✅ Документируются результаты тестов"
    - "✅ Обновляются процедуры на основе тестов"
  
  maintenance:
    - "✅ Мониторинг производительности backup"
    - "✅ Проверка готовности DR систем"
    - "✅ Обновление документации"
    - "✅ Обучение новых сотрудников"
```

Понимание различий между backup и disaster recovery критически важно для создания комплексной стратегии защиты данных и обеспечения непрерывности бизнеса в Kubernetes среде.
