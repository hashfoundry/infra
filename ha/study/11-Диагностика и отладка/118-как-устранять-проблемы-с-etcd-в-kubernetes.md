# 118. Как устранять проблемы с etcd в Kubernetes

## 🎯 **Как устранять проблемы с etcd в Kubernetes**

**etcd** - критически важный компонент Kubernetes, который хранит все данные кластера. Проблемы с etcd могут привести к полной недоступности кластера, поэтому понимание диагностики и восстановления etcd критически важно.

## 🗄️ **Архитектура etcd в Kubernetes:**

### **1. etcd Components:**
- **etcd cluster** - распределенное key-value хранилище
- **etcd members** - узлы etcd кластера
- **Raft consensus** - алгоритм консенсуса
- **WAL (Write-Ahead Log)** - журнал транзакций

### **2. etcd в HA кластере:**
- **Multiple etcd nodes** - обычно 3 или 5 узлов
- **Leader election** - выбор лидера
- **Quorum** - большинство для принятия решений
- **Data replication** - репликация данных

### **3. Common etcd Issues:**
- **Split brain** - разделение кластера
- **Disk space** - нехватка места
- **Network partitions** - сетевые разделения
- **Corruption** - повреждение данных

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive etcd troubleshooting toolkit
cat << 'EOF' > etcd-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== etcd Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing etcd issues in HashFoundry HA cluster"
echo

# Функция для проверки статуса etcd
check_etcd_status() {
    echo "=== etcd Status Check ==="
    
    echo "1. etcd pods status:"
    kubectl get pods -n kube-system | grep etcd
    echo
    
    echo "2. etcd pod details:"
    kubectl get pods -n kube-system -l component=etcd -o wide
    echo
    
    echo "3. etcd container logs:"
    ETCD_PODS=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[*].metadata.name}')
    for pod in $ETCD_PODS; do
        echo "--- Logs for $pod ---"
        kubectl logs -n kube-system $pod --tail=20
        echo
    done
    
    echo "4. etcd events:"
    kubectl get events -n kube-system --field-selector involvedObject.kind=Pod | grep etcd
    echo
}

# Функция для проверки etcd cluster health
check_etcd_cluster_health() {
    echo "=== etcd Cluster Health Check ==="
    
    echo "1. Get etcd endpoints:"
    ETCD_ENDPOINTS=$(kubectl get endpoints -n kube-system etcd -o jsonpath='{.subsets[*].addresses[*].ip}' | tr ' ' ',')
    echo "etcd endpoints: $ETCD_ENDPOINTS"
    echo
    
    echo "2. Check etcd cluster health (from etcd pod):"
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$ETCD_POD" ]; then
        echo "Using etcd pod: $ETCD_POD"
        
        # Check cluster health
        kubectl exec -n kube-system $ETCD_POD -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            endpoint health
        echo
        
        # Check cluster status
        kubectl exec -n kube-system $ETCD_POD -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            endpoint status --write-out=table
        echo
        
        # Check member list
        kubectl exec -n kube-system $ETCD_POD -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            member list --write-out=table
        echo
    else
        echo "❌ No etcd pods found!"
    fi
}

# Функция для проверки etcd performance
check_etcd_performance() {
    echo "=== etcd Performance Check ==="
    
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$ETCD_POD" ]; then
        echo "1. etcd database size:"
        kubectl exec -n kube-system $ETCD_POD -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            endpoint status --write-out=json | jq '.[] | {endpoint: .Endpoint, dbSize: .Status.dbSize, dbSizeInUse: .Status.dbSizeInUse}'
        echo
        
        echo "2. etcd metrics (if available):"
        kubectl exec -n kube-system $ETCD_POD -- curl -s http://127.0.0.1:2381/metrics | grep -E "(etcd_disk|etcd_network|etcd_server)" | head -10
        echo
        
        echo "3. Check disk usage on etcd nodes:"
        kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | while read node; do
            echo "Node: $node"
            kubectl debug node/$node -it --image=busybox -- df -h /var/lib/etcd 2>/dev/null || echo "Cannot check disk usage on $node"
        done
        echo
    fi
}

# Функция для диагностики etcd connectivity
diagnose_etcd_connectivity() {
    echo "=== etcd Connectivity Diagnosis ==="
    
    echo "1. Check etcd service:"
    kubectl get service -n kube-system etcd 2>/dev/null || echo "etcd service not found (normal for static pods)"
    echo
    
    echo "2. Check etcd endpoints:"
    kubectl get endpoints -n kube-system etcd 2>/dev/null || echo "etcd endpoints not found"
    echo
    
    echo "3. Test etcd connectivity from API server:"
    API_SERVER_POD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$API_SERVER_POD" ]; then
        echo "Testing from API server pod: $API_SERVER_POD"
        kubectl exec -n kube-system $API_SERVER_POD -- netstat -tulpn | grep 2379 || echo "No etcd connections found"
    fi
    echo
    
    echo "4. Check etcd certificates:"
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$ETCD_POD" ]; then
        echo "Checking etcd certificates in pod: $ETCD_POD"
        kubectl exec -n kube-system $ETCD_POD -- ls -la /etc/kubernetes/pki/etcd/
        echo
        
        echo "Certificate expiration:"
        kubectl exec -n kube-system $ETCD_POD -- openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -text -noout | grep -A 2 "Validity"
    fi
    echo
}

# Функция для создания etcd backup
create_etcd_backup() {
    echo "=== Creating etcd Backup ==="
    
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$ETCD_POD" ]; then
        BACKUP_FILE="/tmp/etcd-backup-$(date +%Y%m%d-%H%M%S).db"
        
        echo "Creating etcd backup: $BACKUP_FILE"
        kubectl exec -n kube-system $ETCD_POD -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            snapshot save $BACKUP_FILE
        
        echo "Backup created successfully!"
        echo "To copy backup from pod:"
        echo "kubectl cp kube-system/$ETCD_POD:$BACKUP_FILE ./etcd-backup-$(date +%Y%m%d-%H%M%S).db"
        echo
        
        echo "Verify backup:"
        kubectl exec -n kube-system $ETCD_POD -- etcdctl snapshot status $BACKUP_FILE --write-out=table
    else
        echo "❌ No etcd pods found for backup!"
    fi
    echo
}

# Функция для мониторинга etcd
monitor_etcd_health() {
    echo "=== etcd Health Monitoring ==="
    
    echo "1. etcd monitoring script:"
    cat << ETCD_MONITOR_EOF > etcd-health-monitor.sh
#!/bin/bash

echo "=== etcd Health Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "etcd Pods Status:"
    kubectl get pods -n kube-system -l component=etcd --no-headers | awk '{print \$1 " " \$3}'
    echo
    
    echo "etcd Cluster Health:"
    ETCD_POD=\$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "\$ETCD_POD" ]; then
        kubectl exec -n kube-system \$ETCD_POD -- etcdctl \\
            --endpoints=https://127.0.0.1:2379 \\
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \\
            --cert=/etc/kubernetes/pki/etcd/server.crt \\
            --key=/etc/kubernetes/pki/etcd/server.key \\
            endpoint health 2>/dev/null || echo "❌ etcd health check failed"
    else
        echo "❌ No etcd pods found"
    fi
    echo
    
    echo "API Server Status:"
    kubectl get pods -n kube-system -l component=kube-apiserver --no-headers | awk '{print \$1 " " \$3}'
    echo
    
    sleep 30
done

ETCD_MONITOR_EOF
    
    chmod +x etcd-health-monitor.sh
    echo "✅ etcd health monitoring script created: etcd-health-monitor.sh"
    echo
}

# Функция для создания etcd troubleshooting scenarios
create_etcd_troubleshooting_scenarios() {
    echo "=== Creating etcd Troubleshooting Scenarios ==="
    
    echo "1. etcd disaster recovery guide:"
    cat << DISASTER_RECOVERY_EOF > etcd-disaster-recovery-guide.md
# etcd Disaster Recovery Guide

## 🚨 **Emergency etcd Recovery Procedures**

### **Scenario 1: Single etcd Member Failure**
\`\`\`bash
# 1. Check cluster status
kubectl exec -n kube-system <etcd-pod> -- etcdctl member list

# 2. Remove failed member
kubectl exec -n kube-system <etcd-pod> -- etcdctl member remove <member-id>

# 3. Add new member
kubectl exec -n kube-system <etcd-pod> -- etcdctl member add <new-member-name> --peer-urls=<peer-url>

# 4. Start new etcd instance on replacement node
\`\`\`

### **Scenario 2: etcd Quorum Loss**
\`\`\`bash
# 1. Stop all etcd instances
systemctl stop etcd

# 2. Restore from backup on one node
etcdctl snapshot restore /path/to/backup.db \\
    --data-dir=/var/lib/etcd-restore \\
    --initial-cluster=<cluster-config> \\
    --initial-advertise-peer-urls=<peer-url>

# 3. Update etcd configuration
# 4. Start etcd with --force-new-cluster
# 5. Add other members back
\`\`\`

### **Scenario 3: etcd Data Corruption**
\`\`\`bash
# 1. Stop etcd
systemctl stop etcd

# 2. Backup current data
cp -r /var/lib/etcd /var/lib/etcd.backup

# 3. Restore from known good backup
etcdctl snapshot restore /path/to/good-backup.db \\
    --data-dir=/var/lib/etcd

# 4. Start etcd
systemctl start etcd
\`\`\`

## 🔧 **Prevention Best Practices**
1. **Regular backups**: Automated daily backups
2. **Monitoring**: etcd health and performance metrics
3. **Disk space**: Monitor and maintain adequate space
4. **Network**: Ensure stable network between etcd members
5. **Certificates**: Monitor certificate expiration

DISASTER_RECOVERY_EOF
    
    echo "✅ etcd disaster recovery guide created: etcd-disaster-recovery-guide.md"
    echo
    
    echo "2. etcd maintenance procedures:"
    cat << MAINTENANCE_PROCEDURES_EOF > etcd-maintenance-procedures.md
# etcd Maintenance Procedures

## 🔧 **Regular Maintenance Tasks**

### **1. Database Compaction**
\`\`\`bash
# Check database size
kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint status --write-out=table

# Compact database
kubectl exec -n kube-system <etcd-pod> -- etcdctl compact <revision>

# Defragment database
kubectl exec -n kube-system <etcd-pod> -- etcdctl defrag
\`\`\`

### **2. Certificate Rotation**
\`\`\`bash
# Check certificate expiration
kubectl exec -n kube-system <etcd-pod> -- openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -text -noout | grep "Not After"

# Rotate certificates (kubeadm)
kubeadm certs renew etcd-server
kubeadm certs renew etcd-peer
kubeadm certs renew etcd-healthcheck-client
\`\`\`

### **3. Performance Tuning**
\`\`\`bash
# Monitor etcd metrics
kubectl exec -n kube-system <etcd-pod> -- curl -s http://127.0.0.1:2381/metrics | grep etcd_disk

# Tune etcd parameters
# --heartbeat-interval=100
# --election-timeout=1000
# --max-request-bytes=1572864
\`\`\`

MAINTENANCE_PROCEDURES_EOF
    
    echo "✅ etcd maintenance procedures created: etcd-maintenance-procedures.md"
    echo
}

# Функция для автоматического исправления etcd проблем
auto_fix_etcd_issues() {
    echo "=== Auto-fix etcd Issues ==="
    
    echo "1. Common etcd fixes:"
    cat << ETCD_FIXES_EOF
# Fix 1: Restart etcd pods (if using static pods)
kubectl delete pod -n kube-system <etcd-pod-name>

# Fix 2: Check disk space and clean up
df -h /var/lib/etcd
find /var/lib/etcd -name "*.log" -mtime +7 -delete

# Fix 3: Compact and defragment etcd
kubectl exec -n kube-system <etcd-pod> -- etcdctl compact <revision>
kubectl exec -n kube-system <etcd-pod> -- etcdctl defrag

# Fix 4: Restore from backup (emergency)
etcdctl snapshot restore /path/to/backup.db --data-dir=/var/lib/etcd-restore

# Fix 5: Check and fix certificates
kubeadm certs check-expiration
kubeadm certs renew all

ETCD_FIXES_EOF
    echo
    
    echo "2. etcd troubleshooting checklist:"
    cat << ETCD_CHECKLIST_EOF > etcd-troubleshooting-checklist.md
# etcd Troubleshooting Checklist

## ✅ **Step 1: Basic etcd Check**
- [ ] etcd pods are running: \`kubectl get pods -n kube-system -l component=etcd\`
- [ ] etcd logs show no errors: \`kubectl logs -n kube-system <etcd-pod>\`
- [ ] etcd endpoints are healthy: \`etcdctl endpoint health\`

## ✅ **Step 2: Cluster Health**
- [ ] All etcd members are present: \`etcdctl member list\`
- [ ] Cluster has quorum: check member count
- [ ] No split-brain scenario: verify leader election

## ✅ **Step 3: Performance Check**
- [ ] Database size is reasonable: \`etcdctl endpoint status\`
- [ ] Disk space is adequate: \`df -h /var/lib/etcd\`
- [ ] Network latency is low: check between etcd members

## ✅ **Step 4: Connectivity**
- [ ] API server can connect to etcd: check API server logs
- [ ] etcd certificates are valid: check expiration dates
- [ ] Network policies allow etcd traffic: port 2379, 2380

## ✅ **Step 5: Data Integrity**
- [ ] No data corruption: check etcd logs for corruption errors
- [ ] Backups are recent and valid: verify backup integrity
- [ ] WAL files are not corrupted: check etcd data directory

## 🔧 **Emergency Procedures**
1. **Single member failure**: Remove and re-add member
2. **Quorum loss**: Restore from backup with --force-new-cluster
3. **Data corruption**: Restore from known good backup
4. **Certificate expiration**: Renew certificates
5. **Disk full**: Clean up old data and compact database

ETCD_CHECKLIST_EOF
    
    echo "✅ etcd troubleshooting checklist created: etcd-troubleshooting-checklist.md"
    echo
}

# Основная функция
main() {
    case "$1" in
        "status")
            check_etcd_status
            ;;
        "health")
            check_etcd_cluster_health
            ;;
        "performance")
            check_etcd_performance
            ;;
        "connectivity")
            diagnose_etcd_connectivity
            ;;
        "backup")
            create_etcd_backup
            ;;
        "monitor")
            monitor_etcd_health
            ;;
        "scenarios")
            create_etcd_troubleshooting_scenarios
            ;;
        "fix")
            auto_fix_etcd_issues
            ;;
        "all"|"")
            check_etcd_status
            check_etcd_cluster_health
            check_etcd_performance
            diagnose_etcd_connectivity
            create_etcd_backup
            monitor_etcd_health
            create_etcd_troubleshooting_scenarios
            auto_fix_etcd_issues
            ;;
        *)
            echo "Usage: $0 [status|health|performance|connectivity|backup|monitor|scenarios|fix|all]"
            echo ""
            echo "etcd Troubleshooting Options:"
            echo "  status       - Check etcd pods status"
            echo "  health       - Check etcd cluster health"
            echo "  performance  - Check etcd performance"
            echo "  connectivity - Diagnose etcd connectivity"
            echo "  backup       - Create etcd backup"
            echo "  monitor      - Monitor etcd health"
            echo "  scenarios    - Create troubleshooting scenarios"
            echo "  fix          - Auto-fix etcd issues"
            ;;
    esac
}

main "$@"

EOF

chmod +x etcd-troubleshooting-toolkit.sh
./etcd-troubleshooting-toolkit.sh all
```

## 🎯 **Пошаговая диагностика etcd проблем:**

### **Шаг 1: Проверка статуса etcd**
```bash
# Статус etcd pods
kubectl get pods -n kube-system -l component=etcd

# Логи etcd
kubectl logs -n kube-system <etcd-pod-name>

# События etcd
kubectl get events -n kube-system | grep etcd
```

### **Шаг 2: Проверка здоровья кластера**
```bash
# Здоровье endpoints
kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint health

# Статус кластера
kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint status --write-out=table

# Список членов
kubectl exec -n kube-system <etcd-pod> -- etcdctl member list
```

### **Шаг 3: Проверка производительности**
```bash
# Размер базы данных
kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint status --write-out=json

# Использование диска
df -h /var/lib/etcd

# Метрики etcd
curl http://127.0.0.1:2381/metrics | grep etcd_disk
```

### **Шаг 4: Создание backup**
```bash
# Создать snapshot
kubectl exec -n kube-system <etcd-pod> -- etcdctl snapshot save /tmp/backup.db

# Проверить backup
kubectl exec -n kube-system <etcd-pod> -- etcdctl snapshot status /tmp/backup.db
```

## 🔧 **Частые проблемы etcd и решения:**

### **1. etcd pod не запускается:**
```bash
# Проверить логи
kubectl logs -n kube-system <etcd-pod>

# Проверить сертификаты
openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -text -noout

# Проверить место на диске
df -h /var/lib/etcd
```

### **2. Потеря кворума:**
```bash
# Восстановление из backup
etcdctl snapshot restore backup.db --data-dir=/var/lib/etcd-restore

# Запуск с --force-new-cluster
etcd --force-new-cluster
```

### **3. Медленная работа etcd:**
```bash
# Компактирование базы
kubectl exec -n kube-system <etcd-pod> -- etcdctl compact <revision>

# Дефрагментация
kubectl exec -n kube-system <etcd-pod> -- etcdctl defrag
```

### **4. Проблемы с сертификатами:**
```bash
# Проверить срок действия
kubeadm certs check-expiration

# Обновить сертификаты
kubeadm certs renew all
```

**etcd - сердце Kubernetes кластера, его здоровье критически важно!**
