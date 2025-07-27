# 67. PVC Resizing (Volume Expansion)

## 🎯 **PVC Resizing (Volume Expansion)**

**Volume Expansion** позволяет увеличивать размер Persistent Volume Claims без пересоздания Pod'ов или потери данных. Это критически важная функция для растущих приложений и баз данных.

## 🏗️ **Основные концепции:**

### **Требования для расширения:**
- **StorageClass должен поддерживать** `allowVolumeExpansion: true`
- **CSI driver должен поддерживать** volume expansion
- **Файловая система** должна поддерживать online resize
- **PVC должен быть в состоянии** Bound

### **Типы расширения:**
- **Online Expansion** - без остановки Pod'а
- **Offline Expansion** - требует перезапуска Pod'а
- **File System Expansion** - автоматическое расширение FS

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание демонстрационной среды:**
```bash
# Создать namespace для демонстрации volume expansion
kubectl create namespace volume-expansion-demo

# Создать labels для организации
kubectl label namespace volume-expansion-demo \
  demo.type=volume-expansion \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational

# Проверить поддержку expansion в существующих StorageClasses
echo "=== StorageClass Expansion Support in HA cluster ==="
kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,EXPANSION:.allowVolumeExpansion,RECLAIM:.reclaimPolicy"
echo

# Проверить CSI drivers и их возможности
echo "=== CSI Drivers in cluster ==="
kubectl get csidriver -o custom-columns="NAME:.metadata.name,ATTACH:.spec.attachRequired,POD_INFO:.spec.podInfoOnMount,VOLUME_LIFECYCLE:.spec.volumeLifecycleModes[*]"
```

### **2. Создание StorageClasses с поддержкой expansion:**
```bash
# Создать StorageClasses с различными настройками expansion
cat << EOF | kubectl apply -f -
# Expandable StorageClass для стандартного хранилища
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-expandable-standard
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/expansion: enabled
    storage.hashfoundry.io/tier: standard
  annotations:
    storageclass.kubernetes.io/description: "Expandable standard storage for general workloads"
    storageclass.kubernetes.io/expansion-support: "online"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
---
# Expandable StorageClass для высокопроизводительного хранилища
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-expandable-performance
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/expansion: enabled
    storage.hashfoundry.io/tier: performance
  annotations:
    storageclass.kubernetes.io/description: "Expandable high-performance storage"
    storageclass.kubernetes.io/expansion-support: "online"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Non-expandable StorageClass для сравнения
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-non-expandable
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/expansion: disabled
    storage.hashfoundry.io/tier: basic
  annotations:
    storageclass.kubernetes.io/description: "Non-expandable storage for demonstration"
    storageclass.kubernetes.io/expansion-support: "none"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: false
volumeBindingMode: Immediate
EOF

# Проверить созданные StorageClasses
kubectl get storageclass -l app.kubernetes.io/name=hashfoundry-storage
```

### **3. Создание PVCs для демонстрации expansion:**
```bash
# Создать PVCs с различными начальными размерами
cat << EOF | kubectl apply -f -
# Expandable PVC для базы данных
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-database-pvc
  namespace: volume-expansion-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/expansion: enabled
    storage.hashfoundry.io/purpose: database
  annotations:
    storage.hashfoundry.io/description: "Expandable PVC for database storage"
    storage.hashfoundry.io/initial-size: "20Gi"
spec:
  storageClassName: hashfoundry-expandable-standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
# Expandable PVC для логов
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-logs-pvc
  namespace: volume-expansion-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/expansion: enabled
    storage.hashfoundry.io/purpose: logs
  annotations:
    storage.hashfoundry.io/description: "Expandable PVC for log storage"
    storage.hashfoundry.io/initial-size: "10Gi"
spec:
  storageClassName: hashfoundry-expandable-performance
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
# Non-expandable PVC для сравнения
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-fixed-pvc
  namespace: volume-expansion-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/expansion: disabled
    storage.hashfoundry.io/purpose: cache
  annotations:
    storage.hashfoundry.io/description: "Non-expandable PVC for demonstration"
    storage.hashfoundry.io/initial-size: "5Gi"
spec:
  storageClassName: hashfoundry-non-expandable
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# Проверить создание PVCs
kubectl get pvc -n volume-expansion-demo
kubectl get pv | grep volume-expansion-demo
```

### **4. Создание приложений для демонстрации expansion:**
```bash
# Создать приложения, которые будут использовать expandable storage
cat << EOF | kubectl apply -f -
# База данных с expandable storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hashfoundry-expandable-database
  namespace: volume-expansion-demo
  labels:
    app: expandable-database
    storage.hashfoundry.io/expansion: enabled
spec:
  serviceName: expandable-database-service
  replicas: 1
  selector:
    matchLabels:
      app: expandable-database
  template:
    metadata:
      labels:
        app: expandable-database
        storage.hashfoundry.io/expansion: enabled
      annotations:
        storage.hashfoundry.io/expansion-demo: "database"
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_expansion_db"
        - name: POSTGRES_USER
          value: "expansion_user"
        - name: POSTGRES_PASSWORD
          value: "expansion_password_123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Expandable Database Demo..."
          
          # Инициализировать PostgreSQL
          docker-entrypoint.sh postgres &
          
          # Подождать запуска PostgreSQL
          sleep 30
          
          # Создать демонстрационные данные для тестирования expansion
          psql -U expansion_user -d hashfoundry_expansion_db -c "
            CREATE TABLE IF NOT EXISTS storage_expansion_demo (
              id SERIAL PRIMARY KEY,
              expansion_step INTEGER DEFAULT 0,
              storage_size VARCHAR(20),
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              data_content TEXT,
              file_system_info JSONB
            );
            
            -- Создать функцию для мониторинга размера хранилища
            CREATE OR REPLACE FUNCTION get_storage_info()
            RETURNS TABLE(
              metric_name TEXT,
              metric_value TEXT
            ) AS \$\$
            BEGIN
              RETURN QUERY
              SELECT 'Database Size'::TEXT, pg_size_pretty(pg_database_size(current_database()))::TEXT
              UNION ALL
              SELECT 'Total Relations Size'::TEXT, pg_size_pretty(pg_total_relation_size('storage_expansion_demo'))::TEXT
              UNION ALL
              SELECT 'Table Size'::TEXT, pg_size_pretty(pg_relation_size('storage_expansion_demo'))::TEXT
              UNION ALL
              SELECT 'Index Size'::TEXT, pg_size_pretty(pg_indexes_size('storage_expansion_demo'))::TEXT;
            END;
            \$\$ LANGUAGE plpgsql;
            
            -- Вставить начальные данные
            INSERT INTO storage_expansion_demo (expansion_step, storage_size, data_content) VALUES 
            (0, '20Gi', 'Initial data before expansion'),
            (0, '20Gi', 'Database ready for expansion testing');
          "
          
          # Создать скрипт для генерации данных
          cat > /var/lib/postgresql/data/generate_data.sql << 'DATA_EOF'
          -- Скрипт для генерации данных для тестирования expansion
          DO \$\$
          DECLARE
              i INTEGER;
              current_step INTEGER;
          BEGIN
              -- Получить текущий шаг expansion
              SELECT COALESCE(MAX(expansion_step), 0) INTO current_step FROM storage_expansion_demo;
              
              -- Генерировать данные
              FOR i IN 1..10000 LOOP
                  INSERT INTO storage_expansion_demo (
                      expansion_step, 
                      storage_size, 
                      data_content,
                      file_system_info
                  ) VALUES (
                      current_step,
                      '20Gi',
                      'Generated data entry ' || i || ' - ' || repeat('x', 100),
                      jsonb_build_object(
                          'entry_number', i,
                          'expansion_step', current_step,
                          'timestamp', now(),
                          'data_size', length('Generated data entry ' || i || ' - ' || repeat('x', 100))
                      )
                  );
              END LOOP;
              
              RAISE NOTICE 'Generated 10000 records for expansion step %', current_step;
          END \$\$;
          DATA_EOF
          
          echo "Database initialized and ready for expansion testing!"
          echo "Current database size: $(psql -U expansion_user -d hashfoundry_expansion_db -t -c 'SELECT pg_size_pretty(pg_database_size(current_database()));' | tr -d ' ')"
          
          # Продолжить работу PostgreSQL
          wait
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - expansion_user
            - -d
            - hashfoundry_expansion_db
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: database-storage
        persistentVolumeClaim:
          claimName: hashfoundry-database-pvc
---
# Приложение для генерации логов с expandable storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-log-generator
  namespace: volume-expansion-demo
  labels:
    app: log-generator
    storage.hashfoundry.io/expansion: enabled
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-generator
  template:
    metadata:
      labels:
        app: log-generator
        storage.hashfoundry.io/expansion: enabled
      annotations:
        storage.hashfoundry.io/expansion-demo: "logs"
    spec:
      containers:
      - name: log-generator
        image: busybox:1.35
        volumeMounts:
        - name: log-storage
          mountPath: /var/log/expansion
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Log Generator for Expansion Demo..."
          
          # Создать структуру директорий
          mkdir -p /var/log/expansion/application
          mkdir -p /var/log/expansion/system
          mkdir -p /var/log/expansion/audit
          
          # Создать начальные логи
          cat > /var/log/expansion/expansion_info.log << 'INFO_EOF'
          Expansion Demo Log Generator Started
          ===================================
          
          Initial Storage Size: 10Gi
          Storage Class: hashfoundry-expandable-performance
          Expansion Support: Enabled
          
          This log generator will create files to demonstrate storage expansion.
          Monitor the storage usage and expand when needed.
          INFO_EOF
          
          # Функция для генерации логов
          generate_logs() {
              local log_type=$1
              local count=$2
              local size_kb=$3
              
              for i in $(seq 1 $count); do
                  log_file="/var/log/expansion/${log_type}/log_${log_type}_$(date +%Y%m%d_%H%M%S)_${i}.log"
                  
                  {
                      echo "Log Type: $log_type"
                      echo "Entry Number: $i"
                      echo "Timestamp: $(date -Iseconds)"
                      echo "Storage Expansion Demo: HashFoundry"
                      echo "Data: $(head -c ${size_kb}k /dev/zero | tr '\0' 'x')"
                      echo "End of Entry"
                      echo "----------------------------------------"
                  } > "$log_file"
              done
              
              echo "Generated $count log files of type $log_type (${size_kb}KB each)"
          }
          
          # Основной цикл генерации логов
          counter=0
          while true; do
              counter=$((counter + 1))
              
              echo "Log generation cycle $counter - $(date)"
              
              # Генерировать различные типы логов
              generate_logs "application" 10 50
              generate_logs "system" 5 100
              generate_logs "audit" 3 200
              
              # Показать статистику использования
              echo "Storage usage after cycle $counter:"
              df -h /var/log/expansion
              echo "Total files: $(find /var/log/expansion -type f | wc -l)"
              echo "Total size: $(du -sh /var/log/expansion | cut -f1)"
              
              # Создать сводный отчет
              cat > /var/log/expansion/storage_report_$(date +%Y%m%d_%H%M%S).log << REPORT_EOF
          Storage Expansion Report
          =======================
          
          Cycle: $counter
          Timestamp: $(date -Iseconds)
          
          Storage Usage:
          $(df -h /var/log/expansion)
          
          File Statistics:
          Total Files: $(find /var/log/expansion -type f | wc -l)
          Application Logs: $(find /var/log/expansion/application -type f | wc -l)
          System Logs: $(find /var/log/expansion/system -type f | wc -l)
          Audit Logs: $(find /var/log/expansion/audit -type f | wc -l)
          
          Size Breakdown:
          $(du -sh /var/log/expansion/*)
          
          Note: Monitor storage usage and expand PVC when needed!
          REPORT_EOF
              
              sleep 60
          done
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: log-storage
        persistentVolumeClaim:
          claimName: hashfoundry-logs-pvc
---
# Приложение с non-expandable storage для сравнения
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-fixed-cache
  namespace: volume-expansion-demo
  labels:
    app: fixed-cache
    storage.hashfoundry.io/expansion: disabled
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fixed-cache
  template:
    metadata:
      labels:
        app: fixed-cache
        storage.hashfoundry.io/expansion: disabled
      annotations:
        storage.hashfoundry.io/expansion-demo: "fixed-size"
    spec:
      containers:
      - name: cache
        image: redis:6.2
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: cache-storage
          mountPath: /data
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Fixed-Size Cache Demo..."
          
          # Создать конфигурацию Redis
          cat > /data/redis.conf << 'REDIS_EOF'
          # Redis configuration for expansion demo
          dir /data
          dbfilename dump.rdb
          save 900 1
          save 300 10
          save 60 10000
          
          # Logging
          logfile /data/redis.log
          loglevel notice
          
          # Memory settings
          maxmemory 100mb
          maxmemory-policy allkeys-lru
          REDIS_EOF
          
          # Создать информационный файл
          cat > /data/expansion_info.txt << 'INFO_EOF'
          Fixed-Size Storage Demo
          ======================
          
          Storage Size: 5Gi (Fixed, cannot be expanded)
          Storage Class: hashfoundry-non-expandable
          Expansion Support: Disabled
          
          This cache uses non-expandable storage to demonstrate
          the difference with expandable storage.
          
          When storage fills up, manual intervention is required:
          1. Create new PVC with larger size
          2. Migrate data
          3. Update Pod to use new PVC
          INFO_EOF
          
          echo "Fixed-size cache initialized!"
          echo "Storage info:"
          df -h /data
          
          # Запустить Redis
          redis-server /data/redis.conf
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: cache-storage
        persistentVolumeClaim:
          claimName: hashfoundry-fixed-pvc
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: expandable-database-service
  namespace: volume-expansion-demo
  labels:
    app: expandable-database
spec:
  selector:
    app: expandable-database
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
---
apiVersion: v1
kind: Service
metadata:
  name: fixed-cache-service
  namespace: volume-expansion-demo
  labels:
    app: fixed-cache
spec:
  selector:
    app: fixed-cache
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
EOF

# Проверить развертывания
kubectl get pods,pvc,pv -n volume-expansion-demo
kubectl get deployments,statefulsets,services -n volume-expansion-demo
```

### **5. Демонстрация процесса expansion:**
```bash
# Создать скрипт для демонстрации volume expansion
cat << 'EOF' > demonstrate-volume-expansion.sh
#!/bin/bash

NAMESPACE=${1:-"volume-expansion-demo"}

echo "=== Volume Expansion Demonstration ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для проверки текущего состояния
check_current_state() {
    echo "=== Current State Before Expansion ==="
    
    echo "PVCs and their sizes:"
    kubectl get pvc -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,REQUESTED:.spec.resources.requests.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "PVs and their sizes:"
    kubectl get pv -o json | jq -r --arg ns "$NAMESPACE" '.items[] | select(.spec.claimRef.namespace == $ns) | "  - " + .metadata.name + " (Size: " + .spec.capacity.storage + ", PVC: " + .spec.claimRef.name + ")"' 2>/dev/null
    echo
    
    # Проверить использование хранилища в Pod'ах
    echo "Storage usage in pods:"
    
    # Database pod
    db_pod=$(kubectl get pods -n $NAMESPACE -l app=expandable-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$db_pod" ]; then
        echo "Database pod ($db_pod):"
        kubectl exec $db_pod -n $NAMESPACE -- df -h /var/lib/postgresql/data 2>/dev/null || echo "  Could not check database storage"
    fi
    
    # Log generator pod
    log_pod=$(kubectl get pods -n $NAMESPACE -l app=log-generator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$log_pod" ]; then
        echo "Log generator pod ($log_pod):"
        kubectl exec $log_pod -n $NAMESPACE -- df -h /var/log/expansion 2>/dev/null || echo "  Could not check log storage"
    fi
    
    echo
}

# Функция для расширения PVC
expand_pvc() {
    local pvc_name=$1
    local new_size=$2
    
    echo "=== Expanding PVC: $pvc_name to $new_size ==="
    
    # Проверить, поддерживает ли StorageClass expansion
    storage_class=$(kubectl get pvc $pvc_name -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
    expansion_allowed=$(kubectl get storageclass $storage_class -o jsonpath='{.allowVolumeExpansion}' 2>/dev/null)
    
    if [ "$expansion_allowed" != "true" ]; then
        echo "❌ StorageClass $storage_class does not support volume expansion"
        return 1
    fi
    
    echo "✅ StorageClass $storage_class supports volume expansion"
    
    # Получить текущий размер
    current_size=$(kubectl get pvc $pvc_name -n $NAMESPACE -o jsonpath='{.status.capacity.storage}')
    echo "Current size: $current_size"
    echo "Target size: $new_size"
    
    # Выполнить expansion
    echo "Patching PVC..."
    kubectl patch pvc $pvc_name -n $NAMESPACE -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"$new_size\"}}}}"
    
    if [ $? -eq 0 ]; then
        echo "✅ PVC patch applied successfully"
        
        # Мониторинг процесса expansion
        echo "Monitoring expansion progress..."
        
        for i in {1..30}; do
            status=$(kubectl get pvc $pvc_name -n $NAMESPACE -o jsonpath='{.status.phase}')
            capacity=$(kubectl get pvc $pvc_name -n $NAMESPACE -o jsonpath='{.status.capacity.storage}')
            requested=$(kubectl get pvc $pvc_name -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')
            
            echo "  Attempt $i: Status=$status, Capacity=$capacity, Requested=$requested"
            
            if [ "$capacity" = "$new_size" ]; then
                echo "✅ Expansion completed successfully!"
                break
            fi
            
            sleep 10
        done
        
        # Проверить события
        echo "Recent events for PVC:"
        kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$pvc_name --sort-by='.lastTimestamp' | tail -5
        
    else
        echo "❌ Failed to patch PVC"
        return 1
    fi
    
    echo
}

# Функция для проверки файловой системы после expansion
check_filesystem_expansion() {
    local pvc_name=$1
    
    echo "=== Checking Filesystem Expansion for PVC: $pvc_name ==="
    
    # Найти Pod, использующий этот PVC
    pod_name=""
    case "$pvc_name" in
        *database*)
            pod_name=$(kubectl get pods -n $NAMESPACE -l app=expandable-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            mount_path="/var/lib/postgresql/data"
            ;;
        *logs*)
            pod_name=$(kubectl get pods -n $NAMESPACE -l app=log-generator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            mount_path="/var/log/expansion"
            ;;
    esac
    
    if [ -n "$pod_name" ]; then
        echo "Checking filesystem in pod: $pod_name"
        echo "Mount path: $mount_path"
        
        # Проверить размер файловой системы
        kubectl exec $pod_name -n $NAMESPACE -- df -h $mount_path 2>/dev/null || echo "Could not check filesystem"
        
        # Проверить, нужно ли ручное расширение FS
        echo "Checking if manual filesystem resize is needed..."
        kubectl exec $pod_name -n $NAMESPACE -- sh -c "
            echo 'Filesystem info:'
            df -h $mount_path
            echo 'Block device info:'
            lsblk | grep -A 5 -B 5 \$(df $mount_path | tail -1 | awk '{print \$1}' | sed 's|/dev/||') || echo 'Could not get block device info'
        " 2>/dev/null || echo "Could not get detailed filesystem info"
        
    else
        echo "Could not find pod using PVC $pvc_name"
    fi
    
    echo
}

# Функция для генерации данных для тестирования
generate_test_data() {
    echo "=== Generating Test Data ==="
    
    # Генерировать данные в базе данных
    db_pod=$(kubectl get pods -n $NAMESPACE -l app=expandable-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$db_pod" ]; then
        echo "Generating database data..."
        kubectl exec $db_pod -n $NAMESPACE -- psql -U expansion_user -d hashfoundry_expansion_db -f /var/lib/postgresql/data/generate_data.sql 2>/dev/null || echo "Could not generate database data"
        
        # Показать статистику базы данных
        kubectl exec $db_pod -n $NAMESPACE -- psql -U expansion_user -d hashfoundry_expansion_db -c "SELECT * FROM get_storage_info();" 2>/dev/null || echo "Could not get database stats"
    fi
    
    echo
}

# Функция для демонстрации полного процесса expansion
demonstrate_full_expansion() {
    echo "=== Full Volume Expansion Demonstration ==="
    
    # 1. Проверить начальное состояние
    check_current_state
    
    # 2. Генерировать данные для заполнения хранилища
    generate_test_data
    
    # 3. Расширить database PVC
    echo "Step 1: Expanding database PVC from 20Gi to 40Gi"
    expand_pvc "hashfoundry-database-pvc" "40Gi"
    check_filesystem_expansion "hashfoundry-database-pvc"
    
    # 4. Расширить logs PVC
    echo "Step 2: Expanding logs PVC from 10Gi to 25Gi"
    expand_pvc "hashfoundry-logs-pvc" "25Gi"
    check_filesystem_expansion "hashfoundry-logs-pvc"
    
    # 5. Попытаться расширить non-expandable PVC (должно не удаться)
    echo "Step 3: Attempting to expand non-expandable PVC (should fail)"
    expand_pvc "hashfoundry-fixed-pvc" "10Gi" || echo "❌ Expected failure: PVC cannot be expanded"
    
    # 6. Проверить финальное состояние
    echo "=== Final State After Expansion ==="
    check_current_state
}

# Функция для создания отчета о expansion
create_expansion_report() {
    echo "=== Volume Expansion Report ==="
    
    cat << 'REPORT_EOF'
Volume Expansion Summary
=======================

Expansion Process:
1. Check StorageClass supports allowVolumeExpansion: true
2. Patch PVC with new storage size
3. Kubernetes triggers volume expansion
4. CSI driver expands underlying storage
5. Filesystem is automatically or manually resized

Expansion Types:
- Online Expansion: No pod restart required
- Offline Expansion: Pod restart required
- Filesystem Expansion: Automatic or manual

Best Practices:
- Always backup data before expansion
- Monitor expansion progress
- Verify filesystem expansion
- Test application functionality after expansion
- Plan for growth to avoid frequent expansions

Troubleshooting:
- Check StorageClass allowVolumeExpansion setting
- Verify CSI driver supports expansion
- Check PVC and PV events for errors
- Ensure sufficient underlying storage capacity

REPORT_EOF
    
    echo
}

# Основная функция
main() {
    case "$2" in
        "check"|"status")
            check_current_state
            ;;
        "expand")
            if [ -z "$3" ] || [ -z "$4" ]; then
                echo "Usage: $0 $NAMESPACE expand <pvc-name> <new-size>"
                echo "Example: $0 $NAMESPACE expand hashfoundry-database-pvc 40Gi"
                exit 1
            fi
            expand_pvc "$3" "$4"
            ;;
        "filesystem"|"fs")
            if [ -z "$3" ]; then
                echo "Usage: $0 $NAMESPACE filesystem <pvc-name>"
                exit 1
            fi
            check_filesystem_expansion "$3"
            ;;
        "generate"|"data")
            generate_test_data
            ;;
        "demo"|"full")
            demonstrate_full_expansion
            ;;
        "report")
            create_expansion_report
            ;;
        "all"|"")
            demonstrate_full_expansion
            create_expansion_report
            ;;
        *)
            echo "Usage: $0 [namespace] [action] [args...]"
            echo ""
            echo "Actions:"
            echo "  check             - Check current state"
            echo "  expand <pvc> <size> - Expand specific PVC"
            echo "  filesystem <pvc>  - Check filesystem expansion"
            echo "  generate          - Generate test data"
            echo "  demo              - Full expansion demonstration"
            echo "  report            - Show expansion report"
            echo "  all               - Run full demo and report (default)"
            echo ""
            echo "Examples:"
            echo "  $0 volume-expansion-demo"
            echo "  $0 volume-expansion-demo expand hashfoundry-database-pvc 40Gi"
            echo "  $0 volume-expansion-demo check"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x demonstrate-volume-expansion.sh

# Запустить демонстрацию
./demonstrate-volume-expansion.sh volume-expansion-demo
```

### **6. Практические команды для expansion:**
```bash
# Основные команды для volume expansion
echo "=== Volume Expansion Commands ==="

# 1. Проверить поддержку expansion
echo "Check expansion support:"
echo "kubectl get storageclass -o custom-columns='NAME:.metadata.name,EXPANSION:.allowVolumeExpansion'"
kubectl get storageclass -o custom-columns="NAME:.metadata.name,EXPANSION:.allowVolumeExpansion"
echo

# 2. Расширить PVC
echo "Expand PVC (example):"
echo "kubectl patch pvc hashfoundry-database-pvc -n volume-expansion-demo -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"40Gi\"}}}}'"
echo

# 3. Мониторинг expansion
echo "Monitor expansion progress:"
echo "kubectl get pvc -n volume-expansion-demo -w"
echo "kubectl get events -n volume-expansion-demo --sort-by='.lastTimestamp'"
echo

# 4. Проверить файловую систему
echo "Check filesystem after expansion:"
echo "kubectl exec <pod-name> -n volume-expansion-demo -- df -h <mount-path>"
echo

# 5. Ручное расширение файловой системы (если нужно)
echo "Manual filesystem resize (if needed):"
echo "kubectl exec <pod-name> -n volume-expansion-demo -- resize2fs <device>"
```

## 🧹 **Очистка ресурсов:**
```bash
# Создать скрипт для очистки демонстрации volume expansion
cat << 'EOF' > cleanup-volume-expansion-demo.sh
#!/bin/bash

NAMESPACE="volume-expansion-demo"

echo "=== Cleaning up Volume Expansion Demo ==="
echo

# Показать текущие ресурсы перед очисткой
echo "Resources before cleanup:"
kubectl get pods,pvc,pv -n $NAMESPACE
kubectl get storageclass -l app.kubernetes.io/name=hashfoundry-storage

# Удалить Deployments и StatefulSets
echo "Deleting deployments and statefulsets..."
kubectl delete deployments,statefulsets --all -n $NAMESPACE

# Подождать завершения Pod'ов
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pods --all -n $NAMESPACE --timeout=120s

# Удалить PVCs
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

# Очистить локальные файлы
echo "Cleaning up local files..."
rm -f demonstrate-volume-expansion.sh

echo "✓ Volume expansion demo cleanup completed"

EOF

chmod +x cleanup-volume-expansion-demo.sh
./cleanup-volume-expansion-demo.sh
```

## 📋 **Сводка Volume Expansion:**

### **Основные команды:**
```bash
# Проверка поддержки expansion
kubectl get storageclass -o custom-columns="NAME:.metadata.name,EXPANSION:.allowVolumeExpansion"

# Расширение PVC
kubectl patch pvc <pvc-name> -n <namespace> -p '{"spec":{"resources":{"requests":{"storage":"<new-size>"}}}}'

# Мониторинг процесса
kubectl get pvc <pvc-name> -n <namespace> -w
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Проверка файловой системы
kubectl exec <pod-name> -n <namespace> -- df -h <mount-path>
```

## 📊 **Процесс Volume Expansion:**

| **Шаг** | **Действие** | **Результат** |
|----------|--------------|---------------|
| **1** | Patch PVC с новым размером | PVC.spec.resources.requests.storage обновлен |
| **2** | Kubernetes вызывает CSI driver | Underlying storage расширен |
| **3** | PV capacity обновляется | PV.spec.capacity.storage увеличен |
| **4** | Файловая система расширяется | Доступное место увеличено |

## 🎯 **Best Practices:**

### **Планирование expansion:**
- **Мониторьте использование** хранилища
- **Планируйте рост** заранее
- **Тестируйте expansion** в dev среде

### **Безопасность:**
- **Делайте backup** перед expansion
- **Проверяйте поддержку** StorageClass
- **Мониторьте процесс** expansion

### **Troubleshooting:**
- **Проверяйте события** PVC и PV
- **Убедитесь в поддержке** CSI driver
- **Проверяйте файловую систему** после expansion

**Volume Expansion позволяет масштабировать хранилище без простоев!**
