# Substrate Blockchain Helm Chart

Helm chart для развертывания тестового блокчейна на базе Polkadot Substrate в Kubernetes.

## 🎯 Описание

Этот Helm chart создан на основе успешной отладки Docker Compose версии блокчейна и адаптирован для Kubernetes с учетом специфики K8s окружения.

## 📋 Требования

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support в кластере (для persistence)

## 🚀 Быстрый старт

### 1. Установка chart'а

```bash
# Добавить namespace
kubectl create namespace blockchain

# Установить chart
helm install my-blockchain . -n blockchain

# Или с кастомными значениями
helm install my-blockchain . -n blockchain -f values-dev.yaml
```

### 2. Проверка статуса

```bash
# Проверить статус pods
kubectl get pods -n blockchain

# Проверить services
kubectl get svc -n blockchain

# Проверить logs
kubectl logs -f statefulset/my-blockchain-alice -n blockchain
```

### 3. Доступ к RPC

```bash
# Port forward для Alice RPC
kubectl port-forward svc/my-blockchain-alice 9933:9933 -n blockchain

# Port forward для Bob RPC  
kubectl port-forward svc/my-blockchain-bob 9934:9933 -n blockchain

# Тестирование RPC
curl -H "Content-Type: application/json" \
  -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
  http://localhost:9933
```

## ⚙️ Конфигурация

### Основные параметры

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `nodeKeyStrategy` | Стратегия управления node-key | `fixed` |
| `validators.alice.enabled` | Включить Alice validator | `true` |
| `validators.bob.enabled` | Включить Bob validator | `true` |
| `ingress.enabled` | Включить Ingress | `false` |
| `monitoring.enabled` | Включить мониторинг | `false` |

### Node Key стратегии

#### 1. Fixed (для демо/тестов)
```yaml
nodeKeyStrategy: fixed
nodeKeys:
  alice: "0000000000000000000000000000000000000000000000000000000000000001"
  bob: "0000000000000000000000000000000000000000000000000000000000000002"
```

#### 2. Generated (для production)
```yaml
nodeKeyStrategy: generated
# Ключи будут сгенерированы автоматически
```

#### 3. Persistent (для production с сохранением)
```yaml
nodeKeyStrategy: persistent
# Ключи сохраняются в PVC
```

### Сетевая конфигурация

#### Bootnodes
```yaml
validators:
  bob:
    bootnodes:
      enabled: true
      static:
        - peerId: "12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp"
          service: blockchain-alice
          port: 30333
```

#### Services
```yaml
validators:
  alice:
    service:
      type: ClusterIP
      ports:
        p2p: 30333
        rpcHttp: 9933
        rpcWs: 9944
```

### Persistence
```yaml
validators:
  alice:
    persistence:
      enabled: true
      storageClass: "fast-ssd"
      size: 20Gi
      accessMode: ReadWriteOnce
```

### Resources
```yaml
validators:
  alice:
    resources:
      requests:
        memory: "1Gi"
        cpu: "1000m"
      limits:
        memory: "2Gi"
        cpu: "2000m"
```

## 🌍 Примеры конфигураций

### Development Environment
```yaml
# values-dev.yaml
nodeKeyStrategy: fixed
ingress:
  enabled: true
  hosts:
    alice:
      host: blockchain-alice.dev.local
monitoring:
  enabled: false
security:
  networkPolicy:
    enabled: false
```

### Staging Environment
```yaml
# values-staging.yaml
nodeKeyStrategy: persistent
ingress:
  enabled: true
  hosts:
    alice:
      host: blockchain-alice.staging.company.com
monitoring:
  enabled: true
security:
  networkPolicy:
    enabled: true
```

### Production Environment
```yaml
# values-prod.yaml
nodeKeyStrategy: persistent
ingress:
  enabled: true
  hosts:
    alice:
      host: blockchain-alice.company.com
  tls:
    - secretName: blockchain-tls
      hosts:
        - blockchain-alice.company.com
monitoring:
  enabled: true
  prometheus:
    enabled: true
security:
  networkPolicy:
    enabled: true
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

## 🔧 Операции

### Обновление chart'а
```bash
# Обновить с новыми значениями
helm upgrade my-blockchain . -n blockchain -f values-prod.yaml

# Откатить к предыдущей версии
helm rollback my-blockchain 1 -n blockchain
```

### Масштабирование
```bash
# Увеличить количество validator'ов
helm upgrade my-blockchain . -n blockchain \
  --set validators.alice.replicas=2 \
  --set validators.bob.replicas=2
```

### Мониторинг
```bash
# Включить мониторинг
helm upgrade my-blockchain . -n blockchain \
  --set monitoring.enabled=true \
  --set monitoring.prometheus.enabled=true
```

### Backup данных
```bash
# Создать snapshot PVC
kubectl get pvc -n blockchain
# Использовать volume snapshot или backup tool
```

## 🔍 Troubleshooting

### Проблемы с подключением нод

1. **Проверить bootnodes конфигурацию**
```bash
kubectl logs statefulset/my-blockchain-bob -n blockchain | grep bootnode
```

2. **Проверить DNS resolution**
```bash
kubectl exec -it my-blockchain-alice-0 -n blockchain -- nslookup my-blockchain-alice
```

3. **Проверить P2P connectivity**
```bash
kubectl exec -it my-blockchain-bob-0 -n blockchain -- netstat -an | grep 30333
```

### Проблемы с RPC

1. **Проверить health endpoint**
```bash
kubectl exec -it my-blockchain-alice-0 -n blockchain -- \
  curl -s http://localhost:9933/health
```

2. **Проверить service endpoints**
```bash
kubectl get endpoints -n blockchain
```

### Проблемы с persistence

1. **Проверить PVC статус**
```bash
kubectl get pvc -n blockchain
kubectl describe pvc blockchain-data-my-blockchain-alice-0 -n blockchain
```

2. **Проверить storage class**
```bash
kubectl get storageclass
```

## 🔒 Безопасность

### Network Policies
```yaml
security:
  networkPolicy:
    enabled: true
    allowP2P: true
    allowRPCFrom:
      - namespaceSelector:
          matchLabels:
            name: monitoring
```

### Pod Security Context
```yaml
security:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: false
```

## 📊 Мониторинг

### Prometheus метрики
```yaml
monitoring:
  enabled: true
  prometheus:
    enabled: true
    port: 9615
    path: /metrics
```

### Grafana дашборды
```yaml
monitoring:
  grafana:
    enabled: true
    dashboards:
      enabled: true
```

## 🔄 CI/CD Integration

### GitOps с ArgoCD
```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: substrate-blockchain
spec:
  source:
    repoURL: https://github.com/company/blockchain-charts
    path: substrate-blockchain
    targetRevision: HEAD
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: blockchain
```

### Helm в CI/CD pipeline
```bash
# В CI/CD pipeline
helm lint .
helm template . --values values-prod.yaml > rendered.yaml
helm upgrade --install my-blockchain . -n blockchain -f values-prod.yaml
```

## 📚 Дополнительные ресурсы

- [Substrate Documentation](https://docs.substrate.io/)
- [Polkadot Documentation](https://wiki.polkadot.network/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

## 🤝 Поддержка

Для вопросов и поддержки:
- GitHub Issues: [https://github.com/hashfoundry/infra/issues](https://github.com/hashfoundry/infra/issues)
- Email: dev@hashfoundry.com

## 📄 Лицензия

MIT License - см. [LICENSE](LICENSE) файл для деталей.
