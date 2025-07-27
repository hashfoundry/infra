# 62. Access Modes для Persistent Volumes

## 🎯 **Access Modes для Persistent Volumes**

**Access Modes** определяют, как Persistent Volume может быть смонтирован на узлах кластера. Это критически важная характеристика, которая влияет на то, сколько Pod'ов может одновременно использовать один PV и как они могут с ним взаимодействовать.

## 🏗️ **Основные Access Modes:**

### **1. ReadWriteOnce (RWO)**
- **Один узел** может монтировать volume для чтения и записи
- **Наиболее распространенный** режим
- **Подходит для баз данных** и stateful приложений

### **2. ReadOnlyMany (ROX)**
- **Множество узлов** может монтировать volume только для чтения
- **Подходит для статического контента** и конфигураций
- **Безопасный для shared данных**

### **3. ReadWriteMany (RWX)**
- **Множество узлов** может монтировать volume для чтения и записи
- **Требует специальных типов** хранилища (NFS, CephFS)
- **Сложнее в управлении** из-за concurrent access

### **4. ReadWriteOncePod (RWOP)**
- **Только один Pod** может монтировать volume для чтения и записи
- **Новый режим** (Kubernetes 1.22+)
- **Максимальная изоляция** данных

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание демонстрационной среды:**
```bash
# Создать namespace для демонстрации access modes
kubectl create namespace access-modes-demo

# Создать labels для организации
kubectl label namespace access-modes-demo \
  demo.type=access-modes \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational

# Проверить поддерживаемые access modes в вашем HA кластере
echo "=== Checking supported access modes in HA cluster ==="
kubectl get storageclass -o yaml | grep -A 10 -B 5 "allowedTopologies\|volumeBindingMode"
```

### **2. Демонстрация ReadWriteOnce (RWO):**
```bash
# Создать PV с ReadWriteOnce access mode
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-rwo-pv
  labels:
    type: local
    access-mode: rwo
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/demo: access-modes
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/hashfoundry-rwo"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
EOF

# Создать PVC для RWO
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-rwo-pvc
  namespace: access-modes-demo
  labels:
    access-mode: rwo
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "ReadWriteOnce PVC for single-node access"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  selector:
    matchLabels:
      access-mode: rwo
EOF

# Создать StatefulSet, использующий RWO PVC
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hashfoundry-rwo-database
  namespace: access-modes-demo
  labels:
    app: rwo-database
    access-mode: rwo
spec:
  serviceName: rwo-database-service
  replicas: 1  # Только одна реплика для RWO
  selector:
    matchLabels:
      app: rwo-database
  template:
    metadata:
      labels:
        app: rwo-database
        access-mode: rwo
      annotations:
        storage.hashfoundry.io/access-mode: "ReadWriteOnce"
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "hashfoundry_rwo_db"
        - name: POSTGRES_USER
          value: "rwo_user"
        - name: POSTGRES_PASSWORD
          value: "rwo_password_123"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        command: ["sh", "-c"]
        args:
        - |
          # Создать демонстрационные данные
          echo "Starting PostgreSQL with RWO storage..."
          
          # Инициализировать базу данных
          docker-entrypoint.sh postgres &
          
          # Подождать запуска PostgreSQL
          sleep 30
          
          # Создать демонстрационные данные
          psql -U rwo_user -d hashfoundry_rwo_db -c "
            CREATE TABLE IF NOT EXISTS rwo_demo (
              id SERIAL PRIMARY KEY,
              access_mode VARCHAR(20) DEFAULT 'ReadWriteOnce',
              node_name VARCHAR(100),
              pod_name VARCHAR(100),
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              data TEXT
            );
            
            INSERT INTO rwo_demo (node_name, pod_name, data) VALUES 
            ('$(hostname)', '$(hostname)', 'RWO demo data - exclusive access'),
            ('$(hostname)', '$(hostname)', 'Only one pod can write to this volume'),
            ('$(hostname)', '$(hostname)', 'Perfect for databases and stateful apps');
          "
          
          # Продолжить работу PostgreSQL
          wait
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: hashfoundry-rwo-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: rwo-database-service
  namespace: access-modes-demo
  labels:
    app: rwo-database
spec:
  selector:
    app: rwo-database
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
EOF

# Проверить RWO deployment
kubectl get pods,pvc,pv -n access-modes-demo -l access-mode=rwo
```

### **3. Демонстрация ReadOnlyMany (ROX):**
```bash
# Создать PV с ReadOnlyMany access mode
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-rox-pv
  labels:
    type: local
    access-mode: rox
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/demo: access-modes
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/hashfoundry-rox"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
EOF

# Предварительно создать статические файлы для ROX демонстрации
cat << 'EOF' > create-rox-data.sh
#!/bin/bash

# Создать директорию и файлы для ROX демонстрации
sudo mkdir -p /tmp/hashfoundry-rox/config
sudo mkdir -p /tmp/hashfoundry-rox/static
sudo mkdir -p /tmp/hashfoundry-rox/docs

# Создать конфигурационные файлы
sudo tee /tmp/hashfoundry-rox/config/app.conf << 'CONF_EOF'
# HashFoundry Application Configuration
# Access Mode: ReadOnlyMany (ROX)

[database]
host = rwo-database-service.access-modes-demo.svc.cluster.local
port = 5432
name = hashfoundry_rwo_db
read_only = true

[cache]
enabled = true
ttl = 3600
type = redis

[logging]
level = INFO
format = json
output = /var/log/app.log

[features]
readonly_mode = true
shared_config = true
multi_pod_access = true
CONF_EOF

sudo tee /tmp/hashfoundry-rox/config/nginx.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name localhost;
    
    # Статические файлы из ROX volume
    location /static/ {
        alias /usr/share/nginx/html/static/;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
    
    location /config/ {
        alias /etc/app/config/;
        default_type text/plain;
    }
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
NGINX_EOF

# Создать статические файлы
sudo tee /tmp/hashfoundry-rox/static/style.css << 'CSS_EOF'
body {
    font-family: Arial, sans-serif;
    margin: 40px;
    background: #f8f9fa;
}

.rox-container {
    max-width: 800px;
    margin: 0 auto;
    background: white;
    padding: 30px;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.rox-header {
    background: #17a2b8;
    color: white;
    padding: 20px;
    border-radius: 5px;
    margin-bottom: 30px;
}

.rox-badge {
    background: #17a2b8;
    color: white;
    padding: 5px 10px;
    border-radius: 3px;
    font-size: 12px;
    font-weight: bold;
}

.readonly-warning {
    background: #fff3cd;
    border: 1px solid #ffeaa7;
    color: #856404;
    padding: 15px;
    border-radius: 5px;
    margin: 20px 0;
}
CSS_EOF

sudo tee /tmp/hashfoundry-rox/static/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>HashFoundry ROX Demo</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    <div class="rox-container">
        <div class="rox-header">
            <h1>📖 ReadOnlyMany (ROX) Demo</h1>
            <p>Multiple pods can read this content simultaneously</p>
            <span class="rox-badge">READ-ONLY</span>
        </div>
        
        <div class="readonly-warning">
            <strong>⚠️ Read-Only Mode:</strong> This volume is mounted as ReadOnlyMany. 
            Multiple pods across different nodes can read this content, but no pod can modify it.
        </div>
        
        <h2>📋 Configuration Files</h2>
        <ul>
            <li><a href="/config/app.conf">Application Configuration</a></li>
            <li><a href="/config/nginx.conf">Nginx Configuration</a></li>
        </ul>
        
        <h2>📊 ROX Characteristics</h2>
        <ul>
            <li>✅ Multiple pods can mount simultaneously</li>
            <li>✅ Works across different nodes</li>
            <li>✅ Perfect for static content and configurations</li>
            <li>❌ No write operations allowed</li>
            <li>❌ Cannot modify files at runtime</li>
        </ul>
        
        <h2>🎯 Use Cases</h2>
        <ul>
            <li>Static website content</li>
            <li>Application configurations</li>
            <li>Shared libraries and assets</li>
            <li>Documentation and help files</li>
        </ul>
    </div>
</body>
</html>
HTML_EOF

# Создать документацию
sudo tee /tmp/hashfoundry-rox/docs/README.md << 'DOC_EOF'
# ReadOnlyMany (ROX) Volume Demo

This volume demonstrates the ReadOnlyMany access mode in Kubernetes.

## Characteristics

- **Access Mode**: ReadOnlyMany (ROX)
- **Concurrent Access**: Multiple pods can mount simultaneously
- **Write Operations**: Not allowed
- **Use Case**: Static content, configurations, shared resources

## Files Structure

```
/tmp/hashfoundry-rox/
├── config/
│   ├── app.conf
│   └── nginx.conf
├── static/
│   ├── index.html
│   └── style.css
└── docs/
    └── README.md
```

## Access Pattern

Multiple pods can read from this volume simultaneously, making it perfect for:
- Shared configuration files
- Static web content
- Documentation
- Shared libraries

## Limitations

- No write operations allowed
- Content must be prepared before mounting
- Changes require volume recreation
DOC_EOF

# Установить правильные права доступа
sudo chmod -R 755 /tmp/hashfoundry-rox/
sudo chmod 644 /tmp/hashfoundry-rox/config/*
sudo chmod 644 /tmp/hashfoundry-rox/static/*
sudo chmod 644 /tmp/hashfoundry-rox/docs/*

echo "ROX demo data created successfully!"

EOF

chmod +x create-rox-data.sh
./create-rox-data.sh

# Создать PVC для ROX
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-rox-pvc
  namespace: access-modes-demo
  labels:
    access-mode: rox
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "ReadOnlyMany PVC for shared read access"
spec:
  storageClassName: manual
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 1Gi
  selector:
    matchLabels:
      access-mode: rox
EOF

# Создать Deployment с несколькими репликами, использующими ROX PVC
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-rox-readers
  namespace: access-modes-demo
  labels:
    app: rox-readers
    access-mode: rox
spec:
  replicas: 3  # Несколько реплик могут читать одновременно
  selector:
    matchLabels:
      app: rox-readers
  template:
    metadata:
      labels:
        app: rox-readers
        access-mode: rox
      annotations:
        storage.hashfoundry.io/access-mode: "ReadOnlyMany"
    spec:
      containers:
      - name: nginx-reader
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: shared-config
          mountPath: /etc/app/config
          readOnly: true
        - name: shared-static
          mountPath: /usr/share/nginx/html/static
          readOnly: true
        - name: shared-docs
          mountPath: /usr/share/nginx/html/docs
          readOnly: true
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Nginx with ROX shared content..."
          
          # Копировать nginx конфигурацию
          cp /etc/app/config/nginx.conf /etc/nginx/conf.d/default.conf
          
          # Создать главную страницу с информацией о Pod'е
          cat > /usr/share/nginx/html/index.html << 'HTML_EOF'
          <!DOCTYPE html>
          <html>
          <head>
              <title>HashFoundry ROX Reader</title>
              <link rel="stylesheet" href="/static/style.css">
          </head>
          <body>
              <div class="rox-container">
                  <div class="rox-header">
                      <h1>📖 ROX Reader Pod</h1>
                      <p>Pod: $(hostname)</p>
                      <p>Node: $(cat /etc/hostname 2>/dev/null || echo 'Unknown')</p>
                      <span class="rox-badge">READ-ONLY</span>
                  </div>
                  
                  <div class="readonly-warning">
                      <strong>ℹ️ This pod is reading from a ReadOnlyMany volume.</strong><br>
                      Multiple pods can access the same content simultaneously.
                  </div>
                  
                  <h2>📁 Shared Content</h2>
                  <ul>
                      <li><a href="/static/">Static Files</a></li>
                      <li><a href="/config/">Configuration Files</a></li>
                      <li><a href="/docs/">Documentation</a></li>
                  </ul>
                  
                  <h2>📊 Volume Information</h2>
                  <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; font-family: monospace;">
                      <strong>Mount Points:</strong><br>
                      /etc/app/config → ROX Volume (config)<br>
                      /usr/share/nginx/html/static → ROX Volume (static)<br>
                      /usr/share/nginx/html/docs → ROX Volume (docs)<br><br>
                      
                      <strong>Access Mode:</strong> ReadOnlyMany<br>
                      <strong>Concurrent Readers:</strong> Multiple pods allowed<br>
                      <strong>Write Access:</strong> Denied<br>
                  </div>
                  
                  <h2>🔍 File Listing</h2>
                  <div style="background: #2c3e50; color: white; padding: 15px; border-radius: 5px; font-family: monospace;">
                      <strong>Config files:</strong><br>
                      <pre>$(ls -la /etc/app/config/ 2>/dev/null || echo 'No files found')</pre>
                      
                      <strong>Static files:</strong><br>
                      <pre>$(ls -la /usr/share/nginx/html/static/ 2>/dev/null || echo 'No files found')</pre>
                      
                      <strong>Documentation:</strong><br>
                      <pre>$(ls -la /usr/share/nginx/html/docs/ 2>/dev/null || echo 'No files found')</pre>
                  </div>
                  
                  <p><strong>Last Updated:</strong> $(date)</p>
              </div>
          </body>
          </html>
          HTML_EOF
          
          echo "ROX reader pod $(hostname) started successfully!"
          
          # Запустить nginx
          nginx -g 'daemon off;'
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: shared-config
        persistentVolumeClaim:
          claimName: hashfoundry-rox-pvc
      - name: shared-static
        persistentVolumeClaim:
          claimName: hashfoundry-rox-pvc
      - name: shared-docs
        persistentVolumeClaim:
          claimName: hashfoundry-rox-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: rox-readers-service
  namespace: access-modes-demo
  labels:
    app: rox-readers
spec:
  selector:
    app: rox-readers
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить ROX deployment
kubectl get pods,pvc,pv -n access-modes-demo -l access-mode=rox
```

### **4. Демонстрация ReadWriteMany (RWX) с NFS:**
```bash
# Создать NFS-based PV для демонстрации RWX (если NFS доступен)
# Примечание: В production используйте реальный NFS сервер

# Сначала проверим, есть ли NFS provisioner в кластере
kubectl get storageclass | grep nfs || echo "No NFS StorageClass found"

# Создать эмуляцию RWX с помощью hostPath (только для демонстрации)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hashfoundry-rwx-pv
  labels:
    type: local
    access-mode: rwx
    app.kubernetes.io/name: hashfoundry-storage
    storage.hashfoundry.io/demo: access-modes
spec:
  storageClassName: manual
  capacity:
    storage: 3Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/hashfoundry-rwx"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
EOF

# Создать PVC для RWX
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hashfoundry-rwx-pvc
  namespace: access-modes-demo
  labels:
    access-mode: rwx
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    storage.hashfoundry.io/description: "ReadWriteMany PVC for shared read-write access"
    storage.hashfoundry.io/warning: "hostPath RWX only works on single-node clusters"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 2Gi
  selector:
    matchLabels:
      access-mode: rwx
EOF

# Создать Deployment с несколькими репликами, использующими RWX PVC
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-rwx-writers
  namespace: access-modes-demo
  labels:
    app: rwx-writers
    access-mode: rwx
spec:
  replicas: 2  # Несколько реплик могут писать одновременно
  selector:
    matchLabels:
      app: rwx-writers
  template:
    metadata:
      labels:
        app: rwx-writers
        access-mode: rwx
      annotations:
        storage.hashfoundry.io/access-mode: "ReadWriteMany"
    spec:
      containers:
      - name: writer
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting RWX writer pod: $(hostname)"
          
          # Создать директорию для этого Pod'а
          mkdir -p /shared/pods/$(hostname)
          mkdir -p /shared/logs
          mkdir -p /shared/data
          
          # Создать файл с информацией о Pod'е
          cat > /shared/pods/$(hostname)/info.txt << INFO_EOF
          Pod Name: $(hostname)
          Access Mode: ReadWriteMany
          Started: $(date)
          Node: $(cat /etc/hostname 2>/dev/null || echo 'Unknown')
          Capabilities: Read + Write
          Concurrent Access: Yes
          INFO_EOF
          
          # Создать лог файл
          echo "$(date): Pod $(hostname) started with RWX access" >> /shared/logs/activity.log
          
          # Непрерывно записывать данные
          counter=0
          while true; do
            counter=$((counter + 1))
            
            # Записать данные в общий файл
            echo "$(date): Pod $(hostname) - Entry #$counter" >> /shared/data/shared_data.txt
            
            # Записать в лог
            echo "$(date): Pod $(hostname) wrote entry #$counter" >> /shared/logs/activity.log
            
            # Создать HTML отчет
            cat > /shared/rwx_report.html << HTML_EOF
          <!DOCTYPE html>
          <html>
          <head>
              <title>HashFoundry RWX Demo Report</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; background: #f8f9fa; }
                  .rwx-container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                  .rwx-header { background: #28a745; color: white; padding: 20px; border-radius: 5px; margin-bottom: 30px; }
                  .rwx-badge { background: #28a745; color: white; padding: 5px 10px; border-radius: 3px; font-size: 12px; font-weight: bold; }
                  .warning { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 15px; border-radius: 5px; margin: 20px 0; }
                  .log-box { background: #2c3e50; color: white; padding: 15px; border-radius: 5px; font-family: monospace; max-height: 300px; overflow-y: auto; }
                  .pod-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
                  .pod-item { background: #e9ecef; padding: 15px; border-radius: 5px; border-left: 4px solid #28a745; }
              </style>
          </head>
          <body>
              <div class="rwx-container">
                  <div class="rwx-header">
                      <h1>📝 ReadWriteMany (RWX) Demo</h1>
                      <p>Multiple pods writing to shared storage simultaneously</p>
                      <span class="rwx-badge">READ-WRITE-MANY</span>
                  </div>
                  
                  <div class="warning">
                      <strong>⚠️ Note:</strong> This demo uses hostPath which only works on single-node clusters. 
                      In production, use NFS, CephFS, or other distributed storage systems.
                  </div>
                  
                  <h2>📊 Active Pods</h2>
                  <div class="pod-grid">
          $(for pod_dir in /shared/pods/*/; do
              if [ -d "$pod_dir" ]; then
                  pod_name=$(basename "$pod_dir")
                  echo "            <div class=\"pod-item\">"
                  echo "              <strong>Pod:</strong> $pod_name<br>"
                  if [ -f "$pod_dir/info.txt" ]; then
                      echo "              <pre>$(cat "$pod_dir/info.txt")</pre>"
                  fi
                  echo "            </div>"
              fi
          done)
                  </div>
                  
                  <h2>📝 Shared Data (Last 10 entries)</h2>
                  <div class="log-box">
          $(tail -10 /shared/data/shared_data.txt 2>/dev/null || echo 'No data yet')
                  </div>
                  
                  <h2>📋 Activity Log (Last 15 entries)</h2>
                  <div class="log-box">
          $(tail -15 /shared/logs/activity.log 2>/dev/null || echo 'No logs yet')
                  </div>
                  
                  <h2>📁 File System Status</h2>
                  <div class="log-box">
                      <strong>Directory structure:</strong><br>
          $(find /shared -type f | head -20 | while read file; do echo "$file"; done)
                  </div>
                  
                  <p><strong>Last Updated:</strong> $(date)</p>
                  <p><strong>Report Generated by:</strong> Pod $(hostname)</p>
              </div>
          </body>
          </html>
          HTML_EOF
            
            echo "Pod $(hostname): Wrote entry #$counter to shared storage"
            sleep 10
          done
        volumeMounts:
        - name: shared-storage
          mountPath: /shared
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: hashfoundry-rwx-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: rwx-writers-service
  namespace: access-modes-demo
  labels:
    app: rwx-writers
spec:
  selector:
    app: rwx-writers
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Проверить RWX deployment
kubectl get pods,pvc,pv -n access-modes-demo -l access-mode=rwx
```

### **5. Анализ и сравнение Access Modes:**
```bash
# Создать скрипт для анализа access modes
cat << 'EOF' > analyze-access-modes.sh
#!/bin/bash

NAMESPACE=${1:-"access-modes-demo"}

echo "=== Access Modes Analysis ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для анализа PV access modes
analyze_pv_access_modes() {
    echo "=== Persistent Volumes Access Modes ==="
    
    echo "PV Access Modes Summary:"
    kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS_MODES:.spec.accessModes[*],STATUS:.status.phase,CLAIM:.spec.claimRef.name"
    echo
    
    # Группировка по access modes
    echo "PVs by Access Mode:"
    echo "ReadWriteOnce (RWO):"
    kubectl get pv -o json | jq -r '.items[] | select(.spec.accessModes[] == "ReadWriteOnce") | "  - " + .metadata.name + " (" + .spec.capacity.storage + ")"' 2>/dev/null || echo "  No RWO volumes found"
    
    echo "ReadOnlyMany (ROX):"
    kubectl get pv -o json | jq -r '.items[] | select(.spec.accessModes[] == "ReadOnlyMany") | "  - " + .metadata.name + " (" + .spec.capacity.storage + ")"' 2>/dev/null || echo "  No ROX volumes found"
    
    echo "ReadWriteMany (RWX):"
    kubectl get pv -o json | jq -r '.items[] | select(.spec.accessModes[] == "ReadWriteMany") | "  - " + .metadata.name + " (" + .spec.capacity.storage + ")"' 2>/dev/null || echo "  No RWX volumes found"
    
    echo "ReadWriteOncePod (RWOP):"
    kubectl get pv -o json | jq -r '.items[] | select(.spec.accessModes[] == "ReadWriteOncePod") | "  - " + .metadata.name + " (" + .spec.capacity.storage + ")"' 2>/dev/null || echo "  No RWOP volumes found"
    
    echo
}

# Функция для анализа PVC access modes
analyze_pvc_access_modes() {
    echo "=== PVC Access Modes Analysis ==="
    
    echo "PVCs in namespace $NAMESPACE:"
    kubectl get pvc -n $NAMESPACE -o custom-columns="NAME:.metadata.name,ACCESS_MODES:.spec.accessModes[*],STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage" 2>/dev/null || echo "No PVCs found"
    echo
    
    # Детальный анализ каждого PVC
    pvcs=($(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pvc in "${pvcs[@]}"; do
        if [ -z "$pvc" ]; then
            continue
        fi
        
        echo "----------------------------------------"
        echo "PVC: $pvc"
        
        access_modes=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.accessModes[*]}')
        status=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}')
        volume_name=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
        
        echo "  Access Modes: $access_modes"
        echo "  Status: $status"
        echo "  Bound to PV: ${volume_name:-"<none>"}"
        
        # Проверить совместимость access modes
        if [ -n "$volume_name" ]; then
            pv_access_modes=$(kubectl get pv $volume_name -o jsonpath='{.spec.accessModes[*]}' 2>/dev/null)
            echo "  PV Access Modes: ${pv_access_modes:-"<unknown>"}"
            
            # Проверить совместимость
            if [ "$access_modes" = "$pv_access_modes" ]; then
                echo "  ✅ Access modes match"
            else
                echo "  ⚠️  Access modes mismatch!"
            fi
        fi
        
        # Проверить использование в Pod'ах
        echo "  Used by Pods:"
        kubectl get pods -n $NAMESPACE -o json | jq -r --arg pvc "$pvc" '
          .items[] | 
          select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) | 
          "    - " + .metadata.name + " (Node: " + (.spec.nodeName // "Unknown") + ")"
        ' 2>/dev/null || echo "    No pods using this PVC"
        
        echo
    done
}

# Функция для тестирования access modes
test_access_modes() {
    echo "=== Access Modes Testing ==="
    
    # Тест RWO - попытка создать второй Pod с тем же PVC
    echo "Testing ReadWriteOnce (RWO) exclusivity:"
    rwo_pods=$(kubectl get pods -n $NAMESPACE -l access-mode=rwo --no-headers | wc -l)
    echo "  Current RWO pods: $rwo_pods"
    
    if [ "$rwo_pods" -gt 1 ]; then
        echo "  ⚠️  Multiple pods using RWO volume (should not happen)"
    else
        echo "  ✅ RWO exclusivity maintained"
    fi
    
    # Тест ROX - проверить множественный доступ
    echo "Testing ReadOnlyMany (ROX) shared access:"
    rox_pods=$(kubectl get pods -n $NAMESPACE -l access-mode=rox --no-headers | wc -l)
    echo "  Current ROX pods: $rox_pods"
    
    if [ "$rox_pods" -gt 1 ]; then
        echo "  ✅ Multiple pods sharing ROX volume"
    else
        echo "  ℹ️  Only one ROX pod currently running"
    fi
    
    # Тест RWX - проверить множественный доступ для записи
    echo "Testing ReadWriteMany (RWX) shared write access:"
    rwx_pods=$(kubectl get pods -n $NAMESPACE -l access-mode=rwx --no-headers | wc -l)
    echo "  Current RWX pods: $rwx_pods"
    
    if [ "$rwx_pods" -gt 1 ]; then
        echo "  ✅ Multiple pods sharing RWX volume"
        
        # Проверить, что все Pod'ы могут писать
        echo "  Checking write access from all pods:"
        kubectl get pods -n $NAMESPACE -l access-mode=rwx -o name | while read pod; do
            pod_name=$(echo $pod | cut -d'/' -f2)
            echo "    Testing write access from $pod_name..."
            kubectl exec $pod_name -n $NAMESPACE -- sh -c "echo 'Test write from $pod_name at $(date)' >> /shared/test_writes.log" 2>/dev/null && echo "      ✅ Write successful" || echo "      ❌ Write failed"
        done
    else
        echo "  ℹ️  Only one RWX pod currently running"
    fi
    
    echo
}

# Функция для демонстрации ограничений access modes
demonstrate_access_mode_limitations() {
    echo "=== Access Mode Limitations Demo ==="
    
    # Попытка записи в ROX volume
    echo "Testing ROX write limitation:"
    rox_pod=$(kubectl get pods -n $NAMESPACE -l access-mode=rox -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$rox_pod" ]; then
        echo "  Attempting to write to ROX volume from pod $rox_pod..."
        kubectl exec $rox_pod -n $NAMESPACE -- sh -c "echo 'This should fail' > /etc/app/config/test.txt" 2>&1 | grep -q "Read-only" && echo "  ✅ Write correctly blocked (Read-only file system)" || echo "  ⚠️  Write operation result unclear"
    else
        echo "  No ROX pods found for testing"
    fi
    
    echo
}

# Функция для создания сравнительной таблицы
create_access_modes_comparison() {
    echo "=== Access Modes Comparison Table ==="
    
    cat << 'TABLE_EOF'
+------------------+------------------+------------------+------------------+
| Access Mode      | Concurrent Pods  | Read Access      | Write Access     |
+------------------+------------------+------------------+------------------+
| ReadWriteOnce    | Single Node      | ✅ Yes           | ✅ Yes           |
| (RWO)            | Multiple Pods    | (same node)      | (same node)      |
+------------------+------------------+------------------+------------------+
| ReadOnlyMany     | Multiple Nodes   | ✅ Yes           | ❌ No            |
| (ROX)            | Multiple Pods    | (all nodes)      | (read-only)      |
+------------------+------------------+------------------+------------------+
| ReadWriteMany    | Multiple Nodes   | ✅ Yes           | ✅ Yes           |
| (RWX)            | Multiple Pods    | (all nodes)      | (all nodes)      |
+------------------+------------------+------------------+------------------+
| ReadWriteOncePod | Single Pod       | ✅ Yes           | ✅ Yes           |
| (RWOP)           | (exclusive)      | (one pod only)   | (one pod only)   |
+------------------+------------------+------------------+------------------+

Storage Type Compatibility:
+------------------+-------+-------+-------+--------+
| Storage Type     | RWO   | ROX   | RWX   | RWOP   |
+------------------+-------+-------+-------+--------+
| Block Storage    | ✅    | ❌    | ❌    | ✅     |
| (EBS, Disk)      |       |       |       |        |
+------------------+-------+-------+-------+--------+
| File Storage     | ✅    | ✅    | ✅    | ✅     |
| (NFS, CephFS)    |       |       |       |        |
+------------------+-------+-------+-------+--------+
| Object Storage   | ✅    | ✅    | ❌    | ✅     |
| (S3, GCS)        |       |       |       |        |
+------------------+-------+-------+-------+--------+
| hostPath         | ✅    | ✅    | ⚠️*   | ✅     |
| (Local)          |       |       |       |        |
+------------------+-------+-------+-------+--------+

* hostPath RWX only works on single-node clusters
TABLE_EOF
    
    echo
}

# Основная функция
main() {
    case "$2" in
        "pv")
            analyze_pv_access_modes
            ;;
        "pvc")
            analyze_pvc_access_modes
            ;;
        "test")
            test_access_modes
            ;;
        "limits")
            demonstrate_access_mode_limitations
            ;;
        "compare")
            create_access_modes_comparison
            ;;
        "all"|"")
            analyze_pv_access_modes
            analyze_pvc_access_modes
            test_access_modes
            demonstrate_access_mode_limitations
            create_access_modes_comparison
            ;;
        *)
            echo "Usage: $0 [namespace] [analysis_type]"
            echo ""
            echo "Analysis types:"
            echo "  pv       - Analyze PV access modes"
            echo "  pvc      - Analyze PVC access modes"
            echo "  test     - Test access mode behavior"
            echo "  limits   - Demonstrate access mode limitations"
            echo "  compare  - Show comparison table"
            echo "  all      - Run all analyses (default)"
            echo ""
            echo "Examples:"
            echo "  $0 access-modes-demo"
            echo "  $0 access-modes-demo test"
            echo "  $0 access-modes-demo compare"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x analyze-access-modes.sh

# Запустить анализ
./analyze-access-modes.sh access-modes-demo
```

## 🧹 **Очистка ресурсов:**
```bash
# Создать скрипт для очистки демонстрации access modes
cat << 'EOF' > cleanup-access-modes-demo.sh
#!/bin/bash

NAMESPACE="access-modes-demo"

echo "=== Cleaning up Access Modes Demo ==="
echo

# Удалить все deployments и statefulsets
echo "Deleting deployments and statefulsets..."
kubectl delete deployments,statefulsets --all -n $NAMESPACE

# Подождать завершения Pod'ов
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pods --all -n $NAMESPACE --timeout=60s

# Удалить все PVC
echo "Deleting PVCs..."
kubectl delete pvc --all -n $NAMESPACE

# Удалить демонстрационные PV
echo "Deleting demo PVs..."
kubectl delete pv -l storage.hashfoundry.io/demo=access-modes

# Удалить Services
echo "Deleting services..."
kubectl delete services --all -n $NAMESPACE

# Удалить namespace
echo "Deleting namespace..."
kubectl delete namespace $NAMESPACE

# Очистить локальные файлы
echo "Cleaning up local files and directories..."
sudo rm -rf /tmp/hashfoundry-rwo /tmp/hashfoundry-rox /tmp/hashfoundry-rwx
rm -f create-rox-data.sh analyze-access-modes.sh

echo "✓ Access modes demo cleanup completed"

EOF

chmod +x cleanup-access-modes-demo.sh
./cleanup-access-modes-demo.sh
```

## 📋 **Сводка Access Modes:**

### **Основные команды:**
```bash
# Просмотр access modes
kubectl get pv -o custom-columns="NAME:.metadata.name,ACCESS_MODES:.spec.accessModes[*]"
kubectl get pvc -o custom-columns="NAME:.metadata.name,ACCESS_MODES:.spec.accessModes[*]"

# Проверка совместимости
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name>

# Тестирование доступа
kubectl exec <pod-name> -- ls -la /mount/path
kubectl exec <pod-name> -- touch /mount/path/test.txt
```

## 📊 **Сравнительная таблица Access Modes:**

| **Access Mode** | **Сокращение** | **Concurrent Access** | **Use Cases** |
|-----------------|----------------|----------------------|---------------|
| **ReadWriteOnce** | RWO | Один узел | Базы данных, StatefulSets |
| **ReadOnlyMany** | ROX | Множество узлов (чтение) | Конфигурации, статический контент |
| **ReadWriteMany** | RWX | Множество узлов (чтение+запись) | Shared файловые системы |
| **ReadWriteOncePod** | RWOP | Один Pod | Максимальная изоляция |

## 🎯 **Best Practices:**

### **1. Выбор правильного Access Mode:**
- **RWO** для большинства приложений
- **ROX** для shared конфигураций
- **RWX** только когда действительно нужен
- **RWOP** для критичных данных

### **2. Совместимость с хранилищем:**
- **Block storage** поддерживает только RWO/RWOP
- **File storage** поддерживает все режимы
- **Проверяйте документацию** провайдера

### **3. Производительность:**
- **RWO** обеспечивает лучшую производительность
- **RWX** может иметь overhead
- **Тестируйте производительность** в вашей среде

**Access Modes определяют, как ваши приложения могут использовать хранилище в Kubernetes!**
