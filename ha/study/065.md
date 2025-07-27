# 65. Как создавать резервные копии и восстанавливать Persistent Volumes?

## 🎯 **Как создавать резервные копии и восстанавливать Persistent Volumes?**

**Backup и restore Persistent Volumes** - критически важная задача для обеспечения сохранности данных в Kubernetes кластере. Существует несколько подходов к резервному копированию, от простых snapshot'ов до комплексных решений.

## 🌐 **Стратегии резервного копирования:**

### **1. Volume Snapshots:**
- **CSI Volume Snapshots** - стандартный механизм Kubernetes
- **Cloud Provider Snapshots** - нативные snapshot'ы облачных провайдеров
- **Storage-specific Snapshots** - специфичные для типа хранилища

### **2. Application-level Backups:**
- **Database Dumps** - логические бэкапы баз данных
- **File-level Backups** - копирование файлов приложений
- **Consistent Backups** - согласованные снимки состояния

### **3. Cluster-level Solutions:**
- **Velero** - комплексное решение для backup/restore
- **Kasten K10** - enterprise backup platform
- **Stash** - backup operator для Kubernetes

## 📊 **Практические примеры из вашего HA кластера:**

### **CSI Volume Snapshots:**

```bash
# Проверить поддержку snapshots в кластере
kubectl get volumesnapshotclasses
kubectl get csidriver

# Проверить текущие PV и PVC
kubectl get pv
kubectl get pvc --all-namespaces
```

```yaml
# volume-snapshot-class.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: hashfoundry-snapshot-class
  labels:
    environment: hashfoundry-ha
driver: dobs.csi.digitalocean.com
deletionPolicy: Delete
parameters:
  # DigitalOcean specific parameters
  snapshot-type: "standard"
```

```yaml
# volume-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: webapp-data-snapshot
  namespace: production
  labels:
    app: webapp
    backup-type: manual
    environment: hashfoundry-ha
spec:
  volumeSnapshotClassName: hashfoundry-snapshot-class
  source:
    persistentVolumeClaimName: webapp-data-pvc
```

### **Автоматизированные snapshot'ы:**

```bash
# Создать скрипт для автоматических snapshot'ов
cat << 'EOF' > create-snapshots.sh
#!/bin/bash

echo "=== HashFoundry PV Backup Script ==="
echo "Timestamp: $(date)"

# Configuration
NAMESPACE=${1:-"production"}
SNAPSHOT_CLASS="hashfoundry-snapshot-class"
RETENTION_DAYS=7

# Function to create snapshot
create_snapshot() {
    local pvc_name=$1
    local namespace=$2
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_name="${pvc_name}-snapshot-${timestamp}"
    
    echo "Creating snapshot for PVC: $pvc_name in namespace: $namespace"
    
    cat << SNAPSHOT_EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: $snapshot_name
  namespace: $namespace
  labels:
    app: backup
    pvc-name: $pvc_name
    backup-type: automated
    environment: hashfoundry-ha
    created-date: $(date +%Y-%m-%d)
spec:
  volumeSnapshotClassName: $SNAPSHOT_CLASS
  source:
    persistentVolumeClaimName: $pvc_name
SNAPSHOT_EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Snapshot created: $snapshot_name"
    else
        echo "❌ Failed to create snapshot for $pvc_name"
    fi
}

# Function to cleanup old snapshots
cleanup_old_snapshots() {
    local namespace=$1
    local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
    
    echo "Cleaning up snapshots older than $cutoff_date"
    
    kubectl get volumesnapshots -n $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.created-date}{"\n"}{end}' | \
    while read snapshot_name created_date; do
        if [[ "$created_date" < "$cutoff_date" ]]; then
            echo "Deleting old snapshot: $snapshot_name (created: $created_date)"
            kubectl delete volumesnapshot $snapshot_name -n $namespace
        fi
    done
}

# Get all PVCs in namespace
echo "Finding PVCs in namespace: $NAMESPACE"
kubectl get pvc -n $NAMESPACE --no-headers -o custom-columns=NAME:.metadata.name | \
while read pvc_name; do
    if [ ! -z "$pvc_name" ]; then
        create_snapshot "$pvc_name" "$NAMESPACE"
    fi
done

# Cleanup old snapshots
cleanup_old_snapshots "$NAMESPACE"

echo "✅ Backup process completed"
EOF

chmod +x create-snapshots.sh
```

### **Восстановление из snapshot'а:**

```yaml
# restore-from-snapshot.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-data-restored-pvc
  namespace: production
  labels:
    app: webapp
    restore-from: webapp-data-snapshot
    environment: hashfoundry-ha
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: do-block-storage
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: webapp-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

### **Velero для комплексного backup:**

```bash
# Установка Velero
curl -fsSL -o velero-v1.12.0-linux-amd64.tar.gz \
  https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz

tar -xzf velero-v1.12.0-linux-amd64.tar.gz
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Создать S3 bucket для backup storage (DigitalOcean Spaces)
# Настроить credentials
cat << 'EOF' > velero-credentials
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
EOF

# Установить Velero в кластер
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket hashfoundry-backups \
  --secret-file ./velero-credentials \
  --backup-location-config region=fra1,s3ForcePathStyle="true",s3Url=https://fra1.digitaloceanspaces.com \
  --snapshot-location-config region=fra1
```

```yaml
# velero-backup-schedule.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: hashfoundry-daily-backup
  namespace: velero
  labels:
    environment: hashfoundry-ha
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    metadata:
      labels:
        backup-type: scheduled
        environment: hashfoundry-ha
    spec:
      includedNamespaces:
      - production
      - staging
      - monitoring
      excludedResources:
      - events
      - events.events.k8s.io
      snapshotVolumes: true
      ttl: 720h  # 30 days retention
      storageLocation: default
      volumeSnapshotLocations:
      - default
```

### **Database-specific backup strategies:**

```bash
# PostgreSQL backup script
cat << 'EOF' > backup-postgres.sh
#!/bin/bash

echo "=== PostgreSQL Backup Script ==="

# Configuration
NAMESPACE="database"
POD_NAME="postgres-0"
DATABASE_NAME="hashfoundry_db"
BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="postgres_backup_${TIMESTAMP}.sql"

# Create backup directory in pod
kubectl exec -n $NAMESPACE $POD_NAME -- mkdir -p $BACKUP_DIR

# Create database dump
echo "Creating database dump..."
kubectl exec -n $NAMESPACE $POD_NAME -- pg_dump -U postgres $DATABASE_NAME > $BACKUP_FILE

# Copy backup to local storage
echo "Copying backup to local storage..."
kubectl cp $NAMESPACE/$POD_NAME:$BACKUP_DIR/$BACKUP_FILE ./$BACKUP_FILE

# Upload to S3/Spaces (optional)
if command -v aws &> /dev/null; then
    echo "Uploading to S3..."
    aws s3 cp $BACKUP_FILE s3://hashfoundry-db-backups/ \
      --endpoint-url=https://fra1.digitaloceanspaces.com
fi

# Cleanup old backups (keep last 7 days)
find . -name "postgres_backup_*.sql" -mtime +7 -delete

echo "✅ PostgreSQL backup completed: $BACKUP_FILE"
EOF

chmod +x backup-postgres.sh
```

```bash
# MongoDB backup script
cat << 'EOF' > backup-mongodb.sh
#!/bin/bash

echo "=== MongoDB Backup Script ==="

# Configuration
NAMESPACE="database"
POD_NAME="mongodb-0"
DATABASE_NAME="hashfoundry"
BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mongodb_backup_${TIMESTAMP}"

# Create backup directory
kubectl exec -n $NAMESPACE $POD_NAME -- mkdir -p $BACKUP_DIR

# Create database dump
echo "Creating MongoDB dump..."
kubectl exec -n $NAMESPACE $POD_NAME -- mongodump \
  --db $DATABASE_NAME \
  --out $BACKUP_DIR/$BACKUP_FILE

# Create archive
kubectl exec -n $NAMESPACE $POD_NAME -- tar -czf \
  $BACKUP_DIR/${BACKUP_FILE}.tar.gz \
  -C $BACKUP_DIR $BACKUP_FILE

# Copy backup to local storage
kubectl cp $NAMESPACE/$POD_NAME:$BACKUP_DIR/${BACKUP_FILE}.tar.gz \
  ./${BACKUP_FILE}.tar.gz

echo "✅ MongoDB backup completed: ${BACKUP_FILE}.tar.gz"
EOF

chmod +x backup-mongodb.sh
```

### **Restore procedures:**

```bash
# Создать скрипт для восстановления
cat << 'EOF' > restore-volumes.sh
#!/bin/bash

echo "=== HashFoundry Volume Restore Script ==="

# Function to restore from snapshot
restore_from_snapshot() {
    local snapshot_name=$1
    local new_pvc_name=$2
    local namespace=$3
    local storage_size=$4
    
    echo "Restoring PVC $new_pvc_name from snapshot $snapshot_name"
    
    cat << RESTORE_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $new_pvc_name
  namespace: $namespace
  labels:
    app: restored
    restored-from: $snapshot_name
    environment: hashfoundry-ha
    restore-date: $(date +%Y-%m-%d)
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: do-block-storage
  resources:
    requests:
      storage: $storage_size
  dataSource:
    name: $snapshot_name
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
RESTORE_EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ PVC restored successfully: $new_pvc_name"
        
        # Wait for PVC to be bound
        echo "Waiting for PVC to be bound..."
        kubectl wait --for=condition=Bound pvc/$new_pvc_name -n $namespace --timeout=300s
        
        if [ $? -eq 0 ]; then
            echo "✅ PVC is bound and ready to use"
        else
            echo "❌ PVC binding timeout"
        fi
    else
        echo "❌ Failed to restore PVC"
    fi
}

# Function to restore database from backup
restore_database() {
    local backup_file=$1
    local pod_name=$2
    local namespace=$3
    local db_type=$4
    
    echo "Restoring database from backup: $backup_file"
    
    # Copy backup file to pod
    kubectl cp $backup_file $namespace/$pod_name:/tmp/restore_backup
    
    case $db_type in
        "postgres")
            kubectl exec -n $namespace $pod_name -- psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS hashfoundry_db;"
            kubectl exec -n $namespace $pod_name -- psql -U postgres -d postgres -c "CREATE DATABASE hashfoundry_db;"
            kubectl exec -n $namespace $pod_name -- psql -U postgres -d hashfoundry_db -f /tmp/restore_backup
            ;;
        "mongodb")
            kubectl exec -n $namespace $pod_name -- mongorestore --drop --db hashfoundry /tmp/restore_backup
            ;;
        *)
            echo "Unsupported database type: $db_type"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "✅ Database restored successfully"
    else
        echo "❌ Database restore failed"
    fi
}

# Function to list available snapshots
list_snapshots() {
    local namespace=$1
    
    echo "Available snapshots in namespace $namespace:"
    kubectl get volumesnapshots -n $namespace -o custom-columns=\
NAME:.metadata.name,\
PVC:.spec.source.persistentVolumeClaimName,\
CREATED:.metadata.creationTimestamp,\
READY:.status.readyToUse
}

# Function to list available backups
list_backups() {
    echo "Available Velero backups:"
    velero backup get
}

# Main menu
case "$1" in
    "snapshot")
        restore_from_snapshot "$2" "$3" "$4" "$5"
        ;;
    "database")
        restore_database "$2" "$3" "$4" "$5"
        ;;
    "list-snapshots")
        list_snapshots "$2"
        ;;
    "list-backups")
        list_backups
        ;;
    "velero-restore")
        velero restore create --from-backup "$2"
        ;;
    *)
        echo "Usage: $0 [snapshot|database|list-snapshots|list-backups|velero-restore] [args...]"
        echo ""
        echo "Commands:"
        echo "  snapshot <snapshot-name> <new-pvc-name> <namespace> <size>"
        echo "  database <backup-file> <pod-name> <namespace> <db-type>"
        echo "  list-snapshots <namespace>"
        echo "  list-backups"
        echo "  velero-restore <backup-name>"
        echo ""
        echo "Examples:"
        echo "  $0 snapshot webapp-data-snapshot webapp-data-restored production 10Gi"
        echo "  $0 database postgres_backup.sql postgres-0 database postgres"
        echo "  $0 list-snapshots production"
        echo "  $0 velero-restore hashfoundry-daily-backup-20231201"
        ;;
esac
EOF

chmod +x restore-volumes.sh
```

### **Мониторинг backup процессов:**

```bash
# Создать скрипт для мониторинга backup'ов
cat << 'EOF' > monitor-backups.sh
#!/bin/bash

echo "=== HashFoundry Backup Monitoring ==="
echo "Timestamp: $(date)"
echo

# Function to check snapshot status
check_snapshots() {
    echo "1. Volume Snapshots Status:"
    
    echo "   Recent snapshots (last 24 hours):"
    kubectl get volumesnapshots --all-namespaces \
      -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
PVC:.spec.source.persistentVolumeClaimName,\
READY:.status.readyToUse,\
CREATED:.metadata.creationTimestamp | \
    awk -v date="$(date -d '1 day ago' -u +%Y-%m-%dT%H:%M:%S)" '$5 > date'
    
    echo
    echo "   Failed snapshots:"
    kubectl get volumesnapshots --all-namespaces \
      -o jsonpath='{range .items[?(@.status.readyToUse==false)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.error.message}{"\n"}{end}'
    
    echo
}

# Function to check Velero backups
check_velero_backups() {
    echo "2. Velero Backups Status:"
    
    if command -v velero &> /dev/null; then
        echo "   Recent backups:"
        velero backup get | head -10
        
        echo
        echo "   Failed backups:"
        velero backup get | grep -E "(Failed|PartiallyFailed)"
        
        echo
        echo "   Backup storage location:"
        velero backup-location get
    else
        echo "   Velero not installed or not in PATH"
    fi
    
    echo
}

# Function to check backup schedules
check_backup_schedules() {
    echo "3. Backup Schedules:"
    
    echo "   Velero schedules:"
    if command -v velero &> /dev/null; then
        velero schedule get
    fi
    
    echo
    echo "   CronJobs for backups:"
    kubectl get cronjobs --all-namespaces | grep -i backup
    
    echo
}

# Function to check storage usage
check_storage_usage() {
    echo "4. Storage Usage:"
    
    echo "   PVC usage:"
    kubectl get pvc --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
STATUS:.status.phase,\
CAPACITY:.status.capacity.storage,\
STORAGECLASS:.spec.storageClassName
    
    echo
    echo "   PV status:"
    kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
CAPACITY:.spec.capacity.storage,\
STATUS:.status.phase,\
CLAIM:.spec.claimRef.name,\
STORAGECLASS:.spec.storageClassName
    
    echo
}

# Function to generate backup report
generate_backup_report() {
    echo "5. Backup Summary Report:"
    
    local total_snapshots=$(kubectl get volumesnapshots --all-namespaces --no-headers | wc -l)
    local ready_snapshots=$(kubectl get volumesnapshots --all-namespaces -o jsonpath='{range .items[?(@.status.readyToUse==true)]}{.metadata.name}{"\n"}{end}' | wc -l)
    local failed_snapshots=$((total_snapshots - ready_snapshots))
    
    echo "   Total snapshots: $total_snapshots"
    echo "   Ready snapshots: $ready_snapshots"
    echo "   Failed snapshots: $failed_snapshots"
    
    if command -v velero &> /dev/null; then
        local velero_backups=$(velero backup get --output json | jq '.items | length' 2>/dev/null || echo "0")
        local successful_backups=$(velero backup get --output json | jq '[.items[] | select(.status.phase=="Completed")] | length' 2>/dev/null || echo "0")
        
        echo "   Velero backups: $velero_backups"
        echo "   Successful Velero backups: $successful_backups"
    fi
    
    echo
}

# Main execution
check_snapshots
check_velero_backups
check_backup_schedules
check_storage_usage
generate_backup_report

echo "✅ Backup monitoring completed"
EOF

chmod +x monitor-backups.sh
```

### **Команды kubectl для управления backup/restore:**

```bash
# Проверить поддержку snapshots
kubectl get volumesnapshotclasses
kubectl get csidriver

# Создать snapshot вручную
kubectl create -f volume-snapshot.yaml

# Проверить статус snapshot'а
kubectl get volumesnapshots -n production
kubectl describe volumesnapshot webapp-data-snapshot -n production

# Восстановить PVC из snapshot'а
kubectl create -f restore-from-snapshot.yaml

# Проверить Velero backups
velero backup get
velero backup describe <backup-name>

# Создать backup с Velero
velero backup create manual-backup --include-namespaces production

# Восстановить из Velero backup
velero restore create --from-backup manual-backup

# Проверить статус restore
velero restore get
velero restore describe <restore-name>

# Проверить backup schedules
velero schedule get
kubectl get cronjobs --all-namespaces

# Мониторинг storage usage
kubectl top pv
kubectl get events --field-selector reason=VolumeSnapshotCreated

# Проверить backup storage location
velero backup-location get
velero backup-location describe default
```

## 🎯 **Best Practices для Backup/Restore:**

1. **Регулярность** - настройте автоматические backup'ы по расписанию
2. **Тестирование** - регулярно тестируйте процедуры восстановления
3. **Retention Policy** - определите политику хранения backup'ов
4. **Мониторинг** - отслеживайте статус backup'ов и storage usage
5. **Документация** - документируйте процедуры backup/restore
6. **Безопасность** - шифруйте backup'ы и ограничивайте доступ

Правильная стратегия backup и restore обеспечивает надежную защиту данных в HashFoundry HA кластере.
