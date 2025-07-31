# 183. Что такое finalizers и как они работают?

## 🎯 **Что такое Finalizers?**

**Finalizers** — это механизм в Kubernetes, который позволяет контроллерам выполнять cleanup операции перед удалением объекта. Они представляют собой список строк в metadata объекта, которые предотвращают физическое удаление объекта до тех пор, пока все finalizers не будут удалены.

## 🏗️ **Основные функции Finalizers:**

### **1. Graceful Cleanup**
- Обеспечивают корректное удаление зависимых ресурсов
- Предотвращают утечку внешних ресурсов
- Гарантируют выполнение cleanup операций

### **2. Resource Protection**
- Защищают критичные ресурсы от случайного удаления
- Обеспечивают целостность данных
- Контролируют порядок удаления объектов

### **3. Custom Cleanup Logic**
- Позволяют реализовать специфическую логику cleanup
- Интегрируются с внешними системами
- Поддерживают сложные сценарии удаления

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка finalizers в кластере:**
```bash
# Объекты с finalizers
kubectl get all --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.finalizers}{"\n"}{end}' | grep -v "null"

# PersistentVolumes с protection finalizer
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.finalizers}{"\n"}{end}'

# Namespaces с finalizers
kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.finalizers}{"\n"}{end}'

# ArgoCD объекты с finalizers
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.finalizers}{"\n"}{end}'
```

### **2. Мониторинг объекты с finalizers:**
```bash
# Prometheus PV с finalizers
kubectl describe pv | grep -A 5 -B 5 Finalizers

# Grafana PVC с protection
kubectl describe pvc -n monitoring | grep -A 5 -B 5 Finalizers

# Stuck объекты в состоянии Terminating
kubectl get pods --all-namespaces --field-selector status.phase=Terminating
```

### **3. ArgoCD и finalizers:**
```bash
# ArgoCD Applications с finalizers
kubectl get applications -n argocd -o yaml | grep -A 5 -B 5 finalizers

# ArgoCD Projects с finalizers
kubectl get appprojects -n argocd -o yaml | grep -A 5 -B 5 finalizers

# События удаления ArgoCD приложений
kubectl get events -n argocd --field-selector reason=FinalizerUpdateFailed
```

### **4. Storage finalizers:**
```bash
# PV protection finalizers
kubectl get pv -o yaml | grep -A 3 -B 3 "kubernetes.io/pv-protection"

# PVC protection finalizers
kubectl get pvc --all-namespaces -o yaml | grep -A 3 -B 3 "kubernetes.io/pvc-protection"

# NFS volumes с finalizers
kubectl describe pv | grep -A 10 "nfs"
```

## 🔄 **Типы Finalizers в кластере:**

### **1. Kubernetes встроенные finalizers:**
```bash
# PV protection finalizer
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.finalizers}{"\n"}{end}' | grep pv-protection

# PVC protection finalizer
kubectl get pvc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.metadata.finalizers}{"\n"}{end}' | grep pvc-protection

# Namespace finalizer
kubectl get namespace -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.finalizers}{"\n"}{end}' | grep kubernetes
```

### **2. ArgoCD finalizers:**
```bash
# ArgoCD resource finalizers
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.finalizers}{"\n"}{end}'

# ArgoCD cleanup finalizers
kubectl describe application -n argocd | grep -A 5 "resources-finalizer.argocd.argoproj.io"
```

### **3. Custom finalizers:**
```bash
# Поиск custom finalizers
kubectl get all --all-namespaces -o json | jq -r '.items[].metadata.finalizers[]?' | sort | uniq | grep -v "kubernetes.io"

# Monitoring finalizers
kubectl get all -n monitoring -o json | jq -r '.items[] | select(.metadata.finalizers != null) | "\(.metadata.name): \(.metadata.finalizers | join(", "))"'
```

## 🔧 **Демонстрация работы Finalizers:**

### **1. Создание объекта с finalizer:**
```bash
# Создание ConfigMap с custom finalizer
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-finalizer
  namespace: default
  finalizers:
  - "example.com/cleanup-finalizer"
data:
  test: "data"
EOF

# Проверка finalizer
kubectl describe configmap test-finalizer | grep -A 5 Finalizers

# Попытка удаления (объект останется в Terminating)
kubectl delete configmap test-finalizer

# Проверка состояния
kubectl get configmap test-finalizer -o yaml | grep -A 5 deletionTimestamp
```

### **2. Удаление finalizer:**
```bash
# Удаление finalizer для завершения удаления
kubectl patch configmap test-finalizer --type='merge' -p='{"metadata":{"finalizers":null}}'

# Проверка удаления
kubectl get configmap test-finalizer
```

### **3. Тестирование PVC protection:**
```bash
# Создание Pod с PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: nginx:alpine
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# Попытка удаления PVC (будет заблокирована)
kubectl delete pvc test-pvc

# Проверка finalizer protection
kubectl describe pvc test-pvc | grep -A 5 Finalizers

# Удаление Pod для освобождения PVC
kubectl delete pod test-pod

# Теперь PVC можно удалить
kubectl delete pvc test-pvc
```

## 📈 **Мониторинг Finalizers:**

### **1. Поиск stuck объектов:**
```bash
# Объекты в состоянии Terminating
kubectl get all --all-namespaces -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null and .metadata.finalizers != null and (.metadata.finalizers | length) > 0) | "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "cluster-scope") - Stuck with finalizers: \(.metadata.finalizers | join(", "))"'

# Namespaces в Terminating
kubectl get namespaces --field-selector status.phase=Terminating

# События finalizer ошибок
kubectl get events --all-namespaces --field-selector reason=FinalizerUpdateFailed
```

### **2. Анализ finalizer patterns:**
```bash
# Подсчет использования finalizers
kubectl get all --all-namespaces -o json | jq -r '[.items[].metadata.finalizers[]?] | group_by(.) | map({finalizer: .[0], count: length}) | sort_by(.count) | reverse | .[] | "\(.finalizer): \(.count) objects"'

# Finalizers в мониторинге
kubectl get all -n monitoring -o json | jq -r '.items[] | select(.metadata.finalizers != null) | "\(.kind)/\(.metadata.name): \(.metadata.finalizers | join(", "))"'

# ArgoCD finalizers
kubectl get applications,appprojects -n argocd -o json | jq -r '.items[] | select(.metadata.finalizers != null) | "\(.kind)/\(.metadata.name): \(.metadata.finalizers | join(", "))"'
```

### **3. Finalizer события:**
```bash
# События связанные с finalizers
kubectl get events --all-namespaces --field-selector reason=FailedDelete

# Мониторинг в реальном времени
kubectl get events --all-namespaces --watch | grep -i finalizer

# ArgoCD finalizer события
kubectl get events -n argocd --field-selector involvedObject.kind=Application
```

## 🏭 **Finalizers в вашем HA кластере:**

### **1. Storage finalizers:**
```bash
# NFS PV finalizers
kubectl get pv | grep nfs
kubectl describe pv | grep -A 10 "nfs" | grep -A 5 Finalizers

# Block storage finalizers
kubectl get pv | grep do-block-storage
kubectl describe pv | grep -A 5 "do-block-storage"

# PVC в мониторинге
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring | grep -A 5 Finalizers
```

### **2. ArgoCD finalizers:**
```bash
# ArgoCD Applications finalizers
kubectl get applications -n argocd
kubectl describe application monitoring -n argocd | grep -A 5 Finalizers

# ArgoCD Projects finalizers
kubectl get appprojects -n argocd
kubectl describe appproject default -n argocd | grep -A 5 Finalizers

# ArgoCD cleanup behavior
kubectl get applications -n argocd -o yaml | grep -A 10 "resources-finalizer"
```

### **3. Namespace finalizers:**
```bash
# Системные namespaces
kubectl get namespace kube-system -o yaml | grep -A 5 finalizers
kubectl get namespace argocd -o yaml | grep -A 5 finalizers
kubectl get namespace monitoring -o yaml | grep -A 5 finalizers

# Custom namespaces
kubectl get namespaces -o json | jq -r '.items[] | select(.metadata.finalizers != null and (.metadata.finalizers | length) > 0) | "\(.metadata.name): \(.metadata.finalizers | join(", "))"'
```

## 🔄 **Работа с Finalizers:**

### **1. Добавление finalizer:**
```bash
# Добавление finalizer к объекту
kubectl patch deployment nginx-deployment --type='merge' -p='{"metadata":{"finalizers":["example.com/cleanup-finalizer"]}}'

# Проверка добавления
kubectl describe deployment nginx-deployment | grep -A 5 Finalizers
```

### **2. Удаление finalizer:**
```bash
# Удаление конкретного finalizer
kubectl patch deployment nginx-deployment --type='json' -p='[{"op": "remove", "path": "/metadata/finalizers/0"}]'

# Удаление всех finalizers (ОСТОРОЖНО!)
kubectl patch deployment nginx-deployment --type='merge' -p='{"metadata":{"finalizers":null}}'
```

### **3. Безопасное удаление stuck объектов:**
```bash
# Проверка причины stuck состояния
kubectl describe <resource-type> <resource-name> | grep -A 20 Events

# Анализ finalizers
kubectl get <resource-type> <resource-name> -o yaml | grep -A 10 finalizers

# Удаление finalizer только после cleanup
kubectl patch <resource-type> <resource-name> --type='merge' -p='{"metadata":{"finalizers":null}}'
```

## 🎯 **Архитектура Finalizers:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Finalizers Workflow                     │
├─────────────────────────────────────────────────────────────┤
│  Object Deletion Request                                    │
│  ├── kubectl delete object                                 │
│  ├── API Server receives request                           │
│  └── DeletionTimestamp set                                 │
├─────────────────────────────────────────────────────────────┤
│  Finalizer Processing                                       │
│  ├── Object marked for deletion                            │
│  ├── Controllers detect deletionTimestamp                  │
│  ├── Cleanup operations executed                           │
│  └── Finalizers removed one by one                         │
├─────────────────────────────────────────────────────────────┤
│  Physical Deletion                                          │
│  ├── All finalizers removed                                │
│  ├── Object deleted from etcd                              │
│  └── Resources cleaned up                                  │
├─────────────────────────────────────────────────────────────┤
│  Common Finalizers                                          │
│  ├── kubernetes.io/pv-protection                          │
│  ├── kubernetes.io/pvc-protection                         │
│  ├── resources-finalizer.argocd.argoproj.io               │
│  └── Custom application finalizers                         │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Best Practices для Finalizers:**

### **1. Мониторинг:**
```bash
# Регулярная проверка stuck объектов
kubectl get all --all-namespaces -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "cluster-scope")"'

# Мониторинг finalizer events
kubectl get events --all-namespaces --field-selector reason=FinalizerUpdateFailed

# Проверка долго висящих объектов
kubectl get all --all-namespaces -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null and (now - (.metadata.deletionTimestamp | fromdateiso8601) > 3600)) | "\(.kind)/\(.metadata.name) stuck for > 1 hour"'
```

### **2. Troubleshooting:**
```bash
# Анализ stuck namespace
kubectl get namespace <stuck-namespace> -o yaml
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n <stuck-namespace>

# Проверка controller логов
kubectl logs -n kube-system -l app=controller-manager | grep finalizer

# ArgoCD finalizer issues
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep finalizer
```

## 🚨 **Troubleshooting Finalizers:**

### **1. Stuck объекты:**
```bash
# Поиск stuck объектов
kubectl get all --all-namespaces --field-selector metadata.deletionTimestamp!=null

# Анализ причин
kubectl describe <resource-type> <resource-name> | grep -A 20 Events

# Проверка controller состояния
kubectl get pods -n kube-system | grep controller
```

### **2. Namespace не удаляется:**
```bash
# Проверка ресурсов в namespace
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n <namespace>

# Принудительное удаление (ОСТОРОЖНО!)
kubectl get namespace <namespace> -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -
```

### **3. ArgoCD finalizer проблемы:**
```bash
# ArgoCD Application stuck
kubectl patch application <app-name> -n argocd --type='merge' -p='{"metadata":{"finalizers":null}}'

# Проверка ArgoCD controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## 🎯 **Best Practices для Finalizers:**

### **1. Мониторинг:**
- Регулярно проверяйте stuck объекты
- Мониторьте finalizer события
- Отслеживайте время удаления объектов

### **2. Безопасность:**
- Никогда не удаляйте finalizers без понимания последствий
- Всегда проверяйте причину stuck состояния
- Выполняйте cleanup операции перед удалением finalizers

### **3. Отладка:**
- Анализируйте controller логи
- Проверяйте зависимые ресурсы
- Используйте kubectl describe для анализа событий

### **4. Профилактика:**
- Правильно реализуйте cleanup логику в controllers
- Тестируйте сценарии удаления
- Документируйте custom finalizers

**Finalizers — это важный механизм для обеспечения корректного cleanup ресурсов в Kubernetes!**
