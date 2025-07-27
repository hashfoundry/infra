# 112. Основные причины ошибок ImagePullBackOff

## 🎯 **Основные причины ошибок ImagePullBackOff**

**ImagePullBackOff** - одна из самых частых ошибок в Kubernetes, возникающая когда kubelet не может загрузить образ контейнера. Понимание причин и методов решения критически важно для эффективной работы.

## 🔍 **Основные причины ImagePullBackOff:**

### **1. Registry Access Issues:**
- **Authentication failure** - неправильные credentials
- **Network connectivity** - проблемы с сетью
- **Registry unavailable** - недоступность registry
- **Rate limiting** - превышение лимитов запросов

### **2. Image Issues:**
- **Image not found** - образ не существует
- **Wrong tag** - неправильный тег
- **Typo in image name** - опечатка в имени
- **Private registry without secrets** - приватный registry без секретов

### **3. Configuration Issues:**
- **Missing imagePullSecrets** - отсутствующие секреты
- **Wrong secret format** - неправильный формат секрета
- **Namespace mismatch** - несоответствие namespace

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive ImagePullBackOff troubleshooting toolkit
cat << 'EOF' > imagepullbackoff-troubleshooting-toolkit.sh
#!/bin/bash

echo "=== ImagePullBackOff Troubleshooting Toolkit ==="
echo "Comprehensive guide for diagnosing ImagePullBackOff issues in HashFoundry HA cluster"
echo

# Функция для диагностики ImagePullBackOff
diagnose_imagepullbackoff() {
    local POD_NAME=$1
    local NAMESPACE=${2:-default}
    
    if [ -z "$POD_NAME" ]; then
        echo "Usage: diagnose_imagepullbackoff <pod-name> [namespace]"
        return 1
    fi
    
    echo "=== Diagnosing ImagePullBackOff: $NAMESPACE/$POD_NAME ==="
    echo
    
    echo "1. Pod Status and Events:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o wide
    echo
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' | tail -10
    echo
    
    echo "2. Container Image Information:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[*].image}' && echo
    echo
    
    echo "3. Image Pull Secrets:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.imagePullSecrets[*].name}' && echo
    echo
    
    echo "4. Service Account:"
    SA_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.serviceAccountName}')
    echo "Service Account: $SA_NAME"
    if [ ! -z "$SA_NAME" ]; then
        kubectl get serviceaccount $SA_NAME -n $NAMESPACE -o jsonpath='{.imagePullSecrets[*].name}' && echo
    fi
    echo
}

# Функция для поиска всех ImagePullBackOff pods
find_imagepullbackoff_pods() {
    echo "=== Finding All ImagePullBackOff Pods ==="
    
    echo "1. Pods with ImagePullBackOff status:"
    kubectl get pods --all-namespaces | grep -E "(ImagePullBackOff|ErrImagePull)" || echo "No ImagePullBackOff pods found"
    echo
    
    echo "2. Detailed information for each ImagePullBackOff pod:"
    PODS_WITH_ISSUES=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.status.containerStatuses[*].state.waiting.reason=="ImagePullBackOff")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
    
    if [ ! -z "$PODS_WITH_ISSUES" ]; then
        while IFS= read -r line; do
            if [ ! -z "$line" ]; then
                NAMESPACE=$(echo $line | awk '{print $1}')
                POD_NAME=$(echo $line | awk '{print $2}')
                echo "--- $NAMESPACE/$POD_NAME ---"
                diagnose_imagepullbackoff $POD_NAME $NAMESPACE
            fi
        done <<< "$PODS_WITH_ISSUES"
    fi
}

# Функция для проверки registry connectivity
test_registry_connectivity() {
    local IMAGE_NAME=$1
    
    if [ -z "$IMAGE_NAME" ]; then
        echo "Usage: test_registry_connectivity <image-name>"
        return 1
    fi
    
    echo "=== Testing Registry Connectivity for: $IMAGE_NAME ==="
    echo
    
    echo "1. Testing image pull with temporary pod:"
    cat << TEST_POD_EOF > test-image-pull.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-image-pull-$(date +%s)
  namespace: default
spec:
  containers:
  - name: test
    image: $IMAGE_NAME
    command: ['sleep', '10']
  restartPolicy: Never
TEST_POD_EOF
    
    echo "Created test pod configuration: test-image-pull.yaml"
    echo "Run: kubectl apply -f test-image-pull.yaml"
    echo "Then check: kubectl get pods | grep test-image-pull"
    echo
    
    echo "2. Manual registry test commands:"
    cat << REGISTRY_TEST_EOF
# Test with docker (if available)
docker pull $IMAGE_NAME

# Test with crictl (on nodes)
crictl pull $IMAGE_NAME

# Test with skopeo (if available)
skopeo inspect docker://$IMAGE_NAME

REGISTRY_TEST_EOF
    echo
}

# Функция для создания и проверки image pull secrets
manage_image_pull_secrets() {
    echo "=== Managing Image Pull Secrets ==="
    
    echo "1. Current image pull secrets:"
    kubectl get secrets --all-namespaces --field-selector=type=kubernetes.io/dockerconfigjson
    echo
    
    echo "2. Create Docker Registry Secret (example):"
    cat << DOCKER_SECRET_EOF
# Create secret for Docker Hub
kubectl create secret docker-registry dockerhub-secret \\
  --docker-server=https://index.docker.io/v1/ \\
  --docker-username=<username> \\
  --docker-password=<password> \\
  --docker-email=<email> \\
  -n <namespace>

# Create secret for private registry
kubectl create secret docker-registry private-registry-secret \\
  --docker-server=<registry-url> \\
  --docker-username=<username> \\
  --docker-password=<password> \\
  -n <namespace>

# Create secret for HashFoundry registry
kubectl create secret docker-registry hashfoundry-registry \\
  --docker-server=registry.hashfoundry.com \\
  --docker-username=<username> \\
  --docker-password=<token> \\
  -n default

DOCKER_SECRET_EOF
    echo
    
    echo "3. Example secret YAML:"
    cat << SECRET_YAML_EOF > docker-registry-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: hashfoundry-registry-secret
  namespace: default
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
---
# To encode docker config:
# echo '{"auths":{"registry.hashfoundry.com":{"username":"user","password":"pass","auth":"<base64-user:pass>"}}}' | base64 -w 0
SECRET_YAML_EOF
    
    echo "✅ Secret template created: docker-registry-secret.yaml"
    echo
    
    echo "4. Add secret to service account:"
    cat << SA_PATCH_EOF
# Patch service account to include image pull secret
kubectl patch serviceaccount default -n <namespace> -p '{"imagePullSecrets": [{"name": "hashfoundry-registry-secret"}]}'

# Or create new service account with secret
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hashfoundry-sa
  namespace: default
imagePullSecrets:
- name: hashfoundry-registry-secret

SA_PATCH_EOF
    echo
}

# Функция для создания тестовых сценариев
create_test_scenarios() {
    echo "=== Creating Test Scenarios ==="
    
    echo "1. Pod with non-existent image:"
    cat << NONEXISTENT_IMAGE_EOF > test-nonexistent-image.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-nonexistent-image
  namespace: default
  labels:
    test: imagepullbackoff
spec:
  containers:
  - name: app
    image: nonexistent-registry.com/fake-image:latest
    ports:
    - containerPort: 8080
  restartPolicy: Never
NONEXISTENT_IMAGE_EOF
    
    echo "✅ Test pod with non-existent image: test-nonexistent-image.yaml"
    echo
    
    echo "2. Pod with private registry (no secrets):"
    cat << PRIVATE_REGISTRY_EOF > test-private-registry.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-private-registry
  namespace: default
  labels:
    test: imagepullbackoff
spec:
  containers:
  - name: app
    image: registry.hashfoundry.com/private-app:v1.0.0
    ports:
    - containerPort: 8080
  restartPolicy: Never
PRIVATE_REGISTRY_EOF
    
    echo "✅ Test pod with private registry: test-private-registry.yaml"
    echo
    
    echo "3. Pod with wrong tag:"
    cat << WRONG_TAG_EOF > test-wrong-tag.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-wrong-tag
  namespace: default
  labels:
    test: imagepullbackoff
spec:
  containers:
  - name: app
    image: nginx:nonexistent-tag
    ports:
    - containerPort: 80
  restartPolicy: Never
WRONG_TAG_EOF
    
    echo "✅ Test pod with wrong tag: test-wrong-tag.yaml"
    echo
    
    echo "4. Pod with correct image pull secret:"
    cat << CORRECT_SECRET_EOF > test-correct-secret.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-correct-secret
  namespace: default
  labels:
    test: imagepullbackoff
spec:
  containers:
  - name: app
    image: registry.hashfoundry.com/private-app:v1.0.0
    ports:
    - containerPort: 8080
  imagePullSecrets:
  - name: hashfoundry-registry-secret
  restartPolicy: Never
CORRECT_SECRET_EOF
    
    echo "✅ Test pod with correct secret: test-correct-secret.yaml"
    echo
}

# Функция для автоматического исправления ImagePullBackOff
auto_fix_imagepullbackoff() {
    echo "=== Auto-fix ImagePullBackOff Issues ==="
    
    echo "1. Common fixes for ImagePullBackOff:"
    cat << AUTO_FIX_EOF
# Fix 1: Check image name and tag
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'

# Fix 2: Create image pull secret
kubectl create secret docker-registry my-secret \\
  --docker-server=<server> \\
  --docker-username=<username> \\
  --docker-password=<password>

# Fix 3: Add secret to pod
kubectl patch pod <pod-name> -p '{"spec":{"imagePullSecrets":[{"name":"my-secret"}]}}'

# Fix 4: Add secret to service account
kubectl patch serviceaccount default -p '{"imagePullSecrets":[{"name":"my-secret"}]}'

# Fix 5: Test image manually
kubectl run test-image --image=<image-name> --rm -it --restart=Never -- /bin/sh

AUTO_FIX_EOF
    echo
    
    echo "2. Registry-specific solutions:"
    cat << REGISTRY_SOLUTIONS_EOF
# Docker Hub rate limiting
kubectl create secret docker-registry dockerhub-auth \\
  --docker-server=https://index.docker.io/v1/ \\
  --docker-username=<username> \\
  --docker-password=<password>

# AWS ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com

# Google Container Registry
kubectl create secret docker-registry gcr-secret \\
  --docker-server=gcr.io \\
  --docker-username=_json_key \\
  --docker-password="\$(cat key.json)"

# Azure Container Registry
kubectl create secret docker-registry acr-secret \\
  --docker-server=<registry>.azurecr.io \\
  --docker-username=<username> \\
  --docker-password=<password>

REGISTRY_SOLUTIONS_EOF
    echo
}

# Функция для мониторинга ImagePullBackOff
monitor_imagepullbackoff() {
    echo "=== Monitoring ImagePullBackOff Issues ==="
    
    echo "1. Real-time monitoring script:"
    cat << MONITOR_SCRIPT_EOF > monitor-imagepullbackoff.sh
#!/bin/bash

echo "=== ImagePullBackOff Monitor ==="
echo "Press Ctrl+C to stop"
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Pods with ImagePullBackOff:"
    kubectl get pods --all-namespaces | grep -E "(ImagePullBackOff|ErrImagePull)" || echo "No ImagePullBackOff issues"
    echo
    
    echo "Recent image pull events:"
    kubectl get events --all-namespaces --field-selector reason=Failed | grep -i "pull" | tail -5
    echo
    
    sleep 10
done

MONITOR_SCRIPT_EOF
    
    chmod +x monitor-imagepullbackoff.sh
    echo "✅ Monitoring script created: monitor-imagepullbackoff.sh"
    echo
    
    echo "2. Alerting with Prometheus (example):"
    cat << PROMETHEUS_ALERT_EOF > imagepullbackoff-alert.yaml
groups:
- name: imagepullbackoff.rules
  rules:
  - alert: ImagePullBackOff
    expr: kube_pod_container_status_waiting_reason{reason="ImagePullBackOff"} > 0
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} has ImagePullBackOff"
      description: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} container {{ \$labels.container }} has been in ImagePullBackOff state for more than 2 minutes."

PROMETHEUS_ALERT_EOF
    
    echo "✅ Prometheus alert created: imagepullbackoff-alert.yaml"
    echo
}

# Основная функция
main() {
    case "$1" in
        "diagnose")
            diagnose_imagepullbackoff $2 $3
            ;;
        "find")
            find_imagepullbackoff_pods
            ;;
        "test-registry")
            test_registry_connectivity $2
            ;;
        "secrets")
            manage_image_pull_secrets
            ;;
        "test-scenarios")
            create_test_scenarios
            ;;
        "auto-fix")
            auto_fix_imagepullbackoff
            ;;
        "monitor")
            monitor_imagepullbackoff
            ;;
        "all"|"")
            find_imagepullbackoff_pods
            manage_image_pull_secrets
            create_test_scenarios
            auto_fix_imagepullbackoff
            monitor_imagepullbackoff
            ;;
        *)
            echo "Usage: $0 [diagnose|find|test-registry|secrets|test-scenarios|auto-fix|monitor|all] [pod-name] [namespace]"
            echo ""
            echo "ImagePullBackOff Troubleshooting Options:"
            echo "  diagnose <pod> [ns]  - Diagnose specific pod"
            echo "  find                 - Find all ImagePullBackOff pods"
            echo "  test-registry <img>  - Test registry connectivity"
            echo "  secrets              - Manage image pull secrets"
            echo "  test-scenarios       - Create test scenarios"
            echo "  auto-fix             - Auto-fix solutions"
            echo "  monitor              - Monitor ImagePullBackOff issues"
            ;;
    esac
}

main "$@"

EOF

chmod +x imagepullbackoff-troubleshooting-toolkit.sh
./imagepullbackoff-troubleshooting-toolkit.sh all
```

## 🎯 **Пошаговая диагностика ImagePullBackOff:**

### **Шаг 1: Определить проблему**
```bash
# Найти pods с ImagePullBackOff
kubectl get pods --all-namespaces | grep ImagePullBackOff

# Проверить события
kubectl get events --all-namespaces | grep -i "pull"

# Детальная информация о pod
kubectl describe pod <pod-name> -n <namespace>
```

### **Шаг 2: Проверить образ**
```bash
# Получить имя образа
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'

# Проверить доступность образа
docker pull <image-name>

# Проверить теги в registry
curl -s https://registry.hub.docker.com/v2/repositories/<image>/tags/
```

### **Шаг 3: Проверить аутентификацию**
```bash
# Проверить image pull secrets
kubectl get secrets --field-selector=type=kubernetes.io/dockerconfigjson

# Проверить service account
kubectl get serviceaccount default -o yaml

# Проверить секреты в pod
kubectl get pod <pod-name> -o jsonpath='{.spec.imagePullSecrets[*].name}'
```

### **Шаг 4: Создать секреты**
```bash
# Создать Docker registry secret
kubectl create secret docker-registry my-secret \
  --docker-server=<server> \
  --docker-username=<username> \
  --docker-password=<password>

# Добавить секрет к service account
kubectl patch serviceaccount default -p '{"imagePullSecrets":[{"name":"my-secret"}]}'
```

## 🔧 **Частые причины и решения:**

### **1. Неправильное имя образа:**
```bash
# Проблема: nginx:latests (опечатка)
# Решение: nginx:latest
```

### **2. Приватный registry без секретов:**
```bash
# Создать секрет для приватного registry
kubectl create secret docker-registry private-reg \
  --docker-server=registry.company.com \
  --docker-username=user \
  --docker-password=pass
```

### **3. Docker Hub rate limiting:**
```bash
# Создать аутентификацию для Docker Hub
kubectl create secret docker-registry dockerhub-auth \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<password>
```

### **4. Неправильный namespace для секрета:**
```bash
# Секрет должен быть в том же namespace что и pod
kubectl create secret docker-registry my-secret -n <same-namespace>
```

**Правильная диагностика ImagePullBackOff экономит много времени при развертывании!**
