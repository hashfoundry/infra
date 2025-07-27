# 88. Disaster Recovery для Kubernetes

## 🎯 **Disaster Recovery для Kubernetes**

**Disaster Recovery (DR)** - это комплекс мер и процедур для восстановления работоспособности Kubernetes кластера и приложений после катастрофических сбоев, включая резервное копирование, репликацию данных, планирование восстановления и тестирование процедур.

## 🏗️ **Компоненты DR:**

### **1. Backup Components:**
- **etcd snapshots** - резервные копии состояния кластера
- **Application data** - данные приложений
- **Configuration** - конфигурации и манифесты
- **Persistent volumes** - постоянные тома

### **2. Recovery Strategies:**
- **RTO (Recovery Time Objective)** - время восстановления
- **RPO (Recovery Point Objective)** - точка восстановления
- **Multi-region deployment** - мультирегиональное развертывание
- **Cross-cluster replication** - репликация между кластерами

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущего состояния DR:**
```bash
# Проверить backup-related ресурсы
kubectl get volumesnapshots --all-namespaces
kubectl get backups --all-namespaces 2>/dev/null || echo "No backup CRDs found"
```

### **2. Создание comprehensive disaster recovery framework:**
```bash
# Создать скрипт для disaster recovery
cat << 'EOF' > disaster-recovery-implementation.sh
#!/bin/bash

echo "=== Kubernetes Disaster Recovery Implementation ==="
echo "Implementing comprehensive disaster recovery for HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния DR
analyze_current_dr_state() {
    echo "=== Current Disaster Recovery State Analysis ==="
    
    echo "1. Cluster Backup Status:"
    echo "========================"
    
    # Проверить etcd pods
    echo "etcd pods status:"
    kubectl get pods -n kube-system -l component=etcd -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName"
    echo
    
    # Проверить backup-related resources
    echo "Backup-related resources:"
    kubectl get volumesnapshots --all-namespaces 2>/dev/null || echo "No volume snapshots found"
    kubectl get backups --all-namespaces 2>/dev/null || echo "No backup CRDs found"
    echo
    
    echo "2. Persistent Storage Analysis:"
    echo "=============================="
    kubectl get pv,pvc --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,STORAGE:.spec.resources.requests.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "3. Critical Applications:"
    echo "========================"
    for namespace in kube-system monitoring nginx-ingress; do
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            echo "Namespace: $namespace"
            kubectl get pods -n "$namespace" -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount"
        fi
    done
    echo
}

# Функция для создания etcd backup
create_etcd_backup() {
    echo "=== Creating etcd Backup System ==="
    
    # Создать namespace для backup
    cat << BACKUP_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: backup-system
  labels:
    app.kubernetes.io/name: "backup-system"
    hashfoundry.io/component: "disaster-recovery"
  annotations:
    hashfoundry.io/description: "Namespace for backup and disaster recovery tools"
BACKUP_NS_EOF
    
    # Создать etcd backup job
    cat << ETCD_BACKUP_JOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: backup-system
  labels:
    app.kubernetes.io/name: "etcd-backup"
    app.kubernetes.io/component: "backup"
    hashfoundry.io/backup-type: "etcd"
  annotations:
    hashfoundry.io/description: "Automated etcd backup job"
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app.kubernetes.io/name: "etcd-backup"
            app.kubernetes.io/component: "backup"
        spec:
          serviceAccountName: etcd-backup
          restartPolicy: OnFailure
          hostNetwork: true
          containers:
          - name: etcd-backup
            image: quay.io/coreos/etcd:v3.5.9
            command:
            - /bin/sh
            - -c
            - |
              set -e
              BACKUP_DIR="/backup/etcd-\$(date +%Y%m%d-%H%M%S)"
              mkdir -p "\$BACKUP_DIR"
              
              echo "Creating etcd snapshot..."
              etcdctl snapshot save "\$BACKUP_DIR/etcd-snapshot.db" \\
                --endpoints=https://127.0.0.1:2379 \\
                --cacert=/etc/kubernetes/pki/etcd/ca.crt \\
                --cert=/etc/kubernetes/pki/etcd/server.crt \\
                --key=/etc/kubernetes/pki/etcd/server.key
              
              echo "Verifying snapshot..."
              etcdctl snapshot status "\$BACKUP_DIR/etcd-snapshot.db" -w table
              
              echo "Creating cluster info backup..."
              kubectl cluster-info dump --output-directory="\$BACKUP_DIR/cluster-dump" || true
              
              echo "Backup completed: \$BACKUP_DIR"
              
              # Cleanup old backups (keep last 7 days)
              find /backup -name "etcd-*" -type d -mtime +7 -exec rm -rf {} + || true
            env:
            - name: ETCDCTL_API
              value: "3"
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
              readOnly: true
            - name: backup-storage
              mountPath: /backup
            resources:
              requests:
                cpu: "100m"
                memory: "128Mi"
              limits:
                cpu: "500m"
                memory: "512Mi"
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
              type: Directory
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-storage-pvc
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: etcd-backup
  namespace: backup-system
  labels:
    app.kubernetes.io/name: "etcd-backup"
  annotations:
    hashfoundry.io/description: "ServiceAccount for etcd backup"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: etcd-backup
  labels:
    app.kubernetes.io/name: "etcd-backup"
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list"]
- apiGroups: ["apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: etcd-backup
  labels:
    app.kubernetes.io/name: "etcd-backup"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: etcd-backup
subjects:
- kind: ServiceAccount
  name: etcd-backup
  namespace: backup-system
ETCD_BACKUP_JOB_EOF
    
    # Создать PVC для backup storage
    cat << BACKUP_PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-storage-pvc
  namespace: backup-system
  labels:
    app.kubernetes.io/name: "backup-storage"
    hashfoundry.io/component: "disaster-recovery"
  annotations:
    hashfoundry.io/description: "Storage for backup data"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: do-block-storage
BACKUP_PVC_EOF
    
    echo "✅ etcd backup system created"
    echo
}

# Функция для создания Velero backup
create_velero_backup() {
    echo "=== Creating Velero Backup System ==="
    
    # Создать Velero namespace
    cat << VELERO_NS_EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: velero
  labels:
    app.kubernetes.io/name: "velero"
    hashfoundry.io/component: "disaster-recovery"
  annotations:
    hashfoundry.io/description: "Velero backup and restore system"
VELERO_NS_EOF
    
    # Создать Velero deployment
    cat << VELERO_DEPLOYMENT_EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: velero
  namespace: velero
  labels:
    app.kubernetes.io/name: "velero"
    app.kubernetes.io/component: "backup"
    hashfoundry.io/backup-type: "application"
  annotations:
    hashfoundry.io/description: "Velero backup and restore deployment"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: "velero"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "velero"
        app.kubernetes.io/component: "backup"
    spec:
      serviceAccountName: velero
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: velero
        image: velero/velero:v1.11.1
        command:
        - /velero
        args:
        - server
        - --log-level=info
        - --log-format=text
        - --features=
        - --default-volume-snapshot-locations=default:default
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        env:
        - name: VELERO_SCRATCH_DIR
          value: /scratch
        - name: VELERO_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: LD_LIBRARY_PATH
          value: /plugins
        volumeMounts:
        - name: plugins
          mountPath: /plugins
        - name: scratch
          mountPath: /scratch
        - name: cloud-credentials
          mountPath: /credentials
          readOnly: true
        livenessProbe:
          httpGet:
            path: /metrics
            port: 8085
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /metrics
            port: 8085
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: plugins
        emptyDir: {}
      - name: scratch
        emptyDir: {}
      - name: cloud-credentials
        secret:
          secretName: cloud-credentials
          optional: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: velero
  namespace: velero
  labels:
    app.kubernetes.io/name: "velero"
  annotations:
    hashfoundry.io/description: "ServiceAccount for Velero"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: velero
  labels:
    app.kubernetes.io/name: "velero"
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: velero
  labels:
    app.kubernetes.io/name: "velero"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: velero
subjects:
- kind: ServiceAccount
  name: velero
  namespace: velero
VELERO_DEPLOYMENT_EOF
    
    echo "✅ Velero backup system created"
    echo
}

# Функция для создания backup schedules
create_backup_schedules() {
    echo "=== Creating Backup Schedules ==="
    
    # Daily full backup
    cat << DAILY_BACKUP_EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
  labels:
    app.kubernetes.io/name: "velero-schedule"
    hashfoundry.io/backup-frequency: "daily"
  annotations:
    hashfoundry.io/description: "Daily full cluster backup"
spec:
  schedule: "0 1 * * *"  # Daily at 1 AM
  template:
    metadata:
      labels:
        hashfoundry.io/backup-type: "full"
    includedNamespaces:
    - "*"
    excludedNamespaces:
    - kube-system
    - kube-public
    - kube-node-lease
    includedResources:
    - "*"
    excludedResources:
    - events
    - events.events.k8s.io
    snapshotVolumes: true
    ttl: 720h  # 30 days
    storageLocation: default
    volumeSnapshotLocations:
    - default
DAILY_BACKUP_EOF
    
    # Weekly backup with longer retention
    cat << WEEKLY_BACKUP_EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-backup
  namespace: velero
  labels:
    app.kubernetes.io/name: "velero-schedule"
    hashfoundry.io/backup-frequency: "weekly"
  annotations:
    hashfoundry.io/description: "Weekly full cluster backup with long retention"
spec:
  schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
  template:
    metadata:
      labels:
        hashfoundry.io/backup-type: "weekly"
    includedNamespaces:
    - "*"
    excludedNamespaces:
    - kube-system
    - kube-public
    - kube-node-lease
    includedResources:
    - "*"
    excludedResources:
    - events
    - events.events.k8s.io
    snapshotVolumes: true
    ttl: 2160h  # 90 days
    storageLocation: default
    volumeSnapshotLocations:
    - default
WEEKLY_BACKUP_EOF
    
    # Critical applications backup
    cat << CRITICAL_BACKUP_EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: critical-apps-backup
  namespace: velero
  labels:
    app.kubernetes.io/name: "velero-schedule"
    hashfoundry.io/backup-frequency: "frequent"
  annotations:
    hashfoundry.io/description: "Frequent backup of critical applications"
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  template:
    metadata:
      labels:
        hashfoundry.io/backup-type: "critical"
    includedNamespaces:
    - hashfoundry-prod
    - monitoring
    - nginx-ingress
    includedResources:
    - "*"
    excludedResources:
    - events
    - events.events.k8s.io
    snapshotVolumes: true
    ttl: 168h  # 7 days
    storageLocation: default
    volumeSnapshotLocations:
    - default
CRITICAL_BACKUP_EOF
    
    echo "✅ Backup schedules created"
    echo
}

# Функция для создания disaster recovery procedures
create_dr_procedures() {
    echo "=== Creating Disaster Recovery Procedures ==="
    
    cat << DR_PROCEDURES_EOF > disaster-recovery-procedures.md
# HashFoundry Disaster Recovery Procedures

## Overview
This document outlines the disaster recovery procedures for the HashFoundry HA Kubernetes cluster.

## Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO)

| **Component** | **RTO** | **RPO** | **Priority** |
|---------------|---------|---------|--------------|
| Control Plane | 30 minutes | 1 hour | Critical |
| Critical Apps | 15 minutes | 6 hours | High |
| Monitoring | 1 hour | 24 hours | Medium |
| Development | 4 hours | 24 hours | Low |

## Disaster Scenarios

### Scenario 1: Single Node Failure
**Impact**: Minimal (HA cluster)
**Recovery**: Automatic (Kubernetes self-healing)
**Actions**:
1. Monitor cluster health
2. Replace failed node if necessary
3. Verify workload redistribution

### Scenario 2: Control Plane Failure
**Impact**: High (API unavailable)
**Recovery**: 30 minutes
**Actions**:
1. Assess extent of control plane damage
2. Restore from etcd backup if needed
3. Rebuild control plane nodes
4. Verify cluster functionality

### Scenario 3: Complete Cluster Loss
**Impact**: Critical (Total outage)
**Recovery**: 2-4 hours
**Actions**:
1. Provision new cluster infrastructure
2. Restore etcd from latest backup
3. Restore applications from Velero backups
4. Verify all services are operational

### Scenario 4: Data Center Outage
**Impact**: Critical (Regional failure)
**Recovery**: 1-2 hours
**Actions**:
1. Activate secondary region cluster
2. Restore latest backups to secondary cluster
3. Update DNS to point to secondary cluster
4. Verify application functionality

## Recovery Procedures

### etcd Recovery
\`\`\`bash
# Stop kube-apiserver
sudo systemctl stop kubelet

# Restore etcd snapshot
sudo etcdctl snapshot restore /backup/etcd-snapshot.db \\
  --data-dir=/var/lib/etcd-restore \\
  --name=\$(hostname) \\
  --initial-cluster=\$(hostname)=https://\$(hostname):2380 \\
  --initial-advertise-peer-urls=https://\$(hostname):2380

# Update etcd configuration
sudo mv /var/lib/etcd /var/lib/etcd.old
sudo mv /var/lib/etcd-restore /var/lib/etcd

# Restart kubelet
sudo systemctl start kubelet

# Verify cluster health
kubectl get nodes
kubectl get pods --all-namespaces
\`\`\`

### Application Recovery with Velero
\`\`\`bash
# List available backups
velero backup get

# Restore from specific backup
velero restore create --from-backup daily-backup-20240125-010000

# Monitor restore progress
velero restore describe <restore-name>

# Verify restored resources
kubectl get all --all-namespaces
\`\`\`

### Volume Recovery
\`\`\`bash
# List volume snapshots
kubectl get volumesnapshots --all-namespaces

# Create PVC from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: snapshot-name
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF
\`\`\`

## Testing Procedures

### Monthly DR Test
1. Create test backup
2. Simulate failure scenario
3. Execute recovery procedures
4. Validate recovery success
5. Document lessons learned

### Quarterly Full DR Test
1. Complete cluster rebuild
2. Full application restore
3. End-to-end functionality testing
4. Performance validation
5. Update procedures based on findings

## Emergency Contacts

| **Role** | **Contact** | **Escalation** |
|----------|-------------|----------------|
| Primary On-Call | +1-xxx-xxx-xxxx | 15 minutes |
| Secondary On-Call | +1-xxx-xxx-xxxx | 30 minutes |
| Infrastructure Lead | +1-xxx-xxx-xxxx | 1 hour |
| Management | +1-xxx-xxx-xxxx | 2 hours |

## Communication Plan

### Internal Communication
1. Incident declared in #incidents Slack channel
2. Status updates every 30 minutes
3. Post-incident review within 24 hours

### External Communication
1. Status page updates for customer-facing issues
2. Customer notifications for extended outages
3. Stakeholder briefings for major incidents

## Post-Recovery Checklist

- [ ] All services operational
- [ ] Data integrity verified
- [ ] Performance within normal ranges
- [ ] Monitoring systems functional
- [ ] Backup systems operational
- [ ] Security posture maintained
- [ ] Documentation updated
- [ ] Lessons learned documented
- [ ] Process improvements identified

DR_PROCEDURES_EOF
    
    echo "✅ Disaster recovery procedures documented: disaster-recovery-procedures.md"
    echo
}

# Функция для создания DR monitoring
create_dr_monitoring() {
    echo "=== Creating Disaster Recovery Monitoring ==="
    
    cat << DR_MONITORING_EOF > disaster-recovery-monitor.sh
#!/bin/bash

echo "=== Disaster Recovery Monitoring ==="
echo "Monitoring backup and DR readiness for HashFoundry HA cluster"
echo

# Функция для проверки backup health
check_backup_health() {
    echo "1. Backup System Health:"
    echo "======================="
    
    # Check etcd backup job
    echo "etcd Backup Job Status:"
    kubectl get cronjob -n backup-system etcd-backup -o custom-columns="NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST-SCHEDULE:.status.lastScheduleTime,ACTIVE:.status.active"
    echo
    
    # Check Velero status
    echo "Velero Status:"
    kubectl get pods -n velero -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status"
    echo
    
    # Check backup schedules
    echo "Backup Schedules:"
    kubectl get schedules -n velero -o custom-columns="NAME:.metadata.name,SCHEDULE:.spec.schedule,LAST-BACKUP:.status.lastBackup.name"
    echo
}

# Функция для проверки recent backups
check_recent_backups() {
    echo "2. Recent Backups:"
    echo "=================="
    
    # Check Velero backups
    echo "Velero Backups (Last 7 days):"
    kubectl get backups -n velero --sort-by=.metadata.creationTimestamp | tail -10
    echo
    
    # Check backup storage usage
    echo "Backup Storage Usage:"
    kubectl get pvc -n backup-system backup-storage-pvc -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,USED:.status.allocatedResources.storage"
    echo
}

# Функция для проверки DR readiness
check_dr_readiness() {
    echo "3. DR Readiness Assessment:"
    echo "=========================="
    
    # Check critical components
    echo "Critical Components Status:"
    for namespace in kube-system monitoring nginx-ingress hashfoundry-prod; do
        if kubectl get namespace "\$namespace" >/dev/null 2>&1; then
            READY=\$(kubectl get pods -n "\$namespace" --no-headers | grep -c "Running" || echo "0")
            TOTAL=\$(kubectl get pods -n "\$namespace" --no-headers | wc -l)
            echo "- \$namespace: \$READY/\$TOTAL pods ready"
        fi
    done
    echo
    
    # Check persistent volumes
    echo "Persistent Volumes Status:"
    kubectl get pv -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name,STORAGECLASS:.spec.storageClassName" | grep -v Available
    echo
}

# Функция для проверки backup integrity
check_backup_integrity() {
    echo "4. Backup Integrity Check:"
    echo "========================="
    
    # Check latest etcd backup
    echo "Latest etcd Backup Verification:"
    kubectl logs -n backup-system -l app.kubernetes.io/name=etcd-backup --tail=50 | grep -E "(snapshot|backup|error)" | tail -10
    echo
    
    # Check Velero backup validation
    echo "Velero Backup Validation:"
    kubectl get backups -n velero -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,ERRORS:.status.errors,WARNINGS:.status.warnings" | head -10
    echo
}

# Функция для проверки recovery capabilities
check_recovery_capabilities() {
    echo "5. Recovery Capabilities:"
    echo "========================"
    
    # Check if restore tools are available
    echo "Recovery Tools Status:"
    if kubectl get pods -n velero -l app.kubernetes.io/name=velero | grep -q Running; then
        echo "✅ Velero restore capability: Available"
    else
        echo "❌ Velero restore capability: Not available"
    fi
    
    if kubectl get cronjob -n backup-system etcd-backup >/dev/null 2>&1; then
        echo "✅ etcd backup system: Available"
    else
        echo "❌ etcd backup system: Not available"
    fi
    echo
    
    # Check storage snapshots capability
    echo "Volume Snapshot Capability:"
    kubectl get volumesnapshotclasses 2>/dev/null | head -5 || echo "No volume snapshot classes found"
    echo
}

# Функция для генерации DR report
generate_dr_report() {
    echo "6. Disaster Recovery Report:"
    echo "==========================="
    
    echo "✅ BACKUP STATUS:"
    echo "- etcd Backups: \$(kubectl get cronjob -n backup-system --no-headers | wc -l)"
    echo "- Velero Schedules: \$(kubectl get schedules -n velero --no-headers | wc -l)"
    echo "- Recent Backups: \$(kubectl get backups -n velero --no-headers | wc -l)"
    echo
    
    echo "📊 RECOVERY READINESS:"
    CRITICAL_PODS=\$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)
    TOTAL_PODS=\$(kubectl get pods --all-namespaces --no-headers | wc -l)
    echo "- Running Pods: \$CRITICAL_PODS/\$TOTAL_PODS"
    
    BOUND_PVCS=\$(kubectl get pvc --all-namespaces --no-headers | grep -c Bound || echo "0")
    TOTAL_PVCS=\$(kubectl get pvc --all-namespaces --no-headers | wc -l)
    echo "- Bound PVCs: \$BOUND_PVCS/\$TOTAL_PVCS"
    echo
    
    echo "🔧 RECOMMENDATIONS:"
    echo "1. Regular backup testing and validation"
    echo "2. Periodic DR drills and simulations"
    echo "3. Monitor backup storage capacity"
    echo "4. Update recovery procedures documentation"
    echo "5. Cross-region backup replication"
    echo
}

# Main execution
case "\$1" in
    "health")
        check_backup_health
        ;;
    "backups")
        check_recent_backups
        ;;
    "readiness")
        check_dr_readiness
        ;;
    "integrity")
        check_backup_integrity
        ;;
    "recovery")
        check_recovery_capabilities
        ;;
    "report")
        generate_dr_report
        ;;
    "all"|"")
        check_backup_health
        check_recent_backups
        check_dr_readiness
        check_backup_integrity
        check_recovery_capabilities
        generate_dr_report
        ;;
    *)
        echo "Usage: \$0 [health|backups|readiness|integrity|recovery|report|all]"
        echo ""
        echo "Options:"
        echo "  health      - Check backup system health"
        echo "  backups     - Check recent backups"
        echo "  readiness   - Check DR readiness"
        echo "  integrity   - Check backup integrity"
        echo "  recovery    - Check recovery capabilities"
        echo "  report      - Generate DR report"
        echo "  all         - Run all checks (default)"
        ;;
esac

DR_MONITORING_EOF
    
    chmod +x disaster-recovery-monitor.sh
    
    echo "✅ Disaster recovery monitoring script created: disaster-recovery-monitor.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_dr_state
            ;;
        "etcd-backup")
            create_etcd_backup
            ;;
        "velero")
            create_velero_backup
            ;;
        "schedules")
            create_backup_schedules
            ;;
        "procedures")
            create_dr_procedures
            ;;
        "monitoring")
            create_dr_monitoring
            ;;
        "all"|"")
            analyze_current_dr_state
            create_etcd_backup
            create_velero_backup
            create_backup_schedules
            create_dr_procedures
            create_dr_monitoring
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze      - Analyze current DR state"
            echo "  etcd-backup  - Create etcd backup system"
            echo "  velero       - Create Velero backup system"
            echo "  schedules    - Create backup schedules"
            echo "  procedures   - Create DR procedures documentation"
            echo "  monitoring   - Create DR monitoring tools"
            echo "  all          - Create complete DR framework (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 etcd-backup"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x disaster-recovery-implementation.sh

# Запустить создание disaster recovery framework
./disaster-recovery-implementation.sh all
```

## 📋 **Стратегии Disaster Recovery:**

### **Типы восстановления:**

| **Стратегия** | **RTO** | **RPO** | **Стоимость** | **Сложность** |
|---------------|---------|---------|---------------|---------------|
| **Cold Standby** | 4-8 часов | 24 часа | Низкая | Низкая |
| **Warm Standby** | 1-2 часа | 1-4 часа | Средняя | Средняя |
| **Hot Standby** | 5-15 минут | 0-1 час | Высокая | Высокая |
| **Active-Active** | 0-5 минут | 0 минут | Очень высокая | Очень высокая |

## 🎯 **Практические команды:**

### **Создание DR framework:**
```bash
# Создать полную DR систему
./disaster-recovery-implementation.sh all

# Мониторинг DR готовности
./disaster-recovery-monitor.sh all

# Проверить backup health
./disaster-recovery-monitor.sh health
```

### **Backup операции:**
```bash
# Создать manual backup
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S)

# Проверить статус backup
velero backup get

# Восстановить из backup
velero restore create --from-backup backup-name
```

### **etcd операции:**
```bash
# Создать etcd snapshot
kubectl exec -n kube-system etcd-$(kubectl get nodes -o name | head -1 | cut -d/ -f2) -- \
  etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Проверить snapshot
kubectl exec -n kube-system etcd-$(kubectl get nodes -o name | head -1 | cut -d/ -f2) -- \
  etcdctl snapshot status /tmp/etcd-backup.db -w table
```

## 🔧 **Best Practices для DR:**

### **Планирование:**
- **RTO/RPO definition** - определение целей восстановления
- **Risk assessment** - оценка рисков
- **Business impact analysis** - анализ влияния на бизнес
- **Recovery strategies** - стратегии восстановления

### **Реализация:**
- **Automated backups** - автоматические резервные копии
- **Multi-region deployment** - мультирегиональное развертывание
- **Data replication** - репликация данных
- **Infrastructure as Code** - инфраструктура как код

### **Тестирование:**
- **Regular DR drills** - регулярные учения
- **Backup validation** - проверка резервных копий
- **Recovery testing** - тестирование восстановления
- **Documentation updates** - обновление документации

### **Мониторинг:**
- **Backup monitoring** - мониторинг резервных копий
- **Health checks** - проверки состояния
- **Alert systems** - системы оповещения
- **Compliance tracking** - отслеживание соответствия

**Disaster Recovery - критически важный компонент для обеспечения непрерывности бизнеса!**
