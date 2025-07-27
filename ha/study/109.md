# 109. Экосистема и инструменты Kubernetes

## 🎯 **Экосистема и инструменты Kubernetes**

**Kubernetes ecosystem** включает множество инструментов и проектов, которые расширяют функциональность базовой платформы и упрощают управление кластерами.

## 🛠️ **Основные категории инструментов:**

### **1. Package Management:**
- **Helm** - пакетный менеджер для Kubernetes
- **Kustomize** - декларативное управление конфигурациями
- **Operator Framework** - автоматизация операций

### **2. CI/CD Tools:**
- **ArgoCD** - GitOps continuous delivery
- **Tekton** - cloud-native CI/CD
- **Jenkins X** - CI/CD для Kubernetes

### **3. Monitoring & Observability:**
- **Prometheus** - мониторинг и алертинг
- **Grafana** - визуализация метрик
- **Jaeger** - distributed tracing

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать ecosystem tools overview
cat << 'EOF' > kubernetes-ecosystem-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Ecosystem Tools Overview ==="
echo "Comprehensive guide to HashFoundry HA cluster ecosystem"
echo

# Функция для проверки установленных инструментов
check_installed_tools() {
    echo "=== Installed Tools Check ==="
    
    echo "1. Helm Charts:"
    helm list --all-namespaces
    echo
    
    echo "2. ArgoCD Applications:"
    kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not found"
    echo
    
    echo "3. Monitoring Stack:"
    kubectl get pods -n monitoring 2>/dev/null || echo "Monitoring namespace not found"
    echo
    
    echo "4. Ingress Controllers:"
    kubectl get pods -n ingress-nginx 2>/dev/null || echo "Nginx Ingress not found"
    echo
    
    echo "5. Storage Provisioners:"
    kubectl get storageclass
    echo
}

# Функция для демонстрации Helm
demo_helm() {
    echo "=== Helm Package Manager Demo ==="
    
    echo "1. Available Helm Repositories:"
    helm repo list
    echo
    
    echo "2. Search for popular charts:"
    helm search repo nginx | head -5
    echo
    
    echo "3. Create sample Helm chart:"
    cat << HELM_CHART_EOF > sample-chart-values.yaml
# Sample Helm Chart Values for HashFoundry App
replicaCount: 3

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
    - host: hashfoundry-demo.local
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}
HELM_CHART_EOF
    
    echo "✅ Sample Helm values created: sample-chart-values.yaml"
    echo
    
    echo "4. Helm template example:"
    echo "helm template my-app stable/nginx-ingress -f sample-chart-values.yaml"
    echo
}

# Функция для демонстрации ArgoCD
demo_argocd() {
    echo "=== ArgoCD GitOps Demo ==="
    
    echo "1. ArgoCD Server Status:"
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
    echo
    
    echo "2. Create ArgoCD Application:"
    cat << ARGOCD_APP_EOF > argocd-sample-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hashfoundry-sample-app
  namespace: argocd
  labels:
    app: hashfoundry-sample
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/sample-app
    targetRevision: HEAD
    path: k8s
    helm:
      valueFiles:
      - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
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
ARGOCD_APP_EOF
    
    echo "✅ ArgoCD application template created: argocd-sample-app.yaml"
    echo
    
    echo "3. ArgoCD CLI commands:"
    echo "argocd app list"
    echo "argocd app sync hashfoundry-sample-app"
    echo "argocd app get hashfoundry-sample-app"
    echo
}

# Функция для демонстрации мониторинга
demo_monitoring() {
    echo "=== Monitoring Stack Demo ==="
    
    echo "1. Prometheus Targets:"
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
    PF_PID=$!
    sleep 3
    echo "Prometheus available at: http://localhost:9090"
    kill $PF_PID 2>/dev/null
    echo
    
    echo "2. Grafana Dashboards:"
    kubectl port-forward -n monitoring svc/grafana 3000:3000 &
    PF_PID=$!
    sleep 3
    echo "Grafana available at: http://localhost:3000"
    kill $PF_PID 2>/dev/null
    echo
    
    echo "3. Sample Prometheus Query:"
    cat << PROM_QUERIES_EOF > sample-prometheus-queries.txt
# CPU Usage by Pod
rate(container_cpu_usage_seconds_total[5m])

# Memory Usage by Pod
container_memory_usage_bytes

# Pod Restart Count
kube_pod_container_status_restarts_total

# Node CPU Usage
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Disk Usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# Network Traffic
rate(node_network_receive_bytes_total[5m])
PROM_QUERIES_EOF
    
    echo "✅ Sample Prometheus queries created: sample-prometheus-queries.txt"
    echo
}

# Функция для демонстрации операторов
demo_operators() {
    echo "=== Kubernetes Operators Demo ==="
    
    echo "1. Installed Operators:"
    kubectl get crd | grep -E "(operators|\.io)" | head -10
    echo
    
    echo "2. Sample Custom Resource:"
    cat << CUSTOM_RESOURCE_EOF > sample-custom-resource.yaml
apiVersion: apps.hashfoundry.io/v1
kind: HashFoundryApp
metadata:
  name: sample-app
  namespace: default
spec:
  replicas: 3
  image: hashfoundry/app:v1.0.0
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"
  monitoring:
    enabled: true
    scrapeInterval: 30s
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: "7d"
CUSTOM_RESOURCE_EOF
    
    echo "✅ Sample custom resource created: sample-custom-resource.yaml"
    echo
}

# Функция для демонстрации сетевых инструментов
demo_networking() {
    echo "=== Networking Tools Demo ==="
    
    echo "1. Service Mesh (Istio) Check:"
    kubectl get pods -n istio-system 2>/dev/null || echo "Istio not installed"
    echo
    
    echo "2. Network Policies:"
    kubectl get networkpolicies --all-namespaces
    echo
    
    echo "3. Ingress Controllers:"
    kubectl get ingressclass
    echo
    
    echo "4. Sample Service Mesh Configuration:"
    cat << ISTIO_CONFIG_EOF > sample-istio-config.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: hashfoundry-app
  namespace: default
spec:
  hosts:
  - hashfoundry-app.local
  http:
  - match:
    - uri:
        prefix: /api/v1
    route:
    - destination:
        host: hashfoundry-app-v1
        port:
          number: 8080
      weight: 90
    - destination:
        host: hashfoundry-app-v2
        port:
          number: 8080
      weight: 10
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: hashfoundry-app
  namespace: default
spec:
  host: hashfoundry-app
  trafficPolicy:
    circuitBreaker:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
ISTIO_CONFIG_EOF
    
    echo "✅ Sample Istio configuration created: sample-istio-config.yaml"
    echo
}

# Функция для создания development workflow
create_dev_workflow() {
    echo "=== Development Workflow Demo ==="
    
    cat << DEV_WORKFLOW_EOF > development-workflow.sh
#!/bin/bash

echo "=== HashFoundry Development Workflow ==="

# Function for local development
local_dev() {
    echo "1. Local Development with Skaffold:"
    cat << SKAFFOLD_EOF > skaffold.yaml
apiVersion: skaffold/v2beta21
kind: Config
metadata:
  name: hashfoundry-app
build:
  artifacts:
  - image: hashfoundry/app
    docker:
      dockerfile: Dockerfile
deploy:
  helm:
    releases:
    - name: hashfoundry-app
      chartPath: ./helm-chart
      valuesFiles:
      - ./helm-chart/values-dev.yaml
portForward:
- resourceType: service
  resourceName: hashfoundry-app
  port: 8080
  localPort: 8080
SKAFFOLD_EOF
    
    echo "Commands:"
    echo "skaffold dev --port-forward"
    echo "skaffold run --tail"
}

# Function for testing
testing() {
    echo "2. Testing with Kubernetes:"
    echo "kubectl run test-pod --image=busybox --rm -it --restart=Never -- /bin/sh"
    echo "kubectl create job test-job --image=hashfoundry/test-runner"
}

# Function for deployment
deployment() {
    echo "3. Deployment Pipeline:"
    echo "helm upgrade --install hashfoundry-app ./helm-chart -f values-prod.yaml"
    echo "kubectl rollout status deployment/hashfoundry-app"
    echo "kubectl rollout history deployment/hashfoundry-app"
}

case "\$1" in
    "local")
        local_dev
        ;;
    "test")
        testing
        ;;
    "deploy")
        deployment
        ;;
    "all"|"")
        local_dev
        testing
        deployment
        ;;
esac

DEV_WORKFLOW_EOF
    
    chmod +x development-workflow.sh
    echo "✅ Development workflow created: development-workflow.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "check")
            check_installed_tools
            ;;
        "helm")
            demo_helm
            ;;
        "argocd")
            demo_argocd
            ;;
        "monitoring")
            demo_monitoring
            ;;
        "operators")
            demo_operators
            ;;
        "networking")
            demo_networking
            ;;
        "workflow")
            create_dev_workflow
            ;;
        "all"|"")
            check_installed_tools
            demo_helm
            demo_argocd
            demo_monitoring
            demo_operators
            demo_networking
            create_dev_workflow
            ;;
        *)
            echo "Usage: $0 [check|helm|argocd|monitoring|operators|networking|workflow|all]"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubernetes-ecosystem-toolkit.sh
./kubernetes-ecosystem-toolkit.sh all
```

## 🎯 **Популярные инструменты экосистемы:**

### **Package Management:**
```bash
# Helm - пакетный менеджер
helm repo add stable https://charts.helm.sh/stable
helm search repo nginx
helm install my-nginx stable/nginx-ingress

# Kustomize - управление конфигурациями
kubectl apply -k ./overlays/production
```

### **GitOps:**
```bash
# ArgoCD - continuous delivery
kubectl get applications -n argocd
argocd app sync my-app
argocd app get my-app --show-params
```

### **Мониторинг:**
```bash
# Prometheus queries
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Grafana dashboards
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

**Богатая экосистема Kubernetes предоставляет инструменты для любых задач!**
