# 29. Что такое Pod Disruption Budget (PDB)?

## 🎯 **Что такое Pod Disruption Budget?**

**Pod Disruption Budget (PDB)** — это ресурс Kubernetes, который ограничивает количество Pod'ов, которые могут быть одновременно недоступны во время voluntary disruptions (плановых нарушений). PDB обеспечивает высокую доступность приложений во время обновлений, масштабирования Node'ов и других плановых операций.

## 🏗️ **Типы Disruptions:**

### **1. Voluntary Disruptions (Плановые)**
- Обновления Deployment'ов
- Drain Node'ов для обслуживания
- Масштабирование кластера
- Обновления Node'ов

### **2. Involuntary Disruptions (Внеплановые)**
- Сбои оборудования
- Сетевые проблемы
- Kernel panic
- OOM kills

**PDB защищает только от voluntary disruptions!**

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка существующих PDB:**
```bash
# Проверить все PDB в кластере
kubectl get pdb -A

# PDB в ArgoCD namespace
kubectl get pdb -n argocd
kubectl describe pdb -n argocd

# PDB в monitoring namespace
kubectl get pdb -n monitoring
kubectl describe pdb -n monitoring

# Подробная информация о PDB
kubectl get pdb -A -o wide
```

### **2. Анализ ArgoCD availability:**
```bash
# Проверить количество реплик ArgoCD компонентов
kubectl get deployment -n argocd -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas,AVAILABLE:.status.availableReplicas

# Создать PDB для ArgoCD server
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-server-pdb
  namespace: argocd
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
EOF

# Проверить созданный PDB
kubectl describe pdb argocd-server-pdb -n argocd

kubectl delete pdb argocd-server-pdb -n argocd
```

### **3. Создание базового PDB:**
```bash
# Простой Deployment для демонстрации
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2  # Минимум 2 Pod'а должны быть доступны
  selector:
    matchLabels:
      app: web-app
EOF

# Проверить PDB статус
kubectl get pdb web-app-pdb
kubectl describe pdb web-app-pdb

kubectl delete deployment web-app-demo
kubectl delete pdb web-app-pdb
```

## 🔄 **Типы PDB конфигураций:**

### **1. minAvailable (минимум доступных):**
```bash
# PDB с minAvailable
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: min-available-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: min-available-app
  template:
    metadata:
      labels:
        app: min-available-app
    spec:
      containers:
      - name: app
        image: nginx
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: min-available-pdb
spec:
  minAvailable: 3  # Минимум 3 Pod'а всегда доступны
  selector:
    matchLabels:
      app: min-available-app
EOF

# Максимум 2 Pod'а могут быть evicted одновременно
kubectl get pdb min-available-pdb
kubectl describe pdb min-available-pdb

kubectl delete deployment min-available-demo
kubectl delete pdb min-available-pdb
```

### **2. maxUnavailable (максимум недоступных):**
```bash
# PDB с maxUnavailable
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: max-unavailable-demo
spec:
  replicas: 4
  selector:
    matchLabels:
      app: max-unavailable-app
  template:
    metadata:
      labels:
        app: max-unavailable-app
    spec:
      containers:
      - name: app
        image: nginx
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: max-unavailable-pdb
spec:
  maxUnavailable: 1  # Максимум 1 Pod может быть недоступен
  selector:
    matchLabels:
      app: max-unavailable-app
EOF

# Минимум 3 Pod'а всегда доступны
kubectl get pdb max-unavailable-pdb
kubectl describe pdb max-unavailable-pdb

kubectl delete deployment max-unavailable-demo
kubectl delete pdb max-unavailable-pdb
```

### **3. Процентные значения:**
```bash
# PDB с процентными значениями
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: percentage-demo
spec:
  replicas: 10
  selector:
    matchLabels:
      app: percentage-app
  template:
    metadata:
      labels:
        app: percentage-app
    spec:
      containers:
      - name: app
        image: nginx
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: percentage-pdb
spec:
  minAvailable: 70%  # Минимум 70% Pod'ов доступны
  selector:
    matchLabels:
      app: percentage-app
EOF

# При 10 репликах минимум 7 Pod'ов должны быть доступны
kubectl get pdb percentage-pdb
kubectl describe pdb percentage-pdb

kubectl delete deployment percentage-demo
kubectl delete pdb percentage-pdb
```

## 🔧 **PDB для разных workload типов:**

### **1. StatefulSet PDB:**
```bash
# StatefulSet с PDB
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-cluster
spec:
  serviceName: database-service
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: database
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "clusterdb"
        - name: POSTGRES_USER
          value: "clusteruser"
        - name: POSTGRES_PASSWORD
          value: "clusterpass"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-cluster-pdb
spec:
  maxUnavailable: 1  # Только 1 database Pod может быть недоступен
  selector:
    matchLabels:
      app: database
EOF

kubectl get statefulset database-cluster
kubectl get pdb database-cluster-pdb

kubectl delete statefulset database-cluster
kubectl delete pdb database-cluster-pdb
# Очистка PVC
kubectl delete pvc data-database-cluster-0 data-database-cluster-1 data-database-cluster-2
```

### **2. DaemonSet PDB:**
```bash
# DaemonSet с PDB (осторожно с DaemonSet PDB!)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: monitoring-agent
spec:
  selector:
    matchLabels:
      app: monitoring-agent
  template:
    metadata:
      labels:
        app: monitoring-agent
    spec:
      containers:
      - name: agent
        image: busybox
        command: ['sleep', '3600']
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: monitoring-agent-pdb
spec:
  maxUnavailable: 20%  # Максимум 20% Node'ов без агента
  selector:
    matchLabels:
      app: monitoring-agent
EOF

kubectl get daemonset monitoring-agent
kubectl get pdb monitoring-agent-pdb

kubectl delete daemonset monitoring-agent
kubectl delete pdb monitoring-agent-pdb
```

## 📈 **Мониторинг PDB:**

### **1. PDB статус и метрики:**
```bash
# Статус всех PDB
kubectl get pdb -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,MIN-AVAILABLE:.spec.minAvailable,MAX-UNAVAILABLE:.spec.maxUnavailable,ALLOWED-DISRUPTIONS:.status.disruptionsAllowed

# PDB с нулевыми allowed disruptions (проблемные)
kubectl get pdb -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.disruptionsAllowed}{"\n"}{end}' | grep -E "\t0$"

# Подробная информация о PDB статусе
kubectl describe pdb -A | grep -A 5 "Status:"
```

### **2. Метрики в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые метрики PDB:
# kube_poddisruptionbudget_status_current_healthy - текущие здоровые Pod'ы
# kube_poddisruptionbudget_status_desired_healthy - желаемые здоровые Pod'ы
# kube_poddisruptionbudget_status_disruptions_allowed - разрешенные disruptions
# kube_poddisruptionbudget_status_expected_pods - ожидаемые Pod'ы
```

### **3. Анализ PDB violations:**
```bash
# События связанные с PDB
kubectl get events -A --field-selector reason=DisruptionTarget
kubectl get events -A | grep -i "disruption"

# PDB блокирующие eviction
kubectl get events -A | grep -i "pdb.*blocked"

# Проверка Node drain операций
kubectl get events -A --field-selector reason=NodeDrain
```

## 🏭 **Production PDB стратегии:**

### **1. High Availability Web Service:**
```bash
# HA веб-сервис с правильным PDB
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-web-service
spec:
  replicas: 5
  selector:
    matchLabels:
      app: ha-web-service
  template:
    metadata:
      labels:
        app: ha-web-service
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - ha-web-service
              topologyKey: kubernetes.io/hostname
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ha-web-service-pdb
spec:
  minAvailable: 80%  # Минимум 80% Pod'ов доступны (4 из 5)
  selector:
    matchLabels:
      app: ha-web-service
---
apiVersion: v1
kind: Service
metadata:
  name: ha-web-service
spec:
  selector:
    app: ha-web-service
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

kubectl get deployment ha-web-service
kubectl get pdb ha-web-service-pdb
kubectl describe pdb ha-web-service-pdb

kubectl delete deployment ha-web-service
kubectl delete pdb ha-web-service-pdb
kubectl delete service ha-web-service
```

### **2. Database Cluster PDB:**
```bash
# Database cluster с строгим PDB
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-cluster
spec:
  serviceName: postgres-cluster
  replicas: 3
  selector:
    matchLabels:
      app: postgres-cluster
  template:
    metadata:
      labels:
        app: postgres-cluster
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "proddb"
        - name: POSTGRES_USER
          value: "produser"
        - name: POSTGRES_PASSWORD
          value: "prodpass"
        - name: POSTGRES_REPLICATION_MODE
          value: "master"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: postgres-cluster-pdb
spec:
  maxUnavailable: 1  # Только 1 database instance может быть недоступен
  selector:
    matchLabels:
      app: postgres-cluster
EOF

kubectl get statefulset postgres-cluster
kubectl get pdb postgres-cluster-pdb

kubectl delete statefulset postgres-cluster
kubectl delete pdb postgres-cluster-pdb
kubectl delete pvc data-postgres-cluster-0 data-postgres-cluster-1 data-postgres-cluster-2
```

### **3. Multi-tier Application PDB:**
```bash
# Multi-tier приложение с разными PDB стратегиями
cat << EOF | kubectl apply -f -
# Frontend - может терпеть больше disruptions
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 6
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: frontend
        image: nginx
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
spec:
  minAvailable: 50%  # Минимум 50% frontend Pod'ов
  selector:
    matchLabels:
      tier: frontend
---
# Backend - более строгие требования
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 4
  selector:
    matchLabels:
      tier: backend
  template:
    metadata:
      labels:
        tier: backend
    spec:
      containers:
      - name: backend
        image: nginx
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
spec:
  minAvailable: 75%  # Минимум 75% backend Pod'ов
  selector:
    matchLabels:
      tier: backend
EOF

kubectl get deployments
kubectl get pdb

kubectl delete deployment frontend backend
kubectl delete pdb frontend-pdb backend-pdb
```

## 🚨 **Тестирование PDB:**

### **1. Симуляция Node drain:**
```bash
# Создать тестовое приложение
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drain-test-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: drain-test
  template:
    metadata:
      labels:
        app: drain-test
    spec:
      containers:
      - name: app
        image: nginx
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: drain-test-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: drain-test
EOF

# Получить Node где запущены Pod'ы
kubectl get pods -l app=drain-test -o wide

# Попробовать drain Node (осторожно в production!)
# kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --dry-run=client

# PDB должен предотвратить одновременное удаление всех Pod'ов
kubectl describe pdb drain-test-pdb

kubectl delete deployment drain-test-app
kubectl delete pdb drain-test-pdb
```

### **2. Тестирование eviction API:**
```bash
# Создать Pod для тестирования eviction
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eviction-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: eviction-test
  template:
    metadata:
      labels:
        app: eviction-test
    spec:
      containers:
      - name: app
        image: nginx
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: eviction-test-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: eviction-test
EOF

# Попробовать evict Pod через API
POD_NAME=$(kubectl get pods -l app=eviction-test -o jsonpath='{.items[0].metadata.name}')

# Создать eviction request
cat << EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: Eviction
metadata:
  name: $POD_NAME
  namespace: default
EOF

# PDB должен разрешить eviction только если minAvailable соблюдается
kubectl get pods -l app=eviction-test

kubectl delete deployment eviction-test
kubectl delete pdb eviction-test-pdb
```

## 🎯 **Best Practices для PDB:**

### **1. Правильный выбор значений:**
- **minAvailable**: для критических сервисов (базы данных, API)
- **maxUnavailable**: для stateless приложений
- **Проценты**: для динамически масштабируемых приложений

### **2. Координация с Deployment стратегиями:**
```yaml
# Deployment strategy должна учитывать PDB
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Координируется с PDB
      maxSurge: 1
```

### **3. Anti-affinity и PDB:**
- Используйте Pod anti-affinity для распределения по Node'ам
- PDB защищает от voluntary disruptions
- Anti-affinity защищает от Node failures

### **4. Мониторинг и алерты:**
```bash
# Алерты на PDB проблемы
cat << EOF
groups:
- name: pdb-alerts
  rules:
  - alert: PDBViolation
    expr: kube_poddisruptionbudget_status_disruptions_allowed == 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PDB {{ \$labels.poddisruptionbudget }} has zero allowed disruptions"
      
  - alert: PDBUnhealthy
    expr: kube_poddisruptionbudget_status_current_healthy < kube_poddisruptionbudget_status_desired_healthy
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "PDB {{ \$labels.poddisruptionbudget }} is unhealthy"
EOF
```

**PDB обеспечивает высокую доступность приложений во время плановых операций обслуживания!**
