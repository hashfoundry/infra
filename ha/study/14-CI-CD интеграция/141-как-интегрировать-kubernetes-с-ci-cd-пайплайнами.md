# 141. Как интегрировать Kubernetes с CI/CD пайплайнами?

## 🎯 Вопрос
Как интегрировать Kubernetes с CI/CD пайплайнами?

## 💡 Ответ

Интеграция Kubernetes с CI/CD пайплайнами включает несколько ключевых компонентов и подходов.

### 🏗️ Основные компоненты интеграции

#### 1. **Контейнеризация приложений**
```bash
# Создание Dockerfile
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

#### 2. **Сборка и пуш образов**
```yaml
# GitHub Actions пример
name: Build and Deploy
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
        docker tag myapp:${{ github.sha }} myregistry/myapp:${{ github.sha }}
        docker push myregistry/myapp:${{ github.sha }}
```

### 🔧 Стратегии развертывания

#### 1. **Push-based подход**
```yaml
# Jenkins Pipeline пример
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'docker build -t myapp:${BUILD_NUMBER} .'
            }
        }
        stage('Deploy') {
            steps {
                sh '''
                kubectl set image deployment/myapp \
                  myapp=myapp:${BUILD_NUMBER}
                kubectl rollout status deployment/myapp
                '''
            }
        }
    }
}
```

#### 2. **Pull-based подход (GitOps)**
```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  source:
    repoURL: https://github.com/myorg/myapp-config
    path: k8s
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 🛠️ Инструменты интеграции

#### 1. **kubectl в CI/CD**
```bash
# Установка kubectl в CI
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Настройка kubeconfig
echo "$KUBE_CONFIG" | base64 -d > ~/.kube/config

# Развертывание
kubectl apply -f k8s/
kubectl rollout status deployment/myapp
```

#### 2. **Helm в CI/CD**
```bash
# Установка Helm
curl https://get.helm.sh/helm-v3.10.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Развертывание с Helm
helm upgrade --install myapp ./helm-chart \
  --set image.tag=$BUILD_NUMBER \
  --namespace production
```

### 📊 Примеры из нашего кластера

#### Проверка текущих развертываний:
```bash
kubectl get deployments -A
```

#### Просмотр истории развертываний:
```bash
kubectl rollout history deployment/argocd-server -n argocd
```

#### Проверка статуса ArgoCD приложений:
```bash
kubectl get applications -n argocd
```

### 🔐 Безопасность в CI/CD

#### 1. **Service Account для CI/CD**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-cd-deployer
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deployer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ci-cd-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deployer
subjects:
- kind: ServiceAccount
  name: ci-cd-deployer
  namespace: default
```

#### 2. **Получение токена для CI/CD**
```bash
# Создание токена
kubectl create token ci-cd-deployer --duration=8760h

# Использование в CI/CD
kubectl --token=$CI_CD_TOKEN apply -f k8s/
```

### 🎯 Лучшие практики

#### 1. **Версионирование образов**
```bash
# Использование тегов с версией
docker build -t myapp:v1.2.3 .
docker build -t myapp:$GIT_COMMIT .

# Избегание latest в продакшене
kubectl set image deployment/myapp myapp=myapp:v1.2.3
```

#### 2. **Валидация перед развертыванием**
```bash
# Проверка YAML файлов
kubectl apply --dry-run=client -f k8s/

# Валидация с помощью kubeval
kubeval k8s/*.yaml

# Проверка безопасности
kubesec scan k8s/deployment.yaml
```

### 📈 Мониторинг развертываний

#### Проверка статуса развертывания:
```bash
kubectl rollout status deployment/myapp --timeout=300s
```

#### Просмотр событий:
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### Проверка логов:
```bash
kubectl logs -f deployment/myapp
```

### 🔄 Откат при проблемах

```bash
# Откат к предыдущей версии
kubectl rollout undo deployment/myapp

# Откат к конкретной ревизии
kubectl rollout undo deployment/myapp --to-revision=2

# Проверка истории
kubectl rollout history deployment/myapp
```

### 🎪 Пример полного пайплайна

```yaml
# GitLab CI пример
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  IMAGE_NAME: $DOCKER_REGISTRY/$CI_PROJECT_PATH

build:
  stage: build
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA

test:
  stage: test
  script:
    - kubectl apply --dry-run=client -f k8s/
    - helm template ./chart --values values.yaml

deploy:
  stage: deploy
  script:
    - kubectl set image deployment/myapp myapp=$IMAGE_NAME:$CI_COMMIT_SHA
    - kubectl rollout status deployment/myapp
  only:
    - main
```

Интеграция Kubernetes с CI/CD обеспечивает автоматизированное и надежное развертывание приложений с возможностью быстрого отката и мониторинга.
