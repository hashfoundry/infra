# 19. Какова роль Container Runtime Interface (CRI)?

## 🎯 **Что такое CRI?**

**Container Runtime Interface (CRI)** — это стандартный API между kubelet и container runtime, который позволяет Kubernetes работать с различными container runtime'ами без изменения кода kubelet.

## 🏗️ **Основные функции CRI:**

### **1. Абстракция Runtime**
- Единый интерфейс для всех runtime'ов
- Независимость от конкретной реализации
- Стандартизация операций с контейнерами

### **2. Управление Pod'ами**
- Создание и удаление Pod sandbox
- Управление жизненным циклом Pod'ов
- Сетевая изоляция Pod'ов

### **3. Управление контейнерами**
- Создание, запуск, остановка контейнеров
- Управление образами
- Мониторинг состояния контейнеров

### **4. Управление образами**
- Скачивание образов
- Кэширование образов
- Удаление неиспользуемых образов

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Текущий Container Runtime:**
```bash
# Проверить какой runtime используется
kubectl get nodes -o wide

# Подробная информация о runtime
kubectl describe nodes | grep -A 5 "Container Runtime Version"

# В Digital Ocean обычно используется containerd
kubectl describe nodes | grep "containerd"
```

### **2. CRI в действии - создание Pod'а:**
```bash
# Создать простой Pod
kubectl run cri-test --image=nginx

# kubelet через CRI:
# 1. Создает Pod sandbox
# 2. Скачивает образ nginx
# 3. Создает контейнер
# 4. Запускает контейнер

kubectl describe pod cri-test | grep -A 10 "Events:"

# Очистка
kubectl delete pod cri-test
```

### **3. Образы через CRI:**
```bash
# kubelet управляет образами через CRI
kubectl describe nodes | grep -A 20 "Images:"

# CRI скачивает образы для Pod'ов
kubectl get pods -n argocd -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

### **4. Pod sandbox через CRI:**
```bash
# Каждый Pod имеет sandbox (pause container)
kubectl get pods -n argocd -o wide

# CRI создает сетевую изоляцию для каждого Pod'а
kubectl describe pod <argocd-pod> -n argocd | grep -A 5 "IP:"
```

## 🔄 **Архитектура CRI:**

```
┌─────────────────────────────────────────────────────────────┐
│                        kubelet                              │
├─────────────────────────────────────────────────────────────┤
│  CRI Client                                                 │
│  ├── RuntimeService Client                                  │
│  │   ├── RunPodSandbox()                                   │
│  │   ├── StopPodSandbox()                                  │
│  │   ├── CreateContainer()                                 │
│  │   ├── StartContainer()                                  │
│  │   ├── StopContainer()                                   │
│  │   └── RemoveContainer()                                 │
│  └── ImageService Client                                    │
│      ├── PullImage()                                       │
│      ├── RemoveImage()                                     │
│      ├── ImageStatus()                                     │
│      └── ListImages()                                      │
├─────────────────────────────────────────────────────────────┤
│                    gRPC/Unix Socket                        │
├─────────────────────────────────────────────────────────────┤
│  Container Runtime (containerd/CRI-O/Docker)               │
│  ├── RuntimeService Server                                  │
│  │   ├── Pod Sandbox Management                            │
│  │   ├── Container Lifecycle                               │
│  │   └── Container Monitoring                              │
│  └── ImageService Server                                    │
│      ├── Image Pull/Push                                   │
│      ├── Image Storage                                     │
│      └── Image Inspection                                  │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Популярные CRI Runtime'ы:**

### **1. containerd (используется в вашем кластере):**
```bash
# containerd - популярный CRI runtime
# Высокая производительность
# Поддержка OCI стандартов
# Используется в большинстве managed кластеров

# Проверить версию containerd
kubectl describe nodes | grep "Container Runtime Version"
```

### **2. CRI-O:**
```bash
# CRI-O - специально для Kubernetes
# Минималистичный runtime
# Полная совместимость с OCI
# Часто используется в OpenShift
```

### **3. Docker Engine (через dockershim, deprecated):**
```bash
# Docker Engine через dockershim
# Устаревший подход
# Удален в Kubernetes 1.24+
# Заменен на containerd или CRI-O
```

## 🔧 **Демонстрация CRI операций:**

### **1. Жизненный цикл Pod'а через CRI:**
```bash
# Создать Pod с несколькими контейнерами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-cri
spec:
  containers:
  - name: nginx
    image: nginx
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
EOF

# CRI операции:
# 1. RunPodSandbox - создать sandbox
# 2. PullImage - скачать nginx образ
# 3. CreateContainer - создать nginx контейнер
# 4. StartContainer - запустить nginx
# 5. PullImage - скачать busybox образ
# 6. CreateContainer - создать busybox контейнер
# 7. StartContainer - запустить busybox

kubectl describe pod multi-container-cri | grep -A 15 "Events:"

# Очистка
kubectl delete pod multi-container-cri
```

### **2. Управление образами через CRI:**
```bash
# Создать Pod с новым образом
kubectl run image-test --image=alpine:latest

# CRI автоматически скачает образ если его нет
kubectl describe pod image-test | grep -A 5 "Events:" | grep "Pulling\|Pulled"

# Образ кэшируется на Node
kubectl describe nodes | grep -A 50 "Images:" | grep alpine

# Очистка
kubectl delete pod image-test
```

## 📈 **Мониторинг CRI:**

### **1. Метрики CRI в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# CRI метрики:
# container_runtime_cri_api_request_total - количество CRI запросов
# container_runtime_cri_api_request_duration_seconds - время CRI операций
# kubelet_runtime_operations_total - операции runtime
# kubelet_runtime_operations_duration_seconds - время операций
```

### **2. kubelet метрики для CRI:**
```bash
# kubelet предоставляет метрики взаимодействия с CRI
# kubelet_pod_start_duration_seconds - время запуска Pod'ов
# kubelet_pod_worker_duration_seconds - время работы с Pod'ами
# kubelet_running_pods - количество запущенных Pod'ов
# kubelet_running_containers - количество контейнеров
```

### **3. События CRI:**
```bash
# События связанные с CRI операциями
kubectl get events --field-selector reason=Pulling
kubectl get events --field-selector reason=Pulled
kubectl get events --field-selector reason=Created
kubectl get events --field-selector reason=Started
```

## 🏭 **CRI в вашем HA кластере:**

### **1. containerd на всех Node'ах:**
```bash
# containerd работает на каждой Node
kubectl get nodes

# Все Node'ы используют один runtime
kubectl describe nodes | grep "Container Runtime Version" | sort -u

# containerd обеспечивает изоляцию между Pod'ами
```

### **2. ArgoCD и CRI:**
```bash
# ArgoCD Pod'ы управляются через CRI
kubectl get pods -n argocd

# CRI обеспечивает изоляцию ArgoCD компонентов
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "Container ID"

# Образы ArgoCD скачиваются через CRI
kubectl describe nodes | grep -A 100 "Images:" | grep argocd
```

### **3. Мониторинг и CRI:**
```bash
# Prometheus Pod'ы также управляются CRI
kubectl get pods -n monitoring

# CRI обеспечивает ресурсную изоляцию
kubectl describe pod <prometheus-pod> -n monitoring | grep -A 10 "Limits:"
```

## 🚨 **Проблемы CRI:**

### **1. Образ не скачивается:**
```bash
# Проверить события Pod'а
kubectl describe pod <pod-name> | grep -A 10 "Events:"

# Возможные причины:
# - Образ не существует
# - Проблемы с сетью
# - Недостаточно места на диске
# - Проблемы с registry аутентификацией
```

### **2. Контейнер не запускается:**
```bash
# Проверить статус контейнера
kubectl describe pod <pod-name>

# CRI может не смочь создать контейнер из-за:
# - Неправильной команды
# - Недостатка ресурсов
# - Проблем с volumes
# - Security context ограничений
```

### **3. Pod sandbox проблемы:**
```bash
# Проверить сетевые проблемы
kubectl describe pod <pod-name> | grep -A 5 "IP:"

# CRI может не смочь создать sandbox из-за:
# - Проблем с CNI
# - Конфликтов IP адресов
# - Проблем с DNS
```

## 🎯 **CRI спецификация:**

### **1. RuntimeService API:**
```protobuf
// Основные методы RuntimeService
service RuntimeService {
    rpc RunPodSandbox(RunPodSandboxRequest) returns (RunPodSandboxResponse);
    rpc StopPodSandbox(StopPodSandboxRequest) returns (StopPodSandboxResponse);
    rpc RemovePodSandbox(RemovePodSandboxRequest) returns (RemovePodSandboxResponse);
    rpc CreateContainer(CreateContainerRequest) returns (CreateContainerResponse);
    rpc StartContainer(StartContainerRequest) returns (StartContainerResponse);
    rpc StopContainer(StopContainerRequest) returns (StopContainerResponse);
    rpc RemoveContainer(RemoveContainerRequest) returns (RemoveContainerResponse);
}
```

### **2. ImageService API:**
```protobuf
// Основные методы ImageService
service ImageService {
    rpc ListImages(ListImagesRequest) returns (ListImagesResponse);
    rpc ImageStatus(ImageStatusRequest) returns (ImageStatusResponse);
    rpc PullImage(PullImageRequest) returns (PullImageResponse);
    rpc RemoveImage(RemoveImageRequest) returns (RemoveImageResponse);
}
```

## 🔄 **Best Practices для CRI:**

### **1. Выбор Runtime:**
- containerd для production
- Высокая производительность
- Хорошая поддержка сообщества
- Совместимость с Kubernetes

### **2. Мониторинг:**
- Отслеживать CRI метрики
- Мониторить время операций
- Проверять доступность образов
- Анализировать события

### **3. Отладка:**
- Проверять логи kubelet
- Анализировать события Pod'ов
- Мониторить ресурсы Node'ов
- Тестировать сетевую связность

**CRI обеспечивает гибкость и стандартизацию в работе с контейнерами в Kubernetes!**
