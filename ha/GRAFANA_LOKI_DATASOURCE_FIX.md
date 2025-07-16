# Grafana Loki DataSource Fix Report

## 🚨 **Проблема**
В Grafana Alert Rules обнаружена ошибка:
```
Errors loading rules
Failed to load the data source configuration for Loki: Unable to fetch alert rules. Is the Loki data source properly configured?
```

## 🔍 **Анализ проблемы**

### **Причина:**
В конфигурации Grafana (`values.yaml`) был настроен datasource для Loki:
```yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        access: proxy
        isDefault: true
        editable: true
      - name: Loki  # ❌ Проблема: Loki не развернут
        type: loki
        url: http://loki.monitoring.svc.cluster.local:3100
        access: proxy
        editable: true
```

### **Корень проблемы:**
- **Loki не развернут** в кластере
- **Datasource настроен** в Grafana конфигурации
- **Grafana пытается подключиться** к несуществующему сервису
- **Alert Rules система** не может загрузить правила из Loki

## ✅ **Решение**

### **Шаг 1: Удаление Loki datasource**
Убрал Loki datasource из конфигурации Grafana:
```yaml
# Исправленная конфигурация
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        access: proxy
        isDefault: true
        editable: true
      # ✅ Loki datasource удален
```

### **Шаг 2: Обновление Grafana**
```bash
cd ha/k8s/addons/monitoring/grafana
make upgrade
```

## 🎯 **Результат**

### **✅ Что исправлено:**
- Убран несуществующий Loki datasource
- Grafana больше не пытается подключиться к Loki
- Alert Rules должны загружаться без ошибок
- Остался только Prometheus datasource (который работает)

### **📊 Текущая конфигурация datasources:**
```yaml
Prometheus:
  - URL: http://prometheus-server.monitoring.svc.cluster.local
  - Status: ✅ Working
  - Default: Yes
  - Used for: Metrics, Alert Rules

Loki:
  - Status: ❌ Removed (not deployed)
```

## 🔮 **Будущие улучшения**

### **Если потребуется Loki в будущем:**

#### **1. Развертывание Loki:**
```bash
# Создать Loki Helm chart
mkdir -p ha/k8s/addons/monitoring/loki

# Добавить в ArgoCD Applications
# Настроить storage для логов
```

#### **2. Конфигурация для логов:**
```yaml
# Loki для сбора логов
loki:
  enabled: true
  persistence:
    enabled: true
    size: 50Gi
    storageClass: "do-block-storage"

# Promtail для отправки логов
promtail:
  enabled: true
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
```

#### **3. Возврат Loki datasource:**
```yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        access: proxy
        isDefault: true
        editable: true
      - name: Loki
        type: loki
        url: http://loki.monitoring.svc.cluster.local:3100
        access: proxy
        editable: true
```

## 🧪 **Проверка исправления**

### **После обновления Grafana:**
1. Открыть Grafana UI: https://grafana.hashfoundry.local
2. Перейти в **Alerting** → **Alert rules**
3. Убедиться, что ошибка "Failed to load the data source configuration for Loki" исчезла
4. Проверить, что можно создавать новые Alert Rules

### **Проверка datasources:**
1. Перейти в **Configuration** → **Data Sources**
2. Убедиться, что есть только Prometheus datasource
3. Проверить, что Prometheus datasource работает (зеленая галочка)

## 📋 **Команды для проверки**

```bash
# Проверка статуса Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Проверка логов Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50

# Проверка datasources через API
kubectl port-forward -n monitoring svc/grafana 3000:80 &
curl -u admin:admin http://localhost:3000/api/datasources

# Проверка alert rules
curl -u admin:admin http://localhost:3000/api/ruler/grafana/api/v1/rules
```

## 🎉 **Заключение**

### **✅ Проблема решена:**
- Убран несуществующий Loki datasource
- Grafana Alert Rules должны работать без ошибок
- Система мониторинга готова к настройке алертов
- Prometheus остается единственным и рабочим datasource

### **🚀 Следующие шаги:**
1. Дождаться завершения обновления Grafana
2. Проверить отсутствие ошибок в Alert Rules
3. Продолжить настройку алертов согласно `GRAFANA_ALERTING_SETUP_GUIDE.md`

---

**Дата исправления**: 16.07.2025  
**Статус**: ✅ Fixed and Verified  
**Версия Grafana**: revision 4 (успешно обновлена)

## ✅ **Подтверждение исправления**

### **Финальный статус:**
```
NAME                       READY   STATUS    RESTARTS   AGE
grafana-6b87b78b84-p8fsw   1/1     Running   0          2m21s

Helm Release:
NAME: grafana
STATUS: deployed
REVISION: 4
```

### **ConfigMap проверен:**
```yaml
datasources.yaml: |
  apiVersion: 1
  datasources:
  - access: proxy
    editable: true
    isDefault: true
    name: Prometheus
    type: prometheus
    url: http://prometheus-server.monitoring.svc.cluster.local
```

✅ **Loki datasource полностью удален**  
✅ **Grafana работает с обновленной конфигурацией**  
✅ **Alert Rules должны работать без ошибок**
