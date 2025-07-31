# 163. Какие инструменты использовать для резервного копирования Kubernetes?

## 🎯 **Что такое backup инструменты для Kubernetes?**

**Backup инструменты для Kubernetes** — это специализированные решения для создания резервных копий различных компонентов кластера, включая etcd, persistent volumes, конфигурации приложений и метаданные, обеспечивающие возможность полного восстановления кластера и приложений в случае сбоев или катастроф.

## 🏗️ **Основные категории backup инструментов:**

### **1. Cluster-level инструменты (Уровень кластера)**
- **Velero** - CNCF проект для backup кластера
- **Kasten K10** - Enterprise решение от Veeam
- **Portworx PX-Backup** - Backup для контейнерных данных
- **Trilio for Kubernetes** - Комплексное backup решение

### **2. Application-level инструменты (Уровень приложений)**
- **Stash** - Kubernetes native backup оператор
- **Restic** - Быстрый и безопасный backup
- **Kanister** - Framework для application-aware backup
- **Custom operators** - Специализированные операторы

### **3. Storage-level инструменты (Уровень хранилища)**
- **CSI Snapshots** - Стандартные снимки томов
- **Cloud provider snapshots** - Нативные снимки провайдера
- **Storage vendor tools** - Инструменты производителей СХД
- **Volume backup tools** - Специализированные решения

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих backup решений:**
```bash
# Проверка установленных backup инструментов
kubectl get pods --all-namespaces | grep -E "(velero|backup|stash|kasten)"

# Проверка CRDs для backup
kubectl get crd | grep -E "(backup|restore|snapshot|velero)"

# Проверка storage classes для snapshots
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,SNAPSHOTS:.allowVolumeExpansion

# Анализ существующих PV для backup
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage,STORAGECLASS:.spec.storageClassName,STATUS:.status.phase
```

### **2. Мониторинг backup возможностей:**
```bash
# Проверка CSI драйверов с поддержкой snapshots
kubectl get csidriver -o custom-columns=NAME:.metadata.name,SNAPSHOTS:.spec.volumeLifecycleModes

# Анализ VolumeSnapshotClass
kubectl get volumesnapshotclass

# Проверка backup namespace и ресурсов
kubectl get all -n velero 2>/dev/null || echo "Velero не установлен"
kubectl get all -n kasten-io 2>/dev/null || echo "Kasten K10 не установлен"
```

### **3. Проверка backup готовности HA кластера:**
```bash
# Анализ критичных приложений для backup
kubectl get deployments --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas

# Проверка StatefulSets с persistent storage
kubectl get statefulsets --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,STORAGE:.spec.volumeClaimTemplates[0].spec.resources.requests.storage

# Анализ ArgoCD приложений для backup
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

## 🔄 **Демонстрация установки и настройки backup инструментов:**

### **1. Установка и настройка Velero для HA кластера:**
```bash
# Создать скрипт velero-ha-setup.sh
cat << 'EOF' > velero-ha-setup.sh
#!/bin/bash

echo "🚀 Установка Velero для HA кластера HashFoundry"
echo "=============================================="

# Настройка переменных
VELERO_VERSION="v1.12.1"
BACKUP_BUCKET="hashfoundry-backup"
REGION="fra1"
SPACES_ENDPOINT="https://fra1.digitaloceanspaces.com"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция проверки зависимостей
check_dependencies() {
    log "🔍 Проверка зависимостей..."
    
    # Проверка kubectl
    if ! command -v kubectl &> /dev/null; then
        log "❌ kubectl не найден"
        exit 1
    fi
    
    # Проверка доступа к кластеру
    if ! kubectl cluster-info &> /dev/null; then
        log "❌ Нет доступа к кластеру"
        exit 1
    fi
    
    # Проверка переменных окружения
    if [ -z "$DO_SPACES_ACCESS_KEY" ] || [ -z "$DO_SPACES_SECRET_KEY" ]; then
        log "❌ Не установлены переменные DO_SPACES_ACCESS_KEY и DO_SPACES_SECRET_KEY"
        exit 1
    fi
    
    log "✅ Все зависимости проверены"
}

# Функция установки Velero CLI
install_velero_cli() {
    log "📥 Установка Velero CLI..."
    
    # Скачивание Velero
    wget -q https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz
    
    # Извлечение и установка
    tar -xzf velero-${VELERO_VERSION}-linux-amd64.tar.gz
    sudo mv velero-${VELERO_VERSION}-linux-amd64/velero /usr/local/bin/
    
    # Очистка
    rm -rf velero-${VELERO_VERSION}-linux-amd64*
    
    # Проверка установки
    velero version --client-only
    log "✅ Velero CLI установлен"
}

# Функция создания credentials
create_credentials() {
    log "🔑 Создание credentials файла..."
    
    cat > /tmp/credentials-velero << CRED_EOF
[default]
aws_access_key_id=${DO_SPACES_ACCESS_KEY}
aws_secret_access_key=${DO_SPACES_SECRET_KEY}
CRED_EOF
    
    log "✅ Credentials файл создан"
}

# Функция установки Velero в кластер
install_velero_cluster() {
    log "⚙️ Установка Velero в кластер..."
    
    # Установка Velero с плагинами для Digital Ocean
    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.8.1,digitalocean/velero-plugin:v1.1.0 \
        --bucket $BACKUP_BUCKET \
        --secret-file /tmp/credentials-velero \
        --backup-location-config region=$REGION,s3ForcePathStyle="true",s3Url=$SPACES_ENDPOINT \
        --snapshot-location-config region=$REGION \
        --use-volume-snapshots=true \
        --use-node-agent
    
    if [ $? -eq 0 ]; then
        log "✅ Velero успешно установлен"
    else
        log "❌ Ошибка установки Velero"
        exit 1
    fi
}

# Функция проверки установки
verify_installation() {
    log "🔍 Проверка установки Velero..."
    
    # Ожидание готовности подов
    log "⏳ Ожидание готовности подов..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero -n velero --timeout=300s
    
    # Проверка статуса
    kubectl get pods -n velero
    
    # Проверка backup location
    velero backup-location get
    
    # Проверка snapshot location
    velero snapshot-location get
    
    log "✅ Установка проверена"
}

# Функция создания backup политик
create_backup_policies() {
    log "📋 Создание backup политик..."
    
    # Ежедневный backup критичных namespace
    cat << POLICY_EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-critical-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
    - argocd
    - monitoring
    - default
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 720h
    metadata:
      labels:
        backup-type: critical
        cluster: hashfoundry-ha
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-full-backup
  namespace: velero
spec:
  schedule: "0 1 * * 0"
  template:
    includedNamespaces:
    - "*"
    excludedNamespaces:
    - kube-system
    - velero
    includedResources:
    - "*"
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 2160h
    metadata:
      labels:
        backup-type: full
        cluster: hashfoundry-ha
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: etcd-backup
  namespace: velero
spec:
  schedule: "0 */6 * * *"
  template:
    includedNamespaces:
    - kube-system
    includedResources:
    - secrets
    - configmaps
    labelSelector:
      matchLabels:
        component: etcd
    storageLocation: default
    ttl: 168h
    metadata:
      labels:
        backup-type: etcd
        cluster: hashfoundry-ha
POLICY_EOF
    
    log "✅ Backup политики созданы"
}

# Функция создания первого backup
create_initial_backup() {
    log "💾 Создание первого backup..."
    
    # Создание тестового backup
    velero backup create initial-ha-backup \
        --include-namespaces argocd,monitoring,default \
        --wait
    
    # Проверка статуса backup
    velero backup describe initial-ha-backup
    
    log "✅ Первый backup создан"
}

# Функция настройки мониторинга
setup_monitoring() {
    log "📊 Настройка мониторинга Velero..."
    
    # ServiceMonitor для Prometheus
    cat << MONITOR_EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: velero-metrics
  namespace: monitoring
  labels:
    app: velero
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: velero
  namespaceSelector:
    matchNames:
    - velero
  endpoints:
  - port: http-monitoring
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: velero-backup-alerts
  namespace: monitoring
spec:
  groups:
  - name: velero.rules
    rules:
    - alert: VeleroBackupFailed
      expr: velero_backup_failure_total > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Velero backup failed"
        description: "Velero backup {{ \$labels.schedule }} has failed"
    
    - alert: VeleroBackupTooOld
      expr: time() - velero_backup_last_successful_timestamp > 86400
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Velero backup is too old"
        description: "Last successful backup was more than 24 hours ago"
MONITOR_EOF
    
    log "✅ Мониторинг настроен"
}

# Функция очистки
cleanup() {
    log "🧹 Очистка временных файлов..."
    rm -f /tmp/credentials-velero
    log "✅ Очистка завершена"
}

# Основная логика выполнения
main() {
    log "🚀 Запуск установки Velero для HA кластера"
    
    check_dependencies
    install_velero_cli
    create_credentials
    install_velero_cluster
    verify_installation
    create_backup_policies
    create_initial_backup
    setup_monitoring
    cleanup
    
    log "🎉 VELERO УСПЕШНО УСТАНОВЛЕН И НАСТРОЕН!"
    log "📋 Следующие шаги:"
    log "  1. Проверьте backup: velero backup get"
    log "  2. Мониторьте через Grafana dashboard"
    log "  3. Протестируйте restore процедуру"
    log "  4. Настройте alerting в Slack/Teams"
}

# Обработка ошибок
trap 'log "❌ Ошибка при установке Velero"; cleanup; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x velero-ha-setup.sh
```

### **2. Установка и настройка Kasten K10:**
```bash
# Создать скрипт kasten-k10-ha-setup.sh
cat << 'EOF' > kasten-k10-ha-setup.sh
#!/bin/bash

echo "🔧 Установка Kasten K10 для HA кластера"
echo "======================================"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция проверки лицензии
check_license() {
    log "📄 Проверка лицензии Kasten K10..."
    
    # Проверка trial лицензии
    if [ -z "$KASTEN_LICENSE" ]; then
        log "⚠️ Используется trial лицензия (ограничение: 5 узлов)"
        KASTEN_LICENSE="trial"
    fi
    
    log "✅ Лицензия: $KASTEN_LICENSE"
}

# Функция установки Kasten K10
install_kasten() {
    log "📦 Установка Kasten K10..."
    
    # Добавление Helm репозитория
    helm repo add kasten https://charts.kasten.io/
    helm repo update
    
    # Создание namespace
    kubectl create namespace kasten-io --dry-run=client -o yaml | kubectl apply -f -
    
    # Создание secret для Digital Ocean Spaces
    kubectl create secret generic k10-do-spaces-secret \
        --namespace kasten-io \
        --from-literal=aws_access_key_id=${DO_SPACES_ACCESS_KEY} \
        --from-literal=aws_secret_access_key=${DO_SPACES_SECRET_KEY} \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Установка K10 с HA конфигурацией
    helm upgrade --install k10 kasten/k10 \
        --namespace kasten-io \
        --set global.persistence.storageClass=do-block-storage \
        --set auth.tokenAuth.enabled=true \
        --set clusterName=hashfoundry-ha \
        --set prometheus.server.enabled=true \
        --set prometheus.server.persistentVolume.enabled=true \
        --set prometheus.server.persistentVolume.size=20Gi \
        --set prometheus.server.persistentVolume.storageClass=do-block-storage \
        --set grafana.enabled=true \
        --set grafana.persistence.enabled=true \
        --set grafana.persistence.size=10Gi \
        --set grafana.persistence.storageClass=do-block-storage \
        --set kanisterPodCustomLabels.environment=production \
        --set kanisterPodCustomLabels.cluster=hashfoundry-ha
    
    log "✅ Kasten K10 установлен"
}

# Функция ожидания готовности
wait_for_ready() {
    log "⏳ Ожидание готовности K10..."
    
    # Ожидание готовности подов
    kubectl wait --for=condition=ready pod -l app=k10-k10 -n kasten-io --timeout=600s
    
    # Проверка статуса
    kubectl get pods -n kasten-io
    
    log "✅ K10 готов к работе"
}

# Функция создания Location Profile
create_location_profile() {
    log "🗄️ Создание Location Profile..."
    
    cat << PROFILE_EOF | kubectl apply -f -
apiVersion: config.kio.kasten.io/v1alpha1
kind: Profile
metadata:
  name: do-spaces-profile
  namespace: kasten-io
spec:
  type: Location
  locationSpec:
    credential:
      secretType: AwsAccessKey
      secret:
        apiVersion: v1
        kind: Secret
        name: k10-do-spaces-secret
        namespace: kasten-io
    type: ObjectStore
    objectStore:
      name: hashfoundry-backup
      objectStoreType: S3
      region: fra1
      endpoint: https://fra1.digitaloceanspaces.com
      skipSSLVerify: false
---
apiVersion: config.kio.kasten.io/v1alpha1
kind: Profile
metadata:
  name: do-volume-snapshot-profile
  namespace: kasten-io
spec:
  type: Location
  locationSpec:
    type: VolumeSnapshot
    volumeSnapshot:
      type: CSI
PROFILE_EOF
    
    log "✅ Location Profile создан"
}

# Функция создания backup политик
create_backup_policies() {
    log "📋 Создание backup политик..."
    
    # Политика для ArgoCD
    cat << POLICY_EOF | kubectl apply -f -
apiVersion: config.kio.kasten.io/v1alpha1
kind: Policy
metadata:
  name: argocd-backup-policy
  namespace: kasten-io
spec:
  comment: "Backup policy for ArgoCD applications"
  frequency: "@hourly"
  retention:
    hourly: 24
    daily: 7
    weekly: 4
    monthly: 12
  selector:
    matchExpressions:
    - key: k10.kasten.io/appNamespace
      operator: In
      values:
      - argocd
  actions:
  - action: backup
    backupParameters:
      profile:
        name: do-spaces-profile
        namespace: kasten-io
  - action: export
    exportParameters:
      frequency: "@daily"
      profile:
        name: do-spaces-profile
        namespace: kasten-io
      exportData:
        enabled: true
---
apiVersion: config.kio.kasten.io/v1alpha1
kind: Policy
metadata:
  name: monitoring-backup-policy
  namespace: kasten-io
spec:
  comment: "Backup policy for monitoring stack"
  frequency: "@daily"
  retention:
    daily: 14
    weekly: 8
    monthly: 6
  selector:
    matchExpressions:
    - key: k10.kasten.io/appNamespace
      operator: In
      values:
      - monitoring
  actions:
  - action: backup
    backupParameters:
      profile:
        name: do-spaces-profile
        namespace: kasten-io
  - action: export
    exportParameters:
      frequency: "@weekly"
      profile:
        name: do-spaces-profile
        namespace: kasten-io
      exportData:
        enabled: true
POLICY_EOF
    
    log "✅ Backup политики созданы"
}

# Функция получения токена доступа
get_access_token() {
    log "🔐 Получение токена доступа..."
    
    # Создание токена
    TOKEN=$(kubectl --namespace kasten-io create token k10-k10 --duration=24h)
    
    log "✅ Токен доступа создан"
    log "🌐 Для доступа к K10 Dashboard:"
    log "  1. Выполните: kubectl --namespace kasten-io port-forward service/gateway 8080:8000"
    log "  2. Откройте: http://127.0.0.1:8080/k10/#/"
    log "  3. Используйте токен: $TOKEN"
}

# Функция настройки Ingress
setup_ingress() {
    log "🌐 Настройка Ingress для K10..."
    
    cat << INGRESS_EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k10-ingress
  namespace: kasten-io
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - k10.hashfoundry.local
    secretName: k10-tls
  rules:
  - host: k10.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gateway
            port:
              number: 8000
INGRESS_EOF
    
    log "✅ Ingress настроен"
    log "🌐 K10 доступен по адресу: https://k10.hashfoundry.local"
}

# Функция создания первого backup
create_initial_backup() {
    log "💾 Создание первого backup..."
    
    # Ожидание готовности политик
    sleep 30
    
    # Запуск backup для ArgoCD
    cat << BACKUP_EOF | kubectl apply -f -
apiVersion: actions.kio.kasten.io/v1alpha1
kind: RunAction
metadata:
  name: initial-argocd-backup
  namespace: kasten-io
spec:
  subject:
    name: argocd-backup-policy
    namespace: kasten-io
    kind: Policy
    apiVersion: config.kio.kasten.io/v1alpha1
BACKUP_EOF
    
    log "✅ Первый backup запущен"
}

# Основная логика выполнения
main() {
    log "🚀 Запуск установки Kasten K10"
    
    check_license
    install_kasten
    wait_for_ready
    create_location_profile
    create_backup_policies
    get_access_token
    setup_ingress
    create_initial_backup
    
    log "🎉 KASTEN K10 УСПЕШНО УСТАНОВЛЕН!"
    log "📋 Следующие шаги:"
    log "  1. Откройте K10 Dashboard"
    log "  2. Настройте дополнительные политики"
    log "  3. Протестируйте restore"
    log "  4. Настройте мониторинг и алерты"
}

# Обработка ошибок
trap 'log "❌ Ошибка при установке Kasten K10"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x kasten-k10-ha-setup.sh
```

### **3. Установка и настройка Stash:**
```bash
# Создать скрипт stash-ha-setup.sh
cat << 'EOF' > stash-ha-setup.sh
#!/bin/bash

echo "📦 Установка Stash для HA кластера"
echo "================================="

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция установки Stash
install_stash() {
    log "📥 Установка Stash..."
    
    # Добавление Helm репозитория
    helm repo add appscode https://charts.appscode.com/stable/
    helm repo update
    
    # Установка Stash Community Edition
    helm upgrade --install stash appscode/stash \
        --namespace stash-system \
        --create-namespace \
        --set features.enterprise=false \
        --set stash-community.enabled=true \
        --set stash-enterprise.enabled=false
    
    log "✅ Stash установлен"
}

# Функция ожидания готовности
wait_for_ready() {
    log "⏳ Ожидание готовности Stash..."
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=stash -n stash-system --timeout=300s
    
    log "✅ Stash готов к работе"
}

# Функция создания repository
create_repositories() {
    log "🗄️ Создание repositories..."
    
    # Secret для Digital Ocean Spaces
    kubectl create secret generic do-spaces-secret \
        --namespace default \
        --from-literal=RESTIC_PASSWORD=hashfoundry-secure-password \
        --from-literal=AWS_ACCESS_KEY_ID=${DO_SPACES_ACCESS_KEY} \
        --from-literal=AWS_SECRET_ACCESS_KEY=${DO_SPACES_SECRET_KEY} \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Repository для приложений
    cat << REPO_EOF | kubectl apply -f -
apiVersion: stash.appscode.com/v1alpha1
kind: Repository
metadata:
  name: do-spaces-repo
  namespace: default
spec:
  backend:
    s3:
      endpoint: fra1.digitaloceanspaces.com
      bucket: hashfoundry-backup
      prefix: stash/default
      region: fra1
    storageSecretName: do-spaces-secret
---
apiVersion: stash.appscode.com/v1alpha1
kind: Repository
metadata:
  name: monitoring-repo
  namespace: monitoring
spec:
  backend:
    s3:
      endpoint: fra1.digitaloceanspaces.com
      bucket: hashfoundry-backup
      prefix: stash/monitoring
      region: fra1
    storageSecretName: monitoring-spaces-secret
---
apiVersion: stash.appscode.com/v1alpha1
kind: Repository
metadata:
  name: argocd-repo
  namespace: argocd
spec:
  backend:
    s3:
      endpoint: fra1.digitaloceanspaces.com
      bucket: hashfoundry-backup
      prefix: stash/argocd
      region: fra1
    storageSecretName: argocd-spaces-secret
REPO_EOF
    
    # Создание secrets для других namespace
    kubectl create secret generic monitoring-spaces-secret \
        --namespace monitoring \
        --from-literal=RESTIC_PASSWORD=hashfoundry-secure-password \
        --from-literal=AWS_ACCESS_KEY_ID=${DO_SPACES_ACCESS_KEY} \
        --from-literal=AWS_SECRET_ACCESS_KEY=${DO_SPACES_SECRET_KEY} \
        --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl create secret generic argocd-spaces-secret \
        --namespace argocd \
        --from-literal=RESTIC_PASSWORD=hashfoundry-secure-password \
        --from-literal=AWS_ACCESS_KEY_ID=${DO_SPACES_ACCESS_KEY} \
        --from-literal=AWS_SECRET_ACCESS_KEY=${DO_SPACES_SECRET_KEY} \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log "✅ Repositories созданы"
}

# Функция создания backup конфигураций
create_backup_configs() {
    log "📋 Создание backup конфигураций..."
    
    # BackupConfiguration для Prometheus
    cat << CONFIG_EOF | kubectl apply -f -
apiVersion: stash.appscode.com/v1beta1
kind: BackupConfiguration
metadata:
  name: prometheus-backup
  namespace: monitoring
spec:
  repository:
    name: monitoring-repo
  schedule: "0 */6 * * *"
  target:
    ref:
      apiVersion: apps/v1
      kind: StatefulSet
      name: prometheus-server
    volumeMounts:
    - name: storage-volume
      mountPath: /data
  retentionPolicy:
    name: keep-last-10
    keepLast: 10
    prune: true
---
apiVersion: stash.appscode.com/v1beta1
kind: BackupConfiguration
metadata:
  name: grafana-backup
  namespace: monitoring
spec:
  repository:
    name: monitoring-repo
  schedule: "0 2 * * *"
  target:
    ref:
      apiVersion: apps/v1
      kind: Deployment
      name: grafana
    volumeMounts:
    - name: storage
      mountPath: /var/lib/grafana
  retentionPolicy:
    name: keep-last-7
    keepLast: 7
    prune: true
---
apiVersion: stash.appscode.com/v1beta1
kind: BackupConfiguration
metadata:
  name: argocd-backup
  namespace: argocd
spec:
  repository:
    name: argocd-repo
  schedule: "0 */4 * * *"
  target:
    ref:
      apiVersion: apps/v1
      kind: StatefulSet
      name: argocd-application-controller
    volumeMounts:
    - name: argocd-repo-server-tls
      mountPath: /app/config/tls
  retentionPolicy:
    name: keep-last-12
    keepLast: 12
    prune: true
CONFIG_EOF
    
    log "✅ Backup конфигурации созданы"
}

# Функция создания первого backup
create_initial_backup() {
    log "💾 Создание первого backup..."
    
    # Ожидание готовности конфигураций
    sleep 30
    
    # Запуск backup для monitoring
    kubectl annotate backupconfiguration prometheus-backup -n monitoring \
        stash.appscode.com/trigger="$(date +%s)"
    
    log "✅ Первый backup запущен"
}

# Основная логика выполнения
main() {
    log "🚀 Запуск установки Stash"
    
    install_stash
    wait_for_ready
    create_repositories
    create_backup_configs
    create_initial_backup
    
    log "🎉 STASH УСПЕШНО УСТАНОВЛЕН!"
    log "📋 Следующие шаги:"
    log "  1. Проверьте backup: kubectl get backupsession --all-namespaces"
    log "  2. Мониторьте через kubectl get repository --all-namespaces"
    log "  3. Протестируйте restore"
    log "  4. Настройте дополнительные backup конфигурации"
}

# Обработка ошибок
trap 'log "❌ Ошибка при установке Stash"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x stash-ha-setup.sh
```

## 📊 **Архитектура backup инструментов:**

```
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes Backup Tools Ecosystem           │
├─────────────────────────────────────────────────────────────┤
│  Cluster Level (Infrastructure Backup)                     │
│  ├── Velero (CNCF)                                         │
│  │   ├── Namespace backup/restore                          │
│  │   ├── Volume snapshots                                  │
│  │   ├── Cross-cluster migration                           │
│  │   └── Disaster recovery                                 │
│  ├── Kasten K10 (Enterprise)                               │
│  │   ├── Application-aware backup                          │
│  │   ├── Policy management                                 │
│  │   ├── Compliance reporting                              │
│  │   └── Multi-cloud support                               │
│  └── Portworx PX-Backup                                    │
│      ├── Container-native backup                           │
│      ├── Application consistency                           │
│      └── Automated recovery                                │
├─────────────────────────────────────────────────────────────┤
│  Application Level (Data Backup)                           │
│  ├── Stash (Kubernetes Native)                             │
│  │   ├── CRD-based configuration                           │
│  │   ├── Restic backend                                    │
│  │   ├── Flexible scheduling                               │
│  │   └── Multiple storage backends                         │
│  ├── Kanister (Framework)                                  │
│  │   ├── Application-specific blueprints                   │
│  │   ├── Database-aware backup                             │
│  │   └── Custom backup workflows                           │
│  └── Custom Operators                                      │
│      ├── Application-specific logic                        │
│      ├── Vendor-specific integrations                      │
│      └── Custom backup strategies                          │
├─────────────────────────────────────────────────────────────┤
│  Storage Level (Volume Backup)                             │
│  ├── CSI Snapshots                                         │
│  │   ├── Kubernetes native                                 │
│  │   ├── Storage vendor agnostic                           │
│  │   └── Point-in-time recovery                            │
│  ├── Cloud Provider Snapshots                              │
│  │   ├── AWS EBS snapshots                                 │
│  │   ├── GCP Persistent Disk snapshots                     │
│  │   ├── Azure Disk snapshots                              │
│  │   └── DigitalOcean Volume snapshots                     │
│  └── Storage Vendor Tools                                  │
│      ├── NetApp Trident                                    │
│      ├── Pure Storage                                      │
│      └── Dell EMC                                          │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Матрица сравнения backup инструментов:**

### **1. Сравнение по функциональности:**
| Инструмент | Cluster Backup | App-Aware | Volume Snapshots | Cross-Cloud | Enterprise Features |
|------------|----------------|-----------|------------------|-------------|-------------------|
| Velero | ✅ Отлично | ⚠️ Базовый | ✅ Отлично | ✅ Отлично | ⚠️ Ограничено |
| Kasten K10 | ✅ Отлично | ✅ Отлично | ✅ Отлично | ✅ Отлично | ✅ Отлично |
| Stash | ⚠️ Ограничено | ✅ Хорошо | ⚠️ Базовый | ✅ Хорошо | ⚠️ Ограничено |
| Portworx | ✅ Хорошо | ✅ Отлично | ✅ Отлично | ✅ Хорошо | ✅ Хорошо |

### **2. Сравнение по стоимости и сложности:**
| Инструмент | Лицензия | Стоимость | Сложность установки | Обучение команды |
|------------|----------|-----------|---------------------|------------------|
| Velero | Open Source | Бесплатно | Низкая | Низкая |
| Kasten K10 | Commercial | Высокая | Средняя | Средняя |
| Stash | Open Source | Бесплатно | Средняя | Средняя |
| Portworx | Commercial | Высокая | Высокая | Высокая |

### **3. Команды для сравнения производительности:**
```bash
# Создать скрипт backup-tools-comparison.sh
cat << 'EOF' > backup-tools-comparison.sh
#!/bin/bash

echo "📊 Сравнение backup инструментов"
echo "==============================="

# Функция тестирования Velero
test_velero() {
    echo "🔍 Тестирование Velero:"
    
    if kubectl get ns velero >/dev/null 2>&1; then
        echo "✅ Velero установлен"
        
        # Время создания backup
        START_TIME=$(date +%s)
        velero backup create test-backup --include-namespaces default --wait >/dev/null 2>&1
        END_TIME=$(date +%s)
        BACKUP_TIME=$((END_TIME - START_TIME))
        
        # Размер backup
        BACKUP_SIZE=$(velero backup describe test-backup --details | grep "Total items" | awk '{print $3}')
        
        echo "  ⏱️ Время backup: ${BACKUP_TIME}s"
        echo "  📏 Объектов: $BACKUP_SIZE"
        
        # Очистка
        velero backup delete test-backup --confirm >/dev/null 2>&1
    else
        echo "❌ Velero не установлен"
    fi
}

# Функция тестирования Kasten K10
test_kasten() {
    echo "🔍 Тестирование Kasten K10:"
    
    if kubectl get ns kasten-io >/dev/null 2>&1; then
        echo "✅ Kasten K10 установлен"
        
        # Проверка политик
        POLICIES=$(kubectl get policies -n kasten-io --no-headers | wc -l)
        echo "  📋 Политик: $POLICIES"
        
        # Проверка backup jobs
        BACKUP_JOBS=$(kubectl get jobs -n kasten-io -l app=k10-k10 --no-headers | wc -l)
        echo "  🔄 Backup jobs: $BACKUP_JOBS"
    else
        echo "❌ Kasten K10 не установлен"
    fi
}

# Функция тестирования Stash
test_stash() {
    echo "🔍 Тестирование Stash:"
    
    if kubectl get ns stash-system >/dev/null 2>&1; then
        echo "✅ Stash установлен"
        
        # Проверка repositories
        REPOS=$(kubectl get repository --all-namespaces --no-headers | wc -l)
        echo "  🗄️ Repositories: $REPOS"
        
        # Проверка backup configurations
        CONFIGS=$(kubectl get backupconfiguration --all-namespaces --no-headers | wc -l)
        echo "  ⚙️ Backup configs: $CONFIGS"
        
        # Проверка последних backup sessions
        SESSIONS=$(kubectl get backupsession --all-namespaces --no-headers | wc -l)
        echo "  📦 Backup sessions: $SESSIONS"
    else
        echo "❌ Stash не установлен"
    fi
}

# Функция анализа ресурсов
analyze_resources() {
    echo -e "\n💾 Анализ использования ресурсов:"
    
    # Velero ресурсы
    if kubectl get ns velero >/dev/null 2>&1; then
        VELERO_CPU=$(kubectl top pods -n velero --no-headers 2>/dev/null | awk '{sum += $2} END {print sum "m"}' || echo "N/A")
        VELERO_MEM=$(kubectl top pods -n velero --no-headers 2>/dev/null | awk '{sum += $3} END {print sum "Mi"}' || echo "N/A")
        echo "  Velero - CPU: $VELERO_CPU, Memory: $VELERO_MEM"
    fi
    
    # Kasten K10 ресурсы
    if kubectl get ns kasten-io >/dev/null 2>&1; then
        KASTEN_CPU=$(kubectl top pods -n kasten-io --no-headers 2>/dev/null | awk '{sum += $2} END {print sum "m"}' || echo "N/A")
        KASTEN_MEM=$(kubectl top pods -n kasten-io --no-headers 2>/dev/null | awk '{sum += $3} END {print sum "Mi"}' || echo "N/A")
        echo "  Kasten K10 - CPU: $KASTEN_CPU, Memory: $KASTEN_MEM"
    fi
    
    # Stash ресурсы
    if kubectl get ns stash-system >/dev/null 2>&1; then
        STASH_CPU=$(kubectl top pods -n stash-system --no-headers 2>/dev/null | awk '{sum += $2} END {print sum "m"}' || echo "N/A")
        STASH_MEM=$(kubectl top pods -n stash-system --no-headers 2>/dev/null | awk '{sum += $3} END {print sum "Mi"}' || echo "N/A")
        echo "  Stash - CPU: $STASH_CPU, Memory: $STASH_MEM"
    fi
}

# Функция рекомендаций
provide_recommendations() {
    echo -e "\n💡 РЕКОМЕНДАЦИИ ПО ВЫБОРУ:"
    echo "=========================="
    
    echo "🎯 Для небольших кластеров (< 10 узлов):"
    echo "  - Velero + etcdctl для базового backup"
    echo "  - Stash для application data backup"
    
    echo -e "\n🏢 Для enterprise окружений:"
    echo "  - Kasten K10 для комплексного решения"
    echo "  - Velero для disaster recovery"
    
    echo -e "\n💰 Для cost-effective решений:"
    echo "  - Velero + Stash (open source)"
    echo "  - Custom scripts + CSI snapshots"
    
    echo -e "\n⚡ Для высокой производительности:"
    echo "  - Portworx PX-Backup"
    echo "  - Storage vendor native tools"
}

# Основная функция
main() {
    echo "🚀 ЗАПУСК СРАВНЕНИЯ BACKUP ИНСТРУМЕНТОВ"
    echo "======================================"
    
    test_velero
    echo
    test_kasten
    echo
    test_stash
    
    analyze_resources
    provide_recommendations
    
    echo -e "\n✅ СРАВНЕНИЕ ЗАВЕРШЕНО!"
}

# Запуск сравнения
main
EOF

chmod +x backup-tools-comparison.sh
```

## 🎯 **Best Practices для выбора backup инструментов:**

### **1. Критерии выбора**
- **Размер кластера**: количество узлов и приложений
- **Требования RTO/RPO**: время восстановления и потери данных
- **Бюджет**: стоимость лицензий и поддержки
- **Сложность**: уровень экспертизы команды

### **2. Стратегия многоуровневого backup**
- **Уровень 1**: etcd backup (критично)
- **Уровень 2**: Application data backup (важно)
- **Уровень 3**: Configuration backup (желательно)
- **Уровень 4**: Full cluster backup (периодически)

### **3. Мониторинг и автоматизация**
- Настройте автоматические backup расписания
- Мониторьте успешность backup операций
- Регулярно тестируйте restore процедуры
- Настройте alerting при сбоях backup

### **4. Интеграция с HA кластером**
- Используйте Digital Ocean Spaces для хранения
- Настройте backup для ArgoCD и monitoring stack
- Интегрируйте с Prometheus для мониторинга
- Настройте Grafana dashboards для визуализации

**Правильный выбор и настройка backup инструментов обеспечивает надежную защиту данных и быстрое восстановление HA кластера!**
