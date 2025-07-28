# 169. Какие соображения безопасности применяются к backup и recovery?

## 🎯 Вопрос
Какие соображения безопасности применяются к backup и recovery?

## 💡 Ответ

Безопасность backup и recovery включает шифрование данных в покое и при передаче, контроль доступа к backup, secure deletion, защиту от ransomware, audit logging, compliance с regulations и защиту backup инфраструктуры от компрометации.

### 🏗️ Архитектура безопасности backup

#### 1. **Схема security layers**
```
┌─────────────────────────────────────────────────────────────┐
│                 Backup Security Architecture               │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Encryption  │    │ Access      │    │ Network     │     │
│  │ at Rest &   │    │ Control &   │    │ Security &  │     │
│  │ in Transit  │    │ RBAC        │    │ Isolation   │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Audit &     │    │ Compliance  │    │ Threat      │     │
│  │ Logging     │    │ & Retention │    │ Protection  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Основные принципы безопасности**
```yaml
# Принципы безопасности backup
backup_security_principles:
  confidentiality:
    - "Шифрование данных backup"
    - "Защита ключей шифрования"
    - "Secure key management"
    - "Data masking для sensitive данных"
  
  integrity:
    - "Цифровые подписи backup"
    - "Checksums и hash verification"
    - "Immutable backup storage"
    - "Tamper detection"
  
  availability:
    - "Redundant backup copies"
    - "Geographic distribution"
    - "Disaster recovery procedures"
    - "RTO/RPO guarantees"
  
  accountability:
    - "Comprehensive audit logging"
    - "Access tracking"
    - "Change management"
    - "Compliance reporting"
```

### 📊 Примеры из нашего кластера

#### Проверка security backup:
```bash
# Проверка шифрования backup
kubectl get secrets -n velero | grep encryption
velero backup describe <backup-name> | grep -i encrypt

# Проверка RBAC для backup
kubectl get rolebindings,clusterrolebindings -o wide | grep velero
kubectl auth can-i create backups --as=system:serviceaccount:velero:velero

# Проверка audit logs
kubectl get events --field-selector type=Warning | grep -i backup
```

### 🔐 Шифрование и защита данных

#### 1. **Конфигурация шифрования**
```yaml
# backup-encryption-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: backup-encryption-key
  namespace: velero
type: Opaque
data:
  # AES-256 ключ для шифрования backup (base64 encoded)
  encryption-key: <base64-encoded-key>
---
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: encrypted-backup-storage
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: hashfoundry-backup-encrypted
    prefix: encrypted-backups
  config:
    region: fra1
    # Шифрование на стороне сервера
    serverSideEncryption: AES256
    # KMS ключ для дополнительного шифрования
    kmsKeyId: arn:aws:kms:fra1:123456789012:key/12345678-1234-1234-1234-123456789012
---
# Velero конфигурация с шифрованием
apiVersion: apps/v1
kind: Deployment
metadata:
  name: velero
  namespace: velero
spec:
  template:
    spec:
      containers:
      - name: velero
        image: velero/velero:v1.12.0
        env:
        - name: BACKUP_ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: backup-encryption-key
              key: encryption-key
        args:
        - server
        - --backup-encryption-key-file=/etc/velero/encryption/key
        - --backup-compression=gzip
        volumeMounts:
        - name: encryption-key
          mountPath: /etc/velero/encryption
          readOnly: true
      volumes:
      - name: encryption-key
        secret:
          secretName: backup-encryption-key
```

#### 2. **Скрипт управления шифрованием**
```bash
#!/bin/bash
# backup-encryption-manager.sh

echo "🔐 Управление шифрованием backup"

# Переменные
ENCRYPTION_KEY_FILE="/etc/velero/encryption/key"
BACKUP_BUCKET="hashfoundry-backup-encrypted"
KMS_KEY_ID="arn:aws:kms:fra1:123456789012:key/12345678-1234-1234-1234-123456789012"

# Генерация нового ключа шифрования
generate_encryption_key() {
    echo "🔑 Генерация нового ключа шифрования"
    
    # Генерация 256-bit ключа
    local new_key=$(openssl rand -hex 32)
    
    # Создание Kubernetes Secret
    kubectl create secret generic backup-encryption-key \
        --from-literal=encryption-key="$new_key" \
        --namespace=velero \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Новый ключ шифрования создан"
}

# Ротация ключей шифрования
rotate_encryption_keys() {
    echo "🔄 Ротация ключей шифрования"
    
    # Создание backup текущего ключа
    local current_key=$(kubectl get secret backup-encryption-key -n velero \
        -o jsonpath='{.data.encryption-key}' | base64 -d)
    
    echo "$current_key" > /tmp/old-encryption-key-$(date +%s)
    
    # Генерация нового ключа
    generate_encryption_key
    
    # Пере-шифрование существующих backup с новым ключом
    reencrypt_existing_backups
    
    echo "✅ Ротация ключей завершена"
}

# Пере-шифрование существующих backup
reencrypt_existing_backups() {
    echo "🔄 Пере-шифрование существующих backup"
    
    # Получение списка всех backup
    local backups=$(velero backup get -o json | jq -r '.items[].metadata.name')
    
    for backup in $backups; do
        echo "🔐 Пере-шифрование backup: $backup"
        
        # Создание нового backup с новым ключом
        velero backup create ${backup}-reencrypted \
            --from-backup $backup \
            --storage-location encrypted-backup-storage \
            --wait
        
        # Удаление старого backup после успешного пере-шифрования
        if [ $? -eq 0 ]; then
            velero backup delete $backup --confirm
            echo "✅ Backup $backup пере-шифрован"
        else
            echo "❌ Ошибка пере-шифрования backup $backup"
        fi
    done
}

# Проверка целостности шифрования
verify_encryption_integrity() {
    echo "🔍 Проверка целостности шифрования"
    
    # Проверка наличия ключей шифрования
    if ! kubectl get secret backup-encryption-key -n velero &>/dev/null; then
        echo "❌ Ключ шифрования не найден"
        return 1
    fi
    
    # Проверка шифрования в S3
    local encrypted_objects=$(aws s3api list-objects-v2 \
        --bucket $BACKUP_BUCKET \
        --query 'Contents[?ServerSideEncryption==`AES256`]' \
        --output text | wc -l)
    
    local total_objects=$(aws s3api list-objects-v2 \
        --bucket $BACKUP_BUCKET \
        --query 'Contents' \
        --output text | wc -l)
    
    if [ $encrypted_objects -eq $total_objects ]; then
        echo "✅ Все объекты в S3 зашифрованы"
    else
        echo "⚠️ Найдены незашифрованные объекты: $((total_objects - encrypted_objects))"
    fi
    
    # Проверка KMS ключей
    aws kms describe-key --key-id $KMS_KEY_ID &>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ KMS ключ доступен"
    else
        echo "❌ KMS ключ недоступен"
    fi
}

# Secure deletion backup
secure_delete_backup() {
    local backup_name=$1
    
    echo "🗑️ Secure deletion backup: $backup_name"
    
    # Получение информации о backup
    local backup_info=$(velero backup describe $backup_name --details)
    local storage_location=$(echo "$backup_info" | grep "Storage Location:" | awk '{print $3}')
    
    # Удаление backup через Velero
    velero backup delete $backup_name --confirm
    
    # Дополнительная очистка в S3 (если необходимо)
    local s3_prefix=$(echo "$backup_info" | grep "Object Storage Prefix:" | awk '{print $4}')
    if [ -n "$s3_prefix" ]; then
        aws s3 rm s3://$BACKUP_BUCKET/$s3_prefix/$backup_name --recursive
    fi
    
    # Создание audit записи
    cat >> /var/log/backup-secure-deletions.audit << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "action": "secure_backup_deletion",
  "backup_name": "$backup_name",
  "storage_location": "$storage_location",
  "deleted_by": "$(whoami)",
  "method": "secure_deletion"
}
EOF
    
    echo "✅ Secure deletion завершено для $backup_name"
}

# Основная логика
case "$1" in
    generate-key)
        generate_encryption_key
        ;;
    rotate-keys)
        rotate_encryption_keys
        ;;
    verify)
        verify_encryption_integrity
        ;;
    secure-delete)
        secure_delete_backup "$2"
        ;;
    *)
        echo "Использование: $0 {generate-key|rotate-keys|verify|secure-delete <backup-name>}"
        exit 1
        ;;
esac
```

### 🛡️ Контроль доступа и RBAC

#### 1. **RBAC конфигурация для backup**
```yaml
# backup-rbac-config.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backup-operator
  namespace: velero
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-operator
rules:
# Права на управление backup
- apiGroups: ["velero.io"]
  resources: ["backups", "restores", "schedules"]
  verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
# Права на чтение ресурсов для backup
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Права на volume snapshots
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots", "volumesnapshotcontents"]
  verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backup-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backup-operator
subjects:
- kind: ServiceAccount
  name: backup-operator
  namespace: velero
---
# Роль для backup администраторов
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-admin
rules:
- apiGroups: ["velero.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "list", "watch", "update", "patch", "delete"]
  resourceNames: ["backup-encryption-key", "cloud-credentials"]
---
# Роль для backup пользователей (только чтение)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backup-viewer
rules:
- apiGroups: ["velero.io"]
  resources: ["backups", "restores", "schedules"]
  verbs: ["get", "list", "watch"]
---
# RoleBinding для production namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backup-production-access
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backup-operator
subjects:
- kind: ServiceAccount
  name: backup-operator
  namespace: velero
```

#### 2. **Скрипт управления доступом**
```bash
#!/bin/bash
# backup-access-control.sh

echo "🛡️ Управление доступом к backup"

# Создание пользователя для backup операций
create_backup_user() {
    local username=$1
    local role=$2
    
    echo "👤 Создание пользователя backup: $username с ролью $role"
    
    # Генерация сертификата для пользователя
    openssl genrsa -out ${username}.key 2048
    openssl req -new -key ${username}.key -out ${username}.csr -subj "/CN=${username}/O=backup-users"
    
    # Подписание сертификата CA кластера
    openssl x509 -req -in ${username}.csr -CA /etc/kubernetes/pki/ca.crt \
        -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${username}.crt -days 365
    
    # Создание kubeconfig для пользователя
    kubectl config set-credentials $username \
        --client-certificate=${username}.crt \
        --client-key=${username}.key
    
    kubectl config set-context ${username}-context \
        --cluster=kubernetes \
        --user=$username
    
    # Привязка роли к пользователю
    kubectl create clusterrolebinding ${username}-binding \
        --clusterrole=$role \
        --user=$username
    
    echo "✅ Пользователь $username создан с ролью $role"
}

# Аудит доступа к backup
audit_backup_access() {
    echo "📊 Аудит доступа к backup"
    
    # Проверка всех RoleBindings связанных с backup
    echo "=== ClusterRoleBindings для backup ==="
    kubectl get clusterrolebindings -o json | \
        jq -r '.items[] | select(.roleRef.name | contains("backup")) | 
               "\(.metadata.name): \(.subjects[].name) -> \(.roleRef.name)"'
    
    # Проверка ServiceAccounts с backup правами
    echo "=== ServiceAccounts с backup правами ==="
    kubectl get serviceaccounts --all-namespaces -o json | \
        jq -r '.items[] | select(.metadata.name | contains("backup")) | 
               "\(.metadata.namespace)/\(.metadata.name)"'
    
    # Проверка доступа к secrets
    echo "=== Доступ к backup secrets ==="
    kubectl auth can-i get secrets --as=system:serviceaccount:velero:velero
    kubectl auth can-i create secrets --as=system:serviceaccount:velero:velero
    
    # Создание отчета аудита
    cat > /tmp/backup-access-audit.json << EOF
{
  "audit_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_users": $(kubectl get clusterrolebindings -o json | \
    jq '[.items[] | select(.roleRef.name | contains("backup")) | 
         {name: .metadata.name, subjects: .subjects, role: .roleRef.name}]'),
  "backup_serviceaccounts": $(kubectl get serviceaccounts --all-namespaces -o json | \
    jq '[.items[] | select(.metadata.name | contains("backup")) | 
         {namespace: .metadata.namespace, name: .metadata.name}]')
}
EOF
    
    echo "📄 Отчет аудита создан: /tmp/backup-access-audit.json"
}

# Проверка прав доступа
check_backup_permissions() {
    local user=$1
    
    echo "🔍 Проверка прав доступа для пользователя: $user"
    
    # Проверка основных backup операций
    local permissions=(
        "create backups"
        "get backups"
        "list backups"
        "delete backups"
        "create restores"
        "get secrets"
    )
    
    for permission in "${permissions[@]}"; do
        if kubectl auth can-i $permission --as=$user; then
            echo "✅ $user может: $permission"
        else
            echo "❌ $user НЕ может: $permission"
        fi
    done
}

# Ротация credentials
rotate_backup_credentials() {
    echo "🔄 Ротация backup credentials"
    
    # Ротация cloud credentials
    local new_access_key=$(aws iam create-access-key --user-name velero-backup-user \
        --query 'AccessKey.AccessKeyId' --output text)
    local new_secret_key=$(aws iam create-access-key --user-name velero-backup-user \
        --query 'AccessKey.SecretAccessKey' --output text)
    
    # Обновление Kubernetes Secret
    kubectl create secret generic cloud-credentials \
        --from-literal=cloud="[default]
aws_access_key_id=$new_access_key
aws_secret_access_key=$new_secret_key" \
        --namespace=velero \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Перезапуск Velero для применения новых credentials
    kubectl rollout restart deployment/velero -n velero
    
    echo "✅ Backup credentials обновлены"
}

# Основная логика
case "$1" in
    create-user)
        create_backup_user "$2" "$3"
        ;;
    audit)
        audit_backup_access
        ;;
    check-permissions)
        check_backup_permissions "$2"
        ;;
    rotate-credentials)
        rotate_backup_credentials
        ;;
    *)
        echo "Использование: $0 {create-user <username> <role>|audit|check-permissions <user>|rotate-credentials}"
        exit 1
        ;;
esac
```

### 🚨 Защита от угроз

#### 1. **Anti-ransomware защита**
```yaml
# anti-ransomware-protection.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: anti-ransomware-config
  namespace: velero
data:
  protection-policy.yaml: |
    # Политика защиты от ransomware
    anti_ransomware_policy:
      immutable_backups:
        enabled: true
        retention_period: "30 days"
        write_once_read_many: true
      
      air_gapped_backups:
        enabled: true
        offline_storage: true
        network_isolation: true
        manual_restore_only: true
      
      backup_verification:
        integrity_checks: true
        malware_scanning: true
        anomaly_detection: true
        automated_testing: true
      
      access_controls:
        multi_factor_auth: true
        privileged_access_management: true
        just_in_time_access: true
        audit_all_operations: true
---
# Immutable backup storage configuration
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: immutable-backup-storage
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: hashfoundry-backup-immutable
    prefix: immutable-backups
  config:
    region: fra1
    # Object Lock для immutability
    s3ForcePathStyle: "true"
    objectLockEnabled: "true"
    objectLockRetentionMode: "GOVERNANCE"
    objectLockRetentionDays: "30"
---
# NetworkPolicy для изоляции backup трафика
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backup-network-isolation
  namespace: velero
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
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS для cloud storage
    - protocol: TCP
      port: 53   # DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53   # DNS
```

#### 2. **Скрипт защиты от угроз**
```bash
#!/bin/bash
# backup-threat-protection.sh

echo "🚨 Защита backup от угроз"

# Переменные
BACKUP_BUCKET="hashfoundry-backup-immutable"
QUARANTINE_BUCKET="hashfoundry-backup-quarantine"
MALWARE_SCANNER="clamav"

# Проверка на ransomware индикаторы
detect_ransomware_indicators() {
    echo "🔍 Поиск индикаторов ransomware"
    
    # Проверка аномальной активности backup
    local recent_backups=$(velero backup get -o json | \
        jq --arg since "$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ)" \
        '[.items[] | select(.metadata.creationTimestamp > $since)] | length')
    
    if [ $recent_backups -gt 10 ]; then
        echo "⚠️ Аномальная активность: $recent_backups backup за последний час"
        trigger_ransomware_alert "excessive_backup_activity"
    fi
    
    # Проверка неожиданных удалений backup
    local deleted_backups=$(grep "backup_deletion" /var/log/backup-deletions.audit | \
        grep "$(date +%Y-%m-%d)" | wc -l)
    
    if [ $deleted_backups -gt 5 ]; then
        echo "⚠️ Подозрительная активность: $deleted_backups удалений backup сегодня"
        trigger_ransomware_alert "excessive_backup_deletions"
    fi
    
    # Проверка изменений в RBAC
    local rbac_changes=$(kubectl get events --field-selector type=Normal | \
        grep -E "(rolebinding|clusterrolebinding)" | \
        grep "$(date +%Y-%m-%d)" | wc -l)
    
    if [ $rbac_changes -gt 3 ]; then
        echo "⚠️ Подозрительные изменения RBAC: $rbac_changes изменений"
        trigger_ransomware_alert "rbac_modifications"
    fi
}

# Создание immutable backup
create_immutable_backup() {
    local backup_name=$1
    
    echo "🔒 Создание immutable backup: $backup_name"
    
    # Создание backup с immutable storage
    velero backup create $backup_name \
        --storage-location immutable-backup-storage \
        --wait
    
    # Проверка успешности создания
    if [ $? -eq 0 ]; then
        # Установка Object Lock на S3 объекты
        aws s3api put-object-legal-hold \
            --bucket $BACKUP_BUCKET \
            --key "immutable-backups/$backup_name" \
            --legal-hold Status=ON
        
        echo "✅ Immutable backup $backup_name создан"
    else
        echo "❌ Ошибка создания immutable backup $backup_name"
    fi
}

# Сканирование backup на malware
scan_backup_for_malware() {
    local backup_name=$1
    
    echo "🦠 Сканирование backup на malware: $backup_name"
    
    # Скачивание backup для сканирования
    local temp_dir="/tmp/backup-scan-$$"
    mkdir -p $temp_dir
    
    # Восстановление backup во временную директорию
    velero restore create temp-restore-$$ \
        --from-backup $backup_name \
        --include-namespaces temp-scan \
        --wait
    
    # Сканирование с помощью ClamAV
    if command -v clamscan &> /dev/null; then
        clamscan -r $temp_dir --infected --remove
        local scan_result=$?
        
        if [ $scan_result -eq 0 ]; then
            echo "✅ Backup $backup_name чист от malware"
        else
            echo "🚨 Обнаружен malware в backup $backup_name"
            quarantine_backup "$backup_name"
        fi
    else
        echo "⚠️ ClamAV не установлен, пропуск сканирования"
    fi
    
    # Очистка временных файлов
    rm -rf $temp_dir
    kubectl delete namespace temp-scan --ignore-not-found=true
}

# Карантин подозрительного backup
quarantine_backup() {
    local backup_name=$1
    
    echo "🚨 Помещение backup в карантин: $backup_name"
    
    # Перемещение backup в карантинное хранилище
    aws s3 mv s3://$BACKUP_BUCKET/backups/$backup_name \
        s3://$QUARANTINE_BUCKET/quarantine/$backup_name
    
    # Создание записи в карантинном журнале
    cat >> /var/log/backup-quarantine.log << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "action": "backup_quarantine",
  "backup_name": "$backup_name",
  "reason": "malware_detected",
  "quarantine_location": "s3://$QUARANTINE_BUCKET/quarantine/$backup_name"
}
EOF
    
    # Отправка алерта
    trigger_security_alert "backup_quarantined" "$backup_name"
    
    echo "✅ Backup $backup_name помещен в карантин"
}

# Мониторинг целостности backup
monitor_backup_integrity() {
    echo "🔍 Мониторинг целостности backup"
    
    # Проверка checksums всех backup
    local backups=$(velero backup get -o json | jq -r '.items[].metadata.name')
    
    for backup in $backups; do
        echo "Проверка целостности: $backup"
        
        # Получение оригинального checksum
        local original_checksum=$(velero backup describe $backup --details | \
            grep "Checksum:" | awk '{print $2}')
        
        # Вычисление текущего checksum
        local current_checksum=$(aws s3api head-object \
            --bucket $BACKUP_BUCKET \
            --key "backups/$backup" \
            --query 'ETag' --output text | tr -d '"')
        
        if [ "$original_checksum" != "$current_checksum" ]; then
            echo "🚨 Нарушение целостности backup: $backup"
            trigger_security_alert "backup_integrity_violation" "$backup"
        else
            echo "✅ Целостность backup $backup подтверждена"
        fi
    done
}

# Триггер security алерта
trigger_security_alert() {
    local alert_type=$1
    local details=$2
    
    echo "🚨 Триггер security алерта: $alert_type"
    
    # Отправка в Slack
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\":\"🚨 SECURITY ALERT: $alert_type\",
                \"attachments\":[{
                    \"color\":\"danger\",
                    \"fields\":[{
                        \"title\":\"Details\",
                        \"value\":\"$details\",
                        \"short\":false
                    }]
                }]
            }" \
            "$SLACK_WEBHOOK_URL"
    fi
    
    # Создание Kubernetes Event
    kubectl create event security-alert-$(date +%s) \
        --type=Warning \
        --reason="BackupSecurityAlert" \
        --message="Security alert: $alert_type - $details" \
        --namespace=velero
}

# Триггер ransomware алерта
trigger_ransomware_alert() {
    local indicator=$1
    
    echo "🚨 RANSOMWARE ALERT: $indicator"
    
    # Нем
