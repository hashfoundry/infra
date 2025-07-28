# 170. Как реализовать cross-cloud disaster recovery?

## 🎯 Вопрос
Как реализовать cross-cloud disaster recovery?

## 💡 Ответ

Cross-cloud disaster recovery обеспечивает защиту от отказа целого cloud provider через репликацию данных и приложений между разными облачными платформами, использование multi-cloud backup стратегий, автоматизацию failover процедур и поддержание консистентности конфигураций.

### 🏗️ Архитектура cross-cloud DR

#### 1. **Схема multi-cloud DR**
```
┌─────────────────────────────────────────────────────────────┐
│                Cross-Cloud Disaster Recovery               │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   AWS       │    │   Azure     │    │    GCP      │     │
│  │ (Primary)   │◄──▶│ (Secondary) │◄──▶│ (Tertiary)  │     │
│  │  fra1       │    │ westeurope  │    │ europe-west │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Data Sync   │    │ Config      │    │ Network     │     │
│  │ & Backup    │    │ Management  │    │ Connectivity│     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Компоненты cross-cloud DR**
```yaml
# Компоненты cross-cloud disaster recovery
cross_cloud_dr_components:
  data_layer:
    - "Cross-cloud data replication"
    - "Multi-cloud backup storage"
    - "Database synchronization"
    - "Object storage mirroring"
  
  application_layer:
    - "Container image registry sync"
    - "Configuration management"
    - "Secret synchronization"
    - "Application deployment automation"
  
  network_layer:
    - "VPN connections between clouds"
    - "DNS failover mechanisms"
    - "Load balancer configuration"
    - "CDN distribution"
  
  orchestration_layer:
    - "Multi-cloud Kubernetes management"
    - "Automated failover procedures"
    - "Health monitoring"
    - "Recovery automation"
```

### 📊 Примеры из нашего кластера

#### Проверка cross-cloud готовности:
```bash
# Проверка текущего cloud provider
kubectl get nodes -o wide
kubectl get storageclass

# Проверка backup locations
velero backup-location get
kubectl get backupstoragelocation -n velero

# Проверка network connectivity
ping azure-dr-endpoint.westeurope.cloudapp.azure.com
ping gcp-dr-endpoint.europe-west1.compute.googleapis.com
```

### 🌐 Multi-cloud инфраструктура

#### 1. **Terraform конфигурация для multi-cloud**
```hcl
# multi-cloud-infrastructure.tf

# AWS Provider (Primary)
provider "aws" {
  alias  = "primary"
  region = "eu-central-1"
}

# Azure Provider (Secondary)
provider "azurerm" {
  alias = "secondary"
  features {}
}

# GCP Provider (Tertiary)
provider "google" {
  alias   = "tertiary"
  project = "hashfoundry-dr"
  region  = "europe-west1"
}

# AWS Kubernetes Cluster (Primary)
module "aws_eks_primary" {
  source = "./modules/aws-eks"
  providers = {
    aws = aws.primary
  }
  
  cluster_name    = "hashfoundry-primary"
  cluster_version = "1.31"
  
  node_groups = {
    primary = {
      instance_types = ["m5.large"]
      min_size      = 3
      max_size      = 9
      desired_size  = 3
    }
  }
  
  tags = {
    Environment = "production"
    Role        = "primary"
    DR          = "enabled"
  }
}

# Azure Kubernetes Cluster (Secondary)
module "azure_aks_secondary" {
  source = "./modules/azure-aks"
  providers = {
    azurerm = azurerm.secondary
  }
  
  cluster_name     = "hashfoundry-secondary"
  location         = "West Europe"
  kubernetes_version = "1.31"
  
  default_node_pool = {
    vm_size    = "Standard_D2s_v3"
    node_count = 3
    min_count  = 3
    max_count  = 9
  }
  
  tags = {
    Environment = "disaster-recovery"
    Role        = "secondary"
    DR          = "enabled"
  }
}

# GCP Kubernetes Cluster (Tertiary)
module "gcp_gke_tertiary" {
  source = "./modules/gcp-gke"
  providers = {
    google = google.tertiary
  }
  
  cluster_name = "hashfoundry-tertiary"
  location     = "europe-west1"
  
  node_pool = {
    machine_type = "e2-standard-2"
    min_count    = 3
    max_count    = 9
    initial_count = 3
  }
  
  labels = {
    environment = "disaster-recovery"
    role        = "tertiary"
    dr          = "enabled"
  }
}

# Cross-cloud VPN connections
resource "aws_vpn_gateway" "primary_to_azure" {
  provider = aws.primary
  vpc_id   = module.aws_eks_primary.vpc_id
  
  tags = {
    Name = "primary-to-azure-vpn"
  }
}

resource "azurerm_virtual_network_gateway" "azure_to_aws" {
  provider            = azurerm.secondary
  name                = "azure-to-aws-vpn"
  location            = "West Europe"
  resource_group_name = module.azure_aks_secondary.resource_group_name
  
  type     = "Vpn"
  vpn_type = "RouteBased"
  
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
}

# Cross-cloud storage for backup
resource "aws_s3_bucket" "cross_cloud_backup" {
  provider = aws.primary
  bucket   = "hashfoundry-cross-cloud-backup"
  
  tags = {
    Purpose = "cross-cloud-dr"
  }
}

resource "azurerm_storage_account" "dr_backup" {
  provider                 = azurerm.secondary
  name                     = "hashfoundrydrbackup"
  resource_group_name      = module.azure_aks_secondary.resource_group_name
  location                 = "West Europe"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  
  tags = {
    purpose = "cross-cloud-dr"
  }
}

resource "google_storage_bucket" "tertiary_backup" {
  provider = google.tertiary
  name     = "hashfoundry-tertiary-backup"
  location = "EUROPE-WEST1"
  
  versioning {
    enabled = true
  }
  
  labels = {
    purpose = "cross-cloud-dr"
  }
}
```

#### 2. **Скрипт управления multi-cloud**
```bash
#!/bin/bash
# multi-cloud-manager.sh

echo "🌐 Управление multi-cloud disaster recovery"

# Переменные
PRIMARY_CLUSTER="aws-primary"
SECONDARY_CLUSTER="azure-secondary"
TERTIARY_CLUSTER="gcp-tertiary"
DR_NAMESPACE="disaster-recovery"

# Проверка состояния всех кластеров
check_cluster_health() {
    echo "🏥 Проверка состояния кластеров"
    
    local clusters=("$PRIMARY_CLUSTER" "$SECONDARY_CLUSTER" "$TERTIARY_CLUSTER")
    
    for cluster in "${clusters[@]}"; do
        echo "Проверка кластера: $cluster"
        
        # Переключение контекста
        kubectl config use-context $cluster
        
        # Проверка доступности API
        if kubectl cluster-info &>/dev/null; then
            echo "✅ $cluster: API доступен"
            
            # Проверка узлов
            local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
            local total_nodes=$(kubectl get nodes --no-headers | wc -l)
            echo "📊 $cluster: Узлы $ready_nodes/$total_nodes готовы"
            
            # Проверка критичных подов
            local failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l)
            if [ $failed_pods -eq 0 ]; then
                echo "✅ $cluster: Все поды работают"
            else
                echo "⚠️ $cluster: $failed_pods подов в проблемном состоянии"
            fi
        else
            echo "❌ $cluster: API недоступен"
        fi
        
        echo "---"
    done
}

# Синхронизация данных между кластерами
sync_cross_cloud_data() {
    echo "🔄 Синхронизация данных между кластерами"
    
    # Создание backup в primary кластере
    kubectl config use-context $PRIMARY_CLUSTER
    
    local backup_name="cross-cloud-sync-$(date +%s)"
    velero backup create $backup_name \
        --include-namespaces production,staging \
        --storage-location aws-backup-location \
        --wait
    
    if [ $? -eq 0 ]; then
        echo "✅ Backup создан в primary кластере: $backup_name"
        
        # Репликация backup в secondary кластер
        replicate_backup_to_azure "$backup_name"
        
        # Репликация backup в tertiary кластер
        replicate_backup_to_gcp "$backup_name"
    else
        echo "❌ Ошибка создания backup в primary кластере"
    fi
}

# Репликация backup в Azure
replicate_backup_to_azure() {
    local backup_name=$1
    
    echo "📦 Репликация backup в Azure: $backup_name"
    
    # Копирование backup из AWS S3 в Azure Blob Storage
    aws s3 cp s3://hashfoundry-cross-cloud-backup/backups/$backup_name \
        - | az storage blob upload \
        --account-name hashfoundrydrbackup \
        --container-name backups \
        --name $backup_name \
        --file -
    
    # Создание Velero backup объекта в Azure кластере
    kubectl config use-context $SECONDARY_CLUSTER
    
    cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: $backup_name
  namespace: velero
  labels:
    replicated-from: aws-primary
spec:
  storageLocation: azure-backup-location
  includedNamespaces:
  - production
  - staging
EOF
    
    echo "✅ Backup реплицирован в Azure"
}

# Репликация backup в GCP
replicate_backup_to_gcp() {
    local backup_name=$1
    
    echo "📦 Репликация backup в GCP: $backup_name"
    
    # Копирование backup из AWS S3 в Google Cloud Storage
    aws s3 cp s3://hashfoundry-cross-cloud-backup/backups/$backup_name \
        - | gsutil cp - gs://hashfoundry-tertiary-backup/backups/$backup_name
    
    # Создание Velero backup объекта в GCP кластере
    kubectl config use-context $TERTIARY_CLUSTER
    
    cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: $backup_name
  namespace: velero
  labels:
    replicated-from: aws-primary
spec:
  storageLocation: gcp-backup-location
  includedNamespaces:
  - production
  - staging
EOF
    
    echo "✅ Backup реплицирован в GCP"
}

# Автоматический failover
perform_cross_cloud_failover() {
    local target_cluster=$1
    local reason=$2
    
    echo "🚨 Выполнение cross-cloud failover на $target_cluster"
    echo "Причина: $reason"
    
    # Переключение на target кластер
    kubectl config use-context $target_cluster
    
    # Поиск последнего backup
    local latest_backup=$(velero backup get -o json | \
        jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
    
    if [ "$latest_backup" != "null" ]; then
        echo "📦 Восстановление из backup: $latest_backup"
        
        # Создание restore
        velero restore create failover-restore-$(date +%s) \
            --from-backup $latest_backup \
            --wait
        
        if [ $? -eq 0 ]; then
            echo "✅ Failover восстановление завершено"
            
            # Обновление DNS для переключения трафика
            update_dns_for_failover "$target_cluster"
            
            # Уведомление о failover
            send_failover_notification "$target_cluster" "$reason"
        else
            echo "❌ Ошибка failover восстановления"
        fi
    else
        echo "❌ Backup не найден для восстановления"
    fi
}

# Обновление DNS для failover
update_dns_for_failover() {
    local target_cluster=$1
    
    echo "🌐 Обновление DNS для failover на $target_cluster"
    
    # Получение IP адреса load balancer в target кластере
    local lb_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$lb_ip" ]; then
        # Обновление DNS записей (пример для Cloudflare)
        curl -X PUT "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$DNS_RECORD_ID" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{
                \"type\": \"A\",
                \"name\": \"app.hashfoundry.com\",
                \"content\": \"$lb_ip\",
                \"ttl\": 300
            }"
        
        echo "✅ DNS обновлен: app.hashfoundry.com -> $lb_ip"
    else
        echo "❌ Не удалось получить IP load balancer"
    fi
}

# Отправка уведомления о failover
send_failover_notification() {
    local target_cluster=$1
    local reason=$2
    
    echo "📢 Отправка уведомления о failover"
    
    # Отправка в Slack
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\":\"🚨 CROSS-CLOUD FAILOVER ACTIVATED\",
                \"attachments\":[{
                    \"color\":\"warning\",
                    \"fields\":[
                        {
                            \"title\":\"Target Cluster\",
                            \"value\":\"$target_cluster\",
                            \"short\":true
                        },
                        {
                            \"title\":\"Reason\",
                            \"value\":\"$reason\",
                            \"short\":true
                        },
                        {
                            \"title\":\"Status\",
                            \"value\":\"Failover completed successfully\",
                            \"short\":false
                        }
                    ]
                }]
            }" \
            "$SLACK_WEBHOOK_URL"
    fi
    
    # Создание incident в PagerDuty
    if [ -n "$PAGERDUTY_INTEGRATION_KEY" ]; then
        curl -X POST "https://events.pagerduty.com/v2/enqueue" \
            -H "Content-Type: application/json" \
            --data "{
                \"routing_key\": \"$PAGERDUTY_INTEGRATION_KEY\",
                \"event_action\": \"trigger\",
                \"payload\": {
                    \"summary\": \"Cross-cloud failover activated to $target_cluster\",
                    \"severity\": \"warning\",
                    \"source\": \"kubernetes-dr-system\"
                }
            }"
    fi
}

# Тестирование DR процедур
test_dr_procedures() {
    echo "🧪 Тестирование DR процедур"
    
    # Создание тестового namespace
    kubectl config use-context $SECONDARY_CLUSTER
    kubectl create namespace dr-test --dry-run=client -o yaml | kubectl apply -f -
    
    # Развертывание тестового приложения
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dr-test-app
  namespace: dr-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dr-test
  template:
    metadata:
      labels:
        app: dr-test
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: dr-test-service
  namespace: dr-test
spec:
  selector:
    app: dr-test
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF
    
    # Ожидание готовности
    kubectl wait --for=condition=available deployment/dr-test-app -n dr-test --timeout=300s
    
    # Тестирование доступности
    local service_ip=$(kubectl get svc dr-test-service -n dr-test \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if curl -f -s "http://$service_ip" &>/dev/null; then
        echo "✅ DR тест успешен - приложение доступно"
    else
        echo "❌ DR тест неуспешен - приложение недоступно"
    fi
    
    # Очистка тестовых ресурсов
    kubectl delete namespace dr-test
}

# Основная логика
case "$1" in
    health)
        check_cluster_health
        ;;
    sync)
        sync_cross_cloud_data
        ;;
    failover)
        perform_cross_cloud_failover "$2" "$3"
        ;;
    test)
        test_dr_procedures
        ;;
    full-check)
        check_cluster_health
        sync_cross_cloud_data
        test_dr_procedures
        ;;
    *)
        echo "Использование: $0 {health|sync|failover <cluster> <reason>|test|full-check}"
        exit 1
        ;;
esac
```

### 🔄 Автоматизация cross-cloud DR

#### 1. **ArgoCD конфигурация для multi-cloud**
```yaml
# multi-cloud-argocd-config.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cross-cloud-dr-primary
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/k8s-manifests
    targetRevision: HEAD
    path: cross-cloud-dr/primary
  destination:
    server: https://aws-primary-cluster-api.com
    namespace: disaster-recovery
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cross-cloud-dr-secondary
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/k8s-manifests
    targetRevision: HEAD
    path: cross-cloud-dr/secondary
  destination:
    server: https://azure-secondary-cluster-api.com
    namespace: disaster-recovery
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cross-cloud-dr-tertiary
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/k8s-manifests
    targetRevision: HEAD
    path: cross-cloud-dr/tertiary
  destination:
    server: https://gcp-tertiary-cluster-api.com
    namespace: disaster-recovery
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### 2. **Мониторинг cross-cloud DR**
```yaml
# cross-cloud-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cross-cloud-dr-alerts
  namespace: monitoring
spec:
  groups:
  - name: cross-cloud-dr
    rules:
    - alert: PrimaryClusterDown
      expr: up{job="kubernetes-apiservers", cluster="aws-primary"} == 0
      for: 5m
      labels:
        severity: critical
        component: cross-cloud-dr
      annotations:
        summary: "Primary cluster is down"
        description: "AWS primary cluster has been down for more than 5 minutes"
        runbook_url: "https://docs.hashfoundry.com/runbooks/cross-cloud-failover"
    
    - alert: CrossCloudReplicationLag
      expr: cross_cloud_replication_lag_seconds > 300
      for: 10m
      labels:
        severity: warning
        component: cross-cloud-dr
      annotations:
        summary: "Cross-cloud replication lag high"
        description: "Replication lag between clouds is {{ $value }} seconds"
    
    - alert: BackupReplicationFailed
      expr: cross_cloud_backup_replication_failures_total > 0
      for: 5m
      labels:
        severity: critical
        component: cross-cloud-dr
      annotations:
        summary: "Cross-cloud backup replication failed"
        description: "{{ $value }} backup replications have failed"
    
    - alert: DrTestFailed
      expr: cross_cloud_dr_test_success == 0
      for: 0m
      labels:
        severity: warning
        component: cross-cloud-dr
      annotations:
        summary: "DR test failed"
        description: "Cross-cloud DR test has failed"
---
# Grafana Dashboard для cross-cloud DR
apiVersion: v1
kind: ConfigMap
metadata:
  name: cross-cloud-dr-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "Cross-Cloud Disaster Recovery",
        "panels": [
          {
            "title": "Cluster Health Status",
            "type": "stat",
            "targets": [
              {
                "expr": "up{job=\"kubernetes-apiservers\"}"
              }
            ]
          },
          {
            "title": "Replication Lag",
            "type": "graph",
            "targets": [
              {
                "expr": "cross_cloud_replication_lag_seconds"
              }
            ]
          },
          {
            "title": "Backup Replication Status",
            "type": "table",
            "targets": [
              {
                "expr": "cross_cloud_backup_replication_status"
              }
            ]
          },
          {
            "title": "Failover History",
            "type": "logs",
            "targets": [
              {
                "expr": "{job=\"cross-cloud-dr\"} |= \"failover\""
              }
            ]
          }
        ]
      }
    }
```

### 🎯 Лучшие практики cross-cloud DR

#### 1. **Стратегия cross-cloud DR**
```yaml
cross_cloud_dr_best_practices:
  planning:
    - "Выбрать совместимые cloud providers"
    - "Спланировать network connectivity"
    - "Определить RTO/RPO требования"
    - "Создать runbooks для failover"
  
  implementation:
    - "Использовать Infrastructure as Code"
    - "Автоматизировать data replication"
    - "Настроить monitoring и alerting"
    - "Регулярно тестировать DR процедуры"
  
  security:
    - "Шифровать данные при передаче"
    - "Использовать VPN connections"
    - "Управлять access credentials"
    - "Audit всех DR операций"
  
  cost_optimization:
    - "Использовать spot instances для DR"
    - "Оптимизировать storage costs"
    - "Автоматически scale down при неактивности"
    - "Мониторить cross-cloud transfer costs"
```

#### 2. **Чек-лист готовности**
```yaml
cross_cloud_dr_readiness_checklist:
  infrastructure:
    - "✅ Multi-cloud кластеры развернуты"
    - "✅ Network connectivity настроена"
    - "✅ Storage replication работает"
    - "✅ DNS failover настроен"
  
  applications:
    - "✅ Container images синхронизированы"
    - "✅ Configurations реплицированы"
    - "✅ Secrets синхронизированы"
    - "✅ Database replication настроена"
  
  procedures:
    - "✅ Failover runbooks созданы"
    - "✅ Automated failover настроен"
    - "✅ Recovery procedures документированы"
    - "✅ Communication plans готовы"
  
  testing:
    - "✅ DR tests выполняются регулярно"
    - "✅ Failover procedures протестированы"
    - "✅ Recovery time измерен"
    - "✅ Data integrity проверена"
```

Cross-cloud disaster recovery обеспечивает максимальную защиту от катастрофических сбоев и является критически важным компонентом enterprise-уровня надежности в Kubernetes среде.
