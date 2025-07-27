# 64. Volume Reclaim Policies

## 🎯 **Volume Reclaim Policies**

**Volume Reclaim Policies** определяют, что происходит с Persistent Volume после того, как связанный с ним PVC удаляется. Эти политики критически важны для управления жизненным циклом данных и предотвращения потери важной информации.

## 🏗️ **Основные Reclaim Policies:**

### **1. Delete**
- **Автоматическое удаление** PV и underlying storage
- **По умолчанию** для динамически созданных PV
- **Освобождает ресурсы** немедленно
- **Риск потери данных** при случайном удалении

### **2. Retain**
- **Сохраняет PV** после удаления PVC
- **Данные остаются** на underlying storage
- **Требует ручной очистки** администратором
- **Максимальная безопасность** данных

### **3. Recycle (Deprecated)**
- **Очищает данные** на PV (rm -rf /volume/*)
- **Делает PV доступным** для повторного использования
- **Устарел** и не рекомендуется
- **Заменен на Delete** в современных версиях

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание демонстрационной среды:**
```bash
# Создать namespace для демонстрации reclaim policies
kubectl create namespace reclaim-demo

# Создать labels для организации
kubectl label namespace reclaim-demo \
  demo.type=reclaim-policies \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational

# Проверить существующие reclaim policies в кластере
echo "=== Current Reclaim Policies in HA cluster ==="
kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name"
echo

kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class"
```

### **2. Демонстрация Delete Policy:**
```bash
# Создать StorageClass с Delete policy
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-delete-policy
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/reclaim: delete
    storage.hashfoundry.io/demo: reclaim-policies
  annotations:
    storageclass.kubernetes.io/description: "StorageClass with Delete reclaim policy"
    storageclass.kubernetes.io/warning: "Data will be permanently deleted when PVC is removed"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
EOF

# Создать PVC с Delete policy
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-delete-pvc
  namespace: reclaim-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/reclaim: delete
    storage.hashfoundry.io/purpose: temporary-data
  annotations:
    storage.hashfoundry.io/description: "PVC with Delete reclaim policy - data will be lost on deletion"
    storage.hashfoundry.io/warning: "This volume will be automatically deleted when PVC is removed"
spec:
  storageClassName: hashfoundry-delete-policy
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# Создать Pod, использующий Delete PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hashfoundry-delete-demo
  namespace: reclaim-demo
  labels:
    app: delete-demo
    storage.hashfoundry.io/reclaim: delete
  annotations:
    storage.hashfoundry.io/reclaim-policy: "delete"
spec:
  containers:
  - name: data-writer
    image: busybox:1.35
    command: ["sh", "-c"]
    args:
    - |
      echo "Starting Delete Policy Demo..."
      
      # Создать демонстрационные данные
      mkdir -p /data/delete-demo
      
      cat > /data/delete-demo/important-data.txt << 'DATA_EOF'
      IMPORTANT DATA - DELETE POLICY DEMO
      ===================================
      
      This file demonstrates the Delete reclaim policy.
      When the PVC is deleted, this data will be PERMANENTLY LOST!
      
      Created: $(date)
      Pod: $(hostname)
      Reclaim Policy: Delete
      
      Sample Data:
      - User records: 1000 entries
      - Transaction logs: 5000 entries  
      - Configuration files: 50 files
      - Cache data: 2GB
      
      WARNING: This data will be automatically deleted when PVC is removed!
      DATA_EOF
      
      # Создать файлы с временными данными
      for i in $(seq 1 100); do
        echo "Temporary data entry $i - $(date)" > /data/delete-demo/temp_$i.log
      done
      
      # Создать метаданные
      cat > /data/delete-demo/metadata.json << 'META_EOF'
      {
        "reclaim_policy": "Delete",
        "data_type": "temporary",
        "created_at": "$(date -Iseconds)",
        "pod_name": "$(hostname)",
        "storage_class": "hashfoundry-delete-policy",
        "warning": "This data will be permanently deleted when PVC is removed",
        "files_count": $(ls /data/delete-demo/ | wc -l),
        "total_size": "$(du -sh /data/delete-demo | cut -f1)"
      }
      META_EOF
      
      echo "Delete policy demo data created successfully!"
      echo "Files created: $(ls /data/delete-demo/ | wc -l)"
      echo "Total size: $(du -sh /data/delete-demo | cut -f1)"
      
      # Показать содержимое
      echo "=== Directory listing ==="
      ls -la /data/delete-demo/
      
      # Непрерывно записывать логи
      counter=0
      while true; do
        counter=$((counter + 1))
        echo "$(date): Delete demo running - entry $counter" >> /data/delete-demo/activity.log
        echo "Delete demo active - entry $counter (data will be lost on PVC deletion)"
        sleep 30
      done
    volumeMounts:
    - name: delete-storage
      mountPath: /data
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  volumes:
  - name: delete-storage
    persistentVolumeClaim:
      claimName: hashfoundry-delete-pvc
  restartPolicy: Always
EOF

# Проверить создание ресурсов
kubectl get pods,pvc,pv -n reclaim-demo -l storage.hashfoundry.io/reclaim=delete
```

### **3. Демонстрация Retain Policy:**
```bash
# Создать StorageClass с Retain policy
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-retain-policy
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/reclaim: retain
    storage.hashfoundry.io/demo: reclaim-policies
  annotations:
    storageclass.kubernetes.io/description: "StorageClass with Retain reclaim policy"
    storageclass.kubernetes.io/note: "Data will be preserved when PVC is removed"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: Immediate
EOF

# Создать PVC с Retain policy
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-retain-pvc
  namespace: reclaim-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/reclaim: retain
    storage.hashfoundry.io/purpose: persistent-data
  annotations:
    storage.hashfoundry.io/description: "PVC with Retain reclaim policy - data will be preserved"
    storage.hashfoundry.io/note: "This volume will be retained when PVC is removed"
spec:
  storageClassName: hashfoundry-retain-policy
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 15Gi
EOF

# Создать StatefulSet, использующий Retain PVC
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hashfoundry-retain-demo
  namespace: reclaim-demo
  labels:
    app: retain-demo
    storage.hashfoundry.io/reclaim: retain
spec:
  serviceName: retain-demo-service
  replicas: 1
  selector:
    matchLabels:
      app: retain-demo
  template:
    metadata:
      labels:
        app: retain-demo
        storage.hashfoundry.io/reclaim: retain
      annotations:
        storage.hashfoundry.io/reclaim-policy: "retain"
    spec:
      containers:
      - name: database
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_retain_db"
        - name: POSTGRES_USER
          value: "retain_user"
        - name: POSTGRES_PASSWORD
          value: "retain_password_123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
        - name: backup-storage
          mountPath: /backup
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Retain Policy Demo with PostgreSQL..."
          
          # Инициализировать PostgreSQL
          docker-entrypoint.sh postgres &
          
          # Подождать запуска PostgreSQL
          sleep 30
          
          # Создать важные данные
          psql -U retain_user -d hashfoundry_retain_db -c "
            CREATE TABLE IF NOT EXISTS critical_data (
              id SERIAL PRIMARY KEY,
              reclaim_policy VARCHAR(20) DEFAULT 'Retain',
              data_type VARCHAR(50) DEFAULT 'Critical Business Data',
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              content TEXT,
              importance_level VARCHAR(20) DEFAULT 'HIGH'
            );
            
            -- Вставить критически важные данные
            INSERT INTO critical_data (content, importance_level) VALUES 
            ('Customer payment records - Q4 2024', 'CRITICAL'),
            ('Financial audit trail - December 2024', 'CRITICAL'),
            ('User authentication logs', 'HIGH'),
            ('Business intelligence reports', 'HIGH'),
            ('Compliance documentation', 'CRITICAL'),
            ('Backup verification checksums', 'HIGH');
            
            -- Создать индексы
            CREATE INDEX IF NOT EXISTS idx_critical_created_at ON critical_data(created_at);
            CREATE INDEX IF NOT EXISTS idx_critical_importance ON critical_data(importance_level);
            
            -- Создать представление для отчетности
            CREATE OR REPLACE VIEW critical_summary AS
            SELECT 
              importance_level,
              COUNT(*) as record_count,
              MIN(created_at) as earliest_record,
              MAX(created_at) as latest_record
            FROM critical_data 
            GROUP BY importance_level;
          "
          
          # Создать backup файлы
          mkdir -p /backup/database
          mkdir -p /backup/logs
          
          # Создать backup базы данных
          pg_dump -U retain_user -d hashfoundry_retain_db > /backup/database/critical_data_backup_$(date +%Y%m%d_%H%M%S).sql
          
          # Создать важные конфигурационные файлы
          cat > /backup/database_config.conf << 'CONFIG_EOF'
          # Critical Database Configuration - RETAIN POLICY
          # This configuration must be preserved!
          
          [database]
          name = hashfoundry_retain_db
          user = retain_user
          reclaim_policy = retain
          importance = critical
          
          [backup]
          schedule = daily
          retention_days = 365
          encryption = enabled
          
          [compliance]
          audit_required = true
          data_classification = sensitive
          retention_required = true
          
          [recovery]
          rpo_minutes = 15
          rto_minutes = 60
          backup_verification = required
          CONFIG_EOF
          
          # Создать метаданные для восстановления
          cat > /backup/recovery_metadata.json << 'RECOVERY_EOF'
          {
            "reclaim_policy": "Retain",
            "data_classification": "Critical Business Data",
            "created_at": "$(date -Iseconds)",
            "database_name": "hashfoundry_retain_db",
            "backup_location": "/backup/database",
            "recovery_instructions": [
              "1. Create new PVC with same StorageClass",
              "2. Create new Pod/StatefulSet",
              "3. Mount the retained PV",
              "4. Restore database from backup files",
              "5. Verify data integrity"
            ],
            "compliance_notes": "Data must be retained for audit purposes",
            "contact": "dba@hashfoundry.com"
          }
          RECOVERY_EOF
          
          echo "Critical data and backups created successfully!"
          echo "Database records: $(psql -U retain_user -d hashfoundry_retain_db -t -c 'SELECT COUNT(*) FROM critical_data;' | tr -d ' ')"
          echo "Backup files: $(find /backup -type f | wc -l)"
          
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
            - retain_user
            - -d
            - hashfoundry_retain_db
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: database-storage
        persistentVolumeClaim:
          claimName: hashfoundry-retain-pvc
      - name: backup-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: retain-demo-service
  namespace: reclaim-demo
  labels:
    app: retain-demo
spec:
  selector:
    app: retain-demo
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
EOF

# Проверить создание ресурсов
kubectl get pods,pvc,pv -n reclaim-demo -l storage.hashfoundry.io/reclaim=retain
```

### **4. Создание статических PV с различными reclaim policies:**
```bash
# Создать статические PV для демонстрации различных policies
cat << EOF | kubectl apply -f -
# Static PV с Delete policy
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-delete-pv
  labels:
    type: local
    storage.hashfoundry.io/reclaim: delete
    storage.hashfoundry.io/demo: reclaim-policies
    app.kubernetes.io/name: hashfoundry-storage
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: "/tmp/hashfoundry-static-delete"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
---
# Static PV с Retain policy
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-retain-pv
  labels:
    type: local
    storage.hashfoundry.io/reclaim: retain
    storage.hashfoundry.io/demo: reclaim-policies
    app.kubernetes.io/name: hashfoundry-storage
spec:
  storageClassName: manual
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/hashfoundry-static-retain"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
EOF

# Создать PVCs для статических PV
cat << EOF | kubectl apply -f -
# PVC для static Delete PV
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-static-delete-pvc
  namespace: reclaim-demo
  labels:
    storage.hashfoundry.io/reclaim: delete
    storage.hashfoundry.io/type: static
  annotations:
    storage.hashfoundry.io/description: "Static PVC with Delete policy"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  selector:
    matchLabels:
      storage.hashfoundry.io/reclaim: delete
---
# PVC для static Retain PV
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-static-retain-pvc
  namespace: reclaim-demo
  labels:
    storage.hashfoundry.io/reclaim: retain
    storage.hashfoundry.io/type: static
  annotations:
    storage.hashfoundry.io/description: "Static PVC with Retain policy"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 6Gi
  selector:
    matchLabels:
      storage.hashfoundry.io/reclaim: retain
EOF

# Проверить привязку статических PV
kubectl get pv,pvc -n reclaim-demo | grep static
```

### **5. Анализ и тестирование Reclaim Policies:**
```bash
# Создать скрипт для анализа reclaim policies
cat << 'EOF' > analyze-reclaim-policies.sh
#!/bin/bash

NAMESPACE=${1:-"reclaim-demo"}

echo "=== Reclaim Policies Analysis ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для анализа reclaim policies
analyze_reclaim_policies() {
    echo "=== Reclaim Policies Overview ==="
    
    echo "All PVs with their reclaim policies:"
    kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name,STORAGECLASS:.spec.storageClassName"
    echo
    
    # Группировка по reclaim policies
    echo "PVs by Reclaim Policy:"
    echo "Delete Policy:"
    kubectl get pv -o json | jq -r '.items[] | select(.spec.persistentVolumeReclaimPolicy == "Delete") | "  - " + .metadata.name + " (" + .spec.capacity.storage + ", Claim: " + (.spec.claimRef.name // "none") + ")"' 2>/dev/null || echo "  No Delete policy PVs found"
    
    echo "Retain Policy:"
    kubectl get pv -o json | jq -r '.items[] | select(.spec.persistentVolumeReclaimPolicy == "Retain") | "  - " + .metadata.name + " (" + .spec.capacity.storage + ", Claim: " + (.spec.claimRef.name // "none") + ")"' 2>/dev/null || echo "  No Retain policy PVs found"
    
    echo "Recycle Policy (Deprecated):"
    kubectl get pv -o json | jq -r '.items[] | select(.spec.persistentVolumeReclaimPolicy == "Recycle") | "  - " + .metadata.name + " (" + .spec.capacity.storage + ", Claim: " + (.spec.claimRef.name // "none") + ")"' 2>/dev/null || echo "  No Recycle policy PVs found"
    
    echo
}

# Функция для анализа StorageClass reclaim policies
analyze_storageclass_policies() {
    echo "=== StorageClass Reclaim Policies ==="
    
    echo "StorageClasses with their reclaim policies:"
    kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,EXPANSION:.allowVolumeExpansion,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class"
    echo
    
    # Детальный анализ каждого StorageClass
    for sc in $(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}'); do
        echo "----------------------------------------"
        echo "StorageClass: $sc"
        
        reclaim_policy=$(kubectl get storageclass $sc -o jsonpath='{.reclaimPolicy}')
        provisioner=$(kubectl get storageclass $sc -o jsonpath='{.provisioner}')
        
        echo "  Reclaim Policy: ${reclaim_policy:-"Delete (default)"}"
        echo "  Provisioner: $provisioner"
        
        # Подсчитать PVCs, использующие этот StorageClass
        pvc_count=$(kubectl get pvc --all-namespaces -o json | jq --arg sc "$sc" '[.items[] | select(.spec.storageClassName == $sc)] | length' 2>/dev/null || echo 0)
        echo "  PVCs using this StorageClass: $pvc_count"
        
        if [ "$pvc_count" -gt 0 ]; then
            echo "  PVCs:"
            kubectl get pvc --all-namespaces -o json | jq -r --arg sc "$sc" '.items[] | select(.spec.storageClassName == $sc) | "    - " + .metadata.namespace + "/" + .metadata.name' 2>/dev/null
        fi
        
        echo
    done
}

# Функция для анализа PVCs в namespace
analyze_namespace_pvcs() {
    echo "=== PVCs Analysis in Namespace: $NAMESPACE ==="
    
    pvcs=($(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    if [ ${#pvcs[@]} -eq 0 ]; then
        echo "No PVCs found in namespace $NAMESPACE"
        return
    fi
    
    echo "PVCs in namespace $NAMESPACE:"
    kubectl get pvc -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    for pvc in "${pvcs[@]}"; do
        echo "----------------------------------------"
        echo "PVC: $pvc"
        
        status=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}')
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        storage_class=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
        
        echo "  Status: $status"
        echo "  Bound to PV: ${volume_name:-"<none>"}"
        echo "  StorageClass: ${storage_class:-"<default>"}"
        
        if [ -n "$volume_name" ]; then
            # Получить reclaim policy из PV
            pv_reclaim=$(kubectl get pv $volume_name -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null)
            echo "  PV Reclaim Policy: ${pv_reclaim:-"Unknown"}"
            
            # Получить reclaim policy из StorageClass (если есть)
            if [ -n "$storage_class" ] && [ "$storage_class" != "<default>" ]; then
                sc_reclaim=$(kubectl get storageclass $storage_class -o jsonpath='{.reclaimPolicy}' 2>/dev/null)
                echo "  StorageClass Reclaim Policy: ${sc_reclaim:-"Delete (default)"}"
            fi
            
            # Проверить соответствие
            if [ -n "$pv_reclaim" ] && [ -n "$sc_reclaim" ]; then
                if [ "$pv_reclaim" = "$sc_reclaim" ]; then
                    echo "  ✅ Policies match"
                else
                    echo "  ⚠️  Policy mismatch: PV($pv_reclaim) vs SC($sc_reclaim)"
                fi
            fi
        fi
        
        # Показать, что произойдет при удалении PVC
        if [ -n "$volume_name" ]; then
            pv_reclaim=$(kubectl get pv $volume_name -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null)
            case "$pv_reclaim" in
                "Delete")
                    echo "  🗑️  On PVC deletion: PV and underlying storage will be DELETED"
                    ;;
                "Retain")
                    echo "  💾 On PVC deletion: PV and data will be RETAINED"
                    ;;
                "Recycle")
                    echo "  ♻️  On PVC deletion: PV will be recycled (deprecated)"
                    ;;
                *)
                    echo "  ❓ On PVC deletion: Unknown behavior"
                    ;;
            esac
        fi
        
        echo
    done
}

# Функция для демонстрации изменения reclaim policy
demonstrate_policy_change() {
    echo "=== Reclaim Policy Change Demo ==="
    
    # Найти PV с Delete policy
    delete_pv=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.persistentVolumeReclaimPolicy == "Delete" and .spec.claimRef.namespace == "'$NAMESPACE'") | .metadata.name' | head -1 2>/dev/null)
    
    if [ -n "$delete_pv" ]; then
        echo "Found PV with Delete policy: $delete_pv"
        current_policy=$(kubectl get pv $delete_pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
        echo "  Current policy: $current_policy"
        echo "  To change to Retain policy, run:"
        echo "    kubectl patch pv $delete_pv -p '{\"spec\":{\"persistentVolumeReclaimPolicy\":\"Retain\"}}'"
        echo "  Warning: This change is irreversible!"
        echo
    fi
    
    # Найти PV с Retain policy
    retain_pv=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.persistentVolumeReclaimPolicy == "Retain" and .spec.claimRef.namespace == "'$NAMESPACE'") | .metadata.name' | head -1 2>/dev/null)
    
    if [ -n "$retain_pv" ]; then
        echo "Found PV with Retain policy: $retain_pv"
        current_policy=$(kubectl get pv $retain_pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
        echo "  Current policy: $current_policy"
        echo "  Note: Cannot change Retain to Delete for bound PV"
        echo "  To change after PVC deletion:"
        echo "    kubectl patch pv $retain_pv -p '{\"spec\":{\"persistentVolumeReclaimPolicy\":\"Delete\"}}'"
        echo
    fi
}

# Функция для симуляции удаления PVC
simulate_pvc_deletion() {
    echo "=== PVC Deletion Simulation ==="
    
    pvcs=($(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pvc in "${pvcs[@]}"; do
        if [ -z "$pvc" ]; then
            continue
        fi
        
        echo "----------------------------------------"
        echo "Simulating deletion of PVC: $pvc"
        
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        
        if [ -n "$volume_name" ]; then
            pv_reclaim=$(kubectl get pv $volume_name -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null)
            pv_size=$(kubectl get pv $volume_name -o jsonpath='{.spec.capacity.storage}' 2>/dev/null)
            
            echo "  PV: $volume_name"
            echo "  Size: $pv_size"
            echo "  Reclaim Policy: $pv_reclaim"
            
            case "$pv_reclaim" in
                "Delete")
                    echo "  📋 Simulation Result:"
                    echo "    1. PVC $pvc will be deleted"
                    echo "    2. PV $volume_name will be deleted"
                    echo "    3. Underlying storage will be deleted"
                    echo "    4. All data will be PERMANENTLY LOST"
                    echo "    5. Storage resources will be freed"
                    ;;
                "Retain")
                    echo "  📋 Simulation Result:"
                    echo "    1. PVC $pvc will be deleted"
                    echo "    2. PV $volume_name will be retained"
                    echo "    3. Underlying storage will be preserved"
                    echo "    4. Data will be SAFE and accessible"
                    echo "    5. Manual cleanup required later"
                    echo "    6. PV status will change to 'Released'"
                    ;;
                *)
                    echo "  📋 Simulation Result:"
                    echo "    Unknown reclaim policy behavior"
                    ;;
            esac
        else
            echo "  No PV bound to this PVC"
        fi
        
        echo
    done
}

# Функция для создания сравнительной таблицы
create_reclaim_policies_comparison() {
    echo "=== Reclaim Policies Comparison Table ==="
    
    cat << 'TABLE_EOF'
+------------------+------------------+------------------+------------------+
| Reclaim Policy   | Delete           | Retain           | Recycle (Deprecated) |
+------------------+------------------+------------------+------------------+
| PV Behavior      | Deleted          | Preserved        | Data cleared     |
| Storage Behavior | Deleted          | Preserved        | Preserved        |
| Data Safety      | ❌ Lost          | ✅ Safe          | ❌ Lost          |
| Manual Cleanup   | ❌ Not needed    | ✅ Required      | ❌ Not needed    |
| Resource Usage   | ✅ Freed         | ❌ Continues     | ✅ Freed         |
| Use Cases        | Temp data        | Critical data    | Legacy only      |
|                  | Dev/Test         | Production       | (Not recommended)|
+------------------+------------------+------------------+------------------+
| Default for      | Dynamic PVs      | Manual choice    | Legacy systems   |
| Risk Level       | High (data loss) | Low (safe)       | High (data loss) |
| Admin Overhead   | Low              | High             | Medium           |
| Cost Impact      | Low (freed)      | High (retained)  | Low (freed)      |
+------------------+------------------+------------------+------------------+

Reclaim Policy Workflow:
1. PVC is deleted by user
2. Kubernetes checks PV reclaim policy
3. Action taken based on policy:
   - Delete: PV and storage deleted
   - Retain: PV marked as "Released", data preserved
   - Recycle: Data cleared, PV becomes "Available"

Best Practices:
- Use Delete for temporary/development data
- Use Retain for production/critical data
- Avoid Recycle (deprecated)
- Consider backup strategies regardless of policy
TABLE_EOF
    
    echo
}

# Основная функция
main() {
    case "$2" in
        "overview"|"policies")
            analyze_reclaim_policies
            ;;
        "storageclass"|"sc")
            analyze_storageclass_policies
            ;;
        "namespace"|"ns")
            analyze_namespace_pvcs
            ;;
        "change"|"patch")
            demonstrate_policy_change
            ;;
        "simulate"|"sim")
            simulate_pvc_deletion
            ;;
        "compare"|"comparison")
            create_reclaim_policies_comparison
            ;;
        "all"|"")
            analyze_reclaim_policies
            analyze_storageclass_policies
            analyze_namespace_pvcs
            demonstrate_policy_change
            simulate_pvc_deletion
            create_reclaim_policies_comparison
            ;;
        *)
            echo "Usage: $0 [namespace] [analysis_type]"
            echo ""
            echo "Analysis types:"
            echo "  overview      - Analyze all reclaim policies"
            echo "  storageclass  - Analyze StorageClass policies"
            echo "  namespace     - Analyze PVCs in namespace"
            echo "  change        - Show how to change policies"
            echo "  simulate      - Simulate PVC deletion"
            echo "  compare       - Show comparison table"
            echo "  all           - Run all analyses (default)"
            echo ""
            echo "Examples:"
            echo "  $0 reclaim-demo"
            echo "  $0 reclaim-demo simulate"
            echo "  $0 reclaim-demo compare"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x analyze-reclaim-policies.sh

# Запустить анализ
./analyze-reclaim-policies.sh reclaim-demo
```

## 🧹 **Очистка ресурсов:**
```bash
# Создать скрипт для очистки демонстрации reclaim policies
cat << 'EOF' > cleanup-reclaim-demo.sh
#!/bin/bash

NAMESPACE="reclaim-demo"

echo "=== Cleaning up Reclaim Policies Demo ==="
echo

# Показать текущие PVs перед очисткой
echo "PVs before cleanup:"
kubectl get pv -l storage.hashfoundry.io/demo=reclaim-policies

# Удалить Pod'ы и StatefulSets
echo "Deleting pods and statefulsets..."
kubectl delete pods,statefulsets --all -n $NAMESPACE

# Подождать завершения Pod'ов
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pods --all -n $NAMESPACE --timeout=60s

# Удалить PVCs (это покажет разницу в reclaim policies)
echo "Deleting PVCs (demonstrating reclaim policies)..."
kubectl delete pvc --all -n $NAMESPACE

# Показать состояние PVs после удаления PVCs
echo "PVs after PVC deletion (showing reclaim policy effects):"
kubectl get pv -l storage.hashfoundry.io/demo=reclaim-policies

# Удалить retained PVs вручную
echo "Cleaning up retained PVs..."
kubectl delete pv -l storage.hashfoundry.io/demo=reclaim-policies

# Удалить кастомные StorageClasses
echo "Deleting custom StorageClasses..."
kubectl delete storageclass hashfoundry-delete-policy hashfoundry-retain-policy

# Удалить Services
echo "Deleting services..."
kubectl delete services --all -n $NAMESPACE

# Удалить namespace
echo "Deleting namespace..."
kubectl delete namespace $NAMESPACE

# Очистить локальные файлы
echo "Cleaning up local files and directories..."
sudo rm -rf /tmp/hashfoundry-static-delete /tmp/hashfoundry-static-retain
rm -f analyze-reclaim-policies.sh

echo "✓ Reclaim policies demo cleanup completed"

EOF

chmod +x cleanup-reclaim-demo.sh
./cleanup-reclaim-demo.sh
```

## 📋 **Сводка Reclaim Policies:**

### **Основные команды:**
```bash
# Просмотр reclaim policies
kubectl get pv -o custom-columns="NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy"
kubectl get storageclass -o custom-columns="NAME:.metadata.name,RECLAIM:.reclaimPolicy"

# Изменение reclaim policy
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# Проверка статуса после удаления PVC
kubectl get pv
kubectl describe pv <pv-name>
```

## 📊 **Сравнительная таблица Reclaim Policies:**

| **Policy** | **PV после удаления PVC** | **Данные** | **Использование** |
|------------|---------------------------|------------|-------------------|
| **Delete** | Удаляется автоматически | Теряются | Временные данные, dev/test |
| **Retain** | Сохраняется (Released) | Сохраняются | Критичные данные, production |
| **Recycle** | Очищается и становится Available | Теряются | Устарел, не используется |

## 🎯 **Best Practices:**

### **1. Выбор правильной политики:**
- **Delete** для development и temporary data
- **Retain** для production и critical data
- **Избегайте Recycle** (deprecated)

### **2. Безопасность данных:**
- **Всегда делайте backup** независимо от policy
- **Тестируйте восстановление** данных
- **Документируйте критичные volumes**

### **3. Управление ресурсами:**
- **Мониторьте retained PVs** для ручной очистки
- **Автоматизируйте cleanup** retained volumes
- **Планируйте storage costs** для retained data

**Reclaim Policies определяют судьбу ваших данных после удаления PVC!**
