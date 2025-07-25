# 6. Что такое Node в Kubernetes?

## 🎯 **Что такое Node?**

**Node (Узел)** — это физический или виртуальный сервер, который является частью Kubernetes кластера и на котором запускаются Pod'ы с контейнерами.

## 🏗️ **Типы Node'ов:**

### **1. Control Plane Nodes (Master Nodes)**
- Управляют кластером
- Запускают компоненты Control Plane (API Server, etcd, Scheduler, Controller Manager)
- Обычно не запускают пользовательские Pod'ы

### **2. Worker Nodes**
- Выполняют пользовательские рабочие нагрузки
- Запускают Pod'ы с приложениями
- Содержат kubelet, kube-proxy, container runtime

## 🔧 **Компоненты Worker Node:**

### **1. kubelet**
- Агент Kubernetes на каждой ноде
- Управляет Pod'ами и контейнерами
- Отчитывается в Control Plane

### **2. kube-proxy**
- Сетевой прокси
- Обеспечивает сетевую связность
- Реализует Service абстракцию

### **3. Container Runtime**
- Запускает контейнеры (Docker, containerd, CRI-O)
- Управляет жизненным циклом контейнеров

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Посмотреть на Node'ы кластера:**
```bash
# Список всех Node'ов
kubectl get nodes

# Детальная информация о Node'ах
kubectl get nodes -o wide

# Подробная информация о конкретной ноде
kubectl describe node <node-name>

# Статус и версии компонентов
kubectl get nodes -o yaml
```

### **2. Ресурсы Node'ов:**
```bash
# Использование CPU и памяти на Node'ах
kubectl top nodes

# Доступные ресурсы на каждой ноде
kubectl describe nodes | grep -A 5 "Allocatable:"

# Занятые ресурсы на Node'ах
kubectl describe nodes | grep -A 10 "Allocated resources:"
```

### **3. Pod'ы на Node'ах:**
```bash
# Какие Pod'ы запущены на каждой ноде
kubectl get pods -A -o wide

# Pod'ы на конкретной ноде
kubectl get pods -A --field-selector spec.nodeName=<node-name>

# Количество Pod'ов на каждой ноде
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c
```

### **4. Состояние Node'ов:**
```bash
# Условия Node'ов (Ready, MemoryPressure, DiskPressure, etc.)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# События на Node'ах
kubectl get events --field-selector involvedObject.kind=Node

# Taints и Tolerations
kubectl describe nodes | grep -A 5 "Taints:"
```

### **5. Системные Pod'ы на Node'ах:**
```bash
# DaemonSet Pod'ы (запущены на каждой ноде)
kubectl get daemonsets -A

# kube-proxy на каждой ноде
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# CNI Pod'ы (сетевые плагины)
kubectl get pods -n kube-system -o wide | grep -E "(calico|flannel|weave)"
```

## 🏭 **Ваш HA кластер Digital Ocean:**

### **1. Managed Control Plane:**
```bash
# Digital Ocean управляет Control Plane
kubectl cluster-info

# Вы видите только Worker Node'ы
kubectl get nodes

# Control Plane скрыт от пользователя
kubectl get pods -n kube-system | grep -E "(etcd|apiserver|scheduler|controller)"
```

### **2. Worker Node'ы с автомасштабированием:**
```bash
# 3-9 Worker Node'ов в зависимости от нагрузки
kubectl get nodes -o wide

# Информация о Node Pool
kubectl describe nodes | grep -A 5 "Labels:"

# Размер Node'ов (s-2vcpu-4gb согласно .env)
kubectl describe nodes | grep -A 3 "Capacity:"
```

### **3. Распределение Pod'ов по Node'ам:**
```bash
# ArgoCD Pod'ы распределены по разным Node'ам для HA
kubectl get pods -n argocd -o wide

# Anti-affinity правила предотвращают размещение на одной ноде
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 10 "Node-Selectors:"

# Мониторинг Pod'ы также распределены
kubectl get pods -n monitoring -o wide
```

## 🔄 **Жизненный цикл Node'а:**

### **1. Добавление Node'а в кластер:**
```bash
# Новые Node'ы автоматически добавляются (автоскейлинг)
kubectl get nodes --watch

# События добавления Node'а
kubectl get events --field-selector reason=NodeReady

# Регистрация Node'а в кластере
kubectl describe node <new-node> | grep -A 5 "Conditions:"
```

### **2. Обслуживание Node'а:**
```bash
# Пометить Node как неготовую к планированию (cordon)
kubectl cordon <node-name>

# Эвакуировать Pod'ы с Node'а (drain)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Вернуть Node в работу (uncordon)
kubectl uncordon <node-name>
```

### **3. Удаление Node'а:**
```bash
# Автоскейлинг может удалить Node'у при низкой нагрузке
kubectl get nodes --watch

# События удаления Node'а
kubectl get events --field-selector reason=NodeNotReady
```

## 📈 **Мониторинг Node'ов:**

### **1. Prometheus метрики Node'ов:**
```bash
# Node Exporter собирает метрики с каждой ноды
kubectl get pods -A | grep node-exporter

# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# В Prometheus UI найти метрики:
# node_cpu_seconds_total          # CPU ноды
# node_memory_MemAvailable_bytes  # Доступная память
# node_filesystem_avail_bytes     # Свободное место на диске
# node_load1                      # Load average
```

### **2. Grafana дашборды Node'ов:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Открыть http://localhost:3000
# Найти дашборды: "Kubernetes Cluster Monitoring" или "Node Exporter"
```

### **3. Kubernetes метрики Node'ов:**
```bash
# kube-state-metrics предоставляет метрики Kubernetes объектов
kubectl get pods -A | grep kube-state-metrics

# Метрики в Prometheus:
# kube_node_status_condition      # Состояние ноды
# kube_node_info                  # Информация о ноде
# kube_node_status_capacity       # Емкость ноды
# kube_node_status_allocatable    # Доступные ресурсы
```

## 🔧 **Управление Node'ами:**

### **1. Labeling Node'ов:**
```bash
# Добавить label к ноде
kubectl label node <node-name> environment=production

# Посмотреть labels
kubectl get nodes --show-labels

# Использовать labels для планирования Pod'ов
kubectl get pods -o wide --selector environment=production
```

### **2. Taints и Tolerations:**
```bash
# Посмотреть taints на Node'ах
kubectl describe nodes | grep -A 2 "Taints:"

# Добавить taint (Pod'ы не будут планироваться без toleration)
kubectl taint node <node-name> key=value:NoSchedule

# Удалить taint
kubectl taint node <node-name> key=value:NoSchedule-
```

### **3. Node Selectors:**
```bash
# Запустить Pod на конкретной ноде
kubectl run test-pod --image=nginx --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"<node-name>"}}}'

# Посмотреть где запустился Pod
kubectl get pod test-pod -o wide

# Очистка
kubectl delete pod test-pod
```

## 🏗️ **Архитектура Node'ов в вашем кластере:**

### **Digital Ocean Managed Kubernetes:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Digital Ocean Cloud                     │
├─────────────────────────────────────────────────────────────┤
│  Control Plane (Managed by DO)                             │
│  ├── API Server (HA Load Balanced)                         │
│  ├── etcd (HA Cluster)                                     │
│  ├── Scheduler (HA)                                        │
│  └── Controller Manager (HA)                               │
├─────────────────────────────────────────────────────────────┤
│  Worker Nodes (Your managed, auto-scaling 3-9 nodes)      │
│  ├── Node 1 (s-2vcpu-4gb)                                  │
│  │   ├── kubelet                                           │
│  │   ├── kube-proxy                                        │
│  │   ├── containerd                                        │
│  │   └── Pod'ы: ArgoCD Server, Prometheus, etc.           │
│  ├── Node 2 (s-2vcpu-4gb)                                  │
│  │   ├── kubelet                                           │
│  │   ├── kube-proxy                                        │
│  │   ├── containerd                                        │
│  │   └── Pod'ы: ArgoCD Controller, Grafana, etc.          │
│  └── Node 3+ (auto-scaling)                                │
│      ├── kubelet                                           │
│      ├── kube-proxy                                        │
│      ├── containerd                                        │
│      └── Pod'ы: Redis HA, NFS Provisioner, etc.           │
└─────────────────────────────────────────────────────────────┘
```

### **Проверить архитектуру:**
```bash
# Количество Worker Node'ов
kubectl get nodes | wc -l

# Размер и регион Node'ов
kubectl describe nodes | grep -E "(instance-type|zone)"

# Версия Kubernetes на Node'ах
kubectl get nodes -o wide
```

## 🎯 **Ключевые концепции Node'ов:**

### **1. Планирование Pod'ов:**
```bash
# Scheduler выбирает подходящую ноду для Pod'а
kubectl describe pod <pod-name> -n argocd | grep "Node:"

# Ресурсы влияют на планирование
kubectl describe nodes | grep -A 5 "Allocatable:"
```

### **2. Отказоустойчивость:**
```bash
# Если нода упадет, Pod'ы переедут на другие ноды
kubectl get pods -n argocd -o wide

# Anti-affinity обеспечивает распределение по нодам
kubectl describe deployment argocd-server -n argocd | grep -A 10 "Pod Template:"
```

### **3. Автомасштабирование:**
```bash
# Cluster Autoscaler добавляет/удаляет ноды по потребности
kubectl get nodes --watch

# Horizontal Pod Autoscaler масштабирует Pod'ы
kubectl get hpa -A
```

**Node — это физическая основа вашего кластера, где выполняются все рабочие нагрузки!**
