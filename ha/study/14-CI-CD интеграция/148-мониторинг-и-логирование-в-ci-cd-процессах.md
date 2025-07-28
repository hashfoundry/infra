# 148. Как настроить мониторинг и логирование в CI/CD процессах?

## 🎯 Вопрос
Как настроить мониторинг и логирование в CI/CD процессах?

## 💡 Ответ

Мониторинг и логирование CI/CD процессов обеспечивают видимость, быструю диагностику проблем и непрерывное улучшение процессов доставки.

### 🏗️ Архитектура мониторинга CI/CD

#### 1. **Компоненты системы мониторинга**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CI/CD Tools   │───▶│   Metrics       │───▶│   Dashboards    │
│   (Jenkins,     │    │   Collection    │    │   (Grafana)     │
│    GitHub       │    │   (Prometheus)  │    │                 │
│    Actions)     │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Log           │    │   Alerting      │    │   Analytics     │
│   Aggregation   │    │   (AlertManager)│    │   (Kibana)      │
│   (Loki/ELK)    │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### 2. **Ключевые метрики CI/CD**
```yaml
# Основные метрики для отслеживания
metrics:
  deployment:
    - deployment_frequency      # Частота развертываний
    - lead_time                # Время от коммита до продакшена
    - change_failure_rate      # Процент неудачных изменений
    - mean_time_to_recovery    # Среднее время восстановления
  
  pipeline:
    - build_duration           # Время сборки
    - test_duration           # Время тестирования
    - pipeline_success_rate   # Успешность пайплайнов
    - queue_time              # Время ожидания в очереди
```

### 🛠️ Мониторинг Jenkins

#### 1. **Prometheus метрики для Jenkins**
```yaml
# jenkins-prometheus.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    
    scrape_configs:
    - job_name: 'jenkins'
      static_configs:
      - targets: ['jenkins:8080']
      metrics_path: '/prometheus'
      scrape_interval: 5s
```

#### 2. **Jenkins Pipeline с метриками**
```groovy
// Jenkinsfile с мониторингом
pipeline {
    agent any
    
    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        stage('Build') {
            steps {
                script {
                    def startTime = System.currentTimeMillis()
                    
                    sh 'npm ci'
                    sh 'npm run build'
                    
                    def duration = System.currentTimeMillis() - startTime
                    
                    // Отправка метрик в Prometheus
                    sh """
                        echo 'jenkins_build_duration_seconds{job="${env.JOB_NAME}",stage="build"} ${duration/1000}' | \
                        curl -X POST --data-binary @- http://pushgateway:9091/metrics/job/jenkins
                    """
                }
            }
        }
        
        stage('Test') {
            steps {
                script {
                    def startTime = System.currentTimeMillis()
                    
                    sh 'npm test'
                    
                    def duration = System.currentTimeMillis() - startTime
                    def testResults = readFile('test-results.xml')
                    def failedTests = (testResults =~ /failures="(\d+)"/).findAll()
                    
                    sh """
                        echo 'jenkins_test_duration_seconds{job="${env.JOB_NAME}"} ${duration/1000}' | \
                        curl -X POST --data-binary @- http://pushgateway:9091/metrics/job/jenkins
                        
                        echo 'jenkins_test_failures_total{job="${env.JOB_NAME}"} ${failedTests[0][1]}' | \
                        curl -X POST --data-binary @- http://pushgateway:9091/metrics/job/jenkins
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    def startTime = System.currentTimeMillis()
                    
                    sh '''
                        kubectl apply -f k8s/
                        kubectl rollout status deployment/myapp
                    '''
                    
                    def duration = System.currentTimeMillis() - startTime
                    
                    sh """
                        echo 'jenkins_deploy_duration_seconds{job="${env.JOB_NAME}"} ${duration/1000}' | \
                        curl -X POST --data-binary @- http://pushgateway:9091/metrics/job/jenkins
                        
                        echo 'jenkins_deployment_total{job="${env.JOB_NAME}",status="success"} 1' | \
                        curl -X POST --data-binary @- http://pushgateway:9091/metrics/job/jenkins
                    """
                }
            }
        }
    }
    
    post {
        always {
            // Сбор логов
            archiveArtifacts artifacts: 'logs/**/*', allowEmptyArchive: true
            
            // Отправка в ELK
            sh '''
                curl -X POST "elasticsearch:9200/jenkins-logs/_doc" \
                -H "Content-Type: application/json" \
                -d "{
                    \"timestamp\": \"$(date -Iseconds)\",
                    \"job_name\": \"${JOB_NAME}\",
                    \"build_number\": \"${BUILD_NUMBER}\",
                    \"status\": \"${currentBuild.currentResult}\",
                    \"duration\": \"${currentBuild.duration}\"
                }"
            '''
        }
        
        failure {
            sh """
                echo 'jenkins_deployment_total{job="${env.JOB_NAME}",status="failure"} 1' | \
                curl -X POST --data-binary @- http://pushgateway:9091/metrics/job/jenkins
            """
        }
    }
}
```

### 📊 Примеры из нашего кластера

#### Проверка метрик Prometheus:
```bash
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
```

#### Просмотр логов ArgoCD:
```bash
kubectl logs -f deployment/argocd-application-controller -n argocd
```

#### Мониторинг развертываний:
```bash
kubectl get events --sort-by=.metadata.creationTimestamp -A
```

### 🎯 GitHub Actions мониторинг

#### 1. **Workflow с метриками**
```yaml
# .github/workflows/monitored-deploy.yml
name: Monitored Deployment

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Record deployment start
      run: |
        curl -X POST "${{ secrets.WEBHOOK_URL }}/deployment/start" \
          -H "Content-Type: application/json" \
          -d '{
            "repository": "${{ github.repository }}",
            "commit": "${{ github.sha }}",
            "workflow": "${{ github.workflow }}",
            "run_id": "${{ github.run_id }}",
            "timestamp": "'$(date -Iseconds)'"
          }'
    
    - name: Build and test
      id: build
      run: |
        start_time=$(date +%s)
        
        npm ci
        npm run build
        npm test
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        echo "duration=$duration" >> $GITHUB_OUTPUT
    
    - name: Deploy to Kubernetes
      id: deploy
      run: |
        start_time=$(date +%s)
        
        kubectl apply -f k8s/
        kubectl rollout status deployment/myapp --timeout=300s
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        echo "duration=$duration" >> $GITHUB_OUTPUT
    
    - name: Record deployment success
      if: success()
      run: |
        curl -X POST "${{ secrets.WEBHOOK_URL }}/deployment/success" \
          -H "Content-Type: application/json" \
          -d '{
            "repository": "${{ github.repository }}",
            "commit": "${{ github.sha }}",
            "workflow": "${{ github.workflow }}",
            "run_id": "${{ github.run_id }}",
            "build_duration": "${{ steps.build.outputs.duration }}",
            "deploy_duration": "${{ steps.deploy.outputs.duration }}",
            "timestamp": "'$(date -Iseconds)'"
          }'
    
    - name: Record deployment failure
      if: failure()
      run: |
        curl -X POST "${{ secrets.WEBHOOK_URL }}/deployment/failure" \
          -H "Content-Type: application/json" \
          -d '{
            "repository": "${{ github.repository }}",
            "commit": "${{ github.sha }}",
            "workflow": "${{ github.workflow }}",
            "run_id": "${{ github.run_id }}",
            "error": "Deployment failed",
            "timestamp": "'$(date -Iseconds)'"
          }'
```

#### 2. **Webhook сервер для сбора метрик**
```javascript
// webhook-server.js
const express = require('express');
const prometheus = require('prom-client');

const app = express();
app.use(express.json());

// Prometheus метрики
const deploymentCounter = new prometheus.Counter({
  name: 'github_deployments_total',
  help: 'Total number of deployments',
  labelNames: ['repository', 'status']
});

const deploymentDuration = new prometheus.Histogram({
  name: 'github_deployment_duration_seconds',
  help: 'Deployment duration in seconds',
  labelNames: ['repository', 'stage'],
  buckets: [1, 5, 10, 30, 60, 120, 300, 600]
});

// Webhook endpoints
app.post('/deployment/start', (req, res) => {
  console.log('Deployment started:', req.body);
  res.status(200).send('OK');
});

app.post('/deployment/success', (req, res) => {
  const { repository, build_duration, deploy_duration } = req.body;
  
  deploymentCounter.inc({ repository, status: 'success' });
  deploymentDuration.observe({ repository, stage: 'build' }, parseInt(build_duration));
  deploymentDuration.observe({ repository, stage: 'deploy' }, parseInt(deploy_duration));
  
  console.log('Deployment succeeded:', req.body);
  res.status(200).send('OK');
});

app.post('/deployment/failure', (req, res) => {
  const { repository } = req.body;
  
  deploymentCounter.inc({ repository, status: 'failure' });
  
  console.log('Deployment failed:', req.body);
  res.status(200).send('OK');
});

// Prometheus metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});

app.listen(3000, () => {
  console.log('Webhook server listening on port 3000');
});
```

### 📈 Grafana Dashboards

#### 1. **CI/CD Pipeline Dashboard**
```json
{
  "dashboard": {
    "title": "CI/CD Pipeline Metrics",
    "panels": [
      {
        "title": "Deployment Frequency",
        "type": "stat",
        "targets": [
          {
            "expr": "increase(github_deployments_total{status=\"success\"}[24h])"
          }
        ]
      },
      {
        "title": "Pipeline Success Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(github_deployments_total{status=\"success\"}[24h]) / rate(github_deployments_total[24h]) * 100"
          }
        ]
      },
      {
        "title": "Build Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "github_deployment_duration_seconds{stage=\"build\"}"
          }
        ]
      },
      {
        "title": "Deploy Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "github_deployment_duration_seconds{stage=\"deploy\"}"
          }
        ]
      },
      {
        "title": "Lead Time",
        "type": "graph",
        "targets": [
          {
            "expr": "github_deployment_duration_seconds{stage=\"build\"} + github_deployment_duration_seconds{stage=\"deploy\"}"
          }
        ]
      }
    ]
  }
}
```

#### 2. **DORA Metrics Dashboard**
```json
{
  "dashboard": {
    "title": "DORA Metrics",
    "panels": [
      {
        "title": "Deployment Frequency",
        "description": "How often deployments occur",
        "type": "stat",
        "targets": [
          {
            "expr": "increase(github_deployments_total{status=\"success\"}[7d]) / 7"
          }
        ]
      },
      {
        "title": "Lead Time for Changes",
        "description": "Time from commit to production",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(github_deployment_duration_seconds)"
          }
        ]
      },
      {
        "title": "Change Failure Rate",
        "description": "Percentage of deployments causing failures",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(github_deployments_total{status=\"failure\"}[7d]) / rate(github_deployments_total[7d]) * 100"
          }
        ]
      },
      {
        "title": "Mean Time to Recovery",
        "description": "Time to recover from failures",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(time() - github_deployment_failure_timestamp)"
          }
        ]
      }
    ]
  }
}
```

### 🔍 Логирование CI/CD

#### 1. **Структурированное логирование**
```yaml
# fluentd-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*jenkins*.log
      pos_file /var/log/fluentd-jenkins.log.pos
      tag jenkins.*
      format json
      time_key timestamp
      time_format %Y-%m-%dT%H:%M:%S.%NZ
    </source>
    
    <filter jenkins.**>
      @type parser
      key_name log
      reserve_data true
      <parse>
        @type json
      </parse>
    </filter>
    
    <match jenkins.**>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      index_name jenkins-logs
      type_name _doc
      include_tag_key true
      tag_key @log_name
      flush_interval 1s
    </match>
```

#### 2. **Логирование в приложении**
```javascript
// logger.js для CI/CD процессов
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'ci-cd-pipeline',
    version: process.env.BUILD_NUMBER || 'unknown'
  },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Использование в CI/CD скриптах
logger.info('Deployment started', {
  repository: process.env.GITHUB_REPOSITORY,
  commit: process.env.GITHUB_SHA,
  workflow: process.env.GITHUB_WORKFLOW
});

logger.error('Deployment failed', {
  error: error.message,
  stack: error.stack,
  stage: 'kubernetes-deploy'
});
```

### 🚨 Алертинг для CI/CD

#### 1. **Prometheus Rules**
```yaml
# ci-cd-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ci-cd-alerts
spec:
  groups:
  - name: ci-cd
    rules:
    - alert: HighDeploymentFailureRate
      expr: |
        (
          rate(github_deployments_total{status="failure"}[1h]) /
          rate(github_deployments_total[1h])
        ) > 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High deployment failure rate"
        description: "Deployment failure rate is {{ $value | humanizePercentage }}"
    
    - alert: LongBuildTime
      expr: github_deployment_duration_seconds{stage="build"} > 600
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Build taking too long"
        description: "Build duration is {{ $value }}s"
    
    - alert: DeploymentStuck
      expr: |
        time() - max(github_deployment_start_timestamp) > 1800
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Deployment appears to be stuck"
        description: "No deployment activity for 30 minutes"
```

#### 2. **Slack уведомления**
```bash
#!/bin/bash
# notify-slack.sh

SLACK_WEBHOOK_URL="$1"
MESSAGE="$2"
STATUS="$3"

case $STATUS in
  "success")
    COLOR="good"
    EMOJI=":white_check_mark:"
    ;;
  "failure")
    COLOR="danger"
    EMOJI=":x:"
    ;;
  *)
    COLOR="warning"
    EMOJI=":warning:"
    ;;
esac

curl -X POST -H 'Content-type: application/json' \
  --data "{
    \"attachments\": [
      {
        \"color\": \"$COLOR\",
        \"text\": \"$EMOJI $MESSAGE\",
        \"fields\": [
          {
            \"title\": \"Repository\",
            \"value\": \"$GITHUB_REPOSITORY\",
            \"short\": true
          },
          {
            \"title\": \"Commit\",
            \"value\": \"$GITHUB_SHA\",
            \"short\": true
          },
          {
            \"title\": \"Workflow\",
            \"value\": \"$GITHUB_WORKFLOW\",
            \"short\": true
          }
        ]
      }
    ]
  }" \
  $SLACK_WEBHOOK_URL
```

### 📋 Лучшие практики мониторинга CI/CD

#### 1. **Ключевые принципы**
- ✅ **Мониторьте DORA метрики** (Deployment Frequency, Lead Time, MTTR, Change Failure Rate)
- ✅ **Используйте структурированное логирование** для лучшего анализа
- ✅ **Настройте алерты** для критических проблем
- ✅ **Создайте дашборды** для визуализации трендов
- ✅ **Отслеживайте производительность** пайплайнов
- ✅ **Мониторьте качество** кода и тестов

#### 2. **Автоматизация мониторинга**
```bash
#!/bin/bash
# setup-monitoring.sh

echo "🔧 Настройка мониторинга CI/CD..."

# Установка Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Установка Grafana dashboards
kubectl apply -f ci-cd-dashboards.yaml

# Настройка алертов
kubectl apply -f ci-cd-alerts.yaml

echo "✅ Мониторинг CI/CD настроен"
```

Комплексный мониторинг и логирование CI/CD процессов обеспечивает видимость, быструю диагностику проблем и данные для непрерывного улучшения процессов доставки.
