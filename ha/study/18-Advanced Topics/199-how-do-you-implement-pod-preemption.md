# 199. How do you implement pod preemption?

## 🎯 Вопрос
How do you implement pod preemption?

## 💡 Ответ

Pod Preemption - это механизм в Kubernetes, который позволяет высокоприоритетным подам вытеснять (preempt) низкоприоритетные поды для освобождения ресурсов на узлах. Это обеспечивает гарантированное выполнение критически важных рабочих нагрузок.

### 🏗️ Архитектура Pod Preemption

#### 1. **Схема Pod Preemption Flow**
```
┌─────────────────────────────────────────────────────────────┐
│                Pod Preemption Architecture                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                High Priority Pod                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Critical  │    │  System     │    │  Production │ │ │
│  │  │   Service   │───▶│  Component  │───▶│  Workload   │ │ │
│  │  │ Priority:100│    │ Priority:90 │    │ Priority:80 │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   Scheduler                            │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Priority  │    │ Preemption  │    │   Node      │ │ │
│  │  │   Queue     │───▶│   Logic     │───▶│ Selection   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Preemption Decision                     │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Victim    │    │ Graceful    │    │   Resource  │ │ │
│  │  │ Selection   │───▶│ Termination │───▶│ Allocation  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Node Resources                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Low Priority│    │ Medium      │    │ High        │ │ │
│  │  │ Pods (evict)│───▶│ Priority    │───▶│ Priority    │ │ │
│  │  │ Priority:10 │    │ Priority:50 │    │ Priority:100│ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Priority Classes и Preemption Policy**
```yaml
# Priority Classes and Preemption Policy
priority_classes:
  system_priorities:
    system_cluster_critical:
      value: 2000000000
      description: "Used for system critical pods"
      global_default: false
      preemption_policy: "PreemptLowerPriority"
    
    system_node_critical:
      value: 2000001000
      description: "Used for node critical pods"
      global_default: false
      preemption_policy: "PreemptLowerPriority"

  application_priorities:
    high_priority:
      value: 1000
      description: "High priority application pods"
      global_default: false
      preemption_policy: "PreemptLowerPriority"
    
    medium_priority:
      value: 500
      description: "Medium priority application pods"
      global_default: false
      preemption_policy: "PreemptLowerPriority"
    
    low_priority:
      value: 100
      description: "Low priority application pods"
      global_default: true
      preemption_policy: "Never"

  preemption_policies:
    preempt_lower_priority:
      behavior: "Preempt lower priority pods"
      conditions:
        - "Target pod priority > victim pod priority"
        - "No suitable nodes without preemption"
        - "Preemption enables scheduling"
    
    never:
      behavior: "Never preempt other pods"
      use_cases:
        - "Best effort workloads"
        - "Batch jobs"
        - "Development environments"

  preemption_algorithm:
    victim_selection:
      criteria:
        - "Lowest priority first"
        - "Newest pods first (within same priority)"
        - "Minimize disruption"
        - "Consider PodDisruptionBudgets"
      
      constraints:
        - "Respect PodDisruptionBudgets"
        - "Honor graceful termination"
        - "Consider node affinity"
        - "Minimize cross-zone impact"
    
    scheduling_cycle:
      phases:
        - "Filter nodes for preemption candidates"
        - "Score nodes based on preemption cost"
        - "Select optimal node and victims"
        - "Initiate graceful termination"
        - "Schedule high priority pod"

  graceful_termination:
    process:
      - "Send SIGTERM to victim pods"
      - "Wait for graceful shutdown period"
      - "Send SIGKILL if needed"
      - "Clean up resources"
      - "Update node capacity"
    
    considerations:
      - "terminationGracePeriodSeconds"
      - "preStop hooks execution"
      - "Data persistence requirements"
      - "Service disruption minimization"
```

### 📊 Примеры из нашего кластера

#### Проверка Priority Classes и Preemption:
```bash
# Проверка priority classes
kubectl get priorityclasses

# Проверка подов с приоритетами
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,PRIORITY:.spec.priority,PRIORITY_CLASS:.spec.priorityClassName

# Проверка событий preemption
kubectl get events --all-namespaces --field-selector reason=Preempted

# Проверка scheduler logs
kubectl logs -n kube-system -l component=kube-scheduler | grep -i preempt

# Проверка ресурсов узлов
kubectl top nodes
kubectl describe nodes | grep -A 10 "Allocated resources"
```

### 🛠️ Реализация Pod Preemption

#### 1. **Priority Classes Configuration**
```yaml
# priority-classes.yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-priority
value: 1000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Critical priority for essential services"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 800
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "High priority for important services"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: medium-priority
value: 500
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Medium priority for regular services"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: true
preemptionPolicy: Never
description: "Low priority for batch jobs and development"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: best-effort
value: 0
globalDefault: false
preemptionPolicy: Never
description: "Best effort workloads that can be preempted"
```

#### 2. **High Priority Application**
```yaml
# critical-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: critical-service
  template:
    metadata:
      labels:
        app: critical-service
    spec:
      priorityClassName: critical-priority
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
      terminationGracePeriodSeconds: 30
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
                  - critical-service
              topologyKey: kubernetes.io/hostname

---
# Service for critical application
apiVersion: v1
kind: Service
metadata:
  name: critical-service
  namespace: production
spec:
  selector:
    app: critical-service
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# PodDisruptionBudget for critical service
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-service-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: critical-service
```

#### 3. **Low Priority Batch Job**
```yaml
# batch-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing-job
  namespace: batch
spec:
  parallelism: 5
  completions: 10
  backoffLimit: 3
  template:
    metadata:
      labels:
        app: data-processing
        priority: low
    spec:
      priorityClassName: low-priority
      restartPolicy: Never
      containers:
      - name: processor
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting data processing job..."
          # Simulate CPU intensive work
          for i in $(seq 1 300); do
            echo "Processing batch $i"
            sleep 1
          done
          echo "Job completed"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
      terminationGracePeriodSeconds: 10
      tolerations:
      - key: "batch-workload"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"

---
# CronJob for regular batch processing
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scheduled-batch-job
  namespace: batch
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: scheduled-batch
        spec:
          priorityClassName: best-effort
          restartPolicy: OnFailure
          containers:
          - name: batch-processor
            image: alpine:latest
            command: ["/bin/sh"]
            args:
            - -c
            - |
              echo "Starting scheduled batch job..."
              # Simulate long-running batch work
              sleep 3600
              echo "Batch job completed"
            resources:
              requests:
                cpu: 50m
                memory: 64Mi
              limits:
                cpu: 200m
                memory: 128Mi
          terminationGracePeriodSeconds: 5
```

#### 4. **Preemption Test Scenarios**
```yaml
# preemption-test.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: preemption-test

---
# Resource-intensive low priority pods
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hog
  namespace: preemption-test
spec:
  replicas: 10
  selector:
    matchLabels:
      app: resource-hog
  template:
    metadata:
      labels:
        app: resource-hog
    spec:
      priorityClassName: low-priority
      containers:
      - name: hog
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting resource-intensive task..."
          # Consume CPU and memory
          while true; do
            dd if=/dev/zero of=/tmp/test bs=1M count=100 2>/dev/null
            rm /tmp/test
            sleep 1
          done
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      terminationGracePeriodSeconds: 5

---
# High priority pod that should preempt low priority ones
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-preemptor
  namespace: preemption-test
spec:
  priorityClassName: high-priority
  containers:
  - name: preemptor
    image: nginx:alpine
    resources:
      requests:
        cpu: 1000m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 2Gi
    ports:
    - containerPort: 80
  terminationGracePeriodSeconds: 30
```

### 🔧 Утилиты для тестирования Pod Preemption

#### Скрипт для тестирования preemption:
```bash
#!/bin/bash
# test-pod-preemption.sh

echo "🧪 Testing Pod Preemption"

# Test priority class setup
test_priority_classes() {
    echo "=== Testing Priority Classes ==="
    
    # Check if priority classes exist
    echo "--- Available Priority Classes ---"
    kubectl get priorityclasses -o custom-columns=NAME:.metadata.name,VALUE:.value,PREEMPTION:.preemptionPolicy,DEFAULT:.globalDefault
    
    # Verify priority class values
    critical_priority=$(kubectl get priorityclass critical-priority -o jsonpath='{.value}' 2>/dev/null || echo "0")
    high_priority=$(kubectl get priorityclass high-priority -o jsonpath='{.value}' 2>/dev/null || echo "0")
    low_priority=$(kubectl get priorityclass low-priority -o jsonpath='{.value}' 2>/dev/null || echo "0")
    
    echo "Priority values: Critical=$critical_priority, High=$high_priority, Low=$low_priority"
    
    if [ "$critical_priority" -gt "$high_priority" ] && [ "$high_priority" -gt "$low_priority" ]; then
        echo "✅ Priority classes configured correctly"
    else
        echo "❌ Priority class values are not properly ordered"
    fi
}

# Test preemption scenario
test_preemption_scenario() {
    echo "=== Testing Preemption Scenario ==="
    
    # Create test namespace
    kubectl create namespace preemption-test --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy low priority resource-intensive pods
    echo "--- Deploying low priority pods ---"
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: low-priority-workload
  namespace: preemption-test
spec:
  replicas: 5
  selector:
    matchLabels:
      app: low-priority-workload
  template:
    metadata:
      labels:
        app: low-priority-workload
    spec:
      priorityClassName: low-priority
      containers:
      - name: workload
        image: busybox
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
EOF

    # Wait for low priority pods to be scheduled
    echo "Waiting for low priority pods to be scheduled..."
    kubectl wait --for=condition=ready pod -l app=low-priority-workload -n preemption-test --timeout=120s
    
    if [ $? -eq 0 ]; then
        echo "✅ Low priority pods scheduled successfully"
        kubectl get pods -n preemption-test -o wide
    else
        echo "❌ Low priority pods failed to schedule"
        return 1
    fi
    
    # Check node resource usage
    echo "--- Node resource usage before preemption ---"
    kubectl top nodes
    
    # Deploy high priority pod that should trigger preemption
    echo "--- Deploying high priority pod ---"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-pod
  namespace: preemption-test
spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: 2000m
        memory: 2Gi
      limits:
        cpu: 4000m
        memory: 4Gi
EOF

    # Monitor preemption events
    echo "--- Monitoring preemption events ---"
    sleep 10
    
    # Check for preemption events
    preemption_events=$(kubectl get events -n preemption-test --field-selector reason=Preempted --no-headers | wc -l)
    if [ "$preemption_events" -gt 0 ]; then
        echo "✅ Preemption events detected: $preemption_events"
        kubectl get events -n preemption-test --field-selector reason=Preempted
    else
        echo "⚠️  No preemption events found (may indicate sufficient resources)"
    fi
    
    # Check if high priority pod is scheduled
    kubectl wait --for=condition=PodScheduled pod/high-priority-pod -n preemption-test --timeout=60s
    if [ $? -eq 0 ]; then
        echo "✅ High priority pod scheduled successfully"
    else
        echo "❌ High priority pod failed to schedule"
    fi
    
    # Show final pod status
    echo "--- Final pod status ---"
    kubectl get pods -n preemption-test -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,PRIORITY:.spec.priority,NODE:.spec.nodeName
}

# Test graceful termination during preemption
test_graceful_termination() {
    echo "=== Testing Graceful Termination ==="
    
    # Create pod with long termination grace period
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: graceful-termination-test
  namespace: preemption-test
spec:
  priorityClassName: low-priority
  terminationGracePeriodSeconds: 60
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh"]
    args:
    - -c
    - |
      trap 'echo "Received SIGTERM, starting graceful shutdown..."; sleep 30; echo "Graceful shutdown completed"' TERM
      echo "Pod started, waiting for signals..."
      while true; do sleep 1; done
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod/graceful-termination-test -n preemption-test --timeout=60s
    
    # Create high priority pod to trigger preemption
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: preemptor-pod
  namespace: preemption-test
spec:
  priorityClassName: critical-priority
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
EOF

    # Monitor termination process
    echo "--- Monitoring graceful termination ---"
    start_time=$(date +%s)
    
    # Wait for pod to start terminating
    while kubectl get pod graceful-termination-test -n preemption-test >/dev/null 2>&1; do
        status=$(kubectl get pod graceful-termination-test -n preemption-test -o jsonpath='{.status.phase}')
        if [ "$status" = "Terminating" ]; then
            echo "Pod is terminating gracefully..."
            break
        fi
        sleep 2
    done
    
    # Wait for pod to be fully terminated
    kubectl wait --for=delete pod/graceful-termination-test -n preemption-test --timeout=120s
    end_time=$(date +%s)
    termination_time=$((end_time - start_time))
    
    echo "✅ Pod terminated in ${termination_time}s"
}

# Test PodDisruptionBudget interaction
test_pdb_interaction() {
    echo "=== Testing PDB Interaction with Preemption ==="
    
    # Create deployment with PDB
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pdb-protected-app
  namespace: preemption-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pdb-protected-app
  template:
    metadata:
      labels:
        app: pdb-protected-app
    spec:
      priorityClassName: medium-priority
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-protected-app-pdb
  namespace: preemption-test
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: pdb-protected-app
EOF

    # Wait for deployment
    kubectl wait --for=condition=available deployment/pdb-protected-app -n preemption-test --timeout=120s
    
    # Try to preempt with high priority pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pdb-preemptor
  namespace: preemption-test
spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: 1000m
        memory: 1Gi
EOF

    # Check PDB status
    echo "--- PDB Status ---"
    kubectl get pdb -n preemption-test
    
    # Check if preemption respects PDB
    sleep 10
    running_pods=$(kubectl get pods -n preemption-test -l app=pdb-protected-app --field-selector=status.phase=Running --no-headers | wc -l)
    echo "Running PDB-protected pods: $running_pods"
    
    if [ "$running_pods" -ge 2 ]; then
        echo "✅ PDB respected during preemption"
    else
        echo "❌ PDB violated during preemption"
    fi
}

# Performance testing
test_preemption_performance() {
    echo "=== Testing Preemption Performance ==="
    
    local count=${1:-10}
    echo "Creating $count low priority pods..."
    
    # Create many low priority pods
    for i in $(seq 1 $count); do
        cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: perf-low-$i
  namespace: preemption-test
spec:
  priorityClassName: low-priority
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF
    done
    
    # Wait for pods to be scheduled
    sleep 30
    
    # Create high priority pod to trigger mass preemption
    start_time=$(date +%s)
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: mass-preemptor
  namespace: preemption-test
spec:
  priorityClassName: critical-priority
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: 2000m
        memory: 2Gi
EOF

    # Wait for high priority pod to be scheduled
    kubectl wait --for=condition=PodScheduled pod/mass-preemptor -n preemption-test --timeout=120s
    end_time=$(date +%s)
    preemption_time=$((end_time - start_time))
    
    echo "✅ Mass preemption completed in ${preemption_time}s"
    
    # Count preempted pods
    preempted_count=$(kubectl get events -n preemption-test --field-selector reason=Preempted --no-headers | wc -l)
    echo "Pods preempted: $preempted_count"
}

# Cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up Test Resources ==="
    
    kubectl delete namespace preemption-test --ignore-not-found=true
    echo "✅ Cleanup completed"
}

# Main execution
main() {
    echo "Testing Pod Preemption"
    echo ""
    
    # Run tests
    test_priority_classes
    echo ""
    
    test_preemption_scenario
    echo ""
    
    test_graceful_termination
    echo ""
    
    test_pdb_interaction
    echo ""
    
    test_preemption_performance 5
    echo ""
    
    read -p "Cleanup test resources? (y/n): " cleanup
    if [ "$cleanup" = "y" ]; then
        cleanup_test_resources
    fi
}

# Check if arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0"
    echo ""
    echo "Running pod preemption tests..."
    main
else
    main "$@"
fi
```

### 🎯 Заключение

Pod Preemption обеспечивает гарантированное выполнение критически важных рабочих нагрузок:

**Ключевые возможности:**
1. **Priority-based scheduling** - планирование на основе приоритетов
2. **Graceful termination** - корректное завершение вытесняемых подов
3. **PDB respect** - учет PodDisruptionBudgets при вытеснении
4. **Resource optimization** - эффективное использование ресурсов кластера

**Архитектурные принципы:**
1. **Priority Classes** - определение уровней приоритета
2. **Preemption Policies** - настройка поведения вытеснения
3. **Victim Selection** - алгоритм выбора подов для вытеснения
4. **Graceful Handling** - минимизация disruption при вытеснении

**Практические применения:**
- **Critical Services** - гарантированные ресурсы для важных сервисов
- **Batch Processing** - эффективное использование ресурсов для пакетных задач
- **Multi-tenant Clusters** - справедливое распределение ресурсов
- **Emergency Response** - быстрое выделение ресурсов в критических ситуациях

Pod Preemption является важным механизмом для обеспечения SLA и эффективного управления ресурсами в production Kubernetes кластерах.
