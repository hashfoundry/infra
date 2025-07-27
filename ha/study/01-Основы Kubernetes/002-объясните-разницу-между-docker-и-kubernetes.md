# 2. Объясните разницу между Docker и Kubernetes

## 🐳 **Что такое Docker?**

**Docker** — это платформа контейнеризации, которая упаковывает приложения и их зависимости в легковесные, портативные контейнеры.

## ☸️ **Что такое Kubernetes?**

**Kubernetes** — это платформа оркестрации контейнеров, которая управляет множеством Docker контейнеров в кластере серверов.

## 🔄 **Ключевые различия:**

| Аспект | Docker | Kubernetes |
|--------|--------|------------|
| **Назначение** | Создание и запуск контейнеров | Оркестрация контейнеров |
| **Масштаб** | Один хост | Кластер серверов |
| **Сложность** | Простой | Сложный |
| **Автоматизация** | Ручное управление | Автоматическое управление |
| **Отказоустойчивость** | Нет | Есть |

## 🏗️ **Аналогия:**
- **Docker** = Грузовик (перевозит один контейнер)
- **Kubernetes** = Порт (управляет тысячами контейнеров)

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Docker контейнеры в действии:**
```bash
# Посмотреть на контейнеры внутри подов
kubectl get pods -n argocd -o wide

# Детальная информация о контейнерах в поде
kubectl describe pod <pod-name> -n argocd

# Посмотреть образы Docker, которые используются
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
```

### **2. Kubernetes оркестрация:**
```bash
# Kubernetes управляет множеством Docker контейнеров
kubectl get pods -A | wc -l

# Автоматическое распределение по нодам
kubectl get pods -n argocd -o wide

# Kubernetes следит за состоянием контейнеров
kubectl get pods -n argocd --watch
```

### **3. Автоматическое масштабирование (чего нет в Docker):**
```bash
# Kubernetes автоматически создает нужное количество реплик
kubectl get replicasets -n argocd

# Horizontal Pod Autoscaler (автомасштабирование)
kubectl get hpa -A

# Автомасштабирование нод кластера
kubectl get nodes
```

### **4. Самовосстановление (чего нет в Docker):**
```bash
# Если контейнер упадет, Kubernetes перезапустит его
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# История перезапусков
kubectl get pods -n argocd -o wide
```

### **5. Балансировка нагрузки (чего нет в Docker):**
```bash
# Services распределяют трафик между контейнерами
kubectl get svc -n argocd

# Endpoints показывают, куда идет трафик
kubectl get endpoints -n argocd
```

### **6. Управление конфигурацией:**
```bash
# Docker: конфигурация в переменных окружения
# Kubernetes: ConfigMaps и Secrets
kubectl get configmaps -n argocd
kubectl get secrets -n argocd
```

### **7. Хранилище данных:**
```bash
# Docker: volumes привязаны к одному хосту
# Kubernetes: Persistent Volumes работают в кластере
kubectl get pv
kubectl get pvc -A
```

## 🔧 **Практические сценарии использования:**

### **Docker подходит для:**
- **Разработки** на локальной машине
- **Простых приложений** на одном сервере
- **Тестирования** приложений
- **CI/CD пайплайнов**

```bash
# Пример Docker команд (НЕ для продакшена):
docker run -d nginx
docker ps
docker stop <container-id>
```

### **Kubernetes подходит для:**
- **Продакшен окружений**
- **Микросервисной архитектуры**
- **Высоконагруженных приложений**
- **Enterprise решений**

```bash
# Пример Kubernetes команд (ваш HA кластер):
kubectl get deployments -n argocd
kubectl scale deployment argocd-server --replicas=5 -n argocd
kubectl rollout status deployment/argocd-server -n argocd
```

## 🏭 **Ваш HA кластер демонстрирует преимущества Kubernetes:**

### **1. Высокая доступность:**
```bash
# ArgoCD работает в 3 репликах (Docker так не умеет)
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

### **2. Автоматическое восстановление:**
```bash
# Если нода упадет, поды переедут на другие ноды
kubectl get pods -n argocd -o wide
```

### **3. Мониторинг всего кластера:**
```bash
# Prometheus собирает метрики со всех контейнеров
kubectl get pods -n monitoring
kubectl get servicemonitor -n monitoring
```

### **4. Централизованное управление:**
```bash
# Одной командой можно управлять сотнями контейнеров
kubectl get pods -A | grep Running | wc -l
```

## 🎯 **Вывод:**

**Docker и Kubernetes работают вместе:**
- **Docker** создает контейнеры
- **Kubernetes** управляет этими контейнерами в масштабе

**В вашем HA кластере:**
- Приложения упакованы в **Docker контейнеры**
- **Kubernetes** обеспечивает их высокую доступность, масштабирование и мониторинг

**Docker = Строительный материал, Kubernetes = Архитектор**
