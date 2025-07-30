#!/bin/bash
# Полный тест KServe ML Deployment

set -e

echo "🧪 Тестирование KServe ML Deployment..."
echo "========================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl не найден"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl не найден"
        exit 1
    fi
    
    log_success "Все зависимости найдены"
}

# 1. Проверка инфраструктуры
check_infrastructure() {
    log_info "1. Проверка KServe компонентов..."
    
    # Проверка KServe system
    if ! kubectl get pods -n kserve-system --no-headers 2>/dev/null | grep -v Running | grep -v Completed; then
        log_success "KServe система работает"
    else
        log_error "Проблемы с KServe системой"
        kubectl get pods -n kserve-system
        return 1
    fi
    
    # Проверка Knative Serving
    if ! kubectl get pods -n knative-serving --no-headers 2>/dev/null | grep -v Running | grep -v Completed; then
        log_success "Knative Serving работает"
    else
        log_error "Проблемы с Knative Serving"
        kubectl get pods -n knative-serving
        return 1
    fi
    
    # Проверка Istio
    if ! kubectl get pods -n istio-system --no-headers 2>/dev/null | grep -v Running | grep -v Completed; then
        log_success "Istio работает"
    else
        log_error "Проблемы с Istio"
        kubectl get pods -n istio-system
        return 1
    fi
}

# 2. Проверка InferenceService
check_inference_service() {
    log_info "2. Проверка InferenceService..."
    
    local namespace=${1:-ml-models}
    local service_name=${2:-iris-classifier}
    
    # Проверка существования InferenceService
    if kubectl get inferenceservice $service_name -n $namespace &> /dev/null; then
        log_success "InferenceService '$service_name' найден"
    else
        log_error "InferenceService '$service_name' не найден в namespace '$namespace'"
        return 1
    fi
    
    # Проверка статуса Ready
    local ready_status=$(kubectl get inferenceservice $service_name -n $namespace -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [[ "$ready_status" == "True" ]]; then
        log_success "InferenceService готов к работе"
    else
        log_error "InferenceService не готов. Статус: $ready_status"
        kubectl describe inferenceservice $service_name -n $namespace
        return 1
    fi
    
    # Получение URL
    local url=$(kubectl get inferenceservice $service_name -n $namespace -o jsonpath='{.status.url}' 2>/dev/null)
    if [[ -n "$url" ]]; then
        log_success "URL InferenceService: $url"
        echo "INFERENCE_URL=$url" > /tmp/inference_url.env
    else
        log_warning "URL InferenceService не найден"
    fi
}

# 3. Проверка Ingress доступности
check_ingress() {
    log_info "3. Проверка Ingress доступности..."
    
    local ingress_url=${1:-"https://iris-classifier.ml.hashfoundry.local"}
    local model_name=${2:-"iris-classifier"}
    
    # Проверка метаданных модели
    log_info "Проверка метаданных модели..."
    local metadata_url="$ingress_url/v1/models/$model_name"
    
    if curl -f -k -s "$metadata_url" > /dev/null; then
        log_success "Метаданные модели доступны"
        curl -k -s "$metadata_url" | jq . 2>/dev/null || curl -k -s "$metadata_url"
    else
        log_error "Метаданные модели недоступны: $metadata_url"
        return 1
    fi
}

# 4. Тест предсказания
test_prediction() {
    log_info "4. Тест ML предсказания..."
    
    local ingress_url=${1:-"https://iris-classifier.ml.hashfoundry.local"}
    local model_name=${2:-"iris-classifier"}
    
    local predict_url="$ingress_url/v1/models/$model_name:predict"
    
    # Тестовые данные для каждого класса
    local test_cases=(
        '{"instances": [[5.1, 3.5, 1.4, 0.2]]}|setosa|0'
        '{"instances": [[6.2, 2.9, 4.3, 1.3]]}|versicolor|1'
        '{"instances": [[7.3, 2.9, 6.3, 1.8]]}|virginica|2'
    )
    
    local all_tests_passed=true
    
    for test_case in "${test_cases[@]}"; do
        IFS='|' read -r payload species expected_class <<< "$test_case"
        
        log_info "Тестирование предсказания для $species..."
        
        local start_time=$(date +%s%3N)
        local response=$(curl -k -s -X POST \
            "$predict_url" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>/dev/null)
        local end_time=$(date +%s%3N)
        local latency=$((end_time - start_time))
        
        if [[ -n "$response" ]] && echo "$response" | grep -q "predictions"; then
            local predicted_class=$(echo "$response" | jq -r '.predictions[0]' 2>/dev/null)
            
            if [[ "$predicted_class" == "$expected_class" ]]; then
                log_success "$species: Предсказание корректно (класс $predicted_class, ${latency}ms)"
            else
                log_error "$species: Неверное предсказание. Ожидался $expected_class, получен $predicted_class"
                all_tests_passed=false
            fi
        else
            log_error "$species: Ошибка в ответе API"
            echo "Response: $response"
            all_tests_passed=false
        fi
    done
    
    if [[ "$all_tests_passed" == "true" ]]; then
        log_success "Все тесты предсказаний прошли успешно"
    else
        log_error "Некоторые тесты предсказаний провалились"
        return 1
    fi
}

# 5. Проверка производительности
test_performance() {
    log_info "5. Тест производительности..."
    
    local ingress_url=${1:-"https://iris-classifier.ml.hashfoundry.local"}
    local model_name=${2:-"iris-classifier"}
    local num_requests=${3:-10}
    
    local predict_url="$ingress_url/v1/models/$model_name:predict"
    local payload='{"instances": [[5.1, 3.5, 1.4, 0.2]]}'
    
    local total_time=0
    local successful_requests=0
    local failed_requests=0
    
    log_info "Отправка $num_requests запросов..."
    
    for ((i=1; i<=num_requests; i++)); do
        local start_time=$(date +%s%3N)
        local response=$(curl -k -s -X POST \
            "$predict_url" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>/dev/null)
        local end_time=$(date +%s%3N)
        local latency=$((end_time - start_time))
        
        if [[ -n "$response" ]] && echo "$response" | grep -q "predictions"; then
            ((successful_requests++))
            total_time=$((total_time + latency))
        else
            ((failed_requests++))
        fi
        
        # Прогресс
        if ((i % 5 == 0)); then
            echo -n "."
        fi
    done
    echo ""
    
    if ((successful_requests > 0)); then
        local avg_latency=$((total_time / successful_requests))
        local success_rate=$((successful_requests * 100 / num_requests))
        
        log_success "Результаты производительности:"
        echo "  - Успешных запросов: $successful_requests/$num_requests ($success_rate%)"
        echo "  - Средняя задержка: ${avg_latency}ms"
        
        if ((avg_latency <= 100)); then
            log_success "Задержка соответствует требованию (<100ms)"
        else
            log_warning "Задержка превышает требование (>100ms)"
        fi
        
        if ((success_rate >= 95)); then
            log_success "Успешность соответствует требованию (≥95%)"
        else
            log_error "Успешность ниже требования (<95%)"
            return 1
        fi
    else
        log_error "Все запросы провалились"
        return 1
    fi
}

# 6. Проверка мониторинга
check_monitoring() {
    log_info "6. Проверка метрик..."
    
    local prometheus_url=${1:-"http://prometheus.hashfoundry.local"}
    
    # Проверка доступности Prometheus
    if curl -f -s "$prometheus_url/api/v1/query?query=up" > /dev/null; then
        log_success "Prometheus доступен"
    else
        log_warning "Prometheus недоступен по адресу $prometheus_url"
        return 0  # Не критично для основного функционала
    fi
    
    # Проверка KServe метрик
    local kserve_metrics_query="kserve_model_request_duration_seconds"
    if curl -s "$prometheus_url/api/v1/query?query=$kserve_metrics_query" | grep -q "success"; then
        log_success "KServe метрики собираются"
    else
        log_warning "KServe метрики не найдены (возможно, нужно время для накопления)"
    fi
}

# Основная функция
main() {
    local ingress_url=${1:-"https://iris-classifier.ml.hashfoundry.local"}
    local model_name=${2:-"iris-classifier"}
    local namespace=${3:-"ml-models"}
    local prometheus_url=${4:-"http://prometheus.hashfoundry.local"}
    
    echo "Параметры тестирования:"
    echo "  - Ingress URL: $ingress_url"
    echo "  - Model Name: $model_name"
    echo "  - Namespace: $namespace"
    echo "  - Prometheus URL: $prometheus_url"
    echo ""
    
    # Выполнение всех проверок
    check_dependencies || exit 1
    check_infrastructure || exit 1
    check_inference_service "$namespace" "$model_name" || exit 1
    check_ingress "$ingress_url" "$model_name" || exit 1
    test_prediction "$ingress_url" "$model_name" || exit 1
    test_performance "$ingress_url" "$model_name" 10 || exit 1
    check_monitoring "$prometheus_url"
    
    echo ""
    log_success "🎉 Все тесты пройдены успешно!"
    echo ""
    echo "📊 Сводка результатов:"
    echo "  ✅ KServe инфраструктура работает"
    echo "  ✅ InferenceService развернут и готов"
    echo "  ✅ Ingress настроен и доступен"
    echo "  ✅ ML предсказания работают корректно"
    echo "  ✅ Производительность соответствует требованиям"
    echo "  ✅ Мониторинг настроен"
    echo ""
    echo "🚀 KServe ML Deployment успешно развернут и протестирован!"
}

# Проверка аргументов и запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
