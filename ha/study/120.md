# 120. Как отлаживать проблемы с сертификатами в Kubernetes

## 🎯 **Как отлаживать проблемы с сертификатами в Kubernetes**

**Сертификаты** - основа безопасности Kubernetes кластера. Проблемы с сертификатами могут привести к полной недоступности кластера, поэтому понимание диагностики и управления сертификатами критически важно.

## 🔐 **Архитектура сертификатов в Kubernetes:**

### **1. Certificate Types:**
- **CA Certificates** - корневые сертификаты
- **Server Certificates** - сертификаты серверов
- **Client Certificates** - клиентские сертификаты
- **Service Account Tokens** - токены сервисных аккаунтов

### **2. Key Components:**
- **kube-apiserver** - API server сертификаты
- **etcd** - etcd cluster сертификаты
- **kubelet** - node сертификаты
- **kube-proxy** - proxy сертификаты

### **3. Common Certificate Issues:**
- **Expiration** - истечение срока действия
- **Invalid CN/SAN** - неправильные имена
- **Trust chain** - проблемы с цепочкой доверия
- **Permission issues** - проблемы с правами доступа

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive certificate troubleshooting toolkit
cat << 'EOF' > certificate-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== Certificate Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing certificate issues in HashFoundry HA cluster"
echo

# Функция для проверки всех сертификатов кластера
check_all_certificates() {
    echo "=== Cluster Certificates Overview ==="
    
    echo "1. Check certificate expiration with kubeadm:"
    kubeadm certs check-expiration 2>/dev/null || echo "❌ kubeadm not available or not a kubeadm cluster"
    echo
    
    echo "2. Manual certificate check:"
    echo "Checking key certificate files..."
    
    # Common certificate locations
    CERT_DIRS=(
        "/etc/kubernetes/pki"
        "/etc/kubernetes/pki/etcd"
        "/var/lib/kubelet/pki"
    )
    
    for dir in "${CERT_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "--- Certificates in $dir ---"
            find "$dir" -name "*.crt" -exec basename {} \; 2>/dev/null | sort
            echo
        fi
    done
    
    echo "3. Check certificates in running pods:"
    echo "API Server certificates:"
    kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}' | xargs -I {} kubectl exec -n kube-system {} -- ls -la /etc/kubernetes/pki/ 2>/dev/null || echo "Cannot access API server certificates"
    echo
    
    echo "etcd certificates:"
    kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}' | xargs -I {} kubectl exec -n kube-system {} -- ls -la /etc/kubernetes/pki/etcd/ 2>/dev/null || echo "Cannot access etcd certificates"
    echo
}

# Функция для детальной проверки конкретного сертификата
check_certificate_details() {
    local CERT_FILE=$1
    
    if [ -z "$CERT_FILE" ]; then
        echo "Usage: check_certificate_details <certificate-file>"
        return 1
    fi
    
    if [ ! -f "$CERT_FILE" ]; then
        echo "❌ Certificate file not found: $CERT_FILE"
        return 1
    fi
    
    echo "=== Certificate Details: $CERT_FILE ==="
    
    echo "1. Certificate basic info:"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 2 "Subject:"
    echo
    
    echo "2. Certificate validity:"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 2 "Validity"
    echo
    
    echo "3. Certificate expiration check:"
    EXPIRY_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY_DATE" +%s 2>/dev/null)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
    
    if [ $DAYS_LEFT -lt 0 ]; then
        echo "❌ Certificate EXPIRED $((DAYS_LEFT * -1)) days ago"
    elif [ $DAYS_LEFT -lt 30 ]; then
        echo "⚠️  Certificate expires in $DAYS_LEFT days"
    else
        echo "✅ Certificate valid for $DAYS_LEFT days"
    fi
    echo
    
    echo "4. Certificate Subject Alternative Names:"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 1 "Subject Alternative Name" || echo "No SAN found"
    echo
    
    echo "5. Certificate fingerprint:"
    openssl x509 -in "$CERT_FILE" -noout -fingerprint -sha256
    echo
}

# Функция для проверки сертификатов API server
check_apiserver_certificates() {
    echo "=== API Server Certificate Check ==="
    
    echo "1. API server pod certificate mounts:"
    kubectl describe pods -n kube-system -l component=kube-apiserver | grep -A 10 -B 5 "Mounts:" | grep -E "(pki|cert)"
    echo
    
    echo "2. Test API server certificate from outside:"
    API_SERVER_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||' | sed 's|:.*||')
    API_SERVER_PORT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|.*:||')
    
    echo "Testing certificate for $API_SERVER_HOST:$API_SERVER_PORT"
    echo | openssl s_client -connect "$API_SERVER_HOST:$API_SERVER_PORT" -servername "$API_SERVER_HOST" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "❌ Cannot retrieve API server certificate"
    echo
    
    echo "3. Check API server certificate from inside cluster:"
    API_SERVER_POD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$API_SERVER_POD" ]; then
        echo "Checking API server certificate in pod $API_SERVER_POD:"
        kubectl exec -n kube-system $API_SERVER_POD -- openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A 2 "Validity" 2>/dev/null || echo "Cannot access certificate"
    fi
    echo
    
    echo "4. Check client certificate authentication:"
    echo "Testing client certificate authentication..."
    kubectl auth can-i get pods --as=system:admin 2>/dev/null && echo "✅ Client certificate authentication working" || echo "❌ Client certificate authentication failed"
    echo
}

# Функция для проверки etcd сертификатов
check_etcd_certificates() {
    echo "=== etcd Certificate Check ==="
    
    echo "1. etcd certificate files:"
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$ETCD_POD" ]; then
        echo "Checking etcd certificates in pod $ETCD_POD:"
        kubectl exec -n kube-system $ETCD_POD -- ls -la /etc/kubernetes/pki/etcd/ 2>/dev/null || echo "Cannot access etcd certificates"
        echo
        
        echo "2. etcd server certificate details:"
        kubectl exec -n kube-system $ETCD_POD -- openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -text -noout | grep -A 2 "Validity" 2>/dev/null || echo "Cannot read etcd server certificate"
        echo
        
        echo "3. etcd peer certificate details:"
        kubectl exec -n kube-system $ETCD_POD -- openssl x509 -in /etc/kubernetes/pki/etcd/peer.crt -text -noout | grep -A 2 "Validity" 2>/dev/null || echo "Cannot read etcd peer certificate"
        echo
        
        echo "4. Test etcd certificate connectivity:"
        kubectl exec -n kube-system $ETCD_POD -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            endpoint health 2>/dev/null && echo "✅ etcd certificate authentication working" || echo "❌ etcd certificate authentication failed"
    else
        echo "❌ No etcd pods found"
    fi
    echo
}

# Функция для проверки kubelet сертификатов
check_kubelet_certificates() {
    echo "=== Kubelet Certificate Check ==="
    
    echo "1. Check kubelet certificate rotation:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
    echo
    
    echo "2. Check CSRs (Certificate Signing Requests):"
    kubectl get csr | head -10
    echo
    
    echo "3. Check node certificates (if accessible):"
    kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | xargs -I {} kubectl debug node/{} -it --image=busybox -- ls -la /var/lib/kubelet/pki/ 2>/dev/null || echo "Cannot access kubelet certificates directly"
    echo
    
    echo "4. Check kubelet configuration for certificate settings:"
    kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | xargs -I {} kubectl debug node/{} -it --image=busybox -- cat /var/lib/kubelet/config.yaml 2>/dev/null | grep -i cert || echo "Cannot access kubelet config"
    echo
}

# Функция для создания certificate renewal procedures
create_certificate_renewal_procedures() {
    echo "=== Creating Certificate Renewal Procedures ==="
    
    echo "1. Certificate renewal guide:"
    cat << CERT_RENEWAL_EOF > certificate-renewal-guide.md
# Certificate Renewal Guide

## 🔄 **Automatic Certificate Renewal (kubeadm)**

### **1. Check Certificate Expiration**
\`\`\`bash
# Check all certificates
kubeadm certs check-expiration

# Check specific certificate
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep "Not After"
\`\`\`

### **2. Renew All Certificates**
\`\`\`bash
# Backup existing certificates
cp -r /etc/kubernetes/pki /etc/kubernetes/pki.backup

# Renew all certificates
kubeadm certs renew all

# Restart control plane components
systemctl restart kubelet
\`\`\`

### **3. Renew Specific Certificates**
\`\`\`bash
# API server certificate
kubeadm certs renew apiserver

# etcd server certificate
kubeadm certs renew etcd-server

# etcd peer certificate
kubeadm certs renew etcd-peer

# Admin client certificate
kubeadm certs renew admin.conf
\`\`\`

## 🔧 **Manual Certificate Renewal**

### **1. Generate New CA (if needed)**
\`\`\`bash
# Generate new CA private key
openssl genrsa -out ca.key 2048

# Generate new CA certificate
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=kubernetes-ca"
\`\`\`

### **2. Generate Server Certificate**
\`\`\`bash
# Generate server private key
openssl genrsa -out server.key 2048

# Create certificate signing request
openssl req -new -key server.key -out server.csr -subj "/CN=kube-apiserver"

# Generate server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365
\`\`\`

### **3. Update kubeconfig Files**
\`\`\`bash
# Update admin kubeconfig
kubeadm kubeconfig user --org system:masters --client-name kubernetes-admin > /etc/kubernetes/admin.conf

# Update kubelet kubeconfig
kubeadm kubeconfig user --org system:nodes --client-name system:node:\$(hostname) > /etc/kubernetes/kubelet.conf
\`\`\`

## ⚠️ **Certificate Renewal Best Practices**
1. **Backup before renewal**: Always backup existing certificates
2. **Test in staging**: Test renewal procedures in non-production
3. **Monitor expiration**: Set up alerts for certificate expiration
4. **Automate renewal**: Use automated tools when possible
5. **Verify after renewal**: Test cluster functionality after renewal

CERT_RENEWAL_EOF
    
    echo "✅ Certificate renewal guide created: certificate-renewal-guide.md"
    echo
    
    echo "2. Certificate monitoring script:"
    cat << CERT_MONITOR_EOF > certificate-monitor.sh
#!/bin/bash

echo "=== Certificate Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Certificate Expiration Status:"
    
    # Check kubeadm certificates if available
    if command -v kubeadm >/dev/null 2>&1; then
        kubeadm certs check-expiration 2>/dev/null | grep -E "(CERTIFICATE|expires|EXPIRED)" || echo "Cannot check kubeadm certificates"
    else
        echo "kubeadm not available"
    fi
    echo
    
    echo "API Server Certificate Status:"
    API_SERVER_HOST=\$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||' | sed 's|:.*||')
    API_SERVER_PORT=\$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|.*:||')
    
    CERT_INFO=\$(echo | openssl s_client -connect "\$API_SERVER_HOST:\$API_SERVER_PORT" -servername "\$API_SERVER_HOST" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    if [ ! -z "\$CERT_INFO" ]; then
        echo "\$CERT_INFO"
    else
        echo "❌ Cannot retrieve API server certificate"
    fi
    echo
    
    echo "Cluster Component Status:"
    kubectl get pods -n kube-system -l component=kube-apiserver --no-headers | awk '{print "API Server: " \$1 " " \$3}'
    kubectl get pods -n kube-system -l component=etcd --no-headers | awk '{print "etcd: " \$1 " " \$3}'
    echo
    
    sleep 60
done

CERT_MONITOR_EOF
    
    chmod +x certificate-monitor.sh
    echo "✅ Certificate monitoring script created: certificate-monitor.sh"
    echo
}

# Функция для troubleshooting certificate issues
troubleshoot_certificate_issues() {
    echo "=== Certificate Troubleshooting ==="
    
    echo "1. Common certificate error patterns:"
    cat << CERT_TROUBLESHOOTING_EOF
# Common Certificate Issues and Solutions

## ❌ **"x509: certificate signed by unknown authority"**
**Cause**: CA certificate not trusted
**Solution**:
- Check CA certificate in kubeconfig
- Verify CA certificate on nodes
- Update CA bundle if needed

## ❌ **"x509: certificate has expired"**
**Cause**: Certificate has expired
**Solution**:
- Renew expired certificate: kubeadm certs renew <cert-name>
- Restart affected components
- Update kubeconfig files

## ❌ **"x509: certificate is valid for <names>, not <actual-name>"**
**Cause**: Certificate SAN doesn't match hostname
**Solution**:
- Regenerate certificate with correct SAN
- Update DNS/hostname configuration
- Use correct hostname in connections

## ❌ **"tls: bad certificate"**
**Cause**: Invalid or corrupted certificate
**Solution**:
- Verify certificate format
- Check certificate-key pair match
- Regenerate certificate if corrupted

## ❌ **"connection refused" or "timeout"**
**Cause**: Certificate-related connectivity issues
**Solution**:
- Check certificate permissions
- Verify certificate paths in configuration
- Test certificate with openssl s_client

CERT_TROUBLESHOOTING_EOF
    echo
    
    echo "2. Certificate troubleshooting checklist:"
    cat << CERT_CHECKLIST_EOF > certificate-troubleshooting-checklist.md
# Certificate Troubleshooting Checklist

## ✅ **Step 1: Certificate Expiration**
- [ ] Check certificate expiration: \`kubeadm certs check-expiration\`
- [ ] Check specific certificate: \`openssl x509 -in <cert> -noout -dates\`
- [ ] Set up expiration monitoring: alerts for certificates expiring soon

## ✅ **Step 2: Certificate Validity**
- [ ] Verify certificate format: \`openssl x509 -in <cert> -text -noout\`
- [ ] Check certificate-key pair: \`openssl x509 -noout -modulus -in <cert> | openssl md5\`
- [ ] Verify certificate chain: \`openssl verify -CAfile <ca> <cert>\`

## ✅ **Step 3: Certificate Names**
- [ ] Check certificate CN: \`openssl x509 -in <cert> -noout -subject\`
- [ ] Check certificate SAN: \`openssl x509 -in <cert> -noout -text | grep -A1 "Subject Alternative Name"\`
- [ ] Verify hostname matches: ensure certificate covers actual hostnames

## ✅ **Step 4: Certificate Permissions**
- [ ] Check file permissions: \`ls -la /etc/kubernetes/pki/\`
- [ ] Verify ownership: certificates should be owned by root
- [ ] Check SELinux/AppArmor: security contexts for certificate files

## ✅ **Step 5: Certificate Configuration**
- [ ] Verify kubeconfig certificates: \`kubectl config view --raw\`
- [ ] Check component configurations: API server, etcd, kubelet
- [ ] Test certificate connectivity: \`openssl s_client -connect <host:port>\`

## 🔧 **Emergency Procedures**
1. **Certificate expired**: Renew with kubeadm certs renew
2. **CA certificate issues**: Regenerate CA and all certificates
3. **SAN mismatch**: Regenerate certificate with correct SAN
4. **Corrupted certificates**: Restore from backup or regenerate
5. **Permission issues**: Fix file permissions and ownership

CERT_CHECKLIST_EOF
    
    echo "✅ Certificate troubleshooting checklist created: certificate-troubleshooting-checklist.md"
    echo
}

# Основная функция
main() {
    case "$1" in
        "check-all")
            check_all_certificates
            ;;
        "check-cert")
            check_certificate_details $2
            ;;
        "apiserver")
            check_apiserver_certificates
            ;;
        "etcd")
            check_etcd_certificates
            ;;
        "kubelet")
            check_kubelet_certificates
            ;;
        "renewal")
            create_certificate_renewal_procedures
            ;;
        "troubleshoot")
            troubleshoot_certificate_issues
            ;;
        "all"|"")
            check_all_certificates
            check_apiserver_certificates
            check_etcd_certificates
            check_kubelet_certificates
            create_certificate_renewal_procedures
            troubleshoot_certificate_issues
            ;;
        *)
            echo "Usage: $0 [check-all|check-cert <file>|apiserver|etcd|kubelet|renewal|troubleshoot|all]"
            echo ""
            echo "Certificate Troubleshooting Options:"
            echo "  check-all      - Check all cluster certificates"
            echo "  check-cert     - Check specific certificate file"
            echo "  apiserver      - Check API server certificates"
            echo "  etcd           - Check etcd certificates"
            echo "  kubelet        - Check kubelet certificates"
            echo "  renewal        - Create renewal procedures"
            echo "  troubleshoot   - Troubleshoot certificate issues"
            ;;
    esac
}

main "$@"

EOF

chmod +x certificate-troubleshooting-toolkit.sh
./certificate-troubleshooting-toolkit.sh all
```

## 🎯 **Пошаговая диагностика сертификатов:**

### **Шаг 1: Проверка срока действия**
```bash
# Проверка всех сертификатов kubeadm
kubeadm certs check-expiration

# Проверка конкретного сертификата
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# Проверка сертификата API server извне
echo | openssl s_client -connect <api-server>:6443 -servername <hostname> 2>/dev/null | openssl x509 -noout -dates
```

### **Шаг 2: Проверка содержимого сертификата**
```bash
# Детальная информация о сертификате
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout

# Subject и SAN
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"

# Fingerprint сертификата
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -fingerprint -sha256
```

### **Шаг 3: Проверка цепочки доверия**
```bash
# Проверка подписи сертификата
openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt

# Проверка соответствия ключа и сертификата
openssl x509 -noout -modulus -in /etc/kubernetes/pki/apiserver.crt | openssl md5
openssl rsa -noout -modulus -in /etc/kubernetes/pki/apiserver.key | openssl md5
```

### **Шаг 4: Тестирование connectivity**
```bash
# Тест TLS соединения
openssl s_client -connect <api-server>:6443 -servername <hostname>

# Тест аутентификации
kubectl auth can-i get pods --as=system:admin

# Тест etcd сертификатов
kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint health
```

## 🔧 **Обновление сертификатов:**

### **1. Автоматическое обновление (kubeadm):**
```bash
# Проверка срока действия
kubeadm certs check-expiration

# Обновление всех сертификатов
kubeadm certs renew all

# Обновление конкретного сертификата
kubeadm certs renew apiserver
kubeadm certs renew etcd-server
```

### **2. Ручное обновление:**
```bash
# Backup существующих сертификатов
cp -r /etc/kubernetes/pki /etc/kubernetes/pki.backup

# Генерация нового сертификата
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -out server.crt -days 365
```

### **3. Частые проблемы и решения:**

**Сертификат истек:**
- Обновить: `kubeadm certs renew <cert-name>`
- Перезапустить компоненты
- Обновить kubeconfig файлы

**Неправильный CN/SAN:**
- Перегенерировать с правильными именами
- Обновить DNS/hostname
- Использовать правильное имя в подключениях

**Проблемы с CA:**
- Проверить CA сертификат в kubeconfig
- Обновить CA bundle на узлах
- Перегенерировать все сертификаты при необходимости

**Права доступа:**
- Проверить владельца файлов: `chown root:root /etc/kubernetes/pki/*`
- Установить правильные права: `chmod 600 /etc/kubernetes/pki/*.key`

**Правильное управление сертификатами - основа безопасности Kubernetes кластера!**
