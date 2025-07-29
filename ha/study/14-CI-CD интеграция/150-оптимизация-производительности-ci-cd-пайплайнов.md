# 150. Оптимизация производительности CI/CD пайплайнов

## 🎯 **Основные концепции:**

| Аспект | Неоптимизированный подход | Оптимизированный подход |
|--------|---------------------------|-------------------------|
| **Сборка образов** | Последовательная сборка | Параллельная + многоэтапная сборка |
| **Кэширование** | Без кэша | Агрессивное кэширование зависимостей |
| **Тестирование** | Последовательные тесты | Параллельные тесты по группам |
| **Развертывание** | Полная пересборка | Инкрементальные обновления |
| **Ресурсы** | Фиксированные ресурсы | Динамическое масштабирование |
| **Артефакты** | Повторная сборка | Переиспользование артефактов |
| **Зависимости** | Загрузка каждый раз | Кэширование и версионирование |
| **Образы Docker** | Большие образы | Минимальные оптимизированные образы |
| **Мониторинг** | Базовые метрики | Детальная аналитика производительности |
| **Стратегия** | Монолитные пайплайны | Модульные микро-пайплайны |

## 🏆 **Оптимизация CI/CD - что это такое?**

**Оптимизация производительности CI/CD пайплайнов** — это комплексный подход к ускорению процессов непрерывной интеграции и доставки через применение техник кэширования, параллелизации, оптимизации ресурсов и устранения узких мест, что приводит к сокращению времени от коммита до продакшена и повышению эффективности команды разработки.

### **Ключевые области оптимизации:**
1. **Build Optimization** - ускорение процесса сборки
2. **Test Optimization** - параллелизация и оптимизация тестов
3. **Caching Strategies** - эффективное кэширование
4. **Resource Management** - оптимальное использование ресурсов
5. **Pipeline Architecture** - модульная архитектура пайплайнов
6. **Artifact Management** - управление артефактами

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущей производительности ArgoCD:**
```bash
# Проверка времени синхронизации ArgoCD приложений
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,LAST_SYNC:.status.operationState.finishedAt

# Анализ ресурсов ArgoCD
kubectl top pods -n argocd

# Проверка истории операций ArgoCD
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.operationState.operation.sync.revision}{"\t"}{.status.operationState.finishedAt}{"\n"}{end}'

# Мониторинг времени развертывания
kubectl get events -n argocd --sort-by='.lastTimestamp' | grep -E "Sync|Deploy" | tail -20
```

### **2. Анализ производительности кластера:**
```bash
# Проверка использования ресурсов узлов
kubectl top nodes

# Анализ времени запуска подов
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,AGE:.metadata.creationTimestamp,STATUS:.status.phase

# Проверка времени скачивания образов
kubectl describe pods -n argocd | grep -A 5 -B 5 "Pulling\|Pulled"

# Мониторинг сетевой производительности
kubectl get pods -n argocd -o wide
```

### **3. Анализ Helm развертываний:**
```bash
# Проверка времени Helm операций
helm list --all-namespaces -o json | jq '.[] | {name: .name, namespace: .namespace, updated: .updated, status: .status}'

# Анализ размеров Helm чартов
find ha/k8s/addons -name "*.yaml" -exec wc -l {} + | sort -n

# Проверка кэша Helm
helm repo list
```

### 🚀 Оптимизация Docker образов

#### 1. **Многоэтапная сборка**
```dockerfile
# Оптимизированный Dockerfile
# Этап 1: Сборка
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

# Этап 2: Продакшен
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### 2. **Оптимизация слоев**
```dockerfile
# ❌ Неэффективно - каждая команда создает слой
FROM node:18-alpine
RUN apk add --no-cache git
RUN apk add --no-cache python3
RUN apk add --no-cache make
RUN apk add --no-cache g++

# ✅ Эффективно - объединение команд
FROM node:18-alpine
RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*
```

### 📊 Примеры из нашего кластера

#### Анализ времени сборки образов:
```bash
docker history myapp:latest --format "table {{.CreatedBy}}\t{{.Size}}"
```

#### Мониторинг ресурсов во время сборки:
```bash
kubectl top pods -n jenkins
```

#### Проверка кэша Docker:
```bash
docker system df
```

### 🎯 Кэширование зависимостей

#### 1. **GitHub Actions кэширование**
```yaml
# .github/workflows/optimized-build.yml
name: Optimized Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    # Кэширование Node.js зависимостей
    - name: Cache Node modules
      uses: actions/cache@v3
      with:
        path: ~/.npm
        key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
        restore-keys: |
          ${{ runner.os }}-node-
    
    # Кэширование Docker слоев
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: myregistry/myapp:${{ github.sha }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
    
    # Кэширование тестовых данных
    - name: Cache test data
      uses: actions/cache@v3
      with:
        path: test-data/
        key: test-data-${{ hashFiles('test-data/**') }}
```

#### 2. **Jenkins кэширование**
```groovy
// Jenkinsfile с кэшированием
pipeline {
    agent any
    
    stages {
        stage('Cache Dependencies') {
            steps {
                script {
                    // Кэширование npm зависимостей
                    def cacheKey = sh(
                        script: "sha256sum package-lock.json | cut -d' ' -f1",
                        returnStdout: true
                    ).trim()
                    
                    if (fileExists("cache/node_modules_${cacheKey}.tar.gz")) {
                        echo "Восстановление кэша зависимостей..."
                        sh "tar -xzf cache/node_modules_${cacheKey}.tar.gz"
                    } else {
                        echo "Установка зависимостей..."
                        sh "npm ci"
                        sh "mkdir -p cache"
                        sh "tar -czf cache/node_modules_${cacheKey}.tar.gz node_modules/"
                    }
                }
            }
        }
        
        stage('Build with Cache') {
            steps {
                sh '''
                    # Использование BuildKit для кэширования Docker
                    export DOCKER_BUILDKIT=1
                    docker build \
                      --cache-from myregistry/myapp:cache \
                      --tag myregistry/myapp:${BUILD_NUMBER} \
                      --tag myregistry/myapp:cache \
                      .
                '''
            }
        }
    }
}
```

### 🔄 Параллелизация задач

#### 1. **Параллельные тесты**
```yaml
# .github/workflows/parallel-tests.yml
name: Parallel Tests

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        test-group: [unit, integration, e2e]
        node-version: [16, 18, 20]
    steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: npm run test:${{ matrix.test-group }}
```

#### 2. **Параллельная сборка компонентов**
```yaml
# docker-compose.build.yml для параллельной сборки
version: '3.8'
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    image: myregistry/frontend:${TAG}
  
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    image: myregistry/backend:${TAG}
  
  worker:
    build:
      context: ./worker
      dockerfile: Dockerfile
    image: myregistry/worker:${TAG}
```

```bash
#!/bin/bash
# parallel-build.sh

echo "🚀 Параллельная сборка компонентов..."

# Сборка всех сервисов параллельно
docker-compose -f docker-compose.build.yml build --parallel

# Пуш образов параллельно
docker-compose -f docker-compose.build.yml push &
PUSH_PID=$!

# Ожидание завершения
wait $PUSH_PID

echo "✅ Параллельная сборка завершена"
```

### 🎪 Оптимизация Kubernetes развертываний

#### 1. **Быстрые развертывания**
```yaml
# fast-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fast-app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 2  # Быстрое масштабирование
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5  # Быстрая готовность
          periodSeconds: 2
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

#### 2. **Предварительное скачивание образов**
```yaml
# image-puller-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-puller
spec:
  selector:
    matchLabels:
      app: image-puller
  template:
    metadata:
      labels:
        app: image-puller
    spec:
      initContainers:
      - name: pull-images
        image: docker:dind
        command:
        - sh
        - -c
        - |
          docker pull myregistry/myapp:latest
          docker pull myregistry/worker:latest
          docker pull nginx:alpine
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
      containers:
      - name: sleep
        image: alpine
        command: ["sleep", "infinity"]
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
```

### 📈 Мониторинг производительности

#### 1. **Метрики пайплайна**
```javascript
// pipeline-metrics.js
const prometheus = require('prom-client');

// Метрики времени выполнения
const pipelineDuration = new prometheus.Histogram({
  name: 'pipeline_duration_seconds',
  help: 'Pipeline execution duration',
  labelNames: ['pipeline', 'stage', 'status'],
  buckets: [10, 30, 60, 120, 300, 600, 1200]
});

// Метрики использования ресурсов
const resourceUsage = new prometheus.Gauge({
  name: 'pipeline_resource_usage',
  help: 'Pipeline resource usage',
  labelNames: ['pipeline', 'resource_type']
});

// Функция для записи метрик
function recordPipelineMetrics(pipeline, stage, duration, status) {
  pipelineDuration
    .labels(pipeline, stage, status)
    .observe(duration);
}

// Экспорт метрик
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});
```

#### 2. **Dashboard производительности**
```json
{
  "dashboard": {
    "title": "CI/CD Performance",
    "panels": [
      {
        "title": "Pipeline Duration Trend",
        "type": "graph",
        "targets": [
          {
            "expr": "avg(pipeline_duration_seconds) by (pipeline)"
          }
        ]
      },
      {
        "title": "Build Cache Hit Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(build_cache_hits_total[5m]) / rate(build_cache_requests_total[5m]) * 100"
          }
        ]
      },
      {
        "title": "Resource Utilization",
        "type": "graph",
        "targets": [
          {
            "expr": "pipeline_resource_usage{resource_type=\"cpu\"}"
          },
          {
            "expr": "pipeline_resource_usage{resource_type=\"memory\"}"
          }
        ]
      }
    ]
  }
}
```

### 🔧 Инструменты оптимизации

#### 1. **Анализ размера образов**
```bash
#!/bin/bash
# analyze-image-size.sh

IMAGE="$1"

echo "📊 Анализ размера образа: $IMAGE"

# Размер образа
echo "Общий размер:"
docker images $IMAGE --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Анализ слоев
echo -e "\n📋 Анализ слоев:"
docker history $IMAGE --format "table {{.CreatedBy}}\t{{.Size}}" --no-trunc

# Поиск больших файлов
echo -e "\n🔍 Большие файлы в образе:"
docker run --rm $IMAGE find / -type f -size +10M 2>/dev/null | head -10

# Анализ с dive (если установлен)
if command -v dive &> /dev/null; then
    echo -e "\n🏗️ Запуск dive для детального анализа..."
    dive $IMAGE
fi
```

#### 2. **Профилирование сборки**
```bash
#!/bin/bash
# profile-build.sh

echo "⏱️ Профилирование сборки..."

# Включение BuildKit для детальных логов
export DOCKER_BUILDKIT=1

# Сборка с профилированием
docker build \
  --progress=plain \
  --no-cache \
  -t myapp:profile \
  . 2>&1 | tee build.log

# Анализ времени выполнения каждого шага
echo -e "\n📊 Анализ времени выполнения:"
grep -E "^\#[0-9]+" build.log | \
  awk '{print $1, $2, $3}' | \
  sort -k3 -nr | \
  head -10
```

### 🎯 Лучшие практики оптимизации

#### 1. **Стратегии кэширования**
```yaml
# Эффективное кэширование в CI/CD
caching_strategies:
  dependencies:
    - npm_modules: "package-lock.json hash"
    - maven_deps: "pom.xml hash"
    - pip_packages: "requirements.txt hash"
  
  build_artifacts:
    - compiled_code: "source code hash"
    - test_results: "test files hash"
    - docker_layers: "Dockerfile + context hash"
  
  infrastructure:
    - terraform_state: "tf files hash"
    - helm_charts: "Chart.yaml + values hash"
```

#### 2. **Автоматизация оптимизации**
```bash
#!/bin/bash
# auto-optimize.sh

echo "🔧 Автоматическая оптимизация пайплайна..."

# Очистка старых кэшей
find cache/ -type f -mtime +7 -delete

# Оптимизация Docker образов
docker system prune -f
docker builder prune -f

# Анализ и оптимизация Dockerfile
if command -v hadolint &> /dev/null; then
    hadolint Dockerfile
fi

# Проверка размеров образов
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | \
  sort -k3 -hr | head -10

echo "✅ Оптимизация завершена"
```

### 📋 Чек-лист оптимизации

#### 1. **Docker оптимизация**
- ✅ **Используйте многоэтапную сборку** для уменьшения размера
- ✅ **Объединяйте RUN команды** для минимизации слоев
- ✅ **Используйте .dockerignore** для исключения ненужных файлов
- ✅ **Выбирайте минимальные базовые образы** (alpine, distroless)
- ✅ **Кэшируйте зависимости** отдельно от кода приложения

#### 2. **CI/CD оптимизация**
- ✅ **Параллелизируйте независимые задачи**
- ✅ **Используйте кэширование** для зависимостей и артефактов
- ✅ **Оптимизируйте тесты** (быстрые тесты первыми)
- ✅ **Используйте инкрементальную сборку**
- ✅ **Мониторьте производительность** пайплайнов

#### 3. **Kubernetes оптимизация**
- ✅ **Настройте resource requests/limits**
- ✅ **Используйте readiness/liveness probes**
- ✅ **Оптимизируйте стратегии развертывания**
- ✅ **Предварительно скачивайте образы**
- ✅ **Используйте HPA для автомасштабирования**

Оптимизация производительности CI/CD пайплайнов требует постоянного мониторинга, анализа узких мест и применения лучших практик для достижения быстрой и надежной доставки.
