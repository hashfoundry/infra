# 63. StorageClass и Dynamic Provisioning

## 🎯 **StorageClass и Dynamic Provisioning**

**StorageClass** - это ресурс Kubernetes, который описывает "классы" хранилища, доступные в кластере. Он позволяет администраторам описать различные типы хранилища и их характеристики, а также обеспечивает **динамическое создание** Persistent Volumes по требованию.

## 🏗️ **Основные концепции:**

### **1. StorageClass**
- **Шаблон для создания** PV
- **Определяет provisioner** (поставщик хранилища)
- **Настраивает параметры** хранилища
- **Управляет политиками** reclaim и binding

### **2. Dynamic Provisioning**
- **Автоматическое создание** PV при создании PVC
- **Устраняет необходимость** в предварительном создании PV
- **Масштабируется по требованию**
- **Упрощает управление** хранилищем

### **3. Provisioner**
- **Компонент**, который создает PV
- **Специфичен для типа** хранилища
- **Интегрируется с cloud providers**
- **Поддерживает различные параметры**

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих StorageClasses:**
```bash
# Создать namespace для демонстрации StorageClass
kubectl create namespace storageclass-demo

# Проверить существующие StorageClasses в вашем HA кластере
echo "=== Existing StorageClasses in HA cluster ==="
kubectl get storageclass
kubectl get storageclass -o wide

# Детальная информация о StorageClasses
echo "=== Detailed StorageClass Information ==="
for sc in $(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}'); do
    echo "----------------------------------------"
    echo "StorageClass: $sc"
    kubectl describe storageclass $sc
    echo
done

# Проверить default StorageClass
echo "=== Default StorageClass ==="
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
echo

# Анализ provisioners
echo "=== Available Provisioners ==="
kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class"
```

### **2. Создание кастомных StorageClasses:**
```bash
# Создать различные StorageClasses для демонстрации
cat << EOF | kubectl apply -f -
# Fast SSD StorageClass (для DigitalOcean)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-fast-ssd
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: fast
    storage.hashfoundry.io/type: ssd
  annotations:
    storageclass.kubernetes.io/description: "Fast SSD storage for high-performance workloads"
    storageclass.kubernetes.io/created-by: "HashFoundry DevOps Team"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
---
# Standard HDD StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-standard-hdd
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: standard
    storage.hashfoundry.io/type: hdd
  annotations:
    storageclass.kubernetes.io/description: "Standard HDD storage for general workloads"
    storageclass.kubernetes.io/created-by: "HashFoundry DevOps Team"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Local NVMe StorageClass (для демонстрации)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-local-nvme
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: ultra-fast
    storage.hashfoundry.io/type: nvme
  annotations:
    storageclass.kubernetes.io/description: "Local NVMe storage for ultra-fast access"
    storageclass.kubernetes.io/created-by: "HashFoundry DevOps Team"
    storageclass.kubernetes.io/warning: "Data is not replicated across nodes"
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
allowVolumeExpansion: false
volumeBindingMode: WaitForFirstConsumer
---
# Backup StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-backup
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: backup
    storage.hashfoundry.io/type: archive
  annotations:
    storageclass.kubernetes.io/description: "Backup storage for long-term retention"
    storageclass.kubernetes.io/created-by: "HashFoundry DevOps Team"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: Immediate
EOF

# Проверить созданные StorageClasses
kubectl get storageclass -l app.kubernetes.io/name=hashfoundry-storage
kubectl describe storageclass hashfoundry-fast-ssd
```

### **3. Демонстрация Dynamic Provisioning:**
```bash
# Создать PVCs с различными StorageClasses для демонстрации dynamic provisioning
cat << EOF | kubectl apply -f -
# PVC с fast SSD storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-fast-database-pvc
  namespace: storageclass-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: fast
    storage.hashfoundry.io/purpose: database
  annotations:
    storage.hashfoundry.io/description: "Fast SSD storage for database workload"
    storage.hashfoundry.io/performance-requirement: "high-iops"
spec:
  storageClassName: hashfoundry-fast-ssd
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
# PVC с standard HDD storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-standard-logs-pvc
  namespace: storageclass-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: standard
    storage.hashfoundry.io/purpose: logs
  annotations:
    storage.hashfoundry.io/description: "Standard HDD storage for log files"
    storage.hashfoundry.io/performance-requirement: "standard"
spec:
  storageClassName: hashfoundry-standard-hdd
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
---
# PVC с backup storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-backup-archive-pvc
  namespace: storageclass-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: backup
    storage.hashfoundry.io/purpose: archive
  annotations:
    storage.hashfoundry.io/description: "Backup storage for data archival"
    storage.hashfoundry.io/retention-policy: "long-term"
spec:
  storageClassName: hashfoundry-backup
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi
---
# PVC с default StorageClass (без указания storageClassName)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-default-app-pvc
  namespace: storageclass-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/tier: default
    storage.hashfoundry.io/purpose: application
  annotations:
    storage.hashfoundry.io/description: "Default storage for general application use"
spec:
  # Не указываем storageClassName - будет использован default
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
EOF

# Мониторинг процесса dynamic provisioning
echo "=== Monitoring Dynamic Provisioning ==="
echo "Watching PVC creation and binding..."

# Проверить статус PVCs
kubectl get pvc -n storageclass-demo
echo

# Проверить автоматически созданные PVs
echo "=== Dynamically Created PVs ==="
kubectl get pv | grep storageclass-demo || echo "No PVs created yet"
echo

# Проверить события provisioning
echo "=== Provisioning Events ==="
kubectl get events -n storageclass-demo --sort-by='.lastTimestamp' | grep -i "provision\|volume\|pvc"
echo

# Детальная информация о PVCs
for pvc in $(kubectl get pvc -n storageclass-demo -o jsonpath='{.items[*].metadata.name}'); do
    echo "----------------------------------------"
    echo "PVC: $pvc"
    kubectl describe pvc $pvc -n storageclass-demo | grep -A 10 -B 5 "StorageClass\|Volume\|Events"
    echo
done
```

### **4. Создание приложений с различными типами хранилища:**
```bash
# Создать приложения, демонстрирующие использование различных StorageClasses
cat << EOF | kubectl apply -f -
# High-performance database с fast SSD
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hashfoundry-fast-database
  namespace: storageclass-demo
  labels:
    app: fast-database
    storage.tier: fast
spec:
  serviceName: fast-database-service
  replicas: 1
  selector:
    matchLabels:
      app: fast-database
  template:
    metadata:
      labels:
        app: fast-database
        storage.tier: fast
      annotations:
        storage.hashfoundry.io/storageclass: "hashfoundry-fast-ssd"
        storage.hashfoundry.io/performance: "high-iops"
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_fast_db"
        - name: POSTGRES_USER
          value: "fast_user"
        - name: POSTGRES_PASSWORD
          value: "fast_password_123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: fast-database-storage
          mountPath: /var/lib/postgresql/data
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting high-performance PostgreSQL with fast SSD storage..."
          
          # Настроить PostgreSQL для высокой производительности
          cat >> /var/lib/postgresql/data/postgresql.conf << 'POSTGRES_EOF'
          # High-performance settings for SSD storage
          shared_buffers = 256MB
          effective_cache_size = 1GB
          maintenance_work_mem = 64MB
          checkpoint_completion_target = 0.9
          wal_buffers = 16MB
          default_statistics_target = 100
          random_page_cost = 1.1
          effective_io_concurrency = 200
          POSTGRES_EOF
          
          # Запустить PostgreSQL
          docker-entrypoint.sh postgres &
          
          # Подождать запуска и создать демонстрационные данные
          sleep 30
          
          psql -U fast_user -d hashfoundry_fast_db -c "
            CREATE TABLE IF NOT EXISTS performance_test (
              id SERIAL PRIMARY KEY,
              storage_class VARCHAR(50) DEFAULT 'hashfoundry-fast-ssd',
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              data TEXT,
              random_data BYTEA
            );
            
            -- Создать индекс для тестирования производительности
            CREATE INDEX IF NOT EXISTS idx_performance_created_at ON performance_test(created_at);
            
            -- Вставить тестовые данные
            INSERT INTO performance_test (data, random_data) 
            SELECT 
              'Fast SSD performance test data - ' || generate_series,
              decode(md5(random()::text), 'hex')
            FROM generate_series(1, 10000);
            
            -- Создать статистику
            ANALYZE performance_test;
          "
          
          echo "High-performance database ready with fast SSD storage!"
          wait
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - fast_user
            - -d
            - hashfoundry_fast_db
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: fast-database-storage
        persistentVolumeClaim:
          claimName: hashfoundry-fast-database-pvc
---
# Log aggregator с standard HDD
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-log-aggregator
  namespace: storageclass-demo
  labels:
    app: log-aggregator
    storage.tier: standard
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-aggregator
  template:
    metadata:
      labels:
        app: log-aggregator
        storage.tier: standard
      annotations:
        storage.hashfoundry.io/storageclass: "hashfoundry-standard-hdd"
        storage.hashfoundry.io/performance: "standard"
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.14
        ports:
        - containerPort: 24224
        volumeMounts:
        - name: log-storage
          mountPath: /var/log/fluentd
        - name: fluentd-config
          mountPath: /fluentd/etc
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting log aggregator with standard HDD storage..."
          
          # Создать конфигурацию Fluentd
          cat > /fluentd/etc/fluent.conf << 'FLUENTD_EOF'
          <source>
            @type forward
            port 24224
            bind 0.0.0.0
          </source>
          
          <source>
            @type dummy
            tag hashfoundry.demo
            dummy {"message":"Demo log entry from HashFoundry", "storage_class":"hashfoundry-standard-hdd", "timestamp":"#{Time.now}"}
            rate 1
          </source>
          
          <match hashfoundry.**>
            @type file
            path /var/log/fluentd/hashfoundry
            append true
            time_slice_format %Y%m%d%H
            time_slice_wait 10s
            time_format %Y-%m-%dT%H:%M:%S%z
            format json
            include_time_key true
          </match>
          
          <match **>
            @type file
            path /var/log/fluentd/all
            append true
            time_slice_format %Y%m%d%H
            time_slice_wait 10s
            time_format %Y-%m-%dT%H:%M:%S%z
            format json
            include_time_key true
          </match>
          FLUENTD_EOF
          
          # Создать директории для логов
          mkdir -p /var/log/fluentd/hashfoundry
          mkdir -p /var/log/fluentd/all
          
          # Создать демонстрационные логи
          cat > /var/log/fluentd/storage_info.log << 'LOG_EOF'
          {"timestamp":"$(date -Iseconds)","message":"Log aggregator started","storage_class":"hashfoundry-standard-hdd","storage_type":"HDD","performance_tier":"standard","purpose":"log_aggregation"}
          {"timestamp":"$(date -Iseconds)","message":"Storage mounted successfully","mount_point":"/var/log/fluentd","storage_size":"100Gi","filesystem":"ext4"}
          {"timestamp":"$(date -Iseconds)","message":"Fluentd configuration loaded","config_file":"/fluentd/etc/fluent.conf","log_retention":"30_days"}
          LOG_EOF
          
          echo "Log aggregator ready with standard HDD storage!"
          
          # Запустить Fluentd
          fluentd -c /fluentd/etc/fluent.conf -v
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: log-storage
        persistentVolumeClaim:
          claimName: hashfoundry-standard-logs-pvc
      - name: fluentd-config
        emptyDir: {}
---
# Backup service с backup storage
apiVersion: apps/v1
kind: CronJob
metadata:
  name: hashfoundry-backup-service
  namespace: storageclass-demo
  labels:
    app: backup-service
    storage.tier: backup
spec:
  schedule: "0 2 * * *"  # Каждый день в 2:00
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: backup-service
            storage.tier: backup
          annotations:
            storage.hashfoundry.io/storageclass: "hashfoundry-backup"
            storage.hashfoundry.io/purpose: "backup-archive"
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox:1.35
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
            command: ["sh", "-c"]
            args:
            - |
              echo "Starting backup service with backup storage..."
              
              # Создать структуру директорий для backup
              mkdir -p /backup/daily/$(date +%Y/%m/%d)
              mkdir -p /backup/weekly/$(date +%Y/week_%U)
              mkdir -p /backup/monthly/$(date +%Y/%m)
              
              # Создать демонстрационный backup
              backup_date=$(date +%Y%m%d_%H%M%S)
              backup_dir="/backup/daily/$(date +%Y/%m/%d)"
              
              cat > "$backup_dir/backup_$backup_date.log" << BACKUP_EOF
              Backup Information:
              ===================
              Backup Date: $(date -Iseconds)
              Storage Class: hashfoundry-backup
              Storage Type: Archive/Backup
              Retention Policy: Long-term
              Backup Size: $(du -sh /backup 2>/dev/null | cut -f1 || echo 'Unknown')
              
              Backup Contents:
              - Database dumps
              - Application logs
              - Configuration files
              - User data
              
              Storage Details:
              - Mount Point: /backup
              - Storage Size: 200Gi
              - Filesystem: ext4
              - Reclaim Policy: Retain
              
              Backup Status: SUCCESS
              BACKUP_EOF
              
              # Создать метаданные backup
              cat > "$backup_dir/metadata.json" << METADATA_EOF
              {
                "backup_id": "backup_$backup_date",
                "timestamp": "$(date -Iseconds)",
                "storage_class": "hashfoundry-backup",
                "storage_tier": "backup",
                "retention_days": 365,
                "backup_type": "full",
                "compression": "gzip",
                "encryption": "aes256",
                "size_bytes": $(stat -c%s "$backup_dir/backup_$backup_date.log" 2>/dev/null || echo 0),
                "checksum": "$(md5sum "$backup_dir/backup_$backup_date.log" | cut -d' ' -f1 2>/dev/null || echo 'unknown')"
              }
              METADATA_EOF
              
              # Создать индекс всех backup'ов
              echo "$(date -Iseconds): backup_$backup_date completed successfully" >> /backup/backup_index.log
              
              echo "Backup completed successfully!"
              echo "Backup stored in: $backup_dir"
              echo "Total backups: $(find /backup -name "backup_*.log" | wc -l)"
              
              # Показать статистику хранилища
              echo "Storage usage:"
              df -h /backup
              
              echo "Backup files:"
              find /backup -type f -name "*.log" -o -name "*.json" | head -10
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: hashfoundry-backup-archive-pvc
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: fast-database-service
  namespace: storageclass-demo
  labels:
    app: fast-database
spec:
  selector:
    app: fast-database
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
---
apiVersion: v1
kind: Service
metadata:
  name: log-aggregator-service
  namespace: storageclass-demo
  labels:
    app: log-aggregator
spec:
  selector:
    app: log-aggregator
  ports:
  - port: 24224
    targetPort: 24224
  type: ClusterIP
EOF

# Проверить развертывания
kubectl get pods,pvc,pv -n storageclass-demo
kubectl get statefulsets,deployments,cronjobs -n storageclass-demo
```

### **5. Анализ и мониторинг StorageClass:**
```bash
# Создать скрипт для анализа StorageClass и dynamic provisioning
cat << 'EOF' > analyze-storageclass.sh
#!/bin/bash

NAMESPACE=${1:-"storageclass-demo"}

echo "=== StorageClass and Dynamic Provisioning Analysis ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для анализа StorageClasses
analyze_storage_classes() {
    echo "=== StorageClass Analysis ==="
    
    echo "All StorageClasses in cluster:"
    kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode,EXPANSION:.allowVolumeExpansion,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class"
    echo
    
    # Детальный анализ каждого StorageClass
    for sc in $(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}'); do
        echo "----------------------------------------"
        echo "StorageClass: $sc"
        
        # Основная информация
        provisioner=$(kubectl get storageclass $sc -o jsonpath='{.provisioner}')
        reclaim_policy=$(kubectl get storageclass $sc -o jsonpath='{.reclaimPolicy}')
        binding_mode=$(kubectl get storageclass $sc -o jsonpath='{.volumeBindingMode}')
        expansion=$(kubectl get storageclass $sc -o jsonpath='{.allowVolumeExpansion}')
        is_default=$(kubectl get storageclass $sc -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')
        
        echo "  Provisioner: $provisioner"
        echo "  Reclaim Policy: ${reclaim_policy:-"Delete"}"
        echo "  Volume Binding Mode: ${binding_mode:-"Immediate"}"
        echo "  Allow Volume Expansion: ${expansion:-"false"}"
        echo "  Default: ${is_default:-"false"}"
        
        # Параметры
        echo "  Parameters:"
        kubectl get storageclass $sc -o jsonpath='{.parameters}' | jq '.' 2>/dev/null || echo "    No parameters"
        
        # Использование
        echo "  Used by PVCs:"
        pvc_count=$(kubectl get pvc --all-namespaces -o json | jq --arg sc "$sc" '[.items[] | select(.spec.storageClassName == $sc)] | length' 2>/dev/null || echo 0)
        echo "    Total PVCs: $pvc_count"
        
        if [ "$pvc_count" -gt 0 ]; then
            kubectl get pvc --all-namespaces -o json | jq -r --arg sc "$sc" '.items[] | select(.spec.storageClassName == $sc) | "    - " + .metadata.namespace + "/" + .metadata.name + " (" + .status.capacity.storage + ")"' 2>/dev/null
        fi
        
        echo
    done
}

# Функция для анализа dynamic provisioning
analyze_dynamic_provisioning() {
    echo "=== Dynamic Provisioning Analysis ==="
    
    echo "PVCs in namespace $NAMESPACE:"
    kubectl get pvc -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,AGE:.metadata.creationTimestamp" 2>/dev/null || echo "No PVCs found"
    echo
    
    echo "Dynamically provisioned PVs:"
    kubectl get pv -o json | jq -r --arg ns "$NAMESPACE" '.items[] | select(.spec.claimRef.namespace == $ns) | "  - " + .metadata.name + " (StorageClass: " + (.spec.storageClassName // "none") + ", Size: " + .spec.capacity.storage + ")"' 2>/dev/null || echo "No dynamically provisioned PVs found"
    echo
    
    # Анализ каждого PVC
    pvcs=($(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pvc in "${pvcs[@]}"; do
        if [ -z "$pvc" ]; then
            continue
        fi
        
        echo "----------------------------------------"
        echo "PVC: $pvc"
        
        storage_class=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
        status=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}')
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        requested_size=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')
        actual_size=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.capacity.storage}')
        
        echo "  StorageClass: ${storage_class:-"<default>"}"
        echo "  Status: $status"
        echo "  Requested Size: $requested_size"
        echo "  Actual Size: ${actual_size:-"N/A"}"
        echo "  Bound to PV: ${volume_name:-"<none>"}"
        
        # Информация о provisioning
        if [ -n "$volume_name" ]; then
            pv_provisioner=$(kubectl get pv $volume_name -o jsonpath='{.metadata.annotations.pv\.kubernetes\.io/provisioned-by}' 2>/dev/null)
            echo "  Provisioned by: ${pv_provisioner:-"Unknown"}"
            
            # Время создания
            pv_created=$(kubectl get pv $volume_name -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
            pvc_created=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
            echo "  PVC Created: $pvc_created"
            echo "  PV Created: ${pv_created:-"Unknown"}"
        fi
        
        # События provisioning
        echo "  Recent Events:"
        kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$pvc --sort-by='.lastTimestamp' | tail -3 | while read line; do
            echo "    $line"
        done
        
        echo
    done
}

# Функция для тестирования производительности различных StorageClasses
test_storage_performance() {
    echo "=== Storage Performance Testing ==="
    
    # Найти Pod'ы с различными типами хранилища
    fast_pod=$(kubectl get pods -n $NAMESPACE -l storage.tier=fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    standard_pod=$(kubectl get pods -n $NAMESPACE -l storage.tier=standard -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$fast_pod" ]; then
        echo "Testing fast SSD storage performance:"
        echo "  Pod: $fast_pod"
        kubectl exec $fast_pod -n $NAMESPACE -- sh -c "
            echo 'Fast SSD Performance Test:'
            echo 'Write test:'
            time dd if=/dev/zero of=/var/lib/postgresql/data/test_write bs=1M count=100 2>&1 | grep -E 'copied|MB/s'
            echo 'Read test:'
            time dd if=/var/lib/postgresql/data/test_write of=/dev/null bs=1M 2>&1 | grep -E 'copied|MB/s'
            rm -f /var/lib/postgresql/data/test_write
        " 2>/dev/null || echo "  Performance test failed"
        echo
    fi
    
    if [ -n "$standard_pod" ]; then
        echo "Testing standard HDD storage performance:"
        echo "  Pod: $standard_pod"
        kubectl exec $standard_pod -n $NAMESPACE -- sh -c "
            echo 'Standard HDD Performance Test:'
            echo 'Write test:'
            time dd if=/dev/zero of=/var/log/fluentd/test_write bs=1M count=100 2>&1 | grep -E 'copied|MB/s'
            echo 'Read test:'
            time dd if=/var/log/fluentd/test_write of=/dev/null bs=1M 2>&1 | grep -E 'copied|MB/s'
            rm -f /var/log/fluentd/test_write
        " 2>/dev/null || echo "  Performance test failed"
        echo
    fi
}

# Функция для демонстрации volume expansion
demonstrate_volume_expansion() {
    echo "=== Volume Expansion Demo ==="
    
    # Найти PVC с allowVolumeExpansion=true
    expandable_pvcs=$(kubectl get pvc -n $NAMESPACE -o json | jq -r '.items[] | select(.spec.storageClassName) | .metadata.name + ":" + .spec.storageClassName' 2>/dev/null)
    
    for pvc_info in $expandable_pvcs; do
        pvc_name=$(echo $pvc_info | cut -d':' -f1)
        storage_class=$(echo $pvc_info | cut -d':' -f2)
        
        # Проверить, поддерживает ли StorageClass expansion
        expansion_allowed=$(kubectl get storageclass $storage_class -o jsonpath='{.allowVolumeExpansion}' 2>/dev/null)
        
        if [ "$expansion_allowed" = "true" ]; then
            echo "PVC $pvc_name (StorageClass: $storage_class) supports volume expansion"
            
            current_size=$(kubectl get pvc $pvc_name -n $NAMESPACE -o jsonpath='{.status.capacity.storage}')
            echo "  Current size: $current_size"
            echo "  Expansion supported: Yes"
            
            # Показать, как можно расширить volume (не выполняем реально)
            echo "  To expand this volume, run:"
            echo "    kubectl patch pvc $pvc_name -n $NAMESPACE -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"<NEW_SIZE>\"}}}}'"
        else
            echo "PVC $pvc_name (StorageClass: $storage_class) does not support volume expansion"
        fi
        echo
    done
}

# Функция для анализа provisioner'ов
analyze_provisioners() {
    echo "=== Provisioner Analysis ==="
    
    # Группировка StorageClasses по provisioner'ам
    echo "StorageClasses by Provisioner:"
    kubectl get storageclass -o json | jq -r '.items | group_by(.provisioner) | .[] | "  " + .[0].provisioner + ":" + (map("    - " + .metadata.name) | join("\n"))' 2>/dev/null
    echo
    
    # Анализ каждого provisioner'а
    provisioners=($(kubectl get storageclass -o jsonpath='{.items[*].provisioner}' | tr ' ' '\n' | sort -u))
    
    for provisioner in "${provisioners[@]}"; do
        if [ -z "$provisioner" ]; then
            continue
        fi
        
        echo "----------------------------------------"
        echo "Provisioner: $provisioner"
        
        # Найти StorageClasses для этого provisioner'а
        storage_classes=$(kubectl get storageclass -o json | jq -r --arg prov "$provisioner" '.items[] | select(.provisioner == $prov) | .metadata.name' 2>/dev/null)
        
        echo "  StorageClasses:"
        for sc in $storage_classes; do
            echo "    - $sc"
        done
        
        # Подсчитать использование
        total_pvcs=0
        for sc in $storage_classes; do
            pvc_count=$(kubectl get pvc --all-namespaces -o json | jq --arg sc "$sc" '[.items[] | select(.spec.storageClassName == $sc)] | length' 2>/dev/null || echo 0)
            total_pvcs=$((total_pvcs + pvc_count))
        done
        
        echo "  Total PVCs using this provisioner: $total_pvcs"
        
        # Определить тип provisioner'а
        case "$provisioner" in
            *"digitalocean"*)
                echo "  Type: DigitalOcean Block Storage"
                echo "  Features: Dynamic provisioning, Volume expansion, Snapshots"
                ;;
            *"ebs"*)
                echo "  Type: AWS Elastic Block Store"
                echo "  Features: Dynamic provisioning, Volume expansion, Snapshots, Encryption"
                ;;
            *"gce"*)
                echo "  Type: Google Compute Engine Persistent Disk"
                echo "  Features: Dynamic provisioning, Volume expansion, Snapshots"
                ;;
            *"azure"*)
                echo "  Type: Azure Disk Storage"
                echo "  Features: Dynamic provisioning, Volume expansion, Snapshots"
                ;;
            *"nfs"*)
                echo "  Type: Network File System"
                echo "  Features: ReadWriteMany support, Shared storage"
                ;;
            *"local"*|*"no-provisioner"*)
                echo "  Type: Local/Static provisioning"
                echo "  Features: High performance, Node-specific storage"
                ;;
            *)
                echo "  Type: Custom/Other"
                ;;
        esac
        
        echo
    done
}

# Функция для создания сравнительной таблицы StorageClasses
create_storageclass_comparison() {
    echo "=== StorageClass Comparison Table ==="
    
    cat << 'TABLE_EOF'
+----------------------+------------------+------------------+------------------+------------------+
| Feature              | Fast SSD        | Standard HDD     | Local NVMe       | Backup Archive   |
+----------------------+------------------+------------------+------------------+------------------+
| Performance          | High IOPS       | Standard         | Ultra High       | Low (Archive)    |
| Cost                 | High             | Medium           | Variable         | Low              |
| Durability           | High             | High             | Node-dependent   | Very High        |
| Availability         | Multi-AZ         | Multi-AZ         | Single Node      | Multi-AZ         |
| Use Cases            | Databases        | Logs, General    | Cache, Temp      | Backups, Archive |
|                      | High-perf apps   | Applications     | High-perf        | Long-term data   |
+----------------------+------------------+------------------+------------------+------------------+
| Volume Expansion     | ✅ Yes           | ✅ Yes           | ❌ No            | ✅ Yes           |
| Snapshots            | ✅ Yes           | ✅ Yes           | ❌ No            | ✅ Yes           |
| Encryption           | ✅ Yes           | ✅ Yes           | Depends          | ✅ Yes           |
| Access Modes         | RWO              | RWO              | RWO              | RWO              |
| Reclaim Policy       | Delete           | Retain           | Delete           | Retain           |
| Binding Mode         | Immediate        | WaitForConsumer  | WaitForConsumer  | Immediate        |
+----------------------+------------------+------------------+------------------+------------------+

Dynamic Provisioning Workflow:
1. User creates PVC with storageClassName
2. Kubernetes finds matching StorageClass
3. Provisioner creates underlying storage
4. PV is automatically created and bound to PVC
5. Pod can mount the volume

Volume Binding Modes:
- Immediate: PV created immediately when PVC is created
- WaitForFirstConsumer: PV created when first Pod uses the PVC
TABLE_EOF
    
    echo
}

# Основная функция
main() {
    case "$2" in
        "storageclass"|"sc")
            analyze_storage_classes
            ;;
        "provisioning"|"dynamic")
            analyze_dynamic_provisioning
            ;;
        "performance"|"perf")
            test_storage_performance
            ;;
        "expansion"|"expand")
            demonstrate_volume_expansion
            ;;
        "provisioners"|"prov")
            analyze_provisioners
            ;;
        "compare"|"comparison")
            create_storageclass_comparison
            ;;
        "all"|"")
            analyze_storage_classes
            analyze_dynamic_provisioning
            test_storage_performance
            demonstrate_volume_expansion
            analyze_provisioners
            create_storageclass_comparison
            ;;
        *)
            echo "Usage: $0 [namespace] [analysis_type]"
            echo ""
            echo "Analysis types:"
            echo "  storageclass  - Analyze StorageClasses"
            echo "  provisioning  - Analyze dynamic provisioning"
            echo "  performance   - Test storage performance"
            echo "  expansion     - Demonstrate volume expansion"
            echo "  provisioners  - Analyze provisioners"
            echo "  compare       - Show comparison table"
            echo "  all           - Run all analyses (default)"
            echo ""
            echo "Examples:"
            echo "  $0 storageclass-demo"
            echo "  $0 storageclass-demo performance"
            echo "  $0 storageclass-demo compare"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x analyze-storageclass.sh

# Запустить анализ
./analyze-storageclass.sh storageclass-demo
```

## 🧹 **Очистка ресурсов:**
```bash
# Создать скрипт для очистки демонстрации StorageClass
cat << 'EOF' > cleanup-storageclass-demo.sh
#!/bin/bash

NAMESPACE="storageclass-demo"

echo "=== Cleaning up StorageClass Demo ==="
echo

# Удалить CronJobs
echo "Deleting cronjobs..."
kubectl delete cronjobs --all -n $NAMESPACE

# Удалить Deployments и StatefulSets
echo "Deleting deployments and statefulsets..."
kubectl delete deployments,statefulsets --all -n $NAMESPACE

# Подождать завершения Pod'ов
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pods --all -n $NAMESPACE --timeout=120s

# Удалить все PVC
echo "Deleting PVCs..."
kubectl delete pvc --all -n $NAMESPACE

# Удалить кастомные StorageClasses
echo "Deleting custom StorageClasses..."
kubectl delete storageclass -l app.kubernetes.io/name=hashfoundry-storage

# Удалить Services
echo "Deleting services..."
kubectl delete services --all -n $NAMESPACE

# Удалить namespace
echo "Deleting namespace..."
kubectl delete namespace $NAMESPACE

# Удалить локальные файлы
echo "Cleaning up local files..."
rm -f analyze-storageclass.sh

echo "✓ StorageClass demo cleanup completed"

EOF

chmod +x cleanup-storageclass-demo.sh
./cleanup-storageclass-demo.sh
```

## 📋 **Сводка StorageClass и Dynamic Provisioning:**

### **Основные команды:**
```bash
# Просмотр StorageClasses
kubectl get storageclass
kubectl describe storageclass <storageclass-name>

# Создание PVC с определенным StorageClass
kubectl apply -f pvc-with-storageclass.yaml

# Проверка dynamic provisioning
kubectl get pvc
kubectl get pv
kubectl get events --sort-by='.lastTimestamp'

# Расширение volume
kubectl patch pvc <pvc-name> -p '{"spec":{"resources":{"requests":{"storage":"<new-size>"}}}}'
```

## 📊 **Сравнительная таблица StorageClass параметров:**

| **Параметр** | **Описание** | **Значения** | **Влияние** |
|--------------|--------------|--------------|-------------|
| **provisioner** | Поставщик хранилища | CSI driver name | Определяет тип хранилища |
| **reclaimPolicy** | Политика освобождения | Delete/Retain | Что происходит с PV после удаления PVC |
| **volumeBindingMode** | Режим привязки | Immediate/WaitForFirstConsumer | Когда создается PV |
| **allowVolumeExpansion** | Разрешение расширения | true/false | Можно ли увеличить размер |

## 🎯 **Best Practices:**

### **1. Планирование StorageClasses:**
- **Создавайте разные классы** для разных workloads
- **Используйте понятные имена** и labels
- **Документируйте параметры** в annotations
- **Тестируйте производительность** каждого класса

### **2. Dynamic Provisioning:**
- **Используйте WaitForFirstConsumer** для topology-aware provisioning
- **Настройте default StorageClass** для удобства
- **Мониторьте события** provisioning
- **Планируйте capacity** заранее

### **3. Управление жизненным циклом:**
- **Выбирайте правильную reclaim policy**
- **Используйте volume expansion** вместо пересоздания
- **Регулярно очищайте** неиспользуемые PV
- **Мониторьте costs** различных типов хранилища

**StorageClass и Dynamic Provisioning автоматизируют управление хранилищем в Kubernetes!**
