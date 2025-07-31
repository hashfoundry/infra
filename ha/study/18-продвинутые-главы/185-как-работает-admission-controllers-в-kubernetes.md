# 185. Как работает admission controllers в Kubernetes?

## 🎯 **Что такое Admission Controllers?**

**Admission Controllers** — это плагины в Kubernetes API Server, которые перехватывают запросы после аутентификации и авторизации, но до сохранения объекта в etcd. Они могут валидировать, изменять или отклонять запросы, обеспечивая дополнительную безопасность, соблюдение политик и автоматическую настройку ресурсов.

## 🏗️ **Основные типы Admission Controllers:**

### **1. Built-in Controllers**
- Встроенные контроллеры в kube-apiserver
- Компилируются вместе с API Server
- Настраиваются через флаги запуска

### **2. Mutating Admission Webhooks**
- Изменяют объекты перед сохранением
- Выполняются первыми в admission pipeline
- Могут добавлять/изменять поля объектов

### **3. Validating Admission Webhooks**
- Валидируют объекты без изменения
- Выполняются после mutating webhooks
- Могут только принять или отклонить запрос

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка admission controllers:**
```bash
# Включенные admission controllers
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -A 5 -B 5 "enable-admission-plugins"

# Admission webhooks в кластере
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Admission controller логи
kubectl logs -n kube-system -l component=kube-apiserver | grep admission | tail -10

# Тестирование admission
kubectl auth can-i create pods --as=system:serviceaccount:default:default
```

### **2. Built-in controllers в действии:**
```bash
# LimitRanger в мониторинге
kubectl get limitrange -n monitoring
kubectl describe limitrange -n monitoring

# ResourceQuota проверка
kubectl get resourcequota --all-namespaces
kubectl describe resourcequota -n monitoring

# ServiceAccount admission
kubectl get serviceaccount -n monitoring
kubectl describe pod -n monitoring | grep -A 5 "Service Account"
```

### **3. Storage admission controllers:**
```bash
# DefaultStorageClass controller
kubectl get storageclass
kubectl describe storageclass | grep -A 5 "Default"

# PVC admission
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring | grep -A 5 "Events"

# Volume admission
kubectl describe pod -n monitoring | grep -A 10 "Volumes"
```

### **4. Security admission:**
```bash
# Pod Security Standards
kubectl get pods -n monitoring -o yaml | grep -A 10 securityContext

# Service Account tokens
kubectl describe pod -n monitoring | grep -A 5 "Mounts"

# Network policies admission
kubectl get networkpolicies --all-namespaces
```

## 🔄 **Admission Pipeline Flow:**

### **1. Демонстрация admission flow:**
```bash
# Создание pod с минимальной конфигурацией
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: admission-demo
  namespace: default
spec:
  containers:
  - name: app
    image: nginx:alpine
EOF

# Проверка изменений от admission controllers
kubectl describe pod admission-demo | grep -A 20 "Containers"
kubectl get pod admission-demo -o yaml | grep -A 10 serviceAccount

# Удаление demo pod
kubectl delete pod admission-demo
```

### **2. Тестирование LimitRanger:**
```bash
# Создание LimitRange
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: demo-limits
  namespace: default
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "1"
      memory: "1Gi"
EOF

# Создание pod без resource limits
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: limitrange-demo
  namespace: default
spec:
  containers:
  - name: app
    image: nginx:alpine
EOF

# Проверка автоматически добавленных limits
kubectl describe pod limitrange-demo | grep -A 10 "Limits"

# Очистка
kubectl delete pod limitrange-demo
kubectl delete limitrange demo-limits
```

### **3. Тестирование ResourceQuota:**
```bash
# Создание ResourceQuota
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-quota
  namespace: default
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "4Gi"
    limits.cpu: "4"
    limits.memory: "8Gi"
    pods: "10"
EOF

# Проверка quota
kubectl describe resourcequota demo-quota

# Создание pod с большими ресурсами (должен быть отклонен)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-test
  namespace: default
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "3"
        memory: "5Gi"
EOF

# Очистка
kubectl delete resourcequota demo-quota
```

## 📈 **Мониторинг Admission Controllers:**

### **1. Admission metrics:**
```bash
# API Server admission metrics
kubectl get --raw /metrics | grep "apiserver_admission"

# Admission latency
kubectl get --raw /metrics | grep "apiserver_admission_controller_admission_duration_seconds"

# Admission webhook metrics
kubectl get --raw /metrics | grep "apiserver_admission_webhook"

# Failed admissions
kubectl get events --all-namespaces --field-selector reason=FailedAdmissionWebhook
```

### **2. Webhook status:**
```bash
# Mutating webhooks status
kubectl get mutatingwebhookconfigurations -o yaml | grep -A 5 -B 5 "failurePolicy"

# Validating webhooks status
kubectl get validatingwebhookconfigurations -o yaml | grep -A 5 -B 5 "timeoutSeconds"

# Webhook endpoints
kubectl get endpoints --all-namespaces | grep webhook
```

### **3. Admission events:**
```bash
# Admission failures
kubectl get events --all-namespaces --field-selector reason=FailedCreate

# Webhook timeouts
kubectl get events --all-namespaces | grep -i "webhook.*timeout"

# Admission rejections
kubectl get events --all-namespaces | grep -i "admission.*denied"
```

## 🏭 **Admission Controllers в вашем HA кластере:**

### **1. ArgoCD admission:**
```bash
# ArgoCD webhook configurations
kubectl get mutatingwebhookconfigurations | grep argocd
kubectl get validatingwebhookconfigurations | grep argocd

# ArgoCD admission events
kubectl get events -n argocd --field-selector reason=AdmissionWebhook

# ArgoCD resource validation
kubectl describe application -n argocd | grep -A 10 "Events"
```

### **2. Monitoring stack admission:**
```bash
# Prometheus admission
kubectl describe statefulset prometheus-server -n monitoring | grep -A 10 "Events"

# Grafana admission
kubectl describe deployment grafana -n monitoring | grep -A 10 "Events"

# Storage admission в мониторинге
kubectl describe pvc -n monitoring | grep -A 10 "Events"
```

### **3. Security admission:**
```bash
# Pod Security Standards
kubectl get pods -n monitoring -o json | jq '.items[] | {name: .metadata.name, securityContext: .spec.securityContext}'

# Service Account admission
kubectl get pods -n monitoring -o json | jq '.items[] | {name: .metadata.name, serviceAccount: .spec.serviceAccountName}'

# Network policy admission
kubectl describe networkpolicy -n monitoring
```

## 🔧 **Конфигурация Built-in Controllers:**

### **1. Проверка конфигурации:**
```bash
# API Server admission plugins
kubectl describe pod -n kube-system -l component=kube-apiserver | grep -A 20 "Command"

# Включенные admission controllers
kubectl logs -n kube-system -l component=kube-apiserver | grep "Loaded.*admission" | head -5

# Admission controller порядок
kubectl get --raw /api/v1 | jq '.serverAddressByClientCIDRs'
```

### **2. LimitRanger конфигурация:**
```bash
# Создание production LimitRange
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: monitoring
spec:
  limits:
  - type: Container
    default:
      cpu: "1"
      memory: "1Gi"
    defaultRequest:
      cpu: "200m"
      memory: "256Mi"
    max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
  - type: Pod
    max:
      cpu: "4"
      memory: "8Gi"
  - type: PersistentVolumeClaim
    max:
      storage: "100Gi"
    min:
      storage: "1Gi"
EOF

# Проверка применения
kubectl describe limitrange production-limits -n monitoring
```

### **3. ResourceQuota конфигурация:**
```bash
# Создание comprehensive quota
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: monitoring-quota
  namespace: monitoring
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    requests.storage: "100Gi"
    persistentvolumeclaims: "10"
    pods: "50"
    services: "20"
    secrets: "30"
    configmaps: "30"
    count/deployments.apps: "10"
    count/statefulsets.apps: "5"
EOF

# Мониторинг использования quota
kubectl describe resourcequota monitoring-quota -n monitoring
```

## 🎯 **Архитектура Admission Pipeline:**

```
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Admission Pipeline                 │
├─────────────────────────────────────────────────────────────┤
│  1. Authentication & Authorization                         │
│  ├── User/ServiceAccount authentication                    │
│  ├── RBAC authorization check                              │
│  └── Request validated and authorized                      │
├─────────────────────────────────────────────────────────────┤
│  2. Mutating Admission Phase                               │
│  ├── Built-in mutating controllers                        │
│  ├── Mutating admission webhooks (parallel)               │
│  └── Object potentially modified                          │
├─────────────────────────────────────────────────────────────┤
│  3. Object Schema Validation                               │
│  ├── OpenAPI schema validation                            │
│  ├── Field validation                                     │
│  └── Structure validation                                 │
├─────────────────────────────────────────────────────────────┤
│  4. Validating Admission Phase                            │
│  ├── Built-in validating controllers                      │
│  ├── Validating admission webhooks (parallel)             │
│  └── Final validation check                               │
├─────────────────────────────────────────────────────────────┤
│  5. Persistence                                           │
│  ├── Object stored in etcd                                │
│  ├── Response sent to client                              │
│  └── Controllers notified                                 │
└─────────────────────────────────────────────────────────────┘
```

## 🚨 **Troubleshooting Admission Controllers:**

### **1. Admission failures:**
```bash
# Поиск admission failures
kubectl get events --all-namespaces --field-selector reason=FailedCreate | grep -i admission

# Webhook failures
kubectl get events --all-namespaces | grep -i "webhook.*failed"

# Timeout issues
kubectl get events --all-namespaces | grep -i "webhook.*timeout"

# API Server logs
kubectl logs -n kube-system -l component=kube-apiserver | grep -i "admission.*error" | tail -10
```

### **2. Resource quota issues:**
```bash
# Quota exceeded errors
kubectl get events --all-namespaces --field-selector reason=FailedCreate | grep -i quota

# Current quota usage
kubectl describe resourcequota --all-namespaces

# Resource consumption
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory
```

### **3. Webhook debugging:**
```bash
# Webhook configuration issues
kubectl get mutatingwebhookconfigurations -o yaml | grep -A 10 -B 10 "failurePolicy"

# Webhook endpoint health
kubectl get endpoints --all-namespaces | grep webhook

# Webhook service status
kubectl get services --all-namespaces | grep webhook
```

## 🔧 **Best Practices для Admission Controllers:**

### **1. Мониторинг:**
```bash
# Регулярная проверка admission metrics
kubectl get --raw /metrics | grep "apiserver_admission_controller_admission_duration_seconds" | grep -E "(sum|count)"

# Webhook latency мониторинг
kubectl get --raw /metrics | grep "apiserver_admission_webhook_admission_duration_seconds"

# Failure rate tracking
kubectl get events --all-namespaces --field-selector reason=FailedAdmissionWebhook --sort-by='.lastTimestamp'
```

### **2. Конфигурация:**
```bash
# Проверка webhook timeouts
kubectl get validatingwebhookconfigurations -o json | jq '.items[] | {name: .metadata.name, timeout: .webhooks[].timeoutSeconds}'

# Failure policy review
kubectl get mutatingwebhookconfigurations -o json | jq '.items[] | {name: .metadata.name, failurePolicy: .webhooks[].failurePolicy}'

# Namespace selectors
kubectl get validatingwebhookconfigurations -o yaml | grep -A 5 -B 5 namespaceSelector
```

## 🎯 **Best Practices для Admission Controllers:**

### **1. Безопасность:**
- Используйте failurePolicy: Fail для критичных webhooks
- Настраивайте подходящие timeouts
- Мониторьте webhook availability

### **2. Производительность:**
- Минимизируйте latency в webhooks
- Используйте appropriate resource limits
- Кэшируйте данные где возможно

### **3. Надежность:**
- Тестируйте admission logic thoroughly
- Имейте fallback strategies
- Мониторьте admission metrics

### **4. Операционные аспекты:**
- Документируйте admission policies
- Версионируйте webhook configurations
- Планируйте rollback strategies

**Admission Controllers — это мощный механизм для обеспечения безопасности, соблюдения политик и автоматизации в Kubernetes!**
