# 5. В чем разница между Pod и Container?

## 🎯 **Основные различия:**

| Аспект | Container | Pod |
|--------|-----------|-----|
| **Уровень** | Низкий (Docker/containerd) | Высокий (Kubernetes) |
| **Управление** | Docker/containerd | Kubernetes |
| **Сеть** | Собственный IP (или host) | Общий IP для всех контейнеров |
| **Хранилище** | Собственные volumes | Общие volumes |
| **Жизненный цикл** | Независимый | Связанный с другими контейнерами |
| **Масштабирование** | Ручное | Автоматическое через Kubernetes |

## 🐳 **Container (Контейнер)**

**Container** — это изолированный процесс, запущенный из Docker образа, со своими ресурсами и файловой системой.

### **Характеристики контейнера:**
- Один процесс или приложение
- Собственная файловая система
- Изоляция ресурсов (CPU, память)
- Портативность между средами

## ☸️ **Pod (Под)**

**Pod** — это обертка Kubernetes вокруг одного или нескольких контейнеров, которая обеспечивает общие ресурсы.

### **Характеристики Pod'а:**
- Содержит 1+ контейнеров
- Общая сеть и хранилище
- Управляется Kubernetes
- Атомарная единица развертывания

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Посмотреть на контейнеры внутри Pod'ов:**
```bash
# Pod'ы ArgoCD
kubectl get pods -n argocd

# Контейнеры внутри конкретного Pod'а
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 10 "Containers:"

# Количество контейнеров в каждом Pod'е
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{": "}{len(.spec.containers)}{" containers\n"}{end}'
```

### **2. Сравнение сетевых настроек:**
```bash
# IP адрес Pod'а (общий для всех контейнеров)
kubectl get pods -n argocd -o wide

# Зайти в контейнер и посмотреть сетевые интерфейсы
kubectl exec -it <argocd-server-pod> -n argocd -- ip addr show

# Все контейнеры в Pod'е видят одинаковые сетевые интерфейсы
kubectl exec -it <argocd-server-pod> -n argocd -- netstat -tlnp
```

### **3. Образы контейнеров в Pod'ах:**
```bash
# Какие Docker образы используются в Pod'ах ArgoCD
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[*].image}{"\n"}{end}'

# Детальная информация об образах
kubectl describe pod <argocd-server-pod> -n argocd | grep "Image:"
```

### **4. Жизненный цикл: Pod vs Container:**
```bash
# Перезапуск Pod'а перезапускает ВСЕ контейнеры в нем
kubectl delete pod <argocd-server-pod> -n argocd

# Новый Pod создается с новыми контейнерами
kubectl get pods -n argocd --watch

# Статистика перезапусков контейнеров
kubectl get pods -n argocd -o wide
```

## 🔄 **Практические сценарии:**

### **1. Single Container Pod (наиболее частый случай):**
```bash
# Большинство Pod'ов содержат один контейнер
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{": "}{len(.spec.containers)}{" container(s)\n"}{end}'

# Пример: ArgoCD Server Pod с одним контейнером
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "Containers:"
```

### **2. Multi-Container Pod (sidecar pattern):**
```bash
# Создать Pod с несколькими контейнерами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-example
spec:
  containers:
  - name: main-app
    image: nginx
    ports:
    - containerPort: 80
  - name: log-sidecar
    image: busybox
    command: ['sh', '-c', 'while true; do echo "Sidecar running"; sleep 30; done']
EOF

# Посмотреть на контейнеры в Pod'е
kubectl describe pod multi-container-example | grep -A 10 "Containers:"

# Выполнить команду в конкретном контейнере
kubectl exec -it multi-container-example -c main-app -- nginx -v
kubectl exec -it multi-container-example -c log-sidecar -- ps aux

# Очистка
kubectl delete pod multi-container-example
```

### **3. Shared Network в действии:**
```bash
# Создать Pod с двумя контейнерами
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: shared-network-demo
spec:
  containers:
  - name: web-server
    image: nginx
    ports:
    - containerPort: 80
  - name: curl-client
    image: curlimages/curl
    command: ['sh', '-c', 'while true; do sleep 3600; done']
EOF

# Из второго контейнера обратиться к первому через localhost
kubectl exec -it shared-network-demo -c curl-client -- curl localhost:80

# Оба контейнера видят одинаковые сетевые интерфейсы
kubectl exec -it shared-network-demo -c web-server -- ip addr show
kubectl exec -it shared-network-demo -c curl-client -- ip addr show

# Очистка
kubectl delete pod shared-network-demo
```

### **4. Shared Storage в действии:**
```bash
# Создать Pod с общим volume
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: shared-storage-demo
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do echo "$(date): Writer container" >> /shared/log.txt; sleep 10; done']
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  - name: reader
    image: busybox
    command: ['sh', '-c', 'while true; do echo "Reading:"; cat /shared/log.txt 2>/dev/null || echo "No file yet"; sleep 15; done']
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  volumes:
  - name: shared-volume
    emptyDir: {}
EOF

# Посмотреть логи обоих контейнеров
kubectl logs shared-storage-demo -c writer
kubectl logs shared-storage-demo -c reader

# Очистка
kubectl delete pod shared-storage-demo
```

## 🏭 **Примеры из вашего HA кластера:**

### **1. ArgoCD: Pod'ы с одним контейнером:**
```bash
# ArgoCD Server Pod содержит один контейнер
kubectl get pod <argocd-server-pod> -n argocd -o jsonpath='{.spec.containers[*].name}'

# Контейнер запущен из образа ArgoCD
kubectl get pod <argocd-server-pod> -n argocd -o jsonpath='{.spec.containers[*].image}'

# Pod управляет жизненным циклом контейнера
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "State:"
```

### **2. Redis HA: Pod'ы с несколькими контейнерами:**
```bash
# Redis HA Pod'ы могут содержать несколько контейнеров
kubectl get pods -n argocd -l app=redis-ha -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[*].name}{"\n"}{end}'

# Sentinel и Redis контейнеры в одном Pod'е
kubectl describe pod <redis-ha-pod> -n argocd | grep -A 15 "Containers:"
```

### **3. Мониторинг: Prometheus Pod:**
```bash
# Prometheus Pod с одним контейнером
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[*].name}{"\n"}{end}'

# Persistent Volume примонтирован к Pod'у (доступен контейнеру)
kubectl describe pod <prometheus-pod> -n monitoring | grep -A 10 "Mounts:"
```

## 🔧 **Управление: Container vs Pod:**

### **Container уровень (Docker команды):**
```bash
# НА НОДЕ кластера (не в kubectl):
# docker ps                    # Список запущенных контейнеров
# docker logs <container-id>   # Логи контейнера
# docker exec -it <id> bash    # Зайти в контейнер
# docker stop <container-id>   # Остановить контейнер
```

### **Pod уровень (kubectl команды):**
```bash
# Список Pod'ов
kubectl get pods -n argocd

# Логи Pod'а (всех контейнеров)
kubectl logs <pod-name> -n argocd

# Зайти в Pod (в первый контейнер)
kubectl exec -it <pod-name> -n argocd -- /bin/sh

# Удалить Pod (удалит все контейнеры)
kubectl delete pod <pod-name> -n argocd
```

## 📈 **Мониторинг: Container vs Pod метрики:**

### **Container метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# В Prometheus UI найти метрики:
# container_cpu_usage_seconds_total    # CPU контейнера
# container_memory_usage_bytes         # Память контейнера
# container_fs_usage_bytes            # Диск контейнера
```

### **Pod метрики:**
```bash
# Использование ресурсов Pod'ами
kubectl top pods -n argocd

# В Prometheus UI найти метрики:
# kube_pod_status_phase               # Статус Pod'а
# kube_pod_container_status_restarts_total  # Перезапуски контейнеров в Pod'е
# kube_pod_info                       # Информация о Pod'е
```

## 🎯 **Ключевые выводы:**

### **Container:**
- **Что**: Изолированный процесс с приложением
- **Где**: Запускается Docker/containerd
- **Управление**: Docker команды
- **Сеть**: Собственный IP или host network
- **Хранилище**: Собственные volumes

### **Pod:**
- **Что**: Обертка Kubernetes вокруг контейнеров
- **Где**: Управляется Kubernetes
- **Управление**: kubectl команды
- **Сеть**: Общий IP для всех контейнеров
- **Хранилище**: Общие volumes

### **Аналогия:**
- **Container** = Комната в квартире
- **Pod** = Квартира (может содержать несколько комнат)

### **В вашем HA кластере:**
```bash
# Pod'ы обеспечивают высокую доступность
kubectl get pods -n argocd -o wide

# Контейнеры внутри Pod'ов выполняют конкретные задачи
kubectl describe pod <argocd-server-pod> -n argocd | grep "Image:"

# Kubernetes управляет Pod'ами, Pod'ы управляют контейнерами
kubectl get replicasets -n argocd
```

**Pod — это Kubernetes абстракция над контейнерами, которая добавляет общие ресурсы и управление жизненным циклом!**
