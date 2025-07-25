# 51. Что такое ConfigMaps и как их использовать?

## 🎯 **ConfigMaps в Kubernetes**

**ConfigMap** - это объект Kubernetes, который позволяет хранить конфигурационные данные в виде пар ключ-значение отдельно от кода приложения. Это обеспечивает гибкость в управлении конфигурациями и позволяет изменять настройки приложений без пересборки образов контейнеров.

## 🏗️ **Основные характеристики ConfigMaps:**

### **1. Назначение:**
- **Разделение конфигурации и кода**: Конфигурация хранится отдельно от приложения
- **Переносимость**: Одно приложение может использовать разные конфигурации в разных средах
- **Динамическое обновление**: Изменение конфигурации без пересборки образов
- **Централизованное управление**: Единое место для хранения настроек

### **2. Типы данных:**
- **Простые значения**: Строки, числа, булевы значения
- **Файлы конфигурации**: Целые конфигурационные файлы
- **Переменные окружения**: Наборы переменных для приложений
- **Командные аргументы**: Параметры для запуска приложений

### **3. Ограничения:**
- **Размер**: Максимум 1MB на ConfigMap
- **Безопасность**: Данные хранятся в открытом виде (не зашифрованы)
- **Namespace**: ConfigMap доступен только в своем namespace

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание простого ConfigMap:**
```bash
# Создать namespace для демонстрации
kubectl create namespace configmap-demo

# Создать ConfigMap с простыми значениями
kubectl create configmap app-config \
  --from-literal=database_host=postgres.example.com \
  --from-literal=database_port=5432 \
  --from-literal=database_name=myapp \
  --from-literal=log_level=info \
  --from-literal=debug_mode=false \
  -n configmap-demo

# Проверить созданный ConfigMap
kubectl get configmap app-config -n configmap-demo
kubectl describe configmap app-config -n configmap-demo

# Посмотреть содержимое в YAML формате
kubectl get configmap app-config -n configmap-demo -o yaml
```

### **2. Создание ConfigMap из файла:**
```bash
# Создать конфигурационный файл приложения
cat << EOF > app.properties
# Application Configuration
server.port=8080
server.host=0.0.0.0
database.url=jdbc:postgresql://postgres:5432/myapp
database.username=appuser
database.pool.min=5
database.pool.max=20
logging.level=INFO
logging.file=/var/log/app.log
cache.enabled=true
cache.ttl=3600
metrics.enabled=true
metrics.port=9090
EOF

# Создать ConfigMap из файла
kubectl create configmap app-properties \
  --from-file=app.properties \
  -n configmap-demo

# Проверить содержимое
kubectl get configmap app-properties -n configmap-demo -o yaml

# Создать несколько файлов конфигурации
mkdir config-files
cat << EOF > config-files/nginx.conf
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
    
    location /api {
        proxy_pass http://backend:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

cat << EOF > config-files/redis.conf
# Redis Configuration
port 6379
bind 0.0.0.0
timeout 300
tcp-keepalive 60
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
EOF

# Создать ConfigMap из директории
kubectl create configmap multi-config \
  --from-file=config-files/ \
  -n configmap-demo

# Проверить содержимое
kubectl describe configmap multi-config -n configmap-demo
```

### **3. Создание ConfigMap через YAML манифест:**
```bash
# Создать comprehensive ConfigMap через YAML
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: comprehensive-config
  namespace: configmap-demo
  labels:
    app: myapp
    environment: production
    version: "1.0"
data:
  # Простые конфигурационные значения
  database_host: "postgres.hashfoundry.local"
  database_port: "5432"
  database_name: "production_db"
  redis_host: "redis.hashfoundry.local"
  redis_port: "6379"
  log_level: "warn"
  debug_mode: "false"
  
  # JSON конфигурация
  features.json: |
    {
      "feature_flags": {
        "new_ui": true,
        "advanced_analytics": true,
        "beta_features": false
      },
      "limits": {
        "max_users": 10000,
        "max_requests_per_minute": 1000,
        "max_file_size_mb": 100
      }
    }
  
  # YAML конфигурация
  monitoring.yaml: |
    prometheus:
      enabled: true
      port: 9090
      scrape_interval: 30s
    grafana:
      enabled: true
      port: 3000
      admin_password: "admin123"
    alertmanager:
      enabled: true
      port: 9093
      webhook_url: "https://hooks.slack.com/services/..."
  
  # Конфигурация приложения
  application.conf: |
    # Application Settings
    app:
      name: "HashFoundry App"
      version: "1.0.0"
      environment: "production"
    
    server:
      port: 8080
      host: "0.0.0.0"
      threads: 10
    
    database:
      driver: "postgresql"
      host: "postgres.hashfoundry.local"
      port: 5432
      name: "production_db"
      ssl: true
      pool:
        min: 5
        max: 20
        timeout: 30
    
    cache:
      type: "redis"
      host: "redis.hashfoundry.local"
      port: 6379
      ttl: 3600
    
    logging:
      level: "warn"
      format: "json"
      output: "/var/log/app.log"
  
  # Shell script конфигурация
  startup.sh: |
    #!/bin/bash
    echo "Starting HashFoundry Application..."
    echo "Environment: production"
    echo "Database: postgres.hashfoundry.local:5432"
    
    # Проверить подключение к базе данных
    until pg_isready -h postgres.hashfoundry.local -p 5432; do
      echo "Waiting for database..."
      sleep 2
    done
    
    # Проверить подключение к Redis
    until redis-cli -h redis.hashfoundry.local -p 6379 ping; do
      echo "Waiting for Redis..."
      sleep 2
    done
    
    echo "All dependencies are ready. Starting application..."
    exec "$@"
EOF

# Проверить созданный ConfigMap
kubectl get configmap comprehensive-config -n configmap-demo -o yaml
```

## 🔧 **Способы использования ConfigMaps:**

### **1. Переменные окружения:**
```bash
# Создать Deployment, использующий ConfigMap как переменные окружения
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-env-vars
  namespace: configmap-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-with-env-vars
  template:
    metadata:
      labels:
        app: app-with-env-vars
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        # Отдельные переменные из ConfigMap
        - name: DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_host
        - name: DATABASE_PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_port
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: log_level
        # Все переменные из ConfigMap
        envFrom:
        - configMapRef:
            name: comprehensive-config
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

# Проверить переменные окружения в Pod'е
kubectl get pods -n configmap-demo -l app=app-with-env-vars
POD_NAME=$(kubectl get pods -n configmap-demo -l app=app-with-env-vars -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -n configmap-demo -- env | grep -E "(DATABASE|LOG_LEVEL)"
```

### **2. Монтирование как файлы:**
```bash
# Создать Deployment с монтированием ConfigMap как файлов
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-config-files
  namespace: configmap-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-config-files
  template:
    metadata:
      labels:
        app: app-with-config-files
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        # Монтировать весь ConfigMap
        - name: app-config-volume
          mountPath: /etc/config
          readOnly: true
        # Монтировать конкретный файл
        - name: nginx-config-volume
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
          readOnly: true
        # Монтировать startup script
        - name: startup-script-volume
          mountPath: /usr/local/bin/startup.sh
          subPath: startup.sh
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        command: ["/bin/bash"]
        args: ["-c", "chmod +x /usr/local/bin/startup.sh && /usr/local/bin/startup.sh nginx -g 'daemon off;'"]
      volumes:
      # Весь ConfigMap как volume
      - name: app-config-volume
        configMap:
          name: comprehensive-config
      # Конкретный файл из ConfigMap
      - name: nginx-config-volume
        configMap:
          name: multi-config
          items:
          - key: nginx.conf
            path: nginx.conf
      # Startup script с правами выполнения
      - name: startup-script-volume
        configMap:
          name: comprehensive-config
          items:
          - key: startup.sh
            path: startup.sh
            mode: 0755
EOF

# Проверить монтированные файлы
kubectl get pods -n configmap-demo -l app=app-with-config-files
POD_NAME=$(kubectl get pods -n configmap-demo -l app=app-with-config-files -o jsonpath='{.items[0].metadata.name}')

echo "=== Checking mounted config files ==="
kubectl exec $POD_NAME -n configmap-demo -- ls -la /etc/config/
kubectl exec $POD_NAME -n configmap-demo -- cat /etc/config/application.conf
kubectl exec $POD_NAME -n configmap-demo -- cat /etc/nginx/conf.d/default.conf
```

### **3. Использование в командных аргументах:**
```bash
# Создать Pod с аргументами из ConfigMap
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app-with-args
  namespace: configmap-demo
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["sh", "-c"]
    args:
    - |
      echo "Starting application with configuration:"
      echo "Database Host: \$(DATABASE_HOST)"
      echo "Database Port: \$(DATABASE_PORT)"
      echo "Log Level: \$(LOG_LEVEL)"
      echo "Debug Mode: \$(DEBUG_MODE)"
      echo ""
      echo "Configuration files:"
      ls -la /etc/config/
      echo ""
      echo "Application config:"
      cat /etc/config/application.conf
      echo ""
      echo "Keeping container running..."
      while true; do sleep 30; done
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_port
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log_level
    - name: DEBUG_MODE
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: debug_mode
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  volumes:
  - name: config-volume
    configMap:
      name: comprehensive-config
  restartPolicy: Never
EOF

# Проверить логи Pod'а
kubectl logs app-with-args -n configmap-demo
```

## 🔧 **Advanced техники работы с ConfigMaps:**

### **1. Динамическое обновление конфигурации:**
```bash
# Создать приложение, которое отслеживает изменения ConfigMap
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-watcher
  namespace: configmap-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-watcher
  template:
    metadata:
      labels:
        app: config-watcher
    spec:
      containers:
      - name: watcher
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting config watcher..."
          while true; do
            echo "=== $(date) ==="
            echo "Current configuration:"
            cat /etc/config/application.conf | head -10
            echo "---"
            echo "Environment variables:"
            env | grep -E "(DATABASE|LOG_LEVEL)" | sort
            echo "===================="
            sleep 30
          done
        env:
        - name: DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_host
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: log_level
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
          readOnly: true
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
      volumes:
      - name: config-volume
        configMap:
          name: comprehensive-config
EOF

# Проверить начальные логи
kubectl logs -f deployment/config-watcher -n configmap-demo &
LOGS_PID=$!

# Обновить ConfigMap
echo "=== Updating ConfigMap ==="
kubectl patch configmap app-config -n configmap-demo --type merge -p='{"data":{"log_level":"debug","database_host":"postgres-updated.hashfoundry.local"}}'

# Обновить файл в ConfigMap
kubectl patch configmap comprehensive-config -n configmap-demo --type merge -p='{"data":{"application.conf":"# Updated Application Settings\napp:\n  name: \"HashFoundry App Updated\"\n  version: \"1.1.0\"\n  environment: \"production\"\n\nserver:\n  port: 8080\n  host: \"0.0.0.0\"\n  threads: 20\n"}}'

# Подождать и проверить изменения
sleep 60
kill $LOGS_PID

echo "=== Checking updated configuration ==="
POD_NAME=$(kubectl get pods -n configmap-demo -l app=config-watcher -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -n configmap-demo -- env | grep -E "(DATABASE|LOG_LEVEL)"
kubectl exec $POD_NAME -n configmap-demo -- cat /etc/config/application.conf
```

### **2. ConfigMap с различными форматами данных:**
```bash
# Создать ConfigMap с различными форматами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-format-config
  namespace: configmap-demo
data:
  # Properties файл
  database.properties: |
    jdbc.driver=org.postgresql.Driver
    jdbc.url=jdbc:postgresql://postgres:5432/myapp
    jdbc.username=appuser
    jdbc.password=secret123
    connection.pool.size=10
    connection.timeout=30000
  
  # XML конфигурация
  logging.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
        <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <appender name="FILE" class="ch.qos.logback.core.FileAppender">
            <file>/var/log/application.log</file>
            <encoder>
                <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="STDOUT" />
            <appender-ref ref="FILE" />
        </root>
    </configuration>
  
  # TOML конфигурация
  app.toml: |
    [server]
    host = "0.0.0.0"
    port = 8080
    workers = 4
    
    [database]
    host = "postgres"
    port = 5432
    name = "myapp"
    user = "appuser"
    password = "secret123"
    
    [redis]
    host = "redis"
    port = 6379
    db = 0
    
    [logging]
    level = "info"
    format = "json"
    file = "/var/log/app.log"
  
  # INI файл
  config.ini: |
    [DEFAULT]
    debug = false
    environment = production
    
    [database]
    host = postgres
    port = 5432
    name = myapp
    user = appuser
    password = secret123
    
    [cache]
    type = redis
    host = redis
    port = 6379
    ttl = 3600
    
    [logging]
    level = info
    file = /var/log/app.log
  
  # Простые переменные
  simple_vars: |
    API_KEY=abc123def456
    SECRET_TOKEN=xyz789uvw012
    MAX_CONNECTIONS=100
    TIMEOUT=30
    RETRY_COUNT=3
EOF

# Создать Pod для тестирования различных форматов
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-format-test
  namespace: configmap-demo
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ["sh", "-c"]
    args:
    - |
      echo "=== Testing different config formats ==="
      echo ""
      echo "Properties file:"
      cat /etc/config/database.properties
      echo ""
      echo "XML file:"
      cat /etc/config/logging.xml
      echo ""
      echo "TOML file:"
      cat /etc/config/app.toml
      echo ""
      echo "INI file:"
      cat /etc/config/config.ini
      echo ""
      echo "Simple variables:"
      cat /etc/config/simple_vars
      echo ""
      echo "Keeping container running..."
      while true; do sleep 30; done
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  volumes:
  - name: config-volume
    configMap:
      name: multi-format-config
  restartPolicy: Never
EOF

# Проверить различные форматы
kubectl logs multi-format-test -n configmap-demo
```

### **3. ConfigMap с условной конфигурацией:**
```bash
# Создать ConfigMap для разных сред
for env in development staging production; do
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-${env}
  namespace: configmap-demo
  labels:
    environment: ${env}
data:
  environment: "${env}"
  database_host: "postgres-${env}.hashfoundry.local"
  database_name: "myapp_${env}"
  log_level: "$([ "$env" = "production" ] && echo "warn" || echo "debug")"
  debug_mode: "$([ "$env" = "production" ] && echo "false" || echo "true")"
  replicas: "$([ "$env" = "production" ] && echo "3" || echo "1")"
  resources_cpu: "$([ "$env" = "production" ] && echo "500m" || echo "100m")"
  resources_memory: "$([ "$env" = "production" ] && echo "512Mi" || echo "128Mi")"
  
  application.yaml: |
    app:
      name: "HashFoundry App"
      environment: "${env}"
      debug: $([ "$env" = "production" ] && echo "false" || echo "true")
    
    server:
      port: 8080
      workers: $([ "$env" = "production" ] && echo "10" || echo "2")
    
    database:
      host: "postgres-${env}.hashfoundry.local"
      port: 5432
      name: "myapp_${env}"
      ssl: $([ "$env" = "production" ] && echo "true" || echo "false")
    
    logging:
      level: "$([ "$env" = "production" ] && echo "warn" || echo "debug")"
      console: $([ "$env" = "production" ] && echo "false" || echo "true")
    
    monitoring:
      enabled: $([ "$env" = "production" ] && echo "true" || echo "false")
      metrics_port: 9090
EOF
done

# Создать Deployment, использующий конфигурацию для конкретной среды
ENVIRONMENT="production"  # Можно изменить на development или staging

cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-${ENVIRONMENT}
  namespace: configmap-demo
  labels:
    environment: ${ENVIRONMENT}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      environment: ${ENVIRONMENT}
  template:
    metadata:
      labels:
        app: myapp
        environment: ${ENVIRONMENT}
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 8080
        env:
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: app-config-${ENVIRONMENT}
              key: environment
        - name: DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config-${ENVIRONMENT}
              key: database_host
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config-${ENVIRONMENT}
              key: log_level
        - name: DEBUG_MODE
          valueFrom:
            configMapKeyRef:
              name: app-config-${ENVIRONMENT}
              key: debug_mode
        volumeMounts:
        - name: config-volume
          mountPath: /etc/app
          readOnly: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: config-volume
        configMap:
          name: app-config-${ENVIRONMENT}
EOF

# Проверить конфигурацию для выбранной среды
kubectl get configmaps -n configmap-demo -l environment=${ENVIRONMENT}
kubectl describe configmap app-config-${ENVIRONMENT} -n configmap-demo
```

## 🧪 **Тестирование и валидация ConfigMaps:**

### **1. Создание тестового скрипта:**
```bash
# Создать comprehensive тест ConfigMaps
cat << 'EOF' > test-configmaps.sh
#!/bin/bash

NAMESPACE="configmap-demo"

echo "=== ConfigMap Testing Suite ==="
echo

# Тест 1: Проверка создания ConfigMaps
test_configmap_creation() {
    echo "=== Test 1: ConfigMap Creation ==="
    
    # Проверить все ConfigMaps
    echo "Available ConfigMaps:"
    kubectl get configmaps -n $NAMESPACE -o custom-columns="NAME:.metadata.name,DATA-KEYS:.data" --no-headers
    
    # Проверить размеры ConfigMaps
    echo ""
    echo "ConfigMap sizes:"
    for cm in $(kubectl get configmaps -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        size=$(kubectl get configmap $cm -n $NAMESPACE -o jsonpath='{.data}' | wc -c)
        echo "  $cm: ${size} bytes"
    done
    echo
}

# Тест 2: Проверка монтирования
test_configmap_mounting() {
    echo "=== Test 2: ConfigMap Mounting ==="
    
    # Проверить Pod'ы с монтированными ConfigMaps
    for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Pod: $pod"
        echo "  Mounted volumes:"
        kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.volumes[*].name}' | tr ' ' '\n' | sed 's/^/    /'
        
        echo "  Environment variables from ConfigMaps:"
        kubectl exec $pod -n $NAMESPACE -- env 2>/dev/null | grep -E "(DATABASE|LOG_LEVEL|ENVIRONMENT)" | sed 's/^/    /' || echo "    No relevant env vars found"
        echo
    done
}

# Тест 3: Проверка обновлений
test_configmap_updates() {
    echo "=== Test 3: ConfigMap Updates ==="
    
    # Создать тестовый ConfigMap
    kubectl create configmap test-update \
        --from-literal=version=1.0 \
        --from-literal=message="Original message" \
        -n $NAMESPACE
    
    echo "Original ConfigMap:"
    kubectl get configmap test-update -n $NAMESPACE -o jsonpath='{.data}' | jq '.'
    
    # Обновить ConfigMap
    kubectl patch configmap test-update -n $NAMESPACE --type merge -p='{"data":{"version":"2.0","message":"Updated message","new_key":"new_value"}}'
    
    echo "Updated ConfigMap:"
    kubectl get configmap test-update -n $NAMESPACE -o jsonpath='{.data}' | jq '.'
    
    # Очистить тестовый ConfigMap
    kubectl delete configmap test-update -n $NAMESPACE
    echo
}

# Тест 4: Проверка валидности данных
test_configmap_validation() {
    echo "=== Test 4: ConfigMap Validation ==="
    
    # Проверить JSON файлы
    for cm in $(kubectl get configmaps -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Validating ConfigMap: $cm"
        
        # Получить все ключи
        keys=$(kubectl get configmap $cm -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "")
        
        for key in $keys; do
            if [[ "$key" == *.json ]]; then
                echo "  Validating JSON file: $key"
                kubectl get configmap $cm -n $NAMESPACE -o jsonpath="{.data['$key']}" | jq . >/dev/null 2>&1 && echo "    ✅ Valid JSON" || echo "    ❌ Invalid JSON"
            elif [[ "$key" == *.yaml ]] || [[ "$key" == *.yml ]]; then
                echo "  Validating YAML file: $key"
                kubectl get configmap $cm -n $NAMESPACE -o jsonpath="{.data['$key']}" | yq . >/dev/null 2>&1 && echo "    ✅ Valid YAML" || echo "    ❌ Invalid YAML"
            fi
        done
        echo
    done
}

# Выполнить все тесты
test_configmap_creation
test_configmap_mounting
test_configmap_updates
test_configmap_validation

echo "=== Testing Complete ==="
EOF

chmod +x test-configmaps.sh
./test-configmaps.sh
```

### **2. Мониторинг использования ConfigMaps:**
```bash
# Создать скрипт для мониторинга ConfigMaps
cat << 'EOF' > monitor-configmaps.sh
#!/bin/bash

NAMESPACE="configmap-demo"

echo "=== ConfigMap Monitoring ==="
echo

# Функция для мониторинга использования
monitor_usage() {
    echo "=== ConfigMap Usage Report ==="
    echo "$(date)"
    echo
    
    # Общая статистика
    total_configmaps=$(kubectl get configmaps -n $NAMESPACE --no-headers | wc -l)
    echo "Total ConfigMaps: $total_configmaps"
    
    # Размеры ConfigMaps
    echo ""
    echo "ConfigMap sizes:"
    printf "%-30s | %-10s | %-15s\n" "NAME" "SIZE" "KEYS"
    printf "%-30s | %-10s | %-15s\n" "$(printf '%*s' 30 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')"
    
    for cm in $(kubectl get configmaps -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        size=$(kubectl get configmap $cm -n $NAMESPACE -o jsonpath='{.data}' | wc -c)
        keys=$(kubectl get configmap $cm -n $NAMESPACE -o jsonpath='{.data}' | jq 'keys | length' 2>/dev/null || echo "0")
        printf "%-30s | %-10s | %-15s\n" "$cm" "${size}B" "$keys"
    done
    
    # Использование в Pod'ах
    echo ""
    echo "ConfigMap usage in Pods:"
    for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
        echo "Pod: $pod"
        
        # Env vars from ConfigMaps
        env_cms=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[*].env[?(@.valueFrom.configMapKeyRef)].valueFrom.configMapKeyRef.name}' | tr ' ' '\n' | sort -u)
        if [ -n "$env_cms" ]; then
            echo "  Environment variables from:"
            echo "$env_cms" | sed 's/^/    /'
        fi
        
        # EnvFrom ConfigMaps
        envfrom_cms=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[*].envFrom[?(@.configMapRef)].configMapRef.name}' | tr ' ' '\n' | sort -u)
        if [ -n "$envfrom_cms" ]; then
            echo "  All env vars from:"
            echo "$envfrom_cms" | sed 's/^/    /'
        fi
        
        # Volume mounts
        volume_cms=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.volumes[?(@.configMap)].configMap.name}' | tr ' ' '\n' | sort -u)
        if [ -n "$volume_cms" ]; then
            echo "  Volume mounts from:"
            echo "$volume_cms" | sed 's/^/    /'
        fi
        echo
    done
}

# Запустить мониторинг
monitor_usage
EOF

chmod +x monitor-configmaps.sh
./monitor-configmaps.sh
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все ресурсы ConfigMap демонстрации
kubectl delete namespace configmap-demo

# Удалить созданные файлы
rm -f app.properties config-files/nginx.conf config-files/redis.conf
rmdir config-files 2>/dev/null || true
rm -f test-configmaps.sh monitor-configmaps.sh
```

## 📋 **Сводка команд для ConfigMaps:**

### **Основные команды:**
```bash
# Создать ConfigMap из литералов
kubectl create configmap myconfig --from-literal=key1=value1 --from-literal=key2=value2

# Создать ConfigMap из файла
kubectl create configmap myconfig --from-file=config.properties

# Создать ConfigMap из директории
kubectl create configmap myconfig --from-file=config-dir/

# Проверить ConfigMap
kubectl get configmap myconfig
kubectl describe configmap myconfig
kubectl get configmap myconfig -o yaml

# Обновить ConfigMap
kubectl patch configmap myconfig --type merge -p='{"data":{"key1":"new-value"}}'

# Удалить ConfigMap
kubectl delete configmap myconfig
```

### **Advanced команды:**
```bash
# Создать ConfigMap с метками
kubectl create configmap myconfig --from-literal=key=value
kubectl label configmap myconfig environment=production

# Экспортировать ConfigMap
kubectl get configmap myconfig -o yaml > myconfig.yaml

# Применить ConfigMap из файла
kubectl apply -f myconfig.yaml

# Проверить использование ConfigMap
kubectl get pods -o jsonpath='{.items[*].spec.volumes[?(@.configMap)].configMap.name}'
```

## 🎯 **Best Practices для ConfigMaps:**

### **1. Организация конфигураций:**
- **Группируйте** связанные настройки в один ConfigMap
- **Используйте понятные имена** для ключей и ConfigMaps
- **Разделяйте** конфигурации по средам (dev, staging, prod)
- **Версионируйте** ConfigMaps при критических изменениях

### **2. Безопасность:**
- **Не храните секретные данные** в ConfigMaps (используйте Secrets)
- **Ограничивайте доступ** через RBAC
- **Проверяйте содержимое** перед применением
- **Используйте namespace** для изоляции

### **3. Управление изменениями:**
- **Тестируйте изменения** в staging среде
- **Используйте rolling updates** для применения изменений
- **Мониторьте** приложения после обновления конфигурации
- **Имейте план отката** для критических изменений

### **4. Производительность:**
- **Ограничивайте размер** ConfigMaps (максимум 1MB)
- **Избегайте частых обновлений** больших ConfigMaps
- **Используйте subPath** для монтирования отдельных файлов
- **Кэшируйте** конфигурации в приложениях при необходимости

**ConfigMaps являются основным инструментом для управления конфигурациями в Kubernetes, обеспечивая гибкость и разделение кода от настроек!**
