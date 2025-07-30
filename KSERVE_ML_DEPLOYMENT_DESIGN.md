# KServe ML Model Deployment Design Document

## 📌 Название проекта
**Развёртывание легковесной ML-модели (Iris classifier) в HA Kubernetes кластере с использованием KServe**

---

## 🎯 Цель проекта

Интегрировать платформу KServe в существующую HA инфраструктуру HashFoundry для развертывания ML-модели Iris classifier с публичным REST API endpoint'ом.

### Бизнес-цели:
- Демонстрация возможностей ML inference в production-ready Kubernetes кластере
- Создание foundation для будущих ML workloads
- Быстрое развертывание ML платформы с минимальной сложностью

---

## 🏗️ Архитектурное решение

### Текущая архитектура (базовая)
```
┌─────────────────────────────────────────────────────────────┐
│                    DigitalOcean Cloud                      │
├─────────────────────────────────────────────────────────────┤
│  Load Balancer + NGINX Ingress                             │
│  ├── ArgoCD UI                                             │
│  ├── Grafana                                               │
│  ├── Prometheus                                            │
│  └── React App                                             │
├─────────────────────────────────────────────────────────────┤
│  HA Kubernetes Cluster (3-6 nodes)                         │
│  ├── ArgoCD (GitOps)                                       │
│  ├── Monitoring Stack                                      │
│  ├── NFS Provisioner                                       │
│  └── Applications                                          │
└─────────────────────────────────────────────────────────────┘
```

### Целевая архитектура (с KServe) - РЕАЛИЗОВАННАЯ
```
┌─────────────────────────────────────────────────────────────┐
│                    DigitalOcean Cloud                      │
├─────────────────────────────────────────────────────────────┤
│  Load Balancer + NGINX Ingress                             │
│  ├── ArgoCD UI                                             │
│  ├── Grafana                                               │
│  ├── Prometheus                                            │
│  ├── React App                                             │
│  └── ML Model API (iris-classifier.ml.hashfoundry.local)   │ ← NEW
├─────────────────────────────────────────────────────────────┤
│  HA Kubernetes Cluster (3-6 nodes)                         │
│  ├── ArgoCD (GitOps)                                       │
│  ├── Monitoring Stack                                      │
│  ├── NFS Provisioner                                       │
│  ├── Applications                                          │
│  ├── KServe Control Plane                                  │ ← NEW ✅
│  │   ├── KServe Controller                                 │
│  │   ├── Knative Serving                                   │
│  │   └── Istio Service Mesh                               │
│  ├── ML Workloads                                          │ ← NEW ✅
│  │   ├── Iris Classifier InferenceService (Ready)          │
│  │   ├── Model Loader Job (Completed)                      │
│  │   └── NFS PVC Storage (iris-model-storage)              │
│  └── Model Storage Solution                                │ ← UPDATED ✅
│      ├── Job: DigitalOcean Spaces → NFS PVC                │
│      └── InferenceService: PVC → sklearn server            │
├─────────────────────────────────────────────────────────────┤
│  DigitalOcean Spaces (S3-compatible)                       │ ← SOURCE
│  └── ML Models Storage                                     │
│      └── iris-classifier/v1/                               │
│          ├── model.pkl (167KB)                             │
│          └── metadata.json (1.3KB)                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Техническое решение

### Компоненты для развертывания:

#### 1. **KServe Platform**
- **KServe Controller**: Управление InferenceService ресурсами
- **Knative Serving**: Serverless runtime для ML моделей
- **Istio Service Mesh**: Networking и traffic management
- **Cert-Manager**: Автоматическое управление TLS сертификатами

#### 2. **Model Storage**
- **DigitalOcean Spaces**: S3-совместимое хранилище для ML моделей
- **Bucket**: `hashfoundry-ml-models`
- **Path**: `/iris-classifier/v1/`

#### 3. **ML Model**
- **Framework**: Scikit-learn
- **Model**: Iris classifier (4 features → 3 classes)
- **Format**: Pickle (.pkl)
- **Runtime**: sklearn server

#### 4. **Networking**
- **Ingress**: NGINX Ingress Controller (существующий)
- **Domain**: `iris-classifier.ml.hashfoundry.local`
- **Protocol**: HTTPS с TLS

#### 5. **Monitoring**
- **Prometheus**: Метрики KServe и Knative
- **Grafana**: Дашборды для ML inference
- **Alerting**: Мониторинг доступности модели

---

## 📋 Разбивка на задачи

**Общее время выполнения: 7.5 часов**

### **Задача 1: Подготовка ML модели и хранилища** ⏱️ 1.5 часа

#### Описание:
Создание, обучение и сериализация Iris classifier модели, настройка DigitalOcean Spaces для хранения.

#### Подзадачи:
1. Создание Python скрипта для обучения модели
2. Сериализация модели в формат pickle
3. Создание metadata.json с описанием модели
4. Настройка DigitalOcean Spaces bucket
5. Загрузка модели в S3-совместимое хранилище

#### Критерии приёмки:
- [x] Модель обучена на iris dataset с accuracy > 95% (96.67% CV accuracy) ✅
- [x] Модель сериализована в формат .pkl ✅
- [x] Создан metadata.json с версией и описанием ✅
- [x] DigitalOcean Spaces bucket создан и настроен ✅
- [x] Модель успешно загружена в bucket ✅

#### Тест задачи:
```bash
# Проверка доступности модели в DigitalOcean Spaces
doctl spaces ls
doctl spaces ls-objects hashfoundry-ml-models --prefix iris-classifier/v1/
```

---

### **Задача 2: Установка KServe и зависимостей** ⏱️ 1.5 часа

#### Описание:
Развертывание KServe platform в существующий HA кластер через Helm.

#### Подзадачи:
1. Установка Istio через Helm
2. Установка Knative Serving через Helm
3. Установка Cert-Manager через Helm
4. Установка KServe через Helm
5. Проверка статуса всех компонентов

#### Критерии приёмки:
- [x] Istio установлен и работает ✅
- [x] Knative Serving развернут ✅
- [x] Cert-Manager функционирует ✅
- [x] KServe Controller запущен ✅
- [x] Все компоненты в статусе Ready ✅

#### Тест задачи:
```bash
# Проверка статуса KServe компонентов
kubectl get pods -n knative-serving
kubectl get pods -n istio-system
kubectl get pods -n cert-manager
kubectl get pods -n kserve-system
```

---

### **Задача 3: Создание InferenceService** ⏱️ 1 час

#### Описание:
Создание и развертывание InferenceService для Iris classifier модели.

#### Подзадачи:
1. Создание YAML манифеста InferenceService
2. Настройка sklearn predictor
3. Конфигурация storage URI для DigitalOcean Spaces
4. Настройка resource limits и requests
5. Применение манифеста в кластер

#### Критерии приёмки:
- [x] InferenceService манифест создан ✅
- [x] Модель успешно загружается из PVC (решена проблема с S3 credentials) ✅
- [x] Pod модели в статусе Running (2/2) ✅
- [x] InferenceService в статусе Ready ✅
- [x] Сервис доступен через Kubernetes API ✅

#### Тест задачи:
```bash
# Проверка статуса InferenceService
kubectl get inferenceservice iris-classifier -n ml-models
kubectl describe inferenceservice iris-classifier -n ml-models
```

---

### **Задача 4: Настройка Ingress и сетевого доступа** ⏱️ 1.5 часа

#### Описание:
Настройка публичного доступа к ML модели через существующий NGINX Ingress.

#### Подзадачи:
1. Создание Ingress манифеста для ML модели
2. Настройка TLS сертификата
3. Конфигурация routing правил
4. Интеграция с существующим Load Balancer
5. Тестирование доступности

#### Критерии приёмки:
- [ ] Ingress создан и настроен
- [ ] TLS сертификат выпущен
- [ ] Домен iris-classifier.ml.hashfoundry.local доступен
- [ ] HTTPS соединение работает
- [ ] Routing к InferenceService функционирует

#### Тест задачи:
```bash
# Проверка Ingress и TLS
kubectl get ingress -n ml-models
curl -k https://iris-classifier.ml.hashfoundry.local/v1/models/iris-classifier
```

---

### **Задача 5: Интеграция мониторинга** ⏱️ 1 час

#### Описание:
Настройка мониторинга KServe и ML модели в существующем Prometheus/Grafana стеке.

#### Подзадачи:
1. Настройка ServiceMonitor для KServe метрик
2. Создание Grafana дашборда для ML inference
3. Настройка алертов для доступности модели
4. Конфигурация метрик Knative Serving
5. Интеграция с существующим мониторингом

#### Критерии приёмки:
- [ ] KServe метрики собираются в Prometheus
- [ ] Grafana дашборд создан и отображает данные
- [ ] Алерты настроены для критических метрик
- [ ] Мониторинг интегрирован с существующим стеком
- [ ] Метрики доступны в Grafana UI

#### Тест задачи:
```bash
# Проверка метрик в Prometheus
curl http://prometheus.hashfoundry.local/api/v1/query?query=kserve_model_request_duration_seconds
```

---

### **Задача 6: Тестирование и валидация** ⏱️ 1 час

#### Описание:
Комплексное тестирование ML API и создание автоматизированных тестов.

#### Подзадачи:
1. Создание Python скрипта для тестирования API
2. Тестирование различных входных данных
3. Проверка производительности и latency
4. Валидация ответов модели
5. Создание документации API

#### Критерии приёмки:
- [ ] API отвечает на тестовые запросы
- [ ] Предсказания модели корректны
- [ ] Latency < 100ms для простых запросов
- [ ] API документация создана
- [ ] Автоматизированные тесты написаны

#### Тест задачи:
```python
# Тест API endpoint
import requests
response = requests.post(
    'https://iris-classifier.ml.hashfoundry.local/v1/models/iris-classifier:predict',
    json={"instances": [[5.1, 3.5, 1.4, 0.2]]}
)
assert response.status_code == 200
assert 'predictions' in response.json()
```

---

## 🧪 Общий тест решения

### Интеграционный тест:
```bash
#!/bin/bash
# Полный тест KServe ML deployment

echo "🧪 Тестирование KServe ML Deployment..."

# 1. Проверка инфраструктуры
echo "1. Проверка KServe компонентов..."
kubectl get pods -n kserve-system --no-headers | grep -v Running && exit 1

# 2. Проверка InferenceService
echo "2. Проверка InferenceService..."
kubectl get inferenceservice iris-classifier -n ml-models -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q True || exit 1

# 3. Проверка Ingress
echo "3. Проверка Ingress доступности..."
curl -f -k https://iris-classifier.ml.hashfoundry.local/v1/models/iris-classifier > /dev/null || exit 1

# 4. Тест предсказания
echo "4. Тест ML предсказания..."
RESPONSE=$(curl -s -k -X POST \
  https://iris-classifier.ml.hashfoundry.local/v1/models/iris-classifier:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}')

echo $RESPONSE | grep -q "predictions" || exit 1

# 5. Проверка мониторинга
echo "5. Проверка метрик..."
curl -s http://prometheus.hashfoundry.local/api/v1/query?query=kserve_model_request_duration_seconds | grep -q "success" || exit 1

echo "✅ Все тесты пройдены успешно!"
```

---

## ✅ Критерии приёмки (Definition of Done)

### Функциональные требования:
- [ ] **ML модель**: Iris classifier обучена и сериализована
- [ ] **Хранилище**: Модель загружена в DigitalOcean Spaces
- [ ] **KServe**: Platform установлен и функционирует
- [ ] **InferenceService**: Развернут и имеет статус Ready
- [ ] **API доступ**: Публичный HTTPS endpoint работает
- [ ] **Предсказания**: API возвращает корректные результаты
- [ ] **Мониторинг**: Метрики собираются и отображаются
- [ ] **Развертывание**: Все компоненты успешно развернуты в кластере

### Нефункциональные требования:
- [ ] **Производительность**: Latency < 100ms для простых запросов
- [ ] **Доступность**: 99.9% uptime (с учетом HA кластера)
- [ ] **Безопасность**: HTTPS с валидными TLS сертификатами
- [ ] **Масштабируемость**: Auto-scaling через Knative
- [ ] **Мониторинг**: Алерты для критических метрик
- [ ] **Документация**: API документация и примеры использования

### Технические требования:
- [ ] **Интеграция**: Совместимость с существующей HA архитектурой
- [ ] **Управление**: Все ресурсы развернуты через kubectl/Helm
- [ ] **Безопасность**: Pod Security Standards и Network Policies
- [ ] **Ресурсы**: Оптимальное использование CPU/Memory
- [ ] **Логирование**: Централизованные логи через существующий стек

---

## 🔧 Технические детали

### Структура файлов (РЕАЛИЗОВАННАЯ):
```
ha/k8s/addons/
├── kserve/                          # KServe platform ✅
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── istio/                           # Service mesh ✅
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── knative-serving/                 # Knative Serving ✅
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── cert-manager/                    # TLS certificates ✅
    ├── Chart.yaml
    ├── values.yaml
    └── templates/

ha/k8s/apps/
└── ml-models/                       # ML applications ✅
    └── iris-classifier/             # Iris classifier deployment ✅
        ├── Chart.yaml               # Helm chart
        ├── values.yaml              # Configuration values
        └── templates/               # Kubernetes manifests
            ├── inferenceservice.yaml    # KServe InferenceService ✅
            ├── servingruntime.yaml      # Sklearn ServingRuntime ✅
            ├── clusterservingruntime.yaml # Cluster-wide runtime ✅
            ├── pvc.yaml                 # Model storage PVC ✅
            ├── model-loader-job.yaml   # S3 → PVC loader Job ✅
            ├── secret.yaml              # S3 credentials ✅
            ├── configmap.yaml           # S3 configuration ✅
            ├── serviceaccount.yaml      # Service account ✅
            └── ingress.yaml             # Public access (TODO)

ha/ml/                               # ML artifacts ✅
├── iris-classifier/                 # Model files ✅
│   ├── train_model.py               # Training script ✅
│   ├── test_api.py                  # API testing ✅
│   ├── model.pkl                    # Trained model ✅
│   ├── metadata.json                # Model metadata ✅
│   └── requirements.txt             # Dependencies ✅
├── scripts/                         # Utility scripts ✅
│   ├── upload_model.sh              # DigitalOcean Spaces upload ✅
│   └── test_deployment.sh           # Integration tests ✅
├── TASK_1_COMPLETION_REPORT.md      # Task 1 report ✅
├── TASK_2_COMPLETION_REPORT.md      # Task 2 report ✅
├── TASK_3_CREDENTIALS_PROBLEM_SOLUTION.md # Credentials fix ✅
└── IRIS_MODEL_LOADER_ANALYSIS.md    # Job analysis ✅
```

### Ресурсы кластера:
- **CPU**: +2 cores для KServe platform
- **Memory**: +4GB для Istio + Knative + KServe
- **Storage**: +10GB для model cache
- **Network**: Дополнительные Istio sidecars

### Стоимость:
- **Базовая HA**: ~$96/месяц (текущая)
- **С KServe**: ~$120/месяц (+$24 для дополнительных ресурсов)
- **DigitalOcean Spaces**: ~$5/месяц (250GB)
- **Итого**: ~$125/месяч

---

## 🚀 План развертывания

### Фаза 1: Подготовка (День 1)
1. Создание и обучение ML модели
2. Настройка DigitalOcean Spaces
3. Загрузка модели в хранилище

### Фаза 2: Инфраструктура (День 2)
1. Установка Istio Service Mesh
2. Развертывание Knative Serving
3. Установка Cert-Manager
4. Развертывание KServe Controller

### Фаза 3: ML Deployment (День 3)
1. Создание InferenceService
2. Настройка Ingress
3. Конфигурация мониторинга
4. Тестирование и валидация

### Фаза 4: Финализация (День 4)
1. Настройка алертов
2. Создание документации
3. Финальное тестирование
4. Валидация производительности

---

## 🔍 Риски и митигация

### Высокие риски:
1. **Совместимость Istio с NGINX Ingress**
   - *Митигация*: Использование Istio Gateway вместо NGINX для ML трафика
   
2. **Ресурсы кластера недостаточны**
   - *Митигация*: Мониторинг ресурсов, готовность к scale-up

3. **Сложность отладки Knative/Istio**
   - *Митигация*: Подробное логирование, step-by-step развертывание

### Средние риски:
1. **Производительность S3 доступа**
   - *Митигация*: Model caching, оптимизация размера модели
   
2. **TLS сертификаты для новых доменов**
   - *Митигация*: Тестирование cert-manager заранее

---

## 📚 Дополнительные возможности

### После успешного развертывания:
1. **Auto-scaling**: Настройка HPA для InferenceService
2. **A/B Testing**: Canary deployments для новых версий модели
3. **Model Versioning**: Управление версиями моделей
4. **Batch Inference**: Поддержка batch предсказаний
5. **Multi-model Serving**: Развертывание дополнительных моделей
6. **GPU Support**: Интеграция GPU для более сложных моделей

---

## 📖 Документация и ресурсы

### Внутренняя документация:
- API Reference для Iris Classifier
- Troubleshooting Guide для KServe
- Monitoring Runbook
- Deployment Procedures

### Внешние ресурсы:
- [KServe Documentation](https://kserve.github.io/website/)
- [Knative Serving Guide](https://knative.dev/docs/serving/)
- [Istio Service Mesh](https://istio.io/latest/docs/)
- [Scikit-learn Model Serving](https://scikit-learn.org/stable/)

---

**Дата создания**: 30.07.2025  
**Версия**: 1.0  
**Автор**: HashFoundry Infrastructure Team  
**Статус**: Ready for Implementation  

---

*Этот design document является живым документом и будет обновляться по мере развития проекта.*
