# 195. Какие существуют продвинутые паттерны развертывания Kubernetes?

## 🎯 Вопрос
Какие существуют продвинутые паттерны развертывания Kubernetes?

## 💡 Ответ

Продвинутые паттерны развертывания в Kubernetes позволяют реализовать сложные сценарии доставки приложений с минимальными рисками и максимальной надежностью. Эти паттерны особенно важны для production окружений, где требуется высокая доступность и безопасность обновлений.

### 🚀 Архитектура продвинутых паттернов развертывания

#### 1. **Схема Advanced Deployment Patterns**
```
┌─────────────────────────────────────────────────────────────┐
│            Advanced Kubernetes Deployment Patterns         │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Progressive Delivery                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Canary    │    │ Blue-Green  │    │   A/B       │ │ │
│  │  │ Deployment  │───▶│ Deployment  │───▶│  Testing    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Multi-Cluster Patterns                  │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Cross     │    │   Disaster  │    │   Global    │ │ │
│  │  │  Cluster    │───▶│  Recovery   │───▶│ Load        │ │ │
│  │  │ Deployment  │    │ Patterns    │    │ Balancing   │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              GitOps & Automation Patterns              │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   GitOps    │    │ Pipeline    │    │ Environment │ │ │
│  │  │ Workflows   │───▶│ as Code     │───▶│ Promotion   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Security & Compliance                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Policy    │    │   Secret    │    │ Compliance  │ │ │
│  │  │ Enforcement │───▶│ Management  │───▶│ Automation  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Классификация паттернов развертывания**
```yaml
# Advanced Deployment Patterns Classification
deployment_patterns:
  progressive_delivery:
    canary_deployment:
      description: "Gradual rollout to subset of users"
      use_cases:
        - "Risk mitigation"
        - "Performance testing"
        - "User feedback collection"
        - "Feature validation"
      
      implementation:
        traffic_splitting:
          - "Istio traffic management"
          - "NGINX ingress weights"
          - "Flagger automation"
          - "Argo Rollouts"
        
        metrics_monitoring:
          - "Success rate tracking"
          - "Latency monitoring"
          - "Error rate analysis"
          - "Business metrics"
    
    blue_green_deployment:
      description: "Switch between two identical environments"
      use_cases:
        - "Zero-downtime deployments"
        - "Quick rollbacks"
        - "Database migrations"
        - "Infrastructure updates"
      
      implementation:
        environment_management:
          - "Separate namespaces"
          - "Service switching"
          - "DNS updates"
          - "Load balancer reconfiguration"
    
    a_b_testing:
      description: "Compare different versions with user groups"
      use_cases:
        - "Feature experimentation"
        - "UI/UX testing"
        - "Performance comparison"
        - "Business optimization"
      
      implementation:
        user_segmentation:
          - "Header-based routing"
          - "Cookie-based routing"
          - "Geographic routing"
          - "Random distribution"

  multi_cluster_patterns:
    cross_cluster_deployment:
      description: "Deploy across multiple clusters"
      use_cases:
        - "High availability"
        - "Geographic distribution"
        - "Compliance requirements"
        - "Resource optimization"
      
      implementation:
        orchestration:
          - "ArgoCD ApplicationSets"
          - "Flux multi-cluster"
          - "Rancher Fleet"
          - "Admiral"
    
    disaster_recovery:
      description: "Automated failover and recovery"
      use_cases:
        - "Business continuity"
        - "Data protection"
        - "RTO/RPO compliance"
        - "Regulatory requirements"
      
      implementation:
        strategies:
          - "Active-passive clusters"
          - "Active-active clusters"
          - "Backup and restore"
          - "Data replication"
    
    global_load_balancing:
      description: "Intelligent traffic distribution"
      use_cases:
        - "Latency optimization"
        - "Load distribution"
        - "Failover automation"
        - "Cost optimization"
      
      implementation:
        technologies:
          - "Istio multi-cluster"
          - "Submariner"
          - "Cilium cluster mesh"
          - "External DNS"

  gitops_automation:
    declarative_deployments:
      description: "Git as single source of truth"
      use_cases:
        - "Audit trail"
        - "Rollback capability"
        - "Team collaboration"
        - "Compliance tracking"
      
      implementation:
        tools:
          - "ArgoCD"
          - "Flux"
          - "Jenkins X"
          - "Tekton"
    
    environment_promotion:
      description: "Automated promotion through environments"
      use_cases:
        - "Quality gates"
        - "Testing automation"
        - "Approval workflows"
        - "Release management"
      
      implementation:
        pipeline_stages:
          - "Development"
          - "Testing"
          - "Staging"
          - "Production"
    
    policy_as_code:
      description: "Automated policy enforcement"
      use_cases:
        - "Security compliance"
        - "Resource governance"
        - "Cost control"
        - "Operational standards"
      
      implementation:
        frameworks:
          - "Open Policy Agent"
          - "Gatekeeper"
          - "Kyverno"
          - "Falco"

  advanced_strategies:
    feature_flags:
      description: "Runtime feature control"
      use_cases:
        - "Gradual feature rollout"
        - "Emergency feature disable"
        - "User segmentation"
        - "Performance testing"
      
      implementation:
        platforms:
          - "LaunchDarkly"
          - "Split.io"
          - "Unleash"
          - "ConfigCat"
    
    chaos_engineering:
      description: "Controlled failure injection"
      use_cases:
        - "Resilience testing"
        - "Failure preparation"
        - "System validation"
        - "Team training"
      
      implementation:
        tools:
          - "Chaos Monkey"
          - "Litmus"
          - "Chaos Mesh"
          - "Gremlin"
    
    immutable_infrastructure:
      description: "Replace rather than modify"
      use_cases:
        - "Consistency guarantee"
        - "Security hardening"
        - "Simplified rollbacks"
        - "Audit compliance"
      
      implementation:
        practices:
          - "Container immutability"
          - "Infrastructure as Code"
          - "Automated provisioning"
          - "Version control"
```

### 📊 Примеры из нашего кластера

#### Проверка паттернов развертывания:
```bash
# Проверка ArgoCD applications
kubectl get applications -n argocd

# Проверка Istio traffic management
kubectl get virtualservices,destinationrules --all-namespaces

# Проверка deployment strategies
kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.strategy.type}{"\n"}{end}'

# Проверка rollout status
kubectl rollout status deployment/app-name -n namespace

# Проверка ingress configurations
kubectl get ingress --all-namespaces
```

### 🛠️ Реализация продвинутых паттернов

#### 1. **Canary Deployment с Istio**
```yaml
# canary-deployment-istio.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-app
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: canary-app-canary
      stableService: canary-app-stable
      trafficRouting:
        istio:
          virtualService:
            name: canary-app-vs
            routes:
            - primary
          destinationRule:
            name: canary-app-dr
            canarySubsetName: canary
            stableSubsetName: stable
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 20
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 5m}
      - setWeight: 100
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: canary-app
  selector:
    matchLabels:
      app: canary-app
  template:
    metadata:
      labels:
        app: canary-app
    spec:
      containers:
      - name: app
        image: myapp:v2.0
        ports:
        - containerPort: 8080

---
# Istio VirtualService
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary-app-vs
spec:
  hosts:
  - canary-app.example.com
  http:
  - name: primary
    match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: canary-app
        subset: canary
      weight: 100
  - route:
    - destination:
        host: canary-app
        subset: stable
      weight: 100
    - destination:
        host: canary-app
        subset: canary
      weight: 0

---
# Istio DestinationRule
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: canary-app-dr
spec:
  host: canary-app
  subsets:
  - name: stable
    labels:
      version: stable
  - name: canary
    labels:
      version: canary

---
# Analysis Template
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
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
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(
            istio_requests_total{
              destination_service_name="{{args.service-name}}",
              response_code!~"5.*"
            }[2m]
          )) / 
          sum(rate(
            istio_requests_total{
              destination_service_name="{{args.service-name}}"
            }[2m]
          ))
```

#### 2. **Blue-Green Deployment**
```yaml
# blue-green-deployment.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: blue-green-app
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: blue-green-app-active
      previewService: blue-green-app-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: health-check
        args:
        - name: service-name
          value: blue-green-app-preview
      postPromotionAnalysis:
        templates:
        - templateName: health-check
        args:
        - name: service-name
          value: blue-green-app-active
  selector:
    matchLabels:
      app: blue-green-app
  template:
    metadata:
      labels:
        app: blue-green-app
    spec:
      containers:
      - name: app
        image: myapp:v2.0
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5

---
# Active Service
apiVersion: v1
kind: Service
metadata:
  name: blue-green-app-active
spec:
  selector:
    app: blue-green-app
  ports:
  - port: 80
    targetPort: 8080

---
# Preview Service
apiVersion: v1
kind: Service
metadata:
  name: blue-green-app-preview
spec:
  selector:
    app: blue-green-app
  ports:
  - port: 80
    targetPort: 8080

---
# Ingress for production traffic
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blue-green-app-ingress
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blue-green-app-active
            port:
              number: 80

---
# Health Check Analysis
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: health-check
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
        address: http://prometheus.monitoring:9090
        query: |
          up{job="{{args.service-name}}"}
```

#### 3. **Multi-Cluster GitOps Deployment**
```yaml
# multi-cluster-applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-app
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  - list:
      elements:
      - cluster: us-east-1
        region: us-east-1
        replicas: "5"
      - cluster: eu-west-1
        region: eu-west-1
        replicas: "3"
      - cluster: ap-south-1
        region: ap-south-1
        replicas: "2"
  template:
    metadata:
      name: '{{cluster}}-myapp'
    spec:
      project: production
      source:
        repoURL: https://github.com/company/k8s-manifests
        targetRevision: HEAD
        path: apps/myapp
        helm:
          parameters:
          - name: image.tag
            value: "v1.2.3"
          - name: replicaCount
            value: "{{replicas}}"
          - name: region
            value: "{{region}}"
          - name: cluster
            value: "{{cluster}}"
      destination:
        server: '{{server}}'
        namespace: myapp
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
# Environment-specific values
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
data:
  us-east-1.yaml: |
    environment: production
    region: us-east-1
    timezone: America/New_York
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    
  eu-west-1.yaml: |
    environment: production
    region: eu-west-1
    timezone: Europe/London
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 300m
        memory: 256Mi
    
  ap-south-1.yaml: |
    environment: production
    region: ap-south-1
    timezone: Asia/Kolkata
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 128Mi
```

#### 4. **Feature Flag Integration**
```yaml
# feature-flag-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: feature-flag-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: feature-flag-app
  template:
    metadata:
      labels:
        app: feature-flag-app
    spec:
      containers:
      - name: app
        image: myapp:v2.0
        env:
        - name: FEATURE_FLAGS_URL
          value: "http://unleash.feature-flags:4242/api"
        - name: FEATURE_FLAGS_TOKEN
          valueFrom:
            secretKeyRef:
              name: feature-flags-secret
              key: token
        - name: ENVIRONMENT
          value: "production"
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: feature-config
          mountPath: /app/config
      volumes:
      - name: feature-config
        configMap:
          name: feature-flags-config

---
# Feature Flags Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags-config
data:
  features.yaml: |
    features:
      new_ui:
        enabled: true
        rollout_percentage: 25
        user_segments:
          - beta_users
          - premium_users
      
      advanced_analytics:
        enabled: false
        rollout_percentage: 0
        prerequisites:
          - new_ui
      
      payment_v2:
        enabled: true
        rollout_percentage: 100
        regions:
          - us-east-1
          - eu-west-1
        exclude_regions:
          - ap-south-1

---
# Unleash Feature Flag Server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unleash
  namespace: feature-flags
spec:
  replicas: 2
  selector:
    matchLabels:
      app: unleash
  template:
    metadata:
      labels:
        app: unleash
    spec:
      containers:
      - name: unleash
        image: unleashorg/unleash-server:4.22
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: unleash-db-secret
              key: url
        - name: DATABASE_SSL
          value: "false"
        ports:
        - containerPort: 4242
        livenessProbe:
          httpGet:
            path: /health
            port: 4242
        readinessProbe:
          httpGet:
            path: /health
            port: 4242

---
# Feature Flag Monitoring
apiVersion: v1
kind: Service
metadata:
  name: unleash
  namespace: feature-flags
  labels:
    app: unleash
spec:
  selector:
    app: unleash
  ports:
  - port: 4242
    targetPort: 4242
```

### 📈 Мониторинг и автоматизация паттернов

#### Скрипт для управления развертываниями:
```bash
#!/bin/bash
# advanced-deployment-manager.sh

echo "🚀 Advanced Deployment Pattern Manager"

# Canary deployment management
manage_canary() {
    local app_name=$1
    local action=$2
    
    case $action in
        "promote")
            echo "Promoting canary deployment for $app_name"
            kubectl argo rollouts promote $app_name
            ;;
        "abort")
            echo "Aborting canary deployment for $app_name"
            kubectl argo rollouts abort $app_name
            ;;
        "status")
            echo "Checking canary status for $app_name"
            kubectl argo rollouts get rollout $app_name
            ;;
        "restart")
            echo "Restarting canary deployment for $app_name"
            kubectl argo rollouts restart $app_name
            ;;
    esac
}

# Blue-green deployment management
manage_blue_green() {
    local app_name=$1
    local action=$2
    
    case $action in
        "promote")
            echo "Promoting blue-green deployment for $app_name"
            kubectl argo rollouts promote $app_name
            ;;
        "preview")
            echo "Getting preview URL for $app_name"
            kubectl get service ${app_name}-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
            ;;
        "status")
            echo "Checking blue-green status for $app_name"
            kubectl argo rollouts get rollout $app_name --watch
            ;;
    esac
}

# Multi-cluster deployment status
check_multi_cluster_status() {
    echo "=== Multi-Cluster Deployment Status ==="
    
    local app_name=$1
    
    # Get all clusters
    clusters=$(kubectl config get-contexts -o name | grep -v "^*")
    
    for cluster in $clusters; do
        echo "--- Cluster: $cluster ---"
        kubectl config use-context $cluster
        
        # Check application status
        if kubectl get deployment $app_name >/dev/null 2>&1; then
            replicas=$(kubectl get deployment $app_name -o jsonpath='{.status.replicas}')
            ready=$(kubectl get deployment $app_name -o jsonpath='{.status.readyReplicas}')
            echo "Deployment: $ready/$replicas ready"
            
            # Check service status
            if kubectl get service $app_name >/dev/null 2>&1; then
                echo "Service: Available"
            else
                echo "Service: Not found"
            fi
        else
            echo "Deployment: Not found"
        fi
        echo ""
    done
}

# Feature flag status
check_feature_flags() {
    echo "=== Feature Flag Status ==="
    
    # Get feature flags from Unleash API
    unleash_url="http://unleash.feature-flags:4242/api/admin/features"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s $unleash_url | jq -r '.features[] | "\(.name): \(.enabled) (\(.strategies[0].parameters.rollout // "100")%)"'
    else
        echo "curl not available, checking ConfigMap"
        kubectl get configmap feature-flags-config -o yaml | grep -A 20 "features.yaml"
    fi
}

# Deployment health check
health_check() {
    local app_name=$1
    
    echo "=== Health Check for $app_name ==="
    
    # Check deployment status
    echo "--- Deployment Status ---"
    kubectl get deployment $app_name -o wide
    
    # Check pod status
    echo ""
    echo "--- Pod Status ---"
    kubectl get pods -l app=$app_name -o wide
    
    # Check service status
    echo ""
    echo "--- Service Status ---"
    kubectl get service $app_name -o wide
    
    # Check ingress status
    echo ""
    echo "--- Ingress Status ---"
    kubectl get ingress -l app=$app_name -o wide
    
    # Check recent events
    echo ""
    echo "--- Recent Events ---"
    kubectl get events --field-selector involvedObject.name=$app_name --sort-by='.lastTimestamp' | tail -5
}

# Rollback deployment
rollback_deployment() {
    local app_name=$1
    local revision=${2:-""}
    
    echo "=== Rolling back $app_name ==="
    
    if [ -n "$revision" ]; then
        kubectl rollout undo deployment/$app_name --to-revision=$revision
    else
        kubectl rollout undo deployment/$app_name
    fi
    
    # Wait for rollback to complete
    kubectl rollout status deployment/$app_name --timeout=300s
    
    echo "Rollback completed for $app_name"
}

# Performance metrics
get_performance_metrics() {
    local app_name=$1
    
    echo "=== Performance Metrics for $app_name ==="
    
    # CPU and Memory usage
    echo "--- Resource Usage ---"
    kubectl top pods -l app=$app_name
    
    # Request rate (if Prometheus is available)
    echo ""
    echo "--- Request Rate (last 5 minutes) ---"
    if command -v curl >/dev/null 2>&1; then
        prometheus_url="http://prometheus.monitoring:9090"
        query="sum(rate(http_requests_total{job=\"$app_name\"}[5m]))"
        curl -s "$prometheus_url/api/v1/query?query=$query" | jq -r '.data.result[0].value[1] // "No data"'
    else
        echo "Prometheus not accessible"
    fi
}

# Main menu
show_menu() {
    echo "Advanced Deployment Pattern Manager"
    echo "1. Manage Canary Deployment"
    echo "2. Manage Blue-Green Deployment"
    echo "3. Check Multi-Cluster Status"
    echo "4. Check Feature Flags"
    echo "5. Health Check"
    echo "6. Rollback Deployment"
    echo "7. Performance Metrics"
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
                read -p "Action (promote/abort/status/restart): " action
                manage_canary $app_name $action
                ;;
            2)
                read -p "App name: " app_name
                read -p "Action (promote/preview/status): " action
                manage_blue_green $app_name $action
                ;;
            3)
                read -p "App name: " app_name
                check_multi_cluster_status $app_name
                ;;
            4)
                check_feature_flags
                ;;
            5)
                read -p "App name: " app_name
                health_check $app_name
                ;;
            6)
                read -p "App name: " app_name
                read -p "Revision (optional): " revision
                rollback_deployment $app_name $revision
                ;;
            7)
                read -p "App name: " app_name
                get_performance_metrics $app_name
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
            manage_canary $2 $3
            ;;
        "blue-green")
            manage_blue_green $2 $3
            ;;
        "multi-cluster")
            check_multi_cluster_status $2
            ;;
        "health")
            health_check $2
            ;;
        *)
            echo "Usage: $0 [canary|blue-green|multi-cluster|health] <app-name> [action]"
            ;;
    esac
else
    main
fi
```

### 🎯 Заключение

Продвинутые паттерны развертывания Kubernetes обеспечивают:

**Progressive Delivery:**
1. **Canary Deployments** - постепенное развертывание с мониторингом
2. **Blue-Green Deployments** - мгновенное переключение между версиями
3. **A/B Testing** - сравнение версий на реальных пользователях
4. **Feature Flags** - управление функциональностью во время выполнения

**Multi-Cluster Patterns:**
1. **Cross-Cluster Deployment** - развертывание в нескольких кластерах
2. **Disaster Recovery** - автоматическое восстановление после сбоев
3. **Global Load Balancing** - интеллектуальное распределение трафика
4. **Geographic Distribution** - размещение ближе к пользователям

**Automation & GitOps:**
1. **Declarative Deployments** - Git как источник истины
2. **Environment Promotion** - автоматическое продвижение через среды
3. **Policy as Code** - авт
