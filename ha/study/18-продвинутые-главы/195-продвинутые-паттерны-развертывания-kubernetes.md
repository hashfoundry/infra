# 195. Какие существуют продвинутые паттерны развертывания Kubernetes?

## 🎯 **Что такое продвинутые паттерны развертывания?**

**Продвинутые паттерны развертывания Kubernetes** — это стратегии доставки приложений, обеспечивающие минимальные риски, высокую доступность и безопасность обновлений в production окружениях. Эти паттерны критически важны для enterprise приложений.

## 🏗️ **Основные категории паттернов:**

### **1. Progressive Delivery**
- Canary Deployments (постепенное развертывание)
- Blue-Green Deployments (мгновенное переключение)
- A/B Testing (сравнение версий)
- Feature Flags (управление функциональностью)

### **2. Multi-Cluster Patterns**
- Cross-Cluster Deployment (развертывание в нескольких кластерах)
- Disaster Recovery (автоматическое восстановление)
- Global Load Balancing (интеллектуальное распределение)

### **3. GitOps & Automation**
- Declarative Deployments (Git как источник истины)
- Environment Promotion (автоматическое продвижение)
- Policy as Code (автоматизация политик)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка текущих deployment стратегий:**
```bash
# Проверка ArgoCD applications и их стратегий
kubectl get applications -n argocd -o wide

# Проверка deployment strategies
kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.strategy.type}{"\n"}{end}'

# Проверка rollout статуса ArgoCD
kubectl rollout status deployment/argocd-server -n argocd

# Проверка HA конфигурации Prometheus
kubectl get deployment prometheus-server -n monitoring -o yaml | grep -A 10 strategy
```

### **2. Анализ текущих паттернов в кластере:**
```bash
# ArgoCD как пример GitOps паттерна
kubectl describe application hashfoundry-react -n argocd

# Мониторинг как пример HA deployment
kubectl get pods -n monitoring -o wide

# Ingress как пример traffic management
kubectl get ingress --all-namespaces -o wide

# NFS как пример shared storage pattern
kubectl get pv | grep nfs
```

### **3. Настройка Canary Deployment с Argo Rollouts:**
```bash
# Установка Argo Rollouts в ваш кластер
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Проверка установки
kubectl get pods -n argo-rollouts

# Установка kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64
chmod +x kubectl-argo-rollouts-darwin-amd64
sudo mv kubectl-argo-rollouts-darwin-amd64 /usr/local/bin/kubectl-argo-rollouts
```

### **4. Мониторинг deployment паттернов:**
```bash
# Prometheus метрики для deployments
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Grafana dashboard для deployment tracking
kubectl port-forward svc/grafana -n monitoring 3000:80

# ArgoCD UI для GitOps мониторинга
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

### **5. Тестирование Blue-Green в development:**
```bash
# Создание test namespace
kubectl create namespace deployment-patterns-test

# Применение blue-green конфигурации
kubectl apply -f blue-green-test-manifests/ -n deployment-patterns-test

# Мониторинг переключения
kubectl get services -n deployment-patterns-test -w
```

## 🔄 **Canary Deployment с Argo Rollouts:**

### **1. Canary Rollout для React приложения:**
```yaml
# canary-hashfoundry-react.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: hashfoundry-react-canary
  namespace: hashfoundry-react
spec:
  replicas: 5
  strategy:
    canary:
      canaryService: hashfoundry-react-canary
      stableService: hashfoundry-react-stable
      trafficRouting:
        nginx:
          stableIngress: hashfoundry-react-ingress
          annotationPrefix: nginx.ingress.kubernetes.io
          additionalIngressAnnotations:
            canary-by-header: X-Canary
      steps:
      - setWeight: 20
      - pause: {duration: 2m}
      - setWeight: 40
      - pause: {duration: 2m}
      - setWeight: 60
      - pause: {duration: 5m}
      - setWeight: 80
      - pause: {duration: 2m}
      analysis:
        templates:
        - templateName: react-app-success-rate
        args:
        - name: service-name
          value: hashfoundry-react-canary
  selector:
    matchLabels:
      app: hashfoundry-react
  template:
    metadata:
      labels:
        app: hashfoundry-react
        version: canary
    spec:
      containers:
      - name: react-app
        image: hashfoundry/react-app:v2.0
        ports:
        - containerPort: 3000
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
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5

---
# Canary Service
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-react-canary
  namespace: hashfoundry-react
spec:
  selector:
    app: hashfoundry-react
    version: canary
  ports:
  - port: 80
    targetPort: 3000

---
# Stable Service
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-react-stable
  namespace: hashfoundry-react
spec:
  selector:
    app: hashfoundry-react
    version: stable
  ports:
  - port: 80
    targetPort: 3000

---
# Analysis Template
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: react-app-success-rate
  namespace: hashfoundry-react
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 2m
    count: 3
    successCondition: result[0] >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus-server.monitoring:80
        query: |
          sum(rate(
            nginx_ingress_controller_requests{
              service="{{args.service-name}}",
              status!~"5.*"
            }[2m]
          )) / 
          sum(rate(
            nginx_ingress_controller_requests{
              service="{{args.service-name}}"
            }[2m]
          ))
```

### **2. Управление Canary Deployment:**
```bash
# Запуск canary deployment
kubectl apply -f canary-hashfoundry-react.yaml

# Мониторинг прогресса
kubectl argo rollouts get rollout hashfoundry-react-canary -n hashfoundry-react --watch

# Продвижение canary
kubectl argo rollouts promote hashfoundry-react-canary -n hashfoundry-react

# Откат в случае проблем
kubectl argo rollouts abort hashfoundry-react-canary -n hashfoundry-react

# Перезапуск rollout
kubectl argo rollouts restart hashfoundry-react-canary -n hashfoundry-react
```

## 🔧 **Blue-Green Deployment для ArgoCD:**

### **1. Blue-Green конфигурация:**
```yaml
# blue-green-argocd.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: argocd-server-bg
  namespace: argocd
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: argocd-server-active
      previewService: argocd-server-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: argocd-health-check
        args:
        - name: service-name
          value: argocd-server-preview
      postPromotionAnalysis:
        templates:
        - templateName: argocd-health-check
        args:
        - name: service-name
          value: argocd-server-active
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-server
        version: blue-green
    spec:
      containers:
      - name: argocd-server
        image: quay.io/argoproj/argocd:v2.8.4
        command:
        - argocd-server
        - --staticassets
        - /shared/app
        - --repo-server
        - argocd-repo-server:443
        - --dex-server
        - http://argocd-dex-server:5556
        - --logformat
        - text
        - --loglevel
        - info
        - --redis
        - argocd-redis:6379
        ports:
        - containerPort: 8080
        - containerPort: 8083
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 10

---
# Active Service (production traffic)
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-active
  namespace: argocd
spec:
  selector:
    app.kubernetes.io/name: argocd-server
  ports:
  - name: server
    port: 80
    targetPort: 8080
  - name: grpc
    port: 443
    targetPort: 8080

---
# Preview Service (testing traffic)
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-preview
  namespace: argocd
spec:
  selector:
    app.kubernetes.io/name: argocd-server
  ports:
  - name: server
    port: 80
    targetPort: 8080
  - name: grpc
    port: 443
    targetPort: 8080

---
# Health Check Analysis
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: argocd-health-check
  namespace: argocd
spec:
  args:
  - name: service-name
  metrics:
  - name: health-check
    interval: 30s
    count: 5
    successCondition: result == "1"
    provider:
      prometheus:
        address: http://prometheus-server.monitoring:80
        query: |
          up{job="{{args.service-name}}"}
  - name: response-time
    interval: 30s
    count: 3
    successCondition: result[0] < 0.5
    provider:
      prometheus:
        address: http://prometheus-server.monitoring:80
        query: |
          histogram_quantile(0.95,
            rate(http_request_duration_seconds_bucket{
              job="{{args.service-name}}"
            }[2m])
          )
```

### **2. Управление Blue-Green Deployment:**
```bash
# Применение blue-green конфигурации
kubectl apply -f blue-green-argocd.yaml

# Проверка preview версии
kubectl port-forward svc/argocd-server-preview -n argocd 8081:80

# Продвижение в production
kubectl argo rollouts promote argocd-server-bg -n argocd

# Мониторинг статуса
kubectl argo rollouts get rollout argocd-server-bg -n argocd --watch
```

## 🏭 **Multi-Cluster GitOps с ApplicationSets:**

### **1. ApplicationSet для multi-cluster deployment:**
```yaml
# multi-cluster-monitoring.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-monitoring
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  - list:
      elements:
      - cluster: production-us-east
        region: us-east-1
        monitoring_retention: "30d"
        storage_size: "50Gi"
      - cluster: production-eu-west
        region: eu-west-1
        monitoring_retention: "15d"
        storage_size: "30Gi"
      - cluster: production-ap-south
        region: ap-south-1
        monitoring_retention: "7d"
        storage_size: "20Gi"
  template:
    metadata:
      name: '{{cluster}}-monitoring'
    spec:
      project: production
      source:
        repoURL: https://github.com/hashfoundry/k8s-manifests
        targetRevision: HEAD
        path: monitoring
        helm:
          parameters:
          - name: prometheus.retention
            value: "{{monitoring_retention}}"
          - name: prometheus.storage.size
            value: "{{storage_size}}"
          - name: grafana.region
            value: "{{region}}"
          - name: cluster.name
            value: "{{cluster}}"
      destination:
        server: '{{server}}'
        namespace: monitoring
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m

---
# Cluster-specific configurations
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: argocd
data:
  production-us-east.yaml: |
    prometheus:
      retention: "30d"
      storage:
        size: "50Gi"
        class: "do-block-storage"
      resources:
        requests:
          cpu: "500m"
          memory: "2Gi"
        limits:
          cpu: "2000m"
          memory: "4Gi"
    
    grafana:
      replicas: 2
      resources:
        requests:
          cpu: "100m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
  
  production-eu-west.yaml: |
    prometheus:
      retention: "15d"
      storage:
        size: "30Gi"
        class: "do-block-storage"
      resources:
        requests:
          cpu: "300m"
          memory: "1Gi"
        limits:
          cpu: "1000m"
          memory: "2Gi"
    
    grafana:
      replicas: 1
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "300m"
          memory: "256Mi"
```

### **2. Environment Promotion Pipeline:**
```yaml
# environment-promotion.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: environment-promotion
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: development
        cluster: dev-cluster
        branch: develop
        replicas: "1"
        resources: "minimal"
      - env: staging
        cluster: staging-cluster
        branch: staging
        replicas: "2"
        resources: "medium"
      - env: production
        cluster: production-cluster
        branch: main
        replicas: "3"
        resources: "high"
  template:
    metadata:
      name: 'hashfoundry-react-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/hashfoundry/react-app
        targetRevision: '{{branch}}'
        path: k8s/overlays/{{env}}
        kustomize:
          images:
          - hashfoundry/react-app:{{env}}-latest
      destination:
        server: '{{cluster}}'
        namespace: hashfoundry-react-{{env}}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
      syncWaves:
      - wave: 0
        resources:
        - group: ""
          kind: "Namespace"
        - group: ""
          kind: "ConfigMap"
        - group: ""
          kind: "Secret"
      - wave: 1
        resources:
        - group: "apps"
          kind: "Deployment"
        - group: ""
          kind: "Service"
      - wave: 2
        resources:
        - group: "networking.k8s.io"
          kind: "Ingress"
```

## 📈 **Мониторинг deployment паттернов:**

### **1. Prometheus метрики для deployments:**
```yaml
# deployment-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argo-rollouts-metrics
  namespace: argo-rollouts
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argo-rollouts-metrics
  endpoints:
  - port: metrics

---
# Custom metrics для canary deployments
apiVersion: v1
kind: ConfigMap
metadata:
  name: deployment-alerts
  namespace: monitoring
data:
  deployment-rules.yaml: |
    groups:
    - name: deployment.rules
      rules:
      - alert: CanaryDeploymentFailed
        expr: |
          increase(rollout_phase_duration_seconds{phase="Degraded"}[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Canary deployment failed"
          description: "Rollout {{ $labels.rollout }} in namespace {{ $labels.namespace }} has failed"
      
      - alert: BlueGreenPromotionStuck
        expr: |
          rollout_phase_duration_seconds{phase="Paused"} > 600
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Blue-Green promotion stuck"
          description: "Rollout {{ $labels.rollout }} has been paused for more than 10 minutes"
      
      - alert: DeploymentRollbackRequired
        expr: |
          increase(rollout_phase_duration_seconds{phase="Aborted"}[5m]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Deployment rollback required"
          description: "Rollout {{ $labels.rollout }} has been aborted and requires attention"
```

### **2. Grafana Dashboard для deployment tracking:**
```json
{
  "dashboard": {
    "title": "Advanced Deployment Patterns",
    "panels": [
      {
        "title": "Rollout Status",
        "type": "stat",
        "targets": [
          {
            "expr": "rollout_info",
            "legendFormat": "{{rollout}} - {{phase}}"
          }
        ]
      },
      {
        "title": "Canary Success Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(nginx_ingress_controller_requests{service=~\".*-canary\",status!~\"5.*\"}[5m]) / rate(nginx_ingress_controller_requests{service=~\".*-canary\"}[5m])",
            "legendFormat": "{{service}} success rate"
          }
        ]
      },
      {
        "title": "Blue-Green Traffic Split",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum by (service) (rate(nginx_ingress_controller_requests{service=~\".*-(active|preview)\"}[5m]))",
            "legendFormat": "{{service}}"
          }
        ]
      },
      {
        "title": "Deployment Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "rollout_phase_duration_seconds",
            "legendFormat": "{{rollout}} - {{phase}}"
          }
        ]
      }
    ]
  }
}
```

## 🚨 **Troubleshooting deployment паттернов:**

### **1. Диагностика проблем Canary:**
```bash
# Проверка статуса rollout
kubectl argo rollouts get rollout <rollout-name> -n <namespace>

# Проверка analysis runs
kubectl get analysisruns -n <namespace>

# Логи argo-rollouts controller
kubectl logs -n argo-rollouts deployment/argo-rollouts

# Проверка метрик Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Query: rollout_phase_duration_seconds{rollout="<rollout-name>"}

# Проверка ingress конфигурации
kubectl describe ingress <ingress-name> -n <namespace>
```

### **2. Диагностика Blue-Green проблем:**
```bash
# Проверка services
kubectl get services -n <namespace> -l app=<app-name>

# Проверка endpoints
kubectl get endpoints -n <namespace>

# Проверка pod readiness
kubectl get pods -n <namespace> -l app=<app-name> -o wide

# Тестирование preview service
kubectl port-forward svc/<app-name>-preview -n <namespace> 8080:80

# Проверка health checks
kubectl describe analysisrun <analysis-run-name> -n <namespace>
```

### **3. Диагностика Multi-Cluster проблем:**
```bash
# Проверка ApplicationSet
kubectl get applicationset -n argocd

# Проверка generated applications
kubectl get applications -n argocd -l argocd.argoproj.io/application-set-name=<appset-name>

# Проверка cluster connectivity
kubectl get clusters -n argocd

# Проверка sync статуса
kubectl describe application <app-name> -n argocd

# Логи ApplicationSet controller
kubectl logs -n argocd deployment/argocd-applicationset-controller
```

## 🎯 **Архитектура продвинутых паттернов:**

```
┌─────────────────────────────────────────────────────────────┐
│            Advanced Deployment Architecture                │
├─────────────────────────────────────────────────────────────┤
│  GitOps Layer                                              │
│  ├── ArgoCD ApplicationSets                                │
│  ├── Environment Promotion                                 │
│  ├── Multi-Cluster Sync                                    │
│  └── Policy Enforcement                                    │
├─────────────────────────────────────────────────────────────┤
│  Progressive Delivery Layer                                │
│  ├── Argo Rollouts                                         │
│  │   ├── Canary Deployments                               │
│  │   ├── Blue-Green Deployments                           │
│  │   └── Analysis Templates                               │
│  ├── Traffic Management                                    │
│  │   ├── NGINX Ingress                                    │
│  │   ├── Istio Service Mesh                              │
│  │   └── Load Balancers                                   │
│  └── Feature Management                                    │
│      ├── Feature Flags                                    │
│      ├── A/B Testing                                      │
│      └── User Segmentation                                │
├─────────────────────────────────────────────────────────────┤
│  Monitoring & Observability                               │
│  ├── Prometheus Metrics                                    │
│  │   ├── Deployment Success Rate                          │
│  │   ├── Rollout Duration                                 │
│  │   └── Traffic Distribution                             │
│  ├── Grafana Dashboards                                   │
│  │   ├── Deployment Status                                │
│  │   ├── Performance Metrics                              │
│  │   └── Error Tracking                                   │
│  └── Alerting                                             │
│      ├── Failed Deployments                               │
│      ├── Stuck Rollouts                                   │
│      └── Performance Degradation                          │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer                                      │
│  ├── Kubernetes Clusters                                   │
│  │   ├── Production Clusters                              │
│  │   ├── Staging Clusters                                 │
│  │   └── Development Clusters                             │
│  ├── Storage                                              │
│  │   ├── Persistent Volumes                               │
│  │   ├── NFS Shared Storage                               │
│  │   └── Backup Systems                                   │
│  └── Networking                                           │
│      ├── Load Balancers                                   │
│      ├── Ingress Controllers                              │
│      └── Service Mesh                                     │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Скрипт управления deployment паттернами:**

### **1. Advanced Deployment Manager:**
```bash
#!/bin/bash
# advanced-deployment-manager.sh

echo "🚀 Advanced Deployment Pattern Manager for HA Cluster"

# Canary deployment management
manage_canary() {
    local app_name=$1
    local action=$2
    local namespace=${3:-"default"}
    
    echo "=== Managing Canary Deployment: $app_name ==="
    
    case $action in
        "start")
            echo "Starting canary deployment for $app_name"
            kubectl argo rollouts restart $app_name -n $namespace
            kubectl argo rollouts get rollout $app_name -n $namespace
            ;;
        "promote")
            echo "Promoting canary deployment for $app_name"
            kubectl argo rollouts promote $app_name -n $namespace
            ;;
        "abort")
            echo "Aborting canary deployment for $app_name"
            kubectl argo rollouts abort $app_name -n $namespace
            ;;
        "status")
            echo "Checking canary status for $app_name"
            kubectl argo rollouts get rollout $app_name -n $namespace --watch
            ;;
        "metrics")
            echo "Getting canary metrics for $app_name"
            kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &
            sleep 2
            echo "Prometheus available at http://localhost:9090"
            echo "Query: rollout_phase_duration_seconds{rollout=\"$app_name\"}"
            ;;
    esac
}

# Blue-Green deployment management
manage_blue_green() {
    local app_name=$1
    local action=$2
    local namespace=${3:-"default"}
    
    echo "=== Managing Blue-Green Deployment: $app_name ==="
    
    case $action in
        "promote")
            echo "Promoting blue-green deployment for $app_name"
            kubectl argo rollouts promote $app_name -n $namespace
            ;;
        "preview")
            echo "Getting preview URL for $app_name"
            preview_port=$(kubectl get service ${app_name}-preview -n $namespace -o jsonpath='{.spec.ports[0].port}')
            kubectl port-forward svc/${app_name}-preview -n $namespace 8081:$preview_port &
            echo "Preview available at http://localhost:8081"
            ;;
        "status")
            echo "Checking blue-green status for $app_name"
            kubectl argo rollouts get rollout $app_name -n $namespace
            ;;
        "traffic")
            echo "Checking traffic distribution for $app_name"
            kubectl get services -n $namespace -l app=$app_name
            ;;
    esac
}

# Multi-cluster deployment status
check_multi_cluster_status() {
    local app_pattern=${1:-"*"}
    
    echo "=== Multi-Cluster Deployment Status ==="
    
    # Check ArgoCD applications
    echo "--- ArgoCD Applications ---"
    kubectl get applications -n argocd | grep $app_pattern
    
    echo ""
    echo "--- ApplicationSets ---"
    kubectl get applicationsets -n argocd
    
    echo ""
    echo "--- Cluster Status ---"
    kubectl get clusters -n argocd
    
    # Check sync status
    echo ""
    echo "--- Sync Status ---"
    for app in $(kubectl get applications -n argocd -o name | grep $app_pattern); do
        app_name=$(basename $app)
        sync_status=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.sync.status}')
        health_status=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.health.status}')
        echo "$app_name: Sync=$sync_status, Health=$health_status"
    done
}

# Environment promotion
promote_environment() {
    local app_name=$1
    local from_env=$2
    local to_env=$3
    
    echo "=== Promoting $app_name from $from_env to $to_env ==="
    
    # Get current image from source environment
    current_image=$(kubectl get deployment $app_name -n $app_name-$from_env -o jsonpath='{.spec.template.spec.containers[0].image}')
    echo "Current image in $from_env: $current_image"
    
    # Update target environment
    kubectl set image deployment/$app_name $app_name=$current_image -n $app_name-$to_env
    
    # Wait for rollout
    kubectl rollout status deployment/$app_name -n $app_name-$to_env --timeout=300s
    
    echo "Promotion completed successfully"
}

# Deployment health check
health_check() {
    local app_name=$1
    local namespace=${2:-"default"}
    
    echo "=== Health Check for $app_name ==="
    
    # Check deployment status
    echo "--- Deployment Status ---"
    kubectl get deployment $app_name -n $namespace -o wide
    
    # Check pod status
    echo ""
    echo "--- Pod Status ---"
    kubectl get pods -n $namespace -l app=$app_name -o wide
    
    # Check service status
    echo ""
    echo "--- Service Status ---"
    kubectl get service $app_name -n $namespace -o wide
    
    # Check rollout status
    echo ""
    echo "--- Rollout Status ---"
    if kubectl get rollout $app_name -n $namespace >/dev/null 2>&1; then
        kubectl argo rollouts get rollout $app_name -n $namespace
    else
        kubectl rollout status deployment/$app_name -n $namespace
    fi
    
    # Check recent events
    echo ""
    echo "--- Recent Events ---"
    kubectl get events --field-selector involvedObject.name=$app_name -n $namespace --sort-by='.lastTimestamp' | tail -5
}

# Performance metrics
get_performance_metrics() {
    local app_name=$1
    local namespace=${2:-"default"}
    
    echo "=== Performance Metrics for $app_name ==="
    
    # CPU and Memory usage
    echo "--- Resource Usage ---"
    kubectl top pods -n $namespace -l app=$app_name
    
    # Request rate (if Prometheus is available)
    echo ""
    echo "--- Request Rate (last 5 minutes) ---"
    kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &
    sleep 2
    echo "Prometheus available at http://localhost:9090"
    echo "Query: sum(rate(nginx_ingress_controller_requests{service=\"$app_name\"}[5m]))"
}

# Rollback deployment
rollback_deployment() {
    local app_name=$1
    local namespace=${2:-"default"}
    local revision=${3:-""}
    
    echo "=== Rolling back $app_name ==="
    
    # Check if it's a rollout or deployment
    if kubectl get rollout $app_name -n $namespace >/dev/null 2>&1; then
        echo "Aborting rollout and rolling back"
        kubectl argo rollouts abort $app_name -n $namespace
        kubectl argo rollouts undo $app_name -n $namespace
    else
        if [ -n "$revision" ]; then
            kubectl rollout undo deployment/$app_name --to-revision=$revision -n $namespace
        else
            kubectl rollout undo deployment/$app_name -n $namespace
        fi
        
        # Wait for rollback to complete
        kubectl rollout status deployment/$app_name -n $namespace --timeout=300s
    fi
    
    echo "Rollback completed for $app_name"
}

# Main menu
show_menu() {
    echo ""
    echo "🚀 Advanced Deployment Pattern Manager"
    echo "1. Manage Canary Deployment"
    echo "2. Manage Blue-Green Deployment"
    echo "3. Check Multi-Cluster Status"
    echo "4. Environment Promotion"
    echo "5. Health Check"
    echo "6. Performance Metrics"
    echo "7. Rollback Deployment"
    echo "8. Exit"
}

# Main execution
main() {
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1)
                read -p "App name: " app_name
                read -p "Action (start/promote/abort/status/metrics): " action
                read -p "Namespace [default]: " namespace
                namespace=${namespace:-"default"}
                manage_canary $app_name $action $namespace
                ;;
            2)
                read -p "App name: " app_name
                read -p "Action (promote/preview/status/traffic): " action
                read -p "Namespace [default]: " namespace
                namespace=${namespace:-"default"}
                manage_blue_green $app_name $action $namespace
                ;;
            3)
                read -p "App pattern [*]: " app_pattern
                app_pattern=${app_pattern:-"*"}
                check_multi_cluster_status $app_pattern
                ;;
            4)
                read -p "App name: " app_name
                read -p "From environment: " from_env
                read -p "To environment: " to_env
                promote_environment $app_name $from_env $to_env
                ;;
            5)
                read -p "App name: " app_name
                read -p "Namespace [default]: " namespace
                namespace=${namespace:-"default"}
                health_check $app_name $namespace
                ;;
            6)
                read -p "App name: " app_name
                read -p "Namespace [default]: " namespace
                namespace=${namespace:-"default"}
                get_performance_metrics $app_name $namespace
                ;;
            7)
                read -p "App name: " app_name
                read -p "Namespace [default]: " namespace
                read -p "Revision (optional): " revision
                namespace=${namespace:-"default"}
                rollback_deployment $app_name $namespace $revision
                ;;
            8)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Check if arguments provided
if [ $# -gt 0 ]; then
    case $1 in
        "canary")
            manage_canary $2 $3 $4
            ;;
        "blue-green")
            manage_blue_green $2 $3 $4
            ;;
        "multi-cluster")
            check_multi_cluster_status $2
            ;;
        "health")
            health_check $2 $3
            ;;
        "metrics")
            get_performance_metrics $2 $3
            ;;
        "rollback")
            rollback_deployment $2 $3 $4
            ;;
        *)
            echo "Usage: $0 [canary|blue-green|multi-cluster|health|metrics|rollback] <app-name> [action] [namespace]"
            ;;
    esac
else
    main
fi
```

## 🎯 **Best Practices для продвинутых паттернов:**

### **1. Canary Deployments:**
- Начинайте с малого процента трафика (5-10%)
- Используйте автоматические метрики для принятия решений
- Настройте автоматический rollback при проблемах
- Мониторьте business метрики, не только технические

### **2. Blue-Green Deployments:**
- Тестируйте preview environment перед переключением
- Используйте health checks для валидации
- Подготовьте план быстрого rollback
- Учитывайте состояние базы данных при переключении

### **3. Multi-Cluster Patterns:**
- Используйте GitOps для консистентности
- Настройте мониторинг всех кластеров
- Планируйте disaster recovery сценарии
- Автоматизируйте failover процессы

### **4. Мониторинг и Observability:**
- Настройте алерты для критических метрик
- Используйте distributed tracing
- Мониторьте user experience метрики
- Ведите audit log всех изменений

**Продвинутые паттерны развертывания — это основа надежной доставки приложений в production!**
