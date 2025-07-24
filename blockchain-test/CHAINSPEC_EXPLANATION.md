# 🔗 Объяснение разницы между `--chain=local` и кастомным chainspec

## 📋 **Краткий ответ на ваш вопрос:**

**`--chain=local`** - это встроенный chainspec Substrate с готовым runtime, который работает "из коробки".

**Кастомный chainspec** (`/chainspec/genesis.json`) - требует компиляции собственного runtime в WASM формате.

---

## 🔍 **Подробное сравнение:**

### **1. `--chain=local` (текущая рабочая конфигурация)**

#### **Что это:**
- **Встроенный chainspec** в Substrate node
- **Готовый runtime** уже скомпилирован в WASM
- **Стандартные настройки** для локального тестирования

#### **Преимущества:**
- ✅ **Работает сразу** - не требует дополнительной настройки
- ✅ **Включает runtime** - WASM код уже встроен
- ✅ **Стандартные Alice/Bob** аккаунты с балансами
- ✅ **Быстрый старт** для тестирования

#### **Настройки по умолчанию:**
```json
{
  "name": "Local Testnet",
  "id": "local_testnet",
  "chainType": "Local",
  "tokenSymbol": "UNIT",
  "tokenDecimals": 12,
  "ss58Format": 42,
  "runtime": "встроенный WASM код"
}
```

---

### **2. Кастомный chainspec `/chainspec/genesis.json` (не работает)**

#### **Что это:**
- **Наш собственный chainspec** "HashFoundry Local Testnet"
- **Требует runtime WASM** - поле `code` обязательно
- **Кастомные настройки** токена и сети

#### **Проблема:**
```bash
Error: Service(Client(Storage("Error parsing spec file: missing field `code` at line 16 column 18")))
```

#### **Что отсутствует:**
```json
{
  "name": "HashFoundry Local Testnet",
  "id": "hashfoundry_local",
  "genesis": {
    "runtime": {
      // ❌ ОТСУТСТВУЕТ: "code": "0x..." - скомпилированный WASM runtime
      "balances": { ... },
      "aura": { ... },
      "grandpa": { ... }
    }
  }
}
```

---

## 🛠️ **Как создать полный кастомный chainspec:**

### **Шаг 1: Компиляция runtime**
```bash
# Нужен Rust проект с runtime
cargo build --release --features runtime-benchmarks
```

### **Шаг 2: Генерация chainspec**
```bash
# Генерация raw chainspec с WASM кодом
./target/release/node-template build-spec --chain=local --raw > genesis-raw.json
```

### **Шаг 3: Кастомизация**
```json
{
  "name": "HashFoundry Local Testnet",
  "id": "hashfoundry_local",
  "genesis": {
    "runtime": {
      "code": "0x52bc537646fdf07762fac978...", // ← WASM runtime код
      "balances": {
        "balances": [
          ["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1000000000000000]
        ]
      }
    }
  }
}
```

---

## 🎯 **Практические выводы:**

### **Для быстрого тестирования (текущий подход):**
```yaml
command:
  - --chain=local  # ✅ Работает сразу
```

**Преимущества:**
- 🚀 Мгновенный запуск
- 🔧 Не требует компиляции
- ✅ Готовые Alice/Bob аккаунты
- 🧪 Идеально для тестирования

### **Для production с кастомным брендингом:**
```yaml
command:
  - --chain=/chainspec/genesis-raw.json  # Требует WASM runtime
```

**Требования:**
- 🦀 Rust проект с runtime
- 🔨 Компиляция в WASM
- 📝 Генерация raw chainspec
- ⚙️ Кастомизация параметров

---

## 📊 **Сравнительная таблица:**

| Параметр | `--chain=local` | Кастомный chainspec |
|----------|----------------|-------------------|
| **Готовность** | ✅ Сразу работает | ❌ Требует разработки |
| **Runtime** | ✅ Встроенный | ❌ Нужна компиляция |
| **Токен** | UNIT | HF (кастомный) |
| **Брендинг** | Стандартный | Полностью кастомный |
| **Сложность** | Минимальная | Высокая |
| **Время настройки** | 0 минут | Несколько дней |

---

## 🎯 **Рекомендация:**

**Для текущего тестирования:** Используем `--chain=local`
- ✅ Быстро и надежно
- ✅ Все функции работают
- ✅ Подходит для отладки

**Для будущего production:** Разработаем кастомный runtime
- 🎨 Собственный брендинг (токен HF)
- ⚙️ Кастомные модули
- 🔒 Специфичная логика

---

## 🔧 **Текущий статус:**

```bash
# ✅ РАБОТАЕТ - используем встроенный chainspec
--chain=local

# ❌ НЕ РАБОТАЕТ - требует WASM runtime
--chain=/chainspec/genesis.json
```

**Blockchain успешно работает с `--chain=local` и готов к тестированию!**
