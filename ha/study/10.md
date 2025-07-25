# 10. В чем разница между StatefulSet и Deployment?

## 🎯 **Основные различия:**

| Аспект | Deployment | StatefulSet |
|--------|------------|-------------|
| **Назначение** | Stateless приложения | Stateful приложения |
| **Идентичность Pod'ов** | Взаимозаменяемые | Уникальная идентичность |
| **Имена Pod'ов** | Случайные суффиксы | Порядковые номера |
| **Порядок создания** | Параллельное | Последовательное |
| **Хранилище** | Общие volumes | Индивидуальные PVC |
| **Сетевая идентичность** | Нет | Стабильная |
| **Обновления** | Rolling update | Упорядоченное обновление |

## 📦 **Deployment (Развертывание)**

**Deployment** — это ресурс для управления stateless приложениями, где все Pod'ы взаимозаменяемы.

### **Характеристики Deployment:**
- Pod'ы **идентичны** и **взаимозаменяемы**
- **Случайные имена** Pod'ов
- **Параллельное** создание и удаление
- **Общие volumes** (если нужны)
- Подходит для **web серверов**, **API**, **микросервисов**

## 🗄️ **StatefulSet (Состояние)**

**StatefulSet** — это ресурс для управления stateful приложениями, где каждый Pod имеет уникальную идентичность.

### **Характеристики StatefulSet:**
- Pod'ы имеют **уникальную идентичность**
- **Предсказуемые имена** Pod'ов (app-0, app-1, app-2)
- **Последовательное** создание и удаление
- **Индивидуальные PVC** для каждого Pod'а
- Подходит для **баз данных**, **очередей**, **кластерных приложений**

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Deployment примеры (ArgoCD):**
```bash
# ArgoCD Server - stateless приложение
kubectl get deployment argocd-server -n argocd

# Pod'ы имеют случайные суффиксы
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# ReplicaSet управляет Pod'ами
kubectl get replicasets -n argocd -l app.kubernetes.io/name=argocd-server

# Все Pod'ы идентичны и взаимозаменяемы
kubectl describe deployment argocd-server -n argocd | grep -A 5 "Replicas:"
```

### **2. StatefulSet примеры (Redis HA):**
```bash
# Redis HA - stateful приложение
kubectl get statefulsets -n argocd

# Pod'ы имеют порядковые номера
kubectl get pods -n argocd -l app=redis-ha

# Каждый Pod имеет свой PVC
kubectl get pvc -n argocd | grep redis

# Headless Service для стабильной сетевой идентичности
kubectl get svc -n argocd | grep redis
```

### **3. Prometheus как StatefulSet:**
```bash
# Prometheus обычно развертывается как StatefulSet
kubectl get statefulsets -n monitoring

# Prometheus Pod с предсказуемым именем
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Persistent storage для данных Prometheus
kubectl get pvc -n monitoring | grep prometheus
```

## 🔄 **Поведение при создании и удалении:**

### **1. Deployment - параллельное создание:**
```bash
# Создать Deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

# Все Pod'ы создаются одновременно
kubectl get pods -l app=web --watch

# Имена Pod'ов случайные
kubectl get pods -l app=web -o name
```

### **2. StatefulSet - последовательное создание:**
```bash
# Создать StatefulSet
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-statefulset
spec:
  serviceName: web-headless
  replicas: 3
  selector:
    matchLabels:
      app: web-stateful
  template:
    metadata:
      labels:
        app: web-stateful
    spec:
      containers:
      - name: nginx
        image: nginx
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

# Pod'ы создаются по порядку: web-statefulset-0, затем web-statefulset-1, затем web-statefulset-2
kubectl get pods -l app=web-stateful --watch

# Имена Pod'ов предсказуемые
kubectl get pods -l app=web-stateful -o name
```

### **3. Headless Service для StatefulSet:**
```bash
# Создать Headless Service
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None
  selector:
    app: web-stateful
  ports:
  - port: 80
EOF

# Каждый Pod получает DNS запись
kubectl run test-dns --image=busybox -it --rm -- nslookup web-statefulset-0.web-headless.default.svc.cluster.local
```

### **4. Очистка примеров:**
```bash
kubectl delete deployment web-deployment
kubectl delete statefulset web-statefulset
kubectl delete service web-headless
kubectl delete pvc -l app=web-stateful
```

## 💾 **Управление хранилищем:**

### **1. Deployment с общим хранилищем:**
```bash
# Deployment может использовать общие volumes
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared-storage-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shared-app
  template:
    metadata:
      labels:
        app: shared-app
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        persistentVolumeClaim:
          claimName: shared-pvc
EOF

# Все Pod'ы используют один PVC
kubectl describe deployment shared-storage-deployment | grep -A 10 "Volumes:"

# Очистка
kubectl delete deployment shared-storage-deployment
```

### **2. StatefulSet с индивидуальным хранилищем:**
```bash
# StatefulSet автоматически создает PVC для каждого Pod'а
kubectl get statefulset web-statefulset -o yaml | grep -A 10 "volumeClaimTemplates:"

# Каждый Pod имеет свой PVC
kubectl get pvc | grep web-statefulset

# PVC привязаны к конкретным Pod'ам
kubectl describe pvc data-web-statefulset-0
```

## 🔄 **Обновления и масштабирование:**

### **1. Deployment обновления:**
```bash
# Rolling update - Pod'ы обновляются параллельно
kubectl set image deployment/argocd-server -n argocd argocd-server=argoproj/argocd:v2.9.0

# Статус обновления
kubectl rollout status deployment/argocd-server -n argocd

# История обновлений
kubectl rollout history deployment/argocd-server -n argocd

# Откат к предыдущей версии
kubectl rollout undo deployment/argocd-server -n argocd
```

### **2. StatefulSet обновления:**
```bash
# Упорядоченное обновление - Pod'ы обновляются по порядку
kubectl get statefulsets -n argocd -o yaml | grep updateStrategy -A 5

# Обновление начинается с последнего Pod'а (highest ordinal)
kubectl describe statefulset <redis-statefulset> -n argocd | grep -A 5 "Update Strategy:"

# Можно контролировать процесс обновления
kubectl patch statefulset <redis-statefulset> -n argocd -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":1}}}}'
```

### **3. Масштабирование:**
```bash
# Deployment - быстрое параллельное масштабирование
kubectl scale deployment argocd-server --replicas=5 -n argocd

# StatefulSet - последовательное масштабирование
kubectl scale statefulset <redis-statefulset> --replicas=5 -n argocd

# При уменьшении StatefulSet удаляет Pod'ы в обратном порядке
kubectl scale statefulset <redis-statefulset> --replicas=2 -n argocd
```

## 🏭 **Примеры из вашего HA кластера:**

### **1. ArgoCD как Deployment (stateless):**
```bash
# ArgoCD Server - stateless, можно масштабировать горизонтально
kubectl get deployment argocd-server -n argocd -o yaml | grep -A 5 "replicas:"

# ArgoCD Controller - stateless, но обычно 1-2 реплики
kubectl get deployment argocd-application-controller -n argocd

# Repo Server - stateless, можно масштабировать
kubectl get deployment argocd-repo-server -n argocd

# Все Pod'ы взаимозаменяемы
kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd -o wide
```

### **2. Redis HA как StatefulSet (stateful):**
```bash
# Redis HA требует стабильной идентичности
kubectl get statefulsets -n argocd

# Каждый Redis Pod имеет уникальную роль (master/slave)
kubectl get pods -n argocd -l app=redis-ha

# Persistent storage для каждого Redis Pod'а
kubectl get pvc -n argocd | grep redis

# Headless Service для внутренней коммуникации
kubectl get svc -n argocd | grep redis
```

### **3. Prometheus как StatefulSet (stateful):**
```bash
# Prometheus хранит временные ряды данных
kubectl get statefulsets -n monitoring

# Persistent storage для данных Prometheus
kubectl get pvc -n monitoring | grep prometheus

# Стабильная идентичность для scraping
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
```

## 🔧 **Когда использовать что:**

### **Используйте Deployment для:**
- **Web серверов** (nginx, Apache)
- **API серверов** (REST, GraphQL)
- **Микросервисов** без состояния
- **Обработчиков задач** (workers)
- **Прокси серверов** (envoy, haproxy)

```bash
# Примеры из вашего кластера:
kubectl get deployments -n argocd    # ArgoCD компоненты
kubectl get deployments -n monitoring # Grafana
kubectl get deployments -n ingress-nginx # NGINX Ingress
```

### **Используйте StatefulSet для:**
- **Баз данных** (PostgreSQL, MySQL, MongoDB)
- **Очередей сообщений** (RabbitMQ, Kafka)
- **Кластерных приложений** (Elasticsearch, Redis Cluster)
- **Приложений с persistent storage**
- **Приложений требующих стабильной сетевой идентичности**

```bash
# Примеры из вашего кластера:
kubectl get statefulsets -n argocd     # Redis HA
kubectl get statefulsets -n monitoring # Prometheus
```

## 📈 **Мониторинг различий:**

### **1. Prometheus метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики для Deployment:
# kube_deployment_status_replicas
# kube_deployment_status_replicas_available
# kube_deployment_status_replicas_updated

# Метрики для StatefulSet:
# kube_statefulset_status_replicas
# kube_statefulset_status_replicas_ready
# kube_statefulset_status_current_revision
```

### **2. Grafana дашборды:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Дашборды показывают:
# - Deployment rolling updates
# - StatefulSet ordered updates
# - PVC usage по StatefulSet'ам
```

## 🎯 **Best Practices:**

### **1. Выбор типа ресурса:**
```bash
# Задайте себе вопросы:
# - Нужно ли приложению persistent storage? → StatefulSet
# - Важен ли порядок запуска? → StatefulSet  
# - Нужна ли стабильная сетевая идентичность? → StatefulSet
# - Приложение stateless? → Deployment
```

### **2. Именование и labels:**
```bash
# Deployment
app.kubernetes.io/name: web-server
app.kubernetes.io/component: frontend

# StatefulSet  
app.kubernetes.io/name: database
app.kubernetes.io/component: storage
```

### **3. Ресурсы и лимиты:**
```bash
# Deployment - одинаковые ресурсы для всех Pod'ов
resources:
  requests:
    cpu: 100m
    memory: 128Mi

# StatefulSet - может потребоваться разные ресурсы
# для master/slave конфигураций
```

## 🏗️ **Архитектура в вашем кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│                    HA Kubernetes Cluster                   │
├─────────────────────────────────────────────────────────────┤
│  Stateless Applications (Deployments)                      │
│  ├── ArgoCD Server (3 replicas) - взаимозаменяемые         │
│  ├── ArgoCD Controller (2 replicas) - взаимозаменяемые     │
│  ├── NGINX Ingress - load balancing                        │
│  └── Grafana - dashboard server                            │
├─────────────────────────────────────────────────────────────┤
│  Stateful Applications (StatefulSets)                      │
│  ├── Redis HA (3 replicas) - master/slave роли            │
│  ├── Prometheus - временные ряды данных                    │
│  └── Databases - persistent data                           │
├─────────────────────────────────────────────────────────────┤
│  Storage                                                    │
│  ├── Shared PVC - для Deployment'ов                        │
│  ├── Individual PVC - для каждого StatefulSet Pod'а        │
│  └── NFS - для ReadWriteMany                               │
└─────────────────────────────────────────────────────────────┘
```

**Deployment для stateless, StatefulSet для stateful — выбирайте правильный инструмент для задачи!**
