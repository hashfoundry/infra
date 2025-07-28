# 163. Какие инструменты использовать для резервного копирования Kubernetes?

## 🎯 Вопрос
Какие инструменты использовать для резервного копирования Kubernetes?

## 💡 Ответ

Для резервного копирования Kubernetes существует множество инструментов, каждый из которых решает определенные задачи: от backup etcd до полного восстановления кластера. Выбор инструмента зависит от требований к RTO/RPO, типов данных и архитектуры кластера.

### 🏗️ Архитектура backup инструментов

#### 1. **Схема backup экосистемы**
```
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes Backup Ecosystem                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Cluster   │  │ Application │  │   Data      │         │
│  │   Backup    │  │   Backup    │  │   Backup    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │    etcd     │  │   Velero    │  │   Kasten    │         │
│  │   Backup    │  │   Restic    │  │   Stash     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Классификация backup инструментов**
```yaml
# Классификация backup инструментов
backup_tools_classification:
  cluster_level:
    - "Velero (VMware)"
    - "Kasten K10 (Veeam)"
    - "Portworx PX-Backup"
    - "Trilio for Kubernetes"
  
  etcd_specific:
    - "etcdctl"
    - "etcd-operator"
    - "etcd-backup-restore"
    - "Kubernetes native backup"
  
  application_level:
    - "Stash (AppsCode)"
    - "Restic"
    - "Kanister (Kasten)"
    - "Custom backup operators"
  
  storage_level:
    - "Volume snapshots"
    - "CSI snapshots"
    - "Cloud provider snapshots"
    - "Storage vendor tools"
```

### 📊 Примеры из нашего кластера

#### Проверка текущих backup решений:
```bash
# Проверка установленных backup инструментов
kubectl get pods --all-namespaces | grep -E "(velero|backup|stash)"

# Проверка CRDs для backup
kubectl get crd | grep -E "(backup|restore|snapshot)"

# Проверка storage classes для snapshots
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,SNAPSHOTS:.allowVolumeExpansion
```

### 🚀 Velero - Универсальное решение

#### 1. **Установка и настройка Velero**
```yaml
# velero-installation.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: velero
---
# ServiceAccount для Velero
apiVersion: v1
kind: ServiceAccount
metadata:
  name: velero
  namespace: velero
---
# ClusterRoleBinding для Velero
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: velero
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: velero
  namespace: velero
---
# Secret для cloud credentials
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: velero
type: Opaque
data:
  cloud: <base64-encoded-credentials>
---
# BackupStorageLocation для Digital Ocean Spaces
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: hashfoundry-backup
    prefix: velero
  config:
    region: fra1
    s3ForcePathStyle: "true"
    s3Url: https://fra1.digitaloceanspaces.com
---
# VolumeSnapshotLocation для Digital Ocean
apiVersion: velero.io/v1
kind: VolumeSnapshotLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: digitalocean.com/velero
  config:
    region: fra1
```

#### 2. **Скрипт установки Velero**
```bash
#!/bin/bash
# velero-setup.sh

echo "🚀 Установка Velero для кластера hashfoundry-ha"

# Установка Velero CLI
echo "📥 Установка Velero CLI..."
VELERO_VERSION="v1.12.1"
wget https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz
tar -xzf velero-${VELERO_VERSION}-linux-amd64.tar.gz
sudo mv velero-${VELERO_VERSION}-linux-amd64/velero /usr/local/bin/
rm -rf velero-${VELERO_VERSION}-linux-amd64*

# Создание credentials файла для Digital Ocean
echo "🔑 Настройка credentials..."
cat > credentials-velero << EOF
[default]
aws_access_key_id=${DO_SPACES_ACCESS_KEY}
aws_secret_access_key=${DO_SPACES_SECRET_KEY}
EOF

# Установка Velero в кластер
echo "⚙️ Установка Velero в кластер..."
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.8.1,digitalocean/velero-plugin:v1.1.0 \
    --bucket hashfoundry-backup \
    --secret-file ./credentials-velero \
    --backup-location-config region=fra1,s3ForcePathStyle="true",s3Url=https://fra1.digitaloceanspaces.com \
    --snapshot-location-config region=fra1

# Проверка установки
echo "✅ Проверка установки Velero..."
kubectl get pods -n velero
velero version

# Создание первого backup
echo "💾 Создание тестового backup..."
velero backup create initial-backup --include-namespaces default

# Очистка временных файлов
rm credentials-velero

echo "✅ Velero успешно установлен!"
```

#### 3. **Конфигурация backup политик**
```yaml
# backup-schedule.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"                  # Каждый день в 2:00
  template:
    includedNamespaces:
    - default
    - production
    - monitoring
    excludedNamespaces:
    - kube-system
    - velero
    includedResources:
    - "*"
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 720h                            # 30 дней хранения
---
# Еженедельный полный backup
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-full-backup
  namespace: velero
spec:
  schedule: "0 1 * * 0"                  # Каждое воскресенье в 1:00
  template:
    includedNamespaces:
    - "*"
    includedResources:
    - "*"
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 2160h                           # 90 дней хранения
---
# Backup критичных приложений
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: critical-apps-backup
  namespace: velero
spec:
  schedule: "0 */6 * * *"                # Каждые 6 часов
  template:
    labelSelector:
      matchLabels:
        backup: critical
    includedResources:
    - "*"
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 168h                            # 7 дней хранения
```

### 🔧 Kasten K10 - Enterprise решение

#### 1. **Установка Kasten K10**
```yaml
# kasten-k10-installation.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kasten-io
---
# Helm values для Kasten K10
apiVersion: v1
kind: ConfigMap
metadata:
  name: k10-config
  namespace: kasten-io
data:
  values.yaml: |
    global:
      persistence:
        storageClass: fast-ssd
    auth:
      tokenAuth:
        enabled: true
    clusterName: hashfoundry-ha
    
    # Настройки для Digital Ocean
    kanisterPodCustomLabels:
      environment: production
      cluster: hashfoundry-ha
    
    # Настройки мониторинга
    prometheus:
      server:
        enabled: true
        persistentVolume:
          enabled: true
          size: 20Gi
          storageClass: fast-ssd
    
    # Настройки безопасности
    rbac:
      create: true
    
    serviceAccount:
      create: true
      name: k10-k10
---
# Location Profile для Digital Ocean Spaces
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
```

#### 2. **Скрипт установки Kasten K10**
```bash
#!/bin/bash
# kasten-k10-setup.sh

echo "🔧 Установка Kasten K10"

# Добавление Helm репозитория
echo "📦 Добавление Helm репозитория..."
helm repo add kasten https://charts.kasten.io/
helm repo update

# Создание namespace
kubectl create namespace kasten-io

# Создание secret для Digital Ocean Spaces
echo "🔑 Создание credentials..."
kubectl create secret generic k10-do-spaces-secret \
    --namespace kasten-io \
    --from-literal=aws_access_key_id=${DO_SPACES_ACCESS_KEY} \
    --from-literal=aws_secret_access_key=${DO_SPACES_SECRET_KEY}

# Установка K10
echo "⚙️ Установка Kasten K10..."
helm install k10 kasten/k10 \
    --namespace kasten-io \
    --set global.persistence.storageClass=fast-ssd \
    --set auth.tokenAuth.enabled=true \
    --set clusterName=hashfoundry-ha

# Ожидание готовности
echo "⏳ Ожидание готовности K10..."
kubectl wait --for=condition=ready pod -l app=k10-k10 -n kasten-io --timeout=300s

# Получение токена доступа
echo "🔐 Получение токена доступа..."
kubectl --namespace kasten-io create token k10-k10 --duration=24h

# Настройка port-forward для доступа к UI
echo "🌐 Настройка доступа к K10 Dashboard..."
echo "Выполните: kubectl --namespace kasten-io port-forward service/gateway 8080:8000"
echo "Затем откройте: http://127.0.0.1:8080/k10/#/"

echo "✅ Kasten K10 успешно установлен!"
```

### 📦 Stash - Backup оператор

#### 1. **Установка Stash**
```yaml
# stash-installation.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: stash-system
---
# Stash Operator
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stash-operator
  namespace: stash-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stash-operator
  template:
    metadata:
      labels:
        app: stash-operator
    spec:
      serviceAccountName: stash-operator
      containers:
      - name: operator
        image: appscode/stash:v0.32.0
        args:
        - run
        - --v=3
        env:
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
# Repository для хранения backup
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
      prefix: stash
      region: fra1
    storageSecretName: do-spaces-secret
---
# BackupConfiguration для приложения
apiVersion: stash.appscode.com/v1beta1
kind: BackupConfiguration
metadata:
  name: app-backup
  namespace: default
spec:
  repository:
    name: do-spaces-repo
  schedule: "*/30 * * * *"               # Каждые 30 минут
  target:
    ref:
      apiVersion: apps/v1
      kind: Deployment
      name: sample-app
    volumeMounts:
    - name: data
      mountPath: /data
  retentionPolicy:
    name: keep-last-5
    keepLast: 5
    prune: true
```

#### 2. **Скрипт управления Stash**
```bash
#!/bin/bash
# stash-management.sh

echo "📦 Управление Stash backup"

# Установка Stash
install_stash() {
    echo "📥 Установка Stash..."
    
    # Установка через Helm
    helm repo add appscode https://charts.appscode.com/stable/
    helm repo update
    
    helm install stash appscode/stash \
        --namespace stash-system \
        --create-namespace \
        --set features.enterprise=false
    
    echo "✅ Stash установлен"
}

# Создание repository
create_repository() {
    echo "🗄️ Создание repository..."
    
    # Создание secret для Digital Ocean Spaces
    kubectl create secret generic do-spaces-secret \
        --from-literal=RESTIC_PASSWORD=secure-password \
        --from-literal=AWS_ACCESS_KEY_ID=${DO_SPACES_ACCESS_KEY} \
        --from-literal=AWS_SECRET_ACCESS_KEY=${DO_SPACES_SECRET_KEY}
    
    # Применение repository конфигурации
    kubectl apply -f stash-installation.yaml
    
    echo "✅ Repository создан"
}

# Проверка backup статуса
check_backup_status() {
    echo "📊 Статус backup операций:"
    kubectl get backupsession --all-namespaces
    kubectl get restoresession --all-namespaces
    kubectl get repository --all-namespaces
}

# Восстановление из backup
restore_from_backup() {
    local backup_session=$1
    echo "🔄 Восстановление из backup: $backup_session"
    
    cat <<EOF | kubectl apply -f -
apiVersion: stash.appscode.com/v1beta1
kind: RestoreSession
metadata:
  name: restore-$(date +%s)
  namespace: default
spec:
  repository:
    name: do-spaces-repo
  target:
    ref:
      apiVersion: apps/v1
      kind: Deployment
      name: sample-app
    volumeMounts:
    - name: data
      mountPath: /data
  rules:
  - snapshots: ["$backup_session"]
EOF
    
    echo "✅ Восстановление запущено"
}

# Основная логика
case "$1" in
    install)
        install_stash
        ;;
    repository)
        create_repository
        ;;
    status)
        check_backup_status
        ;;
    restore)
        restore_from_backup "$2"
        ;;
    *)
        echo "Использование: $0 {install|repository|status|restore <backup-session>}"
        exit 1
        ;;
esac
```

### 💾 etcd Backup инструменты

#### 1. **etcdctl backup**
```bash
#!/bin/bash
# etcd-backup-script.sh

echo "💾 Backup etcd кластера"

# Переменные
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
BACKUP_DIR="/var/backups/etcd"
DATE=$(date +%Y%m%d_%H%M%S)

# Создание директории для backup
mkdir -p $BACKUP_DIR

# Создание snapshot
echo "📸 Создание etcd snapshot..."
ETCDCTL_API=3 etcdctl snapshot save $BACKUP_DIR/etcd-snapshot-$DATE.db \
    --endpoints=$ETCD_ENDPOINTS \
    --cacert=$ETCD_CACERT \
    --cert=$ETCD_CERT \
    --key=$ETCD_KEY

# Проверка snapshot
echo "✅ Проверка snapshot..."
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_DIR/etcd-snapshot-$DATE.db \
    --write-out=table

# Сжатие backup
echo "🗜️ Сжатие backup..."
gzip $BACKUP_DIR/etcd-snapshot-$DATE.db

# Загрузка в Digital Ocean Spaces
echo "☁️ Загрузка в облачное хранилище..."
s3cmd put $BACKUP_DIR/etcd-snapshot-$DATE.db.gz \
    s3://hashfoundry-backup/etcd/etcd-snapshot-$DATE.db.gz \
    --host=fra1.digitaloceanspaces.com \
    --host-bucket='%(bucket)s.fra1.digitaloceanspaces.com'

# Очистка старых backup (оставляем последние 7)
echo "🧹 Очистка старых backup..."
find $BACKUP_DIR -name "etcd-snapshot-*.db.gz" -mtime +7 -delete

echo "✅ etcd backup завершен: etcd-snapshot-$DATE.db.gz"
```

#### 2. **Автоматизация etcd backup**
```yaml
# etcd-backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 */6 * * *"                # Каждые 6 часов
  jobTemplate:
    spec:
      template:
        spec:
          hostNetwork: true
          containers:
          - name: etcd-backup
            image: k8s.gcr.io/etcd:3.5.9-0
            command:
            - /bin/sh
            - -c
            - |
              ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d_%H%M%S).db \
                --endpoints=https://127.0.0.1:2379 \
                --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                --cert=/etc/kubernetes/pki/etcd/server.crt \
                --key=/etc/kubernetes/pki/etcd/server.key
              
              # Загрузка в облако
              s3cmd put /backup/etcd-snapshot-*.db \
                s3://hashfoundry-backup/etcd/ \
                --host=fra1.digitaloceanspaces.com
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
              readOnly: true
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
          - name: backup-storage
            hostPath:
              path: /var/backups/etcd
          restartPolicy: OnFailure
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
          - operator: Exists
```

### 📊 Сравнение backup инструментов

#### 1. **Матрица сравнения**
```yaml
# Сравнение backup инструментов
backup_tools_comparison:
  velero:
    pros:
      - "CNCF проект"
      - "Поддержка множества провайдеров"
      - "Backup и restore на уровне кластера"
      - "Хорошая интеграция с CSI"
    cons:
      - "Ограниченные возможности для application-aware backup"
      - "Требует настройки storage locations"
    use_cases:
      - "Disaster recovery кластера"
      - "Миграция между кластерами"
      - "Backup namespace и ресурсов"
  
  kasten_k10:
    pros:
      - "Enterprise функции"
      - "Application-aware backup"
      - "Удобный web UI"
      - "Политики и compliance"
    cons:
      - "Коммерческий продукт"
      - "Более сложная настройка"
      - "Требует больше ресурсов"
    use_cases:
      - "Enterprise environments"
      - "Compliance требования"
      - "Complex stateful applications"
  
  stash:
    pros:
      - "Open source"
      - "Гибкие backup политики"
      - "Поддержка различных storage backend"
      - "Kubernetes native"
    cons:
      - "Меньше enterprise функций"
      - "Требует больше ручной настройки"
    use_cases:
      - "Application data backup"
      - "Custom backup workflows"
      - "Cost-effective решения"
```

### 🎯 Лучшие практики

#### 1. **Стратегия выбора инструментов**
```yaml
backup_tool_selection_strategy:
  cluster_backup:
    recommended: "Velero"
    alternatives: ["Kasten K10", "Portworx PX-Backup"]
    considerations:
      - "Размер кластера"
      - "Количество namespaces"
      - "Требования к RTO/RPO"
  
  application_backup:
    recommended: "Stash + Velero"
    alternatives: ["Kasten K10", "Custom operators"]
    considerations:
      - "Тип приложения (stateful/stateless)"
      - "Требования к consistency"
      - "Частота backup"
  
  etcd_backup:
    recommended: "etcdctl + automation"
    alternatives: ["Velero etcd plugin", "etcd-operator"]
    considerations:
      - "Критичность данных"
      - "Размер etcd"
      - "Требования к восстановлению"
```

#### 2. **Чек-лист выбора backup инструментов**
```yaml
backup_tools_checklist:
  requirements_analysis:
    - "✅ Определите типы данных для backup"
    - "✅ Установите требования RTO/RPO"
    - "✅ Оцените бюджет на backup решения"
    - "✅ Проанализируйте compliance требования"
  
  tool_evaluation:
    - "✅ Протестируйте backup и restore процедуры"
    - "✅ Оцените производительность backup"
    - "✅ Проверьте интеграцию с существующей инфраструктурой"
    - "✅ Рассмотрите возможности мониторинга"
  
  implementation:
    - "✅ Настройте автоматизированные backup"
    - "✅ Создайте процедуры восстановления"
    - "✅ Настройте мониторинг и алерты"
    - "✅ Документируйте процессы"
  
  maintenance:
    - "✅ Регулярно тестируйте восстановление"
    - "✅ Мониторьте размер и производительность backup"
    - "✅ Обновляйте backup инструменты"
    - "✅ Пересматривайте backup политики"
```

Правильный выбор backup инструментов обеспечивает надежную защиту данных и быстрое восстановление в случае сбоев в Kubernetes кластере.
