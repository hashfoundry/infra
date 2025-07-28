# 144. Какова роль Helm в CI/CD пайплайнах?

## 🎯 Вопрос
Какова роль Helm в CI/CD пайплайнах?

## 💡 Ответ

Helm играет ключевую роль в CI/CD пайплайнах как пакетный менеджер для Kubernetes, обеспечивая шаблонизацию, версионирование и управление релизами приложений.

### 🏗️ Основные функции Helm в CI/CD

#### 1. **Шаблонизация манифестов**
```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: {{ .Values.service.port }}
        env:
        {{- range .Values.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
```

#### 2. **Конфигурация через Values**
```yaml
# values.yaml
replicaCount: 3

image:
  repository: myapp
  tag: "1.0.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

env:
  - name: NODE_ENV
    value: production
  - name: LOG_LEVEL
    value: info

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### 🛠️ Helm в CI/CD пайплайнах

#### 1. **GitHub Actions с Helm**
```yaml
# .github/workflows/deploy.yml
name: Deploy with Helm

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Helm
      uses: azure/setup-helm@v1
      with:
        version: '3.10.0'
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v1
    
    - name: Build and push image
      run: |
        docker build -t myapp:${{ github.sha }} .
        docker push myregistry/myapp:${{ github.sha }}
    
    - name: Deploy to staging
      run: |
        helm upgrade --install myapp-staging ./helm-chart \
          --namespace staging \
          --create-namespace \
          --set image.tag=${{ github.sha }} \
          --set environment=staging \
          --wait --timeout=300s
    
    - name: Run tests
      run: |
        helm test myapp-staging --namespace staging
    
    - name: Deploy to production
      if: success()
      run: |
        helm upgrade --install myapp-prod ./helm-chart \
          --namespace production \
          --create-namespace \
          --set image.tag=${{ github.sha }} \
          --set environment=production \
          --set replicaCount=5 \
          --wait --timeout=600s
```

#### 2. **Jenkins Pipeline с Helm**
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        HELM_VERSION = '3.10.0'
        KUBECONFIG = credentials('kubeconfig')
    }
    
    stages {
        stage('Setup') {
            steps {
                sh '''
                    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                    chmod 700 get_helm.sh
                    ./get_helm.sh --version v${HELM_VERSION}
                '''
            }
        }
        
        stage('Lint') {
            steps {
                sh 'helm lint ./helm-chart'
            }
        }
        
        stage('Package') {
            steps {
                sh '''
                    helm package ./helm-chart --version ${BUILD_NUMBER}
                    helm repo index . --url https://charts.mycompany.com
                '''
            }
        }
        
        stage('Deploy') {
            steps {
                sh '''
                    helm upgrade --install myapp ./helm-chart \
                      --namespace production \
                      --set image.tag=${BUILD_NUMBER} \
                      --set buildNumber=${BUILD_NUMBER} \
                      --wait
                '''
            }
        }
    }
    
    post {
        failure {
            sh 'helm rollback myapp --namespace production'
        }
    }
}
```

### 📊 Примеры из нашего кластера

#### Проверка установленных Helm релизов:
```bash
helm list -A
```

#### Просмотр истории релизов:
```bash
helm history argocd -n argocd
```

#### Проверка статуса релиза:
```bash
helm status argocd -n argocd
```

### 🎯 Стратегии развертывания с Helm

#### 1. **Blue-Green развертывание**
```bash
#!/bin/bash
# blue-green-deploy.sh

RELEASE_NAME="myapp"
NAMESPACE="production"
NEW_VERSION="$1"

# Развертывание green версии
helm upgrade --install ${RELEASE_NAME}-green ./helm-chart \
  --namespace $NAMESPACE \
  --set image.tag=$NEW_VERSION \
  --set service.selector.version=green \
  --wait

# Проверка здоровья green версии
if helm test ${RELEASE_NAME}-green --namespace $NAMESPACE; then
    echo "Green версия здорова, переключение трафика..."
    
    # Переключение трафика на green
    kubectl patch service $RELEASE_NAME -n $NAMESPACE \
      -p '{"spec":{"selector":{"version":"green"}}}'
    
    # Удаление blue версии
    helm uninstall ${RELEASE_NAME}-blue --namespace $NAMESPACE
    
    # Переименование green в основной релиз
    helm upgrade --install $RELEASE_NAME ./helm-chart \
      --namespace $NAMESPACE \
      --set image.tag=$NEW_VERSION \
      --wait
else
    echo "Green версия нездорова, откат..."
    helm uninstall ${RELEASE_NAME}-green --namespace $NAMESPACE
    exit 1
fi
```

#### 2. **Canary развертывание**
```yaml
# values-canary.yaml
replicaCount: 1
canary:
  enabled: true
  weight: 10

service:
  canary:
    enabled: true
    weight: 10
```

```bash
# Canary развертывание
helm upgrade --install myapp-canary ./helm-chart \
  --namespace production \
  --values values-canary.yaml \
  --set image.tag=$NEW_VERSION

# Постепенное увеличение трафика
for weight in 25 50 75 100; do
    echo "Увеличение canary трафика до $weight%"
    helm upgrade myapp-canary ./helm-chart \
      --namespace production \
      --values values-canary.yaml \
      --set canary.weight=$weight \
      --set image.tag=$NEW_VERSION
    
    sleep 300  # Ожидание 5 минут
done
```

### 🔐 Безопасность с Helm

#### 1. **Управление секретами**
```yaml
# templates/secret.yaml
{{- if .Values.secrets }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "myapp.fullname" . }}-secrets
type: Opaque
data:
  {{- range $key, $value := .Values.secrets }}
  {{ $key }}: {{ $value | b64enc }}
  {{- end }}
{{- end }}
```

#### 2. **Helm Secrets плагин**
```bash
# Установка helm-secrets
helm plugin install https://github.com/jkroepke/helm-secrets

# Создание зашифрованного файла
helm secrets enc values-prod.yaml

# Развертывание с расшифровкой
helm secrets upgrade --install myapp ./helm-chart \
  --namespace production \
  --values secrets://values-prod.yaml
```

### 📈 Тестирование с Helm

#### 1. **Helm Tests**
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "myapp.fullname" . }}-test"
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  restartPolicy: Never
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "myapp.fullname" . }}:{{ .Values.service.port }}/health']
```

#### 2. **Интеграция с тестами**
```bash
#!/bin/bash
# test-deployment.sh

RELEASE_NAME="myapp-test"
NAMESPACE="testing"

# Развертывание тестовой версии
helm upgrade --install $RELEASE_NAME ./helm-chart \
  --namespace $NAMESPACE \
  --create-namespace \
  --set image.tag=$1 \
  --wait

# Запуск Helm тестов
if helm test $RELEASE_NAME --namespace $NAMESPACE; then
    echo "✅ Helm тесты прошли успешно"
else
    echo "❌ Helm тесты не прошли"
    helm uninstall $RELEASE_NAME --namespace $NAMESPACE
    exit 1
fi

# Запуск дополнительных тестов
kubectl run test-runner --rm -i --restart=Never \
  --image=test-image:latest \
  --env="TARGET_URL=http://$RELEASE_NAME.$NAMESPACE.svc.cluster.local" \
  -- /run-tests.sh

# Очистка
helm uninstall $RELEASE_NAME --namespace $NAMESPACE
```

### 🎪 Helm Chart Repository

#### 1. **Создание Chart Repository**
```bash
# Создание и публикация чартов
helm package ./helm-chart --version 1.0.0
helm repo index . --url https://charts.mycompany.com

# Загрузка в S3 или другое хранилище
aws s3 sync . s3://my-helm-charts/ --exclude "*.git/*"
```

#### 2. **Использование в CI/CD**
```yaml
# Добавление репозитория в пайплайн
- name: Add Helm repo
  run: |
    helm repo add mycompany https://charts.mycompany.com
    helm repo update

- name: Deploy from repository
  run: |
    helm upgrade --install myapp mycompany/myapp \
      --version 1.0.0 \
      --namespace production \
      --set image.tag=${{ github.sha }}
```

### 🔄 Откат и управление версиями

#### 1. **Автоматический откат**
```bash
#!/bin/bash
# deploy-with-rollback.sh

RELEASE_NAME="myapp"
NAMESPACE="production"
NEW_VERSION="$1"

echo "Развертывание версии $NEW_VERSION..."

# Сохранение текущей ревизии
CURRENT_REVISION=$(helm history $RELEASE_NAME -n $NAMESPACE -o json | jq -r '.[0].revision')

# Развертывание новой версии
if helm upgrade $RELEASE_NAME ./helm-chart \
    --namespace $NAMESPACE \
    --set image.tag=$NEW_VERSION \
    --wait --timeout=300s; then
    
    echo "✅ Развертывание успешно"
    
    # Проверка здоровья
    if ! helm test $RELEASE_NAME --namespace $NAMESPACE; then
        echo "❌ Тесты не прошли, откат..."
        helm rollback $RELEASE_NAME $CURRENT_REVISION --namespace $NAMESPACE
        exit 1
    fi
else
    echo "❌ Развертывание не удалось, откат..."
    helm rollback $RELEASE_NAME $CURRENT_REVISION --namespace $NAMESPACE
    exit 1
fi
```

### 📊 Мониторинг Helm релизов

#### 1. **Prometheus метрики**
```yaml
# ServiceMonitor для Helm релизов
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: helm-releases
spec:
  selector:
    matchLabels:
      app.kubernetes.io/managed-by: Helm
  endpoints:
  - port: metrics
    interval: 30s
```

#### 2. **Алерты для релизов**
```yaml
# PrometheusRule для Helm
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: helm-alerts
spec:
  groups:
  - name: helm
    rules:
    - alert: HelmReleaseFailed
      expr: increase(helm_release_duration_seconds{status="failed"}[5m]) > 0
      labels:
        severity: critical
      annotations:
        summary: "Helm release {{ $labels.release }} failed"
```

### 📋 Лучшие практики Helm в CI/CD

- ✅ **Версионирование чартов**: Используйте семантическое версионирование
- ✅ **Валидация**: Проверяйте чарты с `helm lint` и `helm template`
- ✅ **Тестирование**: Используйте Helm tests для проверки развертываний
- ✅ **Откат**: Настройте автоматический откат при ошибках
- ✅ **Секреты**: Используйте helm-secrets для чувствительных данных
- ✅ **Мониторинг**: Отслеживайте статус релизов
- ✅ **Документация**: Документируйте values.yaml и templates

Helm обеспечивает мощную абстракцию для управления Kubernetes приложениями в CI/CD пайплайнах, упрощая развертывание, обновление и откат приложений.
