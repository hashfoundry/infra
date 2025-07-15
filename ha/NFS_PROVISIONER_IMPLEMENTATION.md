# NFS Provisioner Implementation Guide

## 🎯 **Цель**
Практическое руководство по реализации NFS Provisioner для ArgoCD HA кластера с полными конфигурационными файлами и инструкциями по развертыванию.

## 📋 **Архитектура решения**

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ ArgoCD Pod  │  │ ArgoCD Pod  │  │ ArgoCD Pod  │          │
│  │             │  │             │  │             │          │
│  │ /app/cache  │  │ /app/cache  │  │ /app/cache  │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          │                                  │
│  ┌──────────────────────┼──────────────────────────────┐    │
│  │       NFS Client     │         Provisioner          │    │
│  │                      │                              │    │
│  │  ┌───────────────────┼─────────────────────────┐    │    │
│  │  │                   │      NFS Server         │    │    │
│  │  │                   │                         │    │    │
│  │  │                   └─► /exports              │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └───────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
                          │
                          │
                ┌─────────┼─────────┐
                │  DigitalOcean     │
                │  Block Storage    │
                │    (50GB SSD)     │
                └───────────────────┘
```

## 🚀 **Полная реализация**

### **Структура файлов:**
```
ha/k8s/addons/nfs-provisioner/
├── Chart.yaml
├── values.yaml
├── Makefile
├── README.md
└── templates/
    ├── _helpers.tpl
    ├── nfs-server.yaml
    ├── nfs-provisioner.yaml
    ├── storage-class.yaml
    ├── rbac.yaml
    └── service.yaml
```

### **1. Chart.yaml**
```yaml
apiVersion: v2
name: nfs-provisioner
description: Platform-agnostic NFS storage provisioner for ArgoCD HA
type: application
version: 0.1.0
appVersion: "1.0"
keywords:
  - nfs
  - storage
  - provisioner
  - argocd
  - ha
home: https://github.com/hashfoundry/infra
sources:
  - https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner
maintainers:
  - name: HashFoundry Team
    email: team@hashfoundry.com
```

### **2. values.yaml**
```yaml
# Platform-specific storage class for NFS server backing storage
platformStorageClass: "do-block-storage"

# NFS Server configuration
nfsServer:
  image: k8s.gcr.io/volume-nfs:0.8
  storage: 50Gi
  replicas: 1
  
  # Resource limits for NFS server
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
  
  # Node selector for NFS server placement
  nodeSelector: {}
  
  # Tolerations for NFS server
  tolerations: []
  
  # Affinity rules
  affinity: {}

# NFS Client Provisioner configuration
nfsProvisioner:
  image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
  
  # Storage class configuration
  storageClass:
    name: nfs-client
    defaultClass: false
    reclaimPolicy: Retain
    volumeBindingMode: Immediate
    allowVolumeExpansion: true
  
  # Resource limits for provisioner
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 10m
      memory: 16Mi
  
  # Node selector for provisioner placement
  nodeSelector: {}
  
  # Tolerations for provisioner
  tolerations: []

# Service configuration
service:
  type: ClusterIP
  ports:
    nfs: 2049
    mountd: 20048
    rpcbind: 111

# Security context
securityContext:
  privileged: true
  runAsUser: 0
  runAsGroup: 0

# Monitoring
monitoring:
  enabled: false
  serviceMonitor:
    enabled: false
    interval: 30s
    scrapeTimeout: 10s

# Backup configuration
backup:
  enabled: false
  schedule: "0 2 * * *"
  retention: 7
```

### **3. templates/_helpers.tpl**
```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "nfs-provisioner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nfs-provisioner.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nfs-provisioner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nfs-provisioner.labels" -}}
helm.sh/chart: {{ include "nfs-provisioner.chart" . }}
{{ include "nfs-provisioner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nfs-provisioner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nfs-provisioner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
NFS Server labels
*/}}
{{- define "nfs-provisioner.nfsServerLabels" -}}
{{ include "nfs-provisioner.labels" . }}
app.kubernetes.io/component: nfs-server
{{- end }}

{{/*
NFS Provisioner labels
*/}}
{{- define "nfs-provisioner.provisionerLabels" -}}
{{ include "nfs-provisioner.labels" . }}
app.kubernetes.io/component: nfs-provisioner
{{- end }}
```

### **4. templates/nfs-server.yaml**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-server-pvc
  labels:
    {{- include "nfs-provisioner.nfsServerLabels" . | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: {{ .Values.platformStorageClass | quote }}
  resources:
    requests:
      storage: {{ .Values.nfsServer.storage }}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-server
  labels:
    {{- include "nfs-provisioner.nfsServerLabels" . | nindent 4 }}
spec:
  replicas: {{ .Values.nfsServer.replicas }}
  selector:
    matchLabels:
      {{- include "nfs-provisioner.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: nfs-server
  template:
    metadata:
      labels:
        {{- include "nfs-provisioner.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: nfs-server
    spec:
      {{- with .Values.nfsServer.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nfsServer.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nfsServer.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
      - name: nfs-server
        image: {{ .Values.nfsServer.image }}
        ports:
        - containerPort: 2049
          name: nfs
        - containerPort: 20048
          name: mountd
        - containerPort: 111
          name: rpcbind
        securityContext:
          privileged: {{ .Values.securityContext.privileged }}
          runAsUser: {{ .Values.securityContext.runAsUser }}
          runAsGroup: {{ .Values.securityContext.runAsGroup }}
        volumeMounts:
        - name: nfs-storage
          mountPath: /exports
        resources:
          {{- toYaml .Values.nfsServer.resources | nindent 10 }}
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "showmount -e localhost"
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "showmount -e localhost"
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
      volumes:
      - name: nfs-storage
        persistentVolumeClaim:
          claimName: {{ include "nfs-provisioner.fullname" . }}-server-pvc
```

### **5. templates/service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-server
  labels:
    {{- include "nfs-provisioner.nfsServerLabels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "nfs-provisioner.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: nfs-server
  ports:
  - port: {{ .Values.service.ports.nfs }}
    targetPort: nfs
    name: nfs
  - port: {{ .Values.service.ports.mountd }}
    targetPort: mountd
    name: mountd
  - port: {{ .Values.service.ports.rpcbind }}
    targetPort: rpcbind
    name: rpcbind
```

### **6. templates/rbac.yaml**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  labels:
    {{- include "nfs-provisioner.provisionerLabels" . | nindent 4 }}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  labels:
    {{- include "nfs-provisioner.provisionerLabels" . | nindent 4 }}
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  labels:
    {{- include "nfs-provisioner.provisionerLabels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
subjects:
- kind: ServiceAccount
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  namespace: {{ .Release.Namespace }}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  labels:
    {{- include "nfs-provisioner.provisionerLabels" . | nindent 4 }}
rules:
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  labels:
    {{- include "nfs-provisioner.provisionerLabels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
subjects:
- kind: ServiceAccount
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  namespace: {{ .Release.Namespace }}
```

### **7. templates/nfs-provisioner.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nfs-provisioner.fullname" . }}-provisioner
  labels:
    {{- include "nfs-provisioner.provisionerLabels" . | nindent 4 }}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      {{- include "nfs-provisioner.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: nfs-provisioner
  template:
    metadata:
      labels:
        {{- include "nfs-provisioner.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: nfs-provisioner
    spec:
      serviceAccountName: {{ include "nfs-provisioner.fullname" . }}-provisioner
      {{- with .Values.nfsProvisioner.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nfsProvisioner.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
      - name: nfs-client-provisioner
        image: {{ .Values.nfsProvisioner.image }}
        volumeMounts:
        - name: nfs-client-root
          mountPath: /persistentvolumes
        env:
        - name: PROVISIONER_NAME
          value: {{ include "nfs-provisioner.fullname" . }}/nfs
        - name: NFS_SERVER
          value: {{ include "nfs-provisioner.fullname" . }}-server
        - name: NFS_PATH
          value: /exports
        resources:
          {{- toYaml .Values.nfsProvisioner.resources | nindent 10 }}
      volumes:
      - name: nfs-client-root
        nfs:
          server: {{ include "nfs-provisioner.fullname" . }}-server
          path: /exports
```

### **8. templates/storage-class.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: {{ .Values.nfsProvisioner.storageClass.name }}
  labels:
    {{- include "nfs-provisioner.provisionerLabels" . | nindent 4 }}
  {{- if .Values.nfsProvisioner.storageClass.defaultClass }}
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  {{- end }}
provisioner: {{ include "nfs-provisioner.fullname" . }}/nfs
parameters:
  archiveOnDelete: "false"
reclaimPolicy: {{ .Values.nfsProvisioner.storageClass.reclaimPolicy }}
volumeBindingMode: {{ .Values.nfsProvisioner.storageClass.volumeBindingMode }}
allowVolumeExpansion: {{ .Values.nfsProvisioner.storageClass.allowVolumeExpansion }}
```

### **9. Makefile**
```makefile
.PHONY: install uninstall upgrade lint test clean

CHART_NAME := nfs-provisioner
NAMESPACE := nfs-system
RELEASE_NAME := nfs-provisioner

install:
	@echo "Installing NFS Provisioner..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 10m

uninstall:
	@echo "Uninstalling NFS Provisioner..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true

upgrade:
	@echo "Upgrading NFS Provisioner..."
	helm upgrade $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--wait \
		--timeout 10m

lint:
	@echo "Linting Helm chart..."
	helm lint .

test:
	@echo "Testing NFS Provisioner..."
	kubectl apply -f test/test-pvc.yaml
	kubectl wait --for=condition=Bound pvc/test-nfs-pvc --timeout=60s
	kubectl delete -f test/test-pvc.yaml

clean:
	@echo "Cleaning up test resources..."
	kubectl delete pvc --all -n $(NAMESPACE) --ignore-not-found=true

status:
	@echo "NFS Provisioner status:"
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)
	kubectl get pods -n $(NAMESPACE)
	kubectl get pvc -n $(NAMESPACE)
	kubectl get storageclass $(CHART_NAME)

logs:
	@echo "NFS Server logs:"
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=nfs-server
	@echo "NFS Provisioner logs:"
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=nfs-provisioner
```

### **10. README.md**
```markdown
# NFS Provisioner for ArgoCD HA

Platform-agnostic NFS storage provisioner for ArgoCD High Availability setup.

## Features

- ✅ Platform-independent storage solution
- ✅ ReadWriteMany support for shared storage
- ✅ Automatic PVC provisioning
- ✅ Cost-effective (single backing volume)
- ✅ Easy backup and restore

## Installation

```bash
# Install NFS Provisioner
make install

# Check status
make status
```

## Usage

Create PVC using NFS storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 10Gi
```

## Configuration

See `values.yaml` for all configuration options.

## Troubleshooting

```bash
# Check logs
make logs

# Test provisioning
make test
```
```

## 🔧 **Интеграция с ArgoCD**

### **Обновить ArgoCD values.yaml:**
```yaml
# ha/k8s/addons/argo-cd/values.yaml

# Redis HA с NFS storage
redis-ha:
  enabled: true
  replicas: 3
  persistentVolume:
    enabled: true
    storageClass: "nfs-client"
    size: 8Gi
    accessModes:
      - ReadWriteMany

# Repo Server с shared cache
repoServer:
  replicas: 3
  volumes:
    - name: repo-cache
      persistentVolumeClaim:
        claimName: argocd-repo-cache
  volumeMounts:
    - name: repo-cache
      mountPath: /app/cache

# Application Controller с shared data
controller:
  replicas: 2
  volumes:
    - name: controller-data
      persistentVolumeClaim:
        claimName: argocd-controller-data
  volumeMounts:
    - name: controller-data
      mountPath: /app/data
```

### **Создать PVC для ArgoCD:**
```yaml
# ha/k8s/addons/argo-cd/templates/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: argocd-repo-cache
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 20Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: argocd-controller-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 10Gi
```

## 📋 **Развертывание**

### **Вариант A: Интеграция в новый кластер (рекомендуется)**

#### **Шаг 1: Развернуть инфраструктуру**
```bash
./deploy-terraform.sh
```

#### **Шаг 2: Создать NFS Provisioner Helm chart**
```bash
# Создать структуру директорий
mkdir -p k8s/addons/nfs-provisioner/templates

# Создать все файлы согласно структуре выше:
# - Chart.yaml
# - values.yaml  
# - Makefile
# - README.md
# - templates/_helpers.tpl
# - templates/nfs-server.yaml
# - templates/nfs-provisioner.yaml
# - templates/storage-class.yaml
# - templates/rbac.yaml
# - templates/service.yaml
```

#### **Шаг 3: Развернуть NFS Provisioner**
```bash
cd k8s/addons/nfs-provisioner
make install
```

#### **Шаг 3: Проверить NFS статус**
```bash
make status
# Убедиться что StorageClass создан:
kubectl get storageclass nfs-client
```

#### **Шаг 4: Развернуть ArgoCD с NFS поддержкой**
```bash
cd ../argo-cd
# ArgoCD будет установлен с обновленным values.yaml, который уже содержит NFS конфигурацию
helm dependency update
envsubst < values.yaml | helm install --create-namespace -n argocd argocd . -f -
```

#### **Шаг 5: Развернуть ArgoCD Apps**
```bash
cd ../argo-cd-apps
helm install -n argocd argo-cd-apps . -f values.yaml
```

### **Вариант B: Добавление в существующий кластер**

#### **Шаг 1: Развернуть NFS Provisioner**
```bash
cd k8s/addons/nfs-provisioner
make install
```

#### **Шаг 2: Проверить статус**
```bash
make status
```

#### **Шаг 3: Обновить ArgoCD (только для существующих установок)**
```bash
cd ../argo-cd
helm upgrade argocd . -n argocd -f values.yaml
```

### **Проверка развертывания**
```bash
# Проверить PVC
kubectl get pvc -n argocd
kubectl get pvc -n nfs-system

# Проверить PV
kubectl get pv

# Проверить StorageClass
kubectl get storageclass

# Проверить ArgoCD поды
kubectl get pods -n argocd
```

## 💰 **Стоимость**

### **DigitalOcean:**
```
NFS Server backing storage (50GB): $5.00/месяц
Итого: $5.00/месяц
```

### **Сравнение с Block Storage:**
```
Block Storage (3x8GB + 2x5GB + 3x10GB): $6.40/месяц
NFS Provisioner (1x50GB): $5.00/месяц
Экономия: $1.40/месяц (22%)
```

## 🎯 **Заключение**

NFS Provisioner обеспечивает:
- ✅ **Platform independence** - работает на любой платформе
- ✅ **Cost efficiency** - экономия на storage
- ✅ **Shared storage** - ReadWriteMany для ArgoCD
- ✅ **Simple management** - один volume для всех

Идеально подходит для ArgoCD HA в multi-cloud или cost-sensitive окружениях.
