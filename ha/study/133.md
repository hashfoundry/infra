# 133. Что такое Operator Pattern

## 🎯 **Что такое Operator Pattern?**

**Operator Pattern** - это метод расширения Kubernetes для автоматизации управления сложными приложениями. Operators объединяют Custom Resource Definitions (CRDs) с контроллерами для кодирования операционных знаний о том, как развертывать, масштабировать и управлять приложениями в Kubernetes.

## 🌐 **Архитектура Operator Pattern:**

### **1. Core Concepts:**
- **Custom Resources** - декларативное описание желаемого состояния
- **Controller** - логика для достижения желаемого состояния
- **Reconciliation Loop** - непрерывный процесс сравнения и корректировки
- **Domain Knowledge** - встроенные знания об управлении приложением

### **2. Operator Capabilities:**
- **Level 1: Basic Install** - автоматическая установка
- **Level 2: Seamless Upgrades** - обновления без простоев
- **Level 3: Full Lifecycle** - полное управление жизненным циклом
- **Level 4: Deep Insights** - мониторинг и аналитика
- **Level 5: Auto Pilot** - автоматическое самовосстановление

### **3. Operator Types:**
- **Infrastructure Operators** - управление инфраструктурой
- **Application Operators** - управление приложениями
- **Platform Operators** - управление платформами
- **Data Operators** - управление базами данных

## 📊 **Практические примеры из вашего HA кластера:**

```bash
# Создать comprehensive operator pattern learning toolkit
cat << 'EOF' > operator-pattern-toolkit.sh
#!/bin/bash

echo "=== Operator Pattern Learning Toolkit ==="
echo "Comprehensive guide for understanding and implementing Operator Pattern in HashFoundry HA cluster"
echo

# Функция для демонстрации основных концепций Operator Pattern
demonstrate_operator_concepts() {
    echo "=== Demonstrating Operator Pattern Concepts ==="
    
    echo "1. Operator Pattern overview:"
    cat << OPERATOR_OVERVIEW_EOF > operator-pattern-overview.md
# Operator Pattern Overview

## What is an Operator?

An Operator is a method of packaging, deploying, and managing a Kubernetes application. 
Operators use Custom Resource Definitions (CRDs) to manage applications and their components.

## Key Components:

### 1. Custom Resource Definition (CRD)
- Defines the API for your application
- Specifies the desired state schema
- Includes validation rules

### 2. Custom Resource (CR)
- Instance of the CRD
- Represents the desired state
- User-facing configuration

### 3. Controller
- Watches for changes to Custom Resources
- Implements the reconciliation logic
- Manages the actual application state

### 4. Reconciliation Loop
- Continuously compares desired vs actual state
- Takes actions to achieve desired state
- Handles errors and retries

## Operator Maturity Levels:

### Level 1: Basic Install
- Automated application provisioning
- Configuration through CRDs
- Basic lifecycle management

### Level 2: Seamless Upgrades
- Patch and minor version upgrades
- Rolling updates
- Backup before upgrade

### Level 3: Full Lifecycle
- App lifecycle management
- Storage lifecycle management
- Scaling and configuration changes

### Level 4: Deep Insights
- Metrics and alerting
- Log aggregation
- Workload analysis

### Level 5: Auto Pilot
- Horizontal/vertical scaling
- Abnormality detection
- Scheduling tuning

## Benefits:

1. **Operational Knowledge Codification**
   - Best practices encoded in software
   - Consistent operations across environments
   - Reduced human error

2. **Automation**
   - Automated deployment and scaling
   - Self-healing capabilities
   - Automated backups and recovery

3. **Kubernetes-native**
   - Uses Kubernetes APIs
   - Integrates with existing tools
   - Follows Kubernetes patterns

OPERATOR_OVERVIEW_EOF
    
    echo "2. Simple database operator example:"
    cat << DATABASE_OPERATOR_CRD_EOF > database-operator-crd.yaml
# Database Operator CRD
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.db.hashfoundry.io
  labels:
    app: database-operator
    component: crd
spec:
  group: db.hashfoundry.io
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
              type:
                type: string
                enum: ["postgresql", "mysql", "redis"]
                description: "Database type"
              version:
                type: string
                description: "Database version"
              replicas:
                type: integer
                minimum: 1
                maximum: 5
                default: 1
                description: "Number of database replicas"
              storage:
                type: object
                properties:
                  size:
                    type: string
                    pattern: '^[0-9]+[KMGT]i$'
                    description: "Storage size"
                  storageClass:
                    type: string
                    description: "Storage class"
                required:
                - size
              backup:
                type: object
                properties:
                  enabled:
                    type: boolean
                    default: false
                  schedule:
                    type: string
                    description: "Backup schedule (cron format)"
                  retention:
                    type: integer
                    minimum: 1
                    maximum: 365
                    default: 7
                    description: "Backup retention in days"
              monitoring:
                type: object
                properties:
                  enabled:
                    type: boolean
                    default: false
                  scrapeInterval:
                    type: string
                    default: "30s"
            required:
            - type
            - version
            - storage
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
              endpoint:
                type: string
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
    additionalPrinterColumns:
    - name: Type
      type: string
      jsonPath: .spec.type
    - name: Version
      type: string
      jsonPath: .spec.version
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
    plural: databases
    singular: database
    kind: Database
    shortNames:
    - db
    categories:
    - database
    - hashfoundry

DATABASE_OPERATOR_CRD_EOF
    
    echo "3. Database Custom Resource examples:"
    cat << DATABASE_CR_EXAMPLES_EOF > database-cr-examples.yaml
# PostgreSQL Database for Development
apiVersion: db.hashfoundry.io/v1
kind: Database
metadata:
  name: postgres-dev
  namespace: development
  labels:
    app: postgres
    environment: development
spec:
  type: "postgresql"
  version: "13.7"
  replicas: 1
  storage:
    size: "10Gi"
    storageClass: "standard"
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 7
  monitoring:
    enabled: true
    scrapeInterval: "30s"

---
# MySQL Database for Production
apiVersion: db.hashfoundry.io/v1
kind: Database
metadata:
  name: mysql-prod
  namespace: production
  labels:
    app: mysql
    environment: production
spec:
  type: "mysql"
  version: "8.0"
  replicas: 3
  storage:
    size: "100Gi"
    storageClass: "fast-ssd"
  backup:
    enabled: true
    schedule: "0 1 * * *"
    retention: 30
  monitoring:
    enabled: true
    scrapeInterval: "15s"

---
# Redis Cache for Staging
apiVersion: db.hashfoundry.io/v1
kind: Database
metadata:
  name: redis-staging
  namespace: staging
  labels:
    app: redis
    environment: staging
spec:
  type: "redis"
  version: "6.2"
  replicas: 2
  storage:
    size: "20Gi"
    storageClass: "standard"
  backup:
    enabled: false
  monitoring:
    enabled: true
    scrapeInterval: "30s"

DATABASE_CR_EXAMPLES_EOF
    
    echo "✅ Operator concepts demonstrated:"
    echo "  - operator-pattern-overview.md"
    echo "  - database-operator-crd.yaml"
    echo "  - database-cr-examples.yaml"
    echo
}

# Функция для создания простого оператора
create_simple_operator() {
    echo "=== Creating Simple Operator Example ==="
    
    echo "1. Web Application Operator CRD:"
    cat << WEBAPP_OPERATOR_CRD_EOF > webapp-operator-crd.yaml
# Web Application Operator CRD
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: webapps.apps.hashfoundry.io
  labels:
    app: webapp-operator
    component: crd
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
              image:
                type: string
                description: "Container image"
              replicas:
                type: integer
                minimum: 1
                maximum: 10
                default: 1
                description: "Number of replicas"
              port:
                type: integer
                minimum: 1
                maximum: 65535
                default: 8080
                description: "Application port"
              environment:
                type: string
                enum: ["development", "staging", "production"]
                description: "Deployment environment"
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
              resources:
                type: object
                properties:
                  requests:
                    type: object
                    properties:
                      cpu:
                        type: string
                      memory:
                        type: string
                  limits:
                    type: object
                    properties:
                      cpu:
                        type: string
                      memory:
                        type: string
              autoscaling:
                type: object
                properties:
                  enabled:
                    type: boolean
                    default: false
                  minReplicas:
                    type: integer
                    minimum: 1
                    default: 1
                  maxReplicas:
                    type: integer
                    minimum: 1
                    default: 10
                  targetCPUUtilization:
                    type: integer
                    minimum: 1
                    maximum: 100
                    default: 80
            required:
            - image
            - environment
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
              url:
                type: string
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
    - name: URL
      type: string
      jsonPath: .status.url
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: webapps
    singular: webapp
    kind: WebApp
    shortNames:
    - wa
    categories:
    - applications
    - hashfoundry

WEBAPP_OPERATOR_CRD_EOF
    
    echo "2. Simple operator controller (pseudo-code):"
    cat << OPERATOR_CONTROLLER_EOF > operator-controller-pseudocode.py
#!/usr/bin/env python3
"""
Simple Web Application Operator Controller (Pseudo-code)
This demonstrates the core logic of an operator controller.
"""

import time
import logging
from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class WebAppOperator:
    def __init__(self):
        # Load Kubernetes configuration
        try:
            config.load_incluster_config()
        except:
            config.load_kube_config()
        
        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        self.networking_v1 = client.NetworkingV1Api()
        self.custom_api = client.CustomObjectsApi()
        
        # CRD information
        self.group = "apps.hashfoundry.io"
        self.version = "v1"
        self.plural = "webapps"
    
    def reconcile(self, webapp_name, webapp_namespace, webapp_spec):
        """
        Reconcile function - core of the operator pattern
        Ensures actual state matches desired state
        """
        logger.info(f"Reconciling WebApp {webapp_namespace}/{webapp_name}")
        
        try:
            # 1. Create or update Deployment
            self.ensure_deployment(webapp_name, webapp_namespace, webapp_spec)
            
            # 2. Create or update Service
            self.ensure_service(webapp_name, webapp_namespace, webapp_spec)
            
            # 3. Create or update Ingress (if enabled)
            if webapp_spec.get('ingress', {}).get('enabled', False):
                self.ensure_ingress(webapp_name, webapp_namespace, webapp_spec)
            
            # 4. Create or update HPA (if enabled)
            if webapp_spec.get('autoscaling', {}).get('enabled', False):
                self.ensure_hpa(webapp_name, webapp_namespace, webapp_spec)
            
            # 5. Update status
            self.update_status(webapp_name, webapp_namespace, "Running")
            
        except Exception as e:
            logger.error(f"Error reconciling WebApp {webapp_namespace}/{webapp_name}: {e}")
            self.update_status(webapp_name, webapp_namespace, "Failed", str(e))
    
    def ensure_deployment(self, name, namespace, spec):
        """Ensure Deployment exists and matches spec"""
        deployment_name = f"{name}-webapp"
        
        # Define Deployment manifest
        deployment = client.V1Deployment(
            metadata=client.V1ObjectMeta(
                name=deployment_name,
                namespace=namespace,
                labels={"app": name, "managed-by": "webapp-operator"}
            ),
            spec=client.V1DeploymentSpec(
                replicas=spec.get('replicas', 1),
                selector=client.V1LabelSelector(
                    match_labels={"app": name}
                ),
                template=client.V1PodTemplateSpec(
                    metadata=client.V1ObjectMeta(
                        labels={"app": name}
                    ),
                    spec=client.V1PodSpec(
                        containers=[
                            client.V1Container(
                                name="webapp",
                                image=spec['image'],
                                ports=[client.V1ContainerPort(
                                    container_port=spec.get('port', 8080)
                                )],
                                resources=self.build_resources(spec.get('resources', {}))
                            )
                        ]
                    )
                )
            )
        )
        
        # Create or update Deployment
        try:
            self.apps_v1.read_namespaced_deployment(deployment_name, namespace)
            # Deployment exists, update it
            self.apps_v1.patch_namespaced_deployment(
                name=deployment_name,
                namespace=namespace,
                body=deployment
            )
            logger.info(f"Updated Deployment {deployment_name}")
        except ApiException as e:
            if e.status == 404:
                # Deployment doesn't exist, create it
                self.apps_v1.create_namespaced_deployment(
                    namespace=namespace,
                    body=deployment
                )
                logger.info(f"Created Deployment {deployment_name}")
            else:
                raise
    
    def ensure_service(self, name, namespace, spec):
        """Ensure Service exists and matches spec"""
        service_name = f"{name}-webapp-service"
        
        service = client.V1Service(
            metadata=client.V1ObjectMeta(
                name=service_name,
                namespace=namespace,
                labels={"app": name, "managed-by": "webapp-operator"}
            ),
            spec=client.V1ServiceSpec(
                selector={"app": name},
                ports=[client.V1ServicePort(
                    port=80,
                    target_port=spec.get('port', 8080)
                )]
            )
        )
        
        try:
            self.v1.read_namespaced_service(service_name, namespace)
            self.v1.patch_namespaced_service(
                name=service_name,
                namespace=namespace,
                body=service
            )
            logger.info(f"Updated Service {service_name}")
        except ApiException as e:
            if e.status == 404:
                self.v1.create_namespaced_service(
                    namespace=namespace,
                    body=service
                )
                logger.info(f"Created Service {service_name}")
            else:
                raise
    
    def ensure_ingress(self, name, namespace, spec):
        """Ensure Ingress exists if enabled"""
        ingress_config = spec.get('ingress', {})
        if not ingress_config.get('enabled', False):
            return
        
        ingress_name = f"{name}-webapp-ingress"
        host = ingress_config.get('host', f"{name}.{namespace}.local")
        
        # Ingress implementation would go here
        logger.info(f"Would create/update Ingress {ingress_name} for host {host}")
    
    def ensure_hpa(self, name, namespace, spec):
        """Ensure HorizontalPodAutoscaler exists if enabled"""
        hpa_config = spec.get('autoscaling', {})
        if not hpa_config.get('enabled', False):
            return
        
        hpa_name = f"{name}-webapp-hpa"
        
        # HPA implementation would go here
        logger.info(f"Would create/update HPA {hpa_name}")
    
    def update_status(self, name, namespace, phase, message=""):
        """Update the status of the WebApp custom resource"""
        try:
            # Get current resource
            webapp = self.custom_api.get_namespaced_custom_object(
                group=self.group,
                version=self.version,
                namespace=namespace,
                plural=self.plural,
                name=name
            )
            
            # Update status
            webapp['status'] = {
                'phase': phase,
                'message': message,
                'lastUpdated': time.strftime('%Y-%m-%dT%H:%M:%SZ')
            }
            
            # Patch the resource
            self.custom_api.patch_namespaced_custom_object(
                group=self.group,
                version=self.version,
                namespace=namespace,
                plural=self.plural,
                name=name,
                body=webapp
            )
            
        except Exception as e:
            logger.error(f"Failed to update status: {e}")
    
    def build_resources(self, resources_spec):
        """Build Kubernetes resource requirements"""
        if not resources_spec:
            return None
        
        requests = resources_spec.get('requests', {})
        limits = resources_spec.get('limits', {})
        
        return client.V1ResourceRequirements(
            requests=requests if requests else None,
            limits=limits if limits else None
        )
    
    def watch_webapps(self):
        """Watch for WebApp custom resource changes"""
        logger.info("Starting WebApp operator...")
        
        w = watch.Watch()
        for event in w.stream(
            self.custom_api.list_cluster_custom_object,
            group=self.group,
            version=self.version,
            plural=self.plural
        ):
            event_type = event['type']
            webapp = event['object']
            
            name = webapp['metadata']['name']
            namespace = webapp['metadata']['namespace']
            spec = webapp.get('spec', {})
            
            logger.info(f"Received {event_type} event for WebApp {namespace}/{name}")
            
            if event_type in ['ADDED', 'MODIFIED']:
                self.reconcile(name, namespace, spec)
            elif event_type == 'DELETED':
                logger.info(f"WebApp {namespace}/{name} deleted")

def main():
    operator = WebAppOperator()
    operator.watch_webapps()

if __name__ == "__main__":
    main()

OPERATOR_CONTROLLER_EOF
    
    echo "3. WebApp Custom Resource examples:"
    cat << WEBAPP_CR_EXAMPLES_EOF > webapp-cr-examples.yaml
# Simple Web Application
apiVersion: apps.hashfoundry.io/v1
kind: WebApp
metadata:
  name: simple-webapp
  namespace: development
  labels:
    app: simple-webapp
    environment: development
spec:
  image: "nginx:alpine"
  replicas: 2
  port: 80
  environment: "development"
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "200m"
      memory: "256Mi"

---
# Production Web Application with Ingress and Autoscaling
apiVersion: apps.hashfoundry.io/v1
kind: WebApp
metadata:
  name: production-webapp
  namespace: production
  labels:
    app: production-webapp
    environment: production
spec:
  image: "hashfoundry/webapp:v1.2.3"
  replicas: 3
  port: 8080
  environment: "production"
  ingress:
    enabled: true
    host: "app.hashfoundry.io"
    tls: true
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilization: 70

---
# Staging Web Application
apiVersion: apps.hashfoundry.io/v1
kind: WebApp
metadata:
  name: staging-webapp
  namespace: staging
  labels:
    app: staging-webapp
    environment: staging
spec:
  image: "hashfoundry/webapp:latest"
  replicas: 2
  port: 8080
  environment: "staging"
  ingress:
    enabled: true
    host: "staging.hashfoundry.io"
    tls: false
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"

WEBAPP_CR_EXAMPLES_EOF
    
    echo "✅ Simple operator example created:"
    echo "  - webapp-operator-crd.yaml"
    echo "  - operator-controller-pseudocode.py"
    echo "  - webapp-cr-examples.yaml"
    echo
}

# Функция для демонстрации популярных операторов
showcase_popular_operators() {
    echo "=== Showcasing Popular Operators ==="
    
    echo "1. Popular operators overview:"
    cat << POPULAR_OPERATORS_EOF > popular-operators-overview.md
# Popular Kubernetes Operators

## Database Operators

### 1. PostgreSQL Operator (Zalando)
- **Purpose**: Manage PostgreSQL clusters
- **Features**: High availability, backup/restore, monitoring
- **Maturity**: Level 4 (Deep Insights)
- **Use Case**: Production PostgreSQL deployments

### 2. MySQL Operator (Oracle)
- **Purpose**: Manage MySQL InnoDB Cluster
- **Features**: Automated clustering, backup, monitoring
- **Maturity**: Level 3 (Full Lifecycle)
- **Use Case**: MySQL high availability setups

### 3. Redis Operator
- **Purpose**: Manage Redis clusters
- **Features**: Sentinel, clustering, backup
- **Maturity**: Level 3 (Full Lifecycle)
- **Use Case**: Redis caching and data store

## Application Operators

### 4. Prometheus Operator
- **Purpose**: Manage Prometheus monitoring stack
- **Features**: Service discovery, alerting, grafana integration
- **Maturity**: Level 4 (Deep Insights)
- **Use Case**: Kubernetes monitoring and alerting

### 5. Jaeger Operator
- **Purpose**: Manage Jaeger tracing
- **Features**: Distributed tracing, sampling strategies
- **Maturity**: Level 3 (Full Lifecycle)
- **Use Case**: Microservices tracing

### 6. Istio Operator
- **Purpose**: Manage Istio service mesh
- **Features**: Traffic management, security, observability
- **Maturity**: Level 4 (Deep Insights)
- **Use Case**: Service mesh implementation

## Platform Operators

### 7. ArgoCD Operator
- **Purpose**: Manage ArgoCD GitOps
- **Features**: Application deployment, sync policies
- **Maturity**: Level 3 (Full Lifecycle)
- **Use Case**: GitOps continuous deployment

### 8. Tekton Operator
- **Purpose**: Manage Tekton CI/CD pipelines
- **Features**: Pipeline management, task execution
- **Maturity**: Level 3 (Full Lifecycle)
- **Use Case**: Cloud-native CI/CD

## Infrastructure Operators

### 9. Cert-Manager
- **Purpose**: Manage TLS certificates
- **Features**: Automatic certificate provisioning and renewal
- **Maturity**: Level 4 (Deep Insights)
- **Use Case**: TLS certificate automation

### 10. External DNS Operator
- **Purpose**: Manage external DNS records
- **Features**: Automatic DNS record creation
- **Maturity**: Level 3 (Full Lifecycle)
- **Use Case**: DNS automation for services

## Operator Frameworks

### 1. Operator SDK
- **Language**: Go, Ansible, Helm
- **Features**: Code generation, testing, lifecycle management
- **Maintainer**: Red Hat

### 2. Kubebuilder
- **Language**: Go
- **Features**: Scaffolding, controller-runtime
- **Maintainer**: Kubernetes SIG API Machinery

### 3. KUDO (Kubernetes Universal Declarative Operator)
- **Language**: YAML
- **Features**: Declarative operators
- **Maintainer**: D2iQ

### 4. Kopf (Kubernetes Operator Pythonic Framework)
- **Language**: Python
- **Features**: Python-based operators
- **Maintainer**: Community

POPULAR_OPERATORS_EOF
    
    echo "2. Operator installation examples:"
    cat << OPERATOR_INSTALL_EXAMPLES_EOF > operator-installation-examples.sh
#!/bin/bash

echo "=== Operator Installation Examples ==="

# Function to install Prometheus Operator
install_prometheus_operator() {
    echo "Installing Prometheus Operator..."
    
    # Add Prometheus community Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install kube-prometheus-stack (includes Prometheus Operator)
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
    
    echo "✅ Prometheus Operator installed"
}

# Function to install ArgoCD Operator
install_argocd_operator() {
    echo "Installing ArgoCD Operator..."
    
    # Install ArgoCD Operator
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    echo "✅ ArgoCD Operator installed"
}

# Function to install Cert-Manager
install_cert_manager() {
    echo "Installing Cert-Manager..."
    
    # Add Jetstack Helm repository
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # Install cert-manager
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true
    
    echo "✅ Cert-Manager installed"
}

# Function to install PostgreSQL Operator
install_postgresql_operator() {
    echo "Installing PostgreSQL Operator (Zalando)..."
    
    # Clone the postgres-operator repository
    git clone https://github.com/zalando/postgres-operator.git
    cd postgres-operator
    
    # Apply the operator manifests
    kubectl apply -k manifests
    
    cd ..
    rm -rf postgres-operator
    
    echo "✅ PostgreSQL Operator installed"
}

# Main function
main() {
    case "\$1" in
        "prometheus")
            install_prometheus_operator
            ;;
        "argocd")
            install_argocd_operator
            ;;
        "cert-manager")
            install_cert_manager
            ;;
        "postgresql")
            install_postgresql_operator
            ;;
        "all")
            install_prometheus_operator
            install_argocd_operator
            install_cert_manager
            install_postgresql_operator
            ;;
        *)
            echo "Usage: \$0 [prometheus|argocd|cert-manager|postgresql|all]"
            echo ""
            echo "
