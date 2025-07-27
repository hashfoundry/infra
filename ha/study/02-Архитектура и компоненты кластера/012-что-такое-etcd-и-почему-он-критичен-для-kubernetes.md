# 12. Что такое etcd и почему он критичен для Kubernetes?

## 🎯 **Что такое etcd?**

**etcd** — это распределенная база данных ключ-значение, которая служит единственным источником истины для всего состояния Kubernetes кластера. Это высокодоступное хранилище, использующее алгоритм консенсуса Raft.

## 🏗️ **Почему etcd критичен для Kubernetes:**

### **1. Единственный источник истины**
- Хранит ВСЕ данные кластера
- Конфигурация всех объектов
- Состояние всех ресурсов
- Метаданные и спецификации

### **2. Консистентность данных**
- ACID транзакции
- Strong consistency
- Алгоритм консенсуса Raft
- Защита от split-brain

### **3. High Availability**
- Кластерная архитектура (обычно 3-5 нод)
- Автоматический failover
- Репликация данных
- Устойчивость к сбоям

## 📊 **Что хранится в etcd:**

### **1. Все Kubernetes объекты:**
```bash
# Все Pod'ы кластера
kubectl get pods -A

# Все Deployments
kubectl get deployments -A

# Все Services
kubectl get services -A

# Все ConfigMaps и Secrets
kubectl get configmaps,secrets -A

# Все эти данные хранятся в etcd
```

### **2. Конфигурация кластера:**
```bash
# Информация о Node'ах
kubectl get nodes

# Namespace'ы
kubectl get namespaces

# RBAC конфигурация
kubectl get roles,rolebindings -A
kubectl get clusterroles,clusterrolebindings

# Custom Resource Definitions
kubectl get crd
```

### **3. Состояние приложений:**
```bash
# ArgoCD Applications (хранятся в etcd)
kubectl get applications -n argocd

# ReplicaSets и их состояние
kubectl get replicasets -A

# Events (временно хранятся в etcd)
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

## 🔄 **Взаимодействие с etcd:**

### **1. Только API Server работает с etcd:**
```bash
# API Server - единственный клиент etcd
kubectl cluster-info

# Все компоненты идут через API Server:
# kubectl → API Server → etcd
# kubelet → API Server → etcd
# controller-manager → API Server → etcd
# scheduler → API Server → etcd
```

### **2. Watch механизм:**
```bash
# etcd поддерживает watch для real-time уведомлений
kubectl get pods -w

# Когда Pod изменяется:
# 1. API Server записывает в etcd
# 2. etcd уведомляет API Server о изменении
# 3. API Server уведомляет всех подписчиков (kubectl, controllers)
```

### **3. Версионирование объектов:**
```bash
# etcd хранит resourceVersion для каждого объекта
kubectl get pod <pod-name> -o yaml | grep resourceVersion

# Optimistic concurrency control
# Предотвращает конфликты при одновременном изменении
```

## 📈 **Мониторинг etcd в вашем HA кластере:**

### **1. etcd метрики в Prometheus:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики etcd (если доступны):
# etcd_server_has_leader - есть ли лидер в кластере
# etcd_server_leader_changes_seen_total - смены лидера
# etcd_disk_wal_fsync_duration_seconds - производительность диска
# etcd_network_peer_round_trip_time_seconds - сетевая задержка
# etcd_mvcc_db_total_size_in_bytes - размер базы данных
```

### **2. API Server метрики для etcd:**
```bash
# Метрики взаимодействия API Server с etcd:
# etcd_request_duration_seconds - время запросов к etcd
# etcd_request_total - количество запросов к etcd
# apiserver_storage_objects - количество объектов в etcd

# В Prometheus UI найти эти метрики
```

### **3. Grafana дашборды etcd:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Дашборды могут показывать:
# - etcd cluster health
# - Request latency
# - Database size
# - Leader elections
```

## 🏭 **etcd в вашем HA кластере Digital Ocean:**

### **1. Managed etcd кластер:**
```bash
# Digital Ocean управляет etcd кластером
# Обычно 3-5 нод etcd для HA
# Автоматические бэкапы
# Мониторинг и алерты

# Пользователь не имеет прямого доступа к etcd
kubectl cluster-info
```

### **2. Высокая доступность:**
```bash
# etcd кластер распределен по зонам доступности
# Автоматический failover при сбоях
# Репликация данных между нодами
# Консенсус Raft обеспечивает консистентность
```

### **3. Производительность:**
```bash
# SSD диски для быстрого I/O
# Оптимизированная сетевая конфигурация
# Регулярная дефрагментация
# Мониторинг производительности
```

## 🔧 **Критичность etcd для операций:**

### **1. Создание ресурсов:**
```bash
# Создание Pod'а
kubectl run test-etcd --image=nginx

# Что происходит:
# 1. kubectl → API Server
# 2. API Server валидирует запрос
# 3. API Server записывает Pod в etcd
# 4. etcd подтверждает запись
# 5. API Server возвращает успех
# 6. Scheduler читает из etcd (через API Server)
# 7. kubelet читает из etcd (через API Server)
```

### **2. Обновление ресурсов:**
```bash
# Масштабирование Deployment
kubectl scale deployment argocd-server --replicas=4 -n argocd

# Что происходит:
# 1. API Server читает текущее состояние из etcd
# 2. Проверяет resourceVersion (optimistic locking)
# 3. Записывает новое состояние в etcd
# 4. Controller Manager читает изменение из etcd
# 5. Создает новые Pod'ы
```

### **3. Watch и события:**
```bash
# Controller'ы подписываются на изменения
kubectl get events -w

# Что происходит:
# 1. Controller подписывается на watch через API Server
# 2. API Server подписывается на watch в etcd
# 3. При изменении etcd уведомляет API Server
# 4. API Server уведомляет Controller
# 5. Controller реагирует на изменение
```

## 💾 **Бэкапы и восстановление etcd:**

### **1. Важность бэкапов:**
```bash
# etcd содержит ВСЕ данные кластера
# Потеря etcd = потеря всего кластера
# Регулярные бэкапы критически важны

# В managed кластере Digital Ocean делает автоматические бэкапы
```

### **2. Что включают бэкапы:**
```bash
# Все объекты Kubernetes
kubectl get all -A | wc -l

# Все конфигурации
kubectl get configmaps,secrets -A | wc -l

# RBAC настройки
kubectl get roles,rolebindings,clusterroles,clusterrolebindings | wc -l

# Custom Resources
kubectl get crd | wc -l
```

### **3. Стратегии бэкапов:**
```bash
# Snapshot-based backups
# Incremental backups
# Cross-region replication
# Point-in-time recovery

# В managed кластере это автоматизировано
```

## 🔄 **Производительность etcd:**

### **1. Факторы производительности:**
```bash
# Дисковый I/O - критически важен
# Сетевая задержка между нодами etcd
# Размер базы данных
# Количество watch'еров
# Частота записей
```

### **2. Оптимизация:**
```bash
# SSD диски обязательны
# Низкая сетевая задержка
# Регулярная дефрагментация
# Мониторинг размера БД
# Очистка старых событий
```

### **3. Лимиты etcd:**
```bash
# Максимальный размер объекта: 1.5MB
# Рекомендуемый размер БД: < 8GB
# Максимальное количество watch'еров: ~1000
# Рекомендуемая задержка: < 10ms
```

## 🚨 **Что происходит при сбое etcd:**

### **1. Потеря кворума:**
```bash
# Если большинство нод etcd недоступно:
# - API Server становится read-only
# - Нельзя создавать/изменять объекты
# - Существующие Pod'ы продолжают работать
# - Новые Pod'ы не создаются
```

### **2. Полная потеря etcd:**
```bash
# Если весь etcd кластер потерян:
# - Кластер полностью неработоспособен
# - Нужно восстановление из бэкапа
# - Возможна потеря данных
# - Длительный downtime
```

### **3. Восстановление:**
```bash
# В managed кластере Digital Ocean:
# - Автоматическое восстановление из бэкапов
# - Минимальный RTO (Recovery Time Objective)
# - Мониторинг и алерты
```

## 🎯 **Best Practices для etcd:**

### **1. Мониторинг:**
- Следить за здоровьем кластера
- Мониторить производительность
- Алерты на критические метрики
- Регулярные health checks

### **2. Бэкапы:**
- Автоматические регулярные бэкапы
- Тестирование восстановления
- Cross-region репликация
- Версионирование бэкапов

### **3. Производительность:**
- SSD диски для etcd
- Низкая сетевая задержка
- Мониторинг размера БД
- Регулярная дефрагментация

## 🏗️ **etcd в архитектуре вашего кластера:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Digital Ocean Cloud                     │
├─────────────────────────────────────────────────────────────┤
│  etcd Cluster (Managed HA)                                 │
│  ├── etcd-1 (Zone A) - Leader/Follower                     │
│  ├── etcd-2 (Zone B) - Leader/Follower                     │
│  └── etcd-3 (Zone C) - Leader/Follower                     │
│                                                             │
│  Raft Consensus Algorithm                                   │
│  ├── Leader Election                                        │
│  ├── Log Replication                                        │
│  └── Strong Consistency                                     │
├─────────────────────────────────────────────────────────────┤
│  API Server Cluster (HA)                                   │
│  ├── API Server 1 → etcd Client                            │
│  ├── API Server 2 → etcd Client                            │
│  └── API Server 3 → etcd Client                            │
├─────────────────────────────────────────────────────────────┤
│  Stored Data in etcd                                       │
│  ├── All Kubernetes Objects                                │
│  │   ├── Pods, Deployments, Services                       │
│  │   ├── ConfigMaps, Secrets                               │
│  │   └── RBAC, CRDs                                        │
│  ├── Cluster State                                         │
│  │   ├── Node Information                                  │
│  │   ├── Resource Quotas                                   │
│  │   └── Events (TTL)                                      │
│  └── Application Data                                       │
│      ├── ArgoCD Applications                               │
│      ├── Prometheus Configuration                          │
│      └── Ingress Rules                                     │
└─────────────────────────────────────────────────────────────┘
```

**etcd — это фундамент Kubernetes. Без etcd нет кластера!**
