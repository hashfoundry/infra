# High Availability Transformation Plan

## Текущее состояние

Конфигурация `ha/terraform/` в настоящее время представляет собой копию single-node конфигурации и создает:
- 1 узел Kubernetes кластера (`s-1vcpu-2gb`)
- Базовый node pool с `node_count = 1`
- Отсутствие резервирования и отказоустойчивости

## Цель преобразования

Создать минимально-необходимую High Availability конфигурацию, которая обеспечит:
- Отказоустойчивость на уровне узлов
- Распределение нагрузки
- Автоматическое восстановление
- Масштабируемость

## Ключевые изменения для HA

### 1. Архитектура узлов

#### Текущая конфигурация:
```hcl
node_pool {
  name       = "worker-pool"
  size       = "s-1vcpu-2gb"
  node_count = 1
  auto_scale = false
}
```

#### HA конфигурация (экономичный вариант):
```hcl
node_pool {
  name       = "ha-worker-pool"
  size       = "s-1vcpu-2gb"  # Те же ресурсы, что и single-node
  node_count = 3              # Минимум 3 узла для кворума
  auto_scale = true
  min_nodes  = 3
  max_nodes  = 6
}
```

#### HA конфигурация (рекомендуемый вариант):
```hcl
node_pool {
  name       = "ha-worker-pool"
  size       = "s-2vcpu-4gb"  # Увеличенные ресурсы для стабильности
  node_count = 3              # Минимум 3 узла для кворума
  auto_scale = true
  min_nodes  = 3
  max_nodes  = 6
}
```

**Обоснование:**
- **3 узла**: Минимальное количество для обеспечения кворума и отказоустойчивости
- **Auto-scaling**: Автоматическое масштабирование при увеличении нагрузки
- **Размер узлов**: 
  - `s-1vcpu-2gb` - экономичный вариант, подходит для легких нагрузок
  - `s-2vcpu-4gb` - рекомендуемый для production с запасом ресурсов

### 2. Переменные окружения

#### Новые переменные в `.env` (экономичный вариант):
```bash
# HA Configuration
CLUSTER_NAME=hashfoundry-ha
NODE_COUNT=3
NODE_SIZE=s-1vcpu-2gb  # Экономичный вариант
AUTO_SCALE_ENABLED=true
MIN_NODES=3
MAX_NODES=6

# HA-specific settings
ENABLE_HA_CONTROL_PLANE=true
ENABLE_MONITORING=true
ENABLE_BACKUP=true
```

#### Для рекомендуемого варианта:
```bash
# HA Configuration
CLUSTER_NAME=hashfoundry-ha
NODE_COUNT=3
NODE_SIZE=s-2vcpu-4gb  # Рекомендуемый вариант
AUTO_SCALE_ENABLED=true
MIN_NODES=3
MAX_NODES=6
```

### 3. Terraform переменные

#### Добавить в `variables.tf`:
```hcl
variable "auto_scale_enabled" {
  description = "Enable auto-scaling for the node pool"
  type        = bool
  default     = true
}

variable "min_nodes" {
  description = "Minimum number of nodes in the auto-scaling node pool"
  type        = number
  default     = 3
}

variable "max_nodes" {
  description = "Maximum number of nodes in the auto-scaling node pool"
  type        = number
  default     = 6
}

variable "enable_ha_control_plane" {
  description = "Enable HA control plane (managed by DigitalOcean)"
  type        = bool
  default     = true
}
```

### 4. Kubernetes кластер конфигурация

#### Обновить `kubernetes.tf`:
```hcl
resource "digitalocean_kubernetes_cluster" "kubernetes_cluster" {
  name    = var.cluster_name
  region  = var.cluster_region
  version = var.cluster_version
  
  # HA control plane автоматически включен в DigitalOcean для кластеров с 3+ узлами
  ha = var.enable_ha_control_plane

  node_pool {
    name       = var.node_pool_name
    size       = var.node_size
    node_count = var.node_count
    auto_scale = var.auto_scale_enabled
    min_nodes  = var.auto_scale_enabled ? var.min_nodes : null
    max_nodes  = var.auto_scale_enabled ? var.max_nodes : null
    
    # Распределение узлов по зонам доступности
    tags = ["ha", "production"]
  }

  # Дополнительный node pool для системных компонентов (опционально)
  node_pool {
    name       = "system-pool"
    size       = "s-1vcpu-2gb"
    node_count = 2
    auto_scale = false
    
    # Taints для системных подов
    taint {
      key    = "node-role"
      value  = "system"
      effect = "NoSchedule"
    }
    
    tags = ["system", "ha"]
  }

  depends_on = [digitalocean_project.hashfoundry]
}
```

### 5. Мониторинг и наблюдаемость

#### Добавить в `kubernetes.tf`:
```hcl
# Включить мониторинг кластера
resource "digitalocean_kubernetes_cluster" "kubernetes_cluster" {
  # ... существующая конфигурация ...
  
  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }
  
  # Автоматические обновления
  auto_upgrade = true
  surge_upgrade = true
}
```

### 6. Load Balancer управляется через ArgoCD

В HA конфигурации Load Balancer будет создаваться автоматически через NGINX Ingress Controller, управляемый ArgoCD, точно так же как в single-node конфигурации.

#### Преимущества ArgoCD подхода:
- **Автоматическое управление**: Load Balancer создается и настраивается автоматически
- **GitOps**: Все изменения отслеживаются в Git
- **Консистентность**: Та же схема, что и в single-node
- **Упрощение**: Не нужно дублировать логику в Terraform

#### Что будет развернуто через ArgoCD:
1. **NGINX Ingress Controller** - автоматически создает DigitalOcean Load Balancer
2. **ArgoCD Ingress** - для доступа к ArgoCD UI
3. **Application Ingresses** - для доступа к приложениям

#### Структура k8s/ для HA:
```
ha/k8s/
├── addons/
│   ├── argo-cd/           # ArgoCD Helm chart
│   ├── argo-cd-apps/      # ArgoCD Applications
│   ├── nginx-ingress/     # NGINX Ingress Controller
│   └── argocd-ingress/    # ArgoCD Ingress
└── apps/
    └── hashfoundry-react/ # React приложение
```

### 7. Outputs для HA

#### Обновить `outputs.tf`:
```hcl
output "ha_status" {
  description = "High Availability status of the cluster"
  value = {
    node_count     = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].actual_node_count
    auto_scale     = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].auto_scale
    min_nodes      = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].min_nodes
    max_nodes      = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].max_nodes
    ha_enabled     = digitalocean_kubernetes_cluster.kubernetes_cluster.ha
  }
}

# Load Balancer информация будет доступна через kubectl:
# kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

## Стоимостные соображения

### Single-node vs HA:
- **Single-node**: ~$12/месяц (1 узел s-1vcpu-2gb)
- **HA экономичный**: ~$36/месяц (3 узла s-1vcpu-2gb)
- **HA рекомендуемый**: ~$72/месяц (3 узла s-2vcpu-4gb + 2 системных узла)
- **Load Balancer**: +$12/месяц

### Сравнение вариантов HA:

#### Экономичный вариант (s-1vcpu-2gb):
- **Стоимость**: ~$48/месяц (включая LB)
- **Увеличение**: 4x от single-node
- **Подходит для**: dev/staging, легкие нагрузки
- **Ограничения**: может потребоваться больше узлов при росте нагрузки

#### Рекомендуемый вариант (s-2vcpu-4gb):
- **Стоимость**: ~$84/месяц (включая LB)
- **Увеличение**: 7x от single-node
- **Подходит для**: production, средние нагрузки
- **Преимущества**: запас ресурсов, стабильность

### Оптимизация затрат:
1. **Начать с экономичного варианта** и масштабировать по мере роста
2. Использовать auto-scaling для снижения затрат в периоды низкой нагрузки
3. Системные узлы можно исключить на начальном этапе
4. Рассмотреть spot instances для dev/staging окружений

## План миграции

### Этап 1: Подготовка
1. Обновить переменные в `ha/.env.example`
2. Модифицировать Terraform конфигурацию
3. Обновить документацию

### Этап 2: Тестирование
1. Развернуть HA кластер в тестовом окружении
2. Проверить отказоустойчивость
3. Тестировать auto-scaling

### Этап 3: Kubernetes компоненты
1. Создать HA-специфичные Helm charts
2. Настроить pod disruption budgets
3. Конфигурировать anti-affinity правила

### Этап 4: Мониторинг
1. Настроить мониторинг кластера
2. Алерты на отказы узлов
3. Метрики производительности

## Kubernetes-уровневые изменения

После создания HA кластера потребуется:

### 1. Pod Disruption Budgets
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: critical-app
```

### 2. Anti-affinity правила
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - critical-app
      topologyKey: kubernetes.io/hostname
```

### 3. Resource requests/limits
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

## Заключение

Преобразование в HA конфигурацию требует:
1. **Инфраструктурные изменения**: 3+ узла, auto-scaling, load balancer
2. **Конфигурационные изменения**: новые переменные, обновленные Terraform файлы
3. **Kubernetes-уровневые изменения**: PDB, anti-affinity, resource management
4. **Мониторинг**: наблюдаемость и алертинг

Минимальная HA конфигурация обеспечит отказоустойчивость при увеличении затрат примерно в 6 раз, но с возможностью автоматического масштабирования для оптимизации.
