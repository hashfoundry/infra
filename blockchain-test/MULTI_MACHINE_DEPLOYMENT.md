# 🌐 Развертывание blockchain на разных машинах с `--chain=local`

## 📋 **Краткий ответ:**

**ДА, можно!** `--chain=local` работает для валидаторов на разных машинах, но требует правильной настройки bootnodes с реальными IP адресами.

---

## 🔍 **Подробное объяснение:**

### **Что такое `--chain=local`:**
- **Встроенный chainspec** Substrate
- **Одинаковый genesis блок** на всех нодах
- **Стандартные Alice/Bob ключи** для валидаторов
- **Работает везде** - локально и между машинами

### **Ключевое отличие:**
- **Локально**: bootnodes используют DNS имена контейнеров
- **Между машинами**: bootnodes должны использовать реальные IP адреса

---

## 🏗️ **Архитектура multi-machine deployment:**

```
┌─────────────────┐                    ┌─────────────────┐
│   Machine 1     │                    │   Machine 2     │
│  (192.168.1.10) │                    │  (192.168.1.20) │
├─────────────────┤                    ├─────────────────┤
│                 │                    │                 │
│ Alice Validator │◄──── P2P ────────►│ Bob Validator   │
│ --chain=local   │    Network         │ --chain=local   │
│ --alice         │                    │ --bob           │
│                 │                    │                 │
│ Port 30333      │                    │ Port 30333      │
│ Port 9933 (RPC) │                    │ Port 9933 (RPC) │
└─────────────────┘                    └─────────────────┘
```

---

## ⚙️ **Конфигурация для разных машин:**

### **Machine 1 (Alice) - docker-compose.yml:**
```yaml
services:
  blockchain-alice:
    image: parity/substrate:latest
    container_name: blockchain-alice
    command:
      - --chain=local
      - --validator
      - --alice
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=alice-node
      # Bootnode указывает на Machine 2
      - --bootnodes=/ip4/192.168.1.20/tcp/30333/p2p/12D3KooWCypfENuYs2G13wp2pJ9LaukfCcRHT4tAxEyE1XCGwVVN
    ports:
      - "9933:9933"   # RPC HTTP
      - "9944:9944"   # RPC WebSocket  
      - "30333:30333" # P2P
    restart: unless-stopped
```

### **Machine 2 (Bob) - docker-compose.yml:**
```yaml
services:
  blockchain-bob:
    image: parity/substrate:latest
    container_name: blockchain-bob
    command:
      - --chain=local
      - --validator
      - --bob
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=bob-node
      # Bootnode указывает на Machine 1
      - --bootnodes=/ip4/192.168.1.10/tcp/30333/p2p/12D3KooWAMacdttUqjZbBG2WzK7j6uZ8xfuv77eKzDKzKi6w3Jm8
    ports:
      - "9933:9933"   # RPC HTTP
      - "9944:9944"   # RPC WebSocket  
      - "30333:30333" # P2P
    restart: unless-stopped
```

---

## 🔑 **Ключевые изменения для multi-machine:**

### **1. Bootnodes с реальными IP:**
```bash
# Локально (текущая конфигурация):
--bootnodes=/dns/blockchain-alice/tcp/30333/p2p/PEER_ID

# Между машинами:
--bootnodes=/ip4/192.168.1.10/tcp/30333/p2p/PEER_ID
```

### **2. Открытые порты:**
```bash
# P2P порт должен быть доступен извне
- "30333:30333"  # Обязательно для P2P соединения

# RPC порты (опционально для внешнего доступа)
- "9933:9933"    # HTTP RPC
- "9944:9944"    # WebSocket RPC
```

### **3. Firewall настройки:**
```bash
# На каждой машине открыть порты:
sudo ufw allow 30333  # P2P
sudo ufw allow 9933   # RPC HTTP (если нужен внешний доступ)
sudo ufw allow 9944   # RPC WebSocket (если нужен внешний доступ)
```

---

## 🚀 **Пошаговое развертывание:**

### **Шаг 1: Подготовка Machine 1 (Alice)**
```bash
# 1. Клонировать проект
git clone <repo> blockchain-multi
cd blockchain-multi

# 2. Создать docker-compose.yml для Alice
cat > docker-compose.yml << 'EOF'
services:
  blockchain-alice:
    image: parity/substrate:latest
    container_name: blockchain-alice
    command:
      - --chain=local
      - --validator
      - --alice
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=alice-node
      - --bootnodes=/ip4/MACHINE_2_IP/tcp/30333/p2p/12D3KooWCypfENuYs2G13wp2pJ9LaukfCcRHT4tAxEyE1XCGwVVN
    ports:
      - "9933:9933"
      - "9944:9944"
      - "30333:30333"
    restart: unless-stopped
EOF

# 3. Заменить MACHINE_2_IP на реальный IP Machine 2
sed -i 's/MACHINE_2_IP/192.168.1.20/g' docker-compose.yml

# 4. Запустить Alice
docker-compose up -d
```

### **Шаг 2: Подготовка Machine 2 (Bob)**
```bash
# 1. Клонировать проект
git clone <repo> blockchain-multi
cd blockchain-multi

# 2. Создать docker-compose.yml для Bob
cat > docker-compose.yml << 'EOF'
services:
  blockchain-bob:
    image: parity/substrate:latest
    container_name: blockchain-bob
    command:
      - --chain=local
      - --validator
      - --bob
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=bob-node
      - --bootnodes=/ip4/MACHINE_1_IP/tcp/30333/p2p/12D3KooWAMacdttUqjZbBG2WzK7j6uZ8xfuv77eKzDKzKi6w3Jm8
    ports:
      - "9933:9933"
      - "9944:9944"
      - "30333:30333"
    restart: unless-stopped
EOF

# 3. Заменить MACHINE_1_IP на реальный IP Machine 1
sed -i 's/MACHINE_1_IP/192.168.1.10/g' docker-compose.yml

# 4. Запустить Bob
docker-compose up -d
```

### **Шаг 3: Проверка соединения**
```bash
# На Machine 1 проверить Alice
curl -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
     http://localhost:9933

# На Machine 2 проверить Bob
curl -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
     http://localhost:9933

# Ожидаемый результат: "peers": 1 на обеих машинах
```

---

## 🔧 **Автоматизация с помощью скриптов:**

### **deploy-alice.sh:**
```bash
#!/bin/bash
BOB_IP=${1:-"192.168.1.20"}

echo "🚀 Deploying Alice validator..."
echo "📡 Bob IP: $BOB_IP"

cat > docker-compose.yml << EOF
services:
  blockchain-alice:
    image: parity/substrate:latest
    container_name: blockchain-alice
    command:
      - --chain=local
      - --validator
      - --alice
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=alice-node
      - --bootnodes=/ip4/$BOB_IP/tcp/30333/p2p/12D3KooWCypfENuYs2G13wp2pJ9LaukfCcRHT4tAxEyE1XCGwVVN
    ports:
      - "9933:9933"
      - "9944:9944"
      - "30333:30333"
    restart: unless-stopped
EOF

docker-compose up -d
echo "✅ Alice validator deployed!"
```

### **deploy-bob.sh:**
```bash
#!/bin/bash
ALICE_IP=${1:-"192.168.1.10"}

echo "🚀 Deploying Bob validator..."
echo "📡 Alice IP: $ALICE_IP"

cat > docker-compose.yml << EOF
services:
  blockchain-bob:
    image: parity/substrate:latest
    container_name: blockchain-bob
    command:
      - --chain=local
      - --validator
      - --bob
      - --tmp
      - --rpc-external
      - --rpc-port=9933
      - --rpc-cors=all
      - --rpc-methods=unsafe
      - --name=bob-node
      - --bootnodes=/ip4/$ALICE_IP/tcp/30333/p2p/12D3KooWAMacdttUqjZbBG2WzK7j6uZ8xfuv77eKzDKzKi6w3Jm8
    ports:
      - "9933:9933"
      - "9944:9944"
      - "30333:30333"
    restart: unless-stopped
EOF

docker-compose up -d
echo "✅ Bob validator deployed!"
```

### **Использование:**
```bash
# На Machine 1:
./deploy-alice.sh 192.168.1.20

# На Machine 2:
./deploy-bob.sh 192.168.1.10
```

---

## 🌍 **Варианты сетевых конфигураций:**

### **1. Локальная сеть (LAN):**
```bash
# Используем приватные IP адреса
--bootnodes=/ip4/192.168.1.10/tcp/30333/p2p/PEER_ID
```

### **2. Публичная сеть (Internet):**
```bash
# Используем публичные IP адреса
--bootnodes=/ip4/203.0.113.10/tcp/30333/p2p/PEER_ID
```

### **3. VPN сеть:**
```bash
# Используем VPN IP адреса
--bootnodes=/ip4/10.8.0.10/tcp/30333/p2p/PEER_ID
```

### **4. Cloud deployment (AWS/GCP/Azure):**
```bash
# Используем внутренние IP адреса облака
--bootnodes=/ip4/10.0.1.10/tcp/30333/p2p/PEER_ID
```

---

## ✅ **Преимущества `--chain=local` для multi-machine:**

1. **✅ Простота**: Не требует компиляции runtime
2. **✅ Совместимость**: Одинаковый genesis на всех машинах
3. **✅ Быстрота**: Мгновенное развертывание
4. **✅ Тестирование**: Идеально для proof-of-concept
5. **✅ Отладка**: Стандартные Alice/Bob ключи

## ❌ **Ограничения:**

1. **❌ Брендинг**: Стандартный токен UNIT
2. **❌ Кастомизация**: Нельзя изменить параметры сети
3. **❌ Production**: Не подходит для реального продакта
4. **❌ Безопасность**: Известные тестовые ключи

---

## 🎯 **Рекомендации:**

### **Для тестирования и разработки:**
```bash
✅ Используйте --chain=local
✅ Быстро и просто
✅ Подходит для multi-machine
```

### **Для production:**
```bash
🔧 Создайте кастомный chainspec
🔧 Скомпилируйте собственный runtime
🔧 Используйте уникальные ключи валидаторов
```

---

## 📋 **Итоговый ответ:**

**ДА, вы можете запустить blockchain с `--chain=local` на разных машинах!**

**Главное изменение:** замените DNS bootnodes на IP адреса:
```bash
# Вместо:
--bootnodes=/dns/blockchain-alice/tcp/30333/p2p/PEER_ID

# Используйте:
--bootnodes=/ip4/192.168.1.10/tcp/30333/p2p/PEER_ID
```

**Blockchain будет работать идентично**, но валидаторы будут на разных машинах!
