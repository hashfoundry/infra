# Grafana Storage Upgrade Solution

## 🚨 **Проблема**

При обновлении Grafana через Helm возникает проблема с ReadWriteOnce (RWO) persistent volume:
- Новый pod не может запуститься, пока старый использует PVC
- Helm upgrade зависает в ожидании готовности нового пода
- Требуется ручное удаление ReplicaSet для освобождения PVC

## 🎯 **Корень проблемы**

### **ReadWriteOnce ограничения:**
- RWO volume может быть примонтирован только к одному узлу одновременно
- При rolling update новый pod не может получить доступ к PVC, пока старый pod активен
- Helm ждет готовности нового пода перед удалением старого

### **Текущая конфигурация:**
```yaml
persistence:
  enabled: true
  type: pvc
  size: 10Gi
  accessModes:
    - ReadWriteOnce  # ← Проблема здесь
```

## 💡 **Решения**

### **РЕШЕНИЕ 1: Изменение стратегии развертывания (Рекомендуемое)**

#### **Изменить на Recreate strategy:**
```yaml
# В values.yaml для Grafana
deploymentStrategy:
  type: Recreate  # Вместо RollingUpdate

persistence:
  enabled: true
  type: pvc
  size: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: do-block-storage
```

#### **Преимущества:**
- ✅ Старый pod удаляется перед созданием нового
- ✅ PVC освобождается автоматически
- ✅ Нет конфликтов с RWO volumes
- ✅ Простое решение без изменения storage

#### **Недостатки:**
- ⚠️ Кратковременный downtime (30-60 секунд)
- ⚠️ Нет rolling update

---

### **РЕШЕНИЕ 2: Переход на ReadWriteMany (NFS)**

#### **Использовать NFS для shared storage:**
```yaml
# Создать NFS-based StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-grafana
provisioner: nfs.csi.k8s.io
parameters:
  server: <NFS_SERVER_IP>
  share: /grafana-data
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

```yaml
# В values.yaml для Grafana
persistence:
  enabled: true
  type: pvc
  size: 10Gi
  accessModes:
    - ReadWriteMany  # ← Поддерживает multiple pods
  storageClassName: nfs-grafana
```

#### **Преимущества:**
- ✅ Поддержка rolling updates
- ✅ Нет downtime при обновлениях
- ✅ Возможность horizontal scaling Grafana

#### **Недостатки:**
- ⚠️ Требует настройки NFS сервера
- ⚠️ Дополнительная сложность
- ⚠️ Потенциальные проблемы с производительностью

---

### **РЕШЕНИЕ 3: Автоматизация через Helm Hooks**

#### **Pre-upgrade hook для очистки:**
```yaml
# templates/pre-upgrade-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: grafana-pre-upgrade-cleanup
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      serviceAccountName: grafana-upgrade-sa
      containers:
      - name: cleanup
        image: bitnami/kubectl:latest
        command:
        - /bin/sh
        - -c
        - |
          echo "Scaling down Grafana deployment..."
          kubectl scale deployment grafana --replicas=0 -n monitoring
          echo "Waiting for pods to terminate..."
          kubectl wait --for=delete pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=120s
          echo "Cleanup completed"
      restartPolicy: Never
```

#### **ServiceAccount для cleanup:**
```yaml
# templates/upgrade-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: grafana-upgrade-sa
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: grafana-upgrade-role
  namespace: monitoring
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "patch", "update"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: grafana-upgrade-binding
  namespace: monitoring
subjects:
- kind: ServiceAccount
  name: grafana-upgrade-sa
  namespace: monitoring
roleRef:
  kind: Role
  name: grafana-upgrade-role
  apiGroup: rbac.authorization.k8s.io
```

---

### **РЕШЕНИЕ 4: Использование StatefulSet вместо Deployment**

#### **StatefulSet конфигурация:**
```yaml
# В values.yaml
useStatefulSet: true

persistence:
  enabled: true
  size: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: do-block-storage

# StatefulSet автоматически управляет PVC lifecycle
```

#### **Преимущества:**
- ✅ Правильное управление persistent storage
- ✅ Ordered deployment/scaling
- ✅ Stable network identity

---

## 🚀 **Рекомендуемое решение: Recreate Strategy**

### **Почему это лучший выбор:**
1. **Простота**: Минимальные изменения в конфигурации
2. **Надежность**: Нет сложной логики с hooks
3. **Совместимость**: Работает с существующим storage
4. **Downtime**: Приемлемый для monitoring системы (30-60 сек)

### **Реализация:**

#### **1. Обновить values.yaml:**
```yaml
# ha/k8s/addons/monitoring/grafana/values.yaml
deploymentStrategy:
  type: Recreate

persistence:
  enabled: true
  type: pvc
  size: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: do-block-storage
  
# Добавить resource limits для быстрого старта
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Оптимизировать readiness probe
readinessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

#### **2. Создать upgrade script:**
```bash
#!/bin/bash
# ha/k8s/addons/monitoring/grafana/upgrade.sh

set -e

echo "🔄 Starting Grafana upgrade with Recreate strategy..."

# Проверить текущий статус
echo "📊 Current Grafana status:"
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Выполнить upgrade
echo "⬆️ Upgrading Grafana..."
helm upgrade grafana . -n monitoring -f values.yaml

# Ждать готовности
echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring

# Проверить статус
echo "✅ Grafana upgrade completed!"
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl get pvc -n monitoring | grep grafana

echo "🌐 Grafana should be available at: https://grafana.hashfoundry.local"
```

#### **3. Обновить Makefile:**
```makefile
# ha/k8s/addons/monitoring/grafana/Makefile

.PHONY: upgrade-safe
upgrade-safe:
	@echo "🔄 Performing safe Grafana upgrade with Recreate strategy..."
	@chmod +x upgrade.sh
	@./upgrade.sh

.PHONY: status
status:
	@echo "📊 Grafana Status:"
	@kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
	@kubectl get pvc -n monitoring | grep grafana
	@kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.strategy.type}'
```

## 🧪 **Тестирование решения**

### **1. Проверить текущую стратегию:**
```bash
kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.strategy.type}'
```

### **2. Применить изменения:**
```bash
cd ha/k8s/addons/monitoring/grafana
make upgrade-safe
```

### **3. Мониторить процесс:**
```bash
# В отдельном терминале
watch kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

### **4. Проверить результат:**
```bash
# Проверить стратегию
kubectl get deployment grafana -n monitoring -o yaml | grep -A 2 strategy

# Проверить PVC
kubectl get pvc -n monitoring | grep grafana

# Проверить доступность
curl -k https://grafana.hashfoundry.local/api/health
```

## 📋 **Альтернативные команды для экстренных случаев**

### **Если upgrade все еще зависает:**
```bash
# 1. Принудительно удалить старый ReplicaSet
kubectl delete rs -n monitoring -l app.kubernetes.io/name=grafana

# 2. Или полностью пересоздать deployment
kubectl delete deployment grafana -n monitoring
helm upgrade grafana . -n monitoring -f values.yaml

# 3. Проверить PVC статус
kubectl describe pvc grafana -n monitoring
```

### **Для отката:**
```bash
# Откатить к предыдущей версии
helm rollback grafana -n monitoring

# Или к конкретной ревизии
helm rollback grafana 1 -n monitoring
```

## 🎯 **Заключение**

**Recreate strategy** - это оптимальное решение для Grafana с RWO storage:
- ✅ Решает проблему с PVC conflicts
- ✅ Простое в реализации и поддержке
- ✅ Минимальный downtime (30-60 секунд)
- ✅ Совместимо с существующей инфраструктурой

**Следующие шаги:**
1. Обновить values.yaml с Recreate strategy
2. Протестировать upgrade процесс
3. Создать документацию для команды
4. Настроить мониторинг upgrade процесса
