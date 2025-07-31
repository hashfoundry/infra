# 170. Как реализовать cross-cloud disaster recovery?

## 🎯 **Что такое cross-cloud disaster recovery?**

**Cross-cloud disaster recovery** — это комплексная стратегия обеспечения непрерывности бизнеса через репликацию данных, приложений и инфраструктуры между различными cloud providers, включающая automated failover, multi-cloud backup, network connectivity, configuration synchronization, DNS failover и automated recovery procedures для защиты от отказа целого облачного провайдера.

## 🏗️ **Основные компоненты cross-cloud DR:**

### **1. Multi-Cloud Architecture**
- **Primary Cloud**: Основной cloud provider (AWS, Azure, GCP)
- **Secondary Cloud**: Резервный cloud provider для failover
- **Tertiary Cloud**: Дополнительный cloud для критичных данных
- **Hybrid Connectivity**: VPN, direct connect, SD-WAN между clouds

### **2. Data Replication Layers**
- **Application Data**: Database replication, object storage sync
- **Configuration Data**: Kubernetes manifests, secrets, configmaps
- **Infrastructure State**: Terraform state, cluster configurations
- **Backup Data**: Cross-cloud backup replication и versioning

### **3. Orchestration Components**
- **Failover Automation**: Automated detection и switching
- **DNS Management**: Global load balancing и health checks
- **Network Routing**: Traffic steering и connectivity management
- **Recovery Procedures**: Automated rollback и data consistency

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей cross-cloud готовности:**
```bash
# Проверка текущего cloud provider
kubectl get nodes -o wide | head -5
doctl kubernetes cluster list
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner

# Анализ backup locations
velero backup-location get -o custom-columns=NAME:.metadata.name,PROVIDER:.spec.provider,BUCKET:.spec.objectStorage.bucket,STATUS:.status.phase

# Проверка network connectivity
ping -c 3 8.8.8.8  # Google DNS
ping -c 3 1.1.1.1  # Cloudflare DNS
curl -I https://api.digitalocean.com/v2/account 2>/dev/null | head -1

# Анализ cross-region latency
for region in fra1 ams3 lon1; do
  echo "Testing latency to $region:"
  curl -w "Connect: %{time_connect}s, Total: %{time_total}s\n" -o /dev/null -s https://$region.digitalocean.com/
done
```

### **2. Диагностика cross-cloud проблем:**
```bash
# Проверка DNS failover готовности
dig +short app.hashfoundry.local
nslookup app.hashfoundry.local 8.8.8.8

# Анализ backup replication status
velero backup get -o json | jq -r '.items[] | "\(.metadata.name): \(.spec.storageLocation) (\(.status.phase))"' | tail -10

# Проверка cross-cloud network connectivity
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l k8s-app=kube-dns -o name | head -1) -- nslookup kubernetes.default

# Анализ storage replication
kubectl get pv -o custom-columns=NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,STATUS:.status.phase,CLAIM:.spec.claimRef.name
```

### **3. Мониторинг cross-cloud метрик:**
```bash
# Проверка cluster health across regions
kubectl top nodes | head -5
kubectl get componentstatuses

# Анализ backup distribution
velero backup get -o json | jq -r 'group_by(.spec.storageLocation) | map({location: .[0].spec.storageLocation, count: length}) | .[]'

# Проверка application readiness
kubectl get deployments --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas | grep -v "0/"
```

## 🔄 **Демонстрация comprehensive cross-cloud DR:**

### **1. Создание multi-cloud infrastructure framework:**
```bash
# Создать скрипт cross-cloud-dr-manager.sh
cat << 'EOF' > cross-cloud-dr-manager.sh
#!/bin/bash

echo "🌐 Comprehensive Cross-Cloud Disaster Recovery Manager"
echo "===================================================="

# Настройка переменных
PRIMARY_CLOUD="digitalocean"
SECONDARY_CLOUD="aws"
TERTIARY_CLOUD="azure"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DR_LOG="/var/log/cross-cloud-dr-$TIMESTAMP.log"

# Cloud configurations
declare -A CLOUD_CONFIG=(
    ["digitalocean"]="fra1:hashfoundry-primary"
    ["aws"]="eu-central-1:hashfoundry-secondary"
    ["azure"]="westeurope:hashfoundry-tertiary"
)

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $DR_LOG
}

# Функция анализа multi-cloud readiness
analyze_multi_cloud_readiness() {
    log "🔍 Анализ multi-cloud readiness"
    
    local readiness_report="/tmp/multi-cloud-readiness-$TIMESTAMP.json"
    
    # Comprehensive readiness assessment
    cat > $readiness_report << READINESS_ANALYSIS_EOF
{
  "analysis_timestamp": "$(date -Iseconds)",
  "primary_cluster": "$(kubectl config current-context)",
  "multi_cloud_readiness": {
    "infrastructure_status": {
      "primary_cluster": {
        "provider": "$PRIMARY_CLOUD",
        "region": "$(kubectl get nodes -o json | jq -r '.items[0].metadata.labels["topology.kubernetes.io/region"] // "unknown"')",
        "nodes_ready": $(kubectl get nodes --no-headers | grep Ready | wc -l),
        "nodes_total": $(kubectl get nodes --no-headers | wc -l),
        "api_server_healthy": $(kubectl cluster-info &>/dev/null && echo "true" || echo "false")
      },
      "storage_locations": {
$(velero backup-location get -o json | jq -r '
    .items[] | 
    {
      name: .metadata.name,
      provider: .spec.provider,
      bucket: .spec.objectStorage.bucket,
      region: .spec.config.region // "unknown",
      status: .status.phase
    } | 
    "        \"\(.name)\": {\"provider\": \"\(.provider)\", \"bucket\": \"\(.bucket)\", \"region\": \"\(.region)\", \"status\": \"\(.status)\"}"
' | paste -sd, -)
      }
    },
    "backup_replication": {
      "total_backups": $(velero backup get -o json | jq '.items | length'),
      "backup_distribution": {
$(velero backup get -o json | jq -r '
    group_by(.spec.storageLocation) | 
    map({
      location: .[0].spec.storageLocation,
      count: length,
      latest_backup: ([.[].metadata.creationTimestamp] | max),
      oldest_backup: ([.[].metadata.creationTimestamp] | min)
    })[] | 
    "        \"\(.location)\": {\"count\": \(.count), \"latest\": \"\(.latest_backup)\", \"oldest\": \"\(.oldest_backup)\"}"
' | paste -sd, -)
      }
    },
    "network_connectivity": {
      "dns_resolution": {
        "google_dns": "$(dig +short @8.8.8.8 google.com | head -1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && echo "ok" || echo "failed")",
        "cloudflare_dns": "$(dig +short @1.1.1.1 cloudflare.com | head -1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && echo "ok" || echo "failed")"
      },
      "external_connectivity": {
        "digitalocean_api": "$(curl -s -o /dev/null -w "%{http_code}" https://api.digitalocean.com/v2/account | grep -q "200\|401" && echo "ok" || echo "failed")",
        "aws_api": "$(curl -s -o /dev/null -w "%{http_code}" https://ec2.amazonaws.com/ | grep -q "200\|403" && echo "ok" || echo "failed")",
        "azure_api": "$(curl -s -o /dev/null -w "%{http_code}" https://management.azure.com/ | grep -q "200\|401" && echo "ok" || echo "failed")"
      }
    }
  },
  "readiness_score": {
    "infrastructure": "$(kubectl get nodes --no-headers | grep Ready | wc -l)/$(kubectl get nodes --no-headers | wc -l)",
    "backup_locations": $(velero backup-location get -o json | jq '[.items[] | select(.status.phase == "Available")] | length'),
    "network_health": "$(curl -s -o /dev/null -w "%{http_code}" https://api.digitalocean.com/v2/account | grep -q "200\|401" && echo "healthy" || echo "degraded")"
  }
}
READINESS_ANALYSIS_EOF
    
    log "📄 Multi-cloud readiness analysis: $readiness_report"
    
    # Краткая статистика
    local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    local backup_locations=$(velero backup-location get -o json | jq '.items | length')
    local available_locations=$(velero backup-location get -o json | jq '[.items[] | select(.status.phase == "Available")] | length')
    
    log "🌐 Multi-cloud статистика:"
    log "  🖥️ Готовых узлов: $ready_nodes/$total_nodes"
    log "  💾 Backup locations: $available_locations/$backup_locations доступны"
    log "  ☁️ Primary cloud: $PRIMARY_CLOUD"
    
    return 0
}

# Функция создания cross-cloud backup strategy
create_cross_cloud_backup_strategy() {
    log "📦 Создание cross-cloud backup strategy"
    
    # Создание backup storage locations для разных clouds
    kubectl apply -f - << CROSS_CLOUD_STORAGE_EOF
# DigitalOcean Primary Storage
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: digitalocean-primary
  namespace: velero
  labels:
    cloud-provider: "digitalocean"
    dr-tier: "primary"
spec:
  provider: aws
  objectStorage:
    bucket: hashfoundry-backup-primary
    prefix: digitalocean-primary
  config:
    region: fra1
    s3ForcePathStyle: "true"
    s3Url: https://fra1.digitaloceanspaces.com
  accessMode: ReadWrite
---
# AWS Secondary Storage
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: aws-secondary
  namespace: velero
  labels:
    cloud-provider: "aws"
    dr-tier: "secondary"
spec:
  provider: aws
  objectStorage:
    bucket: hashfoundry-backup-secondary
    prefix: aws-secondary
  config:
    region: eu-central-1
    serverSideEncryption: AES256
  accessMode: ReadWrite
---
# Azure Tertiary Storage
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: azure-tertiary
  namespace: velero
  labels:
    cloud-provider: "azure"
    dr-tier: "tertiary"
spec:
  provider: azure
  objectStorage:
    bucket: hashfoundry-backup-tertiary
    prefix: azure-tertiary
  config:
    resourceGroup: hashfoundry-dr-rg
    storageAccount: hashfoundrydrbackup
    subscriptionId: "your-azure-subscription-id"
  accessMode: ReadWrite
CROSS_CLOUD_STORAGE_EOF
    
    # Создание cross-cloud backup schedules
    kubectl apply -f - << CROSS_CLOUD_SCHEDULES_EOF
# Primary backup schedule
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: cross-cloud-primary-backup
  namespace: velero
  labels:
    backup-tier: "primary"
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    storageLocation: digitalocean-primary
    includedNamespaces:
    - production
    - staging
    - monitoring
    excludedNamespaces:
    - kube-system
    - velero
    labels:
      backup-type: "cross-cloud-primary"
      retention-policy: "30-days"
    ttl: 720h  # 30 days
---
# Secondary backup schedule (replication)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: cross-cloud-secondary-backup
  namespace: velero
  labels:
    backup-tier: "secondary"
spec:
  schedule: "0 4 * * *"  # Daily at 4 AM (2 hours after primary)
  template:
    storageLocation: aws-secondary
    includedNamespaces:
    - production
    - staging
    excludedNamespaces:
    - kube-system
    - velero
    labels:
      backup-type: "cross-cloud-secondary"
      retention-policy: "90-days"
    ttl: 2160h  # 90 days
---
# Tertiary backup schedule (long-term)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: cross-cloud-tertiary-backup
  namespace: velero
  labels:
    backup-tier: "tertiary"
spec:
  schedule: "0 6 0 * *"  # Weekly on Sunday at 6 AM
  template:
    storageLocation: azure-tertiary
    includedNamespaces:
    - production
    excludedNamespaces:
    - kube-system
    - velero
    - staging
    labels:
      backup-type: "cross-cloud-tertiary"
      retention-policy: "1-year"
    ttl: 8760h  # 1 year
CROSS_CLOUD_SCHEDULES_EOF
    
    log "✅ Cross-cloud backup strategy создана"
}

# Функция automated cross-cloud replication
execute_cross_cloud_replication() {
    log "🔄 Выполнение cross-cloud replication"
    
    local replication_count=0
    local failed_replications=0
    
    # Получение последних backup из primary location
    local primary_backups=$(velero backup get -l backup-type=cross-cloud-primary -o json | \
        jq -r --arg since "$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.items[] | select(.metadata.creationTimestamp > $since) | .metadata.name')
    
    for backup_name in $primary_backups; do
        if [ -n "$backup_name" ]; then
            log "📦 Репликация backup: $backup_name"
            
            # Репликация в AWS secondary
            if replicate_backup_to_aws "$backup_name"; then
                log "✅ AWS replication успешна: $backup_name"
                replication_count=$((replication_count + 1))
            else
                log "❌ AWS replication неуспешна: $backup_name"
                failed_replications=$((failed_replications + 1))
            fi
            
            # Репликация в Azure tertiary (только production)
            if echo "$backup_name" | grep -q "production"; then
                if replicate_backup_to_azure "$backup_name"; then
                    log "✅ Azure replication успешна: $backup_name"
                    replication_count=$((replication_count + 1))
                else
                    log "❌ Azure replication неуспешна: $backup_name"
                    failed_replications=$((failed_replications + 1))
                fi
            fi
        fi
    done
    
    log "📊 Cross-cloud replication завершена:"
    log "  ✅ Успешных репликаций: $replication_count"
    log "  ❌ Неуспешных репликаций: $failed_replications"
    
    # Создание replication report
    create_replication_report "$replication_count" "$failed_replications"
    
    return $failed_replications
}

# Функция репликации в AWS
replicate_backup_to_aws() {
    local backup_name=$1
    
    log "☁️ Репликация в AWS: $backup_name"
    
    # Создание backup в AWS location
    velero backup create ${backup_name}-aws-replica \
        --from-backup $backup_name \
        --storage-location aws-secondary \
        --labels "replicated-from=digitalocean,original-backup=$backup_name" \
        --wait --timeout 30m
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Создание audit записи
        cat >> /var/log/cross-cloud-replication.audit << AUDIT_EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "action": "backup_replication",
  "source_cloud": "digitalocean",
  "target_cloud": "aws",
  "original_backup": "$backup_name",
  "replica_backup": "${backup_name}-aws-replica",
  "status": "success"
}
AUDIT_EOF
        return 0
    else
        log "❌ Ошибка репликации в AWS: $backup_name"
        return 1
    fi
}

# Функция репликации в Azure
replicate_backup_to_azure() {
    local backup_name=$1
    
    log "☁️ Репликация в Azure: $backup_name"
    
    # Создание backup в Azure location
    velero backup create ${backup_name}-azure-replica \
        --from-backup $backup_name \
        --storage-location azure-tertiary \
        --labels "replicated-from=digitalocean,original-backup=$backup_name,tier=long-term" \
        --wait --timeout 45m
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Создание audit записи
        cat >> /var/log/cross-cloud-replication.audit << AUDIT_EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "action": "backup_replication",
  "source_cloud": "digitalocean",
  "target_cloud": "azure",
  "original_backup": "$backup_name",
  "replica_backup": "${backup_name}-azure-replica",
  "status": "success"
}
AUDIT_EOF
        return 0
    else
        log "❌ Ошибка репликации в Azure: $backup_name"
        return 1
    fi
}

# Функция automated failover detection
monitor_primary_cloud_health() {
    log "🏥 Мониторинг health primary cloud"
    
    local health_checks=0
    local failed_checks=0
    local failover_threshold=3
    
    # Проверка API server доступности
    if kubectl cluster-info &>/dev/null; then
        log "✅ Kubernetes API server доступен"
        health_checks=$((health_checks + 1))
    else
        log "❌ Kubernetes API server недоступен"
        failed_checks=$((failed_checks + 1))
    fi
    
    # Проверка nodes готовности
    local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    
    if [ $ready_nodes -eq $total_nodes ] && [ $total_nodes -gt 0 ]; then
        log "✅ Все узлы готовы ($ready_nodes/$total_nodes)"
        health_checks=$((health_checks + 1))
    else
        log "❌ Не все узлы готовы ($ready_nodes/$total_nodes)"
        failed_checks=$((failed_checks + 1))
    fi
    
    # Проверка critical applications
    local critical_apps=("argocd" "monitoring" "ingress-nginx")
    
    for app in "${critical_apps[@]}"; do
        local app_ready=$(kubectl get deployments -n $app --no-headers 2>/dev/null | \
            awk '{if($2==$4 && $4>0) print "ready"; else print "not-ready"}' | \
            grep -c "ready")
        
        if [ $app_ready -gt 0 ]; then
            log "✅ Critical app $app готово"
            health_checks=$((health_checks + 1))
        else
            log "❌ Critical app $app не готово"
            failed_checks=$((failed_checks + 1))
        fi
    done
    
    # Проверка storage доступности
    if kubectl get pv &>/dev/null; then
        log "✅ Storage доступен"
        health_checks=$((health_checks + 1))
    else
        log "❌ Storage недоступен"
        failed_checks=$((failed_checks + 1))
    fi
    
    log "📊 Health check результаты: $health_checks успешных, $failed_checks неуспешных"
    
    # Триггер failover если превышен threshold
    if [ $failed_checks -ge $failover_threshold ]; then
        log "🚨 КРИТИЧЕСКОЕ: Превышен failover threshold ($failed_checks >= $failover_threshold)"
        trigger_cross_cloud_failover "primary_cloud_failure" "Failed health checks: $failed_checks"
    fi
    
    return $failed_checks
}

# Функция cross-cloud failover
trigger_cross_cloud_failover() {
    local failure_reason=$1
    local details=$2
    
    log "🚨 ТРИГГЕР CROSS-CLOUD FAILOVER"
    log "Причина: $failure_reason"
    log "Детали: $details"
    
    # Выбор target cloud для failover
    local target_cloud="aws"  # Default to AWS secondary
    
    # Проверка доступности AWS
    if ! curl -s -o /dev/null -w "%{http_code}" https://ec2.amazonaws.com/ | grep -q "200\|403"; then
        log "⚠️ AWS недоступен, переключение на Azure"
        target_cloud="azure"
    fi
    
    log "🎯 Target cloud для failover: $target_cloud"
    
    # Выполнение failover процедуры
    execute_failover_to_cloud "$target_cloud" "$failure_reason"
    
    # Уведомление о failover
    send_failover_notification "$target_cloud" "$failure_reason" "$details"
    
    # Создание incident report
    create_failover_incident_report "$target_cloud" "$failure_reason" "$details"
}

# Функция выполнения failover
execute_failover_to_cloud() {
    local target_cloud=$1
    local reason=$2
    
    log "🔄 Выполнение failover на $target_cloud"
    
    # Поиск последнего backup в target cloud
    local storage_location="${target_cloud}-secondary"
    if [ "$target_cloud" = "azure" ]; then
        storage_location="azure-tertiary"
    fi
    
    local latest_backup=$(velero backup get -l backup-type=cross-cloud-secondary -o json | \
        jq -r --arg location "$storage_location" \
        '.items[] | select(.spec.storageLocation == $location) | .metadata.name' | \
        sort | tail -1)
    
    if [ -n "$latest_backup" ] && [ "$latest_backup" != "null" ]; then
        log "📦 Восстановление из backup: $latest_backup"
        
        # Создание restore
        velero restore create failover-restore-$(date +%s) \
            --from-backup $latest_backup \
            --wait --timeout 60m
        
        if [ $? -eq 0 ]; then
            log "✅ Failover restore завершен успешно"
            
            # Обновление DNS для переключения трафика
            update_dns_for_failover "$target_cloud"
            
            # Проверка application readiness после failover
            verify_failover_success "$target_cloud"
        else
            log "❌ Ошибка failover restore"
            return 1
        fi
    else
        log "❌ Backup не найден в $target_cloud для восстановления"
        return 1
    fi
}

# Функция обновления DNS для failover
update_dns_for_failover() {
    local target_cloud=$1
    
    log "🌐 Обновление DNS для failover на $target_cloud"
    
    # Получение IP load balancer в target cloud
    local lb_ip=""
    
    case $target_cloud in
        "aws")
            # Для AWS получаем ELB hostname и резолвим в IP
            lb_ip=$(dig +short hashfoundry-aws-lb.eu-central-1.elb.amazonaws.com | head -1)
            ;;
        "azure")
            # Для Azure получаем public IP
            lb_ip="20.105.123.45"  # Example Azure public IP
            ;;
        *)
            log "❌ Неизвестный target cloud: $target_cloud"
            return 1
            ;;
    esac
    
    if [ -n "$lb_ip" ]; then
        # Обновление DNS записей через Cloudflare API
        if [ -n "$CLOUDFLARE_API_TOKEN" ] && [ -n "$CLOUDFLARE_ZONE_ID" ]; then
            curl -X PUT "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$DNS_RECORD_ID" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                --data "{
                    \"type\": \"A\",
                    \"name\": \"app.hashfoundry.com\",
                    \"content\": \"$lb_ip\",
                    \"ttl\": 300,
                    \"comment\": \"Failover to $target_cloud at $(date)\"
                }"
            
            log "✅ DNS обновлен: app.hashfoundry.com -> $lb_ip ($target_cloud)"
        else
            log "⚠️ Cloudflare credentials не настроены, DNS обновление пропущено"
        fi
    else
        log "❌ Не удалось получить IP для $target_cloud"
        return 1
    fi
}

# Функция проверки успешности failover
verify_failover_success() {
    local target_cloud=$1
    
    log "🔍 Проверка успешности failover на $target_cloud"
    
    local verification_passed=0
    local verification_failed=0
    
    # Проверка доступности приложений
    local critical_apps=("argocd" "monitoring" "ingress-nginx")
    
    for app in "${critical_apps[@]}"; do
        local app_ready=$(kubectl get deployments -n $app --no-headers 2>/dev/null | \
            awk '{if($2==$4 && $4>0) print "ready"; else print "not-ready"}' | \
            grep -c "ready")
        
        if [ $app_ready -gt 0 ]; then
            log "✅ Failover verification: $app готово"
            verification_passed=$((verification_passed + 1))
        else
            log "❌ Failover verification: $app не готово"
            verification_failed=$((verification_failed + 1))
        fi
    done
    
    # Проверка external connectivity
    if curl -f -s "https://app.hashfoundry.com/health" &>/dev/null; then
        log "✅ Failover verification: External connectivity работает"
        verification_passed=$((verification_passed + 1))
    else
        log "❌ Failover verification: External connectivity не работает"
        verification_failed=$((verification_failed + 1))
    fi
    
    log "📊 Failover verification: $verification_passed успешных, $verification_failed неуспешных"
    
    if [ $verification_failed -eq 0 ]; then
        log "🎉 Failover на $target_cloud завершен успешно!"
        return 0
    else
        log "⚠️ Failover на $target_cloud завершен с проблемами"
        return 1
    fi
}

# Функция создания replication report
create_replication_report() {
    local successful_replications=$1
    local failed_replications=$2
    
    local replication_report="/tmp/cross-cloud-replication-report-$TIMESTAMP.json"
    
    cat > $replication_report << REPLICATION_REPORT_EOF
{
  "report_timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "replication_summary": {
    "successful_replications": $successful_replications,
    "failed_replications": $failed_replications,
    "success_rate": $(echo "scale=2; $successful_replications / ($successful_replications + $failed_replications) * 100" | bc -l 2>/dev/null || echo "0"),
    "total_backup_locations": $(velero backup-location get -o json | jq '.items | length'),
    "available_locations": $(velero backup-location get -o json | jq '[.items[] | select(.status.phase == "Available")] | length')
  },
  "cloud_distribution": {
$(velero backup get -o json | jq -r '
    group_by(.spec.storageLocation) | 
    map({
      location: .[0].spec.storageLocation,
      count: length,
      latest_backup: ([.[].metadata.creationTimestamp] | max)
    })[] | 
    "    \"\(.location)\": {\"count\": \(.count), \"latest\": \"\(.latest_backup)\"}"
' | paste -sd, -)
  }
}
REPLICATION_REPORT_EOF
    
    log "📄 Replication report создан: $replication_report"
}

# Функция отправки failover notification
send_failover_notification() {
    local target_cloud=$1
    local reason=$2
    local details=$3
    
    log "📧 Отправка failover notification"
    
    # Отправка в Slack
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\":\"🚨 CROSS-CLOUD FAILOVER ACTIVATED\",
                \"attachments\":[{
                    \"color\":\"danger\",
                    \"fields\":[{
                        \"title\":\"Target Cloud\",
                        \"value\":\"$target_cloud\",
                        \"short\":true
                    },{
                        \"title\":\"Reason\",
                        \"value\":\"$reason\",
                        \"short\":true
                    },{
                        \"title\":\"Details\",
                        \"value\":\"$details\",
                        \"short\":false
                    },{
                        \"title\":\"Status\",
                        \"value\":\"Failover in progress\",
                        \"short\":true
                    }]
                }]
            }" \
            "$SLACK_WEBHOOK_URL"
    fi
    
    # Создание PagerDuty incident
    if [ -n "$PAGERDUTY_INTEGRATION_KEY" ]; then
        curl -X POST "https://events.pagerduty.com/v2/enqueue" \
            -H "Content-Type: application/json" \
            --data "{
                \"routing_key\": \"$PAGERDUTY_INTEGRATION_KEY\",
                \"event_action\": \"trigger\",
                \"payload\": {
                    \"summary\": \"Cross-cloud failover to $target_cloud: $reason\",
                    \"severity\": \"critical\",
                    \"source\": \"cross-cloud-dr-system\",
                    \"custom_details\": {
                        \"target_cloud\": \"$target_cloud\",
                        \"reason\": \"$reason\",
                        \"details\": \"$details\"
                    }
                }
            }"
    fi
}

# Функция создания failover incident report
create_failover_incident_report() {
    local target_cloud=$1
    local reason=$2
    local details=$3
    
    local incident_report="/tmp/cross-cloud-failover-incident-$TIMESTAMP.json"
    
    cat > $incident_report << INCIDENT_REPORT_EOF
{
  "incident_timestamp": "$(date -Iseconds)",
  "incident_id": "CCDR-$(date +%Y%m%d-%H%M%S)",
  "failover_details": {
    "source_cloud": "$PRIMARY_CLOUD",
    "target_cloud": "$target_cloud",
    "failure_reason": "$reason",
    "failure_details": "$details",
    "detection_method": "automated_health_monitoring"
  },
  "infrastructure_status": {
    "primary_cluster_health": $(kubectl cluster-info &>/dev/null && echo "false" || echo "true"),
    "backup_locations_available": $(velero backup-location get -o json | jq '[.items[] | select(.status.phase == "Available")] | length'),
    "latest_backup_age_hours": $(velero backup get -o json | jq -r '[.items[].metadata.creationTimestamp] | max | fromdateiso8601 | (now - .) / 3600 | floor')
  },
  "recovery_actions": [
    "Automated failover triggered",
    "Target cloud selected: $target_cloud",
    "Latest backup identified for restore",
    "DNS failover initiated",
    "Stakeholder notifications sent"
  ],
  "next_steps": [
    "Monitor application recovery",
    "Verify data consistency",
    "Update runbooks based on lessons learned",
    "Plan primary cloud recovery"
  ]
}
INCIDENT_REPORT_EOF
    
    log "📄 Failover incident report: $incident_report"
}

# Основная логика выполнения
main() {
    case "$1" in
        analyze)
            analyze_multi_cloud_readiness
            ;;
        setup)
            create_cross_cloud_backup_strategy
            ;;
        replicate)
            execute_cross_cloud_replication
            ;;
        monitor)
            monitor_primary_cloud_health
            ;;
        failover)
            trigger_cross_cloud_failover "$2" "$3"
            ;;
        full)
            log "🚀 Запуск полного cross-cloud DR management"
            analyze_multi_cloud_readiness
            create_cross_cloud_backup_strategy
            execute_cross_cloud_replication
            monitor_primary_cloud_health
            log "🎉 Cross-cloud DR management завершен!"
            ;;
        *)
            echo "Использование: $0 {analyze|setup|replicate|monitor|failover <reason> <details>|full}"
            echo "  analyze   - Анализ multi-cloud readiness"
            echo "  setup     - Создание cross-cloud backup strategy"
            echo "  replicate - Выполнение cross-cloud replication"
            echo "  monitor   - Мониторинг primary cloud health"
            echo "  failover  - Триггер cross-cloud failover"
            echo "  full      - Полное cross-cloud DR management"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в cross-cloud DR manager"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x cross-cloud-dr-manager.sh
```

### **2. Создание terraform multi-cloud infrastructure:**
```bash
# Создать скрипт multi-cloud-terraform.sh
cat << 'EOF' > multi-cloud-terraform.sh
#!/bin/bash

echo "🏗️ Multi-Cloud Terraform Infrastructure Manager"
echo "=============================================="

# Настройка переменных
TERRAFORM_DIR="/tmp/multi-cloud-terraform"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Функция создания multi-cloud terraform configuration
create_multi_cloud_terraform() {
    echo "📝 Создание multi-cloud Terraform configuration"
    
    mkdir -p $TERRAFORM_DIR
    
    # Main terraform configuration
    cat > $TERRAFORM_DIR/main.tf << TERRAFORM_MAIN_EOF
# Multi-Cloud Disaster Recovery Infrastructure
terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# DigitalOcean Provider (Primary)
provider "digitalocean" {
  alias = "primary"
}

# AWS Provider (Secondary)
provider "aws" {
  alias  = "secondary"
  region = "eu-central-1"
}

# Azure Provider (Tertiary)
provider "azurerm" {
  alias = "tertiary"
  features {}
}

# DigitalOcean Kubernetes Cluster (Primary)
resource "digitalocean_kubernetes_cluster" "primary" {
  provider = digitalocean.primary
  
  name    = "hashfoundry-primary"
  region  = "fra1"
  version = "1.31.1-do.0"
  
  node_pool {
    name       = "primary-nodes"
    size       = "s-2vcpu-4gb"
    node_count = 3
    auto_scale = true
    min_nodes  = 3
    max_nodes  = 6
    
    labels = {
      environment = "production"
      role        = "primary"
      dr          = "enabled"
    }
  }
  
  tags = ["production", "primary", "dr-enabled"]
}

# AWS EKS Cluster (Secondary)
module "aws_eks_secondary" {
  source = "./modules/aws-eks"
  providers = {
    aws = aws.secondary
  }
  
  cluster_name    = "hashfoundry-secondary"
  cluster_version = "1.31"
  
  vpc_cidr = "10.1.0.0/16"
  
  node_groups = {
    secondary = {
      instance_types = ["m5.large"]
      min_size      = 3
      max_size      = 6
      desired_size  = 3
      
      labels = {
        environment = "disaster-recovery"
        role        = "secondary"
        dr          = "enabled"
      }
    }
  }
  
  tags = {
    Environment = "disaster-recovery"
    Role        = "secondary"
    DR          = "enabled"
  }
}

# Azure AKS Cluster (Tertiary)
module "azure_aks_tertiary" {
  source = "./modules/azure-aks"
  providers = {
    azurerm = azurerm.tertiary
  }
  
  cluster_name       = "hashfoundry-tertiary"
  location           = "West Europe"
  kubernetes_version = "1.31"
  
  resource_group_name = "hashfoundry-dr-rg"
  
  default_node_pool = {
    name       = "tertiary"
    vm_size    = "Standard_D2s_v3"
    node_count = 3
    min_count  = 3
    max_count  = 6
    
    node_labels = {
      environment = "disaster-recovery"
      role        = "tertiary"
      dr          = "enabled"
    }
  }
  
  tags = {
    Environment = "disaster-recovery"
    Role        = "tertiary"
    DR          = "enabled"
  }
}

# Cross-Cloud Storage for Backup
resource "digitalocean_spaces_bucket" "primary_backup" {
  provider = digitalocean.primary
  
  name   = "hashfoundry-backup-primary"
  region = "fra1"
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    id      = "backup_lifecycle"
    enabled = true
    
    transition {
      days          = 30
      storage_class = "IA"
    }
    
    expiration {
      days = 2555  # 7 years
    }
  }
}

resource "aws_s3_bucket" "secondary_backup" {
  provider = aws.secondary
  
  bucket = "hashfoundry-backup-secondary"
  
  tags = {
    Purpose = "cross-cloud-dr"
    Tier    = "secondary"
  }
}

resource "aws_s3_bucket_versioning" "secondary_backup" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_backup.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "secondary_backup" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_backup.id
  
  rule {
    id     = "backup_lifecycle"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = 2555  # 7 years
    }
  }
}

resource "azurerm_resource_group" "tertiary_dr" {
  provider = azurerm.tertiary
  
  name     = "hashfoundry-dr-rg"
  location = "West Europe"
  
  tags = {
    Purpose = "cross-cloud-dr"
    Tier    = "tertiary"
  }
}

resource "azurerm_storage_account" "tertiary_backup" {
  provider = azurerm.tertiary
  
  name                     = "hashfoundrydrbackup"
  resource_group_name      = azurerm_resource_group.tertiary_dr.name
  location                 = azurerm_resource_group.tertiary_dr.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 2555  # 7 years
    }
  }
  
  tags = {
    Purpose = "cross-cloud-dr"
    Tier    = "tertiary"
  }
}

# Cross-Cloud VPN Connections
resource "aws_vpn_gateway" "secondary_vpn" {
  provider = aws.secondary
  vpc_id   = module.aws_eks_secondary.vpc_id
  
  tags = {
    Name = "hashfoundry-secondary-vpn"
  }
}

resource "azurerm_virtual_network_gateway" "tertiary_vpn" {
  provider = azurerm.tertiary
  
  name                = "hashfoundry-tertiary-vpn"
  location            = azurerm_resource_group.tertiary_dr.location
  resource_group_name = azurerm_resource_group.tertiary_dr.name
  
  type     = "Vpn"
  vpn_type = "RouteBased"
  
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
  
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.tertiary_vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.tertiary_gateway.id
  }
}

resource "azurerm_public_ip" "tertiary_vpn" {
  provider = azurerm.tertiary
  
  name                = "hashfoundry-tertiary-vpn-ip"
  location            = azurerm_resource_group.tertiary_dr.location
  resource_group_name = azurerm_resource_group.tertiary_dr.name
  allocation_method   = "Dynamic"
}

resource "azurerm_subnet" "tertiary_gateway" {
  provider = azurerm.tertiary
  
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.tertiary_dr.name
  virtual_network_name = module.azure_aks_tertiary.vnet_name
  address_prefixes     = ["10.2.1.0/27"]
}
TERRAFORM_MAIN_EOF
    
    # Variables file
    cat > $TERRAFORM_DIR/variables.tf << TERRAFORM_VARS_EOF
variable "digitalocean_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure Client ID"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure Client Secret"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "hashfoundry"
}
TERRAFORM_VARS_EOF
    
    # Outputs file
    cat > $TERRAFORM_DIR/outputs.tf << TERRAFORM_OUTPUTS_EOF
output "primary_cluster_endpoint" {
  description = "DigitalOcean Kubernetes cluster endpoint"
  value       = digitalocean_kubernetes_cluster.primary.endpoint
  sensitive   = true
}

output "primary_cluster_token" {
  description = "DigitalOcean Kubernetes cluster token"
  value       = digitalocean_kubernetes_cluster.primary.kube_config[0].token
  sensitive   = true
}

output "secondary_cluster_endpoint" {
  description = "AWS EKS cluster endpoint"
  value       = module.aws_eks_secondary.cluster_endpoint
  sensitive   = true
}

output "tertiary_cluster_endpoint" {
  description = "Azure AKS cluster endpoint"
  value       = module.azure_aks_tertiary.cluster_endpoint
  sensitive   = true
}

output "backup_storage_locations" {
  description = "Cross-cloud backup storage locations"
  value = {
    primary   = digitalocean_spaces_bucket.primary_backup.name
    secondary = aws_s3_bucket.secondary_backup.bucket
    tertiary  = azurerm_storage_account.tertiary_backup.name
  }
}

output "vpn_gateways" {
  description = "Cross-cloud VPN gateway information"
  value = {
    aws_vpn_gateway_id   = aws_vpn_gateway.secondary_vpn.id
    azure_vpn_gateway_id = azurerm_virtual_network_gateway.tertiary_vpn.id
  }
}
TERRAFORM_OUTPUTS_EOF
    
    echo "✅ Multi-cloud Terraform configuration создана в $TERRAFORM_DIR"
}

# Функция развертывания multi-cloud infrastructure
deploy_multi_cloud_infrastructure() {
    echo "🚀 Развертывание multi-cloud infrastructure"
    
    cd $TERRAFORM_DIR
    
    # Terraform init
    terraform init
    
    # Terraform plan
    terraform plan -out=multi-cloud.tfplan
    
    # Terraform apply
    terraform apply multi-cloud.tfplan
    
    if [ $? -eq 0 ]; then
        echo "✅ Multi-cloud infrastructure развернута успешно"
        
        # Сохранение outputs
        terraform output -json > multi-cloud-outputs.json
        
        echo "📄 Terraform outputs сохранены в multi-cloud-outputs.json"
    else
        echo "❌ Ошибка развертывания multi-cloud infrastructure"
        return 1
    fi
}

# Основная логика
case "$1" in
    create)
        create_multi_cloud_terraform
        ;;
    deploy)
        deploy_multi_cloud_infrastructure
        ;;
    full)
        create_multi_cloud_terraform
        deploy_multi_cloud_infrastructure
        ;;
    *)
        echo "Использование: $0 {create|deploy|full}"
        echo "  create - Создание Terraform configuration"
        echo "  deploy - Развертывание infrastructure"
        echo "  full   - Создание и развертывание"
        exit 1
        ;;
esac
EOF

chmod +x multi-cloud-terraform.sh
```

## 📊 **Архитектура cross-cloud disaster recovery:**

```
┌─────────────────────────────────────────────────────────────┐
│              Cross-Cloud Disaster Recovery                 │
├─────────────────────────────────────────────────────────────┤
│  Multi-Cloud Infrastructure                                │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │ Primary     │ Secondary   │ Tertiary    │ Connectivity│  │
│  │ DigitalOcean│ AWS         │ Azure       │ & Routing   │  │
│  │ ├── fra1    │ ├── eu-c-1  │ ├── west-eu │ ├── VPN     │  │
│  │ ├── K8s 1.31│ ├── EKS     │ ├── AKS     │ ├── DNS     │  │
│  │ ├── 3-6 nodes│ ├── 3-6 nodes│ ├── 3-6 nodes│ ├── LB      │  │
│  │ └── Spaces  │ └── S3      │ └── Blob    │ └── Failover│  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Data Replication & Backup Strategy                        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ ├── Real-time Application Data Sync                    │ │
│  │ ├── Scheduled Cross-Cloud Backup Replication           │ │
│  │ ├── Configuration & Secret Synchronization             │ │
│  │ ├── Infrastructure State Management                    │ │
│  │ └── Automated Failover & Recovery Procedures           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для cross-cloud DR:**

### **1. Infrastructure Design**
- Используйте Infrastructure as Code для consistency
- Настройте automated health monitoring
- Обеспечьте network connectivity между clouds
- Планируйте capacity для failover scenarios

### **2. Data Management**
- Реплицируйте данные в real-time где возможно
- Используйте tiered backup strategy
- Обеспечьте data consistency checks
- Планируйте data migration procedures

### **3. Automation & Orchestration**
- Автоматизируйте failover detection
- Настройте automated recovery procedures
- Используйте GitOps для configuration management
- Обеспечьте automated testing DR procedures

### **4. Monitoring & Alerting**
- Мониторьте health всех clouds
- Настройте cross-cloud connectivity alerts
- Отслеживайте replication lag
- Обеспечьте comprehensive logging

**Cross-cloud disaster recovery обеспечивает максимальную защиту от катастрофических сбоев и является критически важным для enterprise-уровня надежности!**
