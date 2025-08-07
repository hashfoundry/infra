# 199. Что такое Pod Preemption и как его реализовать?

## 🎯 **Что такое Pod Preemption?**

**Pod Preemption** — это механизм в Kubernetes, который позволяет высокоприоритетным Pod'ам вытеснять (preempt) низкоприоритетные Pod'ы для освобождения ресурсов на узлах. Это обеспечивает гарантированное выполнение критически важных рабочих нагрузок.

## 🏗️ **Основные функции Pod Preemption:**

### **1. Priority-based Scheduling**
- Планирование Pod'ов на основе приоритетов
- Гарантированное выделение ресурсов критическим сервисам
- Эффективное использование ресурсов кластера

### **2. Graceful Termination**
- Корректное завершение вытесняемых Pod'ов
- Соблюдение terminationGracePeriodSeconds
- Минимизация disruption для приложений

### **3. Resource Optimization**
- Динамическое перераспределение ресурсов
- Поддержка PodDisruptionBudgets
- Учет node affinity и anti-affinity

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка Priority Classes:**
```bash
# Системные priority classes
kubectl get priorityclasses

# Priority classes в кластере
kubectl get priorityclasses -o custom-columns=NAME:.metadata.name,VALUE:.value,PREEMPTION:.preemptionPolicy

# Pod'ы с приоритетами в ArgoCD
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority,PRIORITY_CLASS:.spec.priorityClassName

# Pod'ы с приоритетами в monitoring
kubectl get pods -n monitoring -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority,PRIORITY_CLASS:.spec.priorityClassName

# События preemption в кластере
kubectl get events --all-namespaces --field-selector reason=Preempted
```

### **2. ArgoCD с высоким приоритетом:**
```bash
# ArgoCD Server Pod'ы
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide

# Проверка priority class ArgoCD
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 5 "Priority"

# Ресурсы ArgoCD Server
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 10 "Requests"
```

### **3. Monitoring с критическим приоритетом:**
```bash
# Prometheus Pod'ы
kubectl get pods -n monitoring -l app=prometheus

# Grafana Pod'ы
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Проверка ресурсов monitoring
kubectl top pods -n monitoring
kubectl describe nodes | grep -A 10 "Allocated resources"
```

### **4. Тестирование preemption:**
```bash
# Создание namespace для тестов
kubectl create namespace preemption-test

# Создание низкоприоритетных Pod'ов
kubectl run low-priority-1 --image=nginx --namespace=preemption-test \
  --overrides='{"spec":{"priorityClassName":"low-priority","containers":[{"name":"nginx","image":"nginx","resources":{"requests":{"cpu":"500m","memory":"512Mi"}}}]}}'

# Создание высокоприоритетного Pod'а
kubectl run high-priority-1 --image=nginx --namespace=preemption-test \
  --overrides='{"spec":{"priorityClassName":"high-priority","containers":[{"name":"nginx","image":"nginx","resources":{"requests":{"cpu":"2000m","memory":"2Gi"}}}]}}'

# Мониторинг событий preemption
kubectl get events -n preemption-test --watch

# Очистка
kubectl delete namespace preemption-test
```

## 🔄 **Создание Priority Classes:**

### **1. Системные Priority Classes:**
```bash
# Критический приоритет для системных компонентов
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: system-critical
value: 2000000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Critical system components"
EOF

# Высокий приоритет для важных сервисов
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "High priority services"
EOF

# Низкий приоритет для batch jobs
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: true
preemptionPolicy: Never
description: "Low priority batch workloads"
EOF
```

### **2. Применение Priority Classes:**
```bash
# ArgoCD с высоким приоритетом
kubectl patch deployment argocd-server -n argocd -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'

# Prometheus с критическим приоритетом
kubectl patch deployment prometheus-server -n monitoring -p '{"spec":{"template":{"spec":{"priorityClassName":"system-critical"}}}}'

# Grafana с высоким приоритетом
kubectl patch deployment grafana -n monitoring -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

## 🔧 **Демонстрация Pod Preemption:**

### **1. Создание ресурсоемких Pod'ов:**
```bash
# Deployment с низким приоритетом
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hog
  namespace: preemption-test
spec:
  replicas: 5
  selector:
    matchLabels:
      app: resource-hog
  template:
    metadata:
      labels:
        app: resource-hog
    spec:
      priorityClassName: low-priority
      containers:
      - name: hog
        image: busybox
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
EOF

# Проверка размещения Pod'ов
kubectl get pods -n preemption-test -o wide
kubectl top nodes
```

### **2. Создание высокоприоритетного Pod'а:**
```bash
# Pod с высоким приоритетом
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: critical-workload
  namespace: preemption-test
spec:
  priorityClassName: high-priority
  containers:
  - name: critical
    image: nginx:alpine
    resources:
      requests:
        cpu: 2000m
        memory: 2Gi
      limits:
        cpu: 4000m
        memory: 4Gi
EOF

# Мониторинг preemption
kubectl get events -n preemption-test --field-selector reason=Preempted
kubectl get pods -n preemption-test -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,PRIORITY:.spec.priority
```

### **3. Graceful Termination:**
```bash
# Pod с graceful shutdown
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: graceful-pod
  namespace: preemption-test
spec:
  priorityClassName: low-priority
  terminationGracePeriodSeconds: 60
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh"]
    args:
    - -c
    - |
      trap 'echo "Graceful shutdown started"; sleep 30; echo "Shutdown complete"' TERM
      while true; do sleep 1; done
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

# Тестирование graceful termination
kubectl delete pod graceful-pod -n preemption-test --grace-period=60
kubectl logs graceful-pod -n preemption-test -f
```

## 📈 **Мониторинг Pod Preemption:**

### **1. Scheduler метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Scheduler метрики в Prometheus:
# scheduler_pending_pods - ожидающие планирования Pod'ы
# scheduler_preemption_attempts_total - попытки preemption
# scheduler_preemption_victims - количество вытесненных Pod'ов
```

### **2. События и логи:**
```bash
# События preemption
kubectl get events --all-namespaces --field-selector reason=Preempted -o wide

# Scheduler логи
kubectl logs -n kube-system -l component=kube-scheduler | grep -i preempt

# Pod события
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events
```

### **3. Ресурсы узлов:**
```bash
# Использование ресурсов
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu

# Детальная информация об узлах
kubectl describe nodes | grep -A 15 "Allocated resources"

# Capacity и allocatable
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU-CAPACITY:.status.capacity.cpu,MEMORY-CAPACITY:.status.capacity.memory,CPU-ALLOCATABLE:.status.allocatable.cpu,MEMORY-ALLOCATABLE:.status.allocatable.memory
```

## 🏭 **Pod Preemption в вашем HA кластере:**

### **1. ArgoCD High Availability:**
```bash
# ArgoCD Server с высоким приоритетом
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# ArgoCD Application Controller
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Проверка priority classes
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep Priority
```

### **2. Monitoring Stack Protection:**
```bash
# Prometheus с критическим приоритетом
kubectl get pods -n monitoring -l app=prometheus -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority

# Grafana с высоким приоритетом
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority

# NFS Provisioner защита
kubectl get pods -n kube-system -l app=nfs-provisioner -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority
```

### **3. Application Workloads:**
```bash
# React App с обычным приоритетом
kubectl get pods -n hashfoundry-react -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority

# Batch jobs с низким приоритетом
kubectl get jobs --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,PRIORITY:.spec.template.spec.priority
```

## 🔄 **PodDisruptionBudget и Preemption:**

### **1. PDB для критических сервисов:**
```bash
# ArgoCD PDB
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-server-pdb
  namespace: argocd
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
EOF

# Prometheus PDB
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: prometheus-pdb
  namespace: monitoring
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: prometheus
EOF
```

### **2. Проверка PDB статуса:**
```bash
# Все PDB в кластере
kubectl get pdb --all-namespaces

# Детальная информация о PDB
kubectl describe pdb argocd-server-pdb -n argocd
kubectl describe pdb prometheus-pdb -n monitoring

# PDB и preemption взаимодействие
kubectl get events --all-namespaces --field-selector reason=EvictionBlocked
```

## 🚨 **Troubleshooting Pod Preemption:**

### **1. Pod не может быть запланирован:**
```bash
# Проверка pending Pod'ов
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Причины pending
kubectl describe pod <pending-pod> -n <namespace>

# Scheduler события
kubectl get events --all-namespaces --field-selector reason=FailedScheduling

# Ресурсы узлов
kubectl describe nodes | grep -A 10 "Non-terminated Pods"
```

### **2. Preemption не происходит:**
```bash
# Проверка priority classes
kubectl get priorityclasses -o custom-columns=NAME:.metadata.name,VALUE:.value,PREEMPTION:.preemptionPolicy

# Scheduler конфигурация
kubectl get configmap kube-scheduler -n kube-system -o yaml

# Scheduler логи
kubectl logs -n kube-system -l component=kube-scheduler | grep -i "preemption\|priority"
```

### **3. Неожиданное preemption:**
```bash
# История событий preemption
kubectl get events --all-namespaces --field-selector reason=Preempted --sort-by='.lastTimestamp'

# Анализ ресурсов
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# PDB нарушения
kubectl get events --all-namespaces --field-selector reason=EvictionBlocked
```

## 🎯 **Архитектура Pod Preemption:**

```
┌─────────────────────────────────────────────────────────────┐
│                Pod Preemption Flow                         │
├─────────────────────────────────────────────────────────────┤
│  High Priority Pod Request                                  │
│  ├── Priority: 1000                                        │
│  ├── Resources: 2 CPU, 4Gi Memory                          │
│  └── Cannot be scheduled on any node                       │
├─────────────────────────────────────────────────────────────┤
│  Scheduler Preemption Logic                                 │
│  ├── Find nodes with lower priority pods                   │
│  ├── Calculate preemption cost                             │
│  ├── Select optimal victims                                │
│  └── Respect PodDisruptionBudgets                          │
├─────────────────────────────────────────────────────────────┤
│  Victim Selection                                           │
│  ├── Lowest priority pods first                            │
│  ├── Newest pods within same priority                      │
│  ├── Minimize disruption                                   │
│  └── Consider node affinity                                │
├─────────────────────────────────────────────────────────────┤
│  Graceful Termination                                       │
│  ├── Send SIGTERM to victim pods                           │
│  ├── Wait for terminationGracePeriodSeconds                │
│  ├── Execute preStop hooks                                 │
│  └── Send SIGKILL if necessary                             │
├─────────────────────────────────────────────────────────────┤
│  Resource Allocation                                        │
│  ├── Update node allocatable resources                     │
│  ├── Schedule high priority pod                            │
│  ├── Update cluster state                                  │
│  └── Generate scheduling events                            │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Best Practices для Pod Preemption:**

### **1. Priority Class Design:**
- Используйте четкую иерархию приоритетов
- Системные компоненты - наивысший приоритет
- Критические сервисы - высокий приоритет
- Batch jobs - низкий приоритет

### **2. Resource Management:**
- Устанавливайте resource requests и limits
- Мониторьте использование ресурсов
- Планируйте capacity заранее

### **3. Graceful Handling:**
- Настраивайте terminationGracePeriodSeconds
- Используйте preStop hooks
- Реализуйте graceful shutdown в приложениях

### **4. Monitoring и Alerting:**
- Мониторьте события preemption
- Настройте алерты на частые preemption
- Отслеживайте SLA критических сервисов

**Pod Preemption — это мощный механизм для гарантированного выполнения критических workloads в ресурсо-ограниченных средах!**
