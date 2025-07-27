# 52. Какие существуют способы создания ConfigMaps?

## 🎯 **Способы создания ConfigMaps в Kubernetes**

**ConfigMaps** можно создавать различными способами в зависимости от источника данных и требований. Каждый способ имеет свои преимущества и подходит для определенных сценариев использования.

## 🏗️ **Основные способы создания ConfigMaps:**

### **1. Из литералов (--from-literal)**
### **2. Из файлов (--from-file)**
### **3. Из директорий (--from-file=directory)**
### **4. Через YAML/JSON манифесты**
### **5. Из переменных окружения (--from-env-file)**
### **6. Программно через API**
### **7. Через Helm и Kustomize**

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание из литералов (--from-literal):**
```bash
# Создать namespace для демонстрации
kubectl create namespace configmap-methods-demo

# Простой ConfigMap из литералов
kubectl create configmap basic-config \
  --from-literal=app_name="HashFoundry App" \
  --from-literal=version="1.0.0" \
  --from-literal=environment="production" \
  --from-literal=debug="false" \
  -n configmap-methods-demo

# Проверить созданный ConfigMap
kubectl get configmap basic-config -n configmap-methods-demo -o yaml

# ConfigMap с различными типами данных
kubectl create configmap typed-config \
  --from-literal=database_port="5432" \
  --from-literal=max_connections="100" \
  --from-literal=timeout_seconds="30" \
  --from-literal=enable_ssl="true" \
  --from-literal=log_level="info" \
  --from-literal=api_endpoint="https://api.hashfoundry.com" \
  -n configmap-methods-demo

# ConfigMap с JSON строкой
kubectl create configmap json-config \
  --from-literal=features='{"new_ui":true,"analytics":false,"beta":true}' \
  --from-literal=limits='{"cpu":"500m","memory":"512Mi","storage":"10Gi"}' \
  -n configmap-methods-demo

# Проверить все созданные ConfigMaps
kubectl get configmaps -n configmap-methods-demo
```

### **2. Создание из файлов (--from-file):**
```bash
# Создать различные конфигурационные файлы
mkdir config-examples

# Properties файл
cat << EOF > config-examples/application.properties
# Application Properties
server.port=8080
server.host=0.0.0.0
server.context-path=/api

# Database Configuration
database.driver=org.postgresql.Driver
database.url=jdbc:postgresql://postgres.hashfoundry.local:5432/production
database.username=app_user
database.password=secure_password
database.pool.min=5
database.pool.max=20
database.pool.timeout=30000

# Cache Configuration
cache.type=redis
cache.host=redis.hashfoundry.local
cache.port=6379
cache.ttl=3600
cache.max_memory=256mb

# Logging Configuration
logging.level=INFO
logging.file=/var/log/application.log
logging.pattern=%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n
EOF

# JSON конфигурация
cat << EOF > config-examples/features.json
{
  "feature_flags": {
    "new_dashboard": true,
    "advanced_search": true,
    "real_time_notifications": false,
    "beta_features": false,
    "experimental_ui": false
  },
  "api_limits": {
    "requests_per_minute": 1000,
    "max_payload_size": "10MB",
    "timeout_seconds": 30,
    "retry_attempts": 3
  },
  "integrations": {
    "slack": {
      "enabled": true,
      "webhook_url": "https://hooks.slack.com/services/..."
    },
    "email": {
      "enabled": true,
      "smtp_server": "smtp.hashfoundry.com",
      "port": 587
    }
  }
}
EOF

# YAML конфигурация
cat << EOF > config-examples/monitoring.yaml
prometheus:
  enabled: true
  port: 9090
  scrape_interval: 30s
  retention: 15d
  storage:
    size: 50Gi
    class: fast-ssd

grafana:
  enabled: true
  port: 3000
  admin_user: admin
  admin_password: secure_admin_pass
  datasources:
    - name: prometheus
      type: prometheus
      url: http://prometheus:9090
    - name: loki
      type: loki
      url: http://loki:3100

alertmanager:
  enabled: true
  port: 9093
  config:
    global:
      smtp_smarthost: 'smtp.hashfoundry.com:587'
      smtp_from: 'alerts@hashfoundry.com'
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://webhook:5001/'
EOF

# XML конфигурация
cat << EOF > config-examples/logback.xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property name="LOG_PATTERN" value="%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"/>
    <property name="LOG_FILE" value="/var/log/application.log"/>
    
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>\${LOG_PATTERN}</pattern>
        </encoder>
    </appender>
    
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>\${LOG_FILE}</file>
        <encoder>
            <pattern>\${LOG_PATTERN}</pattern>
        </encoder>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>/var/log/application.%d{yyyy-MM-dd}.%i.log</fileNamePattern>
            <maxFileSize>100MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>3GB</totalSizeCap>
        </rollingPolicy>
    </appender>
    
    <logger name="com.hashfoundry" level="DEBUG"/>
    <logger name="org.springframework" level="INFO"/>
    <logger name="org.hibernate" level="WARN"/>
    
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
    </root>
</configuration>
EOF

# Shell script
cat << EOF > config-examples/startup.sh
#!/bin/bash
set -e

echo "=== HashFoundry Application Startup ==="
echo "Environment: \${ENVIRONMENT:-production}"
echo "Version: \${APP_VERSION:-1.0.0}"
echo "Timestamp: \$(date)"

# Проверить переменные окружения
required_vars=("DATABASE_HOST" "DATABASE_PORT" "REDIS_HOST")
for var in "\${required_vars[@]}"; do
    if [ -z "\${!var}" ]; then
        echo "ERROR: Required environment variable \$var is not set"
        exit 1
    fi
    echo "✓ \$var = \${!var}"
done

# Проверить подключения
echo "Checking database connection..."
until pg_isready -h "\$DATABASE_HOST" -p "\$DATABASE_PORT" -U "\$DATABASE_USER"; do
    echo "Waiting for database..."
    sleep 2
done
echo "✓ Database is ready"

echo "Checking Redis connection..."
until redis-cli -h "\$REDIS_HOST" -p "\$REDIS_PORT" ping | grep -q PONG; do
    echo "Waiting for Redis..."
    sleep 2
done
echo "✓ Redis is ready"

# Запустить приложение
echo "Starting application..."
exec "\$@"
EOF

# Создать ConfigMaps из отдельных файлов
kubectl create configmap app-properties \
  --from-file=config-examples/application.properties \
  -n configmap-methods-demo

kubectl create configmap features-json \
  --from-file=config-examples/features.json \
  -n configmap-methods-demo

kubectl create configmap monitoring-yaml \
  --from-file=config-examples/monitoring.yaml \
  -n configmap-methods-demo

kubectl create configmap logback-xml \
  --from-file=config-examples/logback.xml \
  -n configmap-methods-demo

kubectl create configmap startup-script \
  --from-file=config-examples/startup.sh \
  -n configmap-methods-demo

# Создать ConfigMap с пользовательским ключом
kubectl create configmap custom-key-config \
  --from-file=database_config=config-examples/application.properties \
  --from-file=app_features=config-examples/features.json \
  -n configmap-methods-demo

# Проверить созданные ConfigMaps
kubectl get configmaps -n configmap-methods-demo
kubectl describe configmap app-properties -n configmap-methods-demo
```

### **3. Создание из директории (--from-file=directory):**
```bash
# Создать структуру директорий с конфигурациями
mkdir -p config-directory/{app,database,monitoring,scripts}

# Конфигурации приложения
cat << EOF > config-directory/app/server.conf
[server]
host = 0.0.0.0
port = 8080
workers = 10
timeout = 30
max_connections = 1000

[security]
enable_https = true
ssl_cert = /etc/ssl/certs/app.crt
ssl_key = /etc/ssl/private/app.key
jwt_secret = super_secret_jwt_key
session_timeout = 3600
EOF

cat << EOF > config-directory/app/features.ini
[features]
new_ui = true
analytics = true
notifications = false
beta_mode = false
debug_mode = false

[limits]
max_file_size = 100MB
max_users = 10000
api_rate_limit = 1000
EOF

# Конфигурации базы данных
cat << EOF > config-directory/database/postgres.conf
# PostgreSQL Configuration
listen_addresses = '*'
port = 5432
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
min_wal_size = 1GB
max_wal_size = 4GB
EOF

cat << EOF > config-directory/database/redis.conf
# Redis Configuration
bind 0.0.0.0
port 6379
timeout 300
tcp-keepalive 60
databases 16
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes
maxmemory 512mb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
EOF

# Конфигурации мониторинга
cat << EOF > config-directory/monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
    - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
      action: keep
      regex: default;kubernetes;https

  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
    - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
EOF

cat << EOF > config-directory/monitoring/grafana.ini
[server]
protocol = http
http_port = 3000
domain = grafana.hashfoundry.local
root_url = http://grafana.hashfoundry.local:3000/

[database]
type = postgres
host = postgres.hashfoundry.local:5432
name = grafana
user = grafana
password = grafana_password

[security]
admin_user = admin
admin_password = admin_password
secret_key = grafana_secret_key

[auth]
disable_login_form = false
disable_signout_menu = false

[auth.anonymous]
enabled = false

[dashboards]
default_home_dashboard_path = /var/lib/grafana/dashboards/home.json
EOF

# Скрипты
cat << EOF > config-directory/scripts/init.sh
#!/bin/bash
echo "Initializing HashFoundry Application..."
echo "Creating necessary directories..."
mkdir -p /var/log/app /var/lib/app /tmp/app

echo "Setting permissions..."
chmod 755 /var/log/app /var/lib/app
chmod 1777 /tmp/app

echo "Loading configuration..."
source /etc/app/server.conf
source /etc/app/features.ini

echo "Initialization complete!"
EOF

cat << EOF > config-directory/scripts/health-check.sh
#!/bin/bash
# Health check script for HashFoundry Application

check_database() {
    pg_isready -h "\$DATABASE_HOST" -p "\$DATABASE_PORT" -U "\$DATABASE_USER" >/dev/null 2>&1
    return \$?
}

check_redis() {
    redis-cli -h "\$REDIS_HOST" -p "\$REDIS_PORT" ping | grep -q PONG
    return \$?
}

check_application() {
    curl -f http://localhost:8080/health >/dev/null 2>&1
    return \$?
}

echo "=== Health Check ==="
echo -n "Database: "
if check_database; then
    echo "✓ OK"
else
    echo "✗ FAIL"
    exit 1
fi

echo -n "Redis: "
if check_redis; then
    echo "✓ OK"
else
    echo "✗ FAIL"
    exit 1
fi

echo -n "Application: "
if check_application; then
    echo "✓ OK"
else
    echo "✗ FAIL"
    exit 1
fi

echo "All checks passed!"
EOF

# Создать ConfigMap из всей директории
kubectl create configmap directory-config \
  --from-file=config-directory/ \
  -n configmap-methods-demo

# Создать ConfigMaps из поддиректорий
kubectl create configmap app-configs \
  --from-file=config-directory/app/ \
  -n configmap-methods-demo

kubectl create configmap database-configs \
  --from-file=config-directory/database/ \
  -n configmap-methods-demo

kubectl create configmap monitoring-configs \
  --from-file=config-directory/monitoring/ \
  -n configmap-methods-demo

kubectl create configmap script-configs \
  --from-file=config-directory/scripts/ \
  -n configmap-methods-demo

# Проверить созданные ConfigMaps
kubectl get configmaps -n configmap-methods-demo
kubectl describe configmap directory-config -n configmap-methods-demo
```

### **4. Создание через YAML манифесты:**
```bash
# Создать comprehensive ConfigMap через YAML
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: yaml-manifest-config
  namespace: configmap-methods-demo
  labels:
    app: hashfoundry
    component: configuration
    environment: production
    version: "1.0.0"
  annotations:
    description: "Comprehensive configuration for HashFoundry application"
    created-by: "DevOps Team"
    last-updated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
data:
  # Простые конфигурационные значения
  app_name: "HashFoundry Production"
  app_version: "1.0.0"
  environment: "production"
  debug_enabled: "false"
  log_level: "INFO"
  
  # Сетевые настройки
  server_host: "0.0.0.0"
  server_port: "8080"
  api_timeout: "30"
  max_connections: "1000"
  
  # База данных
  database_host: "postgres.hashfoundry.local"
  database_port: "5432"
  database_name: "hashfoundry_prod"
  database_ssl: "true"
  database_pool_min: "5"
  database_pool_max: "20"
  
  # Cache
  redis_host: "redis.hashfoundry.local"
  redis_port: "6379"
  redis_db: "0"
  redis_ttl: "3600"
  
  # Многострочные конфигурации
  nginx.conf: |
    upstream backend {
        server app1.hashfoundry.local:8080 weight=3;
        server app2.hashfoundry.local:8080 weight=3;
        server app3.hashfoundry.local:8080 weight=2;
    }
    
    server {
        listen 80;
        server_name hashfoundry.com www.hashfoundry.com;
        return 301 https://\$server_name\$request_uri;
    }
    
    server {
        listen 443 ssl http2;
        server_name hashfoundry.com www.hashfoundry.com;
        
        ssl_certificate /etc/ssl/certs/hashfoundry.crt;
        ssl_certificate_key /etc/ssl/private/hashfoundry.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
        
        location / {
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # API specific settings
            proxy_buffering off;
            proxy_request_buffering off;
            client_max_body_size 100M;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
  
  application.yaml: |
    spring:
      application:
        name: hashfoundry-app
      profiles:
        active: production
      
      datasource:
        url: jdbc:postgresql://postgres.hashfoundry.local:5432/hashfoundry_prod
        username: \${DATABASE_USERNAME}
        password: \${DATABASE_PASSWORD}
        driver-class-name: org.postgresql.Driver
        hikari:
          minimum-idle: 5
          maximum-pool-size: 20
          idle-timeout: 300000
          max-lifetime: 600000
          connection-timeout: 30000
      
      redis:
        host: redis.hashfoundry.local
        port: 6379
        database: 0
        timeout: 2000ms
        lettuce:
          pool:
            max-active: 8
            max-idle: 8
            min-idle: 0
      
      jpa:
        hibernate:
          ddl-auto: validate
        show-sql: false
        properties:
          hibernate:
            dialect: org.hibernate.dialect.PostgreSQLDialect
            format_sql: false
    
    server:
      port: 8080
      servlet:
        context-path: /api
      compression:
        enabled: true
        mime-types: text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json
        min-response-size: 1024
    
    management:
      endpoints:
        web:
          exposure:
            include: health,info,metrics,prometheus
      endpoint:
        health:
          show-details: when-authorized
      metrics:
        export:
          prometheus:
            enabled: true
    
    logging:
      level:
        com.hashfoundry: INFO
        org.springframework: WARN
        org.hibernate: WARN
      pattern:
        console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
        file: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
      file:
        name: /var/log/application.log
        max-size: 100MB
        max-history: 30
  
  docker-compose.yml: |
    version: '3.8'
    
    services:
      app:
        image: hashfoundry/app:1.0.0
        ports:
          - "8080:8080"
        environment:
          - SPRING_PROFILES_ACTIVE=production
          - DATABASE_HOST=postgres
          - DATABASE_USERNAME=\${DATABASE_USERNAME}
          - DATABASE_PASSWORD=\${DATABASE_PASSWORD}
          - REDIS_HOST=redis
        depends_on:
          - postgres
          - redis
        volumes:
          - app_logs:/var/log
        networks:
          - hashfoundry
        restart: unless-stopped
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
          interval: 30s
          timeout: 10s
          retries: 3
          start_period: 40s
      
      postgres:
        image: postgres:13
        environment:
          - POSTGRES_DB=hashfoundry_prod
          - POSTGRES_USER=\${DATABASE_USERNAME}
          - POSTGRES_PASSWORD=\${DATABASE_PASSWORD}
        volumes:
          - postgres_data:/var/lib/postgresql/data
          - ./init.sql:/docker-entrypoint-initdb.d/init.sql
        networks:
          - hashfoundry
        restart: unless-stopped
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U \${DATABASE_USERNAME}"]
          interval: 10s
          timeout: 5s
          retries: 5
      
      redis:
        image: redis:6-alpine
        command: redis-server --appendonly yes
        volumes:
          - redis_data:/data
        networks:
          - hashfoundry
        restart: unless-stopped
        healthcheck:
          test: ["CMD", "redis-cli", "ping"]
          interval: 10s
          timeout: 3s
          retries: 3
    
    volumes:
      postgres_data:
      redis_data:
      app_logs:
    
    networks:
      hashfoundry:
        driver: bridge
  
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'hashfoundry-ha'
        environment: 'production'
    
    rule_files:
      - "/etc/prometheus/rules/*.yml"
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/\${1}/proxy/metrics
      
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: \$1:\$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
EOF

# Создать ConfigMap с бинарными данными
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: binary-config
  namespace: configmap-methods-demo
binaryData:
  # Base64 encoded SSL certificate (пример)
  ssl.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURYVENDQWtXZ0F3SUJBZ0lKQUtMMFVHK2pHS2hrTUEwR0NTcUdTSWIzRFFFQkN3VUFNRVUKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQ==
  
  # Base64 encoded private key (пример)
  ssl.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBZ0VBQW9JQkFRREEKLS0tLS1FTkQgUFJJVkFURSBLRVktLS0tLQ==
EOF

# Проверить созданные ConfigMaps
kubectl get configmaps -n configmap-methods-demo
kubectl describe configmap binary-config -n configmap-methods-demo
```

### **5. Создание из переменных окружения (--from-env-file):**
```bash
# Создать файлы с переменными окружения
cat << EOF > production.env
# Production Environment Variables
APP_NAME=HashFoundry Production
APP_VERSION=1.0.0
ENVIRONMENT=production
DEBUG_MODE=false
LOG_LEVEL=INFO

# Database Configuration
DATABASE_HOST=postgres.hashfoundry.local
DATABASE_PORT=5432
DATABASE_NAME=hashfoundry_prod
DATABASE_SSL=true
DATABASE_POOL_MIN=5
DATABASE_POOL_MAX=20
DATABASE_TIMEOUT=30000

# Cache Configuration
REDIS_HOST=redis.hashfoundry.local
REDIS_PORT=6379
REDIS_DB=0
REDIS_TTL=3600
REDIS_MAX_MEMORY=512mb

# API Configuration
API_TIMEOUT=30
API_RATE_LIMIT=1000
API_MAX_PAYLOAD=10MB
API_RETRY_ATTEMPTS=3

# Monitoring Configuration
METRICS_ENABLED=true
METRICS_PORT=9090
HEALTH_CHECK_INTERVAL=30
PROMETHEUS_SCRAPE=true
EOF

cat << EOF > development.env
# Development Environment Variables
APP_NAME=HashFoundry Development
APP_VERSION=1.0.0-dev
ENVIRONMENT=development
DEBUG_MODE=true
LOG_LEVEL=DEBUG

# Database Configuration
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=hashfoundry_dev
DATABASE_SSL=false
DATABASE_POOL_MIN=2
DATABASE_POOL_MAX=10
DATABASE_TIMEOUT=10000

# Cache Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=1
REDIS_TTL=1800
REDIS_MAX_MEMORY=128mb

# API Configuration
API_TIMEOUT=60
API_RATE_LIMIT=100
API_MAX_PAYLOAD=50MB
API_RETRY_ATTEMPTS=5

# Monitoring Configuration
METRICS_ENABLED=true
METRICS_PORT=9090
HEALTH_CHECK_INTERVAL=10
PROMETHEUS_SCRAPE=true
EOF

# Создать ConfigMaps из env файлов
kubectl create configmap prod-env-config \
  --from-env-file=production.env \
  -n configmap-methods-demo

kubectl create configmap dev-env-config \
  --from-env-file=development.env \
  -n configmap-methods-demo

# Создать ConfigMap из нескольких env файлов
kubectl create configmap multi-env-config \
  --from-env-file=production.env \
  --from-env-file=development.env \
  -n configmap-methods-demo

# Проверить созданные ConfigMaps
kubectl get configmap prod-env-config -n configmap-methods-demo -o yaml
kubectl get configmap dev-env-config -n configmap-methods-demo -o yaml
```

### **6. Программное создание через Kubernetes API:**
```bash
# Создать скрипт для программного создания ConfigMaps
cat << 'EOF' > create-configmap-api.sh
#!/bin/bash

NAMESPACE="configmap-methods-demo"
API_SERVER="https://kubernetes.default.svc"
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Функция для создания ConfigMap через API
create_configmap_api() {
    local name=$1
    local data=$2
    
    cat << EOL | curl -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d @- \
        "$API_SERVER/api/v1/namespaces/$NAMESPACE/configmaps"
{
  "apiVersion": "v1",
  "kind": "ConfigMap",
  "metadata": {
    "name": "$name",
    "namespace": "$NAMESPACE",
    "labels": {
      "created-by": "api-script",
      "method": "programmatic"
    }
  },
  "data": $data
}
EOL
}

# Создать ConfigMap через API
API_DATA='{
  "app_name": "API Created App",
  "version": "1.0.0",
  "environment": "api-test",
  "config.json": "{\"api\": true, \"method\": \"programmatic\"}"
}'

create_configmap_api "api-created-config" "$API_DATA"

echo "ConfigMap created via API"
EOF

chmod +x create-configmap-api.sh

# Альтернативный способ через kubectl и JSON
cat << 'EOF' > create-configmap-json.sh
#!/bin/bash

NAMESPACE="configmap-methods-demo"

# Создать ConfigMap через JSON
cat << EOL | kubectl apply -f -
{
  "apiVersion": "v1",
  "kind": "ConfigMap",
  "metadata": {
    "name": "json-created-config",
    "namespace": "$NAMESPACE",
    "labels": {
      "created-by": "json-script",
      "format": "json"
    }
  },
  "data": {
    "app_name": "JSON Created App",
    "version": "2.0.0",
    "environment": "json-test",
    "features": "{\"json_support\": true, \"yaml_support\": true}",
    "config.properties": "app.name=JSON App\napp.version=2.0.0\napp.environment=json-test"
  }
}
EOL

echo "ConfigMap created via JSON"
EOF

chmod +x create-configmap-json.sh
./create-configmap-json.sh
```

### **7. Создание через Helm и Kustomize:**
```bash
# Создать Helm chart для ConfigMaps
mkdir -p helm-configmap-chart/{templates,values}

cat << EOF > helm-configmap-chart/Chart.yaml
apiVersion: v2
name: configmap-chart
description: A Helm chart for creating ConfigMaps
type: application
version: 0.1.0
appVersion: "1.0"
EOF

cat << EOF > helm-configmap-chart/values.yaml
# Default values for configmap-chart
namespace: configmap-methods-demo

configmaps:
  app-config:
    data:
      app_name: "Helm Created App"
      version: "1.0.0"
      environment: "helm-test"
      debug: "false"
  
  database-config:
    data:
      host: "postgres.helm.local"
      port: "5432"
      name: "helm_db"
      ssl: "true"
  
  monitoring-config:
    data:
      prometheus.yml: |
        global:
          scrape_interval: 15s
        scrape_configs:
          - job_name: 'helm-app'
            static_configs:
              - targets: ['localhost:8080']
EOF

cat << EOF > helm-configmap-chart/templates/configmaps.yaml
{{- range \$name, \$config := .Values.configmaps }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ \$name }}
  namespace: {{ $.Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ include "configmap-chart.name" $ }}
    app.kubernetes.io/instance: {{ $.Release.Name }}
    app.kubernetes.io/version: {{ $.Chart.AppVersion | quote }}
    app.kubernetes.io/managed-by: {{ $.Release.Service }}
    created-by: helm
data:
{{- range \$key, \$value := \$config.data }}
  {{ \$key }}: {{ \$value | quote }}
{{- end }}
{{- end }}
EOF

cat << EOF > helm-configmap-chart/templates/_helpers.tpl
{{- define "configmap-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
EOF

# Установить Helm chart
helm install configmap-demo helm-configmap-chart/

# Создать Kustomize конфигурацию
mkdir -p kustomize-configmap/{base,overlays/production,overlays/development}

cat << EOF > kustomize-configmap/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - configmap.yaml

commonLabels:
  created-by: kustomize
  component: configuration
EOF

cat << EOF > kustomize-configmap/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kustomize-config
  namespace: configmap-methods-demo
data:
  app_name: "Kustomize App"
  version: "1.0.0"
  environment: "base"
  config.yaml: |
    app:
      name: "Kustomize App"
      version: "1.0.0"
    server:
      port: 8080
      host: "0.0.0.0"
EOF

cat << EOF > kustomize-configmap/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patchesStrategicMerge:
  - configmap-patch.yaml

commonLabels:
  environment: production
EOF

cat << EOF > kustomize-configmap/overlays/production/configmap-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kustomize-config
data:
  environment: "production"
  log_level: "WARN"
  database_host: "postgres.prod.local"
  config.yaml: |
    app:
      name: "Kustomize App Production"
      version: "1.0.0"
      environment: "production"
    server:
      port: 8080
      host: "0.0.0.0"
      workers: 10
    database:
      host: "postgres.prod.local"
      port: 5432
      ssl: true
EOF

# Применить Kustomize конфигурацию
kubectl apply -k kustomize-configmap/overlays/production/

# Проверить созданные ресурсы
kubectl get configmaps -n configmap-methods-demo -l created-by=helm
kubectl get configmaps -n configmap-methods-demo -l created-by=kustomize
```

## 🧪 **Сравнение методов создания ConfigMaps:**

### **Создание сравнительной таблицы:**
```bash
# Создать скрипт для сравнения методов
cat << 'EOF' > compare-configmap-methods.sh
#!/bin/bash

NAMESPACE="configmap-methods-demo"

echo "=== Comparison of ConfigMap Creation Methods ==="
echo

# Функция для получения информации о ConfigMap
get_configmap_info() {
    local name=$1
    local size=$(kubectl get configmap $name -n $NAMESPACE -o jsonpath='{.data}' 2>/dev/null | wc -c)
    local keys=$(kubectl get configmap $name -n $NAMESPACE -o jsonpath='{.data}' 2>/dev/null | jq 'keys | length' 2>/dev/null || echo "0")
    local method=$(kubectl get configmap $name -n $NAMESPACE -o jsonpath='{.metadata.labels.created-by}' 2>/dev/null || echo "kubectl")
    
    printf "%-25s | %-15s | %-8s | %-10s\n" "$name" "$method" "${size}B" "$keys"
}

# Заголовок таблицы
printf "%-25s | %-15s | %-8s | %-10s\n" "NAME" "METHOD" "SIZE" "KEYS"
printf "%-25s | %-15s | %-8s | %-10s\n" "$(printf '%*s' 25 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 8 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')"

# Получить все ConfigMaps и их информацию
for cm in $(kubectl get configmaps -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    get_configmap_info "$cm"
done

echo
echo "=== Method Summary ==="
echo "1. --from-literal: Quick for simple key-value pairs"
echo "2. --from-file: Best for existing configuration files"
echo "3. --from-file=dir: Efficient for multiple related files"
echo "4. YAML manifests: Most flexible, supports complex structures"
echo "5. --from-env-file: Perfect for environment variables"
echo "6. API/JSON: Programmatic creation, automation"
echo "7. Helm/Kustomize: Template-based, environment-specific"
EOF

chmod +x compare-configmap-methods.sh
./compare-configmap-methods.sh
```

## 🧹 **Очистка ресурсов:**
```bash
# Удалить все созданные ресурсы
kubectl delete namespace configmap-methods-demo

# Удалить Helm release
helm uninstall configmap-demo

# Удалить созданные файлы и директории
rm -rf config-examples config-directory production.env development.env
rm -f create-configmap-api.sh create-configmap-json.sh compare-configmap-methods.sh
rm -rf helm-configmap-chart kustomize-configmap
```

## 📋 **Сводка всех методов создания ConfigMaps:**

### **1. Командная строка (kubectl create):**
```bash
# Из литералов
kubectl create configmap myconfig --from-literal=key1=value1

# Из файлов
kubectl create configmap myconfig --from-file=config.properties

# Из директории
kubectl create configmap myconfig --from-file=config-dir/

# Из env файла
kubectl create configmap myconfig --from-env-file=app.env
```

### **2. Декларативный подход (kubectl apply):**
```bash
# YAML манифест
kubectl apply -f configmap.yaml

# JSON манифест
kubectl apply -f configmap.json
```

### **3. Инструменты автоматизации:**
```bash
# Helm
helm install myapp ./chart

# Kustomize
kubectl apply -k overlays/production/
```

## 🎯 **Best Practices для создания ConfigMaps:**

### **1. Выбор метода:**
- **--from-literal**: Простые значения, быстрое тестирование
- **--from-file**: Существующие конфигурационные файлы
- **--from-env-file**: Переменные окружения
- **YAML манифесты**: Сложные конфигурации, version control
- **Helm/Kustomize**: Шаблонизация, множественные среды

### **2. Организация:**
- **Группируйте** связанные конфигурации
- **Используйте понятные имена** и метки
- **Документируйте** назначение каждого ConfigMap
- **Версионируйте** критические конфигурации

### **3. Безопасность:**
- **Не храните секреты** в ConfigMaps
- **Проверяйте содержимое** перед применением
- **Используйте RBAC** для ограничения доступа
- **Аудируйте изменения** конфигураций

### **4. Управление:**
- **Автоматизируйте** создание через CI/CD
- **Тестируйте** конфигурации в staging
- **Мониторьте** использование ConfigMaps
- **Планируйте** стратегию обновлений

**Выбор правильного метода создания ConfigMaps зависит от конкретных требований проекта, сложности конфигураций и процессов разработки!**
