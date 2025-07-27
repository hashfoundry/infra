# 86. Безопасные обновления Kubernetes кластера

## 🎯 **Безопасные обновления Kubernetes кластера**

**Cluster Upgrades** - это критически важный процесс обновления компонентов Kubernetes кластера, который требует тщательного планирования, тестирования и поэтапного выполнения для минимизации рисков и обеспечения непрерывности работы приложений.

## 🏗️ **Компоненты обновления:**

### **1. Control Plane Components:**
- **kube-apiserver** - API сервер
- **etcd** - база данных кластера
- **kube-controller-manager** - менеджер контроллеров
- **kube-scheduler** - планировщик

### **2. Node Components:**
- **kubelet** - агент на узлах
- **kube-proxy** - сетевой прокси
- **Container Runtime** - среда выполнения контейнеров
- **CNI Plugins** - сетевые плагины

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей версии кластера:**
```bash
# Проверить версии компонентов
kubectl version --short
kubectl get nodes -o wide

# Анализ готовности к обновлению
kubectl get componentstatuses
```

### **2. Создание comprehensive upgrade framework:**
```bash
# Создать скрипт для безопасного обновления кластера
cat << 'EOF' > cluster-upgrade-implementation.sh
#!/bin/bash

echo "=== Kubernetes Cluster Upgrade Implementation ==="
echo "Implementing safe cluster upgrade procedures for HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния кластера
analyze_current_cluster() {
    echo "=== Current Cluster Analysis ==="
    
    echo "1. Cluster Version Information:"
    echo "=============================="
    kubectl version --short
    echo
    
    echo "2. Node Status and Versions:"
    echo "==========================="
    kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,VERSION:.status.nodeInfo.kubeletVersion,OS:.status.nodeInfo.osImage,KERNEL:.status.nodeInfo.kernelVersion"
    echo
    
    echo "3. Component Status:"
    echo "==================="
    kubectl get componentstatuses 2>/dev/null || echo "Component status not available (normal for newer clusters)"
    echo
    
    echo "4. Critical System Pods:"
    echo "======================="
    kubectl get pods -n kube-system -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,VERSION:.spec.containers[0].image" | head -20
    echo
    
    echo "5. Cluster Resources Summary:"
    echo "============================"
    kubectl get all --all-namespaces --no-headers | wc -l | xargs echo "Total resources:"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | wc -l | xargs echo "Non-running pods:"
    echo
}

# Функция для pre-upgrade проверок
pre_upgrade_checks() {
    echo "=== Pre-Upgrade Checks ==="
    
    echo "1. Backup Verification:"
    echo "======================"
    
    # Проверить etcd backup
    echo "Checking etcd backup status..."
    if kubectl get pods -n kube-system -l component=etcd >/dev/null 2>&1; then
        echo "✅ etcd pods found - backup recommended before upgrade"
    else
        echo "⚠️  etcd pods not visible - ensure backup is available"
    fi
    echo
    
    echo "2. Resource Health Check:"
    echo "========================"
    
    # Проверить unhealthy pods
    UNHEALTHY_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | wc -l)
    if [ "$UNHEALTHY_PODS" -eq 0 ]; then
        echo "✅ All pods are healthy"
    else
        echo "⚠️  Found $UNHEALTHY_PODS unhealthy pods - investigate before upgrade"
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running
    fi
    echo
    
    echo "3. Node Readiness Check:"
    echo "======================="
    
    # Проверить node readiness
    NOT_READY_NODES=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "$NOT_READY_NODES" -eq 0 ]; then
        echo "✅ All nodes are ready"
    else
        echo "⚠️  Found $NOT_READY_NODES not ready nodes - fix before upgrade"
        kubectl get nodes | grep -v " Ready "
    fi
    echo
    
    echo "4. Storage Health Check:"
    echo "======================="
    
    # Проверить PVC status
    PENDING_PVCS=$(kubectl get pvc --all-namespaces --no-headers | grep -c "Pending" || echo "0")
    if [ "$PENDING_PVCS" -eq 0 ]; then
        echo "✅ All PVCs are bound"
    else
        echo "⚠️  Found $PENDING_PVCS pending PVCs"
        kubectl get pvc --all-namespaces | grep "Pending"
    fi
    echo
    
    echo "5. Critical Applications Check:"
    echo "=============================="
    
    # Проверить критические приложения
    for namespace in kube-system monitoring nginx-ingress; do
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            READY_PODS=$(kubectl get pods -n "$namespace" --no-headers | grep -c "Running" || echo "0")
            TOTAL_PODS=$(kubectl get pods -n "$namespace" --no-headers | wc -l)
            echo "Namespace $namespace: $READY_PODS/$TOTAL_PODS pods running"
        fi
    done
    echo
}

# Функция для создания upgrade plan
create_upgrade_plan() {
    echo "=== Creating Upgrade Plan ==="
    
    # Получить текущую версию
    CURRENT_VERSION=$(kubectl version --short --client | grep "Client Version" | awk '{print $3}')
    SERVER_VERSION=$(kubectl version --short | grep "Server Version" | awk '{print $3}' || echo "unknown")
    
    cat << UPGRADE_PLAN_EOF > cluster-upgrade-plan.md
# HashFoundry HA Cluster Upgrade Plan

## Current State
- **Current Client Version**: $CURRENT_VERSION
- **Current Server Version**: $SERVER_VERSION
- **Cluster Name**: hashfoundry-ha
- **Node Count**: $(kubectl get nodes --no-headers | wc -l)
- **Upgrade Date**: $(date)

## Upgrade Strategy

### Phase 1: Preparation (30 minutes)
1. **Backup Creation**
   - etcd snapshot
   - Cluster configuration backup
   - Application data backup

2. **Pre-upgrade Validation**
   - Health checks
   - Resource validation
   - Dependency verification

### Phase 2: Control Plane Upgrade (45 minutes)
1. **Master Node 1**
   - Drain node
   - Upgrade kubelet, kubeadm, kubectl
   - Upgrade control plane
   - Uncordon node

2. **Master Node 2 & 3** (if HA)
   - Repeat process for each master
   - Verify cluster health between upgrades

### Phase 3: Worker Nodes Upgrade (60 minutes)
1. **Rolling Update Strategy**
   - Upgrade one node at a time
   - Drain → Upgrade → Uncordon
   - Verify pod rescheduling

2. **Validation**
   - Check all pods are running
   - Verify application functionality
   - Performance validation

### Phase 4: Post-Upgrade (30 minutes)
1. **System Validation**
   - Component health checks
   - Network connectivity tests
   - Storage functionality

2. **Application Testing**
   - Critical path testing
   - Performance benchmarks
   - User acceptance testing

## Rollback Plan
1. **Immediate Rollback Triggers**
   - API server unavailable > 5 minutes
   - >50% pods failing
   - Critical application failures

2. **Rollback Procedure**
   - Restore etcd from backup
   - Downgrade control plane
   - Restore node configurations

## Risk Mitigation
- **Maintenance Window**: Schedule during low traffic
- **Communication Plan**: Notify stakeholders
- **Monitoring**: Enhanced monitoring during upgrade
- **Support Team**: On-call team availability

## Success Criteria
- ✅ All nodes upgraded successfully
- ✅ All pods running and healthy
- ✅ Applications responding normally
- ✅ No data loss
- ✅ Performance within acceptable range

UPGRADE_PLAN_EOF
    
    echo "✅ Upgrade plan created: cluster-upgrade-plan.md"
    echo
}

# Функция для создания backup
create_cluster_backup() {
    echo "=== Creating Cluster Backup ==="
    
    # Создать директорию для backup
    BACKUP_DIR="cluster-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    echo "Creating backup in: $BACKUP_DIR"
    
    # Backup cluster configuration
    echo "1. Backing up cluster configuration..."
    kubectl cluster-info dump --output-directory="$BACKUP_DIR/cluster-dump" >/dev/null 2>&1
    
    # Backup all resources
    echo "2. Backing up all resources..."
    kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/all-resources.yaml"
    
    # Backup custom resources
    echo "3. Backing up custom resources..."
    kubectl get crd -o yaml > "$BACKUP_DIR/custom-resources.yaml"
    
    # Backup secrets (metadata only for security)
    echo "4. Backing up secrets metadata..."
    kubectl get secrets --all-namespaces -o yaml | grep -v "data:" > "$BACKUP_DIR/secrets-metadata.yaml"
    
    # Backup configmaps
    echo "5. Backing up configmaps..."
    kubectl get configmaps --all-namespaces -o yaml > "$BACKUP_DIR/configmaps.yaml"
    
    # Backup persistent volumes
    echo "6. Backing up persistent volumes..."
    kubectl get pv,pvc --all-namespaces -o yaml > "$BACKUP_DIR/persistent-volumes.yaml"
    
    # Create backup script for etcd (if accessible)
    cat << ETCD_BACKUP_EOF > "$BACKUP_DIR/etcd-backup.sh"
#!/bin/bash
# etcd backup script
# Note: This requires access to etcd pods/nodes

echo "Creating etcd backup..."

# Method 1: Using etcdctl in pod
kubectl exec -n kube-system etcd-\$(kubectl get nodes -o name | head -1 | cut -d/ -f2) -- \\
  etcdctl snapshot save /tmp/etcd-backup-\$(date +%Y%m%d-%H%M%S).db \\
  --endpoints=https://127.0.0.1:2379 \\
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \\
  --cert=/etc/kubernetes/pki/etcd/server.crt \\
  --key=/etc/kubernetes/pki/etcd/server.key

echo "etcd backup completed"
ETCD_BACKUP_EOF
    
    chmod +x "$BACKUP_DIR/etcd-backup.sh"
    
    # Create restore instructions
    cat << RESTORE_INSTRUCTIONS_EOF > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.md"
# Cluster Restore Instructions

## Prerequisites
- Access to cluster nodes
- kubectl configured
- Backup files from this directory

## Restore Procedure

### 1. Restore etcd (if needed)
\`\`\`bash
# Stop kube-apiserver
sudo systemctl stop kubelet

# Restore etcd snapshot
sudo etcdctl snapshot restore /path/to/etcd-backup.db \\
  --data-dir=/var/lib/etcd-restore

# Update etcd configuration to use restored data
# Restart kubelet
sudo systemctl start kubelet
\`\`\`

### 2. Restore Kubernetes Resources
\`\`\`bash
# Apply all resources
kubectl apply -f all-resources.yaml

# Apply custom resources
kubectl apply -f custom-resources.yaml

# Apply configmaps
kubectl apply -f configmaps.yaml

# Apply persistent volumes
kubectl apply -f persistent-volumes.yaml
\`\`\`

### 3. Verification
\`\`\`bash
# Check cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Verify applications
kubectl get all --all-namespaces
\`\`\`

## Notes
- Secrets are not included in backup for security
- Recreate secrets manually if needed
- Test restore procedure in staging environment first
RESTORE_INSTRUCTIONS_EOF
    
    echo "✅ Cluster backup created in: $BACKUP_DIR"
    echo "   - Cluster dump: $BACKUP_DIR/cluster-dump/"
    echo "   - Resources: $BACKUP_DIR/all-resources.yaml"
    echo "   - etcd backup script: $BACKUP_DIR/etcd-backup.sh"
    echo "   - Restore instructions: $BACKUP_DIR/RESTORE_INSTRUCTIONS.md"
    echo
}

# Функция для создания upgrade monitoring
create_upgrade_monitoring() {
    echo "=== Creating Upgrade Monitoring ==="
    
    cat << UPGRADE_MONITORING_EOF > cluster-upgrade-monitor.sh
#!/bin/bash

echo "=== Cluster Upgrade Monitoring ==="
echo "Monitoring cluster health during upgrade process"
echo

# Функция для проверки cluster health
check_cluster_health() {
    echo "1. Cluster Health Check:"
    echo "======================="
    
    # API server health
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ API server is responsive"
    else
        echo "❌ API server is not responsive"
        return 1
    fi
    
    # Node status
    NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
    echo "📊 Nodes: $((TOTAL_NODES - NOT_READY))/$TOTAL_NODES ready"
    
    # Pod status
    RUNNING_PODS=$(kubectl get pods --all-namespaces --no-headers | grep -c "Running" || echo "0")
    TOTAL_PODS=$(kubectl get pods --all-namespaces --no-headers | wc -l)
    echo "📊 Pods: $RUNNING_PODS/$TOTAL_PODS running"
    
    echo
}

# Функция для проверки critical applications
check_critical_applications() {
    echo "2. Critical Applications Check:"
    echo "=============================="
    
    # Check system components
    for component in kube-system monitoring nginx-ingress; do
        if kubectl get namespace "\$component" >/dev/null 2>&1; then
            READY=\$(kubectl get pods -n "\$component" --no-headers | grep -c "Running" || echo "0")
            TOTAL=\$(kubectl get pods -n "\$component" --no-headers | wc -l)
            
            if [ "\$READY" -eq "\$TOTAL" ] && [ "\$TOTAL" -gt 0 ]; then
                echo "✅ \$component: \$READY/\$TOTAL pods ready"
            else
                echo "⚠️  \$component: \$READY/\$TOTAL pods ready"
            fi
        fi
    done
    echo
}

# Функция для проверки network connectivity
check_network_connectivity() {
    echo "3. Network Connectivity Check:"
    echo "============================="
    
    # Test DNS resolution
    if kubectl run test-dns --image=busybox:1.35 --rm -it --restart=Never -- nslookup kubernetes.default >/dev/null 2>&1; then
        echo "✅ DNS resolution working"
    else
        echo "⚠️  DNS resolution issues detected"
    fi
    
    # Test service connectivity
    if kubectl get service kubernetes >/dev/null 2>&1; then
        echo "✅ Kubernetes service accessible"
    else
        echo "❌ Kubernetes service not accessible"
    fi
    
    echo
}

# Функция для проверки storage
check_storage_health() {
    echo "4. Storage Health Check:"
    echo "======================="
    
    # Check PVC status
    BOUND_PVCS=\$(kubectl get pvc --all-namespaces --no-headers | grep -c "Bound" || echo "0")
    TOTAL_PVCS=\$(kubectl get pvc --all-namespaces --no-headers | wc -l)
    
    if [ "\$TOTAL_PVCS" -eq 0 ]; then
        echo "📊 No PVCs found"
    elif [ "\$BOUND_PVCS" -eq "\$TOTAL_PVCS" ]; then
        echo "✅ Storage: \$BOUND_PVCS/\$TOTAL_PVCS PVCs bound"
    else
        echo "⚠️  Storage: \$BOUND_PVCS/\$TOTAL_PVCS PVCs bound"
    fi
    
    echo
}

# Функция для performance check
check_performance() {
    echo "5. Performance Check:"
    echo "===================="
    
    # API server response time
    START_TIME=\$(date +%s%N)
    kubectl get nodes >/dev/null 2>&1
    END_TIME=\$(date +%s%N)
    RESPONSE_TIME=\$(( (END_TIME - START_TIME) / 1000000 ))
    
    if [ "\$RESPONSE_TIME" -lt 1000 ]; then
        echo "✅ API response time: \${RESPONSE_TIME}ms (good)"
    elif [ "\$RESPONSE_TIME" -lt 5000 ]; then
        echo "⚠️  API response time: \${RESPONSE_TIME}ms (acceptable)"
    else
        echo "❌ API response time: \${RESPONSE_TIME}ms (slow)"
    fi
    
    echo
}

# Функция для continuous monitoring
continuous_monitoring() {
    echo "6. Continuous Monitoring Mode:"
    echo "============================="
    echo "Press Ctrl+C to stop monitoring"
    echo
    
    while true; do
        clear
        echo "=== Cluster Upgrade Monitoring - \$(date) ==="
        echo
        
        check_cluster_health
        check_critical_applications
        check_network_connectivity
        check_storage_health
        check_performance
        
        echo "Next check in 30 seconds..."
        sleep 30
    done
}

# Main execution
case "\$1" in
    "health")
        check_cluster_health
        ;;
    "apps")
        check_critical_applications
        ;;
    "network")
        check_network_connectivity
        ;;
    "storage")
        check_storage_health
        ;;
    "performance")
        check_performance
        ;;
    "continuous")
        continuous_monitoring
        ;;
    "all"|"")
        check_cluster_health
        check_critical_applications
        check_network_connectivity
        check_storage_health
        check_performance
        ;;
    *)
        echo "Usage: \$0 [health|apps|network|storage|performance|continuous|all]"
        echo ""
        echo "Options:"
        echo "  health      - Check cluster health"
        echo "  apps        - Check critical applications"
        echo "  network     - Check network connectivity"
        echo "  storage     - Check storage health"
        echo "  performance - Check performance metrics"
        echo "  continuous  - Continuous monitoring mode"
        echo "  all         - Run all checks (default)"
        ;;
esac

UPGRADE_MONITORING_EOF
    
    chmod +x cluster-upgrade-monitor.sh
    
    echo "✅ Upgrade monitoring script created: cluster-upgrade-monitor.sh"
    echo
}

# Функция для создания upgrade automation
create_upgrade_automation() {
    echo "=== Creating Upgrade Automation ==="
    
    cat << UPGRADE_AUTOMATION_EOF > cluster-upgrade-automation.sh
#!/bin/bash

echo "=== Automated Cluster Upgrade ==="
echo "WARNING: This script performs automated cluster upgrade"
echo "Ensure you have tested this in staging environment first"
echo

# Configuration
TARGET_VERSION="\${1:-1.28.0}"
BACKUP_DIR="upgrade-backup-\$(date +%Y%m%d-%H%M%S)"
LOG_FILE="upgrade-\$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" | tee -a "\$LOG_FILE"
}

# Error handling
handle_error() {
    log "ERROR: \$1"
    log "Upgrade failed. Check logs and consider rollback."
    exit 1
}

# Pre-upgrade validation
pre_upgrade_validation() {
    log "Starting pre-upgrade validation..."
    
    # Check cluster health
    if ! kubectl cluster-info >/dev/null 2>&1; then
        handle_error "Cluster is not accessible"
    fi
    
    # Check node readiness
    NOT_READY=\$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "\$NOT_READY" -gt 0 ]; then
        handle_error "Found \$NOT_READY not ready nodes"
    fi
    
    # Check pod health
    UNHEALTHY=\$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | wc -l)
    if [ "\$UNHEALTHY" -gt 0 ]; then
        log "WARNING: Found \$UNHEALTHY unhealthy pods"
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
            handle_error "Upgrade cancelled by user"
        fi
    fi
    
    log "Pre-upgrade validation completed"
}

# Create backup
create_backup() {
    log "Creating cluster backup..."
    
    mkdir -p "\$BACKUP_DIR"
    
    # Backup cluster state
    kubectl get all --all-namespaces -o yaml > "\$BACKUP_DIR/all-resources.yaml"
    kubectl get crd -o yaml > "\$BACKUP_DIR/custom-resources.yaml"
    kubectl get pv,pvc --all-namespaces -o yaml > "\$BACKUP_DIR/storage.yaml"
    
    log "Backup created in \$BACKUP_DIR"
}

# Upgrade control plane
upgrade_control_plane() {
    log "Starting control plane upgrade to \$TARGET_VERSION..."
    
    # Note: This is a simplified example
    # Real implementation would depend on your cluster setup (kubeadm, managed service, etc.)
    
    log "Control plane upgrade completed"
}

# Upgrade worker nodes
upgrade_worker_nodes() {
    log "Starting worker nodes upgrade..."
    
    # Get all worker nodes
    WORKER_NODES=\$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v master)
    
    for node in \$WORKER_NODES; do
        log "Upgrading node: \$node"
        
        # Drain node
        log "Draining node \$node..."
        kubectl drain "\$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s
        
        # Wait for pods to be rescheduled
        sleep 30
        
        # Note: Actual node upgrade would happen here
        # This depends on your infrastructure (SSH to node, package manager, etc.)
        
        # Uncordon node
        log "Uncordoning node \$node..."
        kubectl uncordon "\$node"
        
        # Wait for node to be ready
        log "Waiting for node \$node to be ready..."
        kubectl wait --for=condition=Ready node/"\$node" --timeout=300s
        
        log "Node \$node upgrade completed"
    done
    
    log "All worker nodes upgraded"
}

# Post-upgrade validation
post_upgrade_validation() {
    log "Starting post-upgrade validation..."
    
    # Check cluster version
    NEW_VERSION=\$(kubectl version --short | grep "Server Version" | awk '{print \$3}')
    log "Cluster upgraded to version: \$NEW_VERSION"
    
    # Check all nodes are ready
    NOT_READY=\$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "\$NOT_READY" -gt 0 ]; then
        handle_error "Found \$NOT_READY not ready nodes after upgrade"
    fi
    
    # Check all pods are running
    sleep 60  # Wait for pods to stabilize
    UNHEALTHY=\$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | wc -l)
    if [ "\$UNHEALTHY" -gt 5 ]; then  # Allow some tolerance
        log "WARNING: Found \$UNHEALTHY unhealthy pods after upgrade"
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running
    fi
    
    log "Post-upgrade validation completed"
}

# Main upgrade process
main() {
    log "Starting cluster upgrade to version \$TARGET_VERSION"
    
    pre_upgrade_validation
    create_backup
    upgrade_control_plane
    upgrade_worker_nodes
    post_upgrade_validation
    
    log "Cluster upgrade completed successfully!"
    log "Backup available in: \$BACKUP_DIR"
    log "Upgrade log: \$LOG_FILE"
}

# Check if running in interactive mode
if [ -t 0 ]; then
    echo "Target version: \$TARGET_VERSION"
    echo "This will upgrade your cluster. Are you sure? (y/N)"
    read -n 1 -r
    echo
    if [[ \$REPLY =~ ^[Yy]\$ ]]; then
        main
    else
        echo "Upgrade cancelled"
        exit 0
    fi
else
    main
fi

UPGRADE_AUTOMATION_EOF
    
    chmod +x cluster-upgrade-automation.sh
    
    echo "✅ Upgrade automation script created: cluster-upgrade-automation.sh"
    echo "   Usage: ./cluster-upgrade-automation.sh [target-version]"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_cluster
            ;;
        "pre-check")
            pre_upgrade_checks
            ;;
        "plan")
            create_upgrade_plan
            ;;
        "backup")
            create_cluster_backup
            ;;
        "monitoring")
            create_upgrade_monitoring
            ;;
        "automation")
            create_upgrade_automation
            ;;
        "all"|"")
            analyze_current_cluster
            pre_upgrade_checks
            create_upgrade_plan
            create_cluster_backup
            create_upgrade_monitoring
            create_upgrade_automation
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze      - Analyze current cluster state"
            echo "  pre-check    - Run pre-upgrade checks"
            echo "  plan         - Create upgrade plan"
            echo "  backup       - Create cluster backup"
            echo "  monitoring   - Create upgrade monitoring tools"
            echo "  automation   - Create upgrade automation scripts"
            echo "  all          - Create all upgrade tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 analyze"
            echo "  $0 backup"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x cluster-upgrade-implementation.sh

# Запустить создание upgrade framework
./cluster-upgrade-implementation.sh all
```

## 📋 **Стратегии обновления:**

### **Типы обновлений:**

| **Тип** | **Описание** | **Риск** | **Время простоя** |
|---------|--------------|----------|-------------------|
| **Patch** | Исправления безопасности | Низкий | Минимальное |
| **Minor** | Новые функции | Средний | Короткое |
| **Major** | Кардинальные изменения | Высокий | Значительное |
| **Rolling** | Поэтапное обновление | Низкий | Нулевое |

### **Порядок обновления:**

#### **1. Control Plane First:**
```bash
# Последовательность обновления control plane
1. etcd backup
2. Master node 1 (primary)
3. Master node 2 (secondary)
4. Master node 3 (secondary)
5. Validation between each step
```

#### **2. Worker Nodes:**
```bash
# Rolling update worker nodes
for node in $(kubectl get nodes -o name); do
  kubectl drain $node --ignore-daemonsets
  # Upgrade node
  kubectl uncordon $node
  # Verify health
done
```

## 🎯 **Практические команды:**

### **Подготовка к обновлению:**
```bash
# Создать upgrade framework
./cluster-upgrade-implementation.sh all

# Анализ текущего состояния
./cluster-upgrade-implementation.sh analyze

# Pre-upgrade проверки
./cluster-upgrade-implementation.sh pre-check

# Создать backup
./cluster-upgrade-implementation.sh backup
```

### **Мониторинг обновления:**
```bash
# Запустить мониторинг
./cluster-upgrade-monitor.sh continuous

# Проверить здоровье кластера
./cluster-upgrade-monitor.sh health

# Проверить критические приложения
./cluster-upgrade-monitor.sh apps
```

### **Управление узлами:**
```bash
# Drain node для обновления
kubectl drain node-name --ignore-daemonsets --delete-emptydir-data

# Проверить статус узла
kubectl get nodes

# Uncordon node после обновления
kubectl uncordon node-name
```

## 🔧 **Best Practices для обновлений:**

### **Планирование:**
- **Staging testing** - тестирование в staging среде
- **Maintenance window** - планирование окна обслуживания
- **Rollback plan** - план отката
- **Communication** - уведомление заинтересованных сторон

### **Выполнение:**
- **Incremental upgrades** - поэтапные обновления
- **Health monitoring** - мониторинг здоровья
- **Automated validation** - автоматическая валидация
- **Documentation** - документирование процесса

### **Безопасность:**
- **Backup everything** - резервное копирование всего
- **Test rollback** - тестирование отката
- **Monitor metrics** - мониторинг метрик
- **Validate functionality** - проверка функциональности

### **Автоматизация:**
- **CI/CD integration** - интеграция с CI/CD
- **Infrastructure as Code** - управление через код
- **Automated testing** - автоматическое тестирование
- **Rollback automation** - автоматический откат

**Безопасные обновления кластера - ключ к стабильной работе Kubernetes!**
