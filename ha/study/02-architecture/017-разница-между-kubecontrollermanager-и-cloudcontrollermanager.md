# 17. Разница между kube-controller-manager и cloud-controller-manager

## 🎯 **Основные различия:**

### **kube-controller-manager**
- Встроенные контроллеры Kubernetes
- Управляет базовыми ресурсами кластера
- Не зависит от cloud provider
- Работает в любой среде

### **cloud-controller-manager**
- Cloud-специфичные контроллеры
- Интеграция с cloud provider API
- Управляет cloud ресурсами
- Специфичен для каждого провайдера

## 📊 **Практические примеры из вашего HA кластера Digital Ocean:**

### **1. kube-controller-manager контроллеры:**
```bash
# Deployment Controller (встроенный)
kubectl get deployments -n argocd

# ReplicaSet Controller (встроенный)
kubectl get replicasets -n argocd

# Service Controller (базовая функциональность)
kubectl get services -n argocd

# Namespace Controller (встроенный)
kubectl get namespaces
```

### **2. cloud-controller-manager (Digital Ocean):**
```bash
# LoadBalancer Service - управляется cloud-controller-manager
kubectl get svc -n ingress-nginx | grep LoadBalancer

# Digital Ocean создает Load Balancer через cloud-controller-manager
kubectl describe svc ingress-nginx-controller -n ingress-nginx

# Node management - cloud-controller-manager управляет Node'ами
kubectl get nodes -o wide

# PersistentVolumes - интеграция с DO Block Storage
kubectl get pv
```

## 🔄 **Разделение ответственности:**

### **kube-controller-manager:**
```
┌─────────────────────────────────────────────────────────────┐
│              kube-controller-manager                        │
├─────────────────────────────────────────────────────────────┤
│  Core Controllers:                                          │
│  ├── Deployment Controller                                  │
│  ├── ReplicaSet Controller                                  │
│  ├── DaemonSet Controller                                   │
│  ├── Job Controller                                         │
│  ├── CronJob Controller                                     │
│  ├── StatefulSet Controller                                 │
│  ├── Namespace Controller                                   │
│  ├── ServiceAccount Controller                              │
│  ├── Endpoint Controller                                    │
│  ├── ResourceQuota Controller                               │
│  ├── PersistentVolume Controller                            │
│  └── Certificate Controller                                 │
└─────────────────────────────────────────────────────────────┘
```

### **cloud-controller-manager:**
```
┌─────────────────────────────────────────────────────────────┐
│            cloud-controller-manager                         │
├─────────────────────────────────────────────────────────────┤
│  Cloud-Specific Controllers:                                │
│  ├── Node Controller                                        │
│  │   ├── Node lifecycle management                         │
│  │   ├── Node labeling (zones, instance types)             │
│  │   └── Node deletion handling                            │
│  ├── Route Controller                                       │
│  │   ├── Pod network routes                                │
│  │   └── Cross-node communication                          │
│  ├── Service Controller                                     │
│  │   ├── LoadBalancer provisioning                         │
│  │   ├── External IP assignment                            │
│  │   └── Cloud LB integration                              │
│  └── Volume Controller                                      │
│      ├── PV provisioning                                   │
│      ├── Volume attachment/detachment                      │
│      └── Storage class integration                         │
└─────────────────────────────────────────────────────────────┘
```

## 🏭 **В вашем Digital Ocean кластере:**

### **1. Node Controller (cloud-controller-manager):**
```bash
# Node'ы управляются Digital Ocean cloud-controller-manager
kubectl describe nodes | grep -A 5 "Labels:"

# Cloud-specific labels добавляются автоматически:
# topology.kubernetes.io/region=fra1
# topology.kubernetes.io/zone=fra1
# node.kubernetes.io/instance-type=s-2vcpu-4gb
```

### **2. Service Controller (cloud-controller-manager):**
```bash
# LoadBalancer Service создает DO Load Balancer
kubectl get svc -n ingress-nginx -o wide

# External IP предоставляется Digital Ocean
kubectl describe svc ingress-nginx-controller -n ingress-nginx | grep "LoadBalancer Ingress"

# Digital Ocean Load Balancer интегрируется с кластером
```

### **3. Volume Controller (cloud-controller-manager):**
```bash
# StorageClass для Digital Ocean Block Storage
kubectl get storageclass

# PersistentVolumes создаются через DO API
kubectl get pv

# Volume attachment управляется cloud-controller-manager
kubectl describe pv <pv-name> | grep "Source:"
```

## 🔧 **Демонстрация различий:**

### **1. Создание LoadBalancer Service:**
```bash
# Создать LoadBalancer Service
kubectl create deployment test-lb --image=nginx
kubectl expose deployment test-lb --type=LoadBalancer --port=80

# kube-controller-manager: создает Service объект
kubectl get svc test-lb

# cloud-controller-manager: создает DO Load Balancer
kubectl describe svc test-lb | grep "LoadBalancer Ingress"

# Очистка
kubectl delete deployment test-lb
kubectl delete svc test-lb
```

### **2. Node lifecycle:**
```bash
# kube-controller-manager: базовое управление Node'ами
kubectl get nodes

# cloud-controller-manager: cloud-specific управление
kubectl describe nodes | grep -E "(ProviderID|Labels|Taints)"

# Digital Ocean provider ID
kubectl get nodes -o yaml | grep providerID
```

## 📈 **Мониторинг обоих компонентов:**

### **1. Метрики в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# kube-controller-manager метрики:
# workqueue_depth{name="deployment"}
# controller_runtime_reconcile_total{controller="deployment"}

# cloud-controller-manager метрики:
# cloudprovider_*_api_request_duration_seconds
# service_controller_loadbalancer_sync_total
```

### **2. События от контроллеров:**
```bash
# События от kube-controller-manager
kubectl get events --field-selector source=deployment-controller
kubectl get events --field-selector source=replicaset-controller

# События от cloud-controller-manager
kubectl get events --field-selector source=service-controller
kubectl get events --field-selector source=node-controller
```

## 🎯 **Ключевые отличия:**

### **1. Область ответственности:**
- **kube-controller-manager**: Kubernetes-native ресурсы
- **cloud-controller-manager**: Cloud provider интеграция

### **2. Зависимости:**
- **kube-controller-manager**: Только Kubernetes API
- **cloud-controller-manager**: Cloud provider API

### **3. Развертывание:**
- **kube-controller-manager**: Часть базового Kubernetes
- **cloud-controller-manager**: Специфичен для провайдера

### **4. Конфигурация:**
```bash
# kube-controller-manager - стандартная конфигурация
# cloud-controller-manager - требует cloud credentials

# В managed кластере Digital Ocean это скрыто от пользователя
kubectl cluster-info
```

## 🚨 **Проблемы и отладка:**

### **1. LoadBalancer не создается:**
```bash
# Проверить Service
kubectl describe svc <service-name>

# Проверить события cloud-controller-manager
kubectl get events --field-selector source=service-controller

# Возможные причины:
# - Проблемы с cloud provider API
# - Недостаточно прав у cloud-controller-manager
# - Лимиты cloud provider
```

### **2. Node не готова:**
```bash
# Проверить Node статус
kubectl describe node <node-name>

# cloud-controller-manager может не инициализировать Node
kubectl get events --field-selector source=node-controller
```

## 🏗️ **Архитектура в Digital Ocean:**

```
┌─────────────────────────────────────────────────────────────┐
│                Digital Ocean Cloud                         │
├─────────────────────────────────────────────────────────────┤
│  cloud-controller-manager                                   │
│  ├── Integrates with DO API                                │
│  ├── Manages DO Load Balancers                             │
│  ├── Manages DO Block Storage                              │
│  └── Manages DO Droplets (Nodes)                           │
├─────────────────────────────────────────────────────────────┤
│  kube-controller-manager                                    │
│  ├── Core Kubernetes Controllers                           │
│  ├── Application Lifecycle                                 │
│  ├── Resource Management                                    │
│  └── Cluster State Management                              │
├─────────────────────────────────────────────────────────────┤
│  Managed Kubernetes Control Plane                          │
│  ├── API Server                                            │
│  ├── etcd                                                  │
│  ├── Scheduler                                             │
│  └── Both Controller Managers                              │
└─────────────────────────────────────────────────────────────┘
```

**Разделение позволяет Kubernetes быть cloud-agnostic, а cloud-controller-manager обеспечивает глубокую интеграцию с провайдером!**
