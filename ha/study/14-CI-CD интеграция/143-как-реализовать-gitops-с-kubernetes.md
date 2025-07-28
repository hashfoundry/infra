# 143. Как реализовать GitOps с Kubernetes?

## 🎯 Вопрос
Как реализовать GitOps с Kubernetes?

## 💡 Ответ

GitOps - это методология управления инфраструктурой и приложениями, где Git является единственным источником истины для декларативной инфраструктуры и приложений.

### 🏗️ Основные принципы GitOps

#### 1. **Декларативность**
```yaml
# Все конфигурации описаны декларативно
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v1.2.3
        ports:
        - containerPort: 8080
```

#### 2. **Версионирование в Git**
```bash
# Структура GitOps репозитория
├── apps/
│   ├── production/
│   │   ├── myapp/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   └── staging/
│       └── myapp/
├── infrastructure/
│   ├── monitoring/
│   └── ingress/
└── clusters/
    ├── production/
    └── staging/
```

### 🛠️ Инструменты GitOps

#### 1. **ArgoCD - основной инструмент**
```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/k8s-config
    targetRevision: HEAD
    path: apps/production/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### 2. **Flux как альтернатива**
```yaml
# Flux GitRepository
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: myapp-config
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/myorg/k8s-config
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 10m
  path: "./apps/production"
  prune: true
  sourceRef:
    kind: GitRepository
    name: myapp-config
```

### 📊 Примеры из нашего кластера

#### Проверка ArgoCD приложений:
```bash
kubectl get applications -n argocd
```

#### Просмотр статуса синхронизации:
```bash
kubectl describe application myapp -n argocd
```

#### Проверка ArgoCD сервера:
```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

### 🔄 Workflow GitOps

#### 1. **Разработка и коммит**
```bash
# Разработчик вносит изменения
git clone https://github.com/myorg/myapp
cd myapp

# Изменения в коде
echo "console.log('New feature');" >> src/app.js
git add .
git commit -m "feat: add new feature"
git push origin feature/new-feature

# Создание Pull Request
gh pr create --title "Add new feature" --body "Description"
```

#### 2. **CI Pipeline (сборка образа)**
```yaml
# .github/workflows/ci.yml
name: CI Pipeline
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Build Docker image
      run: |
        docker build -t myapp:${{ github.sha }} .
        docker tag myapp:${{ github.sha }} registry.io/myapp:${{ github.sha }}
        docker push registry.io/myapp:${{ github.sha }}
    
    - name: Update GitOps repo
      run: |
        git clone https://github.com/myorg/k8s-config
        cd k8s-config
        
        # Обновление образа в манифестах
        sed -i "s|image: myapp:.*|image: registry.io/myapp:${{ github.sha }}|" \
          apps/staging/myapp/deployment.yaml
        
        git add .
        git commit -m "Update myapp image to ${{ github.sha }}"
        git push
```

#### 3. **CD через GitOps (автоматическая синхронизация)**
```bash
# ArgoCD автоматически обнаруживает изменения и применяет их
# Проверка статуса синхронизации
argocd app sync myapp-staging
argocd app wait myapp-staging --health
```

### 🎯 Стратегии развертывания в GitOps

#### 1. **Environment Promotion**
```bash
#!/bin/bash
# promote.sh - скрипт для продвижения между окружениями

SOURCE_ENV="staging"
TARGET_ENV="production"
APP_NAME="myapp"

# Получение текущего образа из staging
CURRENT_IMAGE=$(kubectl get deployment $APP_NAME -n $SOURCE_ENV -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "Продвижение $CURRENT_IMAGE из $SOURCE_ENV в $TARGET_ENV"

# Обновление production манифеста
sed -i "s|image: .*|image: $CURRENT_IMAGE|" apps/$TARGET_ENV/$APP_NAME/deployment.yaml

git add .
git commit -m "Promote $APP_NAME to $TARGET_ENV: $CURRENT_IMAGE"
git push
```

#### 2. **Multi-cluster GitOps**
```yaml
# ArgoCD ApplicationSet для нескольких кластеров
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-clusters
  namespace: argocd
spec:
  generators:
  - clusters: {}
  template:
    metadata:
      name: '{{name}}-myapp'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/k8s-config
        targetRevision: HEAD
        path: 'apps/{{name}}'
      destination:
        server: '{{server}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### 🔐 Безопасность в GitOps

#### 1. **RBAC для ArgoCD**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */staging, allow
    g, myorg:devops, role:admin
    g, myorg:developers, role:developer
```

#### 2. **Sealed Secrets для секретов**
```yaml
# Создание Sealed Secret
echo -n mypassword | kubectl create secret generic mysecret \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > mysecret-sealed.yaml

# Sealed Secret в Git
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mysecret
  namespace: production
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
```

### 📈 Мониторинг GitOps

#### 1. **ArgoCD метрики**
```bash
# Проверка метрик ArgoCD
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082

# Prometheus запросы для мониторинга
# argocd_app_health_status
# argocd_app_sync_total
# argocd_app_info
```

#### 2. **Алерты для GitOps**
```yaml
# PrometheusRule для ArgoCD
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
spec:
  groups:
  - name: argocd
    rules:
    - alert: ArgoCDAppNotSynced
      expr: argocd_app_info{sync_status!="Synced"} == 1
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "ArgoCD application {{ $labels.name }} is not synced"
    
    - alert: ArgoCDAppUnhealthy
      expr: argocd_app_info{health_status!="Healthy"} == 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "ArgoCD application {{ $labels.name }} is unhealthy"
```

### 🎪 Практические примеры

#### 1. **Настройка ArgoCD в нашем кластере**
```bash
# Проверка установки ArgoCD
kubectl get pods -n argocd

# Получение пароля admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Доступ к UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

#### 2. **Создание первого GitOps приложения**
```bash
# Создание Application через CLI
argocd app create myapp \
  --repo https://github.com/myorg/k8s-config \
  --path apps/staging/myapp \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace staging \
  --sync-policy automated
```

### 🔍 Отладка GitOps

#### 1. **Диагностика проблем синхронизации**
```bash
# Проверка статуса приложения
argocd app get myapp

# Просмотр логов ArgoCD
kubectl logs -f deployment/argocd-application-controller -n argocd

# Проверка событий
kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
```

#### 2. **Ручная синхронизация**
```bash
# Принудительная синхронизация
argocd app sync myapp --force

# Обновление репозитория
argocd app refresh myapp

# Откат к предыдущей версии
argocd app rollback myapp
```

### 📋 Преимущества GitOps

- ✅ **Декларативность**: Вся инфраструктура как код
- ✅ **Версионирование**: Полная история изменений в Git
- ✅ **Откат**: Простой откат через Git revert
- ✅ **Аудит**: Все изменения отслеживаются
- ✅ **Безопасность**: Нет прямого доступа к кластеру
- ✅ **Автоматизация**: Автоматическая синхронизация
- ✅ **Консистентность**: Одинаковое состояние во всех окружениях

GitOps обеспечивает надежный, безопасный и прозрачный способ управления Kubernetes кластерами через Git как единственный источник истины.
