# 147. Как реализовать canary развертывания

## 🎯 **Основные концепции:**

| Аспект | Традиционное развертывание | Canary развертывание |
|--------|---------------------------|---------------------|
| **Стратегия выкатки** | Все сразу (Big Bang) | Постепенное увеличение трафика |
| **Риск** | Высокий (влияет на всех пользователей) | Низкий (влияет на малую часть) |
| **Время обнаружения проблем** | После полной выкатки | На ранней стадии |
| **Откат** | Сложный и долгий | Быстрый и простой |
| **Мониторинг** | Базовый | Расширенный с метриками |
| **Автоматизация** | Ограниченная | Полная автоматизация с анализом |
| **Тестирование в продакшене** | Отсутствует | Контролируемое тестирование |
| **Распределение трафика** | 100% на новую версию | Градуальное: 5% → 25% → 50% → 100% |
| **Время развертывания** | Быстрое | Постепенное |
| **Сложность настройки** | Простая | Средняя/высокая |
| **Требования к инфраструктуре** | Минимальные | Дополнительные ресурсы |
| **Observability** | Базовая | Детальная с A/B сравнением |

## 🏆 **Canary развертывания - что это такое?**

**Canary развертывания** — это стратегия постепенного развертывания новой версии приложения, при которой трафик переключается на новую версию поэтапно (например, 5% → 25% → 50% → 100%), что позволяет обнаружить проблемы на раннем этапе и быстро откатиться к стабильной версии при необходимости.

### **Этапы Canary развертывания:**
1. **Подготовка** - развертывание новой версии рядом со стабильной
2. **Начальная фаза** - направление 5-10% трафика на новую версию
3. **Мониторинг** - анализ метрик (error rate, latency, throughput)
4. **Постепенное увеличение** - пошаговое увеличение трафика при успешных метриках
5. **Полная миграция** - переключение 100% трафика на новую версию
6. **Очистка** - удаление старой версии

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих развертываний:**
```bash
# Проверка существующих Deployment'ов
kubectl get deployments -A -o wide

# Анализ стратегий развертывания
kubectl get deployments -A -o json | jq -r '
  .items[] | 
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.strategy.type // "RollingUpdate")"
'

# Поиск Argo Rollouts (если установлен)
kubectl get rollouts -A 2>/dev/null || echo "Argo Rollouts не установлен"

# Проверка Ingress для возможного canary routing
kubectl get ingress -A -o json | jq -r '
  .items[] | 
  select(.metadata.annotations | has("nginx.ingress.kubernetes.io/canary")) | 
  "\(.metadata.namespace)/\(.metadata.name): Canary enabled"
'

# Анализ Service Mesh (Istio) для traffic splitting
kubectl get virtualservices -A 2>/dev/null || echo "Istio VirtualServices не найдены"
kubectl get destinationrules -A 2>/dev/null || echo "Istio DestinationRules не найдены"

# Проверка ArgoCD Applications для progressive delivery
kubectl get applications -n argocd -o json | jq -r '
  .items[] | 
  select(.spec.source.helm.parameters[]?.name == "canary.enabled") | 
  "\(.metadata.name): Canary configured"
' 2>/dev/null || echo "ArgoCD Applications без canary конфигурации"
```

### **2. Проверка готовности для Canary развертываний:**
```bash
# Анализ метрик и мониторинга
kubectl get servicemonitors -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,ENDPOINTS:.spec.endpoints[*].port"

# Проверка Prometheus для сбора метрик
kubectl get pods -n monitoring | grep prometheus

# Анализ health checks в приложениях
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[].readinessProbe and .spec.containers[].livenessProbe) | 
  "\(.metadata.namespace)/\(.metadata.name): Has health checks"
'

# Проверка HPA для автомасштабирования
kubectl get hpa -A

# Анализ ресурсов для canary pods
kubectl top nodes
kubectl top pods -A --sort-by=cpu
```

### **3. Тестирование сетевой готовности:**
```bash
# Проверка Load Balancer и Ingress
kubectl get services -A --field-selector spec.type=LoadBalancer

# Тестирование DNS резолюции для service discovery
kubectl run dns-test --rm -i --restart=Never --image=busybox -- \
  nslookup argocd-server.argocd.svc.cluster.local

# Проверка сетевых политик
kubectl get networkpolicies -A

# Анализ endpoints для балансировки нагрузки
kubectl get endpoints -A -o json | jq -r '
  .items[] | 
  select(.subsets[].addresses | length > 1) | 
  "\(.metadata.namespace)/\(.metadata.name): \(.subsets[].addresses | length) endpoints"
'
```

## 🛠️ **Comprehensive Canary Implementation:**

### **1. Argo Rollouts - Advanced Canary Strategy:**
```yaml
# k8s/canary/argo-rollouts-setup.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argo-rollouts
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-rollouts
  namespace: argo-rollouts
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-rollouts
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["*"]
- apiGroups: ["argoproj.io"]
  resources: ["rollouts", "rollouts/status", "experiments", "analysistemplates", "clusteranalysistemplates", "analysisruns"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["networking.istio.io"]
  resources: ["virtualservices", "destinationrules"]
  verbs: ["get", "list", "watch", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-rollouts
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-rollouts
subjects:
- kind: ServiceAccount
  name: argo-rollouts
  namespace: argo-rollouts
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argo-rollouts-controller
  namespace: argo-rollouts
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: argo-rollouts-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argo-rollouts-controller
    spec:
      serviceAccountName: argo-rollouts
      containers:
      - name: argo-rollouts
        image: quay.io/argoproj/argo-rollouts:v1.6.0
        command:
        - /manager
        args:
        - --leader-elect
        - --prometheus-listen-port=8090
        - --klogs-level=0
        - --log-level=info
        - --log-format=text
        ports:
        - name: metrics
          containerPort: 8090
          protocol: TCP
        - name: healthz
          containerPort: 8080
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /healthz
            port: healthz
          initialDelaySeconds: 30
          periodSeconds: 20
          successThreshold: 1
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /metrics
            port: metrics
          initialDelaySeconds: 10
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 4
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 999
```

### **2. HashFoundry Canary Rollout Configuration:**
```yaml
# k8s/canary/hashfoundry-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: hashfoundry-webapp-rollout
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: rollout
spec:
  replicas: 10
  strategy:
    canary:
      maxSurge: "25%"
      maxUnavailable: 0
      analysis:
        templates:
        - templateName: hashfoundry-success-rate
        - templateName: hashfoundry-latency-check
        startingStep: 2
        args:
        - name: service-name
          value: hashfoundry-webapp-canary
        - name: namespace
          value: hashfoundry-production
      steps:
      - setWeight: 5
      - pause: {duration: 2m}
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 40
      - pause: {duration: 10m}
      - setWeight: 60
      - pause: {duration: 10m}
      - setWeight: 80
      - pause: {duration: 10m}
      canaryService: hashfoundry-webapp-canary
      stableService: hashfoundry-webapp-stable
      trafficRouting:
        nginx:
          stableIngress: hashfoundry-webapp-stable
          annotationPrefix: nginx.ingress.kubernetes.io
          additionalIngressAnnotations:
            canary-by-header: X-Canary
            canary-by-cookie: canary-user
      scaleDownDelaySeconds: 30
      abortScaleDownDelaySeconds: 30
  selector:
    matchLabels:
      app.kubernetes.io/name: hashfoundry-webapp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: hashfoundry-webapp
        app.kubernetes.io/version: "{{.Values.image.tag}}"
    spec:
      containers:
      - name: webapp
        image: hashfoundry/webapp:v1.0.0
        ports:
        - name: http
          containerPort: 3000
          protocol: TCP
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        - name: VERSION
          value: "{{.Values.image.tag}}"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
  revisionHistoryLimit: 5
---
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-webapp-stable
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: stable-service
spec:
  selector:
    app.kubernetes.io/name: hashfoundry-webapp
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-webapp-canary
  namespace: hashfoundry-production
  labels:
    app.kubernetes.io/name: hashfoundry-webapp
    app.kubernetes.io/component: canary-service
spec:
  selector:
    app.kubernetes.io/name: hashfoundry-webapp
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  type: ClusterIP
```

### **3. Analysis Templates для автоматической оценки:**
```yaml
# k8s/canary/analysis-templates.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: hashfoundry-success-rate
  namespace: hashfoundry-production
spec:
  args:
  - name: service-name
  - name: namespace
  metrics:
  - name: success-rate
    interval: 1m
    count: 5
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local:80
        query: |
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}",
              status!~"5.."
            }[2m]
          )) / 
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}"
            }[2m]
          ))
  - name: error-rate
    interval: 1m
    count: 5
    successCondition: result[0] <= 0.05
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local:80
        query: |
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}",
              status=~"5.."
            }[2m]
          )) / 
          sum(rate(
            http_requests_total{
              job="{{args.service-name}}",
              namespace="{{args.namespace}}"
            }[2m]
          ))
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: hashfoundry-latency-check
  namespace: hashfoundry-production
spec:
  args:
  - name: service-name
  - name: namespace
  metrics:
  - name: avg-response-time
    interval: 1m
    count: 5
    successCondition: result[0] <= 0.5
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local:80
        query: |
          histogram_quantile(0.95,
            sum(rate(
              http_request_duration_seconds_bucket{
                job="{{args.service-name}}",
                namespace="{{args.namespace}}"
              }[2m]
            )) by (le)
          )
  - name: p99-response-time
    interval: 1m
    count: 5
    successCondition: result[0] <= 1.0
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local:80
        query: |
          histogram_quantile(0.99,
            sum(rate(
              http_request_duration_seconds_bucket{
                job="{{args.service-name}}",
                namespace="{{args.namespace}}"
              }[2m]
            )) by (le)
          )
  - name: memory-usage
    interval: 1m
    count: 5
    successCondition: result[0] <= 400000000  # 400MB
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local:80
        query: |
          avg(
            container_memory_usage_bytes{
              pod=~"hashfoundry-webapp-rollout-.*",
              namespace="{{args.namespace}}",
              container="webapp"
            }
          )
  - name: cpu-usage
    interval: 1m
    count: 5
    successCondition: result[0] <= 0.8  # 80% CPU
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-server.monitoring.svc.cluster.local:80
        query: |
          avg(
            rate(container_cpu_usage_seconds_total{
              pod=~"hashfoundry-webapp-rollout-.*",
              namespace="{{args.namespace}}",
              container="webapp"
            }[2m])
          )
```

### **4. NGINX Ingress Canary Configuration:**
```yaml
# k8s/canary/nginx-ingress-canary.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hashfoundry-webapp-stable
  namespace: hashfoundry-production
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - app.hashfoundry.com
    secretName: hashfoundry-webapp-tls
  rules:
  - host: app.hashfoundry.com
    http:
      paths:
      - path: /(.*)
        pathType: Prefix
        backend:
          service:
            name: hashfoundry-webapp-stable
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hashfoundry-webapp-canary
  namespace: hashfoundry-production
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "0"
    nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
    nginx.ingress.kubernetes.io/canary-by-header-value: "true"
    nginx.ingress.kubernetes.io/canary-by-cookie: "canary-user"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  tls:
  - hosts:
    - app.hashfoundry.com
    secretName: hashfoundry-webapp-tls
  rules:
  - host: app.hashfoundry.com
    http:
      paths:
      - path: /(.*)
        pathType: Prefix
        backend:
          service:
            name: hashfoundry-webapp-canary
            port:
              number: 80
```

## 🎓 **Заключение:**

**Canary развертывания** обеспечивают безопасный и контролируемый способ выкатки новых версий приложений с минимальными рисками.

### **🔑 Ключевые преимущества:**
1. **Снижение рисков** - проблемы затрагивают только малую часть пользователей
2. **Быстрое обнаружение** - проблемы выявляются на ранней стадии
3. **Автоматический откат** - система может автоматически вернуться к стабильной версии
4. **Постепенная миграция** - плавный переход без простоев
5. **A/B тестирование** - возможность сравнения версий в реальных условиях
6. **Мониторинг в реальном времени** - детальная аналитика производительности

### **🛠️ Основные инструменты:**
- **Argo Rollouts** - продвинутые стратегии развертывания
- **NGINX Ingress** - управление трафиком на уровне Ingress
- **Istio Service Mesh** - сложная маршрутизация трафика
- **Prometheus + Grafana** - мониторинг и алертинг
- **Flagger** - автоматизация canary развертываний

### **🎯 Основные команды для изучения в вашем HA кластере:**
```bash
# Анализ текущих развертываний
kubectl get deployments -A -o wide
kubectl get rollouts -A

# Проверка готовности для canary
kubectl get servicemonitors -A
kubectl get ingress -A

# Мониторинг canary развертываний
kubectl argo rollouts get rollout hashfoundry-webapp-rollout -n hashfoundry-production
kubectl argo rollouts status hashfoundry-webapp-rollout -n hashfoundry-production

# Управление canary
kubectl argo rollouts promote hashfoundry-webapp-rollout -n hashfoundry-production
kubectl argo rollouts abort hashfoundry-webapp-rollout -n hashfoundry-production
```

### **🚀 Следующие шаги:**
1. Установите Argo Rollouts в ваш HA кластер
2. Настройте мониторинг метрик с Prometheus
3. Создайте Analysis Templates для автоматической оценки
4. Внедрите canary развертывания для критических приложений
5. Настройте алертинг для быстрого реагирования на проблемы

**Помните:** Canary развертывания требуют хорошего мониторинга и четко определенных метрик успеха для эффективной работы!
