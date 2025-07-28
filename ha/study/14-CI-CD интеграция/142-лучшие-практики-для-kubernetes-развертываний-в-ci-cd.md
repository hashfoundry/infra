# 142. Какие лучшие практики для Kubernetes развертываний в CI/CD?

## 🎯 Вопрос
Какие лучшие практики для Kubernetes развертываний в CI/CD?

## 💡 Ответ

Лучшие практики для Kubernetes развертываний в CI/CD обеспечивают надежность, безопасность и эффективность процесса доставки.

### 🏗️ Структура и организация

#### 1. **Разделение окружений**
```yaml
# Структура репозитория
├── environments/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── production/
│       ├── kustomization.yaml
│       └── values.yaml
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
```

#### 2. **Использование Kustomize**
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

commonLabels:
  app: myapp
```

```yaml
# environments/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

replicas:
- name: myapp
  count: 3

images:
- name: myapp
  newTag: v1.2.3
```

### 🔐 Безопасность

#### 1. **Управление секретами**
```yaml
# Использование External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "myapp"
```

#### 2. **Минимальные привилегии для Service Account**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-deployer
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "update", "patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

### 📊 Примеры из нашего кластера

#### Проверка RBAC для CI/CD:
```bash
kubectl auth can-i create deployments --as=system:serviceaccount:default:ci-deployer
```

#### Просмотр секретов в namespace:
```bash
kubectl get secrets -n argocd
```

#### Проверка политик безопасности:
```bash
kubectl get psp
kubectl get networkpolicies -A
```

### 🎯 Стратегии развертывания

#### 1. **Rolling Updates с проверками**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

#### 2. **Использование Pod Disruption Budget**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

### 🔍 Валидация и тестирование

#### 1. **Pre-deployment валидация**
```bash
#!/bin/bash
# validate.sh

echo "🔍 Валидация Kubernetes манифестов..."

# Проверка синтаксиса
kubectl apply --dry-run=client -f k8s/ || exit 1

# Проверка безопасности
kubesec scan k8s/*.yaml || exit 1

# Проверка ресурсов
kubectl apply --dry-run=server -f k8s/ || exit 1

echo "✅ Валидация прошла успешно"
```

#### 2. **Smoke tests после развертывания**
```bash
#!/bin/bash
# smoke-test.sh

APP_NAME="myapp"
NAMESPACE="production"

echo "🧪 Запуск smoke tests..."

# Проверка готовности deployment
kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=300s

# Проверка health endpoint
kubectl run test-pod --rm -i --restart=Never --image=curlimages/curl -- \
  curl -f http://$APP_NAME.$NAMESPACE.svc.cluster.local:8080/health

echo "✅ Smoke tests прошли успешно"
```

### 📈 Мониторинг и логирование

#### 1. **Интеграция с мониторингом**
```yaml
# ServiceMonitor для Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

#### 2. **Структурированное логирование**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [INPUT]
        Name tail
        Path /var/log/containers/*myapp*.log
        Parser docker
        Tag kube.*
    
    [OUTPUT]
        Name elasticsearch
        Match kube.*
        Host elasticsearch.logging.svc.cluster.local
        Port 9200
```

### 🎪 CI/CD Pipeline лучшие практики

#### 1. **Многоэтапный пайплайн**
```yaml
# .github/workflows/deploy.yml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Validate manifests
      run: |
        kubectl apply --dry-run=client -f k8s/
        kubesec scan k8s/*.yaml

  build:
    needs: validate
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Build and push
      run: |
        docker build -t myapp:$GITHUB_SHA .
        docker push myapp:$GITHUB_SHA

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    steps:
    - name: Deploy to staging
      run: |
        kubectl set image deployment/myapp myapp=myapp:$GITHUB_SHA -n staging
        kubectl rollout status deployment/myapp -n staging

  test-staging:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
    - name: Run integration tests
      run: ./scripts/integration-tests.sh staging

  deploy-production:
    needs: test-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
    - name: Deploy to production
      run: |
        kubectl set image deployment/myapp myapp=myapp:$GITHUB_SHA -n production
        kubectl rollout status deployment/myapp -n production
```

### 📊 Примеры проверок из нашего кластера

#### Проверка статуса развертываний:
```bash
kubectl get deployments -A -o wide
```

#### Просмотр событий развертывания:
```bash
kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
```

#### Проверка ресурсов:
```bash
kubectl top nodes
kubectl top pods -A
```

### 🔄 Откат и восстановление

#### 1. **Автоматический откат при ошибках**
```bash
#!/bin/bash
# deploy-with-rollback.sh

DEPLOYMENT="myapp"
NAMESPACE="production"
NEW_IMAGE="myapp:$1"

echo "🚀 Развертывание $NEW_IMAGE..."

# Сохранение текущей ревизии
CURRENT_REVISION=$(kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE --revision=0 | tail -1 | awk '{print $1}')

# Обновление образа
kubectl set image deployment/$DEPLOYMENT myapp=$NEW_IMAGE -n $NAMESPACE

# Ожидание завершения с таймаутом
if ! kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=300s; then
    echo "❌ Развертывание не удалось, откат к ревизии $CURRENT_REVISION"
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE --to-revision=$CURRENT_REVISION
    kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
    exit 1
fi

echo "✅ Развертывание успешно завершено"
```

### 🎯 Оптимизация производительности

#### 1. **Кэширование образов**
```yaml
# DaemonSet для предзагрузки образов
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-puller
spec:
  selector:
    matchLabels:
      name: image-puller
  template:
    spec:
      initContainers:
      - name: puller
        image: myapp:latest
        command: ['sh', '-c', 'echo "Image pulled"']
      containers:
      - name: pause
        image: k8s.gcr.io/pause:3.1
```

#### 2. **Оптимизация ресурсов**
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

### 📋 Чек-лист лучших практик

- ✅ Использование иммутабельных тегов образов
- ✅ Валидация манифестов перед развертыванием
- ✅ Автоматические health checks
- ✅ Мониторинг метрик развертывания
- ✅ Автоматический откат при ошибках
- ✅ Разделение окружений
- ✅ Минимальные RBAC привилегии
- ✅ Безопасное управление секретами
- ✅ Структурированное логирование
- ✅ Smoke tests после развертывания

Эти практики обеспечивают надежные, безопасные и эффективные развертывания в Kubernetes через CI/CD пайплайны.
