# 145. Как обрабатывать секреты в CI/CD с Kubernetes?

## 🎯 Вопрос
Как обрабатывать секреты в CI/CD с Kubernetes?

## 💡 Ответ

Безопасное управление секретами в CI/CD с Kubernetes требует комплексного подхода, включающего шифрование, ротацию и принцип минимальных привилегий.

### 🔐 Основные принципы безопасности секретов

#### 1. **Никогда не храните секреты в коде**
```yaml
# ❌ НЕПРАВИЛЬНО - секреты в коде
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
data:
  password: cGFzc3dvcmQxMjM=  # НЕ ДЕЛАЙТЕ ТАК!

# ✅ ПРАВИЛЬНО - ссылка на внешний источник
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
  data:
  - secretKey: password
    remoteRef:
      key: myapp/prod
      property: password
```

#### 2. **Разделение секретов по окружениям**
```bash
# Структура секретов
secrets/
├── dev/
│   ├── database.yaml
│   └── api-keys.yaml
├── staging/
│   ├── database.yaml
│   └── api-keys.yaml
└── production/
    ├── database.yaml
    └── api-keys.yaml
```

### 🛠️ Инструменты для управления секретами

#### 1. **Sealed Secrets**
```bash
# Установка Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Создание секрета
echo -n mypassword | kubectl create secret generic mysecret \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > mysecret-sealed.yaml
```

```yaml
# mysecret-sealed.yaml - безопасно хранить в Git
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mysecret
  namespace: production
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
  template:
    metadata:
      name: mysecret
      namespace: production
```

#### 2. **External Secrets Operator**
```yaml
# SecretStore для HashiCorp Vault
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: production
spec:
  provider:
    vault:
      server: "https://vault.company.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "myapp-role"
          serviceAccountRef:
            name: external-secrets-sa
```

```yaml
# ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-config
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-config
    creationPolicy: Owner
  data:
  - secretKey: database-url
    remoteRef:
      key: myapp/production
      property: database_url
  - secretKey: api-key
    remoteRef:
      key: myapp/production
      property: api_key
```

### 📊 Примеры из нашего кластера

#### Проверка секретов в namespace:
```bash
kubectl get secrets -n argocd
```

#### Просмотр External Secrets:
```bash
kubectl get externalsecrets -A
kubectl get secretstores -A
```

#### Проверка Sealed Secrets:
```bash
kubectl get sealedsecrets -A
```

### 🎯 CI/CD интеграция с секретами

#### 1. **GitHub Actions с секретами**
```yaml
# .github/workflows/deploy.yml
name: Deploy with Secrets

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v1
    
    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > ~/.kube/config
    
    - name: Create sealed secret
      run: |
        echo -n "${{ secrets.DATABASE_PASSWORD }}" | \
        kubectl create secret generic db-secret \
          --dry-run=client --from-file=password=/dev/stdin -o yaml | \
        kubeseal -o yaml > k8s/db-secret-sealed.yaml
    
    - name: Deploy application
      run: |
        kubectl apply -f k8s/
        kubectl rollout status deployment/myapp -n production
```

#### 2. **Jenkins с Vault интеграцией**
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        VAULT_ADDR = 'https://vault.company.com'
        VAULT_NAMESPACE = 'myapp'
    }
    
    stages {
        stage('Get Secrets') {
            steps {
                withVault([
                    configuration: [
                        vaultUrl: env.VAULT_ADDR,
                        vaultCredentialId: 'vault-token'
                    ],
                    vaultSecrets: [
                        [
                            path: 'secret/myapp/production',
                            secretValues: [
                                [envVar: 'DB_PASSWORD', vaultKey: 'database_password'],
                                [envVar: 'API_KEY', vaultKey: 'api_key']
                            ]
                        ]
                    ]
                ]) {
                    sh '''
                        # Создание секрета в Kubernetes
                        kubectl create secret generic app-secrets \
                          --from-literal=db-password="$DB_PASSWORD" \
                          --from-literal=api-key="$API_KEY" \
                          --namespace production \
                          --dry-run=client -o yaml | kubectl apply -f -
                    '''
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh '''
                    kubectl apply -f k8s/
                    kubectl rollout status deployment/myapp -n production
                '''
            }
        }
    }
}
```

### 🔄 Ротация секретов

#### 1. **Автоматическая ротация с External Secrets**
```yaml
# ExternalSecret с автоматическим обновлением
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rotating-secret
  namespace: production
spec:
  refreshInterval: 1h  # Проверка каждый час
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: rotating-secret
    creationPolicy: Owner
  data:
  - secretKey: token
    remoteRef:
      key: myapp/tokens
      property: access_token
```

#### 2. **Скрипт для ротации секретов**
```bash
#!/bin/bash
# rotate-secrets.sh

NAMESPACE="production"
SECRET_NAME="app-secrets"

echo "🔄 Ротация секретов для $SECRET_NAME в $NAMESPACE"

# Генерация нового пароля
NEW_PASSWORD=$(openssl rand -base64 32)

# Обновление в Vault
vault kv put secret/myapp/production password="$NEW_PASSWORD"

# Принудительное обновление External Secret
kubectl annotate externalsecret $SECRET_NAME -n $NAMESPACE \
  force-sync=$(date +%s) --overwrite

# Ожидание обновления секрета
kubectl wait --for=condition=Ready externalsecret/$SECRET_NAME -n $NAMESPACE --timeout=60s

# Перезапуск подов для применения нового секрета
kubectl rollout restart deployment/myapp -n $NAMESPACE

echo "✅ Ротация секретов завершена"
```

### 🎪 Практические примеры

#### 1. **Создание секрета для Docker Registry**
```bash
# Создание секрета для приватного реестра
kubectl create secret docker-registry regcred \
  --docker-server=myregistry.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@company.com \
  --namespace production

# Использование в Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
      containers:
      - name: myapp
        image: myregistry.com/myapp:latest
```

#### 2. **Секреты для TLS сертификатов**
```yaml
# Создание TLS секрета
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...  # base64 encoded cert
  tls.key: LS0tLS1CRUdJTi...  # base64 encoded key
```

```bash
# Создание TLS секрета из файлов
kubectl create secret tls tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace production
```

### 🔐 Безопасность в CI/CD

#### 1. **Service Account для CI/CD**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-cd-secrets-manager
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secrets-manager
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: ["external-secrets.io"]
  resources: ["externalsecrets"]
  verbs: ["get", "list", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-cd-secrets-manager
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secrets-manager
subjects:
- kind: ServiceAccount
  name: ci-cd-secrets-manager
  namespace: production
```

#### 2. **Аудит доступа к секретам**
```yaml
# Audit Policy для секретов
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
  namespaces: ["production", "staging"]
```

### 📈 Мониторинг секретов

#### 1. **Алерты для секретов**
```yaml
# PrometheusRule для мониторинга секретов
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: secrets-alerts
spec:
  groups:
  - name: secrets
    rules:
    - alert: ExternalSecretSyncFailed
      expr: external_secrets_sync_calls_error > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "External Secret sync failed"
    
    - alert: SecretExpiringSoon
      expr: (cert_exporter_not_after - time()) / 86400 < 30
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Certificate expires in less than 30 days"
```

#### 2. **Проверка состояния секретов**
```bash
#!/bin/bash
# check-secrets-health.sh

echo "🔍 Проверка состояния секретов..."

# Проверка External Secrets
kubectl get externalsecrets -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.conditions[0].type,READY:.status.conditions[0].status"

# Проверка Sealed Secrets
kubectl get sealedsecrets -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.conditions[0].type"

# Проверка истечения TLS сертификатов
kubectl get secrets -A -o json | jq -r '
  .items[] | 
  select(.type == "kubernetes.io/tls") | 
  "\(.metadata.namespace)/\(.metadata.name)"
' | while read secret; do
    echo "Checking TLS secret: $secret"
    kubectl get secret $secret -o jsonpath='{.data.tls\.crt}' | \
    base64 -d | openssl x509 -noout -dates
done
```

### 🎯 Лучшие практики

#### 1. **Принцип минимальных привилегий**
```yaml
# Ограниченный доступ к секретам
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-secrets-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-config", "db-credentials"]
  verbs: ["get"]
```

#### 2. **Шифрование в покое**
```yaml
# EncryptionConfiguration для etcd
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-key>
  - identity: {}
```

### 📋 Чек-лист безопасности секретов

- ✅ **Никогда не коммитьте секреты в Git**
- ✅ **Используйте внешние системы управления секретами**
- ✅ **Шифруйте секреты в покое и в движении**
- ✅ **Ротируйте секреты регулярно**
- ✅ **Ограничивайте доступ по принципу минимальных привилегий**
- ✅ **Мониторьте доступ к секретам**
- ✅ **Используйте разные секреты для разных окружений**
- ✅ **Автоматизируйте управление секретами**
- ✅ **Проводите аудит секретов**
- ✅ **Имейте план восстановления секретов**

Правильное управление секретами в CI/CD с Kubernetes обеспечивает безопасность приложений и соответствие требованиям безопасности.
