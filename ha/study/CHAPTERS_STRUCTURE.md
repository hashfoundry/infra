# 📚 Структура курса Kubernetes по главам

## 🎯 **Глава 0: Введение и инструменты**
- `000` - Как эффективно использовать kubectl

## 🏗️ **Глава 1: Основы Kubernetes (001-010)**
- `001` - Что такое Kubernetes и зачем он используется
- `002` - Объясните разницу между Docker и Kubernetes  
- `003` - Каковы основные компоненты архитектуры Kubernetes
- `004` - Что такое Pod в Kubernetes
- `005` - В чем разница между Pod и Container
- `006` - Что такое Node в Kubernetes
- `007` - В чем разница между Kubernetes и Docker Swarm
- `008` - Что такое Labels и Selectors в Kubernetes
- `009` - Что такое Namespace в Kubernetes
- `010` - В чем разница между StatefulSet и Deployment

## ⚙️ **Глава 2: Архитектура и компоненты кластера (011-020)**
- `011` - Объясните роль kube-apiserver подробно
- `012` - Что такое etcd и почему он критичен для Kubernetes
- `013` - Как работает Kubernetes Scheduler
- `014` - Какова роль kubelet
- `015` - Что делает kube-proxy
- `016` - Объясните компоненты Controller Manager
- `017` - Разница между kube-controller-manager и cloud-controller-manager
- `018` - Как Kubernetes обрабатывает leader election
- `019` - Какова роль Container Runtime Interface (CRI)
- `020` - Объясните стратегию версионирования API Kubernetes

## 🚀 **Глава 3: Управление Pod-ами (021-030)**
- `021` - Что такое Init Containers и когда их использовать
- `022` - Как обрабатывать multi-container Pod'ы
- `023` - В чем разница между requests и limits в управлении ресурсами
- `024` - Как отлаживать неработающий Pod
- `025` - Что такое Pod Security Contexts
- `026` - Как Kubernetes обрабатывает рестарты контейнеров
- `027` - Что такое классы Quality of Service (QoS) в Kubernetes
- `028` - Как реализовать readiness и liveness probes
- `029` - Что такое Pod Disruption Budget (PDB)
- `030` - Как Kubernetes обрабатывает DNS для Pod'ов

## 🌐 **Глава 4: Сетевые сервисы и Ingress (031-040)**
- `031` - Какие типы Services существуют в Kubernetes
- `032` - Как работает Service Discovery в Kubernetes
- `033` - В чем разница между ClusterIP и NodePort
- `034` - Как работает балансировка нагрузки в Kubernetes Services
- `035` - Что такое Endpoints и EndpointSlices
- `036` - Как предоставить доступ к сервису для внешнего трафика
- `037` - Что такое Ingress Controller и как он работает
- `038` - Как реализовать SSL/TLS termination в Kubernetes
- `039` - Что такое Network Policies и как они работают
- `040` - Объясните сетевую модель Kubernetes

## 📦 **Глава 5: Развертывание и управление приложениями (041-050)**
- `041` - Что такое ReplicaSet и как он работает
- `042` - Чем отличается Deployment от ReplicaSet
- `043` - Какие существуют стратегии развертывания в Kubernetes
- `044` - Как выполнить rolling update и rollback
- `045` - Что такое maxSurge и maxUnavailable в стратегии развертывания
- `046` - Как приостановить и возобновить развертывание
- `047` - Что такое DaemonSets и когда их использовать
- `048` - Как обновлять DaemonSets
- `049` - В чем разница между стратегиями обновления Deployment и StatefulSet
- `050` - Как настроить автоматическое масштабирование (HPA)

## 🔧 **Глава 6: Конфигурация и секреты (051-060)**
- `051` - Что такое ConfigMaps и как их использовать
- `052` - Какие существуют способы создания ConfigMaps
- `053` - Что такое Secrets и чем они отличаются от ConfigMaps
- `054` - Какие существуют типы Secrets
- `055` - Как безопасно управлять секретами в Kubernetes
- `056` - Как монтировать ConfigMaps и Secrets как volumes
- `057` - Что происходит при обновлении ConfigMap или Secret
- `058` - Управление версиями ConfigMaps и Secrets
- `059` - Immutable ConfigMaps и Secrets
- `060` - Troubleshooting ConfigMaps и Secrets

## 💾 **Глава 7: Хранение данных (061-070)**
- `061` - Persistent Volumes (PV) и Persistent Volume Claims (PVC)
- `062` - Access Modes для Persistent Volumes
- `063` - StorageClass и Dynamic Provisioning
- `064` - Volume Reclaim Policies
- `065` - Как создавать резервные копии и восстанавливать Persistent Volumes
- `066` - Static vs Dynamic Provisioning
- `067` - PVC Resizing (Volume Expansion)
- `068` - Volume Snapshots
- `069` - Volume Mounting Issues
- `070` - Storage Best Practices в Kubernetes

## 🔐 **Глава 8: Безопасность и RBAC (071-090)**
- `071` - Multiple Namespaces в Kubernetes
- `072` - Resource Quotas и Limit Ranges в Kubernetes
- `073` - RBAC (Role-Based Access Control) в Kubernetes
- `074` - Role vs ClusterRole в Kubernetes
- `075` - ServiceAccounts в Kubernetes
- `076` - Создание пользовательских RBAC политик в Kubernetes
- `077` - Стандартные RBAC роли в Kubernetes
- `078` - Диагностика проблем с RBAC правами в Kubernetes
- `079` - Принцип минимальных привилегий в Kubernetes RBAC
- `080` - Реализация multi-tenancy с помощью namespaces в Kubernetes
- `081` - Pod Security Standards в Kubernetes
- `082` - Различия между Pod Security Policies и Pod Security Standards
- `083` - Реализация сетевой сегментации в Kubernetes
- `084` - Admission Controllers в Kubernetes
- `085` - Runtime Security Monitoring в Kubernetes
- `086` - Безопасные обновления Kubernetes кластера
- `087` - Управление ресурсами в Kubernetes
- `088` - Disaster Recovery для Kubernetes
- `089` - Kubernetes в Production
- `090` - Troubleshooting Kubernetes

## 🎛️ **Глава 9: Планирование и автомасштабирование (091-100)**
- `091` - Kubernetes Node Selection
- `092` - Node Affinity и Pod Affinity
- `093` - Taints и Tolerations
- `094` - Cordon и Drain Nodes
- `095` - Horizontal Pod Autoscaler (HPA)
- `096` - Vertical Pod Autoscaler (VPA)
- `097` - Cluster Autoscaler
- `098` - Kubernetes Jobs и CronJobs
- `099` - Custom Resources и Operators
- `100` - Kubernetes Best Practices и Production Readiness

## 📊 **Глава 10: Мониторинг и логирование (101-110)**
- `101` - Ключевые метрики для мониторинга в Kubernetes
- `102` - Как работает сбор метрик в Kubernetes
- `103` - Разница между metrics-server и Prometheus
- `104` - Как реализовать централизованное логирование
- `105` - Типы логов в Kubernetes
- `106` - Как настроить алертинг в Kubernetes
- `107` - Как устранять распространенные проблемы в Kubernetes
- `108` - Лучшие практики для продакшена в Kubernetes
- `109` - Экосистема и инструменты Kubernetes
- `110` - Будущее Kubernetes

## 🔍 **Глава 11: Диагностика и отладка (111-120)**
- `111` - Как диагностировать Pod, который не запускается
- `112` - Основные причины ошибок ImagePullBackOff
- `113` - Как отлаживать сетевые проблемы в Kubernetes
- `114` - Инструменты для отладки Kubernetes
- `115` - Как устранять проблемы с DNS в Kubernetes
- `116` - Как устранять проблемы с ресурсными ограничениями и OOMKilled Pods
- `117` - Шаги при недоступности сервиса в Kubernetes
- `118` - Как устранять проблемы с etcd в Kubernetes
- `119` - Что делать когда kubectl команды медленные или зависают
- `120` - Как отлаживать проблемы с сертификатами в Kubernetes

## 🌐 **Глава 12: Продвинутые сетевые концепции (121-130)**
- `121` - Детальное объяснение Container Network Interface (CNI)
- `122` - Различные CNI плагины и их характеристики
- `123` - Как работает Pod-to-Pod сеть между узлами
- `124` - Что такое IPVS и чем он отличается от iptables
- `125` - Как реализовать управление входящим трафиком через Ingress
- `126` - Что такое Service Mesh и как они интегрируются с Kubernetes
- `127` - Как устранять проблемы с DNS разрешением в Kubernetes
- `128` - В чем разница между NodePort, LoadBalancer и Ingress
- `129` - Как реализовать сетевую сегментацию и микросегментацию
- `130` - Какие есть последствия для безопасности различных сетевых решений

## 🔧 **Глава 13: Расширение Kubernetes (131-140)**
- `131` - Что такое Custom Resource Definitions (CRDs)
- `132` - Как создавать и управлять CRDs
- `133` - Что такое Operator Pattern
- `134` - Какие компоненты входят в состав Kubernetes Operator
- `135` - Как разработать собственный оператор
- `136` - Как управлять обновлениями и версионированием операторов
- `137` - Что такое admission controllers и webhooks
- `138` - Как реализовать пользовательскую логику планирования
- `139` - Какие лучшие практики безопасности Kubernetes
- `140` - Как устранять распространенные проблемы Kubernetes

---

## 📁 **Структура папок:**

```
📂 00-Введение и инструменты
📂 01-Основы Kubernetes
📂 02-Архитектура и компоненты кластера
📂 03-Управление Pod-ами
📂 04-Сетевые сервисы и Ingress
📂 05-Развертывание и управление приложениями
📂 06-Конфигурация и секреты
📂 07-Хранение данных
📂 08-Безопасность и RBAC
📂 09-Планирование и автомасштабирование
📂 10-Мониторинг и логирование
📂 11-Диагностика и отладка
📂 12-Продвинутые сетевые концепции
📂 13-Расширение Kubernetes
```

## 📋 **Краткое описание глав:**

1. **Введение** - Основные инструменты для работы с Kubernetes
2. **Основы** - Базовые концепции и терминология
3. **Архитектура** - Компоненты кластера и их взаимодействие
4. **Pod'ы** - Управление контейнерами и их жизненным циклом
5. **Сети** - Сервисы, Ingress, сетевая модель
6. **Развертывание** - Стратегии деплоя и управление приложениями
7. **Конфигурация** - ConfigMaps, Secrets, управление настройками
8. **Хранение** - Persistent Volumes, StorageClass, резервное копирование
9. **Безопасность** - RBAC, Pod Security, сетевая безопасность
10. **Планирование** - Размещение Pod'ов, автомасштабирование
11. **Мониторинг** - Метрики, логи, алертинг
12. **Диагностика** - Отладка и решение проблем
13. **Сети (продвинутое)** - CNI, Service Mesh, микросегментация
14. **Расширение** - CRDs, Operators, кастомизация Kubernetes

Эта структура обеспечивает логическое изучение от базовых концепций к продвинутым темам.
