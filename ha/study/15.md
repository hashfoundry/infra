# 15. Что делает kube-proxy?

## 🎯 **Что такое kube-proxy?**

**kube-proxy** — это сетевой компонент, который работает на каждой Node и отвечает за реализацию сетевых правил для Service'ов. Он обеспечивает сетевую связность и load balancing для Pod'ов.

## 🏗️ **Основные функции kube-proxy:**

### **1. Service Discovery**
- Отслеживает Service'ы и Endpoints
- Обновляет сетевые правила при изменениях
- Обеспечивает доступность Service'ов

### **2. Load Balancing**
- Распределяет трафик между Pod'ами
- Поддерживает различные алгоритмы балансировки
- Обрабатывает session affinity

### **3. Network Proxy**
- Перенаправляет трафик к правильным Pod'ам
- Реализует ClusterIP, NodePort, LoadBalancer
- Обрабатывает внешний трафик

## 📊 **Практические примеры из вашего HA кластера:**

### **1. kube-proxy на Node'ах:**
```bash
# kube-proxy работает как DaemonSet на всех Node'ах
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# kube-proxy на каждой Node
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# Конфигурация kube-proxy
kubectl describe configmap kube-proxy -n kube-system
```

### **2. Service'ы и kube-proxy:**
```bash
# ArgoCD Service
kubectl get svc argocd-server -n argocd

# kube-proxy создает правила для этого Service
kubectl describe svc argocd-server -n argocd

# Endpoints, которые отслеживает kube-proxy
kubectl get endpoints argocd-server -n argocd
```

### **3. ClusterIP в действии:**
```bash
# ClusterIP Service доступен изнутри кластера
kubectl get svc -n monitoring

# kube-proxy обеспечивает доступ к Prometheus
kubectl run test-curl --image=curlimages/curl -it --rm -- \
  curl http://prometheus-server.monitoring.svc.cluster.local

# kube-proxy перенаправляет запрос к Pod'у Prometheus
```

### **4. NodePort Service:**
```bash
# Если есть NodePort Service'ы
kubectl get svc --all-namespaces | grep NodePort

# kube-proxy открывает порт на всех Node'ах
# Трафик на NodePort перенаправляется к Pod'ам
```

### **5. Load Balancer Service:**
```bash
# NGINX Ingress Controller как LoadBalancer
kubectl get svc -n ingress-nginx

# kube-proxy работает с внешним Load Balancer
kubectl describe svc ingress-nginx-controller -n ingress-nginx
```

## 🔄 **Режимы работы kube-proxy:**

### **1. iptables mode (по умолчанию):**
```bash
# kube-proxy создает iptables правила
# Высокая производительность
# Случайная балансировка нагрузки

# Посмотреть режим kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep "Using"
```

### **2. IPVS mode:**
```bash
# Более продвинутый режим
# Лучшая производительность для больших кластеров
# Больше алгоритмов балансировки

# Проверить поддержку IPVS
kubectl get configmap kube-proxy -n kube-system -o yaml | grep mode
```

### **3. userspace mode (устаревший):**
```bash
# Старый режим, не рекомендуется
# Низкая производительность
# Используется только для совместимости
```

## 🔧 **Демонстрация работы kube-proxy:**

### **1. Создание Service и тестирование:**
```bash
# Создать Deployment
kubectl create deployment test-app --image=nginx --replicas=3

# Создать Service
kubectl expose deployment test-app --port=80 --target-port=80

# Получить ClusterIP
kubectl get svc test-app

# Тестировать доступ (kube-proxy обрабатывает запросы)
kubectl run test-client --image=curlimages/curl -it --rm -- \
  curl http://test-app.default.svc.cluster.local

# kube-proxy распределяет запросы между 3 Pod'ами
kubectl get pods -l app=test-app -o wide

# Очистка
kubectl delete deployment test-app
kubectl delete svc test-app
```

### **2. Session Affinity:**
```bash
# Service с session affinity
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: sticky-service
spec:
  selector:
    app: test-sticky
  ports:
  - port: 80
    targetPort: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
EOF

# kube-proxy будет направлять запросы от одного IP к одному Pod'у
kubectl describe svc sticky-service

# Очистка
kubectl delete svc sticky-service
```

## 📈 **Мониторинг kube-proxy:**

### **1. kube-proxy метрики:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# kube-proxy метрики:
# kubeproxy_sync_proxy_rules_duration_seconds - время синхронизации правил
# kubeproxy_network_programming_duration_seconds - время программирования сети
# rest_client_requests_total - запросы к API Server
```

### **2. kube-proxy логи:**
```bash
# Логи kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Фильтровать по конкретной Node
kubectl logs -n kube-system -l k8s-app=kube-proxy --field-selector spec.nodeName=<node-name>
```

### **3. Сетевые правила:**
```bash
# В managed кластере прямой доступ к Node ограничен
# Но можно посмотреть через debug Pod

kubectl run debug-pod --image=nicolaka/netshoot -it --rm -- iptables -t nat -L | grep KUBE
```

## 🏭 **kube-proxy в вашем HA кластере:**

### **1. High Availability:**
```bash
# kube-proxy работает на всех Node'ах
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# Если одна Node недоступна, другие продолжают работать
# Service'ы остаются доступными через другие Node'ы
```

### **2. ArgoCD и kube-proxy:**
```bash
# ArgoCD Server Service
kubectl get svc argocd-server -n argocd

# kube-proxy обеспечивает load balancing между ArgoCD Server Pod'ами
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide

# Внутренний доступ к ArgoCD
kubectl run test-argocd --image=curlimages/curl -it --rm -- \
  curl -k https://argocd-server.argocd.svc.cluster.local
```

### **3. Мониторинг и kube-proxy:**
```bash
# Prometheus Service
kubectl get svc prometheus-server -n monitoring

# kube-proxy обеспечивает доступ к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Grafana Service
kubectl get svc grafana -n monitoring

# kube-proxy обеспечивает доступ к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80
```

## 🔄 **Типы Service'ов и kube-proxy:**

### **1. ClusterIP:**
```bash
# Внутренний IP кластера
kubectl get svc -n argocd | grep ClusterIP

# kube-proxy создает правила для внутреннего доступа
# Доступен только изнутри кластера
```

### **2. NodePort:**
```bash
# Порт на всех Node'ах
kubectl get svc --all-namespaces | grep NodePort

# kube-proxy открывает порт на каждой Node
# Доступен извне через <NodeIP>:<NodePort>
```

### **3. LoadBalancer:**
```bash
# Внешний Load Balancer
kubectl get svc -n ingress-nginx | grep LoadBalancer

# kube-proxy работает с внешним LB
# Digital Ocean предоставляет Load Balancer
```

### **4. ExternalName:**
```bash
# DNS CNAME запись
# kube-proxy не создает правила
# Просто DNS разрешение
```

## 🚨 **Проблемы kube-proxy:**

### **1. Service недоступен:**
```bash
# Проверить Service и Endpoints
kubectl get svc <service-name>
kubectl get endpoints <service-name>

# Проверить kube-proxy логи
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep ERROR

# Проверить Pod'ы kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

### **2. Неправильная балансировка:**
```bash
# Проверить алгоритм балансировки
kubectl describe svc <service-name>

# Проверить session affinity
kubectl get svc <service-name> -o yaml | grep sessionAffinity

# Проверить readiness probes Pod'ов
kubectl describe pods -l <service-selector>
```

## 🎯 **Архитектура kube-proxy:**

```
┌─────────────────────────────────────────────────────────────┐
│                    kube-proxy                               │
├─────────────────────────────────────────────────────────────┤
│  Service Watcher                                            │
│  ├── Watch Services from API Server                        │
│  ├── Watch Endpoints from API Server                       │
│  └── Detect changes in real-time                           │
├─────────────────────────────────────────────────────────────┤
│  Proxy Mode                                                 │
│  ├── iptables mode (default)                               │
│  │   ├── Create iptables rules                             │
│  │   ├── DNAT for ClusterIP                               │
│  │   └── Random load balancing                             │
│  ├── IPVS mode                                             │
│  │   ├── Create IPVS rules                                 │
│  │   ├── Multiple LB algorithms                            │
│  │   └── Better performance                                │
│  └── userspace mode (deprecated)                           │
├─────────────────────────────────────────────────────────────┤
│  Network Programming                                        │
│  ├── ClusterIP implementation                              │
│  ├── NodePort implementation                               │
│  ├── LoadBalancer integration                              │
│  └── Session affinity handling                             │
├─────────────────────────────────────────────────────────────┤
│  Health Checking                                            │
│  ├── Monitor backend Pod health                            │
│  ├── Remove unhealthy endpoints                            │
│  └── Update proxy rules                                    │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Конфигурация kube-proxy:**

### **1. ConfigMap:**
```bash
# Конфигурация kube-proxy
kubectl get configmap kube-proxy -n kube-system -o yaml

# Основные параметры:
# - mode: iptables/ipvs/userspace
# - clusterCIDR: диапазон IP Pod'ов
# - bindAddress: адрес для привязки
```

### **2. Настройки производительности:**
```bash
# iptables mode настройки
# - masqueradeAll: маскировать весь трафик
# - syncPeriod: период синхронизации правил

# IPVS mode настройки
# - scheduler: алгоритм балансировки (rr, lc, sh)
# - strictARP: строгий ARP режим
```

## 🎯 **Best Practices для kube-proxy:**

### **1. Мониторинг:**
- Следите за метриками kube-proxy
- Мониторьте время синхронизации правил
- Проверяйте доступность Service'ов

### **2. Производительность:**
- Используйте IPVS для больших кластеров
- Оптимизируйте количество Service'ов
- Мониторьте сетевую нагрузку

### **3. Отладка:**
- Проверяйте Endpoints при проблемах
- Анализируйте логи kube-proxy
- Тестируйте сетевую связность

**kube-proxy — это сетевой мост, обеспечивающий доступность Service'ов в кластере!**
