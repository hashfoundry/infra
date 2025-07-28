# 164. Как реализовать стратегии disaster recovery?

## 🎯 Вопрос
Как реализовать стратегии disaster recovery?

## 💡 Ответ

Disaster Recovery (DR) в Kubernetes включает комплексную стратегию восстановления после катастрофических сбоев, охватывающую backup данных, репликацию кластеров, автоматизацию восстановления и тестирование процедур для обеспечения минимального RTO и RPO.

### 🏗️ Архитектура Disaster Recovery

#### 1. **Схема DR стратегии**
```
┌─────────────────────────────────────────────────────────────┐
│                Disaster Recovery Strategy                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Primary    │  │  Secondary  │  │   Backup    │         │
│  │  Cluster    │  │   Cluster   │  │  Storage    │         │
│  │   (fra1)    │  │   (ams3)    │  │  (Spaces)   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Monitoring  │  │ Automation  │  │  Testing    │         │
│  │ & Alerting  │  │ & Failover  │  │ & Validation│         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **DR метрики и цели**
```yaml
# DR метрики и цели
disaster_recovery_metrics:
  rto_targets:
    critical_services: "< 15 минут"
    important_services: "< 1 час"
    standard_services: "< 4 часа"
    
  rpo_targets:
    critical_data: "< 5 минут"
    important_data: "< 30 минут"
    standard_data: "< 4 часа"
    
  availability_targets:
    tier_1: "99.99% (52 минуты downtime/год)"
    tier_2: "99.9% (8.7 часов downtime/год)"
    tier_3: "99% (3.65 дня downtime/год)"
```

### 📊 Примеры из нашего кластера

#### Проверка DR готовности:
```bash
# Проверка состояния кластера
kubectl cluster-info

# Проверка критичных компонентов
kubectl get nodes -o wide
kubectl get pods -n kube-system

# Проверка backup систем
kubectl get pods -n velero
kubectl get backups -n velero
```

### 🌐 Multi-Region DR стратегия

#### 1. **Настройка вторичного кластера**
```yaml
# secondary-cluster-config.yaml
# Terraform конфигурация для вторичного кластера
resource "digitalocean_kubernetes_cluster" "secondary" {
  name    = "hashfoundry-dr"
  region  = "ams3"                       # Другой регион для DR
  version = "1.31.9-do.2"
  
  node_pool {
    name       = "dr-worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 2                       # Меньше узлов для экономии
    
    auto_scale = true
    min_nodes  = 2
    max_nodes  = 6
  }
  
  tags = ["disaster-recovery", "secondary"]
}

# VPC для изоляции DR кластера
resource "digitalocean_vpc" "dr_vpc" {
  name     = "hashfoundry-dr-vpc"
  region   = "ams3"
  ip_range = "10.20.0.0/16"
}
---
# ArgoCD конфигурация для DR кластера
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dr-cluster-sync
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/infra.git
    targetRevision: main
    path: ha/k8s
  destination:
    server: https://dr-cluster-api-endpoint
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### 2. **Скрипт настройки DR кластера**
```bash
#!/bin/bash
# dr-cluster-setup.sh

echo "🌐 Настройка DR кластера"

# Переменные
PRIMARY_CLUSTER="hashfoundry-ha"
DR_CLUSTER="hashfoundry-dr"
DR_REGION="ams3"

# Создание DR кластера
setup_dr_cluster() {
    echo "🏗️ Создание DR кластера..."
    
    # Применение Terraform конфигурации
    cd terraform/
    terraform plan -var="cluster_name=$DR_CLUSTER" -var="region=$DR_REGION"
    terraform apply -auto-approve
    
    # Получение kubeconfig для DR кластера
    doctl kubernetes cluster kubeconfig save $DR_CLUSTER
    
    echo "✅ DR кластер создан"
}

# Настройка репликации
setup_replication() {
    echo "🔄 Настройка репликации..."
    
    # Установка Velero в DR кластер
    kubectl config use-context do-ams3-$DR_CLUSTER
    
    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.8.1 \
        --bucket hashfoundry-backup \
        --secret-file ./credentials-velero \
        --backup-location-config region=ams3,s3ForcePathStyle="true",s3Url=https://ams3.digitaloceanspaces.com
    
    echo "✅ Репликация настроена"
}

# Синхронизация конфигураций
sync_configurations() {
    echo "⚙️ Синхронизация конфигураций..."
    
    # Копирование критичных ConfigMaps и Secrets
    kubectl config use-context do-fra1-$PRIMARY_CLUSTER
    kubectl get configmaps --all-namespaces -o yaml > primary-configmaps.yaml
    kubectl get secrets --all-namespaces -o yaml > primary-secrets.yaml
    
    # Применение в DR кластере
    kubectl config use-context do-ams3-$DR_CLUSTER
    kubectl apply -f primary-configmaps.yaml
    kubectl apply -f primary-secrets.yaml
    
    echo "✅ Конфигурации синхронизированы"
}

# Тестирование DR
test_dr_cluster() {
    echo "🧪 Тестирование DR кластера..."
    
    kubectl config use-context do-ams3-$DR_CLUSTER
    
    # Проверка доступности узлов
    kubectl get nodes
    
    # Тестовое развертывание
    kubectl run dr-test --image=nginx --port=80
    kubectl expose pod dr-test --type=LoadBalancer --port=80
    
    echo "✅ DR кластер протестирован"
}

# Основная логика
case "$1" in
    setup)
        setup_dr_cluster
        ;;
    replication)
        setup_replication
        ;;
    sync)
        sync_configurations
        ;;
    test)
        test_dr_cluster
        ;;
    all)
        setup_dr_cluster
        setup_replication
        sync_configurations
        test_dr_cluster
        ;;
    *)
        echo "Использование: $0 {setup|replication|sync|test|all}"
        exit 1
        ;;
esac
```

### 🔄 Автоматизация Failover

#### 1. **Мониторинг и автоматический failover**
```yaml
# dr-monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-monitoring-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
    - "/etc/prometheus/rules/*.yml"
    
    scrape_configs:
    - job_name: 'kubernetes-cluster-health'
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: kubernetes
    
    - job_name: 'dr-cluster-health'
      static_configs:
      - targets: ['dr-cluster-endpoint:443']
      metrics_path: /healthz
      scheme: https
---
# DR алерты
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: disaster-recovery-alerts
  namespace: monitoring
spec:
  groups:
  - name: disaster-recovery
    rules:
    - alert: PrimaryClusterDown
      expr: up{job="kubernetes-cluster-health"} == 0
      for: 5m
      labels:
        severity: critical
        component: cluster
      annotations:
        summary: "Primary cluster is down"
        description: "Primary Kubernetes cluster has been down for more than 5 minutes"
        runbook_url: "https://docs.hashfoundry.com/runbooks/cluster-failover"
    
    - alert: EtcdClusterUnhealthy
      expr: etcd_server_has_leader == 0
      for: 2m
      labels:
        severity: critical
        component: etcd
      annotations:
        summary: "etcd cluster is unhealthy"
        description: "etcd cluster has no leader for more than 2 minutes"
    
    - alert: HighPodFailureRate
      expr: rate(kube_pod_container_status_restarts_total[5m]) > 0.1
      for: 10m
      labels:
        severity: warning
        component: pods
      annotations:
        summary: "High pod failure rate detected"
        description: "Pod restart rate is {{ $value }} per second"
---
# Webhook для автоматического failover
apiVersion: v1
kind: ConfigMap
metadata:
  name: failover-webhook
  namespace: monitoring
data:
  webhook.py: |
    #!/usr/bin/env python3
    import json
    import subprocess
    import requests
    from flask import Flask, request
    
    app = Flask(__name__)
    
    @app.route('/webhook', methods=['POST'])
    def handle_alert():
        alert_data = request.get_json()
        
        for alert in alert_data.get('alerts', []):
            if alert['labels'].get('alertname') == 'PrimaryClusterDown':
                trigger_failover()
        
        return 'OK'
    
    def trigger_failover():
        print("🚨 Triggering automatic failover...")
        
        # Переключение DNS на DR кластер
        subprocess.run([
            'doctl', 'compute', 'domain', 'records', 'update',
            'hashfoundry.com', '--record-type', 'A',
            '--record-name', 'api', '--record-data', 'DR_CLUSTER_IP'
        ])
        
        # Уведомление команды
        send_notification("Primary cluster failed. Automatic failover initiated.")
    
    def send_notification(message):
        # Slack/Teams уведомление
        webhook_url = "SLACK_WEBHOOK_URL"
        payload = {"text": f"🚨 DR Alert: {message}"}
        requests.post(webhook_url, json=payload)
    
    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=5000)
```

#### 2. **Скрипт автоматизации failover**
```bash
#!/bin/bash
# automated-failover.sh

echo "🚨 Автоматизированный Failover"

# Переменные
PRIMARY_CLUSTER="hashfoundry-ha"
DR_CLUSTER="hashfoundry-dr"
BACKUP_BUCKET="hashfoundry-backup"
NOTIFICATION_WEBHOOK="$SLACK_WEBHOOK_URL"

# Проверка состояния primary кластера
check_primary_health() {
    echo "🔍 Проверка состояния primary кластера..."
    
    kubectl config use-context do-fra1-$PRIMARY_CLUSTER
    
    # Проверка API server
    if ! kubectl cluster-info &>/dev/null; then
        echo "❌ Primary кластер недоступен"
        return 1
    fi
    
    # Проверка etcd
    if ! kubectl get --raw /healthz/etcd &>/dev/null; then
        echo "❌ etcd недоступен"
        return 1
    fi
    
    # Проверка критичных подов
    critical_pods=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running -o name | wc -l)
    if [ "$critical_pods" -gt 3 ]; then
        echo "❌ Слишком много неработающих критичных подов: $critical_pods"
        return 1
    fi
    
    echo "✅ Primary кластер здоров"
    return 0
}

# Инициация failover
initiate_failover() {
    echo "🚨 Инициация failover на DR кластер..."
    
    # Уведомление о начале failover
    send_notification "🚨 DISASTER RECOVERY: Initiating failover to DR cluster"
    
    # Переключение на DR кластер
    kubectl config use-context do-ams3-$DR_CLUSTER
    
    # Восстановление из последнего backup
    restore_from_backup
    
    # Обновление DNS записей
    update_dns_records
    
    # Масштабирование DR кластера
    scale_dr_cluster
    
    # Проверка работоспособности
    verify_dr_cluster
    
    send_notification "✅ DISASTER RECOVERY: Failover completed successfully"
}

# Восстановление из backup
restore_from_backup() {
    echo "🔄 Восстановление из backup..."
    
    # Получение последнего backup
    latest_backup=$(velero backup get -o json | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
    
    if [ "$latest_backup" != "null" ]; then
        echo "📦 Восстановление из backup: $latest_backup"
        velero restore create dr-restore-$(date +%s) --from-backup $latest_backup
        
        # Ожидание завершения восстановления
        kubectl wait --for=condition=Completed restore/dr-restore-$(date +%s) --timeout=600s
    else
        echo "⚠️ Backup не найден, развертывание с нуля"
        deploy_from_scratch
    fi
}

# Обновление DNS записей
update_dns_records() {
    echo "🌐 Обновление DNS записей..."
    
    # Получение внешнего IP DR кластера
    DR_EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    # Обновление A записи
    doctl compute domain records update hashfoundry.com \
        --record-type A \
        --record-name api \
        --record-data $DR_EXTERNAL_IP \
        --record-ttl 300
    
    echo "✅ DNS обновлен: api.hashfoundry.com -> $DR_EXTERNAL_IP"
}

# Масштабирование DR кластера
scale_dr_cluster() {
    echo "📈 Масштабирование DR кластера..."
    
    # Увеличение количества узлов
    doctl kubernetes cluster node-pool update $DR_CLUSTER dr-worker-pool \
        --count 6 \
        --auto-scale \
        --min-nodes 3 \
        --max-nodes 12
    
    # Масштабирование критичных сервисов
    kubectl scale deployment -n kube-system coredns --replicas=3
    kubectl scale deployment -n ingress-nginx ingress-nginx-controller --replicas=3
    
    echo "✅ DR кластер масштабирован"
}

# Проверка работоспособности DR кластера
verify_dr_cluster() {
    echo "✅ Проверка работоспособности DR кластера..."
    
    # Проверка узлов
    ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    echo "Готовых узлов: $ready_nodes"
    
    # Проверка критичных подов
    kubectl get pods -n kube-system
    kubectl get pods -n ingress-nginx
    
    # Тест доступности приложений
    test_application_availability
    
    echo "✅ DR кластер работоспособен"
}

# Тест доступности приложений
test_application_availability() {
    echo "🧪 Тестирование доступности приложений..."
    
    # Список критичных сервисов для проверки
    services=(
        "https://api.hashfoundry.com/health"
        "https://app.hashfoundry.com"
        "https://monitoring.hashfoundry.com"
    )
    
    for service in "${services[@]}"; do
        if curl -f -s "$service" > /dev/null; then
            echo "✅ $service доступен"
        else
            echo "❌ $service недоступен"
        fi
    done
}

# Развертывание с нуля
deploy_from_scratch() {
    echo "🏗️ Развертывание с нуля..."
    
    # Применение базовых манифестов
    kubectl apply -f ../k8s/addons/
    
    # Ожидание готовности базовых сервисов
    kubectl wait --for=condition=ready pod -l app=nginx-ingress --timeout=300s
    kubectl wait --for=condition=ready pod -l app=argocd-server --timeout=300s
}

# Отправка уведомлений
send_notification() {
    local message="$1"
    echo "📢 $message"
    
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$NOTIFICATION_WEBHOOK"
    fi
}

# Основная логика
main() {
    echo "🔍 Запуск DR мониторинга..."
    
    while true; do
        if ! check_primary_health; then
            echo "🚨 Primary кластер недоступен, инициация failover..."
            initiate_failover
            break
        fi
        
        echo "✅ Primary кластер работает нормально"
        sleep 60  # Проверка каждую минуту
    done
}

# Запуск в зависимости от аргумента
case "$1" in
    monitor)
        main
        ;;
    failover)
        initiate_failover
        ;;
    test)
        verify_dr_cluster
        ;;
    *)
        echo "Использование: $0 {monitor|failover|test}"
        exit 1
        ;;
esac
```

### 📋 DR процедуры и runbooks

#### 1. **Runbook для disaster recovery**
```yaml
# dr-runbook.yaml
disaster_recovery_runbook:
  incident_classification:
    p1_critical:
      description: "Полная недоступность primary кластера"
      rto_target: "15 минут"
      escalation: "Немедленно"
      actions:
        - "Активация автоматического failover"
        - "Уведомление всех stakeholders"
        - "Переключение DNS на DR кластер"
    
    p2_major:
      description: "Частичная недоступность критичных сервисов"
      rto_target: "1 час"
      escalation: "В течение 30 минут"
      actions:
        - "Анализ причин сбоя"
        - "Попытка восстановления primary"
        - "Подготовка к failover"
    
    p3_minor:
      description: "Деградация производительности"
      rto_target: "4 часа"
      escalation: "В течение 2 часов"
      actions:
        - "Мониторинг ситуации"
        - "Масштабирование ресурсов"
        - "Планирование maintenance"
  
  recovery_procedures:
    step_1_assessment:
      - "Оценка масштаба инцидента"
      - "Определение затронутых сервисов"
      - "Проверка доступности DR кластера"
    
    step_2_communication:
      - "Уведомление команды DevOps"
      - "Информирование stakeholders"
      - "Создание incident ticket"
    
    step_3_failover:
      - "Выполнение backup критичных данных"
      - "Активация DR кластера"
      - "Переключение трафика"
    
    step_4_verification:
      - "Проверка работоспособности сервисов"
      - "Тестирование критичных функций"
      - "Мониторинг производительности"
    
    step_5_communication:
      - "Уведомление о восстановлении"
      - "Документирование инцидента"
      - "Планирование post-mortem"
```

### 🎯 Лучшие практики DR

#### 1. **Стратегия DR планирования**
```yaml
dr_planning_strategy:
  risk_assessment:
    natural_disasters:
      probability: "Low"
      impact: "High"
      mitigation: "Multi-region deployment"
    
    hardware_failures:
      probability: "Medium"
      impact: "Medium"
      mitigation: "Redundancy and monitoring"
    
    human_errors:
      probability: "High"
      impact: "Medium"
      mitigation: "Automation and procedures"
    
    cyber_attacks:
      probability: "Medium"
      impact: "High"
      mitigation: "Security measures and backups"
  
  recovery_tiers:
    tier_1_critical:
      services: ["API Gateway", "Authentication", "Database"]
      rto: "< 15 minutes"
      rpo: "< 5 minutes"
      strategy: "Hot standby"
    
    tier_2_important:
      services: ["Web Application", "Monitoring", "Logging"]
      rto: "< 1 hour"
      rpo: "< 30 minutes"
      strategy: "Warm standby"
    
    tier_3_standard:
      services: ["Analytics", "Reporting", "Development"]
      rto: "< 4 hours"
      rpo: "< 4 hours"
      strategy: "Cold standby"
```

#### 2. **Чек-лист DR готовности**
```yaml
dr_readiness_checklist:
  infrastructure:
    - "✅ DR кластер развернут и настроен"
    - "✅ Сетевая связность между регионами"
    - "✅ Backup системы работают"
    - "✅ Мониторинг DR компонентов настроен"
  
  procedures:
    - "✅ DR runbooks созданы и актуальны"
    - "✅ Команда обучена процедурам DR"
    - "✅ Контакты для эскалации определены"
    - "✅ Автоматизация failover настроена"
  
  testing:
    - "✅ Регулярные DR тесты проводятся"
    - "✅ Backup восстановление тестируется"
    - "✅ RTO/RPO цели проверяются"
    - "✅ Результаты тестов документируются"
  
  compliance:
    - "✅ Соответствие регуляторным требованиям"
    - "✅ Аудит DR процедур проведен"
    - "✅ Документация актуальна"
    - "✅ Метрики DR отслеживаются"
```

Эффективная стратегия disaster recovery обеспечивает быстрое восстановление сервисов после катастрофических сбоев и минимизирует влияние на бизнес-процессы.
