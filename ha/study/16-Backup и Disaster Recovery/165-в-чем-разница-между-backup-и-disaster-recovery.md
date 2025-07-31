# 165. В чем разница между backup и disaster recovery?

## 🎯 **Что такое Backup и Disaster Recovery?**

**Backup и Disaster Recovery (DR)** — это две взаимосвязанные, но принципиально разные концепции защиты данных и обеспечения непрерывности бизнеса. Backup фокусируется на создании копий данных для защиты от потери, а DR представляет собой комплексную стратегию восстановления всей IT-инфраструктуры после катастрофических сбоев с минимальным временем простоя.

## 🏗️ **Основные различия между Backup и DR:**

### **1. Scope (Область применения)**
- **Backup**: Защита данных, файлов, баз данных
- **DR**: Восстановление всей IT-инфраструктуры и бизнес-процессов

### **2. Objectives (Цели)**
- **Backup**: Предотвращение потери данных, восстановление файлов
- **DR**: Минимизация простоя, обеспечение непрерывности бизнеса

### **3. Implementation (Реализация)**
- **Backup**: Scheduled jobs, storage systems, retention policies
- **DR**: Failover procedures, alternative sites, communication plans

### **4. RTO/RPO**
- **Backup**: RTO: часы/дни, RPO: часы
- **DR**: RTO: минуты/часы, RPO: минуты

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих Backup и DR компонентов:**
```bash
# Проверка Backup компонентов
kubectl get pods -n velero
kubectl get backups -n velero --sort-by=.metadata.creationTimestamp
kubectl get schedules -n velero

# Проверка DR компонентов
kubectl get nodes --show-labels | grep disaster-recovery
kubectl get pods --all-namespaces -l disaster-recovery=enabled

# Анализ storage для backup и DR
kubectl get pv -o custom-columns=NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,SIZE:.spec.capacity.storage,STATUS:.status.phase

# Проверка мониторинга обеих систем
kubectl get events --field-selector type=Warning | grep -E "(backup|restore|failover)"
```

### **2. Мониторинг Backup vs DR метрик:**
```bash
# Backup метрики
velero backup get -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CREATED:.metadata.creationTimestamp,SIZE:.status.totalItems

# DR метрики
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REGION:.metadata.labels.topology\\.kubernetes\\.io/region

# Проверка доступности сервисов
kubectl get ingress --all-namespaces -o custom-columns=NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[*].ip
```

### **3. Тестирование Backup и DR готовности:**
```bash
# Тест backup системы
velero backup create test-backup-$(date +%s) --include-namespaces default --wait

# Тест DR готовности
kubectl config get-contexts | grep -E "(fra1|ams3)"
kubectl cluster-info --context do-ams3-hashfoundry-dr
```

## 🔄 **Демонстрация различий Backup vs DR:**

### **1. Создание комплексного скрипта сравнения:**
```bash
# Создать скрипт backup-vs-dr-comparison.sh
cat << 'EOF' > backup-vs-dr-comparison.sh
#!/bin/bash

echo "📊 Сравнение Backup vs Disaster Recovery"
echo "======================================"

# Настройка переменных
PRIMARY_CLUSTER="hashfoundry-ha"
DR_CLUSTER="hashfoundry-dr"
PRIMARY_REGION="fra1"
DR_REGION="ams3"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция анализа Backup системы
analyze_backup_system() {
    log "💾 Анализ Backup системы"
    
    echo "🔍 Backup компоненты:"
    
    # Проверка Velero
    if kubectl get ns velero >/dev/null 2>&1; then
        echo "✅ Velero установлен"
        
        # Статистика backup
        TOTAL_BACKUPS=$(kubectl get backups -n velero --no-headers | wc -l)
        SUCCESSFUL_BACKUPS=$(kubectl get backups -n velero --no-headers | grep Completed | wc -l)
        FAILED_BACKUPS=$(kubectl get backups -n velero --no-headers | grep Failed | wc -l)
        
        echo "  📦 Всего backup: $TOTAL_BACKUPS"
        echo "  ✅ Успешных: $SUCCESSFUL_BACKUPS"
        echo "  ❌ Неудачных: $FAILED_BACKUPS"
        
        # Последний backup
        LATEST_BACKUP=$(kubectl get backups -n velero --sort-by=.metadata.creationTimestamp -o name | tail -1)
        if [ -n "$LATEST_BACKUP" ]; then
            BACKUP_STATUS=$(kubectl get $LATEST_BACKUP -n velero -o jsonpath='{.status.phase}')
            BACKUP_TIME=$(kubectl get $LATEST_BACKUP -n velero -o jsonpath='{.metadata.creationTimestamp}')
            echo "  🕐 Последний backup: $BACKUP_TIME ($BACKUP_STATUS)"
        fi
        
        # Размер backup storage
        BACKUP_LOCATION=$(velero backup-location get -o json 2>/dev/null | jq -r '.items[0].spec.objectStorage.bucket' 2>/dev/null)
        echo "  🗄️ Backup location: $BACKUP_LOCATION"
        
    else
        echo "❌ Velero не установлен"
    fi
    
    # Проверка scheduled backup
    echo -e "\n📅 Scheduled Backup:"
    kubectl get schedules -n velero -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST-BACKUP:.status.lastBackup 2>/dev/null || echo "Нет scheduled backup"
    
    # Backup характеристики
    echo -e "\n📋 Backup характеристики:"
    echo "  🎯 Цель: Защита данных"
    echo "  📏 Область: Файлы, БД, конфигурации"
    echo "  ⏰ Частота: По расписанию (ежедневно/еженедельно)"
    echo "  🔄 RTO: 1-8 часов"
    echo "  📊 RPO: 1-24 часа"
    echo "  💰 Стоимость: Низкая-средняя"
    echo "  🔧 Сложность: Низкая-средняя"
}

# Функция анализа DR системы
analyze_dr_system() {
    log "🚨 Анализ Disaster Recovery системы"
    
    echo "🔍 DR компоненты:"
    
    # Проверка DR кластера
    if kubectl config get-contexts | grep -q "$DR_CLUSTER"; then
        echo "✅ DR кластер настроен"
        
        # Переключение на DR кластер
        kubectl config use-context do-$DR_REGION-$DR_CLUSTER >/dev/null 2>&1
        
        # Статистика DR кластера
        DR_NODES=$(kubectl get nodes --no-headers | wc -l)
        DR_READY_NODES=$(kubectl get nodes --no-headers | grep Ready | wc -l)
        DR_PODS=$(kubectl get pods --all-namespaces --no-headers | wc -l)
        DR_RUNNING_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)
        
        echo "  🏗️ DR узлов: $DR_NODES (готовых: $DR_READY_NODES)"
        echo "  📦 DR подов: $DR_PODS (запущенных: $DR_RUNNING_PODS)"
        
        # Проверка DR tolerations
        DR_TOLERATIONS=$(kubectl get nodes -o jsonpath='{.items[*].spec.taints[?(@.key=="disaster-recovery")].key}' | wc -w)
        echo "  🏷️ DR taints: $DR_TOLERATIONS узлов"
        
        # Проверка Load Balancer
        DR_LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$DR_LB_IP" ]; then
            echo "  🌐 DR Load Balancer: $DR_LB_IP"
        else
            echo "  ⚠️ DR Load Balancer не готов"
        fi
        
        # Переключение обратно на primary
        kubectl config use-context do-$PRIMARY_REGION-$PRIMARY_CLUSTER >/dev/null 2>&1
        
    else
        echo "❌ DR кластер не настроен"
    fi
    
    # DR характеристики
    echo -e "\n📋 DR характеристики:"
    echo "  🎯 Цель: Непрерывность бизнеса"
    echo "  📏 Область: Вся IT-инфраструктура"
    echo "  ⏰ Частота: По требованию (при инцидентах)"
    echo "  🔄 RTO: 15 минут - 4 часа"
    echo "  📊 RPO: 5 минут - 1 час"
    echo "  💰 Стоимость: Средняя-высокая"
    echo "  🔧 Сложность: Высокая"
}

# Функция сравнения сценариев восстановления
compare_recovery_scenarios() {
    log "🔄 Сравнение сценариев восстановления"
    
    echo "📋 Сценарии восстановления:"
    echo ""
    echo "1️⃣ Случайное удаление файла:"
    echo "   Backup: ✅ Восстановление из backup (1-4 часа)"
    echo "   DR: ❌ Избыточно для данного сценария"
    echo ""
    echo "2️⃣ Повреждение базы данных:"
    echo "   Backup: ✅ Восстановление БД из backup (2-8 часов)"
    echo "   DR: ⚠️ Возможно, но избыточно"
    echo ""
    echo "3️⃣ Сбой приложения:"
    echo "   Backup: ✅ Восстановление конфигурации (1-6 часов)"
    echo "   DR: ✅ Переключение на DR кластер (15-60 минут)"
    echo ""
    echo "4️⃣ Отказ узла кластера:"
    echo "   Backup: ❌ Не подходит для данного сценария"
    echo "   DR: ✅ Автоматическое переключение (5-30 минут)"
    echo ""
    echo "5️⃣ Катастрофа дата-центра:"
    echo "   Backup: ⚠️ Медленное восстановление (4-24 часа)"
    echo "   DR: ✅ Быстрое переключение (15 минут - 4 часа)"
    echo ""
    echo "6️⃣ Кибератака/ransomware:"
    echo "   Backup: ✅ Восстановление чистых данных (2-12 часов)"
    echo "   DR: ✅ Изоляция и переключение (30 минут - 2 часа)"
}

# Функция анализа интеграции
analyze_integration() {
    log "🔗 Анализ интеграции Backup и DR"
    
    echo "🤝 Интеграция систем:"
    echo ""
    echo "✅ Backup поддерживает DR:"
    echo "   • Backup данных реплицируется в DR регион"
    echo "   • DR использует backup для восстановления"
    echo "   • Общие storage backend (Digital Ocean Spaces)"
    echo ""
    echo "✅ DR дополняет Backup:"
    echo "   • DR обеспечивает быстрое переключение"
    echo "   • Backup обеспечивает долгосрочное хранение"
    echo "   • Совместное тестирование процедур"
    echo ""
    echo "📊 Совместные метрики:"
    
    # Проверка общих компонентов
    SHARED_STORAGE=$(kubectl get pv | grep -c "do-block-storage")
    MONITORING_PODS=$(kubectl get pods -n monitoring --no-headers | wc -l)
    
    echo "   • Общих storage volumes: $SHARED_STORAGE"
    echo "   • Мониторинг подов: $MONITORING_PODS"
    echo "   • Общий Prometheus для метрик"
    echo "   • Общий Grafana для визуализации"
}

# Функция рекомендаций
provide_recommendations() {
    log "💡 Рекомендации по использованию"
    
    echo "🎯 Когда использовать Backup:"
    echo "   ✅ Ежедневная защита данных"
    echo "   ✅ Восстановление отдельных файлов"
    echo "   ✅ Защита от ошибок пользователей"
    echo "   ✅ Соответствие политикам хранения"
    echo "   ✅ Долгосрочное архивирование"
    echo ""
    echo "🚨 Когда использовать DR:"
    echo "   ✅ Критичные бизнес-приложения"
    echo "   ✅ Высокие требования к доступности"
    echo "   ✅ Минимальные RTO/RPO"
    echo "   ✅ Защита от катастроф"
    echo "   ✅ Соответствие SLA"
    echo ""
    echo "🤝 Совместное использование:"
    echo "   ✅ Многоуровневая защита"
    echo "   ✅ Разные сценарии восстановления"
    echo "   ✅ Оптимизация затрат"
    echo "   ✅ Комплексная стратегия"
    echo ""
    echo "💰 Оптимизация затрат:"
    echo "   • Backup: Для большинства данных"
    echo "   • DR: Только для критичных сервисов"
    echo "   • Tier-based подход к защите"
    echo "   • Автоматизация процессов"
}

# Функция создания отчета
generate_report() {
    log "📄 Создание отчета сравнения"
    
    REPORT_FILE="/tmp/backup-vs-dr-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "BACKUP VS DISASTER RECOVERY COMPARISON REPORT"
        echo "============================================="
        echo "Generated: $(date)"
        echo "Cluster: $PRIMARY_CLUSTER"
        echo ""
        
        # Backup статистика
        echo "BACKUP SYSTEM STATUS:"
        kubectl get backups -n velero --no-headers 2>/dev/null | \
            awk '{print $2}' | sort | uniq -c || echo "No backup data"
        echo ""
        
        # DR статистика
        echo "DR SYSTEM STATUS:"
        kubectl config get-contexts | grep -E "(fra1|ams3)" || echo "No DR contexts"
        echo ""
        
        # Рекомендации
        echo "RECOMMENDATIONS:"
        echo "1. Implement both backup and DR for comprehensive protection"
        echo "2. Use backup for daily data protection"
        echo "3. Use DR for business continuity"
        echo "4. Regular testing of both systems"
        echo "5. Document all procedures"
        
    } > "$REPORT_FILE"
    
    echo "📄 Отчет сохранен: $REPORT_FILE"
}

# Основная логика выполнения
main() {
    log "🚀 Запуск сравнения Backup vs DR"
    
    analyze_backup_system
    echo ""
    analyze_dr_system
    echo ""
    compare_recovery_scenarios
    echo ""
    analyze_integration
    echo ""
    provide_recommendations
    echo ""
    generate_report
    
    log "🎉 СРАВНЕНИЕ ЗАВЕРШЕНО!"
    log "📋 Ключевые выводы:"
    log "  • Backup и DR решают разные задачи"
    log "  • Backup: защита данных, DR: непрерывность бизнеса"
    log "  • Совместное использование обеспечивает полную защиту"
    log "  • Выбор зависит от требований RTO/RPO"
}

# Обработка ошибок
trap 'log "❌ Ошибка при сравнении"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x backup-vs-dr-comparison.sh
```

### **2. Создание практических сценариев:**
```bash
# Создать скрипт scenario-testing.sh
cat << 'EOF' > scenario-testing.sh
#!/bin/bash

echo "🧪 Тестирование сценариев Backup vs DR"
echo "===================================="

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Сценарий 1: Случайное удаление файла (Backup решение)
test_file_deletion_scenario() {
    log "📁 Тестирование сценария: Случайное удаление файла"
    
    echo "🎯 Сценарий: Пользователь случайно удалил важный ConfigMap"
    echo "💡 Решение: Восстановление из backup"
    
    # Создание тестового ConfigMap
    kubectl apply -f - << CONFIG_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: important-config
  namespace: default
  labels:
    backup-test: "true"
data:
  config.yaml: |
    app:
      name: "Important Application"
      version: "1.0.0"
      database:
        host: "db.example.com"
        port: "5432"
CONFIG_EOF
    
    echo "✅ Создан тестовый ConfigMap"
    
    # Создание backup
    velero backup create file-deletion-test-$(date +%s) \
        --include-namespaces default \
        --selector backup-test=true \
        --wait
    
    echo "✅ Backup создан"
    
    # Симуляция удаления
    kubectl delete configmap important-config
    echo "❌ ConfigMap удален (симуляция ошибки пользователя)"
    
    # Восстановление из backup
    BACKUP_NAME=$(velero backup get -o name | grep file-deletion-test | head -1)
    velero restore create file-deletion-restore-$(date +%s) \
        --from-backup ${BACKUP_NAME##*/} \
        --wait
    
    # Проверка восстановления
    if kubectl get configmap important-config >/dev/null 2>&1; then
        echo "✅ ConfigMap восстановлен из backup"
        echo "⏰ Время восстановления: ~2-5 минут"
        echo "💰 Стоимость: Низкая (только backup storage)"
    else
        echo "❌ Восстановление не удалось"
    fi
    
    # Очистка
    kubectl delete configmap important-config --ignore-not-found
    velero backup delete ${BACKUP_NAME##*/} --confirm >/dev/null 2>&1
}

# Сценарий 2: Отказ кластера (DR решение)
test_cluster_failure_scenario() {
    log "🏗️ Тестирование сценария: Отказ кластера"
    
    echo "🎯 Сценарий: Primary кластер недоступен"
    echo "💡 Решение: Переключение на DR кластер"
    
    # Проверка доступности primary кластера
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Primary кластер доступен"
        
        # Создание тестового приложения
        kubectl apply -f - << APP_EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: default
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
APP_EOF
        
        echo "✅ Тестовое приложение развернуто в primary кластере"
        
        # Создание backup приложения
        velero backup create cluster-failure-test-$(date +%s) \
            --include-namespaces default \
            --selector app=test-app \
            --wait
        
        echo "✅ Backup приложения создан"
        
        # Симуляция переключения на DR кластер
        if kubectl config get-contexts | grep -q "hashfoundry-dr"; then
            echo "🔄 Переключение на DR кластер..."
            kubectl config use-context do-ams3-hashfoundry-dr
            
            # Восстановление приложения в DR кластере
            BACKUP_NAME=$(velero backup get -o name | grep cluster-failure-test | head -1)
            velero restore create cluster-failure-restore-$(date +%s) \
                --from-backup ${BACKUP_NAME##*/} \
                --wait
            
            # Проверка восстановления
            if kubectl get deployment test-app >/dev/null 2>&1; then
                echo "✅ Приложение восстановлено в DR кластере"
                echo "⏰ Время переключения: ~5-15 минут"
                echo "💰 Стоимость: Высокая (дублирование инфраструктуры)"
                
                # Проверка доступности
                kubectl wait --for=condition=available deployment/test-app --timeout=300s
                echo "✅ Приложение готово к работе"
            else
                echo "❌ Восстановление в DR кластере не удалось"
            fi
            
            # Возврат к primary кластеру
            kubectl config use-context do-fra1-hashfoundry-ha
            echo "🔄 Возврат к primary кластеру"
        else
            echo "⚠️ DR кластер не настроен"
        fi
        
        # Очистка
        kubectl delete deployment test-app --ignore-not-found
        kubectl delete service test-app --ignore-not-found
    else
        echo "❌ Primary кластер недоступен"
    fi
}

# Сценарий 3: Повреждение данных (Backup решение)
test_data_corruption_scenario() {
    log "💾 Тестирование сценария: Повреждение данных"
    
    echo "🎯 Сценарий: Повреждение данных в базе данных"
    echo "💡 Решение: Восстановление из backup"
    
    # Создание тестовой "базы данных" (ConfigMap с данными)
    kubectl apply -f - << DB_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-database
  namespace: default
  labels:
    component: database
data:
  users.json: |
    {
      "users": [
        {"id": 1, "name": "Alice", "email": "alice@example.com"},
        {"id": 2, "name": "Bob", "email": "bob@example.com"},
        {"id": 3, "name": "Charlie", "email": "charlie@example.com"}
      ]
    }
  products.json: |
    {
      "products": [
        {"id": 1, "name": "Product A", "price": 100},
        {"id": 2, "name": "Product B", "price": 200}
      ]
    }
DB_EOF
    
    echo "✅ Тестовая база данных создана"
    
    # Создание backup
    velero backup create data-corruption-test-$(date +%s) \
        --include-namespaces default \
        --selector component=database \
        --wait
    
    echo "✅ Backup данных создан"
    
    # Симуляция повреждения данных
    kubectl patch configmap test-database --patch='{"data":{"users.json":"CORRUPTED DATA","products.json":"CORRUPTED DATA"}}'
    echo "❌ Данные повреждены (симуляция corruption)"
    
    # Проверка повреждения
    CORRUPTED_DATA=$(kubectl get configmap test-database -o jsonpath='{.data.users\.json}')
    if [[ "$CORRUPTED_DATA" == "CORRUPTED DATA" ]]; then
        echo "⚠️ Подтверждено повреждение данных"
        
        # Восстановление из backup
        kubectl delete configmap test-database
        
        BACKUP_NAME=$(velero backup get -o name | grep data-corruption-test | head -1)
        velero restore create data-corruption-restore-$(date +%s) \
            --from-backup ${BACKUP_NAME##*/} \
            --wait
        
        # Проверка восстановления
        RESTORED_DATA=$(kubectl get configmap test-database -o jsonpath='{.data.users\.json}' 2>/dev/null)
        if [[ "$RESTORED_DATA" == *"Alice"* ]]; then
            echo "✅ Данные восстановлены из backup"
            echo "⏰ Время восстановления: ~3-10 минут"
            echo "📊 RPO: Время последнего backup"
        else
            echo "❌ Восстановление данных не удалось"
        fi
    fi
    
    # Очистка
    kubectl delete configmap test-database --ignore-not-found
}

# Сценарий 4: Сравнение производительности
test_performance_comparison() {
    log "⚡ Сравнение производительности Backup vs DR"
    
    echo "📊 Тестирование производительности:"
    
    # Тест скорости backup
    echo "💾 Тестирование скорости backup..."
    START_TIME=$(date +%s)
    
    # Создание тестовых данных
    for i in {1..10}; do
        kubectl create configmap test-data-$i --from-literal=data="Test data for backup performance test $i"
    done
    
    # Создание backup
    velero backup create performance-test-$(date +%s) \
        --include-namespaces default \
        --selector app.kubernetes.io/name=test-data \
        --wait >/dev/null 2>&1
    
    BACKUP_END_TIME=$(date +%s)
    BACKUP_DURATION=$((BACKUP_END_TIME - START_TIME))
    
    echo "✅ Backup завершен за $BACKUP_DURATION секунд"
    
    # Тест скорости restore
    echo "🔄 Тестирование скорости restore..."
    
    # Удаление данных
    for i in {1..10}; do
        kubectl delete configmap test-data-$i --ignore-not-found
    done
    
    RESTORE_START_TIME=$(date +%s)
    
    # Восстановление
    BACKUP_NAME=$(velero backup get -o name | grep performance-test | head -1)
    velero restore create performance-restore-$(date +%s) \
        --from-backup ${BACKUP_NAME##*/} \
        --wait >/dev/null 2>&1
    
    RESTORE_END_TIME=$(date +%s)
    RESTORE_DURATION=$((RESTORE_END_TIME - RESTORE_START_TIME))
    
    echo "✅ Restore завершен за $RESTORE_DURATION секунд"
    
    # Сравнение с DR (симуляция)
    echo "🚨 Симуляция DR переключения..."
    DR_START_TIME=$(date +%s)
    
    # Симуляция времени переключения DNS и активации сервисов
    sleep 5  # Симуляция DNS propagation
    sleep 10 # Симуляция service startup
    
    DR_END_TIME=$(date +%s)
    DR_DURATION=$((DR_END_TIME - DR_START_TIME))
    
    echo "✅ DR переключение завершено за $DR_DURATION секунд"
    
    # Сравнение результатов
    echo ""
    echo "📊 РЕЗУЛЬТАТЫ СРАВНЕНИЯ:"
    echo "┌─────────────────┬──────────────┬──────────────┐"
    echo "│ Операция        │ Время (сек)  │ Применимость │"
    echo "├─────────────────┼──────────────┼──────────────┤"
    echo "│ Backup          │ $BACKUP_DURATION         │ Защита данных│"
    echo "│ Restore         │ $RESTORE_DURATION        │ Восстановление│"
    echo "│ DR Failover     │ $DR_DURATION         │ Непрерывность│"
    echo "└─────────────────┴──────────────┴──────────────┘"
    
    # Очистка тестовых данных
    for i in {1..10}; do
        kubectl delete configmap test-data-$i --ignore-not-found
    done
}

# Основная логика выполнения
main() {
    case "$1" in
        file-deletion)
            test_file_deletion_scenario
            ;;
        cluster-failure)
            test_cluster_failure_scenario
            ;;
        data-corruption)
            test_data_corruption_scenario
            ;;
        performance)
            test_performance_comparison
            ;;
        all)
            log "🚀 Запуск всех тестовых сценариев"
            test_file_deletion_scenario
            echo ""
            test_cluster_failure_scenario
            echo ""
            test_data_corruption_scenario
            echo ""
            test_performance_comparison
            ;;
        *)
            echo "Использование: $0 {file-deletion|cluster-failure|data-corruption|performance|all}"
            echo "  file-deletion   - Тест восстановления удаленного файла"
            echo "  cluster-failure - Тест переключения на DR кластер"
            echo "  data-corruption - Тест восстановления поврежденных данных"
            echo "  performance     - Сравнение производительности"
            echo "  all            - Запуск всех тестов"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка при тестировании сценариев"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x scenario-testing.sh
```

## 📊 **Архитектура интеграции Backup и DR:**

```
┌─────────────────────────────────────────────────────────────┐
│            Integrated Backup & DR Architecture             │
├─────────────────────────────────────────────────────────────┤
│  Data Protection Layers                                    │
│  ┌─────────────────────┐    ┌─────────────────────┐         │
│  │    BACKUP LAYER     │    │      DR LAYER       │         │
│  │                     │    │                     │         │
│  │  📦 Daily Backups   │◄──►│  🚨 Hot Standby     │         │
│  │  📅 Scheduled Jobs  │    │  🔄 Auto Failover   │         │
│  │  🗄️ Long-term Store │    │  🌐 DNS Switching   │         │
│  │  🔍 Point-in-time   │    │  ⚡ Fast Recovery    │         │
│  └─────────────────────┘    └─────────────────────┘         │
│           │                              │                  │
│           ▼                              ▼                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Shared Components                          │ │
│  │  🗄️ Digital Ocean Spaces (Backup Storage)              │ │
│  │  📊 Prometheus (Monitoring)                             │ │
│  │  📈 Grafana (Visualization)                             │ │
│  │  🔔 AlertManager (Notifications)                        │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Recovery Scenarios Matrix                                  │
│  ┌─────────────────────┬─────────────┬─────────────────────┐ │
│  │ Scenario            │ Best Solution│ RTO/RPO            │ │
│  ├─────────────────────┼─────────────┼─────────────────────┤ │
│  │ File Deletion       │ Backup      │ 1-4h / 24h         │ │
│  │ Data Corruption     │ Backup      │ 2-8h / 4h          │ │
│  │ App Failure         │ Both        │ 15m-6h / 1-4h      │ │
│  │ Node Failure        │ DR          │ 5-30m / 5m         │ │
│  │ Site Disaster       │ DR          │ 15m-4h / 5m-1h     │ │
│  │ Cyber Attack        │ Both        │ 30m-12h / 1-4h     │ │
│  └─────────────────────┴─────────────┴─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Матрица принятия решений:**

### **1. Когда использовать Backup:**
| Сценарий | Backup подходит | Причина |
|----------|----------------|---------|
| Случайное удаление | ✅ Идеально | Точечное восстановление |
| Повреждение данных | ✅ Идеально | Откат к чистой версии |
| Ошибки пользователей | ✅ Идеально | Быстрое восстановление файлов |
| Соответствие политикам | ✅ Идеально | Долгосрочное хранение |
| Архивирование | ✅ Идеально | Низкая стоимость хранения |

### **2. Когда использовать DR:**
| Сценарий | DR подходит | Причина |
|----------|-------------|---------|
| Отказ инфраструктуры | ✅ Идеально | Быстрое переключение |
| Катастрофы | ✅ Идеально | Географическое разделение |
| Высокие SLA | ✅ Идеально | Минимальный RTO |
| Критичные приложения | ✅ Идеально | Непрерывность бизнеса |
| Кибератаки | ✅ Хорошо | Изоляция и переключение |

### **3. Команды для мониторинга интеграции:**
```bash
# Создать скрипт integration-monitoring.sh
cat << 'EOF' > integration-monitoring.sh
#!/bin/bash

echo "🔗 Мониторинг интеграции Backup и DR"
echo "=================================="

# Функция проверки общих компонентов
check_shared_components() {
    echo "🤝 Проверка общих компонентов:"
    
    # Общее хранилище
    SHARED_STORAGE=$(kubectl get pv | grep -c "do-block-storage")
    echo "  🗄️ Общих storage volumes: $SHARED_STORAGE"
    
    # Общий мониторинг
    PROMETHEUS_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers | wc -l)
    GRAFANA_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers | wc -l)
    echo "  📊 Prometheus pods: $PROMETHEUS_PODS"
    echo "  📈 Grafana pods: $GRAFANA_PODS"
    
    # Общие алерты
    BACKUP_ALERTS=$(kubectl get prometheusrules -n monitoring -o yaml | grep -c "backup\|velero" || echo "0")
    DR_ALERTS=$(kubectl get prometheusrules -n monitoring -o yaml | grep -c "disaster\|failover" || echo "0")
    echo "  🔔 Backup alerts: $BACKUP_ALERTS"
    echo "  🚨 DR alerts: $DR_ALERTS"
}

# Функция проверки синхронизации
check_synchronization() {
    echo -e "\n🔄 Проверка синхронизации:"
    
    # Последний backup
    LATEST_BACKUP=$(velero backup get --sort-by=.metadata.creationTimestamp -o name | tail -1)
    if [ -n "$LATEST_BACKUP" ]; then
        BACKUP_TIME=$(kubectl get $LATEST_BACKUP -n velero -o jsonpath='{.metadata.creationTimestamp}')
        BACKUP_AGE=$(( $(date +%s) - $(date -d "$BACKUP_TIME" +%s) ))
        echo "  📦 Последний backup: $((BACKUP_AGE / 60)) минут назад"
        
        if [ $BACKUP_AGE -lt 3600 ]; then
            echo "  ✅ Backup актуален"
        else
            echo "  ⚠️ Backup устарел"
        fi
    fi
    
    # Состояние DR кластера
    if kubectl config get-contexts | grep -q "hashfoundry-dr"; then
        kubectl config use-context do-ams3-hashfoundry-dr >/dev/null 2>&1
        DR_NODES=$(kubectl get nodes --no-headers | grep Ready | wc -l)
        echo "  🏗️ DR узлов готово: $DR_NODES"
        kubectl config use-context do-fra1-hashfoundry-ha >/dev/null 2>&1
    fi
}

# Функция анализа покрытия
analyze_coverage() {
    echo -e "\n📋 Анализ покрытия защиты:"
    
    # Namespace с backup
    BACKUP_NAMESPACES=$(kubectl get schedules -n velero -o yaml | grep -o "includedNamespaces:.*" | wc -l)
    echo "  📦 Namespace с backup: $BACKUP_NAMESPACES"
    
    # Критичные приложения
    CRITICAL_APPS=$(kubectl get deployments --all-namespaces -l tier=critical --no-headers | wc -l)
    echo "  🎯 Критичных приложений: $CRITICAL_APPS"
    
    # Покрытие мониторингом
    MONITORED_SERVICES=$(kubectl get servicemonitors --all-namespaces --no-headers | wc -l)
    echo "  📊 Мониторируемых сервисов: $MONITORED_SERVICES"
}

# Основная функция
main() {
    echo "🚀 ЗАПУСК МОНИТОРИНГА ИНТЕГРАЦИИ"
    echo "==============================="
    
    check_shared_components
    check_synchronization
    analyze_coverage
    
    echo -e "\n💡 РЕКОМЕНДАЦИИ:"
    echo "1. Регулярно проверяйте синхронизацию backup и DR"
    echo "2. Тестируйте оба решения совместно"
    echo "3. Мониторьте общие компоненты"
    echo "4. Обновляйте процедуры на основе тестов"
    
    echo -e "\n✅ МОНИТОРИНГ ЗАВЕРШЕН!"
}

# Запуск мониторинга
main
EOF

chmod +x integration-monitoring.sh
```

## 🎯 **Best Practices для интеграции Backup и DR:**

### **1. Стратегическое планирование**
- Определите RTO/RPO для каждого сервиса
- Классифицируйте приложения по критичности
- Выберите подходящую стратегию для каждого tier
- Планируйте бюджет на обе системы

### **2. Техническая реализация**
- Используйте общие storage backend
- Интегрируйте мониторинг обеих систем
- Автоматизируйте процессы backup и DR
- Настройте cross-region репликацию

### **3. Операционные процедуры**
- Создайте детальные runbooks
- Обучите команду обеим системам
- Регулярно тестируйте процедуры
- Документируйте все изменения

### **4. Мониторинг и улучшение**
- Отслеживайте метрики обеих систем
- Анализируйте результаты тестов
- Оптимизируйте процессы
- Обновляйте стратегии

**Понимание различий между Backup и Disaster Recovery и их правильная интеграция обеспечивает комплексную защиту данных и непрерывность бизнеса в Kubernetes среде!**
