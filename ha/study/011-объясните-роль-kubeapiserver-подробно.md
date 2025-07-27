# 11. Объясните роль kube-apiserver подробно

## 🎯 **Что такое kube-apiserver?**

**kube-apiserver** — это центральный компонент Control Plane, который предоставляет REST API для всех операций в Kubernetes кластере. Это единственный компонент, который напрямую взаимодействует с etcd.

## 🏗️ **Основные функции kube-apiserver:**

### **1. REST API Gateway**
- Предоставляет единый REST API для всех операций
- Обрабатывает HTTP/HTTPS запросы
- Поддерживает различные форматы (JSON, YAML, Protobuf)

### **2. Аутентификация и авторизация**
- Проверяет подлинность пользователей и сервисов
- Применяет RBAC политики
- Контролирует доступ к ресурсам

### **3. Валидация и мутация**
- Проверяет корректность запросов
- Применяет Admission Controllers
- Модифицирует объекты при необходимости

### **4. Хранение состояния**
- Единственный компонент, работающий с etcd
- Обеспечивает консистентность данных
- Управляет версионированием объектов

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Взаимодействие с API Server:**
```bash
# Все kubectl команды идут через API Server
kubectl get nodes -v=6  # Показать HTTP запросы

# API Server endpoint
kubectl cluster-info

# Версия API Server
kubectl version --short

# API ресурсы, доступные через API Server
kubectl api-resources | head -20
```

### **2. API Server обрабатывает все операции:**
```bash
# Создание ресурса через API Server
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
  namespace: default
data:
  key: value
EOF

# API Server валидирует и сохраняет в etcd
kubectl get configmap test-config -o yaml

# Удаление через API Server
kubectl delete configmap test-config
```

### **3. API Server в HA режиме (Digital Ocean):**
```bash
# Digital Ocean управляет API Server в HA режиме
kubectl cluster-info

# Несколько экземпляров API Server за Load Balancer
# (скрыто от пользователя в managed кластере)

# API Server доступен через единый endpoint
kubectl config view | grep server
```

### **4. Аутентификация через API Server:**
```bash
# Текущий пользователь (аутентифицирован через API Server)
kubectl auth whoami

# Проверить права доступа
kubectl auth can-i get pods
kubectl auth can-i create deployments -n argocd

# ServiceAccount токены для аутентификации
kubectl get serviceaccounts -n argocd
kubectl describe serviceaccount argocd-server -n argocd
```

### **5. API версии и группы:**
```bash
# API группы, поддерживаемые API Server
kubectl api-versions

# Ресурсы в разных API группах
kubectl api-resources --api-group=apps
kubectl api-resources --api-group=networking.k8s.io

# Схема API для конкретного ресурса
kubectl explain deployment
kubectl explain pod.spec.containers
```

## 🔄 **Архитектура API Server:**

### **1. Компоненты API Server:**
```
┌─────────────────────────────────────────────────────────────┐
│                    kube-apiserver                           │
├─────────────────────────────────────────────────────────────┤
│  HTTP/HTTPS Server                                          │
│  ├── REST API Handlers                                     │
│  ├── OpenAPI/Swagger Documentation                         │
│  └── Health Check Endpoints                                │
├─────────────────────────────────────────────────────────────┤
│  Authentication Layer                                       │
│  ├── Client Certificates                                   │
│  ├── Bearer Tokens                                         │
│  ├── Basic Auth                                            │
│  └── OIDC Integration                                       │
├─────────────────────────────────────────────────────────────┤
│  Authorization Layer                                        │
│  ├── RBAC (Role-Based Access Control)                      │
│  ├── ABAC (Attribute-Based Access Control)                 │
│  ├── Node Authorization                                     │
│  └── Webhook Authorization                                  │
├─────────────────────────────────────────────────────────────┤
│  Admission Control                                          │
│  ├── Mutating Admission Controllers                        │
│  ├── Validating Admission Controllers                      │
│  └── Custom Admission Webhooks                             │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                              │
│  ├── etcd Client                                           │
│  ├── Resource Versioning                                   │
│  ├── Watch Mechanism                                       │
│  └── Caching Layer                                         │
└─────────────────────────────────────────────────────────────┘
```

### **2. Поток обработки запроса:**
```bash
# 1. HTTP Request → API Server
curl -k -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/default/pods

# 2. Authentication → проверка токена
# 3. Authorization → проверка RBAC
# 4. Admission Control → валидация и мутация
# 5. Storage → сохранение в etcd
# 6. Response → возврат результата
```

## 🔒 **Безопасность API Server:**

### **1. TLS и сертификаты:**
```bash
# API Server использует TLS для всех соединений
kubectl config view | grep certificate-authority

# Клиентские сертификаты для аутентификации
kubectl config view | grep client-certificate

# Проверить TLS соединение
openssl s_client -connect $(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||') -servername kubernetes
```

### **2. RBAC через API Server:**
```bash
# Роли в ArgoCD namespace
kubectl get roles -n argocd

# RoleBindings связывают пользователей с ролями
kubectl get rolebindings -n argocd

# ClusterRoles для кластерных ресурсов
kubectl get clusterroles | grep argocd

# API Server проверяет права при каждом запросе
kubectl auth can-i list pods -n argocd --as=system:serviceaccount:argocd:argocd-server
```

### **3. Admission Controllers:**
```bash
# API Server применяет Admission Controllers
# (в managed кластере настройки скрыты)

# Примеры Admission Controllers:
# - NamespaceLifecycle - предотвращает создание в terminating namespace
# - ResourceQuota - проверяет лимиты ресурсов
# - PodSecurityPolicy - применяет политики безопасности
# - MutatingAdmissionWebhook - изменяет объекты
# - ValidatingAdmissionWebhook - валидирует объекты
```

## 📈 **Мониторинг API Server:**

### **1. Метрики API Server:**
```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики API Server в Prometheus:
# apiserver_request_total - общее количество запросов
# apiserver_request_duration_seconds - время обработки запросов
# apiserver_current_inflight_requests - текущие запросы в обработке
# etcd_request_duration_seconds - время запросов к etcd
```

### **2. Grafana дашборды API Server:**
```bash
# Port forward к Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Дашборды показывают:
# - API Server request rate
# - Response times
# - Error rates
# - etcd performance
```

### **3. API Server health checks:**
```bash
# Health check endpoints (в managed кластере недоступны напрямую)
# /healthz - общее состояние
# /readyz - готовность к обслуживанию
# /livez - проверка жизнеспособности

# Проверить доступность API Server
kubectl get --raw /healthz
kubectl get --raw /version
```

## 🔄 **API Server в действии:**

### **1. Watch механизм:**
```bash
# API Server поддерживает watch для real-time обновлений
kubectl get pods -w

# Другой терминал - создать Pod
kubectl run test-watch --image=nginx

# Первый терминал увидит создание в реальном времени
# API Server отправляет события через HTTP streaming
```

### **2. Patch операции:**
```bash
# API Server поддерживает различные типы patch
kubectl patch deployment argocd-server -n argocd -p '{"spec":{"replicas":4}}'

# Strategic merge patch
kubectl patch deployment argocd-server -n argocd --type='strategic' -p='{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}'

# JSON patch
kubectl patch deployment argocd-server -n argocd --type='json' -p='[{"op": "replace", "path": "/spec/replicas", "value": 3}]'
```

### **3. Server-side apply:**
```bash
# API Server может применять конфигурации server-side
kubectl apply --server-side -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: server-side-test
data:
  managed-by: server-side-apply
EOF

# Посмотреть managed fields
kubectl get configmap server-side-test -o yaml | grep -A 10 managedFields
```

## 🏭 **API Server в вашем HA кластере:**

### **1. High Availability:**
```bash
# Digital Ocean обеспечивает HA API Server
kubectl cluster-info

# Load Balancer перед несколькими экземплярами API Server
# Автоматический failover при сбоях
# Shared etcd кластер для всех API Server экземпляров
```

### **2. Производительность:**
```bash
# API Server оптимизирован для высокой нагрузки
kubectl top nodes  # Запрос через API Server

# Кэширование для улучшения производительности
kubectl get pods -n argocd  # Может использовать кэш

# Pagination для больших списков
kubectl get pods -A --limit=50
```

### **3. Интеграция с ArgoCD:**
```bash
# ArgoCD интенсивно использует API Server
kubectl get applications -n argocd

# ArgoCD Controller делает множество API вызовов
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep "GET\|POST\|PUT"

# API Server обрабатывает все GitOps операции
kubectl describe application -n argocd | head -20
```

## 🎯 **Ключевые особенности API Server:**

### **1. Единая точка входа:**
- Все компоненты взаимодействуют только через API Server
- kubectl, kubelet, controller-manager - все через API
- Обеспечивает консистентность и безопасность

### **2. Stateless дизайн:**
- API Server не хранит состояние
- Все данные в etcd
- Можно масштабировать горизонтально

### **3. Extensibility:**
```bash
# Custom Resource Definitions через API Server
kubectl get crd | head -10

# API Server автоматически поддерживает новые ресурсы
kubectl get applications -n argocd  # ArgoCD CRD
```

## 🔧 **Отладка API Server:**

### **1. Verbose logging:**
```bash
# Увеличить verbosity для отладки
kubectl get pods -v=8  # Показать HTTP запросы и ответы
kubectl get pods -v=9  # Еще больше деталей
```

### **2. API Server logs:**
```bash
# В managed кластере логи API Server недоступны напрямую
# Но можно анализировать через метрики и события

kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
```

**API Server — это сердце Kubernetes, через которое проходят все операции в кластере!**
