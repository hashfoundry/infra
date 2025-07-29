# 146. Стратегии тестирования для Kubernetes приложений

## 🎯 **Основные концепции:**

| Уровень тестирования | Традиционный подход | Kubernetes-native подход |
|---------------------|---------------------|---------------------------|
| **Unit тесты** | Локальное выполнение | Контейнеризованные тесты |
| **Интеграционные тесты** | Docker Compose | Kubernetes Jobs |
| **Contract тесты** | Mock серверы | Service Mesh с Pact |
| **E2E тесты** | Selenium Grid | Kubernetes-based test runners |
| **Performance тесты** | Внешние инструменты | K6/JMeter в кластере |
| **Security тесты** | Статические сканеры | Runtime security scanning |
| **Chaos тесты** | Ручное тестирование | Chaos Engineering tools |
| **Smoke тесты** | Простые HTTP проверки | Health checks + Readiness probes |
| **Regression тесты** | Полный набор тестов | Automated test suites в CI/CD |
| **Load тесты** | Отдельная инфраструктура | Kubernetes HPA testing |
| **Canary тесты** | Blue-Green deployment | Progressive delivery |
| **Infrastructure тесты** | Manual validation | Infrastructure as Code testing |

## 🏆 **Пирамида тестирования для Kubernetes - что это такое?**

**Пирамида тестирования для Kubernetes** — это многоуровневая стратегия тестирования, адаптированная для контейнеризованных приложений и микросервисной архитектуры. Она включает специфичные для Kubernetes инструменты и подходы, обеспечивающие надежность приложений в кластерной среде.

### **Уровни пирамиды тестирования:**
1. **Unit тесты (70%)** - тестирование отдельных компонентов
2. **Integration тесты (20%)** - тестирование взаимодействий между сервисами
3. **Contract тесты (5%)** - тестирование API контрактов
4. **E2E тесты (5%)** - тестирование полных пользовательских сценариев

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих тестовых ресурсов:**
```bash
# Поиск тестовых Job'ов и Pod'ов
kubectl get jobs -A | grep -i test

# Проверка Helm тестов
kubectl get pods -A -l "helm.sh/hook=test"

# Анализ тестовых namespace'ов
kubectl get namespaces | grep -E "(test|staging|dev)"

# Поиск тестовых ConfigMap'ов
kubectl get configmaps -A | grep -i test

# Проверка тестовых сервисов
kubectl get services -A | grep -i test

# Анализ тестовых Ingress'ов
kubectl get ingress -A | grep -i test

# Поиск тестовых PVC
kubectl get pvc -A | grep -i test

# Проверка тестовых секретов
kubectl get secrets -A | grep -i test
```

### **2. Проверка готовности приложений для тестирования:**
```bash
# Проверка health endpoints в ArgoCD
kubectl get pods -n argocd -o json | jq -r '
  .items[] | 
  select(.spec.containers[].readinessProbe.httpGet.path) | 
  "\(.metadata.name): \(.spec.containers[].readinessProbe.httpGet.path)"
'

# Анализ liveness и readiness probes
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[].livenessProbe or .spec.containers[].readinessProbe) | 
  "\(.metadata.namespace)/\(.metadata.name): Has health checks"
'

# Проверка Service Monitor'ов для метрик
kubectl get servicemonitors -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SELECTOR:.spec.selector"

# Анализ endpoints для тестирования
kubectl get endpoints -A -o json | jq -r '
  .items[] | 
  select(.subsets[].addresses) | 
  "\(.metadata.namespace)/\(.metadata.name): \(.subsets[].addresses | length) endpoints"
'
```

### **3. Тестирование сетевой связности в кластере:**
```bash
# Тестирование DNS резолюции
kubectl run dns-test --rm -i --restart=Never --image=busybox -- nslookup kubernetes.default.svc.cluster.local

# Проверка связности между namespace'ами
kubectl run network-test --rm -i --restart=Never --image=busybox -- \
  wget -qO- --timeout=5 http://argocd-server.argocd.svc.cluster.local/healthz

# Тестирование внешней связности
kubectl run external-test --rm -i --restart=Never --image=busybox -- \
  wget -qO- --timeout=10 https://httpbin.org/get

# Проверка Service Mesh связности (если установлен Istio)
kubectl get virtualservices -A
kubectl get destinationrules -A

# Тестирование Ingress доступности
kubectl get ingress -A -o json | jq -r '
  .items[] | 
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.rules[].host)"
'
```

## 🛠️ **Comprehensive Testing Strategy Implementation:**

### **1. Unit Testing в контейнерах:**
```yaml
# k8s/testing/unit-tests-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hashfoundry-unit-tests
  namespace: hashfoundry-testing
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: unit-tests
    test-type: unit
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: hashfoundry-webapp
        app.kubernetes.io/component: unit-tests
    spec:
      restartPolicy: Never
      containers:
      - name: unit-tests
        image: hashfoundry/webapp:test
        command: ["npm", "run", "test:unit"]
        env:
        - name: NODE_ENV
          value: "test"
        - name: CI
          value: "true"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: test-results
          mountPath: /app/test-results
        - name: coverage-reports
          mountPath: /app/coverage
      - name: test-reporter
        image: hashfoundry/test-reporter:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Waiting for tests to complete..."
          while [ ! -f /test-results/junit.xml ]; do sleep 5; done
          echo "Publishing test results..."
          curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d @/test-results/results.json
        env:
        - name: WEBHOOK_URL
          valueFrom:
            secretKeyRef:
              name: test-webhooks
              key: unit-tests-webhook
        volumeMounts:
        - name: test-results
          mountPath: /test-results
          readOnly: true
      volumes:
      - name: test-results
        emptyDir: {}
      - name: coverage-reports
        emptyDir: {}
      activeDeadlineSeconds: 600
  backoffLimit: 2
```

### **2. Integration Testing с зависимостями:**
```yaml
# k8s/testing/integration-tests.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: integration-test-config
  namespace: hashfoundry-testing
data:
  test-config.json: |
    {
      "database": {
        "host": "postgres-test.hashfoundry-testing.svc.cluster.local",
        "port": 5432,
        "database": "hashfoundry_test",
        "ssl": false
      },
      "redis": {
        "host": "redis-test.hashfoundry-testing.svc.cluster.local",
        "port": 6379
      },
      "external_apis": {
        "payment_service": "http://payment-mock.hashfoundry-testing.svc.cluster.local:8080",
        "notification_service": "http://notification-mock.hashfoundry-testing.svc.cluster.local:8080"
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-test
  namespace: hashfoundry-testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-test
  template:
    metadata:
      labels:
        app: postgres-test
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: hashfoundry_test
        - name: POSTGRES_USER
          value: test_user
        - name: POSTGRES_PASSWORD
          value: test_password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: init-scripts
          mountPath: /docker-entrypoint-initdb.d
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - test_user
            - -d
            - hashfoundry_test
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-data
        emptyDir: {}
      - name: init-scripts
        configMap:
          name: postgres-init-scripts
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-test
  namespace: hashfoundry-testing
spec:
  selector:
    app: postgres-test
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: batch/v1
kind: Job
metadata:
  name: hashfoundry-integration-tests
  namespace: hashfoundry-testing
  labels:
    test-type: integration
spec:
  template:
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-dependencies
        image: busybox:1.35
        command: ['sh', '-c']
        args:
        - |
          echo "Waiting for PostgreSQL..."
          until nc -z postgres-test.hashfoundry-testing.svc.cluster.local 5432; do
            echo "PostgreSQL not ready, waiting..."
            sleep 5
          done
          echo "Waiting for Redis..."
          until nc -z redis-test.hashfoundry-testing.svc.cluster.local 6379; do
            echo "Redis not ready, waiting..."
            sleep 5
          done
          echo "All dependencies are ready!"
      containers:
      - name: integration-tests
        image: hashfoundry/webapp:test
        command: ["npm", "run", "test:integration"]
        env:
        - name: NODE_ENV
          value: "test"
        - name: TEST_CONFIG_PATH
          value: "/config/test-config.json"
        - name: DATABASE_URL
          value: "postgresql://test_user:test_password@postgres-test.hashfoundry-testing.svc.cluster.local:5432/hashfoundry_test"
        - name: REDIS_URL
          value: "redis://redis-test.hashfoundry-testing.svc.cluster.local:6379"
        volumeMounts:
        - name: test-config
          mountPath: /config
        - name: test-results
          mountPath: /app/test-results
        resources:
          requests:
            memory: "512Mi"
            cpu: "300m"
          limits:
            memory: "1Gi"
            cpu: "800m"
      volumes:
      - name: test-config
        configMap:
          name: integration-test-config
      - name: test-results
        emptyDir: {}
      activeDeadlineSeconds: 1200
  backoffLimit: 1
```

### **3. Contract Testing с Pact:**
```yaml
# k8s/testing/contract-tests.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hashfoundry-contract-tests
  namespace: hashfoundry-testing
  labels:
    test-type: contract
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pact-consumer-tests
        image: hashfoundry/webapp:test
        command: ["npm", "run", "test:pact:consumer"]
        env:
        - name: PACT_BROKER_BASE_URL
          value: "http://pact-broker.hashfoundry-testing.svc.cluster.local:9292"
        - name: PACT_BROKER_USERNAME
          valueFrom:
            secretKeyRef:
              name: pact-broker-auth
              key: username
        - name: PACT_BROKER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: pact-broker-auth
              key: password
        volumeMounts:
        - name: pact-files
          mountPath: /app/pacts
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      - name: pact-provider-tests
        image: hashfoundry/api:test
        command: ["npm", "run", "test:pact:provider"]
        env:
        - name: PACT_BROKER_BASE_URL
          value: "http://pact-broker.hashfoundry-testing.svc.cluster.local:9292"
        - name: PROVIDER_BASE_URL
          value: "http://hashfoundry-api.hashfoundry-testing.svc.cluster.local:8080"
        volumeMounts:
        - name: pact-files
          mountPath: /app/pacts
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: pact-files
        emptyDir: {}
      activeDeadlineSeconds: 900
  backoffLimit: 2
```

### **4. End-to-End Testing с Playwright:**
```yaml
# k8s/testing/e2e-tests.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: playwright-config
  namespace: hashfoundry-testing
data:
  playwright.config.js: |
    module.exports = {
      testDir: './tests',
      timeout: 30000,
      expect: {
        timeout: 5000
      },
      fullyParallel: true,
      forbidOnly: !!process.env.CI,
      retries: process.env.CI ? 2 : 0,
      workers: process.env.CI ? 1 : undefined,
      reporter: [
        ['html'],
        ['junit', { outputFile: 'test-results/results.xml' }],
        ['json', { outputFile: 'test-results/results.json' }]
      ],
      use: {
        baseURL: process.env.BASE_URL || 'http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000',
        trace: 'on-first-retry',
        screenshot: 'only-on-failure',
        video: 'retain-on-failure'
      },
      projects: [
        {
          name: 'chromium',
          use: { ...devices['Desktop Chrome'] },
        },
        {
          name: 'firefox',
          use: { ...devices['Desktop Firefox'] },
        },
        {
          name: 'webkit',
          use: { ...devices['Desktop Safari'] },
        },
        {
          name: 'Mobile Chrome',
          use: { ...devices['Pixel 5'] },
        }
      ]
    };
  
  auth.setup.js: |
    const { test as setup, expect } = require('@playwright/test');
    
    const authFile = 'playwright/.auth/user.json';
    
    setup('authenticate', async ({ page }) => {
      await page.goto('/login');
      await page.locator('[data-testid="username"]').fill('test@hashfoundry.com');
      await page.locator('[data-testid="password"]').fill('testpassword');
      await page.locator('[data-testid="login-button"]').click();
      
      await page.waitForURL('/dashboard');
      await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
      
      await page.context().storageState({ path: authFile });
    });
  
  dashboard.spec.js: |
    const { test, expect } = require('@playwright/test');
    
    test.use({ storageState: 'playwright/.auth/user.json' });
    
    test.describe('Dashboard', () => {
      test('should display user dashboard', async ({ page }) => {
        await page.goto('/dashboard');
        
        await expect(page.locator('[data-testid="dashboard-title"]')).toContainText('Dashboard');
        await expect(page.locator('[data-testid="user-stats"]')).toBeVisible();
        await expect(page.locator('[data-testid="recent-activity"]')).toBeVisible();
      });
      
      test('should handle navigation', async ({ page }) => {
        await page.goto('/dashboard');
        
        await page.locator('[data-testid="nav-projects"]').click();
        await expect(page).toHaveURL('/projects');
        
        await page.locator('[data-testid="nav-settings"]').click();
        await expect(page).toHaveURL('/settings');
      });
      
      test('should perform CRUD operations', async ({ page }) => {
        await page.goto('/projects');
        
        // Create
        await page.locator('[data-testid="create-project-button"]').click();
        await page.locator('[data-testid="project-name"]').fill('Test Project');
        await page.locator('[data-testid="project-description"]').fill('Test Description');
        await page.locator('[data-testid="save-project"]').click();
        
        await expect(page.locator('[data-testid="project-list"]')).toContainText('Test Project');
        
        // Update
        await page.locator('[data-testid="edit-project"]').first().click();
        await page.locator('[data-testid="project-name"]').fill('Updated Test Project');
        await page.locator('[data-testid="save-project"]').click();
        
        await expect(page.locator('[data-testid="project-list"]')).toContainText('Updated Test Project');
        
        // Delete
        await page.locator('[data-testid="delete-project"]').first().click();
        await page.locator('[data-testid="confirm-delete"]').click();
        
        await expect(page.locator('[data-testid="project-list"]')).not.toContainText('Updated Test Project');
      });
    });
---
apiVersion: batch/v1
kind: Job
metadata:
  name: hashfoundry-e2e-tests
  namespace: hashfoundry-testing
  labels:
    test-type: e2e
spec:
  template:
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-app
        image: busybox:1.35
        command: ['sh', '-c']
        args:
        - |
          echo "Waiting for application to be ready..."
          until wget -qO- --timeout=5 http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000/health; do
            echo "Application not ready, waiting..."
            sleep 10
          done
          echo "Application is ready!"
      containers:
      - name: playwright-tests
        image: mcr.microsoft.com/playwright:v1.40.0-focal
        workingDir: /app
        command: ["npx", "playwright", "test"]
        env:
        - name: BASE_URL
          value: "http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000"
        - name: CI
          value: "true"
        - name: PLAYWRIGHT_BROWSERS_PATH
          value: "/ms-playwright"
        volumeMounts:
        - name: test-config
          mountPath: /app
        - name: test-results
          mountPath: /app/test-results
        - name: playwright-report
          mountPath: /app/playwright-report
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      - name: test-reporter
        image: hashfoundry/test-reporter:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Waiting for E2E tests to complete..."
          while [ ! -f /test-results/results.xml ]; do sleep 10; done
          echo "Publishing E2E test results..."
          
          # Upload test results
          curl -X POST "$RESULTS_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d @/test-results/results.json
          
          # Upload screenshots and videos if tests failed
          if [ -d "/playwright-report" ]; then
            tar -czf /test-results/playwright-artifacts.tar.gz -C /playwright-report .
            curl -X POST "$ARTIFACTS_WEBHOOK_URL" \
              -H "Content-Type: application/octet-stream" \
              --data-binary @/test-results/playwright-artifacts.tar.gz
          fi
        env:
        - name: RESULTS_WEBHOOK_URL
          valueFrom:
            secretKeyRef:
              name: test-webhooks
              key: e2e-results-webhook
        - name: ARTIFACTS_WEBHOOK_URL
          valueFrom:
            secretKeyRef:
              name: test-webhooks
              key: e2e-artifacts-webhook
        volumeMounts:
        - name: test-results
          mountPath: /test-results
          readOnly: true
        - name: playwright-report
          mountPath: /playwright-report
          readOnly: true
      volumes:
      - name: test-config
        configMap:
          name: playwright-config
      - name: test-results
        emptyDir: {}
      - name: playwright-report
        emptyDir: {}
      activeDeadlineSeconds: 1800
  backoffLimit: 1
```

### **5. Performance Testing с K6:**
```yaml
# k8s/testing/performance-tests.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: k6-test-scripts
  namespace: hashfoundry-testing
data:
  load-test.js: |
    import http from 'k6/http';
    import { check, sleep } from 'k6';
    import { Rate } from 'k6/metrics';
    
    export let errorRate = new Rate('errors');
    
    export let options = {
      stages: [
        { duration: '2m', target: 10 },   // Ramp up
        { duration: '5m', target: 10 },   // Stay at 10 users
        { duration: '2m', target: 20 },   // Ramp up to 20 users
        { duration: '5m', target: 20 },   // Stay at 20 users
        { duration: '2m', target: 50 },   // Ramp up to 50 users
        { duration: '5m', target: 50 },   // Stay at 50 users
        { duration: '2m', target: 0 },    // Ramp down
      ],
      thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.1'],
        errors: ['rate<0.1'],
      },
    };
    
    const BASE_URL = __ENV.BASE_URL || 'http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000';
    
    export function setup() {
      // Login and get auth token
      let loginRes = http.post(`${BASE_URL}/api/auth/login`, {
        email: 'test@hashfoundry.com',
        password: 'testpassword'
      });
      
      check(loginRes, {
        'login successful': (r) => r.status === 200,
      });
      
      return { authToken: loginRes.json('token') };
    }
    
    export default function(data) {
      let params = {
        headers: {
          'Authorization': `Bearer ${data.authToken}`,
          'Content-Type': 'application/json',
        },
      };
      
      // Test homepage
      let homeRes = http.get(`${BASE_URL}/`, params);
      check(homeRes, {
        'homepage status is 200': (r) => r.status === 200,
        'homepage loads in <200ms': (r) => r.timings.duration < 200,
      }) || errorRate.add(1);
      
      // Test API endpoints
      let apiRes = http.get(`${BASE_URL}/api/projects`, params);
      check(apiRes, {
        'API status is 200': (r) => r.status === 200,
        'API responds in <500ms': (r) => r.timings.duration < 500,
      }) || errorRate.add(1);
      
      // Test creating a project
      let createRes = http.post(`${BASE_URL}/api/projects`, JSON.stringify({
        name: `Test Project ${Math.random()}`,
        description: 'Load test project'
      }), params);
      
      check(createRes, {
        'create project status is 201': (r) => r.status === 201,
        'create project responds in <1s': (r) => r.timings.duration < 1000,
      }) || errorRate.add(1);
      
      sleep(1);
    }
    
    export function teardown(data) {
      // Cleanup if needed
      console.log('Load test completed');
    }
  
  stress-test.js: |
    import http from 'k6/http';
    import { check } from 'k6';
    
    export let options = {
      stages: [
        { duration: '1m', target: 100 },
        { duration: '3m', target: 100 },
        { duration: '1m', target: 200 },
        { duration: '3m', target: 200 },
        { duration: '1m', target: 300 },
        { duration: '3m', target: 300 },
        { duration: '1m', target: 0 },
      ],
      thresholds: {
        http_req_duration: ['p(95)<1000'],
        http_req_failed: ['rate<0.2'],
      },
    };
    
    const BASE_URL = __ENV.BASE_URL || 'http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000';
    
    export default function() {
      let response = http.get(`${BASE_URL}/api/health`);
      check(response, {
        'status is 200': (r) => r.status === 200,
      });
    }
  
  spike-test.js: |
    import http from 'k6/http';
    import { check } from 'k6';
    
    export let options = {
      stages: [
        { duration: '30s', target: 10 },
        { duration: '1m', target: 500 },   // Spike
        { duration: '30s', target: 10 },
        { duration: '1m', target: 1000 },  // Bigger spike
        { duration: '30s', target: 10 },
      ],
    };
    
    const BASE_URL = __ENV.BASE_URL || 'http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000';
    
    export default function() {
      let response = http.get(`${BASE_URL}/`);
      check(response, {
        'status is 200': (r) => r.status === 200,
      });
    }
---
apiVersion: batch/v1
kind: Job
metadata:
  name: hashfoundry-performance-tests
  namespace: hashfoundry-testing
  labels:
    test-type: performance
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: k6-load-test
        image: grafana/k6:latest
        command: ["k6", "run"]
        args: 
        - "--out"
        - "json=/results/load-test-results.json"
        - "/scripts/load-test.js"
        env:
        - name: BASE_URL
          value: "http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000"
        - name: K6_PROMETHEUS_RW_SERVER_URL
          value: "http://prometheus.monitoring.svc.cluster.local:9090/api/v1/write"
        volumeMounts:
        - name: test-scripts
          mountPath: /scripts
        - name: test-results
          mountPath: /results
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      - name: k6-stress-test
        image: grafana/k6:latest
        command: ["k6", "run"]
        args:
        - "--out"
        - "json=/results/stress-test-results.json"
        - "/scripts/stress-test.js"
        env:
        - name: BASE_URL
          value: "http://hashfoundry-webapp.hashfoundry-testing.svc.cluster.local:3000"
        volumeMounts:
        - name: test-scripts
          mountPath: /scripts
        - name: test-results
          mountPath: /results
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      - name: results-processor
        image: hashfoundry/test-processor:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Waiting for performance tests to complete..."
          while [ ! -f /results/load-test-results.json ] || [ ! -f /results/stress-test-results.json ]; do
            sleep 10
          done
          
          echo "Processing performance test results..."
          
          # Parse and analyze results
          python3 /scripts/analyze-results.py \
            --load-test /results/load-test-results.json \
            --stress-test /results/stress-test-results.json \
            --output /results/performance-report.json
          
          # Send results to monitoring system
          curl -X POST "$METRICS_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d @/results/performance-report.json
        env:
        - name: METRICS_ENDPOINT
          valueFrom:
            secretKeyRef:
              name: test-webhooks
              key: performance-metrics-endpoint
        volumeMounts:
        - name: test-results
          mountPath: /results
        - name: analysis-scripts
          mountPath: /scripts
      volumes:
      - name: test-scripts
        configMap:
          name: k6-test-scripts
      - name: test-results
        emptyDir: {}
      - name: analysis-scripts
        configMap:
          name: performance-analysis-scripts
      activeDeadlineSeconds: 2400
  backoffLimit: 1
```

## 🔐 **Security Testing в Kubernetes:**

### **1. Container Image Security Scanning:**
```yaml
# k8s/testing/security-tests.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hashfoundry-security-scan
  namespace: hashfoundry-testing
  labels:
    test-type: security
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: trivy-scan
        image: aquasec/trivy:latest
        command: ["trivy"]
        args:
        - "image"
        - "--format"
        - "json"
        - "--output"
        - "/results/trivy-report.json"
        - "--severity"
        - "HIGH,CRITICAL"
        - "hashfoundry/webapp:latest"
        volumeMounts:
        - name: scan-results
          mountPath: /results
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      - name: grype-scan
        image: anchore/grype:latest
        command: ["grype"]
        args:
        - "-o"
        - "json"
        - "--file"
        - "/results/grype-report.json"
        - "hashfoundry/webapp:latest"
        volumeMounts:
        - name: scan-results
          mountPath: /results
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      - name: security-reporter
        image: hashfoundry/security-reporter:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Waiting for security scans to complete..."
          while [ ! -f /results/trivy-report.json ] || [ ! -f /results/grype-report.json ]; do
            sleep 5
          done
          
          echo "Processing security scan results..."
          python3 /scripts/process-security-results.py \
            --trivy /results/trivy-report.json \
            --grype /results/grype-report.json \
            --output /results/security-summary.json
          
          # Check for critical vulnerabilities
          CRITICAL_COUNT=$(jq '.summary.critical' /results/security-summary.json)
          HIGH_COUNT=$(jq '.summary.high' /results/security-summary.json)
          
          if [ "$CRITICAL_COUNT" -gt 0 ]; then
            echo "❌ Critical vulnerabilities found: $CRITICAL_COUNT"
            exit 1
          elif [ "$HIGH_COUNT" -gt 5 ]; then
            echo "⚠️ Too many high severity vulnerabilities: $HIGH_COUNT"
            exit 1
          else
            echo "✅ Security scan passed"
          fi
        volumeMounts:
        - name: scan-results
          mountPath: /results
        - name: security-scripts
          mountPath: /scripts
      volumes:
      - name: scan-results
        emptyDir: {}
      - name: security-scripts
        configMap:
          name: security-analysis-scripts
      activeDeadlineSeconds: 900
  backoffLimit: 1
```

### **2. Runtime Security Testing:**
```yaml
# k8s/testing/runtime-security-tests.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hashfoundry-runtime-security-tests
  namespace: hashfoundry-testing
  labels:
    test-type: runtime-security
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: falco-test
        image: falcosecurity/falco:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting Falco runtime security monitoring..."
          falco --daemon &
          FALCO_PID=$!
          
          # Wait for Falco to start
          sleep 10
          
          # Run test scenarios
          echo "Running security test scenarios..."
          
          # Test 1: Attempt to write to /etc (should trigger alert)
          kubectl run security-test-1 --rm -i --restart=Never --image=busybox -- \
            sh -c "echo 'test' > /etc/test-file" || true
          
          # Test 2: Attempt to access sensitive files
          kubectl run security-test-2 --rm -i --restart=Never --image=busybox -- \
            sh -c "cat /etc/passwd" || true
          
          # Test 3: Network scanning attempt
          kubectl run security-test-3 --rm -i --restart=Never --image=busybox -- \
            sh -c "nc -z kubernetes.default.svc.cluster.local 443" || true
          
          # Wait for alerts to be generated
          sleep 30
          
          # Stop Falco and collect results
          kill $FALCO_PID
          
          echo "Security tests completed"
        securityContext:
          privileged: true
        volumeMounts:
        - name: falco-config
          mountPath: /etc/falco
        - name: test-results
          mountPath: /results
      volumes:
      - name: falco-config
        configMap:
          name: falco-test-config
      - name: test-results
        emptyDir: {}
      activeDeadlineSeconds: 600
  backoffLimit: 1
```

## 🎪 **Advanced CI/CD Integration:**

### **1. GitHub Actions с полным набором тестов:**
```yaml
# .github/workflows/comprehensive-testing.yml
name: Comprehensive Testing Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: hashfoundry/webapp

jobs:
  # Unit Tests
  unit-tests:
    name: Unit Tests
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

    - name: Run unit tests
      run: npm run test:unit

    - name: Generate coverage report
      run: npm run test:coverage

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage/lcov.info

    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: unit-test-results
        path: test-results/

  # Integration Tests
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: hashfoundry_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
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

    - name: Run integration tests
      run: npm run test:integration
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/hashfoundry_test
        REDIS_URL: redis://localhost:6379

    - name: Upload integration test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: integration-test-results
        path: test-results/

  # Build and Security Scan
  build-and-scan:
    name: Build and Security Scan
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
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

    - name: Build and push Docker image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ steps.meta.outputs.tags }}
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  # Kubernetes Tests
  kubernetes-tests:
    name: Kubernetes Tests
    runs-on: ubuntu-latest
    needs: build-and-scan
    strategy:
      matrix:
        test-type: [unit, integration, e2e, performance]
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: '1.28.0'

    - name: Setup Kind
      uses: helm/kind-action@v1.8.0
      with:
        cluster_name: test-cluster-${{ matrix.test-type }}
        config: .github/kind-config.yaml

    - name: Deploy test infrastructure
      run: |
        # Create test namespace
        kubectl create namespace hashfoundry-testing
        
        # Deploy test dependencies
        kubectl apply -f k8s/testing/dependencies/
        
        # Wait for dependencies to be ready
        kubectl wait --for=condition=ready pod -l app=postgres-test -n hashfoundry-testing --timeout=300s
        kubectl wait --for=condition=ready pod -l app=redis-test -n hashfoundry-testing --timeout=300s

    - name: Deploy application
      run: |
        # Update image tag in manifests
        sed -i 's|hashfoundry/webapp:latest|${{ needs.build-and-scan.outputs.image-tag }}|g' k8s/testing/app/
        
        # Deploy application
        kubectl apply -f k8s/testing/app/
        
        # Wait for application to be ready
        kubectl wait --for=condition=ready pod -l app=hashfoundry-webapp -n hashfoundry-testing --timeout=600s

    - name: Run ${{ matrix.test-type }} tests
      run: |
        # Apply test job
        kubectl apply -f k8s/testing/${{ matrix.test-type }}-tests.yaml
        
        # Wait for test completion
        kubectl wait --for=condition=complete job/hashfoundry-${{ matrix.test-type }}-tests -n hashfoundry-testing --timeout=1800s

    - name: Collect test results
      if: always()
      run: |
        # Get test logs
        kubectl logs job/hashfoundry-${{ matrix.test-type }}-tests -n hashfoundry-testing > ${{ matrix.test-type }}-test-logs.txt
        
        # Extract test results if available
        kubectl cp hashfoundry-testing/$(kubectl get pods -n hashfoundry-testing -l job-name=hashfoundry-${{ matrix.test-type }}-tests -o jsonpath='{.items[0].metadata.name}'):/app/test-results ./test-results/ || true

    - name: Upload test artifacts
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: ${{ matrix.test-type }}-test-artifacts
        path: |
          ${{ matrix.test-type }}-test-logs.txt
          test-results/

  # Chaos Engineering Tests
  chaos-tests:
    name: Chaos Engineering Tests
    runs-on: ubuntu-latest
    needs: [build-and-scan, kubernetes-tests]
    if: github.ref == 'refs/heads/main'
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3

    - name: Setup Kind
      uses: helm/kind-action@v1.8.0
      with:
        cluster_name: chaos-test-cluster

    - name: Install Chaos Mesh
      run: |
        curl -sSL https://mirrors.chaos-mesh.org/v2.5.1/install.sh | bash
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=chaos-mesh -n chaos-mesh --timeout=300s

    - name: Deploy application for chaos testing
      run: |
        kubectl create namespace hashfoundry-chaos
        kubectl apply -f k8s/testing/chaos/ -n hashfoundry-chaos
        kubectl wait --for=condition=ready pod -l app=hashfoundry-webapp -n hashfoundry-chaos --timeout=600s

    - name: Run chaos experiments
      run: |
        # Pod failure experiment
        kubectl apply -f k8s/testing/chaos-experiments/pod-failure.yaml
        sleep 60
        
        # Network delay experiment
        kubectl apply -f k8s/testing/chaos-experiments/network-delay.yaml
        sleep 60
        
        # CPU stress experiment
        kubectl apply -f k8s/testing/chaos-experiments/cpu-stress.yaml
        sleep 60

    - name: Verify application resilience
      run: |
        # Check if application is still responsive
        kubectl run chaos-test --rm -i --restart=Never --image=busybox -- \
          wget -qO- --timeout=10 http://hashfoundry-webapp.hashfoundry-chaos.svc.cluster.local:3000/health

    - name: Cleanup chaos experiments
      if: always()
      run: |
        kubectl delete -f k8s/testing/chaos-experiments/ || true

  # Performance Baseline
  performance-baseline:
    name: Performance Baseline
    runs-on: ubuntu-latest
    needs: kubernetes-tests
    if: github.ref == 'refs/heads/main'
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3

    - name: Connect to staging cluster
      run: |
        echo "${{ secrets.KUBECONFIG_STAGING }}" | base64 -d > ~/.kube/config

    - name: Run performance baseline tests
      run: |
        kubectl apply -f k8s/testing/performance-baseline.yaml -n hashfoundry-staging
        kubectl wait --for=condition=complete job/performance-baseline -n hashfoundry-staging --timeout=1800s

    - name: Extract performance metrics
      run: |
        kubectl logs job/performance-baseline -n hashfoundry-staging > performance-baseline.log
        
        # Parse metrics and compare with previous baseline
        python3 .github/scripts/compare-performance.py \
          --current performance-baseline.log \
          --baseline performance-baseline-reference.json \
          --output performance-comparison.json

    - name: Comment performance results on PR
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          const comparison = JSON.parse(fs.readFileSync('performance-comparison.json', 'utf8'));
          
          const comment = `## 📊 Performance Test Results
          
          | Metric | Current | Baseline | Change |
          |--------|---------|----------|--------|
          | Response Time (p95) | ${comparison.current.p95}ms | ${comparison.baseline.p95}ms | ${comparison.change.p95} |
          | Throughput | ${comparison.current.rps} RPS | ${comparison.baseline.rps} RPS | ${comparison.change.rps} |
          | Error Rate | ${comparison.current.error_rate}% | ${comparison.baseline.error_rate}% | ${comparison.change.error_rate} |
          
          ${comparison.summary}`;
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: comment
          });

  # Test Report
  test-report:
    name: Generate Test Report
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests, kubernetes-tests, chaos-tests, performance-baseline]
    if: always()
    steps:
    - name: Download all test artifacts
      uses: actions/download-artifact@v3

    - name: Generate comprehensive test report
      run: |
        python3 .github/scripts/generate-test-report.py \
          --unit-tests unit-test-results/ \
          --integration-tests integration-test-results/ \
          --k8s-tests */test-artifacts/ \
          --output comprehensive-test-report.html

    - name: Upload test report
      uses: actions/upload-artifact@v3
      with:
        name: comprehensive-test-report
        path: comprehensive-test-report.html

    - name: Publish test results
      uses: dorny/test-reporter@v1
      if: always()
      with:
        name: Test Results
        path: '*/test-results/*.xml'
        reporter: java-junit
```

## 🎯 **Мониторинг и метрики тестирования:**

### **1. Test Metrics Dashboard:**
```yaml
# k8s/monitoring/test-metrics-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-metrics-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "HashFoundry Test Metrics",
        "panels": [
          {
            "title": "Test Success Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(test_runs_total{status=\"success\"}[5m]) / rate(test_runs_total[5m]) * 100",
                "legendFormat": "Success Rate %"
              }
            ]
          },
          {
            "title": "Test Duration",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, test_duration_seconds_bucket)",
                "legendFormat": "95th percentile"
              },
              {
                "expr": "histogram_quantile(0.50, test_duration_seconds_bucket)",
                "legendFormat": "50th percentile"
              }
            ]
          },
          {
            "title": "Test Coverage",
            "type": "gauge",
            "targets": [
              {
                "expr": "test_coverage_percentage",
                "legendFormat": "Coverage %"
              }
            ]
          }
        ]
      }
    }
```

### **2. Test Alerting Rules:**
```yaml
# k8s/monitoring/test-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alerts
  namespace: monitoring
spec:
  groups:
  - name: testing
    rules:
    - alert: TestJobFailed
      expr: kube_job_status_failed{job_name=~".*-tests"} > 0
      for: 1m
      labels:
        severity: critical
        component: testing
      annotations:
        summary: "Test job {{ $labels.job_name }} failed"
        description: "Test job {{ $labels.job_name }} in namespace {{ $labels.namespace }} has failed."
        runbook_url: "https://docs.hashfoundry.com/runbooks/test-job-failed"

    - alert: TestCoverageDropped
      expr: test_coverage_percentage < 80
      for: 5m
      labels:
        severity: warning
        component: testing
      annotations:
        summary: "Test coverage dropped below 80%"
        description: "Current test coverage is {{ $value }}%, which is below the 80% threshold."

    - alert: E2ETestsSlowResponse
      expr: histogram_quantile(0.95, test_duration_seconds_bucket{test_type="e2e"}) > 300
      for: 10m
      labels:
        severity: warning
        component: testing
      annotations:
        summary: "E2E tests are running slowly"
        description: "95th percentile of E2E test duration is {{ $value }}s, which exceeds the 300s threshold."

    - alert: PerformanceTestRegression
      expr: increase(performance_test_p95_response_time[1h]) > 100
      for: 5m
      labels:
        severity: warning
        component: performance
      annotations:
        summary: "Performance regression detected"
        description: "P95 response time increased by {{ $value }}ms in the last hour."
```

## 🎓 **Заключение:**

**Стратегии тестирования для Kubernetes приложений** требуют комплексного подхода, включающего:

### **🔑 Ключевые принципы:**
1. **Пирамида тестирования** - правильное распределение тестов по уровням
2. **Контейнеризация тестов** - выполнение тестов в Kubernetes Jobs
3. **Изоляция окружений** - отдельные namespace для каждого типа тестов
4. **Автоматизация** - интеграция всех тестов в CI/CD пайплайны
5. **Мониторинг качества** - отслеживание метрик тестирования
6. **Chaos Engineering** - тестирование устойчивости к сбоям

### **🛠️ Основные инструменты:**
- **Unit тесты** - Jest, Mocha, PyTest в контейнерах
- **Integration тесты** - Testcontainers, Docker Compose
- **Contract тесты** - Pact, Spring Cloud Contract
- **E2E тесты** - Playwright, Cypress, Selenium
- **Performance тесты** - K6, JMeter, Artillery
- **Security тесты** - Trivy, Grype, Falco
- **Chaos тесты** - Chaos Mesh, Litmus, Gremlin

### **📊 Мониторинг и метрики:**
- **Test success rate** - процент успешных тестов
- **Test duration** - время выполнения тестов
- **Code coverage** - покрытие кода тестами
- **Performance metrics** - метрики производительности
- **Security vulnerabilities** - количество уязвимостей

### **🎯 Основные команды для изучения в вашем HA кластере:**
```bash
# Анализ тестовых ресурсов
kubectl get jobs -A | grep -i test
kubectl get pods -A -l "helm.sh/hook=test"

# Проверка health checks
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].readinessProbe) | "\(.metadata.namespace)/\(.metadata.name)"'

# Тестирование сетевой связности
kubectl run network-test --rm -i --restart=Never --image=busybox -- wget -qO- http://argocd-server.argocd.svc.cluster.local/healthz

# Запуск Helm тестов
helm test argocd -n argocd

# Мониторинг тестов
kubectl get servicemonitors -A
kubectl get prometheusrules -A | grep test
```

### **🚀 Следующие шаги:**
1. Изучите существующие health checks в вашем HA кластере
2. Настройте базовые smoke тесты для критических сервисов
3. Внедрите автоматизированное тестирование в CI/CD пайплайны
4. Настройте мониторинг качества тестирования
5. Рассмотрите внедрение Chaos Engineering для тестирования устойчивости

**Помните:** Качественное тестирование - это инвестиция в надежность и стабильность ваших Kubernetes приложений!
