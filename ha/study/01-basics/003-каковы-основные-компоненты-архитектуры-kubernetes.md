# 3. Каковы основные компоненты архитектуры Kubernetes?

## 🏗️ **Архитектура Kubernetes**

Kubernetes состоит из **Control Plane** (плоскость управления) и **Worker Nodes** (рабочие узлы).

## ⚙️ **Control Plane (Плоскость управления)**

### **1. API Server (kube-apiserver)**
- **Назначение**: Центральная точка управления кластером
- **Функции**: Обрабатывает REST API запросы, аутентификация, авторизация

### **2. etcd**
- **Назначение**: Распределенная база данных ключ-значение
- **Функции**: Хранит всю конфигурацию и состояние кластера

### **3. Controller Manager (kube-controller-manager)**
- **Назначение**: Запускает контроллеры
- **Функции**: Следит за состоянием ресурсов и приводит их к желаемому состоянию

### **4. Scheduler (kube-scheduler)**
- **Назначение**: Планировщик подов
- **Функции**: Решает, на какой ноде запустить под

## 🔧 **Worker Nodes (Рабочие узлы)**

### **1. kubelet**
- **Назначение**: Агент на каждой ноде
- **Функции**: Управляет подами и контейнерами на ноде

### **2. kube-proxy**
- **Назначение**: Сетевой прокси
- **Функции**: Обеспечивает сетевую связность и балансировку нагрузки

### **3. Container Runtime**
- **Назначение**: Среда выполнения контейнеров
- **Функции**: Запускает и управляет контейнерами (Docker, containerd, CRI-O)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверить компоненты Control Plane:**
```bash
# Посмотреть на системные поды (Control Plane)
kubectl get pods -n kube-system

# Проверить состояние компонентов
kubectl get componentstatuses

# Информация о кластере (API Server)
kubectl cluster-info
```

### **2. API Server в действии:**
```bash
# Все команды kubectl идут через API Server
kubectl get nodes -v=6  # Показать HTTP запросы к API

# API Server обрабатывает все операции
kubectl get pods -n argocd
kubectl describe pod <pod-name> -n argocd
```

### **3. etcd - хранилище состояния:**
```bash
# Вся информация о ресурсах хранится в etcd
kubectl get all -A

# Конфигурация кластера
kubectl get configmaps -n kube-system
kubectl get secrets -n kube-system
```

### **4. Controller Manager - контроллеры:**
```bash
# ReplicaSet Controller следит за количеством реплик
kubectl get replicasets -n argocd

# Deployment Controller управляет развертываниями
kubectl get deployments -n argocd

# Service Controller управляет сервисами
kubectl get svc -n argocd
```

### **5. Scheduler - планировщик:**
```bash
# Scheduler распределяет поды по нодам
kubectl get pods -n argocd -o wide

# Посмотреть события планирования
kubectl get events --sort-by=.metadata.creationTimestamp

# Ресурсы нод для планирования
kubectl describe nodes
```

### **6. kubelet на Worker Nodes:**
```bash
# kubelet управляет подами на каждой ноде
kubectl get pods -A -o wide

# Статус нод (kubelet отчитывается)
kubectl get nodes -o wide

# Ресурсы нод
kubectl top nodes
```

### **7. kube-proxy - сетевая связность:**
```bash
# kube-proxy обеспечивает работу сервисов
kubectl get svc -A

# Endpoints - куда kube-proxy направляет трафик
kubectl get endpoints -n argocd

# DaemonSet kube-proxy на каждой ноде
kubectl get daemonsets -n kube-system
```

### **8. Container Runtime:**
```bash
# Посмотреть runtime информацию нод
kubectl get nodes -o wide

# Образы контейнеров в подах
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'

# Статус контейнеров
kubectl describe pod <pod-name> -n argocd
```

## 🏭 **Архитектура вашего HA кластера:**

### **1. HA Control Plane (Digital Ocean Managed):**
```bash
# Digital Ocean управляет Control Plane в HA режиме
kubectl get nodes
kubectl cluster-info

# Несколько мастер-нод для отказоустойчивости
kubectl get componentstatuses
```

### **2. Worker Nodes с автомасштабированием:**
```bash
# 3-9 worker нод с автоскейлингом
kubectl get nodes -o wide

# Поды распределены по нодам для HA
kubectl get pods -n argocd -o wide
```

### **3. Компоненты в действии:**
```bash
# API Server обрабатывает запросы ArgoCD
kubectl get applications -n argocd

# Scheduler распределил ArgoCD поды по разным нодам
kubectl get pods -n argocd -o wide

# Controller Manager поддерживает 3 реплики ArgoCD server
kubectl get replicasets -n argocd
```

## 🔄 **Взаимодействие компонентов:**

### **Пример: Создание пода**
```bash
# 1. kubectl отправляет запрос в API Server
kubectl run test-pod --image=nginx

# 2. API Server сохраняет в etcd
kubectl get pod test-pod -o yaml

# 3. Scheduler выбирает ноду
kubectl describe pod test-pod

# 4. kubelet на выбранной ноде создает контейнер
kubectl get pod test-pod -o wide

# 5. kube-proxy настраивает сеть (если нужен Service)
kubectl expose pod test-pod --port=80

# Очистка
kubectl delete pod test-pod
kubectl delete svc test-pod
```

## 📈 **Мониторинг компонентов в вашем кластере:**

### **1. Prometheus собирает метрики компонентов:**
```bash
# Метрики API Server, kubelet, kube-proxy
kubectl get servicemonitor -n monitoring

# Prometheus targets
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Открыть http://localhost:9090/targets
```

### **2. Grafana визуализирует состояние:**
```bash
# Дашборды для компонентов Kubernetes
kubectl port-forward svc/grafana -n monitoring 3000:80
# Открыть http://localhost:3000
```

## 🎯 **Ключевые особенности архитектуры:**

### **Декларативная модель:**
```bash
# Вы описываете желаемое состояние
kubectl apply -f deployment.yaml

# Kubernetes приводит к этому состоянию
kubectl get deployments
```

### **Самовосстановление:**
```bash
# Если компонент упадет, Controller Manager восстановит
kubectl delete pod <argocd-pod> -n argocd
kubectl get pods -n argocd --watch
```

### **Масштабируемость:**
```bash
# Легко масштабировать приложения
kubectl scale deployment argocd-server --replicas=5 -n argocd
kubectl get pods -n argocd
```

## 🏗️ **Диаграмма архитектуры вашего кластера:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Digital Ocean Cloud                     │
├─────────────────────────────────────────────────────────────┤
│  Control Plane (HA Managed)                                │
│  ├── API Server (Load Balanced)                            │
│  ├── etcd (HA Cluster)                                     │
│  ├── Controller Manager (HA)                               │
│  └── Scheduler (HA)                                        │
├─────────────────────────────────────────────────────────────┤
│  Worker Nodes (3-9 nodes, auto-scaling)                    │
│  ├── Node 1: kubelet + kube-proxy + containerd             │
│  │   ├── ArgoCD Server Pod                                 │
│  │   ├── Prometheus Pod                                    │
│  │   └── NGINX Ingress Pod                                 │
│  ├── Node 2: kubelet + kube-proxy + containerd             │
│  │   ├── ArgoCD Controller Pod                             │
│  │   ├── Grafana Pod                                       │
│  │   └── NFS Provisioner Pod                               │
│  └── Node 3: kubelet + kube-proxy + containerd             │
│      ├── ArgoCD Repo Server Pod                            │
│      ├── Redis HA Pod                                      │
│      └── React App Pod                                     │
└─────────────────────────────────────────────────────────────┘
```

**Каждый компонент выполняет свою роль в обеспечении надежной работы вашего HA кластера!**
