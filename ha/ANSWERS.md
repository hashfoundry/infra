# Kubernetes Educational Q&A

## 8. What are Labels and Selectors in Kubernetes?

### Definition

**Labels** are key-value pairs attached to Kubernetes objects (like pods, services, deployments) that are used to organize and identify resources. They are metadata that help categorize and group objects.

**Selectors** are queries that use labels to identify and select a set of objects. They allow Kubernetes controllers and services to find and manage the right resources.

### Key Concepts

1. **Labels are arbitrary key-value pairs** - You can create any labels that make sense for your organization
2. **Labels are used for identification, not for semantic meaning** - Kubernetes doesn't interpret the meaning of labels
3. **Selectors use labels to find matching resources** - This is how services find pods, deployments manage pods, etc.
4. **Labels enable loose coupling** - Resources can be selected dynamically based on their labels

### Examples from HashFoundry HA Cluster

#### Example 1: NFS Exporter Deployment and Service

**Deployment with Labels:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-exporter
  labels:
    helm.sh/chart: nfs-exporter-1.0.0
    app.kubernetes.io/name: nfs-exporter
    app.kubernetes.io/instance: monitoring
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/component: nfs-exporter
    app.kubernetes.io/part-of: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: nfs-exporter
      app.kubernetes.io/instance: monitoring
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nfs-exporter
        app.kubernetes.io/instance: monitoring
```

**Service using Selector:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nfs-exporter
  labels:
    helm.sh/chart: nfs-exporter-1.0.0
    app.kubernetes.io/name: nfs-exporter
    app.kubernetes.io/instance: monitoring
    app.kubernetes.io/managed-by: Helm
spec:
  selector:
    app.kubernetes.io/name: nfs-exporter
    app.kubernetes.io/instance: monitoring
```

**How it works:** The Service uses its `selector` to find pods that have matching labels (`app.kubernetes.io/name: nfs-exporter` AND `app.kubernetes.io/instance: monitoring`).

#### Example 2: Blockchain Validator Pods

**Alice Validator StatefulSet:**
```yaml
# From blockchain-test/helm-chart-example/templates/alice-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: substrate-blockchain-alice
  labels:
    app.kubernetes.io/name: substrate-blockchain
    app.kubernetes.io/instance: blockchain
    app.kubernetes.io/component: validator
    app.kubernetes.io/role: alice
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: substrate-blockchain
      app.kubernetes.io/instance: blockchain
      app.kubernetes.io/component: validator
      app.kubernetes.io/role: alice
  template:
    metadata:
      labels:
        app.kubernetes.io/name: substrate-blockchain
        app.kubernetes.io/instance: blockchain
        app.kubernetes.io/component: validator
        app.kubernetes.io/role: alice
```

**Alice Service:**
```yaml
# From blockchain-test/helm-chart-example/templates/alice-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: substrate-blockchain-alice
  labels:
    app.kubernetes.io/name: substrate-blockchain
    app.kubernetes.io/instance: blockchain
    app.kubernetes.io/component: validator
    app.kubernetes.io/role: alice
spec:
  selector:
    app.kubernetes.io/name: substrate-blockchain
    app.kubernetes.io/instance: blockchain
    app.kubernetes.io/component: validator
    app.kubernetes.io/role: alice
```

#### Example 3: Pod Disruption Budget with Selectors

**NGINX Ingress PDB:**
```yaml
# From ha/k8s/addons/nginx-ingress/templates/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nginx-ingress-controller-pdb
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/component: controller
      app.kubernetes.io/instance: nginx-ingress
```

### Common Label Patterns in Our Cluster

1. **Standard Kubernetes Labels:**
   - `app.kubernetes.io/name` - The name of the application
   - `app.kubernetes.io/instance` - A unique name identifying the instance
   - `app.kubernetes.io/component` - The component within the architecture
   - `app.kubernetes.io/part-of` - The name of a higher level application
   - `app.kubernetes.io/managed-by` - The tool being used to manage the operation

2. **Role-based Labels:**
   - `app.kubernetes.io/role: alice` - Identifies the Alice validator
   - `app.kubernetes.io/role: bob` - Identifies the Bob validator
   - `app.kubernetes.io/component: validator` - Identifies validator components

3. **Helm Labels:**
   - `helm.sh/chart` - The chart name and version
   - `app.kubernetes.io/managed-by: Helm` - Indicates Helm management

### Selector Types

1. **Equality-based selectors:**
   ```yaml
   selector:
     app.kubernetes.io/name: nfs-exporter
     app.kubernetes.io/instance: monitoring
   ```

2. **Set-based selectors (matchLabels):**
   ```yaml
   selector:
     matchLabels:
       app.kubernetes.io/name: substrate-blockchain
       app.kubernetes.io/component: validator
   ```

### Benefits in Our HA Cluster

1. **Service Discovery:** Services automatically find their target pods using selectors
2. **Resource Management:** Deployments manage pods based on label matching
3. **Monitoring:** Prometheus can scrape metrics from pods with specific labels
4. **High Availability:** PodDisruptionBudgets protect critical components using selectors
5. **Organization:** Clear separation between different components (validators, monitoring, ingress)

### Best Practices Demonstrated

1. **Consistent labeling scheme** across all resources
2. **Hierarchical organization** (app → component → role)
3. **Standard Kubernetes labels** for interoperability
4. **Unique identification** using instance names
5. **Functional grouping** using component and part-of labels

Labels and selectors are fundamental to Kubernetes' declarative model, enabling loose coupling and dynamic resource management throughout our HA cluster infrastructure.

### Practical kubectl Commands for Working with Labels and Selectors

#### Getting Deployment Description
```bash
# Get detailed description of a specific deployment
kubectl describe deployment nfs-exporter -n monitoring

# Get deployment with labels shown
kubectl get deployment nfs-exporter -n monitoring --show-labels

# Get all deployments with specific labels
kubectl get deployments -l app.kubernetes.io/component=nfs-exporter

# Get deployments across all namespaces with labels
kubectl get deployments --all-namespaces -l app.kubernetes.io/part-of=monitoring
```

#### Using Selectors to Query Resources
```bash
# Find all pods with specific labels
kubectl get pods -l app.kubernetes.io/name=nfs-exporter

# Find all resources managed by a specific instance
kubectl get all -l app.kubernetes.io/instance=monitoring

# Find validator pods specifically
kubectl get pods -l app.kubernetes.io/component=validator

# Find Alice validator resources
kubectl get all -l app.kubernetes.io/role=alice

# Complex selector with multiple labels
kubectl get pods -l app.kubernetes.io/name=substrate-blockchain,app.kubernetes.io/role=alice
```

#### Viewing Labels
```bash
# Show all labels for deployments
kubectl get deployments --show-labels

# Show specific label columns
kubectl get pods -L app.kubernetes.io/role,app.kubernetes.io/component

# Get resources with custom output showing labels
kubectl get pods -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels
```

These commands demonstrate how labels and selectors are used in practice to manage and query resources in our HA cluster.
