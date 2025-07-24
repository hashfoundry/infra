# HashFoundry Blockchain Test Environment

Минималистичная реализация тестового блокчейна на базе Polkadot Substrate для локального тестирования с использованием Docker.

## 🎯 Что это?

Простой двухнодовый блокчейн с Alice и Bob validator нодами для быстрого локального тестирования переводов и базовой функциональности.

## ✅ Статус

**✅ РАБОТАЕТ!** Блокчейн успешно запущен и протестирован на Intel процессоре.

## 🚀 Быстрый старт

### 1. Запуск блокчейна
```bash
# Запуск в фоновом режиме
docker-compose up -d

# Проверка статуса
docker-compose ps
```

### 2. Тестирование
```bash
# Запуск автоматических тестов
./test-blockchain.sh
```

### 3. Остановка
```bash
# Остановка
docker-compose down

# Полная очистка (удаление данных)
docker-compose down -v
```

## 📊 Результаты тестирования

```
🚀 HashFoundry Blockchain Test Script
======================================

📦 Test 1: Checking container status...
✅ Containers are running and healthy

📡 Test 2: Testing Alice RPC endpoint (localhost:9933)...
✅ Alice RPC is working and has 1 peer

📡 Test 3: Testing Bob RPC endpoint (localhost:9934)...
✅ Bob RPC is working and has 1 peer

🔗 Test 4: Checking block production...
✅ Block production is working (block height increased)

👩 Test 5: Checking Alice account...
✅ Alice account exists (nonce: 0)

👨 Test 6: Checking Bob account...
✅ Bob account exists (nonce: 0)

🎉 All tests passed! Blockchain is working correctly!
```

## 🔗 Endpoints

| Нода | RPC HTTP | WebSocket | P2P |
|------|----------|-----------|-----|
| Alice | http://localhost:9933 | ws://localhost:9944 | localhost:30333 |
| Bob | http://localhost:9934 | ws://localhost:9945 | localhost:30334 |

## 🧪 Ручное тестирование

### Проверка здоровья нод
```bash
# Alice
curl -H "Content-Type: application/json" \
  -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
  http://localhost:9933

# Bob  
curl -H "Content-Type: application/json" \
  -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
  http://localhost:9934
```

### Проверка текущего блока
```bash
curl -H "Content-Type: application/json" \
  -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' \
  http://localhost:9933
```

### Проверка аккаунтов
```bash
# Alice account
curl -H "Content-Type: application/json" \
  -d '{"id":1, "jsonrpc":"2.0", "method": "system_accountNextIndex", "params":["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"]}' \
  http://localhost:9933

# Bob account
curl -H "Content-Type: application/json" \
  -d '{"id":1, "jsonrpc":"2.0", "method": "system_accountNextIndex", "params":["5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"]}' \
  http://localhost:9934
```

## 🛠 CLI инструменты (опционально)

Для расширенного тестирования установите Node.js:

```bash
# macOS
brew install node

# Установка зависимостей
cd cli
npm install

# Проверка балансов
npm run check-balances

# Мониторинг блоков
npm run monitor
```

## 📁 Структура проекта

```
blockchain-test/
├── docker-compose.yml          # Основная конфигурация
├── test-blockchain.sh          # Скрипт автоматического тестирования
├── README.md                   # Этот файл
└── cli/                       # CLI инструменты
    ├── package.json
    └── examples/
        ├── check-balances.js
        ├── transfer-tokens.js
        └── monitor-blocks.js
```

## 🔧 Troubleshooting

### Проблема: Контейнеры не запускаются
```bash
# Проверить логи
docker-compose logs

# Перезапустить
docker-compose down && docker-compose up -d
```

### Проблема: RPC не отвечает
```bash
# Проверить статус
docker-compose ps

# Проверить порты
netstat -an | grep 9933
```

### Проблема: Ноды не видят друг друга
```bash
# Проверить сеть
docker network ls
docker network inspect blockchain-test_blockchain-network
```

## 📋 Технические детали

- **Framework**: Substrate (Polkadot SDK)
- **Consensus**: Aura (Authority Round)
- **Finality**: GRANDPA
- **Block Time**: ~6 секунд
- **Validators**: Alice, Bob
- **Chain**: Local testnet

## 🎯 Следующие шаги

1. ✅ **Базовый блокчейн** - Готов и протестирован
2. 🔄 **Переводы между Alice и Bob** - Требует CLI инструменты
3. 🔄 **Интеграция с фронтендом** - Следующий этап
4. 🔄 **Деплой в Kubernetes** - Для продакшена

## 📝 История изменений

- **v1.0** - Первоначальная настройка (проблемы с ARM)
- **v1.1** - Исправлена совместимость с Intel процессорами
- **v1.2** - Добавлены автоматические тесты
- **v1.3** - Полностью рабочая версия ✅

---

**Статус**: ✅ Готов к использованию  
**Платформа**: Intel/AMD64  
**Последнее тестирование**: 23.07.2025
