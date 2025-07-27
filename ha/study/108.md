# 108. Лучшие практики для продакшена в Kubernetes

## 🎯 **Лучшие практики для продакшена в Kubernetes**

**Production-ready Kubernetes** требует соблюдения множества best practices для обеспечения надежности, безопасности и производительности.

## 🏗️ **Основные категории:**

### **1. Security:**
- **RBAC** - минимальные привилегии
- **Network Policies** - сетевая изоляция
- **Pod Security Standards** - безопасность контейнеров
- **Secrets Management** - управление секретами

### **2. Resource Management:**
- **Resource Limits** - ограничения ресурсов
- **Quality of Service** - классы QoS
- **Autoscaling** - автомасштабирование

### **3. High Availability:**
- **Multi-zone deployment** - развертывание в зонах
- **Pod Disruption Budgets** - бюджеты прерывания
- **Health Checks** - проверки работоспособности

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать production best practices toolkit
cat << 'EOF' > kubernetes-production-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Production Best Practices Toolkit ==="
echo "Production guidelines for HashFoundry HA cluster"
echo

# Функция для проверки security
check_security() {
    echo "=== Security Check ==="
    
    echo "1. RBAC Status:"
    kubectl get clusterroles | head -5
    kubectl get rolebindings --all-namespaces | head -5
    echo
    
    echo "2. Network Policies:"
    kubectl get networkpolicies --all-namespaces
    echo
    
    echo "3. Pod Security Context:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.runAsNonRoot}{"\n"}{end}' | head -5
    echo
}

# Функция для создания production deployment
create_production_deployment() {
    echo "=== Creating Production Deployment Template ==="
    
    cat << DEPLOY_EOF > production-app-template.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hashfoundry-app
  namespace: default
  labels:
    app: hashfoundry-app
    version: v1.0.0
    environment: production
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: hashfoundry-app
  template:
    metadata:
      labels:
        app: hashfoundry-app
        version: v1.0.0
    spec:
      serviceAccountName: hashfoundry-app-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - hashfoundry-app
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: hashfoundry/app:v1.0.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ENV
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: hashfoundry-app-service
  namespace: default
  labels:
    app: hashfoundry-app
spec:
  selector:
    app: hashfoundry-app
  ports:
  - port: 80
    targetPort: 8080
    name: http
  type: ClusterIP
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: hashfoundry-app-pdb
  namespace: default
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: hashfoundry-app
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hashfoundry-app-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hashfoundry-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
DEPLOY_EOF
    
    echo "✅ Production deployment template created: production-app-template.yaml"
    echo
}

# Функция для создания resource policies
create_resource_policies() {
    echo "=== Creating Resource Policies ==="
    
    cat << POLICIES_EOF > resource-policies.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: default
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    pods: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: default
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-traffic
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: hashfoundry-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
POLICIES_EOF
    
    echo "✅ Resource policies created: resource-policies.yaml"
    echo
}

# Функция для проверки production readiness
check_production_readiness() {
    echo "=== Production Readiness Check ==="
    
    echo "1. Resource Limits Check:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits}{"\n"}{end}' | grep -v "cpu\|memory" | head -5
    echo
    
    echo "2. Health Checks:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].livenessProbe.httpGet.path}{"\n"}{end}' | head -5
    echo
    
    echo "3. Security Context:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.runAsNonRoot}{"\n"}{end}' | head -5
    echo
    
    echo "4. Multi-replica Deployments:"
    kubectl get deployments --all-namespaces -o custom-columns="NAME:.metadata.name,REPLICAS:.spec.replicas" | awk '$2==1'
    echo
}

# Основная функция
main() {
    case "$1" in
        "security")
            check_security
            ;;
        "deployment")
            create_production_deployment
            ;;
        "policies")
            create_resource_policies
            ;;
        "check")
            check_production_readiness
            ;;
        "all"|"")
            check_security
            create_production_deployment
            create_resource_policies
            check_production_readiness
            ;;
        *)
            echo "Usage: $0 [security|deployment|policies|check|all]"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubernetes-production-toolkit.sh
./kubernetes-production-toolkit.sh all
```

## 📋 **Production Checklist:**

### **Security:**
- ✅ RBAC настроен с минимальными привилегиями
- ✅ Network Policies ограничивают трафик
- ✅ Pod Security Context настроен
- ✅ Secrets не хранятся в plain text

### **Resource Management:**
- ✅ Resource requests и limits установлены
- ✅ ResourceQuota и LimitRange настроены
- ✅ HPA настроен для автомасштабирования
- ✅ PDB защищает от disruptions

### **High Availability:**
- ✅ Минимум 3 реплики для критичных сервисов
- ✅ Anti-affinity правила для распределения
- ✅ Health checks настроены
- ✅ Multi-zone deployment

## 🎯 **Практические команды:**

```bash
# Запустить production toolkit
./kubernetes-production-toolkit.sh all

# Проверить production readiness
./kubernetes-production-toolkit.sh check

# Применить production deployment
kubectl apply -f production-app-template.yaml

# Проверить security
kubectl auth can-i --list --as=system:serviceaccount:default:hashfoundry-app-sa
```

**Соблюдение production best practices критически важно для стабильной работы в продакшене!**
