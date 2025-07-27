# 20. Объясните стратегию версионирования API Kubernetes

## 🎯 **Что такое API Versioning в Kubernetes?**

**API Versioning** — это система управления версиями API Kubernetes, которая обеспечивает обратную совместимость и плавную эволюцию платформы без нарушения работы существующих приложений.

## 🏗️ **Уровни зрелости API:**

### **1. Alpha (v1alpha1, v1alpha2)**
- Экспериментальные функции
- Могут быть удалены без предупреждения
- Не рекомендуется для production
- Отключены по умолчанию

### **2. Beta (v1beta1, v1beta2)**
- Функции проходят тестирование
- Включены по умолчанию
- Могут изменяться, но с предупреждением
- Подходят для тестирования

### **3. Stable (v1, v2)**
- Стабильные API
- Гарантия обратной совместимости
- Рекомендуется для production
- Долгосрочная поддержка

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Различные версии API:**
```bash
# Посмотреть все доступные API версии
kubectl api-versions

# Группировка по стабильности:
# v1 - стабильные API (Pod, Service, ConfigMap)
# apps/v1 - стабильные API приложений (Deployment, StatefulSet)
# networking.k8s.io/v1 - стабильные сетевые API (Ingress)
# batch/v1 - стабильные batch API (Job)
```

### **2. Стабильные API (v1):**
```bash
# Pod - стабильный API с самого начала
kubectl explain pod --api-version=v1

# Service - стабильный API
kubectl get services -n argocd

# ConfigMap - стабильный API
kubectl get configmaps -n argocd
```

### **3. Apps API группа (apps/v1):**
```bash
# Deployment - стабильный в apps/v1
kubectl get deployments -n argocd

# StatefulSet - стабильный в apps/v1
kubectl get statefulsets -n monitoring

# DaemonSet - стабильный в apps/v1
kubectl get daemonsets -n kube-system
```

### **4. Networking API (networking.k8s.io/v1):**
```bash
# Ingress - стабилизирован в networking.k8s.io/v1
kubectl get ingress -A

# NetworkPolicy - стабильный API
kubectl get networkpolicies -A
```

### **5. Beta API примеры:**
```bash
# Посмотреть beta API
kubectl api-versions | grep beta

# HorizontalPodAutoscaler может быть в autoscaling/v2beta2
kubectl get hpa -A

# CustomResourceDefinitions в apiextensions.k8s.io/v1
kubectl get crd | head -5
```

## 🔄 **API Groups и Versioning:**

### **1. Core API Group (legacy):**
```bash
# Без префикса группы - legacy API
kubectl api-resources --api-group=""

# Примеры:
# v1: Pod, Service, ConfigMap, Secret, Namespace
```

### **2. Named API Groups:**
```bash
# apps группа
kubectl api-resources --api-group=apps

# networking.k8s.io группа
kubectl api-resources --api-group=networking.k8s.io

# batch группа
kubectl api-resources --api-group=batch

# autoscaling группа
kubectl api-resources --api-group=autoscaling
```

### **3. Custom API Groups:**
```bash
# ArgoCD CRDs
kubectl api-resources --api-group=argoproj.io

# Prometheus Operator CRDs (если установлен)
kubectl api-resources --api-group=monitoring.coreos.com
```

## 🔧 **Демонстрация версионирования:**

### **1. Проверка поддерживаемых версий ресурса:**
```bash
# Deployment поддерживает несколько версий
kubectl explain deployment

# Посмотреть все версии Deployment
kubectl api-resources | grep deployments

# Подробности о версиях
kubectl explain deployment --api-version=apps/v1
```

### **2. Использование разных версий:**
```bash
# Создать Deployment с явным указанием версии
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: version-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: version-demo
  template:
    metadata:
      labels:
        app: version-demo
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

# Проверить версию созданного ресурса
kubectl get deployment version-demo -o yaml | grep apiVersion

# Очистка
kubectl delete deployment version-demo
```

### **3. Deprecated API предупреждения:**
```bash
# kubectl предупреждает об устаревших API
# Например, если использовать старую версию Ingress:

# Устаревшая версия (пример)
# apiVersion: extensions/v1beta1
# kind: Ingress

# Новая стабильная версия
# apiVersion: networking.k8s.io/v1
# kind: Ingress
```

## 📈 **Мониторинг API версий:**

### **1. Audit logs для API версий:**
```bash
# В managed кластере audit logs недоступны напрямую
# Но можно анализировать через метрики

kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики API Server:
# apiserver_requested_deprecated_apis - использование deprecated API
# apiserver_request_total{group="apps",version="v1"} - запросы по версиям
```

### **2. Проверка deprecated API:**
```bash
# kubectl может показать предупреждения
kubectl get deployments -n argocd --warnings-as-errors=false

# Проверить какие API версии используются
kubectl get deployments -n argocd -o yaml | grep apiVersion
```

### **3. API discovery:**
```bash
# Получить информацию о поддерживаемых API
kubectl api-versions | sort

# Подробная информация о ресурсах
kubectl api-resources --verbs=list --namespaced -o wide
```

## 🏭 **Версионирование в вашем HA кластере:**

### **1. ArgoCD использует стабильные API:**
```bash
# ArgoCD Deployment использует apps/v1
kubectl get deployment argocd-server -n argocd -o yaml | grep apiVersion

# ArgoCD Service использует v1
kubectl get service argocd-server -n argocd -o yaml | grep apiVersion

# ArgoCD ConfigMaps используют v1
kubectl get configmaps -n argocd -o yaml | grep apiVersion | head -5
```

### **2. Мониторинг использует стабильные API:**
```bash
# Prometheus StatefulSet использует apps/v1
kubectl get statefulset -n monitoring -o yaml | grep apiVersion

# Grafana Deployment использует apps/v1
kubectl get deployment -n monitoring -o yaml | grep apiVersion
```

### **3. Custom Resources:**
```bash
# ArgoCD Applications используют argoproj.io/v1alpha1
kubectl get applications -n argocd -o yaml | grep apiVersion | head -1

# CRDs используют apiextensions.k8s.io/v1
kubectl get crd applications.argoproj.io -o yaml | grep apiVersion
```

## 🚨 **Управление deprecated API:**

### **1. Обнаружение deprecated API:**
```bash
# Проверить предупреждения kubectl
kubectl get all -A --warnings-as-errors=false 2>&1 | grep -i deprecat

# Анализ YAML файлов
find . -name "*.yaml" -exec grep -l "apiVersion:" {} \; | head -5
```

### **2. Миграция API версий:**
```bash
# Пример миграции Ingress
# Старая версия:
# apiVersion: extensions/v1beta1

# Новая версия:
# apiVersion: networking.k8s.io/v1

# Обновить существующие ресурсы
kubectl convert -f old-ingress.yaml --output-version networking.k8s.io/v1
```

### **3. Планирование обновлений:**
```bash
# Проверить версию Kubernetes
kubectl version --short

# Посмотреть changelog для deprecated API
# https://kubernetes.io/docs/reference/using-api/deprecation-guide/
```

## 🎯 **Стратегия версионирования:**

### **1. Жизненный цикл API:**
```
┌─────────────────────────────────────────────────────────────┐
│                    API Lifecycle                           │
├─────────────────────────────────────────────────────────────┤
│  1. Alpha (v1alpha1)                                       │
│     ├── Experimental features                              │
│     ├── May be removed without notice                      │
│     ├── Disabled by default                                │
│     └── Not recommended for production                     │
├─────────────────────────────────────────────────────────────┤
│  2. Beta (v1beta1)                                         │
│     ├── Well-tested features                               │
│     ├── Enabled by default                                 │
│     ├── May change with deprecation notice                 │
│     └── Suitable for testing                               │
├─────────────────────────────────────────────────────────────┤
│  3. Stable (v1)                                            │
│     ├── Production-ready                                   │
│     ├── Backward compatibility guaranteed                  │
│     ├── Long-term support                                  │
│     └── Recommended for production                         │
├─────────────────────────────────────────────────────────────┤
│  4. Deprecated                                             │
│     ├── Marked for removal                                 │
│     ├── Migration path provided                            │
│     ├── Removal timeline announced                         │
│     └── Alternative API available                          │
└─────────────────────────────────────────────────────────────┘
```

### **2. Backward Compatibility Rules:**
```bash
# Kubernetes гарантирует:
# - Stable API не изменяются breaking changes
# - Deprecated API поддерживаются минимум 2 версии
# - Предупреждения о deprecation заранее
# - Миграционные пути для новых версий
```

## 🔄 **Best Practices:**

### **1. Выбор API версий:**
- Используйте stable (v1) для production
- Избегайте alpha в production
- Тестируйте beta версии
- Следите за deprecation notices

### **2. Мониторинг:**
- Отслеживайте deprecated API warnings
- Планируйте миграции заранее
- Тестируйте новые версии API
- Обновляйте документацию

### **3. Миграция:**
- Создавайте план миграции
- Тестируйте в staging среде
- Используйте kubectl convert
- Обновляйте CI/CD пайплайны

### **4. Примеры эволюции API:**
```bash
# Ingress эволюция:
# extensions/v1beta1 → networking.k8s.io/v1beta1 → networking.k8s.io/v1

# Deployment эволюция:
# extensions/v1beta1 → apps/v1beta1 → apps/v1beta2 → apps/v1

# HPA эволюция:
# autoscaling/v1 → autoscaling/v2beta1 → autoscaling/v2beta2 → autoscaling/v2
```

**API Versioning обеспечивает стабильную эволюцию Kubernetes без нарушения работы приложений!**
