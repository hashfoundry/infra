# 1. Что такое Kubernetes и зачем он используется?

## 🎯 **Что такое Kubernetes?**

**Kubernetes (K8s)** — это платформа оркестрации контейнеров с открытым исходным кодом, которая автоматизирует развертывание, масштабирование и управление контейнеризованными приложениями.

## 🚀 **Зачем используется Kubernetes?**

### **Основные проблемы, которые решает K8s:**
1. **Автоматическое масштабирование** приложений
2. **Самовосстановление** (перезапуск упавших контейнеров)
3. **Балансировка нагрузки** между репликами
4. **Управление конфигурацией** и секретами
5. **Оркестрация хранилища** (persistent volumes)
6. **Канареечные и rolling deployments**

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверить основную информацию о кластере:**
```bash
# Версия Kubernetes
kubectl version

# Информация о кластере
kubectl cluster-info

# Количество и состояние нод
kubectl get nodes
```

### **2. Увидеть автоматическое масштабирование в действии:**
```bash
# Проверить текущие ноды (должно быть 3-9 нод с автоскейлингом)
kubectl get nodes -o wide

# Посмотреть на ArgoCD HA - несколько реплик для отказоустойчивости
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### **3. Самовосстановление (Self-healing):**
```bash
# Посмотреть на ReplicaSets - они обеспечивают нужное количество реплик
kubectl get replicasets -n argocd

# Если удалить под, K8s автоматически создаст новый
kubectl get pods -n argocd --watch
```

### **4. Управление конфигурацией:**
```bash
# ConfigMaps для конфигурации приложений
kubectl get configmaps -n argocd

# Secrets для паролей и сертификатов
kubectl get secrets -n argocd
```

### **5. Оркестрация хранилища:**
```bash
# Persistent Volumes - постоянное хранилище
kubectl get pv

# Persistent Volume Claims - запросы на хранилище
kubectl get pvc -A

# Storage Classes - типы хранилища (NFS, Block Storage)
kubectl get storageclass
```

### **6. Сервисы и балансировка нагрузки:**
```bash
# Services - внутренняя балансировка нагрузки
kubectl get svc -n argocd

# Ingress - внешний доступ через Load Balancer
kubectl get ingress -A
```

### **7. Мониторинг состояния приложений:**
```bash
# Deployments - декларативное управление приложениями
kubectl get deployments -A

# Статус всех ресурсов
kubectl get all -n argocd
```

## 🏗️ **Архитектурные преимущества в вашем кластере:**

**Ваш HA кластер демонстрирует все ключевые возможности Kubernetes:**

- **Высокая доступность**: ArgoCD работает в 3 репликах
- **Автомасштабирование**: Ноды масштабируются от 3 до 9
- **Мониторинг**: Prometheus собирает метрики со всех компонентов
- **GitOps**: ArgoCD автоматически синхронизирует приложения из Git
- **Персистентное хранилище**: NFS для shared storage, Block Storage для баз данных

**Kubernetes превращает ваш кластер в самоуправляемую, отказоустойчивую платформу для запуска enterprise-приложений.**
