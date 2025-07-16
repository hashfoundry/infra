# Prometheus UI Access Guide

## 🎯 **Доступ к Prometheus UI**

В нашей конфигурации Prometheus UI доступен через несколько способов:

## 🌐 **Способ 1: Через Ingress (Рекомендуемый)**

### **Настройки Ingress:**
- **URL**: `https://prometheus.hashfoundry.local`
- **External IP**: `129.212.169.0`
- **TLS**: Включен с автоматическими сертификатами
- **Ingress Class**: nginx

### **Настройка DNS:**

#### **Вариант A: Добавить в /etc/hosts**
```bash
echo "129.212.169.0 prometheus.hashfoundry.local" | sudo tee -a /etc/hosts
```

#### **Вариант B: Использовать curl для тестирования**
```bash
curl -k -H "Host: prometheus.hashfoundry.local" https://129.212.169.0/
```

### **Доступ через браузер:**
1. Добавить запись в `/etc/hosts`
2. Открыть: `https://prometheus.hashfoundry.local`
3. Принять самоподписанный сертификат (если используется)

## 🔌 **Способ 2: Через Port-Forward (Для разработки)**

### **Создание port-forward:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
```

### **Доступ:**
- **URL**: `http://localhost:9090`
- **Преимущества**: Не требует настройки DNS
- **Недостатки**: Только локальный доступ

## 📊 **Что доступно в Prometheus UI**

### **1. Главная страница:**
- **Status**: Состояние Prometheus сервера
- **Targets**: Список всех мониторируемых целей
- **Configuration**: Текущая конфигурация
- **Rules**: Настроенные правила алертов

### **2. Graph (Графики):**
- **Query interface**: Интерфейс для PromQL запросов
- **Metrics browser**: Браузер доступных метрик
- **Time range selector**: Выбор временного диапазона

### **3. Alerts:**
- **Active alerts**: Активные алерты
- **Alert rules**: Правила алертов
- **Alert history**: История срабатываний

### **4. Targets:**
- **Service discovery**: Обнаруженные цели
- **Health status**: Статус здоровья целей
- **Last scrape**: Время последнего сбора метрик

## 🔍 **Полезные PromQL запросы для начала**

### **Мониторинг узлов кластера:**
```promql
# CPU usage по узлам
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage по узлам
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)
```

### **Мониторинг Kubernetes:**
```promql
# Количество подов по namespace
count by (namespace) (kube_pod_info)

# Поды в состоянии не Ready
kube_pod_status_ready{condition="false"}

# Использование CPU подами
rate(container_cpu_usage_seconds_total[5m])
```

### **Мониторинг ArgoCD:**
```promql
# Статус приложений ArgoCD
argocd_app_info

# Приложения не в состоянии Synced
argocd_app_info{sync_status!="Synced"}

# Приложения не в состоянии Healthy
argocd_app_info{health_status!="Healthy"}
```

## 🛠️ **Проверка доступности**

### **Проверка через curl:**
```bash
# Через Ingress
curl -k -H "Host: prometheus.hashfoundry.local" https://129.212.169.0/api/v1/status/config

# Через port-forward (если запущен)
curl http://localhost:9090/api/v1/status/config
```

### **Проверка targets:**
```bash
# Список всех targets
curl -k -H "Host: prometheus.hashfoundry.local" https://129.212.169.0/api/v1/targets

# Или через port-forward
curl http://localhost:9090/api/v1/targets
```

## 🔧 **Troubleshooting**

### **Проблема: Ingress не отвечает**
```bash
# Проверить статус ingress
kubectl get ingress -n monitoring

# Проверить NGINX Ingress Controller
kubectl get pods -n ingress-nginx

# Проверить логи ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### **Проблема: Port-forward не работает**
```bash
# Проверить статус сервиса
kubectl get svc prometheus-server -n monitoring

# Проверить статус подов
kubectl get pods -n monitoring

# Убить существующий port-forward
pkill -f "kubectl port-forward"

# Запустить заново
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
```

### **Проблема: Prometheus UI загружается, но нет данных**
```bash
# Проверить логи Prometheus
kubectl logs prometheus-server-<pod-id> -n monitoring -c prometheus-server

# Проверить конфигурацию
kubectl get configmap prometheus-server -n monitoring -o yaml

# Проверить targets в UI: Status -> Targets
```

## 📋 **Команды для управления**

### **Запуск port-forward в фоне:**
```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &
```

### **Остановка port-forward:**
```bash
# Найти процесс
ps aux | grep "kubectl port-forward"

# Убить процесс
pkill -f "kubectl port-forward"
```

### **Проверка статуса Prometheus:**
```bash
# Статус подов
kubectl get pods -n monitoring

# Логи сервера
kubectl logs -f prometheus-server-<pod-id> -n monitoring -c prometheus-server

# Конфигурация
kubectl describe configmap prometheus-server -n monitoring
```

## 🎉 **Заключение**

### **Рекомендуемый workflow:**

1. **Для разработки**: Используйте port-forward для быстрого доступа
2. **Для production**: Настройте DNS и используйте Ingress
3. **Для мониторинга**: Регулярно проверяйте Status -> Targets
4. **Для алертов**: Используйте раздел Alerts для мониторинга правил

### **Полезные ссылки в UI:**
- **Status -> Configuration**: Просмотр текущей конфигурации
- **Status -> Targets**: Проверка доступности мониторируемых сервисов
- **Graph**: Выполнение PromQL запросов
- **Alerts**: Мониторинг активных алертов

**Prometheus UI теперь полностью доступен и готов к использованию!**
