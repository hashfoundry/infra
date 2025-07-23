# HashFoundry Blockchain - High Level Design Document

## 📋 **Обзор проекта**

Реализация простого блокчейна на базе Polkadot Substrate с интеграцией в существующую HA инфраструктуру HashFoundry. Цель: создать минимальный блокчейн с возможностью переводов между Alice и Bob аккаунтами.

## 🎯 **Требования**

### **Функциональные требования:**
- ✅ **2 validator ноды** для консенсуса
- ✅ **Переводы между Alice и Bob** - единственная операция
- ✅ **CLI инструменты** для взаимодействия с блокчейном
- ✅ **RPC endpoints** для внешнего доступа

### **Нефункциональные требования:**
- ✅ **Высокая доступность** - использование HA кластера
- ✅ **Мониторинг** - интеграция с Prometheus/Grafana
- ✅ **GitOps** - управление через ArgoCD
- ✅ **Persistent storage** - сохранение данных блокчейна

## 🏗️ **Архитектура системы**

### **Общая архитектура:**
```
┌─────────────────────────────────────────────────────────────┐
│               Существующая HA инфраструктура                 │
├─────────────────────────────────────────────────────────────┤
│  NGINX Ingress Controller                                   │
│  ├── blockchain-rpc-1.hashfoundry.local                    │
│  └── blockchain-rpc-2.hashfoundry.local                    │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes Namespace: blockchain                           │
│  ├── substrate-validator-1 (Alice Authority)               │
│  ├── substrate-validator-2 (Bob Authority)                 │
│  └── blockchain-metrics-exporter                           │
├─────────────────────────────────────────────────────────────┤
│  ArgoCD GitOps Management                                   │
│  └── blockchain Application (automated sync)               │
├─────────────────────────────────────────────────────────────┤
│  Persistent Storage                                         │
│  ├── blockchain-data-1 (Validator 1 database)             │
│  └── blockchain-data-2 (Validator 2 database)             │
├─────────────────────────────────────────────────────────────┤
│  Мониторинг (Prometheus + Grafana)                         │
│  ├── Block production metrics                               │
│  ├── Transaction throughput                                 │
│  ├── Validator connectivity                                 │
│  └── Alice/Bob account balances                            │
└─────────────────────────────────────────────────────────────┘
```

### **Компонентная диаграмма:**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  CLI Tools      │────│  NGINX Ingress  │────│  RPC Endpoints  │
│  (polkadot-js)  │    │  Load Balancer  │    │  (HTTP/WS)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Substrate RPC 1 │◄───┤  Load Balancer  ├───►│ Substrate RPC 2 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                                              │
         ▼                                              ▼
┌─────────────────┐                          ┌─────────────────┐
│ Validator Node 1│◄────── P2P Network ─────►│ Validator Node 2│
│     (Alice)     │                          │      (Bob)      │
└─────────────────┘                          └─────────────────┘
         │                                              │
         ▼                                              ▼
┌─────────────────┐                          ┌─────────────────┐
│ Persistent Vol 1│                          │ Persistent Vol 2│
└─────────────────┘                          └─────────────────┘
```

## 🔧 **Техническая спецификация**

### **Blockchain Technology Stack:**

#### **Runtime Configuration:**
- **Framework**: Substrate (Polkadot SDK)
- **Consensus**: Aura (Authority Round)
- **Finality**: GRANDPA 
- **Runtime Modules**: System, Balances, Aura, GRANDPA
- **Block Time**: 6 seconds
- **Era Duration**: 24 hours

#### **Network Configuration:**
```json
{
  "name": "HashFoundry Local Testnet",
  "id": "hashfoundry_local",
  "chainType": "Local",
  "protocolId": "hf",
  "properties": {
    "tokenSymbol": "HF",
    "tokenDecimals": 12,
    "ss58Format": 42
  }
}
```

#### **Genesis Block Configuration:**
```json
{
  "genesis": {
    "runtime": {
      "balances": {
        "balances": [
          ["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1000000000000000],
          ["5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty", 1000000000000000]
        ]
      },
      "aura": {
        "authorities": [
          "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
          "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
        ]
      },
      "grandpa": {
        "authorities": [
          ["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1],
          ["5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty", 1]
        ]
      }
    }
  }
}
```

### **Kubernetes Deployment Specification:**

#### **Validator Nodes StatefulSet:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: substrate-validator-1
  namespace: blockchain
spec:
  serviceName: substrate-validator-1
  replicas: 1
  template:
    metadata:
      labels:
        app: substrate-validator-1
        role: validator
    spec:
      containers:
      - name: substrate
        image: parity/substrate:latest
        command:
        - substrate
        - --chain=/chainspec/genesis.json
        - --validator
        - --alice
        - --base-path=/data
        - --rpc-external
        - --ws-external
        - --rpc-cors=all
        - --unsafe-rpc-external
        - --unsafe-ws-external
        - --prometheus-external
        - --telemetry-url=ws://telemetry:8001/submit 0
        ports:
        - name: rpc-http
          containerPort: 9933
        - name: rpc-ws  
          containerPort: 9944
        - name: p2p
          containerPort: 30333
        - name: prometheus
          containerPort: 9615
        resources:
          requests:
            memory: 1Gi
            cpu: 500m
          limits:
            memory: 4Gi
            cpu: 2000m
        volumeMounts:
        - name: blockchain-data
          mountPath: /data
        - name: chainspec
          mountPath: /chainspec
        livenessProbe:
          httpGet:
            path: /health
            port: 9933
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 9933
          initialDelaySeconds: 10
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: blockchain-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi
      storageClassName: do-block-storage
```

#### **Services Configuration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: substrate-validator-1
  namespace: blockchain
spec:
  selector:
    app: substrate-validator-1
  ports:
  - name: rpc-http
    port: 9933
    targetPort: 9933
  - name: rpc-ws
    port: 9944
    targetPort: 9944
  - name: p2p
    port: 30333
    targetPort: 30333
  - name: prometheus
    port: 9615
    targetPort: 9615
```

#### **Ingress Configuration:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blockchain-ingress
  namespace: blockchain
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  ingressClassName: nginx
  rules:
  - host: blockchain-rpc-1.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: substrate-validator-1
            port:
              number: 9944
  - host: blockchain-rpc-2.hashfoundry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: substrate-validator-2
            port:
              number: 9944
```

## 📂 **Структура проекта**

### **Файловая структура:**
```
ha/
├── blockchain/
│   ├── high-level-design-doc.md           # Этот документ
│   └── implementation-guide.md             # Руководство по реализации
├── k8s/apps/blockchain/                    # Kubernetes манифесты
│   ├── Chart.yaml                          # Helm chart
│   ├── values.yaml                         # Конфигурация
│   ├── templates/
│   │   ├── namespace.yaml                  # blockchain namespace
│   │   ├── configmap-chainspec.yaml        # Genesis конфигурация
│   │   ├── statefulset-validator1.yaml     # Alice validator
│   │   ├── statefulset-validator2.yaml     # Bob validator
│   │   ├── service-validator1.yaml         # Alice RPC service
│   │   ├── service-validator2.yaml         # Bob RPC service
│   │   ├── ingress.yaml                    # External access
│   │   └── servicemonitor.yaml             # Prometheus monitoring
│   └── chainspec/
│       └── genesis.json                    # Genesis блок с Alice/Bob
└── k8s/addons/argo-cd-apps/templates/
    └── blockchain-application.yaml         # ArgoCD application
```

### **ArgoCD Application:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: blockchain
  namespace: argocd
  labels:
    app.kubernetes.io/name: blockchain
    app.kubernetes.io/part-of: hashfoundry
spec:
  project: default
  source:
    repoURL: https://github.com/hashfoundry/infra.git
    targetRevision: HEAD
    path: ha/k8s/apps/blockchain
  destination:
    server: https://kubernetes.default.svc
    namespace: blockchain
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## 📊 **Мониторинг и наблюдаемость**

### **Prometheus Metrics Collection:**
```yaml
# Добавить в ha/k8s/addons/monitoring/prometheus/values.yaml
additionalScrapeConfigs: |
  - job_name: 'substrate-blockchain'
    static_configs:
    - targets:
      - 'substrate-validator-1.blockchain:9615'
      - 'substrate-validator-2.blockchain:9615'
    metrics_path: /metrics
    scrape_interval: 15s
    scrape_timeout: 10s
```

### **Ключевые метрики для мониторинга:**

#### **Blockchain Metrics:**
- `substrate_block_height` - текущая высота блока
- `substrate_finalized_height` - финализированная высота
- `substrate_peers` - количество подключенных пиров
- `substrate_is_syncing` - статус синхронизации
- `substrate_ready_transactions_number` - транзакции в mempool

#### **Runtime Metrics:**
- `substrate_runtime_balance_total_issuance` - общее количество токенов
- `substrate_extrinsics_total` - общее количество транзакций
- `substrate_block_verification_time` - время верификации блока

### **Grafana Dashboard Panels:**

#### **Overview Panel:**
- Block production rate (blocks/minute)
- Transaction throughput (tx/block)
- Network connectivity (peer count)
- Validator status (online/offline)

#### **Accounts Panel:**
- Alice account balance
- Bob account balance
- Transaction history (Alice ↔ Bob)
- Transfer volume per hour

#### **Technical Panel:**
- Block finalization lag
- Memory usage per node
- CPU usage per node
- Storage usage growth

### **Alerting Rules:**
```yaml
groups:
- name: blockchain.rules
  rules:
  - alert: BlockchainNoBlocksProduced
    expr: increase(substrate_block_height[5m]) == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "No blocks produced in 2 minutes"
      
  - alert: ValidatorOffline
    expr: up{job="substrate-blockchain"} == 0
    for: 30s
    labels:
      severity: warning
    annotations:
      summary: "Validator {{ $labels.instance }} is offline"
```

## 🖥️ **CLI интерфейс для тестирования**

### **Polkadot.js API CLI:**
```bash
# Установка CLI инструментов
npm install -g @polkadot/api-cli

# Подключение к локальной ноде
polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local"
```

### **Основные CLI команды:**

#### **Проверка статуса блокчейна:**
```bash
# Получить информацию о последнем блоке
curl -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
     https://blockchain-rpc-1.hashfoundry.local

# Получить баланс Alice
polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
  query.system.account 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY

# Получить баланс Bob  
polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
  query.system.account 5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty
```

#### **Отправка переводов:**
```bash
# Перевод от Alice к Bob (100 токенов)
polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
  --seed "//Alice" \
  tx.balances.transfer 5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty 1000000000000

# Перевод от Bob к Alice (50 токенов)
polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
  --seed "//Bob" \
  tx.balances.transfer 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY 500000000000
```

#### **Мониторинг транзакций:**
```bash
# Подписка на новые блоки
polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
  rpc.chain.subscribeNewHeads

# Просмотр событий в последнем блоке
polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
  query.system.events
```

### **CLI функционал:**
- ✅ **Подключение к RPC endpoints** через WebSocket/HTTP
- ✅ **Просмотр балансов** Alice и Bob через команды
- ✅ **Отправка переводов** между аккаунтами через CLI
- ✅ **Мониторинг блоков** в реальном времени
- ✅ **Просмотр событий** и транзакций
- ✅ **Скриптинг** для автоматизации тестов

## 🔒 **Безопасность**

### **Kubernetes Security:**
- **Network Policies** - изоляция трафика blockchain namespace
- **Pod Security Standards** - restricted security context
- **Service Accounts** - минимальные RBAC права
- **Secrets Management** - validator keys в Kubernetes secrets

### **Blockchain Security:**
- **Authority Round Consensus** - защита от Byzantine failures
- **GRANDPA Finality** - необратимость финализированных блоков
- **Session Keys Rotation** - периодическая смена ключей валидаторов

### **Network Security:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: blockchain-network-policy
  namespace: blockchain
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 9933
    - protocol: TCP
      port: 9944
  - from:
    - podSelector:
        matchLabels:
          app: substrate-validator
    ports:
    - protocol: TCP
      port: 30333
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: substrate-validator
    ports:
    - protocol: TCP
      port: 30333
```

## 🚀 **План развертывания**

### **Задача 1: Подготовка инфраструктуры блокчейна**
**Оценка времени**: 1-2 дня  
**Приоритет**: Critical

#### **Описание задачи:**
Создать полную структуру Kubernetes приложения для развертывания blockchain в существующей HA инфраструктуре, включая Helm chart, манифесты и genesis конфигурацию.

#### **Критерии приемки:**
- ✅ **Создана файловая структура** `ha/k8s/apps/blockchain/` с полным набором шаблонов
- ✅ **Написан Chart.yaml** с корректными metadata и dependencies
- ✅ **Создан values.yaml** с настройками Alice/Bob и ресурсов
- ✅ **Подготовлен genesis.json** с начальными балансами Alice (1M токенов) и Bob (1M токенов)
- ✅ **Написаны StatefulSet манифесты** для validator-1 (Alice) и validator-2 (Bob)
- ✅ **Созданы Service манифесты** для RPC endpoints (порты 9933, 9944)
- ✅ **Подготовлен Ingress манифест** для external access через NGINX
- ✅ **Создан ServiceMonitor** для Prometheus интеграции
- ✅ **Helm chart валидируется** без ошибок: `helm template ha/k8s/apps/blockchain/`

---

### **Задача 2: Развертывание validator нод**
**Оценка времени**: 1 день  
**Приоритет**: Critical  
**Зависимости**: Задача 1

#### **Описание задачи:**
Интегрировать blockchain приложение в ArgoCD и развернуть два validator узла с проверкой их корректной работы и взаимодействия.

#### **Критерии приемки:**
- ✅ **Создан ArgoCD Application** в `ha/k8s/addons/argo-cd-apps/templates/blockchain-application.yaml`
- ✅ **ArgoCD Application синхронизирован** статус: `Synced, Healthy`
- ✅ **Namespace blockchain создан** и активен
- ✅ **Validator pods запущены**: 
  - `substrate-validator-1-0`: Status `Running` (1/1)
  - `substrate-validator-2-0`: Status `Running` (1/1)
- ✅ **Services доступны**:
  - `substrate-validator-1:9944` отвечает на WebSocket запросы
  - `substrate-validator-2:9944` отвечает на WebSocket запросы
- ✅ **P2P connectivity установлен**: ноды видят друг друга как peers
- ✅ **Block production активен**: высота блока увеличивается каждые ~6 секунд
- ✅ **Finalization работает**: finalized height следует за best height
- ✅ **Persistent storage функционирует**: данные сохраняются после restart подов

---

### **Задача 3: Настройка внешнего доступа и CLI тестирование**
**Оценка времени**: 1 день  
**Приоритет**: High  
**Зависимости**: Задача 2

#### **Описание задачи:**
Настроить внешний доступ к RPC endpoints через Ingress и провести полное функциональное тестирование блокчейна с помощью CLI инструментов.

#### **Критерии приемки:**
- ✅ **Ingress rules активны**:
  - `blockchain-rpc-1.hashfoundry.local` доступен извне
  - `blockchain-rpc-2.hashfoundry.local` доступен извне
- ✅ **SSL/TLS сертификаты работают**: HTTPS доступ без ошибок
- ✅ **CLI инструменты установлены**: `npm install -g @polkadot/api-cli`
- ✅ **RPC connectivity тестирован**:
  ```bash
  curl -H "Content-Type: application/json" \
       -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader"}' \
       https://blockchain-rpc-1.hashfoundry.local
  # Ответ: HTTP 200 с корректным JSON
  ```
- ✅ **Баланс аккаунтов проверен**:
  ```bash
  polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
    query.system.account 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY
  # Результат: Alice balance = 1,000,000,000,000,000 (1M токенов)
  ```
- ✅ **Переводы между Alice и Bob выполняются успешно**:
  ```bash
  # Перевод Alice → Bob: 100 токенов
  polkadot-js-api --ws "wss://blockchain-rpc-1.hashfoundry.local" \
    --seed "//Alice" tx.balances.transfer 5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty 1000000000000
  # Результат: Transaction finalized, Alice balance уменьшился, Bob balance увеличился
  ```
- ✅ **Load balancing работает**: запросы распределяются между обеими нодами
- ✅ **Создан тестовый скрипт** для автоматизации проверок: `ha/blockchain/test-transfers.sh`

---

### **Задача 4: Интеграция мониторинга блокчейна**
**Оценка времени**: 1 день  
**Приоритет**: Medium  
**Зависимости**: Задача 3

#### **Описание задачи:**
Интегрировать blockchain метрики в существующий monitoring stack (Prometheus/Grafana) и настроить alerting для критических событий.

#### **Критерии приемки:**
- ✅ **Prometheus scraping настроен**: targets активны для обеих validator нод
  ```bash
  # В Prometheus UI: Status > Targets
  substrate-validator-1.blockchain:9615  UP
  substrate-validator-2.blockchain:9615  UP
  ```
- ✅ **Blockchain метрики собираются**:
  - `substrate_block_height` - актуальная высота блока
  - `substrate_finalized_height` - финализированная высота
  - `substrate_peers` - количество подключенных peers (≥1)
  - `substrate_ready_transactions_number` - транзакции в mempool
- ✅ **Grafana dashboard создан** с панелями:
  - Block production rate (blocks/minute)
  - Transaction throughput (tx/block)
  - Validator connectivity status
  - Alice/Bob account balances (если доступно)
  - Node resource usage (CPU, Memory)
- ✅ **Alerting rules настроены** и протестированы:
  - `BlockchainNoBlocksProduced` - нет блоков 2+ минуты (severity: critical)
  - `ValidatorOffline` - validator недоступен 30+ секунд (severity: warning)
- ✅ **Alert тестирование**: остановка одного validator вызывает alert
- ✅ **Grafana dashboard доступен**: `https://grafana.hashfoundry.local/d/blockchain`

---

### **Задача 5: Автоматизация и документация**
**Оценка времени**: 1 день  
**Приоритет**: Low  
**Зависимости**: Задача 4

#### **Описание задачи:**
Создать automation scripts для testing, провести нагрузочное тестирование и подготовить операционную документацию.

#### **Критерии приемки:**
- ✅ **CLI testing suite создан**: `ha/blockchain/scripts/`
  - `test-connectivity.sh` - проверка RPC доступности
  - `test-transfers.sh` - автоматические переводы Alice ↔ Bob
  - `test-monitoring.sh` - проверка metrics и alerts
  - `health-check.sh` - общая проверка состояния блокчейна
- ✅ **Integration тесты написаны и проходят**:
  ```bash
  cd ha/blockchain/scripts
  ./run-all-tests.sh
  # Результат: All tests passed (4/4)
  ```
- ✅ **Load testing выполнен**:
  - 100 переводов в минуту в течение 10 минут
  - Block time остается ≤ 6 секунд
  - Validator ноды stable (CPU < 80%, Memory < 2Gi)
- ✅ **Операционная документация создана**:
  - `ha/blockchain/implementation-guide.md` - пошаговое руководство
  - `ha/blockchain/troubleshooting-guide.md` - решение проблем
  - `ha/blockchain/operations-manual.md` - эксплуатация и maintenance
- ✅ **Backup procedures документированы**:
  - Persistent volumes backup strategy
  - Validator keys backup процедуры
  - Disaster recovery план
- ✅ **Performance benchmarks документированы**:
  - Baseline метрики производительности
  - Resource requirements для scaling
  - Capacity planning рекомендации

## 📋 **Критерии успеха**

### **Функциональные критерии:**
- ✅ **2 validator ноды** успешно производят блоки
- ✅ **Alice и Bob аккаунты** могут отправлять переводы друг другу
- ✅ **CLI инструменты** работают с RPC endpoints
- ✅ **RPC endpoints** отвечают на запросы через Ingress

### **Нефункциональные критерии:**
- ✅ **Uptime > 99%** для validator нод
- ✅ **Block time ≤ 6 секунд** в среднем
- ✅ **Мониторинг** показывает метрики в реальном времени
- ✅ **Автоматическое восстановление** при сбоях нод

### **Операционные критерии:**
- ✅ **GitOps deployment** через ArgoCD работает
- ✅ **Persistent storage** сохраняет данные между перезапусками
- ✅ **Load balancing** распределяет RPC запросы
- ✅ **Alerting** срабатывает при проблемах

## 🔧 **Maintenance и Operations**

### **Обновления:**
- **Runtime upgrades** через forkless upgrades
- **Container updates** через ArgoCD automation
- **Kubernetes manifests** изменения через Git

### **Backup стратегия:**
- **Persistent Volumes** автоматический backup
- **Chainspec** версионирование в Git
- **Validator keys** secure backup в Vault

### **Troubleshooting:**
- **Logs aggregation** через Loki/Grafana
- **Metrics analysis** через Prometheus/Grafana
- **Network debugging** через kubectl exec

### **Scaling:**
- **Horizontal scaling** - добавление validator нод
- **Vertical scaling** - увеличение ресурсов нод
- **Storage scaling** - расширение persistent volumes

## 📚 **Документация и ресурсы**

### **External Dependencies:**
- [Substrate Documentation](https://docs.substrate.io/)
- [Polkadot.js Apps Guide](https://polkadot.js.org/apps/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

### **Internal Documentation:**
- `implementation-guide.md` - пошаговое руководство реализации
- `troubleshooting-guide.md` - решение типичных проблем
- `operations-manual.md` - руководство по эксплуатации

---

**Версия документа**: 1.0  
**Дата создания**: 23.07.2025  
**Автор**: HashFoundry Infrastructure Team  
**Статус**: Draft for Review
