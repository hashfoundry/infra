# 187. Что такое Kubernetes API Aggregation?

## 🎯 Вопрос
Что такое Kubernetes API Aggregation?

## 💡 Ответ

Kubernetes API Aggregation - это механизм, который позволяет расширять Kubernetes API Server дополнительными API endpoints, не изменяя основной код kube-apiserver. Это достигается через APIService ресурсы, которые регистрируют внешние API серверы и делают их доступными через единую точку входа Kubernetes API.

### 🏗️ Архитектура API Aggregation

#### 1. **Схема API Aggregation Layer**
```
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes API Aggregation                  │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Client Request                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   kubectl   │    │    HTTP     │    │   Request   │ │ │
│  │  │   client    │───▶│   Client    │───▶│ to API Path │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 kube-apiserver                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Request   │    │    Route    │    │   Handler   │ │ │
│  │  │ Processing  │───▶│  Decision   │───▶│ Selection   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              API Path Routing                          │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Core API  │    │ Aggregated  │    │   Custom    │ │ │
│  │  │ (/api/v1)   │    │ API Service │    │ Resources   │ │ │
│  │  │             │    │(/apis/...)  │    │   (CRDs)    │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              External API Server                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Custom    │    │   Business  │    │   Response  │ │ │
│  │  │ API Logic   │───▶│    Logic    │───▶│ Generation  │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **API Aggregation Components**
```yaml
# API Aggregation Architecture
api_aggregation_components:
  kube_aggregator:
    description: "Компонент kube-apiserver для aggregation"
    responsibilities:
      - "APIService registration"
      - "Request routing"
      - "Authentication delegation"
      - "Authorization delegation"
    
  apiservice_resource:
    description: "Kubernetes ресурс для регистрации API"
    fields:
      - "group: API group name"
      - "version: API version"
      - "service: Backend service reference"
      - "caBundle: CA certificate bundle"
      - "insecureSkipTLSVerify: Skip TLS verification"
      - "groupPriorityMinimum: Group priority"
      - "versionPriority: Version priority"
  
  extension_apiserver:
    description: "Внешний API сервер"
    requirements:
      - "Kubernetes API conventions"
      - "Authentication webhook support"
      - "Authorization webhook support"
      - "Admission controller integration"
    
    examples:
      - "metrics-server"
      - "custom-metrics-api"
      - "external-metrics-api"
      - "service-catalog"

# API Aggregation vs CRDs
comparison:
  api_aggregation:
    pros:
      - "Full control over API behavior"
      - "Custom storage backends"
      - "Complex business logic"
      - "Performance optimization"
      - "Advanced validation"
    cons:
      - "Complex implementation"
      - "Separate deployment"
      - "Additional maintenance"
      - "Security considerations"
    
  custom_resources:
    pros:
      - "Simple implementation"
      - "Built-in etcd storage"
      - "Automatic CRUD operations"
      - "OpenAPI schema validation"
      - "Easy deployment"
    cons:
      - "Limited customization"
      - "etcd storage only"
      - "Basic validation"
      - "Standard behavior only"
```

### 📊 Примеры из нашего кластера

#### Проверка API aggregation:
```bash
# Проверка зарегистрированных APIServices
kubectl get apiservices

# Проверка metrics-server (пример aggregated API)
kubectl get apiservices v1beta1.metrics.k8s.io

# Проверка доступных API групп
kubectl api-versions

# Проверка API resources
kubectl api-resources --api-group=metrics.k8s.io
```

### 🔧 Создание Extension API Server

#### 1. **APIService Registration**
```yaml
# custom-api-service.yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1.example.com
spec:
  group: example.com
  version: v1
  service:
    name: custom-api-server
    namespace: custom-api-system
    port: 443
  caBundle: LS0tLS1CRUdJTi... # Base64 encoded CA certificate
  groupPriorityMinimum: 100
  versionPriority: 100
  insecureSkipTLSVerify: false

---
# Service для custom API server
apiVersion: v1
kind: Service
metadata:
  name: custom-api-server
  namespace: custom-api-system
spec:
  selector:
    app: custom-api-server
  ports:
  - port: 443
    targetPort: 8443
    protocol: TCP
  type: ClusterIP

---
# Deployment для custom API server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-api-server
  namespace: custom-api-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: custom-api-server
  template:
    metadata:
      labels:
        app: custom-api-server
    spec:
      serviceAccountName: custom-api-server
      containers:
      - name: api-server
        image: custom-api-server:latest
        ports:
        - containerPort: 8443
        args:
        - --secure-port=8443
        - --cert-dir=/etc/certs
        - --authentication-kubeconfig=/etc/kubeconfig/kubeconfig
        - --authorization-kubeconfig=/etc/kubeconfig/kubeconfig
        - --kubeconfig=/etc/kubeconfig/kubeconfig
        volumeMounts:
        - name: certs
          mountPath: /etc/certs
          readOnly: true
        - name: kubeconfig
          mountPath: /etc/kubeconfig
          readOnly: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: certs
        secret:
          secretName: custom-api-server-certs
      - name: kubeconfig
        secret:
          secretName: custom-api-server-kubeconfig
```

#### 2. **Custom API Server Implementation**
```go
// custom-api-server.go
package main

import (
    "context"
    "fmt"
    "net/http"
    
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/runtime/schema"
    "k8s.io/apimachinery/pkg/runtime/serializer"
    "k8s.io/apiserver/pkg/registry/rest"
    genericapiserver "k8s.io/apiserver/pkg/server"
    "k8s.io/apiserver/pkg/server/options"
)

// CustomResource представляет наш custom resource
type CustomResource struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    
    Spec   CustomResourceSpec   `json:"spec,omitempty"`
    Status CustomResourceStatus `json:"status,omitempty"`
}

type CustomResourceSpec struct {
    Message     string            `json:"message"`
    Replicas    int32             `json:"replicas"`
    Config      map[string]string `json:"config,omitempty"`
    Enabled     bool              `json:"enabled"`
}

type CustomResourceStatus struct {
    Phase       string             `json:"phase,omitempty"`
    Conditions  []metav1.Condition `json:"conditions,omitempty"`
    ObservedGen int64              `json:"observedGeneration,omitempty"`
}

// CustomResourceList представляет список custom resources
type CustomResourceList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    
    Items []CustomResource `json:"items"`
}

// Схема для нашего API
var (
    Scheme = runtime.NewScheme()
    Codecs = serializer.NewCodecFactory(Scheme)
)

func init() {
    // Регистрация типов в схеме
    metav1.AddToGroupVersion(Scheme, schema.GroupVersion{Version: "v1"})
    
    Scheme.AddKnownTypes(schema.GroupVersion{Group: "example.com", Version: "v1"},
        &CustomResource{},
        &CustomResourceList{},
    )
}

// CustomResourceStorage реализует REST storage для CustomResource
type CustomResourceStorage struct {
    // В реальной реализации здесь может быть база данных,
    // файловая система или другой storage backend
    resources map[string]*CustomResource
}

// NewCustomResourceStorage создает новый storage
func NewCustomResourceStorage() *CustomResourceStorage {
    return &CustomResourceStorage{
        resources: make(map[string]*CustomResource),
    }
}

// New возвращает новый пустой объект
func (r *CustomResourceStorage) New() runtime.Object {
    return &CustomResource{}
}

// NewList возвращает новый пустой список
func (r *CustomResourceStorage) NewList() runtime.Object {
    return &CustomResourceList{}
}

// Get получает объект по имени
func (r *CustomResourceStorage) Get(ctx context.Context, name string, options *metav1.GetOptions) (runtime.Object, error) {
    if resource, exists := r.resources[name]; exists {
        return resource.DeepCopy(), nil
    }
    return nil, fmt.Errorf("CustomResource %s not found", name)
}

// List возвращает список всех объектов
func (r *CustomResourceStorage) List(ctx context.Context, options *metav1.ListOptions) (runtime.Object, error) {
    list := &CustomResourceList{
        Items: make([]CustomResource, 0, len(r.resources)),
    }
    
    for _, resource := range r.resources {
        list.Items = append(list.Items, *resource.DeepCopy())
    }
    
    return list, nil
}

// Create создает новый объект
func (r *CustomResourceStorage) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
    resource := obj.(*CustomResource)
    
    // Валидация
    if createValidation != nil {
        if err := createValidation(ctx, obj); err != nil {
            return nil, err
        }
    }
    
    // Установка метаданных
    if resource.Name == "" {
        return nil, fmt.Errorf("name is required")
    }
    
    if _, exists := r.resources[resource.Name]; exists {
        return nil, fmt.Errorf("CustomResource %s already exists", resource.Name)
    }
    
    // Установка default значений
    if resource.Spec.Replicas == 0 {
        resource.Spec.Replicas = 1
    }
    
    resource.Status.Phase = "Created"
    resource.Status.ObservedGen = resource.Generation
    
    // Сохранение
    r.resources[resource.Name] = resource.DeepCopy()
    
    return resource, nil
}

// Update обновляет существующий объект
func (r *CustomResourceStorage) Update(ctx context.Context, name string, objInfo rest.UpdatedObjectInfo, createValidation rest.ValidateObjectFunc, updateValidation rest.ValidateObjectUpdateFunc, forceAllowCreate bool, options *metav1.UpdateOptions) (runtime.Object, bool, error) {
    existing, exists := r.resources[name]
    if !exists {
        if !forceAllowCreate {
            return nil, false, fmt.Errorf("CustomResource %s not found", name)
        }
        // Создание нового объекта
        obj, err := objInfo.UpdatedObject(ctx, nil)
        if err != nil {
            return nil, false, err
        }
        created, err := r.Create(ctx, obj, createValidation, &metav1.CreateOptions{})
        return created, true, err
    }
    
    // Обновление существующего объекта
    obj, err := objInfo.UpdatedObject(ctx, existing)
    if err != nil {
        return nil, false, err
    }
    
    resource := obj.(*CustomResource)
    
    // Валидация обновления
    if updateValidation != nil {
        if err := updateValidation(ctx, obj, existing); err != nil {
            return nil, false, err
        }
    }
    
    // Обновление статуса
    resource.Status.Phase = "Updated"
    resource.Status.ObservedGen = resource.Generation
    
    // Сохранение
    r.resources[name] = resource.DeepCopy()
    
    return resource, false, nil
}

// Delete удаляет объект
func (r *CustomResourceStorage) Delete(ctx context.Context, name string, deleteValidation rest.ValidateObjectFunc, options *metav1.DeleteOptions) (runtime.Object, bool, error) {
    existing, exists := r.resources[name]
    if !exists {
        return nil, false, fmt.Errorf("CustomResource %s not found", name)
    }
    
    // Валидация удаления
    if deleteValidation != nil {
        if err := deleteValidation(ctx, existing); err != nil {
            return nil, false, err
        }
    }
    
    // Удаление
    delete(r.resources, name)
    
    return existing, true, nil
}

// Реализация интерфейсов для REST storage
func (r *CustomResourceStorage) NamespaceScoped() bool {
    return true
}

// CustomAPIServer представляет наш custom API server
type CustomAPIServer struct {
    GenericAPIServer *genericapiserver.GenericAPIServer
}

// Complete завершает конфигурацию сервера
func (s *CustomAPIServer) Complete() error {
    // Регистрация API группы
    apiGroupInfo := genericapiserver.NewDefaultAPIGroupInfo("example.com", Scheme, metav1.ParameterCodec, Codecs)
    
    // Создание storage для наших ресурсов
    customResourceStorage := NewCustomResourceStorage()
    
    // Регистрация версии API
    v1storage := map[string]rest.Storage{
        "customresources": customResourceStorage,
    }
    
    apiGroupInfo.VersionedResourcesStorageMap["v1"] = v1storage
    
    // Установка API группы
    if err := s.GenericAPIServer.InstallAPIGroup(&apiGroupInfo); err != nil {
        return err
    }
    
    return nil
}

// NewCustomAPIServer создает новый custom API server
func NewCustomAPIServer(recommendedOptions *options.RecommendedOptions) (*CustomAPIServer, error) {
    // Создание generic API server
    genericConfig, err := recommendedOptions.Config()
    if err != nil {
        return nil, err
    }
    
    genericServer, err := genericConfig.Complete().New("custom-api-server", genericapiserver.NewEmptyDelegate())
    if err != nil {
        return nil, err
    }
    
    server := &CustomAPIServer{
        GenericAPIServer: genericServer,
    }
    
    return server, nil
}

func main() {
    // Настройка опций
    recommendedOptions := options.NewRecommendedOptions(
        "/registry/example.com",
        Codecs.LegacyCodec(schema.GroupVersion{Group: "example.com", Version: "v1"}),
    )
    
    // Создание сервера
    server, err := NewCustomAPIServer(recommendedOptions)
    if err != nil {
        panic(err)
    }
    
    // Завершение конфигурации
    if err := server.Complete(); err != nil {
        panic(err)
    }
    
    // Запуск сервера
    if err := server.GenericAPIServer.PrepareRun().Run(context.Background()); err != nil {
        panic(err)
    }
}
```

#### 3. **Advanced API Server с Database Backend**
```go
// database-api-server.go
package main

import (
    "context"
    "database/sql"
    "encoding/json"
    "fmt"
    
    _ "github.com/lib/pq" // PostgreSQL driver
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
)

// DatabaseStorage реализует storage с PostgreSQL backend
type DatabaseStorage struct {
    db *sql.DB
}

// NewDatabaseStorage создает новый database storage
func NewDatabaseStorage(connectionString string) (*DatabaseStorage, error) {
    db, err := sql.Open("postgres", connectionString)
    if err != nil {
        return nil, err
    }
    
    // Создание таблицы если не существует
    if err := createTables(db); err != nil {
        return nil, err
    }
    
    return &DatabaseStorage{db: db}, nil
}

func createTables(db *sql.DB) error {
    query := `
    CREATE TABLE IF NOT EXISTS custom_resources (
        namespace VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        resource_version VARCHAR(255) NOT NULL,
        data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        PRIMARY KEY (namespace, name)
    );
    
    CREATE INDEX IF NOT EXISTS idx_custom_resources_namespace ON custom_resources(namespace);
    CREATE INDEX IF NOT EXISTS idx_custom_resources_name ON custom_resources(name);
    `
    
    _, err := db.Exec(query)
    return err
}

// Get получает объект из базы данных
func (d *DatabaseStorage) Get(ctx context.Context, namespace, name string, options *metav1.GetOptions) (runtime.Object, error) {
    query := `SELECT data FROM custom_resources WHERE namespace = $1 AND name = $2`
    
    var data []byte
    err := d.db.QueryRowContext(ctx, query, namespace, name).Scan(&data)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, fmt.Errorf("CustomResource %s/%s not found", namespace, name)
        }
        return nil, err
    }
    
    var resource CustomResource
    if err := json.Unmarshal(data, &resource); err != nil {
        return nil, err
    }
    
    return &resource, nil
}

// List возвращает список объектов из базы данных
func (d *DatabaseStorage) List(ctx context.Context, namespace string, options *metav1.ListOptions) (runtime.Object, error) {
    var query string
    var args []interface{}
    
    if namespace != "" {
        query = `SELECT data FROM custom_resources WHERE namespace = $1 ORDER BY name`
        args = []interface{}{namespace}
    } else {
        query = `SELECT data FROM custom_resources ORDER BY namespace, name`
    }
    
    rows, err := d.db.QueryContext(ctx, query, args...)
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    
    list := &CustomResourceList{
        Items: make([]CustomResource, 0),
    }
    
    for rows.Next() {
        var data []byte
        if err := rows.Scan(&data); err != nil {
            return nil, err
        }
        
        var resource CustomResource
        if err := json.Unmarshal(data, &resource); err != nil {
            return nil, err
        }
        
        list.Items = append(list.Items, resource)
    }
    
    return list, nil
}

// Create создает новый объект в базе данных
func (d *DatabaseStorage) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
    resource := obj.(*CustomResource)
    
    // Валидация
    if createValidation != nil {
        if err := createValidation(ctx, obj); err != nil {
            return nil, err
        }
    }
    
    // Сериализация объекта
    data, err := json.Marshal(resource)
    if err != nil {
        return nil, err
    }
    
    // Вставка в базу данных
    query := `
    INSERT INTO custom_resources (namespace, name, resource_version, data) 
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (namespace, name) DO NOTHING
    `
    
    result, err := d.db.ExecContext(ctx, query, 
        resource.Namespace, 
        resource.Name, 
        resource.ResourceVersion, 
        data)
    if err != nil {
        return nil, err
    }
    
    rowsAffected, err := result.RowsAffected()
    if err != nil {
        return nil, err
    }
    
    if rowsAffected == 0 {
        return nil, fmt.Errorf("CustomResource %s/%s already exists", resource.Namespace, resource.Name)
    }
    
    return resource, nil
}

// Update обновляет объект в базе данных
func (d *DatabaseStorage) Update(ctx context.Context, namespace, name string, objInfo rest.UpdatedObjectInfo, createValidation rest.ValidateObjectFunc, updateValidation rest.ValidateObjectUpdateFunc, forceAllowCreate bool, options *metav1.UpdateOptions) (runtime.Object, bool, error) {
    // Получение существующего объекта
    existing, err := d.Get(ctx, namespace, name, &metav1.GetOptions{})
    if err != nil {
        if !forceAllowCreate {
            return nil, false, err
        }
        // Создание нового объекта
        obj, err := objInfo.UpdatedObject(ctx, nil)
        if err != nil {
            return nil, false, err
        }
        created, err := d.Create(ctx, obj, createValidation, &metav1.CreateOptions{})
        return created, true, err
    }
    
    // Обновление существующего объекта
    obj, err := objInfo.UpdatedObject(ctx, existing)
    if err != nil {
        return nil, false, err
    }
    
    resource := obj.(*CustomResource)
    
    // Валидация обновления
    if updateValidation != nil {
        if err := updateValidation(ctx, obj, existing); err != nil {
            return nil, false, err
        }
    }
    
    // Сериализация объекта
    data, err := json.Marshal(resource)
    if err != nil {
        return nil, false, err
    }
    
    // Обновление в базе данных
    query := `
    UPDATE custom_resources 
    SET data = $1, resource_version = $2, updated_at = NOW() 
    WHERE namespace = $3 AND name = $4
    `
    
    _, err = d.db.ExecContext(ctx, query, 
        data, 
        resource.ResourceVersion, 
        namespace, 
        name)
    if err != nil {
        return nil, false, err
    }
    
    return resource, false, nil
}

// Delete удаляет объект из базы данных
func (d *DatabaseStorage) Delete(ctx context.Context, namespace, name string, deleteValidation rest.ValidateObjectFunc, options *metav1.DeleteOptions) (runtime.Object, bool, error) {
    // Получение объекта перед удалением
    existing, err := d.Get(ctx, namespace, name, &metav1.GetOptions{})
    if err != nil {
        return nil, false, err
    }
    
    // Валидация удаления
    if deleteValidation != nil {
        if err := deleteValidation(ctx, existing); err != nil {
            return nil, false, err
        }
    }
    
    // Удаление из базы данных
    query := `DELETE FROM custom_resources WHERE namespace = $1 AND name = $2`
    
    result, err := d.db.ExecContext(ctx, query, namespace, name)
    if err != nil {
        return nil, false, err
    }
    
    rowsAffected, err := result.RowsAffected()
    if err != nil {
        return nil, false, err
    }
    
    if rowsAffected == 0 {
        return nil, false, fmt.Errorf("CustomResource %s/%s not found", namespace, name)
    }
    
    return existing, true, nil
}
```

### 📊 Мониторинг API Aggregation

#### 1. **API Server Monitoring**
```bash
#!/bin/bash
# api-aggregation-monitoring.sh

echo "📊 Мониторинг API Aggregation"

# Проверка APIServices
check_apiservices() {
    echo "=== APIServices Status ==="
    
    kubectl get apiservices -o custom-columns=\
NAME:.metadata.name,\
GROUP:.spec.group,\
VERSION:.spec.version,\
AVAILABLE:.status.conditions[?(@.type==\"Available\")].status,\
SERVICE:.spec.service.name

    echo ""
    echo "=== APIServices Details ==="
    kubectl get apiservices -o json | jq -r '
        .items[] | 
        select(.spec.service != null) | 
        "\(.metadata.name): \(.spec.service.namespace)/\(.spec.service.name):\(.spec.service.port)"
    '
}

# Проверка доступности aggregated APIs
check_api_availability() {
    echo "=== API Availability Check ==="
    
    # Проверка metrics API
    if kubectl top nodes >/dev/null 2>&1; then
        echo "✅ Metrics API: Available"
    else
        echo "❌ Metrics API: Unavailable"
    fi
    
    # Проверка custom APIs
    kubectl get apiservices -o json | jq -r '.items[] | select(.spec.service != null) | .metadata.name' | while read apiservice; do
        group=$(kubectl get apiservice $apiservice -o jsonpath='{.spec.group}')
        version=$(kubectl get apiservice $apiservice -o jsonpath='{.spec.version}')
        
        if kubectl api-resources --api-group=$group >/dev/null 2>&1; then
            echo "✅ $apiservice ($group/$version): Available"
        else
            echo "❌ $apiservice ($group/$version): Unavailable"
        fi
    done
}

# Проверка API server pods
check_api_server_pods() {
    echo "=== Extension API Server Pods ==="
    
    # Поиск pods с aggregated API servers
    kubectl get pods --all-namespaces -o json | jq -r '
        .items[] | 
        select(.metadata.labels."app" // "" | contains("api")) | 
        "\(.metadata.namespace)/\(.metadata.name): \(.status.phase)"
    '
    
    echo ""
    echo "=== API Server Logs ==="
    kubectl get pods --all-namespaces -l app=custom-api-server --no-headers | while read namespace pod rest; do
        echo "--- $namespace/$pod ---"
        kubectl logs -n $namespace $pod --tail=10
    done
}

# Проверка сертификатов
check_certificates() {
    echo "=== Certificate Status ==="
    
    kubectl get apiservices -o json | jq -r '
        .items[] | 
        select(.spec.caBundle != null) | 
        .metadata.name
    ' | while read apiservice; do
        echo "Checking certificates for $apiservice..."
        
        # Получение CA bundle
        ca_bundle=$(kubectl get apiservice $apiservice -o jsonpath='{.spec.caBundle}')
        
        if [ -n "$ca_bundle" ]; then
            echo "$ca_bundle" | base64 -d | openssl x509 -text -noout | grep -E "(Subject:|Not After)"
        fi
    done
}

# Тестирование API endpoints
test_api_endpoints() {
    echo "=== API Endpoint
