# 61. Persistent Volumes (PV) и Persistent Volume Claims (PVC)

## 🎯 **Persistent Volumes (PV) и Persistent Volume Claims (PVC)**

**Persistent Volumes (PV)** и **Persistent Volume Claims (PVC)** - это ключевые компоненты Kubernetes для управления постоянным хранилищем данных. PV представляет физическое хранилище, а PVC - это запрос на использование этого хранилища.

## 🏗️ **Основные концепции:**

### **1. Persistent Volume (PV)**
- **Ресурс кластера** для постоянного хранения
- **Независим от Pod'ов** и их жизненного цикла
- **Управляется администратором** кластера

### **2. Persistent Volume Claim (PVC)**
- **Запрос на хранилище** от пользователя
- **Связывается с PV** автоматически
- **Используется в Pod'ах** для монтирования

### **3. StorageClass**
- **Динамическое создание** PV
- **Различные типы** хранилища
- **Автоматизация** процесса

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание демонстрационной среды:**
```bash
# Создать namespace для демонстрации PV/PVC
kubectl create namespace storage-demo

# Проверить существующие StorageClasses в вашем HA кластере
kubectl get storageclass
kubectl describe storageclass

# Проверить существующие PV в кластере
kubectl get pv
kubectl get pvc --all-namespaces

# Создать labels для организации ресурсов
kubectl label namespace storage-demo \
  demo.type=storage \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational
```

### **2. Создание статических Persistent Volumes:**
```bash
# Создать статический PV для демонстрации (используя hostPath для demo)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-pv-1
  labels:
    type: local
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/type: static
    storage.hashfoundry.io/tier: demo
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/hashfoundry-pv-1"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-pv-2
  labels:
    type: local
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/type: static
    storage.hashfoundry.io/tier: demo
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Recycle
  hostPath:
    path: "/tmp/hashfoundry-pv-2"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-static-pv-3
  labels:
    type: local
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/type: static
    storage.hashfoundry.io/tier: demo
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadOnlyMany
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: "/tmp/hashfoundry-pv-3"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
EOF

# Проверить созданные PV
kubectl get pv -l app.kubernetes.io/name=hashfoundry-storage
kubectl describe pv hashfoundry-static-pv-1
```

### **3. Создание Persistent Volume Claims:**
```bash
# Создать PVC для различных сценариев использования
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-app-data-pvc
  namespace: storage-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/purpose: app-data
    storage.hashfoundry.io/tier: primary
  annotations:
    storage.hashfoundry.io/description: "Primary application data storage"
    storage.hashfoundry.io/created-by: "DevOps Team"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  selector:
    matchLabels:
      type: local
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-shared-pvc
  namespace: storage-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/purpose: shared-data
    storage.hashfoundry.io/tier: secondary
  annotations:
    storage.hashfoundry.io/description: "Shared data storage for multiple pods"
    storage.hashfoundry.io/created-by: "DevOps Team"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 8Gi
  selector:
    matchLabels:
      type: local
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-config-pvc
  namespace: storage-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/purpose: config-data
    storage.hashfoundry.io/tier: tertiary
  annotations:
    storage.hashfoundry.io/description: "Configuration and static data storage"
    storage.hashfoundry.io/created-by: "DevOps Team"
spec:
  storageClassName: manual
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 1Gi
  selector:
    matchLabels:
      type: local
EOF

# Проверить статус PVC и их привязку к PV
kubectl get pvc -n storage-demo
kubectl describe pvc hashfoundry-app-data-pvc -n storage-demo

# Проверить события, связанные с PVC
kubectl get events -n storage-demo --sort-by='.lastTimestamp' | grep -i persistent
```

### **4. Создание динамических PVC (используя StorageClass):**
```bash
# Проверить доступные StorageClasses в вашем HA кластере
echo "=== Available StorageClasses in HA cluster ==="
kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode"

# Создать PVC с динамическим provisioning
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-dynamic-pvc-1
  namespace: storage-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/type: dynamic
    storage.hashfoundry.io/purpose: database
  annotations:
    storage.hashfoundry.io/description: "Dynamic PVC for database storage"
    storage.hashfoundry.io/performance-tier: "standard"
spec:
  # Использовать default StorageClass или указать конкретный
  # storageClassName: do-block-storage  # Для DigitalOcean
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-dynamic-pvc-2
  namespace: storage-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/type: dynamic
    storage.hashfoundry.io/purpose: logs
  annotations:
    storage.hashfoundry.io/description: "Dynamic PVC for application logs"
    storage.hashfoundry.io/performance-tier: "standard"
spec:
  # Использовать default StorageClass
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-dynamic-pvc-3
  namespace: storage-demo
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/type: dynamic
    storage.hashfoundry.io/purpose: cache
  annotations:
    storage.hashfoundry.io/description: "Dynamic PVC for cache storage"
    storage.hashfoundry.io/performance-tier: "fast"
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# Проверить динамические PVC
kubectl get pvc -n storage-demo -l storage.hashfoundry.io/type=dynamic
kubectl get pv | grep storage-demo
```

### **5. Создание приложений, использующих PVC:**
```bash
# Создать StatefulSet с PVC для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hashfoundry-database
  namespace: storage-demo
  labels:
    app: hashfoundry-database
    app.kubernetes.io/name: hashfoundry-storage
spec:
  serviceName: hashfoundry-database-service
  replicas: 2
  selector:
    matchLabels:
      app: hashfoundry-database
  template:
    metadata:
      labels:
        app: hashfoundry-database
      annotations:
        storage.hashfoundry.io/pvc-usage: "database-data"
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_db"
        - name: POSTGRES_USER
          value: "hashfoundry_user"
        - name: POSTGRES_PASSWORD
          value: "secure_password_123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: shared-config
          mountPath: /etc/postgresql/shared
        - name: logs-volume
          mountPath: /var/log/postgresql
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - hashfoundry_user
            - -d
            - hashfoundry_db
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - hashfoundry_user
            - -d
            - hashfoundry_db
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: shared-config
        persistentVolumeClaim:
          claimName: hashfoundry-shared-pvc
      - name: logs-volume
        persistentVolumeClaim:
          claimName: hashfoundry-dynamic-pvc-2
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
      labels:
        app: hashfoundry-database
        storage.hashfoundry.io/purpose: database
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 15Gi
---
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-database-service
  namespace: storage-demo
  labels:
    app: hashfoundry-database
spec:
  selector:
    app: hashfoundry-database
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
EOF

# Создать Deployment с использованием существующих PVC
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-app
  namespace: storage-demo
  labels:
    app: hashfoundry-app
    app.kubernetes.io/name: hashfoundry-storage
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hashfoundry-app
  template:
    metadata:
      labels:
        app: hashfoundry-app
      annotations:
        storage.hashfoundry.io/pvc-usage: "app-data,shared-data"
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-data
          mountPath: /var/lib/app
        - name: shared-data
          mountPath: /usr/share/nginx/html/shared
        - name: config-data
          mountPath: /etc/nginx/conf.d
          readOnly: true
        - name: cache-data
          mountPath: /var/cache/nginx
        command: ["sh", "-c"]
        args:
        - |
          # Создать демонстрационные файлы
          echo "Creating demo files in mounted volumes..."
          
          # Создать файлы в app-data volume
          mkdir -p /var/lib/app/data
          echo "HashFoundry Application Data - $(date)" > /var/lib/app/data/app.log
          echo "Pod: $(hostname)" > /var/lib/app/data/pod-info.txt
          echo "Storage demo running on $(date)" > /var/lib/app/data/status.txt
          
          # Создать файлы в shared-data volume
          mkdir -p /usr/share/nginx/html/shared/data
          cat > /usr/share/nginx/html/shared/index.html << 'HTML_EOF'
          <!DOCTYPE html>
          <html>
          <head>
              <title>HashFoundry Storage Demo</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                  .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                  .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; margin-bottom: 30px; }
                  .section { background: #ecf0f1; padding: 20px; border-radius: 5px; margin: 20px 0; }
                  .pv-badge { background: #3498db; color: white; padding: 5px 10px; border-radius: 3px; font-size: 12px; font-weight: bold; }
                  .pvc-badge { background: #e74c3c; color: white; padding: 5px 10px; border-radius: 3px; font-size: 12px; font-weight: bold; }
                  .storage-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
                  .storage-item { background: white; padding: 15px; border-radius: 5px; border-left: 4px solid #3498db; }
                  .volume-info { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 5px; font-family: monospace; }
              </style>
          </head>
          <body>
              <div class="container">
                  <div class="header">
                      <h1>💾 HashFoundry Storage Demo</h1>
                      <p>Demonstrating Persistent Volumes and Persistent Volume Claims</p>
                      <span class="pv-badge">PV</span>
                      <span class="pvc-badge">PVC</span>
                  </div>
                  
                  <div class="section">
                      <h2>📊 Volume Mount Information</h2>
                      <div class="storage-grid">
                          <div class="storage-item">
                              <strong>App Data Volume:</strong><br>
                              Mount: /var/lib/app<br>
                              PVC: hashfoundry-app-data-pvc<br>
                              Access: ReadWriteOnce
                          </div>
                          <div class="storage-item">
                              <strong>Shared Data Volume:</strong><br>
                              Mount: /usr/share/nginx/html/shared<br>
                              PVC: hashfoundry-shared-pvc<br>
                              Access: ReadWriteMany
                          </div>
                          <div class="storage-item">
                              <strong>Config Volume:</strong><br>
                              Mount: /etc/nginx/conf.d<br>
                              PVC: hashfoundry-config-pvc<br>
                              Access: ReadOnlyMany
                          </div>
                          <div class="storage-item">
                              <strong>Cache Volume:</strong><br>
                              Mount: /var/cache/nginx<br>
                              PVC: hashfoundry-dynamic-pvc-3<br>
                              Access: ReadWriteOnce
                          </div>
                      </div>
                  </div>
                  
                  <div class="section">
                      <h2>📁 Volume Contents</h2>
                      <div class="volume-info">
                          <strong>App Data Files:</strong><br>
                          <pre>$(ls -la /var/lib/app/ 2>/dev/null || echo 'No files found')</pre>
                      </div>
                      <div class="volume-info">
                          <strong>Shared Data Files:</strong><br>
                          <pre>$(ls -la /usr/share/nginx/html/shared/ 2>/dev/null || echo 'No files found')</pre>
                      </div>
                  </div>
                  
                  <div class="section">
                      <h2>ℹ️ Storage Concepts</h2>
                      <div class="storage-grid">
                          <div class="storage-item">
                              <strong>🏗️ Persistent Volume (PV):</strong> Cluster-level storage resource
                          </div>
                          <div class="storage-item">
                              <strong>📋 Persistent Volume Claim (PVC):</strong> User request for storage
                          </div>
                          <div class="storage-item">
                              <strong>🔗 Binding:</strong> Automatic connection between PV and PVC
                          </div>
                          <div class="storage-item">
                              <strong>⚡ Dynamic Provisioning:</strong> Automatic PV creation via StorageClass
                          </div>
                      </div>
                  </div>
                  
                  <div class="section">
                      <p><strong>Pod:</strong> $(hostname)</p>
                      <p><strong>Last Updated:</strong> $(date)</p>
                  </div>
              </div>
          </body>
          </html>
          HTML_EOF
          
          echo "Demo files created successfully!"
          
          # Запустить nginx
          nginx -g 'daemon off;'
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: app-data
        persistentVolumeClaim:
          claimName: hashfoundry-app-data-pvc
      - name: shared-data
        persistentVolumeClaim:
          claimName: hashfoundry-shared-pvc
      - name: config-data
        persistentVolumeClaim:
          claimName: hashfoundry-config-pvc
      - name: cache-data
        persistentVolumeClaim:
          claimName: hashfoundry-dynamic-pvc-3
---
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-app-service
  namespace: storage-demo
  labels:
    app: hashfoundry-app
spec:
  selector:
    app: hashfoundry-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить развертывания
kubectl get pods,pvc,pv -n storage-demo
kubectl get statefulsets,deployments -n storage-demo
```

### **6. Анализ и мониторинг PV/PVC:**
```bash
# Создать скрипт для анализа storage ресурсов
cat << 'EOF' > analyze-storage.sh
#!/bin/bash

NAMESPACE=${1:-"storage-demo"}

echo "=== Persistent Volume and PVC Analysis ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для анализа PV
analyze_persistent_volumes() {
    echo "=== Persistent Volumes Analysis ==="
    
    echo "All Persistent Volumes in cluster:"
    kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS:.spec.accessModes[*],RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "PV Details:"
    for pv in $(kubectl get pv -o jsonpath='{.items[*].metadata.name}'); do
        echo "----------------------------------------"
        echo "PV: $pv"
        
        # Основная информация
        capacity=$(kubectl get pv $pv -o jsonpath='{.spec.capacity.storage}')
        access_modes=$(kubectl get pv $pv -o jsonpath='{.spec.accessModes[*]}')
        reclaim_policy=$(kubectl get pv $pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
        status=$(kubectl get pv $pv -o jsonpath='{.status.phase}')
        storage_class=$(kubectl get pv $pv -o jsonpath='{.spec.storageClassName}')
        
        echo "  Capacity: $capacity"
        echo "  Access Modes: $access_modes"
        echo "  Reclaim Policy: $reclaim_policy"
        echo "  Status: $status"
        echo "  Storage Class: ${storage_class:-"<none>"}"
        
        # Информация о привязке
        claim_name=$(kubectl get pv $pv -o jsonpath='{.spec.claimRef.name}' 2>/dev/null)
        claim_namespace=$(kubectl get pv $pv -o jsonpath='{.spec.claimRef.namespace}' 2>/dev/null)
        
        if [ -n "$claim_name" ]; then
            echo "  Bound to PVC: $claim_namespace/$claim_name"
        else
            echo "  Status: Available (not bound)"
        fi
        
        # Тип хранилища
        if kubectl get pv $pv -o jsonpath='{.spec.hostPath}' >/dev/null 2>&1; then
            host_path=$(kubectl get pv $pv -o jsonpath='{.spec.hostPath.path}')
            echo "  Type: hostPath ($host_path)"
        elif kubectl get pv $pv -o jsonpath='{.spec.nfs}' >/dev/null 2>&1; then
            nfs_server=$(kubectl get pv $pv -o jsonpath='{.spec.nfs.server}')
            nfs_path=$(kubectl get pv $pv -o jsonpath='{.spec.nfs.path}')
            echo "  Type: NFS ($nfs_server:$nfs_path)"
        else
            echo "  Type: Other/Cloud"
        fi
        
        echo
    done
}

# Функция для анализа PVC
analyze_persistent_volume_claims() {
    echo "=== Persistent Volume Claims Analysis ==="
    
    echo "PVCs in namespace $NAMESPACE:"
    kubectl get pvc -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,ACCESS:.spec.accessModes[*],STORAGECLASS:.spec.storageClassName,AGE:.metadata.creationTimestamp" 2>/dev/null || echo "No PVCs found in namespace $NAMESPACE"
    echo
    
    # Детальный анализ каждого PVC
    pvcs=($(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pvc in "${pvcs[@]}"; do
        if [ -z "$pvc" ]; then
            echo "No PVCs found in namespace $NAMESPACE"
            continue
        fi
        
        echo "----------------------------------------"
        echo "PVC: $pvc"
        
        # Основная информация
        status=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}')
        requested_storage=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')
        actual_capacity=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.capacity.storage}')
        access_modes=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.accessModes[*]}')
        storage_class=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        
        echo "  Status: $status"
        echo "  Requested Storage: $requested_storage"
        echo "  Actual Capacity: ${actual_capacity:-"N/A"}"
        echo "  Access Modes: $access_modes"
        echo "  Storage Class: ${storage_class:-"<none>"}"
        echo "  Bound to PV: ${volume_name:-"<none>"}"
        
        # Проверить использование в Pod'ах
        echo "  Used by Pods:"
        kubectl get pods -n $NAMESPACE -o json | jq -r --arg pvc "$pvc" '
          .items[] | 
          select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) | 
          "    - " + .metadata.name
        ' 2>/dev/null || echo "    No pods found using this PVC"
        
        # Проверить события
        echo "  Recent Events:"
        kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$pvc --sort-by='.lastTimestamp' | tail -3 | while read line; do
            echo "    $line"
        done
        
        echo
    done
}

# Функция для проверки использования хранилища
check_storage_usage() {
    echo "=== Storage Usage Analysis ==="
    
    # Проверить использование в Pod'ах
    pods=($(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pod in "${pods[@]}"; do
        if [ -z "$pod" ]; then
            echo "No pods found in namespace $NAMESPACE"
            continue
        fi
        
        echo "Pod: $pod"
        echo "  Mounted Volumes:"
        
        # Получить информацию о volume mounts
        kubectl get pod $pod -n $NAMESPACE -o json | jq -r '
          .spec.containers[].volumeMounts[]? | 
          "    - " + .name + " -> " + .mountPath
        ' 2>/dev/null || echo "    No volume mounts found"
        
        # Проверить использование дискового пространства (если Pod запущен)
        status=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
        if [ "$status" = "Running" ]; then
            echo "  Disk Usage:"
            kubectl exec $pod -n $NAMESPACE -- df -h 2>/dev/null | grep -E "(Filesystem|/var|/etc|/usr)" | while read line; do
                echo "    $line"
            done
        fi
        
        echo
    done
}

# Функция для проверки StorageClass
analyze_storage_classes() {
    echo "=== StorageClass Analysis ==="
    
    echo "Available StorageClasses:"
    kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class"
    echo
    
    # Детальный анализ каждого StorageClass
    for sc in $(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}'); do
        echo "----------------------------------------"
        echo "StorageClass: $sc"
        
        provisioner=$(kubectl get storageclass $sc -o jsonpath='{.provisioner}')
        reclaim_policy=$(kubectl get storageclass $sc -o jsonpath='{.reclaimPolicy}')
        binding_mode=$(kubectl get storageclass $sc -o jsonpath='{.volumeBindingMode}')
        is_default=$(kubectl get storageclass $sc -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')
        
        echo "  Provisioner: $provisioner"
        echo "  Reclaim Policy: ${reclaim_policy:-"Delete"}"
        echo "  Volume Binding Mode: ${binding_mode:-"Immediate"}"
        echo "  Default: ${is_default:-"false"}"
        
        # Показать параметры
        echo "  Parameters:"
        kubectl get storageclass $sc -o jsonpath='{.parameters}' | jq '.' 2>/dev/null || echo "    No parameters"
        
        echo
    done
}

# Основная функция
main() {
    case "$2" in
        "pv")
            analyze_persistent_volumes
            ;;
        "pvc")
            analyze_persistent_volume_claims
            ;;
        "usage")
            check_storage_usage
            ;;
        "storageclass")
            analyze_storage_classes
            ;;
        "all"|"")
            analyze_persistent_volumes
            analyze_persistent_volume_claims
            check_storage_usage
            analyze_storage_classes
            ;;
        *)
            echo "Usage: $0 [namespace] [analysis_type]"
            echo ""
            echo "Analysis types:"
            echo "  pv           - Analyze Persistent Volumes"
            echo "  pvc          - Analyze Persistent Volume Claims"
            echo "  usage        - Check storage usage in pods"
            echo "  storageclass - Analyze StorageClasses"
            echo "  all          - Run all analyses (default)"
            echo ""
            echo "Examples:"
            echo "  $0 storage-demo"
            echo "  $0 storage-demo pvc"
            echo "  $0 storage-demo usage"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x analyze-storage.sh

# Запустить анализ
./analyze-storage.sh storage-demo
```

## 🧹 **Очистка ресурсов:**
```bash
# Создать скрипт для очистки демонстрации
cat << 'EOF' > cleanup-storage-demo.sh
#!/bin/bash

NAMESPACE="storage-demo"

echo "=== Cleaning up Storage Demo ==="
echo

# Удалить все Pod'ы и Deployments
echo "Deleting deployments and statefulsets..."
kubectl delete deployments,statefulsets --all -n $NAMESPACE

# Подождать завершения Pod'ов
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pods --all -n $NAMESPACE --timeout=60s

# Удалить все PVC
echo "Deleting PVCs..."
kubectl delete pvc --all -n $NAMESPACE

# Удалить статические PV
echo "Deleting static PVs..."
kubectl delete pv -l app.kubernetes.io/name=hashfoundry-storage

# Удалить Services
echo "Deleting services..."
kubectl delete services --all -n $NAMESPACE

# Удалить namespace
echo "Deleting namespace..."
kubectl delete namespace $NAMESPACE

# Удалить локальные файлы
echo "Cleaning up local files..."
rm -f analyze-storage.sh

echo "✓ Storage demo cleanup completed"

EOF

chmod +x cleanup-storage-demo.sh
./cleanup-storage-demo.sh
```

## 📋 **Сводка PV и PVC:**

### **Основные команды:**
```bash
# Просмотр PV и PVC
kubectl get pv
kubectl get pvc --all-namespaces
kubectl get storageclass

# Детальная информация
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name> -n <namespace>

# Создание PVC
kubectl apply -f pvc.yaml

# Проверка привязки
kubectl get pvc -o wide
kubectl get events --sort-by='.lastTimestamp'
```

## 📊 **Сравнительная таблица:**

| **Компонент** | **Уровень** | **Управление** | **Жизненный цикл** |
|---------------|-------------|----------------|-------------------|
| **PV** | Кластер | Администратор | Независимый от Pod'ов |
| **PVC** | Namespace | Пользователь | Связан с приложением |
| **StorageClass** | Кластер | Администратор | Шаблон для динамического создания |

## 🎯 **Best Practices:**

### **1. Планирование хранилища:**
- **Определите требования** к производительности и объему
- **Выберите подходящий тип** хранилища
- **Планируйте backup стратегию**
- **Учитывайте costs** различных типов хранилища

### **2. Безопасность:**
- **Используйте RBAC** для контроля доступа к PVC
- **Шифруйте данные** at rest и in transit
- **Регулярно аудируйте** использование хранилища
- **Мониторьте доступ** к критичным данным

### **3. Производительность:**
- **Выбирайте правильные access modes**
- **Оптимизируйте размер** PV/PVC
- **Используйте подходящие StorageClass**
- **Мониторьте производительность** I/O

**PV и PVC обеспечивают надежное и гибкое управление постоянным хранилищем в Kubernetes!**
