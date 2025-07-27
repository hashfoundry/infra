# 132. Как создавать и управлять CRDs

## 🎯 **Как создавать и управлять CRDs?**

**Создание и управление Custom Resource Definitions (CRDs)** включает в себя полный жизненный цикл: от проектирования схемы до развертывания, обновления и удаления. Правильное управление CRDs критически важно для стабильности и безопасности кластера.

## 🌐 **Жизненный цикл CRD:**

### **1. Design Phase:**
- **Schema Design** - проектирование OpenAPI схемы
- **Validation Rules** - правила валидации
- **Versioning Strategy** - стратегия версионирования
- **Naming Conventions** - соглашения об именовании

### **2. Development Phase:**
- **CRD Creation** - создание CRD манифеста
- **Testing** - тестирование схемы
- **Validation** - проверка корректности
- **Documentation** - документирование API

### **3. Management Phase:**
- **Deployment** - развертывание в кластере
- **Updates** - обновление версий
- **Migration** - миграция данных
- **Monitoring** - мониторинг использования

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive CRD management toolkit
cat << 'EOF' > crd-management-toolkit.sh
#!/bin/bash

echo "=== CRD Management Toolkit ==="
echo "Comprehensive guide for creating and managing CRDs in HashFoundry HA cluster"
echo

# Функция для создания CRD с нуля
create_crd_from_scratch() {
    echo "=== Creating CRD from Scratch ==="
    
    echo "1. Step-by-step CRD creation process:"
    cat << CRD_CREATION_GUIDE_EOF > crd-creation-guide.md
# CRD Creation Guide

## Step 1: Define the API Group and Resource
- Choose a unique group name (e.g., hashfoundry.io)
- Define resource names (plural, singular, kind)
- Select appropriate scope (Namespaced or Cluster)

## Step 2: Design the Schema
- Define spec properties
- Add validation rules
- Design status structure
- Plan for future versions

## Step 3: Create the CRD Manifest
- Use apiextensions.k8s.io/v1 API
- Include OpenAPI v3 schema
- Add printer columns for kubectl
- Configure subresources if needed

## Step 4: Test and Validate
- Validate YAML syntax
- Test with dry-run
- Create sample custom resources
- Verify validation rules

## Step 5: Deploy and Monitor
- Apply to cluster
- Wait for establishment
- Monitor usage
- Plan for updates

CRD_CREATION_GUIDE_EOF
    
    echo "2. Interactive CRD generator:"
    cat << CRD_GENERATOR_EOF > crd-generator.sh
#!/bin/bash

echo "=== Interactive CRD Generator ==="

# Function to collect CRD metadata
collect_metadata() {
    echo "Enter CRD metadata:"
    read -p "Group name (e.g., hashfoundry.io): " GROUP
    read -p "Resource kind (e.g., Application): " KIND
    read -p "Plural name (e.g., applications): " PLURAL
    read -p "Singular name (e.g., application): " SINGULAR
    read -p "Short names (comma-separated, e.g., app,apps): " SHORT_NAMES
    read -p "Categories (comma-separated, e.g., hashfoundry): " CATEGORIES
    read -p "Scope (Namespaced/Cluster): " SCOPE
    
    # Convert short names and categories to arrays
    IFS=',' read -ra SHORT_NAMES_ARRAY <<< "\$SHORT_NAMES"
    IFS=',' read -ra CATEGORIES_ARRAY <<< "\$CATEGORIES"
}

# Function to generate basic CRD structure
generate_crd() {
    local filename="\${PLURAL}-crd.yaml"
    
    cat << CRD_TEMPLATE_EOF > \$filename
# Generated CRD for \$KIND
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: \${PLURAL}.\${GROUP}
  labels:
    app: hashfoundry-crd
    component: \${SINGULAR}-manager
spec:
  group: \$GROUP
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
              # Add your spec properties here
              name:
                type: string
                description: "Resource name"
              enabled:
                type: boolean
                description: "Enable/disable resource"
                default: true
            required:
            - name
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
    additionalPrinterColumns:
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: \$SCOPE
  names:
    plural: \$PLURAL
    singular: \$SINGULAR
    kind: \$KIND
CRD_TEMPLATE_EOF

    # Add short names if provided
    if [ ! -z "\$SHORT_NAMES" ]; then
        echo "    shortNames:" >> \$filename
        for name in "\${SHORT_NAMES_ARRAY[@]}"; do
            echo "    - \${name// /}" >> \$filename
        done
    fi
    
    # Add categories if provided
    if [ ! -z "\$CATEGORIES" ]; then
        echo "    categories:" >> \$filename
        for category in "\${CATEGORIES_ARRAY[@]}"; do
            echo "    - \${category// /}" >> \$filename
        done
    fi
    
    echo "✅ CRD generated: \$filename"
}

# Main function
main() {
    collect_metadata
    generate_crd
    echo "Next steps:"
    echo "1. Edit the generated CRD to add your specific schema"
    echo "2. Validate with: kubectl apply --dry-run=client -f \${PLURAL}-crd.yaml"
    echo "3. Apply to cluster: kubectl apply -f \${PLURAL}-crd.yaml"
}

main

CRD_GENERATOR_EOF
    
    chmod +x crd-generator.sh
    echo "✅ CRD creation tools created:"
    echo "  - crd-creation-guide.md"
    echo "  - crd-generator.sh"
    echo
}

# Функция для управления версиями CRD
manage_crd_versions() {
    echo "=== Managing CRD Versions ==="
    
    echo "1. Multi-version CRD example:"
    cat << MULTI_VERSION_CRD_EOF > multi-version-crd.yaml
# Multi-version CRD with migration strategy
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: services.platform.hashfoundry.io
  labels:
    app: hashfoundry-platform
    component: service-manager
spec:
  group: platform.hashfoundry.io
  versions:
  # Legacy version - deprecated
  - name: v1alpha1
    served: true
    storage: false
    deprecated: true
    deprecationWarning: "platform.hashfoundry.io/v1alpha1 is deprecated, use v1beta1"
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
                default: 1
          status:
            type: object
    additionalPrinterColumns:
    - name: Image
      type: string
      jsonPath: .spec.image
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  
  # Current stable version
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
                minimum: 1
                maximum: 100
                default: 1
              resources:
                type: object
                properties:
                  cpu:
                    type: string
                    pattern: '^[0-9]+m?$'
                  memory:
                    type: string
                    pattern: '^[0-9]+[KMGT]i?$'
              ports:
                type: array
                items:
                  type: object
                  properties:
                    name:
                      type: string
                    port:
                      type: integer
                      minimum: 1
                      maximum: 65535
                    protocol:
                      type: string
                      enum: ["TCP", "UDP"]
                      default: "TCP"
            required:
            - image
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Running", "Failed"]
              replicas:
                type: integer
              readyReplicas:
                type: integer
    additionalPrinterColumns:
    - name: Image
      type: string
      jsonPath: .spec.image
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Ready
      type: integer
      jsonPath: .status.readyReplicas
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  
  # Next version - storage version
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
                description: "Container image"
              replicas:
                type: integer
                minimum: 1
                maximum: 100
                default: 1
                description: "Number of replicas"
              resources:
                type: object
                properties:
                  requests:
                    type: object
                    properties:
                      cpu:
                        type: string
                        pattern: '^[0-9]+m?$'
                      memory:
                        type: string
                        pattern: '^[0-9]+[KMGT]i?$'
                  limits:
                    type: object
                    properties:
                      cpu:
                        type: string
                        pattern: '^[0-9]+m?$'
                      memory:
                        type: string
                        pattern: '^[0-9]+[KMGT]i?$'
              networking:
                type: object
                properties:
                  ports:
                    type: array
                    items:
                      type: object
                      properties:
                        name:
                          type: string
                        port:
                          type: integer
                          minimum: 1
                          maximum: 65535
                        protocol:
                          type: string
                          enum: ["TCP", "UDP"]
                          default: "TCP"
                  ingress:
                    type: object
                    properties:
                      enabled:
                        type: boolean
                        default: false
                      host:
                        type: string
                      tls:
                        type: boolean
                        default: false
              monitoring:
                type: object
                properties:
                  enabled:
                    type: boolean
                    default: false
                  metrics:
                    type: object
                    properties:
                      path:
                        type: string
                        default: "/metrics"
                      port:
                        type: integer
                        minimum: 1
                        maximum: 65535
            required:
            - image
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Creating", "Running", "Updating", "Failed", "Deleting"]
              replicas:
                type: integer
              readyReplicas:
                type: integer
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
              observedGeneration:
                type: integer
    # Subresources for v1
    subresources:
      status: {}
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
    additionalPrinterColumns:
    - name: Image
      type: string
      jsonPath: .spec.image
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Ready
      type: integer
      jsonPath: .status.readyReplicas
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  
  scope: Namespaced
  names:
    plural: services
    singular: service
    kind: Service
    shortNames:
    - svc
    - svcs
    categories:
    - platform
    - hashfoundry

MULTI_VERSION_CRD_EOF
    
    echo "2. Version migration script:"
    cat << VERSION_MIGRATION_EOF > crd-version-migration.sh
#!/bin/bash

echo "=== CRD Version Migration ==="

# Function to migrate CRD to new version
migrate_crd_version() {
    local crd_name=\$1
    local old_version=\$2
    local new_version=\$3
    
    if [ -z "\$crd_name" ] || [ -z "\$old_version" ] || [ -z "\$new_version" ]; then
        echo "Usage: migrate_crd_version <crd-name> <old-version> <new-version>"
        return 1
    fi
    
    echo "=== Migrating CRD \$crd_name from \$old_version to \$new_version ==="
    
    # Check if CRD exists
    if ! kubectl get crd \$crd_name >/dev/null 2>&1; then
        echo "❌ CRD \$crd_name not found"
        return 1
    fi
    
    # Get resource info
    PLURAL=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.names.plural}')
    GROUP=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.group}')
    
    echo "1. Backing up existing resources..."
    kubectl get \$PLURAL --all-namespaces -o yaml > "\${crd_name}-backup-\$(date +%Y%m%d-%H%M%S).yaml"
    
    echo "2. Listing resources using old version..."
    kubectl get \$PLURAL --all-namespaces -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
VERSION:.apiVersion
    
    echo "3. Checking version support..."
    OLD_SERVED=\$(kubectl get crd \$crd_name -o jsonpath="{.spec.versions[?(@.name=='\$old_version')].served}")
    NEW_SERVED=\$(kubectl get crd \$crd_name -o jsonpath="{.spec.versions[?(@.name=='\$new_version')].served}")
    
    if [ "\$OLD_SERVED" != "true" ]; then
        echo "❌ Old version \$old_version is not served"
        return 1
    fi
    
    if [ "\$NEW_SERVED" != "true" ]; then
        echo "❌ New version \$new_version is not served"
        return 1
    fi
    
    echo "4. Converting resources to new version..."
    kubectl get \$PLURAL --all-namespaces -o yaml | \
    sed "s|apiVersion: \$GROUP/\$old_version|apiVersion: \$GROUP/\$new_version|g" | \
    kubectl apply -f -
    
    echo "5. Verifying migration..."
    kubectl get \$PLURAL --all-namespaces -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
VERSION:.apiVersion
    
    echo "✅ Migration completed"
    echo "Next steps:"
    echo "- Test applications with new version"
    echo "- Update CRD to make new version storage version"
    echo "- Deprecate old version"
}

# Function to update storage version
update_storage_version() {
    local crd_name=\$1
    local new_storage_version=\$2
    
    if [ -z "\$crd_name" ] || [ -z "\$new_storage_version" ]; then
        echo "Usage: update_storage_version <crd-name> <new-storage-version>"
        return 1
    fi
    
    echo "=== Updating storage version for \$crd_name to \$new_storage_version ==="
    
    # Create patch to update storage version
    cat << PATCH_EOF > storage-version-patch.yaml
spec:
  versions:
PATCH_EOF
    
    # Get all versions and update storage flags
    kubectl get crd \$crd_name -o jsonpath='{.spec.versions[*].name}' | tr ' ' '\n' | while read version; do
        if [ "\$version" = "\$new_storage_version" ]; then
            echo "  - name: \$version" >> storage-version-patch.yaml
            echo "    served: true" >> storage-version-patch.yaml
            echo "    storage: true" >> storage-version-patch.yaml
        else
            echo "  - name: \$version" >> storage-version-patch.yaml
            echo "    served: true" >> storage-version-patch.yaml
            echo "    storage: false" >> storage-version-patch.yaml
        fi
    done
    
    # Apply patch
    kubectl patch crd \$crd_name --type=merge --patch-file=storage-version-patch.yaml
    
    # Cleanup
    rm -f storage-version-patch.yaml
    
    echo "✅ Storage version updated to \$new_storage_version"
}

# Main function
main() {
    case "\$1" in
        "migrate")
            migrate_crd_version "\$2" "\$3" "\$4"
            ;;
        "storage")
            update_storage_version "\$2" "\$3"
            ;;
        *)
            echo "Usage: \$0 [migrate|storage] [args...]"
            echo ""
            echo "Version Migration Commands:"
            echo "  migrate <crd-name> <old-version> <new-version> - Migrate resources"
            echo "  storage <crd-name> <new-storage-version>       - Update storage version"
            ;;
    esac
}

main "\$@"

VERSION_MIGRATION_EOF
    
    chmod +x crd-version-migration.sh
    echo "✅ Version management tools created:"
    echo "  - multi-version-crd.yaml"
    echo "  - crd-version-migration.sh"
    echo
}

# Функция для валидации и тестирования CRD
validate_and_test_crd() {
    echo "=== CRD Validation and Testing ==="
    
    echo "1. CRD validation script:"
    cat << CRD_VALIDATOR_EOF > crd-validator.sh
#!/bin/bash

echo "=== CRD Validator ==="

# Function to validate CRD schema
validate_crd_schema() {
    local crd_file=\$1
    
    if [ -z "\$crd_file" ]; then
        echo "Usage: validate_crd_schema <crd-file>"
        return 1
    fi
    
    echo "=== Validating CRD Schema: \$crd_file ==="
    
    if [ ! -f "\$crd_file" ]; then
        echo "❌ File \$crd_file not found"
        return 1
    fi
    
    echo "1. YAML syntax validation:"
    if yq eval . "\$crd_file" >/dev/null 2>&1; then
        echo "✅ YAML syntax is valid"
    else
        echo "❌ YAML syntax errors:"
        yq eval . "\$crd_file"
        return 1
    fi
    
    echo
    echo "2. Required fields validation:"
    
    # Check API version
    API_VERSION=\$(yq eval '.apiVersion' "\$crd_file")
    if [ "\$API_VERSION" = "apiextensions.k8s.io/v1" ]; then
        echo "✅ API version is correct"
    else
        echo "❌ API version should be apiextensions.k8s.io/v1, found: \$API_VERSION"
    fi
    
    # Check kind
    KIND=\$(yq eval '.kind' "\$crd_file")
    if [ "\$KIND" = "CustomResourceDefinition" ]; then
        echo "✅ Kind is correct"
    else
        echo "❌ Kind should be CustomResourceDefinition, found: \$KIND"
    fi
    
    # Check group
    GROUP=\$(yq eval '.spec.group' "\$crd_file")
    if [ "\$GROUP" != "null" ] && [ ! -z "\$GROUP" ]; then
        echo "✅ Group is specified: \$GROUP"
    else
        echo "❌ Group is required"
    fi
    
    # Check versions
    VERSIONS_COUNT=\$(yq eval '.spec.versions | length' "\$crd_file")
    if [ "\$VERSIONS_COUNT" -gt 0 ]; then
        echo "✅ Versions are specified (\$VERSIONS_COUNT versions)"
    else
        echo "❌ At least one version is required"
    fi
    
    # Check storage version
    STORAGE_VERSIONS=\$(yq eval '.spec.versions[] | select(.storage == true) | .name' "\$crd_file" | wc -l)
    if [ "\$STORAGE_VERSIONS" -eq 1 ]; then
        echo "✅ Exactly one storage version found"
    else
        echo "❌ Exactly one storage version is required, found: \$STORAGE_VERSIONS"
    fi
    
    echo
    echo "3. Schema validation:"
    
    # Check OpenAPI schema
    SCHEMA_EXISTS=\$(yq eval '.spec.versions[0].schema.openAPIV3Schema != null' "\$crd_file")
    if [ "\$SCHEMA_EXISTS" = "true" ]; then
        echo "✅ OpenAPI v3 schema is present"
    else
        echo "❌ OpenAPI v3 schema is required"
    fi
    
    # Check spec properties
    SPEC_PROPS=\$(yq eval '.spec.versions[0].schema.openAPIV3Schema.properties.spec != null' "\$crd_file")
    if [ "\$SPEC_PROPS" = "true" ]; then
        echo "✅ Spec properties are defined"
    else
        echo "⚠️  No spec properties defined"
    fi
    
    echo
    echo "4. Kubernetes API validation:"
    if kubectl apply --dry-run=client -f "\$crd_file" >/dev/null 2>&1; then
        echo "✅ Kubernetes API validation passed"
    else
        echo "❌ Kubernetes API validation failed:"
        kubectl apply --dry-run=client -f "\$crd_file"
    fi
}

# Function to test CRD with sample resources
test_crd_with_samples() {
    local crd_file=\$1
    
    if [ -z "\$crd_file" ]; then
        echo "Usage: test_crd_with_samples <crd-file>"
        return 1
    fi
    
    echo "=== Testing CRD with Sample Resources ==="
    
    # Extract CRD information
    CRD_NAME=\$(yq eval '.metadata.name' "\$crd_file")
    GROUP=\$(yq eval '.spec.group' "\$crd_file")
    VERSION=\$(yq eval '.spec.versions[0].name' "\$crd_file")
    KIND=\$(yq eval '.spec.names.kind' "\$crd_file")
    
    echo "1. Creating CRD..."
    if kubectl apply -f "\$crd_file"; then
        echo "✅ CRD created successfully"
    else
        echo "❌ Failed to create CRD"
        return 1
    fi
    
    echo "2. Waiting for CRD to be established..."
    kubectl wait --for condition=established crd/\$CRD_NAME --timeout=60s
    
    echo "3. Creating valid sample resource..."
    cat << VALID_SAMPLE_EOF > valid-sample.yaml
apiVersion: \$GROUP/\$VERSION
kind: \$KIND
metadata:
  name: test-valid-sample
  namespace: default
spec:
  name: "Test Resource"
VALID_SAMPLE_EOF
    
    if kubectl apply -f valid-sample.yaml; then
        echo "✅ Valid sample resource created"
    else
        echo "❌ Failed to create valid sample resource"
    fi
    
    echo "4. Testing invalid resource (should fail)..."
    cat << INVALID_SAMPLE_EOF > invalid-sample.yaml
apiVersion: \$GROUP/\$VERSION
kind: \$KIND
metadata:
  name: test-invalid-sample
  namespace: default
spec:
  # Missing required fields
  invalid_field: "This should fail"
INVALID_SAMPLE_EOF
    
    if kubectl apply -f invalid-sample.yaml 2>/dev/null; then
        echo "⚠️  Invalid sample was accepted (validation may be too permissive)"
    else
        echo "✅ Invalid sample was rejected (validation working)"
    fi
    
    echo "5. Cleanup..."
    kubectl delete -f valid-sample.yaml --ignore-not-found=true
    kubectl delete -f invalid-sample.yaml --ignore-not-found=true
    kubectl delete -f "\$crd_file" --ignore-not-found=true
    
    rm -f valid-sample.yaml invalid-sample.yaml
    
    echo "✅ Testing completed"
}

# Main function
main() {
    case "\$1" in
        "schema")
            validate_crd_schema "\$2"
            ;;
        "test")
            test_crd_with_samples "\$2"
            ;;
        *)
            echo "Usage: \$0 [schema|test] <crd-file>"
            echo ""
            echo "CRD Validation Commands:"
            echo "  schema <crd-file> - Validate CRD schema"
            echo "  test <crd-file>   - Test CRD with sample resources"
            ;;
    esac
}

main "\$@"

CRD_VALIDATOR_EOF
    
    chmod +x crd-validator.sh
    echo "✅ CRD validation tools created: crd-validator.sh"
    echo
}

# Функция для мониторинга CRD
monitor_crd_usage() {
    echo "=== CRD Monitoring and Management ==="
    
    echo "1. CRD monitoring script:"
    cat << CRD_MONITOR_EOF > crd-monitor.sh
#!/bin/bash

echo "=== CRD Monitor ==="

# Function to show CRD overview
show_crd_overview() {
    echo "=== CRD Overview ==="
    
    echo "1. Total CRDs in cluster:"
    TOTAL_CRDS=\$(kubectl get crd --no-headers | wc -l)
    echo "   Total: \$TOTAL_CRDS CRDs"
    
    echo
    echo "2. CRDs by group:"
    kubectl get crd -o jsonpath='{.items[*].spec.group}' | tr ' ' '\n' | sort | uniq -c | sort -nr
    
    echo
    echo "3. CRDs by scope:"
    echo "   Namespaced: \$(kubectl get crd -o jsonpath='{.items[?(@.spec.scope=="Namespaced")].metadata.name}' | wc -w)"
    echo "   Cluster: \$(kubectl get crd -o jsonpath='{.items[?(@.spec.scope=="Cluster")].metadata.name}' | wc -w)"
    
    echo
    echo "4. Recently created CRDs (last 7 days):"
    kubectl get crd --sort-by=.metadata.creationTimestamp | tail -10
}

# Function to show resource usage
show_resource_usage() {
    echo "=== Custom Resource Usage ==="
    
    kubectl get crd --no-headers | while read crd_name established age; do
        PLURAL=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.names.plural}')
        GROUP=\$(kubectl get crd \$crd_name -o jsonpath='{.spec.group}')
        
        # Count resources
        RESOURCE_COUNT=\$(kubectl get \$PLURAL --all-namespaces --no-headers 2>/dev/null | wc -l)
        
        if [ \$RESOURCE_COUNT -gt 0 ]; then
            echo "📋 \$crd_name: \$RESOURCE_COUNT resources"
            
            # Show namespace distribution
            kubectl get \$PLURAL --all-namespaces --no-headers 2>/dev/null | \
            awk '{print \$1}' | sort | uniq -c | \
            awk '{printf "   %s: %d\\n", \$2, \$1}'
        fi
    done
}

# Function to check CRD health
check_crd_health() {
    echo "=== CRD Health Check ==="
    
    echo "1. CRD establishment status:"
    kubectl get crd -o custom-columns=\
NAME:.metadata.name,\
ESTABLISHED:.status.conditions[?(@.type==\"Established\")].status,\
AGE:.metadata.creationTimestamp
    
    echo
    echo "2. CRDs with issues:"
    kubectl get crd -o json | jq -r '.items[] | select(.status.conditions[]?.status != "True") | .metadata.name' | \
    while read crd_name; do
        if [ ! -z "\$crd_name" ]; then
            echo "❌ \$crd_name has issues"
            kubectl get crd \$crd_name -o jsonpath='{.status.conditions[*]}' | jq .
        fi
    done
    
    echo
    echo "3. Deprecated versions in use:"
    kubectl get crd -o json | jq -r '.items[] | select(.spec.versions[]?.deprecated == true) | .metadata.name' | \
    while read crd_name; do
        if [ ! -z "\$crd_name" ]; then
            echo "⚠️  \$crd_name has deprecated versions"
            kubectl get crd \$crd_name -o jsonpath='{.spec
