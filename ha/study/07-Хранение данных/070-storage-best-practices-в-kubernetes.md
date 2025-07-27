# 70. Storage Best Practices в Kubernetes

## 🎯 **Storage Best Practices в Kubernetes**

**Storage Best Practices** - это набор проверенных методов и рекомендаций для эффективного, безопасного и надежного управления хранилищем данных в Kubernetes. Правильное применение этих практик критически важно для production-ready кластеров.

## 🏗️ **Основные принципы:**

### **Категории Best Practices:**
- **Performance Optimization** - оптимизация производительности
- **Security & Access Control** - безопасность и контроль доступа
- **Reliability & Backup** - надежность и резервное копирование
- **Cost Optimization** - оптимизация затрат
- **Monitoring & Observability** - мониторинг и наблюдаемость

### **Ключевые аспекты:**
- **Right-sizing storage** - правильный выбор размера
- **Storage class selection** - выбор подходящего storage class
- **Data lifecycle management** - управление жизненным циклом данных
- **Disaster recovery planning** - планирование восстановления

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание comprehensive storage strategy:**
```bash
# Создать namespace для демонстрации storage best practices
kubectl create namespace storage-best-practices

# Создать labels для организации
kubectl label namespace storage-best-practices \
  demo.type=storage-best-practices \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational \
  storage.policy=production-ready

# Проверить текущее состояние storage в HA кластере
echo "=== Current Storage Infrastructure Analysis ==="
kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,EXPANSION:.allowVolumeExpansion,BINDING:.volumeBindingMode"
kubectl get csidriver -o custom-columns="NAME:.metadata.name,ATTACH:.spec.attachRequired,POD_INFO:.spec.podInfoOnMount,VOLUME_MODES:.spec.volumeLifecycleModes[*]"
kubectl get nodes -o custom-columns="NAME:.metadata.name,STORAGE:.status.allocatable.ephemeral-storage,ZONE:.metadata.labels.topology\.kubernetes\.io/zone"
```

### **2. Создание production-ready StorageClasses:**
```bash
# Создать скрипт для демонстрации storage best practices
cat << 'EOF' > storage-best-practices-demo.sh
#!/bin/bash

NAMESPACE=${1:-"storage-best-practices"}

echo "=== Storage Best Practices Demonstration ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для создания production-ready StorageClasses
create_production_storage_classes() {
    echo "=== Creating Production-Ready StorageClasses ==="
    
    # High-performance storage class для критических workloads
    cat << SC_EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-high-performance
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.tier: high-performance
    storage.policy: production
  annotations:
    storageclass.kubernetes.io/description: "High-performance storage for critical workloads"
    storageclass.kubernetes.io/is-default-class: "false"
    storage.hashfoundry.io/backup-policy: "daily"
    storage.hashfoundry.io/monitoring: "enabled"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Retain  # Безопасная политика для production
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer  # Оптимизация для multi-zone
---
# Standard storage class для обычных workloads
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-standard
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.tier: standard
    storage.policy: production
  annotations:
    storageclass.kubernetes.io/description: "Standard storage for general workloads"
    storageclass.kubernetes.io/is-default-class: "true"
    storage.hashfoundry.io/backup-policy: "weekly"
    storage.hashfoundry.io/monitoring: "enabled"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Archive storage class для долгосрочного хранения
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hashfoundry-archive
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.tier: archive
    storage.policy: cost-optimized
  annotations:
    storageclass.kubernetes.io/description: "Archive storage for long-term data retention"
    storageclass.kubernetes.io/is-default-class: "false"
    storage.hashfoundry.io/backup-policy: "monthly"
    storage.hashfoundry.io/monitoring: "basic"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
SC_EOF
    
    echo "✅ Production-ready StorageClasses created"
    echo
}

# Функция для создания storage policies
create_storage_policies() {
    echo "=== Creating Storage Policies ==="
    
    # ResourceQuota для контроля использования storage
    cat << RQ_EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    policy.type: resource-quota
  annotations:
    policy.hashfoundry.io/description: "Storage resource quota for namespace"
spec:
  hard:
    requests.storage: "100Gi"
    persistentvolumeclaims: "10"
    hashfoundry-high-performance.storageclass.storage.k8s.io/requests.storage: "50Gi"
    hashfoundry-high-performance.storageclass.storage.k8s.io/persistentvolumeclaims: "5"
    hashfoundry-standard.storageclass.storage.k8s.io/requests.storage: "75Gi"
    hashfoundry-standard.storageclass.storage.k8s.io/persistentvolumeclaims: "8"
RQ_EOF
    
    # LimitRange для контроля размеров PVC
    cat << LR_EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-limits
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    policy.type: limit-range
  annotations:
    policy.hashfoundry.io/description: "Storage size limits for PVCs"
spec:
  limits:
  - type: PersistentVolumeClaim
    min:
      storage: "1Gi"
    max:
      storage: "100Gi"
    default:
      storage: "10Gi"
    defaultRequest:
      storage: "5Gi"
LR_EOF
    
    echo "✅ Storage policies created"
    echo
}

# Функция для создания примеров с best practices
create_best_practice_examples() {
    echo "=== Creating Best Practice Examples ==="
    
    # Database с high-performance storage
    cat << DB_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.tier: high-performance
    workload.type: database
    backup.policy: daily
  annotations:
    storage.hashfoundry.io/description: "High-performance storage for production database"
    storage.hashfoundry.io/backup-schedule: "0 2 * * *"
    storage.hashfoundry.io/monitoring: "enabled"
    storage.hashfoundry.io/encryption: "enabled"
spec:
  storageClassName: hashfoundry-high-performance
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: production-database
  namespace: $NAMESPACE
  labels:
    app: production-database
    storage.tier: high-performance
spec:
  serviceName: production-database
  replicas: 1
  selector:
    matchLabels:
      app: production-database
  template:
    metadata:
      labels:
        app: production-database
        storage.tier: high-performance
      annotations:
        storage.hashfoundry.io/best-practices: "applied"
    spec:
      securityContext:
        fsGroup: 999  # PostgreSQL group
        runAsUser: 999
        runAsNonRoot: true
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "production_db"
        - name: POSTGRES_USER
          value: "app_user"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: password
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
        - name: backup-storage
          mountPath: /backup
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - app_user
            - -d
            - production_db
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - app_user
            - -d
            - production_db
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: database-storage
        persistentVolumeClaim:
          claimName: database-pvc
      - name: backup-storage
        emptyDir:
          sizeLimit: 10Gi
---
# Secret для database
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
type: Opaque
data:
  password: cHJvZHVjdGlvbl9wYXNzd29yZF8xMjM=  # production_password_123
DB_EOF
    
    # Application с standard storage
    cat << APP_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: application-pvc
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.tier: standard
    workload.type: application
    backup.policy: weekly
  annotations:
    storage.hashfoundry.io/description: "Standard storage for application data"
    storage.hashfoundry.io/backup-schedule: "0 3 * * 0"
    storage.hashfoundry.io/monitoring: "enabled"
spec:
  storageClassName: hashfoundry-standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application-server
  namespace: $NAMESPACE
  labels:
    app: application-server
    storage.tier: standard
spec:
  replicas: 2
  selector:
    matchLabels:
      app: application-server
  template:
    metadata:
      labels:
        app: application-server
        storage.tier: standard
      annotations:
        storage.hashfoundry.io/best-practices: "applied"
    spec:
      securityContext:
        fsGroup: 1000
        runAsUser: 1000
        runAsNonRoot: true
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-data
          mountPath: /usr/share/nginx/html
        - name: app-config
          mountPath: /etc/nginx/conf.d
        - name: app-logs
          mountPath: /var/log/nginx
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: app-data
        persistentVolumeClaim:
          claimName: application-pvc
      - name: app-config
        configMap:
          name: nginx-config
      - name: app-logs
        emptyDir:
          sizeLimit: 1Gi
---
# ConfigMap для nginx
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        location /ready {
            access_log off;
            return 200 "ready\n";
            add_header Content-Type text/plain;
        }
    }
APP_EOF
    
    # Archive storage для логов
    cat << ARCHIVE_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: archive-logs-pvc
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.tier: archive
    workload.type: logging
    backup.policy: monthly
  annotations:
    storage.hashfoundry.io/description: "Archive storage for long-term log retention"
    storage.hashfoundry.io/backup-schedule: "0 4 1 * *"
    storage.hashfoundry.io/retention-period: "1year"
spec:
  storageClassName: hashfoundry-archive
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: log-archiver
  namespace: $NAMESPACE
  labels:
    app: log-archiver
    storage.tier: archive
spec:
  schedule: "0 1 * * *"  # Ежедневно в 1:00
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: log-archiver
            storage.tier: archive
          annotations:
            storage.hashfoundry.io/best-practices: "applied"
        spec:
          securityContext:
            fsGroup: 1000
            runAsUser: 1000
            runAsNonRoot: true
          containers:
          - name: archiver
            image: busybox:1.35
            command: ["sh", "-c"]
            args:
            - |
              echo "Starting log archival process..."
              
              # Создать структуру архива
              mkdir -p /archive/$(date +%Y)/$(date +%m)/$(date +%d)
              
              # Симуляция архивирования логов
              echo "Archiving logs for $(date -d 'yesterday' +%Y-%m-%d)..."
              
              # Создать архивный файл
              cat > /archive/$(date +%Y)/$(date +%m)/$(date +%d)/archive_$(date +%Y%m%d).log << 'LOG_EOF'
              Archive Log Entry
              =================
              
              Date: $(date -Iseconds)
              Archive Type: Daily Log Archive
              Source: Application and System Logs
              Retention Policy: 1 Year
              
              Best Practices Applied:
              - Automated archival process
              - Structured directory layout
              - Retention policy enforcement
              - Monitoring and alerting
              - Secure storage configuration
              
              Archive Statistics:
              - Files Processed: 1000
              - Total Size: 500MB
              - Compression Ratio: 75%
              - Archive Duration: 5 minutes
              
              Next Archive: $(date -d 'tomorrow' +%Y-%m-%d)
              LOG_EOF
              
              echo "Archive completed successfully!"
              
              # Показать статистику архива
              echo "Archive statistics:"
              du -sh /archive/*
              find /archive -type f | wc -l
            volumeMounts:
            - name: archive-storage
              mountPath: /archive
            resources:
              requests:
                memory: "128Mi"
                cpu: "100m"
              limits:
                memory: "256Mi"
                cpu: "200m"
          volumes:
          - name: archive-storage
            persistentVolumeClaim:
              claimName: archive-logs-pvc
          restartPolicy: OnFailure
ARCHIVE_EOF
    
    echo "✅ Best practice examples created"
    echo
}

# Функция для создания monitoring и backup solutions
create_monitoring_backup() {
    echo "=== Creating Monitoring and Backup Solutions ==="
    
    # Storage monitoring ConfigMap
    cat << MONITOR_EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-monitoring-config
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    component: monitoring
data:
  storage-alerts.yaml: |
    groups:
    - name: storage.rules
      rules:
      - alert: PVCUsageHigh
        expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PVC usage is high"
          description: "PVC {{ \$labels.persistentvolumeclaim }} usage is above 80%"
      
      - alert: PVCUsageCritical
        expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.9
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "PVC usage is critical"
          description: "PVC {{ \$labels.persistentvolumeclaim }} usage is above 90%"
      
      - alert: PVCMountFailed
        expr: increase(storage_operation_duration_seconds_count{operation_name="volume_mount",status="fail-unknown"}[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PVC mount failed"
          description: "PVC mount operations are failing"
  
  backup-policy.yaml: |
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: backup-policies
    data:
      daily-backup.sh: |
        #!/bin/bash
        # Daily backup script for high-performance storage
        BACKUP_DATE=$(date +%Y%m%d)
        kubectl exec -n $NAMESPACE deployment/production-database -- pg_dump -U app_user production_db > /backup/db_backup_\$BACKUP_DATE.sql
      
      weekly-backup.sh: |
        #!/bin/bash
        # Weekly backup script for standard storage
        BACKUP_DATE=$(date +%Y%m%d)
        tar -czf /backup/app_backup_\$BACKUP_DATE.tar.gz /usr/share/nginx/html
      
      monthly-archive.sh: |
        #!/bin/bash
        # Monthly archive script
        ARCHIVE_DATE=$(date +%Y%m)
        find /archive -name "*.log" -mtime +30 -exec gzip {} \;
MONITOR_EOF
    
    # Storage health check DaemonSet
    cat << HEALTH_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: storage-health-checker
  namespace: $NAMESPACE
  labels:
    app: storage-health-checker
    component: monitoring
spec:
  selector:
    matchLabels:
      app: storage-health-checker
  template:
    metadata:
      labels:
        app: storage-health-checker
        component: monitoring
      annotations:
        storage.hashfoundry.io/best-practices: "applied"
    spec:
      securityContext:
        runAsUser: 0  # Нужны root права для проверки storage
      containers:
      - name: health-checker
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting storage health checker..."
          
          while true; do
            echo "=== Storage Health Check - $(date) ==="
            
            # Проверить доступность storage
            echo "Checking storage accessibility..."
            
            # Проверить mount points
            echo "Mount points:"
            df -h | grep -E "(pvc|volume)"
            
            # Проверить I/O performance
            echo "I/O Performance test:"
            time dd if=/dev/zero of=/tmp/test_file bs=1M count=10 2>&1
            rm -f /tmp/test_file
            
            # Проверить storage usage
            echo "Storage usage:"
            du -sh /var/lib/kubelet/pods/*/volumes/kubernetes.io~csi/* 2>/dev/null | head -10
            
            echo "Health check completed"
            echo "========================"
            
            sleep 300  # Проверка каждые 5 минут
          done
        volumeMounts:
        - name: kubelet-pods
          mountPath: /var/lib/kubelet/pods
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: kubelet-pods
        hostPath:
          path: /var/lib/kubelet/pods
          type: Directory
      tolerations:
      - operator: Exists
HEALTH_EOF
    
    echo "✅ Monitoring and backup solutions created"
    echo
}

# Функция для создания security best practices
create_security_practices() {
    echo "=== Creating Security Best Practices ==="
    
    # NetworkPolicy для storage access
    cat << NP_EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: storage-access-policy
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    policy.type: network
spec:
  podSelector:
    matchLabels:
      storage.tier: high-performance
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: application-server
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53  # DNS
    - protocol: UDP
      port: 53  # DNS
NP_EOF
    
    # PodSecurityPolicy для storage workloads
    cat << PSP_EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: storage-workload-psp
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    policy.type: security
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'persistentVolumeClaim'
    - 'emptyDir'
    - 'configMap'
    - 'secret'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
PSP_EOF
    
    echo "✅ Security best practices created"
    echo
}

# Функция для создания performance optimization examples
create_performance_optimization() {
    echo "=== Creating Performance Optimization Examples ==="
    
    # Performance-optimized StatefulSet
    cat << PERF_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: high-performance-app
  namespace: $NAMESPACE
  labels:
    app: high-performance-app
    storage.tier: high-performance
    performance.optimized: "true"
spec:
  serviceName: high-performance-app
  replicas: 3
  selector:
    matchLabels:
      app: high-performance-app
  template:
    metadata:
      labels:
        app: high-performance-app
        storage.tier: high-performance
        performance.optimized: "true"
      annotations:
        storage.hashfoundry.io/best-practices: "applied"
        storage.hashfoundry.io/performance-tier: "high"
    spec:
      securityContext:
        fsGroup: 1000
        runAsUser: 1000
        runAsNonRoot: true
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - high-performance-app
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: redis:6.2
        ports:
        - containerPort: 6379
        command: ["redis-server"]
        args:
        - "--appendonly"
        - "yes"
        - "--appendfsync"
        - "everysec"
        - "--save"
        - "900 1"
        - "--save"
        - "300 10"
        - "--save"
        - "60 10000"
        volumeMounts:
        - name: data-storage
          mountPath: /data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: data-storage
      labels:
        app.kubernetes.io/name: hashfoundry-storage
        storage.tier: high-performance
        performance.optimized: "true"
      annotations:
        storage.hashfoundry.io/description: "High-performance storage for Redis"
        storage.hashfoundry.io/backup-policy: "daily"
        storage.hashfoundry.io/monitoring: "enabled"
    spec:
      storageClassName: hashfoundry-high-performance
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
PERF_EOF
    
    echo "✅ Performance optimization examples created"
    echo
}

# Функция для создания cost optimization strategies
create_cost_optimization() {
    echo "=== Creating Cost Optimization Strategies ==="
    
    # Cost-optimized storage example
    cat << COST_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cost-optimized-pvc
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: hashfoundry-storage
    storage.tier: standard
    cost.optimized: "true"
  annotations:
    storage.hashfoundry.io/description: "Cost-optimized storage with right-sizing"
    storage.hashfoundry.io/cost-optimization: "enabled"
    storage.hashfoundry.io/auto-resize: "enabled"
spec:
  storageClassName: hashfoundry-standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi  # Start small, expand as needed
---
# Cost monitoring CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: storage-cost-analyzer
  namespace: $NAMESPACE
  labels:
    app: storage-cost-analyzer
    component: cost-optimization
spec:
  schedule: "0 6 * * *"  # Daily at 6 AM
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: storage-cost-analyzer
            component: cost-optimization
        spec:
          securityContext:
            fsGroup: 1000
            runAsUser: 1000
            runAsNonRoot: true
          containers:
          - name: cost-analyzer
            image: busybox:1.35
            command: ["sh", "-c"]
            args:
            - |
              echo "=== Storage Cost Analysis - $(date) ==="
              
              # Анализ использования storage
              echo "Storage Usage Analysis:"
              echo "======================"
              
              # Симуляция анализа затрат
              cat << 'ANALYSIS_EOF'
              Storage Cost Optimization Report
              ===============================
              
              Date: $(date -Iseconds)
              Namespace: $NAMESPACE
              
              Current Storage Usage:
              - High-Performance: 80Gi (Cost: $40/month)
              - Standard: 150Gi (Cost: $15/month)
              - Archive: 500Gi (Cost: $10/month)
              
              Optimization Recommendations:
              1. Move infrequently accessed data to archive tier
              2. Enable automatic PVC resizing based on usage
              3. Implement data lifecycle policies
              4. Consider compression for archive data
              
              Potential Savings: $15/month (23% reduction)
              
              Next Review: $(date -d '+1 week' +%Y-%m-%d)
              ANALYSIS_EOF
              
              echo "Cost analysis completed!"
            volumeMounts:
            - name: cost-data
              mountPath: /cost-analysis
            resources:
              requests:
                memory: "128Mi"
                cpu: "100m"
              limits:
                memory: "256Mi"
                cpu: "200m"
          volumes:
          - name: cost-data
            persistentVolumeClaim:
              claimName: cost-optimized-pvc
          restartPolicy: OnFailure
COST_EOF
    
    echo "✅ Cost optimization strategies created"
    echo
}

# Основная функция для демонстрации всех best practices
demonstrate_all_best_practices() {
    echo "=== Full Storage Best Practices Demonstration ==="
    
    create_production_storage_classes
    create_storage_policies
    create_best_practice_examples
    create_monitoring_backup
    create_security_practices
    create_performance_optimization
    create_cost_optimization
    
    echo "=== Best Practices Summary ==="
    echo "✅ Production-ready StorageClasses created"
    echo "✅ Storage policies and quotas implemented"
    echo "✅ Best practice examples deployed"
    echo "✅ Monitoring and backup solutions configured"
    echo "✅ Security practices applied"
    echo "✅ Performance optimization implemented"
    echo "✅ Cost optimization strategies deployed"
    echo
    
    echo "=== Current State ==="
    kubectl get storageclass -l app.kubernetes.io/name=hashfoundry-storage
    kubectl get pvc,pods -n $NAMESPACE
    kubectl get resourcequota,limitrange -n $NAMESPACE
}

# Основная функция
main() {
    case "$2" in
        "storage-classes")
            create_production_storage_classes
            ;;
        "policies")
            create_storage_policies
            ;;
        "examples")
            create_best_practice_examples
            ;;
        "monitoring")
            create_monitoring_backup
            ;;
        "security")
            create_security_practices
            ;;
        "performance")
            create_performance_optimization
            ;;
        "cost")
            create_cost_optimization
            ;;
        "demo"|"all"|"")
            demonstrate_all_best_practices
            ;;
        *)
            echo "Usage: $0 [namespace] [action]"
            echo ""
            echo "Actions:"
            echo "  storage-classes  - Create production-ready StorageClasses"
            echo "  policies         - Create storage policies and quotas"
            echo "  examples         - Create best practice examples"
            echo "  monitoring       - Create monitoring and backup solutions"
            echo "  security         - Create security best practices"
            echo "  performance      - Create performance optimization examples"
            echo "  cost             - Create cost optimization strategies"
            echo "  demo             - Full demonstration (default)"
            echo ""
            echo "Examples:"
            echo "  $0 storage-best-practices"
            echo "  $0 storage-best-practices storage-classes"
            echo "  $0 storage-best-practices monitoring"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x storage-best-practices-demo.sh

# Запустить демонстрацию
./storage-best-practices-demo.sh storage-best-practices demo
```

## 📋 **Сводка Storage Best Practices:**

### **1. StorageClass Best Practices:**
```bash
# Production-ready StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: production-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: do-block-storage
  fs-type: ext4
reclaimPolicy: Retain  # Безопасная политика
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer  # Multi-zone optimization
```

### **2. Security Best Practices:**
```bash
# Правильный securityContext
spec:
  securityContext:
    fsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

### **3. Performance Best Practices:**
```bash
# Оптимизация производительности
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: high-performance-app
          topologyKey: kubernetes.io/hostname
```

### **4. Monitoring Best Practices:**
```bash
# Мониторинг storage usage
kubectl top pods --containers
kubectl get pvc -o custom-columns="NAME:.metadata.name,CAPACITY:.status.capacity.storage,USED:.status.phase"

# Проверка storage health
kubectl exec <pod-name> -- df -h
kubectl describe pvc <pvc-name>
```

## 🎯 **Ключевые принципы:**

### **Performance:**
- **Right-sizing** - правильный выбор размера storage
- **Storage tiers** - использование разных уровней производительности
- **Volume binding mode** - оптимизация для multi-zone
- **Anti-affinity** - распределение по узлам

### **Security:**
- **Non-root containers** - запуск без root прав
- **fsGroup** - правильные права доступа к файлам
- **Network policies** - ограничение сетевого доступа
- **Encryption** - шифрование данных

### **Reliability:**
- **Retain policy** - сохранение данных при удалении PVC
- **Regular backups** - регулярное резервное копирование
- **Health checks** - мониторинг состояния storage
- **Disaster recovery** - планы восстановления

### **Cost Optimization:**
- **Storage tiers** - использование подходящих уровней storage
- **Lifecycle policies** - автоматическое управление данными
- **Right-sizing** - избежание over-provisioning
- **Monitoring usage** - отслеживание использования

## 📊 **Практические команды:**

### **Мониторинг:**
```bash
# Проверка использования storage
kubectl get pvc --all-namespaces
kubectl top pods --containers --all-namespaces

# Анализ storage classes
kubectl get storageclass -o wide
kubectl describe storageclass <class-name>

# Проверка CSI drivers
kubectl get csidriver
kubectl get pods -n kube-system | grep csi
```

### **Troubleshooting:**
```bash
# Диагностика проблем
kubectl describe pvc <pvc-name>
kubectl get events --sort-by='.lastTimestamp'
kubectl logs <csi-driver-pod> -n kube-system

# Проверка mount points
kubectl exec <pod-name> -- df -h
kubectl exec <pod-name> -- ls -la /mount/path
```

## 🔧 **Cleanup ресурсов:**
```bash
# Создать скрипт для очистки
cat << 'EOF' > cleanup-storage-best-practices.sh
#!/bin/bash

NAMESPACE="storage-best-practices"

echo "=== Cleaning up Storage Best Practices Demo ==="

# Удалить все ресурсы в namespace
kubectl delete all --all -n $NAMESPACE
kubectl delete pvc --all -n $NAMESPACE
kubectl delete configmap --all -n $NAMESPACE
kubectl delete secret --all -n $NAMESPACE

# Удалить policies
kubectl delete resourcequota,limitrange --all -n $NAMESPACE
kubectl delete networkpolicy --all -n $NAMESPACE

# Удалить кастомные StorageClasses
kubectl delete storageclass -l app.kubernetes.io/name=hashfoundry-storage

# Удалить namespace
kubectl delete namespace $NAMESPACE

# Очистить локальные файлы
rm -f storage-best-practices-demo.sh

echo "✅ Cleanup completed"

EOF

chmod +x cleanup-storage-best-practices.sh
```

**Storage Best Practices обеспечивают надежную, безопасную и эффективную работу с данными в Kubernetes!**

## 🎯 **Заключение по Storage в Kubernetes:**

Мы рассмотрели **22 ключевых аспекта** работы с storage в Kubernetes:

1. **Основы** - PV, PVC, StorageClass
2. **Типы volumes** - различные варианты хранения
3. **Dynamic provisioning** - автоматическое создание storage
4. **Access modes** - режимы доступа к данным
5. **Reclaim policies** - политики освобождения ресурсов
6. **Volume expansion** - расширение размера storage
7. **Snapshots** - создание point-in-time копий
8. **Troubleshooting** - диагностика и решение проблем
9. **Best practices** - проверенные методы работы

**Эти знания критически важны для создания production-ready Kubernetes кластеров!**
