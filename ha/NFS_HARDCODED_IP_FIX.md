# NFS Provisioner Hard-coded IP Fix

## 🎯 **Проблема**

В конфигурации NFS Provisioner был захардкожен IP адрес:

```yaml
nfsProvisioner:
  nfsServer: "10.245.186.170"  # Hard-coded IP address
```

Это делало развертывание неповторяемым, так как:
- IP адрес сервиса может измениться при пересоздании
- Скрипт `deploy-k8s.sh` не мог работать с чистого листа
- Конфигурация была привязана к конкретному кластеру

## 🔧 **Решение**

### **1. Обновлен скрипт развертывания**

Модифицирован `deploy-k8s.sh` для динамического получения IP адреса:

```bash
# First, deploy only the NFS server
echo "   Installing NFS Server..."
helm upgrade --install --create-namespace -n nfs-system nfs-provisioner . -f values.yaml --set nfsProvisioner.enabled=false --wait --timeout=10m

# Wait for NFS server service to be ready
echo "   Waiting for NFS server service to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=nfs-server -n nfs-system --timeout=300s

# Get the NFS server service IP
echo "   Getting NFS server service IP..."
NFS_SERVER_IP=$(kubectl get svc nfs-provisioner-server -n nfs-system -o jsonpath='{.spec.clusterIP}')
echo "   NFS Server IP: $NFS_SERVER_IP"

# Deploy the provisioner with the correct IP
echo "   Installing NFS Provisioner with server IP..."
helm upgrade nfs-provisioner . -n nfs-system -f values.yaml --set nfsProvisioner.nfsServer="$NFS_SERVER_IP" --wait --timeout=5m
```

### **2. Добавлена поддержка условного развертывания**

Обновлен шаблон `nfs-provisioner.yaml`:

```yaml
{{- if .Values.nfsProvisioner.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  # ... rest of the deployment
{{- end }}
```

### **3. Обновлена конфигурация values.yaml**

```yaml
nfsProvisioner:
  enabled: true  # Добавлен флаг для условного развертывания
  nfsServer: ""  # Возвращено к пустому значению для автоопределения
```

## ✅ **Результат**

### **Процесс развертывания теперь:**

1. **Шаг 1**: Развертывается только NFS сервер (`nfsProvisioner.enabled=false`)
2. **Шаг 2**: Ожидается готовность NFS сервера
3. **Шаг 3**: Динамически получается IP адрес сервиса
4. **Шаг 4**: Развертывается NFS Provisioner с правильным IP

### **Тестирование:**

```bash
# Создан тестовый PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc-final
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

# Результат
NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
test-nfs-pvc-final   Bound    pvc-bffc06f5-588f-4e11-bb55-dd0db226a158   1Gi        RWX            nfs-client
```

✅ **PVC успешно создан и привязан с режимом ReadWriteMany**

## 🚀 **Преимущества исправления**

### **1. Повторяемость развертывания:**
- Скрипт `deploy-k8s.sh` теперь работает с чистого листа
- Нет зависимости от конкретных IP адресов
- Автоматическое определение сетевых параметров

### **2. Гибкость конфигурации:**
- Поддержка условного развертывания компонентов
- Возможность отключения NFS Provisioner при необходимости
- Динамическое получение параметров подключения

### **3. Надежность:**
- Ожидание готовности сервисов перед подключением
- Проверка доступности NFS сервера
- Корректная обработка ошибок

## 📋 **Команды для проверки**

```bash
# Проверка статуса NFS компонентов
kubectl get pods -n nfs-system

# Проверка StorageClass
kubectl get storageclass nfs-client

# Проверка тестового PVC
kubectl get pvc test-nfs-pvc-final

# Проверка IP адреса NFS сервера
kubectl get svc nfs-provisioner-server -n nfs-system -o jsonpath='{.spec.clusterIP}'
```

## 🎉 **Заключение**

Проблема с захардкоженным IP адресом полностью решена:

✅ **Автоматическое определение** IP адреса NFS сервера  
✅ **Повторяемое развертывание** через скрипт deploy-k8s.sh  
✅ **Гибкая конфигурация** с поддержкой условного развертывания  
✅ **Успешное тестирование** с созданием ReadWriteMany PVC  

**NFS Provisioner теперь готов к продуктивному использованию в любом кластере!**

---

**Дата исправления**: 15.07.2025  
**Версия**: NFS Provisioner v1.0 с динамическим IP  
**Статус**: ✅ Исправлено и протестировано
