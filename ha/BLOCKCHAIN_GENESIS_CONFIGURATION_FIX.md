# Blockchain Genesis Configuration Fix Report

## 🎯 **Проблема**

Blockchain StatefulSets (Alice и Bob) находились в состоянии CrashLoopBackOff из-за неправильной конфигурации genesis.json файла.

## 🔍 **Анализ ошибок**

### **Первоначальные ошибки:**
1. `missing field 'aura'` - отсутствующая секция aura
2. `missing field 'allowed_slots'` - неправильное имя поля
3. `missing field 'indices'` - отсутствующая секция indices

### **Логи ошибок:**
```
Error: Service(Client(Storage("Error parsing spec file: missing field `aura` at line 48 column 9")))
Error: Service(Client(Storage("Error parsing spec file: missing field `allowed_slots` at line 48 column 9")))
Error: Service(Client(Storage("Error parsing spec file: missing field `indices` at line 68 column 5")))
```

## 🔧 **Выполненные исправления**

### **1. Удаление секции `aura`:**
Substrate v3.0.0 использует BABE consensus, а не Aura. Секция `aura` была удалена.

### **2. Исправление поля `allowedSlots` → `allowed_slots`:**
```yaml
# До:
"allowedSlots": "PrimaryAndSecondaryPlainSlots"

# После:
"allowed_slots": "PrimaryAndSecondaryPlainSlots"
```

### **3. Добавление секции `indices`:**
```yaml
"runtime": {
  "system": {
    "code": "0x"
  },
  "indices": {},  # Добавлено
  "balances": {
    ...
  }
}
```

## 📋 **Итоговая конфигурация genesis.json**

```json
{
  "name": "HashFoundry Local Testnet",
  "id": "hashfoundry_local",
  "chainType": "Local",
  "bootNodes": [],
  "telemetryEndpoints": null,
  "protocolId": "hf",
  "properties": {
    "tokenSymbol": "HF",
    "tokenDecimals": 12,
    "ss58Format": 42
  },
  "codeSubstitutes": {},
  "genesis": {
    "runtime": {
      "system": {
        "code": "0x"
      },
      "indices": {},
      "balances": {
        "balances": [
          ["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1000000000000000],
          ["5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty", 1000000000000000]
        ]
      },
      "babe": {
        "authorities": [
          ["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1],
          ["5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty", 1]
        ],
        "epochConfig": {
          "c": [1, 4],
          "allowed_slots": "PrimaryAndSecondaryPlainSlots"
        }
      },
      "grandpa": {
        "authorities": [
          ["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1],
          ["5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty", 1]
        ]
      },
      "sudo": {
        "key": "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
      },
      "transactionPayment": {
        "multiplier": "1000000000000000000"
      }
    }
  }
}
```

## ✅ **Проделанная работа**

1. **Исправлен ConfigMap template** в `ha/k8s/apps/blockchain/templates/configmap.yaml`
2. **Обновлен Helm release** (revision 9)
3. **Подтверждено обновление ConfigMap** в кластере
4. **Пересозданы поды** для применения новой конфигурации

## ⚠️ **Текущий статус**

### **Статус подов:**
```
NAME                             READY   STATUS             RESTARTS
hashfoundry-blockchain-alice-0   0/1     CrashLoopBackOff   4
hashfoundry-blockchain-bob-0     0/1     Error              4
```

### **Последняя ошибка:**
```
Error: Service(Client(Storage("Error parsing spec file: missing field `indices` at line 19 column 19")))
```

## 🔍 **Дальнейшие шаги для отладки**

### **1. Проверка Substrate версии:**
Возможно, используемая версия `parity/substrate:latest` требует другой формат genesis.json.

### **2. Недостающие поля:**
Substrate может требовать дополнительные поля:
- `session` - для управления сессиями валидаторов
- `authority_discovery` - для обнаружения авторитетов
- `im_online` - для мониторинга онлайн статуса

### **3. Рекомендуемые исправления:**

#### **Добавить недостающие runtime модули:**
```yaml
"runtime": {
  "system": { "code": "0x" },
  "indices": {},
  "balances": { ... },
  "session": {
    "keys": []
  },
  "authorityDiscovery": {
    "keys": []
  },
  "imOnline": {
    "keys": []
  },
  "babe": { ... },
  "grandpa": { ... },
  "sudo": { ... },
  "transactionPayment": { ... }
}
```

#### **Использовать готовый chainspec:**
```bash
# Генерация chainspec из Substrate node template
substrate build-spec --chain local > genesis.json
```

## 📊 **Статус компонентов**

| Компонент | Статус | Описание |
|-----------|--------|----------|
| ConfigMap | ✅ Исправлен | Обновлен с правильными полями |
| Helm Chart | ✅ Обновлен | Revision 9 развернута |
| Alice Pod | ❌ CrashLoopBackOff | Требует дополнительные поля |
| Bob Pod | ❌ Error | Требует дополнительные поля |
| Services | ✅ Созданы | Готовы к подключению |
| PVC | ✅ Созданы | Persistent storage готов |

## 💡 **Рекомендации**

1. **Использовать substrate node template** для генерации правильного chainspec
2. **Проверить совместимость** версии Docker образа с форматом genesis.json
3. **Добавить недостающие runtime модули** по мере необходимости
4. **Настроить мониторинг** после успешного запуска

## 🔗 **Ссылки**

- [Substrate Runtime Development](https://docs.substrate.io/fundamentals/runtime-development/)
- [Chain Specification](https://docs.substrate.io/build/chain-spec/)
- [BABE Consensus](https://docs.substrate.io/fundamentals/consensus/#babe)

---

**Дата**: 23.07.2025  
**Статус**: В процессе отладки  
**Следующий шаг**: Исследование требований Substrate v3.0.0 для genesis.json
