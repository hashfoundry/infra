# 161. Какие компоненты нуждаются в резервном копировании в Kubernetes?

## 🎯 **Что такое компоненты для резервного копирования?**

**Компоненты для резервного копирования в Kubernetes** — это критически важные элементы кластера, включающие данные состояния (etcd), конфигурации приложений, persistent volumes, secrets, и системные настройки, которые необходимо регулярно сохранять для обеспечения возможности полного восстановления кластера и приложений.

## 🏗️ **Основные категории компонентов:**

### **1. Критические компоненты (Tier 1)**
- **etcd** - хранилище состояния кластера
- **Persistent Volumes** - данные приложений
- **Secrets** - конфиденциальная информация
- **PKI сертификаты** - безопасность кластера

### **2. Важные компоненты (Tier 2)**
- **ConfigMaps** - конфигурации приложений
- **RBAC политики** - управление доступом
- **Network Policies** - сетевая безопасность
- **Custom Resources** - пользовательские ресурсы

### **3. Конфигурационные компоненты (Tier 3)**
- **Helm Charts** - пакеты приложений
- **Ingress конфигурации** - внешний доступ
- **Monitoring настройки** - мониторинг
- **DNS конфигурации** - сетевые настройки

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ критических компонентов:**
```bash
# Проверка состояния etcd
kubectl get pods -n kube-system | grep etcd
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint health

# Анализ Persistent Volumes
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name

# Проверка критических Secrets
kubectl get secrets --all-namespaces | grep -E "(tls|docker|token)"

# Размер данных etcd
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=table
```

### **2. Мониторинг компонентов для backup:**
```bash
# Анализ использования storage
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage,STATUS:.status.phase

# Проверка ConfigMaps
kubectl get configmaps --all-namespaces | wc -l

# Анализ Custom Resources
kubectl get crd | wc -l
```

### **3. Проверка конфигураций HA кластера:**
```bash
# ArgoCD конфигурации
kubectl get applications -n argocd
kubectl get secrets -n argocd | grep -E "(repo|cluster)"

# Monitoring stack
kubectl get configmaps -n monitoring | grep -E "(prometheus|grafana|alertmanager)"

# NFS Provisioner данные
kubectl get pv | grep nfs
```

## 🔄 **Демонстрация backup стратегий:**

### **1. Создание комплексного backup скрипта:**
```bash
# Создать скрипт comprehensive-backup.sh
cat << 'EOF' > comprehensive-backup.sh
#!/bin/bash

echo "🚀 Комплексное резервное копирование HA кластера"
echo "=============================================="

# Настройка переменных
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/backup/kubernetes/$BACKUP_DATE"
mkdir -p $BACKUP_DIR

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 1. КРИТИЧЕСКИЕ КОМПОНЕНТЫ (Tier 1)
log "📦 Резервное копирование критических компонентов..."

# etcd backup
log "Создание snapshot etcd..."
ETCDCTL_API=3 etcdctl snapshot save $BACKUP_DIR/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Проверка snapshot
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_DIR/etcd-snapshot.db --write-out=table

# Persistent Volumes metadata
log "Сохранение метаданных PV..."
kubectl get pv,pvc --all-namespaces -o yaml > $BACKUP_DIR/persistent-volumes.yaml

# Secrets (зашифрованные)
log "Резервное копирование Secrets..."
kubectl get secrets --all-namespaces -o yaml > $BACKUP_DIR/secrets.yaml

# PKI сертификаты
log "Копирование PKI сертификатов..."
mkdir -p $BACKUP_DIR/pki
cp -r /etc/kubernetes/pki/* $BACKUP_DIR/pki/ 2>/dev/null || log "PKI недоступны (managed cluster)"

# 2. ВАЖНЫЕ КОМПОНЕНТЫ (Tier 2)
log "📋 Резервное копирование важных компонентов..."

# ConfigMaps
kubectl get configmaps --all-namespaces -o yaml > $BACKUP_DIR/configmaps.yaml

# RBAC
kubectl get clusterroles,clusterrolebindings,roles,rolebindings --all-namespaces -o yaml > $BACKUP_DIR/rbac.yaml

# Network Policies
kubectl get networkpolicies --all-namespaces -o yaml > $BACKUP_DIR/network-policies.yaml

# Custom Resources
kubectl get crd -o yaml > $BACKUP_DIR/crds.yaml

# Backup всех Custom Resources
for crd in $(kubectl get crd -o jsonpath='{.items[*].metadata.name}'); do
    log "Backing up custom resources for CRD: $crd"
    kubectl get $crd --all-namespaces -o yaml > "$BACKUP_DIR/cr-$crd.yaml" 2>/dev/null || log "No resources for $crd"
done

# 3. КОНФИГУРАЦИОННЫЕ КОМПОНЕНТЫ (Tier 3)
log "⚙️ Резервное копирование конфигураций..."

# Все ресурсы кластера
kubectl get all --all-namespaces -o yaml > $BACKUP_DIR/all-resources.yaml

# Ingress конфигурации
kubectl get ingress --all-namespaces -o yaml > $BACKUP_DIR/ingress.yaml

# Services
kubectl get services --all-namespaces -o yaml > $BACKUP_DIR/services.yaml

# Namespaces
kubectl get namespaces -o yaml > $BACKUP_DIR/namespaces.yaml

# 4. HA КЛАСТЕР СПЕЦИФИЧНЫЕ КОМПОНЕНТЫ
log "🏗️ Резервное копирование HA компонентов..."

# ArgoCD конфигурации
mkdir -p $BACKUP_DIR/argocd
kubectl get applications,appprojects -n argocd -o yaml > $BACKUP_DIR/argocd/applications.yaml
kubectl get secrets -n argocd -o yaml > $BACKUP_DIR/argocd/secrets.yaml
kubectl get configmaps -n argocd -o yaml > $BACKUP_DIR/argocd/configmaps.yaml

# Monitoring stack
mkdir -p $BACKUP_DIR/monitoring
kubectl get configmaps -n monitoring -o yaml > $BACKUP_DIR/monitoring/configmaps.yaml
kubectl get secrets -n monitoring -o yaml > $BACKUP_DIR/monitoring/secrets.yaml
kubectl get servicemonitors,prometheusrules -n monitoring -o yaml > $BACKUP_DIR/monitoring/prometheus-configs.yaml 2>/dev/null

# NFS Provisioner
mkdir -p $BACKUP_DIR/nfs
kubectl get storageclass -o yaml > $BACKUP_DIR/nfs/storageclasses.yaml
kubectl get pv | grep nfs > $BACKUP_DIR/nfs/nfs-volumes.txt

# 5. HELM RELEASES
log "📦 Резервное копирование Helm releases..."
mkdir -p $BACKUP_DIR/helm

# Список всех Helm releases
helm list --all-namespaces -o yaml > $BACKUP_DIR/helm/releases.yaml

# Values для каждого release
for release in $(helm list --all-namespaces -q); do
    namespace=$(helm list --all-namespaces | grep $release | awk '{print $2}')
    log "Backing up Helm values for $release in $namespace"
    helm get values $release -n $namespace > $BACKUP_DIR/helm/$release-values.yaml
    helm get manifest $release -n $namespace > $BACKUP_DIR/helm/$release-manifest.yaml
done

# 6. СОЗДАНИЕ МЕТАДАННЫХ BACKUP
log "📊 Создание метаданных backup..."
cat << METADATA_EOF > $BACKUP_DIR/backup-metadata.yaml
backup_info:
  timestamp: "$BACKUP_DATE"
  cluster_info:
    kubernetes_version: "$(kubectl version --short --client | grep Client)"
    server_version: "$(kubectl version --short | grep Server)"
    node_count: $(kubectl get nodes --no-headers | wc -l)
    namespace_count: $(kubectl get namespaces --no-headers | wc -l)
    pod_count: $(kubectl get pods --all-namespaces --no-headers | wc -l)
  
  backup_components:
    etcd_snapshot: "etcd-snapshot.db"
    persistent_volumes: "persistent-volumes.yaml"
    secrets: "secrets.yaml"
    configmaps: "configmaps.yaml"
    rbac: "rbac.yaml"
    network_policies: "network-policies.yaml"
    custom_resources: "crds.yaml"
    all_resources: "all-resources.yaml"
    
  ha_specific:
    argocd: "argocd/"
    monitoring: "monitoring/"
    nfs: "nfs/"
    helm: "helm/"
    
  backup_size: "$(du -sh $BACKUP_DIR | cut -f1)"
  backup_location: "$BACKUP_DIR"
METADATA_EOF

# 7. СЖАТИЕ И ФИНАЛИЗАЦИЯ
log "📦 Сжатие backup..."
cd $(dirname $BACKUP_DIR)
tar -czf $BACKUP_DIR.tar.gz $(basename $BACKUP_DIR)

# Проверка целостности
log "🔍 Проверка целостности backup..."
tar -tzf $BACKUP_DIR.tar.gz > /dev/null && log "✅ Backup архив корректен" || log "❌ Ошибка в backup архиве"

# Очистка временной директории
rm -rf $BACKUP_DIR

# Статистика
BACKUP_SIZE=$(du -sh $BACKUP_DIR.tar.gz | cut -f1)
log "✅ Backup завершен: $BACKUP_DIR.tar.gz (размер: $BACKUP_SIZE)"

# Очистка старых backup (старше 30 дней)
find /backup/kubernetes -name "*.tar.gz" -mtime +30 -delete
log "🧹 Старые backup очищены"

echo "🎉 КОМПЛЕКСНОЕ РЕЗЕРВНОЕ КОПИРОВАНИЕ ЗАВЕРШЕНО!"
echo "Backup файл: $BACKUP_DIR.tar.gz"
echo "Размер: $BACKUP_SIZE"
EOF

chmod +x comprehensive-backup.sh
```

### **2. Создание backup validator:**
```bash
# Создать скрипт backup-validator.sh
cat << 'EOF' > backup-validator.sh
#!/bin/bash

echo "🔍 Валидация компонентов для резервного копирования"
echo "=============================================="

# Функция проверки компонентов
validate_component() {
    local component=$1
    local check_command=$2
    local description=$3
    
    echo -n "Проверка $component: "
    if eval $check_command >/dev/null 2>&1; then
        echo "✅ $description"
        return 0
    else
        echo "❌ $description"
        return 1
    fi
}

# Счетчики
total_checks=0
passed_checks=0

# 1. КРИТИЧЕСКИЕ КОМПОНЕНТЫ
echo "📦 КРИТИЧЕСКИЕ КОМПОНЕНТЫ (Tier 1):"

# etcd
total_checks=$((total_checks + 1))
validate_component "etcd" "kubectl get pods -n kube-system | grep etcd | grep Running" "etcd доступен" && passed_checks=$((passed_checks + 1))

# Persistent Volumes
total_checks=$((total_checks + 1))
validate_component "PV" "kubectl get pv | grep -v 'No resources'" "Persistent Volumes найдены" && passed_checks=$((passed_checks + 1))

# Secrets
total_checks=$((total_checks + 1))
validate_component "Secrets" "kubectl get secrets --all-namespaces | grep -v 'No resources'" "Secrets найдены" && passed_checks=$((passed_checks + 1))

# PKI сертификаты
total_checks=$((total_checks + 1))
validate_component "PKI" "ls /etc/kubernetes/pki/ca.crt" "PKI сертификаты доступны" && passed_checks=$((passed_checks + 1))

# 2. ВАЖНЫЕ КОМПОНЕНТЫ
echo -e "\n📋 ВАЖНЫЕ КОМПОНЕНТЫ (Tier 2):"

# ConfigMaps
total_checks=$((total_checks + 1))
validate_component "ConfigMaps" "kubectl get configmaps --all-namespaces | grep -v 'No resources'" "ConfigMaps найдены" && passed_checks=$((passed_checks + 1))

# RBAC
total_checks=$((total_checks + 1))
validate_component "RBAC" "kubectl get clusterroles | grep -v 'No resources'" "RBAC политики найдены" && passed_checks=$((passed_checks + 1))

# Network Policies
total_checks=$((total_checks + 1))
validate_component "NetworkPolicies" "kubectl get networkpolicies --all-namespaces" "Network Policies проверены" && passed_checks=$((passed_checks + 1))

# Custom Resources
total_checks=$((total_checks + 1))
validate_component "CRDs" "kubectl get crd | grep -v 'No resources'" "Custom Resources найдены" && passed_checks=$((passed_checks + 1))

# 3. HA КЛАСТЕР КОМПОНЕНТЫ
echo -e "\n🏗️ HA КЛАСТЕР КОМПОНЕНТЫ:"

# ArgoCD
total_checks=$((total_checks + 1))
validate_component "ArgoCD" "kubectl get applications -n argocd" "ArgoCD приложения найдены" && passed_checks=$((passed_checks + 1))

# Monitoring
total_checks=$((total_checks + 1))
validate_component "Monitoring" "kubectl get pods -n monitoring | grep prometheus" "Monitoring stack найден" && passed_checks=$((passed_checks + 1))

# NFS Provisioner
total_checks=$((total_checks + 1))
validate_component "NFS" "kubectl get storageclass | grep nfs" "NFS StorageClass найден" && passed_checks=$((passed_checks + 1))

# Ingress
total_checks=$((total_checks + 1))
validate_component "Ingress" "kubectl get ingress --all-namespaces" "Ingress конфигурации найдены" && passed_checks=$((passed_checks + 1))

# 4. ДЕТАЛЬНЫЙ АНАЛИЗ
echo -e "\n📊 ДЕТАЛЬНЫЙ АНАЛИЗ КОМПОНЕНТОВ:"

# Размер etcd
echo "etcd размер данных:"
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=table 2>/dev/null || echo "  etcd недоступен для анализа"

# Статистика PV
echo -e "\nPersistent Volumes статистика:"
echo "  Всего PV: $(kubectl get pv --no-headers | wc -l)"
echo "  Available: $(kubectl get pv --no-headers | grep Available | wc -l)"
echo "  Bound: $(kubectl get pv --no-headers | grep Bound | wc -l)"

# Статистика Secrets
echo -e "\nSecrets статистика:"
echo "  Всего Secrets: $(kubectl get secrets --all-namespaces --no-headers | wc -l)"
echo "  TLS Secrets: $(kubectl get secrets --all-namespaces --no-headers | grep tls | wc -l)"

# Статистика ConfigMaps
echo -e "\nConfigMaps статистика:"
echo "  Всего ConfigMaps: $(kubectl get configmaps --all-namespaces --no-headers | wc -l)"

# Helm releases
echo -e "\nHelm releases:"
helm list --all-namespaces 2>/dev/null || echo "  Helm недоступен"

# 5. РЕКОМЕНДАЦИИ
echo -e "\n💡 РЕКОМЕНДАЦИИ ПО BACKUP:"

if [ $passed_checks -eq $total_checks ]; then
    echo "✅ Все компоненты готовы для резервного копирования"
else
    echo "⚠️ Некоторые компоненты требуют внимания ($passed_checks/$total_checks прошли проверку)"
fi

echo -e "\nПриоритеты backup:"
echo "1. 🔴 КРИТИЧНО: etcd, PV, Secrets, PKI"
echo "2. 🟡 ВАЖНО: ConfigMaps, RBAC, NetworkPolicies, CRDs"
echo "3. 🟢 ЖЕЛАТЕЛЬНО: Helm, Monitoring configs, Ingress"

echo -e "\nРекомендуемая частота backup:"
echo "- etcd: каждые 15 минут"
echo "- PV: ежедневно"
echo "- Конфигурации: при изменении"
echo "- Полный backup: еженедельно"

echo -e "\n📋 СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Запустите ./comprehensive-backup.sh для полного backup"
echo "2. Настройте автоматический backup через CronJob"
echo "3. Протестируйте восстановление из backup"
echo "4. Настройте мониторинг backup процессов"

echo -e "\n✅ ВАЛИДАЦИЯ ЗАВЕРШЕНА!"
echo "Результат: $passed_checks/$total_checks компонентов готовы"
EOF

chmod +x backup-validator.sh
```

### **3. Создание CronJob для автоматического backup:**
```bash
# Создать манифест backup-cronjob.yaml
cat << 'EOF' > backup-cronjob.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backup-service-account
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-cluster-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backup-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backup-cluster-role
subjects:
- kind: ServiceAccount
  name: backup-service-account
  namespace: kube-system
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
  namespace: kube-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: do-block-storage
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: kubernetes-comprehensive-backup
  namespace: kube-system
  labels:
    app: kubernetes-backup
    component: comprehensive-backup
spec:
  schedule: "0 2 * * *"  # Каждый день в 2:00 UTC
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: kubernetes-backup
        spec:
          serviceAccountName: backup-service-account
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - -c
            - |
              echo "🚀 Автоматическое резервное копирование HA кластера"
              
              # Настройка переменных
              BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
              BACKUP_DIR="/backup/$BACKUP_DATE"
              mkdir -p $BACKUP_DIR
              
              # Функция логирования
              log() {
                  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
              }
              
              # 1. Основные ресурсы
              log "📦 Backup основных ресурсов..."
              kubectl get all --all-namespaces -o yaml > $BACKUP_DIR/all-resources.yaml
              kubectl get secrets --all-namespaces -o yaml > $BACKUP_DIR/secrets.yaml
              kubectl get configmaps --all-namespaces -o yaml > $BACKUP_DIR/configmaps.yaml
              kubectl get pv,pvc --all-namespaces -o yaml > $BACKUP_DIR/persistent-volumes.yaml
              
              # 2. RBAC и безопасность
              log "🔐 Backup RBAC и безопасности..."
              kubectl get clusterroles,clusterrolebindings,roles,rolebindings --all-namespaces -o yaml > $BACKUP_DIR/rbac.yaml
              kubectl get networkpolicies --all-namespaces -o yaml > $BACKUP_DIR/network-policies.yaml
              
              # 3. Custom Resources
              log "🔧 Backup Custom Resources..."
              kubectl get crd -o yaml > $BACKUP_DIR/crds.yaml
              
              # 4. HA специфичные компоненты
              log "🏗️ Backup HA компонентов..."
              
              # ArgoCD
              mkdir -p $BACKUP_DIR/argocd
              kubectl get applications,appprojects -n argocd -o yaml > $BACKUP_DIR/argocd/applications.yaml 2>/dev/null || log "ArgoCD недоступен"
              
              # Monitoring
              mkdir -p $BACKUP_DIR/monitoring
              kubectl get configmaps,secrets -n monitoring -o yaml > $BACKUP_DIR/monitoring/configs.yaml 2>/dev/null || log "Monitoring недоступен"
              
              # Ingress
              kubectl get ingress --all-namespaces -o yaml > $BACKUP_DIR/ingress.yaml
              
              # 5. Метаданные
              log "📊 Создание метаданных..."
              cat << METADATA_EOF > $BACKUP_DIR/backup-metadata.yaml
              backup_info:
                timestamp: "$BACKUP_DATE"
                type: "automated-cronjob"
                kubernetes_version: "$(kubectl version --short --client 2>/dev/null | grep Client || echo 'unknown')"
                cluster_nodes: $(kubectl get nodes --no-headers | wc -l)
                total_pods: $(kubectl get pods --all-namespaces --no-headers | wc -l)
                total_namespaces: $(kubectl get namespaces --no-headers | wc -l)
                backup_size: "$(du -sh $BACKUP_DIR | cut -f1)"
              METADATA_EOF
              
              # 6. Сжатие
              log "📦 Сжатие backup..."
              cd /backup
              tar -czf $BACKUP_DATE.tar.gz $BACKUP_DATE/
              rm -rf $BACKUP_DATE/
              
              # 7. Очистка старых backup
              log "🧹 Очистка старых backup..."
              find /backup -name "*.tar.gz" -mtime +7 -delete
              
              # 8. Статистика
              BACKUP_SIZE=$(du -sh $BACKUP_DATE.tar.gz | cut -f1)
              log "✅ Backup завершен: $BACKUP_DATE.tar.gz (размер: $BACKUP_SIZE)"
              
              # 9. Проверка успешности
              if [ -f "$BACKUP_DATE.tar.gz" ]; then
                  log "🎉 АВТОМАТИЧЕСКИЙ BACKUP УСПЕШНО ЗАВЕРШЕН!"
                  exit 0
              else
                  log "❌ ОШИБКА: Backup файл не создан"
                  exit 1
              fi
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
            resources:
              requests:
                cpu: 100m
                memory: 256Mi
              limits:
                cpu: 500m
                memory: 512Mi
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
EOF

# Применить CronJob
kubectl apply -f backup-cronjob.yaml
```

## 📊 **Архитектура компонентов для backup:**

```
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Backup Components               │
├─────────────────────────────────────────────────────────────┤
│  Tier 1: Critical Components (RTO: 15 min)                 │
│  ├── etcd (cluster state)                                  │
│  ├── Persistent Volumes (application data)                 │
│  ├── Secrets (credentials, certificates)                   │
│  └── PKI Certificates (cluster security)                   │
├─────────────────────────────────────────────────────────────┤
│  Tier 2: Important Components (RTO: 1 hour)                │
│  ├── ConfigMaps (application configs)                      │
│  ├── RBAC Policies (access control)                        │
│  ├── Network Policies (network security)                   │
│  └── Custom Resources (extensions)                         │
├─────────────────────────────────────────────────────────────┤
│  Tier 3: Configuration Components (RTO: 4 hours)           │
│  ├── Helm Charts (package definitions)                     │
│  ├── Ingress Configs (external access)                     │
│  ├── Monitoring Configs (observability)                    │
│  └── DNS Configurations (service discovery)                │
├─────────────────────────────────────────────────────────────┤
│  HA Cluster Specific Components                             │
│  ├── ArgoCD Applications (GitOps)                          │
│  ├── Prometheus/Grafana Configs (monitoring)               │
│  ├── NFS Provisioner Settings (shared storage)             │
│  └── Load Balancer Configurations (HA access)              │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Матрица приоритетов backup:**

### **1. По критичности и частоте:**
| Компонент | Критичность | Частота Backup | RTO | RPO |
|-----------|-------------|----------------|-----|-----|
| etcd | Критическая | 15 минут | 15 мин | 15 мин |
| PV (Database) | Критическая | 6 часов | 1 час | 6 часов |
| Secrets | Высокая | Ежедневно | 4 часа | 24 часа |
| ConfigMaps | Высокая | При изменении | 4 часа | 24 часа |
| RBAC | Средняя | Еженедельно | 8 часов | 7 дней |
| Monitoring | Низкая | Еженедельно | 24 часа | 7 дней |

### **2. По размеру и сложности:**
```bash
# Анализ размеров компонентов
echo "📊 Анализ размеров компонентов для backup:"

# etcd размер
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=table 2>/dev/null | grep -E "ENDPOINT|127.0.0.1"

# PV использование
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage,USED:.status.phase | grep Bound

# Secrets количество
echo "Secrets: $(kubectl get secrets --all-namespaces --no-headers | wc -l) объектов"

# ConfigMaps количество  
echo "ConfigMaps: $(kubectl get configmaps --all-namespaces --no-headers | wc -l) объектов"
```

## 🔧 **Скрипт мониторинга backup компонентов:**

### **1. Создание backup monitor:**
```bash
# Создать скрипт backup-component-monitor.sh
cat << 'EOF' > backup-component-monitor.sh
#!/bin/bash

echo "📊 Мониторинг компонентов для резервного копирования"
echo "================================================"

# Функция для проверки изменений
check_component_changes() {
    local component=$1
    local namespace=${2:-"--all-namespaces"}
    local last_backup_file="/tmp/last-backup-$component.txt"
    
    # Получить текущее состояние
    if [ "$namespace" = "--all-namespaces" ]; then
        current_state=$(kubectl get $component --all-namespaces -o yaml | sha256sum)
    else
        current_state=$(kubectl get $component -n $namespace -o yaml | sha256sum)
    fi
    
    # Сравнить с последним backup
    if [ -f "$last_backup_file" ]; then
        last_state=$(cat $last_backup_file)
        if [ "$current_state" != "$last_state" ]; then
            echo "🔄 $component изменился с последнего backup"
            return 1
        else
            echo "✅ $component не изменился"
            return 0
        fi
    else
        echo "📝 Первая проверка $component"
        echo "$current_state" > $last_backup_file
        return 1
    fi
}

# Мониторинг критических компонентов
echo "🔍 МОНИТОРИНГ ИЗМЕНЕНИЙ КОМПОНЕНТОВ:"

# Проверка etcd
echo -n "etcd состояние: "
kubectl get pods -n kube-system | grep etcd | grep Running >/dev/null && echo "✅ Работает" || echo "❌ Проблемы"

# Проверка изменений в критических компонентах
check_component_changes "secrets" "--all-namespaces"
check_component_changes "configmaps" "--all-namespaces"
check_component_changes "pv"
check_component_changes "applications" "argocd"

# Статистика компонентов
echo -e "\n📊 СТАТИСТИКА КОМПОНЕНТОВ:"
echo "Secrets: $(kubectl get secrets --all-namespaces --no-headers | wc -l)"
echo "ConfigMaps: $(kubectl get configmaps --all-namespaces --no-headers | wc -l)"
echo "PV: $(kubectl get pv --no-headers | wc -l)"
echo "PVC: $(kubectl get pvc --all-namespaces --no-headers | wc -l)"
echo "CRDs: $(kubectl get crd --no-headers | wc -l)"

# Анализ размеров
echo -e "\n💾 АНАЛИЗ РАЗМЕРОВ:"
echo "etcd размер:"
kubectl exec -n kube-system etcd-$(hostname) -- etcdctl endpoint status --write-out=table 2>/dev/null | grep -E "ENDPOINT|127.0.0.1" || echo "  etcd недоступен"

echo -e "\nPV использование:"
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage,STATUS:.status.phase | head -10

# Рекомендации по backup
echo -e "\n💡 РЕКОМЕНДАЦИИ:"
echo "1. Backup etcd каждые 15 минут"
echo "2. Backup PV данных ежедневно"
echo "3. Backup конфигураций при изменении"
echo "4. Полный backup еженедельно"
echo "5. Тестирование восстановления ежемесячно"

echo -e "\n✅ МОНИТОРИНГ ЗАВЕРШЕН!"
EOF

chmod +x backup-component-monitor.sh
```

## 🎯 **Best Practices для backup компонентов:**

### **1. Приоритизация компонентов**
- Критические (Tier 1): etcd, PV, Secrets, PKI
- Важные (Tier 2): ConfigMaps, RBAC, NetworkPolicies
- Конфигурационные (Tier 3): Helm, Ingress, Monitoring

### **2. Частота backup**
- etcd: каждые 15 минут (автоматически)
- Persistent Volumes: ежедневно
- Конфигурации: при изменении
- Полный backup: еженедельно

### **3. Мониторинг и валидация**
- Автоматическая проверка целостности backup
- Мониторинг изменений компонентов
- Регулярное тестирование восстановления
- Alerting при сбоях backup процессов

### **4. Безопасность backup**
- Шифрование backup данных
- Контроль доступа к backup хранилищу
- Ротация backup файлов
- Аудит backup операций

**Правильная идентификация и приоритизация компонентов — основа эффективной стратегии резервного копирования Kubernetes!**
