# 149. Как автоматизировать развертывание с ArgoCD?

## 🎯 Вопрос
Как автоматизировать развертывание с ArgoCD?

## 💡 Ответ

ArgoCD обеспечивает автоматизированное развертывание через GitOps подход, где Git является единственным источником истины для состояния кластера.

### 🏗️ Архитектура ArgoCD

#### 1. **Компоненты ArgoCD**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Repository│───▶│   ArgoCD        │───▶│   Kubernetes    │
│   (Manifests)   │    │   Controller    │    │   Cluster       │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ArgoCD UI     │    │   Application   │    │   Deployed      │
│   (Dashboard)   │    │   Definitions   │    │   Resources     │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### 2. **Основные концепции**
```yaml
# Application - основная единица развертывания
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/k8s-manifests
    targetRevision: HEAD
    path: apps/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 🛠️ Установка и настройка ArgoCD

#### 1. **Установка ArgoCD**
```bash
# Создание namespace
kubectl create namespace argocd

# Установка ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Ожидание готовности
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

#### 2. **Настройка доступа**
```bash
# Получение пароля admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forwarding для доступа к UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Установка ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Логин через CLI
argocd login localhost:8080
```

### 📊 Примеры из нашего кластера

#### Проверка статуса ArgoCD:
```bash
kubectl get pods -n argocd
```

#### Просмотр приложений:
```bash
kubectl get applications -n argocd
```

#### Проверка синхронизации:
```bash
argocd app list
argocd app get myapp
```

### 🎯 Создание Applications

#### 1. **Простое приложение**
```yaml
# simple-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/nginx-manifests
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### 2. **Helm приложение**
```yaml
# helm-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wordpress
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: wordpress
    targetRevision: 15.2.5
    helm:
      values: |
        wordpressUsername: admin
        wordpressPassword: secretpassword
        service:
          type: LoadBalancer
        persistence:
          enabled: true
          size: 10Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: wordpress
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### 3. **Kustomize приложение**
```yaml
# kustomize-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/kustomize-manifests
    targetRevision: HEAD
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 🔄 Автоматизация с ApplicationSets

#### 1. **ApplicationSet для множественных окружений**
```yaml
# multi-env-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-env-apps
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        url: https://dev-cluster.example.com
      - env: staging
        url: https://staging-cluster.example.com
      - env: production
        url: https://prod-cluster.example.com
  template:
    metadata:
      name: '{{env}}-myapp'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/k8s-manifests
        targetRevision: HEAD
        path: 'environments/{{env}}'
      destination:
        server: '{{url}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### 2. **ApplicationSet с Git генератором**
```yaml
# git-generator-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: git-generator
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/myorg/apps
      revision: HEAD
      directories:
      - path: apps/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/apps
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### 🎪 CI/CD интеграция с ArgoCD

#### 1. **GitHub Actions с ArgoCD**
```yaml
# .github/workflows/argocd-deploy.yml
name: Deploy with ArgoCD

on:
  push:
    branches: [main]

jobs:
  update-manifests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push image
      run: |
        docker build -t myregistry/myapp:${{ github.sha }} .
        docker push myregistry/myapp:${{ github.sha }}
    
    - name: Update manifest
      run: |
        # Клонирование репозитория с манифестами
        git clone https://${{ secrets.GITHUB_TOKEN }}@github.com/myorg/k8s-manifests.git
        cd k8s-manifests
        
        # Обновление образа в манифесте
        sed -i "s|image: myregistry/myapp:.*|image: myregistry/myapp:${{ github.sha }}|" \
          apps/production/deployment.yaml
        
        # Коммит и пуш изменений
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add .
        git commit -m "Update image to ${{ github.sha }}"
        git push
    
    - name: Wait for ArgoCD sync
      run: |
        # Ожидание синхронизации ArgoCD
        timeout 300 bash -c '
          while true; do
            STATUS=$(argocd app get myapp -o json | jq -r ".status.sync.status")
            if [ "$STATUS" = "Synced" ]; then
              echo "Application synced successfully"
              break
            fi
            echo "Waiting for sync... Current status: $STATUS"
            sleep 10
          done
        '
```

#### 2. **Jenkins Pipeline с ArgoCD**
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        REGISTRY = 'myregistry'
        APP_NAME = 'myapp'
        ARGOCD_SERVER = 'argocd-server.argocd.svc.cluster.local'
    }
    
    stages {
        stage('Build') {
            steps {
                sh '''
                    docker build -t ${REGISTRY}/${APP_NAME}:${BUILD_NUMBER} .
                    docker push ${REGISTRY}/${APP_NAME}:${BUILD_NUMBER}
                '''
            }
        }
        
        stage('Update Manifests') {
            steps {
                withCredentials([gitUsernamePassword(credentialsId: 'git-credentials')]) {
                    sh '''
                        git clone https://github.com/myorg/k8s-manifests.git
                        cd k8s-manifests
                        
                        sed -i "s|image: ${REGISTRY}/${APP_NAME}:.*|image: ${REGISTRY}/${APP_NAME}:${BUILD_NUMBER}|" \
                          apps/production/deployment.yaml
                        
                        git add .
                        git commit -m "Update ${APP_NAME} to build ${BUILD_NUMBER}"
                        git push
                    '''
                }
            }
        }
        
        stage('Trigger ArgoCD Sync') {
            steps {
                sh '''
                    argocd app sync ${APP_NAME} --server ${ARGOCD_SERVER}
                    argocd app wait ${APP_NAME} --server ${ARGOCD_SERVER} --health
                '''
            }
        }
    }
}
```

### 🔐 Безопасность ArgoCD

#### 1. **RBAC конфигурация**
```yaml
# argocd-rbac-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Администраторы
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    
    # Разработчики
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */dev, allow
    p, role:developer, applications, sync, */staging, allow
    
    # DevOps команда
    p, role:devops, applications, *, */*, allow
    p, role:devops, applications, sync, */production, allow
    
    # Группы пользователей
    g, myorg:admins, role:admin
    g, myorg:developers, role:developer
    g, myorg:devops, role:devops
```

#### 2. **Управление репозиториями**
```yaml
# private-repo.yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/myorg/private-manifests
  password: ghp_xxxxxxxxxxxxxxxxxxxx
  username: not-used
```

### 📈 Мониторинг ArgoCD

#### 1. **Prometheus метрики**
```yaml
# argocd-metrics-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    app.kubernetes.io/component: metrics
    app.kubernetes.io/name: argocd-metrics
spec:
  ports:
  - name: metrics
    port: 8082
    protocol: TCP
    targetPort: 8082
  selector:
    app.kubernetes.io/name: argocd-application-controller
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

#### 2. **Grafana Dashboard**
```json
{
  "dashboard": {
    "title": "ArgoCD Metrics",
    "panels": [
      {
        "title": "Application Health",
        "type": "stat",
        "targets": [
          {
            "expr": "argocd_app_health_status"
          }
        ]
      },
      {
        "title": "Sync Status",
        "type": "stat",
        "targets": [
          {
            "expr": "argocd_app_sync_total"
          }
        ]
      },
      {
        "title": "Application Count by Project",
        "type": "piechart",
        "targets": [
          {
            "expr": "count by (project) (argocd_app_info)"
          }
        ]
      }
    ]
  }
}
```

### 🔍 Отладка и устранение неполадок

#### 1. **Диагностика проблем синхронизации**
```bash
#!/bin/bash
# debug-argocd.sh

APP_NAME="$1"

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app-name>"
    exit 1
fi

echo "🔍 Диагностика ArgoCD приложения: $APP_NAME"

# Статус приложения
echo "📊 Статус приложения:"
argocd app get $APP_NAME

# Последние события
echo "📝 События синхронизации:"
argocd app history $APP_NAME

# Различия между Git и кластером
echo "🔄 Различия:"
argocd app diff $APP_NAME

# Логи контроллера
echo "📋 Логи ArgoCD контроллера:"
kubectl logs -n argocd deployment/argocd-application-controller --tail=50

# Проверка ресурсов
echo "🎯 Ресурсы приложения:"
kubectl get all -l app.kubernetes.io/instance=$APP_NAME
```

#### 2. **Принудительная синхронизация**
```bash
#!/bin/bash
# force-sync.sh

APP_NAME="$1"

echo "🔄 Принудительная синхронизация $APP_NAME"

# Обновление репозитория
argocd app refresh $APP_NAME

# Принудительная синхронизация
argocd app sync $APP_NAME --force

# Ожидание завершения
argocd app wait $APP_NAME --health --timeout 300
```

### 🎯 Продвинутые возможности

#### 1. **Sync Waves для упорядоченного развертывания**
```yaml
# database.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Развертывается первым
spec:
  # ... спецификация базы данных
---
# application.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application
  annotations:
    argocd.argoproj.io/sync-wave: "2"  # Развертывается после БД
spec:
  # ... спецификация приложения
```

#### 2. **Resource Hooks**
```yaml
# pre-sync-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: migrate/migrate
        command: ["migrate", "-path", "/migrations", "-database", "$DATABASE_URL", "up"]
```

### 📋 Лучшие практики ArgoCD

#### 1. **Организация репозиториев**
```
# Рекомендуемая структура
k8s-manifests/
├── apps/
│   ├── production/
│   ├── staging/
│   └── development/
├── infrastructure/
│   ├── monitoring/
│   ├── ingress/
│   └── storage/
└── argocd/
    ├── applications/
    └── projects/
```

#### 2. **Автоматизация управления**
```bash
#!/bin/bash
# setup-argocd-apps.sh

echo "🚀 Настройка ArgoCD приложений..."

# Создание проектов
argocd proj create production \
  --description "Production applications" \
  --src "https://github.com/myorg/k8s-manifests" \
  --dest "https://kubernetes.default.svc,production"

# Создание приложений из манифестов
kubectl apply -f argocd/applications/

# Синхронизация всех приложений
argocd app sync -l env=production

echo "✅ ArgoCD приложения настроены"
```

ArgoCD обеспечивает мощную автоматизацию развертывания через GitOps подход, предоставляя декларативное управление состоянием кластера с полной видимостью и контролем.
