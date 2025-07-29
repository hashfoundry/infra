# 141. Как интегрировать Kubernetes с CI/CD пайплайнами?

## 🎯 **Основные концепции:**

| Аспект | Традиционный CI/CD | Kubernetes CI/CD |
|--------|-------------------|------------------|
| **Развертывание** | На серверы напрямую | В контейнеры и поды |
| **Масштабирование** | Ручное | Автоматическое |
| **Конфигурация** | Файлы на серверах | YAML манифесты |
| **Откат** | Сложный процесс | Встроенный rollback |
| **Мониторинг** | Внешние инструменты | Встроенные метрики |
| **Секреты** | Переменные среды | Kubernetes Secrets |
| **Сеть** | Статические IP | Service Discovery |
| **Хранилище** | Локальные диски | Persistent Volumes |

## 🚀 **CI/CD интеграция с Kubernetes**

**CI/CD с Kubernetes** — это процесс автоматизации сборки, тестирования и развертывания приложений в Kubernetes кластере с использованием контейнеров и декларативных манифестов.

### **Ключевые компоненты интеграции:**
- **Container Registry** - хранение образов
- **Build Pipeline** - сборка и тестирование
- **Deployment Pipeline** - развертывание в кластер
- **GitOps** - управление через Git
- **Monitoring** - отслеживание развертываний
- **Security Scanning** - проверка безопасности

## 🏗️ **Архитектура CI/CD с Kubernetes**

**CI/CD Pipeline** состоит из этапов сборки, тестирования, упаковки в контейнеры и развертывания в Kubernetes кластер.

### **Этапы CI/CD Pipeline:**
- **Source** - код в Git репозитории
- **Build** - сборка приложения
- **Test** - автоматические тесты
- **Package** - создание Docker образа
- **Deploy** - развертывание в Kubernetes
- **Monitor** - мониторинг и алерты

## 📊 **Практические примеры из вашего HA кластера:**

### **1. ArgoCD - GitOps развертывание (уже установлен):**
```bash
# Проверка ArgoCD приложений
kubectl get applications -n argocd

# Статус синхронизации приложений
kubectl describe application hashfoundry-react -n argocd

# Просмотр ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Логи ArgoCD контроллера
kubectl logs -f deployment/argocd-application-controller -n argocd

# Проверка ArgoCD репозиториев
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
```

### **2. Проверка текущих развертываний:**
```bash
# Все развертывания в кластере
kubectl get deployments --all-namespaces

# История развертываний ArgoCD
kubectl rollout history deployment/argocd-server -n argocd

# Статус развертываний
kubectl get deployments -n argocd -o wide

# События развертываний
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

### **3. Мониторинг через Prometheus (если установлен):**
```bash
# Проверка Prometheus метрик
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики развертываний:
# - kube_deployment_status_replicas
# - kube_deployment_status_replicas_available
# - kube_deployment_status_replicas_updated
# - argocd_app_info
# - argocd_app_sync_total
```

## 🛠️ **Создание полного CI/CD Pipeline:**

### **1. Структура проекта с CI/CD:**
```bash
# Создать структуру проекта
mkdir -p webapp-cicd/{src,k8s,helm,ci}
cd webapp-cicd

# Структура файлов
cat << 'EOF'
webapp-cicd/
├── src/                          # Исходный код приложения
│   ├── app.js
│   ├── package.json
│   └── Dockerfile
├── k8s/                          # Kubernetes манифесты
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── configmap.yaml
├── helm/                         # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── ci/                           # CI/CD конфигурации
│   ├── .github/
│   ├── .gitlab-ci.yml
│   ├── Jenkinsfile
│   └── azure-pipelines.yml
└── scripts/                      # Deployment скрипты
    ├── build.sh
    ├── deploy.sh
    └── rollback.sh
EOF
```

### **2. Dockerfile для приложения:**
```dockerfile
# src/Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS runtime

# Создать non-root пользователя
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

WORKDIR /app

# Копировать зависимости
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --chown=nextjs:nodejs src/ ./

# Настройки безопасности
USER nextjs
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "app.js"]
```

### **3. Kubernetes манифесты:**
```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-production
  labels:
    name: webapp-production
    environment: production

---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: webapp-production
  labels:
    app: webapp
    version: "1.0"
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: "1.0"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: webapp
        image: hashfoundry/webapp:latest
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        envFrom:
        - configMapRef:
            name: webapp-config
        - secretRef:
            name: webapp-secrets
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/.cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}

---
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: webapp-production
  labels:
    app: webapp
spec:
  selector:
    app: webapp
  ports:
  - name: http
    port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP

---
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: webapp-production
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - webapp.hashfoundry.com
    secretName: webapp-tls
  rules:
  - host: webapp.hashfoundry.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-service
            port:
              number: 80

---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: webapp-production
data:
  LOG_LEVEL: "info"
  METRICS_ENABLED: "true"
  CACHE_TTL: "3600"
  API_TIMEOUT: "30000"
```

### **4. GitHub Actions CI/CD Pipeline:**
```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: hashfoundry/webapp
  KUBE_NAMESPACE: webapp-production

jobs:
  test:
    name: Test Application
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Run linting
      run: npm run lint

    - name: Run unit tests
      run: npm run test:unit

    - name: Run integration tests
      run: npm run test:integration

    - name: Generate test coverage
      run: npm run test:coverage

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  build:
    name: Build and Push Image
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/main'
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Docker image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: ./src
        file: ./src/Dockerfile
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64,linux/arm64

    - name: Generate SBOM
      uses: anchore/sbom-action@v0
      with:
        image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

  deploy:
    name: Deploy to Kubernetes
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > ~/.kube/config
        chmod 600 ~/.kube/config

    - name: Validate Kubernetes manifests
      run: |
        kubectl apply --dry-run=client -f k8s/
        kubectl apply --dry-run=server -f k8s/

    - name: Deploy to Kubernetes
      run: |
        # Update image tag in deployment
        sed -i "s|hashfoundry/webapp:latest|${{ needs.build.outputs.image-tag }}|g" k8s/deployment.yaml
        
        # Apply manifests
        kubectl apply -f k8s/
        
        # Wait for rollout to complete
        kubectl rollout status deployment/webapp -n ${{ env.KUBE_NAMESPACE }} --timeout=300s

    - name: Verify deployment
      run: |
        kubectl get pods -n ${{ env.KUBE_NAMESPACE }} -l app=webapp
        kubectl get service -n ${{ env.KUBE_NAMESPACE }} webapp-service
        kubectl get ingress -n ${{ env.KUBE_NAMESPACE }} webapp-ingress

    - name: Run smoke tests
      run: |
        # Wait for service to be ready
        kubectl wait --for=condition=ready pod -l app=webapp -n ${{ env.KUBE_NAMESPACE }} --timeout=300s
        
        # Port forward and test
        kubectl port-forward svc/webapp-service 8080:80 -n ${{ env.KUBE_NAMESPACE }} &
        sleep 10
        
        # Health check
        curl -f http://localhost:8080/health || exit 1
        
        # API test
        curl -f http://localhost:8080/api/status || exit 1

  notify:
    name: Notify Deployment
    runs-on: ubuntu-latest
    needs: [deploy]
    if: always()
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        fields: repo,message,commit,author,action,eventName,ref,workflow
```

### **5. GitLab CI/CD Pipeline:**
```yaml
# .gitlab-ci.yml
stages:
  - test
  - security
  - build
  - deploy
  - verify

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  IMAGE_NAME: $DOCKER_REGISTRY/$CI_PROJECT_PATH/webapp
  KUBE_NAMESPACE: webapp-production
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

.kubectl_config: &kubectl_config
  - echo "$KUBE_CONFIG" | base64 -d > ~/.kube/config
  - chmod 600 ~/.kube/config

test:unit:
  stage: test
  image: node:18-alpine
  cache:
    paths:
      - node_modules/
  script:
    - npm ci
    - npm run lint
    - npm run test:unit
    - npm run test:coverage
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    paths:
      - coverage/

test:integration:
  stage: test
  image: node:18-alpine
  services:
    - postgres:13-alpine
    - redis:6-alpine
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: testuser
    POSTGRES_PASSWORD: testpass
    DATABASE_URL: postgres://testuser:testpass@postgres:5432/testdb
    REDIS_URL: redis://redis:6379
  script:
    - npm ci
    - npm run test:integration

security:sast:
  stage: security
  image: securecodewarrior/gitlab-sast:latest
  script:
    - /analyzer run
  artifacts:
    reports:
      sast: gl-sast-report.json

security:container:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy fs --format template --template "@contrib/gitlab.tpl" -o gl-container-scanning-report.json .
  artifacts:
    reports:
      container_scanning: gl-container-scanning-report.json

build:
  stage: build
  image: docker:24-dind
  services:
    - docker:24-dind
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA ./src
    - docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:latest
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
    - docker push $IMAGE_NAME:latest
  only:
    - main

deploy:staging:
  stage: deploy
  image: bitnami/kubectl:latest
  environment:
    name: staging
    url: https://webapp-staging.hashfoundry.com
  before_script:
    - *kubectl_config
  script:
    - sed -i "s|hashfoundry/webapp:latest|$IMAGE_NAME:$CI_COMMIT_SHA|g" k8s/deployment.yaml
    - kubectl apply -f k8s/ -n webapp-staging
    - kubectl rollout status deployment/webapp -n webapp-staging --timeout=300s
  only:
    - main

deploy:production:
  stage: deploy
  image: bitnami/kubectl:latest
  environment:
    name: production
    url: https://webapp.hashfoundry.com
  before_script:
    - *kubectl_config
  script:
    - sed -i "s|hashfoundry/webapp:latest|$IMAGE_NAME:$CI_COMMIT_SHA|g" k8s/deployment.yaml
    - kubectl apply -f k8s/ -n $KUBE_NAMESPACE
    - kubectl rollout status deployment/webapp -n $KUBE_NAMESPACE --timeout=300s
  when: manual
  only:
    - main

verify:production:
  stage: verify
  image: curlimages/curl:latest
  script:
    - sleep 30
    - curl -f https://webapp.hashfoundry.com/health
    - curl -f https://webapp.hashfoundry.com/api/status
  dependencies:
    - deploy:production
  only:
    - main
```

### **6. Jenkins Pipeline:**
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'registry.hashfoundry.com'
        IMAGE_NAME = 'hashfoundry/webapp'
        KUBE_NAMESPACE = 'webapp-production'
        DOCKER_CREDENTIALS = credentials('docker-registry-creds')
        KUBE_CONFIG = credentials('kube-config')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh '''
                            npm ci
                            npm run lint
                            npm run test:unit
                        '''
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'test-results.xml'
                            publishCoverage adapters: [
                                istanbulCoberturaAdapter('coverage/cobertura-coverage.xml')
                            ]
                        }
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        sh '''
                            docker run --rm -v $(pwd):/workspace \
                              aquasec/trivy:latest fs /workspace
                        '''
                    }
                }
            }
        }
        
        stage('Build') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def image = docker.build("${IMAGE_NAME}:${GIT_COMMIT_SHORT}", "./src")
                    
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'docker-registry-creds') {
                        image.push("${GIT_COMMIT_SHORT}")
                        image.push("latest")
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                script {
                    withKubeConfig([credentialsId: 'kube-config']) {
                        sh '''
                            sed -i "s|hashfoundry/webapp:latest|${DOCKER_REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT_SHORT}|g" k8s/deployment.yaml
                            kubectl apply -f k8s/ -n webapp-staging
                            kubectl rollout status deployment/webapp -n webapp-staging --timeout=300s
                        '''
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    kubectl port-forward svc/webapp-service 8080:80 -n webapp-staging &
                    sleep 10
                    npm run test:integration
                '''
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to production?"
                ok "Deploy"
                parameters {
                    choice(
                        name: 'DEPLOYMENT_STRATEGY',
                        choices: ['rolling', 'blue-green', 'canary'],
                        description: 'Deployment strategy'
                    )
                }
            }
            steps {
                script {
                    withKubeConfig([credentialsId: 'kube-config']) {
                        if (params.DEPLOYMENT_STRATEGY == 'rolling') {
                            sh '''
                                sed -i "s|hashfoundry/webapp:latest|${DOCKER_REGISTRY}/${IMAGE_NAME}:${GIT_COMMIT_SHORT}|g" k8s/deployment.yaml
                                kubectl apply -f k8s/ -n ${KUBE_NAMESPACE}
                                kubectl rollout status deployment/webapp -n ${KUBE_NAMESPACE} --timeout=300s
                            '''
                        } else if (params.DEPLOYMENT_STRATEGY == 'blue-green') {
                            sh '''
                                # Blue-Green deployment logic
                                kubectl apply -f k8s/blue-green/ -n ${KUBE_NAMESPACE}
                            '''
                        } else if (params.DEPLOYMENT_STRATEGY == 'canary') {
                            sh '''
                                # Canary deployment logic
                                kubectl apply -f k8s/canary/ -n ${KUBE_NAMESPACE}
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    sleep 30
                    curl -f https://webapp.hashfoundry.com/health
                    curl -f https://webapp.hashfoundry.com/api/status
                '''
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "✅ Deployment successful: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
            )
        }
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: "❌ Deployment failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
            )
        }
    }
}
```

## 🔧 **Helm интеграция в CI/CD:**

### **1. Helm Chart структура:**
```bash
# helm/Chart.yaml
apiVersion: v2
name: webapp
description: HashFoundry WebApp Helm Chart
type: application
version: 1.0.0
appVersion: "1.0.0"
dependencies:
- name: postgresql
  version: 12.1.9
  repository: https://charts.bitnami.com/bitnami
  condition: postgresql.enabled
- name: redis
  version: 17.3.7
  repository: https://charts.bitnami.com/bitnami
  condition: redis.enabled
```

```yaml
# helm/values.yaml
replicaCount: 3

image:
  repository: hashfoundry/webapp
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
  - host: webapp.hashfoundry.com
    paths:
    - path: /
      pathType: Prefix
  tls:
  - secretName: webapp-tls
    hosts:
    - webapp.hashfoundry.com

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

postgresql:
  enabled: true
  auth:
    database: webapp
    username: webapp

redis:
  enabled: true
  auth:
    enabled: false

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    path: /metrics
```

### **2. Helm в CI/CD Pipeline:**
```bash
# scripts/deploy-helm.sh
#!/bin/bash

set -e

NAMESPACE=${KUBE_NAMESPACE:-webapp-production}
RELEASE_NAME=${HELM_RELEASE:-webapp}
CHART_PATH=${CHART_PATH:-./helm}
IMAGE_TAG=${IMAGE_TAG:-latest}

echo "Deploying ${RELEASE_NAME} to ${NAMESPACE} with image tag ${IMAGE_TAG}"

# Добавить Helm репозитории
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Проверить Helm chart
helm lint ${CHART_PATH}

# Dry run
helm upgrade --install ${RELEASE_NAME} ${CHART_PATH} \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --set image.tag=${IMAGE_TAG} \
  --dry-run --debug

# Развертывание
helm upgrade --install ${RELEASE_NAME} ${CHART_PATH} \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --set image.tag=${IMAGE_TAG} \
  --wait --timeout=300s

# Проверить статус
helm status ${RELEASE_NAME} -n ${NAMESPACE}
kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME}

echo "Deployment completed successfully!"
```

## 🔐 **Безопасность в CI/CD:**

### **1. RBAC для CI/CD Service Account:**
```yaml
# ci/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-cd-deployer
  namespace: webapp-production
automountServiceAccountToken: false

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: webapp-production
  name: ci-cd-deployer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-cd-deployer
  namespace: webapp-production
subjects:
- kind: ServiceAccount
  name: ci-cd-deployer
  namespace: webapp-production
roleRef:
  kind: Role
  name: ci-cd-deployer
  apiGroup: rbac.authorization.k8s.io
```

### **2. Создание токена для CI/CD:**
```bash
# Создать долгосрочный токен для CI/CD
kubectl create token ci-cd-deployer --duration=8760h -n webapp-production

# Получить токен из Secret (для старых версий K8s)
kubectl get secret ci-cd-deployer-token -n webapp-production -o jsonpath='{.data.token}' | base64 -d

# Использование токена в CI/CD
export KUBE_TOKEN=$(kubectl create token ci-cd-deployer --duration=8760h -n webapp-production)
kubectl --token=$KUBE_TOKEN get pods -n webapp-production
```

### **3. Безопасные практики:**
```yaml
# ci/security-policies.yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
  namespace: webapp-production
type: Opaque
data:
  database-password: <base64-encoded-password>
  api-key: <base64-encoded-api-key>
  jwt-secret: <base64-encoded-jwt-secret>

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: webapp-network-policy
  namespace: webapp-production
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: webapp-production
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
  - to: []
    ports:
    - protocol: TCP
      port: 443   # HTTPS
    - protocol: TCP
      port: 53    # DNS
    - protocol: UDP
      port: 53    # DNS
```

## 📊 **Мониторинг CI/CD в вашем кластере:**

### **1. Проверка развертываний через kubectl:**
```bash
# Мониторинг всех развертываний
kubectl get deployments --all-namespaces -o wide

# Проверка статуса ArgoCD приложений
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# История развертываний
kubectl rollout history deployment/argocd-server -n argocd

# События в реальном времени
kubectl get events --all-namespaces --watch

# Логи развертываний
kubectl logs -f deployment/argocd-application-controller -n argocd

# Проверка ресурсов после развертывания
kubectl top pods -n argocd
kubectl top nodes
```

### **2. Prometheus метрики для CI/CD:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики для мониторинга CI/CD:
# - kube_deployment_status_replicas
# - kube_deployment_status_replicas_available
# - kube_deployment_status_replicas_updated
# - kube_pod_container_status_restarts_total
# - argocd_app_info
# - argocd_app_sync_total
# - argocd_app_health_status
```

### **3. Grafana дашборды:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Создать дашборд для мониторинга:
# - Deployment success rate
# - Build duration
# - Test coverage
# - Security scan results
# - Application health
```

## 🔄 **Стратегии развертывания:**

### **1. Rolling Update (по умолчанию):**
```yaml
# k8s/rolling-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-rolling
  namespace: webapp-production
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Максимум 2 дополнительных пода
      maxUnavailable: 1  # Максимум 1 недоступный под
  selector:
    matchLabels:
      app: webapp
      strategy: rolling
  template:
    metadata:
      labels:
        app: webapp
        strategy: rolling
    spec:
      containers:
      - name: webapp
        image: hashfoundry/webapp:latest
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### **2. Blue-Green развертывание:**
```yaml
# k8s/blue-green/blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-blue
  namespace: webapp-production
  labels:
    app: webapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: blue
  template:
    metadata:
      labels:
        app: webapp
        version: blue
    spec:
      containers:
      - name: webapp
        image: hashfoundry/webapp:v1.0.0
        ports:
        - containerPort: 3000

---
# k8s/blue-green/green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-green
  namespace: webapp-production
  labels:
    app: webapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: green
  template:
    metadata:
      labels:
        app: webapp
        version: green
    spec:
      containers:
      - name: webapp
        image: hashfoundry/webapp:v2.0.0
        ports:
        - containerPort: 3000

---
# k8s/blue-green/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: webapp-production
spec:
  selector:
    app: webapp
    version: blue  # Переключение между blue и green
  ports:
  - port: 80
    targetPort: 3000
```

### **3. Canary развертывание:**
```yaml
# k8s/canary/stable-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-stable
  namespace: webapp-production
  labels:
    app: webapp
    version: stable
spec:
  replicas: 9  # 90% трафика
  selector:
    matchLabels:
      app: webapp
      version: stable
  template:
    metadata:
      labels:
        app: webapp
        version: stable
    spec:
      containers:
      - name: webapp
        image: hashfoundry/webapp:v1.0.0
        ports:
        - containerPort: 3000

---
# k8s/canary/canary-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
  namespace: webapp-production
  labels:
    app: webapp
    version: canary
spec:
  replicas: 1  # 10% трафика
  selector:
    matchLabels:
      app: webapp
      version: canary
  template:
    metadata:
      labels:
        app: webapp
        version: canary
    spec:
      containers:
      - name: webapp
        image: hashfoundry/webapp:v2.0.0
        ports:
        - containerPort: 3000

---
# k8s/canary/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: webapp-production
spec:
  selector:
    app: webapp  # Обе версии получают трафик
  ports:
  - port: 80
    targetPort: 3000
```

## 🛠️ **Скрипты автоматизации:**

### **1. Скрипт сборки и развертывания:**
```bash
#!/bin/bash
# scripts/deploy.sh

set -e

# Конфигурация
NAMESPACE=${NAMESPACE:-webapp-production}
IMAGE_TAG=${IMAGE_TAG:-latest}
DEPLOYMENT_STRATEGY=${DEPLOYMENT_STRATEGY:-rolling}
REGISTRY=${REGISTRY:-hashfoundry}
APP_NAME=${APP_NAME:-webapp}

echo "🚀 Starting deployment of ${APP_NAME}:${IMAGE_TAG} to ${NAMESPACE}"

# Функция для проверки готовности
check_readiness() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    echo "⏳ Waiting for deployment ${deployment} to be ready..."
    kubectl rollout status deployment/${deployment} -n ${namespace} --timeout=${timeout}s
    
    if [ $? -eq 0 ]; then
        echo "✅ Deployment ${deployment} is ready"
        return 0
    else
        echo "❌ Deployment ${deployment} failed to become ready"
        return 1
    fi
}

# Функция для smoke tests
run_smoke_tests() {
    local service=$1
    local namespace=$2
    
    echo "🧪 Running smoke tests..."
    
    # Port forward в фоне
    kubectl port-forward svc/${service} 8080:80 -n ${namespace} &
    local pf_pid=$!
    
    # Дождаться готовности port forward
    sleep 10
    
    # Health check
    if curl -f http://localhost:8080/health; then
        echo "✅ Health check passed"
    else
        echo "❌ Health check failed"
        kill $pf_pid
        return 1
    fi
    
    # API test
    if curl -f http://localhost:8080/api/status; then
        echo "✅ API test passed"
    else
        echo "❌ API test failed"
        kill $pf_pid
        return 1
    fi
    
    # Остановить port forward
    kill $pf_pid
    
    echo "✅ All smoke tests passed"
    return 0
}

# Функция для отката
rollback_deployment() {
    local deployment=$1
    local namespace=$2
    
    echo "🔄 Rolling back deployment ${deployment}..."
    kubectl rollout undo deployment/${deployment} -n ${namespace}
    
    if check_readiness ${deployment} ${namespace}; then
        echo "✅ Rollback successful"
        return 0
    else
        echo "❌ Rollback failed"
        return 1
    fi
}

# Основная логика развертывания
deploy_application() {
    case ${DEPLOYMENT_STRATEGY} in
        "rolling")
            echo "📦 Deploying with Rolling Update strategy"
            
            # Обновить образ в deployment
            sed -i "s|${REGISTRY}/${APP_NAME}:.*|${REGISTRY}/${APP_NAME}:${IMAGE_TAG}|g" k8s/deployment.yaml
            
            # Применить манифесты
            kubectl apply -f k8s/ -n ${NAMESPACE}
            
            # Проверить готовность
            if check_readiness ${APP_NAME} ${NAMESPACE}; then
                if run_smoke_tests "${APP_NAME}-service" ${NAMESPACE}; then
                    echo "✅ Rolling deployment successful"
                else
                    echo "❌ Smoke tests failed, rolling back..."
                    rollback_deployment ${APP_NAME} ${NAMESPACE}
                    exit 1
                fi
            else
                echo "❌ Deployment failed"
                exit 1
            fi
            ;;
            
        "blue-green")
            echo "🔵🟢 Deploying with Blue-Green strategy"
            
            # Определить текущую активную версию
            current_version=$(kubectl get service ${APP_NAME}-service -n ${NAMESPACE} -o jsonpath='{.spec.selector.version}')
            
            if [ "$current_version" = "blue" ]; then
                new_version="green"
            else
                new_version="blue"
            fi
            
            echo "Current version: ${current_version}, deploying to: ${new_version}"
            
            # Обновить образ в новой версии
            sed -i "s|${REGISTRY}/${APP_NAME}:.*|${REGISTRY}/${APP_NAME}:${IMAGE_TAG}|g" k8s/blue-green/${new_version}-deployment.yaml
            
            # Развернуть новую версию
            kubectl apply -f k8s/blue-green/${new_version}-deployment.yaml -n ${NAMESPACE}
            
            # Проверить готовность
            if check_readiness "${APP_NAME}-${new_version}" ${NAMESPACE}; then
                # Переключить трафик
                kubectl patch service ${APP_NAME}-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"'${new_version}'"}}}'
                
                if run_smoke_tests "${APP_NAME}-service" ${NAMESPACE}; then
                    echo "✅ Blue-Green deployment successful"
                    
                    # Удалить старую версию
                    kubectl delete deployment ${APP_NAME}-${current_version} -n ${NAMESPACE}
                else
                    echo "❌ Smoke tests failed, switching back..."
                    kubectl patch service ${APP_NAME}-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"'${current_version}'"}}}'
                    exit 1
                fi
            else
                echo "❌ Blue-Green deployment failed"
                exit 1
            fi
            ;;
            
        "canary")
            echo "🐤 Deploying with Canary strategy"
            
            # Обновить образ в canary deployment
            sed -i "s|${REGISTRY}/${APP_NAME}:.*|${REGISTRY}/${APP_NAME}:${IMAGE_TAG}|g" k8s/canary/canary-deployment.yaml
            
            # Развернуть canary версию
            kubectl apply -f k8s/canary/canary-deployment.yaml -n ${NAMESPACE}
            
            # Проверить готовность
            if check_readiness "${APP_NAME}-canary" ${NAMESPACE}; then
                echo "✅ Canary deployment ready"
                
                # Мониторинг canary в течение 5 минут
                echo "📊 Monitoring canary for 5 minutes..."
                sleep 300
                
                # Проверить метрики (здесь должна быть интеграция с Prometheus)
                if run_smoke_tests "${APP_NAME}-service" ${NAMESPACE}; then
                    echo "✅ Canary metrics look good, promoting to stable"
                    
                    # Обновить stable версию
                    sed -i "s|${REGISTRY}/${APP_NAME}:.*|${REGISTRY}/${APP_NAME}:${IMAGE_TAG}|g" k8s/canary/stable-deployment.yaml
                    kubectl apply -f k8s/canary/stable-deployment.yaml -n ${NAMESPACE}
                    
                    # Проверить готовность stable
                    if check_readiness "${APP_NAME}-stable" ${NAMESPACE}; then
                        # Удалить canary
                        kubectl delete deployment ${APP_NAME}-canary -n ${NAMESPACE}
                        echo "✅ Canary deployment promoted successfully"
                    else
                        echo "❌ Failed to promote canary to stable"
                        exit 1
                    fi
                else
                    echo "❌ Canary metrics failed, rolling back..."
                    kubectl delete deployment ${APP_NAME}-canary -n ${NAMESPACE}
                    exit 1
                fi
            else
                echo "❌ Canary deployment failed"
                exit 1
            fi
            ;;
            
        *)
            echo "❌ Unknown deployment strategy: ${DEPLOYMENT_STRATEGY}"
            exit 1
            ;;
    esac
}

# Проверить зависимости
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "❌ curl is not installed"
    exit 1
fi

# Проверить подключение к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

# Запустить развертывание
deploy_application

echo "🎉 Deployment completed successfully!"
```

### **2. Скрипт отката:**
```bash
#!/bin/bash
# scripts/rollback.sh

set -e

NAMESPACE=${NAMESPACE:-webapp-production}
APP_NAME=${APP_NAME:-webapp}
REVISION=${REVISION:-}

echo "🔄 Starting rollback of ${APP_NAME} in ${NAMESPACE}"

# Показать историю развертываний
echo "📜 Deployment history:"
kubectl rollout history deployment/${APP_NAME} -n ${NAMESPACE}

# Выполнить откат
if [ -n "${REVISION}" ]; then
    echo "🔄 Rolling back to revision ${REVISION}"
    kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE} --to-revision=${REVISION}
else
    echo "🔄 Rolling back to previous revision"
    kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}
fi

# Проверить статус отката
echo "⏳ Waiting for rollback to complete..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s

if [ $? -eq 0 ]; then
    echo "✅ Rollback completed successfully"
    
    # Проверить состояние подов
    kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}
    
    # Запустить smoke tests
    echo "🧪 Running post-rollback smoke tests..."
    kubectl port-forward svc/${APP_NAME}-service 8080:80 -n ${NAMESPACE} &
    local pf_pid=$!
    
    sleep 10
    
    if curl -f http://localhost:8080/health; then
        echo "✅ Post-rollback health check passed"
    else
        echo "❌ Post-rollback health check failed"
        kill $pf_pid
        exit 1
    fi
    
    kill $pf_pid
    echo "🎉 Rollback verification completed successfully!"
else
    echo "❌ Rollback failed"
    exit 1
fi
```

## 🎯 **Best Practices для Kubernetes CI/CD:**

### **1. Версионирование и тегирование:**
```bash
# Семантическое версионирование
docker build -t hashfoundry/webapp:v1.2.3 .
docker build -t hashfoundry/webapp:v1.2.3-${GIT_COMMIT} .

# Избегать latest в production
# ❌ Плохо
image: hashfoundry/webapp:latest

# ✅ Хорошо
image: hashfoundry/webapp:v1.2.3

# Использование Git commit hash
IMAGE_TAG=${GIT_COMMIT_SHA:-$(git rev-parse --short HEAD)}
docker build -t hashfoundry/webapp:${IMAGE_TAG} .
```

### **2. Валидация и тестирование:**
```bash
# Валидация YAML манифестов
kubectl apply --dry-run=client -f k8s/
kubectl apply --dry-run=server -f k8s/

# Проверка с kubeval
kubeval k8s/*.yaml

# Безопасность с kubesec
kubesec scan k8s/deployment.yaml

# Линтинг Helm charts
helm lint ./helm

# Проверка Dockerfile
hadolint src/Dockerfile
```

### **3. Мониторинг и алерты:**
```yaml
# Prometheus AlertManager правила
groups:
- name: deployment.rules
  rules:
  - alert: DeploymentReplicasMismatch
    expr: kube_deployment_status_replicas != kube_deployment_status_replicas_available
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Deployment {{ $labels.deployment }} has mismatched replicas"
      
  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Pod {{ $labels.pod }} is crash looping"
```

## 🏗️ **Архитектура CI/CD в вашем кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│                    HashFoundry HA Cluster                  │
├─────────────────────────────────────────────────────────────┤
│  CI/CD Pipeline Architecture                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   Source    │    │    Build    │    │   Deploy    │      │
│  │             │    │             │    │             │      │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │      │
│  │ │   Git   │ │───▶│ │ Docker  │ │───▶│ │ArgoCD/  │ │      │
│  │ │ Repo    │ │    │ │ Build   │ │    │ │kubectl  │ │      │
│  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │      │
│  │             │    │             │    │             │      │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │      │
│  │ │Webhooks │ │    │ │ Tests   │ │    │ │ Health  │ │      │
│  │ │         │ │    │ │Security │ │    │ │ Checks  │ │      │
│  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│                                                             │
│  Deployment Strategies:                                     │
│  ├── Rolling Update (default)                               │
│  ├── Blue-Green (zero downtime)                             │
│  └── Canary (gradual rollout)                               │
│                                                             │
│  Monitoring & Observability:                                │
│  ├── Prometheus (metrics)                                   │
│  ├── Grafana (dashboards)                                   │
│  ├── ArgoCD (GitOps status)                                 │
│  └── Kubernetes Events                                      │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Заключение:**

**Kubernetes CI/CD интеграция** обеспечивает автоматизированную и надежную доставку приложений:

**Ключевые преимущества:**
1. **Автоматизация** - полный цикл от кода до production
2. **Надежность** - встроенные проверки и откаты
3. **Масштабируемость** - автоматическое управление ресурсами
4. **Безопасность** - сканирование и RBAC
5. **Наблюдаемость** - полный мониторинг процесса

**Практическое применение в HashFoundry HA кластере:**
- **ArgoCD** для GitOps развертываний
- **Prometheus/Grafana** для мониторинга
- **NGINX Ingress** для маршрутизации трафика
- **Helm** для управления пакетами

CI/CD с Kubernetes превращает развертывание приложений в надежный, автоматизированный и масштабируемый процесс.
