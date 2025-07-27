# 18. Как Kubernetes обрабатывает leader election?

## 🎯 **Что такое Leader Election?**

**Leader Election** — это механизм выбора единственного активного экземпляра из нескольких реплик компонента для предотвращения конфликтов и обеспечения консистентности.

## 🏗️ **Зачем нужен Leader Election:**

### **1. Предотвращение конфликтов**
- Только один экземпляр выполняет операции
- Избежание race conditions
- Консистентность данных

### **2. High Availability**
- Автоматический failover при сбоях
- Быстрое восстановление
- Непрерывность работы

### **3. Координация работы**
- Синхронизация между репликами
- Распределение задач
- Управление ресурсами

## 📊 **Практические примеры из вашего HA кластера:**

### **1. kube-controller-manager leader election:**
```bash
# В managed кластере несколько экземпляров controller-manager
# Только один активен в любой момент времени

# Проверить события leader election
kubectl get events -n kube-system | grep -i leader

# Lease объекты для leader election
kubectl get leases -n kube-system
kubectl describe lease kube-controller-manager -n kube-system
```

### **2. kube-scheduler leader election:**
```bash
# Scheduler также использует leader election
kubectl describe lease kube-scheduler -n kube-system

# Только один scheduler активно планирует Pod'ы
kubectl get events --field-selector source=default-scheduler | head -5
```

### **3. ArgoCD Application Controller:**
```bash
# ArgoCD использует leader election для Application Controller
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Проверить leader election в ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep -i leader

# ConfigMap для leader election
kubectl get configmaps -n argocd | grep leader
```

### **4. Prometheus Operator (если установлен):**
```bash
# Многие операторы используют leader election
kubectl get leases -A | grep -E "(operator|controller)"

# Проверить статус leader election
kubectl describe lease <lease-name> -n <namespace>
```

## 🔄 **Механизм Leader Election:**

### **1. Lease-based Leader Election:**
```
┌─────────────────────────────────────────────────────────────┐
│                  Leader Election Process                   │
├─────────────────────────────────────────────────────────────┤
│  1. Candidate Startup                                       │
│     ├── Instance starts up                                 │
│     ├── Attempts to acquire lease                          │
│     └── Becomes leader or follower                         │
├─────────────────────────────────────────────────────────────┤
│  2. Leader Operations                                       │
│     ├── Renews lease periodically                          │
│     ├── Performs active work                               │
│     └── Updates lease timestamp                            │
├─────────────────────────────────────────────────────────────┤
│  3. Follower Monitoring                                     │
│     ├── Watches lease object                               │
│     ├── Waits for lease expiration                         │
│     └── Ready to take over                                 │
├─────────────────────────────────────────────────────────────┤
│  4. Failover                                               │
│     ├── Leader fails to renew lease                        │
│     ├── Lease expires                                      │
│     ├── New leader elected                                 │
│     └── Work continues                                     │
└─────────────────────────────────────────────────────────────┘
```

### **2. Lease объект структура:**
```bash
# Посмотреть структуру Lease
kubectl get lease kube-controller-manager -n kube-system -o yaml

# Ключевые поля:
# spec.holderIdentity - кто держит lease
# spec.leaseDurationSeconds - длительность lease
# spec.renewTime - время последнего обновления
# spec.acquireTime - время получения lease
```

## 🔧 **Демонстрация Leader Election:**

### **1. Создание простого контроллера с leader election:**
```bash
# Создать Deployment с несколькими репликами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: leader-election-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: leader-demo
  template:
    metadata:
      labels:
        app: leader-demo
    spec:
      containers:
      - name: leader-elector
        image: k8s.gcr.io/leader-elector:0.5
        args:
        - --election=example
        - --http=0.0.0.0:4040
        ports:
        - containerPort: 4040
        env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
EOF

# Проверить какой Pod стал лидером
kubectl get pods -l app=leader-demo
kubectl logs -l app=leader-demo | grep -i leader

# Lease для демо
kubectl get lease example -o yaml

# Очистка
kubectl delete deployment leader-election-demo
kubectl delete lease example
```

### **2. Мониторинг leader election:**
```bash
# Отслеживать изменения в lease
kubectl get lease kube-controller-manager -n kube-system -w

# В другом терминале - посмотреть события
kubectl get events -n kube-system --field-selector involvedObject.name=kube-controller-manager -w
```

## 📈 **Мониторинг Leader Election:**

### **1. Метрики в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Leader election метрики:
# leader_election_master_status - статус лидера (1 = leader, 0 = follower)
# rest_client_requests_total{verb="UPDATE",resource="leases"} - обновления lease
# workqueue_depth - глубина очереди работ лидера
```

### **2. Grafana дашборды:**
```bash
kubectl port-forward svc/grafana -n monitoring 3000:80

# Дашборды показывают:
# - Leader election events
# - Lease renewal frequency
# - Failover times
# - Controller performance
```

### **3. События leader election:**
```bash
# События смены лидера
kubectl get events -A | grep -i "leader\|election"

# Подробности о lease объектах
kubectl describe leases -A | grep -A 10 -B 5 "Holder Identity"
```

## 🏭 **Leader Election в вашем HA кластере:**

### **1. Control Plane компоненты:**
```bash
# kube-controller-manager в HA режиме
kubectl describe lease kube-controller-manager -n kube-system

# kube-scheduler в HA режиме  
kubectl describe lease kube-scheduler -n kube-system

# Только один экземпляр каждого компонента активен
```

### **2. ArgoCD High Availability:**
```bash
# ArgoCD Application Controller использует leader election
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Проверить который Pod является лидером
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep "became leader\|lost leadership"

# ArgoCD Server может работать в active-active режиме
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

### **3. Мониторинг компоненты:**
```bash
# Prometheus может использовать leader election если несколько реплик
kubectl get statefulsets -n monitoring

# Grafana обычно работает в active-passive режиме
kubectl get deployments -n monitoring
```

## 🚨 **Проблемы Leader Election:**

### **1. Split-brain prevention:**
```bash
# Lease механизм предотвращает split-brain
# Только один holder может обновлять lease

# Проверить текущего holder
kubectl get lease -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,HOLDER:.spec.holderIdentity
```

### **2. Failover время:**
```bash
# Время failover зависит от leaseDurationSeconds
kubectl get lease kube-controller-manager -n kube-system -o jsonpath='{.spec.leaseDurationSeconds}'

# Обычно 15-30 секунд для быстрого failover
# Но достаточно долго чтобы избежать ложных срабатываний
```

### **3. Отладка проблем:**
```bash
# Проверить статус lease
kubectl describe lease <lease-name> -n <namespace>

# Проверить события
kubectl get events --field-selector involvedObject.name=<lease-name>

# Проверить логи контроллера
kubectl logs -n <namespace> -l <controller-selector> | grep -i "leader\|election"
```

## 🎯 **Конфигурация Leader Election:**

### **1. Параметры lease:**
```yaml
# Типичная конфигурация lease
spec:
  holderIdentity: "controller-manager-instance-1"
  leaseDurationSeconds: 15
  acquireTime: "2024-01-01T12:00:00Z"
  renewTime: "2024-01-01T12:00:10Z"
  leaseTransitions: 1
```

### **2. Настройки контроллера:**
```bash
# Параметры leader election для контроллеров:
# --leader-elect=true - включить leader election
# --leader-elect-lease-duration=15s - длительность lease
# --leader-elect-renew-deadline=10s - deadline для обновления
# --leader-elect-retry-period=2s - период повторных попыток
```

## 🔄 **Best Practices:**

### **1. Настройка времени:**
- leaseDurationSeconds: 15-30 секунд
- renewDeadline: 10-20 секунд  
- retryPeriod: 2-5 секунд
- Баланс между быстрым failover и стабильностью

### **2. Мониторинг:**
- Отслеживать смены лидера
- Мониторить время failover
- Алерты на частые смены лидера
- Проверять здоровье lease объектов

### **3. Отладка:**
- Анализировать логи контроллеров
- Проверять сетевую связность
- Мониторить производительность API Server
- Проверять ресурсы Node'ов

**Leader Election обеспечивает высокую доступность без конфликтов в распределенной системе!**
