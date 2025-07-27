# 139. Какие лучшие практики безопасности Kubernetes

## 🎯 **Какие лучшие практики безопасности Kubernetes?**

**Безопасность Kubernetes** - это многоуровневый подход, включающий защиту кластера, рабочих нагрузок, сети и данных. Правильная реализация security practices критически важна для production среды.

## 🌐 **Уровни безопасности Kubernetes:**

### **1. Cluster Security:**
- **API Server Security** - защита точки входа
- **etcd Security** - шифрование данных в покое
- **Node Security** - защита worker nodes
- **Network Security** - сегментация сети

### **2. Workload Security:**
- **Pod Security Standards** - политики безопасности подов
- **Container Security** - безопасность контейнеров
- **Image Security** - сканирование образов
- **Runtime Security** - защита во время выполнения

### **3. Access Control:**
- **RBAC** - ролевое управление доступом
- **Service Accounts** - учетные записи сервисов
- **Authentication** - аутентификация
- **Authorization** - авторизация

## 📊 **Практические примеры из вашего HA кластера:**

### **Pod Security Standards:**

```yaml
# pod-security-policy.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
# Secure Pod Example
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: secure-namespace
  labels:
    app: secure-app
    environment: hashfoundry-ha
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: hashfoundry/secure-app:v1.0.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: var-run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: var-run
    emptyDir: {}
```

### **RBAC Configuration:**

```yaml
# rbac-config.yaml
# Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hashfoundry-app-sa
  namespace: production
  labels:
    app: hashfoundry-app

---
# Role for namespace-specific permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: hashfoundry-app-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: hashfoundry-app-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: hashfoundry-app-sa
  namespace: production
roleRef:
  kind: Role
  name: hashfoundry-app-role
  apiGroup: rbac.authorization.k8s.io

---
# ClusterRole for cluster-wide permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hashfoundry-monitoring-role
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]

---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hashfoundry-monitoring-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: hashfoundry-monitoring-role
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring
```

### **Network Policies:**

```yaml
# network-policies.yaml
# Default deny all ingress traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Allow ingress from specific namespaces
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080

---
# Allow egress to specific services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: UDP
      port: 53
```

### **Secrets Management:**

```bash
# Создание секретов безопасным способом
kubectl create secret generic app-secrets \
  --from-literal=database-password="$(openssl rand -base64 32)" \
  --from-literal=api-key="$(openssl rand -hex 16)" \
  --namespace=production

# Создание TLS секрета
kubectl create secret tls hashfoundry-tls \
  --cert=hashfoundry.crt \
  --key=hashfoundry.key \
  --namespace=production

# Проверка секретов
kubectl get secrets -n production
kubectl describe secret app-secrets -n production
```

```yaml
# secure-deployment-with-secrets.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-webapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-webapp
  template:
    metadata:
      labels:
        app: secure-webapp
        tier: frontend
    spec:
      serviceAccountName: hashfoundry-app-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: webapp
        image: hashfoundry/webapp:v2.1.0
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: api-key
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```

### **Image Security:**

```bash
# Сканирование образов с помощью trivy
trivy image hashfoundry/webapp:v2.1.0

# Проверка подписей образов
cosign verify hashfoundry/webapp:v2.1.0

# Создание политики для разрешенных реестров
cat << 'EOF' > allowed-registries-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: allowed-registries
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must come from approved registries"
      pattern:
        spec:
          containers:
          - image: "registry.hashfoundry.io/* | docker.io/* | gcr.io/* | quay.io/*"
EOF
```

### **Admission Controllers для безопасности:**

```yaml
# security-admission-controller.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: security-validator
spec:
  clientConfig:
    service:
      name: security-webhook
      namespace: security-system
      path: "/validate"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1"]
    resources: ["deployments", "daemonsets", "statefulsets"]
  failurePolicy: Fail
  sideEffects: None
  admissionReviewVersions: ["v1", "v1beta1"]
```

### **Security Monitoring:**

```bash
# Создать скрипт для мониторинга безопасности
cat << 'EOF' > security-monitor.sh
#!/bin/bash

echo "=== HashFoundry Security Monitor ==="
echo "Timestamp: $(date)"
echo

# Проверка привилегированных подов
echo "1. Privileged Pods Check:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.namespace}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}' | \
grep -v "false" | grep -v "<no value>"
echo

# Проверка подов, работающих от root
echo "2. Pods Running as Root:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.namespace}{"\t"}{.spec.securityContext.runAsUser}{"\n"}{end}' | \
grep -E "\t0$|\t$"
echo

# Проверка подов без resource limits
echo "3. Pods Without Resource Limits:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.namespace}{"\t"}{.spec.containers[*].resources.limits}{"\n"}{end}' | \
grep -v "map\["
echo

# Проверка секретов
echo "4. Secrets Analysis:"
kubectl get secrets --all-namespaces --no-headers | wc -l | xargs echo "Total secrets:"
kubectl get secrets --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.namespace}{"\t"}{.type}{"\n"}{end}' | \
sort | uniq -c
echo

# Проверка RBAC
echo "5. RBAC Analysis:"
echo "ClusterRoles: $(kubectl get clusterroles --no-headers | wc -l)"
echo "ClusterRoleBindings: $(kubectl get clusterrolebindings --no-headers | wc -l)"
echo "Roles: $(kubectl get roles --all-namespaces --no-headers | wc -l)"
echo "RoleBindings: $(kubectl get rolebindings --all-namespaces --no-headers | wc -l)"
echo

# Проверка Network Policies
echo "6. Network Policies:"
kubectl get networkpolicies --all-namespaces
echo

# Проверка Pod Security Standards
echo "7. Pod Security Standards:"
kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.pod-security\.kubernetes\.io/enforce}{"\n"}{end}' | \
grep -v "<no value>"
echo

echo "✅ Security monitoring completed"
EOF

chmod +x security-monitor.sh
```

### **Falco для Runtime Security:**

```yaml
# falco-deployment.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: security-system
  labels:
    app: falco
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      serviceAccountName: falco
      hostNetwork: true
      hostPID: true
      containers:
      - name: falco
        image: falcosecurity/falco:latest
        securityContext:
          privileged: true
        args:
        - /usr/bin/falco
        - --cri=/run/containerd/containerd.sock
        - --k8s-api=https://kubernetes.default.svc.cluster.local
        - --k8s-api-cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        - --k8s-api-token=/var/run/secrets/kubernetes.io/serviceaccount/token
        volumeMounts:
        - name: dev-fs
          mountPath: /host/dev
          readOnly: true
        - name: proc-fs
          mountPath: /host/proc
          readOnly: true
        - name: boot-fs
          mountPath: /host/boot
          readOnly: true
        - name: lib-modules
          mountPath: /host/lib/modules
          readOnly: true
        - name: usr-fs
          mountPath: /host/usr
          readOnly: true
        - name: etc-fs
          mountPath: /host/etc
          readOnly: true
        - name: containerd-socket
          mountPath: /run/containerd/containerd.sock
      volumes:
      - name: dev-fs
        hostPath:
          path: /dev
      - name: proc-fs
        hostPath:
          path: /proc
      - name: boot-fs
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr-fs
        hostPath:
          path: /usr
      - name: etc-fs
        hostPath:
          path: /etc
      - name: containerd-socket
        hostPath:
          path: /run/containerd/containerd.sock
```

### **OPA Gatekeeper для Policy Enforcement:**

```yaml
# gatekeeper-constraint-template.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        type: object
        properties:
          runAsNonRoot:
            type: boolean
          readOnlyRootFilesystem:
            type: boolean
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := "Container must run as non-root user"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.readOnlyRootFilesystem
          msg := "Container must have read-only root filesystem"
        }

---
# Constraint using the template
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredSecurityContext
metadata:
  name: must-have-security-context
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces: ["production", "staging"]
  parameters:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
```

### **Команды kubectl для анализа безопасности:**

```bash
# Проверить RBAC права пользователя
kubectl auth can-i --list --as=system:serviceaccount:production:hashfoundry-app-sa

# Проверить доступ к ресурсам
kubectl auth can-i get pods --as=system:serviceaccount:production:hashfoundry-app-sa -n production

# Аудит привилегированных подов
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}' | grep true

# Проверить поды без security context
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}' | grep "null"

# Проверить использование host network
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.hostNetwork}{"\n"}{end}' | grep true

# Проверить capabilities
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.capabilities}{"\n"}{end}'

# Аудит секретов
kubectl get secrets --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.namespace}{"\t"}{.type}{"\n"}{end}'

# Проверить образы без тегов или с latest
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | grep -E ":latest|@sha256"
```

### **Security Benchmarks:**

```bash
# Запуск CIS Kubernetes Benchmark с kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Проверка результатов
kubectl logs job/kube-bench

# Запуск kube-hunter для поиска уязвимостей
kubectl create -f https://raw.githubusercontent.com/aquasecurity/kube-hunter/main/job.yaml

# Проверка с помощью kubesec
kubesec scan deployment.yaml
```

## 🎯 **Ключевые принципы безопасности:**

1. **Defense in Depth** - многоуровневая защита
2. **Least Privilege** - минимальные необходимые права
3. **Zero Trust** - не доверять по умолчанию
4. **Continuous Monitoring** - постоянный мониторинг
5. **Regular Updates** - регулярные обновления
6. **Security by Design** - безопасность с самого начала

Правильная реализация security practices обеспечивает надежную защиту HashFoundry HA кластера от различных угроз.
