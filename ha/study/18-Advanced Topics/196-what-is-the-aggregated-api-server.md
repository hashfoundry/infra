# 196. What is the aggregated API server?

## 🎯 Вопрос
What is the aggregated API server?

## 💡 Ответ

Aggregated API Server - это механизм в Kubernetes, который позволяет расширять Kubernetes API путем добавления пользовательских API серверов. Это позволяет создавать новые API ресурсы, которые выглядят и работают как встроенные Kubernetes ресурсы, но обрабатываются отдельными серверами.

### 🏗️ Архитектура Aggregated API

#### 1. **Схема API Aggregation**
```
┌─────────────────────────────────────────────────────────────┐
│                 API Aggregation Architecture               │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Client Layer                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   kubectl   │    │  Dashboard  │    │   Custom    │ │ │
│  │  │             │───▶│             │───▶│   Client    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 kube-apiserver                         │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Core API  │    │ Extensions  │    │ Aggregation │ │ │
│  │  │   /api/v1   │───▶│   /apis/    │───▶│   Layer     │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              APIService Registration                   │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ APIService  │    │   Service   │    │ Endpoint    │ │ │
│  │  │   Object    │───▶│  Discovery  │───▶│  Routing    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Extension API Servers                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   Metrics   │    │  Custom     │    │   Service   │ │ │
│  │  │   Server    │───▶│ Resources   │───▶│  Catalog    │ │ │
│  │  │             │    │   Server    │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **Компоненты API Aggregation**
```yaml
# API Aggregation Components
api_aggregation:
  core_components:
    kube_apiserver:
      role: "Main API server and aggregation proxy"
      responsibilities:
        - "Route requests to appropriate API servers"
        - "Handle authentication and authorization"
        - "Manage APIService registrations"
        - "Provide unified API discovery"
      
      aggregation_layer:
        purpose: "Proxy requests to extension API servers"
        features:
          - "Request routing based on API group/version"
          - "Authentication token forwarding"
          - "TLS certificate validation"
          - "Load balancing across endpoints"
    
    apiservice_controller:
      role: "Manage APIService lifecycle"
      responsibilities:
        - "Watch APIService objects"
        - "Update API discovery information"
        - "Handle service availability"
        - "Manage endpoint routing"
    
    extension_apiserver:
      role: "Custom API implementation"
      responsibilities:
        - "Implement custom resource logic"
        - "Handle CRUD operations"
        - "Provide resource validation"
        - "Manage custom storage"

  registration_process:
    apiservice_object:
      purpose: "Register extension API server"
      fields:
        - "API group and version"
        - "Service reference"
        - "CA bundle for TLS"
        - "Priority and version priority"
    
    service_discovery:
      purpose: "Enable client discovery"
      mechanism:
        - "Update /apis endpoint"
        - "Provide OpenAPI schema"
        - "Enable kubectl integration"
        - "Support API versioning"
    
    request_routing:
      purpose: "Route requests to correct server"
      flow:
        - "Client sends request to kube-apiserver"
        - "Aggregation layer checks APIService"
        - "Request proxied to extension server"
        - "Response returned to client"

  authentication_authorization:
    token_forwarding:
      mechanism: "Forward user tokens to extension servers"
      headers:
        - "Authorization: Bearer <token>"
        - "X-Remote-User: <username>"
        - "X-Remote-Group: <groups>"
    
    rbac_integration:
      purpose: "Use standard Kubernetes RBAC"
      resources:
        - "Custom resources follow RBAC rules"
        - "Standard verbs (get, list, create, etc.)"
        - "Namespace and cluster scoped resources"
    
    admission_control:
      integration: "Extension servers can use admission webhooks"
      flow:
        - "Request validation"
        - "Mutation webhooks"
        - "Validation webhooks"
        - "Final admission decision"
```

### 📊 Примеры из нашего кластера

#### Проверка Aggregated API:
```bash
# Проверка APIServices
kubectl get apiservices

# Проверка metrics server (пример aggregated API)
kubectl get apiservices v1beta1.metrics.k8s.io

# Проверка доступных API групп
kubectl api-resources

# Проверка API versions
kubectl api-versions

# Проверка custom resources
kubectl get crd
```

### 🛠️ Создание Extension API Server

#### 1. **APIService Registration**
```yaml
# apiservice.yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1alpha1.example.com
spec:
  group: example.com
  version: v1alpha1
  groupPriorityMinimum: 100
  versionPriority: 100
  service:
    name: example-api-server
    namespace: default
    port: 443
  caBundle: LS0tLS1CRUdJTi... # Base64 encoded CA certificate
  insecureSkipTLSVerify: false

---
# Service for extension API server
apiVersion: v1
kind: Service
metadata:
  name: example-api-server
  namespace: default
spec:
  selector:
    app: example-api-server
  ports:
  - port: 443
    targetPort: 8443
    protocol: TCP

---
# Deployment for extension API server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-api-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example-api-server
  template:
    metadata:
      labels:
        app: example-api-server
    spec:
      serviceAccountName: example-api-server
      containers:
      - name: api-server
        image: example/api-server:v1.0.0
        ports:
        - containerPort: 8443
        args:
        - --secure-port=8443
        - --tls-cert-file=/etc/certs/tls.crt
        - --tls-private-key-file=/etc/certs/tls.key
        - --audit-log-path=-
        - --audit-log-maxage=0
        - --audit-log-maxbackup=0
        volumeMounts:
        - name: certs
          mountPath: /etc/certs
          readOnly: true
      volumes:
      - name: certs
        secret:
          secretName: example-api-server-certs

---
# RBAC for extension API server
apiVersion: v1
kind: ServiceAccount
metadata:
  name: example-api-server
  namespace: default

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: example-api-server
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingadmissionwebhooks", "validatingadmissionwebhooks"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["flowcontrol.apiserver.k8s.io"]
  resources: ["prioritylevelconfigurations", "flowschemas"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: example-api-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: example-api-server
subjects:
- kind: ServiceAccount
  name: example-api-server
  namespace: default

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: example-api-server:system:auth-delegator
rules:
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create"]
- apiGroups: ["authorization.k8s.io"]
  resources: ["subjectaccessreviews"]
  verbs: ["create"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: example-api-server:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: example-api-server:system:auth-delegator
subjects:
- kind: ServiceAccount
  name: example-api-server
  namespace: default

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: example-api-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: example-api-server
  namespace: default
```

#### 2. **Extension API Server Implementation**
```go
// main.go - Extension API Server
package main

import (
    "context"
    "fmt"
    "net/http"
    "os"

    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/runtime/schema"
    "k8s.io/apimachinery/pkg/runtime/serializer"
    "k8s.io/apiserver/pkg/registry/rest"
    genericapiserver "k8s.io/apiserver/pkg/server"
    "k8s.io/apiserver/pkg/server/options"
    "k8s.io/client-go/kubernetes"
    "k8s.io/klog/v2"
)

var (
    Scheme = runtime.NewScheme()
    Codecs = serializer.NewCodecFactory(Scheme)
)

func main() {
    // Create server options
    opts := options.NewRecommendedOptions("", Scheme)
    opts.SecureServing.BindPort = 8443
    
    // Create server config
    config, err := opts.Config()
    if err != nil {
        klog.Fatalf("Error creating server config: %v", err)
    }
    
    // Create extension API server
    server, err := config.Complete().New("example-api-server", genericapiserver.NewEmptyDelegate())
    if err != nil {
        klog.Fatalf("Error creating server: %v", err)
    }
    
    // Install API groups
    if err := installAPIGroups(server); err != nil {
        klog.Fatalf("Error installing API groups: %v", err)
    }
    
    // Start server
    ctx := context.Background()
    if err := server.PrepareRun().Run(ctx.Done()); err != nil {
        klog.Fatalf("Error running server: %v", err)
    }
}

func installAPIGroups(server *genericapiserver.GenericAPIServer) error {
    // Define API group
    apiGroupInfo := genericapiserver.NewDefaultAPIGroupInfo("example.com", Scheme, runtime.NewParameterCodec(Scheme), Codecs)
    
    // Add v1alpha1 version
    v1alpha1Storage := map[string]rest.Storage{}
    v1alpha1Storage["widgets"] = &WidgetStorage{}
    apiGroupInfo.VersionedResourcesStorageMap["v1alpha1"] = v1alpha1Storage
    
    // Install API group
    return server.InstallAPIGroup(&apiGroupInfo)
}

// Widget represents a custom resource
type Widget struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    
    Spec   WidgetSpec   `json:"spec,omitempty"`
    Status WidgetStatus `json:"status,omitempty"`
}

type WidgetSpec struct {
    Size  string `json:"size,omitempty"`
    Color string `json:"color,omitempty"`
}

type WidgetStatus struct {
    Phase string `json:"phase,omitempty"`
}

type WidgetList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    
    Items []Widget `json:"items"`
}

// WidgetStorage implements REST storage for Widget resources
type WidgetStorage struct {
    // In-memory storage for demo purposes
    widgets map[string]*Widget
}

func (s *WidgetStorage) New() runtime.Object {
    return &Widget{}
}

func (s *WidgetStorage) NewList() runtime.Object {
    return &WidgetList{}
}

func (s *WidgetStorage) Get(ctx context.Context, name string, options *metav1.GetOptions) (runtime.Object, error) {
    widget, exists := s.widgets[name]
    if !exists {
        return nil, errors.NewNotFound(schema.GroupResource{Group: "example.com", Resource: "widgets"}, name)
    }
    return widget.DeepCopy(), nil
}

func (s *WidgetStorage) List(ctx context.Context, options *metav1.ListOptions) (runtime.Object, error) {
    list := &WidgetList{}
    for _, widget := range s.widgets {
        list.Items = append(list.Items, *widget.DeepCopy())
    }
    return list, nil
}

func (s *WidgetStorage) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
    widget := obj.(*Widget)
    
    // Validate
    if createValidation != nil {
        if err := createValidation(ctx, obj); err != nil {
            return nil, err
        }
    }
    
    // Generate name if needed
    if widget.Name == "" {
        widget.Name = fmt.Sprintf("widget-%d", len(s.widgets)+1)
    }
    
    // Set defaults
    if widget.Spec.Size == "" {
        widget.Spec.Size = "medium"
    }
    if widget.Spec.Color == "" {
        widget.Spec.Color = "blue"
    }
    
    // Set status
    widget.Status.Phase = "Active"
    
    // Store
    if s.widgets == nil {
        s.widgets = make(map[string]*Widget)
    }
    s.widgets[widget.Name] = widget.DeepCopy()
    
    return widget, nil
}

func (s *WidgetStorage) Update(ctx context.Context, name string, objInfo rest.UpdatedObjectInfo, createValidation rest.ValidateObjectFunc, updateValidation rest.ValidateObjectUpdateFunc, forceAllowCreate bool, options *metav1.UpdateOptions) (runtime.Object, bool, error) {
    existing, exists := s.widgets[name]
    if !exists && !forceAllowCreate {
        return nil, false, errors.NewNotFound(schema.GroupResource{Group: "example.com", Resource: "widgets"}, name)
    }
    
    updated, err := objInfo.UpdatedObject(ctx, existing)
    if err != nil {
        return nil, false, err
    }
    
    widget := updated.(*Widget)
    
    // Validate
    if updateValidation != nil {
        if err := updateValidation(ctx, widget, existing); err != nil {
            return nil, false, err
        }
    }
    
    // Store
    s.widgets[name] = widget.DeepCopy()
    
    return widget, !exists, nil
}

func (s *WidgetStorage) Delete(ctx context.Context, name string, deleteValidation rest.ValidateObjectFunc, options *metav1.DeleteOptions) (runtime.Object, bool, error) {
    widget, exists := s.widgets[name]
    if !exists {
        return nil, false, errors.NewNotFound(schema.GroupResource{Group: "example.com", Resource: "widgets"}, name)
    }
    
    // Validate
    if deleteValidation != nil {
        if err := deleteValidation(ctx, widget); err != nil {
            return nil, false, err
        }
    }
    
    // Delete
    delete(s.widgets, name)
    
    return widget, true, nil
}

// Implement additional required methods
func (s *WidgetStorage) NamespaceScoped() bool {
    return true
}

func (s *WidgetStorage) GetSingularName() string {
    return "widget"
}
```

#### 3. **Client Usage Example**
```go
// client-example.go
package main

import (
    "context"
    "fmt"
    
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime/schema"
    "k8s.io/client-go/dynamic"
    "k8s.io/client-go/tools/clientcmd"
)

func main() {
    // Create client
    config, err := clientcmd.BuildConfigFromFlags("", "~/.kube/config")
    if err != nil {
        panic(err)
    }
    
    client, err := dynamic.NewForConfig(config)
    if err != nil {
        panic(err)
    }
    
    // Define resource
    gvr := schema.GroupVersionResource{
        Group:    "example.com",
        Version:  "v1alpha1",
        Resource: "widgets",
    }
    
    // Create widget
    widget := map[string]interface{}{
        "apiVersion": "example.com/v1alpha1",
        "kind":       "Widget",
        "metadata": map[string]interface{}{
            "name":      "my-widget",
            "namespace": "default",
        },
        "spec": map[string]interface{}{
            "size":  "large",
            "color": "red",
        },
    }
    
    created, err := client.Resource(gvr).Namespace("default").Create(
        context.TODO(),
        &unstructured.Unstructured{Object: widget},
        metav1.CreateOptions{},
    )
    if err != nil {
        panic(err)
    }
    
    fmt.Printf("Created widget: %s\n", created.GetName())
    
    // List widgets
    list, err := client.Resource(gvr).Namespace("default").List(
        context.TODO(),
        metav1.ListOptions{},
    )
    if err != nil {
        panic(err)
    }
    
    fmt.Printf("Found %d widgets\n", len(list.Items))
    for _, item := range list.Items {
        fmt.Printf("- %s\n", item.GetName())
    }
}
```

### 🔧 Утилиты для работы с Aggregated API

#### Скрипт для тестирования Extension API Server:
```bash
#!/bin/bash
# test-aggregated-api.sh

echo "🧪 Testing Aggregated API Server"

# Test API service registration
test_apiservice_registration() {
    local api_service=$1
    
    echo "=== Testing APIService Registration ==="
    
    # Check if APIService exists
    if kubectl get apiservice $api_service >/dev/null 2>&1; then
        echo "✅ APIService registered: $api_service"
        
        # Check service availability
        available=$(kubectl get apiservice $api_service -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
        if [ "$available" = "True" ]; then
            echo "✅ APIService available"
        else
            echo "❌ APIService not available"
            kubectl get apiservice $api_service -o yaml
        fi
    else
        echo "❌ APIService not found: $api_service"
        return 1
    fi
}

# Test API discovery
test_api_discovery() {
    local group=$1
    local version=$2
    
    echo "=== Testing API Discovery ==="
    
    # Check if API group is discoverable
    if kubectl api-resources --api-group=$group >/dev/null 2>&1; then
        echo "✅ API group discoverable: $group"
        kubectl api-resources --api-group=$group
    else
        echo "❌ API group not discoverable: $group"
    fi
    
    # Check API version
    if kubectl api-versions | grep "$group/$version" >/dev/null 2>&1; then
        echo "✅ API version available: $group/$version"
    else
        echo "❌ API version not available: $group/$version"
    fi
}

# Test custom resource operations
test_custom_resource_operations() {
    local group=$1
    local version=$2
    local resource=$3
    local namespace=${4:-"default"}
    
    echo "=== Testing Custom Resource Operations ==="
    
    # Create test resource
    echo "--- Creating test resource ---"
    cat <<EOF | kubectl apply -f -
apiVersion: $group/$version
kind: Widget
metadata:
  name: test-widget
  namespace: $namespace
spec:
  size: large
  color: green
EOF

    if [ $? -eq 0 ]; then
        echo "✅ Resource created successfully"
    else
        echo "❌ Resource creation failed"
        return 1
    fi
    
    # Get resource
    echo "--- Getting resource ---"
    if kubectl get $resource test-widget -n $namespace >/dev/null 2>&1; then
        echo "✅ Resource retrieved successfully"
        kubectl get $resource test-widget -n $namespace -o yaml
    else
        echo "❌ Resource retrieval failed"
    fi
    
    # List resources
    echo "--- Listing resources ---"
    if kubectl get $resource -n $namespace >/dev/null 2>&1; then
        echo "✅ Resource listing successful"
        kubectl get $resource -n $namespace
    else
        echo "❌ Resource listing failed"
    fi
    
    # Update resource
    echo "--- Updating resource ---"
    kubectl patch $resource test-widget -n $namespace --type='merge' -p='{"spec":{"color":"blue"}}'
    if [ $? -eq 0 ]; then
        echo "✅ Resource updated successfully"
    else
        echo "❌ Resource update failed"
    fi
    
    # Delete resource
    echo "--- Deleting resource ---"
    kubectl delete $resource test-widget -n $namespace
    if [ $? -eq 0 ]; then
        echo "✅ Resource deleted successfully"
    else
        echo "❌ Resource deletion failed"
    fi
}

# Test authentication and authorization
test_auth() {
    local resource=$1
    local namespace=${2:-"default"}
    
    echo "=== Testing Authentication and Authorization ==="
    
    # Test with different service account
    echo "--- Testing with limited service account ---"
    
    # Create limited service account
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-user
  namespace: $namespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: widget-reader
  namespace: $namespace
rules:
- apiGroups: ["example.com"]
  resources: ["widgets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: test-user-binding
  namespace: $namespace
subjects:
- kind: ServiceAccount
  name: test-user
  namespace: $namespace
roleRef:
  kind: Role
  name: widget-reader
  apiGroup: rbac.authorization.k8s.io
EOF

    # Test with limited permissions
    token=$(kubectl create token test-user -n $namespace)
    
    # Should succeed (read operations)
    if kubectl --token=$token get $resource -n $namespace >/dev/null 2>&1; then
        echo "✅ Read access works with limited permissions"
    else
        echo "❌ Read access failed with limited permissions"
    fi
    
    # Should fail (write operations)
    if kubectl --token=$token create -f - <<EOF >/dev/null 2>&1
apiVersion: example.com/v1alpha1
kind: Widget
metadata:
  name: unauthorized-widget
  namespace: $namespace
spec:
  size: small
  color: red
EOF
    then
        echo "❌ Write access should have been denied"
    else
        echo "✅ Write access correctly denied"
    fi
    
    # Cleanup
    kubectl delete serviceaccount test-user -n $namespace
    kubectl delete role widget-reader -n $namespace
    kubectl delete rolebinding test-user-binding -n $namespace
}

# Test metrics and monitoring
test_metrics() {
    local api_service=$1
    
    echo "=== Testing Metrics and Monitoring ==="
    
    # Check if metrics are available
    if kubectl top nodes >/dev/null 2>&1; then
        echo "✅ Node metrics available"
    else
        echo "❌ Node metrics not available"
    fi
    
    if kubectl top pods >/dev/null 2>&1; then
        echo "✅ Pod metrics available"
    else
        echo "❌ Pod metrics not available"
    fi
    
    # Check API server logs
    echo "--- Checking API server logs ---"
    kubectl logs -n kube-system -l component=kube-apiserver --tail=10 | grep -i "aggregat\|proxy" || echo "No aggregation logs found"
}

# Performance testing
performance_test() {
    local resource=$1
    local namespace=${2:-"default"}
    local count=${3:-10}
    
    echo "=== Performance Testing ==="
    
    echo "Creating $count resources..."
    start_time=$(date +%s)
    
    for i in $(seq 1 $count); do
        cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: example.com/v1alpha1
kind: Widget
metadata:
  name: perf-widget-$i
  namespace: $namespace
spec:
  size: medium
  color: blue
EOF
    done
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "✅ Created $count resources in ${duration}s"
    echo "Average: $((duration * 1000 / count))ms per resource"
    
    # List performance
    echo "Testing list performance..."
    start_time=$(date +%s)
    kubectl get $resource -n $namespace >/dev/null 2>&1
    end_time=$(date +%s)
    list_duration=$((end_time - start_time))
    
    echo "✅ Listed $count resources in ${list_duration}s"
    
    # Cleanup
    echo "Cleaning up test resources..."
    for i in $(seq 1 $count); do
        kubectl delete $resource perf-widget-$i -n $namespace >/dev/null 2>&1
    done
}

# Main execution
main() {
    local api_service=${1:-"v1alpha1.example.com"}
    local group=${2:-"example.com"}
    local version=${3:-"v1alpha1"}
    local resource=${4:-"widgets"}
    local namespace=${5:-"default"}
    
    echo "Testing Aggregated API Server"
    echo "APIService: $api_service"
    echo "Group: $group"
    echo "Version: $version"
    echo "Resource: $resource"
    echo "Namespace: $namespace"
    echo ""
    
    # Run tests
    test_apiservice_registration $api_service
    echo ""
    
    test_api_discovery $group $version
    echo ""
    
    test_custom_resource_operations $group $version $resource $namespace
    echo ""
    
    test_auth $resource $namespace
    echo ""
    
    test_metrics $api_service
    echo ""
    
    read -p "Run performance test? (y/n): " run_perf
    if [ "$run_perf" = "y" ]; then
        performance_test $resource $namespace 10
    fi
}

# Check if arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <api-service> [group] [version] [resource] [namespace]"
    echo "Example: $0 v1alpha1.example.com example.com v1alpha1 widgets default"
    echo ""
    echo "Running with default values..."
    main
else
    main "$@"
fi
```

### 🎯 Заключение

Aggregated API Server предоставляет мощный механизм для расширения Kubernetes API:

**Ключевые преимущества:**
1. **Единый API интерфейс** - все ресурсы доступны через kube-apiserver
2. **Стандартная аутентификация** - использует существующие механизмы Kubernetes
3. **RBAC интеграция** - полная поддержка стандартных разрешений
4. **kubectl совместимость** - работает со всеми стандартными инструментами

**Архитектурные компоненты:**
1. **APIService** - регистрация extension API server
2. **Aggregation Layer** - проксирование запросов
3. **Extension API Server** - пользовательская реализация API
4. **Service Discovery** - автоматическое обнаружение API

**Случаи использования:**
- **Metrics Server** - предоставление метрик ресурсов
- **Custom Resources** - сложная бизнес-логика
- **Service Catalog** - управление внешними сервисами
- **Policy Engines** - расширенные политики безопасности

Aggregated API обеспечивает гибкий и масштабируемый способ расширения функциональности Kubernetes без изменения основного кода платформы.
