# 4. Что такое Pod в Kubernetes?

## 🎯 **Что такое Pod?**

**Pod** — это наименьшая развертываемая единица в Kubernetes, которая содержит один или несколько тесно связанных контейнеров, разделяющих сеть и хранилище.

## 🏗️ **Ключевые характеристики Pod:**

### **1. Атомарная единица**
- Pod создается и удаляется как единое целое
- Все контейнеры в Pod запускаются на одной ноде
- Pod имеет уникальный IP адрес в кластере

### **2. Разделяемые ресурсы**
- **Сеть**: Все контейнеры используют один IP и порты
- **Хранилище**: Volumes монтируются во все контейнеры
- **Жизненный цикл**: Контейнеры живут и умирают вместе

### **3. Эфемерность**
- Pod может быть пересоздан в любой момент
- IP адрес может измениться при пересоздании
- Данные внутри Pod теряются (если нет Persistent Volumes)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Посмотреть на Pod'ы в кластере:**
```bash
# Все Pod'ы во всех namespace'ах
kubectl get pods -A

# Pod'ы ArgoCD
kubectl get pods -n argocd

# Детальная информация о Pod'е
kubectl describe pod <pod-name> -n argocd

# Pod'ы с IP адресами и нодами
kubectl get pods -n argocd -o wide
```

### **2. Структура Pod'а ArgoCD Server:**
```bash
# Посмотреть YAML конфигурацию Pod'а
kubectl get pod <argocd-server-pod> -n argocd -o yaml

# Контейнеры внутри Pod'а
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 10 "Containers:"

# Образы контейнеров в Pod'е
kubectl get pod <argocd-server-pod> -n argocd -o jsonpath='{.spec.containers[*].image}'
```

### **3. Сетевые характеристики Pod'а:**
```bash
# IP адрес Pod'а
kubectl get pods -n argocd -o wide

# Порты, которые слушает Pod
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "Ports:"

# Проверить сетевую связность между Pod'ами
kubectl exec -it <pod1> -n argocd -- ping <pod2-ip>
```

### **4. Жизненный цикл Pod'а:**
```bash
# Статус Pod'а (Running, Pending, Failed, etc.)
kubectl get pods -n argocd

# События Pod'а (создание, планирование, запуск)
kubectl describe pod <pod-name> -n argocd | grep -A 10 "Events:"

# Логи Pod'а
kubectl logs <pod-name> -n argocd

# Логи конкретного контейнера в Pod'е (если их несколько)
kubectl logs <pod-name> -c <container-name> -n argocd
```

### **5. Ресурсы Pod'а:**
```bash
# Использование CPU и памяти
kubectl top pods -n argocd

# Лимиты и запросы ресурсов
kubectl describe pod <pod-name> -n argocd | grep -A 10 "Limits:"

# Volumes, примонтированные к Pod'у
kubectl describe pod <pod-name> -n argocd | grep -A 10 "Volumes:"
```

### **6. Многоконтейнерные Pod'ы:**
```bash
# Pod'ы с несколькими контейнерами (например, с sidecar'ами)
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{" containers: "}{.spec.containers[*].name}{"\n"}{end}'

# Выполнить команду в конкретном контейнере
kubectl exec -it <pod-name> -c <container-name> -n argocd -- /bin/sh
```

## 🔄 **Управление Pod'ами:**

### **1. Создание Pod'а:**
```bash
# Простой Pod с nginx
kubectl run test-pod --image=nginx --restart=Never

# Посмотреть созданный Pod
kubectl get pod test-pod

# Детальная информация
kubectl describe pod test-pod
```

### **2. Взаимодействие с Pod'ом:**
```bash
# Выполнить команду в Pod'е
kubectl exec -it test-pod -- /bin/bash

# Скопировать файл в/из Pod'а
kubectl cp test-pod:/etc/nginx/nginx.conf ./nginx.conf

# Port forwarding для доступа к Pod'у
kubectl port-forward pod/test-pod 8080:80
```

### **3. Удаление Pod'а:**
```bash
# Удалить Pod
kubectl delete pod test-pod

# Принудительное удаление
kubectl delete pod test-pod --force --grace-period=0
```

## 🏭 **Pod'ы в вашем HA кластере:**

### **1. ArgoCD Pod'ы с высокой доступностью:**
```bash
# ArgoCD Server - 3 реплики для HA
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# ArgoCD Controller - 2 реплики для HA
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Redis HA - 3 реплики для отказоустойчивости
kubectl get pods -n argocd -l app=redis-ha
```

### **2. Мониторинг Pod'ов:**
```bash
# Prometheus Pod с persistent storage
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Grafana Pod с конфигурацией
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# NFS Exporter Pod для мониторинга файловой системы
kubectl get pods -l app=nfs-exporter
```

### **3. Распределение Pod'ов по нодам:**
```bash
# Посмотреть, как Pod'ы распределены по нодам для HA
kubectl get pods -n argocd -o wide

# Anti-affinity правила не дают Pod'ам попасть на одну ноду
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 10 "Node-Selectors:"
```

## 🔧 **Паттерны использования Pod'ов:**

### **1. Single Container Pod (наиболее частый):**
```bash
# Большинство Pod'ов содержат один контейнер
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{" containers: "}{len(.spec.containers)}{"\n"}{end}'
```

### **2. Multi-Container Pod (sidecar pattern):**
```yaml
# Пример Pod'а с основным контейнером и sidecar'ом
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: main-app
    image: nginx
  - name: log-sidecar
    image: busybox
    command: ['sh', '-c', 'tail -f /var/log/nginx/access.log']
```

### **3. Init Container Pattern:**
```bash
# Pod'ы с init контейнерами (выполняются перед основными)
kubectl describe pod <pod-name> -n argocd | grep -A 5 "Init Containers:"
```

## 📈 **Мониторинг Pod'ов в вашем кластере:**

### **1. Prometheus метрики Pod'ов:**
```bash
# ServiceMonitor для сбора метрик с Pod'ов
kubectl get servicemonitor -n monitoring

# Port forward к Prometheus для просмотра метрик
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Открыть http://localhost:9090 и найти метрики: container_*
```

### **2. Grafana дашборды Pod'ов:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80
# Открыть http://localhost:3000 и посмотреть Kubernetes дашборды
```

### **3. Логи Pod'ов:**
```bash
# Логи всех Pod'ов ArgoCD
kubectl logs -l app.kubernetes.io/part-of=argocd -n argocd

# Следить за логами в реальном времени
kubectl logs -f <pod-name> -n argocd

# Логи за последние 1 час
kubectl logs --since=1h <pod-name> -n argocd
```

## 🎯 **Ключевые концепции Pod'ов:**

### **1. Эфемерность:**
```bash
# Pod'ы могут быть пересозданы в любой момент
kubectl delete pod <argocd-server-pod> -n argocd
kubectl get pods -n argocd --watch  # Новый Pod будет создан автоматически
```

### **2. Shared Network:**
```bash
# Все контейнеры в Pod'е используют один IP
kubectl exec -it <pod-name> -n argocd -- ip addr show

# Контейнеры могут общаться через localhost
kubectl exec -it <pod-name> -n argocd -- netstat -tlnp
```

### **3. Shared Storage:**
```bash
# Volumes монтируются во все контейнеры Pod'а
kubectl describe pod <pod-name> -n argocd | grep -A 20 "Mounts:"
```

## 🏗️ **Pod в контексте других ресурсов:**

```
Deployment → ReplicaSet → Pod → Container(s)
     ↓           ↓         ↓         ↓
  Желаемое   Текущее   Исполнение  Приложение
 состояние  состояние
```

### **Проверить эту иерархию:**
```bash
# Deployment управляет ReplicaSet
kubectl get deployments -n argocd

# ReplicaSet управляет Pod'ами
kubectl get replicasets -n argocd

# Pod'ы содержат контейнеры
kubectl get pods -n argocd

# Связь между ресурсами
kubectl describe deployment argocd-server -n argocd
```

**Pod — это основа всего в Kubernetes. Понимание Pod'ов критично для работы с кластером!**
