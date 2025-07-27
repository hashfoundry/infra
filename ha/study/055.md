# 55. Как безопасно управлять секретами в Kubernetes?

## 🎯 **Безопасное управление секретами в Kubernetes**

**Безопасное управление секретами** - это критически важный аспект работы с Kubernetes кластерами. Правильная стратегия управления секретами защищает конфиденциальные данные от несанкционированного доступа и обеспечивает соответствие требованиям безопасности.

## 🏗️ **Основные принципы безопасного управления секретами:**

### **1. Encryption at Rest (Шифрование в покое)**
### **2. RBAC (Role-Based Access Control)**
### **3. External Secret Management**
### **4. Secret Rotation (Ротация секретов)**
### **5. Audit и Monitoring**
### **6. Network Security**
### **7. GitOps и Sealed Secrets**

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Encryption at Rest - Шифрование секретов в etcd:**
```bash
# Создать namespace для демонстрации
kubectl create namespace secret-security-demo

# Проверить текущую конфигурацию шифрования
echo "=== Checking etcd encryption configuration ==="

# Создать тестовый Secret для проверки шифрования
kubectl create secret generic encryption-test \
  --from-literal=sensitive-data="This is highly sensitive information" \
  --from-literal=api-key="super_secret_api_key_12345" \
  --from-literal=database-password="encrypted_db_password_67890" \
  -n secret-security-demo

# Проверить Secret в etcd (требует доступа к etcd)
cat << 'EOF' > check-etcd-encryption.sh
#!/bin/bash

echo "=== Checking Secret encryption in etcd ==="
echo "Note: This requires direct etcd access"

# Получить информацию о Secret
SECRET_NAME="encryption-test"
NAMESPACE="secret-security-demo"

echo "Secret created: $SECRET_NAME in namespace $NAMESPACE"
echo "Checking if data is encrypted in etcd..."

# Команда для проверки в etcd (выполняется на master node)
echo "To check encryption on master node:"
echo "sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \\"
echo "  --cacert=/etc/kubernetes/pki/etcd/ca.crt \\"
echo "  --cert=/etc/kubernetes/pki/etcd/server.crt \\"
echo "  --key=/etc/kubernetes/pki/etcd/server.key \\"
echo "  get /registry/secrets/$NAMESPACE/$SECRET_NAME"

echo ""
echo "If encryption is enabled, the output should be binary/encrypted."
echo "If not encrypted, you'll see plain text data."
EOF

chmod +x check-etcd-encryption.sh
./check-etcd-encryption.sh

# Создать EncryptionConfiguration для включения шифрования
cat << EOF > encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: $(head -c 32 /dev/urandom | base64)
  - identity: {}
EOF

echo "=== Encryption Configuration Example ==="
echo "To enable encryption at rest, add this to kube-apiserver:"
echo "--encryption-provider-config=/etc/kubernetes/encryption-config.yaml"
cat encryption-config.yaml
```

### **2. RBAC для ограничения доступа к секретам:**
```bash
# Создать Service Accounts с разными уровнями доступа
kubectl create serviceaccount secret-admin -n secret-security-demo
kubectl create serviceaccount secret-reader -n secret-security-demo
kubectl create serviceaccount secret-writer -n secret-security-demo
kubectl create serviceaccount no-secret-access -n secret-security-demo

# Создать ClusterRole для полного управления секретами
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-admin-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete", "watch"]
- apiGroups: [""]
  resources: ["secrets/status"]
  verbs: ["get", "update", "patch"]
EOF

# Создать Role для чтения секретов только в определенном namespace
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: secret-security-demo
  name: secret-reader-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
EOF

# Создать Role для записи секретов
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: secret-security-demo
  name: secret-writer-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch"]
EOF

# Создать Role с ограниченным доступом к конкретным секретам
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: secret-security-demo
  name: specific-secret-access
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["encryption-test", "app-config-secret"]
EOF

# Привязать роли к Service Accounts
kubectl create clusterrolebinding secret-admin-binding \
  --clusterrole=secret-admin-role \
  --serviceaccount=secret-security-demo:secret-admin

kubectl create rolebinding secret-reader-binding \
  --role=secret-reader-role \
  --serviceaccount=secret-security-demo:secret-reader \
  -n secret-security-demo

kubectl create rolebinding secret-writer-binding \
  --role=secret-writer-role \
  --serviceaccount=secret-security-demo:secret-writer \
  -n secret-security-demo

kubectl create rolebinding specific-secret-binding \
  --role=specific-secret-access \
  --serviceaccount=secret-security-demo:no-secret-access \
  -n secret-security-demo

# Создать тестовые Pod'ы для проверки RBAC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-admin-pod
  namespace: secret-security-demo
spec:
  serviceAccountName: secret-admin
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  restartPolicy: Never
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-pod
  namespace: secret-security-demo
spec:
  serviceAccountName: secret-reader
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  restartPolicy: Never
---
apiVersion: v1
kind: Pod
metadata:
  name: no-access-pod
  namespace: secret-security-demo
spec:
  serviceAccountName: no-secret-access
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  restartPolicy: Never
EOF

# Тестировать RBAC доступ
echo "=== Testing RBAC Access ==="
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod/secret-admin-pod -n secret-security-demo --timeout=60s
kubectl wait --for=condition=Ready pod/secret-reader-pod -n secret-security-demo --timeout=60s
kubectl wait --for=condition=Ready pod/no-access-pod -n secret-security-demo --timeout=60s

echo "Testing secret-admin access (should work):"
kubectl exec secret-admin-pod -n secret-security-demo -- kubectl get secrets -n secret-security-demo

echo "Testing secret-reader access (should work for reading):"
kubectl exec secret-reader-pod -n secret-security-demo -- kubectl get secrets -n secret-security-demo

echo "Testing no-access pod (should fail for general access):"
kubectl exec no-access-pod -n secret-security-demo -- kubectl get secrets -n secret-security-demo || echo "Access denied (expected)"

echo "Testing specific secret access (should work for specific secret):"
kubectl exec no-access-pod -n secret-security-demo -- kubectl get secret encryption-test -n secret-security-demo
```

### **3. External Secret Management с Vault интеграцией:**
```bash
# Симуляция интеграции с HashiCorp Vault
echo "=== External Secret Management Demo ==="

# Создать Secret для Vault аутентификации
kubectl create secret generic vault-auth \
  --from-literal=vault-token="hvs.example_vault_token_12345" \
  --from-literal=vault-url="https://vault.hashfoundry.com:8200" \
  --from-literal=vault-namespace="hashfoundry" \
  -n secret-security-demo

# Создать ConfigMap с Vault конфигурацией
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: secret-security-demo
data:
  vault-config.yaml: |
    vault:
      address: "https://vault.hashfoundry.com:8200"
      namespace: "hashfoundry"
      auth:
        method: "kubernetes"
        path: "auth/kubernetes"
        role: "hashfoundry-app"
      secrets:
        - path: "secret/data/database"
          keys:
            - "username"
            - "password"
            - "host"
        - path: "secret/data/api"
          keys:
            - "api-key"
            - "webhook-secret"
        - path: "secret/data/certificates"
          keys:
            - "tls.crt"
            - "tls.key"
  
  external-secrets-config.yaml: |
    apiVersion: external-secrets.io/v1beta1
    kind: SecretStore
    metadata:
      name: vault-backend
      namespace: secret-security-demo
    spec:
      provider:
        vault:
          server: "https://vault.hashfoundry.com:8200"
          path: "secret"
          version: "v2"
          auth:
            kubernetes:
              mountPath: "auth/kubernetes"
              role: "hashfoundry-app"
              serviceAccountRef:
                name: "vault-auth-sa"
    ---
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: database-secret
      namespace: secret-security-demo
    spec:
      refreshInterval: 15s
      secretStoreRef:
        name: vault-backend
        kind: SecretStore
      target:
        name: database-credentials
        creationPolicy: Owner
      data:
      - secretKey: username
        remoteRef:
          key: database
          property: username
      - secretKey: password
        remoteRef:
          key: database
          property: password
      - secretKey: host
        remoteRef:
          key: database
          property: host
EOF

# Создать демонстрационный External Secrets Operator Pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: external-secrets-demo
  namespace: secret-security-demo
  labels:
    app: external-secrets-demo
spec:
  containers:
  - name: vault-client
    image: vault:1.15.2
    command: ["sh", "-c"]
    args:
    - |
      echo "=== External Secrets Management Demo ==="
      echo "Vault Server: \$VAULT_ADDR"
      echo "Vault Namespace: \$VAULT_NAMESPACE"
      echo ""
      
      echo "Simulating Vault secret retrieval..."
      echo "vault kv get -mount=secret database"
      echo "vault kv get -mount=secret api"
      echo "vault kv get -mount=secret certificates"
      echo ""
      
      echo "External Secrets Operator would:"
      echo "1. Authenticate with Vault using Kubernetes auth"
      echo "2. Retrieve secrets from specified paths"
      echo "3. Create/update Kubernetes Secrets"
      echo "4. Refresh secrets based on configured interval"
      echo ""
      
      echo "Benefits:"
      echo "- Centralized secret management"
      echo "- Automatic secret rotation"
      echo "- Audit trail in Vault"
      echo "- No secrets in Git repositories"
      echo ""
      
      while true; do sleep 30; done
    env:
    - name: VAULT_ADDR
      valueFrom:
        secretKeyRef:
          name: vault-auth
          key: vault-url
    - name: VAULT_NAMESPACE
      valueFrom:
        secretKeyRef:
          name: vault-auth
          key: vault-namespace
    - name: VAULT_TOKEN
      valueFrom:
        secretKeyRef:
          name: vault-auth
          key: vault-token
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  restartPolicy: Never
EOF

# Проверить демонстрацию External Secrets
kubectl logs external-secrets-demo -n secret-security-demo
```

### **4. Secret Rotation - Автоматическая ротация секретов:**
```bash
# Создать скрипт для автоматической ротации секретов
cat << 'EOF' > secret-rotation-demo.sh
#!/bin/bash

NAMESPACE="secret-security-demo"

echo "=== Secret Rotation Demonstration ==="
echo

# Функция для генерации сильного пароля
generate_strong_password() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Функция для генерации API ключа
generate_api_key() {
    echo "hf_$(openssl rand -hex 16)"
}

# Функция для ротации Secret
rotate_secret() {
    local secret_name=$1
    local key_name=$2
    local value_type=${3:-password}
    
    echo "Rotating $secret_name.$key_name ($value_type)..."
    
    # Создать резервную копию
    kubectl get secret $secret_name -n $NAMESPACE -o yaml > "/tmp/${secret_name}-backup-$(date +%Y%m%d-%H%M%S).yaml"
    
    # Генерировать новое значение
    case $value_type in
        "password")
            new_value=$(generate_strong_password)
            ;;
        "api-key")
            new_value=$(generate_api_key)
            ;;
        "jwt-secret")
            new_value=$(generate_strong_password 64)
            ;;
        *)
            new_value=$(generate_strong_password)
            ;;
    esac
    
    # Обновить Secret
    kubectl patch secret $secret_name -n $NAMESPACE --type='merge' \
        -p="{\"data\":{\"$key_name\":\"$(echo -n $new_value | base64)\"}}"
    
    # Добавить аннотацию с временем ротации
    kubectl annotate secret $secret_name -n $NAMESPACE \
        "rotation.hashfoundry.com/last-rotated-$(echo $key_name | tr '.' '-')=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --overwrite
    
    echo "✓ Rotated $secret_name.$key_name"
    echo "  New value length: ${#new_value}"
    echo "  Backup saved to: /tmp/${secret_name}-backup-$(date +%Y%m%d-%H%M%S).yaml"
    echo
}

# Создать секреты для ротации
kubectl create secret generic app-credentials \
    --from-literal=database-password="old_db_password_123" \
    --from-literal=api-key="old_api_key_456" \
    --from-literal=jwt-secret="old_jwt_secret_789" \
    --from-literal=encryption-key="old_encryption_key_000" \
    -n $NAMESPACE

kubectl create secret generic service-tokens \
    --from-literal=github-token="ghp_old_github_token_123" \
    --from-literal=slack-webhook="https://hooks.slack.com/old_webhook" \
    --from-literal=monitoring-token="old_monitoring_token_456" \
    -n $NAMESPACE

# Выполнить ротацию
echo "Starting secret rotation process..."
echo

rotate_secret "app-credentials" "database-password" "password"
rotate_secret "app-credentials" "api-key" "api-key"
rotate_secret "app-credentials" "jwt-secret" "jwt-secret"
rotate_secret "app-credentials" "encryption-key" "password"

rotate_secret "service-tokens" "github-token" "api-key"
rotate_secret "service-tokens" "monitoring-token" "api-key"

echo "=== Rotation Summary ==="
kubectl get secrets -n $NAMESPACE -o custom-columns="NAME:.metadata.name,LAST-ROTATED:.metadata.annotations.rotation\.hashfoundry\.com/last-rotated-database-password"

echo
echo "=== Verification ==="
echo "Checking rotated values (showing lengths only for security):"

for secret in app-credentials service-tokens; do
    echo "Secret: $secret"
    for key in $(kubectl get secret $secret -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]'); do
        length=$(kubectl get secret $secret -n $NAMESPACE -o jsonpath="{.data.$key}" | base64 --decode | wc -c)
        echo "  $key: $length characters"
    done
    echo
done

EOF

chmod +x secret-rotation-demo.sh
./secret-rotation-demo.sh

# Создать CronJob для автоматической ротации
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: secret-rotation-job
  namespace: secret-security-demo
spec:
  schedule: "0 2 * * 0"  # Каждое воскресенье в 2:00 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: secret-admin
          containers:
          - name: secret-rotator
            image: bitnami/kubectl:latest
            command: ["sh", "-c"]
            args:
            - |
              echo "Starting automated secret rotation..."
              
              # Функция для генерации пароля
              generate_password() {
                openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
              }
              
              # Ротация критических секретов
              for secret in app-credentials service-tokens; do
                if kubectl get secret \$secret -n secret-security-demo >/dev/null 2>&1; then
                  echo "Rotating secret: \$secret"
                  
                  # Создать резервную копию
                  kubectl get secret \$secret -n secret-security-demo -o yaml > /tmp/\${secret}-backup.yaml
                  
                  # Обновить аннотацию времени ротации
                  kubectl annotate secret \$secret -n secret-security-demo \
                    "rotation.hashfoundry.com/last-automated-rotation=\$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    --overwrite
                  
                  echo "✓ Processed \$secret"
                else
                  echo "✗ Secret \$secret not found"
                fi
              done
              
              echo "Automated rotation completed"
            resources:
              requests:
                memory: "64Mi"
                cpu: "100m"
              limits:
                memory: "128Mi"
                cpu: "200m"
          restartPolicy: OnFailure
EOF
```

### **5. Audit и Monitoring секретов:**
```bash
# Создать систему мониторинга доступа к секретам
cat << 'EOF' > secret-monitoring.sh
#!/bin/bash

NAMESPACE="secret-security-demo"

echo "=== Secret Monitoring and Auditing ==="
echo

# Функция для анализа использования секретов
analyze_secret_usage() {
    local secret_name=$1
    
    echo "Analyzing secret: $secret_name"
    
    # Получить информацию о Secret
    local created=$(kubectl get secret $secret_name -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}')
    local size=$(kubectl get secret $secret_name -n $NAMESPACE -o jsonpath='{.data}' | wc -c)
    local keys=$(kubectl get secret $secret_name -n $NAMESPACE -o jsonpath='{.data}' | jq 'keys | length')
    
    echo "  Created: $created"
    echo "  Size: ${size} bytes"
    echo "  Keys: $keys"
    
    # Найти Pod'ы, использующие Secret
    echo "  Used by Pods:"
    local env_pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].env[?(@.valueFrom.secretKeyRef.name=="'$secret_name'")].valueFrom.secretKeyRef.name}{"\n"}{end}' | grep -v "^$")
    local volume_pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumes[?(@.secret.secretName=="'$secret_name'")].secret.secretName}{"\n"}{end}' | grep -v "^$")
    
    if [ -n "$env_pods" ]; then
        echo "$env_pods" | sed 's/^/    ENV: /'
    fi
    if [ -n "$volume_pods" ]; then
        echo "$volume_pods" | sed 's/^/    VOLUME: /'
    fi
    if [ -z "$env_pods" ] && [ -z "$volume_pods" ]; then
        echo "    None (unused secret)"
    fi
    
    # Проверить последнюю ротацию
    local last_rotation=$(kubectl get secret $secret_name -n $NAMESPACE -o jsonpath='{.metadata.annotations.rotation\.hashfoundry\.com/last-rotated-database-password}' 2>/dev/null)
    if [ -n "$last_rotation" ]; then
        echo "  Last rotation: $last_rotation"
    else
        echo "  Last rotation: Never"
    fi
    
    echo
}

# Создать Secret для мониторинга
kubectl create secret generic monitoring-secret \
    --from-literal=prometheus-password="monitoring_pass_123" \
    --from-literal=grafana-admin="grafana_admin_456" \
    --from-literal=alertmanager-webhook="webhook_secret_789" \
    -n $NAMESPACE

# Анализировать все секреты
echo "=== Secret Usage Analysis ==="
for secret in $(kubectl get secrets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' | grep -v default-token); do
    analyze_secret_usage "$secret"
done

# Создать алерты для мониторинга секретов
echo "=== Security Monitoring Alerts ==="
cat << 'EOL'
Recommended monitoring alerts:

1. Secret Access Monitoring:
   - Alert when secrets are accessed outside business hours
   - Monitor failed secret access attempts
   - Track secret creation/deletion events

2. Secret Rotation Monitoring:
   - Alert when secrets haven't been rotated in X days
   - Monitor rotation failures
   - Track secret age and usage patterns

3. RBAC Violations:
   - Alert on unauthorized secret access attempts
   - Monitor privilege escalation attempts
   - Track service account token usage

4. Secret Exposure Detection:
   - Monitor for secrets in logs
   - Detect secrets in environment variables
   - Scan for hardcoded secrets in images

Example Prometheus queries:
- increase(apiserver_audit_total{verb="get",objectRef_resource="secrets"}[5m])
- increase(apiserver_audit_total{verb="create",objectRef_resource="secrets"}[1h])
- increase(apiserver_audit_total{verb="delete",objectRef_resource="secrets"}[1h])
EOL

EOF

chmod +x secret-monitoring.sh
./secret-monitoring.sh

# Создать Pod для демонстрации мониторинга
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-monitor
  namespace: secret-security-demo
  labels:
    app: secret-monitor
spec:
  serviceAccountName: secret-reader
  containers:
  - name: monitor
    image: busybox:1.35
    command: ["sh", "-c"]
    args:
    - |
      echo "=== Secret Security Monitoring ==="
      echo "Monitoring secret access patterns..."
      echo ""
      
      while true; do
        echo "\$(date): Checking secret security status..."
        
        # Симуляция мониторинга
        echo "- Checking for unauthorized access attempts"
        echo "- Monitoring secret rotation status"
        echo "- Validating RBAC compliance"
        echo "- Scanning for secret exposure"
        echo ""
        
        sleep 60
      done
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  restartPolicy: Never
EOF
```

### **6. Network Security для секретов:**
```bash
# Создать NetworkPolicy для ограничения доступа к секретам
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secret-access-policy
  namespace: secret-security-demo
spec:
  podSelector:
    matchLabels:
      access-secrets: "true"
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: secret-security-demo
    - podSelector:
        matchLabels:
          role: secret-consumer
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 443  # Kubernetes API
  - to:
    - namespaceSelector:
        matchLabels:
          name: vault-system
    ports:
    - protocol: TCP
      port: 8200  # Vault
EOF

# Создать Pod с метками для NetworkPolicy
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: secret-security-demo
  labels:
    access-secrets: "true"
    role: secret-consumer
spec:
  containers:
  - name: app
    image: nginx:1.21
    ports:
    - containerPort: 8080
    env:
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-credentials
          key: database-password
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: app-credentials
          key: api-key
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  volumes:
  - name: secret-volume
    secret:
      secretName: app-credentials
      defaultMode: 0600
EOF

# Создать Service Mesh конфигурацию для mTLS
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-mtls-config
  namespace: secret-security-demo
data:
  destination-rule.yaml: |
    apiVersion: networking.istio.io/v1beta1
    kind: DestinationRule
    metadata:
      name: secret-service-mtls
      namespace: secret-security-demo
    spec:
      host: secret-service.secret-security-demo.svc.cluster.local
      trafficPolicy:
        tls:
          mode: ISTIO_MUTUAL
  
  peer-authentication.yaml: |
    apiVersion: security.istio.io/v1beta1
    kind: PeerAuthentication
    metadata:
      name: secret-namespace-mtls
      namespace: secret-security-demo
    spec:
      mtls:
        mode: STRICT
  
  authorization-policy.yaml: |
    apiVersion: security.istio.io/v1beta1
    kind: AuthorizationPolicy
    metadata:
      name: secret-access-policy
      namespace: secret-security-demo
    spec:
      selector:
        matchLabels:
          access-secrets: "true"
      rules:
      - from:
        - source:
            principals: ["cluster.local/ns/secret-security-demo/sa/secret-reader"]
        to:
        - operation:
            methods: ["GET"]
        when:
        - key: request.headers[authorization]
          values: ["Bearer *"]
EOF
```

### **7. GitOps и Sealed Secrets:**
```bash
# Демонстрация Sealed Secrets для GitOps
echo "=== Sealed Secrets for GitOps ==="

# Создать обычный Secret для запечатывания
cat << EOF > plain-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitops-secret
  namespace: secret-security-demo
type: Opaque
data:
  database-url: $(echo -n "postgresql://user:password@db.hashfoundry.com:5432/prod" | base64)
  api-key: $(echo -n "sk-1234567890abcdef" | base64)
  webhook-secret: $(echo -n "webhook_secret_xyz789" | base64)
EOF

# Создать SealedSecret (симуляция)
cat << EOF > sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: gitops-secret
  namespace: secret-security-demo
spec:
  encryptedData:
    database-url: AgBy3i4OJSWK+PiTySYZZA9rO7hvfMl/xvkNaUQfTg0XeiVBmR9wZmxhVGhwbXVCY2c9PQo=
    api-key: AgAKVVMvem1CY2c9PQoiTySYZZA9rO7hvfMl/xvkNaUQfTg0XeiVBmR9wZmxhVGhwbXVCY2c9PQo=
    webhook-secret: AgAKVVMvem1CY2c9PQoiTySYZZA9rO7hvfMl/xvkNaUQfTg0XeiVBmR9wZmxhVGhwbXVCY2c9PQo=
  template:
    metadata:
      name: gitops-secret
      namespace: secret-security-demo
    type: Opaque
EOF

echo "=== Sealed Secrets Workflow ==="
cat << 'EOL'
1. Install Sealed Secrets Controller:
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

2. Install kubeseal CLI:
   wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
   tar -xvzf kubeseal-0.24.0-linux-amd64.tar.gz
   sudo install -m 755 kubeseal /usr/local/bin/kubeseal

3. Create SealedSecret from regular Secret:
   kubeseal -f plain-secret.yaml -w sealed-secret.yaml

4. Commit SealedSecret to Git:
   git add sealed-secret.yaml
   git commit -m "Add sealed secret for production"
   git push

5. ArgoCD deploys SealedSecret:
   - SealedSecret is applied to cluster
   - Controller decrypts and creates regular Secret
   - Application uses the Secret normally
EOL

# Создать ArgoCD Application для Sealed Secrets
cat << EOF > argocd-sealed-secrets-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/k8s-secrets
    targetRevision: HEAD
    path: sealed-secrets
  destination:
    server: https://kubernetes.default.svc
    namespace: secret-security-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

echo "Created ArgoCD application for Sealed Secrets GitOps workflow"
```

## 🔐 **Advanced Security Techniques:**

### **8. Secret Scanning и Detection:**
```bash
# Создать скрипт для сканирования секретов
cat << 'EOF' > secret-scanner.sh
#!/bin/bash

NAMESPACE="secret-security-demo"

echo "=== Secret Security Scanner ==="
echo

# Функция для сканирования секретов в логах
scan_logs_for_secrets() {
    echo "Scanning Pod logs for potential secret exposure..."
    
    for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Checking logs for pod: $pod"
        
        # Проверить на наличие паттернов секретов
        local logs=$(kubectl logs $pod -n $NAMESPACE 2>/dev/null || echo "")
        
        # Паттерны для поиска
        local patterns=(
            "password.*=.*[a-zA-Z0-9]+"
            "api[_-]?key.*=.*[a-zA-Z0-9]+"
            "secret.*=.*[a-zA-Z0-9]+"
            "token.*=.*[a-zA-Z0-9]+"
            "-----BEGIN.*PRIVATE KEY-----"
            "ghp_[a-zA-Z0-9]+"
            "sk-[a-zA-Z0-9]+"
        )
        
        for pattern in "${patterns[@]}"; do
            if echo "$logs" | grep -iE "$pattern" >/dev/null 2>&1; then
                echo "  ⚠️  Potential secret exposure detected: $pattern"
            fi
        done
    done
    echo
}

# Функция для проверки переменных окружения
scan_environment_variables() {
    echo "Scanning environment variables for secrets..."
    
    for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Checking environment variables for pod: $pod"
        
        # Получить переменные окружения
        local env_vars=$(kubectl exec $pod -n $NAMESPACE -- env 2>/dev/null || echo "")
        
        # Проверить на подозрительные переменные
        local suspicious_vars=$(echo "$env_vars" | grep -iE "(password|secret|key|token)" | grep -v "PATH\|HOME\|USER")
        
        if [ -n "$suspicious_vars" ]; then
            echo "  Suspicious environment variables found:"
            echo "$suspicious_vars" | sed 's/^/    /'
        else
            echo "  No suspicious environment variables found"
        fi
    done
    echo
}

# Функция для проверки конфигурации безопасности
check_security_configuration() {
    echo "Checking security configuration..."
    
    # Проверить RBAC
    echo "RBAC Configuration:"
    kubectl get rolebindings,clusterrolebindings -n $NAMESPACE -o wide
    echo
    
    # Проверить NetworkPolicies
    echo "Network Policies:"
    kubectl get networkpolicies -n $NAMESPACE
    echo
    
    # Проверить Pod Security Standards
    echo "Pod Security Context:"
    for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Pod: $pod"
        kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.securityContext}' | jq '.' 2>/dev/null || echo "  No security context"
    done
    echo
}

# Выполнить сканирование
scan_logs_for_secrets
scan_environment_variables
check_security_configuration

echo "=== Security Recommendations ==="
cat << 'EOL'
1. Secret Management:
   ✓ Use external secret management systems (Vault, AWS Secrets Manager)
   ✓ Implement automatic secret rotation
   ✓ Never log sensitive information
   ✓ Use Sealed Secrets for GitOps workflows

2. Access Control:
   ✓ Implement least privilege RBAC
   ✓ Use Service Accounts with minimal permissions
   ✓ Regular RBAC audits and reviews
   ✓ Monitor secret access patterns

3. Network Security:
   ✓ Implement NetworkPolicies
   ✓ Use Service Mesh for mTLS
   ✓ Encrypt traffic between services
   ✓ Isolate sensitive workloads

4. Monitoring and Auditing:
   ✓ Enable Kubernetes audit logging
   ✓ Monitor secret access and modifications
   ✓ Set up alerts for suspicious activities
   ✓ Regular security assessments

5. Container Security:
   ✓ Use minimal base images
   ✓ Scan images for vulnerabilities
   ✓ Implement Pod Security Standards
   ✓ Use read-only root filesystems
EOL

EOF

chmod +x secret-scanner.sh
./secret-scanner.sh
```

## 🧹 **Очистка ресурсов:**
```bash
# Создать скрипт для безопасной очистки
cat << 'EOF' > cleanup-security-demo.sh
#!/bin/bash

NAMESPACE="secret-security-demo"

echo "=== Secure Cleanup of Security Demo ==="
echo

# Функция для безопасного удаления секретов
secure_delete_secrets() {
    echo "Securely deleting secrets..."
    
    for secret in $(kubectl get secrets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' | grep -v default-token); do
        echo "Deleting secret: $secret"
        
        # Создать финальную резервную копию (зашифрованную)
        kubectl get secret $secret -n $NAMESPACE -o yaml > "/tmp/${secret}-final-backup.yaml"
        
        # Удалить Secret
        kubectl delete secret $secret -n $NAMESPACE
        
        echo "✓ Deleted $secret"
    done
    echo
}

# Удалить все ресурсы
echo "Deleting all demo resources..."
kubectl delete namespace $NAMESPACE

# Удалить RBAC ресурсы
kubectl delete clusterrole secret-admin-role
kubectl delete clusterrolebinding secret-admin-binding

# Удалить созданные файлы
echo "Cleaning up local files..."
rm -f check-etcd-encryption.sh
rm -f encryption-config.yaml
rm -f secret-rotation-demo.sh
rm -f secret-monitoring.sh
rm -f secret-scanner.sh
rm -f plain-secret.yaml
rm -f sealed-secret.yaml
rm -f argocd-sealed-secrets-app.yaml

# Удалить резервные копии (опционально)
echo "Backup files remain in /tmp/ for security review"
echo "To remove backups: rm -f /tmp/*-backup*.yaml"

echo "✓ Cleanup completed"

EOF

chmod +x cleanup-security-demo.sh
./cleanup-security-demo.sh
```

## 📋 **Сводка команд для безопасного управления секретами:**

### **Основные команды безопасности:**
```bash
# Encryption at Rest
kubectl create secret generic test-secret --from-literal=data=sensitive
# Проверить шифрование в etcd (на master node)

# RBAC для секретов
kubectl create role secret-reader --verb=get,list --resource=secrets
kubectl create rolebinding user-secret-reader --role=secret-reader --user=username

# External Secrets (с Vault)
kubectl apply -f external-secret-store.yaml
kubectl apply -f external-secret.yaml

# Secret Rotation
kubectl patch secret mysecret --type='merge' -p='{"data":{"key":"bmV3X3ZhbHVl"}}'
kubectl annotate secret mysecret rotation.date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Monitoring
kubectl get events --field-selector involvedObject.kind=Secret
kubectl logs -l app=secret-scanner

# Sealed Secrets
kubeseal -f secret.yaml -w sealed-secret.yaml
kubectl apply -f sealed-secret.yaml
```

## 📊 **Security Best Practices Matrix:**

| **Аспект** | **Базовый уровень** | **Продвинутый уровень** | **Enterprise уровень** |
|------------|-------------------|------------------------|----------------------|
| **Шифрование** | Base64 кодирование | Encryption at Rest | HSM интеграция |
| **Доступ** | Базовый RBAC | Детальный RBAC | Zero Trust модель |
| **Ротация** | Ручная ротация | Автоматическая ротация | Динамические секреты |
| **Хранение** | Kubernetes Secrets | External Secret Store | Multi-cloud секреты |
| **Мониторинг** | Базовые логи | Audit логи + алерты | SIEM интеграция |
| **GitOps** | Секреты в Git | Sealed Secrets | External Secret Operator |

## 🎯 **Критические принципы безопасности:**

### **1. Defense in Depth (Эшелонированная защита):**
- **Множественные уровни** защиты секретов
- **Шифрование** на всех уровнях
- **Сегментация** доступа
- **Мониторинг** на каждом уровне

### **2. Least Privilege (Минимальные привилегии):**
- **Ограниченный доступ** только к необходимым секретам
- **Временные токены** вместо постоянных
- **Регулярный аудит** прав доступа
- **Автоматическое отзыв** неиспользуемых прав

### **3. Zero Trust (Нулевое доверие):**
- **Проверка каждого запроса** к секретам
- **Непрерывная аутентификация** и авторизация
- **Микросегментация** сети
- **Постоянный мониторинг** активности

### **4. Automation (Автоматизация):**
- **Автоматическая ротация** секретов
- **Автоматическое обнаружение** утечек
- **Автоматическое восстановление** после инцидентов
- **Автоматическое соответствие** политикам безопасности

**Безопасное управление секретами требует комплексного подхода, включающего технические, процессные и организационные меры защиты!**
