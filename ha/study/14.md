# 14. Какова роль kubelet?

## 🎯 **Что такое kubelet?**

**kubelet** — это основной агент Node, который работает на каждой Node и отвечает за управление Pod'ами и контейнерами на этой Node. Это связующее звено между Control Plane и рабочими Node'ами.

## 🏗️ **Основные функции kubelet:**

### **1. Управление Pod'ами**
- Получает Pod спецификации от API Server
- Запускает и останавливает контейнеры
- Мониторит состояние Pod'ов
- Отправляет статус обратно в API Server

### **2. Взаимодействие с Container Runtime**
- Использует CRI (Container Runtime Interface)
- Управляет жизненным циклом контейнеров
- Обрабатывает образы контейнеров
- Настраивает сеть и хранилище

### **3. Health Checks**
- Выполняет liveness probes
- Выполняет readiness probes
- Выполняет startup probes
- Перезапускает неисправные контейнеры

### **4. Ресурсы и мониторинг**
- Собирает метрики использования ресурсов
- Управляет cgroups
- Контролирует лимиты ресурсов
- Отправляет метрики в metrics-server

## 📊 **Практические примеры из вашего HA кластера:**

### **1. kubelet управляет Pod'ами:**
```bash
# Все Pod'ы на Node'ах управляются kubelet
kubectl get pods -A -o wide

# kubelet получает спецификации от API Server
kubectl describe pod <argocd-server-pod> -n argocd

# Статус Pod'а обновляется kubelet'ом
kubectl get pod <pod-name> -n argocd -w
```

### **2. kubelet и health checks:**
```bash
# Liveness и readiness probes настроены в Pod'ах
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "Liveness:"
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "Readiness:"

# kubelet выполняет эти проверки и перезапускает контейнеры при необходимости
kubectl get pods -n argocd | grep -E "(Restart|Running)"
```

### **3. kubelet и ресурсы:**
```bash
# kubelet собирает метрики ресурсов
kubectl top nodes
kubectl top pods -n argocd

# kubelet применяет resource limits
kubectl describe pod <pod-name> -n argocd | grep -A 10 "Limits:"
```

### **4. kubelet и volumes:**
```bash
# kubelet монтирует volumes в Pod'ы
kubectl describe pod <prometheus-pod> -n monitoring | grep -A 10 "Mounts:"

# kubelet работает с PVC
kubectl get pvc -n monitoring
kubectl describe pvc <pvc-name> -n monitoring
```

### **5. kubelet логи и события:**
```bash
# События от kubelet
kubectl get events --field-selector source=kubelet

# kubelet создает события о состоянии Pod'ов
kubectl describe pod <pod-name> -n argocd | grep -A 10 "Events:"
```

## 🔄 **Архитектура kubelet:**

```
┌─────────────────────────────────────────────────────────────┐
│                        kubelet                              │
├─────────────────────────────────────────────────────────────┤
│  API Client                                                 │
│  ├── Watch Pod specs from API Server                       │
│  ├── Report Pod status to API Server                       │
│  └── Authenticate with certificates                        │
├─────────────────────────────────────────────────────────────┤
│  Pod Manager                                                │
│  ├── Pod lifecycle management                              │
│  ├── Container creation/deletion                           │
│  ├── Image pulling                                         │
│  └── Pod sandbox management                                │
├─────────────────────────────────────────────────────────────┤
│  Container Runtime Interface (CRI)                         │
│  ├── containerd/CRI-O integration                          │
│  ├── Container operations                                  │
│  └── Image management                                      │
├─────────────────────────────────────────────────────────────┤
│  Volume Manager                                             │
│  ├── Volume mounting/unmounting                            │
│  ├── PVC attachment                                        │
│  └── Storage plugin integration                            │
├─────────────────────────────────────────────────────────────┤
│  Network Manager                                            │
│  ├── Pod networking setup                                  │
│  ├── CNI plugin integration                                │
│  └── Port management                                       │
├─────────────────────────────────────────────────────────────┤
│  Health Manager                                             │
│  ├── Liveness probes                                       │
│  ├── Readiness probes                                      │
│  ├── Startup probes                                        │
│  └── Container restart logic                               │
├─────────────────────────────────────────────────────────────┤
│  Resource Manager                                           │
│  ├── cgroups management                                    │
│  ├── Resource limits enforcement                           │
│  ├── QoS classes                                           │
│  └── Metrics collection                                    │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **kubelet в действии:**

### **1. Жизненный цикл Pod'а:**
```bash
# 1. kubelet получает Pod spec от API Server
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-kubelet
spec:
  containers:
  - name: nginx
    image: nginx
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 30
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
EOF

# 2. kubelet создает Pod sandbox
# 3. kubelet скачивает образ
# 4. kubelet запускает контейнер
# 5. kubelet настраивает сеть
# 6. kubelet начинает health checks

kubectl get pod test-kubelet -w
kubectl describe pod test-kubelet

# Очистка
kubectl delete pod test-kubelet
```

### **2. Restart policy:**
```bash
# kubelet перезапускает контейнеры согласно restart policy
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restart-test
spec:
  restartPolicy: Always
  containers:
  - name: failing-container
    image: busybox
    command: ["sh", "-c", "sleep 10; exit 1"]
EOF

# kubelet будет перезапускать контейнер
kubectl get pod restart-test -w
kubectl describe pod restart-test | grep -A 5 "Events:"

# Очистка
kubectl delete pod restart-test
```

## 📈 **Мониторинг kubelet:**

### **1. kubelet метрики:**
```bash
# kubelet предоставляет метрики на порту 10255 (read-only) или 10250 (auth)
# В managed кластере доступ ограничен

# Метрики через Prometheus:
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# kubelet метрики:
# kubelet_running_pods - количество запущенных Pod'ов
# kubelet_running_containers - количество контейнеров
# kubelet_volume_stats_* - статистика volumes
# kubelet_node_* - метрики Node
```

### **2. Node статус от kubelet:**
```bash
# kubelet отправляет статус Node в API Server
kubectl describe nodes | grep -A 10 "Conditions:"

# kubelet отправляет информацию о ресурсах
kubectl describe nodes | grep -A 5 "Capacity:"
kubectl describe nodes | grep -A 5 "Allocatable:"
```

### **3. kubelet health:**
```bash
# kubelet health endpoint
# /healthz - общее состояние
# /metrics - метрики
# /stats - статистика

# В managed кластере прямой доступ ограничен
```

## 🏭 **kubelet в вашем HA кластере:**

### **1. kubelet на каждой Node:**
```bash
# kubelet работает на всех Node'ах
kubectl get nodes

# kubelet управляет системными Pod'ами
kubectl get pods -n kube-system -o wide

# kubelet управляет приложениями
kubectl get pods -A -o wide
```

### **2. kubelet и автомасштабирование:**
```bash
# kubelet предоставляет метрики для HPA
kubectl get hpa -A

# kubelet поддерживает новые Node'ы при cluster autoscaling
kubectl get nodes --watch
```

### **3. kubelet и мониторинг:**
```bash
# kubelet интегрируется с metrics-server
kubectl top nodes
kubectl top pods -A

# kubelet предоставляет данные для Prometheus
kubectl get servicemonitor -A | grep kubelet
```

## 🔒 **Безопасность kubelet:**

### **1. Аутентификация:**
```bash
# kubelet использует сертификаты для связи с API Server
# В managed кластере это настроено автоматически

# kubelet имеет собственный ServiceAccount
kubectl get serviceaccounts -n kube-system | grep kubelet
```

### **2. Авторизация:**
```bash
# kubelet имеет ограниченные права в кластере
kubectl describe clusterrole system:kubelet-api-admin

# Node authorization для kubelet
kubectl get clusterroles | grep node
```

## 🚨 **Проблемы kubelet:**

### **1. Pod не запускается:**
```bash
# Проверить события от kubelet
kubectl describe pod <pod-name> | grep -A 10 "Events:"

# Возможные причины:
# - Образ не найден
# - Недостаточно ресурсов
# - Volume не может быть примонтирован
# - Проблемы с сетью
```

### **2. Node NotReady:**
```bash
# Проверить статус Node
kubectl describe node <node-name> | grep -A 10 "Conditions:"

# kubelet может быть недоступен
# Проблемы с container runtime
# Проблемы с сетью или диском
```

## 🎯 **Best Practices для kubelet:**

### **1. Resource Management:**
- Настройте правильные resource requests/limits
- Используйте QoS classes
- Мониторьте использование ресурсов

### **2. Health Checks:**
- Всегда настраивайте liveness probes
- Используйте readiness probes для traffic routing
- Настройте startup probes для медленно стартующих приложений

### **3. Мониторинг:**
- Следите за метриками kubelet
- Мониторьте статус Node'ов
- Анализируйте события от kubelet

**kubelet — это рабочая лошадка каждой Node, обеспечивающая выполнение Pod'ов!**
