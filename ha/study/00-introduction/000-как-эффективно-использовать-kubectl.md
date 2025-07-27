# 000. Как эффективно использовать kubectl

## 🎯 **Как эффективно использовать kubectl**

**kubectl** - основной инструмент для взаимодействия с Kubernetes кластером. Знание продвинутых техник и команд значительно повышает продуктивность работы.

## 🛠️ **Основные категории команд:**

### **1. Resource Management:**
- **get** - получение информации о ресурсах
- **describe** - детальная информация
- **create/apply** - создание ресурсов
- **delete** - удаление ресурсов

### **2. Debugging & Troubleshooting:**
- **logs** - просмотр логов
- **exec** - выполнение команд в контейнерах
- **port-forward** - проброс портов
- **top** - мониторинг ресурсов

### **3. Advanced Operations:**
- **patch** - частичное обновление
- **scale** - масштабирование
- **rollout** - управление развертываниями

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive kubectl toolkit
cat << 'EOF' > kubectl-mastery-toolkit.sh
#!/bin/bash

echo "=== Kubectl Mastery Toolkit ==="
echo "Advanced kubectl techniques for HashFoundry HA cluster"
echo

# Функция для демонстрации основных команд
demo_basic_commands() {
    echo "=== Basic kubectl Commands ==="
    
    echo "1. Resource Overview:"
    echo "kubectl get all --all-namespaces"
    kubectl get all --all-namespaces | head -10
    echo
    
    echo "2. Detailed Resource Information:"
    echo "kubectl describe nodes"
    kubectl describe nodes | head -20
    echo
    
    echo "3. Resource with Custom Columns:"
    echo "kubectl get pods -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName'"
    kubectl get pods --all-namespaces -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName' | head -10
    echo
    
    echo "4. JSON Path Queries:"
    echo "kubectl get nodes -o jsonpath='{.items[*].metadata.name}'"
    kubectl get nodes -o jsonpath='{.items[*].metadata.name}'
    echo
    echo
}

# Функция для демонстрации продвинутых селекторов
demo_advanced_selectors() {
    echo "=== Advanced Selectors ==="
    
    echo "1. Label Selectors:"
    echo "kubectl get pods -l app=nginx"
    kubectl get pods --all-namespaces -l app.kubernetes.io/name=nginx-ingress | head -5
    echo
    
    echo "2. Field Selectors:"
    echo "kubectl get pods --field-selector=status.phase=Running"
    kubectl get pods --all-namespaces --field-selector=status.phase=Running | head -5
    echo
    
    echo "3. Multiple Selectors:"
    echo "kubectl get pods -l 'app in (nginx,apache),tier!=frontend'"
    kubectl get pods --all-namespaces -l 'app.kubernetes.io/component in (controller,webhook)' | head -5
    echo
    
    echo "4. Exclude by Labels:"
    echo "kubectl get pods -l 'app!=system'"
    kubectl get pods --all-namespaces -l 'app.kubernetes.io/name!=coredns' | head -5
    echo
}

# Функция для демонстрации output форматов
demo_output_formats() {
    echo "=== Output Formats ==="
    
    echo "1. YAML Output:"
    echo "kubectl get pod <pod-name> -o yaml"
    echo
    
    echo "2. JSON Output with jq:"
    echo "kubectl get nodes -o json | jq '.items[].metadata.name'"
    kubectl get nodes -o json | jq '.items[].metadata.name' 2>/dev/null || echo "jq not available"
    echo
    
    echo "3. Custom Columns:"
    echo "kubectl get pods -o custom-columns='POD:.metadata.name,STATUS:.status.phase,IP:.status.podIP'"
    kubectl get pods --all-namespaces -o custom-columns='POD:.metadata.name,STATUS:.status.phase,IP:.status.podIP' | head -5
    echo
    
    echo "4. Wide Output:"
    echo "kubectl get pods -o wide"
    kubectl get pods --all-namespaces -o wide | head -5
    echo
}

# Функция для демонстрации debugging команд
demo_debugging_commands() {
    echo "=== Debugging Commands ==="
    
    echo "1. Pod Logs:"
    echo "kubectl logs <pod-name> --tail=50 --follow"
    echo "kubectl logs -l app=nginx --tail=10"
    echo
    
    echo "2. Previous Container Logs:"
    echo "kubectl logs <pod-name> --previous"
    echo
    
    echo "3. Execute Commands in Pod:"
    echo "kubectl exec -it <pod-name> -- /bin/bash"
    echo "kubectl exec <pod-name> -- ps aux"
    echo
    
    echo "4. Port Forwarding:"
    echo "kubectl port-forward pod/<pod-name> 8080:80"
    echo "kubectl port-forward service/<service-name> 8080:80"
    echo
    
    echo "5. Resource Usage:"
    echo "kubectl top nodes"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo "kubectl top pods --all-namespaces"
    kubectl top pods --all-namespaces 2>/dev/null | head -5 || echo "Metrics server not available"
    echo
}

# Функция для демонстрации patch операций
demo_patch_operations() {
    echo "=== Patch Operations ==="
    
    echo "1. Strategic Merge Patch:"
    cat << PATCH_EXAMPLE_EOF
kubectl patch deployment nginx-deployment -p '{"spec":{"replicas":5}}'
PATCH_EXAMPLE_EOF
    echo
    
    echo "2. JSON Patch:"
    cat << JSON_PATCH_EOF
kubectl patch pod nginx-pod --type='json' -p='[{"op": "replace", "path": "/spec/containers/0/image", "value":"nginx:1.21"}]'
JSON_PATCH_EOF
    echo
    
    echo "3. Merge Patch:"
    cat << MERGE_PATCH_EOF
kubectl patch service nginx-service --type='merge' -p='{"spec":{"ports":[{"port":8080,"targetPort":80}]}}'
MERGE_PATCH_EOF
    echo
    
    echo "4. Add Labels:"
    cat << LABEL_PATCH_EOF
kubectl patch pod nginx-pod -p '{"metadata":{"labels":{"environment":"production"}}}'
LABEL_PATCH_EOF
    echo
}

# Функция для демонстрации context и namespace управления
demo_context_management() {
    echo "=== Context and Namespace Management ==="
    
    echo "1. Current Context:"
    echo "kubectl config current-context"
    kubectl config current-context
    echo
    
    echo "2. Available Contexts:"
    echo "kubectl config get-contexts"
    kubectl config get-contexts
    echo
    
    echo "3. Switch Context:"
    echo "kubectl config use-context <context-name>"
    echo
    
    echo "4. Set Default Namespace:"
    echo "kubectl config set-context --current --namespace=<namespace>"
    echo
    
    echo "5. Create Namespace:"
    echo "kubectl create namespace development"
    echo
}

# Функция для создания полезных алиасов
create_kubectl_aliases() {
    echo "=== Creating Kubectl Aliases ==="
    
    cat << ALIASES_EOF > kubectl-aliases.sh
#!/bin/bash

# Kubectl Aliases for HashFoundry HA cluster

# Basic aliases
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias ka='kubectl apply'
alias kc='kubectl create'

# Pod operations
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods --all-namespaces'
alias kgpw='kubectl get pods -o wide'
alias kdp='kubectl describe pod'
alias kdelp='kubectl delete pod'

# Service operations
alias kgs='kubectl get services'
alias kgsa='kubectl get services --all-namespaces'
alias kds='kubectl describe service'
alias kdels='kubectl delete service'

# Deployment operations
alias kgd='kubectl get deployments'
alias kgda='kubectl get deployments --all-namespaces'
alias kdd='kubectl describe deployment'
alias kdeld='kubectl delete deployment'
alias ksd='kubectl scale deployment'

# Node operations
alias kgn='kubectl get nodes'
alias kdn='kubectl describe node'
alias ktn='kubectl top nodes'

# Namespace operations
alias kgns='kubectl get namespaces'
alias kcns='kubectl create namespace'
alias kdelns='kubectl delete namespace'

# Logs and debugging
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias klt='kubectl logs --tail=50'
alias ke='kubectl exec -it'
alias kpf='kubectl port-forward'

# Resource monitoring
alias ktp='kubectl top pods'
alias ktpa='kubectl top pods --all-namespaces'

# Context and config
alias kcc='kubectl config current-context'
alias kgc='kubectl config get-contexts'
alias kuc='kubectl config use-context'

# Advanced operations
alias kgall='kubectl get all --all-namespaces'
alias kwait='kubectl wait --for=condition=ready'
alias kwatch='kubectl get pods -w'

# Custom functions
kexec() {
    kubectl exec -it \$1 -- /bin/bash
}

klogs() {
    kubectl logs \$1 --tail=100 -f
}

kdebug() {
    kubectl run debug-\$RANDOM --image=busybox:1.28 --rm -it --restart=Never -- sh
}

kforward() {
    kubectl port-forward \$1 \$2:\$3
}

# Export functions
export -f kexec klogs kdebug kforward

echo "Kubectl aliases loaded! Use 'k' instead of 'kubectl'"
echo "Examples:"
echo "  kgp          # kubectl get pods"
echo "  kgpa         # kubectl get pods --all-namespaces"
echo "  kl pod-name  # kubectl logs pod-name"
echo "  ke pod-name  # kubectl exec -it pod-name -- /bin/bash"

ALIASES_EOF
    
    chmod +x kubectl-aliases.sh
    echo "✅ Kubectl aliases created: kubectl-aliases.sh"
    echo "Source it with: source kubectl-aliases.sh"
    echo
}

# Функция для создания полезных скриптов
create_kubectl_scripts() {
    echo "=== Creating Kubectl Utility Scripts ==="
    
    # Script for pod troubleshooting
    cat << TROUBLESHOOT_EOF > kubectl-troubleshoot-pod.sh
#!/bin/bash

POD_NAME=\$1
NAMESPACE=\${2:-default}

if [ -z "\$POD_NAME" ]; then
    echo "Usage: \$0 <pod-name> [namespace]"
    exit 1
fi

echo "=== Troubleshooting Pod: \$NAMESPACE/\$POD_NAME ==="
echo

echo "1. Pod Status:"
kubectl get pod \$POD_NAME -n \$NAMESPACE -o wide
echo

echo "2. Pod Events:"
kubectl get events -n \$NAMESPACE --field-selector involvedObject.name=\$POD_NAME --sort-by='.lastTimestamp'
echo

echo "3. Pod Description:"
kubectl describe pod \$POD_NAME -n \$NAMESPACE
echo

echo "4. Pod Logs (last 50 lines):"
kubectl logs \$POD_NAME -n \$NAMESPACE --tail=50
echo

echo "5. Previous Logs (if available):"
kubectl logs \$POD_NAME -n \$NAMESPACE --previous --tail=20 2>/dev/null || echo "No previous logs"

TROUBLESHOOT_EOF
    
    chmod +x kubectl-troubleshoot-pod.sh
    
    # Script for resource monitoring
    cat << MONITOR_EOF > kubectl-monitor-resources.sh
#!/bin/bash

echo "=== Kubernetes Resource Monitor ==="
echo

while true; do
    clear
    echo "=== \$(date) ==="
    echo
    
    echo "Nodes:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "Top CPU Pods:"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
    
    echo "Top Memory Pods:"
    kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
    
    echo "Problematic Pods:"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
    echo
    
    sleep 10
done

MONITOR_EOF
    
    chmod +x kubectl-monitor-resources.sh
    
    # Script for quick deployment
    cat << DEPLOY_EOF > kubectl-quick-deploy.sh
#!/bin/bash

APP_NAME=\$1
IMAGE=\$2
REPLICAS=\${3:-3}
NAMESPACE=\${4:-default}

if [ -z "\$APP_NAME" ] || [ -z "\$IMAGE" ]; then
    echo "Usage: \$0 <app-name> <image> [replicas] [namespace]"
    echo "Example: \$0 my-app nginx:1.21 3 default"
    exit 1
fi

echo "Deploying \$APP_NAME with image \$IMAGE..."

# Create deployment
kubectl create deployment \$APP_NAME --image=\$IMAGE --replicas=\$REPLICAS -n \$NAMESPACE

# Expose service
kubectl expose deployment \$APP_NAME --port=80 --target-port=8080 -n \$NAMESPACE

# Wait for rollout
kubectl rollout status deployment/\$APP_NAME -n \$NAMESPACE

echo "Deployment completed!"
echo "Check status: kubectl get pods -l app=\$APP_NAME -n \$NAMESPACE"

DEPLOY_EOF
    
    chmod +x kubectl-quick-deploy.sh
    
    echo "✅ Utility scripts created:"
    echo "- kubectl-troubleshoot-pod.sh"
    echo "- kubectl-monitor-resources.sh"
    echo "- kubectl-quick-deploy.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "basic")
            demo_basic_commands
            ;;
        "selectors")
            demo_advanced_selectors
            ;;
        "output")
            demo_output_formats
            ;;
        "debug")
            demo_debugging_commands
            ;;
        "patch")
            demo_patch_operations
            ;;
        "context")
            demo_context_management
            ;;
        "aliases")
            create_kubectl_aliases
            ;;
        "scripts")
            create_kubectl_scripts
            ;;
        "all"|"")
            demo_basic_commands
            demo_advanced_selectors
            demo_output_formats
            demo_debugging_commands
            demo_patch_operations
            demo_context_management
            create_kubectl_aliases
            create_kubectl_scripts
            ;;
        *)
            echo "Usage: $0 [basic|selectors|output|debug|patch|context|aliases|scripts|all]"
            echo ""
            echo "kubectl Mastery Topics:"
            echo "  basic     - Basic kubectl commands"
            echo "  selectors - Advanced selectors"
            echo "  output    - Output formats"
            echo "  debug     - Debugging commands"
            echo "  patch     - Patch operations"
            echo "  context   - Context management"
            echo "  aliases   - Create useful aliases"
            echo "  scripts   - Create utility scripts"
            ;;
    esac
}

main "$@"

EOF

chmod +x kubectl-mastery-toolkit.sh
./kubectl-mastery-toolkit.sh all
```

## 🎯 **Практические команды kubectl:**

### **Основные операции:**
```bash
# Получить все ресурсы
kubectl get all --all-namespaces

# Детальная информация
kubectl describe pod <pod-name>

# Применить конфигурацию
kubectl apply -f deployment.yaml
```

### **Продвинутые селекторы:**
```bash
# По меткам
kubectl get pods -l app=nginx,tier=frontend

# По полям
kubectl get pods --field-selector=status.phase=Running

# Исключение
kubectl get pods -l 'app!=system'
```

### **Debugging:**
```bash
# Логи с follow
kubectl logs -f <pod-name>

# Выполнение команд
kubectl exec -it <pod-name> -- /bin/bash

# Проброс портов
kubectl port-forward pod/<pod-name> 8080:80
```

### **Мониторинг:**
```bash
# Использование ресурсов
kubectl top nodes
kubectl top pods --all-namespaces

# Наблюдение за изменениями
kubectl get pods -w
```

**Эффективное использование kubectl значительно повышает продуктивность работы с Kubernetes!**
