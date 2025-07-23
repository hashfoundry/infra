# HashFoundry Blockchain - High Level Design Document (Docker Local Testing Edition)

## 📋 **Обзор проекта**

Минималистичная реализация простого блокчейна на базе Polkadot Substrate для локального тестирования с использованием Docker и Docker Compose. Цель: создать максимально простой блокчейн с возможностью переводов между Alice и Bob аккаунтами для быстрого локального тестирования.

## 🎯 **Требования**

### **Функциональные требования:**
- ✅ **2 validator ноды** для консенсуса
- ✅ **Переводы между Alice и Bob** - единственная операция
- ✅ **CLI инструменты** для взаимодействия с блокчейном
- ✅ **RPC endpoints** для прямого доступа

### **Нефункциональные требования:**
- ✅ **Максимальная простота** - одна команда `docker-compose up`
- ✅ **Минимальные зависимости** - только Docker
- ✅ **Быстрый старт** - готов к тестированию за 1 минуту
- ✅ **Persistent storage** - сохранение данных блокчейна

## 🏗️ **Архитектура системы**

### **Упрощенная архитектура:**
```
┌─────────────────────────────────────────────────────────────┐
│               Docker Host Machine                            │
├─────────────────────────────────────────────────────────────┤
│  Direct Access to RPC Endpoints                             │
│  ├── localhost:9933 → Alice RPC HTTP                       │
│  ├── localhost:9944 → Alice RPC WebSocket                  │
│  ├── localhost:9934 → Bob RPC HTTP                         │
│  └── localhost:9945 → Bob RPC WebSocket                    │
├─────────────────────────────────────────────────────────────┤
│  Blockchain Network (docker-compose network)                │
│  ├── blockchain-alice (Substrate Alice Authority)          │
│  └── blockchain-bob (Substrate Bob Authority)              │
├─────────────────────────────────────────────────────────────┤
│  Persistent Storage (Docker Volumes)                       │
│  ├── blockchain-alice-data (Alice validator database)      │
│  └── blockchain-bob-data (Bob validator database)          │
└─────────────────────────────────────────────────────────────┘
```

### **Компонентная диаграмма:**
```
┌─────────────────┐                          ┌─────────────────┐
│  CLI Tools      │────────────────────────────│  RPC Endpoints  │
│  (polkadot-js)  │                          │  (HTTP/WS)      │
└─────────────────┘                          └─────────────────┘
                                │
                                ▼
┌─────────────────┐                          ┌─────────────────┐
│ Alice Container │◄────── P2P Network ─────►│  Bob Container  │
│ (localhost:9944)│                          │ (localhost:9945)│
└─────────────────┘                          └─────────────────┘
         │                                              │
         ▼                                              ▼
┌─────────────────┐                          ┌─────────────────┐
│ Docker Volume 1 │                          │ Docker Volume 2 │
└─────────────────┘                          └─────────────────┘
```

## 🔧 **Техническая спецификация**

### **Docker Technology Stack:**

#### **Container Runtime:**
- **Container Engine**: Docker
- **Orchestration**: Docker Compose v2
- **Networking**: Default bridge network
- **Storage**: Named Docker volumes
- **Process Management**: Docker restart policies

#### **Substrate Configuration:**
- **Framework**: Substrate (Polkadot SDK)
- **Consensus**: Aura (Authority Round)
- **Finality**: GRANDPA 
- **Runtime Modules**: System, Balances, Aura, GRANDPA
- **Block Time**: 6 seconds

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

### **Simplified Docker Compose Configuration:**

```yaml
version: '3.8'

services:
  # Alice Validator Node
  blockchain-alice:
    image: parity/substrate:latest
    container_name: blockchain-alice
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
      - --rpc-methods=unsafe
      - --name=alice-node
    ports:
      - "9933:9933"  # RPC HTTP
      - "9944:9944"  # RPC WebSocket  
      - "30333:30333" # P2P
    volumes:
      - blockchain-alice-data:/data
      - ./chainspec:/chainspec:ro
    networks:
      - blockchain-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9933/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # Bob Validator Node
  blockchain-bob:
    image: parity/substrate:latest
    container_name: blockchain-bob
    command:
      - substrate
      - --chain=/chainspec/genesis.json
      - --validator
      - --bob
      - --base-path=/data
      - --rpc-external
      - --ws-external
      - --rpc-cors=all
      - --unsafe-rpc-external
      - --unsafe-ws-external
      - --rpc-methods=unsafe
      - --name=bob-node
      - --bootnodes=/dns/blockchain-alice/tcp/30333/p2p/12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp
    ports:
      - "9934:9933"  # RPC HTTP (different port)
      - "9945:9944"  # RPC WebSocket (different port)
      - "30334:30333" # P2P (different port)
    volumes:
      - blockchain-bob-data:/data
      - ./chainspec:/chainspec:ro
    networks:
      - blockchain-network
    restart: unless-stopped
    depends_on:
      blockchain-alice:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9933/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s

networks:
  blockchain-network:
    driver: bridge

volumes:
  blockchain-alice-data:
    driver: local
  blockchain-bob-data:
    driver: local
```

## 📂 **Структура проекта**

### **Упрощенная файловая структура:**
```
docker-blockchain/
├── high-level-design-doc.md               # Этот документ
├── README.md                              # Quick start guide
├── docker-compose.yml                     # Основная конфигурация
├── .env                                   # Environment variables
├── .env.example                          # Example environment config
├── chainspec/
│   └── genesis.json                      # Genesis блок с Alice/Bob
├── scripts/
│   ├── start.sh                          # Start blockchain
│   ├── stop.sh                           # Stop blockchain
│   ├── reset.sh                          # Reset blockchain data
│   ├── test-connectivity.sh              # Test RPC connectivity
│   └── test-transfers.sh                 # Test Alice ↔ Bob transfers
├── cli/
│   ├── install.sh                        # Install CLI tools
│   ├── examples/
│   │   ├── check-balances.js             # Check Alice/Bob balances
│   │   ├── transfer-tokens.js            # Send transfers
│   │   └── monitor-blocks.js             # Monitor new blocks
│   └── package.json                     # Node.js dependencies
└── docs/
    └── troubleshooting.md                # Решение проблем
```

### **Environment Configuration (.env):**
```bash
# Blockchain Configuration
SUBSTRATE_VERSION=latest
CHAIN_NAME=hashfoundry_local

# Alice Node Configuration
ALICE_RPC_PORT=9933
ALICE_WS_PORT=9944
ALICE_P2P_PORT=30333

# Bob Node Configuration  
BOB_RPC_PORT=9934
BOB_WS_PORT=9945
BOB_P2P_PORT=30334

# Resource Limits (optional)
MEMORY_LIMIT=2g
CPU_LIMIT=1.0
```

## 🖥️ **CLI интерфейс для тестирования**

### **Быстрая установка CLI инструментов:**
```bash
# Установка через setup script
cd docker-blockchain/cli
./install.sh

# Или manual установка
npm install -g @polkadot/api-cli
```

### **Основные CLI команды:**

#### **Проверка статуса блокчейна:**
```bash
# Подключение к Alice ноде
polkadot-js-api --ws "ws://localhost:9944"

# Подключение к Bob ноде  
polkadot-js-api --ws "ws://localhost:9945"

# Получить информацию о последнем блоке Alice
curl -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
     http://localhost:9933

# Получить информацию о последнем блоке Bob
curl -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
     http://localhost:9934
```

#### **Проверка балансов:**
```bash
# Баланс Alice через Alice ноду
polkadot-js-api --ws "ws://localhost:9944" \
  query.system.account 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY

# Баланс Bob через Bob ноду
polkadot-js-api --ws "ws://localhost:9945" \
  query.system.account 5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty

# Использование готового скрипта
node cli/examples/check-balances.js
```

#### **Отправка переводов:**
```bash
# Перевод от Alice к Bob (100 токенов) через Alice ноду
polkadot-js-api --ws "ws://localhost:9944" \
  --seed "//Alice" \
  tx.balances.transfer 5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty 1000000000000

# Перевод от Bob к Alice (50 токенов) через Bob ноду
polkadot-js-api --ws "ws://localhost:9945" \
  --seed "//Bob" \
  tx.balances.transfer 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY 500000000000

# Использование готового скрипта
node cli/examples/transfer-tokens.js --from alice --to bob --amount 100
```

#### **Мониторинг блоков:**
```bash
# Подписка на новые блоки Alice ноды
polkadot-js-api --ws "ws://localhost:9944" \
  rpc.chain.subscribeNewHeads

# Подписка на новые блоки Bob ноды
polkadot-js-api --ws "ws://localhost:9945" \
  rpc.chain.subscribeNewHeads

# Мониторинг обеих нод одновременно
node cli/examples/monitor-blocks.js
```

### **Готовые тестовые скрипты:**

#### **check-balances.js:**
```javascript
const { ApiPromise, WsProvider } = require('@polkadot/api');

async function checkBalances() {
  console.log('🔍 Checking Alice and Bob balances...\n');

  try {
    // Alice node connection
    const aliceProvider = new WsProvider('ws://localhost:9944');
    const aliceApi = await ApiPromise.create({ provider: aliceProvider });
    
    // Alice balance
    const aliceAccount = await aliceApi.query.system.account('5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY');
    console.log(`👩 Alice Balance: ${aliceAccount.data.free.toHuman()}`);

    // Bob node connection
    const bobProvider = new WsProvider('ws://localhost:9945');
    const bobApi = await ApiPromise.create({ provider: bobProvider });
    
    // Bob balance  
    const bobAccount = await bobApi.query.system.account('5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty');
    console.log(`👨 Bob Balance: ${bobAccount.data.free.toHuman()}`);

    await aliceApi.disconnect();
    await bobApi.disconnect();
    
  } catch (error) {
    console.error('❌ Error checking balances:', error.message);
  }
}

checkBalances().then(() => process.exit(0));
```

#### **transfer-tokens.js:**
```javascript
const { ApiPromise, WsProvider, Keyring } = require('@polkadot/api');
const { cryptoWaitReady } = require('@polkadot/util-crypto');

async function transferTokens() {
  await cryptoWaitReady();
  
  console.log('💸 Starting transfer test...\n');

  try {
    // Connect to Alice node
    const provider = new WsProvider('ws://localhost:9944');
    const api = await ApiPromise.create({ provider });

    // Setup keyring
    const keyring = new Keyring({ type: 'sr25519' });
    const alice = keyring.addFromUri('//Alice');
    const bobAddress = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';

    // Transfer amount (100 tokens)
    const amount = 1000000000000;

    console.log(`📤 Sending ${amount / 10**12} tokens from Alice to Bob...`);

    // Create and send transfer
    const transfer = api.tx.balances.transfer(bobAddress, amount);
    const hash = await transfer.signAndSend(alice);

    console.log(`✅ Transfer sent with hash: ${hash}`);
    console.log('🔍 Check balances to see the result\n');

    await api.disconnect();
    
  } catch (error) {
    console.error('❌ Transfer failed:', error.message);
  }
}

transferTokens().then(() => process.exit(0));
```

## 🔒 **Безопасность**

### **Docker Security:**
- **Container Isolation** - каждый validator в отдельном контейнере
- **Network Segmentation** - custom network для блокчейн нод
- **Volume Permissions** - ограниченные права доступа к данным
- **Resource Limits** - ограничения CPU/Memory

### **Blockchain Security:**
- **Authority Round Consensus** - защита от Byzantine failures
- **GRANDPA Finality** - необратимость финализированных блоков
- **Test Keys** - использование стандартных Alice/Bob ключей для тестирования
- **RPC Security** - unsafe методы разрешены только для тестирования

## 🚀 **Упрощенный план развертывания**

### **Задача 1: Подготовка тестовой среды**
**Оценка времени**: 30 минут  
**Приоритет**: Critical

#### **Описание задачи:**
Создать минимальную структуру Docker проекта для локального тестирования blockchain.

#### **Критерии приемки:**
- ✅ **Создана структура проекта** `docker-blockchain/` с базовыми файлами
- ✅ **Написан docker-compose.yml** с Alice/Bob validator нодами
- ✅ **Создан .env файл** с портами и настройками
- ✅ **Подготовлен genesis.json** с начальными балансами Alice и Bob
- ✅ **Docker Compose валидируется**: `docker-compose config` без ошибок

---

### **Задача 2: Запуск blockchain нод**
**Оценка времени**: 15 минут  
**Приоритет**: Critical  
**Зависимости**: Задача 1

#### **Описание задачи:**
Запустить Alice и Bob validator ноды и проверить их взаимодействие.

#### **Критерии приемки:**
- ✅ **Контейнеры запущены**:
  ```bash
  docker-compose up -d
  docker-compose ps
  # blockchain-alice    running
  # blockchain-bob      running
  ```
- ✅ **RPC endpoints отвечают**:
  ```bash
  curl http://localhost:9933/health  # Alice
  curl http://localhost:9934/health  # Bob
  # Оба возвращают HTTP 200
  ```
- ✅ **Block production активен**: высота блока увеличивается
- ✅ **P2P connectivity**: Bob видит Alice как peer

---

### **Задача 3: CLI тестирование**
**Оценка времени**: 30 минут  
**Приоритет**: High  
**Зависимости**: Задача 2

#### **Описание задачи:**
Установить CLI инструменты и провести функциональное тестирование переводов.

#### **Критерии приемки:**
- ✅ **CLI инструменты установлены**: `npm install -g @polkadot/api-cli`
- ✅ **Баланс проверка работает**:
  ```bash
  node cli/examples/check-balances.js
  # Alice Balance: 1.0000 MHF
  # Bob Balance: 1.0000 MHF
  ```
- ✅ **Переводы выполняются**:
  ```bash
  node cli/examples/transfer-tokens.js
  # Transfer sent successfully
  ```
- ✅ **Тестовые скрипты работают**: connectivity и transfer тесты проходят

## 📋 **Критерии успеха**

### **Функциональные критерии:**
- ✅ **2 validator ноды** производят блоки каждые 6 секунд
- ✅ **Alice и Bob аккаунты** могут отправлять переводы через CLI
- ✅ **RPC endpoints** отвечают на портах 9933/9944 (Alice) и 9934/9945 (Bob)
- ✅ **CLI тесты** проходят успешно

### **Операционные критерии:**
- ✅ **One-command start**: `docker-compose up -d` запускает все
- ✅ **Fast startup**: готов к тестированию за 1-2 минуты
- ✅ **Persistent data**: данные сохраняются между перезапусками
- ✅ **Easy cleanup**: `docker-compose down -v` полностью очищает

## 🔧 **Операции и обслуживание**

### **Основные команды:**
```bash
# Запуск blockchain
docker-compose up -d

# Проверка статуса
docker-compose ps
docker-compose logs blockchain-alice

# Остановка
docker-compose down

# Полная очистка (удаление данных)
docker-compose down -v
docker system prune -f

# Перезапуск
docker-compose restart
```

### **Тестирование:**
```bash
# Быстрый тест connectivity
curl http://localhost:9933/health && curl http://localhost:9934/health

# Проверка балансов
node cli/examples/check-balances.js

# Тест перевода
node cli/examples/transfer-tokens.js

# Комплексный тест
./scripts/test-transfers.sh
```

### **Troubleshooting:**
```bash
# Просмотр логов
docker-compose logs -f blockchain-alice
docker-compose logs -f blockchain-bob

# Проверка сети
docker network ls
docker network inspect docker-blockchain_blockchain-network

# Информация о контейнерах
docker inspect blockchain-alice
docker inspect blockchain-bob

# Ресурсы
docker stats blockchain-alice blockchain-bob
```

## 📚 **Quick Start Guide**

### **Минимальные требования:**
- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM
- 10GB свободного места на диске
- Node.js 16+ (для CLI tools)

### **Быстрый старт:**
```bash
# 1. Клонирование проекта
git clone <repo-url> docker-blockchain
cd docker-blockchain

# 2. Настройка окружения
cp .env.example .env

# 3. Запуск blockchain
docker-compose up -d

# 4. Ожидание готовности (1-2 минуты)
echo "Waiting for blockchain to start..."
sleep 90

# 5. Проверка готовности
curl http://localhost:9933/health
curl http://localhost:9934/health

# 6. Установка CLI tools
npm install -g @polkadot/api-cli

# 7. Первый тест
node cli/examples/check-balances.js

# 8. Тест перевода
node cli/examples/transfer-tokens.js

# 9. Проверка результата
node cli/examples/check-balances.js
```

### **Что ожидать:**
- **Время запуска**: 1-2 минуты до готовности
- **Начальные балансы**: Alice и Bob по 1M токенов каждый
- **Block time**: новый блок каждые 6 секунд
- **RPC доступ**: Alice на 9933/9944, Bob на 9934/9945

---

**Версия документа**: 1.0  
**Дата создания**: 23.07.2025  
**Автор**: HashFoundry Infrastructure Team  
**Статус**: Ready for Local Testing

**Преимущества упрощенной версии:**
- ✅ **Максимально простое развертывание** - только blockchain ноды
- ✅ **Быстрый старт** - готово к тестированию за 1 минуту
- ✅ **Минимальные ресурсы** - требует только 4GB RAM
- ✅ **Прямой доступ** - RPC endpoints доступны напрямую
- ✅ **Легкое тестирование** - CLI скрипты для всех операций
- ✅ **Простая очистка** - одна команда удаляет все данные
