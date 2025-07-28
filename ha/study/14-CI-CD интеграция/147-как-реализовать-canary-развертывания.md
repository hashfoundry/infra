# 147. Как реализовать canary развертывания?

## 🎯 Вопрос
Как реализовать canary развертывания?

## 💡 Ответ

Canary развертывания позволяют постепенно переводить трафик на новую версию приложения, минимизируя риски и обеспечивая быстрый откат при проблемах.

### 🏗️ Основные принципы Canary развертывания

#### 1. **Постепенное увеличение трафика**
```
Стадии Canary развертывания:
┌─────────────┬─────────────┬─────────────┬─────────────┐
│   Stable    │   Canary    │   Canary    │   Canary    │
│    100%     │     5%      │     25%     │    100%     │
│             │   Stable    │   Stable    │             │
│             │     95%     │     75%     │      0%     │
└─────────────┴─────────────┴─────────────┴─────────────┘
```

#### 2. **Мониторинг и автоматический откат**
```yaml
# Пример конфигурации с метриками
canary:
  analysis:
    threshold: 5
    interval: 1m
    metrics:
    - name: success-rate
      threshold: 99
    - name: latency
      threshold: 500ms
```

### 🛠️ Реализация с Kubernetes

#### 1. **Ручное Canary с двумя Deployment**
```yaml
# stable-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
  labels:
    app: myapp
    version: stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
      version: stable
  template:
    metadata:
      labels:
        app: myapp
        version: stable
    spec:
      containers:
      - name: myapp
        image: myapp:v1.0.0
        ports:
        - containerPort: 8080
---
# canary-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
  labels:
    app: myapp
    version: canary
spec:
  replicas: 1  # 10% трафика (1 из 10 подов)
  selector:
    matchLabels:
      app: myapp
      version: canary
  template:
    metadata:
      labels:
        app: myapp
        version: canary
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0.0
        ports:
        - containerPort: 8080
```

```yaml
# service.yaml - общий сервис для обеих версий
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp  # Выбирает поды обеих версий
  ports:
  - port: 80
    targetPort: 8080
```

#### 2. **Скрипт для управления Canary**
```bash
#!/bin/bash
# canary-deploy.sh

APP_NAME="myapp"
NAMESPACE="production"
NEW_VERSION="$1"
CANARY_PERCENTAGE="$2"

if [ -z "$NEW_VERSION" ] || [ -z "$CANARY_PERCENTAGE" ]; then
    echo "Usage: $0 <new-version> <canary-percentage>"
    exit 1
fi

echo "🚀 Запуск Canary развертывания $NEW_VERSION с $CANARY_PERCENTAGE% трафика"

# Вычисление количества реплик
TOTAL_REPLICAS=10
CANARY_REPLICAS=$((TOTAL_REPLICAS * CANARY_PERCENTAGE / 100))
STABLE_REPLICAS=$((TOTAL_REPLICAS - CANARY_REPLICAS))

echo "Stable replicas: $STABLE_REPLICAS, Canary replicas: $CANARY_REPLICAS"

# Обновление Canary deployment
kubectl set image deployment/$APP_NAME-canary \
  $APP_NAME=myregistry/$APP_NAME:$NEW_VERSION \
  -n $NAMESPACE

kubectl scale deployment/$APP_NAME-canary \
  --replicas=$CANARY_REPLICAS \
  -n $NAMESPACE

kubectl scale deployment/$APP_NAME-stable \
  --replicas=$STABLE_REPLICAS \
  -n $NAMESPACE

# Ожидание готовности
kubectl rollout status deployment/$APP_NAME-canary -n $NAMESPACE
kubectl rollout status deployment/$APP_NAME-stable -n $NAMESPACE

echo "✅ Canary развертывание завершено"
```

### 📊 Примеры из нашего кластера

#### Проверка текущих развертываний:
```bash
kubectl get deployments -n production -l app=myapp
```

#### Мониторинг распределения трафика:
```bash
kubectl get pods -n production -l app=myapp --show-labels
```

#### Проверка метрик через Prometheus:
```bash
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Затем открыть http://localhost:9090
```

### 🎯 Автоматизированное Canary с Argo Rollouts

#### 1. **Установка Argo Rollouts**
```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

#### 2. **Rollout конфигурация**
```yaml
# rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp-rollout
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 1m}
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 40
      - pause: {duration: 1m}
      - setWeight: 60
      - pause: {duration: 1m}
      - setWeight: 80
      - pause: {duration: 1m}
      canaryService: myapp-canary-service
      stableService: myapp-stable-service
      trafficRouting:
        nginx:
          stableIngress: myapp-stable-ingress
          annotationPrefix: nginx.ingress.kubernetes.io
          additionalIngressAnnotations:
            canary-by-header: X-Canary
      analysis:
        templates:
        - templateName: success-rate
        startingStep: 2
        args:
        - name: service-name
          value: myapp-canary-service
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
        image: myapp:v1.0.0
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
```

#### 3. **AnalysisTemplate для автоматической оценки**
```yaml
# analysis-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 1m
    count: 5
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local
        query: |
          sum(rate(
            http_requests_total{job="{{args.service-name}}",status!~"5.."}[1m]
          )) / 
          sum(rate(
            http_requests_total{job="{{args.service-name}}"}[1m]
          ))
  - name: avg-response-time
    interval: 1m
    count: 5
    successCondition: result[0] <= 0.5
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{job="{{args.service-name}}"}[1m])) by (le)
          )
```

### 🌐 Canary с Ingress Controller

#### 1. **NGINX Ingress Canary**
```yaml
# stable-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-stable
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-stable-service
            port:
              number: 80
---
# canary-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-canary-service
            port:
              number: 80
```

#### 2. **Istio Service Mesh Canary**
```yaml
# virtual-service.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp.example.com
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: myapp-service
        subset: canary
  - route:
    - destination:
        host: myapp-service
        subset: stable
      weight: 90
    - destination:
        host: myapp-service
        subset: canary
      weight: 10
---
# destination-rule.yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: myapp
spec:
  host: myapp-service
  subsets:
  - name: stable
    labels:
      version: stable
  - name: canary
    labels:
      version: canary
```

### 🎪 CI/CD интеграция Canary

#### 1. **GitHub Actions с Argo Rollouts**
```yaml
# .github/workflows/canary-deploy.yml
name: Canary Deployment

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v1
    
    - name: Install Argo Rollouts CLI
      run: |
        curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
        chmod +x kubectl-argo-rollouts-linux-amd64
        sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
    
    - name: Build and push image
      run: |
        docker build -t myapp:${{ github.sha }} .
        docker push myregistry/myapp:${{ github.sha }}
    
    - name: Update rollout image
      run: |
        kubectl argo rollouts set image myapp-rollout \
          myapp=myregistry/myapp:${{ github.sha }} \
          -n production
    
    - name: Wait for rollout
      run: |
        kubectl argo rollouts get rollout myapp-rollout -n production --watch
    
    - name: Promote if successful
      run: |
        kubectl argo rollouts promote myapp-rollout -n production
```

#### 2. **Jenkins Pipeline с автоматическим откатом**
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        APP_NAME = 'myapp'
        NAMESPACE = 'production'
        REGISTRY = 'myregistry'
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
        
        stage('Deploy Canary') {
            steps {
                sh '''
                    kubectl argo rollouts set image ${APP_NAME}-rollout \
                      ${APP_NAME}=${REGISTRY}/${APP_NAME}:${BUILD_NUMBER} \
                      -n ${NAMESPACE}
                '''
            }
        }
        
        stage('Monitor Canary') {
            steps {
                script {
                    timeout(time: 10, unit: 'MINUTES') {
                        sh '''
                            kubectl argo rollouts get rollout ${APP_NAME}-rollout \
                              -n ${NAMESPACE} --watch
                        '''
                    }
                }
            }
        }
        
        stage('Promote or Abort') {
            steps {
                script {
                    def rolloutStatus = sh(
                        script: "kubectl argo rollouts status ${APP_NAME}-rollout -n ${NAMESPACE}",
                        returnStatus: true
                    )
                    
                    if (rolloutStatus == 0) {
                        echo "✅ Canary успешен, продвижение..."
                        sh "kubectl argo rollouts promote ${APP_NAME}-rollout -n ${NAMESPACE}"
                    } else {
                        echo "❌ Canary неуспешен, откат..."
                        sh "kubectl argo rollouts abort ${APP_NAME}-rollout -n ${NAMESPACE}"
                        error("Canary deployment failed")
                    }
                }
            }
        }
    }
    
    post {
        failure {
            sh '''
                kubectl argo rollouts abort ${APP_NAME}-rollout -n ${NAMESPACE}
                kubectl argo rollouts undo ${APP_NAME}-rollout -n ${NAMESPACE}
            '''
        }
    }
}
```

### 📈 Мониторинг Canary развертываний

#### 1. **Grafana Dashboard для Canary**
```json
{
  "dashboard": {
    "title": "Canary Deployment Monitoring",
    "panels": [
      {
        "title": "Success Rate by Version",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"myapp\",status!~\"5..\"}[5m])) by (version) / sum(rate(http_requests_total{job=\"myapp\"}[5m])) by (version) * 100"
          }
        ]
      },
      {
        "title": "Response Time by Version",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"myapp\"}[5m])) by (le, version))"
          }
        ]
      },
      {
        "title": "Traffic Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"myapp\"}[5m])) by (version)"
          }
        ]
      }
    ]
  }
}
```

#### 2. **Алерты для Canary**
```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: canary-alerts
spec:
  groups:
  - name: canary
    rules:
    - alert: CanaryHighErrorRate
      expr: |
        (
          sum(rate(http_requests_total{job="myapp",version="canary",status=~"5.."}[5m])) /
          sum(rate(http_requests_total{job="myapp",version="canary"}[5m]))
        ) > 0.05
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Canary version has high error rate"
        description: "Canary version error rate is {{ $value | humanizePercentage }}"
    
    - alert: CanaryHighLatency
      expr: |
        histogram_quantile(0.95,
          sum(rate(http_request_duration_seconds_bucket{job="myapp",version="canary"}[5m])) by (le)
        ) > 0.5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Canary version has high latency"
        description: "Canary 95th percentile latency is {{ $value }}s"
```

### 🔄 Автоматический откат

#### 1. **Скрипт мониторинга и отката**
```bash
#!/bin/bash
# canary-monitor.sh

APP_NAME="myapp"
NAMESPACE="production"
PROMETHEUS_URL="http://prometheus-server.monitoring.svc.cluster.local"

echo "🔍 Мониторинг Canary развертывания..."

while true; do
    # Проверка error rate
    ERROR_RATE=$(curl -s "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode "query=sum(rate(http_requests_total{job=\"${APP_NAME}\",version=\"canary\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{job=\"${APP_NAME}\",version=\"canary\"}[5m]))" \
        | jq -r '.data.result[0].value[1] // "0"')
    
    # Проверка latency
    LATENCY=$(curl -s "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode "query=histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"${APP_NAME}\",version=\"canary\"}[5m])) by (le))" \
        | jq -r '.data.result[0].value[1] // "0"')
    
    echo "Error rate: ${ERROR_RATE}, Latency: ${LATENCY}s"
    
    # Проверка пороговых значений
    if (( $(echo "$ERROR_RATE > 0.05" | bc -l) )); then
        echo "❌ Высокий error rate, откат Canary..."
        kubectl argo rollouts abort ${APP_NAME}-rollout -n ${NAMESPACE}
        exit 1
    fi
    
    if (( $(echo "$LATENCY > 0.5" | bc -l) )); then
        echo "❌ Высокая задержка, откат Canary..."
        kubectl argo rollouts abort ${APP_NAME}-rollout -n ${NAMESPACE}
        exit 1
    fi
    
    sleep 30
done
```

### 📋 Лучшие практики Canary развертываний

- ✅ **Начинайте с малого процента** (5-10%)
- ✅ **Мониторьте ключевые метрики** (error rate, latency, throughput)
- ✅ **Автоматизируйте откат** при превышении пороговых значений
- ✅ **Используйте feature flags** для дополнительного контроля
- ✅ **Тестируйте в staging** перед production
- ✅ **Документируйте процесс** отката
- ✅ **Уведомляйте команду** о статусе развертывания
- ✅ **Сохраняйте логи** для анализа

Canary развертывания обеспечивают безопасный способ выкатки новых версий с минимальным риском для пользователей и возможностью быстрого отката при проблемах.
