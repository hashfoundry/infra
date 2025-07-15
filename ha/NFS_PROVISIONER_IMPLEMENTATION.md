# NFS Provisioner для ArgoCD HA - Инструкция по развертыванию

## 🎯 **Назначение**

Данная инструкция описывает развертывание платформо-независимого NFS Storage Provisioner для обеспечения ReadWriteMany (RWX) томов в ArgoCD HA кластере.

## 📋 **Требования**

### **Системные требования:**
- Kubernetes кластер версии 1.19+
- Helm 3.0+
- kubectl с доступом к кластеру
- Минимум 3 worker узла для HA

### **Ресурсы:**
- **NFS Server**: 1 CPU, 2Gi RAM, 50Gi storage
- **NFS Provisioner**: 100m CPU, 128Mi RAM
- **Общий объем**: ~52Gi дискового пространства

## 🏗️ **Архитектура решения**

```
┌─────────────────────────────────────────────────────────────┐
│                    NFS Storage Architecture                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   NFS Server    │    │ NFS Provisioner │                │
│  │                 │    │                 │                │
│  │ • 50Gi Storage  │◄───┤ • Auto PV       │                │
│  │ • /exports      │    │ • Dynamic       │                │
│  │ • NFSv3/v4      │    │ • Subdir        │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           └───────────────────────┼────────────────────────│
│                                   │                        │
│  ┌─────────────────────────────────▼─────────────────────┐  │
│  │              StorageClass: nfs-client                │  │
│  │                                                     │  │
│  │ • Provisioner: nfs-provisioner/nfs                 │  │
│  │ • Access Modes: ReadWriteMany                       │  │
│  │ • Reclaim Policy: Retain                            │  │
│  └─────────────────────────────────────────────────────┘  │
│                                   │                        │
│  ┌─────────────────────────────────▼─────────────────────┐  │
│  │                 Applications                        │  │
│  │                                                     │  │
│  │ • ArgoCD HA (multiple replicas)                    │  │
│  │ • Shared configuration                              │  │
│  │ • Persistent data                                   │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Развертывание**

### **Вариант A: Интеграция в новый кластер (рекомендуется)**

Этот вариант подходит для развертывания NFS Provisioner вместе с новым HA кластером.

#### **Шаг 1: Подготовка окружения**
```bash
# Клонирование репозитория
git clone https://github.com/hashfoundry/infra.git
cd infra/ha

# Инициализация конфигурации
./init.sh

# Настройка переменных окружения
nano .env
# Установите ваш DO_TOKEN и другие параметры
```

#### **Шаг 2: Развертывание инфраструктуры**
```bash
# Полное развертывание HA кластера с ArgoCD
./deploy.sh
```

#### **Шаг 3: Развертывание NFS Provisioner**
```bash
# Переход в директорию NFS Provisioner
cd k8s/addons/nfs-provisioner

# Установка NFS Provisioner
make install
```

#### **Шаг 4: Проверка развертывания**
```bash
# Проверка статуса подов
kubectl get pods -n nfs-system

# Проверка StorageClass
kubectl get storageclass nfs-client

# Проверка сервисов
kubectl get svc -n nfs-system
```

**Ожидаемый результат:**
```
NAME                                           READY   STATUS    RESTARTS   AGE
nfs-provisioner-provisioner-xxxxx-xxxxx        1/1     Running   0          2m
nfs-provisioner-server-xxxxx-xxxxx             1/1     Running   0          2m

NAME                          PROVISIONER           RECLAIMPOLICY   VOLUMEBINDINGMODE
nfs-client                    nfs-provisioner/nfs   Retain          Immediate
```

---

### **Вариант B: Добавление в существующий кластер**

Этот вариант подходит для добавления NFS Provisioner в уже работающий кластер.

#### **Шаг 1: Подготовка**
```bash
# Убедитесь, что kubectl настроен для вашего кластера
kubectl cluster-info

# Клонирование только необходимых файлов
git clone https://github.com/hashfoundry/infra.git
cd infra/ha/k8s/addons/nfs-provisioner
```

#### **Шаг 2: Настройка конфигурации**
```bash
# Проверьте values.yaml и при необходимости измените параметры
nano values.yaml

# Основные параметры для настройки:
# - nfsServer.storage.size (по умолчанию 50Gi)
# - nfsServer.storage.storageClass (по умолчанию do-block-storage)
# - nfsProvisioner.resources (лимиты CPU/памяти)
```

#### **Шаг 3: Установка**
```bash
# Создание namespace
kubectl create namespace nfs-system

# Установка через Helm
helm install nfs-provisioner . \
  --namespace nfs-system \
  --create-namespace \
  --wait \
  --timeout 10m
```

#### **Шаг 4: Проверка установки**
```bash
# Проверка статуса
kubectl get pods -n nfs-system
kubectl get storageclass nfs-client
kubectl get pv | grep nfs-client
```

#### **Шаг 5: Тестирование (опционально)**
```bash
# Создание тестового PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

# Проверка статуса PVC
kubectl get pvc test-nfs-pvc

# Очистка тестовых ресурсов
kubectl delete pvc test-nfs-pvc
```

## 🔧 **Конфигурация ArgoCD для использования NFS**

После успешного развертывания NFS Provisioner, настройте ArgoCD для использования RWX томов:

### **Обновление ArgoCD values.yaml:**
```yaml
# В ha/k8s/addons/argo-cd/values.yaml добавьте:

# Для Application Controller
controller:
  volumes:
    - name: argocd-repo-server-tls-certs
      persistentVolumeClaim:
        claimName: argocd-repo-server-tls-certs
  volumeMounts:
    - name: argocd-repo-server-tls-certs
      mountPath: /app/config/tls

# Для Repo Server  
repoServer:
  volumes:
    - name: argocd-repo-server-tls-certs
      persistentVolumeClaim:
        claimName: argocd-repo-server-tls-certs
  volumeMounts:
    - name: argocd-repo-server-tls-certs
      mountPath: /app/config/tls

# Создание PVC для общих данных
extraObjects:
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: argocd-repo-server-tls-certs
      namespace: argocd
    spec:
      accessModes:
        - ReadWriteMany
      storageClassName: nfs-client
      resources:
        requests:
          storage: 1Gi
```

### **Применение изменений:**
```bash
# Обновление ArgoCD
cd ha/k8s/addons/argo-cd
helm upgrade argocd . -n argocd -f values.yaml
```

## 🛠️ **Управление**

### **Мониторинг:**
```bash
# Статус компонентов
kubectl get pods -n nfs-system
kubectl get storageclass nfs-client
kubectl get pv | grep nfs-client

# Логи NFS Server
kubectl logs -n nfs-system deployment/nfs-provisioner-server

# Логи NFS Provisioner
kubectl logs -n nfs-system deployment/nfs-provisioner-provisioner

# Проверка экспортов NFS
kubectl exec -n nfs-system deployment/nfs-provisioner-server -- showmount -e localhost
```

### **Обновление:**
```bash
cd ha/k8s/addons/nfs-provisioner

# Обновление конфигурации
helm upgrade nfs-provisioner . --namespace nfs-system

# Или через Makefile
make upgrade
```

### **Масштабирование:**
```bash
# Увеличение размера NFS Server storage
kubectl patch pvc nfs-provisioner-server-pvc -n nfs-system -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# Изменение ресурсов NFS Provisioner
helm upgrade nfs-provisioner . --namespace nfs-system --set nfsProvisioner.resources.limits.memory=256Mi
```

### **Удаление:**
```bash
# Через Makefile
cd ha/k8s/addons/nfs-provisioner
make uninstall

# Или через Helm
helm uninstall nfs-provisioner -n nfs-system
kubectl delete namespace nfs-system
```

## 🔍 **Troubleshooting**

### **Проблема: Pod в состоянии ContainerCreating**
```bash
# Проверка событий
kubectl describe pod -n nfs-system <pod-name>

# Частые причины:
# 1. DNS resolution проблемы
# 2. Недостаточные привилегии
# 3. Недоступность NFS сервера
```

**Решение:**
```bash
# Проверка DNS
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup nfs-provisioner-server.nfs-system.svc.cluster.local

# Проверка доступности NFS
kubectl run test-nfs --image=alpine --rm -it --restart=Never -- sh -c "apk add --no-cache nfs-utils && showmount -e nfs-provisioner-server.nfs-system.svc.cluster.local"
```

### **Проблема: PVC в состоянии Pending**
```bash
# Проверка событий PVC
kubectl describe pvc <pvc-name>

# Проверка статуса provisioner
kubectl get pods -n nfs-system
kubectl logs -n nfs-system deployment/nfs-provisioner-provisioner
```

### **Проблема: Permission denied при монтировании**
```bash
# Проверка NFS экспортов
kubectl exec -n nfs-system deployment/nfs-provisioner-server -- cat /etc/exports

# Проверка прав доступа
kubectl exec -n nfs-system deployment/nfs-provisioner-server -- ls -la /exports
```

## 📊 **Технические характеристики**

### **NFS Server:**
- **Image**: `k8s.gcr.io/volume-nfs:0.8`
- **Ports**: 2049 (NFS), 20048 (mountd), 111 (portmap)
- **Storage**: Использует PVC с облачным storage
- **Экспорты**: `/` и `/exports` с правами `rw,sync,no_subtree_check,no_root_squash,insecure`

### **NFS Provisioner:**
- **Image**: `k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2`
- **Provisioner Name**: `nfs-provisioner/nfs`
- **Subdir Pattern**: `${.PVC.namespace}-${.PVC.name}-${.PV.name}`

### **StorageClass:**
- **Name**: `nfs-client`
- **Access Modes**: ReadWriteMany (RWX)
- **Reclaim Policy**: Retain
- **Volume Binding Mode**: Immediate
- **Allow Volume Expansion**: true

## 🎯 **Использование в приложениях**

### **Пример PVC для приложения:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-shared-storage
  namespace: my-namespace
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 5Gi
```

### **Пример использования в Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3  # Множественные реплики могут использовать один том
  template:
    spec:
      containers:
      - name: app
        image: my-app:latest
        volumeMounts:
        - name: shared-data
          mountPath: /shared
      volumes:
      - name: shared-data
        persistentVolumeClaim:
          claimName: my-app-shared-storage
```

## ✅ **Проверка готовности**

После завершения развертывания выполните следующие проверки:

```bash
# 1. Все поды запущены
kubectl get pods -n nfs-system
# Ожидаемый результат: 2/2 подов в статусе Running

# 2. StorageClass доступен
kubectl get storageclass nfs-client
# Ожидаемый результат: StorageClass существует

# 3. Тест создания PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-rwx-pvc
spec:
  accessModes: [ReadWriteMany]
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

# 4. Проверка привязки PVC
kubectl get pvc test-rwx-pvc
# Ожидаемый результат: STATUS = Bound

# 5. Очистка тестовых ресурсов
kubectl delete pvc test-rwx-pvc
```

**✅ Если все проверки прошли успешно, NFS Provisioner готов к использованию!**

---

**Версия документа**: 2.0  
**Дата обновления**: 15.07.2025  
**Статус**: ✅ Готов к использованию
