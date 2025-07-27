66. # Static vs Dynamic Provisioning

## 🎯 **Static vs Dynamic Provisioning**

**Static и Dynamic Provisioning** - это два основных подхода к управлению Persistent Volumes в Kubernetes. Они определяют, как и когда создаются PV для удовлетворения запросов PVC.

## 🏗️ **Основные различия:**

### **Static Provisioning**
- **Администратор создает PV заранее**
- **PV существуют до создания PVC**
- **Ручное управление** жизненным циклом
- **Предопределенные характеристики** хранилища

### **Dynamic Provisioning**
- **PV создаются автоматически** по требованию
- **StorageClass определяет** параметры создания
- **Автоматическое управление** жизненным циклом
- **Гибкие параметры** на основе PVC

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание демонстрационной среды:**
```bash
# Создать namespace для демонстрации provisioning
kubectl create namespace provisioning-demo

# Создать labels для организации
kubectl label namespace provisioning-demo \
  demo.type=provisioning-comparison \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational

# Проверить текущие StorageClasses в HA кластере
echo "=== Current StorageClasses in HA cluster ==="
kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class"
echo

# Проверить существующие PVs
echo "=== Existing PVs in cluster ==="
kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name,STORAGECLASS:.spec.storageClassName,PROVISIONING:.metadata.annotations.pv\.kubernetes\.io/provisioned-by"
```

### **2. Демонстрация Static Provisioning:**
```bash
# Создать статические PVs различных типов
cat << EOF | kubectl apply -f -
# Static PV #1 - Local hostPath storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-local-pv
  labels:
    type: local
    provisioning.type: static
    storage.tier: fast
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "Static PV using local hostPath storage"
    storage.hashfoundry.io/provisioning: "static"
    storage.hashfoundry.io/created-by: "administrator"
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/hashfoundry-static-local"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
---
# Static PV #2 - NFS storage (симуляция)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-nfs-pv
  labels:
    type: nfs
    provisioning.type: static
    storage.tier: shared
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "Static PV using NFS storage"
    storage.hashfoundry.io/provisioning: "static"
    storage.hashfoundry.io/created-by: "administrator"
spec:
  storageClassName: manual
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/hashfoundry-static-nfs"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
---
# Static PV #3 - High-performance storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-performance-pv
  labels:
    type: performance
    provisioning.type: static
    storage.tier: ultra-fast
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "Static PV for high-performance workloads"
    storage.hashfoundry.io/provisioning: "static"
    storage.hashfoundry.io/created-by: "administrator"
    storage.hashfoundry.io/performance: "ultra-high"
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: "/tmp/hashfoundry-static-performance"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
EOF

# Создать PVCs для статических PVs
cat << EOF | kubectl apply -f -
# PVC для local storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-static-local-pvc
  namespace: provisioning-demo
  labels:
    provisioning.type: static
    storage.tier: fast
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "PVC for static local storage"
    storage.hashfoundry.io/provisioning: "static"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  selector:
    matchLabels:
      type: local
      provisioning.type: static
---
# PVC для NFS storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-static-nfs-pvc
  namespace: provisioning-demo
  labels:
    provisioning.type: static
    storage.tier: shared
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "PVC for static NFS storage"
    storage.hashfoundry.io/provisioning: "static"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 15Gi
  selector:
    matchLabels:
      type: nfs
      provisioning.type: static
---
# PVC для performance storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-static-performance-pvc
  namespace: provisioning-demo
  labels:
    provisioning.type: static
    storage.tier: ultra-fast
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "PVC for static high-performance storage"
    storage.hashfoundry.io/provisioning: "static"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  selector:
    matchLabels:
      type: performance
      provisioning.type: static
EOF

# Проверить привязку статических PVs
echo "=== Static Provisioning Results ==="
kubectl get pv -l provisioning.type=static
kubectl get pvc -n provisioning-demo -l provisioning.type=static
```

### **3. Демонстрация Dynamic Provisioning:**
```bash
# Создать StorageClasses для dynamic provisioning
cat << EOF | kubectl apply -f -
# Dynamic StorageClass #1 - Standard performance
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-dynamic-standard
  labels:
    provisioning.type: dynamic
    storage.tier: standard
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storageclass.kubernetes.io/description: "Dynamic provisioning with standard performance"
    storageclass.kubernetes.io/provisioning: "dynamic"
    storageclass.kubernetes.io/created-by: "administrator"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
---
# Dynamic StorageClass #2 - High performance
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-dynamic-performance
  labels:
    provisioning.type: dynamic
    storage.tier: high-performance
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storageclass.kubernetes.io/description: "Dynamic provisioning with high performance"
    storageclass.kubernetes.io/provisioning: "dynamic"
    storageclass.kubernetes.io/created-by: "administrator"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Dynamic StorageClass #3 - Backup storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-dynamic-backup
  labels:
    provisioning.type: dynamic
    storage.tier: backup
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storageclass.kubernetes.io/description: "Dynamic provisioning for backup storage"
    storageclass.kubernetes.io/provisioning: "dynamic"
    storageclass.kubernetes.io/created-by: "administrator"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: Immediate
EOF

# Создать PVCs для dynamic provisioning
cat << EOF | kubectl apply -f -
# Dynamic PVC #1 - Standard storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-dynamic-standard-pvc
  namespace: provisioning-demo
  labels:
    provisioning.type: dynamic
    storage.tier: standard
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "PVC for dynamic standard storage"
    storage.hashfoundry.io/provisioning: "dynamic"
spec:
  storageClassName: hashfoundry-dynamic-standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 25Gi
---
# Dynamic PVC #2 - High performance storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-dynamic-performance-pvc
  namespace: provisioning-demo
  labels:
    provisioning.type: dynamic
    storage.tier: high-performance
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "PVC for dynamic high-performance storage"
    storage.hashfoundry.io/provisioning: "dynamic"
spec:
  storageClassName: hashfoundry-dynamic-performance
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
# Dynamic PVC #3 - Backup storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-dynamic-backup-pvc
  namespace: provisioning-demo
  labels:
    provisioning.type: dynamic
    storage.tier: backup
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "PVC for dynamic backup storage"
    storage.hashfoundry.io/provisioning: "dynamic"
spec:
  storageClassName: hashfoundry-dynamic-backup
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF

# Мониторинг dynamic provisioning
echo "=== Monitoring Dynamic Provisioning ==="
echo "Watching PVC creation and binding..."

# Проверить статус dynamic PVCs
kubectl get pvc -n provisioning-demo -l provisioning.type=dynamic
echo

# Проверить автоматически созданные PVs
echo "=== Dynamically Created PVs ==="
kubectl get pv | grep provisioning-demo || echo "No dynamic PVs created yet"
echo

# Проверить события provisioning
echo "=== Provisioning Events ==="
kubectl get events -n provisioning-demo --sort-by='.lastTimestamp' | grep -i "provision\|volume\|pvc"
```

### **4. Создание приложений для сравнения подходов:**
```bash
# Создать приложения, использующие static и dynamic storage
cat << EOF | kubectl apply -f -
# Приложение с static storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-static-app
  namespace: provisioning-demo
  labels:
    app: static-app
    provisioning.type: static
spec:
  replicas: 1
  selector:
    matchLabels:
      app: static-app
  template:
    metadata:
      labels:
        app: static-app
        provisioning.type: static
      annotations:
        storage.hashfoundry.io/provisioning: "static"
    spec:
      containers:
      - name: static-demo
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: static-local-storage
          mountPath: /usr/share/nginx/html/local
        - name: static-nfs-storage
          mountPath: /usr/share/nginx/html/shared
        - name: static-performance-storage
          mountPath: /usr/share/nginx/html/performance
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Static Provisioning Demo..."
          
          # Создать демонстрационные файлы для static storage
          cat > /usr/share/nginx/html/local/index.html << 'LOCAL_EOF'
          <!DOCTYPE html>
          <html>
          <head>
              <title>Static Local Storage Demo</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; }
                  .header { background: #2196F3; color: white; padding: 20px; }
                  .content { padding: 20px; }
                  .info { background: #f5f5f5; padding: 15px; margin: 10px 0; }
              </style>
          </head>
          <body>
              <div class="header">
                  <h1>HashFoundry Static Local Storage</h1>
                  <p>Demonstrating Static Provisioning with Local Storage</p>
              </div>
              <div class="content">
                  <div class="info">
                      <h3>Storage Information:</h3>
                      <ul>
                          <li><strong>Provisioning Type:</strong> Static</li>
                          <li><strong>Storage Type:</strong> Local hostPath</li>
                          <li><strong>Access Mode:</strong> ReadWriteOnce</li>
                          <li><strong>Capacity:</strong> 10Gi</li>
                          <li><strong>Reclaim Policy:</strong> Retain</li>
                          <li><strong>Created:</strong> $(date)</li>
                      </ul>
                  </div>
                  <div class="info">
                      <h3>Static Provisioning Characteristics:</h3>
                      <ul>
                          <li>PV created manually by administrator</li>
                          <li>Pre-defined storage characteristics</li>
                          <li>Manual lifecycle management</li>
                          <li>Immediate availability</li>
                          <li>Predictable performance</li>
                      </ul>
                  </div>
              </div>
          </body>
          </html>
          LOCAL_EOF
          
          cat > /usr/share/nginx/html/shared/index.html << 'SHARED_EOF'
          <!DOCTYPE html>
          <html>
          <head>
              <title>Static NFS Storage Demo</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; }
                  .header { background: #4CAF50; color: white; padding: 20px; }
                  .content { padding: 20px; }
                  .info { background: #f5f5f5; padding: 15px; margin: 10px 0; }
              </style>
          </head>
          <body>
              <div class="header">
                  <h1>HashFoundry Static NFS Storage</h1>
                  <p>Demonstrating Static Provisioning with Shared Storage</p>
              </div>
              <div class="content">
                  <div class="info">
                      <h3>Storage Information:</h3>
                      <ul>
                          <li><strong>Provisioning Type:</strong> Static</li>
                          <li><strong>Storage Type:</strong> NFS (simulated)</li>
                          <li><strong>Access Mode:</strong> ReadWriteMany</li>
                          <li><strong>Capacity:</strong> 20Gi</li>
                          <li><strong>Reclaim Policy:</strong> Retain</li>
                          <li><strong>Created:</strong> $(date)</li>
                      </ul>
                  </div>
                  <div class="info">
                      <h3>Shared Storage Benefits:</h3>
                      <ul>
                          <li>Multiple pods can access simultaneously</li>
                          <li>Data sharing between applications</li>
                          <li>Centralized storage management</li>
                          <li>High availability</li>
                      </ul>
                  </div>
              </div>
          </body>
          </html>
          SHARED_EOF
          
          cat > /usr/share/nginx/html/performance/index.html << 'PERF_EOF'
          <!DOCTYPE html>
          <html>
          <head>
              <title>Static Performance Storage Demo</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; }
                  .header { background: #FF9800; color: white; padding: 20px; }
                  .content { padding: 20px; }
                  .info { background: #f5f5f5; padding: 15px; margin: 10px 0; }
              </style>
          </head>
          <body>
              <div class="header">
                  <h1>HashFoundry Static Performance Storage</h1>
                  <p>Demonstrating Static Provisioning with High Performance</p>
              </div>
              <div class="content">
                  <div class="info">
                      <h3>Storage Information:</h3>
                      <ul>
                          <li><strong>Provisioning Type:</strong> Static</li>
                          <li><strong>Storage Type:</strong> High-performance local</li>
                          <li><strong>Access Mode:</strong> ReadWriteOnce</li>
                          <li><strong>Capacity:</strong> 5Gi</li>
                          <li><strong>Reclaim Policy:</strong> Delete</li>
                          <li><strong>Created:</strong> $(date)</li>
                      </ul>
                  </div>
                  <div class="info">
                      <h3>Performance Characteristics:</h3>
                      <ul>
                          <li>Ultra-fast I/O operations</li>
                          <li>Low latency access</li>
                          <li>Optimized for high-performance workloads</li>
                          <li>Dedicated storage resources</li>
                      </ul>
                  </div>
              </div>
          </body>
          </html>
          PERF_EOF
          
          # Создать главную страницу
          cat > /usr/share/nginx/html/index.html << 'MAIN_EOF'
          <!DOCTYPE html>
          <html>
          <head>
              <title>HashFoundry Static Provisioning Demo</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; }
                  .header { background: #673AB7; color: white; padding: 20px; }
                  .content { padding: 20px; }
                  .storage-links { display: flex; gap: 20px; margin: 20px 0; }
                  .storage-link { 
                      background: #f5f5f5; 
                      padding: 20px; 
                      text-decoration: none; 
                      color: #333; 
                      border-radius: 5px;
                      flex: 1;
                  }
                  .storage-link:hover { background: #e0e0e0; }
              </style>
          </head>
          <body>
              <div class="header">
                  <h1>HashFoundry Static Provisioning Demo</h1>
                  <p>Exploring different types of static storage</p>
              </div>
              <div class="content">
                  <h2>Available Storage Types:</h2>
                  <div class="storage-links">
                      <a href="/local/" class="storage-link">
                          <h3>Local Storage</h3>
                          <p>Fast local hostPath storage</p>
                      </a>
                      <a href="/shared/" class="storage-link">
                          <h3>Shared Storage</h3>
                          <p>NFS-based shared storage</p>
                      </a>
                      <a href="/performance/" class="storage-link">
                          <h3>Performance Storage</h3>
                          <p>High-performance storage</p>
                      </a>
                  </div>
                  <p><strong>Note:</strong> All storage volumes are statically provisioned and pre-created by administrators.</p>
              </div>
          </body>
          </html>
          MAIN_EOF
          
          echo "Static provisioning demo content created!"
          
          # Запустить nginx
          nginx -g "daemon off;"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: static-local-storage
        persistentVolumeClaim:
          claimName: hashfoundry-static-local-pvc
      - name: static-nfs-storage
        persistentVolumeClaim:
          claimName: hashfoundry-static-nfs-pvc
      - name: static-performance-storage
        persistentVolumeClaim:
          claimName: hashfoundry-static-performance-pvc
---
# Приложение с dynamic storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hashfoundry-dynamic-app
  namespace: provisioning-demo
  labels:
    app: dynamic-app
    provisioning.type: dynamic
spec:
  serviceName: dynamic-app-service
  replicas: 1
  selector:
    matchLabels:
      app: dynamic-app
  template:
    metadata:
      labels:
        app: dynamic-app
        provisioning.type: dynamic
      annotations:
        storage.hashfoundry.io/provisioning: "dynamic"
    spec:
      containers:
      - name: dynamic-demo
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_dynamic_db"
        - name: POSTGRES_USER
          value: "dynamic_user"
        - name: POSTGRES_PASSWORD
          value: "dynamic_password_123"
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
          echo "Starting Dynamic Provisioning Demo with PostgreSQL..."
          
          # Инициализировать PostgreSQL
          docker-entrypoint.sh postgres &
          
          # Подождать запуска PostgreSQL
          sleep 30
          
          # Создать демонстрационные данные
          psql -U dynamic_user -d hashfoundry_dynamic_db -c "
            CREATE TABLE IF NOT EXISTS provisioning_demo (
              id SERIAL PRIMARY KEY,
              provisioning_type VARCHAR(20) DEFAULT 'Dynamic',
              storage_class VARCHAR(100),
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              description TEXT,
              advantages TEXT[]
            );
            
            -- Вставить данные о dynamic provisioning
            INSERT INTO provisioning_demo (storage_class, description, advantages) VALUES 
            ('hashfoundry-dynamic-standard', 'Standard performance dynamic storage', ARRAY['Automatic creation', 'Cost-effective', 'Easy management']),
            ('hashfoundry-dynamic-performance', 'High-performance dynamic storage', ARRAY['Auto-scaling', 'High IOPS', 'Low latency']),
            ('hashfoundry-dynamic-backup', 'Backup-optimized dynamic storage', ARRAY['Data retention', 'Long-term storage', 'Cost optimization']);
            
            -- Создать представление для анализа
            CREATE OR REPLACE VIEW dynamic_storage_analysis AS
            SELECT 
              storage_class,
              COUNT(*) as usage_count,
              string_agg(description, '; ') as descriptions,
              array_agg(DISTINCT unnest(advantages)) as all_advantages
            FROM provisioning_demo 
            GROUP BY storage_class;
            
            -- Создать функцию для демонстрации
            CREATE OR REPLACE FUNCTION get_provisioning_info()
            RETURNS TABLE(
              info_type TEXT,
              info_value TEXT
            ) AS \$\$
            BEGIN
              RETURN QUERY
              SELECT 'Provisioning Type'::TEXT, 'Dynamic'::TEXT
              UNION ALL
              SELECT 'Storage Classes', COUNT(DISTINCT storage_class)::TEXT FROM provisioning_demo
              UNION ALL
              SELECT 'Total Records', COUNT(*)::TEXT FROM provisioning_demo
              UNION ALL
              SELECT 'Database Size', pg_size_pretty(pg_database_size(current_database()))::TEXT;
            END;
            \$\$ LANGUAGE plpgsql;
          "
          
          # Создать backup и метаданные
          mkdir -p /backup/dynamic
          
          pg_dump -U dynamic_user -d hashfoundry_dynamic_db > /backup/dynamic/dynamic_provisioning_backup_$(date +%Y%m%d_%H%M%S).sql
          
          cat > /backup/dynamic/provisioning_metadata.json << 'META_EOF'
          {
            "provisioning_type": "Dynamic",
            "created_at": "$(date -Iseconds)",
            "storage_classes": [
              "hashfoundry-dynamic-standard",
              "hashfoundry-dynamic-performance", 
              "hashfoundry-dynamic-backup"
            ],
            "advantages": [
              "Automatic PV creation",
              "No pre-provisioning required",
              "Flexible resource allocation",
              "Cost optimization",
              "Simplified management"
            ],
            "use_cases": [
              "Development environments",
              "Auto-scaling applications",
              "Cloud-native workloads",
              "Multi-tenant systems"
            ]
          }
          META_EOF
          
          echo "Dynamic provisioning demo data created successfully!"
          echo "Database records: $(psql -U dynamic_user -d hashfoundry_dynamic_db -t -c 'SELECT COUNT(*) FROM provisioning_demo;' | tr -d ' ')"
          
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
            - dynamic_user
            - -d
            - hashfoundry_dynamic_db
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: database-storage
        persistentVolumeClaim:
          claimName: hashfoundry-dynamic-standard-pvc
      - name: backup-storage
        persistentVolumeClaim:
          claimName: hashfoundry-dynamic-backup-pvc
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: static-app-service
  namespace: provisioning-demo
  labels:
    app: static-app
spec:
  selector:
    app: static-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: dynamic-app-service
  namespace: provisioning-demo
  labels:
    app: dynamic-app
spec:
  selector:
    app: dynamic-app
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
EOF

# Проверить развертывания
kubectl get pods,pvc,pv -n provisioning-demo
kubectl get deployments,statefulsets,services -n provisioning-demo
```

### **5. Анализ и сравнение подходов:**
```bash
# Создать скрипт для анализа static vs dynamic provisioning
cat << 'EOF' > analyze-provisioning.sh
#!/bin/bash

NAMESPACE=${1:-"provisioning-demo"}

echo "=== Static vs Dynamic Provisioning Analysis ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для анализа static provisioning
analyze_static_provisioning() {
    echo "=== Static Provisioning Analysis ==="
    
    echo "Static PVs:"
    kubectl get pv -l provisioning.type=static -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name,ACCESS:.spec.accessModes[*],RECLAIM:.spec.persistentVolumeReclaimPolicy"
    echo
    
    echo "Static PVCs:"
    kubectl get pvc -n $NAMESPACE -l provisioning.type=static -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    # Детальный анализ каждого static PV
    static_pvs=($(kubectl get pv -l provisioning.type=static -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pv in "${static_pvs[@]}"; do
        if [ -z "$pv" ]; then
            continue
        fi
        
        echo "----------------------------------------"
        echo "Static PV: $pv"
        
        capacity=$(kubectl get pv $pv -o jsonpath='{.spec.capacity.storage}')
        status=$(kubectl get pv $pv -o jsonpath='{.status.phase}')
        claim=$(kubectl get pv $pv -o jsonpath='{.spec.claimRef.name}')
        storage_class=$(kubectl get pv $pv -o jsonpath='{.spec.storageClassName}')
        
        echo "  Capacity: $capacity"
        echo "  Status: $status"
        echo "  Bound to PVC: ${claim:-"<none>"}"
        echo "  StorageClass: ${storage_class:-"<none>"}"
        
        # Время создания
        created=$(kubectl get pv $pv -o jsonpath='{.metadata.creationTimestamp}')
        echo "  Created: $created"
        
        # Характеристики static provisioning
        echo "  Static Provisioning Characteristics:"
        echo "    ✓ Pre-created by administrator"
        echo "    ✓ Immediate availability"
        echo "    ✓ Predictable performance"
        echo "    ✓ Manual lifecycle management"
        
        echo
    done
}

# Функция для анализа dynamic provisioning
analyze_dynamic_provisioning() {
    echo "=== Dynamic Provisioning Analysis ==="
    
    echo "Dynamic StorageClasses:"
    kubectl get storageclass -l provisioning.type=dynamic -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode,EXPANSION:.allowVolumeExpansion"
    echo
    
    echo "Dynamic PVCs:"
    kubectl get pvc -n $NAMESPACE -l provisioning.type=dynamic -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "Dynamically Created PVs:"
    kubectl get pv -o json | jq -r --arg ns "$NAMESPACE" '.items[] | select(.spec.claimRef.namespace == $ns and (.metadata.annotations."pv.kubernetes.io/provisioned-by" // "none") != "none") | "  - " + .metadata.name + " (Size: " + .spec.capacity.storage + ", Provisioner: " + (.metadata.annotations."pv.kubernetes.io/provisioned-by" // "unknown") + ")"' 2>/dev/null || echo "  No dynamically provisioned PVs found"
    echo
    
    # Детальный анализ каждого dynamic PVC
    dynamic_pvcs=($(kubectl get pvc -n $NAMESPACE -l provisioning.type=dynamic -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pvc in "${dynamic_pvcs[@]}"; do
        if [ -z "$pvc" ]; then
            continue
        fi
        
        echo "----------------------------------------"
        echo "Dynamic PVC: $pvc"
        
        status=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}')
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        storage_class=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
        requested_size=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')
        
        echo "  Status: $status"
        echo "  StorageClass: $storage_class"
        echo "  Requested Size: $requested_size"
        echo "  Bound to PV: ${volume_name:-"<none>"}"
        
        if [ -n "$volume_name" ]; then
            # Информация о динамически созданном PV
            provisioner=$(kubectl get pv $volume_name -o jsonpath='{.metadata.annotations.pv\.kubernetes\.io/provisioned-by}' 2>/dev/null)
            pv_created=$(kubectl get pv $volume_name -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
            
            echo "  Provisioned by: ${provisioner:-"Unknown"}"
            echo "  PV Created: ${pv_created:-"Unknown"}"
        fi
        
        # Время создания PVC
        pvc_created=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
        echo "  PVC Created: $pvc_created"
        
        # Характеристики dynamic provisioning
        echo "  Dynamic Provisioning Characteristics:"
        echo "    ✓ Automatically created on demand"
        echo "    ✓ Flexible resource allocation"
        echo "    ✓ Automated lifecycle management"
        echo "    ✓ StorageClass-driven parameters"
        
        echo
    done
}

# Функция для сравнения производительности
compare_performance() {
    echo "=== Performance Comparison ==="
    
    # Найти Pod'ы с static и dynamic storage
    static_pod=$(kubectl get pods -n $NAMESPACE -l provisioning.type=static -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    dynamic_pod=$(kubectl get pods -n $NAMESPACE -l provisioning.type=dynamic -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$static_pod" ]; then
        echo "Testing static storage performance:"
        echo "  Pod: $static_pod"
        kubectl exec $static_pod -n $NAMESPACE -- sh -c "
            echo 'Static Storage Performance Test:'
            echo 'Local storage write test:'
            time dd if=/dev/zero of=/usr/share/nginx/html/local/test_write bs=1M count=50 2>&1 | grep -E 'copied|MB/s' || echo 'Test completed'
            echo 'Performance storage write test:'
            time dd if=/dev/zero of=/usr/share/nginx/html/performance/test_write bs=1M count=50 2>&1 | grep -E 'copied|MB/s' || echo 'Test completed'
            rm -f /usr/share/nginx/html/local/test_write /usr/share/nginx/html/performance/test_write
        " 2>/dev/null || echo "  Performance test failed"
        echo
    fi
    
    if [ -n "$dynamic_pod" ]; then
        echo "Testing dynamic storage performance:"
        echo "  Pod: $dynamic_pod"
        kubectl exec $dynamic_pod -n $NAMESPACE -- sh -c "
            echo 'Dynamic Storage Performance Test:'
            echo 'Database storage write test:'
            time dd if=/dev/zero of=/var/lib/postgresql/data/test_write bs=1M count=50 2>&1 | grep -E 'copied|MB/s' || echo 'Test completed'
            echo 'Backup storage write test:'
            time dd if=/dev/zero of=/backup/test_write bs=1M count=50 2>&1 | grep -E 'copied|MB/s' || echo 'Test completed'
            rm -f /var/lib/postgresql/data/test_write /backup/test_write
        " 2>/dev/null || echo "  Performance test failed"
        echo
    fi
}

# Функция для создания сравнительной таблицы
create_comparison_table() {
    echo "=== Static vs Dynamic Provisioning Comparison ==="
    
    cat << 'TABLE_EOF'
+------------------------+------------------------+------------------------+
| Aspect                 | Static Provisioning    | Dynamic Provisioning   |
+------------------------+------------------------+------------------------+
| PV Creation            | Manual (pre-created)   | Automatic (on-demand)  |
| Administrator Effort  | High (manual setup)    | Low (automated)         |
| Resource Utilization  | May be underutilized   | Optimized usage         |
| Flexibility            | Limited (pre-defined)  | High (configurable)     |
| Provisioning Speed     | Immediate (pre-exists) | Depends on provisioner  |
| Storage Waste          | Possible (over-prov.)  | Minimal (exact size)    |
| Scalability            | Manual scaling         | Automatic scaling       |
| Cost Management        | Predictable costs      | Pay-as-you-use          |
| Complexity             | Simple (straightforward)| Complex (dependencies)  |
| Use Cases              | Legacy, specific needs | Cloud-native, modern    |
+------------------------+------------------------+------------------------+
| Best for:              | - Fixed requirements   | - Dynamic workloads     |
|                        | - Predictable workloads| - Auto-scaling apps     |
|                        | - Legacy applications  | - Development envs      |
|                        | - Specific hardware    | - Multi-tenant systems  |
+------------------------+------------------------+------------------------+

Provisioning Workflow Comparison:

Static Provisioning:
1. Administrator creates PV manually
2. PV becomes Available
3. User creates PVC
4. Kubernetes binds PVC to matching PV
5. Pod uses the bound volume

Dynamic Provisioning:
1. User creates PVC with StorageClass
2. Kubernetes calls provisioner
3. Provisioner creates underlying storage
4. PV is automatically created
5. PVC is bound to new PV
6. Pod uses the bound volume
TABLE_EOF
    
    echo
}

# Функция для анализа событий provisioning
analyze_provisioning_events() {
    echo "=== Provisioning Events Analysis ==="
    
    echo "Recent provisioning events:"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i "provision\|volume\|pvc\|storageclass" | tail -10
    echo
    
    # Анализ времени provisioning
    echo "Provisioning timing analysis:"
    
    # Для static PVCs
    static_pvcs=($(kubectl get pvc -n $NAMESPACE -l provisioning.type=static -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    for pvc in "${static_pvcs[@]}"; do
        if [ -z "$pvc" ]; then
            continue
        fi
        
        pvc_created=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        
        if [ -n "$volume_name" ]; then
            pv_created=$(kubectl get pv $volume_name -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
            echo "  Static PVC $pvc: PV pre-existed, immediate binding"
        fi
    done
    
    # Для dynamic PVCs
    dynamic_pvcs=($(kubectl get pvc -n $NAMESPACE -l provisioning.type=dynamic -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    for pvc in "${dynamic_pvcs[@]}"; do
        if [ -z "$pvc" ]; then
            continue
        fi
        
        pvc_created=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        
        if [ -n "$volume_name" ]; then
            pv_created=$(kubectl get pv $volume_name -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
            echo "  Dynamic PVC $pvc: PV created on-demand"
            echo "    PVC Created: $pvc_created"
            echo "    PV Created: ${pv_created:-"Unknown"}"
        fi
    done
    
    echo
}

# Основная функция
main() {
    case "$2" in
        "static")
            analyze_static_provisioning
            ;;
        "dynamic")
            analyze_dynamic_provisioning
            ;;
        "performance"|"perf")
            compare_performance
            ;;
        "compare"|"comparison")
            create_comparison_table
            ;;
        "events")
            analyze_provisioning_events
            ;;
        "all"|"")
            analyze_static_provisioning
            analyze_dynamic_provisioning
            compare_performance
            create_comparison_table
            analyze_provisioning_events
            ;;
        *)
            echo "Usage: $0 [namespace] [analysis_type]"
            echo ""
            echo "Analysis types:"
            echo "  static        - Analyze static provisioning"
            echo "  dynamic       - Analyze dynamic provisioning"
            echo "  performance   - Compare performance"
            echo "  compare       - Show comparison table"
            echo "  events        - Analyze provisioning events"
            echo "  all           - Run all analyses (default)"
            echo ""
            echo "Examples:"
            echo "  $0 provisioning-demo"
            echo "  $0 provisioning-demo compare"
            echo "  $0 provisioning-demo performance"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x analyze-provisioning.sh

# Запустить анализ
./analyze-provisioning.sh provisioning-demo
```

## 🧹 **Очистка ресурсов:**
```bash
# Создать скрипт для очистки демонстрации provisioning
cat << 'EOF' > cleanup-provisioning-demo.sh
#!/bin/bash

NAMESPACE="provisioning-demo"

echo "=== Cleaning up Provisioning Demo ==="
echo

# Показать текущие ресурсы перед очисткой
echo "Resources before cleanup:"
kubectl get pods,pvc,pv -n $NAMESPACE
kubectl get storageclass -l provisioning.type=dynamic

# Удалить Deployments и StatefulSets
echo "Deleting deployments and statefulsets..."
kubectl delete deployments,statefulsets --all -n $NAMESPACE

# Подождать завершения Pod'ов
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pods --all -n $NAMESPACE --timeout=120s

# Удалить PVCs
echo "Deleting PVCs..."
kubectl delete pvc --all -n $NAMESPACE

# Удалить static PVs
echo "Deleting static PVs..."
kubectl delete pv -l provisioning.type=static

# Удалить dynamic StorageClasses
echo "Deleting dynamic StorageClasses..."
kubectl delete storageclass -l provisioning.type=dynamic

# Удалить Services
echo "Deleting services..."
kubectl delete services --all -n $NAMESPACE

# Удалить namespace
echo "Deleting namespace..."
kubectl delete namespace $NAMESPACE

# Очистить локальные файлы и директории
echo "Cleaning up local files and directories..."
sudo rm -rf /tmp/hashfoundry-static-local /tmp/hashfoundry-static-nfs /tmp/hashfoundry-static-performance
rm -f analyze-provisioning.sh

echo "✓ Provisioning demo cleanup completed"

EOF

chmod +x cleanup-provisioning-demo.sh
./cleanup-provisioning-demo.sh
```

## 📋 **Сводка Static vs Dynamic Provisioning:**

### **Основные команды:**
```bash
# Static Provisioning
kubectl apply -f static-pv.yaml
kubectl apply -f static-pvc.yaml

# Dynamic Provisioning
kubectl apply -f storageclass.yaml
kubectl apply -f dynamic-pvc.yaml

# Анализ
kubectl get pv,pvc
kubectl describe storageclass <storageclass-name>
kubectl get events --sort-by='.lastTimestamp'
```

## 📊 **Сравнительная таблица:**

| **Аспект** | **Static Provisioning** | **Dynamic Provisioning** |
|------------|--------------------------|---------------------------|
| **Создание PV** | Ручное, заранее | Автоматическое, по требованию |
| **Гибкость** | Ограниченная | Высокая |
| **Управление** | Ручное | Автоматизированное |
| **Использование** | Legacy, специфичные нужды | Cloud-native, современные приложения |

## 🎯 **Best Practices:**

### **Static Provisioning:**
- **Используйте для** legacy приложений и специфичных требований
- **Планируйте capacity** заранее
- **Документируйте** характеристики PV

### **Dynamic Provisioning:**
- **Используйте для** cloud-native приложений
- **Настройте StorageClasses** под разные workloads
- **Мониторьте** автоматическое создание ресурсов

**Static и Dynamic Provisioning решают разные задачи управления хранилищем!**
