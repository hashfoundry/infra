# 145. Как обрабатывать секреты в CI/CD с Kubernetes

## 🎯 **Основные концепции:**

| Аспект | Небезопасный подход | Безопасный подход |
|--------|---------------------|-------------------|
| **Хранение секретов** | В коде/Git репозитории | Внешние системы управления секретами |
| **Передача секретов** | Environment variables | Kubernetes Secrets + Volume mounts |
| **Шифрование** | Plaintext | Шифрование в покое и в движении |
| **Доступ к секретам** | Широкие права доступа | Принцип минимальных привилегий |
| **Ротация секретов** | Ручная ротация | Автоматическая ротация |
| **Аудит** | Отсутствует | Полное логирование доступа |
| **Разделение окружений** | Одни секреты для всех | Отдельные секреты для каждого окружения |
| **Управление жизненным циклом** | Статичные секреты | Динамическое управление |
| **Backup и восстановление** | Отсутствует | Автоматическое резервное копирование |
| **Compliance** | Не соответствует стандартам | SOC2, PCI DSS, GDPR compliance |
| **Мониторинг** | Отсутствует | Real-time мониторинг и алерты |
| **Integration** | Ручная интеграция | Автоматическая интеграция с CI/CD |

## 🏆 **Секреты в Kubernetes - что это такое?**

**Секреты в Kubernetes** — это объекты, которые содержат конфиденциальную информацию (пароли, токены, ключи) и обеспечивают безопасную передачу этой информации в Pod'ы. В CI/CD пайплайнах правильное управление секретами критически важно для безопасности всей инфраструктуры.

### **Типы секретов в Kubernetes:**
- **Opaque** - произвольные пользовательские данные
- **kubernetes.io/service-account-token** - токены сервисных аккаунтов
- **kubernetes.io/dockercfg** - сериализованный ~/.dockercfg файл
- **kubernetes.io/dockerconfigjson** - сериализованный ~/.docker/config.json файл
- **kubernetes.io/basic-auth** - учетные данные для базовой аутентификации
- **kubernetes.io/ssh-auth** - учетные данные для SSH аутентификации
- **kubernetes.io/tls** - данные для TLS клиента или сервера

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих секретов:**
```bash
# Проверка всех секретов в кластере
kubectl get secrets -A

# Детальная информация о секретах ArgoCD
kubectl get secrets -n argocd -o wide

# Проверка типов секретов
kubectl get secrets -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.type,DATA:.data"

# Анализ секретов по типам
kubectl get secrets -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.type)"' | sort

# Проверка размера секретов
kubectl get secrets -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.data | length) keys"'

# Поиск TLS секретов
kubectl get secrets -A --field-selector type=kubernetes.io/tls

# Проверка Docker registry секретов
kubectl get secrets -A --field-selector type=kubernetes.io/dockerconfigjson
```

### **2. Анализ использования секретов в Pod'ах:**
```bash
# Поиск Pod'ов, использующих секреты
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.volumes[]?.secret or .spec.containers[].env[]?.valueFrom.secretKeyRef or .spec.containers[].envFrom[]?.secretRef) | 
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Детальный анализ использования секретов в ArgoCD
kubectl get pods -n argocd -o json | jq -r '
  .items[] | 
  "\(.metadata.name):" as $pod |
  (.spec.containers[].env[]? | select(.valueFrom.secretKeyRef) | "  Secret: \(.valueFrom.secretKeyRef.name), Key: \(.valueFrom.secretKeyRef.key)"),
  (.spec.volumes[]? | select(.secret) | "  Volume Secret: \(.secret.secretName)")
'

# Проверка Service Account токенов
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.serviceAccountName != "default") | 
  "\(.metadata.namespace)/\(.metadata.name): SA=\(.spec.serviceAccountName)"
'

# Анализ imagePullSecrets
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.imagePullSecrets) | 
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.imagePullSecrets[].name)"
'
```

### **3. Проверка External Secrets и Sealed Secrets:**
```bash
# Проверка External Secrets Operator
kubectl get externalsecrets -A 2>/dev/null || echo "External Secrets Operator не установлен"

# Проверка Sealed Secrets
kubectl get sealedsecrets -A 2>/dev/null || echo "Sealed Secrets не установлен"

# Проверка Secret Stores
kubectl get secretstores -A 2>/dev/null || echo "Secret Stores не найдены"

# Проверка Cluster Secret Stores
kubectl get clustersecretstores 2>/dev/null || echo "Cluster Secret Stores не найдены"

# Анализ операторов управления секретами
kubectl get pods -A | grep -E "(external-secrets|sealed-secrets|vault|cert-manager)"
```

## 🛠️ **Comprehensive Secrets Management Implementation:**

### **1. Установка и настройка External Secrets Operator:**
```bash
#!/bin/bash
# scripts/setup-external-secrets.sh

echo "🔐 Setting up External Secrets Operator..."

# Add External Secrets Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true \
  --set webhook.port=9443 \
  --set certController.enable=true \
  --values - <<EOF
replicaCount: 2

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 65534

podSecurityContext:
  fsGroup: 65534
  runAsGroup: 65534
  runAsNonRoot: true
  runAsUser: 65534

serviceMonitor:
  enabled: true
  namespace: monitoring

webhook:
  replicaCount: 2
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

certController:
  replicaCount: 2
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
EOF

echo "✅ External Secrets Operator installed successfully!"

# Verify installation
kubectl get pods -n external-secrets-system
kubectl get crds | grep external-secrets
```

### **2. Настройка HashiCorp Vault как Secret Store:**
```yaml
# vault-secret-store.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: hashfoundry-production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-auth
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: hashfoundry-production
---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: hashfoundry-production
spec:
  provider:
    vault:
      server: "https://vault.hashfoundry.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "hashfoundry-production"
          serviceAccountRef:
            name: vault-auth
      caBundle: |
        -----BEGIN CERTIFICATE-----
        MIIDXTCCAkWgAwIBAgIJAKoK/heBjcOuMA0GCSqGSIb3DQEBBQUAMEUxCzAJBgNV
        BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
        aWRnaXRzIFB0eSBMdGQwHhcNMTYxMjMwMTQzNDQ3WhcNMjYxMjI4MTQzNDQ3WjBF
        MQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50
        ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
        CgKCAQEAwU1/1e2nUGVhXLiUBMkn5hHfBQNRwn2v4/L1hnFnxcHDjgL6+k1VZ5gQ
        -----END CERTIFICATE-----
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-cluster-backend
spec:
  provider:
    vault:
      server: "https://vault.hashfoundry.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "cluster-admin"
          serviceAccountRef:
            name: vault-auth
            namespace: external-secrets-system
```

### **3. Comprehensive External Secrets для HashFoundry:**
```yaml
# hashfoundry-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: hashfoundry-database-secrets
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: database
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: hashfoundry-database-secrets
    creationPolicy: Owner
    template:
      type: Opaque
      metadata:
        labels:
          app.kubernetes.io/name: hashfoundry-webapp
          app.kubernetes.io/component: database
      data:
        database-url: "postgresql://{{ .username }}:{{ .password }}@{{ .host }}:{{ .port }}/{{ .database }}?sslmode=require"
        username: "{{ .username }}"
        password: "{{ .password }}"
        host: "{{ .host }}"
        port: "{{ .port }}"
        database: "{{ .database }}"
  data:
  - secretKey: username
    remoteRef:
      key: hashfoundry/production/database
      property: username
  - secretKey: password
    remoteRef:
      key: hashfoundry/production/database
      property: password
  - secretKey: host
    remoteRef:
      key: hashfoundry/production/database
      property: host
  - secretKey: port
    remoteRef:
      key: hashfoundry/production/database
      property: port
  - secretKey: database
    remoteRef:
      key: hashfoundry/production/database
      property: database

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: hashfoundry-api-secrets
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: api
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: hashfoundry-api-secrets
    creationPolicy: Owner
    template:
      type: Opaque
      metadata:
        labels:
          app.kubernetes.io/name: hashfoundry-webapp
          app.kubernetes.io/component: api
  data:
  - secretKey: jwt-secret
    remoteRef:
      key: hashfoundry/production/api
      property: jwt_secret
  - secretKey: api-key
    remoteRef:
      key: hashfoundry/production/api
      property: api_key
  - secretKey: encryption-key
    remoteRef:
      key: hashfoundry/production/api
      property: encryption_key
  - secretKey: webhook-secret
    remoteRef:
      key: hashfoundry/production/api
      property: webhook_secret

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: hashfoundry-registry-secrets
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: registry
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: hashfoundry-registry-secrets
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
      metadata:
        labels:
          app.kubernetes.io/name: hashfoundry-webapp
          app.kubernetes.io/component: registry
      data:
        .dockerconfigjson: |
          {
            "auths": {
              "{{ .registry_url }}": {
                "username": "{{ .username }}",
                "password": "{{ .password }}",
                "email": "{{ .email }}",
                "auth": "{{ printf "%s:%s" .username .password | b64enc }}"
              }
            }
          }
  data:
  - secretKey: registry_url
    remoteRef:
      key: hashfoundry/production/registry
      property: url
  - secretKey: username
    remoteRef:
      key: hashfoundry/production/registry
      property: username
  - secretKey: password
    remoteRef:
      key: hashfoundry/production/registry
      property: password
  - secretKey: email
    remoteRef:
      key: hashfoundry/production/registry
      property: email

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: hashfoundry-tls-secrets
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: tls
spec:
  refreshInterval: 12h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: hashfoundry-tls-secrets
    creationPolicy: Owner
    template:
      type: kubernetes.io/tls
      metadata:
        labels:
          app.kubernetes.io/name: hashfoundry-webapp
          app.kubernetes.io/component: tls
  data:
  - secretKey: tls.crt
    remoteRef:
      key: hashfoundry/production/tls
      property: certificate
  - secretKey: tls.key
    remoteRef:
      key: hashfoundry/production/tls
      property: private_key
```

### **4. Sealed Secrets Implementation:**
```bash
#!/bin/bash
# scripts/setup-sealed-secrets.sh

echo "🔐 Setting up Sealed Secrets..."

# Install Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Wait for controller to be ready
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n kube-system

# Install kubeseal CLI
KUBESEAL_VERSION='0.24.0'
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm kubeseal kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz

# Verify installation
kubeseal --version
kubectl get pods -n kube-system | grep sealed-secrets

echo "✅ Sealed Secrets setup completed!"

# Create example sealed secret
echo "📝 Creating example sealed secret..."

# Create a regular secret (don't apply it)
kubectl create secret generic example-secret \
  --from-literal=username=admin \
  --from-literal=password=supersecret \
  --namespace=hashfoundry-production \
  --dry-run=client -o yaml > example-secret.yaml

# Seal the secret
kubeseal -f example-secret.yaml -w example-sealed-secret.yaml

echo "✅ Example sealed secret created: example-sealed-secret.yaml"
echo "🔒 This file can be safely committed to Git!"

# Clean up temporary file
rm example-secret.yaml
```

### **5. Production Sealed Secrets для HashFoundry:**
```yaml
# hashfoundry-sealed-secrets.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: hashfoundry-app-config
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: config
spec:
  encryptedData:
    database-password: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    api-key: AgAKAoiQm7xFtFqKJ8Z5X9Y2N1vP8wE4Ox...
    jwt-secret: AgBxQm9vK2L8N5M3P7R1S6T4U8V2W9X0Y...
    redis-password: AgCyDm8wL5N2O6P3Q7R4S8T1U5V9W2X6Y...
  template:
    metadata:
      name: hashfoundry-app-config
      namespace: hashfoundry-production
      labels:
        app.kubernetes.io/name: hashfoundry-webapp
        app.kubernetes.io/component: config
    type: Opaque

---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: hashfoundry-docker-registry
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: registry
spec:
  encryptedData:
    .dockerconfigjson: AgDxEm7wK4L9N2O5P8Q1R6S3T7U0V4W8X...
  template:
    metadata:
      name: hashfoundry-docker-registry
      namespace: hashfoundry-production
      labels:
        app.kubernetes.io/name: hashfoundry-webapp
        app.kubernetes.io/component: registry
    type: kubernetes.io/dockerconfigjson

---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: hashfoundry-monitoring-secrets
  namespace: monitoring
  labels:
    app.kubernetes.io/name: hashfoundry-monitoring
    app.kubernetes.io/component: secrets
spec:
  encryptedData:
    grafana-admin-password: AgExFm6vJ3K8L1M4N7O0P3Q6R9S2T5U8V...
    prometheus-basic-auth: AgFyGn5uI2J7K0L3M6N9O2P5Q8R1S4T7U...
    alertmanager-webhook-url: AgGzHo4tH1I6J9K2L5M8N1O4P7Q0R3S6T...
  template:
    metadata:
      name: hashfoundry-monitoring-secrets
      namespace: monitoring
      labels:
        app.kubernetes.io/name: hashfoundry-monitoring
        app.kubernetes.io/component: secrets
    type: Opaque
```

## 🔄 **Advanced CI/CD Integration с Secrets:**

### **1. GitHub Actions с комплексным управлением секретами:**
```yaml
# .github/workflows/secrets-management.yml
name: Secrets Management CI/CD

on:
  push:
    branches: [main, develop, staging]
    paths:
    - 'k8s/secrets/**'
    - 'vault/**'
    - '.github/workflows/secrets-management.yml'
  pull_request:
    branches: [main]
    paths:
    - 'k8s/secrets/**'

env:
  VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
  KUBESEAL_VERSION: '0.24.0'

jobs:
  # Валидация секретов
  validate-secrets:
    name: Validate Secrets Configuration
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: '1.28.0'

    - name: Install kubeseal
      run: |
        curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
        tar -xvf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
        sudo install -m 755 kubeseal /usr/local/bin/kubeseal

    - name: Validate Sealed Secrets
      run: |
        echo "🔍 Validating Sealed Secrets..."
        for file in k8s/secrets/sealed/*.yaml; do
          if [ -f "$file" ]; then
            echo "Validating $file"
            kubectl apply --dry-run=client -f "$file"
          fi
        done

    - name: Validate External Secrets
      run: |
        echo "🔍 Validating External Secrets..."
        for file in k8s/secrets/external/*.yaml; do
          if [ -f "$file" ]; then
            echo "Validating $file"
            kubectl apply --dry-run=client -f "$file"
          fi
        done

    - name: Check for hardcoded secrets
      run: |
        echo "🔍 Checking for hardcoded secrets..."
        
        # Check for base64 encoded secrets in YAML files
        if grep -r "password.*:" k8s/ | grep -v "passwordRef\|passwordFrom" | grep -E "[A-Za-z0-9+/]{20,}"; then
          echo "❌ Found potential hardcoded secrets!"
          exit 1
        fi
        
        # Check for common secret patterns
        if grep -r -E "(password|secret|key|token).*['\"][^'\"]{10,}['\"]" k8s/ --exclude-dir=.git; then
          echo "❌ Found potential hardcoded secrets!"
          exit 1
        fi
        
        echo "✅ No hardcoded secrets found"

  # Синхронизация с Vault
  sync-vault-secrets:
    name: Sync Vault Secrets
    runs-on: ubuntu-latest
    needs: validate-secrets
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Vault CLI
      run: |
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update && sudo apt-get install vault

    - name: Authenticate with Vault
      run: |
        vault auth -method=github token=${{ secrets.GITHUB_TOKEN }}

    - name: Sync secrets to Vault
      run: |
        echo "🔄 Syncing secrets to Vault..."
        
        # Read secrets from configuration files and sync to Vault
        for env in development staging production; do
          echo "Syncing $env secrets..."
          
          if [ -f "vault/secrets/$env.json" ]; then
            vault kv put secret/hashfoundry/$env @vault/secrets/$env.json
          fi
        done

    - name: Verify Vault sync
      run: |
        echo "✅ Verifying Vault sync..."
        vault kv list secret/hashfoundry/

  # Создание Sealed Secrets
  create-sealed-secrets:
    name: Create Sealed Secrets
    runs-on: ubuntu-latest
    needs: validate-secrets
    if: github.event_name == 'pull_request'
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: '1.28.0'

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBECONFIG }}" | base64 -d > ~/.kube/config

    - name: Install kubeseal
      run: |
        curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
        tar -xvf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
        sudo install -m 755 kubeseal /usr/local/bin/kubeseal

    - name: Create Sealed Secrets from templates
      run: |
        echo "🔐 Creating Sealed Secrets..."
        
        for template in k8s/secrets/templates/*.yaml; do
          if [ -f "$template" ]; then
            filename=$(basename "$template" .yaml)
            echo "Processing $filename"
            
            # Replace placeholders with GitHub secrets
            envsubst < "$template" > "/tmp/$filename-temp.yaml"
            
            # Seal the secret
            kubeseal -f "/tmp/$filename-temp.yaml" -w "k8s/secrets/sealed/$filename-sealed.yaml"
            
            # Clean up temporary file
            rm "/tmp/$filename-temp.yaml"
          fi
        done

    - name: Commit sealed secrets
      run: |
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        git add k8s/secrets/sealed/
        git commit -m "Update sealed secrets" || exit 0
        git push

  # Развертывание секретов
  deploy-secrets:
    name: Deploy Secrets
    runs-on: ubuntu-latest
    needs: [validate-secrets, sync-vault-secrets]
    if: github.ref == 'refs/heads/main'
    environment: production
    strategy:
      matrix:
        environment: [development, staging, production]
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: '1.28.0'

    - name: Configure kubectl
      run: |
        echo "${{ secrets[format('KUBECONFIG_{0}', matrix.environment)] }}" | base64 -d > ~/.kube/config

    - name: Deploy External Secrets
      run: |
        echo "🚀 Deploying External Secrets to ${{ matrix.environment }}..."
        
        # Deploy Secret Stores
        kubectl apply -f k8s/secrets/stores/${{ matrix.environment }}/
        
        # Wait for Secret Stores to be ready
        kubectl wait --for=condition=Ready secretstore --all -n hashfoundry-${{ matrix.environment }} --timeout=60s
        
        # Deploy External Secrets
        kubectl apply -f k8s/secrets/external/${{ matrix.environment }}/
        
        # Wait for External Secrets to sync
        kubectl wait --for=condition=Ready externalsecret --all -n hashfoundry-${{ matrix.environment }} --timeout=120s

    - name: Deploy Sealed Secrets
      run: |
        echo "🔐 Deploying Sealed Secrets to ${{ matrix.environment }}..."
        
        # Deploy Sealed Secrets
        kubectl apply -f k8s/secrets/sealed/${{ matrix.environment }}/

    - name: Verify secrets deployment
      run: |
        echo "✅ Verifying secrets deployment in ${{ matrix.environment }}..."
        
        # Check External Secrets status
        kubectl get externalsecrets -n hashfoundry-${{ matrix.environment }}
        
        # Check Sealed Secrets status
        kubectl get sealedsecrets -n hashfoundry-${{ matrix.environment }}
        
        # Check actual secrets
        kubectl get secrets -n hashfoundry-${{ matrix.environment }} -l app.kubernetes.io/name=hashfoundry-webapp

    - name: Test secret accessibility
      run: |
        echo "🧪 Testing secret accessibility..."
        
        # Create test pod to verify secret mounting
        kubectl run secret-test-${{ matrix.environment }} \
          --image=busybox:1.35 \
          --restart=Never \
          --rm -i --tty \
          --namespace=hashfoundry-${{ matrix.environment }} \
          --overrides='{
            "spec": {
              "containers": [{
                "name": "secret-test",
                "image": "busybox:1.35",
                "command": ["sh", "-c", "echo Testing secrets && ls -la /etc/secrets/ && cat /etc/secrets/database-password && exit 0"],
                "volumeMounts": [{
                  "name": "secret-volume",
                  "mountPath": "/etc/secrets",
                  "readOnly": true
                }]
              }],
              "volumes": [{
                "name": "secret-volume",
                "secret": {
                  "secretName": "hashfoundry-database-secrets"
                }
              }]
            }
          }' -- sleep 30

  # Мониторинг секретов
  monitor-secrets:
    name: Monitor Secrets
    runs-on: ubuntu-latest
    needs: deploy-secrets
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: '1.28.0'

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBECONFIG_PROD }}" | base64 -d > ~/.kube/config

    - name: Monitor External Secrets status
      run: |
        echo "📊 Monitoring External Secrets status..."
        
        # Check External Secrets health
        kubectl get externalsecrets -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.conditions[0].type,READY:.status.conditions[0].status,AGE:.metadata.creationTimestamp"
        
        # Check for failed External Secrets
        FAILED_SECRETS=$(kubectl get externalsecrets -A -o json | jq -r '.items[] | select(.status.conditions[]?.type == "Ready" and .status.conditions[]?.status == "False") | "\(.metadata.namespace)/\(.metadata.name)"')
        
        if [ -n "$FAILED_SECRETS" ]; then
          echo "❌ Failed External Secrets found:"
          echo "$FAILED_SECRETS"
          exit 1
        fi
        
        echo "✅ All External Secrets are healthy"

    - name: Check secret rotation status
      run: |
        echo "🔄 Checking secret rotation status..."
        
        # Check last refresh time for External Secrets
        kubectl get externalsecrets -A -o json | jq -r '
          .items[] | 
          "\(.metadata.namespace)/\(.metadata.name): Last refresh: \(.status.refreshTime // "Never")"
        '

    - name: Audit secret access
      run: |
        echo "🔍 Auditing secret access..."
        
        # Check which pods are using secrets
        kubectl get pods -A -o json | jq -r '
          .items[] | 
          select(.spec.volumes[]?.secret or .spec.containers[].env[]?.valueFrom.secretKeyRef) | 
          "\(.metadata.namespace)/\(.metadata.name): Uses secrets"
        '

    - name: Generate secrets report
      run: |
        echo "📋 Generating secrets report..."
        
        cat << EOF > secrets-report.md
        # Secrets Management Report
        
        ## External Secrets Status
        $(kubectl get externalsecrets -A -o wide)
        
        ## Sealed Secrets Status
        $(kubectl get sealedsecrets -A -o wide 2>/dev/null || echo "No Sealed Secrets found")
        
        ## Secret Stores Status
        $(kubectl get secretstores -A -o wide 2>/dev/null || echo "No Secret Stores found")
        
        ## Secrets by Namespace
        $(kubectl get secrets -A --sort-by=.metadata.namespace -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.type,AGE:.metadata.creationTimestamp")
        
        ## Pods Using Secrets
        $(kubectl get pods -A -o json | jq -r '.items[] | select(.spec.volumes[]?.secret or .spec.containers[].env[]?.valueFrom.secretKeyRef) | "\(.metadata.namespace)/\(.metadata.name)"')
        EOF
        
        echo "Report generated: secrets-report.md"

    - name: Upload secrets report
      uses: actions/upload-artifact@v3
      with:
        name: secrets-report
        path: secrets-report.md
```

### **2. Jenkins Pipeline для управления секретами:**
```groovy
// Jenkinsfile-secrets
pipeline {
    agent any
    
    environment {
        VAULT_ADDR = credentials('vault-addr')
        VAULT_TOKEN = credentials('vault-token')
        KUBESEAL_VERSION = '0.24.0'
    }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['development', 'staging', 'production'],
            description: 'Target environment'
        )
        choice(
            name: 'ACTION',
            choices: ['deploy', 'rotate', 'audit', 'backup'],
            description: 'Action to perform'
        )
        booleanParam(
            name: 'FORCE_ROTATION',
            defaultValue: false,
            description: 'Force secret rotation'
        )
    }
    
    stages {
        stage('Setup') {
            steps {
                script {
                    // Install required tools
                    sh '''
                        # Install Vault CLI
                        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
                        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
                        sudo apt-get update && sudo apt-get install vault
                        
                        # Install kubeseal
                        curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
                        tar -xvf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
                        sudo install -m 755 kubeseal /usr/local/bin/kubeseal
                        rm kubeseal kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
                    '''
                }
            }
        }
        
        stage('Validate Secrets') {
            steps {
                script {
                    echo "🔍 Validating secrets configuration..."
                    sh '''
                        # Validate External Secrets
                        for file in k8s/secrets/external/${ENVIRONMENT}/*.yaml; do
                            if [ -f "$file" ]; then
                                echo "Validating $file"
                                kubectl apply --dry-run=client -f "$file"
                            fi
                        done
                        
                        # Validate Sealed Secrets
                        for file in k8s/secrets/sealed/${ENVIRONMENT}/*.yaml; do
                            if [ -f "$file" ]; then
                                echo "Validating $file"
                                kubectl apply --dry-run=client -f "$file"
                            fi
                        done
                    '''
                }
            }
        }
        
        stage('Deploy Secrets') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                script {
                    echo "🚀 Deploying secrets to ${params.ENVIRONMENT}..."
                    sh '''
                        # Configure kubectl for target environment
                        export KUBECONFIG=/var/lib/jenkins/.kube/config-${ENVIRONMENT}
                        
                        # Deploy Secret Stores
                        kubectl apply -f k8s/secrets/stores/${ENVIRONMENT}/
                        
                        # Wait for Secret Stores to be ready
                        kubectl wait --for=condition=Ready secretstore --all -n hashfoundry-${ENVIRONMENT} --timeout=60s
                        
                        # Deploy External Secrets
                        kubectl apply -f k8s/secrets/external/${ENVIRONMENT}/
                        
                        # Deploy Sealed Secrets
                        kubectl apply -f k8s/secrets/sealed/${ENVIRONMENT}/
                        
                        # Verify deployment
                        kubectl get externalsecrets -n hashfoundry-${ENVIRONMENT}
                        kubectl get sealedsecrets -n hashfoundry-${ENVIRONMENT}
                        kubectl get secrets -n hashfoundry-${ENVIRONMENT} -l app.kubernetes.io/name=hashfoundry-webapp
                    '''
                }
            }
        }
        
        stage('Rotate Secrets') {
            when {
                expression { params.ACTION == 'rotate' }
            }
            steps {
                script {
                    echo "🔄 Rotating secrets in ${params.ENVIRONMENT}..."
                    sh '''
                        # Authenticate with Vault
                        vault auth -method=token token=${VAULT_TOKEN}
                        
                        # Generate new secrets
                        NEW_DB_PASSWORD=$(openssl rand -base64 32)
                        NEW_API_KEY=$(openssl rand -hex 32)
                        NEW_JWT_SECRET=$(openssl rand -base64 64)
                        
                        # Update secrets in Vault
                        vault kv put secret/hashfoundry/${ENVIRONMENT}/database password="$NEW_DB_PASSWORD"
                        vault kv put secret/hashfoundry/${ENVIRONMENT}/api api_key="$NEW_API_KEY" jwt_secret="$NEW_JWT_SECRET"
                        
                        # Force External Secrets refresh
                        kubectl annotate externalsecret hashfoundry-database-secrets -n hashfoundry-${ENVIRONMENT} force-sync="$(date +%s)" --overwrite
                        kubectl annotate externalsecret hashfoundry-api-secrets -n hashfoundry-${ENVIRONMENT} force-sync="$(date +%s)" --overwrite
                        
                        # Wait for secrets to be updated
                        sleep 30
                        
                        # Restart deployments to pick up new secrets
                        kubectl rollout restart deployment -n hashfoundry-${ENVIRONMENT} -l app.kubernetes.io/name=hashfoundry-webapp
                        
                        # Wait for rollout to complete
                        kubectl rollout status deployment -n hashfoundry-${ENVIRONMENT} -l app.kubernetes.io/name=hashfoundry-webapp --timeout=300s
                    '''
                }
            }
        }
        
        stage('Audit Secrets') {
            when {
                expression { params.ACTION == 'audit' }
            }
            steps {
                script {
                    echo "🔍 Auditing secrets in ${params.ENVIRONMENT}..."
                    sh '''
                        # Generate audit report
                        cat << EOF > secrets-audit-${ENVIRONMENT}.md
                        # Secrets Audit Report - ${ENVIRONMENT}
                        
                        ## External Secrets Status
                        $(kubectl get externalsecrets -n hashfoundry-${ENVIRONMENT} -o wide)
                        
                        ## Secret Stores Status
                        $(kubectl get secretstores -n hashfoundry-${ENVIRONMENT} -o wide)
                        
                        ## Secrets List
                        $(kubectl get secrets -n hashfoundry-${ENVIRONMENT} -o custom-columns="NAME:.metadata.name,TYPE:.type,AGE:.metadata.creationTimestamp")
                        
                        ## Pods Using Secrets
                        $(kubectl get pods -n hashfoundry-${ENVIRONMENT} -o json | jq -r '.items[] | select(.spec.volumes[]?.secret or .spec.containers[].env[]?.valueFrom.secretKeyRef) | .metadata.name')
                        
                        ## Secret Access Patterns
                        $(kubectl get pods -n hashfoundry-${ENVIRONMENT} -o json | jq -r '.items[] | "\(.metadata.name):" as $pod | (.spec.containers[].env[]? | select(.valueFrom.secretKeyRef) | "  Secret: \(.valueFrom.secretKeyRef.name), Key: \(.valueFrom.secretKeyRef.key)"), (.spec.volumes[]? | select(.secret) | "  Volume Secret: \(.secret.secretName)")')
                        EOF
                        
                        echo "Audit report generated: secrets-audit-${ENVIRONMENT}.md"
                    '''
                    
                    // Archive audit report
                    archiveArtifacts artifacts: "secrets-audit-${params.ENVIRONMENT}.md", fingerprint: true
                }
            }
        }
        
        stage('Backup Secrets') {
            when {
                expression { params.ACTION == 'backup' }
            }
            steps {
                script {
                    echo "💾 Backing up secrets from ${params.ENVIRONMENT}..."
                    sh '''
                        # Create backup directory
                        mkdir -p backups/${ENVIRONMENT}/$(date +%Y-%m-%d)
                        
                        # Backup External Secrets configurations
                        kubectl get externalsecrets -n hashfoundry-${ENVIRONMENT} -o yaml > backups/${ENVIRONMENT}/$(date +%Y-%m-%d)/external-secrets.yaml
                        
                        # Backup Secret Stores configurations
                        kubectl get secretstores -n hashfoundry-${ENVIRONMENT} -o yaml > backups/${ENVIRONMENT}/$(date +%Y-%m-%d)/secret-stores.yaml
                        
                        # Backup Sealed Secrets
                        kubectl get sealedsecrets -n hashfoundry-${ENVIRONMENT} -o yaml > backups/${ENVIRONMENT}/$(date +%Y-%m-%d)/sealed-secrets.yaml
                        
                        # Create backup metadata
                        cat << EOF > backups/${ENVIRONMENT}/$(date +%Y-%m-%d)/metadata.json
                        {
                          "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
                          "environment": "${ENVIRONMENT}",
                          "kubernetes_version": "$(kubectl version --short --client)",
                          "external_secrets_count": $(kubectl get externalsecrets -n hashfoundry-${ENVIRONMENT} --no-headers | wc -l),
                          "sealed_secrets_count": $(kubectl get sealedsecrets -n hashfoundry-${ENVIRONMENT} --no-headers 2>/dev/null | wc -l || echo 0),
                          "secret_stores_count": $(kubectl get secretstores -n hashfoundry-${ENVIRONMENT} --no-headers 2>/dev/null | wc -l || echo 0)
                        }
                        EOF
                        
                        # Compress backup
                        tar -czf backups/secrets-backup-${ENVIRONMENT}-$(date +%Y-%m-%d).tar.gz -C backups/${ENVIRONMENT}/$(date +%Y-%m-%d) .
                        
                        echo "Backup created: secrets-backup-${ENVIRONMENT}-$(date +%Y-%m-%d).tar.gz"
                    '''
                    
                    // Archive backup
                    archiveArtifacts artifacts: "backups/secrets-backup-${params.ENVIRONMENT}-*.tar.gz", fingerprint: true
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Cleanup
                sh 'rm -rf backups/'
            }
        }
        
        success {
            script {
                echo "✅ Secrets management completed successfully!"
                
                // Notify Slack
                slackSend(
                    channel: '#security',
                    color: 'good',
                    message: """
                        ✅ Secrets Management Successful
                        Environment: ${params.ENVIRONMENT}
                        Action: ${params.ACTION}
                        Build: ${BUILD_NUMBER}
                    """
                )
            }
        }
        
        failure {
            script {
                echo "❌ Secrets management failed!"
                
                // Notify Slack
                slackSend(
                    channel: '#security',
                    color: 'danger',
                    message: """
                        ❌ Secrets Management Failed
                        Environment: ${params.ENVIRONMENT}
                        Action: ${params.ACTION}
                        Build: ${BUILD_NUMBER}
                        Please check logs for details
                    """
                )
            }
        }
    }
}
```

## 🔐 **Advanced Security Practices:**

### **1. RBAC для управления секретами:**
```yaml
# rbac-secrets.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secrets-manager
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: secrets-manager
    app.kubernetes.io/component: security
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: hashfoundry-production
  name: secrets-manager
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["external-secrets.io"]
  resources: ["externalsecrets", "secretstores"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["bitnami.com"]
  resources: ["sealedsecrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secrets-manager
  namespace: hashfoundry-production
subjects:
- kind: ServiceAccount
  name: secrets-manager
  namespace: hashfoundry-production
roleRef:
  kind: Role
  name: secrets-manager
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secrets-auditor
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
- apiGroups: ["external-secrets.io"]
  resources: ["externalsecrets", "secretstores", "clustersecretstores"]
  verbs: ["get", "list"]
- apiGroups: ["bitnami.com"]
  resources: ["sealedsecrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secrets-auditor
subjects:
- kind: ServiceAccount
  name: secrets-auditor
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: secrets-auditor
  apiGroup: rbac.authorization.k8s.io
```

### **2. Network Policies для изоляции секретов:**
```yaml
# network-policy-secrets.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-secrets-isolation
  namespace: external-secrets-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: external-secrets
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
      port: 443  # HTTPS to Vault
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sealed-secrets-isolation
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      name: sealed-secrets-controller
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # Kubernetes API
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
```

## 📊 **Monitoring и Alerting для секретов:**

### **1. Prometheus мониторинг секретов:**
```yaml
# monitoring/secrets-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: external-secrets-metrics
  namespace: monitoring
  labels:
    app.kubernetes.io/name: external-secrets
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: external-secrets
  namespaceSelector:
    matchNames:
    - external-secrets-system
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: secrets-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: secrets-alerts
    release: prometheus
spec:
  groups:
  - name: secrets.rules
    rules:
    # External Secret sync failure
    - alert: ExternalSecretSyncFailure
      expr: external_secrets_sync_calls_total{status="error"} > 0
      for: 5m
      labels:
        severity: critical
        component: external-secrets
      annotations:
        summary: "External Secret sync failure"
        description: "External Secret {{ $labels.name }} in namespace {{ $labels.namespace }} failed to sync."
        runbook_url: "https://docs.hashfoundry.com/runbooks/external-secret-sync-failure"
    
    # Secret not found
    - alert: SecretNotFound
      expr: external_secrets_sync_calls_total{status="not_found"} > 0
      for: 2m
      labels:
        severity: warning
        component: external-secrets
      annotations:
        summary: "Secret not found in external store"
        description: "External Secret {{ $labels.name }} cannot find secret in external store."
        runbook_url: "https://docs.hashfoundry.com/runbooks/secret-not-found"
    
    # Secret expiring soon
    - alert: SecretExpiringSoon
      expr: (cert_exporter_cert_expires_in_seconds < 86400 * 7) and (cert_exporter_cert_expires_in_seconds > 0)
      for: 1h
      labels:
        severity: warning
        component: certificates
      annotations:
        summary: "Certificate expiring soon"
        description: "Certificate {{ $labels.name }} expires in less than 7 days."
        runbook_url: "https://docs.hashfoundry.com/runbooks/certificate-expiring"
    
    # Sealed Secrets controller down
    - alert: SealedSecretsControllerDown
      expr: up{job="sealed-secrets-controller"} == 0
      for: 5m
      labels:
        severity: critical
        component: sealed-secrets
      annotations:
        summary: "Sealed Secrets controller is down"
        description: "Sealed Secrets controller has been down for more than 5 minutes."
        runbook_url: "https://docs.hashfoundry.com/runbooks/sealed-secrets-controller-down"
```

### **2. Grafana Dashboard для секретов:**
```json
{
  "dashboard": {
    "id": null,
    "title": "HashFoundry Secrets Management",
    "tags": ["hashfoundry", "secrets", "security"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "External Secrets Status",
        "type": "stat",
        "targets": [
          {
            "expr": "count(external_secrets_sync_calls_total)",
            "legendFormat": "Total External Secrets"
          },
          {
            "expr": "count(external_secrets_sync_calls_total{status=\"success\"})",
            "legendFormat": "Successful Syncs"
          },
          {
            "expr": "count(external_secrets_sync_calls_total{status=\"error\"})",
            "legendFormat": "Failed Syncs"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 5}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "Secret Sync Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(external_secrets_sync_calls_total[5m])",
            "legendFormat": "Sync Rate - {{ $labels.name }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Secrets by Namespace",
        "type": "piechart",
        "targets": [
          {
            "expr": "count by (namespace) (kube_secret_info)",
            "legendFormat": "{{ $labels.namespace }}"
          }
        ]
      },
      {
        "id": 4,
        "title": "Certificate Expiration",
        "type": "table",
        "targets": [
          {
            "expr": "cert_exporter_cert_expires_in_seconds / 86400",
            "legendFormat": "Days until expiration",
            "format": "table"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

## 🎯 **Проверка секретов в вашем HA кластере:**

### **1. Comprehensive secrets audit script:**
```bash
#!/bin/bash
# scripts/audit-secrets.sh

echo "🔍 Comprehensive Secrets Audit for HashFoundry HA Cluster"

# 1. Анализ всех секретов
echo "📊 Secrets Overview:"
kubectl get secrets -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.type,DATA-KEYS:.data,AGE:.metadata.creationTimestamp" | sort

# 2. Анализ по типам секретов
echo "📋 Secrets by Type:"
kubectl get secrets -A -o json | jq -r '.items | group_by(.type) | .[] | "\(.[0].type): \(length) secrets"'

# 3. Поиск потенциально небезопасных секретов
echo "⚠️ Security Analysis:"
echo "Secrets with default names:"
kubectl get secrets -A | grep -E "(default|admin|root|password|secret)"

echo "Large secrets (potential data leaks):"
kubectl get secrets -A -o json | jq -r '.items[] | select((.data | length) > 10) | "\(.metadata.namespace)/\(.metadata.name): \(.data | length) keys"'

# 4. Анализ использования секретов
echo "🔗 Secret Usage Analysis:"
kubectl get pods -A -o json | jq -r '
  .items[] | 
  {
    namespace: .metadata.namespace,
    pod: .metadata.name,
    secrets: [
      (.spec.volumes[]? | select(.secret) | .secret.secretName),
      (.spec.containers[].env[]? | select(.valueFrom.secretKeyRef) | .valueFrom.secretKeyRef.name),
      (.spec.containers[].envFrom[]? | select(.secretRef) | .secretRef.name)
    ] | unique
  } | 
  select(.secrets | length > 0) | 
  "\(.namespace)/\(.pod): \(.secrets | join(\", \"))"
'

# 5. Проверка External Secrets
echo "🔄 External Secrets Status:"
if kubectl get externalsecrets -A &>/dev/null; then
    kubectl get externalsecrets -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.conditions[0].type,READY:.status.conditions[0].status,LAST-SYNC:.status.refreshTime"
else
    echo "External Secrets Operator not installed"
fi

# 6. Проверка Sealed Secrets
echo "🔐 Sealed Secrets Status:"
if kubectl get sealedsecrets -A &>/dev/null; then
    kubectl get sealedsecrets -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,AGE:.metadata.creationTimestamp"
else
    echo "Sealed Secrets not installed"
fi

# 7. Анализ RBAC для секретов
echo "🛡️ RBAC Analysis for Secrets:"
kubectl get rolebindings,clusterrolebindings -A -o json | jq -r '
  .items[] | 
  select(.roleRef.apiGroup == "rbac.authorization.k8s.io" and (.roleRef.kind == "Role" or .roleRef.kind == "ClusterRole")) | 
  "\(.metadata.namespace // "cluster")/\(.metadata.name): \(.roleRef.name)"
' | grep -i secret || echo "No specific secret RBAC found"

# 8. Проверка Service Account токенов
echo "🎫 Service Account Token Analysis:"
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SA:.metadata.annotations.kubernetes\.io/service-account\.name,AGE:.metadata.creationTimestamp"

# 9. Анализ TLS секретов
echo "🔒 TLS Secrets Analysis:"
kubectl get secrets -A --field-selector type=kubernetes.io/tls -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,AGE:.metadata.creationTimestamp"

# 10. Проверка Docker registry секретов
echo "🐳 Docker Registry Secrets:"
kubectl get secrets -A --field-selector type=kubernetes.io/dockerconfigjson -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,AGE:.metadata.creationTimestamp"

echo "✅ Secrets audit completed!"
```

### **2. Real-time secrets monitoring:**
```bash
#!/bin/bash
# scripts/monitor-secrets-realtime.sh

echo "📊 Real-time Secrets Monitoring for HashFoundry HA Cluster"

monitor_secrets() {
    while true; do
        clear
        echo "🔄 Secrets Status - $(date)"
        echo "=================================="
        
        # External Secrets status
        if kubectl get externalsecrets -A &>/dev/null; then
            echo "📡 External Secrets:"
            kubectl get externalsecrets -A --no-headers | while read line; do
                namespace=$(echo $line | awk '{print $1}')
                name=$(echo $line | awk '{print $2}')
                status=$(kubectl get externalsecret $name -n $namespace -o jsonpath='{.status.conditions[0].status}' 2>/dev/null)
                
                if [ "$status" = "True" ]; then
                    echo -e "\033[32m  $namespace/$name: Ready\033[0m"
                elif [ "$status" = "False" ]; then
                    echo -e "\033[31m  $namespace/$name: Failed\033[0m"
                else
                    echo -e "\033[33m  $namespace/$name: Unknown\033[0m"
                fi
            done
        else
            echo "📡 External Secrets: Not installed"
        fi
        
        echo ""
        
        # Sealed Secrets status
        if kubectl get sealedsecrets -A &>/dev/null; then
            echo "🔐 Sealed Secrets:"
            kubectl get sealedsecrets -A --no-headers | while read line; do
                namespace=$(echo $line | awk '{print $1}')
                name=$(echo $line | awk '{print $2}')
                echo -e "\033[36m  $namespace/$name: Active\033[0m"
            done
        else
            echo "🔐 Sealed Secrets: Not installed"
        fi
        
        echo ""
        
        # Secrets statistics
        echo "📈 Secrets Statistics:"
        echo "Total secrets: $(kubectl get secrets -A --no-headers | wc -l)"
        echo "TLS secrets: $(kubectl get secrets -A --field-selector type=kubernetes.io/tls --no-headers | wc -l)"
        echo "Docker registry secrets: $(kubectl get secrets -A --field-selector type=kubernetes.io/dockerconfigjson --no-headers | wc -l)"
        echo "Service account tokens: $(kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token --no-headers | wc -l)"
        
        sleep 5
    done
}

# Запуск мониторинга
monitor_secrets
```

### **3. Automated secret rotation script:**
```bash
#!/bin/bash
# scripts/rotate-secrets.sh

echo "🔄 Automated Secret Rotation for HashFoundry HA Cluster"

ENVIRONMENT=${1:-production}
FORCE_ROTATION=${2:-false}

rotate_database_secrets() {
    echo "🗄️ Rotating database secrets..."
    
    # Generate new password
    NEW_PASSWORD=$(openssl rand -base64 32)
    
    # Update in Vault (if using External Secrets)
    if command -v vault &> /dev/null; then
        vault kv put secret/hashfoundry/$ENVIRONMENT/database password="$NEW_PASSWORD"
        echo "✅ Database password updated in Vault"
    fi
    
    # Force External Secret refresh
    if kubectl get externalsecret hashfoundry-database-secrets -n hashfoundry-$ENVIRONMENT &>/dev/null; then
        kubectl annotate externalsecret hashfoundry-database-secrets -n hashfoundry-$ENVIRONMENT \
            force-sync="$(date +%s)" --overwrite
        echo "✅ External Secret refresh triggered"
    fi
}

rotate_api_secrets() {
    echo "🔑 Rotating API secrets..."
    
    # Generate new API key and JWT secret
    NEW_API_KEY=$(openssl rand -hex 32)
    NEW_JWT_SECRET=$(openssl rand -base64 64)
    
    # Update in Vault
    if command -v vault &> /dev/null; then
        vault kv put secret/hashfoundry/$ENVIRONMENT/api \
            api_key="$NEW_API_KEY" \
            jwt_secret="$NEW_JWT_SECRET"
        echo "✅ API secrets updated in Vault"
    fi
    
    # Force External Secret refresh
    if kubectl get externalsecret hashfoundry-api-secrets -n hashfoundry-$ENVIRONMENT &>/dev/null; then
        kubectl annotate externalsecret hashfoundry-api-secrets -n hashfoundry-$ENVIRONMENT \
            force-sync="$(date +%s)" --overwrite
        echo "✅ External Secret refresh triggered"
    fi
}

restart_affected_deployments() {
    echo "🔄 Restarting affected deployments..."
    
    # Restart deployments that use the rotated secrets
    kubectl rollout restart deployment -n hashfoundry-$ENVIRONMENT \
        -l app.kubernetes.io/name=hashfoundry-webapp
    
    # Wait for rollout to complete
    kubectl rollout status deployment -n hashfoundry-$ENVIRONMENT \
        -l app.kubernetes.io/name=hashfoundry-webapp --timeout=300s
    
    echo "✅ Deployments restarted successfully"
}

# Main rotation logic
echo "Starting secret rotation for environment: $ENVIRONMENT"

if [ "$FORCE_ROTATION" = "true" ] || [ "$(date +%u)" = "1" ]; then
    echo "🔄 Performing weekly secret rotation..."
    
    rotate_database_secrets
    rotate_api_secrets
    
    # Wait for secrets to propagate
    sleep 30
    
    restart_affected_deployments
    
    echo "✅ Secret rotation completed successfully!"
else
    echo "ℹ️ Skipping rotation (not forced and not Monday)"
fi
```

## 🎓 **Заключение:**

**Управление секретами в CI/CD с Kubernetes** требует комплексного подхода, включающего:

### **🔑 Ключевые принципы:**
1. **Безопасное хранение** - использование внешних систем управления секретами (Vault, AWS Secrets Manager)
2. **Шифрование** - защита секретов в покое и в движении
3. **Принцип минимальных привилегий** - ограничение доступа к секретам
4. **Автоматическая ротация** - регулярное обновление секретов
5. **Мониторинг и аудит** - отслеживание использования секретов
6. **Compliance** - соответствие стандартам безопасности (SOC2, PCI DSS, GDPR)

### **🛠️ Основные инструменты:**
- **External Secrets Operator** - синхронизация с внешними хранилищами секретов
- **Sealed Secrets** - шифрование секретов для безопасного хранения в Git
- **HashiCorp Vault** - централизованное управление секретами
- **RBAC** - контроль доступа к секретам на уровне Kubernetes
- **Network Policies** - изоляция компонентов управления секретами

### **📊 Мониторинг и алертинг:**
- **Prometheus** - сбор метрик о состоянии секретов
- **Grafana** - визуализация и дашборды
- **Alertmanager** - уведомления о проблемах с секретами

### **🎯 Основные команды для изучения в вашем HA кластере:**
```bash
# Анализ секретов
kubectl get secrets -A
kubectl get secrets -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.type)"'

# Проверка использования секретов
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.volumes[]?.secret) | "\(.metadata.namespace)/\(.metadata.name)"'

# Мониторинг External Secrets
kubectl get externalsecrets -A
kubectl get secretstores -A

# Аудит безопасности
kubectl get secrets -A --field-selector type=kubernetes.io/tls
kubectl get secrets -A --field-selector type=kubernetes.io/dockerconfigjson

# Проверка RBAC
kubectl auth can-i get secrets --as=system:serviceaccount:default:default
```

### **🚀 Следующие шаги:**
1. Изучите существующие секреты в вашем HA кластере с помощью предоставленных команд
2. Рассмотрите внедрение External Secrets Operator для централизованного управления
3. Настройте мониторинг секретов с помощью Prometheus и Grafana
4. Внедрите автоматическую ротацию секретов в CI/CD пайплайны
5. Проведите аудит безопасности существующих секретов

**Помните:** Безопасность секретов - это не разовая задача, а непрерывный процесс, требующий постоянного внимания и улучшения!
