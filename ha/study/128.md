# 128. В чем разница между NodePort, LoadBalancer и Ingress

## 🎯 **В чем разница между NodePort, LoadBalancer и Ingress**

**Service types** в Kubernetes предоставляют различные способы экспонирования приложений для внешнего доступа. Понимание различий между NodePort, LoadBalancer и Ingress критически важно для правильного выбора метода экспонирования сервисов.

## 🌐 **Сравнение Service Types:**

### **1. NodePort:**
- **Уровень**: L4 (Transport Layer)
- **Порты**: 30000-32767
- **Доступ**: <NodeIP>:<NodePort>
- **Use Case**: Development, простые deployments

### **2. LoadBalancer:**
- **Уровень**: L4 (Transport Layer)
- **Провайдер**: Cloud Provider
- **IP**: External IP от провайдера
- **Use Case**: Production, cloud environments

### **3. Ingress:**
- **Уровень**: L7 (Application Layer)
- **Протокол**: HTTP/HTTPS
- **Функции**: Routing, SSL termination
- **Use Case**: Web applications, API gateways

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive service types comparison toolkit
cat << 'EOF' > service-types-comparison-toolkit.sh
#!/bin/bash

echo "=== Service Types Comparison Toolkit ==="
echo "Comprehensive guide for NodePort, LoadBalancer, and Ingress in HashFoundry HA cluster"
echo

# Функция для создания демо приложения
create_demo_application() {
    echo "=== Creating Demo Application ==="
    
    echo "1. Demo web application:"
    cat << DEMO_APP_EOF > demo-web-app.yaml
# Demo web application for service types comparison
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web-app
  namespace: default
  labels:
    app: demo-web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-web-app
  template:
    metadata:
      labels:
        app: demo-web-app
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
      volumes:
      - name: web-content
        configMap:
          name: demo-web-content

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-web-content
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>HashFoundry Service Types Demo</title>
        <style>
            body { 
                font-family: Arial, sans-serif; 
                margin: 40px; 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
            }
            .container { 
                max-width: 800px; 
                margin: 0 auto; 
                background: rgba(255,255,255,0.1); 
                padding: 30px; 
                border-radius: 15px; 
                backdrop-filter: blur(10px);
            }
            .header { 
                text-align: center; 
                margin-bottom: 30px; 
            }
            .service-type { 
                margin: 20px 0; 
                padding: 20px; 
                background: rgba(255,255,255,0.1); 
                border-radius: 10px; 
                border-left: 5px solid #4CAF50;
            }
            .comparison-table {
                width: 100%;
                border-collapse: collapse;
                margin: 20px 0;
            }
            .comparison-table th, .comparison-table td {
                border: 1px solid rgba(255,255,255,0.3);
                padding: 12px;
                text-align: left;
            }
            .comparison-table th {
                background: rgba(255,255,255,0.2);
            }
            .info-box {
                background: rgba(76, 175, 80, 0.2);
                border: 1px solid #4CAF50;
                border-radius: 5px;
                padding: 15px;
                margin: 15px 0;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🌐 HashFoundry Service Types Demo</h1>
                <p>Demonstrating NodePort, LoadBalancer, and Ingress</p>
                <p><strong>Pod:</strong> <span id="hostname">Loading...</span></p>
                <p><strong>Access Method:</strong> <span id="access-method">Unknown</span></p>
            </div>
            
            <div class="service-type">
                <h3>🔌 NodePort Service</h3>
                <p><strong>Port Range:</strong> 30000-32767</p>
                <p><strong>Access:</strong> &lt;NodeIP&gt;:&lt;NodePort&gt;</p>
                <p><strong>Use Case:</strong> Development, testing</p>
            </div>
            
            <div class="service-type">
                <h3>⚖️ LoadBalancer Service</h3>
                <p><strong>Provider:</strong> Cloud Provider</p>
                <p><strong>Access:</strong> External IP</p>
                <p><strong>Use Case:</strong> Production, cloud environments</p>
            </div>
            
            <div class="service-type">
                <h3>🚪 Ingress</h3>
                <p><strong>Layer:</strong> L7 (HTTP/HTTPS)</p>
                <p><strong>Features:</strong> Routing, SSL, Host-based routing</p>
                <p><strong>Use Case:</strong> Web applications, API gateways</p>
            </div>
            
            <table class="comparison-table">
                <tr>
                    <th>Feature</th>
                    <th>NodePort</th>
                    <th>LoadBalancer</th>
                    <th>Ingress</th>
                </tr>
                <tr>
                    <td>OSI Layer</td>
                    <td>L4</td>
                    <td>L4</td>
                    <td>L7</td>
                </tr>
                <tr>
                    <td>Protocol</td>
                    <td>TCP/UDP</td>
                    <td>TCP/UDP</td>
                    <td>HTTP/HTTPS</td>
                </tr>
                <tr>
                    <td>SSL Termination</td>
                    <td>❌</td>
                    <td>❌</td>
                    <td>✅</td>
                </tr>
                <tr>
                    <td>Path-based Routing</td>
                    <td>❌</td>
                    <td>❌</td>
                    <td>✅</td>
                </tr>
                <tr>
                    <td>Host-based Routing</td>
                    <td>❌</td>
                    <td>❌</td>
                    <td>✅</td>
                </tr>
                <tr>
                    <td>External IP</td>
                    <td>❌</td>
                    <td>✅</td>
                    <td>✅ (via LB)</td>
                </tr>
            </table>
            
            <div class="info-box">
                <h4>💡 Current Request Information</h4>
                <p><strong>URL:</strong> <span id="current-url"></span></p>
                <p><strong>User Agent:</strong> <span id="user-agent"></span></p>
                <p><strong>Timestamp:</strong> <span id="timestamp"></span></p>
            </div>
        </div>
        
        <script>
            // Get hostname (simulated)
            document.getElementById('hostname').textContent = 'demo-web-app-' + Math.random().toString(36).substr(2, 9);
            
            // Detect access method based on URL
            const url = window.location.href;
            let accessMethod = 'Unknown';
            
            if (url.includes(':30') || url.includes(':31') || url.includes(':32')) {
                accessMethod = 'NodePort';
            } else if (url.includes('ingress') || url.includes('app.')) {
                accessMethod = 'Ingress';
            } else {
                accessMethod = 'LoadBalancer';
            }
            
            document.getElementById('access-method').textContent = accessMethod;
            document.getElementById('current-url').textContent = url;
            document.getElementById('user-agent').textContent = navigator.userAgent.substring(0, 50) + '...';
            document.getElementById('timestamp').textContent = new Date().toISOString();
        </script>
    </body>
    </html>

DEMO_APP_EOF
    
    echo "✅ Demo application created: demo-web-app.yaml"
    echo "To deploy: kubectl apply -f demo-web-app.yaml"
    echo
}

# Функция для создания NodePort сервиса
create_nodeport_service() {
    echo "=== Creating NodePort Service ==="
    
    cat << NODEPORT_SERVICE_EOF > nodeport-service.yaml
# NodePort Service Example
apiVersion: v1
kind: Service
metadata:
  name: demo-nodeport-service
  namespace: default
  labels:
    app: demo-web-app
    service-type: nodeport
spec:
  type: NodePort
  selector:
    app: demo-web-app
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: 30080  # Optional: specify port (30000-32767)
    protocol: TCP

NODEPORT_SERVICE_EOF
    
    echo "✅ NodePort service created: nodeport-service.yaml"
    echo
    
    echo "NodePort Service Characteristics:"
    echo "  ✅ Exposes service on each node's IP at a static port"
    echo "  ✅ Port range: 30000-32767"
    echo "  ✅ Access: <NodeIP>:<NodePort>"
    echo "  ✅ Works in any environment"
    echo "  ❌ Requires knowledge of node IPs"
    echo "  ❌ Non-standard ports"
    echo "  ❌ No load balancing across nodes"
    echo
}

# Функция для создания LoadBalancer сервиса
create_loadbalancer_service() {
    echo "=== Creating LoadBalancer Service ==="
    
    cat << LOADBALANCER_SERVICE_EOF > loadbalancer-service.yaml
# LoadBalancer Service Example
apiVersion: v1
kind: Service
metadata:
  name: demo-loadbalancer-service
  namespace: default
  labels:
    app: demo-web-app
    service-type: loadbalancer
  annotations:
    # Cloud provider specific annotations
    service.beta.kubernetes.io/do-loadbalancer-name: "hashfoundry-demo-lb"
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-size-slug: "lb-small"
spec:
  type: LoadBalancer
  selector:
    app: demo-web-app
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
  - name: https
    port: 443
    targetPort: 80
    protocol: TCP
  # Optional: specify load balancer source ranges
  loadBalancerSourceRanges:
  - "0.0.0.0/0"  # Allow from anywhere (use with caution)

LOADBALANCER_SERVICE_EOF
    
    echo "✅ LoadBalancer service created: loadbalancer-service.yaml"
    echo
    
    echo "LoadBalancer Service Characteristics:"
    echo "  ✅ Provides external IP address"
    echo "  ✅ Automatic load balancing"
    echo "  ✅ Standard ports (80, 443)"
    echo "  ✅ Cloud provider integration"
    echo "  ✅ Health checks"
    echo "  ❌ Requires cloud provider support"
    echo "  ❌ Additional cost"
    echo "  ❌ One LoadBalancer per service"
    echo
}

# Функция для создания Ingress
create_ingress_configuration() {
    echo "=== Creating Ingress Configuration ==="
    
    cat << INGRESS_CONFIG_EOF > ingress-configuration.yaml
# Ingress Configuration Example
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
  namespace: default
  labels:
    app: demo-web-app
    service-type: ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    # Additional annotations for advanced features
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
spec:
  rules:
  # Host-based routing
  - host: app.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-nodeport-service
            port:
              number: 80
  
  # Path-based routing
  - host: demo.hashfoundry.local
    http:
      paths:
      - path: /nodeport
        pathType: Prefix
        backend:
          service:
            name: demo-nodeport-service
            port:
              number: 80
      - path: /loadbalancer
        pathType: Prefix
        backend:
          service:
            name: demo-loadbalancer-service
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-nodeport-service
            port:
              number: 80

---
# HTTPS Ingress with TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress-tls
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  tls:
  - hosts:
    - secure.hashfoundry.local
    secretName: demo-tls-secret
  rules:
  - host: secure.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-nodeport-service
            port:
              number: 80

INGRESS_CONFIG_EOF
    
    echo "✅ Ingress configuration created: ingress-configuration.yaml"
    echo
    
    echo "Ingress Characteristics:"
    echo "  ✅ L7 (HTTP/HTTPS) load balancing"
    echo "  ✅ Host-based routing"
    echo "  ✅ Path-based routing"
    echo "  ✅ SSL/TLS termination"
    echo "  ✅ Single entry point for multiple services"
    echo "  ✅ Advanced features (rate limiting, CORS, etc.)"
    echo "  ❌ Requires Ingress Controller"
    echo "  ❌ HTTP/HTTPS only"
    echo
}

# Функция для создания comprehensive comparison
create_comparison_analysis() {
    echo "=== Creating Service Types Comparison Analysis ==="
    
    cat << COMPARISON_ANALYSIS_EOF > service-types-comparison.md
# Service Types Comparison: NodePort vs LoadBalancer vs Ingress

## 📊 **Detailed Comparison Matrix**

| Feature | NodePort | LoadBalancer | Ingress |
|---------|----------|--------------|---------|
| **OSI Layer** | L4 (Transport) | L4 (Transport) | L7 (Application) |
| **Protocols** | TCP, UDP | TCP, UDP | HTTP, HTTPS |
| **Port Range** | 30000-32767 | Any | 80, 443 |
| **External IP** | ❌ | ✅ | ✅ (via LB) |
| **SSL Termination** | ❌ | ❌ | ✅ |
| **Path Routing** | ❌ | ❌ | ✅ |
| **Host Routing** | ❌ | ❌ | ✅ |
| **Load Balancing** | Manual | Automatic | Automatic |
| **Cloud Provider** | Not required | Required | Optional |
| **Cost** | Free | Additional cost | Controller cost |
| **Complexity** | Low | Medium | High |

## 🎯 **Use Case Recommendations**

### **NodePort - Best for:**
- **Development environments**
- **Testing and debugging**
- **On-premises clusters without LB**
- **Simple TCP/UDP services**
- **Cost-sensitive deployments**

### **LoadBalancer - Best for:**
- **Production cloud deployments**
- **Single service exposure**
- **Non-HTTP protocols**
- **Simple requirements**
- **When cloud provider LB features are needed**

### **Ingress - Best for:**
- **Web applications**
- **Multiple services behind single IP**
- **SSL/TLS termination needed**
- **Advanced routing requirements**
- **API gateways**

## 🔧 **Implementation Examples**

### **NodePort Access Pattern:**
\`\`\`
Client → NodeIP:NodePort → Service → Pod
\`\`\`

### **LoadBalancer Access Pattern:**
\`\`\`
Client → External IP → LoadBalancer → Service → Pod
\`\`\`

### **Ingress Access Pattern:**
\`\`\`
Client → Ingress IP → Ingress Controller → Service → Pod
\`\`\`

## 📈 **Performance Characteristics**

### **NodePort:**
- **Latency**: Low (direct node access)
- **Throughput**: Limited by node capacity
- **Scalability**: Manual scaling required
- **Availability**: Depends on node availability

### **LoadBalancer:**
- **Latency**: Low to medium (LB overhead)
- **Throughput**: High (LB capacity)
- **Scalability**: Automatic scaling
- **Availability**: High (LB health checks)

### **Ingress:**
- **Latency**: Medium (L7 processing)
- **Throughput**: High (optimized for HTTP)
- **Scalability**: Controller-dependent
- **Availability**: High (advanced health checks)

## 🛡️ **Security Considerations**

### **NodePort:**
- Exposes service on all nodes
- Requires firewall configuration
- No built-in SSL/TLS
- Limited access control

### **LoadBalancer:**
- Cloud provider security features
- Source IP preservation
- Network-level filtering
- No application-level security

### **Ingress:**
- SSL/TLS termination
- Application-level security
- Rate limiting and DDoS protection
- Advanced authentication options

## 💰 **Cost Analysis**

### **NodePort:**
- **Infrastructure**: No additional cost
- **Maintenance**: Low
- **Scaling**: Manual effort required

### **LoadBalancer:**
- **Infrastructure**: Cloud provider LB cost
- **Maintenance**: Medium
- **Scaling**: Automatic but costly

### **Ingress:**
- **Infrastructure**: Controller resources
- **Maintenance**: High (controller management)
- **Scaling**: Efficient resource utilization

COMPARISON_ANALYSIS_EOF
    
    echo "✅ Comparison analysis created: service-types-comparison.md"
    echo
}

# Функция для тестирования всех типов сервисов
create_service_testing_suite() {
    echo "=== Creating Service Testing Suite ==="
    
    cat << SERVICE_TEST_SUITE_EOF > service-testing-suite.sh
#!/bin/bash

echo "=== Service Types Testing Suite ==="

# Function to test NodePort service
test_nodeport_service() {
    echo "Testing NodePort Service:"
    
    # Get NodePort
    NODEPORT=\$(kubectl get service demo-nodeport-service -o jsonpath='{.spec.ports[0].nodePort}')
    
    if [ ! -z "\$NODEPORT" ]; then
        echo "NodePort: \$NODEPORT"
        
        # Get node IPs
        NODE_IPS=\$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}')
        if [ -z "\$NODE_IPS" ]; then
            NODE_IPS=\$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
        fi
        
        echo "Testing access via nodes:"
        for ip in \$NODE_IPS; do
            echo "Testing \$ip:\$NODEPORT"
            curl -s --connect-timeout 5 http://\$ip:\$NODEPORT | grep -o "<title>.*</title>" || echo "❌ Failed to connect"
        done
    else
        echo "❌ NodePort service not found"
    fi
    echo
}

# Function to test LoadBalancer service
test_loadbalancer_service() {
    echo "Testing LoadBalancer Service:"
    
    # Get external IP
    EXTERNAL_IP=\$(kubectl get service demo-loadbalancer-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ ! -z "\$EXTERNAL_IP" ] && [ "\$EXTERNAL_IP" != "null" ]; then
        echo "External IP: \$EXTERNAL_IP"
        echo "Testing HTTP access:"
        curl -s --connect-timeout 10 http://\$EXTERNAL_IP | grep -o "<title>.*</title>" || echo "❌ Failed to connect"
        
        echo "Testing HTTPS access:"
        curl -s --connect-timeout 10 -k https://\$EXTERNAL_IP | grep -o "<title>.*</title>" || echo "❌ HTTPS not available"
    else
        echo "❌ External IP not assigned yet (this may take a few minutes)"
        echo "Current status:"
        kubectl get service demo-loadbalancer-service -o wide
    fi
    echo
}

# Function to test Ingress
test_ingress() {
    echo "Testing Ingress:"
    
    # Get ingress IP
    INGRESS_IP=\$(kubectl get ingress demo-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ ! -z "\$INGRESS_IP" ] && [ "\$INGRESS_IP" != "null" ]; then
        echo "Ingress IP: \$INGRESS_IP"
        
        echo "Testing host-based routing (app.hashfoundry.local):"
        curl -s --connect-timeout 10 -H "Host: app.hashfoundry.local" http://\$INGRESS_IP | grep -o "<title>.*</title>" || echo "❌ Failed to connect"
        
        echo "Testing path-based routing (demo.hashfoundry.local/nodeport):"
        curl -s --connect-timeout 10 -H "Host: demo.hashfoundry.local" http://\$INGRESS_IP/nodeport | grep -o "<title>.*</title>" || echo "❌ Failed to connect"
        
        echo "Testing TLS ingress (secure.hashfoundry.local):"
        curl -s --connect-timeout 10 -k -H "Host: secure.hashfoundry.local" https://\$INGRESS_IP | grep -o "<title>.*</title>" || echo "❌ TLS not available"
    else
        echo "❌ Ingress IP not assigned yet"
        echo "Current status:"
        kubectl get ingress demo-ingress -o wide
    fi
    echo
}

# Function to show service comparison
show_service_comparison() {
    echo "=== Service Comparison Summary ==="
    
    echo "NodePort Service:"
    kubectl get service demo-nodeport-service -o wide 2>/dev/null || echo "❌ Not deployed"
    
    echo "LoadBalancer Service:"
    kubectl get service demo-loadbalancer-service -o wide 2>/dev/null || echo "❌ Not deployed"
    
    echo "Ingress:"
    kubectl get ingress demo-ingress -o wide 2>/dev/null || echo "❌ Not deployed"
    echo
}

# Main testing function
main() {
    show_service_comparison
    test_nodeport_service
    test_loadbalancer_service
    test_ingress
}

main

SERVICE_TEST_SUITE_EOF
    
    chmod +x service-testing-suite.sh
    echo "✅ Service testing suite created: service-testing-suite.sh"
    echo
}

# Функция для cleanup
cleanup_demo_resources() {
    echo "=== Cleaning up demo resources ==="
    
    kubectl delete deployment demo-web-app --ignore-not-found=true
    kubectl delete configmap demo-web-content --ignore-not-found=true
    kubectl delete service demo-nodeport-service --ignore-not-found=true
    kubectl delete service demo-loadbalancer-service --ignore-not-found=true
    kubectl delete ingress demo-ingress --ignore-not-found=true
    kubectl delete ingress demo-ingress-tls --ignore-not-found=true
    
    echo "✅ Demo resources cleaned up"
}

# Основная функция
main() {
    case "$1" in
        "app")
            create_demo_application
            ;;
        "nodeport")
            create_nodeport_service
            ;;
        "loadbalancer")
            create_loadbalancer_service
            ;;
        "ingress")
            create_ingress_configuration
            ;;
        "comparison")
            create_comparison_analysis
            ;;
        "test")
            create_service_testing_suite
            ;;
        "cleanup")
            cleanup_demo_resources
            ;;
        "all"|"")
            create_demo_application
            create_nodeport_service
            create_loadbalancer_service
            create_ingress_configuration
            create_comparison_analysis
            create_service_testing_suite
            ;;
        *)
            echo "Usage: $0 [app|nodeport|loadbalancer|ingress|comparison|test|cleanup|all]"
            echo ""
            echo "Service Types Comparison Options:"
            echo "  app          - Create demo application"
            echo "  nodeport     - Create NodePort service"
            echo "  loadbalancer - Create LoadBalancer service"
            echo "  ingress      - Create Ingress configuration"
            echo "  comparison   - Create comparison analysis"
            echo "  test         - Create testing suite"
            echo "  cleanup      - Clean up demo resources"
            ;;
    esac
}

main "$@"

EOF

chmod +x service-types-comparison-toolkit.sh
./service-types-comparison-toolkit.sh all
```

## 🎯 **Основные различия:**

### **1. NodePort Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodeport-example
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # 30000-32767
```

**Характеристики:**
- ✅ Простота настройки
- ✅ Работает в любой среде
- ❌ Нестандартные порты
- ❌ Требует знания IP узлов

### **2. LoadBalancer Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer-example
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

**Характеристики:**
- ✅ Внешний IP адрес
- ✅ Автоматическая балансировка
- ✅ Стандартные порты
- ❌ Требует cloud provider
- ❌ Дополнительная стоимость

### **3. Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-example
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

**Характеристики:**
- ✅ L7 маршрутизация
- ✅ SSL/TLS termination
- ✅ Host/Path-based routing
- ❌ Только HTTP/HTTPS
- ❌ Требует Ingress Controller

## 📊 **Сравнительная таблица:**

| Функция | NodePort | LoadBalancer | Ingress |
|---------|----------|--------------|---------|
| **OSI Layer** | L4 | L4 | L7 |
| **Протоколы** | TCP/UDP | TCP/UDP | HTTP/HTTPS |
| **Внешний IP** | ❌ | ✅ | ✅ |
| **SSL Termination** | ❌ | ❌ | ✅ |
| **Path Routing** | ❌ | ❌ | ✅ |
| **Host Routing** | ❌ | ❌ | ✅ |
| **Стоимость** | Бесплатно | Платно | Контроллер |

## 🔧 **Практические примеры использования:**

### **Тестирование доступа:**
```bash
# NodePort
curl http://<node-ip>:30080

# LoadBalancer
curl http://<external-ip>

# Ingress
curl -H "Host: app.example.com" http://<ingress-ip>
```

### **Проверка статуса:**
```bash
# Проверка сервисов
kubectl get services

# Проверка Ingress
kubectl get ingress

# Детальная информация
kubectl describe service <service-name>
kubectl describe ingress <ingress-name>
```

**Выбор типа сервиса зависит от требований приложения, среды развертывания и бюджета!**
