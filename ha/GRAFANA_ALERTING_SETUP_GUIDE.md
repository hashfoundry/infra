# Grafana Alerting Setup Guide

## 🎯 **Обзор**
Пошаговое руководство по настройке алертов в Grafana через веб-интерфейс, поскольку Helm chart не поддерживает декларативную конфигурацию алертов.

## 🔐 **Доступ к Grafana**

### **Через Ingress (рекомендуется):**
```bash
# Добавить в /etc/hosts
echo "129.212.169.0 grafana.hashfoundry.local" >> /etc/hosts

# Открыть в браузере
https://grafana.hashfoundry.local
```

### **Через Port-Forward:**
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# Открыть: http://localhost:3000
```

### **Учетные данные:**
- **Username**: `admin`
- **Password**: `admin`

## 📊 **Шаг 1: Проверка Data Sources**

1. Войти в Grafana UI
2. Перейти в **Configuration** → **Data Sources**
3. Убедиться, что Prometheus настроен:
   - **Name**: Prometheus
   - **URL**: `http://prometheus-server.monitoring.svc.cluster.local`
   - **Access**: Server (default)

## 🚨 **Шаг 2: Настройка Contact Points**

### **2.1 Создание Email Contact Point:**
1. Перейти в **Alerting** → **Contact points**
2. Нажать **New contact point**
3. Заполнить:
   - **Name**: `email-alerts`
   - **Contact point type**: `Email`
   - **Addresses**: `admin@hashfoundry.local`
   - **Subject**: `🚨 Grafana Alert: {{ .GroupLabels.alertname }}`
   - **Message**: 
     ```
     {{ range .Alerts }}
     Alert: {{ .Annotations.summary }}
     Description: {{ .Annotations.description }}
     Status: {{ .Status }}
     Severity: {{ .Labels.severity }}
     {{ end }}
     ```
4. Нажать **Save contact point**

### **2.2 Создание Slack Contact Point (опционально):**
1. Нажать **New contact point**
2. Заполнить:
   - **Name**: `slack-alerts`
   - **Contact point type**: `Slack`
   - **Webhook URL**: `YOUR_SLACK_WEBHOOK_URL`
   - **Channel**: `#alerts`
   - **Title**: `🚨 Grafana Alert`
   - **Text**: 
     ```
     {{ range .Alerts }}
     Alert: {{ .Annotations.summary }}
     Description: {{ .Annotations.description }}
     {{ end }}
     ```
3. Нажать **Save contact point**

## 📋 **Шаг 3: Настройка Notification Policies**

1. Перейти в **Alerting** → **Notification policies**
2. Нажать **Edit** на Default policy
3. Настроить:
   - **Contact point**: `email-alerts`
   - **Group by**: `alertname`
   - **Group wait**: `10s`
   - **Group interval**: `5m`
   - **Repeat interval**: `12h`

### **3.1 Добавление политики для критических алертов:**
1. Нажать **Add nested policy**
2. Настроить:
   - **Matching labels**: `severity = critical`
   - **Contact point**: `email-alerts`
   - **Group wait**: `5s`
   - **Group interval**: `2m`
   - **Repeat interval**: `6h`

### **3.2 Добавление политики для предупреждений:**
1. Нажать **Add nested policy**
2. Настроить:
   - **Matching labels**: `severity = warning`
   - **Contact point**: `slack-alerts` (если настроен)
   - **Group wait**: `10s`
   - **Group interval**: `5m`
   - **Repeat interval**: `1h`

## ⚠️ **Шаг 4: Создание Alert Rules**

### **4.1 Node Down Alert:**
1. Перейти в **Alerting** → **Alert rules**
2. Нажать **New rule**
3. Заполнить:
   - **Rule name**: `Node Down`
   - **Folder**: `Kubernetes` (создать если нет)
   - **Query A**: 
     - **Data source**: Prometheus
     - **Query**: `up{job="kubernetes-nodes"} == 0`
   - **Condition**: `IS BELOW 1`
   - **Evaluation**: 
     - **For**: `5m`
     - **Evaluate every**: `1m`
   - **Labels**:
     - `severity`: `critical`
   - **Annotations**:
     - `summary`: `Node {{ $labels.instance }} is down`
     - `description`: `Node {{ $labels.instance }} has been down for more than 5 minutes`
4. Нажать **Save rule and exit**

### **4.2 High CPU Usage Alert:**
1. Нажать **New rule**
2. Заполнить:
   - **Rule name**: `High CPU Usage`
   - **Folder**: `Kubernetes`
   - **Query A**: 
     - **Data source**: Prometheus
     - **Query**: `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - **Condition**: `IS ABOVE 80`
   - **Evaluation**: 
     - **For**: `5m`
     - **Evaluate every**: `1m`
   - **Labels**:
     - `severity`: `warning`
   - **Annotations**:
     - `summary`: `High CPU usage on {{ $labels.instance }}`
     - `description`: `CPU usage is above 80% for more than 5 minutes`
3. Нажать **Save rule and exit**

### **4.3 High Memory Usage Alert:**
1. Нажать **New rule**
2. Заполнить:
   - **Rule name**: `High Memory Usage`
   - **Folder**: `Kubernetes`
   - **Query A**: 
     - **Data source**: Prometheus
     - **Query**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
   - **Condition**: `IS ABOVE 90`
   - **Evaluation**: 
     - **For**: `5m`
     - **Evaluate every**: `1m`
   - **Labels**:
     - `severity`: `critical`
   - **Annotations**:
     - `summary`: `High memory usage on {{ $labels.instance }}`
     - `description`: `Memory usage is above 90% for more than 5 minutes`
3. Нажать **Save rule and exit**

### **4.4 Low Disk Space Alert:**
1. Нажать **New rule**
2. Заполнить:
   - **Rule name**: `Low Disk Space`
   - **Folder**: `Kubernetes`
   - **Query A**: 
     - **Data source**: Prometheus
     - **Query**: `(1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100`
   - **Condition**: `IS ABOVE 85`
   - **Evaluation**: 
     - **For**: `5m`
     - **Evaluate every**: `1m`
   - **Labels**:
     - `severity`: `warning`
   - **Annotations**:
     - `summary`: `Low disk space on {{ $labels.instance }}`
     - `description`: `Disk usage is above 85% on {{ $labels.mountpoint }}`
3. Нажать **Save rule and exit**

### **4.5 ArgoCD Application Not Synced:**
1. Нажать **New rule**
2. Заполнить:
   - **Rule name**: `ArgoCD Application Not Synced`
   - **Folder**: `ArgoCD` (создать если нет)
   - **Query A**: 
     - **Data source**: Prometheus
     - **Query**: `argocd_app_info{sync_status!="Synced"}`
   - **Condition**: `IS ABOVE 0`
   - **Evaluation**: 
     - **For**: `15m`
     - **Evaluate every**: `1m`
   - **Labels**:
     - `severity`: `warning`
   - **Annotations**:
     - `summary`: `ArgoCD application {{ $labels.name }} not synced`
     - `description`: `Application {{ $labels.name }} in project {{ $labels.project }} is not synced for more than 15 minutes`
3. Нажать **Save rule and exit**

### **4.6 ArgoCD Application Unhealthy:**
1. Нажать **New rule**
2. Заполнить:
   - **Rule name**: `ArgoCD Application Unhealthy`
   - **Folder**: `ArgoCD`
   - **Query A**: 
     - **Data source**: Prometheus
     - **Query**: `argocd_app_info{health_status!="Healthy"}`
   - **Condition**: `IS ABOVE 0`
   - **Evaluation**: 
     - **For**: `10m`
     - **Evaluate every**: `1m`
   - **Labels**:
     - `severity`: `critical`
   - **Annotations**:
     - `summary`: `ArgoCD application {{ $labels.name }} unhealthy`
     - `description`: `Application {{ $labels.name }} in project {{ $labels.project }} is unhealthy`
3. Нажать **Save rule and exit**

## 🧪 **Шаг 5: Тестирование алертов**

### **5.1 Создание тестового алерта:**
```bash
# Создание пода с высоким потреблением CPU
cat > test-high-cpu.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress-test
  namespace: default
spec:
  containers:
  - name: cpu-stress
    image: progrium/stress
    args: ["--cpu", "2", "--timeout", "300s"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 2000m
        memory: 256Mi
EOF

kubectl apply -f test-high-cpu.yaml
```

### **5.2 Проверка срабатывания алерта:**
1. Подождать 5-10 минут
2. Перейти в **Alerting** → **Alert rules**
3. Проверить статус правила **High CPU Usage**
4. Проверить **Alerting** → **Alerts** для активных алертов

### **5.3 Очистка тестового пода:**
```bash
kubectl delete -f test-high-cpu.yaml
rm test-high-cpu.yaml
```

## 📧 **Шаг 6: Настройка SMTP (опционально)**

Для отправки email уведомлений нужно настроить SMTP:

### **6.1 Обновление Grafana конфигурации:**
```bash
# Редактировать values.yaml
cd ha/k8s/addons/monitoring/grafana
```

Добавить в `grafana.ini`:
```yaml
grafana.ini:
  smtp:
    enabled: true
    host: smtp.gmail.com:587
    user: your-email@gmail.com
    password: your-app-password
    from_address: your-email@gmail.com
    from_name: Grafana HashFoundry
```

### **6.2 Обновление Grafana:**
```bash
make upgrade
```

## 📊 **Шаг 7: Проверка статуса алертов**

### **7.1 Через Grafana UI:**
1. **Alerting** → **Alert rules** - список всех правил
2. **Alerting** → **Alerts** - активные алерты
3. **Alerting** → **Silences** - заглушенные алерты
4. **Alerting** → **Contact points** - точки контакта
5. **Alerting** → **Notification policies** - политики уведомлений

### **7.2 Через API:**
```bash
# Получение всех алертов
curl -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v1/alerts

# Получение правил алертов
curl -u admin:admin http://localhost:3000/api/ruler/grafana/api/v1/rules
```

## 🔧 **Troubleshooting**

### **Алерты не срабатывают:**
1. Проверить Data Source Prometheus
2. Проверить Query в правиле алерта
3. Проверить Evaluation настройки
4. Проверить логи Grafana: `kubectl logs -n monitoring -l app.kubernetes.io/name=grafana`

### **Уведомления не приходят:**
1. Проверить Contact Points
2. Проверить Notification Policies
3. Проверить SMTP настройки (если используется email)
4. Проверить Webhook URL (если используется Slack)

### **Полезные команды:**
```bash
# Проверка статуса Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Логи Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100

# Port-forward для доступа
kubectl port-forward -n monitoring svc/grafana 3000:80

# Проверка конфигурации
kubectl get configmap -n monitoring grafana -o yaml
```

## 📋 **Итоговый чеклист**

### **✅ Настройка завершена:**
- [ ] Grafana доступна через Ingress
- [ ] Data Source Prometheus настроен
- [ ] Contact Points созданы
- [ ] Notification Policies настроены
- [ ] Alert Rules созданы:
  - [ ] Node Down
  - [ ] High CPU Usage
  - [ ] High Memory Usage
  - [ ] Low Disk Space
  - [ ] ArgoCD Application Not Synced
  - [ ] ArgoCD Application Unhealthy
- [ ] Тестирование алертов проведено
- [ ] SMTP настроен (опционально)

### **🎯 Результат:**
Полноценная система алертов в Grafana готова к production использованию с:
- ✅ **Мониторинг инфраструктуры** (CPU, Memory, Disk, Nodes)
- ✅ **Мониторинг ArgoCD** (приложения и их статус)
- ✅ **Уведомления** через Email/Slack
- ✅ **Гибкие политики** для разных типов алертов
- ✅ **Тестирование** и troubleshooting

---

**Дата создания**: 16.07.2025  
**Версия**: 1.0.0  
**Статус**: ✅ Production Ready
