# 126. Что такое Service Mesh и как они интегрируются с Kubernetes

## 🎯 **Что такое Service Mesh и как они интегрируются с Kubernetes**

**Service Mesh** - это выделенная инфраструктурная прослойка для обработки service-to-service коммуникации в микросервисной архитектуре. Service mesh обеспечивает наблюдаемость, безопасность и управление трафиком без изменения кода приложений.

## 🌐 **Архитектура Service Mesh:**

### **1. Data Plane:**
- **Sidecar Proxies** - прокси контейнеры рядом с каждым сервисом
- **Traffic Interception** - перехват всего network трафика
- **Load Balancing** - распределение нагрузки
- **Circuit Breaking** - защита от каскадных отказов

### **2. Control Plane:**
- **Configuration Management** - управление конфигурацией
- **Service Discovery** - обнаружение сервисов
- **Certificate Management** - управление сертификатами
- **Policy Enforcement** - применение политик

### **3. Popular Service Mesh Solutions:**
- **Istio** - наиболее популярное решение
- **Linkerd** - легковесная альтернатива
- **Consul Connect** - от HashiCorp
- **AWS App Mesh** - managed решение от AWS

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive service mesh toolkit
cat << 'EOF' > service-mesh-toolkit.sh
#!/bin/bash

echo "=== Service Mesh Toolkit ==="
echo "Comprehensive guide for service mesh implementation in HashFoundry HA cluster"
echo

# Функция для анализа текущего состояния кластера
analyze_cluster_readiness() {
    echo "=== Cluster Readiness Analysis ==="
    
    echo "1. Check cluster resources:"
    echo "Nodes:"
    kubectl get nodes -o wide
    echo
    
    echo "CPU and Memory resources:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "2. Check existing service mesh components:"
    kubectl get pods --all-namespaces | grep -E "(istio|linkerd|consul|envoy)" || echo "No service mesh components found"
    echo
    
    echo "3. Check for sidecar injectors:"
    kubectl get mutatingwebhookconfigurations | grep -E "(istio|linkerd)" || echo "No sidecar injectors found"
    echo
    
    echo "4. Analyze current services:"
    SERVICE_COUNT=$(kubectl get services --all-namespaces --no-headers | wc -l)
    echo "Total services in cluster: $SERVICE_COUNT"
    
    if [ $SERVICE_COUNT -gt 10 ]; then
        echo "✅ Good candidate for service mesh (many services)"
    else
        echo "⚠️  Small number of services - consider if service mesh is needed"
    fi
    echo
}

# Функция для установки Istio
install_istio() {
    echo "=== Installing Istio Service Mesh ==="
    
    echo "1. Download and install Istio:"
    cat << ISTIO_INSTALL_EOF > install-istio.sh
#!/bin/bash

# Download Istio
ISTIO_VERSION=1.19.0
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=\$ISTIO_VERSION sh -

# Add istioctl to PATH
export PATH=\$PWD/istio-\$ISTIO_VERSION/bin:\$PATH

# Install Istio with demo profile (for learning)
istioctl install --set values.defaultRevision=default --set values.pilot.env.EXTERNAL_ISTIOD=false -y

# Enable automatic sidecar injection for default namespace
kubectl label namespace default istio-injection=enabled

echo "✅ Istio installed successfully"

ISTIO_INSTALL_EOF
    
    chmod +x install-istio.sh
    echo "✅ Istio installation script created: install-istio.sh"
    echo
    
    echo "2. Istio configuration for HA cluster:"
    cat << ISTIO_CONFIG_EOF > istio-ha-config.yaml
# Istio configuration for HashFoundry HA cluster
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: hashfoundry-istio
spec:
  values:
    defaultRevision: default
    pilot:
      env:
        EXTERNAL_ISTIOD: false
        PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION: true
    global:
      meshID: hashfoundry-mesh
      multiCluster:
        clusterName: hashfoundry-ha
      network: hashfoundry-network
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        hpaSpec:
          minReplicas: 2
          maxReplicas: 5
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        hpaSpec:
          minReplicas: 2
          maxReplicas: 5
        service:
          type: LoadBalancer
    egressGateways:
    - name: istio-egressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi

ISTIO_CONFIG_EOF
    
    echo "✅ Istio HA configuration created: istio-ha-config.yaml"
    echo
}

# Функция для установки Linkerd
install_linkerd() {
    echo "=== Installing Linkerd Service Mesh ==="
    
    echo "1. Linkerd installation script:"
    cat << LINKERD_INSTALL_EOF > install-linkerd.sh
#!/bin/bash

echo "Installing Linkerd service mesh..."

# Download linkerd CLI
curl -sL https://run.linkerd.io/install | sh
export PATH=\$PATH:\$HOME/.linkerd2/bin

# Pre-installation checks
linkerd check --pre

# Install Linkerd control plane
linkerd install | kubectl apply -f -

# Wait for control plane to be ready
linkerd check

# Install Linkerd viz extension
linkerd viz install | kubectl apply -f -

echo "✅ Linkerd installed successfully"

LINKERD_INSTALL_EOF
    
    chmod +x install-linkerd.sh
    echo "✅ Linkerd installation script created: install-linkerd.sh"
    echo
    
    echo "2. Linkerd configuration for HA:"
    cat << LINKERD_CONFIG_EOF > linkerd-ha-config.yaml
# Linkerd HA configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: linkerd-config
  namespace: linkerd
data:
  global: |
    linkerdNamespace: linkerd
    cniEnabled: false
    version: stable-2.14.1
    identityContext:
      trustDomain: cluster.local
      trustAnchorsPEM: |
        # Trust anchors will be generated during installation
    autoInjectContext:
      opaquePorts: "25,443,587,3306,5432"
    proxy:
      resources:
        cpu:
          limit: "1"
          request: "100m"
        memory:
          limit: "250Mi"
          request: "20Mi"
      logLevel: warn,linkerd=info
      disableIdentity: false
      image:
        name: cr.l5d.io/linkerd/proxy
        version: v2.14.1
    proxyInit:
      image:
        name: cr.l5d.io/linkerd/proxy-init
        version: v2.14.1
      resources:
        cpu:
          limit: "100m"
          request: "10m"
        memory:
          limit: "50Mi"
          request: "10Mi"

LINKERD_CONFIG_EOF
    
    echo "✅ Linkerd HA configuration created: linkerd-ha-config.yaml"
    echo
}

# Функция для создания демо приложений
create_demo_applications() {
    echo "=== Creating Demo Applications for Service Mesh ==="
    
    echo "1. Frontend application:"
    cat << FRONTEND_APP_EOF > demo-frontend.yaml
# Frontend application for service mesh demo
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: default
  labels:
    app: frontend
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      version: v1
  template:
    metadata:
      labels:
        app: frontend
        version: v1
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: frontend-config
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
      volumes:
      - name: frontend-config
        configMap:
          name: frontend-config

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>HashFoundry Service Mesh Demo</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f0f0f0; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
            .header { background: #4CAF50; color: white; padding: 20px; border-radius: 5px; text-align: center; }
            .service { margin: 20px 0; padding: 15px; background: #e8f5e8; border-radius: 5px; }
            button { background: #4CAF50; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🌐 HashFoundry Service Mesh Demo</h1>
                <p>Frontend Service - Demonstrating Service Mesh Capabilities</p>
            </div>
            
            <div class="service">
                <h3>🔗 Service Communication</h3>
                <button onclick="callBackend()">Call Backend Service</button>
                <button onclick="callDatabase()">Call Database Service</button>
                <div id="response"></div>
            </div>
            
            <div class="service">
                <h3>📊 Service Mesh Features</h3>
                <ul>
                    <li>✅ Automatic mTLS encryption</li>
                    <li>✅ Traffic management and load balancing</li>
                    <li>✅ Observability and metrics</li>
                    <li>✅ Circuit breaking and retries</li>
                    <li>✅ Security policies</li>
                </ul>
            </div>
        </div>
        
        <script>
            function callBackend() {
                fetch('/api/backend')
                    .then(response => response.text())
                    .then(data => {
                        document.getElementById('response').innerHTML = '<p><strong>Backend Response:</strong> ' + data + '</p>';
                    })
                    .catch(error => {
                        document.getElementById('response').innerHTML = '<p><strong>Error:</strong> ' + error + '</p>';
                    });
            }
            
            function callDatabase() {
                fetch('/api/database')
                    .then(response => response.text())
                    .then(data => {
                        document.getElementById('response').innerHTML = '<p><strong>Database Response:</strong> ' + data + '</p>';
                    })
                    .catch(error => {
                        document.getElementById('response').innerHTML = '<p><strong>Error:</strong> ' + error + '</p>';
                    });
            }
        </script>
    </body>
    </html>

---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: default
  labels:
    app: frontend
spec:
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 80
  type: ClusterIP

FRONTEND_APP_EOF
    
    echo "2. Backend application:"
    cat << BACKEND_APP_EOF > demo-backend.yaml
# Backend application for service mesh demo
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: default
  labels:
    app: backend
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
      - name: backend
        image: hashicorp/http-echo:0.2.3
        args:
          - "-text=Backend Service Response from \$(hostname) - Service Mesh Enabled"
          - "-listen=:8080"
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "25m"
            memory: "32Mi"
          limits:
            cpu: "50m"
            memory: "64Mi"

---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: default
  labels:
    app: backend
spec:
  selector:
    app: backend
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  type: ClusterIP

BACKEND_APP_EOF
    
    echo "3. Database simulation application:"
    cat << DATABASE_APP_EOF > demo-database.yaml
# Database simulation for service mesh demo
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: default
  labels:
    app: database
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      version: v1
  template:
    metadata:
      labels:
        app: database
        version: v1
    spec:
      containers:
      - name: database
        image: hashicorp/http-echo:0.2.3
        args:
          - "-text=Database Query Result: {users: 1000, orders: 5000, products: 200} from \$(hostname)"
          - "-listen=:5432"
        ports:
        - containerPort: 5432
        resources:
          requests:
            cpu: "25m"
            memory: "32Mi"
          limits:
            cpu: "50m"
            memory: "64Mi"

---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: default
  labels:
    app: database
spec:
  selector:
    app: database
  ports:
  - name: tcp
    port: 5432
    targetPort: 5432
  type: ClusterIP

DATABASE_APP_EOF
    
    echo "✅ Demo applications created:"
    echo "  - demo-frontend.yaml"
    echo "  - demo-backend.yaml"
    echo "  - demo-database.yaml"
    echo
}

# Функция для создания Istio конфигураций
create_istio_configurations() {
    echo "=== Creating Istio Traffic Management Configurations ==="
    
    echo "1. Gateway configuration:"
    cat << GATEWAY_EOF > istio-gateway.yaml
# Istio Gateway for external traffic
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: hashfoundry-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "mesh.hashfoundry.local"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: hashfoundry-tls
    hosts:
    - "mesh.hashfoundry.local"

GATEWAY_EOF
    
    echo "2. Virtual Service configuration:"
    cat << VIRTUAL_SERVICE_EOF > istio-virtual-service.yaml
# Virtual Service for traffic routing
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: hashfoundry-vs
  namespace: default
spec:
  hosts:
  - "mesh.hashfoundry.local"
  gateways:
  - hashfoundry-gateway
  http:
  - match:
    - uri:
        prefix: "/api/backend"
    route:
    - destination:
        host: backend
        port:
          number: 8080
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
  - match:
    - uri:
        prefix: "/api/database"
    route:
    - destination:
        host: database
        port:
          number: 5432
    timeout: 30s
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: frontend
        port:
          number: 80

VIRTUAL_SERVICE_EOF
    
    echo "3. Destination Rules for load balancing:"
    cat << DESTINATION_RULES_EOF > istio-destination-rules.yaml
# Destination Rules for traffic policies
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-dr
  namespace: default
spec:
  host: backend
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    circuitBreaker:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: database-dr
  namespace: default
spec:
  host: database
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    connectionPool:
      tcp:
        maxConnections: 50
        connectTimeout: 30s

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: frontend-dr
  namespace: default
spec:
  host: frontend
  trafficPolicy:
    loadBalancer:
      simple: RANDOM

DESTINATION_RULES_EOF
    
    echo "4. Security policies:"
    cat << SECURITY_POLICIES_EOF > istio-security-policies.yaml
# Istio Security Policies
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
  - to:
    - operation:
        methods: ["GET", "POST"]

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: backend
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/default"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]

SECURITY_POLICIES_EOF
    
    echo "✅ Istio configurations created:"
    echo "  - istio-gateway.yaml"
    echo "  - istio-virtual-service.yaml"
    echo "  - istio-destination-rules.yaml"
    echo "  - istio-security-policies.yaml"
    echo
}

# Функция для мониторинга service mesh
create_monitoring_tools() {
    echo "=== Creating Service Mesh Monitoring Tools ==="
    
    echo "1. Service mesh monitoring script:"
    cat << MONITORING_SCRIPT_EOF > service-mesh-monitor.sh
#!/bin/bash

echo "=== Service Mesh Monitoring Dashboard ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Service Mesh Control Plane Status:"
    kubectl get pods -n istio-system 2>/dev/null || kubectl get pods -n linkerd 2>/dev/null || echo "No service mesh control plane found"
    echo
    
    echo "Sidecar Injection Status:"
    echo "Pods with sidecars:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}' | grep -E "(istio-proxy|linkerd-proxy)" | wc -l
    echo
    
    echo "Service Mesh Resources:"
    kubectl get virtualservices,destinationrules,gateways 2>/dev/null || echo "No Istio resources found"
    kubectl get trafficsplits,serviceprofiles 2>/dev/null || echo "No Linkerd resources found"
    echo
    
    echo "mTLS Status:"
    kubectl get peerauthentication 2>/dev/null || echo "No mTLS policies found"
    echo
    
    echo "Recent Service Mesh Logs:"
    kubectl logs -n istio-system -l app=istiod --tail=3 --since=1m 2>/dev/null || \
    kubectl logs -n linkerd -l linkerd.io/control-plane-component=controller --tail=3 --since=1m 2>/dev/null || \
    echo "No service mesh logs available"
    echo
    
    sleep 30
done

MONITORING_SCRIPT_EOF
    
    chmod +x service-mesh-monitor.sh
    echo "✅ Service mesh monitoring script created: service-mesh-monitor.sh"
    echo
    
    echo "2. Traffic analysis script:"
    cat << TRAFFIC_ANALYSIS_EOF > traffic-analysis.sh
#!/bin/bash

echo "=== Service Mesh Traffic Analysis ==="

# Function to analyze Istio traffic
analyze_istio_traffic() {
    echo "Istio Traffic Analysis:"
    
    echo "1. Gateway status:"
    kubectl get gateways -o wide
    echo
    
    echo "2. Virtual Services:"
    kubectl get virtualservices -o wide
    echo
    
    echo "3. Destination Rules:"
    kubectl get destinationrules -o wide
    echo
    
    echo "4. Envoy proxy configuration:"
    FRONTEND_POD=\$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "\$FRONTEND_POD" ]; then
        echo "Envoy clusters for frontend pod:"
        kubectl exec \$FRONTEND_POD -c istio-proxy -- pilot-agent request GET clusters | head -10
    fi
    echo
}

# Function to analyze Linkerd traffic
analyze_linkerd_traffic() {
    echo "Linkerd Traffic Analysis:"
    
    echo "1. Service profiles:"
    kubectl get serviceprofiles
    echo
    
    echo "2. Traffic splits:"
    kubectl get trafficsplits
    echo
    
    echo "3. Linkerd proxy stats:"
    FRONTEND_POD=\$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "\$FRONTEND_POD" ]; then
        echo "Proxy stats for frontend pod:"
        kubectl exec \$FRONTEND_POD -c linkerd-proxy -- curl -s localhost:4191/stats | head -10
    fi
    echo
}

# Detect service mesh and run appropriate analysis
if kubectl get pods -n istio-system | grep -q istiod; then
    analyze_istio_traffic
elif kubectl get pods -n linkerd | grep -q linkerd-controller; then
    analyze_linkerd_traffic
else
    echo "No service mesh detected"
fi

TRAFFIC_ANALYSIS_EOF
    
    chmod +x traffic-analysis.sh
    echo "✅ Traffic analysis script created: traffic-analysis.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_cluster_readiness
            ;;
        "istio")
            install_istio
            ;;
        "linkerd")
            install_linkerd
            ;;
        "demo")
            create_demo_applications
            ;;
        "config")
            create_istio_configurations
            ;;
        "monitor")
            create_monitoring_tools
            ;;
        "all"|"")
            analyze_cluster_readiness
            install_istio
            install_linkerd
            create_demo_applications
            create_istio_configurations
            create_monitoring_tools
            ;;
        *)
            echo "Usage: $0 [analyze|istio|linkerd|demo|config|monitor|all]"
            echo ""
            echo "Service Mesh Toolkit Options:"
            echo "  analyze  - Analyze cluster readiness for service mesh"
            echo "  istio    - Install Istio service mesh"
            echo "  linkerd  - Install Linkerd service mesh"
            echo "  demo     - Create demo applications"
            echo "  config   - Create Istio configurations"
            echo "  monitor  - Create monitoring tools"
            ;;
    esac
}

main "$@"

EOF

chmod +x service-mesh-toolkit.sh
./service-mesh-toolkit.sh all
```

## 🎯 **Основные преимущества Service Mesh:**

### **1. Observability:**
```bash
# Просмотр метрик трафика
kubectl exec -n istio-system deployment/istiod -- pilot-discovery request GET /debug/endpointz

# Анализ sidecar конфигурации
kubectl exec <pod-name> -c istio-proxy -- pilot-agent request GET config_dump

# Мониторинг трафика
kubectl logs -n istio-system -l app=istiod -f
```

### **2. Security (mTLS):**
```yaml
# Включение строгого mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
```

### **3. Traffic Management:**
```yaml
# Canary deployment
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary-deployment
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: backend
        subset: v2
  - route:
    - destination:
        host: backend
        subset: v1
      weight: 90
    - destination:
        host: backend
        subset: v2
      weight: 10
```

## 🔧 **Интеграция с Kubernetes:**

### **Sidecar Injection:**
```bash
# Автоматическая инъекция sidecar
kubectl label namespace default istio-injection=enabled

# Проверка инъекции
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

### **Service Discovery:**
```bash
# Проверка service discovery
kubectl get services
kubectl get endpoints

# Istio service registry
istioctl proxy-config cluster <pod-name>
```

### **Load Balancing:**
```yaml
# Настройка load balancing
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-lb
spec:
  host: backend
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
```

**Service Mesh обеспечивает мощные возможности для управления микросервисной архитектурой в Kubernetes!**
