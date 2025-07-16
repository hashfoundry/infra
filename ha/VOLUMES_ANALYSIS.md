# HashFoundry Infrastructure - Volumes Analysis

## 🎯 **Обзор**
Анализ всех volumes в HashFoundry Infrastructure: их создание, расположение, доступ и управление.

## 📊 **Типы Volumes в проекте**

### **1. NFS Server Volume (Primary Storage)**

#### **Создание:**
```yaml
# ha/k8s/addons/nfs-provisioner/templates/nfs-server.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-server-storage
  namespace: nfs-provisioner
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: do-block-storage
```

#### **Кто создает:**
- **ArgoCD** через application `nfs-provisioner`
- **Kubernetes** автоматически создает PV при создании PVC
- **DigitalOcean CSI Driver** создает Block Storage volume

#### **Где располагается:**
- **DigitalOcean Block Storage** - в том же регионе что и кластер (fra1)
- **Физическое расположение** - DigitalOcean datacenter Frankfurt
- **Attachment** - к узлу где запущен NFS Server pod

#### **Доступ:**
```yaml
# Прямой доступ к volume
Pod: nfs-server-xxx (namespace: nfs-provisioner)
Mount: /exports

# Сетевой доступ через NFS
Service: nfs-server-service (ClusterIP)
Port: 2049 (NFS protocol)
```

### **2. ArgoCD Redis HA Volumes**

#### **Создание:**
```yaml
# Автоматически создается ArgoCD Helm chart
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 8Gi
    storageClassName: do-block-storage
```

#### **Количество volumes:**
- **3 volumes** для Redis HA (по одному на каждый Redis instance)
- **Имена**: `data-argocd-redis-ha-server-0`, `data-argocd-redis-ha-server-1`, `data-argocd-redis-ha-server-2`

#### **Кто создает:**
- **ArgoCD Helm chart** при развертывании Redis HA
- **StatefulSet controller** создает PVC для каждого replica
- **DigitalOcean CSI Driver** создает Block Storage volumes

#### **Где располагаются:**
- **DigitalOcean Block Storage** - регион fra1
- **Attachment** - каждый volume прикреплен к узлу с соответствующим Redis pod

#### **Доступ:**
```yaml
# Каждый Redis pod имеет эксклюзивный доступ к своему volume
Pods:
  - argocd-redis-ha-server-0 → data-argocd-redis-ha-server-0
  - argocd-redis-ha-server-1 → data-argocd-redis-ha-server-1  
  - argocd-redis-ha-server-2 → data-argocd-redis-ha-server-2

Mount path: /data
Access mode: ReadWriteOnce (эксклюзивный доступ)
```

### **3. Application Volumes (через NFS)**

#### **Создание:**
```yaml
# ha/k8s/apps/hashfoundry-react/values.yaml
persistence:
  enabled: true
  storageClass: "nfs-client"
  accessMode: ReadWriteMany
  size: 1Gi
```

#### **Кто создает:**
- **Application Helm charts** запрашивают PVC
- **NFS Provisioner** автоматически создает PV
- **Subdirectory** создается на NFS Server volume

#### **Где располагаются:**
- **Логически** - как subdirectory на NFS Server volume
- **Физически** - на том же DigitalOcean Block Storage что и NFS Server
- **Путь** - `/exports/<namespace>-<pvc-name>-<pv-name>/`

#### **Доступ:**
```yaml
# Множественный доступ через NFS
Access mode: ReadWriteMany
Pods: Любые поды в кластере с соответствующим PVC
Protocol: NFS v4
```

## 🏗️ **Архитектура Storage**

### **Схема volumes:**
```
DigitalOcean Block Storage (fra1)
├── NFS Server Volume (50Gi)
│   ├── /exports/
│   │   ├── default-hashfoundry-react-pvc-xxx/
│   │   ├── argocd-data-pvc-xxx/
│   │   └── other-app-volumes/
│   └── NFS Server Pod (nfs-provisioner namespace)
│
├── Redis HA Volume 0 (8Gi)
│   └── argocd-redis-ha-server-0 pod
│
├── Redis HA Volume 1 (8Gi)
│   └── argocd-redis-ha-server-1 pod
│
└── Redis HA Volume 2 (8Gi)
    └── argocd-redis-ha-server-2 pod
```

## 🔐 **Безопасность и доступ**

### **1. Network Level Security:**
```yaml
# NFS доступ ограничен кластером
Service: nfs-server-service
Type: ClusterIP (внутренний доступ только)
Namespace: nfs-provisioner
```

### **2. RBAC для NFS Provisioner:**
```yaml
# ha/k8s/addons/nfs-provisioner/templates/rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nfs-provisioner
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update"]
```

### **3. Pod Security:**
```yaml
# NFS Server pod security context
securityContext:
  privileged: true  # Требуется для NFS server
  capabilities:
    add: ["SYS_ADMIN", "SETPCAP"]
```

### **4. Volume Access Control:**
```yaml
# Redis volumes - эксклюзивный доступ
accessModes: ["ReadWriteOnce"]

# NFS volumes - множественный доступ
accessModes: ["ReadWriteMany"]
```

## 💾 **Storage Classes**

### **1. DigitalOcean Block Storage:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: do-block-storage
provisioner: dobs.csi.digitalocean.com
parameters:
  type: pd-ssd
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### **2. NFS Client Storage:**
```yaml
# ha/k8s/addons/nfs-provisioner/templates/storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: cluster.local/nfs-provisioner
parameters:
  archiveOnDelete: "false"
reclaimPolicy: Delete
allowVolumeExpansion: true
```

## 📈 **Мониторинг и управление**

### **Команды для проверки volumes:**
```bash
# Все PersistentVolumes
kubectl get pv

# Все PersistentVolumeClaims
kubectl get pvc --all-namespaces

# DigitalOcean volumes
doctl compute volume list

# NFS exports
kubectl exec -it <nfs-server-pod> -n nfs-provisioner -- showmount -e localhost

# Использование дискового пространства
kubectl exec -it <nfs-server-pod> -n nfs-provisioner -- df -h /exports
```

### **Статус volumes:**
```bash
# Проверка статуса PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Проверка events
kubectl get events --field-selector involvedObject.kind=PersistentVolumeClaim

# Проверка attachment к узлам
kubectl get volumeattachment
```

## 🔄 **Lifecycle Management**

### **1. Создание volume:**
```
1. Application создает PVC
2. Storage Class определяет provisioner
3. Provisioner создает PV (NFS или Block Storage)
4. Kubernetes связывает PVC с PV
5. Pod монтирует volume
```

### **2. Backup и восстановление:**
```bash
# NFS volumes backup (через NFS Server)
kubectl exec -it <nfs-server-pod> -n nfs-provisioner -- tar -czf /backup/exports-backup.tar.gz /exports

# Redis volumes backup (через Redis)
kubectl exec -it argocd-redis-ha-server-0 -n argocd -- redis-cli BGSAVE
```

### **3. Удаление volumes:**
```bash
# Через cleanup.sh script
./cleanup.sh  # Удаляет все PVC и PV

# Вручную
kubectl delete pvc <pvc-name> -n <namespace>
doctl compute volume delete <volume-id>
```

## 💰 **Стоимость volumes**

### **DigitalOcean Block Storage pricing:**
```
- $0.10/GB/месяц
- NFS Server volume (50Gi): $5/месяц
- Redis HA volumes (3 × 8Gi): $2.40/месяц
- Итого: ~$7.40/месяц
```

### **Оптимизация затрат:**
- **Автоматическое удаление** через cleanup.sh
- **Reclaim Policy: Delete** - volumes удаляются с PVC
- **Мониторинг использования** для оптимизации размеров

## ⚠️ **Важные особенности**

### **1. NFS Server Single Point of Failure:**
- **NFS Server pod** - единственная точка доступа к shared storage
- **Mitigation** - быстрое восстановление через Kubernetes
- **Data persistence** - данные сохраняются на Block Storage

### **2. Volume Attachment Limitations:**
- **Block Storage volumes** могут быть прикреплены только к одному узлу
- **NFS решает проблему** множественного доступа
- **Pod scheduling** учитывает volume constraints

### **3. Performance Considerations:**
- **Block Storage** - высокая производительность для Redis
- **NFS** - сетевые задержки для shared storage
- **SSD storage** - используется для всех volumes

## 🎉 **Заключение**

**Volumes в HashFoundry Infrastructure организованы по hybrid модели:**

✅ **Block Storage** для высокопроизводительных workloads (Redis HA)  
✅ **NFS Storage** для shared access между подами  
✅ **Автоматическое управление** через Kubernetes и ArgoCD  
✅ **Безопасность** через RBAC и network isolation  
✅ **Cost optimization** через автоматическое удаление  
✅ **Monitoring** через kubectl и doctl команды  

**Система storage обеспечивает надежность, производительность и экономичность!**

---

**Дата анализа**: 16.07.2025  
**Общий объем storage**: ~74Gi  
**Месячная стоимость**: ~$7.40
