# 143. Как реализовать GitOps с Kubernetes

## 🎯 **Основные концепции:**

| Аспект | Традиционный подход | GitOps подход |
|--------|-------------------|---------------|
| **Развертывание** | Push-модель (CI/CD пушит в кластер) | Pull-модель (кластер синхронизируется с Git) |
| **Источник истины** | Множественные источники | Git как единственный источник |
| **Доступ к кластеру** | Прямой доступ из CI/CD | Нет прямого доступа |
| **Откат изменений** | Сложные процедуры | Git revert |
| **Аудит** | Логи CI/CD системы | Git история |
| **Безопасность** | Секреты в CI/CD | Sealed Secrets в Git |
| **Дрифт** | Ручное обнаружение | Автоматическое обнаружение |
| **Мульти-кластер** | Сложная настройка | Декларативное управление |

## 🏆 **GitOps - что это такое?**

**GitOps** — это операционная модель для Kubernetes, которая использует Git как единственный источник истины для декларативной инфраструктуры и приложений. Система автоматически синхронизирует желаемое состояние (в Git) с фактическим состоянием (в кластере).

### **Ключевые принципы GitOps:**
- **Декларативность** - всё описано как код
- **Версионирование** - Git как источник истины
- **Автоматизация** - автоматическая синхронизация
- **Наблюдаемость** - мониторинг дрифта
- **Безопасность** - нет прямого доступа к кластеру

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка ArgoCD в кластере:**
```bash
# Проверка статуса ArgoCD
kubectl get pods -n argocd -o wide

# Проверка ArgoCD приложений
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL

# Проверка ArgoCD сервисов
kubectl get svc -n argocd

# Получение пароля admin для ArgoCD
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Проверка ArgoCD ConfigMap
kubectl get configmap argocd-cm -n argocd -o yaml
```

### **2. Анализ текущих GitOps приложений:**
```bash
# Детальная информация о приложениях
kubectl describe applications -n argocd

# Проверка истории синхронизации
kubectl get events -n argocd --sort-by='.lastTimestamp' | grep Application

# Проверка ArgoCD метрик
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082

# Логи ArgoCD application controller
kubectl logs -f deployment/argocd-application-controller -n argocd --tail=50
```

### **3. Проверка GitOps репозиториев:**
```bash
# Проверка подключенных репозиториев в ArgoCD
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository

# Проверка ArgoCD проектов
kubectl get appprojects -n argocd

# Проверка RBAC настроек ArgoCD
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
```

## 🛠️ **Comprehensive GitOps Implementation:**

### **1. Структура GitOps репозитория:**
```bash
# Создать полную структуру GitOps репозитория
mkdir -p hashfoundry-gitops/{apps,infrastructure,clusters,scripts,docs}
cd hashfoundry-gitops

# Структура файлов
cat << 'EOF'
hashfoundry-gitops/
├── apps/                             # Приложения
│   ├── base/                         # Базовые манифесты
│   │   ├── webapp/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── hpa.yaml
│   │   │   └── kustomization.yaml
│   │   └── api/
│   ├── overlays/                     # Environment-specific
│   │   ├── development/
│   │   │   ├── webapp/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   ├── deployment-patch.yaml
│   │   │   │   └── configmap-patch.yaml
│   │   │   └── api/
│   │   ├── staging/
│   │   │   ├── webapp/
│   │   │   └── api/
│   │   └── production/
│   │       ├── webapp/
│   │       └── api/
│   └── argocd-apps/                  # ArgoCD Applications
│       ├── development.yaml
│       ├── staging.yaml
│       └── production.yaml
├── infrastructure/                   # Инфраструктурные компоненты
│   ├── monitoring/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   └── alertmanager/
│   ├── ingress/
│   │   ├── nginx-ingress/
│   │   └── cert-manager/
│   ├── storage/
│   │   ├── nfs-provisioner/
│   │   └── persistent-volumes/
│   └── security/
│       ├── network-policies/
│       ├── pod-security-policies/
│       └── sealed-secrets/
├── clusters/                         # Cluster-specific конфигурации
│   ├── hashfoundry-ha/              # Production HA cluster
│   │   ├── argocd/
│   │   │   ├── install.yaml
│   │   │   ├── projects.yaml
│   │   │   └── repositories.yaml
│   │   ├── bootstrap/
│   │   │   └── root-app.yaml
│   │   └── config/
│   │       ├── cluster-config.yaml
│   │       └── cluster-secrets.yaml
│   ├── hashfoundry-dev/             # Development cluster
│   └── hashfoundry-staging/         # Staging cluster
├── scripts/                          # Automation scripts
│   ├── bootstrap-cluster.sh
│   ├── promote-app.sh
│   ├── sync-all-apps.sh
│   └── backup-configs.sh
├── docs/                             # Документация
│   ├── gitops-workflow.md
│   ├── deployment-guide.md
│   ├── troubleshooting.md
│   └── runbooks/
├── .github/                          # GitHub Actions
│   └── workflows/
│       ├── validate-manifests.yml
│       ├── promote-staging.yml
│       └── security-scan.yml
├── .gitignore
├── README.md
└── SECURITY.md
EOF
```

### **2. ArgoCD Application для HashFoundry webapp:**
```yaml
# apps/argocd-apps/production.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hashfoundry-webapp-production
  namespace: argocd
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: frontend
    environment: production
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: hashfoundry-production
  
  source:
    repoURL: https://github.com/hashfoundry/gitops-config
    targetRevision: main
    path: apps/overlays/production/webapp
    
    # Kustomize конфигурация
    kustomize:
      images:
      - hashfoundry/webapp:v1.2.3
      commonLabels:
        environment: production
        managed-by: argocd
      commonAnnotations:
        deployment.kubernetes.io/revision: "1"
        argocd.argoproj.io/tracking-id: hashfoundry-webapp-production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: hashfoundry-production
  
  syncPolicy:
    automated:
      prune: true           # Удалять ресурсы, которых нет в Git
      selfHeal: true        # Автоматически исправлять дрифт
      allowEmpty: false     # Не разрешать пустые приложения
    
    syncOptions:
    - CreateNamespace=true  # Создавать namespace если не существует
    - PrunePropagationPolicy=foreground
    - PruneLast=true       # Удалять ресурсы в последнюю очередь
    - ApplyOutOfSyncOnly=true
    - RespectIgnoreDifferences=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
  
  # Ignore differences для определенных полей
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas  # Игнорировать изменения replicas (управляется HPA)
  - group: ""
    kind: Service
    jsonPointers:
    - /spec/clusterIP  # Игнорировать изменения clusterIP
  
  # Health check конфигурация
  info:
  - name: 'Example'
    value: 'https://hashfoundry.com'
  - name: 'Repository'
    value: 'https://github.com/hashfoundry/webapp'

---
# ArgoCD Project для production
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: hashfoundry-production
  namespace: argocd
  labels:
    environment: production
spec:
  description: HashFoundry Production Applications
  
  # Source repositories
  sourceRepos:
  - 'https://github.com/hashfoundry/gitops-config'
  - 'https://github.com/hashfoundry/helm-charts'
  
  # Destination clusters и namespaces
  destinations:
  - namespace: 'hashfoundry-production'
    server: https://kubernetes.default.svc
  - namespace: 'monitoring'
    server: https://kubernetes.default.svc
  - namespace: 'ingress-nginx'
    server: https://kubernetes.default.svc
  
  # Cluster resource whitelist
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: rbac.authorization.k8s.io
    kind: ClusterRole
  - group: rbac.authorization.k8s.io
    kind: ClusterRoleBinding
  - group: networking.k8s.io
    kind: NetworkPolicy
  
  # Namespace resource whitelist
  namespaceResourceWhitelist:
  - group: ''
    kind: ConfigMap
  - group: ''
    kind: Secret
  - group: ''
    kind: Service
  - group: ''
    kind: ServiceAccount
  - group: apps
    kind: Deployment
  - group: apps
    kind: StatefulSet
  - group: networking.k8s.io
    kind: Ingress
  - group: autoscaling
    kind: HorizontalPodAutoscaler
  - group: policy
    kind: PodDisruptionBudget
  
  # RBAC roles
  roles:
  - name: production-admin
    description: Full access to production applications
    policies:
    - p, proj:hashfoundry-production:production-admin, applications, *, hashfoundry-production/*, allow
    - p, proj:hashfoundry-production:production-admin, repositories, *, *, allow
    groups:
    - hashfoundry:devops
    - hashfoundry:platform-team
  
  - name: production-developer
    description: Limited access to production applications
    policies:
    - p, proj:hashfoundry-production:production-developer, applications, get, hashfoundry-production/*, allow
    - p, proj:hashfoundry-production:production-developer, applications, sync, hashfoundry-production/*, allow
    groups:
    - hashfoundry:developers
  
  # Sync windows
  syncWindows:
  - kind: allow
    schedule: '0 9-17 * * 1-5'  # Рабочие часы
    duration: 8h
    applications:
    - '*'
    manualSync: true
  - kind: deny
    schedule: '0 0-6 * * *'     # Ночные часы
    duration: 6h
    applications:
    - '*'
    manualSync: false
```

### **3. Kustomize конфигурация для production:**
```yaml
# apps/overlays/production/webapp/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: hashfoundry-webapp-production

namespace: hashfoundry-production

resources:
- ../../../base/webapp
- ingress.yaml
- sealed-secrets.yaml
- network-policy.yaml
- pod-disruption-budget.yaml

patchesStrategicMerge:
- deployment-patch.yaml
- service-patch.yaml
- configmap-patch.yaml

replicas:
- name: hashfoundry-webapp
  count: 5

images:
- name: hashfoundry/webapp
  newTag: v1.2.3

configMapGenerator:
- name: webapp-config
  behavior: merge
  literals:
  - NODE_ENV=production
  - LOG_LEVEL=warn
  - METRICS_ENABLED=true
  - CACHE_TTL=3600
  - API_TIMEOUT=30000
  - FEATURE_ANALYTICS=true
  - FEATURE_NEW_UI=true

secretGenerator:
- name: webapp-secrets
  type: Opaque
  literals:
  - database-password=placeholder  # Будет заменено Sealed Secret

patches:
# Resource limits для production
- target:
    kind: Deployment
    name: hashfoundry-webapp
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/cpu
      value: 200m
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/cpu
      value: 2000m
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/memory
      value: 256Mi
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: 1Gi

# Production node selector
- target:
    kind: Deployment
    name: hashfoundry-webapp
  patch: |-
    - op: add
      path: /spec/template/spec/nodeSelector
      value:
        node-type: production
        kubernetes.io/arch: amd64

# Production tolerations
- target:
    kind: Deployment
    name: hashfoundry-webapp
  patch: |-
    - op: add
      path: /spec/template/spec/tolerations
      value:
      - key: "production"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"

commonLabels:
  app.kubernetes.io/name: hashfoundry-webapp
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: hashfoundry-platform
  app.kubernetes.io/managed-by: argocd
  environment: production
  tier: frontend

commonAnnotations:
  deployment.kubernetes.io/revision: "1"
  argocd.argoproj.io/tracking-id: hashfoundry-webapp-production
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"

---
# apps/overlays/production/webapp/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-webapp
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  template:
    metadata:
      annotations:
        # Force restart при изменении конфигурации
        config/hash: "production-v1.2.3"
        # Prometheus annotations
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      # Production security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      
      # Production affinity rules
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                - hashfoundry-webapp
            topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values:
                - production
      
      containers:
      - name: webapp
        env:
        - name: NODE_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "warn"
        - name: CLUSTER_NAME
          value: "hashfoundry-ha"
        - name: DEPLOYMENT_ENVIRONMENT
          value: "production"
        
        # Production health checks
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
          successThreshold: 1
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        
        startupProbe:
          httpGet:
            path: /health/startup
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
          successThreshold: 1
```

### **4. Sealed Secrets для безопасного хранения секретов:**
```yaml
# apps/overlays/production/webapp/sealed-secrets.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: hashfoundry-webapp-secrets
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    environment: production
spec:
  encryptedData:
    # Эти значения зашифрованы с помощью kubeseal
    database-url: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    api-key: AgAKbC2YvK8nKZZA9rO43cGDEQAxBy3i4OJ...
    jwt-secret: AgCx8nKZZA9rO43cGDEQAxBy3i4OJSWKbC2...
    redis-password: AgDEQAxBy3i4OJSWKbC2YvK8nKZZA9rO43c...
  template:
    metadata:
      name: hashfoundry-webapp-secrets
      namespace: hashfoundry-production
      labels:
        app.kubernetes.io/name: hashfoundry-webapp
        environment: production
    type: Opaque

---
# Скрипт для создания Sealed Secrets
# scripts/create-sealed-secret.sh
#!/bin/bash

set -e

NAMESPACE="hashfoundry-production"
SECRET_NAME="hashfoundry-webapp-secrets"

echo "🔐 Creating sealed secret for $SECRET_NAME in $NAMESPACE"

# Создание временного secret
kubectl create secret generic $SECRET_NAME \
  --namespace=$NAMESPACE \
  --from-literal=database-url="postgresql://webapp:$(openssl rand -base64 32)@postgres:5432/webapp" \
  --from-literal=api-key="$(openssl rand -base64 32)" \
  --from-literal=jwt-secret="$(openssl rand -base64 64)" \
  --from-literal=redis-password="$(openssl rand -base64 32)" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets -o yaml > \
  apps/overlays/production/webapp/sealed-secrets.yaml

echo "✅ Sealed secret created: apps/overlays/production/webapp/sealed-secrets.yaml"
echo "🔄 Commit and push to Git to deploy"
```

## 🔄 **GitOps Workflow Implementation:**

### **1. Полный CI/CD pipeline с GitOps:**
```yaml
# .github/workflows/gitops-pipeline.yml
name: GitOps CI/CD Pipeline

on:
  push:
    branches: [main, develop]
    paths:
    - 'apps/**'
    - 'infrastructure/**'
  pull_request:
    branches: [main]
    paths:
    - 'apps/**'
    - 'infrastructure/**'

env:
  ARGOCD_SERVER: argocd.hashfoundry.com
  ARGOCD_NAMESPACE: argocd

jobs:
  validate:
    name: Validate Manifests
    runs-on: ubuntu-latest
    steps:
    - name: Checkout GitOps repo
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'

    - name: Setup Kustomize
      uses: imranismail/setup-kustomize@v1

    - name: Validate Kubernetes manifests
      run: |
        echo "🔍 Validating Kubernetes manifests..."
        
        # Validate all overlays
        for env in development staging production; do
          echo "Validating $env environment..."
          
          if [ -d "apps/overlays/$env" ]; then
            for app in apps/overlays/$env/*/; do
              if [ -f "$app/kustomization.yaml" ]; then
                echo "Validating $app"
                kustomize build "$app" | kubectl apply --dry-run=client -f -
              fi
            done
          fi
        done

    - name: Validate ArgoCD Applications
      run: |
        echo "🔍 Validating ArgoCD Applications..."
        kubectl apply --dry-run=client -f apps/argocd-apps/

    - name: Security scan with Kubesec
      run: |
        echo "🔒 Running security scan..."
        docker run --rm -v $(pwd):/workspace \
          kubesec/kubesec:latest scan /workspace/apps/base/webapp/deployment.yaml

    - name: Policy validation with OPA Conftest
      run: |
        echo "📋 Running policy validation..."
        docker run --rm -v $(pwd):/workspace \
          openpolicyagent/conftest:latest verify \
          --policy /workspace/policies/ /workspace/apps/base/webapp/

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: validate
    if: github.ref == 'refs/heads/develop'
    environment:
      name: staging
      url: https://webapp-staging.hashfoundry.com
    steps:
    - name: Checkout GitOps repo
      uses: actions/checkout@v4

    - name: Setup ArgoCD CLI
      run: |
        curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x argocd
        sudo mv argocd /usr/local/bin/

    - name: Login to ArgoCD
      run: |
        argocd login $ARGOCD_SERVER \
          --username admin \
          --password ${{ secrets.ARGOCD_PASSWORD }} \
          --insecure

    - name: Sync staging applications
      run: |
        echo "🚀 Syncing staging applications..."
        
        # Sync all staging applications
        argocd app sync -l environment=staging --timeout 300
        
        # Wait for applications to be healthy
        argocd app wait -l environment=staging --health --timeout 600

    - name: Run staging tests
      run: |
        echo "🧪 Running staging tests..."
        
        # Health check
        curl -f https://webapp-staging.hashfoundry.com/health
        
        # API tests
        curl -f https://webapp-staging.hashfoundry.com/api/status

  promote-production:
    name: Promote to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://webapp.hashfoundry.com
    steps:
    - name: Checkout GitOps repo
      uses: actions/checkout@v4
      with:
        token: ${{ secrets.GITHUB_TOKEN }}

    - name: Setup ArgoCD CLI
      run: |
        curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x argocd
        sudo mv argocd /usr/local/bin/

    - name: Login to ArgoCD
      run: |
        argocd login $ARGOCD_SERVER \
          --username admin \
          --password ${{ secrets.ARGOCD_PASSWORD }} \
          --insecure

    - name: Get staging image version
      id: get-version
      run: |
        # Получить текущую версию из staging
        STAGING_IMAGE=$(kustomize build apps/overlays/staging/webapp | \
          yq eval 'select(.kind == "Deployment") | .spec.template.spec.containers[0].image' -)
        
        echo "staging-image=$STAGING_IMAGE" >> $GITHUB_OUTPUT
        echo "Staging image: $STAGING_IMAGE"

    - name: Update production manifests
      run: |
        echo "📝 Updating production manifests..."
        
        # Update production kustomization with staging image
        cd apps/overlays/production/webapp
        kustomize edit set image hashfoundry/webapp=${{ steps.get-version.outputs.staging-image }}
        
        # Commit changes
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        git add .
        git commit -m "Promote ${{ steps.get-version.outputs.staging-image }} to production"
        git push

    - name: Sync production applications
      run: |
        echo "🚀 Syncing production applications..."
        
        # Sync production applications
        argocd app sync -l environment=production --timeout 600
        
        # Wait for applications to be healthy
        argocd app wait -l environment=production --health --timeout 900

    - name: Verify production deployment
      run: |
        echo "✅ Verifying production deployment..."
        
        # Health check
        curl -f https://webapp.hashfoundry.com/health
        
        # API tests
        curl -f https://webapp.hashfoundry.com/api/status
        
        # Load test
        docker run --rm loadimpact/k6:latest run --vus 10 --duration 30s - <<EOF
        import http from 'k6/http';
        import { check } from 'k6';
        
        export default function() {
          let response = http.get('https://webapp.hashfoundry.com/health');
          check(response, {
            'status is 200': (r) => r.status === 200,
            'response time < 500ms': (r) => r.timings.duration < 500,
          });
        }
        EOF

  notify:
    name: Notify Deployment
    runs-on: ubuntu-latest
    needs: [promote-production]
    if: always()
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#gitops-deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        fields: repo,message,commit,author,action,eventName,ref,workflow
        custom_payload: |
          {
            "text": "GitOps Production Deployment",
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
                "title": "URL",
                "value": "https://webapp.hashfoundry.com",
                "short": true
              }]
            }]
          }
```

### **2. Automation scripts для GitOps:**
```bash
#!/bin/bash
# scripts/bootstrap-cluster.sh - Инициализация GitOps в кластере

set -e

CLUSTER_NAME=${1:-hashfoundry-ha}
GITOPS_REPO=${2:-https://github.com/hashfoundry/gitops-config}
ARGOCD_NAMESPACE=${3:-argocd}

echo "🚀 Bootstrapping GitOps for cluster: $CLUSTER_NAME"

# 1. Установка ArgoCD
echo "📦 Installing ArgoCD..."
kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Ожидание готовности ArgoCD
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE

# 3. Получение пароля admin
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"

# 4. Создание root application (App of Apps pattern)
echo "🌳 Creating root application..."
cat << EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: $ARGOCD_NAMESPACE
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: $GITOPS_REPO
    targetRevision: main
    path: clusters/$CLUSTER_NAME/bootstrap
  destination:
    server: https://kubernetes.default.svc
    namespace: $ARGOCD_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

echo "✅ GitOps bootstrap completed for cluster: $CLUSTER_NAME"
echo "🌐 Access ArgoCD UI: kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
echo "👤 Username: admin"
echo "🔑 Password: $ARGOCD_PASSWORD"

---
#!/bin/bash
# scripts/promote-app.sh - Продвижение приложения между окружениями

set -e

APP_NAME=${1}
SOURCE_ENV=${2:-staging}
TARGET_ENV=${3:-production}
GITOPS_REPO_PATH=${4:-.}

if [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <app-name> [source-env] [target-env] [gitops-repo-path]"
    echo "Example: $0 webapp staging production"
    exit 1
fi

echo "🚀 Promoting $APP_NAME from $SOURCE_ENV to $TARGET_ENV"

# 1. Получение текущего образа из source environment
SOURCE_KUSTOMIZATION="$GITOPS_REPO_PATH/apps/overlays/$SOURCE_ENV/$APP_NAME/kustomization.yaml"
TARGET_KUSTOMIZATION="$GITOPS_REPO_PATH/apps/overlays/$TARGET_ENV/$APP_NAME/kustomization.yaml"

if [ ! -f "$SOURCE_KUSTOMIZATION" ]; then
    echo "❌ Source kustomization not found: $SOURCE_KUSTOMIZATION"
    exit 1
fi

if [ ! -f "$TARGET_KUSTOMIZATION" ]; then
    echo "❌ Target kustomization not found: $TARGET_KUSTOMIZATION"
    exit 1
fi

# 2. Извлечение текущего образа
CURRENT_IMAGE=$(yq eval '.images[0].newTag' "$SOURCE_KUSTOMIZATION")
if [ "$CURRENT_IMAGE" = "null" ]; then
    echo "❌ Could not find image tag in $SOURCE_KUSTOMIZATION"
    exit 1
fi

echo "📦 Current image in $SOURCE_ENV: $CURRENT_IMAGE"

# 3. Обновление target environment
echo "📝 Updating $TARGET_ENV kustomization..."
yq eval ".images[0].newTag = \"$CURRENT_IMAGE\"" -i "$TARGET_KUSTOMIZATION"

# 4. Коммит изменений
echo "💾 Committing changes..."
git add "$TARGET_KUSTOMIZATION"
git commit -m "Promote $APP_NAME to $TARGET_ENV: $CURRENT_IMAGE

- Source: $SOURCE_ENV
- Target: $TARGET_ENV
- Image: $CURRENT_IMAGE
- Promoted at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

echo "✅ Promotion completed!"
echo "🔄 Push to Git to trigger deployment: git push"

---
#!/bin/bash
# scripts/sync-all-apps.sh - Синхронизация всех ArgoCD приложений

set -e

ENVIRONMENT=${1:-all}
ARGOCD_NAMESPACE=${2:-argocd}
TIMEOUT=${3:-300}

echo "🔄 Syncing ArgoCD applications for environment: $ENVIRONMENT"

# Функция для синхронизации приложений
sync_apps() {
    local env_filter=$1
    local apps
    
    if [ "$env_filter" = "all" ]; then
        apps=$(kubectl get applications -n $ARGOCD_NAMESPACE -o name)
    else
        apps=$(kubectl get applications -n $ARGOCD_NAMESPACE -l environment=$env_filter -o name)
    fi
    
    if [ -z "$apps" ]; then
        echo "❌ No applications found for environment: $env_filter"
        return 1
    fi
    
    echo "📋 Found applications:"
    echo "$apps" | sed 's|application.argoproj.io/||g'
    
    # Синхронизация каждого приложения
    for app in $apps; do
        app_name=$(echo $app | sed 's|application.argoproj.io/||g')
        echo "🔄 Syncing $app_name..."
        
        kubectl patch $app -n $ARGOCD_NAMESPACE --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
        
        # Ожидание синхронизации
        echo "⏳ Waiting for $app_name to sync..."
        kubectl wait --for=condition=Synced $app -n $ARGOCD_NAMESPACE --timeout=${TIMEOUT}s
        
        # Ожидание здоровья
        echo "🏥 Waiting for $app_name to be healthy..."
        kubectl wait --for=condition=Healthy $app -n $ARGOCD_NAMESPACE --timeout=${TIMEOUT}s
        
        echo "✅ $app_name synced and healthy"
    done
}

# Проверка доступности ArgoCD
if ! kubectl get deployment argocd-server -n $ARGOCD_NAMESPACE >/dev/null 2>&1; then
    echo "❌ ArgoCD not found in namespace: $ARGOCD_NAMESPACE"
    exit 1
fi

# Синхронизация приложений
sync_apps $ENVIRONMENT

echo "✅ All applications synced successfully!"

# Показать статус всех приложений
echo "📊 Application status:"
kubectl get applications -n $ARGOCD_NAMESPACE -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,AGE:.metadata.creationTimestamp
```

## 🔐 **Security и RBAC в GitOps:**

### **1. ArgoCD RBAC конфигурация:**
```yaml
# clusters/hashfoundry-ha/argocd/rbac-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  # Default policy
  policy.default: role:readonly
  
  # RBAC policies
  policy.csv: |
    # Platform team - full access
    p, role:platform-admin, applications, *, */*, allow
    p, role:platform-admin, clusters, *, *, allow
    p, role:platform-admin, repositories, *, *, allow
    p, role:platform-admin, projects, *, *, allow
    
    # DevOps team - production access
    p, role:devops, applications, *, hashfoundry-production/*, allow
    p, role:devops, applications, *, hashfoundry-staging/*, allow
    p, role:devops, applications, sync, */*, allow
    p, role:devops, repositories, get, *, allow
    
    # Developers - limited access
    p, role:developer, applications, get, hashfoundry-staging/*, allow
    p, role:developer, applications, sync, hashfoundry-staging/*, allow
    p, role:developer, applications, get, hashfoundry-development/*, allow
    p, role:developer, applications, *, hashfoundry-development/*, allow
    
    # Read-only access
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, repositories, get, *, allow
    p, role:readonly, projects, get, *, allow
    
    # Group mappings (для OIDC/LDAP)
    g, hashfoundry:platform-team, role:platform-admin
    g, hashfoundry:devops-team, role:devops
    g, hashfoundry:developers, role:developer
    g, hashfoundry:viewers, role:readonly
    
    # User mappings (для локальных пользователей)
    g, admin, role:platform-admin
    g, devops-user, role:devops
    g, developer-user, role:developer

---
# ArgoCD Server конфигурация с OIDC
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # OIDC конфигурация
  oidc.config: |
    name: HashFoundry SSO
    issuer: https://auth.hashfoundry.com
    clientId: argocd
    clientSecret: $oidc.hashfoundry.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims: {"groups": {"essential": true}}
  
  # URL конфигурация
  url: https://argocd.hashfoundry.com
  
  # Application in any namespace
  application.instanceLabelKey: argocd.argoproj.io/instance
```

### **2. Network Policies для ArgoCD:**
```yaml
# clusters/hashfoundry-ha/argocd/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-server-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Разрешить трафик от Ingress Controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8083
  # Разрешить трафик от ArgoCD CLI
  - from:
    - namespaceSelector:
        matchLabels:
          name: argocd
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Разрешить трафик к Git репозиториям
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 22
  # Разрешить трафик к Kubernetes API
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 443
  # DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-application-controller-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  policyTypes:
  - Egress
  egress:
  # Разрешить трафик к Git репозиториям
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 22
  # Разрешить трафик к Kubernetes API
  - to: []
    ports:
    - protocol: TCP
      port: 6443
    - protocol: TCP
      port: 443
  # DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
```

## 📊 **Monitoring и Observability для GitOps:**

### **1. Prometheus monitoring для ArgoCD:**
```yaml
# infrastructure/monitoring/argocd-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
  labels:
    app.kubernetes.io/name: argocd-metrics
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
      app.kubernetes.io/part-of: argocd
  namespaceSelector:
    matchNames:
    - argocd
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    honorLabels: true

---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: monitoring
  labels:
    app.kubernetes.io/name: argocd-server-metrics
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
      app.kubernetes.io/part-of: argocd
  namespaceSelector:
    matchNames:
    - argocd
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    honorLabels: true

---
# Prometheus Rules для ArgoCD
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/name: argocd
    release: prometheus
spec:
  groups:
  - name: argocd.rules
    rules:
    # Application sync status
    - alert: ArgoCDAppNotSynced
      expr: argocd_app_info{sync_status!="Synced"} == 1
      for: 15m
      labels:
        severity: warning
        component: argocd
      annotations:
        summary: "ArgoCD application {{ $labels.name }} is not synced"
        description: "ArgoCD application {{ $labels.name }} in project {{ $labels.project }} has been out of sync for more than 15 minutes."
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-sync-issues"
    
    # Application health status
    - alert: ArgoCDAppUnhealthy
      expr: argocd_app_info{health_status!="Healthy"} == 1
      for: 5m
      labels:
        severity: critical
        component: argocd
      annotations:
        summary: "ArgoCD application {{ $labels.name }} is unhealthy"
        description: "ArgoCD application {{ $labels.name }} in project {{ $labels.project }} has been unhealthy for more than 5 minutes. Current status: {{ $labels.health_status }}"
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-health-issues"
    
    # ArgoCD server availability
    - alert: ArgoCDServerDown
      expr: up{job="argocd-server-metrics"} == 0
      for: 2m
      labels:
        severity: critical
        component: argocd
      annotations:
        summary: "ArgoCD server is down"
        description: "ArgoCD server has been down for more than 2 minutes."
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-server-down"
    
    # Application controller availability
    - alert: ArgoCDControllerDown
      expr: up{job="argocd-application-controller-metrics"} == 0
      for: 2m
      labels:
        severity: critical
        component: argocd
      annotations:
        summary: "ArgoCD application controller is down"
        description: "ArgoCD application controller has been down for more than 2 minutes."
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-controller-down"
    
    # Sync operation failures
    - alert: ArgoCDSyncFailures
      expr: increase(argocd_app_sync_total{phase="Failed"}[5m]) > 0
      for: 1m
      labels:
        severity: warning
        component: argocd
      annotations:
        summary: "ArgoCD sync failures detected"
        description: "ArgoCD application {{ $labels.name }} has had {{ $value }} sync failures in the last 5 minutes."
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-sync-failures"
    
    # Repository connection issues
    - alert: ArgoCDRepoConnectionFailure
      expr: argocd_repo_connection_status == 0
      for: 5m
      labels:
        severity: warning
        component: argocd
      annotations:
        summary: "ArgoCD repository connection failure"
        description: "ArgoCD cannot connect to repository {{ $labels.repo }} for more than 5 minutes."
        runbook_url: "https://docs.hashfoundry.com/runbooks/argocd-repo-connection"
```

### **2. Grafana Dashboard для GitOps:**
```json
{
  "dashboard": {
    "id": null,
    "title": "HashFoundry GitOps Dashboard",
    "tags": ["gitops", "argocd", "hashfoundry"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Application Sync Status",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (sync_status) (argocd_app_info)",
            "legendFormat": "{{ sync_status }}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "Application Health Status",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (health_status) (argocd_app_info)",
            "legendFormat": "{{ health_status }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Sync Operations Over Time",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(argocd_app_sync_total[5m])",
            "legendFormat": "{{ name }} - {{ phase }}"
          }
        ]
      },
      {
        "id": 4,
        "title": "Applications by Environment",
        "type": "piechart",
        "targets": [
          {
            "expr": "count by (project) (argocd_app_info)",
            "legendFormat": "{{ project }}"
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

## 🎯 **Проверка GitOps в вашем кластере:**

### **1. Диагностика ArgoCD:**
```bash
# Полная диагностика ArgoCD в кластере
#!/bin/bash
# scripts/diagnose-gitops.sh

echo "🔍 GitOps Diagnostics for HashFoundry HA Cluster"

# 1. Проверка ArgoCD компонентов
echo "📦 Checking ArgoCD components..."
kubectl get pods -n argocd -o wide
kubectl get svc -n argocd
kubectl get ingress -n argocd

# 2. Проверка ArgoCD приложений
echo "📋 Checking ArgoCD applications..."
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,PROJECT:.spec.project,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL

# 3. Проверка ArgoCD проектов
echo "🏗️ Checking ArgoCD projects..."
kubectl get appprojects -n argocd

# 4. Проверка репозиториев
echo "📚 Checking repositories..."
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository -o custom-columns=NAME:.metadata.name,REPO:.data.url

# 5. Проверка RBAC
echo "🔐 Checking RBAC configuration..."
kubectl get configmap argocd-rbac-cm -n argocd -o yaml | grep -A 20 "policy.csv"

# 6. Проверка событий
echo "📰 Recent events..."
kubectl get events -n argocd --sort-by='.lastTimestamp' | tail -10

# 7. Проверка логов
echo "📝 Recent logs from application controller..."
kubectl logs deployment/argocd-application-controller -n argocd --tail=20

# 8. Проверка метрик
echo "📊 Checking metrics availability..."
kubectl get servicemonitor -n monitoring | grep argocd || echo "No ArgoCD ServiceMonitors found"

# 9. Проверка сетевых политик
echo "🌐 Checking network policies..."
kubectl get networkpolicies -n argocd || echo "No network policies found"

# 10. Проверка ресурсов
echo "💾 Resource usage..."
kubectl top pods -n argocd

echo "✅ GitOps diagnostics completed!"
```

### **2. Мониторинг GitOps в реальном времени:**
```bash
# Команды для мониторинга GitOps
# Мониторинг синхронизации приложений
watch kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# Мониторинг логов ArgoCD
kubectl logs -f deployment/argocd-application-controller -n argocd

# Проверка метрик ArgoCD
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082

# Мониторинг событий
kubectl get events -n argocd --watch

# Проверка статуса репозиториев
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sourceType}{"\t"}{.status.sync.revision}{"\n"}{end}'
```

## 🏗️ **Архитектура GitOps:**

```
┌─────────────────────────────────────────────────────────────┐
│                HashFoundry GitOps Architecture             │
├─────────────────────────────────────────────────────────────┤
│  Git Repository (Source of Truth)                          │
│  ├── apps/                                                 │
│  │   ├── base/ (Kustomize base)                            │
│  │   └── overlays/ (Environment-specific)                  │
│  ├── infrastructure/ (Platform components)                 │
│  ├── clusters/ (Cluster-specific configs)                  │
│  └── scripts/ (Automation)                                 │
│                                                             │
│  ArgoCD (GitOps Operator)                                  │
│  ├── Application Controller (Sync engine)                  │
│  ├── Server (API & UI)                                     │
│  ├── Repo Server (Git operations)                          │
│  └── Redis (Cache)                                         │
│                                                             │
│  Kubernetes Cluster (hashfoundry-ha)                       │
│  ├── Applications (Deployed workloads)                     │
│  ├── Infrastructure (Monitoring, Ingress, etc.)           │
│  ├── Security (RBAC, Network Policies)                     │
│  └── Observability (Metrics, Logs, Alerts)                │
│                                                             │
│  CI/CD Pipeline                                             │
│  ├── Build & Test (Application code)                       │
│  ├── Image Build & Push                                    │
│  ├── GitOps Repo Update                                    │
│  └── ArgoCD Sync Trigger                                   │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Заключение:**

**GitOps с Kubernetes** обеспечивает:

**Ключевые преимущества:**
1. **Декларативность** - всё как код в Git
2. **Версионирование** - полная история изменений
3. **Безопасность** - нет прямого доступа к кластеру
4. **Автоматизация** - автоматическая синхронизация
5. **Наблюдаемость** - мониторинг дрифта и состояния

**Практическое применение в HashFoundry HA кластере:**
- **ArgoCD** как GitOps оператор
- **Kustomize** для управления конфигурациями
- **Sealed Secrets** для безопасного хранения секретов
- **Monitoring** с Prometheus и Grafana
- **RBAC** для контроля доступа

GitOps превращает управление Kubernetes в надежный, безопасный и прозрачный процесс, где Git становится единственным источником истины для всей инфраструктуры и приложений.
