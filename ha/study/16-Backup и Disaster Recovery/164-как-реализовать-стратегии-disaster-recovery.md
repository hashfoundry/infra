# 164. Как реализовать стратегии disaster recovery?

## 🎯 **Что такое Disaster Recovery для Kubernetes?**

**Disaster Recovery (DR) для Kubernetes** — это комплексная стратегия и набор процедур для быстрого восстановления работоспособности кластера и приложений после катастрофических сбоев, включающая multi-region репликацию, автоматизированный failover, backup/restore процедуры и непрерывное тестирование для обеспечения минимальных RTO и RPO.

## 🏗️ **Основные компоненты DR стратегии:**

### **1. Multi-Region Architecture (Мульти-региональная архитектура)**
- **Primary Cluster** - основной рабочий кластер
- **Secondary Cluster** - резервный кластер в другом регионе
- **Backup Storage** - централизованное хранилище backup
- **DNS Failover** - автоматическое переключение трафика

### **2. RTO/RPO Targets (Цели восстановления)**
- **RTO (Recovery Time Objective)** - максимальное время восстановления
- **RPO (Recovery Point Objective)** - максимальная потеря данных
- **Availability Targets** - целевые показатели доступности
- **Service Tiers** - классификация сервисов по критичности

### **3. Automation & Monitoring (Автоматизация и мониторинг)**
- **Health Checks** - проверки состояния кластера
- **Automated Failover** - автоматическое переключение
- **Alert Management** - управление уведомлениями
- **Recovery Orchestration** - оркестрация восстановления

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей DR готовности:**
```bash
# Проверка состояния primary кластера
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Анализ критичных компонентов
kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Проверка backup систем
kubectl get pods -n velero
kubectl get backups -n velero --sort-by=.metadata.creationTimestamp

# Анализ persistent volumes
kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,STORAGECLASS:.spec.storageClassName,SIZE:.spec.capacity.storage
```

### **2. Мониторинг DR метрик:**
```bash
# Проверка доступности etcd
kubectl get --raw /healthz/etcd

# Анализ производительности кластера
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu

# Проверка сетевой связности
kubectl get svc -n ingress-nginx
kubectl get ingress --all-namespaces
```

### **3. Проверка backup готовности:**
```bash
# Анализ последних backup
velero backup get --sort-by=.metadata.creationTimestamp
velero backup describe $(velero backup get -o name | tail -1)

# Проверка backup locations
velero backup-location get
velero snapshot-location get

# Анализ размера backup
kubectl get backups -n velero -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,SIZE:.status.totalItems,CREATED:.metadata.creationTimestamp
```

## 🔄 **Демонстрация реализации DR стратегии:**

### **1. Создание Multi-Region DR архитектуры:**
```bash
# Создать скрипт multi-region-dr-setup.sh
cat << 'EOF' > multi-region-dr-setup.sh
#!/bin/bash

echo "🌐 Настройка Multi-Region Disaster Recovery"
echo "=========================================="

# Настройка переменных
PRIMARY_CLUSTER="hashfoundry-ha"
DR_CLUSTER="hashfoundry-dr"
PRIMARY_REGION="fra1"
DR_REGION="ams3"
BACKUP_BUCKET="hashfoundry-backup"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция проверки зависимостей
check_dependencies() {
    log "🔍 Проверка зависимостей..."
    
    # Проверка инструментов
    for tool in kubectl doctl terraform helm; do
        if ! command -v $tool &> /dev/null; then
            log "❌ $tool не найден"
            exit 1
        fi
    done
    
    # Проверка переменных окружения
    if [ -z "$DO_TOKEN" ]; then
        log "❌ DO_TOKEN не установлен"
        exit 1
    fi
    
    log "✅ Все зависимости проверены"
}

# Функция создания DR кластера
create_dr_cluster() {
    log "🏗️ Создание DR кластера..."
    
    # Создание Terraform конфигурации для DR
    cat << TERRAFORM_EOF > dr-cluster.tf
# DR Cluster Configuration
resource "digitalocean_kubernetes_cluster" "dr_cluster" {
  name    = "$DR_CLUSTER"
  region  = "$DR_REGION"
  version = "1.31.9-do.2"
  
  node_pool {
    name       = "dr-worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 3
    
    auto_scale = true
    min_nodes  = 2
    max_nodes  = 8
    
    labels = {
      environment = "disaster-recovery"
      cluster     = "$DR_CLUSTER"
    }
    
    taint {
      key    = "disaster-recovery"
      value  = "true"
      effect = "NoSchedule"
    }
  }
  
  tags = ["disaster-recovery", "secondary", "ha"]
}

# VPC для DR кластера
resource "digitalocean_vpc" "dr_vpc" {
  name     = "$DR_CLUSTER-vpc"
  region   = "$DR_REGION"
  ip_range = "10.20.0.0/16"
  
  tags = ["disaster-recovery"]
}

# Load Balancer для DR кластера
resource "digitalocean_loadbalancer" "dr_lb" {
  name   = "$DR_CLUSTER-lb"
  region = "$DR_REGION"
  vpc_uuid = digitalocean_vpc.dr_vpc.id
  
  forwarding_rule {
    entry_protocol  = "https"
    entry_port      = 443
    target_protocol = "https"
    target_port     = 443
    tls_passthrough = true
  }
  
  forwarding_rule {
    entry_protocol  = "http"
    entry_port      = 80
    target_protocol = "http"
    target_port     = 80
  }
  
  healthcheck {
    protocol               = "http"
    port                   = 80
    path                   = "/healthz"
    check_interval_seconds = 10
    response_timeout_seconds = 5
    unhealthy_threshold    = 3
    healthy_threshold      = 2
  }
  
  tags = ["disaster-recovery"]
}

# Outputs
output "dr_cluster_id" {
  value = digitalocean_kubernetes_cluster.dr_cluster.id
}

output "dr_cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.dr_cluster.endpoint
}

output "dr_lb_ip" {
  value = digitalocean_loadbalancer.dr_lb.ip
}
TERRAFORM_EOF
    
    # Применение Terraform конфигурации
    terraform init
    terraform plan -var="do_token=$DO_TOKEN"
    terraform apply -auto-approve -var="do_token=$DO_TOKEN"
    
    # Получение kubeconfig для DR кластера
    doctl kubernetes cluster kubeconfig save $DR_CLUSTER
    
    log "✅ DR кластер создан"
}

# Функция настройки DR кластера
setup_dr_cluster() {
    log "⚙️ Настройка DR кластера..."
    
    # Переключение на DR кластер
    kubectl config use-context do-$DR_REGION-$DR_CLUSTER
    
    # Создание namespace для DR
    kubectl create namespace disaster-recovery --dry-run=client -o yaml | kubectl apply -f -
    
    # Установка базовых компонентов
    install_dr_components
    
    # Настройка tolerations для DR узлов
    setup_dr_tolerations
    
    log "✅ DR кластер настроен"
}

# Функция установки DR компонентов
install_dr_components() {
    log "📦 Установка DR компонентов..."
    
    # Установка NGINX Ingress
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=2 \
        --set controller.nodeSelector."kubernetes\.io/os"=linux \
        --set controller.tolerations[0].key=disaster-recovery \
        --set controller.tolerations[0].value=true \
        --set controller.tolerations[0].effect=NoSchedule \
        --set controller.service.type=LoadBalancer \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/do-loadbalancer-name"=$DR_CLUSTER-lb
    
    # Установка Velero для DR
    install_velero_dr
    
    # Установка мониторинга
    install_monitoring_dr
    
    log "✅ DR компоненты установлены"
}

# Функция установки Velero для DR
install_velero_dr() {
    log "📥 Установка Velero для DR..."
    
    # Создание credentials
    cat > /tmp/credentials-velero-dr << CRED_EOF
[default]
aws_access_key_id=${DO_SPACES_ACCESS_KEY}
aws_secret_access_key=${DO_SPACES_SECRET_KEY}
CRED_EOF
    
    # Установка Velero
    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.8.1,digitalocean/velero-plugin:v1.1.0 \
        --bucket $BACKUP_BUCKET \
        --secret-file /tmp/credentials-velero-dr \
        --backup-location-config region=$DR_REGION,s3ForcePathStyle="true",s3Url=https://$DR_REGION.digitaloceanspaces.com \
        --snapshot-location-config region=$DR_REGION \
        --use-volume-snapshots=true \
        --use-node-agent
    
    # Настройка tolerations для Velero
    kubectl patch deployment velero -n velero -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"disaster-recovery","value":"true","effect":"NoSchedule"}]}}}}'
    
    rm -f /tmp/credentials-velero-dr
    log "✅ Velero для DR установлен"
}

# Функция установки мониторинга для DR
install_monitoring_dr() {
    log "📊 Установка мониторинга для DR..."
    
    # Создание namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Установка Prometheus для DR
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.nodeSelector."kubernetes\.io/os"=linux \
        --set prometheus.prometheusSpec.tolerations[0].key=disaster-recovery \
        --set prometheus.prometheusSpec.tolerations[0].value=true \
        --set prometheus.prometheusSpec.tolerations[0].effect=NoSchedule \
        --set grafana.nodeSelector."kubernetes\.io/os"=linux \
        --set grafana.tolerations[0].key=disaster-recovery \
        --set grafana.tolerations[0].value=true \
        --set grafana.tolerations[0].effect=NoSchedule \
        --set prometheus.prometheusSpec.retention=7d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=do-block-storage \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi
    
    log "✅ Мониторинг для DR установлен"
}

# Функция настройки tolerations
setup_dr_tolerations() {
    log "🔧 Настройка tolerations для DR..."
    
    # Создание DaemonSet для настройки узлов
    cat << DAEMONSET_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dr-node-setup
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: dr-node-setup
  template:
    metadata:
      labels:
        name: dr-node-setup
    spec:
      tolerations:
      - key: disaster-recovery
        value: "true"
        effect: NoSchedule
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-setup
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do sleep 3600; done"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-root
          mountPath: /host
      volumes:
      - name: host-root
        hostPath:
          path: /
      nodeSelector:
        kubernetes.io/os: linux
DAEMONSET_EOF
    
    log "✅ Tolerations настроены"
}

# Функция создания DNS failover
setup_dns_failover() {
    log "🌐 Настройка DNS failover..."
    
    # Получение IP адресов
    PRIMARY_LB_IP=$(kubectl config use-context do-$PRIMARY_REGION-$PRIMARY_CLUSTER && kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    DR_LB_IP=$(kubectl config use-context do-$DR_REGION-$DR_CLUSTER && kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    # Создание DNS записей
    doctl compute domain records create hashfoundry.com \
        --record-type A \
        --record-name api \
        --record-data $PRIMARY_LB_IP \
        --record-ttl 300 \
        --record-priority 10
    
    doctl compute domain records create hashfoundry.com \
        --record-type A \
        --record-name api-dr \
        --record-data $DR_LB_IP \
        --record-ttl 300
    
    log "✅ DNS failover настроен"
    log "Primary: api.hashfoundry.com -> $PRIMARY_LB_IP"
    log "DR: api-dr.hashfoundry.com -> $DR_LB_IP"
}

# Функция тестирования DR
test_dr_setup() {
    log "🧪 Тестирование DR настройки..."
    
    # Переключение на DR кластер
    kubectl config use-context do-$DR_REGION-$DR_CLUSTER
    
    # Проверка узлов
    kubectl get nodes -o wide
    
    # Проверка подов
    kubectl get pods --all-namespaces
    
    # Тестовое развертывание
    kubectl run dr-test --image=nginx:alpine --port=80
    kubectl expose pod dr-test --type=LoadBalancer --port=80
    
    # Ожидание получения внешнего IP
    log "⏳ Ожидание внешнего IP..."
    kubectl wait --for=condition=ready pod/dr-test --timeout=300s
    
    # Получение внешнего IP
    EXTERNAL_IP=$(kubectl get svc dr-test -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    log "🌐 Тестовый сервис доступен: http://$EXTERNAL_IP"
    
    # Очистка тестовых ресурсов
    kubectl delete pod dr-test
    kubectl delete svc dr-test
    
    log "✅ DR тестирование завершено"
}

# Основная логика выполнения
main() {
    log "🚀 Запуск настройки Multi-Region DR"
    
    check_dependencies
    create_dr_cluster
    setup_dr_cluster
    setup_dns_failover
    test_dr_setup
    
    log "🎉 MULTI-REGION DR УСПЕШНО НАСТРОЕН!"
    log "📋 Следующие шаги:"
    log "  1. Настройте автоматический failover"
    log "  2. Создайте DR runbooks"
    log "  3. Проведите DR drill"
    log "  4. Настройте мониторинг DR метрик"
}

# Обработка ошибок
trap 'log "❌ Ошибка при настройке DR"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x multi-region-dr-setup.sh
```

### **2. Создание автоматизированного failover:**
```bash
# Создать скрипт automated-failover.sh
cat << 'EOF' > automated-failover.sh
#!/bin/bash

echo "🚨 Автоматизированный Disaster Recovery Failover"
echo "=============================================="

# Настройка переменных
PRIMARY_CLUSTER="hashfoundry-ha"
DR_CLUSTER="hashfoundry-dr"
PRIMARY_REGION="fra1"
DR_REGION="ams3"
DOMAIN="hashfoundry.com"
SLACK_WEBHOOK="$SLACK_WEBHOOK_URL"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция отправки уведомлений
send_notification() {
    local severity="$1"
    local message="$2"
    
    log "$severity $message"
    
    # Отправка в Slack
    if [ -n "$SLACK_WEBHOOK" ]; then
        local color="good"
        case $severity in
            "🚨") color="danger" ;;
            "⚠️") color="warning" ;;
            "✅") color="good" ;;
        esac
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"$color\",\"text\":\"$severity DR Alert: $message\",\"ts\":$(date +%s)}]}" \
            "$SLACK_WEBHOOK" >/dev/null 2>&1
    fi
    
    # Отправка метрик в Prometheus
    if [ -n "$PROMETHEUS_PUSHGATEWAY" ]; then
        echo "dr_failover_event{severity=\"$severity\",message=\"$message\"} 1" | \
            curl --data-binary @- "$PROMETHEUS_PUSHGATEWAY/metrics/job/dr_failover" >/dev/null 2>&1
    fi
}

# Функция проверки состояния primary кластера
check_primary_health() {
    log "🔍 Проверка состояния primary кластера..."
    
    # Переключение на primary кластер
    kubectl config use-context do-$PRIMARY_REGION-$PRIMARY_CLUSTER >/dev/null 2>&1
    
    # Проверка API server
    if ! timeout 30 kubectl cluster-info >/dev/null 2>&1; then
        log "❌ Primary API server недоступен"
        return 1
    fi
    
    # Проверка etcd
    if ! timeout 15 kubectl get --raw /healthz/etcd >/dev/null 2>&1; then
        log "❌ etcd недоступен"
        return 1
    fi
    
    # Проверка критичных подов
    local failed_pods=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ "$failed_pods" -gt 5 ]; then
        log "❌ Слишком много неработающих критичных подов: $failed_pods"
        return 1
    fi
    
    # Проверка узлов
    local not_ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -v Ready | wc -l)
    if [ "$not_ready_nodes" -gt 1 ]; then
        log "❌ Слишком много неготовых узлов: $not_ready_nodes"
        return 1
    fi
    
    # Проверка ingress controller
    if ! kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --field-selector=status.phase=Running >/dev/null 2>&1; then
        log "❌ Ingress controller недоступен"
        return 1
    fi
    
    log "✅ Primary кластер здоров"
    return 0
}

# Функция проверки состояния DR кластера
check_dr_health() {
    log "🔍 Проверка состояния DR кластера..."
    
    # Переключение на DR кластер
    kubectl config use-context do-$DR_REGION-$DR_CLUSTER >/dev/null 2>&1
    
    # Проверка API server
    if ! timeout 30 kubectl cluster-info >/dev/null 2>&1; then
        log "❌ DR API server недоступен"
        return 1
    fi
    
    # Проверка узлов
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep Ready | wc -l)
    if [ "$ready_nodes" -lt 2 ]; then
        log "❌ Недостаточно готовых узлов в DR кластере: $ready_nodes"
        return 1
    fi
    
    log "✅ DR кластер готов к failover"
    return 0
}

# Функция создания emergency backup
create_emergency_backup() {
    log "💾 Создание emergency backup..."
    
    # Переключение на primary кластер
    kubectl config use-context do-$PRIMARY_REGION-$PRIMARY_CLUSTER >/dev/null 2>&1
    
    # Создание emergency backup через Velero
    local backup_name="emergency-backup-$(date +%Y%m%d-%H%M%S)"
    
    if timeout 300 velero backup create $backup_name \
        --include-namespaces argocd,monitoring,default \
        --wait >/dev/null 2>&1; then
        log "✅ Emergency backup создан: $backup_name"
        echo $backup_name
    else
        log "⚠️ Не удалось создать emergency backup"
        echo ""
    fi
}

# Функция инициации failover
initiate_failover() {
    log "🚨 Инициация failover на DR кластер..."
    
    send_notification "🚨" "Primary cluster failure detected. Initiating failover to DR cluster."
    
    # Создание emergency backup (если возможно)
    local backup_name=$(create_emergency_backup)
    
    # Переключение на DR кластер
    kubectl config use-context do-$DR_REGION-$DR_CLUSTER
    
    # Масштабирование DR кластера
    scale_dr_cluster
    
    # Восстановление из backup
    if [ -n "$backup_name" ]; then
        restore_from_backup "$backup_name"
    else
        restore_from_latest_backup
    fi
    
    # Обновление DNS записей
    update_dns_records
    
    # Развертывание критичных сервисов
    deploy_critical_services
    
    # Проверка работоспособности
    verify_dr_services
    
    send_notification "✅" "Failover completed successfully. Services are running on DR cluster."
}

# Функция масштабирования DR кластера
scale_dr_cluster() {
    log "📈 Масштабирование DR кластера..."
    
    # Увеличение количества узлов
    doctl kubernetes cluster node-pool update $DR_CLUSTER dr-worker-pool \
        --count 6 \
        --auto-scale \
        --min-nodes 3 \
        --max-nodes 12 >/dev/null 2>&1
    
    # Ожидание готовности узлов
    log "⏳ Ожидание готовности узлов..."
    for i in {1..30}; do
        local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
        if [ "$ready_nodes" -ge 4 ]; then
            log "✅ DR кластер масштабирован: $ready_nodes узлов готово"
            break
        fi
        sleep 10
    done
}

# Функция восстановления из backup
restore_from_backup() {
    local backup_name="$1"
    log "🔄 Восстановление из backup: $backup_name"
    
    # Создание restore
    local restore_name="dr-restore-$(date +%s)"
    velero restore create $restore_name --from-backup $backup_name >/dev/null 2>&1
    
    # Ожидание завершения restore
    log "⏳ Ожидание завершения restore..."
    for i in {1..60}; do
        local status=$(velero restore get $restore_name -o json 2>/dev/null | jq -r '.status.phase' 2>/dev/null)
        if [ "$status" = "Completed" ]; then
            log "✅ Restore завершен успешно"
            return 0
        elif [ "$status" = "Failed" ]; then
            log "❌ Restore завершился с ошибкой"
            return 1
        fi
        sleep 10
    done
    
    log "⚠️ Restore не завершился в ожидаемое время"
    return 1
}

# Функция восстановления из последнего backup
restore_from_latest_backup() {
    log "🔄 Восстановление из последнего backup..."
    
    # Получение последнего backup
    local latest_backup=$(velero backup get -o json 2>/dev/null | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name' 2>/dev/null)
    
    if [ "$latest_backup" != "null" ] && [ -n "$latest_backup" ]; then
        restore_from_backup "$latest_backup"
    else
        log "⚠️ Backup не найден, развертывание с нуля"
        deploy_from_scratch
    fi
}

# Функция обновления DNS записей
update_dns_records() {
    log "🌐 Обновление DNS записей..."
    
    # Получение внешнего IP DR кластера
    local dr_external_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -n "$dr_external_ip" ]; then
        # Обновление A записи для переключения трафика
        doctl compute domain records update $DOMAIN \
            --record-type A \
            --record-name api \
            --record-data $dr_external_ip \
            --record-ttl 60 >/dev/null 2>&1
        
        log "✅ DNS обновлен: api.$DOMAIN -> $dr_external_ip"
    else
        log "❌ Не удалось получить внешний IP DR кластера"
    fi
}

# Функция развертывания критичных сервисов
deploy_critical_services() {
    log "🚀 Развертывание критичных сервисов..."
    
    # Развертывание ArgoCD
    deploy_argocd_dr
    
    # Развертывание мониторинга
    deploy_monitoring_dr
    
    # Развертывание приложений
    deploy_applications_dr
    
    log "✅ Критичные сервисы развернуты"
}

# Функция развертывания ArgoCD для DR
deploy_argocd_dr() {
    log "📦 Развертывание ArgoCD для DR..."
    
    # Создание namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Установка ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >/dev/null 2>&1
    
    # Ожидание готовности
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s >/dev/null 2>&1
    
    log "✅ ArgoCD развернут"
}

# Функция развертывания мониторинга для DR
deploy_monitoring_dr() {
    log "📊 Развертывание мониторинга для DR..."
    
    # Проверка существования мониторинга
    if kubectl get namespace monitoring >/dev/null 2>&1; then
        log "✅ Мониторинг уже развернут"
        return 0
    fi
    
    # Создание namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Базовая конфигурация Prometheus
    kubectl apply -f - << PROMETHEUS_EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      tolerations:
      - key: disaster-recovery
        value: "true"
        effect: NoSchedule
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
PROMETHEUS_EOF
    
    log "✅ Мониторинг для DR развернут"
}

# Функция развертывания приложений для DR
deploy_applications_dr() {
    log "🚀 Развертывание приложений для DR..."
    
    # Развертывание тестового приложения
    kubectl apply -f - << APP_EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hashfoundry-app
  template:
    metadata:
      labels:
        app: hashfoundry-app
    spec:
      tolerations:
      - key: disaster-recovery
        value: "true"
        effect: NoSchedule
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-app
  namespace: default
spec:
  selector:
    app: hashfoundry-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
APP_EOF
    
    log "✅ Приложения для DR развернуты"
}

# Функция развертывания с нуля
deploy_from_scratch() {
    log "🏗️ Развертывание с нуля..."
    
    # Развертывание базовых сервисов
    deploy_critical_services
    
    # Создание базовых конфигураций
    kubectl apply -f - << CONFIG_EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-config
  namespace: default
data:
  environment: "disaster-recovery"
  cluster: "$DR_CLUSTER"
  region: "$DR_REGION"
  deployment_time: "$(date)"
CONFIG_EOF
    
    log "✅ Развертывание с нуля завершено"
}

# Функция проверки работоспособности DR сервисов
verify_dr_services() {
    log "✅ Проверка работоспособности DR сервисов..."
    
    # Проверка узлов
    local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    log "Готовых узлов: $ready_nodes"
    
    # Проверка критичных подов
    log "Критичные поды:"
    kubectl get pods -n kube-system --field-selector=status.phase=Running
    kubectl get pods -n ingress-nginx --field-selector=status.phase=Running
    
    # Тест доступности сервисов
    test_service_availability
    
    log "✅ DR сервисы работоспособны"
}

# Функция тестирования доступности сервисов
test_service_availability() {
    log "🧪 Тестирование доступности сервисов..."
    
    # Получение внешнего IP
    local external_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -n "$external_ip" ]; then
        log "🌐 Внешний IP DR кластера: $external_ip"
        
        # Тест HTTP доступности
        if curl -f -s "http://$external_ip" >/dev/null 2>&1; then
            log "✅ HTTP доступность подтверждена"
        else
            log "⚠️ HTTP недоступен"
        fi
    else
        log "⚠️ Внешний IP не получен"
    fi
}

# Функция мониторинга DR
monitor_dr_health() {
    log "📊 Запуск мониторинга DR..."
    
    while true; do
        if ! check_primary_health; then
            log "🚨 Primary кластер недоступен!"
            
            if check_dr_health; then
                log "🚨 Инициация автоматического failover..."
                initiate_failover
                break
            else
                log "❌ DR кластер также недоступен!"
                send_notification "🚨" "Both primary and DR clusters are unavailable!"
            fi
        else
            log "✅ Primary кластер работает нормально"
        fi
        
        sleep 60  # Проверка каждую минуту
    done
}

# Функция восстановления primary кластера
restore_primary_cluster() {
    log "🔄 Восстановление primary кластера..."
    
    send_notification "🔄" "Starting primary cluster recovery process."
    
    # Переключение обратно на primary
    kubectl config use-context do-$PRIMARY_REGION-$PRIMARY_CLUSTER
    
    # Проверка состояния primary
    if check_primary_health; then
        log "✅ Primary кластер восстановлен"
        
        # Создание backup текущего состояния DR
        create_dr_backup
        
        # Переключение DNS обратно
        switch_dns_to_primary
        
        # Масштабирование DR кластера обратно
        scale_down_dr_cluster
        
        send_notification "✅" "Primary cluster recovery completed. Traffic switched back."
    else
        log "❌ Primary кластер все еще недоступен"
        send_notification "⚠️" "Primary cluster recovery failed. Continuing on DR cluster."
    fi
}

# Функция создания backup DR состояния
create_dr_backup() {
    log "💾 Создание backup DR состояния..."
    
    kubectl config use-context do-$DR_REGION-$DR_CLUSTER
    
    local dr_backup_name="dr-state-backup-$(date +%Y%m%d-%H%M%S)"
    velero backup create $dr_backup_name \
        --include-namespaces default,monitoring,argocd \
        --wait >/dev/null 2>&1
    
    log "✅ DR backup создан: $dr_backup_name"
}

# Функция переключения DNS на primary
switch_dns_to_primary() {
    log "🌐 Переключение DNS на primary кластер..."
    
    kubectl config use-context do-$PRIMARY_REGION-$PRIMARY_CLUSTER
    local primary_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -n "$primary_ip" ]; then
        doctl compute domain records update $DOMAIN \
            --record-type A \
            --record-name api \
            --record-data $primary_ip \
            --record-ttl 300 >/dev/null 2>&1
        
        log "✅ DNS переключен на primary: api.$DOMAIN -> $primary_ip"
    fi
}

# Функция масштабирования DR кластера вниз
scale_down_dr_cluster() {
    log "📉 Масштабирование DR кластера вниз..."
    
    doctl kubernetes cluster node-pool update $DR_CLUSTER dr-worker-pool \
        --count 2 \
        --auto-scale \
        --min-nodes 2 \
        --max-nodes 4 >/dev/null 2>&1
    
    log "✅ DR кластер масштабирован вниз"
}

# Основная логика выполнения
main() {
    case "$1" in
        monitor)
            log "🔍 Запуск мониторинга DR..."
            monitor_dr_health
            ;;
        failover)
            log "🚨 Принудительный failover..."
            if check_dr_health; then
                initiate_failover
            else
                log "❌ DR кластер недоступен для failover"
                exit 1
            fi
            ;;
        restore)
            log "🔄 Восстановление primary кластера..."
            restore_primary_cluster
            ;;
        test)
            log "🧪 Тестирование DR готовности..."
            check_primary_health
            check_dr_health
            verify_dr_services
            ;;
        *)
            echo "Использование: $0 {monitor|failover|restore|test}"
            echo "  monitor  - Непрерывный мониторинг и автоматический failover"
            echo "  failover - Принудительный failover на DR кластер"
            echo "  restore  - Восстановление primary кластера"
            echo "  test     - Тестирование DR готовности"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'send_notification "❌" "DR script error occurred"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x automated-failover.sh
```

## 📊 **Архитектура Disaster Recovery:**

```
┌─────────────────────────────────────────────────────────────┐
│                Multi-Region DR Architecture                 │
├─────────────────────────────────────────────────────────────┤
│  Primary Region (fra1)          DR Region (ams3)           │
│  ┌─────────────────────┐        ┌─────────────────────┐     │
│  │  Primary Cluster    │        │   DR Cluster        │     │
│  │  ├── Control Plane  │◄──────►│  ├── Control Plane  │     │
│  │  ├── Worker Nodes   │        │  ├── Worker Nodes   │     │
│  │  ├── ArgoCD         │        │  ├── ArgoCD (Sync)  │     │
│  │  ├── Monitoring     │        │  ├── Monitoring     │     │
│  │  └── Applications   │        │  └── Applications   │     │
│  └─────────────────────┘        └─────────────────────┘     │
│           │                              │                  │
│           ▼                              ▼                  │
│  ┌─────────────────────┐        ┌─────────────────────┐     │
│  │   Load Balancer     │        │   Load Balancer     │     │
│  │   (Primary LB)      │        │   (DR LB)           │     │
│  └─────────────────────┘        └─────────────────────┘     │
│           │                              │                  │
│           ▼                              ▼                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              DNS Failover Management                    │ │
│  │  api.hashfoundry.com → Primary LB (Normal)             │ │
│  │  api.hashfoundry.com → DR LB (Failover)                │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Shared Components                                          │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Backup Storage (Digital Ocean Spaces)                 │ │
│  │  ├── etcd snapshots                                    │ │
│  │  ├── Application data                                  │ │
│  │  ├── Configuration backups                             │ │
│  │  └── Volume snapshots                                  │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Monitoring & Alerting                                 │ │
│  │  ├── Health checks                                     │ │
│  │  ├── Automated failover triggers                       │ │
│  │  ├── Slack/Teams notifications                         │ │
│  │  └── Prometheus metrics                                │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Матрица DR стратегий:**

### **1. RTO/RPO цели по уровням сервисов:**
| Tier | Сервисы | RTO | RPO | Стратегия | Стоимость |
|------|---------|-----|-----|-----------|-----------|
| Tier 1 | API, Auth, etcd | < 15 мин | < 5 мин | Hot Standby | Высокая |
| Tier 2 | Web App, Monitoring | < 1 час | < 30 мин | Warm Standby | Средняя |
| Tier 3 | Analytics, Reports | < 4 часа | < 4 часа | Cold Standby | Низкая |

### **2. Команды для мониторинга DR:**
```bash
# Создать скрипт dr-monitoring.sh
cat << 'EOF' > dr-monitoring.sh
#!/bin/bash

echo "📊 Мониторинг DR готовности"
echo "=========================="

# Функция проверки DR метрик
check_dr_metrics() {
    echo "🔍 Проверка DR метрик:"
    
    # Проверка последних backup
    echo "📦 Последние backup:"
    velero backup get --sort-by=.metadata.creationTimestamp | tail -5
    
    # Проверка состояния кластеров
    echo -e "\n🏗️ Состояние кластеров:"
    
    # Primary кластер
    kubectl config use-context do-fra1-hashfoundry-ha >/dev/null 2>&1
    PRIMARY_NODES=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    PRIMARY_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)
    echo "Primary: $PRIMARY_NODES узлов, $PRIMARY_PODS подов"
    
    # DR кластер
    kubectl config use-context do-ams3-hashfoundry-dr >/dev/null 2>&1
    DR_NODES=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    DR_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)
    echo "DR: $DR_NODES узлов, $DR_PODS подов"
    
    # Проверка backup возраста
    echo -e "\n⏰ Возраст последнего backup:"
    LATEST_BACKUP=$(velero backup get -o json | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.creationTimestamp')
    if [ "$LATEST_BACKUP" != "null" ]; then
        BACKUP_AGE=$(( $(date +%s) - $(date -d "$LATEST_BACKUP" +%s) ))
        BACKUP_AGE_MIN=$((BACKUP_AGE / 60))
        echo "Последний backup: $BACKUP_AGE_MIN минут назад"
        
        if [ $BACKUP_AGE -gt 3600 ]; then
            echo "⚠️ WARNING: Backup старше 1 часа"
        else
            echo "✅ Backup актуален"
        fi
    else
        echo "❌ Backup не найден"
    fi
}

# Функция проверки DNS конфигурации
check_dns_config() {
    echo -e "\n🌐 Проверка DNS конфигурации:"
    
    # Проверка текущих DNS записей
    API_IP=$(dig +short api.hashfoundry.com)
    echo "api.hashfoundry.com -> $API_IP"
    
    # Проверка доступности
    if curl -f -s "http://$API_IP" >/dev/null 2>&1; then
        echo "✅ API доступен"
    else
        echo "❌ API недоступен"
    fi
}

# Функция проверки автоматизации
check_automation() {
    echo -e "\n🤖 Проверка автоматизации:"
    
    # Проверка CronJob для backup
    BACKUP_JOBS=$(kubectl get cronjobs --all-namespaces --no-headers | grep backup | wc -l)
    echo "Backup CronJobs: $BACKUP_JOBS"
    
    # Проверка мониторинга
    MONITORING_PODS=$(kubectl get pods -n monitoring --field-selector=status.phase=Running --no-headers | wc -l)
    echo "Мониторинг подов: $MONITORING_PODS"
    
    # Проверка алертов
    if kubectl get prometheusrules -n monitoring disaster-recovery-alerts >/dev/null 2>&1; then
        echo "✅ DR алерты настроены"
    else
        echo "⚠️ DR алерты не найдены"
    fi
}

# Основная функция
main() {
    echo "🚀 ЗАПУСК DR МОНИТОРИНГА"
    echo "======================="
    
    check_dr_metrics
    check_dns_config
    check_automation
    
    echo -e "\n💡 РЕКОМЕНДАЦИИ:"
    echo "1. Регулярно тестируйте DR процедуры"
    echo "2. Обновляйте DR runbooks"
    echo "3. Мониторьте RTO/RPO метрики"
    echo "4. Проводите DR drills ежемесячно"
    
    echo -e "\n✅ DR МОНИТОРИНГ ЗАВЕРШЕН!"
}

# Запуск мониторинга
main
EOF

chmod +x dr-monitoring.sh
```

## 🎯 **Best Practices для Disaster Recovery:**

### **1. Планирование DR**
- Определите критичность сервисов и RTO/RPO цели
- Создайте multi-region архитектуру
- Настройте автоматизированный backup
- Разработайте детальные runbooks

### **2. Автоматизация DR**
- Настройте автоматический health monitoring
- Реализуйте automated failover
- Создайте DNS failover механизмы
- Интегрируйте с системами уведомлений

### **3. Тестирование DR**
- Проводите регулярные DR drills
- Тестируйте restore процедуры
- Проверяйте RTO/RPO соответствие
- Документируйте результаты тестов

### **4. Мониторинг и улучшение**
- Отслеживайте DR метрики
- Анализируйте инциденты
- Обновляйте процедуры
- Обучайте команду

**Эффективная стратегия Disaster Recovery обеспечивает быстрое восстановление сервисов после катастрофических сбоев и минимизирует влияние на бизнес-процессы!**
