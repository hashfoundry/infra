# 13. Как работает Kubernetes Scheduler?

## 🎯 **Что такое Kubernetes Scheduler?**

**kube-scheduler** — это компонент Control Plane, который отвечает за размещение Pod'ов на подходящих Node'ах в кластере. Он принимает решения о том, где запустить каждый Pod, основываясь на ресурсах, ограничениях и политиках.

## 🏗️ **Основные функции Scheduler:**

### **1. Планирование Pod'ов**
- Выбирает оптимальную Node для каждого Pod'а
- Учитывает ресурсы (CPU, память, диск)
- Применяет ограничения и предпочтения
- Балансирует нагрузку по кластеру

### **2. Фильтрация Node'ов**
- Исключает неподходящие Node'ы
- Проверяет доступность ресурсов
- Учитывает taints и tolerations
- Применяет node selectors

### **3. Ранжирование Node'ов**
- Оценивает подходящие Node'ы
- Выбирает наилучший вариант
- Оптимизирует распределение
- Минимизирует фрагментацию ресурсов

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Scheduler в действии:**
```bash
# Посмотреть как Scheduler распределил Pod'ы ArgoCD
kubectl get pods -n argocd -o wide

# Scheduler распределил Pod'ы по разным Node'ам для HA
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# События планирования
kubectl get events --field-selector reason=Scheduled | head -10
```

### **2. Ресурсы влияют на планирование:**
```bash
# Доступные ресурсы на Node'ах
kubectl describe nodes | grep -A 5 "Allocatable:"

# Занятые ресурсы
kubectl describe nodes | grep -A 10 "Allocated resources:"

# Scheduler учитывает эти данные при планировании
kubectl top nodes
```

### **3. Планирование с ограничениями:**
```bash
# Pod'ы с resource requests
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "Requests:"

# Scheduler не разместит Pod, если недостаточно ресурсов
kubectl describe pod <pod-name> -n argocd | grep -A 10 "Events:"
```

### **4. Anti-affinity в ArgoCD:**
```bash
# ArgoCD использует anti-affinity для распределения по Node'ам
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 10 "Affinity:"

# Scheduler размещает Pod'ы на разных Node'ах
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide
```

### **5. Scheduler и автомасштабирование:**
```bash
# Когда нет подходящих Node'ов, Pod остается Pending
kubectl get pods -A | grep Pending

# Cluster Autoscaler добавляет новые Node'ы
kubectl get nodes --watch

# Scheduler размещает ожидающие Pod'ы на новых Node'ах
```

## 🔄 **Алгоритм работы Scheduler:**

### **1. Фаза фильтрации (Filtering):**
```
┌─────────────────────────────────────────────────────────────┐
│                    Filtering Phase                         │
├─────────────────────────────────────────────────────────────┤
│  Input: Unscheduled Pod + All Nodes                        │
├─────────────────────────────────────────────────────────────┤
│  Filters (Predicates):                                     │
│  ├── NodeResourcesFit - достаточно ресурсов?               │
│  ├── NodeAffinity - соответствует node selector?           │
│  ├── PodAffinity/AntiAffinity - правила размещения         │
│  ├── TaintToleration - tolerates node taints?              │
│  ├── VolumeBinding - можно примонтировать volumes?          │
│  ├── NodePorts - свободны ли порты?                        │
│  └── PodTopologySpread - соблюдены ли правила топологии?   │
├─────────────────────────────────────────────────────────────┤
│  Output: List of feasible Nodes                            │
└─────────────────────────────────────────────────────────────┘
```

### **2. Фаза ранжирования (Scoring):**
```
┌─────────────────────────────────────────────────────────────┐
│                    Scoring Phase                           │
├─────────────────────────────────────────────────────────────┤
│  Input: List of feasible Nodes                             │
├─────────────────────────────────────────────────────────────┤
│  Scoring Functions (Priorities):                           │
│  ├── NodeResourcesFit - оптимальное использование ресурсов │
│  ├── BalancedResourceAllocation - баланс CPU/Memory        │
│  ├── NodeAffinity - предпочтения node affinity            │
│  ├── PodAffinity/AntiAffinity - предпочтения размещения   │
│  ├── TaintToleration - предпочтения tolerations           │
│  ├── ImageLocality - локальность образов                   │
│  └── NodePreferAvoidPods - избегание определенных нод     │
├─────────────────────────────────────────────────────────────┤
│  Output: Ranked list of Nodes                              │
└─────────────────────────────────────────────────────────────┘
```

### **3. Выбор лучшей Node:**
```bash
# Scheduler выбирает Node с наивысшим рейтингом
# При равных рейтингах - случайный выбор
# Результат записывается в Pod.spec.nodeName
```

## 🔧 **Демонстрация планирования:**

### **1. Создание Pod'а без ограничений:**
```bash
# Простой Pod - Scheduler выберет любую подходящую Node
kubectl run simple-pod --image=nginx

# Посмотреть на какой Node попал
kubectl get pod simple-pod -o wide

# События планирования
kubectl describe pod simple-pod | grep -A 5 "Events:"

# Очистка
kubectl delete pod simple-pod
```

### **2. Pod с resource requests:**
```bash
# Pod с требованиями к ресурсам
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
EOF

# Scheduler учтет resource requests при выборе Node
kubectl get pod resource-pod -o wide
kubectl describe pod resource-pod | grep -A 5 "Requests:"

# Очистка
kubectl delete pod resource-pod
```

### **3. Pod с node selector:**
```bash
# Добавить label к Node
kubectl label node <node-name> disktype=ssd

# Pod с node selector
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-selector-pod
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: app
    image: nginx
EOF

# Scheduler разместит только на Node с label disktype=ssd
kubectl get pod node-selector-pod -o wide

# Очистка
kubectl delete pod node-selector-pod
kubectl label node <node-name> disktype-
```

### **4. Pod с affinity/anti-affinity:**
```bash
# Pod с anti-affinity (не размещать рядом с другими nginx Pod'ами)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: anti-affinity-pod
  labels:
    app: nginx
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - nginx
        topologyKey: kubernetes.io/hostname
  containers:
  - name: nginx
    image: nginx
EOF

# Scheduler разместит на Node без других nginx Pod'ов
kubectl get pods -l app=nginx -o wide

# Очистка
kubectl delete pod anti-affinity-pod
```

## 📈 **Мониторинг Scheduler:**

### **1. Метрики Scheduler в Prometheus:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики Scheduler:
# scheduler_scheduling_duration_seconds - время планирования
# scheduler_pod_scheduling_attempts - попытки планирования
# scheduler_pending_pods - количество ожидающих Pod'ов
# scheduler_schedule_attempts_total - общее количество попыток
```

### **2. Grafana дашборды Scheduler:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Дашборды показывают:
# - Scheduling latency
# - Failed scheduling attempts
# - Pending pods
# - Node utilization
```

### **3. События планирования:**
```bash
# События успешного планирования
kubectl get events --field-selector reason=Scheduled

# События неудачного планирования
kubectl get events --field-selector reason=FailedScheduling

# Подробности о проблемах планирования
kubectl describe pod <pending-pod> | grep -A 10 "Events:"
```

## 🏭 **Scheduler в вашем HA кластере:**

### **1. High Availability Scheduler:**
```bash
# В managed кластере Digital Ocean Scheduler работает в HA режиме
# Несколько экземпляров Scheduler
# Leader election для активного экземпляра
# Автоматический failover
```

### **2. Оптимизация для HA:**
```bash
# Scheduler распределяет критические Pod'ы по разным Node'ам
kubectl get pods -n argocd -o wide

# Anti-affinity правила для высокой доступности
kubectl describe deployment argocd-server -n argocd | grep -A 15 "Pod Template:"

# PodDisruptionBudgets учитываются при планировании
kubectl get pdb -A
```

### **3. Автомасштабирование и Scheduler:**
```bash
# Cluster Autoscaler работает с Scheduler
# Когда Pod'ы не могут быть запланированы - добавляются Node'ы
kubectl get nodes

# Horizontal Pod Autoscaler создает новые Pod'ы
kubectl get hpa -A

# Scheduler размещает новые Pod'ы на доступных Node'ах
```

## 🔧 **Продвинутые возможности Scheduler:**

### **1. Topology Spread Constraints:**
```bash
# Равномерное распределение Pod'ов по зонам
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-deployment
spec:
  replicas: 6
  selector:
    matchLabels:
      app: spread-app
  template:
    metadata:
      labels:
        app: spread-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: spread-app
      containers:
      - name: app
        image: nginx
EOF

# Scheduler распределит Pod'ы равномерно по зонам
kubectl get pods -l app=spread-app -o wide

# Очистка
kubectl delete deployment spread-deployment
```

### **2. Priority Classes:**
```bash
# Создать Priority Class
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "High priority class"
EOF

# Pod с высоким приоритетом
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-pod
spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: nginx
EOF

# Scheduler предпочтет этот Pod при нехватке ресурсов
kubectl describe pod high-priority-pod | grep Priority

# Очистка
kubectl delete pod high-priority-pod
kubectl delete priorityclass high-priority
```

### **3. Custom Schedulers:**
```bash
# Можно создать собственный Scheduler
# Pod может указать конкретный Scheduler
spec:
  schedulerName: my-custom-scheduler

# По умолчанию используется default-scheduler
kubectl get pods -o yaml | grep schedulerName
```

## 🚨 **Проблемы планирования:**

### **1. Pending Pod'ы:**
```bash
# Найти Pod'ы в состоянии Pending
kubectl get pods -A | grep Pending

# Причины могут быть:
# - Недостаточно ресурсов на Node'ах
# - Нет подходящих Node'ов (taints, selectors)
# - Volume не может быть примонтирован
# - Anti-affinity правила блокируют размещение
```

### **2. Отладка проблем планирования:**
```bash
# Подробная информация о проблеме
kubectl describe pod <pending-pod>

# События планирования
kubectl get events --field-selector involvedObject.name=<pending-pod>

# Проверить доступные ресурсы
kubectl describe nodes | grep -A 5 "Allocatable:"
```

### **3. Решение проблем:**
```bash
# Добавить больше Node'ов (автоскейлинг)
# Уменьшить resource requests
# Изменить affinity/anti-affinity правила
# Добавить tolerations для taints
# Освободить ресурсы на существующих Node'ах
```

## 🎯 **Best Practices для Scheduler:**

### **1. Resource Management:**
- Всегда указывайте resource requests
- Используйте resource limits
- Мониторьте использование ресурсов
- Планируйте capacity

### **2. Affinity Rules:**
- Используйте anti-affinity для критических приложений
- Применяйте topology spread constraints
- Балансируйте между доступностью и производительностью

### **3. Мониторинг:**
- Следите за pending Pod'ами
- Мониторьте время планирования
- Анализируйте события планирования
- Оптимизируйте распределение нагрузки

**Scheduler — это мозг размещения Pod'ов, обеспечивающий оптимальное использование ресурсов кластера!**
