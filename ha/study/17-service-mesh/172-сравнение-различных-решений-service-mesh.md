# 172. Сравнение различных решений service mesh

## 🎯 **Что такое сравнение service mesh решений?**

**Сравнение service mesh решений** — это комплексный анализ различных платформ управления микросервисной коммуникацией, включающий оценку Istio vs Linkerd vs Consul Connect vs AWS App Mesh vs Cilium по критериям performance overhead, feature completeness, operational complexity, security capabilities, observability depth и ecosystem integration для выбора оптимального решения под конкретные требования.

## 🏗️ **Основные service mesh решения:**

### **1. Istio - Enterprise-grade платформа**
- **Strengths**: Максимальная функциональность, rich traffic management
- **Weaknesses**: Высокая сложность, значительный resource overhead
- **Best for**: Enterprise environments, complex microservices
- **Proxy**: Envoy, Control Plane: Istiod

### **2. Linkerd - Simplicity-focused решение**
- **Strengths**: Простота, низкий overhead, Rust-based proxy
- **Weaknesses**: Ограниченная функциональность, меньше features
- **Best for**: Performance-critical apps, quick adoption
- **Proxy**: Linkerd2-proxy, Control Plane: Linkerd Controller

### **3. Consul Connect - HashiCorp ecosystem**
- **Strengths**: Интеграция с Vault/Nomad, multi-platform
- **Weaknesses**: Меньше Kubernetes-native features
- **Best for**: HashiCorp environments, hybrid deployments
- **Proxy**: Envoy/Built-in, Control Plane: Consul

### **4. AWS App Mesh - Cloud-native решение**
- **Strengths**: AWS integration, managed service
- **Weaknesses**: Vendor lock-in, AWS-specific
- **Best for**: AWS-heavy workloads, managed operations
- **Proxy**: Envoy, Control Plane: AWS Managed

### **5. Cilium Service Mesh - eBPF-powered**
- **Strengths**: eBPF performance, network-focused
- **Weaknesses**: Новое решение, ограниченная зрелость
- **Best for**: Network-intensive apps, performance optimization
- **Proxy**: eBPF, Control Plane: Cilium Agent

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ текущих service mesh возможностей:**
```bash
# Проверка доступных service mesh решений
kubectl get namespace istio-system linkerd cilium-system consul --ignore-not-found
kubectl get pods -n kube-system -l k8s-app=cilium

# Анализ CNI совместимости
kubectl get pods -n kube-system -o jsonpath='{.items[*].spec.containers[*].image}' | grep -E "(calico|cilium|flannel|weave)"

# Проверка ресурсов кластера для service mesh
kubectl top nodes
kubectl describe nodes | grep -E "(Capacity|Allocatable)" -A 5

# Анализ текущего network policy support
kubectl get networkpolicies --all-namespaces
```

### **2. Диагностика service mesh readiness:**
```bash
# Проверка Kubernetes версии для совместимости
kubectl version --short

# Анализ доступных ресурсов
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory,PODS:.status.capacity.pods

# Проверка storage classes для persistent volumes
kubectl get storageclass

# Анализ load balancer capabilities
kubectl get svc -o wide | grep LoadBalancer
```

### **3. Мониторинг service mesh performance baseline:**
```bash
# Baseline network performance
kubectl run network-test --image=busybox --rm -i --restart=Never -- sh -c "time wget -q -O- http://prometheus-server.monitoring/ > /dev/null"

# Проверка current latency между сервисами
kubectl exec deployment/argocd-server -n argocd -- time curl -s http://grafana.monitoring/ > /dev/null

# Анализ current resource usage
kubectl top pods --all-namespaces --containers | head -20
```

## 🔄 **Демонстрация comprehensive service mesh comparison:**

### **1. Создание multi-mesh evaluation framework:**
```bash
# Создать скрипт service-mesh-evaluator.sh
cat << 'EOF' > service-mesh-evaluator.sh
#!/bin/bash

echo "🔍 Comprehensive Service Mesh Evaluation Framework"
echo "================================================="

# Настройка переменных
EVALUATION_NAMESPACE="mesh-evaluation"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
EVALUATION_LOG="/var/log/service-mesh-evaluation-$TIMESTAMP.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $EVALUATION_LOG
}

# Функция анализа cluster readiness
analyze_cluster_readiness() {
    log "🏥 Анализ готовности кластера для service mesh"
    
    local readiness_report="/tmp/cluster-readiness-$TIMESTAMP.json"
    
    # Comprehensive cluster assessment
    cat > $readiness_report << READINESS_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "cluster": "$(kubectl config current-context)",
  "cluster_readiness": {
    "kubernetes_version": "$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")",
    "node_resources": {
      "total_nodes": $(kubectl get nodes --no-headers | wc -l),
      "ready_nodes": $(kubectl get nodes --no-headers | grep Ready | wc -l),
      "total_cpu": "$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.cpu}' | tr ' ' '\n' | awk '{sum += $1} END {print sum}')cores",
      "total_memory": "$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.memory}' | tr ' ' '\n' | sed 's/Ki$//' | awk '{sum += $1} END {print sum/1024/1024 "GB"}')",
      "total_pods_capacity": $(kubectl get nodes -o jsonpath='{.items[*].status.capacity.pods}' | tr ' ' '\n' | awk '{sum += $1} END {print sum}')
    },
    "network_capabilities": {
      "cni_plugin": "$(kubectl get pods -n kube-system -o jsonpath='{.items[*].spec.containers[*].image}' | grep -o -E '(calico|cilium|flannel|weave)' | head -1 || echo "unknown")",
      "network_policies_supported": $(kubectl get networkpolicies --all-namespaces --no-headers | wc -l | awk '{if($1>0) print "true"; else print "false"}'),
      "load_balancer_available": $(kubectl get svc --all-namespaces -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].metadata.name}' | wc -w | awk '{if($1>0) print "true"; else print "false"}')
    },
    "storage_capabilities": {
      "storage_classes": $(kubectl get storageclass --no-headers | wc -l),
      "default_storage_class": "$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' || echo "none")",
      "persistent_volumes": $(kubectl get pv --no-headers | wc -l)
    }
  },
  "service_mesh_compatibility": {
    "istio_compatible": $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | grep -E "v1\.(2[0-9]|3[0-9])" && echo "true" || echo "false"),
    "linkerd_compatible": $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | grep -E "v1\.(1[8-9]|2[0-9]|3[0-9])" && echo "true" || echo "false"),
    "consul_compatible": $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | grep -E "v1\.(1[6-9]|2[0-9]|3[0-9])" && echo "true" || echo "false"),
    "cilium_compatible": $(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | wc -l | awk '{if($1>0) print "true"; else print "false"}')
  }
}
READINESS_REPORT_EOF
    
    log "📄 Cluster readiness report: $readiness_report"
    
    # Краткая статистика
    local total_cpu=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.cpu}' | tr ' ' '\n' | awk '{sum += $1} END {print sum}')
    local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    local cni_plugin=$(kubectl get pods -n kube-system -o jsonpath='{.items[*].spec.containers[*].image}' | grep -o -E '(calico|cilium|flannel|weave)' | head -1 || echo "unknown")
    
    log "🎯 Cluster Readiness Summary:"
    log "  🖥️ Ready nodes: $ready_nodes"
    log "  ⚡ Total CPU: ${total_cpu} cores"
    log "  🌐 CNI plugin: $cni_plugin"
    
    return 0
}

# Функция создания evaluation environment
create_evaluation_environment() {
    log "🏗️ Создание evaluation environment"
    
    # Создание namespace для тестирования
    kubectl create namespace $EVALUATION_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Развертывание test applications
    kubectl apply -f - << TEST_APPS_EOF
# Frontend application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: $EVALUATION_NAMESPACE
  labels:
    app: frontend
    tier: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: web
    spec:
      containers:
      - name: frontend
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        env:
        - name: BACKEND_URL
          value: "http://backend:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: $EVALUATION_NAMESPACE
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
# Backend application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: $EVALUATION_NAMESPACE
  labels:
    app: backend
    tier: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: api
    spec:
      containers:
      - name: backend
        image: httpd:2.4
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: DATABASE_URL
          value: "http://database:5432"
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: $EVALUATION_NAMESPACE
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 80
---
# Database application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: $EVALUATION_NAMESPACE
  labels:
    app: database
    tier: data
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        tier: data
    spec:
      containers:
      - name: database
        image: postgres:13
        ports:
        - containerPort: 5432
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        env:
        - name: POSTGRES_DB
          value: "testdb"
        - name: POSTGRES_USER
          value: "testuser"
        - name: POSTGRES_PASSWORD
          value: "testpass"
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: $EVALUATION_NAMESPACE
spec:
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
TEST_APPS_EOF
    
    # Ожидание готовности приложений
    kubectl wait --for=condition=available deployment/frontend -n $EVALUATION_NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/backend -n $EVALUATION_NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/database -n $EVALUATION_NAMESPACE --timeout=300s
    
    log "✅ Evaluation environment создан"
}

# Функция baseline performance testing
run_baseline_performance_test() {
    log "📊 Запуск baseline performance test"
    
    local baseline_report="/tmp/baseline-performance-$TIMESTAMP.json"
    
    # Получение service IPs
    local frontend_ip=$(kubectl get svc frontend -n $EVALUATION_NAMESPACE -o jsonpath='{.spec.clusterIP}')
    local backend_ip=$(kubectl get svc backend -n $EVALUATION_NAMESPACE -o jsonpath='{.spec.clusterIP}')
    
    # Запуск performance tests
    cat > $baseline_report << BASELINE_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "test_type": "baseline_without_service_mesh",
  "cluster": "$(kubectl config current-context)",
  "performance_metrics": {
    "frontend_response_time": {
$(kubectl run perf-test-frontend --image=busybox --rm -i --restart=Never --quiet -- sh -c "
time for i in \$(seq 1 10); do
  wget -q -O- http://$frontend_ip/ > /dev/null 2>&1
done" 2>&1 | grep real | awk '{print "      \"average_time\": \"" $2 "\""}')
    },
    "backend_response_time": {
$(kubectl run perf-test-backend --image=busybox --rm -i --restart=Never --quiet -- sh -c "
time for i in \$(seq 1 10); do
  wget -q -O- http://$backend_ip/ > /dev/null 2>&1
done" 2>&1 | grep real | awk '{print "      \"average_time\": \"" $2 "\""}')
    },
    "resource_usage": {
      "total_cpu_usage": "$(kubectl top pods -n $EVALUATION_NAMESPACE --no-headers | awk '{sum+=$2} END {print sum "m"}' | sed 's/m$//' || echo "0")m",
      "total_memory_usage": "$(kubectl top pods -n $EVALUATION_NAMESPACE --no-headers | awk '{sum+=$3} END {print sum "Mi"}' | sed 's/Mi$//' || echo "0")Mi",
      "pod_count": $(kubectl get pods -n $EVALUATION_NAMESPACE --no-headers | wc -l)
    }
  }
}
BASELINE_REPORT_EOF
    
    log "📄 Baseline performance report: $baseline_report"
    
    # Краткая статистика
    local pod_count=$(kubectl get pods -n $EVALUATION_NAMESPACE --no-headers | wc -l)
    local total_cpu=$(kubectl top pods -n $EVALUATION_NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum}' | sed 's/m$//' || echo "0")
    
    log "🎯 Baseline Performance:"
    log "  📦 Active pods: $pod_count"
    log "  ⚡ Total CPU: ${total_cpu}m"
    
    return 0
}

# Функция evaluation Istio
evaluate_istio_performance() {
    log "🔍 Evaluation Istio performance"
    
    # Проверка наличия Istio
    if ! kubectl get namespace istio-system &>/dev/null; then
        log "⚠️ Istio не установлен, пропуск evaluation"
        return 1
    fi
    
    local istio_report="/tmp/istio-evaluation-$TIMESTAMP.json"
    
    # Включение Istio injection
    kubectl label namespace $EVALUATION_NAMESPACE istio-injection=enabled --overwrite
    
    # Перезапуск подов для sidecar injection
    kubectl rollout restart deployment/frontend -n $EVALUATION_NAMESPACE
    kubectl rollout restart deployment/backend -n $EVALUATION_NAMESPACE
    kubectl rollout restart deployment/database -n $EVALUATION_NAMESPACE
    
    # Ожидание готовности
    kubectl wait --for=condition=available deployment/frontend -n $EVALUATION_NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/backend -n $EVALUATION_NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/database -n $EVALUATION_NAMESPACE --timeout=300s
    
    # Проверка sidecar injection
    local sidecar_count=$(kubectl get pods -n $EVALUATION_NAMESPACE -o jsonpath='{.items[*].spec.containers[*].name}' | grep -o istio-proxy | wc -l)
    
    # Performance testing с Istio
    local frontend_ip=$(kubectl get svc frontend -n $EVALUATION_NAMESPACE -o jsonpath='{.spec.clusterIP}')
    
    cat > $istio_report << ISTIO_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "test_type": "istio_service_mesh",
  "cluster": "$(kubectl config current-context)",
  "istio_metrics": {
    "sidecar_injection": {
      "total_sidecars": $sidecar_count,
      "injection_successful": $([ $sidecar_count -gt 0 ] && echo "true" || echo "false")
    },
    "performance_metrics": {
      "frontend_response_time": {
$(kubectl run perf-test-istio --image=busybox --rm -i --restart=Never --quiet -- sh -c "
time for i in \$(seq 1 10); do
  wget -q -O- http://$frontend_ip/ > /dev/null 2>&1
done" 2>&1 | grep real | awk '{print "        \"average_time\": \"" $2 "\""}')
      },
      "resource_usage": {
        "total_cpu_usage": "$(kubectl top pods -n $EVALUATION_NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum "m"}' | sed 's/m$//' || echo "0")m",
        "total_memory_usage": "$(kubectl top pods -n $EVALUATION_NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum "Mi"}' | sed 's/Mi$//' || echo "0")Mi",
        "sidecar_overhead": {
          "cpu": "$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$4} END {print sum "m"}' | sed 's/m$//' || echo "0")m",
          "memory": "$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$5} END {print sum "Mi"}' | sed 's/Mi$//' || echo "0")Mi"
        }
      }
    },
    "security_features": {
      "mtls_enabled": $(kubectl get peerauthentication -n $EVALUATION_NAMESPACE --no-headers | wc -l | awk '{if($1>0) print "true"; else print "false"}'),
      "authorization_policies": $(kubectl get authorizationpolicies -n $EVALUATION_NAMESPACE --no-headers | wc -l)
    }
  }
}
ISTIO_REPORT_EOF
    
    log "📄 Istio evaluation report: $istio_report"
    
    # Краткая статистика
    local sidecar_cpu=$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$4} END {print sum}' | sed 's/m$//' || echo "0")
    local sidecar_memory=$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep istio-proxy | awk '{sum+=$5} END {print sum}' | sed 's/Mi$//' || echo "0")
    
    log "🎯 Istio Performance:"
    log "  🔗 Sidecars injected: $sidecar_count"
    log "  ⚡ Sidecar CPU overhead: ${sidecar_cpu}m"
    log "  💾 Sidecar Memory overhead: ${sidecar_memory}Mi"
    
    return 0
}

# Функция evaluation Linkerd
evaluate_linkerd_performance() {
    log "🔍 Evaluation Linkerd performance"
    
    # Проверка наличия Linkerd
    if ! kubectl get namespace linkerd &>/dev/null; then
        log "⚠️ Linkerd не установлен, пропуск evaluation"
        return 1
    fi
    
    local linkerd_report="/tmp/linkerd-evaluation-$TIMESTAMP.json"
    
    # Отключение Istio injection
    kubectl label namespace $EVALUATION_NAMESPACE istio-injection-
    
    # Включение Linkerd injection
    kubectl annotate namespace $EVALUATION_NAMESPACE linkerd.io/inject=enabled --overwrite
    
    # Перезапуск подов для sidecar injection
    kubectl rollout restart deployment/frontend -n $EVALUATION_NAMESPACE
    kubectl rollout restart deployment/backend -n $EVALUATION_NAMESPACE
    kubectl rollout restart deployment/database -n $EVALUATION_NAMESPACE
    
    # Ожидание готовности
    kubectl wait --for=condition=available deployment/frontend -n $EVALUATION_NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/backend -n $EVALUATION_NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/database -n $EVALUATION_NAMESPACE --timeout=300s
    
    # Проверка sidecar injection
    local sidecar_count=$(kubectl get pods -n $EVALUATION_NAMESPACE -o jsonpath='{.items[*].spec.containers[*].name}' | grep -o linkerd-proxy | wc -l)
    
    # Performance testing с Linkerd
    local frontend_ip=$(kubectl get svc frontend -n $EVALUATION_NAMESPACE -o jsonpath='{.spec.clusterIP}')
    
    cat > $linkerd_report << LINKERD_REPORT_EOF
{
  "timestamp": "$(date -Iseconds)",
  "test_type": "linkerd_service_mesh",
  "cluster": "$(kubectl config current-context)",
  "linkerd_metrics": {
    "sidecar_injection": {
      "total_sidecars": $sidecar_count,
      "injection_successful": $([ $sidecar_count -gt 0 ] && echo "true" || echo "false")
    },
    "performance_metrics": {
      "frontend_response_time": {
$(kubectl run perf-test-linkerd --image=busybox --rm -i --restart=Never --quiet -- sh -c "
time for i in \$(seq 1 10); do
  wget -q -O- http://$frontend_ip/ > /dev/null 2>&1
done" 2>&1 | grep real | awk '{print "        \"average_time\": \"" $2 "\""}')
      },
      "resource_usage": {
        "total_cpu_usage": "$(kubectl top pods -n $EVALUATION_NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum "m"}' | sed 's/m$//' || echo "0")m",
        "total_memory_usage": "$(kubectl top pods -n $EVALUATION_NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum "Mi"}' | sed 's/Mi$//' || echo "0")Mi",
        "sidecar_overhead": {
          "cpu": "$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep linkerd-proxy | awk '{sum+=$4} END {print sum "m"}' | sed 's/m$//' || echo "0")m",
          "memory": "$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep linkerd-proxy | awk '{sum+=$5} END {print sum "Mi"}' | sed 's/Mi$//' || echo "0")Mi"
        }
      }
    },
    "security_features": {
      "mtls_enabled": "true",
      "automatic_tls": "true"
    }
  }
}
LINKERD_REPORT_EOF
    
    log "📄 Linkerd evaluation report: $linkerd_report"
    
    # Краткая статистика
    local sidecar_cpu=$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep linkerd-proxy | awk '{sum+=$4} END {print sum}' | sed 's/m$//' || echo "0")
    local sidecar_memory=$(kubectl top pods -n $EVALUATION_NAMESPACE --containers 2>/dev/null | grep linkerd-proxy | awk '{sum+=$5} END {print sum}' | sed 's/Mi$//' || echo "0")
    
    log "🎯 Linkerd Performance:"
    log "  🔗 Sidecars injected: $sidecar_count"
    log "  ⚡ Sidecar CPU overhead: ${sidecar_cpu}m"
    log "  💾 Sidecar Memory overhead: ${sidecar_memory}Mi"
    
    return 0
}

# Функция создания comparison report
create_comparison_report() {
    log "📋 Создание comprehensive comparison report"
    
    local comparison_report="/tmp/service-mesh-comparison-$TIMESTAMP.json"
    
    cat > $comparison_report << COMPARISON_REPORT_EOF
{
  "report_metadata": {
    "timestamp": "$(date -Iseconds)",
    "cluster": "$(kubectl config current-context)",
    "evaluation_namespace": "$EVALUATION_NAMESPACE",
    "kubernetes_version": "$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")"
  },
  "service_mesh_comparison": {
    "available_solutions": {
      "istio": $(kubectl get namespace istio-system &>/dev/null && echo "true" || echo "false"),
      "linkerd": $(kubectl get namespace linkerd &>/dev/null && echo "true" || echo "false"),
      "consul": $(kubectl get namespace consul &>/dev/null && echo "true" || echo "false"),
      "cilium": $(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | wc -l | awk '{if($1>0) print "true"; else print "false"}')
    },
    "cluster_characteristics": {
      "total_nodes": $(kubectl get nodes --no-headers | wc -l),
      "total_cpu_cores": "$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.cpu}' | tr ' ' '\n' | awk '{sum += $1} END {print sum}')cores",
      "total_memory": "$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.memory}' | tr ' ' '\n' | sed 's/Ki$//' | awk '{sum += $1} END {print sum/1024/1024 "GB"}')",
      "cni_plugin": "$(kubectl get pods -n kube-system -o jsonpath='{.items[*].spec.containers[*].image}' | grep -o -E '(calico|cilium|flannel|weave)' | head -1 || echo "unknown")"
    },
    "recommendations": {
      "for_performance": "Linkerd или Cilium",
      "for_features": "Istio",
      "for_simplicity": "Linkerd или AWS App Mesh",
      "for_aws_workloads": "AWS App Mesh",
      "for_hashicorp_ecosystem": "Consul Connect",
      "for_network_focus": "Cilium Service Mesh"
    }
  },
  "evaluation_summary": {
    "baseline_established": $([ -f "/tmp/baseline-performance-$TIMESTAMP.json" ] && echo "true" || echo "false"),
    "istio_evaluated": $([ -f "/tmp/istio-evaluation-$TIMESTAMP.json" ] && echo "true" || echo "false"),
    "linkerd_evaluated": $([ -f "/tmp/linkerd-evaluation-$TIMESTAMP.json" ] && echo "true" || echo "false"),
    "next_steps": [
      "Review performance reports",
      "Consider feature requirements",
      "Evaluate operational complexity",
      "Plan pilot deployment"
    ]
  }
}
COMPARISON_REPORT_EOF
    
    log "📄 Comprehensive comparison report: $comparison_report"
    
    # Summary
    local available_meshes=0
    kubectl get namespace istio-system &>/dev/null && available_meshes=$((available_meshes + 1))
    kubectl get namespace linkerd &>/dev/null && available_meshes=$((available_meshes + 1))
    kubectl get namespace consul &>/dev/null && available_meshes=$((available_meshes + 1))
    
    log "🎯 Service Mesh Comparison Summary:"
    log "  📊 Available meshes: $available_meshes"
    log "  🏥 Cluster ready for service mesh"
    log "  📋 Evaluation reports generated"
    
    return 0
}

# Функция cleanup
cleanup_evaluation_environment() {
    log "🧹 Cleanup evaluation environment"
    
    # Удаление test namespace
    kubectl delete namespace $EVALUATION_NAMESPACE --ignore-not-found
    
    # Удаление temporary reports
    rm -f /tmp/*-evaluation-$TIMESTAMP.json
    rm -f /tmp/cluster-readiness-$TIMESTAMP.json
    rm -f /tmp/service-mesh-comparison-$TIMESTAMP.json
    
    log "✅ Cleanup завершен"
}

# Основная логика выполнения
main() {
    case "$1" in
        readiness)
            analyze_cluster_readiness
            ;;
        setup)
            create_evaluation_environment
            ;;
        baseline)
            run_baseline_performance_test
            ;;
        istio)
            evaluate_istio_performance
            ;;
        linkerd)
            evaluate_linkerd_performance
            ;;
        report)
            create_comparison_report
            ;;
        cleanup)
            cleanup_evaluation_environment
            ;;
        full)
            log "🚀 Запуск полного service mesh evaluation"
            analyze_cluster_readiness
            create_evaluation_environment
            run_baseline_performance_test
            evaluate_istio_performance
            evaluate_linkerd_performance
            create_comparison_report
            log "🎉 Service mesh evaluation завершен!"
            ;;
        *)
            echo "Использование: $0 {readiness|setup|baseline|istio|linkerd|report|cleanup|full}"
            echo "  readiness - Анализ готовности кластера"
            echo "  setup     - Создание evaluation environment"
            echo "  baseline  - Baseline performance test"
            echo "  istio     - Evaluation Istio performance"
            echo "  linkerd   - Evaluation Linkerd performance"
            echo "  report    - Создание comparison report"
            echo "  cleanup   - Cleanup evaluation environment"
            echo "  full      - Полное evaluation"
            exit 1
            ;;
    esac
}

# Обработка ошибок
trap 'log "❌ Ошибка в service mesh evaluator"; exit 1' ERR

# Запуск основной функции
main "$@"
EOF

chmod +x service-mesh-evaluator.sh
```

## 📊 **Service Mesh Decision Matrix:**

| Критерий | Istio | Linkerd | Consul Connect | AWS App Mesh | Cilium |
|----------|-------|---------|----------------|--------------|--------|
| **Performance** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Features** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Complexity** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Security** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Observability** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Ecosystem** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

## 🏗️ **Архитектура comparison в HA кластере:**

```
┌─────────────────────────────────────────────────────────────┐
│              Service Mesh Comparison Architecture           │
├─────────────────────────────────────────────────────────────┤
│  Evaluation Environment (mesh-evaluation namespace)        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ ┌─────────┐    ┌─────────┐    ┌─────────┐              │ │
│  │ │Frontend │    │Backend  │    │Database │              │ │
│  │ │(nginx)  │◄──▶│(httpd)  │◄──▶│(postgres)              │ │
│  │ └─────────┘    └─────────┘    └─────────┘              │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Service Mesh Options Testing                              │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │   Istio     │  Linkerd    │   Consul    │   Cilium    │  │
│  │ ├── Envoy   │ ├── Rust    │ ├── Envoy   │ ├── eBPF    │  │
│  │ ├── Istiod  │ ├── Control │ ├── Agent   │ ├── Agent   │  │
│  │ ├── Rich    │ ├── Simple  │ ├── Vault   │ ├── Network │  │
│  │ └── Complex │ └── Fast    │ └── Multi   │ └── Focus   │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Performance Metrics Collection                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ ├── Latency Measurement                                 │ │
│  │ ├── Resource Usage Tracking                             │ │
│  │ ├── Sidecar Overhead Analysis                           │ │
│  │ ├── Feature Completeness Assessment                     │ │
│  │ └── Operational Complexity Evaluation                   │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 **Best Practices для выбора service mesh:**

### **1. Performance Requirements**
- **High Performance**: Linkerd или Cilium
- **Balanced Performance**: Consul Connect
- **Feature-rich**: Istio (с оптимизацией)

### **2. Operational Complexity**
- **Simple Operations**: Linkerd или AWS App Mesh
- **Advanced Operations**: Istio
- **Hybrid Environments**: Consul Connect

### **3. Security Requirements**
- **Zero-trust**: Istio или Consul Connect
- **Automatic mTLS**: Linkerd
- **Policy Enforcement**: Istio

### **4. Ecosystem Integration**
- **Kubernetes-native**: Istio или Linkerd
- **HashiCorp stack**: Consul Connect
- **AWS workloads**: AWS App Mesh
- **Network focus**: Cilium

**Service mesh comparison обеспечивает data-driven выбор оптимального решения для управления микросервисной коммуникацией в HA кластере!**
