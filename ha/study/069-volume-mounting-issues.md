# 69. Volume Mounting Issues

## 🎯 **Volume Mounting Issues**

**Volume mounting issues** - это распространенные проблемы в Kubernetes, которые могут возникать из-за неправильной конфигурации, проблем с storage backend, permissions или resource constraints. Правильная диагностика и решение этих проблем критически важны для стабильности приложений.

## 🏗️ **Типы проблем с mounting:**

### **Основные категории:**
- **Permission Issues** - проблемы с правами доступа
- **Storage Backend Problems** - проблемы с underlying storage
- **Configuration Errors** - ошибки в конфигурации
- **Resource Constraints** - ограничения ресурсов
- **Node-specific Issues** - проблемы на уровне узлов

### **Симптомы проблем:**
- **Pod в состоянии ContainerCreating**
- **Mount timeout errors**
- **Permission denied errors**
- **Volume attachment failures**

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание демонстрационной среды для troubleshooting:**
```bash
# Создать namespace для демонстрации volume mounting issues
kubectl create namespace volume-troubleshooting-demo

# Создать labels
kubectl label namespace volume-troubleshooting-demo \
  demo.type=volume-troubleshooting \
  app.kubernetes.io/name=hashfoundry-storage \
  environment=educational

# Проверить текущее состояние storage в кластере
echo "=== Current Storage State in HA Cluster ==="
kubectl get storageclass
kubectl get pv
kubectl get csidriver
kubectl get nodes -o custom-columns="NAME:.metadata.name,READY:.status.conditions[?(@.type=='Ready')].status,STORAGE:.status.allocatable.ephemeral-storage"
```

### **2. Создание различных типов volume mounting проблем:**
```bash
# Создать скрипт для демонстрации и решения volume mounting issues
cat << 'EOF' > troubleshoot-volume-mounting.sh
#!/bin/bash

NAMESPACE=${1:-"volume-troubleshooting-demo"}

echo "=== Volume Mounting Troubleshooting Demo ==="
echo "Namespace: $NAMESPACE"
echo

# Функция для создания проблемы с permissions
create_permission_issue() {
    echo "=== Creating Permission Issue Demo ==="
    
    # Создать PVC
    cat << PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: permission-issue-pvc
  namespace: $NAMESPACE
  labels:
    issue.type: permission
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "permission-denied"
spec:
  storageClassName: do-block-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
PVC_EOF
    
    # Создать Pod с неправильными security context
    cat << POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: permission-issue-pod
  namespace: $NAMESPACE
  labels:
    issue.type: permission
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "permission-denied"
    troubleshooting.hashfoundry.io/description: "Pod with incorrect security context causing permission issues"
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 2000
  containers:
  - name: permission-test
    image: busybox:1.35
    command: ["sh", "-c"]
    args:
    - |
      echo "Testing volume permissions..."
      echo "Current user: \$(id)"
      echo "Mount point permissions:"
      ls -la /data
      echo "Attempting to write to volume..."
      echo "test data" > /data/test.txt || echo "❌ Permission denied!"
      echo "Attempting to read from volume..."
      cat /data/test.txt || echo "❌ Cannot read file!"
      sleep 3600
    volumeMounts:
    - name: data-volume
      mountPath: /data
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: permission-issue-pvc
POD_EOF
    
    echo "✅ Permission issue demo created"
    echo
}

# Функция для создания проблемы с mount timeout
create_mount_timeout_issue() {
    echo "=== Creating Mount Timeout Issue Demo ==="
    
    # Создать PVC с несуществующим storage class
    cat << PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: timeout-issue-pvc
  namespace: $NAMESPACE
  labels:
    issue.type: timeout
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "mount-timeout"
spec:
  storageClassName: non-existent-storage-class
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
PVC_EOF
    
    # Создать Pod, который будет ждать mount
    cat << POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: timeout-issue-pod
  namespace: $NAMESPACE
  labels:
    issue.type: timeout
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "mount-timeout"
    troubleshooting.hashfoundry.io/description: "Pod stuck in ContainerCreating due to mount timeout"
spec:
  containers:
  - name: timeout-test
    image: nginx:1.21
    volumeMounts:
    - name: data-volume
      mountPath: /usr/share/nginx/html
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: timeout-issue-pvc
POD_EOF
    
    echo "✅ Mount timeout issue demo created"
    echo
}

# Функция для создания проблемы с node affinity
create_node_affinity_issue() {
    echo "=== Creating Node Affinity Issue Demo ==="
    
    # Создать PV с node affinity на несуществующий node
    cat << PV_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: node-affinity-issue-pv
  labels:
    issue.type: node-affinity
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "node-affinity-mismatch"
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: "/tmp/hashfoundry-node-affinity-test"
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - "non-existent-node"
PV_EOF
    
    # Создать PVC для этого PV
    cat << PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: node-affinity-issue-pvc
  namespace: $NAMESPACE
  labels:
    issue.type: node-affinity
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "node-affinity-mismatch"
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      issue.type: node-affinity
PVC_EOF
    
    # Создать Pod
    cat << POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-affinity-issue-pod
  namespace: $NAMESPACE
  labels:
    issue.type: node-affinity
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "node-affinity-mismatch"
    troubleshooting.hashfoundry.io/description: "Pod cannot be scheduled due to node affinity constraints"
spec:
  containers:
  - name: affinity-test
    image: busybox:1.35
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data-volume
      mountPath: /data
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: node-affinity-issue-pvc
POD_EOF
    
    echo "✅ Node affinity issue demo created"
    echo
}

# Функция для создания проблемы с resource constraints
create_resource_constraint_issue() {
    echo "=== Creating Resource Constraint Issue Demo ==="
    
    # Создать PVC с очень большим размером
    cat << PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: resource-constraint-pvc
  namespace: $NAMESPACE
  labels:
    issue.type: resource-constraint
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "insufficient-storage"
spec:
  storageClassName: do-block-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1000Gi  # Очень большой размер
PVC_EOF
    
    echo "✅ Resource constraint issue demo created"
    echo
}

# Функция для создания правильно работающего примера
create_working_example() {
    echo "=== Creating Working Example ==="
    
    # Создать правильный PVC
    cat << PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: working-example-pvc
  namespace: $NAMESPACE
  labels:
    issue.type: none
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "none"
    troubleshooting.hashfoundry.io/description: "Properly configured PVC and Pod"
spec:
  storageClassName: do-block-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
PVC_EOF
    
    # Создать правильно настроенный Pod
    cat << POD_EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: working-example-pod
  namespace: $NAMESPACE
  labels:
    issue.type: none
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "none"
    troubleshooting.hashfoundry.io/description: "Properly configured Pod with correct volume mounting"
spec:
  securityContext:
    fsGroup: 1000
  containers:
  - name: working-app
    image: nginx:1.21
    ports:
    - containerPort: 80
    volumeMounts:
    - name: data-volume
      mountPath: /usr/share/nginx/html
    - name: config-volume
      mountPath: /etc/nginx/conf.d
    command: ["sh", "-c"]
    args:
    - |
      echo "Setting up working volume example..."
      
      # Создать HTML контент
      cat > /usr/share/nginx/html/index.html << 'HTML_EOF'
      <!DOCTYPE html>
      <html>
      <head>
          <title>Volume Mounting Success</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; }
              .header { background: #4CAF50; color: white; padding: 20px; }
              .content { padding: 20px; }
              .success { background: #d4edda; padding: 15px; margin: 10px 0; border-radius: 5px; }
          </style>
      </head>
      <body>
          <div class="header">
              <h1>✅ Volume Mounting Success!</h1>
              <p>This demonstrates a properly configured volume mount</p>
          </div>
          <div class="content">
              <div class="success">
                  <h3>Volume Mount Details:</h3>
                  <ul>
                      <li><strong>PVC:</strong> working-example-pvc</li>
                      <li><strong>Mount Path:</strong> /usr/share/nginx/html</li>
                      <li><strong>Storage Class:</strong> do-block-storage</li>
                      <li><strong>Access Mode:</strong> ReadWriteOnce</li>
                      <li><strong>Size:</strong> 5Gi</li>
                  </ul>
              </div>
              <div class="success">
                  <h3>Best Practices Applied:</h3>
                  <ul>
                      <li>Correct security context with fsGroup</li>
                      <li>Appropriate resource requests and limits</li>
                      <li>Valid storage class</li>
                      <li>Proper volume mount configuration</li>
                      <li>Health checks and monitoring</li>
                  </ul>
              </div>
          </div>
      </body>
      </html>
      HTML_EOF
      
      # Создать nginx конфигурацию
      cat > /etc/nginx/conf.d/default.conf << 'NGINX_EOF'
      server {
          listen 80;
          server_name localhost;
          
          location / {
              root /usr/share/nginx/html;
              index index.html;
          }
          
          location /health {
              access_log off;
              return 200 "healthy\n";
              add_header Content-Type text/plain;
          }
          
          location /volume-info {
              access_log off;
              return 200 "Volume mounted successfully at /usr/share/nginx/html\n";
              add_header Content-Type text/plain;
          }
      }
      NGINX_EOF
      
      echo "Volume mounted successfully!"
      echo "Starting nginx..."
      nginx -g "daemon off;"
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
    livenessProbe:
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: working-example-pvc
  - name: config-volume
    emptyDir: {}
POD_EOF
    
    echo "✅ Working example created"
    echo
}

# Функция для диагностики проблем
diagnose_issues() {
    echo "=== Diagnosing Volume Mounting Issues ==="
    
    echo "1. Checking Pod status:"
    kubectl get pods -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp"
    echo
    
    echo "2. Checking PVC status:"
    kubectl get pvc -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "3. Checking PV status:"
    kubectl get pv -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name,CAPACITY:.spec.capacity.storage,STORAGECLASS:.spec.storageClassName"
    echo
    
    echo "4. Detailed analysis of problematic pods:"
    
    # Анализ каждого pod'а с проблемами
    problematic_pods=($(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    
    for pod in "${problematic_pods[@]}"; do
        if [ -z "$pod" ]; then
            continue
        fi
        
        echo "----------------------------------------"
        echo "Analyzing pod: $pod"
        
        # Статус pod'а
        phase=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
        echo "  Phase: $phase"
        
        # Условия pod'а
        echo "  Conditions:"
        kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.conditions[*].type}:{.status.conditions[*].status}:{.status.conditions[*].message}' | tr ' ' '\n' | while IFS=':' read type status message; do
            echo "    $type: $status - $message"
        done
        
        # События pod'а
        echo "  Recent events:"
        kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$pod --sort-by='.lastTimestamp' | tail -5 | while read line; do
            echo "    $line"
        done
        
        # Проверка volume mounts
        echo "  Volume mounts:"
        kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.volumes[*].name}:{.spec.volumes[*].persistentVolumeClaim.claimName}' | tr ' ' '\n' | while IFS=':' read vol_name pvc_name; do
            if [ -n "$pvc_name" ]; then
                pvc_status=$(kubectl get pvc $pvc_name -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
                echo "    Volume: $vol_name -> PVC: $pvc_name (Status: $pvc_status)"
            fi
        done
        
        echo
    done
}

# Функция для решения проблем
fix_issues() {
    echo "=== Fixing Volume Mounting Issues ==="
    
    echo "1. Fixing permission issue:"
    # Обновить security context для permission issue pod
    kubectl patch pod permission-issue-pod -n $NAMESPACE -p '{"spec":{"securityContext":{"fsGroup":0}}}' 2>/dev/null || echo "  Could not patch permission issue pod"
    
    echo "2. Fixing timeout issue:"
    # Удалить PVC с неправильным storage class и создать новый
    kubectl delete pvc timeout-issue-pvc -n $NAMESPACE 2>/dev/null || echo "  PVC already deleted or not found"
    
    cat << PVC_EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: timeout-issue-pvc-fixed
  namespace: $NAMESPACE
  labels:
    issue.type: timeout-fixed
    app.kubernetes.io/name: hashfoundry-storage
  annotations:
    troubleshooting.hashfoundry.io/issue: "timeout-fixed"
spec:
  storageClassName: do-block-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
PVC_EOF
    
    # Обновить pod для использования нового PVC
    kubectl delete pod timeout-issue-pod -n $NAMESPACE 2>/dev/null || echo "  Pod already deleted or not found"
    
    echo "3. Fixing node affinity issue:"
    # Получить имя реального node
    real_node=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    
    # Обновить PV с правильным node affinity
    kubectl patch pv node-affinity-issue-pv -p "{\"spec\":{\"nodeAffinity\":{\"required\":{\"nodeSelectorTerms\":[{\"matchExpressions\":[{\"key\":\"kubernetes.io/hostname\",\"operator\":\"In\",\"values\":[\"$real_node\"]}]}]}}}}" 2>/dev/null || echo "  Could not patch PV node affinity"
    
    echo "4. Fixing resource constraint issue:"
    # Обновить PVC с разумным размером
    kubectl patch pvc resource-constraint-pvc -n $NAMESPACE -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}' 2>/dev/null || echo "  Could not patch PVC size"
    
    echo "✅ Attempted to fix all issues"
    echo
}

# Функция для создания troubleshooting guide
create_troubleshooting_guide() {
    echo "=== Volume Mounting Troubleshooting Guide ==="
    
    cat << 'GUIDE_EOF'
Volume Mounting Troubleshooting Checklist
=========================================

1. Check Pod Status:
   kubectl get pods -n <namespace>
   kubectl describe pod <pod-name> -n <namespace>

2. Check PVC Status:
   kubectl get pvc -n <namespace>
   kubectl describe pvc <pvc-name> -n <namespace>

3. Check PV Status:
   kubectl get pv
   kubectl describe pv <pv-name>

4. Check Events:
   kubectl get events -n <namespace> --sort-by='.lastTimestamp'

5. Check Storage Class:
   kubectl get storageclass
   kubectl describe storageclass <storage-class-name>

6. Check CSI Driver:
   kubectl get csidriver
   kubectl get pods -n kube-system | grep csi

Common Issues and Solutions:

Permission Issues:
- Symptom: "Permission denied" errors
- Solution: Set correct fsGroup in securityContext
- Example: securityContext: { fsGroup: 1000 }

Mount Timeout:
- Symptom: Pod stuck in ContainerCreating
- Solution: Check storage class exists and CSI driver is running
- Check: kubectl get storageclass <class-name>

Node Affinity Mismatch:
- Symptom: Pod cannot be scheduled
- Solution: Ensure PV node affinity matches available nodes
- Check: kubectl get nodes --show-labels

Resource Constraints:
- Symptom: PVC stuck in Pending
- Solution: Check available storage capacity
- Check: kubectl describe pvc <pvc-name>

Storage Class Issues:
- Symptom: PVC not binding to PV
- Solution: Verify storage class configuration
- Check: kubectl describe storageclass <class-name>

CSI Driver Issues:
- Symptom: Volume attachment failures
- Solution: Check CSI driver pods are running
- Check: kubectl get pods -n kube-system | grep csi

Best Practices:
- Always set appropriate securityContext
- Use resource requests and limits
- Monitor storage usage
- Test volume mounting in development
- Use health checks for applications
- Implement proper error handling
- Document storage requirements

Debugging Commands:
- kubectl logs <pod-name> -n <namespace>
- kubectl exec <pod-name> -n <namespace> -- df -h
- kubectl exec <pod-name> -n <namespace> -- ls -la /mount/path
- kubectl get events --field-selector involvedObject.name=<resource-name>

GUIDE_EOF
    
    echo
}

# Функция для мониторинга состояния
monitor_status() {
    echo "=== Monitoring Volume Mounting Status ==="
    
    while true; do
        clear
        echo "=== Real-time Volume Mounting Status ==="
        echo "Time: $(date)"
        echo
        
        echo "Pod Status:"
        kubectl get pods -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,ISSUE:.metadata.annotations.troubleshooting\.hashfoundry\.io/issue"
        echo
        
        echo "PVC Status:"
        kubectl get pvc -n $NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,ISSUE:.metadata.annotations.troubleshooting\.hashfoundry\.io/issue"
        echo
        
        echo "Recent Events:"
        kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -5
        echo
        
        echo "Press Ctrl+C to stop monitoring..."
        sleep 10
    done
}

# Основная функция
main() {
    case "$2" in
        "create-issues")
            create_permission_issue
            create_mount_timeout_issue
            create_node_affinity_issue
            create_resource_constraint_issue
            ;;
        "create-working")
            create_working_example
            ;;
        "diagnose")
            diagnose_issues
            ;;
        "fix")
            fix_issues
            ;;
        "guide")
            create_troubleshooting_guide
            ;;
        "monitor")
            monitor_status
            ;;
        "demo"|"full")
            create_permission_issue
            create_mount_timeout_issue
            create_node_affinity_issue
            create_resource_constraint_issue
            create_working_example
            sleep 30
            diagnose_issues
            fix_issues
            sleep 30
            diagnose_issues
            create_troubleshooting_guide
            ;;
        *)
            echo "Usage: $0 [namespace] [action]"
            echo ""
            echo "Actions:"
            echo "  create-issues    - Create various volume mounting issues"
            echo "  create-working   - Create working example"
            echo "  diagnose         - Diagnose current issues"
            echo "  fix              - Attempt to fix issues"
            echo "  guide            - Show troubleshooting guide"
            echo "  monitor          - Monitor status in real-time"
            echo "  demo             - Full demonstration (default)"
            echo ""
            echo "Examples:"
            echo "  $0 volume-troubleshooting-demo"
            echo "  $0 volume-troubleshooting-demo diagnose"
            echo "  $0 volume-troubleshooting-demo fix"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x troubleshoot-volume-mounting.sh

# Запустить демонстрацию
./troubleshoot-volume-mounting.sh volume-troubleshooting-demo demo
```

### **3. Практические команды для диагностики:**
```bash
# Основные команды для troubleshooting volume mounting
echo "=== Volume Mounting Troubleshooting Commands ==="

# 1. Проверка статуса Pod'ов
echo "Check Pod status:"
echo "kubectl get pods -n <namespace>"
echo "kubectl describe pod <pod-name> -n <namespace>"
echo

# 2. Проверка PVC
echo "Check PVC status:"
echo "kubectl get pvc -n <namespace>"
echo "kubectl describe pvc <pvc-name> -n <namespace>"
echo

# 3. Проверка PV
echo "Check PV status:"
echo "kubectl get pv"
echo "kubectl describe pv <pv-name>"
echo

# 4. Проверка событий
echo "Check events:"
echo "kubectl get events -n <namespace> --sort-by='.lastTimestamp'"
echo "kubectl get events --field-selector involvedObject.name=<pod-name>"
echo

# 5. Проверка логов
echo "Check logs:"
echo "kubectl logs <pod-name> -n <namespace>"
echo "kubectl logs <pod-name> -n <namespace> -c <container-name>"
echo

# 6. Проверка mount points внутри Pod'а
echo "Check mount points:"
echo "kubectl exec <pod-name> -n <namespace> -- df -h"
echo "kubectl exec <pod-name> -n <namespace> -- ls -la /mount/path"
echo "kubectl exec <pod-name> -n <namespace> -- mount | grep /mount/path"
```

### **4. Создание утилиты для автоматической диагностики:**
```bash
# Создать утилиту для автоматической диагностики volume issues
cat << 'EOF' > volume-health-check.sh
#!/bin/bash

NAMESPACE=${1:-"default"}
POD_NAME=${2:-""}

echo "=== Volume Health Check ==="
echo "Namespace: $NAMESPACE"
if [ -n "$POD_NAME" ]; then
    echo "Pod: $POD_NAME"
fi
echo

# Функция для проверки здоровья volume mounting
check_volume_health() {
    local namespace=$1
    local pod_name=$2
    
    if [ -n "$pod_name" ]; then
        # Проверка конкретного pod'а
        check_single_pod_volumes "$namespace" "$pod_name"
    else
        # Проверка всех pod'ов в namespace
        pods=($(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
        
        for pod in "${pods[@]}"; do
            if [ -n "$pod" ]; then
                check_single_pod_volumes "$namespace" "$pod"
            fi
        done
    fi
}

# Функция для проверки volumes одного pod'а
check_single_pod_volumes() {
    local namespace=$1
    local pod_name=$2
    
    echo "----------------------------------------"
    echo "Checking pod: $pod_name"
    
    # Статус pod'а
    phase=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
    ready=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
    
    echo "  Status: $phase (Ready: $ready)"
    
    if [ "$phase" != "Running" ]; then
        echo "  ❌ Pod is not running"
        
        # Проверить причины
        conditions=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.status=="False")].message}' 2>/dev/null)
        if [ -n "$conditions" ]; then
            echo "  Issues: $conditions"
        fi
        
        # Проверить события
        echo "  Recent events:"
        kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp' | tail -3
    else
        echo "  ✅ Pod is running"
        
        # Проверить volume mounts внутри pod'а
        echo "  Volume mounts:"
        volumes=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.volumes[*].name}' 2>/dev/null)
        for vol in $volumes; do
            mount_path=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name=='$vol')].mountPath}" 2>/dev/null)
            if [ -n "$mount_path" ]; then
                echo "    Volume: $vol -> $mount_path"
                
                # Проверить доступность mount point
                kubectl exec "$pod_name" -n "$namespace" -- test -d "$mount_path" 2>/dev/null && echo "      ✅ Mount point accessible" || echo "      ❌ Mount point not accessible"
                
                # Проверить права доступа
                perms=$(kubectl exec "$pod_name" -n "$namespace" -- ls -ld "$mount_path" 2>/dev/null | awk '{print $1}')
                echo "      Permissions: $perms"
            fi
        done
    fi
    
    echo
}

# Запустить проверку
check_volume_health "$NAMESPACE" "$POD_NAME"

EOF

chmod +x volume-health-check.sh
```

## 📋 **Основные команды для troubleshooting:**

### **Диагностика:**
```bash
# Проверка статуса
kubectl get pods,pvc,pv -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>

# Проверка событий
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=<resource-name>

# Проверка логов
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> -c <container-name>

# Проверка mount points
kubectl exec <pod-name> -n <namespace> -- df -h
kubectl exec <pod-name> -n <namespace> -- ls -la /mount/path
```

## 🔧 **Решение распространенных проблем:**

### **Permission Issues:**
```bash
# Установить правильный fsGroup
spec:
  securityContext:
    fsGroup: 1000
```

### **Mount Timeout:**
```bash
# Проверить StorageClass
kubectl get storageclass <class-name>
kubectl describe storageclass <class-name>

# Проверить CSI driver
kubectl get pods -n kube-system | grep csi
```

### **Node Affinity:**
```bash
# Проверить node labels
kubectl get nodes --show-labels
kubectl describe pv <pv-name>
```

## 🎯 **Best Practices:**

### **Предотвращение проблем:**
- **Правильный securityContext** с fsGroup
- **Валидация StorageClass** перед использованием
- **Мониторинг storage usage**
- **Тестирование в dev среде**

### **Быстрая диагностика:**
- **Проверка событий** в первую очередь
- **Анализ логов** Pod'ов и CSI drivers
- **Проверка permissions** внутри контейнеров

**Правильная диагностика volume mounting issues критически важна для стабильности приложений!**
