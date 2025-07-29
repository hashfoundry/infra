# 142. Лучшие практики для Kubernetes развертываний в CI/CD

## 🎯 **Основные концепции:**

| Аспект | Плохие практики | Лучшие практики |
|--------|----------------|-----------------|
| **Образы** | latest теги | Семантическое версионирование |
| **Секреты** | В переменных среды | Kubernetes Secrets + External Secrets |
| **Конфигурация** | Хардкод в манифестах | ConfigMaps + Kustomize/Helm |
| **Тестирование** | Только unit тесты | Полный цикл: unit + integration + e2e |
| **Развертывание** | Прямое kubectl apply | GitOps + ArgoCD |
| **Мониторинг** | Логи в stdout | Structured logging + metrics |
| **Безопасность** | Root контейнеры | Non-root + Security Context |
| **Ресурсы** | Без лимитов | Resource requests/limits |

## 🏆 **Best Practices для Kubernetes CI/CD**

**Best Practices** — это проверенные временем подходы и методы, которые обеспечивают надежность, безопасность, производительность и поддерживаемость Kubernetes развертываний в CI/CD пайплайнах.

### **Ключевые принципы:**
- **Иммутабельность** - неизменяемые артефакты
- **Идемпотентность** - повторяемые операции
- **Наблюдаемость** - полная видимость процесса
- **Безопасность** - security by design
- **Автоматизация** - минимум ручных операций
- **Тестируемость** - проверка на каждом этапе

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка текущих практик в ArgoCD:**
```bash
# Проверка ArgoCD приложений и их конфигурации
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL

# Проверка используемых образов
kubectl get deployments -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[*].image}{"\n"}{end}'

# Проверка security context
kubectl get deployments -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.securityContext}{"\n"}{end}'

# Проверка resource limits
kubectl get deployments -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[*].resources}{"\n"}{end}'
```

### **2. Анализ мониторинга (если установлен Prometheus):**
```bash
# Проверка ServiceMonitors для мониторинга
kubectl get servicemonitor -n monitoring

# Проверка метрик развертываний
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики для анализа:
# - kube_deployment_status_replicas_available
# - kube_deployment_status_replicas_updated
# - kube_pod_container_status_restarts_total
# - argocd_app_sync_total
```

### **3. Проверка безопасности в кластере:**
```bash
# RBAC анализ
kubectl auth can-i --list --as=system:serviceaccount:argocd:argocd-application-controller

# Network Policies
kubectl get networkpolicies --all-namespaces

# Pod Security Standards
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'

# Secrets management
kubectl get secrets -n argocd -o custom-columns=NAME:.metadata.name,TYPE:.type,AGE:.metadata.creationTimestamp
```

## 🛠️ **Comprehensive Best Practices Implementation:**

### **1. Структура проекта с лучшими практиками:**
```bash
# Создать структуру проекта
mkdir -p webapp-best-practices/{src,k8s,helm,ci,tests,docs}
cd webapp-best-practices

# Структура файлов
cat << 'EOF'
webapp-best-practices/
├── src/                              # Исходный код
│   ├── app/
│   ├── Dockerfile
│   ├── Dockerfile.prod
│   └── .dockerignore
├── k8s/                              # Kubernetes манифесты
│   ├── base/                         # Базовые манифесты
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── hpa.yaml
│   │   ├── pdb.yaml
│   │   ├── networkpolicy.yaml
│   │   └── kustomization.yaml
│   ├── overlays/                     # Environment-specific
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
│   └── components/                   # Reusable components
├── helm/                             # Helm charts
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   ├── values-prod.yaml
│   └── templates/
├── ci/                               # CI/CD конфигурации
│   ├── .github/workflows/
│   ├── .gitlab-ci.yml
│   ├── Jenkinsfile
│   ├── scripts/
│   └── policies/
├── tests/                            # Тесты
│   ├── unit/
│   ├── integration/
│   ├── e2e/
│   └── security/
├── docs/                             # Документация
│   ├── deployment.md
│   ├── troubleshooting.md
│   └── runbooks/
├── .gitignore
├── README.md
└── SECURITY.md
EOF
```

### **2. Production-ready Dockerfile:**
```dockerfile
# src/Dockerfile.prod
# Multi-stage build для оптимизации размера
FROM node:18-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && npm run test

FROM node:18-alpine AS runtime

# Создать non-root пользователя
RUN addgroup -g 1001 -S nodejs && \
    adduser -S webapp -u 1001 -G nodejs

# Установить только необходимые пакеты
RUN apk add --no-cache dumb-init curl

WORKDIR /app

# Копировать только необходимые файлы
COPY --from=dependencies --chown=webapp:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=webapp:nodejs /app/dist ./dist
COPY --from=build --chown=webapp:nodejs /app/package.json ./

# Настройки безопасности
USER webapp
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Использовать dumb-init для правильной обработки сигналов
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]

# Метаданные
LABEL maintainer="hashfoundry-team@example.com" \
      version="1.0.0" \
      description="HashFoundry WebApp Production Image"
```

### **3. Secure Kubernetes манифесты:**
```yaml
# k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
    version: "1.0"
    component: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # Zero downtime
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: "1.0"
        component: backend
      annotations:
        # Prometheus scraping
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
        # Config hash для автоматического restart при изменении config
        config/hash: "placeholder"
    spec:
      # Security Context на уровне Pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      
      # Service Account с минимальными правами
      serviceAccountName: webapp-sa
      automountServiceAccountToken: false
      
      # Affinity для распределения по узлам
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - webapp
              topologyKey: kubernetes.io/hostname
      
      # Tolerations для специальных узлов
      tolerations:
      - key: "app"
        operator: "Equal"
        value: "webapp"
        effect: "NoSchedule"
      
      # Init containers для подготовки
      initContainers:
      - name: migration
        image: hashfoundry/webapp-migrations:latest
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database-url
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
      
      containers:
      - name: webapp
        image: hashfoundry/webapp:latest
        imagePullPolicy: IfNotPresent
        
        ports:
        - name: http
          containerPort: 3000
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP
        
        # Environment variables
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        - name: METRICS_PORT
          value: "9090"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        
        # ConfigMap и Secrets
        envFrom:
        - configMapRef:
            name: webapp-config
        - secretRef:
            name: webapp-secrets
        
        # Resource limits и requests
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
            ephemeral-storage: 1Gi
          limits:
            cpu: 1000m
            memory: 512Mi
            ephemeral-storage: 2Gi
        
        # Security Context на уровне контейнера
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
        
        startupProbe:
          httpGet:
            path: /health/startup
            port: http
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30
          successThreshold: 1
        
        # Volume mounts
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/.cache
        - name: logs
          mountPath: /app/logs
        - name: config-volume
          mountPath: /app/config
          readOnly: true
      
      # Sidecar для логирование (опционально)
      - name: log-shipper
        image: fluent/fluent-bit:2.0
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: logs
          mountPath: /app/logs
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc
      
      # Volumes
      volumes:
      - name: tmp
        emptyDir:
          sizeLimit: 1Gi
      - name: cache
        emptyDir:
          sizeLimit: 2Gi
      - name: logs
        emptyDir:
          sizeLimit: 1Gi
      - name: config-volume
        configMap:
          name: webapp-config
          defaultMode: 0444
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
      
      # DNS настройки
      dnsPolicy: ClusterFirst
      dnsConfig:
        options:
        - name: ndots
          value: "2"
        - name: edns0
      
      # Restart policy
      restartPolicy: Always
      
      # Termination grace period
      terminationGracePeriodSeconds: 30

---
# k8s/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  labels:
    app: webapp
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
spec:
  type: ClusterIP
  selector:
    app: webapp
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: metrics
    protocol: TCP
  sessionAffinity: None

---
# k8s/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  labels:
    app: webapp
data:
  # Application configuration
  LOG_LEVEL: "info"
  LOG_FORMAT: "json"
  METRICS_ENABLED: "true"
  CACHE_TTL: "3600"
  API_TIMEOUT: "30000"
  MAX_CONNECTIONS: "100"
  
  # Feature flags
  FEATURE_NEW_UI: "true"
  FEATURE_ANALYTICS: "false"
  
  # Performance tuning
  NODE_OPTIONS: "--max-old-space-size=256"
  UV_THREADPOOL_SIZE: "4"

---
# k8s/base/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
  labels:
    app: webapp
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60

---
# k8s/base/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: webapp-pdb
  labels:
    app: webapp
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: webapp

---
# k8s/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: webapp-network-policy
  labels:
    app: webapp
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Разрешить трафик от Ingress Controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000
  # Разрешить трафик от Prometheus
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
  egress:
  # Разрешить трафик к базе данных
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
  # Разрешить трафик к Redis
  - to:
    - namespaceSelector:
        matchLabels:
          name: cache
    ports:
    - protocol: TCP
      port: 6379
  # Разрешить DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # Разрешить HTTPS для внешних API
  - to: []
    ports:
    - protocol: TCP
      port: 443
```

### **4. RBAC с минимальными привилегиями:**
```yaml
# k8s/base/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-sa
  labels:
    app: webapp
automountServiceAccountToken: false

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: webapp-role
  labels:
    app: webapp
rules:
# Только чтение собственных ресурсов
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list"]
  resourceNames: ["webapp", "webapp-service", "webapp-config"]
# Доступ к секретам только для чтения
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["webapp-secrets"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: webapp-rolebinding
  labels:
    app: webapp
subjects:
- kind: ServiceAccount
  name: webapp-sa
  namespace: default
roleRef:
  kind: Role
  name: webapp-role
  apiGroup: rbac.authorization.k8s.io

---
# CI/CD Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-cd-deployer
  namespace: webapp-production
  labels:
    component: ci-cd
automountServiceAccountToken: false

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: webapp-production
  name: ci-cd-deployer-role
rules:
# Управление основными ресурсами
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
# Только чтение для мониторинга
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-cd-deployer-binding
  namespace: webapp-production
subjects:
- kind: ServiceAccount
  name: ci-cd-deployer
  namespace: webapp-production
roleRef:
  kind: Role
  name: ci-cd-deployer-role
  apiGroup: rbac.authorization.k8s.io
```

### **5. Kustomize для управления окружениями:**
```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: webapp-base

resources:
- deployment.yaml
- service.yaml
- configmap.yaml
- hpa.yaml
- pdb.yaml
- networkpolicy.yaml
- rbac.yaml

commonLabels:
  app: webapp
  managed-by: kustomize

commonAnnotations:
  app.kubernetes.io/name: webapp
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: hashfoundry-platform

images:
- name: hashfoundry/webapp
  newTag: latest

configMapGenerator:
- name: webapp-config
  files:
  - config.properties
  - logging.conf

secretGenerator:
- name: webapp-secrets
  type: Opaque
  literals:
  - database-password=placeholder
  - api-key=placeholder
  - jwt-secret=placeholder

---
# k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: webapp-production

namespace: webapp-production

resources:
- ../../base
- ingress.yaml
- external-secrets.yaml

patchesStrategicMerge:
- deployment-patch.yaml
- service-patch.yaml

replicas:
- name: webapp
  count: 5

images:
- name: hashfoundry/webapp
  newTag: v1.2.3

configMapGenerator:
- name: webapp-config
  behavior: merge
  literals:
  - LOG_LEVEL=warn
  - METRICS_ENABLED=true
  - FEATURE_ANALYTICS=true

patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/cpu
      value: 200m
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/cpu
      value: 2000m
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/memory
      value: 256Mi
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: 1Gi

---
# k8s/overlays/production/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 5
  template:
    spec:
      nodeSelector:
        node-type: production
      tolerations:
      - key: "production"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      containers:
      - name: webapp
        env:
        - name: NODE_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "warn"
```

## 🔐 **Security Best Practices:**

### **1. External Secrets Operator интеграция:**
```yaml
# k8s/base/external-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: webapp-production
spec:
  provider:
    vault:
      server: "https://vault.hashfoundry.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "webapp-production"
          serviceAccountRef:
            name: external-secrets-sa

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: webapp-secrets
  namespace: webapp-production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: webapp-secrets
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        database-url: "postgresql://{{ .username }}:{{ .password }}@postgres:5432/webapp"
        api-key: "{{ .api_key }}"
        jwt-secret: "{{ .jwt_secret }}"
  data:
  - secretKey: username
    remoteRef:
      key: database
      property: username
  - secretKey: password
    remoteRef:
      key: database
      property: password
  - secretKey: api_key
    remoteRef:
      key: external-api
      property: key
  - secretKey: jwt_secret
    remoteRef:
      key: auth
      property: jwt_secret
```

### **2. Pod Security Standards:**
```yaml
# k8s/base/pod-security-policy.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-production
  labels:
    name: webapp-production
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: webapp-security-policy
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-non-root
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - webapp-production
    validate:
      message: "Containers must run as non-root user"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
          containers:
          - securityContext:
              runAsNonRoot: true
  
  - name: require-resource-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - webapp-production
    validate:
      message: "Resource limits are required"
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
              requests:
                memory: "?*"
                cpu: "?*"
  
  - name: disallow-privileged
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - webapp-production
    validate:
      message: "Privileged containers are not allowed"
      pattern:
        spec:
          containers:
          - securityContext:
              privileged: false
```

## 🧪 **Testing Best Practices:**

### **1. Comprehensive testing pipeline:**
```bash
#!/bin/bash
# tests/run-all-tests.sh

set -e

NAMESPACE=${NAMESPACE:-webapp-test}
IMAGE_TAG=${IMAGE_TAG:-test}

echo "🧪 Running comprehensive test suite..."

# 1. Unit tests
echo "📝 Running unit tests..."
npm run test:unit -- --coverage --ci

# 2. Lint и security scan
echo "🔍 Running linting and security scans..."
npm run lint
npm audit --audit-level moderate
docker run --rm -v $(pwd):/workspace aquasec/trivy:latest fs /workspace

# 3. Build test image
echo "🏗️ Building test image..."
docker build -t webapp:${IMAGE_TAG} -f src/Dockerfile.test .

# 4. Container security scan
echo "🔒 Scanning container image..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image webapp:${IMAGE_TAG}

# 5. Kubernetes manifest validation
echo "✅ Validating Kubernetes manifests..."
kubectl apply --dry-run=client -f k8s/base/
kubectl apply --dry-run=server -f k8s/base/

# 6. Security policy validation
echo "🛡️ Validating security policies..."
kubesec scan k8s/base/deployment.yaml
polaris audit --audit-path k8s/base/

# 7. Deploy to test environment
echo "🚀 Deploying to test environment..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
kustomize build k8s/overlays/test | kubectl apply -f - -n ${NAMESPACE}

# 8. Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/webapp -n ${NAMESPACE} --timeout=300s

# 9. Integration tests
echo "🔗 Running integration tests..."
kubectl port-forward svc/webapp-service 8080:80 -n ${NAMESPACE} &
PF_PID=$!
sleep 10

npm run test:integration
INTEGRATION_RESULT=$?

# 10. E2E tests
echo "🎭 Running E2E tests..."
npm run test:e2e
E2E_RESULT=$?

# 11. Performance tests
echo "⚡ Running performance tests..."
npm run test:performance
PERFORMANCE_RESULT=$?

# 12. Load testing
echo "🔥 Running load tests..."
kubectl run load-test --image=loadimpact/k6:latest --rm -i --restart=Never -- \
  run --vus 10 --duration 30s - < tests/load/basic-load-test.js
LOAD_TEST_RESULT=$?

# Cleanup
kill $PF_PID 2>/dev/null || true
kubectl delete namespace ${NAMESPACE} --ignore-not-found=true

# Results
echo "📊 Test Results Summary:"
echo "Unit Tests: $([ $? -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "Integration Tests: $([ $INTEGRATION_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "E2E Tests: $([ $E2E_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "Performance Tests: $([ $PERFORMANCE_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "Load Tests: $([ $LOAD_TEST_RESULT -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"

# Exit with error if any test failed
if [ $INTEGRATION_RESULT -ne 0 ] || [ $E2E_RESULT -ne 0 ] || [ $PERFORMANCE_RESULT -ne 0 ] || [ $LOAD_TEST_RESULT -ne 0 ]; then
    echo "❌ Some tests failed!"
    exit 1
fi

echo "✅ All tests passed!"
```

### **2. Security testing integration:**
```bash
#!/bin/bash
# tests/security-tests.sh

set -e

echo "🔒 Running security test suite..."

# 1. Static Application Security Testing (SAST)
echo "🔍 Running SAST scan..."
docker run --rm -v $(pwd):/workspace \
  securecodewarrior/semgrep:latest \
  --config=auto /workspace/src

# 2. Dependency vulnerability scan
echo "🔍 Scanning dependencies..."
npm audit --audit-level moderate
docker run --rm -v $(pwd):/workspace \
  aquasec/trivy:latest fs /workspace --severity HIGH,CRITICAL

# 3. Container image security scan
echo "🔍 Scanning container image..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image hashfoundry/webapp:latest

# 4. Kubernetes security scan
echo "🔍 Scanning Kubernetes manifests..."
docker run --rm -v $(pwd):/workspace \
  kubesec/kubesec:latest scan /workspace/k8s/base/deployment.yaml

# 5. Network policy validation
echo "🔍 Validating network policies..."
kubectl apply --dry-run=client -f k8s/base/networkpolicy.yaml

# 6. RBAC validation
echo "🔍 Validating RBAC policies..."
kubectl auth can-i --list --as=system:serviceaccount:webapp-production:webapp-sa

# 7. Pod Security Standards validation
echo "🔍 Validating Pod Security Standards..."
kubectl apply --dry-run=server -f k8s/base/deployment.yaml

echo "✅ Security tests completed!"
```

### **3. Performance testing:**
```javascript
// tests/performance/k6-load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

export let errorRate = new Rate('errors');

export let options = {
  stages: [
    { duration: '2m', target: 10 }, // Ramp up
    { duration: '5m', target: 10 }, // Stay at 10 users
    { duration: '2m', target: 20 }, // Ramp up to 20 users
    { duration: '5m', target: 20 }, // Stay at 20 users
    { duration: '2m', target: 0 },  // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.1'],    // Error rate must be below 10%
    errors: ['rate<0.1'],
  },
};

export default function() {
  // Health check
  let healthResponse = http.get('http://webapp-service/health');
  check(healthResponse, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 100ms': (r) => r.timings.duration < 100,
  }) || errorRate.add(1);

  // API endpoint test
  let apiResponse = http.get('http://webapp-service/api/status');
  check(apiResponse, {
    'API status is 200': (r) => r.status === 200,
    'API response time < 200ms': (r) => r.timings.duration < 200,
    'API response has correct content': (r) => r.body.includes('status'),
  }) || errorRate.add(1);

  // Simulate user behavior
  sleep(1);
}
```

## 📊 **Monitoring и Observability Best Practices:**

### **1. Structured logging configuration:**
```yaml
# k8s/base/logging-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  labels:
    app: webapp
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Path              /app/logs/*.log
        Parser            json
        Tag               webapp.*
        Refresh_Interval  5
        Mem_Buf_Limit     50MB

    [FILTER]
        Name                kubernetes
        Match               webapp.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off

    [OUTPUT]
        Name  forward
        Match *
        Host  fluentd.logging.svc.cluster.local
        Port  24224

  parsers.conf: |
    [PARSER]
        Name        json
        Format      json
        Time_Key    timestamp
        Time_Format %Y-%m-%dT%H:%M:%S.%L
        Time_Keep   On
```

### **2. Prometheus monitoring configuration:**
```yaml
# k8s/base/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: webapp-metrics
  labels:
    app: webapp
    release: prometheus
spec:
  selector:
    matchLabels:
      app: webapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    honorLabels: true
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_name]
      targetLabel: pod
    - sourceLabels: [__meta_kubernetes_pod_node_name]
      targetLabel: node

---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: webapp-alerts
  labels:
    app: webapp
    release: prometheus
spec:
  groups:
  - name: webapp.rules
    rules:
    - alert: WebAppHighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} errors per second"

    - alert: WebAppHighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High latency detected"
        description: "95th percentile latency is {{ $value }}s"

    - alert: WebAppPodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} is restarting frequently"

    - alert: WebAppDeploymentReplicasMismatch
      expr: kube_deployment_status_replicas != kube_deployment_status_replicas_available
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Deployment replicas mismatch"
        description: "Deployment {{ $labels.deployment }} has {{ $value }} unavailable replicas"
```

## 🚀 **Advanced CI/CD Pipeline с Best Practices:**

### **1. GitHub Actions с полным циклом:**
```yaml
# .github/workflows/production-pipeline.yml
name: Production CI/CD Pipeline

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: hashfoundry/webapp
  KUBE_NAMESPACE: webapp-production

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Run Semgrep SAST
      uses: returntocorp/semgrep-action@v1
      with:
        config: auto

  test:
    name: Test Suite
    runs-on: ubuntu-latest
    needs: security-scan
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: webapp_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:6
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

    - name: Run linting
      run: npm run lint

    - name: Run unit tests
      run: npm run test:unit -- --coverage --ci
      env:
        NODE_ENV: test

    - name: Run integration tests
      run: npm run test:integration
      env:
        DATABASE_URL: postgres://postgres:test@localhost:5432/webapp_test
        REDIS_URL: redis://localhost:6379

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage/lcov.info
        flags: unittests
        name: codecov-umbrella

  build:
    name: Build and Push
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')
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
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Docker image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        file: ./src/Dockerfile.prod
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64,linux/arm64
        build-args: |
          BUILD_DATE=${{ github.event.head_commit.timestamp }}
          VCS_REF=${{ github.sha }}
          VERSION=${{ steps.meta.outputs.version }}

    - name: Generate SBOM
      uses: anchore/sbom-action@v0
      with:
        image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        format: spdx-json
        output-file: sbom.spdx.json

    - name: Upload SBOM
      uses: actions/upload-artifact@v3
      with:
        name: sbom
        path: sbom.spdx.json

  security-image-scan:
    name: Container Security Scan
    runs-on: ubuntu-latest
    needs: build
    steps:
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ needs.build.outputs.image-tag }}
        format: 'sarif'
        output: 'trivy-image-results.sarif'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-image-results.sarif'

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: [build, security-image-scan]
    if: github.ref == 'refs/heads/main'
    environment:
      name: staging
      url: https://webapp-staging.hashfoundry.com
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'

    - name: Setup Kustomize
      uses: imranismail/setup-kustomize@v1

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBE_CONFIG_STAGING }}" | base64 -d > ~/.kube/config
        chmod 600 ~/.kube/config

    - name: Deploy to staging
      run: |
        cd k8s/overlays/staging
        kustomize edit set image hashfoundry/webapp=${{ needs.build.outputs.image-tag }}
        kustomize build . | kubectl apply -f -
        kubectl rollout status deployment/webapp -n webapp-staging --timeout=300s

    - name: Run smoke tests
      run: |
        kubectl wait --for=condition=ready pod -l app=webapp -n webapp-staging --timeout=300s
        kubectl port-forward svc/webapp-service 8080:80 -n webapp-staging &
        sleep 10
        curl -f http://localhost:8080/health
        curl -f http://localhost:8080/api/status

  e2e-tests:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: deploy-staging
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

    - name: Run E2E tests
      run: npm run test:e2e
      env:
        BASE_URL: https://webapp-staging.hashfoundry.com

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build, e2e-tests]
    if: startsWith(github.ref, 'refs/tags/v')
    environment:
      name: production
      url: https://webapp.hashfoundry.com
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'

    - name: Setup Kustomize
      uses: imranismail/setup-kustomize@v1

    - name: Configure kubectl
      run: |
        echo "${{ secrets.KUBE_CONFIG_PRODUCTION }}" | base64 -d > ~/.kube/config
        chmod 600 ~/.kube/config

    - name: Deploy to production
      run: |
        cd k8s/overlays/production
        kustomize edit set image hashfoundry/webapp=${{ needs.build.outputs.image-tag }}
        kustomize build . | kubectl apply -f -
        kubectl rollout status deployment/webapp -n ${{ env.KUBE_NAMESPACE }} --timeout=600s

    - name: Verify deployment
      run: |
        kubectl get pods -n ${{ env.KUBE_NAMESPACE }} -l app=webapp
        kubectl get service -n ${{ env.KUBE_NAMESPACE }} webapp-service
        kubectl get ingress -n ${{ env.KUBE_NAMESPACE }} webapp-ingress

    - name: Run production smoke tests
      run: |
        kubectl wait --for=condition=ready pod -l app=webapp -n ${{ env.KUBE_NAMESPACE }} --timeout=300s
        sleep 30
        curl -f https://webapp.hashfoundry.com/health
        curl -f https://webapp.hashfoundry.com/api/status

    - name: Run load tests
      run: |
        kubectl run load-test --image=loadimpact/k6:latest --rm -i --restart=Never -- \
          run --vus 10 --duration 60s - < tests/load/production-load-test.js

  notify:
    name: Notify Deployment
    runs-on: ubuntu-latest
    needs: [deploy-production]
    if: always()
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        fields: repo,message,commit,author,action,eventName,ref,workflow
        custom_payload: |
          {
            "text": "Production Deployment",
            "attachments": [{
              "color": "${{ job.status == 'success' && 'good' || 'danger' }}",
              "fields": [{
                "title": "Repository",
                "value": "${{ github.repository }}",
                "short": true
              }, {
                "title": "Tag",
                "value": "${{ github.ref_name }}",
                "short": true
              }, {
                "title": "Status",
                "value": "${{ job.status }}",
                "short": true
              }, {
                "title": "URL",
                "value": "https://webapp.hashfoundry.com",
                "short": true
              }]
            }]
          }
```

## 🎯 **Проверка Best Practices в вашем кластере:**

### **1. Audit текущих практик:**
```bash
# Скрипт для проверки best practices в кластере
#!/bin/bash
# scripts/audit-best-practices.sh

echo "🔍 Auditing Kubernetes Best Practices in HashFoundry HA Cluster"

# 1. Проверка образов без latest тегов
echo "📦 Checking image tags..."
kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.template.spec.containers[*].image}{"\n"}{end}' | grep -E ":latest|:$" || echo "✅ No latest tags found"

# 2. Проверка resource limits
echo "💾 Checking resource limits..."
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}' | grep -v "limits\|requests" && echo "❌ Pods without resource limits found" || echo "✅ All pods have resource limits"

# 3. Проверка security context
echo "🔒 Checking security contexts..."
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.runAsNonRoot}{"\n"}{end}' | grep -v "true" && echo "❌ Pods running as root found" || echo "✅ All pods run as non-root"

# 4. Проверка health checks
echo "🏥 Checking health checks..."
kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.template.spec.containers[*].livenessProbe}{"\n"}{end}' | grep -v "httpGet\|exec\|tcpSocket" && echo "❌ Deployments without liveness probes found" || echo "✅ All deployments have health checks"

# 5. Проверка network policies
echo "🌐 Checking network policies..."
kubectl get networkpolicies --all-namespaces || echo "❌ No network policies found"

# 6. Проверка pod disruption budgets
echo "🛡️ Checking pod disruption budgets..."
kubectl get pdb --all-namespaces || echo "❌ No pod disruption budgets found"

# 7. Проверка HPA
echo "📈 Checking horizontal pod autoscalers..."
kubectl get hpa --all-namespaces || echo "❌ No horizontal pod autoscalers found"

# 8. Проверка secrets
echo "🔐 Checking secrets management..."
kubectl get secrets --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.type}{"\n"}{end}' | grep -v "kubernetes.io" | head -10

echo "✅ Best practices audit completed!"
```

### **2. Мониторинг в реальном времени:**
```bash
# Команды для мониторинга best practices
# Проверка ArgoCD приложений
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# Проверка ресурсов
kubectl top pods -n argocd
kubectl top nodes

# Проверка событий
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Проверка логов
kubectl logs -f deployment/argocd-application-controller -n argocd --tail=50

# Проверка метрик (если Prometheus установлен)
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
```

## 🏗️ **Архитектура Best Practices:**

```
┌─────────────────────────────────────────────────────────────┐
│                HashFoundry HA Cluster Best Practices       │
├─────────────────────────────────────────────────────────────┤
│  Security Layer                                             │
│  ├── Pod Security Standards (restricted)                    │
│  ├── Network Policies (zero-trust)                          │
│  ├── RBAC (least privilege)                                 │
│  ├── External Secrets Operator                              │
│  └── Security Scanning (SAST/DAST)                          │
│                                                             │
│  Reliability Layer                                          │
│  ├── Resource Limits & Requests                             │
│  ├── Health Checks (liveness/readiness/startup)             │
│  ├── Pod Disruption Budgets                                 │
│  ├── Horizontal Pod Autoscaler                              │
│  └── Anti-Affinity Rules                                    │
│                                                             │
│  Observability Layer                                        │
│  ├── Structured Logging (JSON)                              │
│  ├── Prometheus Metrics                                     │
│  ├── Distributed Tracing                                    │
│  ├── Alerting Rules                                         │
│  └── Grafana Dashboards                                     │
│                                                             │
│  CI/CD Layer                                                │
│  ├── GitOps (ArgoCD)                                        │
│  ├── Multi-stage Testing                                    │
│  ├── Security Scanning                                      │
│  ├── Immutable Artifacts                                    │
│  └── Automated Rollbacks                                    │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Заключение:**

**Best Practices для Kubernetes CI/CD** обеспечивают:

**Ключевые принципы:**
1. **Security by Design** - безопасность на каждом уровне
2. **Reliability First** - надежность через автоматизацию
3. **Observability** - полная видимость процессов
4. **Immutability** - неизменяемые артефакты
5. **Automation** - минимизация человеческого фактора

**Практическое применение в HashFoundry HA кластере:**
- **ArgoCD** для GitOps развертываний
- **Prometheus/Grafana** для мониторинга
- **Security Policies** для защиты
- **Resource Management** для стабильности

Следование этим практикам превращает Kubernetes развертывания в надежный, безопасный и масштабируемый процесс, готовый для production использования.
