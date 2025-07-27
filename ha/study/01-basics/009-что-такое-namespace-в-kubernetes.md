# 9. Что такое Namespace в Kubernetes?

## 🎯 **Что такое Namespace?**

**Namespace (Пространство имен)** — это виртуальное разделение кластера Kubernetes, которое позволяет изолировать группы ресурсов в одном физическом кластере.

## 🏗️ **Назначение Namespace:**

### **1. Изоляция ресурсов**
- Логическое разделение приложений
- Предотвращение конфликтов имен
- Организация по командам/проектам

### **2. Управление доступом**
- RBAC (Role-Based Access Control)
- Ограничение доступа к ресурсам
- Безопасность на уровне namespace

### **3. Управление ресурсами**
- Resource Quotas (лимиты ресурсов)
- Limit Ranges (ограничения для объектов)
- Network Policies (сетевая изоляция)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Посмотреть на Namespace'ы в кластере:**
```bash
# Список всех namespace'ов
kubectl get namespaces

# Детальная информация о namespace'ах
kubectl get ns -o wide

# Описание конкретного namespace'а
kubectl describe namespace argocd

# Namespace'ы с labels
kubectl get ns --show-labels
```

### **2. Ресурсы в разных Namespace'ах:**
```bash
# Pod'ы в namespace argocd
kubectl get pods -n argocd

# Pod'ы в namespace monitoring
kubectl get pods -n monitoring

# Pod'ы в системном namespace
kubectl get pods -n kube-system

# Все Pod'ы во всех namespace'ах
kubectl get pods -A
```

### **3. ArgoCD Namespace:**
```bash
# Все ресурсы ArgoCD
kubectl get all -n argocd

# ConfigMaps в ArgoCD namespace
kubectl get configmaps -n argocd

# Secrets в ArgoCD namespace
kubectl get secrets -n argocd

# Services в ArgoCD namespace
kubectl get svc -n argocd
```

### **4. Monitoring Namespace:**
```bash
# Все ресурсы мониторинга
kubectl get all -n monitoring

# Persistent Volume Claims для мониторинга
kubectl get pvc -n monitoring

# ServiceMonitor ресурсы
kubectl get servicemonitor -n monitoring

# Ingress для мониторинга
kubectl get ingress -n monitoring
```

### **5. System Namespace'ы:**
```bash
# Системные компоненты Kubernetes
kubectl get pods -n kube-system

# Ingress Controller
kubectl get pods -n ingress-nginx

# DNS система
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Сетевые компоненты
kubectl get pods -n kube-system | grep -E "(calico|flannel|weave)"
```

## 🔧 **Работа с Namespace'ами:**

### **1. Создание Namespace'а:**
```bash
# Создать namespace императивно
kubectl create namespace test-namespace

# Создать namespace декларативно
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: dev
    team: backend
EOF

# Посмотреть созданные namespace'ы
kubectl get ns test-namespace development
```

### **2. Работа с ресурсами в Namespace'е:**
```bash
# Создать Pod в конкретном namespace'е
kubectl run test-pod --image=nginx -n development

# Посмотреть Pod в namespace'е
kubectl get pods -n development

# Создать Service в namespace'е
kubectl expose pod test-pod --port=80 -n development

# Посмотреть все ресурсы в namespace'е
kubectl get all -n development
```

### **3. Переключение контекста:**
```bash
# Установить namespace по умолчанию для текущего контекста
kubectl config set-context --current --namespace=development

# Проверить текущий namespace
kubectl config view --minify | grep namespace

# Теперь команды выполняются в development namespace
kubectl get pods  # эквивалентно kubectl get pods -n development

# Вернуть обратно в default
kubectl config set-context --current --namespace=default
```

### **4. Удаление Namespace'а:**
```bash
# Удалить namespace (удалит ВСЕ ресурсы внутри)
kubectl delete namespace test-namespace development

# Проверить что namespace'ы удалены
kubectl get ns
```

## 🏭 **Namespace'ы в вашем HA кластере:**

### **1. Организация по функциональности:**
```bash
# ArgoCD - GitOps платформа
kubectl get all -n argocd | wc -l

# Monitoring - наблюдаемость
kubectl get all -n monitoring | wc -l

# Ingress-nginx - входящий трафик
kubectl get all -n ingress-nginx | wc -l

# Kube-system - системные компоненты
kubectl get all -n kube-system | wc -l
```

### **2. Изоляция приложений:**
```bash
# ArgoCD изолирован от мониторинга
kubectl get pods -n argocd
kubectl get pods -n monitoring

# Каждый namespace имеет свои Service'ы
kubectl get svc -n argocd
kubectl get svc -n monitoring

# Secrets изолированы по namespace'ам
kubectl get secrets -n argocd
kubectl get secrets -n monitoring
```

### **3. Сетевая связность между Namespace'ами:**
```bash
# Service в другом namespace доступен по FQDN
# <service-name>.<namespace>.svc.cluster.local

# Пример: ArgoCD может обращаться к Prometheus
# prometheus-server.monitoring.svc.cluster.local:80

# Проверить DNS разрешение
kubectl run test-dns --image=busybox -it --rm -- nslookup prometheus-server.monitoring.svc.cluster.local
```

## 🔒 **Безопасность и изоляция:**

### **1. RBAC по Namespace'ам:**
```bash
# Роли ограничены namespace'ом
kubectl get roles -n argocd

# RoleBindings привязывают пользователей к ролям в namespace'е
kubectl get rolebindings -n argocd

# ClusterRoles работают во всех namespace'ах
kubectl get clusterroles | grep argocd

# ServiceAccounts изолированы по namespace'ам
kubectl get serviceaccounts -n argocd
```

### **2. Resource Quotas:**
```bash
# Создать Resource Quota для namespace'а
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: development
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
    services: "5"
EOF

# Посмотреть квоты
kubectl get resourcequota -n development
kubectl describe resourcequota development-quota -n development

# Очистка
kubectl delete resourcequota development-quota -n development
```

### **3. Network Policies:**
```bash
# Создать Network Policy для изоляции namespace'а
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: development
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Посмотреть Network Policies
kubectl get networkpolicies -n development

# Очистка
kubectl delete networkpolicy deny-all -n development
```

## 📈 **Мониторинг по Namespace'ам:**

### **1. Prometheus метрики по Namespace'ам:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# В Prometheus UI найти метрики по namespace'ам:
# kube_namespace_status_phase{namespace="argocd"}
# container_cpu_usage_seconds_total{namespace="monitoring"}
# kube_pod_info{namespace="argocd"}
```

### **2. Grafana дашборды по Namespace'ам:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# В дашбордах можно фильтровать по namespace:
# - Kubernetes Cluster Monitoring (по namespace)
# - Pod ресурсы по namespace'ам
# - Network трафик между namespace'ами
```

### **3. Логи по Namespace'ам:**
```bash
# Логи всех Pod'ов в namespace'е
kubectl logs -l app.kubernetes.io/part-of=argocd -n argocd

# Логи всех Pod'ов мониторинга
kubectl logs -l app.kubernetes.io/name=prometheus -n monitoring

# События в namespace'е
kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
```

## 🔄 **Практические сценарии:**

### **1. Разделение по окружениям:**
```bash
# Создать namespace'ы для разных окружений
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace development

# Добавить labels для организации
kubectl label namespace production environment=prod
kubectl label namespace staging environment=staging
kubectl label namespace development environment=dev

# Посмотреть namespace'ы с labels
kubectl get ns --show-labels

# Очистка
kubectl delete namespace production staging development
```

### **2. Разделение по командам:**
```bash
# Создать namespace'ы для команд
kubectl create namespace team-frontend
kubectl create namespace team-backend
kubectl create namespace team-data

# Добавить labels команд
kubectl label namespace team-frontend team=frontend
kubectl label namespace team-backend team=backend
kubectl label namespace team-data team=data

# Найти namespace'ы конкретной команды
kubectl get ns -l team=frontend

# Очистка
kubectl delete namespace team-frontend team-backend team-data
```

### **3. Временные namespace'ы для тестирования:**
```bash
# Создать временный namespace для эксперимента
kubectl create namespace experiment-$(date +%s)

# Запустить тестовое приложение
kubectl run test-app --image=nginx -n experiment-*

# После тестирования удалить весь namespace
kubectl delete namespace experiment-*
```

## 🎯 **Best Practices для Namespace'ов:**

### **1. Именование:**
```bash
# Используйте понятные имена
production, staging, development
team-frontend, team-backend
monitoring, logging, security
```

### **2. Labels для организации:**
```bash
# Стандартные labels
environment: production
team: platform
project: hashfoundry
cost-center: engineering
```

### **3. Resource Quotas:**
```bash
# Всегда устанавливайте лимиты ресурсов
requests.cpu: "4"
requests.memory: 8Gi
limits.cpu: "8"
limits.memory: 16Gi
```

## 🏗️ **Namespace'ы в архитектуре вашего кластера:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                      │
├─────────────────────────────────────────────────────────────┤
│  kube-system (System Components)                           │
│  ├── kube-proxy, kube-dns                                  │
│  ├── CNI pods, metrics-server                              │
│  └── System DaemonSets                                     │
├─────────────────────────────────────────────────────────────┤
│  argocd (GitOps Platform)                                  │
│  ├── ArgoCD Server (3 replicas)                            │
│  ├── ArgoCD Controller (2 replicas)                        │
│  ├── Redis HA (3 replicas)                                 │
│  └── ArgoCD Applications                                    │
├─────────────────────────────────────────────────────────────┤
│  monitoring (Observability)                                │
│  ├── Prometheus Server                                     │
│  ├── Grafana                                               │
│  ├── NFS Exporter                                          │
│  └── ServiceMonitors                                       │
├─────────────────────────────────────────────────────────────┤
│  ingress-nginx (Traffic Routing)                           │
│  ├── NGINX Ingress Controller                              │
│  ├── Load Balancer Service                                 │
│  └── Ingress Resources                                     │
├─────────────────────────────────────────────────────────────┤
│  default (Default Namespace)                               │
│  ├── NFS Provisioner                                       │
│  └── User applications                                     │
└─────────────────────────────────────────────────────────────┘
```

### **Проверить архитектуру:**
```bash
# Количество ресурсов в каждом namespace'е
kubectl get all -n argocd | wc -l
kubectl get all -n monitoring | wc -l
kubectl get all -n ingress-nginx | wc -l
kubectl get all -n kube-system | wc -l
```

**Namespace'ы — это основа организации и изоляции ресурсов в Kubernetes кластере!**
