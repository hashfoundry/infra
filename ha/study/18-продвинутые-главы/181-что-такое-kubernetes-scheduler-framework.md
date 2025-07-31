# 181. Что такое Kubernetes scheduler framework?

## 🎯 **Что такое Kubernetes Scheduler Framework?**

**Kubernetes Scheduler Framework** — это расширяемая архитектура планировщика, которая позволяет создавать custom scheduling plugins для реализации специфической логики размещения Pod'ов. Framework предоставляет extension points в жизненном цикле планирования без изменения core scheduler кода.

## 🏗️ **Основные функции Scheduler Framework:**

### **1. Extension Points**
- Предоставляет точки расширения в цикле планирования
- Позволяет подключать custom логику
- Поддерживает различные этапы scheduling

### **2. Plugin Architecture**
- Модульная архитектура с plugin'ами
- Возможность включения/отключения plugins
- Конфигурируемые параметры plugins

### **3. Scheduling Cycles**
- Scheduling Cycle (выбор Node)
- Binding Cycle (привязка Pod'а)
- Асинхронная обработка

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Scheduler в действии:**
```bash
# Scheduler Pod в kube-system
kubectl get pods -n kube-system -l component=kube-scheduler

# Конфигурация scheduler
kubectl get configmap -n kube-system | grep scheduler

# Scheduler логи
kubectl logs -n kube-system -l component=kube-scheduler
```

### **2. Планирование ArgoCD Pod'ов:**
```bash
# ArgoCD Pod'ы и их размещение
kubectl get pods -n argocd -o wide

# События планирования ArgoCD
kubectl get events -n argocd --field-selector reason=Scheduled

# Node affinity для ArgoCD
kubectl describe deployment argocd-server -n argocd | grep -A 5 Affinity
```

### **3. Мониторинг Pod'ы и scheduler:**
```bash
# Prometheus Pod'ы на разных Node'ах
kubectl get pods -n monitoring -o wide

# Scheduler решения для Prometheus
kubectl describe pod -n monitoring -l app=prometheus

# Resource requests влияющие на планирование
kubectl describe pod -n monitoring -l app=prometheus | grep -A 10 Requests
```

### **4. Pending Pod'ы:**
```bash
# Поиск pending Pod'ов
kubectl get pods --all-namespaces --field-selector status.phase=Pending

# Причины неудачного планирования
kubectl describe pod <pending-pod> | grep -A 10 Events

# Scheduler events
kubectl get events --all-namespaces --field-selector reason=FailedScheduling
```

## 🔄 **Extension Points в Scheduler Framework:**

### **1. Scheduling Cycle:**
```bash
# QueueSort - сортировка Pod'ов в очереди
# PreFilter - предварительная фильтрация
# Filter - фильтрация Node'ов
# PostFilter - действия при отсутствии подходящих Node'ов
# PreScore - подготовка к scoring
# Score - оценка Node'ов
# NormalizeScore - нормализация scores
# Reserve - резервирование ресурсов

# Проверка scheduler метрик
kubectl get --raw /metrics | grep scheduler_plugin
```

### **2. Binding Cycle:**
```bash
# Permit - разрешение binding
# PreBind - подготовка к binding
# Bind - привязка Pod'а к Node
# PostBind - действия после binding
# Unreserve - освобождение ресурсов при ошибке

# Binding события
kubectl get events --all-namespaces --field-selector reason=Binding
```

## 🔧 **Демонстрация работы Scheduler Framework:**

### **1. Создание Pod'а с особыми требованиями:**
```bash
# Pod с node selector
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-scheduler-framework
spec:
  nodeSelector:
    kubernetes.io/os: linux
  containers:
  - name: test
    image: nginx:alpine
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

# Отслеживание планирования
kubectl describe pod test-scheduler-framework | grep -A 10 Events

# Scheduler принял решение
kubectl get pod test-scheduler-framework -o wide

# Очистка
kubectl delete pod test-scheduler-framework
```

### **2. Pod с affinity правилами:**
```bash
# Pod с node affinity
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/arch
            operator: In
            values:
            - amd64
  containers:
  - name: test
    image: nginx:alpine
EOF

# Scheduler обработал affinity
kubectl describe pod test-affinity | grep -A 5 "Node-Selectors"

# Результат планирования
kubectl get pod test-affinity -o wide

# Очистка
kubectl delete pod test-affinity
```

### **3. Resource-based scheduling:**
```bash
# Pod с большими resource requests
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-resources
spec:
  containers:
  - name: test
    image: nginx:alpine
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 1000m
        memory: 2Gi
EOF

# Scheduler учел resource requirements
kubectl describe pod test-resources | grep -A 10 "QoS Class"

# Node с достаточными ресурсами
kubectl get pod test-resources -o wide

# Очистка
kubectl delete pod test-resources
```

## 📈 **Мониторинг Scheduler Framework:**

### **1. Scheduler метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Scheduler метрики в Prometheus:
# scheduler_scheduling_duration_seconds - время планирования
# scheduler_plugin_execution_duration_seconds - время выполнения plugins
# scheduler_pending_pods - количество pending Pod'ов
# scheduler_schedule_attempts_total - попытки планирования
```

### **2. Scheduler performance:**
```bash
# Время планирования Pod'ов
kubectl get --raw /metrics | grep "scheduler_scheduling_duration_seconds"

# Производительность plugins
kubectl get --raw /metrics | grep "scheduler_plugin_execution"

# Throughput scheduler'а
kubectl get --raw /metrics | grep "scheduler_schedule_attempts"
```

### **3. Анализ планирования:**
```bash
# События планирования
kubectl get events --all-namespaces --field-selector reason=Scheduled --sort-by='.lastTimestamp'

# Неудачные попытки
kubectl get events --all-namespaces --field-selector reason=FailedScheduling

# Preemption события
kubectl get events --all-namespaces --field-selector reason=Preempted
```

## 🏭 **Scheduler Framework в вашем HA кластере:**

### **1. High Availability Scheduler:**
```bash
# Scheduler работает в HA режиме
kubectl get pods -n kube-system -l component=kube-scheduler

# Leader election для scheduler
kubectl describe lease -n kube-system kube-scheduler

# Scheduler на разных control plane Node'ах
kubectl get pods -n kube-system -l component=kube-scheduler -o wide
```

### **2. ArgoCD и Scheduler Framework:**
```bash
# ArgoCD Server размещение
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide

# Scheduler учел HA требования ArgoCD
kubectl describe deployment argocd-server -n argocd | grep -A 5 "Pod Template"

# Anti-affinity для ArgoCD HA
kubectl get deployment argocd-server -n argocd -o yaml | grep -A 10 affinity
```

### **3. Мониторинг и Scheduler:**
```bash
# Prometheus Pod'ы распределены по Node'ам
kubectl get pods -n monitoring -o wide

# Scheduler обеспечил распределение нагрузки
kubectl describe statefulset prometheus-server -n monitoring

# Resource-based планирование для мониторинга
kubectl describe pod -n monitoring -l app=prometheus | grep -A 5 Requests
```

## 🔄 **Default Plugins в Scheduler Framework:**

### **1. Filtering Plugins:**
```bash
# NodeResourcesFit - проверка ресурсов
# NodeAffinity - node affinity правила
# PodTopologySpread - распределение Pod'ов
# TaintToleration - taints и tolerations

# Проверка Node ресурсов
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### **2. Scoring Plugins:**
```bash
# NodeResourcesFit - предпочтение Node'ов с ресурсами
# ImageLocality - предпочтение Node'ов с образами
# InterPodAffinity - pod affinity scoring
# NodeAffinity - node affinity scoring

# Распределение Pod'ов по Node'ам
kubectl get pods --all-namespaces -o wide | awk '{print $8}' | sort | uniq -c
```

### **3. Binding Plugins:**
```bash
# DefaultBinder - стандартный binding
# VolumeBinding - binding с учетом volumes

# Volume binding события
kubectl get events --all-namespaces --field-selector reason=VolumeBinding
```

## 🎯 **Архитектура Scheduler Framework:**

```
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes Scheduler Framework              │
├─────────────────────────────────────────────────────────────┤
│  Scheduling Queue                                           │
│  ├── Priority Queue (Pod priority)                         │
│  ├── QueueSort Plugin                                      │
│  └── Pod ordering logic                                    │
├─────────────────────────────────────────────────────────────┤
│  Scheduling Cycle                                           │
│  ├── PreFilter → Filter → PostFilter                      │
│  ├── PreScore → Score → NormalizeScore                     │
│  └── Reserve (resource reservation)                        │
├─────────────────────────────────────────────────────────────┤
│  Binding Cycle                                              │
│  ├── Permit (wait/approve binding)                         │
│  ├── PreBind → Bind → PostBind                            │
│  └── Unreserve (cleanup on failure)                       │
├─────────────────────────────────────────────────────────────┤
│  Plugin Manager                                             │
│  ├── Plugin Registry                                       │
│  ├── Plugin Configuration                                  │
│  ├── Extension Point Handlers                              │
│  └── Plugin Lifecycle Management                           │
├─────────────────────────────────────────────────────────────┤
│  Default Plugins                                            │
│  ├── NodeResourcesFit, NodeAffinity                       │
│  ├── PodTopologySpread, TaintToleration                   │
│  ├── ImageLocality, InterPodAffinity                      │
│  └── VolumeBinding, DefaultBinder                         │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Конфигурация Scheduler Framework:**

### **1. Scheduler Configuration:**
```bash
# Конфигурация scheduler
kubectl get configmap -n kube-system | grep scheduler

# Profiles и plugins
kubectl describe configmap kube-scheduler-config -n kube-system

# Scheduler параметры
kubectl logs -n kube-system -l component=kube-scheduler | grep "Starting"
```

### **2. Plugin Configuration:**
```bash
# Включенные plugins
kubectl get --raw /metrics | grep "scheduler_plugin" | head -10

# Plugin weights и параметры
kubectl describe configmap kube-scheduler-config -n kube-system | grep -A 10 plugins
```

## 🚨 **Troubleshooting Scheduler Framework:**

### **1. Pod не планируется:**
```bash
# Проверить pending Pod'ы
kubectl get pods --all-namespaces --field-selector status.phase=Pending

# Причины неудачного планирования
kubectl describe pod <pending-pod> | grep -A 20 Events

# Scheduler логи
kubectl logs -n kube-system -l component=kube-scheduler | grep ERROR
```

### **2. Медленное планирование:**
```bash
# Scheduler performance метрики
kubectl get --raw /metrics | grep "scheduler_scheduling_duration"

# Plugin performance
kubectl get --raw /metrics | grep "scheduler_plugin_execution_duration"

# Queue depth
kubectl get --raw /metrics | grep "scheduler_pending_pods"
```

### **3. Неправильное размещение:**
```bash
# Проверить Node affinity
kubectl describe pod <pod-name> | grep -A 10 "Node-Selectors"

# Проверить resource requests
kubectl describe pod <pod-name> | grep -A 5 Requests

# Проверить taints и tolerations
kubectl describe nodes | grep -A 3 Taints
```

## 🎯 **Best Practices для Scheduler Framework:**

### **1. Мониторинг:**
- Отслеживайте scheduler метрики
- Мониторьте время планирования
- Проверяйте pending Pod'ы

### **2. Конфигурация:**
- Используйте подходящие plugins
- Настраивайте plugin weights
- Тестируйте custom plugins

### **3. Производительность:**
- Оптимизируйте resource requests
- Используйте node affinity разумно
- Избегайте сложных scheduling constraints

### **4. Отладка:**
- Анализируйте scheduler события
- Проверяйте plugin execution time
- Мониторьте scheduler throughput

**Scheduler Framework — это мощная архитектура для создания intelligent scheduling решений в Kubernetes!**
