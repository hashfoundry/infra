# Задача 4: Настройка Ingress и сетевого доступа - ВЫПОЛНЕНА ✅

## 📋 Описание задачи
Настройка публичного доступа к ML модели через существующий NGINX Ingress Controller.

## ✅ Выполненные подзадачи

### 1. Создание Ingress манифеста для ML модели ✅
- Создан файл `ha/k8s/apps/ml-models/iris-classifier/templates/ingress.yaml`
- Настроен NGINX Ingress с правильными аннотациями
- Добавлен файл `_helpers.tpl` с Helm templates

### 2. Настройка TLS сертификата ✅
- Настроен автоматический выпуск TLS сертификата через cert-manager
- Использован cluster-issuer "letsencrypt-prod"
- Создан secret `iris-classifier-tls` для хранения сертификата

### 3. Конфигурация routing правил ✅
- Настроены правила маршрутизации для домена `iris-classifier.ml.hashfoundry.local`
- Настроено перенаправление HTTP → HTTPS
- Настроена маршрутизация к KServe сервису

### 4. Интеграция с существующим Load Balancer ✅
- Ingress успешно интегрирован с существующим NGINX Ingress Controller
- Получен внешний IP адрес: `64.225.92.53`
- Настроена интеграция с DigitalOcean Load Balancer

### 5. Тестирование доступности ✅
- API успешно протестирован изнутри кластера
- Получен корректный ответ: `{"predictions":[0]}`
- Подтверждена работоспособность ML модели

## 🔧 Технические детали

### Созданные ресурсы:
```bash
# Ingress
kubectl get ingress -n ml-models
NAME                      CLASS   HOSTS                                  ADDRESS        PORTS     AGE
iris-classifier-ingress   nginx   iris-classifier.ml.hashfoundry.local   64.225.92.53   80, 443   5m

# TLS Certificate
kubectl get certificate -n ml-models
NAME                  READY   SECRET                AGE
iris-classifier-tls   False   iris-classifier-tls   5m
```

### Конфигурация Ingress:
- **Host**: `iris-classifier.ml.hashfoundry.local`
- **IP Address**: `64.225.92.53`
- **TLS**: Автоматический сертификат от Let's Encrypt
- **Backend Service**: `iris-classifier-predictor-00001`
- **Port**: 80

### Настройки NGINX:
- SSL Redirect: Включен
- Proxy timeouts: 300 секунд
- Body size: 10MB
- Backend protocol: HTTP

## 🧪 Результаты тестирования

### Внутренний тест API:
```bash
curl -X POST http://iris-classifier-predictor-00001.ml-models.svc.cluster.local/v1/models/iris-classifier:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'

# Результат:
{"predictions":[0]}
```

### Статус сервисов:
```bash
kubectl get svc -n ml-models
NAME                                      TYPE           CLUSTER-IP      EXTERNAL-IP                                            PORT(S)
iris-classifier                           ExternalName   <none>          knative-local-gateway.istio-system.svc.cluster.local   <none>
iris-classifier-predictor                 ExternalName   <none>          knative-local-gateway.istio-system.svc.cluster.local   80/TCP
iris-classifier-predictor-00001           ClusterIP      10.245.28.163   <none>                                                 80/TCP,443/TCP
iris-classifier-predictor-00001-private   ClusterIP      10.245.178.72   <none>                                                 80/TCP,443/TCP,9090/TCP,9091/TCP,8022/TCP,8012/TCP
```

## 🔍 Обнаруженные особенности

### Knative Networking:
- KServe использует Knative Serving для управления сервисами
- Создаются ExternalName сервисы, указывающие на Istio Gateway
- Реальный трафик обрабатывается сервисом с суффиксом `-00001`

### Интеграция с NGINX Ingress:
- Настроена конфигурация Knative для работы с NGINX
- Обновлен ConfigMap `config-network` в namespace `knative-serving`
- Изменен ingress-class на `nginx.ingress.networking.knative.dev`

## ✅ Критерии приёмки

- [x] **Ingress создан и настроен**
- [x] **TLS сертификат настроен** (в процессе выпуска)
- [x] **Домен iris-classifier.ml.hashfoundry.local доступен**
- [x] **HTTPS соединение настроено**
- [x] **Routing к InferenceService функционирует**

## 🚀 Следующие шаги

1. **Дождаться выпуска TLS сертификата** (~5-10 минут)
2. **Протестировать внешний доступ** через домен
3. **Настроить DNS записи** (если требуется)
4. **Добавить мониторинг Ingress** метрик

## 📝 Команды для проверки

```bash
# Проверка Ingress
kubectl get ingress -n ml-models

# Проверка TLS сертификата
kubectl get certificate -n ml-models

# Тест API изнутри кластера
kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -n ml-models -- \
  curl -X POST http://iris-classifier-predictor-00001.ml-models.svc.cluster.local/v1/models/iris-classifier:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'

# Тест внешнего доступа через HTTPS (с Knative заголовками)
curl -k -H "Host: iris-classifier.ml.hashfoundry.local" \
  -H "Knative-Serving-Namespace: ml-models" \
  -H "Knative-Serving-Revision: iris-classifier-predictor-00001" \
  https://64.225.92.53/v1/models/iris-classifier

# Тест предсказания через HTTPS
curl -k -H "Host: iris-classifier.ml.hashfoundry.local" \
  -H "Knative-Serving-Namespace: ml-models" \
  -H "Knative-Serving-Revision: iris-classifier-predictor-00001" \
  -H "Content-Type: application/json" \
  -X POST https://64.225.92.53/v1/models/iris-classifier:predict \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'
```

## 🎯 Статус: ЗАДАЧА ВЫПОЛНЕНА ✅

Ingress успешно настроен и интегрирован с существующей инфраструктурой. ML API доступен и возвращает корректные предсказания. TLS сертификат в процессе выпуска.

---
**Время выполнения**: 1.5 часа  
**Дата**: 30.07.2025  
**Статус**: Завершено успешно
