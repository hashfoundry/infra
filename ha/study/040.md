# 40. Объясните сетевую модель Kubernetes

## 🎯 **Сетевая модель Kubernetes**

**Сетевая модель Kubernetes** определяет, как Pod'ы, Service'ы и внешние клиенты взаимодействуют друг с другом в кластере. Она основана на плоской сетевой архитектуре, где каждый Pod получает уникальный IP адрес и может напрямую общаться с другими Pod'ами.

## 🏗️ **Основные принципы сетевой модели:**

### **1. Фундаментальные требования:**
- Каждый Pod имеет уникальный IP адрес
- Pod'ы могут общаться друг с другом без NAT
- Агенты на Node'ах могут общаться со всеми Pod'ами
- Pod'ы в host network могут общаться со всеми Pod'ами

### **2. Сетевые компоненты:**
- **Pod Network**: сеть для Pod'ов
- **Service Network**: виртуальная сеть для Service'ов
- **Node Network**: физическая сеть Node'ов
- **Cluster DNS**: внутренний DNS для service discovery

### **3. CNI (Container Network Interface):**
- Стандартный интерфейс для сетевых плагинов
- Управление IP адресацией
- Настройка сетевых интерфейсов
- Реализация Network Policies

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ сетевой архитектуры кластера:**
```bash
# Проверить информацию о Node'ах и их сетевых интерфейсах
kubectl get nodes -o wide
kubectl describe nodes

# Проверить Pod CIDR для каждого Node'а
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# Проверить CNI плагин
kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium)"
kubectl describe daemonset -n kube-system | grep -i cni

# Проверить сетевые настройки кластера
kubectl cluster-info
kubectl get services -n kube-system
```

### **2. Исследование Pod сетей:**
```bash
# Создать тестовые Pod'ы для анализа сети
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: network-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: network-test-app
  namespace: network-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: network-test
  template:
    metadata:
      labels:
        app: network-test
    spec:
      containers:
      - name: netshoot
        image: nicolaka/netshoot
        command: ["sleep", "3600"]
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: network-test-service
  namespace: network-test
spec:
  selector:
    app: network-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Получить информацию о Pod'ах и их IP адресах
kubectl get pods -n network-test -o wide
kubectl describe pods -n network-test

# Проверить сетевые интерфейсы внутри Pod'а
POD_NAME=$(kubectl get pods -n network-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n network-test $POD_NAME -- ip addr show
kubectl exec -n network-test $POD_NAME -- ip route show
kubectl exec -n network-test $POD_NAME -- cat /etc/resolv.conf

# Проверить connectivity между Pod'ами
POD1=$(kubectl get pods -n network-test -o jsonpath='{.items[0].metadata.name}')
POD2=$(kubectl get pods -n network-test -o jsonpath='{.items[1].metadata.name}')
POD2_IP=$(kubectl get pod -n network-test $POD2 -o jsonpath='{.status.podIP}')

kubectl exec -n network-test $POD1 -- ping -c 3 $POD2_IP
kubectl exec -n network-test $POD1 -- traceroute $POD2_IP
```

### **3. Service Discovery и DNS:**
```bash
# Проверить CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl describe service -n kube-system kube-dns

# Тестирование DNS resolution
kubectl exec -n network-test $POD_NAME -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -n network-test $POD_NAME -- nslookup network-test-service.network-test.svc.cluster.local
kubectl exec -n network-test $POD_NAME -- dig +short network-test-service.network-test.svc.cluster.local

# Проверить DNS конфигурацию
kubectl exec -n network-test $POD_NAME -- cat /etc/resolv.conf
kubectl get configmap -n kube-system coredns -o yaml

# Тестирование различных DNS записей
kubectl exec -n network-test $POD_NAME -- nslookup kubernetes
kubectl exec -n network-test $POD_NAME -- nslookup kubernetes.default
kubectl exec -n network-test $POD_NAME -- nslookup kubernetes.default.svc
kubectl exec -n network-test $POD_NAME -- nslookup kubernetes.default.svc.cluster.local
```

### **4. Service сети и kube-proxy:**
```bash
# Проверить kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl describe daemonset -n kube-system kube-proxy

# Проверить Service CIDR
kubectl cluster-info dump | grep -i service-cluster-ip-range

# Создать Service для анализа
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: test-clusterip
  namespace: network-test
spec:
  selector:
    app: network-test
  ports:
  - port: 8080
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: test-nodeport
  namespace: network-test
spec:
  selector:
    app: network-test
  ports:
  - port: 8080
    targetPort: 80
    nodePort: 30080
  type: NodePort
EOF

# Проверить Service endpoints
kubectl get services -n network-test
kubectl get endpoints -n network-test
kubectl describe service -n network-test test-clusterip

# Тестирование Service connectivity
SERVICE_IP=$(kubectl get service -n network-test test-clusterip -o jsonpath='{.spec.clusterIP}')
kubectl exec -n network-test $POD_NAME -- curl -s --connect-timeout 5 $SERVICE_IP:8080

# Проверить iptables правила (если доступ к Node'ам)
# kubectl get nodes -o wide
# ssh user@node-ip "sudo iptables -t nat -L | grep test-clusterip"
```

## 🔧 **Детальный анализ сетевых компонентов:**

### **1. Pod-to-Pod коммуникация:**
```bash
# Создать Pod'ы на разных Node'ах для тестирования
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-node1
  namespace: network-test
spec:
  nodeSelector:
    kubernetes.io/hostname: $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-node2
  namespace: network-test
spec:
  nodeSelector:
    kubernetes.io/hostname: $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}')
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
EOF

# Получить IP адреса Pod'ов
POD1_IP=$(kubectl get pod -n network-test pod-node1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod -n network-test pod-node2 -o jsonpath='{.status.podIP}')

echo "Pod1 IP: $POD1_IP"
echo "Pod2 IP: $POD2_IP"

# Тестирование межузловой коммуникации
kubectl exec -n network-test pod-node1 -- ping -c 3 $POD2_IP
kubectl exec -n network-test pod-node1 -- traceroute $POD2_IP

# Проверить маршрутизацию
kubectl exec -n network-test pod-node1 -- ip route show
kubectl exec -n network-test pod-node1 -- ip route get $POD2_IP
```

### **2. Network Namespaces и изоляция:**
```bash
# Создать Pod'ы в разных namespace'ах
kubectl create namespace network-test-2

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: isolated-pod
  namespace: network-test-2
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Service
metadata:
  name: isolated-service
  namespace: network-test-2
spec:
  selector:
    app: isolated
  ports:
  - port: 80
    targetPort: 80
EOF

# Тестирование cross-namespace коммуникации
ISOLATED_POD_IP=$(kubectl get pod -n network-test-2 isolated-pod -o jsonpath='{.status.podIP}')

kubectl exec -n network-test $POD_NAME -- ping -c 3 $ISOLATED_POD_IP
kubectl exec -n network-test $POD_NAME -- nslookup isolated-service.network-test-2.svc.cluster.local

# Проверить DNS поиск в разных namespace'ах
kubectl exec -n network-test $POD_NAME -- nslookup isolated-service
kubectl exec -n network-test $POD_NAME -- nslookup isolated-service.network-test-2
```

### **3. Host Network и privileged Pod'ы:**
```bash
# Создать Pod с host network
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: host-network-pod
  namespace: network-test
spec:
  hostNetwork: true
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
EOF

# Сравнить сетевые интерфейсы
kubectl exec -n network-test host-network-pod -- ip addr show
kubectl exec -n network-test $POD_NAME -- ip addr show

# Проверить доступ к Node сети
kubectl exec -n network-test host-network-pod -- netstat -tuln
kubectl exec -n network-test host-network-pod -- ss -tuln
```

## 🏭 **Production сетевые конфигурации:**

### **1. Multi-zone networking:**
```bash
# Проверить зоны доступности Node'ов
kubectl get nodes --show-labels | grep zone
kubectl get nodes -o custom-columns=NAME:.metadata.name,ZONE:.metadata.labels.'topology\.kubernetes\.io/zone'

# Создать Pod'ы с zone affinity
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zone-aware-app
  namespace: network-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: zone-aware
  template:
    metadata:
      labels:
        app: zone-aware
    spec:
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
                  - zone-aware
              topologyKey: topology.kubernetes.io/zone
      containers:
      - name: app
        image: nginx
        ports:
        - containerPort: 80
EOF

# Проверить распределение по зонам
kubectl get pods -n network-test -l app=zone-aware -o wide
```

### **2. Network performance тестирование:**
```bash
# Создать iperf3 сервер и клиент
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: iperf3-server
  namespace: network-test
spec:
  containers:
  - name: iperf3
    image: networkstatic/iperf3
    command: ["iperf3", "-s"]
    ports:
    - containerPort: 5201
---
apiVersion: v1
kind: Service
metadata:
  name: iperf3-service
  namespace: network-test
spec:
  selector:
    app: iperf3-server
  ports:
  - port: 5201
    targetPort: 5201
---
apiVersion: v1
kind: Pod
metadata:
  name: iperf3-client
  namespace: network-test
spec:
  containers:
  - name: iperf3
    image: networkstatic/iperf3
    command: ["sleep", "3600"]
EOF

# Дождаться запуска Pod'ов
kubectl wait --for=condition=Ready pod/iperf3-server -n network-test --timeout=60s
kubectl wait --for=condition=Ready pod/iperf3-client -n network-test --timeout=60s

# Запустить тест производительности сети
IPERF_SERVER_IP=$(kubectl get pod -n network-test iperf3-server -o jsonpath='{.status.podIP}')
kubectl exec -n network-test iperf3-client -- iperf3 -c $IPERF_SERVER_IP -t 10

# Тест через Service
kubectl exec -n network-test iperf3-client -- iperf3 -c iperf3-service.network-test.svc.cluster.local -t 10
```

### **3. Network troubleshooting tools:**
```bash
# Создать comprehensive debug Pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-debug
  namespace: network-test
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "NET_RAW"]
EOF

# Network diagnostic команды
kubectl exec -n network-test network-debug -- ss -tuln
kubectl exec -n network-test network-debug -- netstat -rn
kubectl exec -n network-test network-debug -- arp -a

# DNS troubleshooting
kubectl exec -n network-test network-debug -- dig @10.96.0.10 kubernetes.default.svc.cluster.local
kubectl exec -n network-test network-debug -- nslookup kubernetes.default.svc.cluster.local 10.96.0.10

# Network connectivity matrix
for pod in $(kubectl get pods -n network-test -o jsonpath='{.items[*].metadata.name}'); do
  echo "Testing from $pod:"
  kubectl exec -n network-test $pod -- ping -c 1 8.8.8.8 2>/dev/null && echo "  Internet: OK" || echo "  Internet: FAIL"
  kubectl exec -n network-test $pod -- nslookup kubernetes.default 2>/dev/null && echo "  DNS: OK" || echo "  DNS: FAIL"
done
```

## 🚨 **Troubleshooting сетевых проблем:**

### **1. Диагностика CNI проблем:**
```bash
# Проверить статус CNI плагина
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system -l k8s-app=calico-node --tail=50

# Проверить CNI конфигурацию
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l k8s-app=calico-node -o jsonpath='{.items[0].metadata.name}') -- cat /etc/cni/net.d/10-calico.conflist

# Проверить IP pool'ы (для Calico)
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l k8s-app=calico-node -o jsonpath='{.items[0].metadata.name}') -- calicoctl get ippool -o wide
```

### **2. Service discovery проблемы:**
```bash
# Проверить CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Проверить DNS конфигурацию
kubectl get configmap -n kube-system coredns -o yaml

# Тестирование DNS resolution
kubectl exec -n network-test $POD_NAME -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -n network-test $POD_NAME -- dig +trace kubernetes.default.svc.cluster.local
```

### **3. kube-proxy диагностика:**
```bash
# Проверить kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=50

# Проверить Service endpoints
kubectl get endpoints -A
kubectl describe endpoints -n network-test test-clusterip

# Проверить iptables правила (требует доступа к Node'ам)
# kubectl debug node/node-name -it --image=nicolaka/netshoot
# iptables -t nat -L | grep KUBE
```

## 🎯 **Best Practices для сетевой архитектуры:**

### **1. Планирование сети:**
- Правильное планирование CIDR блоков
- Избегание конфликтов IP адресов
- Резервирование адресного пространства
- Документирование сетевой топологии

### **2. Производительность:**
- Оптимизация MTU размеров
- Использование node-local DNS кэширования
- Минимизация network hops
- Мониторинг сетевой латентности

### **3. Безопасность:**
- Реализация Network Policies
- Сегментация сетевого трафика
- Шифрование inter-pod коммуникации
- Регулярный аудит сетевых правил

### **4. Мониторинг:**
- Метрики сетевого трафика
- Мониторинг DNS resolution времени
- Алерты на сетевые сбои
- Capacity planning для сетевых ресурсов

## 🧹 **Очистка тестовых ресурсов:**
```bash
# Удалить все тестовые ресурсы
kubectl delete namespace network-test network-test-2
```

## 📋 **Сводка сетевой модели Kubernetes:**

### **Ключевые компоненты:**
1. **Pod Network**: Каждый Pod получает уникальный IP
2. **Service Network**: Виртуальные IP для Service'ов
3. **CNI**: Плагины для управления сетью
4. **kube-proxy**: Реализация Service абстракции
5. **CoreDNS**: Service discovery через DNS

### **Типы сетевого трафика:**
- **Pod-to-Pod**: Прямая коммуникация между Pod'ами
- **Pod-to-Service**: Через Service абстракцию
- **External-to-Service**: Внешний доступ через Ingress/LoadBalancer
- **Pod-to-External**: Исходящий трафик из кластера

**Сетевая модель Kubernetes обеспечивает простую, масштабируемую и безопасную коммуникацию между всеми компонентами кластера!**
