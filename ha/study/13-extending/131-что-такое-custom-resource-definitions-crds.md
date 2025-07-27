# 131. Что такое Custom Resource Definitions (CRDs)

## 🎯 **Что такое Custom Resource Definitions (CRDs)?**

**Custom Resource Definitions (CRDs)** - это механизм расширения Kubernetes API, который позволяет создавать собственные типы ресурсов. CRDs дают возможность определить новые API объекты, которые ведут себя как встроенные ресурсы Kubernetes (Pods, Services, Deployments), но содержат пользовательскую логику и данные.

## 🌐 **Архитектура CRDs:**

### **1. Core Components:**
- **Custom Resource Definition** - схема нового ресурса
- **Custom Resource** - экземпляр CRD
- **Controller** - логика управления CR
- **API Server** - обработка CR через Kubernetes API

### **2. CRD Structure:**
- **Metadata** - имя, версия, scope
- **Spec** - схема данных (OpenAPI v3)
- **Status** - текущее состояние
- **Validation** - правила валидации

### **3. API Extension Levels:**
- **CRDs** - декларативные ресурсы
- **API Aggregation** - полноценные API серверы
- **Admission Controllers** - валидация и мутация

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive CRD learning toolkit
cat << 'EOF' > crd-learning-toolkit.sh
#!/bin/bash

echo "=== Custom Resource Definitions (CRDs) Learning Toolkit ==="
echo "Comprehensive guide for understanding and working with CRDs in HashFoundry HA cluster"
echo

# Функция для создания простого CRD
create_basic_crd() {
    echo "=== Creating Basic CRD Example ==="
    
    echo "1. Simple Application CRD:"
    cat << BASIC_CRD_EOF > basic-application-crd.yaml
# Basic Application Custom Resource Definition
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.hashfoundry.io
  labels:
    app: hashfoundry-crd
    component: application-manager
spec:
  group: hashfoundry.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              name:
                type: string
                description: "Application name"
              version:
                type: string
                description: "Application version"
                pattern: '^v[0-9]+\.[0-9]+\.[0-9]+$'
              replicas:
                type: integer
                minimum: 1
                maximum: 10
                description: "Number of replicas"
              image:
                type: string
                description: "Container image"
              port:
                type: integer
                minimum: 1
                maximum: 65535
                description: "Application port"
              environment:
                type: string
                enum: ["development", "staging", "production"]
                description: "Deployment environment"
              resources:
                type: object
                properties:
                  cpu:
                    type: string
                    description: "CPU request"
                  memory:
                    type: string
                    description: "Memory request"
              config:
                type: object
                additionalProperties:
                  type: string
                description: "Application configuration"
            required:
            - name
            - version
            - image
            - environment
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Running", "Failed", "Succeeded"]
              message:
                type: string
              lastUpdated:
                type: string
                format: date-time
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                      enum: ["True", "False", "Unknown"]
                    reason:
                      type: string
                    message:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames:
    - app
    - apps
    categories:
    - hashfoundry

BASIC_CRD_EOF
    
    echo "2. Database CRD with advanced features:"
    cat << DATABASE_CRD_EOF > database-crd.yaml
# Advanced Database Custom Resource Definition
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.data.hashfoundry.io
  labels:
    app: hashfoundry-crd
    component: database-manager
spec:
  group: data.hashfoundry.io
  versions:
  - name: v1alpha1
    served: true
    storage: false
    deprecated: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              type:
                type: string
                enum: ["postgresql", "mysql", "redis"]
          status:
            type: object
  - name: v1beta1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              type:
                type: string
                enum: ["postgresql", "mysql", "redis", "mongodb"]
              version:
                type: string
          status:
            type: object
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              type:
                type: string
                enum: ["postgresql", "mysql", "redis", "mongodb", "elasticsearch"]
                description: "Database type"
              version:
                type: string
                description: "Database version"
              size:
                type: string
                enum: ["small", "medium", "large", "xlarge"]
                description: "Database size"
              storage:
                type: object
                properties:
                  size:
                    type: string
                    pattern: '^[0-9]+[KMGT]i$'
                  storageClass:
                    type: string
                  accessMode:
                    type: string
                    enum: ["ReadWriteOnce", "ReadOnlyMany", "ReadWriteMany"]
                required:
                - size
              backup:
                type: object
                properties:
                  enabled:
                    type: boolean
                  schedule:
                    type: string
                    description: "Cron schedule for backups"
                  retention:
                    type: integer
                    minimum: 1
                    maximum: 365
                    description: "Backup retention in days"
              monitoring:
                type: object
                properties:
                  enabled:
                    type: boolean
                  metrics:
                    type: array
                    items:
                      type: string
              security:
                type: object
                properties:
                  encryption:
                    type: boolean
                  ssl:
                    type: boolean
                  authentication:
                    type: object
                    properties:
                      method:
                        type: string
                        enum: ["password", "certificate", "ldap"]
                      users:
                        type: array
                        items:
                          type: object
                          properties:
                            username:
                              type: string
                            role:
                              type: string
                              enum: ["admin", "readwrite", "readonly"]
            required:
            - type
            - version
            - size
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Creating", "Running", "Updating", "Failed", "Deleting"]
              endpoint:
                type: string
              credentials:
                type: object
                properties:
                  secretName:
                    type: string
              backupStatus:
                type: object
                properties:
                  lastBackup:
                    type: string
                    format: date-time
                  nextBackup:
                    type: string
                    format: date-time
                  status:
                    type: string
              metrics:
                type: object
                properties:
                  connections:
                    type: integer
                  cpu:
                    type: string
                  memory:
                    type: string
                  storage:
                    type: string
    # Additional printer columns for kubectl output
    additionalPrinterColumns:
    - name: Type
      type: string
      jsonPath: .spec.type
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Size
      type: string
      jsonPath: .spec.size
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames:
    - db
    categories:
    - data
    - hashfoundry

DATABASE_CRD_EOF
    
    echo "✅ Basic CRDs created:"
    echo "  - basic-application-crd.yaml"
    echo "  - database-crd.yaml"
    echo
}

# Функция для создания Custom Resources
create_custom_resources() {
    echo "=== Creating Custom Resource Examples ==="
    
    echo "1. Application Custom Resources:"
    cat << APP_CR_EOF > application-custom-resources.yaml
# Development Application
apiVersion: hashfoundry.io/v1
kind: Application
metadata:
  name: web-app-dev
  namespace: development
  labels:
    app: web-app
    environment: development
    tier: frontend
spec:
  name: "HashFoundry Web App"
  version: "v1.2.3"
  replicas: 2
  image: "nginx:alpine"
  port: 80
  environment: "development"
  resources:
    cpu: "100m"
    memory: "128Mi"
  config:
    DEBUG: "true"
    LOG_LEVEL: "debug"
    API_URL: "http://api-dev.hashfoundry.local"

---
# Staging Application
apiVersion: hashfoundry.io/v1
kind: Application
metadata:
  name: web-app-staging
  namespace: staging
  labels:
    app: web-app
    environment: staging
    tier: frontend
spec:
  name: "HashFoundry Web App"
  version: "v1.2.3"
  replicas: 3
  image: "nginx:alpine"
  port: 80
  environment: "staging"
  resources:
    cpu: "200m"
    memory: "256Mi"
  config:
    DEBUG: "false"
    LOG_LEVEL: "info"
    API_URL: "http://api-staging.hashfoundry.local"

---
# Production Application
apiVersion: hashfoundry.io/v1
kind: Application
metadata:
  name: web-app-prod
  namespace: production
  labels:
    app: web-app
    environment: production
    tier: frontend
spec:
  name: "HashFoundry Web App"
  version: "v1.2.3"
  replicas: 5
  image: "nginx:alpine"
  port: 80
  environment: "production"
  resources:
    cpu: "500m"
    memory: "512Mi"
  config:
    DEBUG: "false"
    LOG_LEVEL: "warn"
    API_URL: "https://api.hashfoundry.io"

APP_CR_EOF
    
    echo "2. Database Custom Resources:"
    cat << DB_CR_EOF > database-custom-resources.yaml
# PostgreSQL Database for Development
apiVersion: data.hashfoundry.io/v1
kind: Database
metadata:
  name: postgres-dev
  namespace: development
  labels:
    app: postgres
    environment: development
    tier: data
spec:
  type: "postgresql"
  version: "13.7"
  size: "small"
  storage:
    size: "10Gi"
    storageClass: "standard"
    accessMode: "ReadWriteOnce"
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 7
  monitoring:
    enabled: true
    metrics:
    - "connections"
    - "queries_per_second"
    - "cache_hit_ratio"
  security:
    encryption: true
    ssl: true
    authentication:
      method: "password"
      users:
      - username: "app_user"
        role: "readwrite"
      - username: "readonly_user"
        role: "readonly"

---
# Redis Cache for Production
apiVersion: data.hashfoundry.io/v1
kind: Database
metadata:
  name: redis-cache-prod
  namespace: production
  labels:
    app: redis
    environment: production
    tier: cache
spec:
  type: "redis"
  version: "6.2"
  size: "medium"
  storage:
    size: "20Gi"
    storageClass: "fast-ssd"
    accessMode: "ReadWriteOnce"
  backup:
    enabled: true
    schedule: "0 */6 * * *"
    retention: 30
  monitoring:
    enabled: true
    metrics:
    - "memory_usage"
    - "operations_per_second"
    - "hit_ratio"
  security:
    encryption: true
    ssl: false
    authentication:
      method: "password"

---
# MongoDB for Analytics
apiVersion: data.hashfoundry.io/v1
kind: Database
metadata:
  name: mongodb-analytics
  namespace: analytics
  labels:
    app: mongodb
    environment: production
    tier: analytics
spec:
  type: "mongodb"
  version: "5.0"
  size: "large"
  storage:
    size: "100Gi"
    storageClass: "fast-ssd"
    accessMode: "ReadWriteOnce"
  backup:
    enabled: true
    schedule: "0 1 * * *"
    retention: 90
  monitoring:
    enabled: true
    metrics:
    - "operations_per_second"
    - "connections"
    - "replication_lag"
  security:
    encryption: true
    ssl: true
    authentication:
      method: "certificate"
      users:
      - username: "analytics_user"
        role: "readwrite"
      - username: "report_user"
        role: "readonly"

DB_CR_EOF
    
    echo "✅ Custom Resources created:"
    echo "  - application-custom-resources.yaml"
    echo "  - database-custom-resources.yaml"
    echo
}

# Функция для демонстрации CRD features
demonstrate_crd_features() {
    echo "=== Demonstrating CRD Features ==="
    
    echo "1. CRD with subresources:"
    cat << SUBRESOURCES_CRD_EOF > crd-with-subresources.yaml
# CRD with Status and Scale Subresources
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: webservices.apps.hashfoundry.io
spec:
  group: apps.hashfoundry.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
                minimum: 1
              image:
                type: string
              port:
                type: integer
          status:
            type: object
            properties:
              replicas:
                type: integer
              readyReplicas:
                type: integer
              conditions:
                type: array
                items:
                  type: object
    # Status subresource
    subresources:
      status: {}
      # Scale subresource
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
        labelSelectorPath: .status.labelSelector
    additionalPrinterColumns:
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Ready
      type: integer
      jsonPath: .status.readyReplicas
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: webservices
    singular: webservice
    kind: WebService
    shortNames:
    - ws

SUBRESOURCES_CRD_EOF
    
    echo "2. CRD with conversion webhook:"
    cat << CONVERSION_CRD_EOF > crd-with-conversion.yaml
# CRD with Conversion Webhook
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: microservices.platform.hashfoundry.io
spec:
  group: platform.hashfoundry.io
  versions:
  - name: v1alpha1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              replicas:
                type: integer
  - name: v1beta1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              replicas:
                type: integer
              resources:
                type: object
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              replicas:
                type: integer
              resources:
                type: object
              networking:
                type: object
  # Conversion webhook configuration
  conversion:
    strategy: Webhook
    webhook:
      clientConfig:
        service:
          name: microservice-conversion-webhook
          namespace: platform-system
          path: /convert
      conversionReviewVersions:
      - v1
      - v1beta1
  scope: Namespaced
  names:
    plural: microservices
    singular: microservice
    kind: Microservice

CONVERSION_CRD_EOF
    
    echo "3. CRD validation examples:"
    cat << VALIDATION_EXAMPLES_EOF > crd-validation-examples.yaml
# CRD with Advanced Validation
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: configurations.config.hashfoundry.io
spec:
  group: config.hashfoundry.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              # String validation
              name:
                type: string
                minLength: 3
                maxLength: 50
                pattern: '^[a-z0-9-]+$'
              
              # Number validation
              timeout:
                type: integer
                minimum: 1
                maximum: 3600
                multipleOf: 5
              
              # Array validation
              tags:
                type: array
                minItems: 1
                maxItems: 10
                uniqueItems: true
                items:
                  type: string
                  pattern: '^[a-z0-9-]+$'
              
              # Object validation
              database:
                type: object
                properties:
                  host:
                    type: string
                    format: hostname
                  port:
                    type: integer
                    minimum: 1
                    maximum: 65535
                  ssl:
                    type: boolean
                required:
                - host
                - port
              
              # Conditional validation
              environment:
                type: string
                enum: ["dev", "staging", "prod"]
              
              # Complex validation with dependencies
              features:
                type: object
                properties:
                  monitoring:
                    type: boolean
                  alerting:
                    type: boolean
                  backup:
                    type: boolean
                # If monitoring is true, alerting must be specified
                if:
                  properties:
                    monitoring:
                      const: true
                then:
                  required:
                  - alerting
              
              # OneOf validation
              storage:
                oneOf:
                - properties:
                    type:
                      const: "local"
                    path:
                      type: string
                  required:
                  - type
                  - path
                - properties:
                    type:
                      const: "s3"
                    bucket:
                      type: string
                    region:
                      type: string
                  required:
                  - type
                  - bucket
                  - region
            required:
            - name
            - environment
  scope: Namespaced
  names:
    plural: configurations
    singular: configuration
    kind: Configuration

VALIDATION_EXAMPLES_EOF
    
    echo "✅ CRD features demonstrated:"
    echo "  - crd-with-subresources.yaml"
    echo "  - crd-with-conversion.yaml"
    echo "  - crd-validation-examples.yaml"
    echo
}

# Функция для создания CRD management tools
create_crd_management_tools() {
    echo "=== Creating CRD Management Tools ==="
    
    echo "1. CRD inspection script:"
    cat << CRD_INSPECTOR_EOF > crd-inspector.sh
#!/bin/bash

echo "=== CRD Inspector ==="

# Function to list all CRDs
list_crds() {
    echo "=== All Custom Resource Definitions ==="
    kubectl get crd --no-headers | while read name established age; do
        GROUP=\$(kubectl get crd \$name -o jsonpath='{.spec.group}')
        VERSIONS=\$(kubectl get crd \$name -o jsonpath='{.spec.versions[*].name}' | tr ' ' ',')
        SCOPE=\$(kubectl get crd \$name -o jsonpath='{.spec.scope}')
        echo "📋 \$name"
        echo "   Group: \$GROUP"
        echo "   Versions: \$VERSIONS"
        echo "   Scope: \$SCOPE"
        echo "   Age: \$age"
        echo
    done
}

# Function to inspect specific CRD
inspect_crd() {
    local crd_name=\$1
    
    if [ -z "\$crd_name" ]; then
        echo "Usage: inspect_crd <crd-name>"
        return 1
    fi
    
    echo "=== Inspecting CRD: \$crd_name ==="
    
    if ! kubectl get crd \$crd_name >/dev/null 2>&1; then
        echo "❌ CRD \$crd_name not found"
        return 1
    fi
    
    echo "1. Basic Information:"
    kubectl get crd \$crd_name -o custom-columns=\
NAME:.metadata.name,\
GROUP:.spec.group,\
SCOPE:.spec.scope,\
AGE:.metadata.creationTimestamp
    
    echo
    echo "2. Versions:"
    kubectl get crd \$crd_name -o jsonpath='{.spec.versions[*]}' | jq -r '.[] | "Version: \(.name), Served: \(.served), Storage: \(.storage)"'
    
    echo
    echo "3. Names:"
    kubectl get crd \$crd_name -o jsonpath='{.spec.names}' | jq .
    
    echo
    echo "4. Schema (first version):"
    kubectl get crd \$crd_name -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec}' | jq .
    
    echo
    echo "5. Custom Resources:"
    PLURAL=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.names.plural}')
    GROUP=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.group}')
    
    echo "Listing \$PLURAL.\$GROUP resources:"
    kubectl get \$PLURAL --all-namespaces 2>/dev/null || echo "No custom resources found"
}

# Function to validate CRD
validate_crd() {
    local crd_file=\$1
    
    if [ -z "\$crd_file" ]; then
        echo "Usage: validate_crd <crd-file>"
        return 1
    fi
    
    echo "=== Validating CRD: \$crd_file ==="
    
    if [ ! -f "\$crd_file" ]; then
        echo "❌ File \$crd_file not found"
        return 1
    fi
    
    echo "1. YAML syntax check:"
    if yq eval . "\$crd_file" >/dev/null 2>&1; then
        echo "✅ YAML syntax is valid"
    else
        echo "❌ YAML syntax errors found"
        return 1
    fi
    
    echo
    echo "2. Kubernetes API validation:"
    if kubectl apply --dry-run=client -f "\$crd_file" >/dev/null 2>&1; then
        echo "✅ Kubernetes API validation passed"
    else
        echo "❌ Kubernetes API validation failed:"
        kubectl apply --dry-run=client -f "\$crd_file"
        return 1
    fi
    
    echo
    echo "3. Schema validation check:"
    SCHEMA_VALID=\$(yq eval '.spec.versions[0].schema.openAPIV3Schema != null' "\$crd_file")
    if [ "\$SCHEMA_VALID" = "true" ]; then
        echo "✅ OpenAPI schema is present"
    else
        echo "⚠️  No OpenAPI schema found"
    fi
}

# Function to show CRD usage examples
show_crd_examples() {
    local crd_name=\$1
    
    if [ -z "\$crd_name" ]; then
        echo "Usage: show_crd_examples <crd-name>"
        return 1
    fi
    
    echo "=== CRD Usage Examples: \$crd_name ==="
    
    PLURAL=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.names.plural}')
    SINGULAR=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.names.singular}')
    GROUP=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.group}')
    VERSION=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.versions[?(@.storage==true)].name}')
    
    echo "1. List all resources:"
    echo "   kubectl get \$PLURAL --all-namespaces"
    echo
    
    echo "2. Describe a resource:"
    echo "   kubectl describe \$SINGULAR <name> -n <namespace>"
    echo
    
    echo "3. Get resource YAML:"
    echo "   kubectl get \$SINGULAR <name> -n <namespace> -o yaml"
    echo
    
    echo "4. Create resource example:"
    cat << EXAMPLE_EOF
apiVersion: \$GROUP/\$VERSION
kind: \$(kubectl get crd \$crd_name -o jsonpath='{.spec.names.kind}')
metadata:
  name: example-\$SINGULAR
  namespace: default
spec:
  # Add your spec here based on the CRD schema
EXAMPLE_EOF
}

# Main function
main() {
    case "\$1" in
        "list")
            list_crds
            ;;
        "inspect")
            inspect_crd "\$2"
            ;;
        "validate")
            validate_crd "\$2"
            ;;
        "examples")
            show_crd_examples "\$2"
            ;;
        *)
            echo "Usage: \$0 [list|inspect|validate|examples] [args...]"
            echo ""
            echo "CRD Inspector Commands:"
            echo "  list                    - List all CRDs"
            echo "  inspect <crd-name>      - Inspect specific CRD"
            echo "  validate <crd-file>     - Validate CRD file"
            echo "  examples <crd-name>     - Show usage examples"
            ;;
    esac
}

main "\$@"

CRD_INSPECTOR_EOF
    
    chmod +x crd-inspector.sh
    echo "✅ CRD inspector script created: crd-inspector.sh"
    echo
    
    echo "2. CRD testing script:"
    cat << CRD_TESTER_EOF > crd-tester.sh
#!/bin/bash

echo "=== CRD Tester ==="

# Function to test CRD lifecycle
test_crd_lifecycle() {
    local crd_file=\$1
    local cr_file=\$2
    
    if [ -z "\$crd_file" ] || [ -z "\$cr_file" ]; then
        echo "Usage: test_crd_lifecycle <crd-file> <cr-file>"
        return 1
    fi
    
    echo "=== Testing CRD Lifecycle ==="
    
    # Extract CRD name
    CRD_NAME=\$(yq eval '.metadata.name' "\$crd_file")
    
    echo "1. Creating CRD: \$CRD_NAME"
    if kubectl apply -f "\$crd_file"; then
        echo "✅ CRD created successfully"
    else
        echo "❌ Failed to create CRD"
        return 1
    fi
    
    echo
    echo "2. Waiting for CRD to be established..."
    kubectl wait --for condition=established crd/\$CRD_NAME --timeout=60s
    
    echo
    echo "3. Creating Custom Resource..."
    if kubectl apply -f "\$cr_file"; then
        echo "✅ Custom Resource created successfully"
    else
        echo "❌ Failed to create Custom Resource"
        kubectl delete -f "\$crd_file" --ignore-not-found=true
        return 1
    fi
    
    echo
    echo "4. Verifying Custom Resource..."
    PLURAL=\$(kubectl get crd \$CRD_NAME -o jsonpath='{.spec.names.plural}')
    kubectl get \$PLURAL --all-namespaces
    
    echo
    echo "5. Testing CRUD operations..."
    
    # Get first CR name and namespace
    CR_NAME=\$(yq eval '.metadata.name' "\$cr_file")
    CR_NAMESPACE=\$(yq eval '.metadata.namespace // "default"' "\$cr_file")
    
    echo "   - Read operation:"
    kubectl get \$PLURAL \$CR_NAME -n \$CR_NAMESPACE -o yaml | head -20
    
    echo "   - Update operation (adding label):"
    kubectl label \$PLURAL \$CR_NAME -n \$CR_NAMESPACE test=crd-lifecycle
    
    echo "   - Verify update:"
    kubectl get \$PLURAL \$CR_NAME -n \$CR_NAMESPACE -o jsonpath='{.metadata.labels
