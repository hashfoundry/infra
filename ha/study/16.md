# 16. Объясните компоненты Controller Manager

## 🎯 **Что такое Controller Manager?**

**kube-controller-manager** — это компонент Control Plane, который запускает различные контроллеры для поддержания желаемого состояния кластера. Каждый контроллер отвечает за определенный тип ресурсов.

## 🏗️ **Основные контроллеры:**

### **1. Deployment Controller**
- Управляет ReplicaSets
- Обеспечивает rolling updates
- Поддерживает желаемое количество реплик

### **2. ReplicaSet Controller**
- Поддерживает количество Pod'ов
- Создает/удаляет Pod'ы при необходимости
- Мониторит состояние Pod'ов

### **3. Node Controller**
- Мониторит состояние Node'ов
- Обрабатывает Node failures
- Управляет Node lifecycle

### **4. Service Controller**
- Управляет Endpoints
- Обновляет Service discovery
- Интегрируется с cloud providers

### **5. Namespace Controller**
- Управляет жизненным циклом Namespace'ов
- Очищает ресурсы при удалении Namespace

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Deployment Controller в действии:**
```bash
# ArgoCD Deployment управляется Deployment Controller
kubectl get deployment argocd-server -n argocd

# Масштабирование - Deployment Controller создаст новые Pod'ы
kubectl scale deployment argocd-server --replicas=4 -n argocd

# Проверить ReplicaSet, созданный Deployment Controller
kubectl get replicasets -n argocd -l app.kubernetes.io/name=argocd-server

# Deployment Controller поддерживает желаемое состояние
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

### **2. Node Controller:**
```bash
# Node Controller мониторит состояние Node'ов
kubectl get nodes

# Node conditions, управляемые Node Controller
kubectl describe nodes | grep -A 10 "Conditions:"

# Node Controller обрабатывает недоступные Node'ы
kubectl get events --field-selector source=node-controller
```

### **3. Endpoint Controller:**
```bash
# Service Controller управляет Endpoints
kubectl get svc argocd-server -n argocd
kubectl get endpoints argocd-server -n argocd

# При изменении Pod'ов, Endpoint Controller обновляет Endpoints
kubectl describe endpoints argocd-server -n argocd
```

### **4. Namespace Controller:**
```bash
# Создание Namespace
kubectl create namespace test-controller

# Namespace Controller инициализирует Namespace
kubectl describe namespace test-controller

# При удалении Namespace Controller очищает все ресурсы
kubectl delete namespace test-controller
```

## 🔄 **Control Loop Pattern:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Controller Loop                         │
├─────────────────────────────────────────────────────────────┤
│  1. Watch API Server                                       │
│     ├── Monitor resource changes                           │
│     ├── Get current state                                  │
│     └── Compare with desired state                         │
├─────────────────────────────────────────────────────────────┤
│  2. Reconcile                                              │
│     ├── Calculate diff                                     │
│     ├── Plan actions                                       │
│     └── Execute changes                                    │
├─────────────────────────────────────────────────────────────┤
│  3. Update Status                                          │
│     ├── Report back to API Server                         │
│     ├── Update resource status                             │
│     └── Generate events                                    │
├─────────────────────────────────────────────────────────────┤
│  4. Repeat                                                 │
│     └── Continue monitoring                                │
└─────────────────────────────────────────────────────────────┘
```

## 📈 **Мониторинг Controller Manager:**

### **1. Метрики в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Controller Manager метрики:
# workqueue_depth - глубина очереди работ
# workqueue_adds_total - добавленные элементы
# controller_runtime_reconcile_total - количество reconcile операций
# rest_client_requests_total - запросы к API Server
```

### **2. События от контроллеров:**
```bash
# События от различных контроллеров
kubectl get events --sort-by=.metadata.creationTimestamp

# События от Deployment Controller
kubectl get events --field-selector source=deployment-controller

# События от ReplicaSet Controller
kubectl get events --field-selector source=replicaset-controller
```

## 🔧 **Демонстрация работы контроллеров:**

### **1. Self-healing:**
```bash
# Создать Deployment
kubectl create deployment test-healing --image=nginx --replicas=3

# Удалить Pod - ReplicaSet Controller восстановит
kubectl delete pod -l app=test-healing --force --grace-period=0

# Контроллер автоматически создаст новый Pod
kubectl get pods -l app=test-healing -w

# Очистка
kubectl delete deployment test-healing
```

### **2. Rolling Update:**
```bash
# Обновить образ - Deployment Controller выполнит rolling update
kubectl set image deployment/argocd-server -n argocd argocd-server=argoproj/argocd:v2.9.0

# Отследить процесс обновления
kubectl rollout status deployment/argocd-server -n argocd

# Deployment Controller создает новый ReplicaSet
kubectl get replicasets -n argocd -l app.kubernetes.io/name=argocd-server
```

## 🏭 **Контроллеры в вашем HA кластере:**

### **1. ArgoCD контроллеры:**
```bash
# ArgoCD Application Controller - custom controller
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Стандартные контроллеры управляют ArgoCD компонентами
kubectl get deployments -n argocd
kubectl get replicasets -n argocd
```

### **2. Мониторинг контроллеры:**
```bash
# Prometheus как StatefulSet - StatefulSet Controller
kubectl get statefulsets -n monitoring

# Grafana как Deployment - Deployment Controller
kubectl get deployments -n monitoring
```

### **3. Custom Resource Controllers:**
```bash
# ArgoCD CRDs и их контроллеры
kubectl get crd | grep argoproj

# Applications управляются ArgoCD Controller
kubectl get applications -n argocd
```

## 🎯 **Типы контроллеров:**

### **1. Built-in Controllers:**
- Deployment, ReplicaSet, DaemonSet
- Service, Endpoint, Namespace
- Node, PersistentVolume
- Job, CronJob

### **2. Custom Controllers:**
- ArgoCD Application Controller
- Prometheus Operator
- Cert-Manager Controller
- Ingress Controllers

### **3. Cloud Controllers:**
- LoadBalancer provisioning
- Volume attachment
- Node management

## 🚨 **Отладка контроллеров:**

### **1. Проверка состояния:**
```bash
# Статус ресурсов
kubectl describe deployment <name>
kubectl describe replicaset <name>

# События от контроллеров
kubectl get events --field-selector involvedObject.name=<resource-name>
```

### **2. Логи контроллеров:**
```bash
# В managed кластере логи controller-manager недоступны
# Но можно анализировать через события и метрики

kubectl get events --field-selector source=deployment-controller | tail -10
```

**Controller Manager — это мозг автоматизации, поддерживающий желаемое состояние кластера!**
