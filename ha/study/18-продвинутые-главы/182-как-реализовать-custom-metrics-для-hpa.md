# 182. Как реализовать custom metrics для HPA?

## 🎯 **Что такое Custom Metrics для HPA?**

**Custom Metrics для HPA** — это механизм автомасштабирования приложений на основе специфических метрик приложения или внешних систем, а не только CPU/Memory. Реализуется через Custom Metrics API и External Metrics API, позволяя HPA принимать решения на основе бизнес-метрик.

## 🏗️ **Основные типы метрик для HPA:**

### **1. Resource Metrics**
- Стандартные ресурсные метрики (CPU, Memory)
- Источник: metrics-server
- Простая настройка и использование

### **2. Custom Metrics**
- Метрики из кластера (pods, objects)
- Источник: custom metrics adapter
- Специфические метрики приложений

### **3. External Metrics**
- Метрики из внешних систем
- Источник: external metrics adapter
- Cloud provider метрики, SaaS сервисы

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка metrics APIs:**
```bash
# Доступные metrics APIs
kubectl api-versions | grep metrics

# Metrics-server для resource metrics
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Проверка custom metrics API
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"

# Проверка external metrics API
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1"
```

### **2. HPA в мониторинге:**
```bash
# Существующие HPA
kubectl get hpa --all-namespaces

# HPA для ArgoCD (если есть)
kubectl describe hpa -n argocd

# Prometheus метрики для HPA
kubectl get --raw /metrics | grep hpa_controller
```

### **3. Prometheus как источник custom metrics:**
```bash
# Prometheus в monitoring namespace
kubectl get pods -n monitoring -l app=prometheus

# Доступные метрики в Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Открыть http://localhost:9090/api/v1/label/__name__/values
```

### **4. Создание HPA с resource metrics:**
```bash
# Простой HPA для тестирования
kubectl create deployment test-app --image=nginx --replicas=1

# Установка resource requests
kubectl patch deployment test-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"cpu":"100m","memory":"128Mi"}}}]}}}}'

# Создание HPA
kubectl autoscale deployment test-app --cpu-percent=50 --min=1 --max=10

# Проверка HPA
kubectl get hpa test-app

# Очистка
kubectl delete hpa test-app
kubectl delete deployment test-app
```

## 🔄 **Настройка Prometheus Adapter:**

### **1. Конфигурация Prometheus Adapter:**
```bash
# Создание ConfigMap для Prometheus Adapter
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: adapter-config
  namespace: monitoring
data:
  config.yaml: |
    rules:
    # HTTP requests per second
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: {resource: namespace}
          pod: {resource: pod}
      name:
        matches: "^http_requests_total"
        as: "requests_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
    
    # Queue length metric
    - seriesQuery: 'queue_length{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: {resource: namespace}
          pod: {resource: pod}
      name:
        matches: "^queue_length"
        as: "queue_length"
      metricsQuery: 'avg(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'
EOF

# Проверка конфигурации
kubectl describe configmap adapter-config -n monitoring
```

### **2. Развертывание Prometheus Adapter:**
```bash
# ServiceAccount и RBAC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-adapter
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-adapter
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/stats", "namespaces", "pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-adapter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-adapter
subjects:
- kind: ServiceAccount
  name: prometheus-adapter
  namespace: monitoring
EOF

# Проверка RBAC
kubectl describe clusterrole prometheus-adapter
```

## 🔧 **Демонстрация Custom Metrics HPA:**

### **1. Приложение с custom метриками:**
```bash
# Создание приложения с метриками
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-metrics-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: custom-metrics-app
  template:
    metadata:
      labels:
        app: custom-metrics-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 8080
          name: metrics
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: custom-metrics-app
  namespace: default
spec:
  selector:
    app: custom-metrics-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 8080
    targetPort: 8080
EOF

# Проверка развертывания
kubectl get pods -l app=custom-metrics-app
kubectl get svc custom-metrics-app
```

### **2. HPA с custom метриками:**
```bash
# HPA на основе requests per second
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: custom-metrics-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: custom-metrics-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "50"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
EOF

# Проверка HPA
kubectl describe hpa custom-metrics-hpa
kubectl get hpa custom-metrics-hpa -w
```

### **3. Тестирование нагрузки:**
```bash
# Генерация нагрузки для тестирования HPA
kubectl run load-generator --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://custom-metrics-app.default.svc.cluster.local; done"

# Мониторинг HPA в реальном времени
kubectl get hpa custom-metrics-hpa -w

# Проверка масштабирования
kubectl get pods -l app=custom-metrics-app -w

# Остановка нагрузки
kubectl delete pod load-generator

# Очистка
kubectl delete hpa custom-metrics-hpa
kubectl delete deployment custom-metrics-app
kubectl delete svc custom-metrics-app
```

## 📈 **Мониторинг HPA с Custom Metrics:**

### **1. HPA метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# HPA метрики в Prometheus:
# hpa_controller_reconcile_duration_seconds - время обработки HPA
# hpa_controller_reconcile_errors_total - ошибки HPA controller
# hpa_controller_reconciliations_total - количество обработок HPA
```

### **2. Анализ HPA событий:**
```bash
# События HPA
kubectl get events --all-namespaces --field-selector reason=SuccessfulRescale

# Неудачные масштабирования
kubectl get events --all-namespaces --field-selector reason=FailedGetScale

# HPA controller логи
kubectl logs -n kube-system -l app=horizontal-pod-autoscaler
```

### **3. Custom metrics доступность:**
```bash
# Проверка custom metrics API
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .

# Конкретные метрики
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/pods/*/requests_per_second" | jq .

# External metrics API
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .
```

## 🏭 **Custom Metrics в вашем HA кластере:**

### **1. Мониторинг стека и HPA:**
```bash
# Prometheus метрики для HPA
kubectl get pods -n monitoring -l app=prometheus

# Grafana для визуализации HPA
kubectl port-forward svc/grafana -n monitoring 3000:80

# ArgoCD приложения с HPA
kubectl get applications -n argocd
```

### **2. HA для Prometheus Adapter:**
```bash
# Prometheus Adapter в HA режиме
kubectl get deployment prometheus-adapter -n monitoring

# Масштабирование Prometheus Adapter
kubectl scale deployment prometheus-adapter --replicas=2 -n monitoring

# Проверка leader election
kubectl describe lease prometheus-adapter -n monitoring
```

### **3. Интеграция с ArgoCD:**
```bash
# HPA как часть ArgoCD приложения
kubectl get applications -n argocd -o yaml | grep -A 10 hpa

# Синхронизация HPA через GitOps
kubectl describe application monitoring -n argocd | grep -A 5 hpa
```

## 🔄 **Типы HPA метрик:**

### **1. Resource-based HPA:**
```bash
# CPU и Memory HPA
kubectl get hpa --all-namespaces | grep Resource

# Проверка resource requests
kubectl describe deployment -n monitoring prometheus-server | grep -A 5 Requests
```

### **2. Custom metrics HPA:**
```bash
# Pod-based custom metrics
kubectl get hpa --all-namespaces -o yaml | grep -A 5 "type: Pods"

# Object-based custom metrics
kubectl get hpa --all-namespaces -o yaml | grep -A 5 "type: Object"
```

### **3. External metrics HPA:**
```bash
# External metrics sources
kubectl get hpa --all-namespaces -o yaml | grep -A 5 "type: External"

# Cloud provider metrics
kubectl describe hpa | grep -A 10 external
```

## 🎯 **Архитектура Custom Metrics:**

```
┌─────────────────────────────────────────────────────────────┐
│                Custom Metrics Architecture                 │
├─────────────────────────────────────────────────────────────┤
│  HPA Controller                                             │
│  ├── Resource Metrics API (metrics-server)                 │
│  ├── Custom Metrics API (prometheus-adapter)               │
│  └── External Metrics API (cloud adapters)                 │
├─────────────────────────────────────────────────────────────┤
│  Metrics Adapters                                           │
│  ├── Prometheus Adapter (custom metrics)                   │
│  ├── CloudWatch Adapter (AWS metrics)                      │
│  ├── Stackdriver Adapter (GCP metrics)                     │
│  └── Custom Adapters (specific integrations)               │
├─────────────────────────────────────────────────────────────┤
│  Metrics Sources                                            │
│  ├── Prometheus Server (application metrics)               │
│  ├── Application Exporters (custom metrics)                │
│  ├── Cloud Provider APIs (external metrics)                │
│  └── Third-party Services (SaaS metrics)                   │
├─────────────────────────────────────────────────────────────┤
│  Target Applications                                        │
│  ├── Deployments with HPA                                  │
│  ├── StatefulSets with HPA                                 │
│  └── Custom Resources with HPA                             │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Конфигурация HPA Behavior:**

### **1. Scaling Policies:**
```bash
# HPA с настроенным поведением
cat << EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: advanced-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: test-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
EOF

# Проверка поведения HPA
kubectl describe hpa advanced-hpa | grep -A 20 Behavior
```

## 🚨 **Troubleshooting Custom Metrics HPA:**

### **1. HPA не масштабируется:**
```bash
# Проверка HPA статуса
kubectl describe hpa <hpa-name>

# Проверка метрик
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/<namespace>/pods/*/requests_per_second"

# HPA controller логи
kubectl logs -n kube-system -l app=horizontal-pod-autoscaler
```

### **2. Custom metrics недоступны:**
```bash
# Проверка Prometheus Adapter
kubectl get pods -n monitoring -l app=prometheus-adapter

# Adapter логи
kubectl logs -n monitoring -l app=prometheus-adapter

# API service статус
kubectl get apiservice v1beta1.custom.metrics.k8s.io
```

### **3. Медленное масштабирование:**
```bash
# HPA метрики производительности
kubectl get --raw /metrics | grep hpa_controller_reconcile_duration

# Stabilization windows
kubectl describe hpa <hpa-name> | grep -A 10 stabilizationWindowSeconds

# Metrics collection time
kubectl get --raw /metrics | grep prometheus_adapter
```

## 🎯 **Best Practices для Custom Metrics HPA:**

### **1. Мониторинг:**
- Отслеживайте HPA метрики и события
- Мониторьте доступность custom metrics
- Проверяйте производительность adapters

### **2. Конфигурация:**
- Используйте подходящие stabilization windows
- Настраивайте scaling policies
- Тестируйте HPA поведение

### **3. Метрики:**
- Выбирайте релевантные метрики для масштабирования
- Избегайте слишком чувствительных метрик
- Комбинируйте разные типы метрик

### **4. Производительность:**
- Оптимизируйте queries в Prometheus Adapter
- Используйте caching для external metrics
- Мониторьте latency metrics collection

**Custom Metrics HPA — это мощный инструмент для intelligent автомасштабирования на основе бизнес-метрик!**
