# 25. Что такое Pod Security Contexts?

## 🎯 **Что такое Security Context?**

**Security Context** — это набор настроек безопасности, применяемых к Pod'у или контейнеру. Определяет права доступа, пользователей, группы, capabilities и другие параметры безопасности для выполнения контейнеров.

## 🏗️ **Основные компоненты Security Context:**

### **1. User и Group ID**
- runAsUser - UID пользователя
- runAsGroup - GID группы
- runAsNonRoot - запрет запуска от root
- fsGroup - группа для файловой системы

### **2. Capabilities**
- add - добавить Linux capabilities
- drop - убрать Linux capabilities
- Контроль системных привилегий

### **3. SELinux/AppArmor**
- seLinuxOptions - настройки SELinux
- appArmorProfile - профиль AppArmor
- seccompProfile - профиль seccomp

### **4. Privileged режим**
- privileged - привилегированный контейнер
- allowPrivilegeEscalation - разрешение повышения привилегий
- readOnlyRootFilesystem - только чтение корневой ФС

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Проверка Security Context в ArgoCD:**
```bash
# Проверить Security Context ArgoCD Pod'ов
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{.spec.securityContext}{"\n"}{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}{"\n"}{end}'

# Подробная информация о Security Context
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server | grep -A 10 "Security Context:"

# Проверить пользователя в ArgoCD контейнере
kubectl exec -n argocd <argocd-pod> -- id
```

### **2. Мониторинг Security Context:**
```bash
# Проверить Security Context в monitoring namespace
kubectl describe pod -n monitoring -l app=prometheus | grep -A 10 "Security Context:"

# Проверить пользователя в Prometheus контейнере
kubectl exec -n monitoring <prometheus-pod> -- id

# Grafana Security Context
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep -A 10 "Security Context:"
```

### **3. Создание Pod'а с Security Context:**
```bash
# Pod с базовым Security Context
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    runAsNonRoot: true
    fsGroup: 2000
  containers:
  - name: sec-ctx-demo
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
EOF

# Проверить применение Security Context
kubectl exec security-context-demo -- id
kubectl exec security-context-demo -- ps aux

# Очистка
kubectl delete pod security-context-demo
```

## 🔄 **Уровни Security Context:**

### **1. Pod-level Security Context:**
```bash
# Security Context на уровне Pod'а
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-security-context
spec:
  securityContext:
    runAsUser: 1001
    runAsGroup: 3001
    runAsNonRoot: true
    fsGroup: 2001
    supplementalGroups: [4001, 5001]
  containers:
  - name: container1
    image: busybox
    command: ['sleep', '3600']
  - name: container2
    image: busybox
    command: ['sleep', '3600']
EOF

# Все контейнеры наследуют Pod Security Context
kubectl exec pod-security-context -c container1 -- id
kubectl exec pod-security-context -c container2 -- id

kubectl delete pod pod-security-context
```

### **2. Container-level Security Context:**
```bash
# Security Context на уровне контейнера
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: container-security-context
spec:
  securityContext:
    runAsUser: 1000  # Pod-level default
  containers:
  - name: container1
    image: busybox
    command: ['sleep', '3600']
    # Использует Pod-level Security Context
  - name: container2
    image: busybox
    command: ['sleep', '3600']
    securityContext:
      runAsUser: 2000  # Override Pod-level
      runAsNonRoot: true
EOF

# Разные пользователи в контейнерах
kubectl exec container-security-context -c container1 -- id
kubectl exec container-security-context -c container2 -- id

kubectl delete pod container-security-context
```

### **3. Capabilities управление:**
```bash
# Pod с управлением capabilities
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-demo
spec:
  containers:
  - name: cap-demo
    image: busybox
    command: ['sleep', '3600']
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "SYS_TIME"]
        drop: ["MKNOD", "AUDIT_WRITE"]
EOF

# Проверить capabilities
kubectl exec capabilities-demo -- cat /proc/1/status | grep Cap

kubectl delete pod capabilities-demo
```

## 🔧 **Практические сценарии Security Context:**

### **1. Non-root контейнер:**
```bash
# Безопасный non-root контейнер
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: non-root-demo
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
  - name: app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: var-cache
      mountPath: /var/cache/nginx
    - name: var-run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: var-cache
    emptyDir: {}
  - name: var-run
    emptyDir: {}
EOF

kubectl exec non-root-demo -- id
kubectl exec non-root-demo -- ps aux

kubectl delete pod non-root-demo
```

### **2. Read-only файловая система:**
```bash
# Контейнер с read-only root filesystem
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: readonly-fs-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp-volume
      mountPath: /tmp
  volumes:
  - name: tmp-volume
    emptyDir: {}
EOF

# Попытка записи в root filesystem (должна провалиться)
kubectl exec readonly-fs-demo -- touch /test-file || echo "Write to root FS blocked"

# Запись в /tmp (должна работать)
kubectl exec readonly-fs-demo -- touch /tmp/test-file && echo "Write to /tmp allowed"

kubectl delete pod readonly-fs-demo
```

### **3. Privileged контейнер (осторожно!):**
```bash
# Privileged контейнер (только для демонстрации)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-demo
spec:
  containers:
  - name: privileged-container
    image: busybox
    command: ['sleep', '3600']
    securityContext:
      privileged: true
EOF

# Privileged контейнер имеет доступ к host устройствам
kubectl exec privileged-demo -- ls /dev

# ВНИМАНИЕ: Privileged контейнеры опасны в production!
kubectl delete pod privileged-demo
```

## 📈 **Мониторинг Security Context:**

### **1. Аудит Security Context:**
```bash
# Проверить Security Context всех Pod'ов
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.runAsUser}{"\t"}{.spec.securityContext.runAsNonRoot}{"\n"}{end}' | column -t

# Pod'ы запущенные от root
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.runAsUser}{"\n"}{end}' | grep -E "\t0$|\t$"

# Privileged контейнеры
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{$.metadata.namespace}{"\t"}{$.metadata.name}{"\t"}{.name}{"\t"}{.securityContext.privileged}{"\n"}{end}{end}' | grep true
```

### **2. Метрики безопасности в Prometheus:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Метрики Security Context:
# kube_pod_container_status_running{container!="POD"} - запущенные контейнеры
# kube_pod_spec_volumes_persistentvolumeclaim_readonly - read-only volumes
# Можно создать custom метрики для Security Context через kube-state-metrics
```

### **3. Policy Engine интеграция:**
```bash
# Проверка с помощью OPA Gatekeeper (если установлен)
kubectl get constraints

# Falco для runtime security (если установлен)
kubectl get pods -n falco-system

# Pod Security Standards
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
kubectl label namespace default pod-security.kubernetes.io/audit=restricted
kubectl label namespace default pod-security.kubernetes.io/warn=restricted
```

## 🏭 **Production Security Context:**

### **1. Deployment с Security Context:**
```bash
# Production Deployment с безопасными настройками
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: var-cache
          mountPath: /var/cache/nginx
        - name: var-run
          mountPath: /var/run
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
      volumes:
      - name: tmp
        emptyDir: {}
      - name: var-cache
        emptyDir: {}
      - name: var-run
        emptyDir: {}
EOF

kubectl get deployment secure-app
kubectl describe pod -l app=secure-app | grep -A 15 "Security Context:"

kubectl delete deployment secure-app
```

### **2. StatefulSet с Security Context:**
```bash
# StatefulSet с безопасными настройками
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: secure-database
spec:
  serviceName: secure-database
  replicas: 1
  selector:
    matchLabels:
      app: secure-database
  template:
    metadata:
      labels:
        app: secure-database
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
      - name: database
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "testdb"
        - name: POSTGRES_USER
          value: "testuser"
        - name: POSTGRES_PASSWORD
          value: "testpass"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: tmp
          mountPath: /tmp
        - name: run
          mountPath: /var/run/postgresql
      volumes:
      - name: tmp
        emptyDir: {}
      - name: run
        emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

kubectl get statefulset secure-database
kubectl exec secure-database-0 -- id

kubectl delete statefulset secure-database
kubectl delete pvc data-secure-database-0
```

## 🚨 **Security Context Best Practices:**

### **1. Принцип минимальных привилегий:**
```bash
# Базовый безопасный Security Context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
  seccompProfile:
    type: RuntimeDefault
```

### **2. Избегайте опасных настроек:**
```bash
# ОПАСНО - НЕ используйте в production:
securityContext:
  privileged: true              # Полный доступ к host
  runAsUser: 0                  # Root пользователь
  allowPrivilegeEscalation: true # Повышение привилегий
  capabilities:
    add: ["SYS_ADMIN"]          # Опасные capabilities
```

### **3. Проверка Security Context:**
```bash
# Скрипт для аудита Security Context
cat << 'EOF' > audit-security-context.sh
#!/bin/bash
echo "=== Security Context Audit ==="
echo "Pods running as root:"
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.runAsUser}{"\n"}{end}' | grep -E "\t0$|\t$"

echo -e "\nPrivileged containers:"
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{$.metadata.namespace}{"\t"}{$.metadata.name}{"\t"}{.name}{"\t"}{.securityContext.privileged}{"\n"}{end}{end}' | grep true

echo -e "\nContainers with privilege escalation:"
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{$.metadata.namespace}{"\t"}{$.metadata.name}{"\t"}{.name}{"\t"}{.securityContext.allowPrivilegeEscalation}{"\n"}{end}{end}' | grep true
EOF

chmod +x audit-security-context.sh
./audit-security-context.sh
rm audit-security-context.sh
```

## 🎯 **Pod Security Standards:**

### **1. Privileged (небезопасный):**
- Разрешает все
- Не рекомендуется для production

### **2. Baseline (базовый):**
- Запрещает privileged контейнеры
- Ограничивает опасные capabilities
- Минимальные ограничения

### **3. Restricted (ограниченный):**
- Строгие ограничения безопасности
- runAsNonRoot: true
- readOnlyRootFilesystem: true
- Минимальные capabilities

```bash
# Применение Pod Security Standards
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
kubectl label namespace default pod-security.kubernetes.io/audit=restricted
kubectl label namespace default pod-security.kubernetes.io/warn=restricted

# Проверка применения
kubectl describe namespace default | grep Labels
```

**Security Context обеспечивает многоуровневую защиту контейнеров в Kubernetes!**

## 🔍 **Troubleshooting Security Context:**

### **1. Отладка проблем с правами доступа:**
```bash
# Создать Pod с проблемами доступа
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: permission-debug
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 2000
  containers:
  - name: debug
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    emptyDir: {}
EOF

# Проверить права доступа
kubectl exec permission-debug -- ls -la /data
kubectl exec permission-debug -- id
kubectl exec permission-debug -- touch /data/test-file

kubectl delete pod permission-debug
```

### **2. Диагностика capabilities:**
```bash
# Pod для проверки capabilities
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-debug
spec:
  containers:
  - name: debug
    image: busybox
    command: ['sleep', '3600']
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
        drop: ["MKNOD"]
EOF

# Проверить эффективные capabilities
kubectl exec capabilities-debug -- cat /proc/1/status | grep Cap
kubectl exec capabilities-debug -- capsh --print

kubectl delete pod capabilities-debug
```

### **3. Проблемы с SELinux/AppArmor:**
```bash
# Проверить SELinux контекст (если включен)
kubectl exec <pod-name> -- ls -Z /

# Проверить AppArmor профиль (если включен)
kubectl exec <pod-name> -- cat /proc/1/attr/current

# События безопасности
kubectl get events --field-selector reason=FailedMount
kubectl get events --field-selector reason=SecurityContextDeny
```

## 🛡️ **Advanced Security Context:**

### **1. Seccomp профили:**
```bash
# Pod с кастомным seccomp профилем
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-demo
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/audit.json
EOF

# Проверить применение seccomp
kubectl exec seccomp-demo -- cat /proc/1/status | grep Seccomp

kubectl delete pod seccomp-demo
```

### **2. AppArmor интеграция:**
```bash
# Pod с AppArmor профилем
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-demo
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

# Проверить AppArmor статус
kubectl exec apparmor-demo -- cat /proc/1/attr/current

kubectl delete pod apparmor-demo
```

### **3. SELinux конфигурация:**
```bash
# Pod с SELinux настройками
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: selinux-demo
spec:
  securityContext:
    seLinuxOptions:
      level: "s0:c123,c456"
      role: "object_r"
      type: "svirt_sandbox_file_t"
      user: "system_u"
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
EOF

# Проверить SELinux контекст
kubectl exec selinux-demo -- ls -Z /

kubectl delete pod selinux-demo
```

## 📋 **Security Context Templates:**

### **1. Высокобезопасный template:**
```yaml
# Максимально безопасный Security Context
apiVersion: v1
kind: Pod
metadata:
  name: ultra-secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534  # nobody user
    runAsGroup: 65534
    fsGroup: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

### **2. Web application template:**
```yaml
# Security Context для веб-приложений
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-web-app
  template:
    metadata:
      labels:
        app: secure-web-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: var-cache
          mountPath: /var/cache/nginx
        - name: var-run
          mountPath: /var/run
      volumes:
      - name: tmp
        emptyDir: {}
      - name: var-cache
        emptyDir: {}
      - name: var-run
        emptyDir: {}
```

### **3. Database template:**
```yaml
# Security Context для баз данных
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: secure-database
spec:
  serviceName: secure-database
  replicas: 1
  selector:
    matchLabels:
      app: secure-database
  template:
    metadata:
      labels:
        app: secure-database
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: "securedb"
        - name: POSTGRES_USER
          value: "dbuser"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: tmp
          mountPath: /tmp
        - name: run
          mountPath: /var/run/postgresql
      volumes:
      - name: tmp
        emptyDir: {}
      - name: run
        emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

## 🎯 **Security Context Checklist:**

### **✅ Обязательные настройки для production:**
- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- `capabilities.drop: ["ALL"]`
- `seccompProfile.type: RuntimeDefault`

### **⚠️ Избегайте в production:**
- `privileged: true`
- `runAsUser: 0`
- `capabilities.add: ["SYS_ADMIN", "SYS_PTRACE"]`
- `hostNetwork: true`
- `hostPID: true`

### **🔍 Регулярно проверяйте:**
- Аудит Security Context всех Pod'ов
- Мониторинг нарушений безопасности
- Обновление security policies
- Тестирование с Pod Security Standards

## 📊 **Мониторинг и алерты:**

### **1. Prometheus алерты для Security Context:**
```yaml
groups:
- name: security-context-alerts
  rules:
  - alert: PrivilegedContainer
    expr: kube_pod_container_info{container!="POD"} * on(pod, namespace) group_left() kube_pod_spec_containers_security_context_privileged == 1
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "Privileged container detected"
      description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has privileged container"

  - alert: RootContainer
    expr: kube_pod_container_info{container!="POD"} * on(pod, namespace) group_left() (kube_pod_spec_containers_security_context_run_as_user == 0)
    for: 0m
    labels:
      severity: warning
    annotations:
      summary: "Container running as root"
      description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is running as root user"
```

### **2. Grafana dashboard для Security Context:**
```bash
# Метрики для мониторинга:
# - kube_pod_spec_containers_security_context_privileged
# - kube_pod_spec_containers_security_context_run_as_user
# - kube_pod_spec_containers_security_context_run_as_non_root
# - kube_pod_spec_containers_security_context_read_only_root_filesystem
```

**Security Context — это фундаментальный механизм безопасности в Kubernetes, который должен быть правильно настроен для каждого workload'а!**
