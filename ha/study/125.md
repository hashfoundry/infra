# 125. Как реализовать управление входящим трафиком через Ingress

## 🎯 **Как реализовать управление входящим трафиком через Ingress**

**Ingress traffic management** - это критически важный компонент Kubernetes, который обеспечивает управление внешним доступом к сервисам в кластере. Правильная реализация Ingress позволяет эффективно маршрутизировать HTTP/HTTPS трафик, обеспечивать SSL termination и load balancing.

## 🌐 **Архитектура Ingress:**

### **1. Ingress Components:**
- **Ingress Controller** - реализация Ingress функциональности
- **Ingress Resources** - правила маршрутизации трафика
- **Backend Services** - целевые сервисы
- **Load Balancer** - внешний балансировщик нагрузки

### **2. Ingress Controllers:**
- **NGINX Ingress** - популярный open-source контроллер
- **Traefik** - современный cloud-native контроллер
- **HAProxy** - высокопроизводительный контроллер
- **Cloud Provider** - AWS ALB, GCP GLB, Azure Application Gateway

### **3. Traffic Management Features:**
- **Path-based Routing** - маршрутизация по пути
- **Host-based Routing** - маршрутизация по хосту
- **SSL/TLS Termination** - завершение SSL соединений
- **Load Balancing** - балансировка нагрузки

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive ingress traffic management toolkit
cat << 'EOF' > ingress-traffic-management-toolkit.sh
#!/bin/bash

echo "=== Ingress Traffic Management Toolkit ==="
echo "Comprehensive guide for implementing ingress traffic management in HashFoundry HA cluster"
echo

# Функция для анализа текущей Ingress конфигурации
analyze_current_ingress_setup() {
    echo "=== Current Ingress Setup Analysis ==="
    
    echo "1. Check for Ingress Controllers:"
    kubectl get pods --all-namespaces | grep -E "(ingress|nginx|traefik|haproxy)" || echo "No obvious ingress controllers found"
    echo
    
    echo "2. Check Ingress Classes:"
    kubectl get ingressclass 2>/dev/null || echo "No IngressClass resources found"
    echo
    
    echo "3. Existing Ingress Resources:"
    kubectl get ingress --all-namespaces -o wide
    echo
    
    echo "4. LoadBalancer Services (potential ingress endpoints):"
    kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer -o wide
    echo
    
    echo "5. NodePort Services (potential ingress backends):"
    kubectl get services --all-namespaces --field-selector spec.type=NodePort -o wide
    echo
    
    echo "6. Check for existing ingress configurations:"
    if kubectl get configmap -n kube-system | grep -q nginx; then
        echo "NGINX Ingress configuration found:"
        kubectl get configmap -n kube-system | grep nginx
    fi
    echo
}

# Функция для установки NGINX Ingress Controller
install_nginx_ingress_controller() {
    echo "=== Installing NGINX Ingress Controller ==="
    
    echo "1. Create NGINX Ingress Controller deployment:"
    cat << NGINX_INGRESS_EOF > nginx-ingress-controller.yaml
# NGINX Ingress Controller for HashFoundry HA cluster
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx

---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  name: ingress-nginx
  namespace: ingress-nginx

---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  # Custom NGINX configuration
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  use-proxy-protocol: "false"
  enable-real-ip: "true"
  proxy-real-ip-cidr: "0.0.0.0/0"
  # Performance tuning
  worker-processes: "auto"
  max-worker-connections: "16384"
  upstream-keepalive-connections: "320"
  upstream-keepalive-requests: "10000"
  # SSL configuration
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  name: ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - endpoints
      - nodes
      - pods
      - secrets
      - namespaces
    verbs:
      - list
      - watch
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - services
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - networking.k8s.io
    resources:
      - ingressclasses
    verbs:
      - get
      - list
      - watch

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  name: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ingress-nginx
subjects:
  - kind: ServiceAccount
    name: ingress-nginx
    namespace: ingress-nginx

---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
    spec:
      serviceAccountName: ingress-nginx
      containers:
        - name: controller
          image: registry.k8s.io/ingress-nginx/controller:v1.8.1
          lifecycle:
            preStop:
              exec:
                command:
                  - /wait-shutdown
          args:
            - /nginx-ingress-controller
            - --configmap=\$(POD_NAMESPACE)/ingress-nginx-controller
            - --report-node-internal-ip-address
            - --tcp-services-configmap=\$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=\$(POD_NAMESPACE)/udp-services
            - --validating-webhook=:8443
            - --validating-webhook-certificate=/usr/local/certificates/cert
            - --validating-webhook-key=/usr/local/certificates/key
          securityContext:
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            runAsUser: 101
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: LD_PRELOAD
              value: /usr/local/lib/libmimalloc.so
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
            - name: https
              containerPort: 443
              protocol: TCP
            - name: webhook
              containerPort: 8443
              protocol: TCP
          livenessProbe:
            failureThreshold: 5
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          resources:
            requests:
              cpu: 100m
              memory: 90Mi

---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  name: nginx
spec:
  controller: k8s.io/ingress-nginx

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
    - name: https
      port: 443
      protocol: TCP
      targetPort: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

NGINX_INGRESS_EOF
    
    echo "✅ NGINX Ingress Controller configuration created: nginx-ingress-controller.yaml"
    echo "To deploy: kubectl apply -f nginx-ingress-controller.yaml"
    echo
}

# Функция для создания примеров Ingress правил
create_ingress_examples() {
    echo "=== Creating Ingress Examples ==="
    
    echo "1. Basic HTTP Ingress:"
    cat << BASIC_INGRESS_EOF > basic-http-ingress.yaml
# Basic HTTP Ingress example
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-http-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: app.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080

BASIC_INGRESS_EOF
    
    echo "2. HTTPS Ingress with TLS:"
    cat << HTTPS_INGRESS_EOF > https-tls-ingress.yaml
# HTTPS Ingress with TLS termination
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-tls-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - secure.hashfoundry.local
    secretName: hashfoundry-tls
  rules:
  - host: secure.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-web-service
            port:
              number: 443

HTTPS_INGRESS_EOF
    
    echo "3. Multi-host Ingress:"
    cat << MULTIHOST_INGRESS_EOF > multi-host-ingress.yaml
# Multi-host Ingress configuration
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  rules:
  # Frontend application
  - host: frontend.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  
  # API backend
  - host: api.hashfoundry.local
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-v1-service
            port:
              number: 8080
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: api-v2-service
            port:
              number: 8080
  
  # Admin interface
  - host: admin.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 3000

MULTIHOST_INGRESS_EOF
    
    echo "4. Advanced Ingress with annotations:"
    cat << ADVANCED_INGRESS_EOF > advanced-ingress.yaml
# Advanced Ingress with custom annotations
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: advanced-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    # Rate limiting
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    # CORS configuration
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://hashfoundry.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    # Custom headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
    # Load balancing
    nginx.ingress.kubernetes.io/upstream-hash-by: "\$request_uri"
    # Session affinity
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "hashfoundry-session"
    nginx.ingress.kubernetes.io/session-cookie-expires: "86400"
    # Custom timeouts
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
spec:
  rules:
  - host: advanced.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: advanced-service
            port:
              number: 80

ADVANCED_INGRESS_EOF
    
    echo "✅ Ingress examples created:"
    echo "  - basic-http-ingress.yaml"
    echo "  - https-tls-ingress.yaml"
    echo "  - multi-host-ingress.yaml"
    echo "  - advanced-ingress.yaml"
    echo
}

# Функция для создания тестовых приложений
create_test_applications() {
    echo "=== Creating Test Applications ==="
    
    echo "1. Web application for testing:"
    cat << WEB_APP_EOF > test-web-application.yaml
# Test web application for ingress testing
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-web-app
  namespace: default
  labels:
    app: test-web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-web-app
  template:
    metadata:
      labels:
        app: test-web-app
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
          name: web-content

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>HashFoundry Test App</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 800px; margin: 0 auto; }
            .header { background: #2196F3; color: white; padding: 20px; border-radius: 5px; }
            .content { padding: 20px; background: #f5f5f5; margin-top: 20px; border-radius: 5px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 HashFoundry HA Cluster</h1>
                <p>Ingress Traffic Management Test Application</p>
            </div>
            <div class="content">
                <h2>Application Information</h2>
                <p><strong>Pod:</strong> <span id="hostname">Loading...</span></p>
                <p><strong>Timestamp:</strong> <span id="timestamp"></span></p>
                <p><strong>Request Path:</strong> <span id="path"></span></p>
                
                <h3>Test Endpoints</h3>
                <ul>
                    <li><a href="/api/health">Health Check</a></li>
                    <li><a href="/api/info">Application Info</a></li>
                    <li><a href="/metrics">Metrics</a></li>
                </ul>
            </div>
        </div>
        
        <script>
            document.getElementById('hostname').textContent = window.location.hostname;
            document.getElementById('timestamp').textContent = new Date().toISOString();
            document.getElementById('path').textContent = window.location.pathname;
        </script>
    </body>
    </html>

---
apiVersion: v1
kind: Service
metadata:
  name: test-web-service
  namespace: default
  labels:
    app: test-web-app
spec:
  selector:
    app: test-web-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  type: ClusterIP

WEB_APP_EOF
    
    echo "2. API application for testing:"
    cat << API_APP_EOF > test-api-application.yaml
# Test API application for ingress testing
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-api-app
  namespace: default
  labels:
    app: test-api-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-api-app
  template:
    metadata:
      labels:
        app: test-api-app
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:0.2.3
        args:
          - "-text=HashFoundry API Response from \$(hostname)"
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
  name: test-api-service
  namespace: default
  labels:
    app: test-api-app
spec:
  selector:
    app: test-api-app
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  type: ClusterIP

API_APP_EOF
    
    echo "✅ Test applications created:"
    echo "  - test-web-application.yaml"
    echo "  - test-api-application.yaml"
    echo
}

# Функция для создания SSL/TLS сертификатов
create_ssl_certificates() {
    echo "=== Creating SSL/TLS Certificates ==="
    
    echo "1. Self-signed certificate for testing:"
    cat << SSL_CERT_EOF > create-ssl-certificate.sh
#!/bin/bash

echo "Creating self-signed SSL certificate for HashFoundry..."

# Create private key
openssl genrsa -out hashfoundry.key 2048

# Create certificate signing request
openssl req -new -key hashfoundry.key -out hashfoundry.csr -subj "/C=US/ST=CA/L=San Francisco/O=HashFoundry/OU=IT/CN=*.hashfoundry.local"

# Create self-signed certificate
openssl x509 -req -in hashfoundry.csr -signkey hashfoundry.key -out hashfoundry.crt -days 365 -extensions v3_req -extfile <(cat <<EOF
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = hashfoundry.local
DNS.2 = *.hashfoundry.local
DNS.3 = app.hashfoundry.local
DNS.4 = api.hashfoundry.local
DNS.5 = secure.hashfoundry.local
EOF
)

# Create Kubernetes secret
kubectl create secret tls hashfoundry-tls \\
  --cert=hashfoundry.crt \\
  --key=hashfoundry.key \\
  --namespace=default

echo "✅ SSL certificate created and stored in Kubernetes secret 'hashfoundry-tls'"

# Cleanup temporary files
rm hashfoundry.csr

SSL_CERT_EOF
    
    chmod +x create-ssl-certificate.sh
    echo "✅ SSL certificate creation script: create-ssl-certificate.sh"
    echo
    
    echo "2. cert-manager configuration for automatic certificates:"
    cat << CERT_MANAGER_EOF > cert-manager-setup.yaml
# cert-manager ClusterIssuer for automatic SSL certificates
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@hashfoundry.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx

---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@hashfoundry.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx

CERT_MANAGER_EOF
    
    echo "✅ cert-manager configuration created: cert-manager-setup.yaml"
    echo
}

# Функция для мониторинга и troubleshooting Ingress
create_ingress_monitoring() {
    echo "=== Creating Ingress Monitoring and Troubleshooting Tools ==="
    
    echo "1. Ingress monitoring script:"
    cat << MONITORING_SCRIPT_EOF > ingress-monitoring.sh
#!/bin/bash

echo "=== Ingress Monitoring Dashboard ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Ingress Controller Status:"
    kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers | awk '{print \$1 " " \$3}'
    echo
    
    echo "Ingress Resources:"
    kubectl get ingress --all-namespaces --no-headers | awk '{print \$1 "/" \$2 " " \$3 " " \$4}'
    echo
    
    echo "LoadBalancer Services:"
    kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer --no-headers | awk '{print \$1 "/" \$2 " " \$4 " " \$5}'
    echo
    
    echo "Recent Ingress Controller Logs:"
    kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=5 --since=1m 2>/dev/null | grep -E "(error|warn|fail)" || echo "No recent errors"
    echo
    
    sleep 30
done

MONITORING_SCRIPT_EOF
    
    chmod +x ingress-monitoring.sh
    echo "✅ Ingress monitoring script created: ingress-monitoring.sh"
    echo
    
    echo "2. Ingress troubleshooting guide:"
    cat << TROUBLESHOOTING_GUIDE_EOF > ingress-troubleshooting-guide.md
# Ingress Troubleshooting Guide

## 🔍 **Common Issues and Solutions**

### **Issue 1: Ingress Not Accessible**

#### **Symptoms:**
- 404 Not Found errors
- Connection timeouts
- DNS resolution failures

#### **Diagnosis Steps:**
\`\`\`bash
# Check ingress controller status
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress --all-namespaces

# Check service endpoints
kubectl get endpoints <service-name>

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
\`\`\`

#### **Common Solutions:**
1. Verify ingress controller is running
2. Check ingress rules syntax
3. Ensure backend services exist
4. Verify DNS configuration

### **Issue 2: SSL/TLS Certificate Problems**

#### **Symptoms:**
- SSL certificate errors
- Mixed content warnings
- Certificate not trusted

#### **Diagnosis Steps:**
\`\`\`bash
# Check TLS secrets
kubectl get secrets | grep tls

# Verify certificate details
kubectl get secret <tls-secret> -o yaml

# Check cert-manager status
kubectl get certificates
kubectl get certificaterequests
\`\`\`

### **Issue 3: Load Balancing Issues**

#### **Symptoms:**
- Uneven traffic distribution
- Session affinity problems
- Backend connection errors

#### **Diagnosis Steps:**
\`\`\`bash
# Check backend pod status
kubectl get pods -l app=<app-label>

# Monitor ingress metrics
kubectl exec -n ingress-nginx <controller-pod> -- curl localhost:10254/metrics

# Test backend connectivity
kubectl exec <test-pod> -- curl <backend-service>:<port>
\`\`\`

## 🛠️ **Debugging Commands**

### **Ingress Controller Debugging:**
\`\`\`bash
# Get controller configuration
kubectl exec -n ingress-nginx <controller-pod> -- cat /etc/nginx/nginx.conf

# Check upstream configuration
kubectl exec -n ingress-nginx <controller-pod> -- nginx -T

# Monitor real-time logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
\`\`\`

### **Network Connectivity Testing:**
\`\`\`bash
# Test from outside cluster
curl -H "Host: app.hashfoundry.local" http://<ingress-ip>/

# Test with verbose output
curl -v -H "Host: app.hashfoundry.local" https://<ingress-ip>/

# Test specific paths
curl -H "Host: api.hashfoundry.local" http://<ingress-ip>/v1/health
\`\`\`

### **Performance Testing:**
\`\`\`bash
# Load testing with ab
ab -n 1000 -c 10 -H "Host: app.hashfoundry.local" http://<ingress-ip>/

# Load testing with wrk
wrk -t12 -c400 -d30s -H "Host: app.hashfoundry.local" http://<ingress-ip>/
\`\`\`

TROUBLESHOOTING_GUIDE_EOF
    
    echo "✅ Ingress troubleshooting guide created: ingress-troubleshooting-guide.md"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_ingress_setup
            ;;
        "install")
            install_nginx_ingress_controller
            ;;
        "examples")
            create_ingress_examples
            ;;
        "apps")
            create_test_applications
            ;;
        "ssl")
            create_ssl_certificates
            ;;
        "monitor")
            create_ingress_monitoring
            ;;
        "all"|"")
            analyze_current_ingress_setup
            install_nginx_ingress_controller
            create_ingress_examples
            create_test_applications
            create_ssl_certificates
            create_ingress_monitoring
            ;;
        *)
            echo "Usage: $0 [analyze|install|examples|apps|ssl|monitor|all]"
            echo ""
            echo "Ingress Traffic Management Options:"
            echo "  analyze   - Analyze current ingress setup"
            echo "  install   - Install NGINX Ingress Controller"
            echo "  examples  - Create Ingress examples"
            echo "  apps      - Create test applications"
            echo "  ssl       - Create SSL certificates"
            echo "  monitor   - Create monitoring tools"
            ;;
    esac
}

main "$@"

EOF

chmod +x ingress-traffic-management-toolkit.sh
./ingress-traffic-management-toolkit.sh all
```

## 🎯 **Основные компоненты Ingress:**

### **1. Установка NGINX Ingress Controller:**
```bash
# Проверка текущих Ingress Controllers
kubectl get pods --all-namespaces | grep ingress

# Установка NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Проверка статуса
kubectl get pods -n ingress-nginx
```

### **2. Базовый Ingress ресурс:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: app.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### **3. HTTPS Ingress с TLS:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - secure.hashfoundry.local
    secretName: hashfoundry-tls
  rules:
  - host: secure.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 443
```

## 🔧 **Advanced Ingress Features:**

### **Rate Limiting:**
```yaml
annotations:
  nginx.ingress.kubernetes.io/rate-limit: "100"
  nginx.ingress.kubernetes.io/rate-limit-window: "1m"
```

### **CORS Configuration:**
```yaml
annotations:
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "https://hashfoundry.com"
```

### **Session Affinity:**
```yaml
annotations:
  nginx.ingress.kubernetes.io/affinity: "cookie"
  nginx.ingress.kubernetes.io/session-cookie-name: "route"
```

## 🌐 **Тестирование Ingress:**

### **Создание тестового приложения:**
```bash
# Развертывание тестового приложения
kubectl create deployment test-app --image=nginx:alpine
kubectl expose deployment test-app --port=80

# Создание Ingress
kubectl apply -f basic-ingress.yaml

# Тестирование
curl -H "Host: app.hashfoundry.local" http://<ingress-ip>/
```

### **SSL сертификаты:**
```bash
# Создание self-signed сертификата
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=*.hashfoundry.local"

# Создание Kubernetes secret
kubectl create secret tls hashfoundry-tls \
  --key tls.key --cert tls.crt
```

### **Мониторинг Ingress:**
```bash
# Проверка статуса Ingress Controller
kubectl get pods -n ingress-nginx

# Просмотр логов
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Проверка Ingress ресурсов
kubectl get ingress --all-namespaces
```

**Правильная реализация Ingress обеспечивает эффективное управление внешним трафиком в Kubernetes!**
