# 68. Volume Snapshots

## 🎯 **Volume Snapshots**

**Volume Snapshots** - это point-in-time копии Persistent Volumes, которые позволяют создавать backup'ы, восстанавливать данные и клонировать volumes. Это критически важная функция для защиты данных и disaster recovery.

## 🏗️ **Основные концепции:**

### **Компоненты Volume Snapshots:**
- **VolumeSnapshot** - запрос на создание snapshot'а
- **VolumeSnapshotContent** - фактический snapshot в storage backend
- **VolumeSnapshotClass** - определяет параметры создания snapshot'ов
- **CSI Driver** - обеспечивает интеграцию с storage системой

### **Типы операций:**
- **Create Snapshot** - создание point-in-time копии
- **Restore from Snapshot** - восстановление PVC из snapshot'а
- **Clone Volume** - создание копии volume через snapshot

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка поддержки snapshots:**
```bash
# Проверить поддержку snapshots в кластере
echo "=== Volume Snapshot Support Check ==="

# Проверить CRDs для snapshots
kubectl get crd | grep snapshot
echo

# Проверить snapshot controller
kubectl get pods -n kube-system | grep snapshot
echo

# Проверить CSI drivers и их возможности
kubectl get csidriver -o custom-columns="NAME:.metadata.name,SNAPSHOT:.spec.volumeLifecycleModes[*]"
echo

# Проверить существующие VolumeSnapshotClasses
kubectl get volumesnapshotclass
```

### **2. Создание VolumeSnapshotClass:**
```bash
# Создать VolumeSnapshotClass для DigitalOcean
cat << EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: hashfoundry-snapshot-class
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    snapshot.hashfoundry.io/type: standard
  annotations:
    snapshot.storage.kubernetes.io/description: "Standard snapshot class for HashFoundry workloads"
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: dobs.csi.digitalocean.com
deletionPolicy: Delete
parameters:
  # DigitalOcean specific parameters
  snapshot-type: "standard"
EOF

# Проверить созданный VolumeSnapshotClass
kubectl get volumesnapshotclass hashfoundry-snapshot-class -o yaml
```

### **3. Создание демонстрационной среды:**
```bash
# Создать namespace для демонстрации snapshots
kubectl create namespace volume-snapshot-demo

# Создать labels
kubectl label namespace volume-snapshot-demo \
  demo.type=volume-snapshots \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational

# Создать PVC для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-data-pvc
  namespace: volume-snapshot-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    snapshot.hashfoundry.io/enabled: "true"
  annotations:
    snapshot.hashfoundry.io/description: "PVC for snapshot demonstration"
spec:
  storageClassName: do-block-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# Создать приложение с данными для snapshot'ов
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-data-app
  namespace: volume-snapshot-demo
  labels:
    app: data-app
    snapshot.hashfoundry.io/enabled: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-app
  template:
    metadata:
      labels:
        app: data-app
        snapshot.hashfoundry.io/enabled: "true"
    spec:
      containers:
      - name: data-generator
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_snapshot_db"
        - name: POSTGRES_USER
          value: "snapshot_user"
        - name: POSTGRES_PASSWORD
          value: "snapshot_password_123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: data-storage
          mountPath: /var/lib/postgresql/data
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Snapshot Demo Database..."
          
          # Инициализировать PostgreSQL
          docker-entrypoint.sh postgres &
          
          # Подождать запуска
          sleep 30
          
          # Создать демонстрационные данные
          psql -U snapshot_user -d hashfoundry_snapshot_db -c "
            CREATE TABLE IF NOT EXISTS snapshot_demo_data (
              id SERIAL PRIMARY KEY,
              snapshot_version INTEGER DEFAULT 1,
              data_content TEXT,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              metadata JSONB
            );
            
            -- Функция для создания версионированных данных
            CREATE OR REPLACE FUNCTION create_version_data(version_num INTEGER, record_count INTEGER DEFAULT 1000)
            RETURNS INTEGER AS \$\$
            DECLARE
                i INTEGER;
                inserted_count INTEGER := 0;
            BEGIN
                FOR i IN 1..record_count LOOP
                    INSERT INTO snapshot_demo_data (
                        snapshot_version,
                        data_content,
                        metadata
                    ) VALUES (
                        version_num,
                        'Version ' || version_num || ' - Record ' || i || ' - ' || repeat('data', 10),
                        jsonb_build_object(
                            'version', version_num,
                            'record_number', i,
                            'timestamp', now(),
                            'size_bytes', length('Version ' || version_num || ' - Record ' || i || ' - ' || repeat('data', 10))
                        )
                    );
                    inserted_count := inserted_count + 1;
                END LOOP;
                
                RETURN inserted_count;
            END;
            \$\$ LANGUAGE plpgsql;
            
            -- Функция для получения статистики данных
            CREATE OR REPLACE FUNCTION get_data_stats()
            RETURNS TABLE(
                metric_name TEXT,
                metric_value TEXT
            ) AS \$\$
            BEGIN
                RETURN QUERY
                SELECT 'Total Records'::TEXT, COUNT(*)::TEXT FROM snapshot_demo_data
                UNION ALL
                SELECT 'Unique Versions'::TEXT, COUNT(DISTINCT snapshot_version)::TEXT FROM snapshot_demo_data
                UNION ALL
                SELECT 'Latest Version'::TEXT, COALESCE(MAX(snapshot_version)::TEXT, '0') FROM snapshot_demo_data
                UNION ALL
                SELECT 'Database Size'::TEXT, pg_size_pretty(pg_database_size(current_database()))::TEXT
                UNION ALL
                SELECT 'Table Size'::TEXT, pg_size_pretty(pg_total_relation_size('snapshot_demo_data'))::TEXT;
            END;
            \$\$ LANGUAGE plpgsql;
            
            -- Создать начальную версию данных
            SELECT create_version_data(1, 500);
            
            -- Показать статистику
            SELECT * FROM get_data_stats();
          "
          
          echo "Database initialized with version 1 data!"
          echo "Ready for snapshot operations..."
          
          # Продолжить работу PostgreSQL
          wait
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: data-storage
        persistentVolumeClaim:
          claimName: hashfoundry-data-pvc
EOF

# Проверить развертывание
kubectl get pods,pvc,pv -n volume-snapshot-demo
```

### **4. Создание Volume Snapshots:**
```bash
# Создать скрипт для управления snapshots
cat << 'EOF' > manage-volume-snapshots.sh
#!/bin/bash

NAMESPACE=${1:-"volume-snapshot-demo"}
PVC_NAME=${2:-"hashfoundry-data-pvc"}

echo "=== Volume Snapshot Management ==="
echo "Namespace: $NAMESPACE"
echo "PVC: $PVC_NAME"
echo

# Функция для создания snapshot'а
create_snapshot() {
    local snapshot_name=$1
    local description=${2:-"Snapshot created by HashFoundry demo"}
    
    echo "=== Creating Volume Snapshot: $snapshot_name ==="
    
    # Проверить существование PVC
    if ! kubectl get pvc $PVC_NAME -n $NAMESPACE >/dev/null 2>&1; then
        echo "❌ PVC $PVC_NAME not found in namespace $NAMESPACE"
        return 1
    fi
    
    # Создать snapshot
    cat << SNAPSHOT_EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: $snapshot_name
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    snapshot.hashfoundry.io/source-pvc: $PVC_NAME
    snapshot.hashfoundry.io/type: manual
  annotations:
    snapshot.hashfoundry.io/description: "$description"
    snapshot.hashfoundry.io/created-by: "hashfoundry-demo"
    snapshot.hashfoundry.io/creation-time: "$(date -Iseconds)"
spec:
  volumeSnapshotClassName: hashfoundry-snapshot-class
  source:
    persistentVolumeClaimName: $PVC_NAME
SNAPSHOT_EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Snapshot $snapshot_name created successfully"
        
        # Мониторинг создания snapshot'а
        echo "Monitoring snapshot creation..."
        for i in {1..30}; do
            status=$(kubectl get volumesnapshot $snapshot_name -n $NAMESPACE -o jsonpath='{.status.readyToUse}' 2>/dev/null)
            error=$(kubectl get volumesnapshot $snapshot_name -n $NAMESPACE -o jsonpath='{.status.error.message}' 2>/dev/null)
            
            if [ "$status" = "true" ]; then
                echo "✅ Snapshot $snapshot_name is ready to use!"
                
                # Показать детали snapshot'а
                kubectl get volumesnapshot $snapshot_name -n $NAMESPACE -o custom-columns="NAME:.metadata.name,READY:.status.readyToUse,SOURCE:.spec.source.persistentVolumeClaimName,CLASS:.spec.volumeSnapshotClassName,AGE:.metadata.creationTimestamp"
                break
            elif [ -n "$error" ]; then
                echo "❌ Snapshot creation failed: $error"
                return 1
            else
                echo "  Attempt $i: Snapshot status = $status"
                sleep 10
            fi
        done
        
        # Показать события
        echo "Recent events for snapshot:"
        kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$snapshot_name --sort-by='.lastTimestamp' | tail -5
        
    else
        echo "❌ Failed to create snapshot $snapshot_name"
        return 1
    fi
    
    echo
}

# Функция для восстановления из snapshot'а
restore_from_snapshot() {
    local snapshot_name=$1
    local new_pvc_name=$2
    local description=${3:-"PVC restored from snapshot"}
    
    echo "=== Restoring PVC from Snapshot: $snapshot_name ==="
    
    # Проверить существование snapshot'а
    if ! kubectl get volumesnapshot $snapshot_name -n $NAMESPACE >/dev/null 2>&1; then
        echo "❌ Snapshot $snapshot_name not found in namespace $NAMESPACE"
        return 1
    fi
    
    # Проверить готовность snapshot'а
    ready=$(kubectl get volumesnapshot $snapshot_name -n $NAMESPACE -o jsonpath='{.status.readyToUse}')
    if [ "$ready" != "true" ]; then
        echo "❌ Snapshot $snapshot_name is not ready to use"
        return 1
    fi
    
    # Получить размер оригинального PVC
    original_size=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')
    storage_class=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
    
    echo "Original PVC size: $original_size"
    echo "Storage class: $storage_class"
    
    # Создать новый PVC из snapshot'а
    cat << RESTORE_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $new_pvc_name
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    snapshot.hashfoundry.io/restored-from: $snapshot_name
    snapshot.hashfoundry.io/type: restored
  annotations:
    snapshot.hashfoundry.io/description: "$description"
    snapshot.hashfoundry.io/source-snapshot: "$snapshot_name"
    snapshot.hashfoundry.io/restored-at: "$(date -Iseconds)"
spec:
  storageClassName: $storage_class
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $original_size
  dataSource:
    name: $snapshot_name
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
RESTORE_EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ PVC $new_pvc_name created from snapshot $snapshot_name"
        
        # Мониторинг создания PVC
        echo "Monitoring PVC creation..."
        for i in {1..30}; do
            status=$(kubectl get pvc $new_pvc_name -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
            
            if [ "$status" = "Bound" ]; then
                echo "✅ PVC $new_pvc_name is bound and ready!"
                
                # Показать детали PVC
                kubectl get pvc $new_pvc_name -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
                break
            else
                echo "  Attempt $i: PVC status = $status"
                sleep 10
            fi
        done
        
    else
        echo "❌ Failed to create PVC from snapshot"
        return 1
    fi
    
    echo
}

# Функция для создания приложения с восстановленными данными
create_restored_app() {
    local restored_pvc_name=$1
    local app_name="restored-data-app"
    
    echo "=== Creating Application with Restored Data ==="
    
    cat << APP_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app_name
  namespace: $NAMESPACE
  labels:
    app: $app_name
    snapshot.hashfoundry.io/type: restored
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app_name
  template:
    metadata:
      labels:
        app: $app_name
        snapshot.hashfoundry.io/type: restored
    spec:
      containers:
      - name: restored-data-viewer
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_snapshot_db"
        - name: POSTGRES_USER
          value: "snapshot_user"
        - name: POSTGRES_PASSWORD
          value: "snapshot_password_123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: restored-data-storage
          mountPath: /var/lib/postgresql/data
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Restored Data Viewer..."
          
          # Запустить PostgreSQL
          docker-entrypoint.sh postgres &
          
          # Подождать запуска
          sleep 30
          
          echo "Analyzing restored data..."
          
          # Проверить восстановленные данные
          psql -U snapshot_user -d hashfoundry_snapshot_db -c "
            -- Показать статистику восстановленных данных
            SELECT 'Restored Data Analysis' as analysis_type;
            SELECT * FROM get_data_stats();
            
            -- Показать примеры данных по версиям
            SELECT 
              snapshot_version,
              COUNT(*) as record_count,
              MIN(created_at) as earliest_record,
              MAX(created_at) as latest_record
            FROM snapshot_demo_data 
            GROUP BY snapshot_version 
            ORDER BY snapshot_version;
            
            -- Показать последние записи
            SELECT 
              id,
              snapshot_version,
              LEFT(data_content, 50) as data_preview,
              created_at
            FROM snapshot_demo_data 
            ORDER BY id DESC 
            LIMIT 10;
          "
          
          echo "Restored data analysis completed!"
          echo "Database is ready for queries..."
          
          # Продолжить работу PostgreSQL
          wait
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: restored-data-storage
        persistentVolumeClaim:
          claimName: $restored_pvc_name
APP_EOF
    
    echo "✅ Restored data application created: $app_name"
    echo
}

# Функция для добавления новых данных (для демонстрации версионирования)
add_version_data() {
    local version_num=$1
    local record_count=${2:-1000}
    
    echo "=== Adding Version $version_num Data ==="
    
    # Найти pod с оригинальными данными
    pod_name=$(kubectl get pods -n $NAMESPACE -l app=data-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        echo "❌ Data app pod not found"
        return 1
    fi
    
    echo "Adding data to pod: $pod_name"
    
    # Добавить новую версию данных
    kubectl exec $pod_name -n $NAMESPACE -- psql -U snapshot_user -d hashfoundry_snapshot_db -c "
        SELECT create_version_data($version_num, $record_count);
        SELECT * FROM get_data_stats();
    " 2>/dev/null || echo "Could not add version data"
    
    echo "✅ Version $version_num data added ($record_count records)"
    echo
}

# Функция для сравнения данных между оригиналом и восстановленным
compare_data() {
    local restored_pvc_name=$1
    
    echo "=== Comparing Original and Restored Data ==="
    
    # Найти оригинальный pod
    original_pod=$(kubectl get pods -n $NAMESPACE -l app=data-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    # Найти восстановленный pod
    restored_pod=$(kubectl get pods -n $NAMESPACE -l app=restored-data-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$original_pod" ] || [ -z "$restored_pod" ]; then
        echo "❌ Could not find both original and restored pods"
        return 1
    fi
    
    echo "Original pod: $original_pod"
    echo "Restored pod: $restored_pod"
    echo
    
    echo "Original data statistics:"
    kubectl exec $original_pod -n $NAMESPACE -- psql -U snapshot_user -d hashfoundry_snapshot_db -c "SELECT * FROM get_data_stats();" 2>/dev/null
    echo
    
    echo "Restored data statistics:"
    kubectl exec $restored_pod -n $NAMESPACE -- psql -U snapshot_user -d hashfoundry_snapshot_db -c "SELECT * FROM get_data_stats();" 2>/dev/null
    echo
}

# Функция для показа всех snapshots
list_snapshots() {
    echo "=== Volume Snapshots in namespace $NAMESPACE ==="
    
    kubectl get volumesnapshot -n $NAMESPACE -o custom-columns="NAME:.metadata.name,READY:.status.readyToUse,SOURCE:.spec.source.persistentVolumeClaimName,CLASS:.spec.volumeSnapshotClassName,CREATED:.metadata.creationTimestamp"
    echo
    
    echo "VolumeSnapshotContents:"
    kubectl get volumesnapshotcontent -o custom-columns="NAME:.metadata.name,READY:.status.readyToUse,SNAPSHOT:.spec.volumeSnapshotRef.name,SIZE:.status.restoreSize,CREATED:.metadata.creationTimestamp"
    echo
}

# Функция для демонстрации полного workflow
demonstrate_snapshot_workflow() {
    echo "=== Full Snapshot Workflow Demonstration ==="
    
    # 1. Показать начальное состояние
    echo "Step 1: Initial state"
    list_snapshots
    add_version_data 1 500
    
    # 2. Создать первый snapshot
    echo "Step 2: Creating first snapshot"
    create_snapshot "hashfoundry-snapshot-v1" "Snapshot of initial data (version 1)"
    
    # 3. Добавить новые данные
    echo "Step 3: Adding version 2 data"
    add_version_data 2 750
    
    # 4. Создать второй snapshot
    echo "Step 4: Creating second snapshot"
    create_snapshot "hashfoundry-snapshot-v2" "Snapshot after adding version 2 data"
    
    # 5. Добавить еще данных
    echo "Step 5: Adding version 3 data"
    add_version_data 3 1000
    
    # 6. Восстановить из первого snapshot'а
    echo "Step 6: Restoring from first snapshot"
    restore_from_snapshot "hashfoundry-snapshot-v1" "hashfoundry-restored-v1-pvc" "PVC restored from version 1 snapshot"
    
    # 7. Создать приложение с восстановленными данными
    echo "Step 7: Creating application with restored data"
    create_restored_app "hashfoundry-restored-v1-pvc"
    
    # 8. Подождать готовности приложения
    echo "Step 8: Waiting for restored application to be ready"
    sleep 60
    
    # 9. Сравнить данные
    echo "Step 9: Comparing original and restored data"
    compare_data "hashfoundry-restored-v1-pvc"
    
    # 10. Показать финальное состояние
    echo "Step 10: Final state"
    list_snapshots
}

# Основная функция
main() {
    case "$3" in
        "create")
            if [ -z "$4" ]; then
                echo "Usage: $0 $NAMESPACE $PVC_NAME create <snapshot-name> [description]"
                exit 1
            fi
            create_snapshot "$4" "$5"
            ;;
        "restore")
            if [ -z "$4" ] || [ -z "$5" ]; then
                echo "Usage: $0 $NAMESPACE $PVC_NAME restore <snapshot-name> <new-pvc-name> [description]"
                exit 1
            fi
            restore_from_snapshot "$4" "$5" "$6"
            ;;
        "add-data")
            version=${4:-2}
            count=${5:-1000}
            add_version_data $version $count
            ;;
        "compare")
            if [ -z "$4" ]; then
                echo "Usage: $0 $NAMESPACE $PVC_NAME compare <restored-pvc-name>"
                exit 1
            fi
            compare_data "$4"
            ;;
        "list")
            list_snapshots
            ;;
        "demo"|"full")
            demonstrate_snapshot_workflow
            ;;
        "app")
            if [ -z "$4" ]; then
                echo "Usage: $0 $NAMESPACE $PVC_NAME app <restored-pvc-name>"
                exit 1
            fi
            create_restored_app "$4"
            ;;
        *)
            echo "Usage: $0 [namespace] [pvc-name] [action] [args...]"
            echo ""
            echo "Actions:"
            echo "  create <name> [desc]     - Create snapshot"
            echo "  restore <snap> <pvc> [desc] - Restore PVC from snapshot"
            echo "  add-data [version] [count]  - Add versioned data"
            echo "  compare <restored-pvc>   - Compare original and restored data"
            echo "  list                     - List all snapshots"
            echo "  app <restored-pvc>       - Create app with restored data"
            echo "  demo                     - Full workflow demonstration"
            echo ""
            echo "Examples:"
            echo "  $0 volume-snapshot-demo hashfoundry-data-pvc create my-snapshot"
            echo "  $0 volume-snapshot-demo hashfoundry-data-pvc restore my-snapshot restored-pvc"
            echo "  $0 volume-snapshot-demo hashfoundry-data-pvc demo"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x manage-volume-snapshots.sh

# Запустить демонстрацию
./manage-volume-snapshots.sh volume-snapshot-demo hashfoundry-data-pvc demo
```

## 📋 **Основные команды для Volume Snapshots:**

### **Создание snapshot'а:**
```bash
kubectl apply -f - << EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
  namespace: my-namespace
spec:
  volumeSnapshotClassName: my-snapshot-class
  source:
    persistentVolumeClaimName: my-pvc
EOF
```

### **Восстановление из snapshot'а:**
```bash
kubectl apply -f - << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
  namespace: my-namespace
spec:
  storageClassName: my-storage-class
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF
```

### **Мониторинг snapshots:**
```bash
# Список snapshots
kubectl get volumesnapshot -n my-namespace

# Детали snapshot'а
kubectl describe volumesnapshot my-snapshot -n my-namespace

# Список VolumeSnapshotContents
kubectl get volumesnapshotcontent
```

## 🎯 **Best Practices для Volume Snapshots:**

### **Планирование:**
- **Регулярные snapshots** для критических данных
- **Retention policy** для управления lifecycle
- **Тестирование восстановления** в dev среде

### **Безопасность:**
- **Проверка готовности** snapshot'а перед использованием
- **Мониторинг процесса** создания и восстановления
- **Backup snapshots** в другие регионы

**Volume Snapshots обеспечивают надежную защиту данных в Kubernetes!**
