# 144. Роль Helm в CI/CD пайплайнах

## 🎯 **Основные концепции:**

| Аспект | Без Helm | С Helm |
|--------|----------|--------|
| **Управление манифестами** | Статичные YAML файлы | Динамические шаблоны |
| **Конфигурация** | Хардкод значений | Values.yaml для окружений |
| **Версионирование** | Git теги | Helm chart versions + app versions |
| **Развертывание** | kubectl apply -f | helm upgrade --install |
| **Откат** | Ручное восстановление | helm rollback |
| **Тестирование** | Внешние скрипты | Встроенные helm tests |
| **Управление зависимостями** | Ручное управление | Chart dependencies |
| **Переиспользование** | Копирование файлов | Helm charts как пакеты |
| **Конфигурация окружений** | Множественные файлы | Один chart + разные values |
| **Lifecycle hooks** | Отсутствуют | Pre/post install/upgrade hooks |
| **Валидация** | kubectl --dry-run | helm lint + template |
| **Упаковка** | Архивы | Helm packages (.tgz) |

## 🏆 **Helm - что это такое?**

**Helm** — это пакетный менеджер для Kubernetes, который упрощает развертывание, обновление и управление приложениями через шаблонизацию и версионирование. В CI/CD пайплайнах Helm выступает как мост между кодом приложения и его развертыванием в Kubernetes.

### **Ключевые компоненты Helm:**
- **Charts** - пакеты Kubernetes манифестов
- **Templates** - шаблоны с переменными
- **Values** - конфигурационные файлы
- **Releases** - экземпляры установленных charts
- **Repositories** - хранилища charts

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка Helm в кластере:**
```bash
# Проверка установленных Helm релизов
helm list -A

# Проверка ArgoCD релиза (установлен через Helm)
helm list -n argocd

# Детальная информация о релизе
helm status argocd -n argocd

# История релиза ArgoCD
helm history argocd -n argocd

# Проверка values ArgoCD
helm get values argocd -n argocd

# Проверка всех ресурсов релиза
helm get all argocd -n argocd
```

### **2. Анализ Helm charts в кластере:**
```bash
# Проверка nginx-ingress chart
helm list -n ingress-nginx

# Проверка monitoring stack
helm list -n monitoring

# Проверка всех Helm releases с подробностями
helm list -A -o table

# Проверка failed releases
helm list -A --failed

# Проверка pending releases
helm list -A --pending
```

### **3. Работа с Helm repositories:**
```bash
# Проверка добавленных репозиториев
helm repo list

# Поиск charts в репозиториях
helm search repo prometheus

# Информация о chart
helm show chart prometheus-community/prometheus

# Проверка values chart
helm show values prometheus-community/prometheus

# Обновление репозиториев
helm repo update
```

## 🛠️ **Comprehensive Helm CI/CD Implementation:**

### **1. Полная структура Helm chart для HashFoundry:**
```bash
# Создание структуры Helm chart
mkdir -p hashfoundry-helm-chart
cd hashfoundry-helm-chart

# Структура chart
cat << 'EOF'
hashfoundry-helm-chart/
├── Chart.yaml                       # Метаданные chart
├── Chart.lock                       # Зависимости (автогенерируется)
├── values.yaml                      # Значения по умолчанию
├── values-development.yaml          # Development окружение
├── values-staging.yaml              # Staging окружение
├── values-production.yaml           # Production окружение
├── charts/                          # Зависимые charts
│   └── postgresql/                  # Подчарт для БД
├── templates/                       # Kubernetes шаблоны
│   ├── NOTES.txt                    # Инструкции после установки
│   ├── _helpers.tpl                 # Вспомогательные шаблоны
│   ├── configmap.yaml               # ConfigMap шаблон
│   ├── deployment.yaml              # Deployment шаблон
│   ├── service.yaml                 # Service шаблон
│   ├── ingress.yaml                 # Ingress шаблон
│   ├── serviceaccount.yaml          # ServiceAccount шаблон
│   ├── rbac.yaml                    # RBAC шаблоны
│   ├── hpa.yaml                     # HorizontalPodAutoscaler
│   ├── pdb.yaml                     # PodDisruptionBudget
│   ├── networkpolicy.yaml           # NetworkPolicy
│   ├── secrets.yaml                 # Secrets шаблон
│   ├── cronjob.yaml                 # CronJob для задач
│   └── tests/                       # Helm tests
│       ├── test-connection.yaml     # Тест подключения
│       ├── test-api.yaml            # Тест API
│       └── test-database.yaml       # Тест БД
├── crds/                            # Custom Resource Definitions
│   └── hashfoundry-crd.yaml
├── .helmignore                      # Игнорируемые файлы
├── README.md                        # Документация chart
└── ci/                              # CI/CD конфигурации
    ├── values-ci.yaml               # CI окружение
    ├── test-values.yaml             # Тестовые значения
    └── lint-values.yaml             # Значения для линтинга
EOF
```

### **2. Chart.yaml с полными метаданными:**
```yaml
# Chart.yaml
apiVersion: v2
name: hashfoundry-webapp
description: HashFoundry Web Application Helm Chart
type: application
version: 1.0.0
appVersion: "1.2.3"

keywords:
  - hashfoundry
  - webapp
  - blockchain
  - react

home: https://hashfoundry.com
sources:
  - https://github.com/hashfoundry/webapp
  - https://github.com/hashfoundry/helm-charts

maintainers:
  - name: HashFoundry DevOps Team
    email: devops@hashfoundry.com
    url: https://hashfoundry.com

icon: https://hashfoundry.com/logo.png

annotations:
  category: Application
  licenses: MIT
  images: |
    - name: hashfoundry-webapp
      image: hashfoundry/webapp:1.2.3
    - name: nginx
      image: nginx:1.21-alpine

dependencies:
  - name: postgresql
    version: "11.9.13"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
    tags:
      - database
  - name: redis
    version: "17.3.7"
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
    tags:
      - cache
  - name: prometheus
    version: "15.12.0"
    repository: https://prometheus-community.github.io/helm-charts
    condition: monitoring.prometheus.enabled
    tags:
      - monitoring

kubeVersion: ">=1.20.0-0"

deprecated: false
```

### **3. Production-ready values.yaml:**
```yaml
# values.yaml - Default values
global:
  imageRegistry: ""
  imagePullSecrets: []
  storageClass: ""

nameOverride: ""
fullnameOverride: ""

image:
  registry: docker.io
  repository: hashfoundry/webapp
  tag: "1.2.3"
  pullPolicy: IfNotPresent
  pullSecrets: []

replicaCount: 3

strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  fsGroup: 1001
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1001

service:
  type: ClusterIP
  port: 80
  targetPort: 3000
  annotations: {}

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: webapp.hashfoundry.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: hashfoundry-webapp-tls
      hosts:
        - webapp.hashfoundry.com

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector:
  kubernetes.io/arch: amd64

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - hashfoundry-webapp
        topologyKey: kubernetes.io/hostname

podDisruptionBudget:
  enabled: true
  minAvailable: 2

networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
      ports:
      - protocol: TCP
        port: 3000

config:
  nodeEnv: production
  logLevel: warn
  apiTimeout: 30000
  cacheEnabled: true
  cacheTTL: 3600
  metricsEnabled: true
  healthCheckPath: /health
  readinessCheckPath: /ready

secrets:
  enabled: true
  data: {}
    # database-url: ""
    # api-key: ""
    # jwt-secret: ""

postgresql:
  enabled: true
  auth:
    postgresPassword: "changeme"
    database: "hashfoundry"
  primary:
    persistence:
      enabled: true
      size: 10Gi

redis:
  enabled: true
  auth:
    enabled: true
    password: "changeme"
  master:
    persistence:
      enabled: true
      size: 5Gi

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    path: /metrics
  prometheusRule:
    enabled: true

tests:
  enabled: true
  image:
    repository: curlimages/curl
    tag: latest
```

### **4. Environment-specific values:**
```yaml
# values-production.yaml
replicaCount: 5

image:
  tag: "1.2.3"

config:
  nodeEnv: production
  logLevel: warn
  cacheEnabled: true
  metricsEnabled: true

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20
  targetCPUUtilizationPercentage: 60

ingress:
  hosts:
    - host: webapp.hashfoundry.com
      paths:
        - path: /
          pathType: Prefix

nodeSelector:
  node-type: production
  kubernetes.io/arch: amd64

tolerations:
  - key: "production"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"

postgresql:
  enabled: true
  primary:
    persistence:
      size: 100Gi
    resources:
      limits:
        cpu: 2000m
        memory: 4Gi
      requests:
        cpu: 500m
        memory: 1Gi

redis:
  enabled: true
  master:
    persistence:
      size: 20Gi
    resources:
      limits:
        cpu: 1000m
        memory: 2Gi
      requests:
        cpu: 200m
        memory: 512Mi

---
# values-staging.yaml
replicaCount: 2

image:
  tag: "staging-latest"

config:
  nodeEnv: staging
  logLevel: debug
  cacheEnabled: false
  metricsEnabled: true

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false

ingress:
  hosts:
    - host: webapp-staging.hashfoundry.com
      paths:
        - path: /
          pathType: Prefix

postgresql:
  enabled: true
  primary:
    persistence:
      size: 10Gi

redis:
  enabled: false

---
# values-development.yaml
replicaCount: 1

image:
  tag: "dev-latest"
  pullPolicy: Always

config:
  nodeEnv: development
  logLevel: debug
  cacheEnabled: false
  metricsEnabled: false

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi

autoscaling:
  enabled: false

ingress:
  hosts:
    - host: webapp-dev.hashfoundry.com
      paths:
        - path: /
          pathType: Prefix

postgresql:
  enabled: false

redis:
  enabled: false

podDisruptionBudget:
  enabled: false

networkPolicy:
  enabled: false
```

### **5. Advanced Deployment template:**
```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "hashfoundry-webapp.fullname" . }}
  labels:
    {{- include "hashfoundry-webapp.labels" . | nindent 4 }}
  annotations:
    deployment.kubernetes.io/revision: "{{ .Values.image.tag }}"
    {{- with .Values.podAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  strategy:
    {{- toYaml .Values.strategy | nindent 4 }}
  selector:
    matchLabels:
      {{- include "hashfoundry-webapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "hashfoundry-webapp.selectorLabels" . | nindent 8 }}
        version: {{ .Values.image.tag | quote }}
    spec:
      {{- with .Values.image.pullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "hashfoundry-webapp.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      
      # Init containers
      initContainers:
      {{- if .Values.postgresql.enabled }}
      - name: wait-for-db
        image: postgres:13-alpine
        command:
        - sh
        - -c
        - |
          until pg_isready -h {{ include "hashfoundry-webapp.postgresql.fullname" . }} -p 5432; do
            echo "Waiting for PostgreSQL..."
            sleep 2
          done
        env:
        - name: PGHOST
          value: {{ include "hashfoundry-webapp.postgresql.fullname" . }}
        - name: PGPORT
          value: "5432"
      {{- end }}
      
      containers:
      - name: {{ .Chart.Name }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        {{- if .Values.monitoring.enabled }}
        - name: metrics
          containerPort: 9090
          protocol: TCP
        {{- end }}
        
        env:
        - name: NODE_ENV
          value: {{ .Values.config.nodeEnv | quote }}
        - name: LOG_LEVEL
          value: {{ .Values.config.logLevel | quote }}
        - name: PORT
          value: {{ .Values.service.targetPort | quote }}
        - name: HEALTH_CHECK_PATH
          value: {{ .Values.config.healthCheckPath | quote }}
        - name: READINESS_CHECK_PATH
          value: {{ .Values.config.readinessCheckPath | quote }}
        - name: API_TIMEOUT
          value: {{ .Values.config.apiTimeout | quote }}
        - name: CACHE_ENABLED
          value: {{ .Values.config.cacheEnabled | quote }}
        - name: CACHE_TTL
          value: {{ .Values.config.cacheTTL | quote }}
        - name: METRICS_ENABLED
          value: {{ .Values.config.metricsEnabled | quote }}
        
        # Database configuration
        {{- if .Values.postgresql.enabled }}
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: {{ include "hashfoundry-webapp.fullname" . }}-secrets
              key: database-url
        {{- end }}
        
        # Redis configuration
        {{- if .Values.redis.enabled }}
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: {{ include "hashfoundry-webapp.fullname" . }}-secrets
              key: redis-url
        {{- end }}
        
        # Custom secrets
        {{- if .Values.secrets.enabled }}
        {{- range $key, $value := .Values.secrets.data }}
        - name: {{ $key | upper | replace "-" "_" }}
          valueFrom:
            secretKeyRef:
              name: {{ include "hashfoundry-webapp.fullname" $ }}-secrets
              key: {{ $key }}
        {{- end }}
        {{- end }}
        
        # Health checks
        livenessProbe:
          httpGet:
            path: {{ .Values.config.healthCheckPath }}
            port: http
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
          successThreshold: 1
        
        readinessProbe:
          httpGet:
            path: {{ .Values.config.readinessCheckPath }}
            port: http
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        
        startupProbe:
          httpGet:
            path: {{ .Values.config.healthCheckPath }}
            port: http
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
          successThreshold: 1
        
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        
        # Volume mounts
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
        {{- if .Values.config.configMapEnabled }}
        - name: config
          mountPath: /app/config
          readOnly: true
        {{- end }}
      
      # Volumes
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      {{- if .Values.config.configMapEnabled }}
      - name: config
        configMap:
          name: {{ include "hashfoundry-webapp.fullname" . }}-config
      {{- end }}
      
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

## 🔄 **Advanced CI/CD Pipeline с Helm:**

### **1. GitHub Actions с полным Helm workflow:**
```yaml
# .github/workflows/helm-cicd.yml
name: Helm CI/CD Pipeline

on:
  push:
    branches: [main, develop, staging]
    paths:
    - 'src/**'
    - 'helm-chart/**'
    - 'Dockerfile'
  pull_request:
    branches: [main]
    paths:
    - 'src/**'
    - 'helm-chart/**'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: hashfoundry/webapp
  HELM_VERSION: 3.12.0
  KUBECTL_VERSION: 1.28.0

jobs:
  # Lint и валидация
  lint-and-validate:
    name: Lint and Validate
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: ${{ env.HELM_VERSION }}

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: ${{ env.KUBECTL_VERSION }}

    - name: Lint Helm chart
      run: |
        echo "🔍 Linting Helm chart..."
        helm lint ./helm-chart
        
        echo "🔍 Validating Helm templates..."
        helm template hashfoundry-webapp ./helm-chart \
          --values ./helm-chart/values.yaml \
          --dry-run > /dev/null
        
        echo "🔍 Validating with different environments..."
        for env in development staging production; do
          echo "Validating $env environment..."
          if [ -f "./helm-chart/values-$env.yaml" ]; then
            helm template hashfoundry-webapp ./helm-chart \
              --values ./helm-chart/values.yaml \
              --values ./helm-chart/values-$env.yaml \
              --dry-run > /dev/null
          fi
        done

    - name: Validate Kubernetes manifests
      run: |
        echo "🔍 Validating Kubernetes manifests..."
        helm template hashfoundry-webapp ./helm-chart \
          --values ./helm-chart/values.yaml | \
          kubectl apply --dry-run=client -f -

    - name: Security scan with Kubesec
      run: |
        echo "🔒 Running security scan..."
        helm template hashfoundry-webapp ./helm-chart \
          --values ./helm-chart/values.yaml | \
          docker run --rm -i kubesec/kubesec:latest scan /dev/stdin

    - name: Check Helm chart version
      run: |
        echo "📋 Checking chart version consistency..."
        CHART_VERSION=$(yq eval '.version' ./helm-chart/Chart.yaml)
        APP_VERSION=$(yq eval '.appVersion' ./helm-chart/Chart.yaml)
        echo "Chart version: $CHART_VERSION"
        echo "App version: $APP_VERSION"

  # Build и push образа
  build-and-push:
    name: Build and Push Image
    runs-on: ubuntu-latest
    needs: lint-and-validate
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to Container Registry
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

    - name: Build and push image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  # Package Helm chart
  package-chart:
    name: Package Helm Chart
    runs-on: ubuntu-latest
    needs: lint-and-validate
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: ${{ env.HELM_VERSION }}

    - name: Package Helm chart
      run: |
        echo "📦 Packaging Helm chart..."
        
        # Update chart version with build number
        CHART_VERSION=$(yq eval '.version' ./helm-chart/Chart.yaml)
        NEW_VERSION="${CHART_VERSION}-${{ github.run_number }}"
        
        yq eval ".version = \"$NEW_VERSION\"" -i ./helm-chart/Chart.yaml
        yq eval ".appVersion = \"${{ github.sha }}\"" -i ./helm-chart/Chart.yaml
        
        # Package chart
        helm package ./helm-chart --destination ./charts/
        
        # Create index
        helm repo index ./charts/ --url https://charts.hashfoundry.com

    - name: Upload chart artifacts
      uses: actions/upload-artifact@v3
      with:
        name: helm-charts
        path: ./charts/

  # Deploy to development
  deploy-development:
    name: Deploy to Development
    runs-on: ubuntu-latest
    needs: [build-and-push, package-chart]
    if: github.ref == 'refs/heads/develop'
    environment:
      name: development
      url: https://webapp-dev.hashfoundry.com
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: ${{ env.HELM_VERSION }}

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: ${{ env.KUBECTL_VERSION }}

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBECONFIG_DEV }}" | base64 -d > ~/.kube/config

    - name: Deploy to development
      run: |
        echo "🚀 Deploying to development..."
        
        IMAGE_TAG="${{ github.sha }}"
        
        helm upgrade --install hashfoundry-webapp-dev ./helm-chart \
          --namespace hashfoundry-development \
          --create-namespace \
          --values ./helm-chart/values.yaml \
          --values ./helm-chart/values-development.yaml \
          --set image.tag="$IMAGE_TAG" \
          --set image.repository="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" \
          --wait --timeout=300s

    - name: Run Helm tests
      run: |
        echo "🧪 Running Helm tests..."
        helm test hashfoundry-webapp-dev --namespace hashfoundry-development

    - name: Verify deployment
      run: |
        echo "✅ Verifying deployment..."
        kubectl get pods -n hashfoundry-development
        kubectl get svc -n hashfoundry-development
        kubectl get ingress -n hashfoundry-development

  # Deploy to staging
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: [build-and-push, package-chart]
    if: github.ref == 'refs/heads/staging'
    environment:
      name: staging
      url: https://webapp-staging.hashfoundry.com
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: ${{ env.HELM_VERSION }}

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: ${{ env.KUBECTL_VERSION }}

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBECONFIG_STAGING }}" | base64 -d > ~/.kube/config

    - name: Deploy to staging
      run: |
        echo "🚀 Deploying to staging..."
        
        IMAGE_TAG="${{ github.sha }}"
        
        helm upgrade --install hashfoundry-webapp-staging ./helm-chart \
          --namespace hashfoundry-staging \
          --create-namespace \
          --values ./helm-chart/values.yaml \
          --values ./helm-chart/values-staging.yaml \
          --set image.tag="$IMAGE_TAG" \
          --set image.repository="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" \
          --wait --timeout=600s

    - name: Run Helm tests
      run: |
        echo "🧪 Running Helm tests..."
        helm test hashfoundry-webapp-staging --namespace hashfoundry-staging

    - name: Run integration tests
      run: |
        echo "🧪 Running integration tests..."
        kubectl run integration-tests --rm -i --restart=Never \
          --image=hashfoundry/integration-tests:latest \
          --env="TARGET_URL=https://webapp-staging.hashfoundry.com" \
          -- /run-tests.sh

  # Deploy to production
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build-and-push, package-chart, deploy-staging]
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://webapp.hashfoundry.com
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: ${{ env.HELM_VERSION }}

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: ${{ env.KUBECTL_VERSION }}

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBECONFIG_PROD }}" | base64 -d > ~/.kube/config

    - name: Deploy to production with Blue-Green
      run: |
        echo "🚀 Deploying to production with Blue-Green strategy..."
        
        IMAGE_TAG="${{ github.sha }}"
        RELEASE_NAME="hashfoundry-webapp-prod"
        NAMESPACE="hashfoundry-production"
        
        # Check current deployment
        CURRENT_COLOR=$(kubectl get deployment $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.metadata.labels.color}' 2>/dev/null || echo "blue")
        NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")
        
        echo "Current color: $CURRENT_COLOR, New color: $NEW_COLOR"
        
        # Deploy new version
        helm upgrade --install $RELEASE_NAME-$NEW_COLOR ./helm-chart \
          --namespace $NAMESPACE \
          --create-namespace \
          --values ./helm-chart/values.yaml \
          --values ./helm-chart/values-production.yaml \
          --set image.tag="$IMAGE_TAG" \
          --set image.repository="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" \
          --set deployment.color="$NEW_COLOR" \
          --wait --timeout=900s

    - name: Run production health checks
      run: |
        echo "🏥 Running production health checks..."
        
        # Wait for deployment to be ready
        kubectl wait --for=condition=available --timeout=300s \
          deployment/hashfoundry-webapp-prod-$NEW_COLOR -n hashfoundry-production
        
        # Run Helm tests
        helm test hashfoundry-webapp-prod-$NEW_COLOR --namespace hashfoundry-production
        
        # Run smoke tests
        kubectl run smoke-tests --rm -i --restart=Never \
          --image=hashfoundry/smoke-tests:latest \
          --env="TARGET_URL=http://hashfoundry-webapp-prod-$NEW_COLOR.hashfoundry-production.svc.cluster.local" \
          -- /run-smoke-tests.sh

    - name: Switch traffic to new version
      run: |
        echo "🔄 Switching traffic to new version..."
        
        # Update main service to point to new color
        kubectl patch service hashfoundry-webapp-prod -n hashfoundry-production \
          -p "{\"spec\":{\"selector\":{\"color\":\"$NEW_COLOR\"}}}"
        
        # Wait for traffic switch
        sleep 30
        
        # Verify new version is serving traffic
        curl -f https://webapp.hashfoundry.com/health

    - name: Cleanup old version
      run: |
        echo "🧹 Cleaning up old version..."
        
        # Remove old deployment
        helm uninstall hashfoundry-webapp-prod-$CURRENT_COLOR --namespace hashfoundry-production || true
        
        # Rename new deployment to main
        helm upgrade --install hashfoundry-webapp-prod ./helm-chart \
          --namespace hashfoundry-production \
          --values ./helm-chart/values.yaml \
          --values ./helm-chart/values-production.yaml \
          --set image.tag="${{ github.sha }}" \
          --set image.repository="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" \
          --wait --timeout=600s

  # Publish Helm chart
  publish-chart:
    name: Publish Helm Chart
    runs-on: ubuntu-latest
    needs: [package-chart, deploy-production]
    if: github.ref == 'refs/heads/main'
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Download chart artifacts
      uses: actions/download-artifact@v3
      with:
        name: helm-charts
        path: ./charts/

    - name: Publish to Helm repository
      run: |
        echo "📦 Publishing Helm chart to repository..."
        
        # Configure AWS CLI for S3 (if using S3 as chart repository)
        aws configure set aws_access_key_id ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws configure set aws_secret_access_key ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws configure set region us-east-1
        
        # Upload charts to S3
        aws s3 sync ./charts/ s3://hashfoundry-helm-charts/ --delete
        
        # Update chart repository index
        aws s3 cp s3://hashfoundry-helm-charts/index.yaml ./index.yaml
        helm repo index ./charts/ --url https://charts.hashfoundry.com --merge ./index.yaml
        aws s3 cp ./charts/index.yaml s3://hashfoundry-helm-charts/index.yaml

  # Notify deployment
  notify:
    name: Notify Deployment
    runs-on: ubuntu-latest
    needs: [deploy-production, publish-chart]
    if: always()
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        fields: repo,message,commit,author,action,eventName,ref,workflow
        custom_payload: |
          {
            "text": "Helm Production Deployment",
            "attachments": [{
              "color": "${{ job.status == 'success' && 'good' || 'danger' }}",
              "fields": [{
                "title": "Repository",
                "value": "${{ github.repository }}",
                "short": true
              }, {
                "title": "Environment",
                "value": "Production",
                "short": true
              }, {
                "title": "Status",
                "value": "${{ job.status }}",
                "short": true
              }, {
                "title": "Image Tag",
                "value": "${{ github.sha }}",
                "short": true
              }, {
                "title": "URL",
                "value": "https://webapp.hashfoundry.com",
                "short": true
              }]
            }]
          }
```

### **2. Jenkins Pipeline с Helm:**
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        HELM_VERSION = '3.12.0'
        KUBECTL_VERSION = '1.28.0'
        REGISTRY = 'ghcr.io'
        IMAGE_NAME = 'hashfoundry/webapp'
        KUBECONFIG = credentials('kubeconfig-prod')
        GITHUB_TOKEN = credentials('github-token')
    }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['development', 'staging', 'production'],
            description: 'Target environment'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: 'latest',
            description: 'Docker image tag to deploy'
        )
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run Helm tests after deployment'
        )
        booleanParam(
            name: 'BLUE_GREEN_DEPLOYMENT',
            defaultValue: false,
            description: 'Use Blue-Green deployment strategy'
        )
    }
    
    stages {
        stage('Setup') {
            steps {
                script {
                    // Install Helm
                    sh '''
                        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                        chmod 700 get_helm.sh
                        ./get_helm.sh --version v${HELM_VERSION}
                    '''
                    
                    // Install kubectl
                    sh '''
                        curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/
                    '''
                }
            }
        }
        
        stage('Lint and Validate') {
            steps {
                script {
                    echo "🔍 Linting Helm chart..."
                    sh 'helm lint ./helm-chart'
                    
                    echo "🔍 Validating Helm templates..."
                    sh '''
                        helm template hashfoundry-webapp ./helm-chart \
                          --values ./helm-chart/values.yaml \
                          --values ./helm-chart/values-${ENVIRONMENT}.yaml \
                          --set image.tag=${IMAGE_TAG} \
                          --dry-run > /dev/null
                    '''
                    
                    echo "🔍 Validating Kubernetes manifests..."
                    sh '''
                        helm template hashfoundry-webapp ./helm-chart \
                          --values ./helm-chart/values.yaml \
                          --values ./helm-chart/values-${ENVIRONMENT}.yaml \
                          --set image.tag=${IMAGE_TAG} | \
                          kubectl apply --dry-run=client -f -
                    '''
                }
            }
        }
        
        stage('Package Chart') {
            steps {
                script {
                    echo "📦 Packaging Helm chart..."
                    sh '''
                        # Update chart version
                        CHART_VERSION=$(yq eval '.version' ./helm-chart/Chart.yaml)
                        NEW_VERSION="${CHART_VERSION}-${BUILD_NUMBER}"
                        
                        yq eval ".version = \\"$NEW_VERSION\\"" -i ./helm-chart/Chart.yaml
                        yq eval ".appVersion = \\"${IMAGE_TAG}\\"" -i ./helm-chart/Chart.yaml
                        
                        # Package chart
                        helm package ./helm-chart --destination ./charts/
                        
                        # Create index
                        helm repo index ./charts/ --url https://charts.hashfoundry.com
                    '''
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    if (params.BLUE_GREEN_DEPLOYMENT && params.ENVIRONMENT == 'production') {
                        echo "🚀 Deploying with Blue-Green strategy..."
                        sh '''
                            # Blue-Green deployment logic
                            RELEASE_NAME="hashfoundry-webapp-${ENVIRONMENT}"
                            NAMESPACE="hashfoundry-${ENVIRONMENT}"
                            
                            # Determine current and new colors
                            CURRENT_COLOR=$(kubectl get deployment $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.metadata.labels.color}' 2>/dev/null || echo "blue")
                            NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")
                            
                            echo "Deploying $NEW_COLOR version..."
                            
                            # Deploy new version
                            helm upgrade --install $RELEASE_NAME-$NEW_COLOR ./helm-chart \
                              --namespace $NAMESPACE \
                              --create-namespace \
                              --values ./helm-chart/values.yaml \
                              --values ./helm-chart/values-${ENVIRONMENT}.yaml \
                              --set image.tag=${IMAGE_TAG} \
                              --set deployment.color=$NEW_COLOR \
                              --wait --timeout=900s
                            
                            # Health check
                            kubectl wait --for=condition=available --timeout=300s \
                              deployment/$RELEASE_NAME-$NEW_COLOR -n $NAMESPACE
                            
                            # Switch traffic
                            kubectl patch service $RELEASE_NAME -n $NAMESPACE \
                              -p "{\\"spec\\":{\\"selector\\":{\\"color\\":\\"$NEW_COLOR\\"}}}"
                            
                            # Cleanup old version
                            helm uninstall $RELEASE_NAME-$CURRENT_COLOR --namespace $NAMESPACE || true
                        '''
                    } else {
                        echo "🚀 Deploying with Rolling Update strategy..."
                        sh '''
                            RELEASE_NAME="hashfoundry-webapp-${ENVIRONMENT}"
                            NAMESPACE="hashfoundry-${ENVIRONMENT}"
                            
                            helm upgrade --install $RELEASE_NAME ./helm-chart \
                              --namespace $NAMESPACE \
                              --create-namespace \
                              --values ./helm-chart/values.yaml \
                              --values ./helm-chart/values-${ENVIRONMENT}.yaml \
                              --set image.tag=${IMAGE_TAG} \
                              --wait --timeout=600s
                        '''
                    }
                }
            }
        }
        
        stage('Test') {
            when {
                expression { params.RUN_TESTS }
            }
            steps {
                script {
                    echo "🧪 Running Helm tests..."
                    sh '''
                        RELEASE_NAME="hashfoundry-webapp-${ENVIRONMENT}"
                        NAMESPACE="hashfoundry-${ENVIRONMENT}"
                        
                        helm test $RELEASE_NAME --namespace $NAMESPACE
                    '''
                    
                    echo "🧪 Running integration tests..."
                    sh '''
                        kubectl run integration-tests-${BUILD_NUMBER} --rm -i --restart=Never \
                          --image=hashfoundry/integration-tests:latest \
                          --env="TARGET_URL=https://webapp-${ENVIRONMENT}.hashfoundry.com" \
                          -- /run-tests.sh
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    echo "✅ Verifying deployment..."
                    sh '''
                        NAMESPACE="hashfoundry-${ENVIRONMENT}"
                        
                        echo "Pods:"
                        kubectl get pods -n $NAMESPACE
                        
                        echo "Services:"
                        kubectl get svc -n $NAMESPACE
                        
                        echo "Ingress:"
                        kubectl get ingress -n $NAMESPACE
                        
                        echo "HPA:"
                        kubectl get hpa -n $NAMESPACE
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Archive Helm charts
                archiveArtifacts artifacts: 'charts/*.tgz', fingerprint: true
                
                // Cleanup
                sh 'rm -rf charts/'
            }
        }
        
        success {
            script {
                echo "✅ Deployment successful!"
                
                // Notify Slack
                slackSend(
                    channel: '#deployments',
                    color: 'good',
                    message: """
                        ✅ Helm Deployment Successful
                        Environment: ${params.ENVIRONMENT}
                        Image Tag: ${params.IMAGE_TAG}
                        Build: ${BUILD_NUMBER}
                        URL: https://webapp-${params.ENVIRONMENT}.hashfoundry.com
                    """
                )
            }
        }
        
        failure {
            script {
                echo "❌ Deployment failed!"
                
                // Rollback on failure
                sh '''
                    RELEASE_NAME="hashfoundry-webapp-${ENVIRONMENT}"
                    NAMESPACE="hashfoundry-${ENVIRONMENT}"
                    
                    echo "Rolling back to previous version..."
                    helm rollback $RELEASE_NAME --namespace $NAMESPACE
                '''
                
                // Notify Slack
                slackSend(
                    channel: '#deployments',
                    color: 'danger',
                    message: """
                        ❌ Helm Deployment Failed
                        Environment: ${params.ENVIRONMENT}
                        Image Tag: ${params.IMAGE_TAG}
                        Build: ${BUILD_NUMBER}
                        Rolled back to previous version
                    """
                )
            }
        }
    }
}
```

## 🔐 **Advanced Helm Security и Best Practices:**

### **1. Helm Secrets для управления секретами:**
```bash
#!/bin/bash
# scripts/setup-helm-secrets.sh

echo "🔐 Setting up Helm Secrets..."

# Install helm-secrets plugin
helm plugin install https://github.com/jkroepke/helm-secrets --version v4.4.2

# Install SOPS
curl -LO https://github.com/mozilla/sops/releases/download/v3.7.3/sops-v3.7.3.linux.amd64
chmod +x sops-v3.7.3.linux.amd64
sudo mv sops-v3.7.3.linux.amd64 /usr/local/bin/sops

# Create .sops.yaml configuration
cat << 'EOF' > .sops.yaml
creation_rules:
  - path_regex: \.secrets\.yaml$
    encrypted_regex: '^(data|stringData)$'
    age: age1ql3z7hjy54pw9hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
  - path_regex: values-.*\.secrets\.yaml$
    encrypted_regex: '^(.*\.password|.*\.key|.*\.secret|.*\.token)$'
    age: age1ql3z7hjy54pw9hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
EOF

echo "✅ Helm Secrets setup completed!"
```

### **2. Encrypted values files:**
```yaml
# values-production.secrets.yaml (encrypted)
postgresql:
  auth:
    postgresPassword: ENC[AES256_GCM,data:Tr7o1...]
    password: ENC[AES256_GCM,data:CwE4O...]

redis:
  auth:
    password: ENC[AES256_GCM,data:p673w...]

secrets:
  data:
    database-url: ENC[AES256_GCM,data:8jmwVZ...]
    api-key: ENC[AES256_GCM,data:HQmp9...]
    jwt-secret: ENC[AES256_GCM,data:LKj8n...]

# Deployment with encrypted secrets
helm secrets upgrade --install hashfoundry-webapp ./helm-chart \
  --namespace hashfoundry-production \
  --values ./helm-chart/values.yaml \
  --values ./helm-chart/values-production.yaml \
  --values secrets://./helm-chart/values-production.secrets.yaml \
  --set image.tag="v1.2.3"
```

### **3. Helm Chart testing framework:**
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "hashfoundry-webapp.fullname" . }}-test-connection"
  labels:
    {{- include "hashfoundry-webapp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
  - name: wget
    image: busybox:1.35
    command: ['wget']
    args: ['--no-check-certificate', '--quiet', '--timeout=30', '--tries=3', '--spider', '{{ include "hashfoundry-webapp.fullname" . }}:{{ .Values.service.port }}/health']
  - name: curl-health
    image: curlimages/curl:8.1.2
    command: ['curl']
    args: ['-f', '{{ include "hashfoundry-webapp.fullname" . }}:{{ .Values.service.port }}/health']

---
# templates/tests/test-api.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "hashfoundry-webapp.fullname" . }}-test-api"
  labels:
    {{- include "hashfoundry-webapp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-weight": "2"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
  - name: api-test
    image: curlimages/curl:8.1.2
    command: ['/bin/sh']
    args:
    - -c
    - |
      set -e
      echo "Testing API endpoints..."
      
      # Test health endpoint
      curl -f {{ include "hashfoundry-webapp.fullname" . }}:{{ .Values.service.port }}/health
      
      # Test ready endpoint
      curl -f {{ include "hashfoundry-webapp.fullname" . }}:{{ .Values.service.port }}/ready
      
      # Test API version endpoint
      curl -f {{ include "hashfoundry-webapp.fullname" . }}:{{ .Values.service.port }}/api/version
      
      echo "All API tests passed!"

---
# templates/tests/test-database.yaml
{{- if .Values.postgresql.enabled }}
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "hashfoundry-webapp.fullname" . }}-test-database"
  labels:
    {{- include "hashfoundry-webapp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-weight": "3"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
  - name: postgres-test
    image: postgres:13-alpine
    env:
    - name: PGHOST
      value: {{ include "hashfoundry-webapp.postgresql.fullname" . }}
    - name: PGPORT
      value: "5432"
    - name: PGUSER
      value: postgres
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "hashfoundry-webapp.postgresql.secretName" . }}
          key: postgres-password
    - name: PGDATABASE
      value: {{ .Values.postgresql.auth.database }}
    command: ['/bin/sh']
    args:
    - -c
    - |
      set -e
      echo "Testing PostgreSQL connection..."
      
      # Test connection
      pg_isready -h $PGHOST -p $PGPORT
      
      # Test database access
      psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "SELECT version();"
      
      echo "Database tests passed!"
{{- end }}
```

## 📊 **Monitoring и Observability для Helm:**

### **1. Prometheus monitoring для Helm releases:**
```yaml
# monitoring/helm-exporter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helm-exporter
  namespace: monitoring
  labels:
    app.kubernetes.io/name: helm-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: helm-exporter
  template:
    metadata:
      labels:
        app.kubernetes.io/name: helm-exporter
    spec:
      serviceAccountName: helm-exporter
      containers:
      - name: helm-exporter
        image: sstarcher/helm-exporter:latest
        ports:
        - containerPort: 9571
          name: metrics
        env:
        - name: HELM_NAMESPACE
          value: ""
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: helm-exporter
  namespace: monitoring

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: helm-exporter
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: helm-exporter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: helm-exporter
subjects:
- kind: ServiceAccount
  name: helm-exporter
  namespace: monitoring

---
apiVersion: v1
kind: Service
metadata:
  name: helm-exporter
  namespace: monitoring
  labels:
    app.kubernetes.io/name: helm-exporter
spec:
  ports:
  - port: 9571
    targetPort: 9571
    name: metrics
  selector:
    app.kubernetes.io/name: helm-exporter

---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: helm-exporter
  namespace: monitoring
  labels:
    app.kubernetes.io/name: helm-exporter
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: helm-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### **2. Prometheus alerts для Helm:**
```yaml
# monitoring/helm-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: helm-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: helm-alerts
    release: prometheus
spec:
  groups:
  - name: helm.rules
    rules:
    # Helm release failed
    - alert: HelmReleaseFailed
      expr: helm_chart_info{status="failed"} == 1
      for: 0m
      labels:
        severity: critical
        component: helm
      annotations:
        summary: "Helm release {{ $labels.chart }} failed"
        description: "Helm release {{ $labels.chart }} in namespace {{ $labels.namespace }} has failed status."
        runbook_url: "https://docs.hashfoundry.com/runbooks/helm-release-failed"
    
    # Helm release pending
    - alert: HelmReleasePending
      expr: helm_chart_info{status="pending-install"} == 1 or helm_chart_info{status="pending-upgrade"} == 1
      for: 10m
      labels:
        severity: warning
        component: helm
      annotations:
        summary: "Helm release {{ $labels.chart }} is pending"
        description: "Helm release {{ $labels.chart }} in namespace {{ $labels.namespace }} has been pending for more than 10 minutes."
        runbook_url: "https://docs.hashfoundry.com/runbooks/helm-release-pending"
    
    # Helm release superseded
    - alert: HelmReleaseSuperseded
      expr: helm_chart_info{status="superseded"} == 1
      for: 1h
      labels:
        severity: info
        component: helm
      annotations:
        summary: "Helm release {{ $labels.chart }} is superseded"
        description: "Helm release {{ $labels.chart }} in namespace {{ $labels.namespace }} has been superseded and should be cleaned up."
        runbook_url: "https://docs.hashfoundry.com/runbooks/helm-release-superseded"
    
    # Helm chart version mismatch
    - alert: HelmChartVersionMismatch
      expr: |
        (
          helm_chart_info{chart="hashfoundry-webapp"} 
          unless on(namespace) 
          helm_chart_info{chart="hashfoundry-webapp", version="1.0.0"}
        ) == 1
      for: 5m
      labels:
        severity: warning
        component: helm
      annotations:
        summary: "Helm chart version mismatch detected"
        description: "Helm chart {{ $labels.chart }} in namespace {{ $labels.namespace }} is not running the expected version 1.0.0."
        runbook_url: "https://docs.hashfoundry.com/runbooks/helm-version-mismatch"
```

## 🎯 **Проверка Helm в вашем кластере:**

### **1. Диагностика Helm в HA кластере:**
```bash
#!/bin/bash
# scripts/diagnose-helm.sh

echo "🔍 Helm Diagnostics for HashFoundry HA Cluster"

# 1. Проверка версии Helm
echo "📋 Helm version:"
helm version

# 2. Проверка всех Helm releases
echo "📦 All Helm releases:"
helm list -A -o table

# 3. Проверка failed releases
echo "❌ Failed releases:"
helm list -A --failed

# 4. Проверка pending releases
echo "⏳ Pending releases:"
helm list -A --pending

# 5. Детальная информация о каждом release
echo "📊 Detailed release information:"
for release in $(helm list -A -q); do
    namespace=$(helm list -A | grep $release | awk '{print $2}')
    echo "Release: $release (namespace: $namespace)"
    helm status $release -n $namespace
    echo "---"
done

# 6. Проверка Helm repositories
echo "📚 Helm repositories:"
helm repo list

# 7. Проверка истории releases
echo "📜 Release history:"
for release in $(helm list -A -q); do
    namespace=$(helm list -A | grep $release | awk '{print $2}')
    echo "History for $release:"
    helm history $release -n $namespace
    echo "---"
done

# 8. Проверка values
echo "⚙️ Release values:"
for release in $(helm list -A -q); do
    namespace=$(helm list -A | grep $release | awk '{print $2}')
    echo "Values for $release:"
    helm get values $release -n $namespace
    echo "---"
done

# 9. Проверка ресурсов Kubernetes для Helm releases
echo "🔧 Kubernetes resources for Helm releases:"
for release in $(helm list -A -q); do
    namespace=$(helm list -A | grep $release | awk '{print $2}')
    echo "Resources for $release in namespace $namespace:"
    kubectl get all -l app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=$release -n $namespace
    echo "---"
done

echo "✅ Helm diagnostics completed!"
```

### **2. Мониторинг Helm в реальном времени:**
```bash
#!/bin/bash
# scripts/monitor-helm.sh

echo "📊 Real-time Helm Monitoring for HashFoundry HA Cluster"

# Функция для мониторинга Helm releases
monitor_releases() {
    while true; do
        clear
        echo "🔄 Helm Releases Status - $(date)"
        echo "=================================="
        
        # Показать все releases с цветовой кодировкой
        helm list -A -o table | while read line; do
            if echo "$line" | grep -q "deployed"; then
                echo -e "\033[32m$line\033[0m"  # Зеленый для deployed
            elif echo "$line" | grep -q "failed"; then
                echo -e "\033[31m$line\033[0m"  # Красный для failed
            elif echo "$line" | grep -q "pending"; then
                echo -e "\033[33m$line\033[0m"  # Желтый для pending
            else
                echo "$line"
            fi
        done
        
        echo ""
        echo "📈 Release Statistics:"
        echo "Total releases: $(helm list -A -q | wc -l)"
        echo "Deployed: $(helm list -A | grep deployed | wc -l)"
        echo "Failed: $(helm list -A --failed | wc -l)"
        echo "Pending: $(helm list -A --pending | wc -l)"
        
        sleep 5
    done
}

# Запуск мониторинга
monitor_releases
```

## 🎓 **Заключение:**

**Helm в CI/CD пайплайнах** предоставляет мощные возможности для:

1. **Шаблонизации** - динамические манифесты для разных окружений
2. **Версионирования** - отслеживание изменений и откаты
3. **Управления зависимостями** - автоматическая установка связанных компонентов
4. **Тестирования** - встроенные тесты для валидации развертываний
5. **Безопасности** - шифрование секретов и валидация
6. **Мониторинга** - отслеживание состояния releases

### **Ключевые команды для изучения в вашем HA кластере:**
```bash
# Основные команды диагностики
helm list -A
helm status <release> -n <namespace>
helm history <release> -n <namespace>
helm get values <release> -n <namespace>
helm get all <release> -n <namespace>

# Команды для работы с charts
helm lint ./chart
helm template ./chart --values values.yaml
helm package ./chart
helm test <release> -n <namespace>

# Команды развертывания
helm upgrade --install <release> ./chart --namespace <ns>
helm rollback <release> <revision> -n <namespace>
helm uninstall <release> -n <namespace>
```

Helm значительно упрощает управление сложными Kubernetes приложениями в CI/CD пайплайнах, обеспечивая консистентность, повторяемость и надежность развертываний.
