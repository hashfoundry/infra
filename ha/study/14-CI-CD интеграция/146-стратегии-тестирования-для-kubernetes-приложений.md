# 146. Какие стратегии тестирования для Kubernetes приложений?

## 🎯 Вопрос
Какие стратегии тестирования для Kubernetes приложений?

## 💡 Ответ

Тестирование Kubernetes приложений требует многоуровневого подхода, включающего unit-тесты, интеграционные тесты, end-to-end тесты и тесты инфраструктуры.

### 🏗️ Пирамида тестирования для Kubernetes

#### 1. **Unit тесты (основание пирамиды)**
```javascript
// Пример unit теста для Node.js приложения
const request = require('supertest');
const app = require('../src/app');

describe('Health endpoint', () => {
  test('should return 200 OK', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);
    
    expect(response.body).toEqual({
      status: 'healthy',
      timestamp: expect.any(String)
    });
  });
});
```

#### 2. **Интеграционные тесты**
```yaml
# docker-compose.test.yml для интеграционных тестов
version: '3.8'
services:
  app:
    build: .
    environment:
      - DATABASE_URL=postgresql://test:test@db:5432/testdb
    depends_on:
      - db
  
  db:
    image: postgres:13
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
  
  test:
    build: .
    command: npm run test:integration
    depends_on:
      - app
      - db
```

### 🛠️ Kubernetes-специфичные тесты

#### 1. **Тестирование манифестов**
```bash
#!/bin/bash
# test-manifests.sh

echo "🧪 Тестирование Kubernetes манифестов..."

# Валидация синтаксиса
kubectl apply --dry-run=client -f k8s/ || exit 1

# Проверка с kubeval
kubeval k8s/*.yaml || exit 1

# Проверка безопасности с kubesec
kubesec scan k8s/*.yaml || exit 1

# Проверка политик с OPA Conftest
conftest test --policy policies/ k8s/*.yaml || exit 1

echo "✅ Все тесты манифестов прошли успешно"
```

#### 2. **Helm Chart тесты**
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "myapp.fullname" . }}-test"
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['--spider', '{{ include "myapp.fullname" . }}:{{ .Values.service.port }}/health']
```

### 📊 Примеры из нашего кластера

#### Запуск Helm тестов:
```bash
helm test argocd -n argocd
```

#### Проверка готовности приложений:
```bash
kubectl get pods -A -o wide | grep -v Running
```

#### Тестирование сетевой связности:
```bash
kubectl run test-pod --rm -i --restart=Never --image=busybox -- \
  wget -qO- http://argocd-server.argocd.svc.cluster.local/healthz
```

### 🎯 End-to-End тестирование

#### 1. **Cypress тесты в Kubernetes**
```javascript
// cypress/integration/app.spec.js
describe('Application E2E Tests', () => {
  beforeEach(() => {
    cy.visit(Cypress.env('APP_URL') || 'http://localhost:3000');
  });

  it('should load the homepage', () => {
    cy.contains('Welcome');
    cy.get('[data-testid="header"]').should('be.visible');
  });

  it('should handle user authentication', () => {
    cy.get('[data-testid="login-button"]').click();
    cy.get('[data-testid="username"]').type('testuser');
    cy.get('[data-testid="password"]').type('testpass');
    cy.get('[data-testid="submit"]').click();
    cy.url().should('include', '/dashboard');
  });
});
```

```yaml
# k8s/cypress-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: e2e-tests
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: cypress
        image: cypress/included:latest
        env:
        - name: CYPRESS_baseUrl
          value: "http://myapp.default.svc.cluster.local:8080"
        - name: CYPRESS_APP_URL
          value: "http://myapp.default.svc.cluster.local:8080"
        volumeMounts:
        - name: tests
          mountPath: /e2e
        workingDir: /e2e
        command: ["cypress", "run", "--headless"]
      volumes:
      - name: tests
        configMap:
          name: cypress-tests
```

#### 2. **Playwright тесты**
```javascript
// tests/e2e.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Kubernetes App E2E', () => {
  test('should perform health check', async ({ page }) => {
    await page.goto(process.env.APP_URL + '/health');
    const response = await page.textContent('body');
    const health = JSON.parse(response);
    expect(health.status).toBe('healthy');
  });

  test('should handle API requests', async ({ request }) => {
    const response = await request.get(process.env.APP_URL + '/api/users');
    expect(response.ok()).toBeTruthy();
    const users = await response.json();
    expect(Array.isArray(users)).toBeTruthy();
  });
});
```

### 🔍 Тестирование производительности

#### 1. **K6 нагрузочные тесты**
```javascript
// k6-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 10 },
    { duration: '2m', target: 20 },
    { duration: '5m', target: 20 },
    { duration: '2m', target: 0 },
  ],
};

export default function() {
  let response = http.get(`${__ENV.APP_URL}/api/health`);
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
```

```yaml
# k8s/k6-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: performance-test
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: k6
        image: grafana/k6:latest
        env:
        - name: APP_URL
          value: "http://myapp.default.svc.cluster.local:8080"
        command: ["k6", "run", "/scripts/k6-test.js"]
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: k6-scripts
```

#### 2. **JMeter тесты**
```xml
<!-- jmeter-test.jmx -->
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Kubernetes App Test">
      <elementProp name="TestPlan.arguments" elementType="Arguments" guiclass="ArgumentsPanel">
        <collectionProp name="Arguments.arguments">
          <elementProp name="APP_HOST" elementType="Argument">
            <stringProp name="Argument.name">APP_HOST</stringProp>
            <stringProp name="Argument.value">${__P(APP_HOST,myapp.default.svc.cluster.local)}</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
  </hashTree>
</jmeterTestPlan>
```

### 🎪 CI/CD интеграция тестов

#### 1. **GitHub Actions с тестами**
```yaml
# .github/workflows/test.yml
name: Test Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: actions/setup-node@v2
      with:
        node-version: '16'
    - run: npm ci
    - run: npm test
    - run: npm run test:coverage

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
    - uses: actions/checkout@v2
    - run: npm ci
    - run: npm run test:integration

  k8s-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Kind
      uses: helm/kind-action@v1.2.0
      with:
        cluster_name: test-cluster
    
    - name: Deploy to test cluster
      run: |
        kubectl apply -f k8s/
        kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s
    
    - name: Run Helm tests
      run: |
        helm install myapp-test ./helm-chart --wait
        helm test myapp-test
    
    - name: Run E2E tests
      run: |
        kubectl apply -f k8s/cypress-job.yaml
        kubectl wait --for=condition=complete job/e2e-tests --timeout=600s
```

#### 2. **Jenkins Pipeline с тестами**
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    stages {
        stage('Unit Tests') {
            steps {
                sh 'npm ci'
                sh 'npm test'
                publishTestResults testResultsPattern: 'test-results.xml'
                publishCoverageGoberturaReports 'coverage/cobertura-coverage.xml'
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh 'docker-compose -f docker-compose.test.yml up --abort-on-container-exit'
            }
            post {
                always {
                    sh 'docker-compose -f docker-compose.test.yml down'
                }
            }
        }
        
        stage('K8s Manifest Tests') {
            steps {
                sh '''
                    kubectl apply --dry-run=client -f k8s/
                    kubeval k8s/*.yaml
                    kubesec scan k8s/*.yaml
                '''
            }
        }
        
        stage('Deploy to Test Environment') {
            steps {
                sh '''
                    helm upgrade --install myapp-test ./helm-chart \
                      --namespace test \
                      --create-namespace \
                      --set image.tag=${BUILD_NUMBER} \
                      --wait
                '''
            }
        }
        
        stage('E2E Tests') {
            steps {
                sh '''
                    kubectl apply -f k8s/cypress-job.yaml -n test
                    kubectl wait --for=condition=complete job/e2e-tests -n test --timeout=600s
                '''
            }
        }
        
        stage('Performance Tests') {
            steps {
                sh '''
                    kubectl apply -f k8s/k6-job.yaml -n test
                    kubectl wait --for=condition=complete job/performance-test -n test --timeout=900s
                '''
            }
        }
    }
    
    post {
        always {
            sh 'helm uninstall myapp-test --namespace test'
        }
    }
}
```

### 🔐 Тестирование безопасности

#### 1. **Сканирование образов**
```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
    branches: [main]

jobs:
  image-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Build image
      run: docker build -t myapp:test .
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'myapp:test'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v1
      with:
        sarif_file: 'trivy-results.sarif'
```

#### 2. **Тестирование RBAC**
```bash
#!/bin/bash
# test-rbac.sh

echo "🔐 Тестирование RBAC политик..."

# Тест доступа для обычного пользователя
kubectl auth can-i get pods --as=system:serviceaccount:default:myapp-sa
kubectl auth can-i create secrets --as=system:serviceaccount:default:myapp-sa

# Тест доступа для админа
kubectl auth can-i "*" "*" --as=system:serviceaccount:kube-system:admin

# Тест сетевых политик
kubectl run test-pod --rm -i --restart=Never --image=busybox -- \
  wget -qO- --timeout=5 http://restricted-service.default.svc.cluster.local

echo "✅ RBAC тесты завершены"
```

### 📈 Мониторинг тестов

#### 1. **Метрики тестирования**
```yaml
# ServiceMonitor для тестовых метрик
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: test-metrics
spec:
  selector:
    matchLabels:
      app: test-runner
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

#### 2. **Алерты для тестов**
```yaml
# PrometheusRule для тестов
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alerts
spec:
  groups:
  - name: testing
    rules:
    - alert: TestJobFailed
      expr: kube_job_status_failed > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Test job {{ $labels.job_name }} failed"
    
    - alert: E2ETestsSlowResponse
      expr: http_request_duration_seconds{job="e2e-tests"} > 5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "E2E tests are responding slowly"
```

### 📋 Лучшие практики тестирования

#### 1. **Стратегия тестирования**
- ✅ **70% Unit тесты** - быстрые, изолированные
- ✅ **20% Интеграционные тесты** - проверка взаимодействий
- ✅ **10% E2E тесты** - полный пользовательский сценарий

#### 2. **Тестовые окружения**
```yaml
# Изолированные namespace для тестов
apiVersion: v1
kind: Namespace
metadata:
  name: test-pr-123
  labels:
    type: test
    pr: "123"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: test-quota
  namespace: test-pr-123
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    pods: "10"
```

### 🎯 Автоматизация тестирования

```bash
#!/bin/bash
# run-all-tests.sh

set -e

echo "🚀 Запуск полного набора тестов..."

# Unit тесты
echo "1️⃣ Unit тесты..."
npm test

# Lint и статический анализ
echo "2️⃣ Статический анализ..."
npm run lint
npm run audit

# Тестирование манифестов
echo "3️⃣ Тестирование Kubernetes манифестов..."
./scripts/test-manifests.sh

# Интеграционные тесты
echo "4️⃣ Интеграционные тесты..."
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Развертывание в тестовое окружение
echo "5️⃣ Развертывание в тестовое окружение..."
helm upgrade --install myapp-test ./helm-chart \
  --namespace test-$(git rev-parse --short HEAD) \
  --create-namespace \
  --wait

# E2E тесты
echo "6️⃣ E2E тесты..."
kubectl apply -f k8s/cypress-job.yaml -n test-$(git rev-parse --short HEAD)
kubectl wait --for=condition=complete job/e2e-tests -n test-$(git rev-parse --short HEAD) --timeout=600s

# Нагрузочные тесты
echo "7️⃣ Нагрузочные тесты..."
kubectl apply -f k8s/k6-job.yaml -n test-$(git rev-parse --short HEAD)
kubectl wait --for=condition=complete job/performance-test -n test-$(git rev-parse --short HEAD) --timeout=900s

echo "✅ Все тесты прошли успешно!"

# Очистка
helm uninstall myapp-test --namespace test-$(git rev-parse --short HEAD)
kubectl delete namespace test-$(git rev-parse --short HEAD)
```

Комплексная стратегия тестирования обеспечивает надежность, производительность и безопасность Kubernetes приложений на всех этапах разработки и развертывания.
