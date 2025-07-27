# 38. Как реализовать SSL/TLS termination в Kubernetes?

## 🎯 **Что такое SSL/TLS termination?**

**SSL/TLS termination** — это процесс расшифровки HTTPS трафика на уровне Load Balancer или Ingress Controller, после чего трафик передается к backend сервисам в незашифрованном виде. Это позволяет централизованно управлять сертификатами и снизить нагрузку на backend приложения.

## 🏗️ **Методы SSL/TLS termination в Kubernetes:**

### **1. Ingress Controller termination**
- Наиболее популярный подход
- Централизованное управление сертификатами
- Автоматическое обновление через cert-manager

### **2. LoadBalancer termination**
- На уровне cloud provider
- Высокая производительность
- Ограниченная гибкость

### **3. Pod-level termination**
- Сертификаты в каждом Pod'е
- Максимальная безопасность
- Сложность управления

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Создание самоподписанных сертификатов:**
```bash
# Создать CA (Certificate Authority)
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -sha256 -subj "/C=US/ST=CA/O=HashFoundry/CN=HashFoundry CA" -days 3650 -out ca.crt

# Создать приватный ключ для домена
openssl genrsa -out tls.key 4096

# Создать CSR (Certificate Signing Request)
openssl req -new -key tls.key -out tls.csr -subj "/C=US/ST=CA/O=HashFoundry/CN=*.hashfoundry.local"

# Создать конфигурацию для SAN (Subject Alternative Names)
cat > tls.conf <<EOF
[req]
default_bits = 4096
prompt = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
C = US
ST = CA
O = HashFoundry
CN = *.hashfoundry.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.hashfoundry.local
DNS.2 = hashfoundry.local
DNS.3 = secure.hashfoundry.local
DNS.4 = api.hashfoundry.local
EOF

# Подписать сертификат с помощью CA
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 365 -sha256 -extensions v3_req -extfile tls.conf

# Проверить сертификат
openssl x509 -in tls.crt -text -noout

# Создать Kubernetes Secret
kubectl create secret tls wildcard-tls --cert=tls.crt --key=tls.key

# Проверить Secret
kubectl describe secret wildcard-tls
```

### **2. SSL/TLS termination через Ingress:**
```bash
# Создать приложение для HTTPS демонстрации
cat << EOF | kubectl apply -f -
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
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: html
        configMap:
          name: secure-web-content
      - name: nginx-config
        configMap:
          name: nginx-ssl-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: secure-web-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <title>Secure Web App</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .secure { color: green; font-weight: bold; }
        .info { background: #f0f0f0; padding: 20px; border-radius: 5px; }
      </style>
    </head>
    <body>
      <h1>🔒 Secure Web Application</h1>
      <div class="info">
        <p class="secure">✅ SSL/TLS Termination активен</p>
        <p>Этот сайт защищен HTTPS через Ingress Controller</p>
        <p>Сертификат: *.hashfoundry.local</p>
        <p>Время: <span id="time"></span></p>
      </div>
      <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
      </script>
    </body>
    </html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ssl-config
data:
  default.conf: |
    server {
        listen 80;
        server_name _;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: secure-web-service
spec:
  selector:
    app: secure-web-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-web-ingress
  annotations:
    # SSL настройки
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    
    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # SSL protocols
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256,ECDHE-RSA-AES128-GCM-SHA256,ECDHE-ECDSA-AES256-GCM-SHA384,ECDHE-RSA-AES256-GCM-SHA384"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.hashfoundry.local
    secretName: wildcard-tls
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
              number: 80
EOF

# Проверить HTTPS Ingress
kubectl get ingress secure-web-ingress
kubectl describe ingress secure-web-ingress

# Получить IP Ingress Controller'а
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Тестирование HTTPS
echo "Testing HTTPS connection..."
curl -k -H "Host: secure.hashfoundry.local" https://$INGRESS_IP/ -v

# Проверить редирект с HTTP на HTTPS
echo "Testing HTTP to HTTPS redirect..."
curl -H "Host: secure.hashfoundry.local" http://$INGRESS_IP/ -v

kubectl delete deployment secure-web-app
kubectl delete service secure-web-service
kubectl delete configmap secure-web-content nginx-ssl-config
kubectl delete ingress secure-web-ingress
```

### **3. Установка и настройка cert-manager:**
```bash
# Установить cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Проверить установку
kubectl get pods -n cert-manager

# Создать ClusterIssuer для самоподписанных сертификатов
cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
# CA Issuer для создания собственного CA
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: hashfoundry-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: HashFoundry CA
  secretName: hashfoundry-ca-secret
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: hashfoundry-ca-issuer
spec:
  ca:
    secretName: hashfoundry-ca-secret
EOF

# Проверить ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer hashfoundry-ca-issuer
```

### **4. Автоматические сертификаты с cert-manager:**
```bash
# Приложение с автоматическими сертификатами
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auto-ssl-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: auto-ssl-app
  template:
    metadata:
      labels:
        app: auto-ssl-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: auto-ssl-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: auto-ssl-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Auto SSL App</title></head>
    <body>
      <h1>🤖 Автоматический SSL</h1>
      <p>Сертификат создан автоматически через cert-manager</p>
      <p>Domain: api.hashfoundry.local</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: auto-ssl-service
spec:
  selector:
    app: auto-ssl-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auto-ssl-ingress
  annotations:
    # cert-manager аннотации
    cert-manager.io/cluster-issuer: "hashfoundry-ca-issuer"
    
    # SSL настройки
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.hashfoundry.local
    secretName: auto-ssl-tls  # cert-manager создаст автоматически
  rules:
  - host: api.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: auto-ssl-service
            port:
              number: 80
EOF

# Проверить создание сертификата
kubectl get certificate
kubectl describe certificate auto-ssl-tls

# Проверить Secret с сертификатом
kubectl get secret auto-ssl-tls
kubectl describe secret auto-ssl-tls

# Тестирование
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: api.hashfoundry.local" https://$INGRESS_IP/

kubectl delete deployment auto-ssl-app
kubectl delete service auto-ssl-service
kubectl delete configmap auto-ssl-content
kubectl delete ingress auto-ssl-ingress
```

## 🔧 **Advanced SSL/TLS конфигурации:**

### **1. Mutual TLS (mTLS):**
```bash
# Создать клиентский сертификат
openssl genrsa -out client.key 4096
openssl req -new -key client.key -out client.csr -subj "/C=US/ST=CA/O=HashFoundry/CN=client.hashfoundry.local"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256

# Создать Secret с CA сертификатом
kubectl create secret generic ca-secret --from-file=ca.crt=ca.crt

# mTLS Ingress
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mtls-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mtls-app
  template:
    metadata:
      labels:
        app: mtls-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: mtls-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mtls-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>mTLS App</title></head>
    <body>
      <h1>🔐 Mutual TLS Application</h1>
      <p>Требуется клиентский сертификат для доступа</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: mtls-service
spec:
  selector:
    app: mtls-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mtls-ingress
  annotations:
    # mTLS настройки
    nginx.ingress.kubernetes.io/auth-tls-verify-client: "on"
    nginx.ingress.kubernetes.io/auth-tls-secret: "default/ca-secret"
    nginx.ingress.kubernetes.io/auth-tls-verify-depth: "1"
    nginx.ingress.kubernetes.io/auth-tls-error-page: "https://example.com/error"
    
    # SSL настройки
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - mtls.hashfoundry.local
    secretName: wildcard-tls
  rules:
  - host: mtls.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mtls-service
            port:
              number: 80
EOF

# Тестирование mTLS
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Без клиентского сертификата (должно быть отклонено)
curl -k -H "Host: mtls.hashfoundry.local" https://$INGRESS_IP/ -v

# С клиентским сертификатом
curl -k -H "Host: mtls.hashfoundry.local" --cert client.crt --key client.key https://$INGRESS_IP/ -v

kubectl delete deployment mtls-app
kubectl delete service mtls-service
kubectl delete configmap mtls-content
kubectl delete ingress mtls-ingress
kubectl delete secret ca-secret
```

### **2. SSL Passthrough:**
```bash
# Приложение с собственным SSL
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ssl-passthrough-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ssl-passthrough-app
  template:
    metadata:
      labels:
        app: ssl-passthrough-app
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 443
        volumeMounts:
        - name: ssl-certs
          mountPath: /etc/ssl/certs
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: ssl-certs
        secret:
          secretName: wildcard-tls
      - name: nginx-config
        configMap:
          name: ssl-passthrough-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssl-passthrough-config
data:
  default.conf: |
    server {
        listen 443 ssl;
        server_name passthrough.hashfoundry.local;
        
        ssl_certificate /etc/ssl/certs/tls.crt;
        ssl_certificate_key /etc/ssl/certs/tls.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256;
        
        location / {
            return 200 '<!DOCTYPE html><html><head><title>SSL Passthrough</title></head><body><h1>🔄 SSL Passthrough</h1><p>SSL обрабатывается на уровне Pod</p></body></html>';
            add_header Content-Type text/html;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: ssl-passthrough-service
spec:
  selector:
    app: ssl-passthrough-app
  ports:
  - port: 443
    targetPort: 443
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ssl-passthrough-ingress
  annotations:
    # SSL Passthrough
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
  - host: passthrough.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ssl-passthrough-service
            port:
              number: 443
EOF

# Тестирование SSL Passthrough
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: passthrough.hashfoundry.local" https://$INGRESS_IP/ -v

kubectl delete deployment ssl-passthrough-app
kubectl delete service ssl-passthrough-service
kubectl delete configmap ssl-passthrough-config
kubectl delete ingress ssl-passthrough-ingress
```

## 🏭 **Production SSL/TLS setup:**

### **1. Let's Encrypt с cert-manager:**
```bash
# ClusterIssuer для Let's Encrypt (для production)
cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # ACME server URL для production
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@hashfoundry.com  # Замените на ваш email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
# ClusterIssuer для Let's Encrypt staging (для тестирования)
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
EOF

# Пример Ingress с Let's Encrypt (для реального домена)
cat << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - yourdomain.com
    - www.yourdomain.com
    secretName: production-tls
  rules:
  - host: yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: your-service
            port:
              number: 80
EOF
```

### **2. SSL мониторинг и алерты:**
```bash
# Certificate monitoring
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssl-monitoring-script
data:
  check-ssl.sh: |
    #!/bin/bash
    
    # Проверить срок действия сертификата
    check_cert_expiry() {
        local host=$1
        local port=${2:-443}
        
        expiry_date=$(echo | openssl s_client -servername $host -connect $host:$port 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        echo "Certificate for $host expires in $days_until_expiry days"
        
        if [ $days_until_expiry -lt 30 ]; then
            echo "WARNING: Certificate expires soon!"
            return 1
        fi
        return 0
    }
    
    # Проверить все домены
    check_cert_expiry "secure.hashfoundry.local"
    check_cert_expiry "api.hashfoundry.local"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ssl-cert-monitor
spec:
  schedule: "0 6 * * *"  # Каждый день в 6:00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: ssl-monitor
            image: alpine/openssl
            command:
            - /bin/sh
            - /scripts/check-ssl.sh
            volumeMounts:
            - name: script
              mountPath: /scripts
          volumes:
          - name: script
            configMap:
              name: ssl-monitoring-script
              defaultMode: 0755
          restartPolicy: OnFailure
EOF

# Проверить CronJob
kubectl get cronjob ssl-cert-monitor
```

## 🚨 **Troubleshooting SSL/TLS:**

### **1. Диагностика сертификатов:**
```bash
# Проверить сертификаты в кластере
kubectl get certificates -A
kubectl get secrets -A | grep tls

# Проверить конкретный сертификат
kubectl describe certificate <certificate-name>
kubectl get secret <tls-secret-name> -o yaml

# Декодировать сертификат из Secret
kubectl get secret wildcard-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Проверить cert-manager логи
kubectl logs -n cert-manager deployment/cert-manager -f

# Проверить события cert-manager
kubectl get events -n cert-manager --sort-by='.lastTimestamp'
```

### **2. Тестирование SSL соединений:**
```bash
# Создать debug Pod для SSL тестирования
kubectl run ssl-debug --image=alpine/openssl -it --rm -- sh

# Внутри Pod'а:
# openssl s_client -connect secure.hashfoundry.local:443 -servername secure.hashfoundry.local
# openssl s_client -connect $INGRESS_IP:443 -servername secure.hashfoundry.local

# Проверить SSL конфигурацию Ingress Controller
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep ssl
```

### **3. Общие проблемы и решения:**
```bash
# 1. Сертификат не создается
kubectl describe certificate <cert-name>
kubectl describe certificaterequest <cert-request-name>

# 2. Ingress не использует сертификат
kubectl describe ingress <ingress-name>
kubectl get ingress <ingress-name> -o yaml

# 3. SSL handshake ошибки
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep ssl

# 4. cert-manager проблемы
kubectl get clusterissuer
kubectl describe clusterissuer <issuer-name>
```

## 🎯 **Best Practices:**

### **1. Безопасность сертификатов:**
- Использование сильных алгоритмов шифрования
- Регулярное обновление сертификатов
- Мониторинг сроков действия
- Безопасное хранение приватных ключей

### **2. Производительность:**
- SSL session caching
- HTTP/2 поддержка
- OCSP stapling
- Оптимизация cipher suites

### **3. Мониторинг:**
- Метрики SSL handshake времени
- Алерты на истечение сертификатов
- Мониторинг SSL ошибок
- Dashboard для SSL статуса

### **4. Автоматизация:**
- Автоматическое обновление через cert-manager
- CI/CD интеграция для сертификатов
- Backup и restore процедуры
- Disaster recovery планы

**SSL/TLS termination в Kubernetes обеспечивает безопасную передачу данных с централизованным управлением сертификатами!**

# Очистка демо ресурсов
kubectl delete secret wildcard-tls ca-secret
rm -f ca.key ca.crt ca.srl tls.key tls.crt tls.csr tls.conf client.key client.crt client.csr
