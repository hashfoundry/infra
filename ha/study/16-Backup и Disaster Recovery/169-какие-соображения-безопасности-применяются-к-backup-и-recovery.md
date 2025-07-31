# 169. Какие соображения безопасности применяются к backup и recovery?

## 🎯 **Что такое backup security?**

**Backup security** — это комплексная система защиты резервных копий, включающая encryption at rest и in transit, access control, immutable storage, anti-ransomware protection, audit logging, compliance management, threat detection, secure deletion и защиту backup инфраструктуры от компрометации на всех этапах жизненного цикла данных.

## 🏗️ **Основные компоненты backup security:**

### **1. Security Layers**
- **Encryption**: AES-256 шифрование данных в покое и при передаче
- **Access Control**: RBAC, MFA, privileged access management
- **Network Security**: Isolation, VPN, private endpoints
- **Threat Protection**: Anti-ransomware, malware scanning, anomaly detection
- **Compliance**: Audit trails, retention policies, regulatory compliance

### **2. Security Architecture**
- **Defense in Depth**: Многоуровневая защита backup системы
- **Zero Trust**: Проверка всех доступов к backup данным
- **Immutable Storage**: Write-once-read-many backup хранилище
- **Air-gapped Backups**: Физически изолированные копии данных

### **3. Threat Landscape**
- **Ransomware**: Шифрование и удаление backup злоумышленниками
- **Data Exfiltration**: Кража sensitive данных из backup
- **Insider Threats**: Злоумышленные действия внутренних пользователей
- **Supply Chain Attacks**: Компрометация backup инфраструктуры

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей backup security:**
```bash
# Проверка шифрования backup
kubectl get secrets -n velero | grep -E "(encryption|tls|cert)"
velero backup describe $(velero backup get -o name | head -1) | grep -i encrypt

# Анализ RBAC для backup операций
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name | contains("backup") or contains("velero")) | "\(.metadata.name): \(.subjects[].name) -> \(.roleRef.name)"'

# Проверка network policies для backup
kubectl get networkpolicies -n velero -o yaml

# Аудит backup storage locations
velero backup-location get -o json | jq -r '.items[] | "\(.metadata.name): \(.spec.provider) (\(.status.phase))"'
```

### **2. Диагностика security проблем:**
```bash
# Поиск незашифрованных backup
velero backup get -o json | jq -r '.items[] | select(.spec.storageLocation | contains("unencrypted") or (.metadata.labels.encrypted // "false") == "false") | .metadata.name'

# Проверка suspicious backup activity
kubectl get events --all-namespaces --field-selector type=Warning | grep -i backup | tail -10

# Анализ failed authentication attempts
kubectl logs -n velero deployment/velero | grep -i "auth\|permission\|denied" | tail -20

# Проверка backup integrity violations
aws s3api list-objects-v2 --bucket hashfoundry-backup --query 'Contents[?LastModified>`2024-01-01`]' --output table 2>/dev/null || echo "AWS CLI not configured"
```

### **3. Мониторинг security метрик:**
```bash
# Проверка encryption status всех backup
kubectl get backups -n velero -o json | jq -r 'group_by(.metadata.labels.encrypted // "unknown") | map({encrypted: .[0].metadata.labels.encrypted // "unknown", count: length}) | .[]'

# Анализ access patterns
kubectl get events --field-selector involvedObject.kind=Backup | awk '{print $1, $5, $6}' | sort | uniq -c

# Проверка compliance status
velero backup get -o json | jq -r '.items[] | select(.metadata.annotations["compliance.required"] == "true") | "\(.metadata.name): \(.metadata.annotations["retention.policy"] // "undefined")"'
```

## 🔄 **Демонстрация comprehensive backup security:**

### **1. Создание secure backup framework:**
```bash
# Создать скрипт backup-security-manager.sh
cat << 'EOF' > backup-security-manager.sh
#!/bin/bash

echo "🔐 Comprehensive Backup Security Manager"
echo "======================================="

# Настройка переменных
VELERO_NAMESPACE="velero"
MONITORING_NAMESPACE="monitoring"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SECURITY_LOG="/var/log/backup-security-$TIMESTAMP.log"

# Encryption configurations
ENCRYPTION_ALGORITHM="AES-256-GCM"
KEY_ROTATION_DAYS=90
BACKUP_RETENTION_DAYS=2555  # 7 years for compliance

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $SECURITY_LOG
}

# Функция анализа security posture
analyze_backup_security_posture() {
    log "🔍 Анализ backup security posture"
    
    local security_report="/tmp/backup-security-analysis-$TIMESTAMP.json"
    
    # Comprehensive security assessment
    cat > $security_report << SECURITY_ANALYSIS_EOF
{
  "analysis_timestamp": "$(date -Iseconds)",
  "cluster_context": "$(kubectl config current-context)",
  "security_assessment": {
    "encryption_status": {
$(velero backup get -o json | jq -r '
    group_by(.metadata.labels.encrypted // "unknown") | 
    map({
      encryption_status: .[0].metadata.labels.encrypted // "unknown",
      count: length,
      backup_names: [.[].metadata.name],
      total_size_estimate: ([.[].status.progress.totalItems // 0] | add)
    })[] | 
    "      \"\(.encryption_status)\": {\"count\": \(.count), \"total_items\": \(.total_size_estimate), \"backups\": \(.backup_names)}"
' | paste -sd, -)
    },
    "access_control": {
      "rbac_bindings": $(kubectl get clusterrolebindings -o json | jq '[.items[] | select(.roleRef.name | contains("backup") or contains("velero")) | {name: .metadata.name, subjects: .subjects, role: .roleRef.name}]'),
      "service_accounts": $(kubectl get serviceaccounts -n $VELERO_NAMESPACE -o json | jq '[.items[] | {name: .metadata.name, secrets: .secrets}]'),
      "network_policies": $(kubectl get networkpolicies -n $VELERO_NAMESPACE -o json | jq '[.items[] | {name: .metadata.name, spec: .spec}]')
    },
    "storage_security": {
$(kubectl get backupstoragelocations -n $VELERO_NAMESPACE -o json | jq -r '
    .items[] | 
    {
      name: .metadata.name,
      provider: .spec.provider,
      encryption_config: .spec.config.serverSideEncryption // "none",
      access_mode: .spec.accessMode,
      status: .status.phase
    } | 
    "      \"\(.name)\": {\"provider\": \"\(.provider)\", \"encryption\": \"\(.encryption_config)\", \"access_mode\": \"\(.access_mode)\", \"status\": \"\(.status)\"}"
' | paste -sd, -)
    },
    "compliance_status": {
$(velero backup get -o json | jq -r '
    group_by(.metadata.annotations["compliance.required"] // "unknown") | 
    map({
      compliance_required: .[0].metadata.annotations["compliance.required"] // "unknown",
      count: length,
      retention_policies: [.[].metadata.annotations["retention.policy"] // "undefined"] | unique
    })[] | 
    "      \"\(.compliance_required)\": {\"count\": \(.count), \"retention_policies\": \(.retention_policies)}"
' | paste -sd, -)
    }
  },
  "security_recommendations": [
$(velero backup get -o json | jq -r '
    .items[] | 
    select((.metadata.labels.encrypted // "false") == "false") |
    "    \"Encrypt backup: \(.metadata.name)\""
' | paste -sd, -)
  ]
}
SECURITY_ANALYSIS_EOF
    
    log "📄 Security analysis сохранен в $security_report"
    
    # Краткая статистика
    local total_backups=$(velero backup get -o json | jq '.items | length')
    local encrypted_backups=$(velero backup get -o json | jq '[.items[] | select((.metadata.labels.encrypted // "false") == "true")] | length')
    local compliance_backups=$(velero backup get -o json | jq '[.items[] | select(.metadata.annotations["compliance.required"] == "true")] | length')
    
    log "🔐 Security статистика:"
    log "  📦 Всего backup: $total_backups"
    log "  🔒 Зашифрованных: $encrypted_backups"
    log "  📋 Compliance: $compliance_backups"
    
    return 0
}

# Функция создания encryption framework
create_encryption_framework() {
    log "🔐 Создание encryption framework"
    
    # Генерация master encryption key
    local master_key=$(openssl rand -hex 32)
    local key_id="backup-master-key-$(date +%s)"
    
    # Создание encryption secrets
    kubectl apply -f - << ENCRYPTION_SECRETS_EOF
apiVersion: v1
kind: Secret
metadata:
  name: backup-encryption-keys
  namespace: $VELERO_NAMESPACE
  labels:
    component: backup-security
    encryption: master-key
type: Opaque
data:
  master-key: $(echo -n "$master_key" | base64 -w 0)
  key-id: $(echo -n "$key_id" | base64 -w 0)
  algorithm: $(echo -n "$ENCRYPTION_ALGORITHM" | base64 -w 0)
  created: $(echo -n "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | base64 -w 0)
---
apiVersion: v1
kind: Secret
metadata:
  name: backup-tls-certificates
  namespace: $VELERO_NAMESPACE
  labels:
    component: backup-security
    encryption: transport
type: kubernetes.io/tls
data:
  tls.crt: $(openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/backup.key -out /tmp/backup.crt -subj "/CN=backup.hashfoundry.local" && cat /tmp/backup.crt | base64 -w 0)
  tls.key: $(cat /tmp/backup.key | base64 -w 0)
ENCRYPTION_SECRETS_EOF
    
    # Создание encrypted storage locations
    kubectl apply -f - << ENCRYPTED_STORAGE_EOF
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: encrypted-primary-storage
  namespace: $VELERO_NAMESPACE
  labels:
    security-tier: "high"
    encryption: "enabled"
spec:
  provider: aws
  objectStorage:
    bucket: hashfoundry-backup-encrypted
    prefix: encrypted-primary
  config:
    region: fra1
    serverSideEncryption: AES256
    kmsKeyId: arn:aws:kms:fra1:123456789012:key/backup-encryption-key
    s3ForcePathStyle: "false"
  accessMode: ReadWrite
---
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: immutable-compliance-storage
  namespace: $VELERO_NAMESPACE
  labels:
    security-tier: "maximum"
    encryption: "enabled"
    compliance: "required"
spec:
  provider: aws
  objectStorage:
    bucket: hashfoundry-backup-immutable
    prefix: compliance-backups
  config:
    region: fra1
    serverSideEncryption: AES256
    kmsKeyId: arn:aws:kms:fra1:123456789012:key/compliance-encryption-key
    objectLockEnabled: "true"
    objectLockRetentionMode: "GOVERNANCE"
    objectLockRetentionDays: "$BACKUP_RETENTION_DAYS"
  accessMode: ReadOnly
ENCRYPTED_STORAGE_EOF
    
    log "✅ Encryption framework создан"
}

# Функция создания access control
create_access_control_framework() {
    log "🛡️ Создание access control framework"
    
    kubectl apply -f - << ACCESS_CONTROL_EOF
# Backup Security ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backup-security-operator
  namespace: $VELERO_NAMESPACE
  labels:
    component: backup-security
---
# Backup Admin Role (Full Access)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-admin
  labels:
    component: backup-security
rules:
- apiGroups: ["velero.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
  resourceNames: ["backup-encryption-keys", "cloud-credentials", "backup-tls-certificates"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["*"]
  verbs: ["*"]
---
# Backup Operator Role (Limited Access)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-operator
  labels:
    component: backup-security
rules:
- apiGroups: ["velero.io"]
  resources: ["backups", "restores", "schedules"]
  verbs: ["create", "get", "list", "watch", "update", "patch"]
- apiGroups: ["velero.io"]
  resources: ["backups"]
  verbs: ["delete"]
  resourceNames: []  # Specific backup names only
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
---
# Backup Viewer Role (Read-Only)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-viewer
  labels:
    component: backup-security
rules:
- apiGroups: ["velero.io"]
  resources: ["backups", "restores", "schedules", "backupstoragelocations"]
  verbs: ["get", "list", "watch"]
---
# Emergency Backup Role (Break-Glass Access)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-emergency
  labels:
    component: backup-security
    emergency: "true"
rules:
- apiGroups: ["velero.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
---
# Production Backup Access
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backup-production-access
  namespace: production
  labels:
    component: backup-security
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backup-operator
subjects:
- kind: ServiceAccount
  name: backup-security-operator
  namespace: $VELERO_NAMESPACE
---
# Network Security Policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backup-network-security
  namespace: $VELERO_NAMESPACE
  labels:
    component: backup-security
spec:
  podSelector:
    matchLabels:
      app: velero
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 8080  # Metrics
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443   # HTTPS to cloud storage
    - protocol: TCP
      port: 53    # DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53    # DNS
ACCESS_CONTROL_EOF
    
    log "✅ Access control framework создан"
}

# Функция создания threat protection
create_threat_protection_framework() {
    log "🚨 Создание threat protection framework"
    
    kubectl apply -f - << THREAT_PROTECTION_EOF
# Anti-Ransomware Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-threat-protection
  namespace: $VELERO_NAMESPACE
  labels:
    component: backup-security
data:
  threat-protection-config.yaml: |
    threat_protection:
      anti_ransomware:
        enabled: true
        immutable_backups: true
        air_gapped_copies: true
        anomaly_detection: true
        rapid_backup_detection_threshold: 10  # backups per hour
        mass_deletion_threshold: 5  # deletions per day
      
      malware_protection:
        enabled: true
        scan_on_restore: true
        quarantine_suspicious: true
        scan_engines: ["clamav", "defender"]
      
      access_monitoring:
        enabled: true
        failed_auth_threshold: 3
        privilege_escalation_detection: true
        unusual_access_pattern_detection: true
      
      compliance_enforcement:
        enabled: true
        retention_policy_enforcement: true
        encryption_requirement: true
        audit_trail_requirement: true
---
# Backup Monitoring Rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backup-security-monitoring
  namespace: $MONITORING_NAMESPACE
  labels:
    component: backup-security
spec:
  groups:
  - name: backup-security
    rules:
    - alert: BackupRansomwareActivity
      expr: increase(backup_creation_rate[1h]) > 10
      for: 5m
      labels:
        severity: critical
        component: backup-security
        threat: ransomware
      annotations:
        summary: "Potential ransomware activity detected"
        description: "Unusual backup creation rate: {{ \$value }} backups in 1 hour"
    
    - alert: BackupMassDeletion
      expr: increase(backup_deletion_rate[1d]) > 5
      for: 0m
      labels:
        severity: critical
        component: backup-security
        threat: ransomware
      annotations:
        summary: "Mass backup deletion detected"
        description: "{{ \$value }} backups deleted in 24 hours"
    
    - alert: BackupEncryptionFailure
      expr: backup_encryption_failures_total > 0
      for: 0m
      labels:
        severity: warning
        component: backup-security
      annotations:
        summary: "Backup encryption failure"
        description: "{{ \$value }} backup encryption failures detected"
    
    - alert: BackupUnauthorizedAccess
      expr: backup_unauthorized_access_attempts_total > 3
      for: 5m
      labels:
        severity: warning
        component: backup-security
        threat: unauthorized-access
      annotations:
        summary: "Unauthorized backup access attempts"
        description: "{{ \$value }} unauthorized access attempts to backup system"
    
    - alert: BackupIntegrityViolation
      expr: backup_integrity_check_failures_total > 0
      for: 0m
      labels:
        severity: critical
        component: backup-security
        threat: data-corruption
      annotations:
        summary: "Backup integrity violation"
        description: "{{ \$value }} backup integrity check failures"
    
    - alert: BackupComplianceViolation
      expr: backup_compliance_violations_total > 0
      for: 0m
      labels:
        severity: warning
        component: backup-security
        compliance: violation
      annotations:
        summary: "Backup compliance violation"
        description: "{{ \$value }} backup compliance violations detected"
THREAT_PROTECTION_EOF
    
    log "✅ Threat protection framework создан"
}

# Функция automated security scanning
execute_security_scanning() {
    log "🔍 Выполнение automated security scanning"
    
    local scan_results="/tmp/backup-security-scan-$TIMESTAMP.json"
    local threats_detected=0
    
    # Сканирование на ransomware индикаторы
    log "🦠 Сканирование на ransomware индикаторы"
    
    # Проверка аномальной backup активности
    local recent_backups=$(velero backup get -o json | \
        jq --arg since "$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ)" \
        '[.items[] | select(.metadata.creationTimestamp > $since)] | length')
    
    if [ $recent_backups -gt 10 ]; then
        log "⚠️ THREAT: Аномальная backup активность - $recent_backups backup за час"
        threats_detected=$((threats_detected + 1))
        trigger_security_alert "ransomware_activity" "excessive_backup_creation:$recent_backups"
    fi
    
    # Проверка mass deletion events
    local recent_deletions=$(grep "backup.*delete" /var/log/velero.log 2>/dev/null | \
        grep "$(date +%Y-%m-%d)" | wc -l || echo "0")
    
    if [ $recent_deletions -gt 5 ]; then
        log "⚠️ THREAT: Mass deletion detected - $recent_deletions удалений"
        threats_detected=$((threats_detected + 1))
        trigger_security_alert "mass_deletion" "backup_deletions:$recent_deletions"
    fi
    
    # Проверка unauthorized access attempts
    local auth_failures=$(kubectl get events --field-selector type=Warning | \
        grep -i "auth\|permission\|denied" | \
        grep "$(date +%Y-%m-%d)" | wc -l)
    
    if [ $auth_failures -gt 3 ]; then
        log "⚠️ THREAT: Unauthorized access attempts - $auth_failures попыток"
        threats_detected=$((threats_detected + 1))
        trigger_security_alert "unauthorized_access" "auth_failures:$auth_failures"
    fi
    
    # Проверка encryption compliance
    local unencrypted_backups=$(velero backup get -o json | \
        jq '[.items[] | select((.metadata.labels.encrypted // "false") == "false")] | length')
    
    if [ $unencrypted_backups -gt 0 ]; then
        log "⚠️ COMPLIANCE: Незашифрованные backup - $unencrypted_backups штук"
        threats_detected=$((threats_detected + 1))
        trigger_security_alert "encryption_compliance" "unencrypted_backups:$unencrypted_backups"
    fi
    
    # Создание scan report
    cat > $scan_results << SCAN_REPORT_EOF
{
  "scan_timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "security_scan_results": {
    "threats_detected": $threats_detected,
    "ransomware_indicators": {
      "excessive_backup_creation": $recent_backups,
      "mass_deletions": $recent_deletions,
      "risk_level": "$(if [ $recent_backups -gt 10 ] || [ $recent_deletions -gt 5 ]; then echo "high"; elif [ $recent_backups -gt 5 ] || [ $recent_deletions -gt 2 ]; then echo "medium"; else echo "low"; fi)"
    },
    "access_security": {
      "auth_failures": $auth_failures,
      "unauthorized_attempts": "$(if [ $auth_failures -gt 3 ]; then echo "detected"; else echo "none"; fi)"
    },
    "compliance_status": {
      "unencrypted_backups": $unencrypted_backups,
      "encryption_compliance": "$(if [ $unencrypted_backups -eq 0 ]; then echo "compliant"; else echo "violation"; fi)"
    }
  },
  "recommendations": [
$(if [ $recent_backups -gt 10 ]; then echo '    "Investigate excessive backup creation activity",'; fi)
$(if [ $recent_deletions -gt 5 ]; then echo '    "Review mass deletion events for potential ransomware",'; fi)
$(if [ $auth_failures -gt 3 ]; then echo '    "Strengthen access controls and investigate auth failures",'; fi)
$(if [ $unencrypted_backups -gt 0 ]; then echo '    "Encrypt all backup data to meet compliance requirements",'; fi)
    "Continue regular security monitoring"
  ]
}
SCAN_REPORT_EOF
    
    log "📄 Security scan report: $scan_results"
    log "🎯 Threats detected: $threats_detected"
    
    return $threats_detected
}

# Функция создания compliance framework
create_compliance_framework() {
    log "📋 Создание compliance framework"
    
    kubectl apply -f - << COMPLIANCE_FRAMEWORK_EOF
# Compliance Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-compliance-config
  namespace: $VELERO_NAMESPACE
  labels:
    component: backup-security
    compliance: required
data:
  compliance-policies.yaml: |
    compliance_policies:
      gdpr:
        enabled: true
        data_retention_days: 2555  # 7 years
        encryption_required: true
        right_to_erasure: true
        data_portability: true
        audit_trail_required: true
      
      sox:
        enabled: true
        financial_data_retention_days: 2555  # 7 years
        immutable_storage_required: true
        access_controls_required: true
        change_management_required: true
      
      hipaa:
        enabled: false  # Enable if healthcare data
        phi_encryption_required: true
        access_logging_required: true
        breach_notification_required: true
      
      pci_dss:
        enabled: false  # Enable if payment data
        cardholder_data_protection: true
        access_restriction_required: true
        vulnerability_management: true
---
# Compliance Monitoring
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-compliance-audit
  namespace: $VELERO_NAMESPACE
  labels:
    component: backup-security
    compliance: audit
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: backup-security-operator
          containers:
          - name: compliance-auditor
            image: alpine/curl:latest
            command:
            - /bin/sh
            - -c
            - |
              echo "Running backup compliance audit..."
              
              # Check encryption compliance
              UNENCRYPTED=\$(kubectl get backups -n velero -o json | jq '[.items[] | select((.metadata.labels.encrypted // "false") == "false")] | length')
              
              # Check retention compliance
              EXPIRED=\$(kubectl get backups -n velero -o json | jq --arg cutoff "\$(date -d '7 years ago' -u +%Y-%m-%dT%H:%M:%SZ)" '[.items[] | select(.metadata.creationTimestamp < \$cutoff)] | length')
              
              # Generate compliance report
              cat > /tmp/compliance-report.json << EOF
              {
                "audit_date": "\$(date -u +%Y-%m-%dT%H:%M:%SZ)",
                "compliance_status": {
                  "encryption_violations": \$UNENCRYPTED,
                  "retention_violations": \$EXPIRED,
                  "overall_status": "\$(if [ \$UNENCRYPTED -eq 0 ] && [ \$EXPIRED -eq 0 ]; then echo "compliant"; else echo "violations_detected"; fi)"
                }
              }
              EOF
              
              echo "Compliance audit completed"
          restartPolicy: OnFailure
COMPLIANCE_FRAMEWORK_EOF
    
    log "✅ Compliance framework создан"
}

# Функция триггера security alerts
trigger_security_alert() {
    local alert_type=$1
    local details=$2
    
    log "🚨 SECURITY ALERT: $alert_type - $details"
    
    # Создание Kubernetes Event
    kubectl create event backup-security-alert-$(date +%s) \
        --type=Warning \
        --reason="BackupSecurityAlert" \
        --message="Security alert: $alert_type - $details" \
        --namespace=$VELERO_NAMESPACE
    
    # Отправка в monitoring system
    if command -v curl &> /dev/null && [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\":\"🚨 BACKUP SECURITY ALERT\",
                \"attachments\":[{
                    \"color\":\"danger\",
                    \"fields\":[{
                        \"title\":\"Alert Type\",
                        \"value\":\"$alert_type\",
                        \"short\":true
                    },{
                        \"title\":\"Details\",
                        \"value\":\"$details\",
                        \"short\":true
                    },{
                        \"title\":\"Cluster\",
                        \"value\":\"$(kubectl config current-context)\",
                        \"short\":true
                    },{
                        \"title\":\"Timestamp\",
                        \"value\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                        \"short\":true
                    }]
                }]
            }" \
            "$SLACK_WEBHOOK_URL"
    fi
    
    # Создание audit записи
    cat >> /var/log/backup-security-alerts.audit << AUDIT_EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "alert_type": "$alert_type",
  "details": "$details",
  "cluster": "$(kubectl config current-context)",
  "severity": "high"
}
AUDIT_EOF
}

# Основная логика выполнения
main() {
    case "$1" in
        analyze)
            analyze_backup_security_posture
            ;;
        encryption)
            create_encryption_framework
            ;;
        access-control)
            create_access_control_framework
            ;;
        threat-protection)
            create_threat_protection_framework
            ;;
        scan)
            execute_security_scanning
            ;;
        compliance)
            create_compliance_framework
            ;;
        full)
            log "🚀 Запуск полного backup security framework"
            analyze_backup_security_posture
            create_encryption_framework
            create_access_control_framework
            create_threat_protection_framework
            execute_security_scanning
            create_compliance_framework
            log "🎉 Backup security framework настроен!"
            ;;
        *)
            echo "Использование: $0 {analyze|encryption|access-control|threat-protection|scan|compliance|full}"
            echo "  analyze          - Анализ security posture"
            echo "  encryption       - Создание encryption framework"
            echo "  access-control   - Создание access control"
            echo "  threat-protection - Создание threat protection"
            echo "  scan            - Security scanning"
            echo "  compliance      - Compliance framework"
            echo "  full            - Полная настройка security"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в backup security manager"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x backup-security-manager.sh
```

### **2. Создание incident response framework:**
```bash
# Создать скрипт backup-incident-response.sh
cat << 'EOF' > backup-incident-response.sh
#!/bin/bash

echo "🚨 Backup Security Incident Response"
echo "===================================="

# Настройка переменных
INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"
INCIDENT_LOG="/var/log/backup-incidents-$INCIDENT_ID.log"
QUARANTINE_NAMESPACE="backup-quarantine"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $INCIDENT_LOG
}

# Функция ransomware response
ransomware_incident_response() {
    log "🚨 RANSOMWARE INCIDENT RESPONSE ACTIVATED"
    
    # Немедленная изоляция backup системы
    log "🔒 Изоляция backup системы"
    
    # Блокировка всех backup операций
    kubectl patch deployment velero -n velero -p '{"spec":{"replicas":0}}'
    
    # Создание emergency backup перед изоляцией
    log "📦 Создание emergency backup"
    velero backup create emergency-backup-$(date +%s) \
        --storage-location immutable-compliance-storage \
        --wait --timeout 10m
    
    # Изоляция network traffic
    kubectl apply -f - << ISOLATION_POLICY_EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backup-emergency-isolation
  namespace: velero
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  # Блокировка всего трафика
ISOLATION_POLICY_EOF
    
    # Создание forensic snapshot
    create_forensic_snapshot
    
    # Уведомление security team
    notify_security_team "ransomware_detected" "Backup system isolated"
    
    log "✅ Ransomware response completed"
}

# Функция создания forensic snapshot
create_forensic_snapshot() {
    log "🔍 Создание forensic snapshot"
    
    # Snapshot всех backup PVs
    kubectl get pv -l backup-storage=true -o json | \
        jq -r '.items[].metadata.name' | \
        while read pv_name; do
            log "📸 Forensic snapshot: $pv_name"
            
            kubectl apply -f - << FORENSIC_SNAPSHOT_EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: forensic-${pv_name}-$(date +%s)
  namespace: velero
  labels:
    forensic: "true"
    incident-id: "$INCIDENT_ID"
spec:
  source:
    persistentVolumeClaimName: $pv_name
  volumeSnapshotClassName: csi-do-snapshots
FORENSIC_SNAPSHOT_EOF
        done
    
    log "✅ Forensic snapshots созданы"
}

# Функция data breach response
data_breach_incident_response() {
    local breach_type=$1
    
    log "🚨 DATA BREACH INCIDENT RESPONSE: $breach_type"
    
    # Немедленная ротация всех credentials
    log "🔑 Ротация credentials"
    
    # Ротация cloud credentials
    rotate_cloud_credentials
    
    # Ротация encryption keys
    rotate_encryption_keys
    
    # Audit всех access logs
    audit_access_logs
    
    # Создание breach report
    create_breach_report "$breach_type"
    
    log "✅ Data breach response completed"
}

# Функция ротации cloud credentials
rotate_cloud_credentials() {
    log "🔄 Ротация cloud credentials"
    
    # Создание новых AWS credentials
    local new_access_key=$(aws iam create-access-key --user-name velero-backup-user \
        --query 'AccessKey.AccessKeyId' --output text 2>/dev/null || echo "manual-rotation-required")
    
    if [ "$new_access_key" != "manual-rotation-required" ]; then
        local new_secret_key=$(aws iam create-access-key --user-name velero-backup-user \
            --query 'AccessKey.SecretAccessKey' --output text)
        
        # Обновление Kubernetes Secret
        kubectl create secret generic cloud-credentials \
            --from-literal=cloud="[default]
aws_access_key_id=$new_access_key
aws_secret_access_key=$new_secret_key" \
            --namespace=velero \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log "✅ Cloud credentials обновлены"
    else
        log "⚠️ Manual cloud credentials rotation required"
    fi
}

# Функция ротации encryption keys
rotate_encryption_keys() {
    log "🔐 Ротация encryption keys"
    
    # Генерация нового master key
    local new_master_key=$(openssl rand -hex 32)
    local new_key_id="emergency-key-$(date +%s)"
    
    # Создание нового encryption secret
    kubectl create secret generic backup-encryption-keys-emergency \
        --from-literal=master-key="$new_master_key" \
        --from-literal=key-id="$new_key_id" \
        --from-literal=created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --namespace=velero
    
    # Backup старого ключа для recovery
    kubectl get secret backup-encryption-keys -n velero -o yaml > \
        /tmp/old-encryption-keys-$INCIDENT_ID.yaml
    
    # Замена активного ключа
    kubectl delete secret backup-encryption-keys -n velero
    kubectl create secret generic backup-encryption-keys \
        --from-literal=master-key="$new_master_key" \
        --from-literal=key-id="$new_key_id" \
        --from-literal=created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --namespace=velero
    
    log "✅ Encryption keys обновлены"
}

# Функция audit access logs
audit_access_logs() {
    log "📊 Audit access logs"
    
    local audit_report="/tmp/backup-access-audit-$INCIDENT_ID.json"
    
    # Анализ Kubernetes audit logs
    local suspicious_access=$(kubectl get events --all-namespaces \
        --field-selector type=Warning | \
        grep -E "(backup|velero)" | \
        grep "$(date +%Y-%m-%d)" | wc -l)
    
    # Анализ Velero logs
    local velero_errors=$(kubectl logs -n velero deployment/velero --since=24h | \
        grep -i "error\|denied\|unauthorized" | wc -l)
    
    # Создание audit report
    cat > $audit_report << AUDIT_REPORT_EOF
{
  "incident_id": "$INCIDENT_ID",
  "audit_timestamp": "$(date -Iseconds)",
  "access_audit": {
    "suspicious_kubernetes_events": $suspicious_access,
    "velero_errors": $velero_errors,
    "recent_backup_operations": $(velero backup get -o json | jq --arg since "$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ)" '[.items[] | select(.metadata.creationTimestamp > $since)] | length'),
    "recent_restore_operations": $(velero restore get -o json | jq --arg since "$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ)" '[.items[] | select(.metadata.creationTimestamp > $since)] | length')
  },
  "rbac_analysis": {
    "backup_role_bindings": $(kubectl get clusterrolebindings -o json | jq '[.items[] | select(.roleRef.name | contains("backup")) | {name: .metadata.name, subjects: .subjects}]'),
    "velero_service_accounts": $(kubectl get serviceaccounts -n velero -o json | jq '[.items[] | {name: .metadata.name, secrets: .secrets}]')
  }
}
AUDIT_REPORT_EOF
    
    log "📄 Access audit report: $audit_report"
}

# Функция создания breach report
create_breach_report() {
    local breach_type=$1
    
    log "📋 Создание breach report"
    
    local breach_report="/tmp/backup-breach-report-$INCIDENT_ID.json"
    
    cat > $breach_report << BREACH_REPORT_EOF
{
  "incident_id": "$INCIDENT_ID",
  "breach_type": "$breach_type",
  "detection_timestamp": "$(date -Iseconds)",
  "affected_systems": {
    "backup_storage_locations": $(kubectl get backupstoragelocations -n velero -o json | jq '[.items[] | {name: .metadata.name, provider: .spec.provider}]'),
    "backup_count": $(velero backup get -o json | jq '.items | length'),
    "encrypted_backups": $(velero backup get -o json | jq '[.items[] | select((.metadata.labels.encrypted // "false") == "true")] | length')
  },
  "response_actions": [
    "Isolated backup system",
    "Rotated all credentials",
    "Created forensic snapshots",
    "Audited access logs",
    "Notified security team"
  ],
  "compliance_notifications": {
    "gdpr_notification_required": true,
    "sox_notification_required": true,
    "notification_deadline": "$(date -d '+72 hours' -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
BREACH_REPORT_EOF
    
    log "📄 Breach report создан: $breach_report"
}

# Функция уведомления security team
notify_security_team() {
    local incident_type=$1
    local details=$2
    
    log "📧 Уведомление security team: $incident_type"
    
    # Отправка в Slack
    if [ -n "$SLACK_SECURITY_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\":\"🚨 BACKUP SECURITY INCIDENT\",
                \"attachments\":[{
                    \"color\":\"danger\",
                    \"fields\":[{
                        \"title\":\"Incident ID\",
                        \"value\":\"$INCIDENT_ID\",
                        \"short\":true
                    },{
                        \"title\":\"Type\",
                        \"value\":\"$incident_type\",
                        \"short\":true
                    },{
                        \"title\":\"Details\",
                        \"value\":\"$details\",
                        \"short\":false
                    },{
                        \"title\":\"Response Status\",
                        \"value\":\"Automated response activated\",
                        \"short\":true
                    }]
                }]
            }" \
            "$SLACK_SECURITY_WEBHOOK"
    fi
    
    # Создание PagerDuty incident
    if [ -n "$PAGERDUTY_API_KEY" ]; then
        curl -X POST \
            -H "Authorization: Token token=$PAGERDUTY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"incident\": {
                    \"type\": \"incident\",
                    \"title\": \"Backup Security Incident: $incident_type\",
                    \"service\": {
                        \"id\": \"$PAGERDUTY_SERVICE_ID\",
                        \"type\": \"service_reference\"
                    },
                    \"urgency\": \"high\",
                    \"body\": {
                        \"type\": \"incident_body\",
                        \"details\": \"Incident ID: $INCIDENT_ID\\nType: $incident_type\\nDetails: $details\"
                    }
                }
            }" \
            "https://api.pagerduty.com/incidents"
    fi
}

# Функция recovery после incident
post_incident_recovery() {
    log "🔄 Post-incident recovery"
    
    # Проверка целостности backup после incident
    log "🔍 Проверка целостности backup"
    
    local integrity_issues=0
    
    velero backup get -o json | jq -r '.items[].metadata.name' | \
        while read backup_name; do
            log "Проверка: $backup_name"
            
            # Проверка backup status
            local backup_status=$(velero backup describe $backup_name | grep "Phase:" | awk '{print $2}')
            
            if [ "$backup_status" != "Completed" ]; then
                log "⚠️ Backup integrity issue: $backup_name ($backup_status)"
                integrity_issues=$((integrity_issues + 1))
            fi
        done
    
    # Восстановление backup операций
    log "🔄 Восстановление backup операций"
    
    # Удаление emergency isolation
    kubectl delete networkpolicy backup-emergency-isolation -n velero --ignore-not-found=true
    
    # Восстановление Velero deployment
    kubectl patch deployment velero -n velero -p '{"spec":{"replicas":1}}'
    
    # Проверка восстановления
    kubectl wait --for=condition=available deployment/velero -n velero --timeout=300s
    
    if [ $? -eq 0 ]; then
        log "✅ Backup система восстановлена"
    else
        log "❌ Ошибка восстановления backup системы"
    fi
    
    # Создание post-incident report
    create_post_incident_report
}

# Функция создания post-incident report
create_post_incident_report() {
    log "📋 Создание post-incident report"
    
    local post_incident_report="/tmp/backup-post-incident-$INCIDENT_ID.json"
    
    cat > $post_incident_report << POST_INCIDENT_EOF
{
  "incident_id": "$INCIDENT_ID",
  "recovery_timestamp": "$(date -Iseconds)",
  "recovery_status": {
    "backup_system_operational": $(kubectl get deployment velero -n velero -o json | jq '.status.readyReplicas > 0'),
    "backup_count_post_incident": $(velero backup get -o json | jq '.items | length'),
    "storage_locations_available": $(kubectl get backupstoragelocations -n velero -o json | jq '[.items[] | select(.status.phase == "Available")] | length')
  },
  "lessons_learned": [
    "Review incident response procedures",
    "Update security monitoring thresholds",
    "Enhance backup encryption policies",
    "Improve access control mechanisms"
  ],
  "action_items": [
    "Conduct security training for operations team",
    "Review and update backup security policies",
    "Implement additional monitoring controls",
    "Schedule regular security assessments"
  ]
}
POST_INCIDENT_EOF
    
    log "📄 Post-incident report: $post_incident_report"
}

# Основная логика выполнения
main() {
    case "$1" in
        ransomware)
            ransomware_incident_response
            ;;
        data-breach)
            data_breach_incident_response "$2"
            ;;
        recovery)
            post_incident_recovery
            ;;
        *)
            echo "Использование: $0 {ransomware|data-breach <type>|recovery}"
            echo "  ransomware    - Ransomware incident response"
            echo "  data-breach   - Data breach incident response"
            echo "  recovery      - Post-incident recovery"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в incident response"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x backup-incident-response.sh
```

## 📊 **Архитектура backup security:**

```
┌─────────────────────────────────────────────────────────────┐
│                 Backup Security Architecture               │
├─────────────────────────────────────────────────────────────┤
│  Security Layers & Protection Mechanisms                   │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │ Encryption  │ Access      │ Network     │ Threat      │  │
│  │ ├── At Rest │ ├── RBAC    │ ├── VPN     │ ├── Anti-   │  │
│  │ ├── Transit │ ├── MFA     │ ├── Private │ │   Ransom  │  │
│  │ ├── Keys    │ ├── PAM     │ ├── Firewall│ ├── Malware │  │
│  │ └── Rotation│ └── Audit   │ └── Isolation│ └── Anomaly │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Compliance & Governance                                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ ├── GDPR (Data Protection & Privacy)                   │ │
│  │ ├── SOX (Financial Data Retention)                     │ │
│  │ ├── HIPAA (Healthcare Data Security)                   │ │
│  │ ├── PCI-DSS (Payment Card Data)                        │ │
│  │ └── Audit Trails & Incident Response                   │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для backup security:**

### **1. Defense in Depth**
- Многоуровневая защита на всех этапах backup lifecycle
- Encryption at rest и in transit для всех backup данных
- Immutable storage для критичных backup
- Air-gapped copies для disaster recovery

### **2. Zero Trust Security**
- Проверка всех доступов к backup системе
- Least privilege access для backup операций
- Continuous monitoring и anomaly detection
- Regular security assessments и penetration testing

### **3. Incident Response**
- Automated threat detection и response
- Forensic capabilities для investigation
- Rapid isolation и containment procedures
- Post-incident analysis и improvement

### **4. Compliance Management**
- Automated compliance monitoring
- Regular audit trails и reporting
- Data retention policy enforcement
- Regulatory notification procedures

**Comprehensive backup security критически важна для защиты от современных угроз, включая ransomware, data breaches и insider threats!**
