# 151. Какие ключевые метрики производительности для Kubernetes?

## 🎯 **Что такое метрики производительности Kubernetes?**

**Метрики производительности Kubernetes** — это количественные показатели, которые позволяют оценить эффективность работы кластера, узлов, подов и приложений. Они критически важны для обеспечения стабильности и оптимизации ресурсов.

## 🏗️ **Основные категории метрик:**

### **1. Cluster Level (Уровень кластера)**
- API Server производительность
- etcd производительность
- Scheduler эффективность
- Общее состояние кластера

### **2. Node Level (Уровень узлов)**
- CPU, Memory, Disk, Network утилизация
- Системные метрики узлов
- Kubelet производительность

### **3. Pod Level (Уровень подов)**
- Ресурсы контейнеров
- Жизненный цикл подов
- Сетевые метрики

### **4. Application Level (Уровень приложений)**
- Golden Signals (Latency, Traffic, Errors, Saturation)
- Бизнес-метрики приложений

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка метрик кластера:**
```bash
# Общее состояние кластера
kubectl get componentstatuses

# Производительность API Server
kubectl get --raw /metrics | grep apiserver_request_duration_seconds

# Статус узлов
kubectl top nodes

# Топ подов по ресурсам
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory
```

### **2. Мониторинг ArgoCD производительности:**
```bash
# Метрики ArgoCD Server
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide

# Ресурсы ArgoCD подов
kubectl top pods -n argocd

# Логи производительности ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server | grep -i "duration\|latency"

# Проверка готовности ArgoCD
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount
```

### **3. Мониторинг Prometheus и Grafana:**
```bash
# Метрики Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &
curl http://localhost:9090/metrics | grep prometheus_

# Ресурсы мониторинга
kubectl top pods -n monitoring

# Статус хранилища Prometheus
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-server -n monitoring
```

### **4. Сетевые метрики NGINX Ingress:**
```bash
# NGINX Ingress метрики
kubectl get svc -n ingress-nginx

# Производительность Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep -E "upstream_response_time|request_time"

# Статус Load Balancer
kubectl describe svc ingress-nginx-controller -n ingress-nginx
```

### **5. NFS Provisioner метрики:**
```bash
# NFS Provisioner производительность
kubectl get pods -n nfs-provisioner

# Метрики NFS хранилища
kubectl top pods -n nfs-provisioner

# Статус PV созданных NFS
kubectl get pv | grep nfs
kubectl describe pv <nfs-pv-name>
```

## 🔄 **Golden Signals в действии:**

### **1. Latency (Задержка):**
```bash
# API Server latency
kubectl get --raw /metrics | grep apiserver_request_duration_seconds_bucket

# ArgoCD response time
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
time curl -k https://localhost:8080/api/version

# Grafana response time
kubectl port-forward svc/grafana -n monitoring 3000:80 &
time curl http://localhost:3000/api/health
```

### **2. Traffic (Трафик):**
```bash
# API Server requests per second
kubectl get --raw /metrics | grep apiserver_request_total

# Ingress requests
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep -c "GET\|POST"

# Pod network traffic
kubectl top pods --all-namespaces --containers | grep -E "nginx|argocd|prometheus"
```

### **3. Errors (Ошибки):**
```bash
# API Server errors
kubectl get --raw /metrics | grep apiserver_request_total | grep -E "5[0-9][0-9]"

# Pod restart count (индикатор проблем)
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,RESTARTS:.status.containerStatuses[*].restartCount | grep -v "0"

# Events с ошибками
kubectl get events --all-namespaces --field-selector type=Warning
```

### **4. Saturation (Насыщенность):**
```bash
# CPU saturation
kubectl top nodes | awk 'NR>1 {print $1, $3}' | while read node cpu; do echo "$node: $cpu"; done

# Memory saturation
kubectl top nodes | awk 'NR>1 {print $1, $5}' | while read node mem; do echo "$node: $mem"; done

# Disk saturation (через describe nodes)
kubectl describe nodes | grep -A 5 "Allocated resources"
```

## 📈 **Демонстрация сбора метрик:**

### **1. Создание тестового приложения с метриками:**
```bash
# Создать тестовое приложение
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-demo
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: metrics-demo
  template:
    metadata:
      labels:
        app: metrics-demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: metrics-demo-svc
  namespace: default
spec:
  selector:
    app: metrics-demo
  ports:
  - port: 80
    targetPort: 80
EOF

# Мониторинг созданного приложения
kubectl top pods -l app=metrics-demo
kubectl get pods -l app=metrics-demo -o custom-columns=NAME:.metadata.name,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory

# Очистка
kubectl delete deployment metrics-demo
kubectl delete svc metrics-demo-svc
```

### **2. Нагрузочное тестирование:**
```bash
# Создать нагрузку на ArgoCD
kubectl run load-test --image=busybox -it --rm -- /bin/sh -c "
while true; do
  wget -q -O- http://argocd-server.argocd.svc.cluster.local/api/version
  sleep 1
done"

# Мониторинг во время нагрузки
kubectl top pods -n argocd
kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
```

## 🔧 **Настройка мониторинга в вашем кластере:**

### **1. Prometheus метрики:**
```bash
# Доступ к Prometheus UI
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Ключевые PromQL запросы:
# CPU утилизация кластера:
# 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory утилизация:
# (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod count по namespace:
# count by (namespace) (kube_pod_info)

# API Server latency:
# histogram_quantile(0.99, rate(apiserver_request_duration_seconds_bucket[5m]))
```

### **2. Grafana дашборды:**
```bash
# Доступ к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Импорт готовых дашбордов:
# - Kubernetes Cluster Monitoring (ID: 7249)
# - Node Exporter Full (ID: 1860)
# - Kubernetes Pod Monitoring (ID: 6417)
# - NGINX Ingress Controller (ID: 9614)
```

### **3. Алерты для критических метрик:**
```bash
# Проверка настроенных алертов
kubectl get prometheusrules -n monitoring

# Статус алертов в Prometheus
# Открыть http://localhost:9090/alerts после port-forward
```

## 📊 **Архитектура мониторинга метрик:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Metrics Collection                      │
├─────────────────────────────────────────────────────────────┤
│  Application Level                                          │
│  ├── Custom App Metrics (/metrics endpoint)                │
│  ├── Golden Signals (Latency, Traffic, Errors, Saturation) │
│  └── Business Metrics                                       │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes Level                                           │
│  ├── kube-state-metrics (Pod, Service, Deployment status)  │
│  ├── kubelet metrics (Container resources)                 │
│  └── API Server metrics (Request latency, throughput)      │
├─────────────────────────────────────────────────────────────┤
│  Node Level                                                 │
│  ├── node-exporter (CPU, Memory, Disk, Network)           │
│  ├── cAdvisor (Container metrics)                          │
│  └── System metrics (Load, I/O, Processes)                 │
├─────────────────────────────────────────────────────────────┤
│  Storage & Processing                                       │
│  ├── Prometheus (Metrics storage & querying)               │
│  ├── Grafana (Visualization & dashboards)                  │
│  └── AlertManager (Alert routing & notifications)          │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Скрипт комплексной проверки производительности:**

### **1. Создание скрипта мониторинга:**
```bash
# Создать скрипт performance-check.sh
cat << 'EOF' > performance-check.sh
#!/bin/bash

echo "🔍 Комплексная проверка производительности HA кластера"
echo "=================================================="

echo -e "\n📊 1. СОСТОЯНИЕ КЛАСТЕРА:"
kubectl get componentstatuses
kubectl get nodes -o wide

echo -e "\n📊 2. РЕСУРСЫ УЗЛОВ:"
kubectl top nodes

echo -e "\n📊 3. ТОП ПОДОВ ПО CPU:"
kubectl top pods --all-namespaces --sort-by=cpu | head -10

echo -e "\n📊 4. ТОП ПОДОВ ПО ПАМЯТИ:"
kubectl top pods --all-namespaces --sort-by=memory | head -10

echo -e "\n📊 5. ARGOCD ПРОИЗВОДИТЕЛЬНОСТЬ:"
kubectl get pods -n argocd -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,CPU:.spec.containers[*].resources.requests.cpu,MEMORY:.spec.containers[*].resources.requests.memory

echo -e "\n📊 6. МОНИТОРИНГ СТЕК:"
kubectl top pods -n monitoring

echo -e "\n📊 7. INGRESS ПРОИЗВОДИТЕЛЬНОСТЬ:"
kubectl get pods -n ingress-nginx -o wide
kubectl get svc -n ingress-nginx

echo -e "\n📊 8. ХРАНИЛИЩЕ:"
kubectl get pvc --all-namespaces
kubectl get pv

echo -e "\n⚠️  9. ПРОБЛЕМНЫЕ ПОДЫ:"
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

echo -e "\n⚠️  10. СОБЫТИЯ С ПРЕДУПРЕЖДЕНИЯМИ:"
kubectl get events --all-namespaces --field-selector type=Warning | tail -5

echo -e "\n📈 11. API SERVER МЕТРИКИ:"
kubectl get --raw /metrics | grep -E "apiserver_request_duration_seconds_sum|apiserver_request_total" | head -5

echo -e "\n✅ Проверка завершена!"
echo "💡 Для детального анализа используйте:"
echo "   - Prometheus: kubectl port-forward svc/prometheus-server -n monitoring 9090:80"
echo "   - Grafana: kubectl port-forward svc/grafana -n monitoring 3000:80"
EOF

chmod +x performance-check.sh
```

### **2. Запуск проверки:**
```bash
# Выполнить комплексную проверку
./performance-check.sh

# Сохранить результат в файл
./performance-check.sh > performance-report-$(date +%Y%m%d-%H%M%S).txt
```

## 🚨 **Критические метрики для алертов:**

### **1. Кластерные алерты:**
```bash
# API Server недоступен
kubectl get componentstatuses | grep -v Healthy

# Высокая задержка API Server (>1s)
kubectl get --raw /metrics | grep apiserver_request_duration_seconds_bucket

# etcd проблемы
kubectl logs -n kube-system -l component=etcd | grep -i error
```

### **2. Узловые алерты:**
```bash
# CPU > 80%
kubectl top nodes | awk 'NR>1 && $3+0 > 80 {print $1 ": " $3}'

# Memory > 85%
kubectl top nodes | awk 'NR>1 && $5+0 > 85 {print $1 ": " $5}'

# Disk space критичен
kubectl describe nodes | grep -A 10 "Conditions:" | grep -E "DiskPressure|MemoryPressure"
```

### **3. Подовые алерты:**
```bash
# Поды с частыми перезапусками
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,RESTARTS:.status.containerStatuses[*].restartCount | awk '$3+0 > 5'

# Поды в состоянии Pending
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# OOMKilled контейнеры
kubectl get events --all-namespaces --field-selector reason=OOMKilling
```

## 🏭 **Производительность в вашем HA кластере:**

### **1. ArgoCD HA метрики:**
```bash
# Балансировка между ArgoCD серверами
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide

# Производительность ArgoCD Application Controller
kubectl top pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Синхронизация приложений
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

### **2. Мониторинг HA:**
```bash
# Prometheus HA (если настроен)
kubectl get pods -n monitoring -l app=prometheus

# Grafana доступность
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# NFS Provisioner производительность
kubectl top pods -n nfs-provisioner
```

### **3. Load Balancer метрики:**
```bash
# DigitalOcean Load Balancer статус
kubectl describe svc ingress-nginx-controller -n ingress-nginx

# Распределение трафика
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep -E "upstream_addr|upstream_response_time" | tail -10
```

## 🎯 **Best Practices для метрик производительности:**

### **1. Мониторинг:**
- Отслеживайте Golden Signals на всех уровнях
- Настройте алерты для критических метрик
- Используйте SLI/SLO для определения целей
- Создайте дашборды для разных ролей

### **2. Оптимизация:**
- Регулярно анализируйте тренды производительности
- Оптимизируйте resource requests/limits
- Мониторьте автомасштабирование
- Анализируйте bottlenecks

### **3. Автоматизация:**
- Автоматизируйте сбор метрик
- Настройте автоматические алерты
- Используйте GitOps для конфигурации мониторинга
- Интегрируйте с CI/CD пайплайнами

**Эффективный мониторинг метрик производительности — основа стабильной работы Kubernetes кластера!**
