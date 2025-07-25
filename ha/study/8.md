# 8. Что такое Labels и Selectors в Kubernetes?

## 🎯 **Что такое Labels?**

**Labels (Метки)** — это пары ключ-значение, прикрепленные к Kubernetes объектам для их идентификации и группировки.

### **Характеристики Labels:**
- **Произвольные** пары ключ-значение
- **Не уникальные** (много объектов могут иметь одинаковые labels)
- **Используются для организации** и выбора объектов
- **Могут изменяться** во время выполнения

## 🎯 **Что такое Selectors?**

**Selectors (Селекторы)** — это запросы для поиска объектов по их labels.

### **Типы Selectors:**
- **Equality-based**: `app=nginx`, `version!=v1`
- **Set-based**: `environment in (production, qa)`, `tier notin (frontend)`

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Посмотреть Labels на объектах:**
```bash
# Labels на Pod'ах ArgoCD
kubectl get pods -n argocd --show-labels

# Labels на Node'ах
kubectl get nodes --show-labels

# Labels на Services
kubectl get svc -n argocd --show-labels

# Labels на Deployments
kubectl get deployments -n argocd --show-labels
```

### **2. Использование Selectors для поиска:**
```bash
# Найти Pod'ы ArgoCD Server
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Найти Pod'ы ArgoCD Controller
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Найти все Pod'ы ArgoCD
kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd

# Найти Redis HA Pod'ы
kubectl get pods -n argocd -l app=redis-ha
```

### **3. Мониторинг с Labels:**
```bash
# Prometheus Pod'ы
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Grafana Pod'ы
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# NFS Exporter Pod'ы
kubectl get pods -l app=nfs-exporter --show-labels

# Все мониторинг Pod'ы
kubectl get pods -A -l 'app.kubernetes.io/component in (prometheus,grafana)'
```

### **4. Services и их Selectors:**
```bash
# Посмотреть как Service выбирает Pod'ы
kubectl describe svc argocd-server -n argocd | grep -A 3 "Selector:"

# Endpoints показывают результат селекции
kubectl get endpoints argocd-server -n argocd

# Service для Prometheus
kubectl describe svc prometheus-server -n monitoring | grep -A 3 "Selector:"
```

### **5. Deployments и их Selectors:**
```bash
# Selector в Deployment ArgoCD Server
kubectl get deployment argocd-server -n argocd -o yaml | grep -A 5 "selector:"

# ReplicaSet использует тот же selector
kubectl get replicaset -n argocd -l app.kubernetes.io/name=argocd-server

# Pod'ы должны соответствовать selector'у
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

## 🔧 **Работа с Labels:**

### **1. Добавление Labels:**
```bash
# Добавить label к Pod'у
kubectl label pod <pod-name> -n argocd environment=production

# Добавить label к Node
kubectl label node <node-name> disktype=ssd

# Добавить label к Namespace
kubectl label namespace argocd team=platform
```

### **2. Изменение Labels:**
```bash
# Изменить существующий label
kubectl label pod <pod-name> -n argocd environment=staging --overwrite

# Удалить label
kubectl label pod <pod-name> -n argocd environment-

# Посмотреть изменения
kubectl get pod <pod-name> -n argocd --show-labels
```

### **3. Сложные Selectors:**
```bash
# Equality-based selectors
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
kubectl get pods -n argocd -l 'app.kubernetes.io/name!=argocd-server'

# Set-based selectors
kubectl get pods -A -l 'app.kubernetes.io/name in (prometheus,grafana)'
kubectl get pods -A -l 'environment notin (development,test)'

# Множественные условия
kubectl get pods -n argocd -l 'app.kubernetes.io/part-of=argocd,app.kubernetes.io/name=argocd-server'
```

## 🏭 **Стандартные Labels в вашем кластере:**

### **1. Kubernetes рекомендуемые labels:**
```bash
# app.kubernetes.io/name - имя приложения
kubectl get pods -A -l app.kubernetes.io/name=argocd-server

# app.kubernetes.io/instance - экземпляр приложения
kubectl get pods -A -l app.kubernetes.io/instance=argocd

# app.kubernetes.io/version - версия приложения
kubectl get pods -A --show-labels | grep version

# app.kubernetes.io/component - компонент архитектуры
kubectl get pods -A -l app.kubernetes.io/component=server

# app.kubernetes.io/part-of - часть какого приложения
kubectl get pods -A -l app.kubernetes.io/part-of=argocd
```

### **2. Helm labels:**
```bash
# app.kubernetes.io/managed-by - кто управляет
kubectl get pods -A -l app.kubernetes.io/managed-by=Helm

# helm.sh/chart - какой Helm chart
kubectl get pods -A --show-labels | grep helm.sh/chart

# Все Helm ресурсы
kubectl get all -A -l app.kubernetes.io/managed-by=Helm
```

### **3. ArgoCD labels:**
```bash
# argocd.argoproj.io/instance - ArgoCD application
kubectl get pods -A --show-labels | grep argocd.argoproj.io

# Все ресурсы управляемые ArgoCD
kubectl get all -A -l argocd.argoproj.io/instance
```

## 🔄 **Практические сценарии использования:**

### **1. Развертывание по окружениям:**
```bash
# Создать Pod для production
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web-prod
  labels:
    app: web
    environment: production
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx
EOF

# Создать Pod для staging
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web-staging
  labels:
    app: web
    environment: staging
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx
EOF

# Найти только production Pod'ы
kubectl get pods -l environment=production

# Найти все web Pod'ы
kubectl get pods -l app=web

# Очистка
kubectl delete pod web-prod web-staging
```

### **2. Service с Selector:**
```bash
# Создать Service, который выберет Pod'ы по labels
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
    tier: frontend
  ports:
  - port: 80
    targetPort: 80
EOF

# Посмотреть какие Pod'ы выбрал Service
kubectl describe svc web-service | grep -A 3 "Selector:"
kubectl get endpoints web-service

# Очистка
kubectl delete svc web-service
```

### **3. Deployment с Labels и Selectors:**
```bash
# Создать Deployment с labels
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
      tier: frontend
  template:
    metadata:
      labels:
        app: web
        tier: frontend
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

# Посмотреть на labels и selectors
kubectl describe deployment web-deployment | grep -A 5 "Selector:"
kubectl get pods -l app=web --show-labels

# Очистка
kubectl delete deployment web-deployment
```

## 📈 **Labels в мониторинге:**

### **1. Prometheus использует labels для метрик:**
```bash
# ServiceMonitor выбирает Service'ы по labels
kubectl get servicemonitor -n monitoring -o yaml | grep -A 5 "selector:"

# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# В Prometheus UI метрики содержат labels:
# container_cpu_usage_seconds_total{pod="argocd-server-xxx", namespace="argocd"}
# kube_pod_info{pod="argocd-server-xxx", namespace="argocd", created_by_kind="ReplicaSet"}
```

### **2. Grafana дашборды фильтруют по labels:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# В дашбордах можно фильтровать по:
# - namespace
# - pod
# - app.kubernetes.io/name
# - environment
```

## 🎯 **Best Practices для Labels:**

### **1. Стандартные labels:**
```bash
# Всегда используйте рекомендуемые labels
app.kubernetes.io/name: argocd
app.kubernetes.io/instance: argocd
app.kubernetes.io/version: v2.8.0
app.kubernetes.io/component: server
app.kubernetes.io/part-of: argocd
app.kubernetes.io/managed-by: Helm
```

### **2. Организационные labels:**
```bash
# Для организации ресурсов
environment: production
team: platform
cost-center: engineering
project: hashfoundry
```

### **3. Технические labels:**
```bash
# Для технических нужд
tier: frontend
layer: application
monitoring: enabled
backup: required
```

## 🔍 **Отладка с Labels и Selectors:**

### **1. Проверить почему Service не работает:**
```bash
# Посмотреть selector Service'а
kubectl describe svc <service-name> -n <namespace> | grep -A 3 "Selector:"

# Найти Pod'ы с такими labels
kubectl get pods -n <namespace> -l <selector-from-service>

# Проверить endpoints
kubectl get endpoints <service-name> -n <namespace>
```

### **2. Проверить почему Deployment не создает Pod'ы:**
```bash
# Посмотреть selector Deployment'а
kubectl describe deployment <deployment-name> -n <namespace> | grep -A 5 "Selector:"

# Проверить ReplicaSet
kubectl get replicaset -n <namespace> -l <deployment-labels>

# Проверить события
kubectl get events -n <namespace> --field-selector involvedObject.kind=ReplicaSet
```

## 🏗️ **Labels в вашем HA кластере:**

### **Организация по компонентам:**
```bash
# ArgoCD компоненты
kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --show-labels

# Мониторинг компоненты
kubectl get pods -n monitoring --show-labels

# Ingress компоненты
kubectl get pods -n ingress-nginx --show-labels
```

### **Высокая доступность через labels:**
```bash
# Anti-affinity использует labels для распределения
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 10 "Affinity:"

# PodDisruptionBudget использует selector
kubectl get pdb -A -o yaml | grep -A 3 "selector:"
```

**Labels и Selectors — это основа организации и управления ресурсами в Kubernetes!**
