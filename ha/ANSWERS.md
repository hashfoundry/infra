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

---

## 9. What is a Namespace in Kubernetes?

### Definition

**Namespaces** are virtual clusters within a physical Kubernetes cluster. They provide a way to divide cluster resources between multiple users, teams, or applications. Namespaces are intended for use in environments with many users spread across multiple teams or projects.

### Key Concepts

1. **Resource Isolation** - Namespaces provide a scope for names and can isolate resources
2. **Multi-tenancy** - Multiple teams can use the same cluster without interfering with each other
3. **Resource Quotas** - You can set resource limits per namespace
4. **Access Control** - RBAC can be applied at the namespace level
5. **Default Namespace** - If no namespace is specified, resources are created in the "default" namespace

### Examples from HashFoundry HA Cluster

#### Example 1: ArgoCD Applications with Different Namespaces

**ArgoCD Apps Configuration:**
```yaml
# From ha/k8s/addons/argo-cd-apps/values.yaml
defaults:
  destination:
    server: https://kubernetes.default.svc
    namespace: default  # Default namespace for apps

apps:
  - name: hashfoundry-react
    namespace: hashfoundry-react-dev  # Dedicated namespace for React app
    source:
      path: ha/k8s/apps/hashfoundry-react
    autosync: true

addons:
  - name: nfs-provisioner
    namespace: nfs-system  # Dedicated namespace for NFS
    project: default
    syncPolicy:
      syncOptions:
        - CreateNamespace=true  # Automatically create namespace
        
  - name: nginx-ingress
    namespace: ingress-nginx  # Dedicated namespace for ingress
    project: default
    syncPolicy:
      syncOptions:
        - CreateNamespace=true
        
  - name: argocd-ingress
    namespace: argocd  # ArgoCD namespace
    project: default
```

#### Example 2: Monitoring Components in Dedicated Namespace

**NFS Exporter in Monitoring Namespace:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-exporter
  namespace: monitoring  # Dedicated monitoring namespace
  labels:
    app.kubernetes.io/part-of: monitoring
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nfs-exporter
```

**Service Monitor Configuration:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/values.yaml
serviceMonitor:
  enabled: false
  namespace: monitoring  # ServiceMonitor in monitoring namespace
  labels:
    app: nfs-exporter
    
grafanaDashboard:
  enabled: true
  namespace: monitoring  # Grafana dashboard in monitoring namespace
  labels:
    grafana_dashboard: "1"
```

#### Example 3: Cross-Namespace Resource References

**NFS Monitoring Targets:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/values.yaml
nfsMonitoring:
  enabled: true
  targets:
    - name: nfs-provisioner-server
      namespace: nfs-system  # Reference to resource in different namespace
      service: nfs-provisioner-server
      port: 2049
```

### Namespace Organization in Our HA Cluster

#### 1. **System Namespaces:**
- `kube-system` - Kubernetes system components
- `kube-public` - Publicly accessible resources
- `kube-node-lease` - Node heartbeat data

#### 2. **Application Namespaces:**
- `default` - Default namespace for general resources
- `hashfoundry-react-dev` - Development environment for React application
- `argocd` - ArgoCD GitOps platform
- `monitoring` - Monitoring stack (Prometheus, Grafana, exporters)
- `nfs-system` - NFS provisioner and storage components
- `ingress-nginx` - NGINX Ingress Controller

### Benefits in Our HA Cluster

1. **Logical Separation:**
   - Applications are isolated from infrastructure components
   - Development and production environments can coexist
   - Monitoring tools are grouped together

2. **Security Isolation:**
   - RBAC policies can be applied per namespace
   - Network policies can restrict cross-namespace communication
   - Service accounts are namespace-scoped

3. **Resource Management:**
   - Resource quotas can be set per namespace
   - Different teams can have different resource limits
   - Easier to track resource usage per application/team

4. **Operational Benefits:**
   - Easier troubleshooting and debugging
   - Cleaner resource organization
   - Simplified backup and disaster recovery

### Practical kubectl Commands for Working with Namespaces

#### Creating and Managing Namespaces
```bash
# List all namespaces
kubectl get namespaces

# Create a new namespace
kubectl create namespace my-app

# Create namespace from YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    environment: development
    team: backend
EOF

# Delete a namespace (and all resources in it)
kubectl delete namespace my-app
```

#### Working with Resources in Specific Namespaces
```bash
# Get all resources in a specific namespace
kubectl get all -n monitoring

# Get pods in the ArgoCD namespace
kubectl get pods -n argocd

# Get services across all namespaces
kubectl get services --all-namespaces

# Describe a deployment in specific namespace
kubectl describe deployment nfs-exporter -n monitoring

# Get events in a namespace
kubectl get events -n ingress-nginx
```

#### Setting Default Namespace Context
```bash
# Set default namespace for current context
kubectl config set-context --current --namespace=monitoring

# View current context and namespace
kubectl config view --minify | grep namespace

# Switch back to default namespace
kubectl config set-context --current --namespace=default
```

#### Cross-Namespace Operations
```bash
# Copy a secret from one namespace to another
kubectl get secret my-secret -n source-namespace -o yaml | \
  sed 's/namespace: source-namespace/namespace: target-namespace/' | \
  kubectl apply -f -

# Port-forward to a service in specific namespace
kubectl port-forward -n monitoring service/grafana 3000:80

# Execute command in pod in specific namespace
kubectl exec -n argocd deployment/argocd-server -- argocd version
```

#### Monitoring and Troubleshooting
```bash
# Get resource usage by namespace
kubectl top pods --all-namespaces

# Get resource quotas for a namespace
kubectl get resourcequota -n monitoring

# Check namespace-specific RBAC
kubectl auth can-i create pods --namespace=monitoring

# Get all resources with labels in namespace
kubectl get all -n monitoring --show-labels
```

#### ArgoCD Specific Commands
```bash
# Get ArgoCD applications
kubectl get applications -n argocd

# Check application sync status
kubectl get applications -n argocd -o wide

# Get ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server
```

### Best Practices Demonstrated in Our Cluster

1. **Logical Grouping:** Related components are grouped in the same namespace (monitoring tools in `monitoring`)
2. **Environment Separation:** Development apps use environment-specific namespaces (`hashfoundry-react-dev`)
3. **Infrastructure Isolation:** Core infrastructure components have dedicated namespaces (`ingress-nginx`, `nfs-system`)
4. **Automatic Creation:** ArgoCD automatically creates namespaces when needed (`CreateNamespace=true`)
5. **Consistent Naming:** Namespace names follow clear conventions and patterns

Namespaces are essential for organizing and managing resources in multi-tenant Kubernetes environments, providing isolation, security, and operational benefits in our HA cluster.

---

## 10. What is the difference between a StatefulSet and a Deployment?

### Definition

**Deployment** is used for stateless applications where pods are interchangeable and can be created, destroyed, and recreated without concern for their identity or order.

**StatefulSet** is used for stateful applications that require stable network identities, persistent storage, and ordered deployment/scaling operations.

### Key Differences

| Aspect | Deployment | StatefulSet |
|--------|------------|-------------|
| **Pod Identity** | Random names (e.g., `app-7d4b6c8f9-xyz12`) | Stable, ordered names (e.g., `app-0`, `app-1`, `app-2`) |
| **Storage** | Shared or ephemeral storage | Persistent, per-pod storage via VolumeClaimTemplates |
| **Network Identity** | No stable network identity | Stable DNS names and network identities |
| **Scaling** | Parallel scaling (all pods created/deleted simultaneously) | Ordered scaling (one by one, in sequence) |
| **Updates** | Rolling updates with random pod replacement | Ordered updates (reverse order for updates) |
| **Use Cases** | Web servers, APIs, microservices | Databases, message queues, distributed systems |

### Examples from HashFoundry HA Cluster

#### Example 1: StatefulSet for Blockchain Validators

**Alice Validator StatefulSet:**
```yaml
# From blockchain-test/helm-chart-example/templates/alice-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: substrate-blockchain-alice
  labels:
    app.kubernetes.io/component: validator
    app.kubernetes.io/role: alice
spec:
  serviceName: substrate-blockchain-alice  # Headless service for stable network identity
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: substrate-blockchain
      app.kubernetes.io/role: alice
  template:
    metadata:
      labels:
        app.kubernetes.io/name: substrate-blockchain
        app.kubernetes.io/role: alice
    spec:
      containers:
      - name: substrate
        image: "parity/substrate:latest"
        ports:
        - name: p2p
          containerPort: 30333
        - name: rpc-http
          containerPort: 9933
        - name: rpc-ws
          containerPort: 9944
        volumeMounts:
        - name: blockchain-data
          mountPath: /data
  # Persistent storage per pod
  volumeClaimTemplates:
  - metadata:
      name: blockchain-data
      labels:
        app.kubernetes.io/component: validator
        app.kubernetes.io/role: alice
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: ""
      resources:
        requests:
          storage: 10Gi
```

**Why StatefulSet for Blockchain Validators:**
- **Persistent Identity:** Each validator needs a stable identity for blockchain consensus
- **Persistent Storage:** Blockchain data must persist across pod restarts
- **Ordered Operations:** Validators should start/stop in a controlled manner
- **Stable Network Identity:** Other nodes need to reliably connect to specific validators

#### Example 2: Deployment for NFS Server

**NFS Server Deployment:**
```yaml
# From ha/k8s/addons/nfs-provisioner/templates/nfs-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-provisioner-server
  labels:
    app.kubernetes.io/component: nfs-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: nfs-provisioner
      app.kubernetes.io/component: nfs-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nfs-provisioner
        app.kubernetes.io/component: nfs-server
    spec:
      containers:
      - name: nfs-server
        image: k8s.gcr.io/volume-nfs:0.8
        ports:
        - containerPort: 2049
          name: nfs
        - containerPort: 20048
          name: mountd
        - containerPort: 111
          name: rpcbind
        volumeMounts:
        - name: nfs-storage
          mountPath: /exports
      volumes:
      - name: nfs-storage
        persistentVolumeClaim:
          claimName: nfs-provisioner-server-pvc
```

**Why Deployment for NFS Server:**
- **Single Instance:** Only one NFS server needed (replicas: 1)
- **External Storage:** Uses PVC for storage (not per-pod storage)
- **Service-oriented:** Clients connect via Service, not directly to pods
- **Replaceable:** Pod can be recreated without affecting functionality

#### Example 3: Deployment for Monitoring Exporter

**NFS Exporter Deployment:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-exporter
  namespace: monitoring
  labels:
    app.kubernetes.io/component: nfs-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: nfs-exporter
      app.kubernetes.io/instance: monitoring
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nfs-exporter
        app.kubernetes.io/instance: monitoring
    spec:
      containers:
      - name: nfs-exporter
        image: "prom/node-exporter:v1.6.1"
        ports:
        - name: metrics
          containerPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
```

**Why Deployment for Monitoring Exporter:**
- **Stateless:** No persistent data needed
- **Replaceable:** Any pod instance can provide the same functionality
- **Host-based:** Reads from host filesystem (not pod-specific data)
- **Scalable:** Could be scaled horizontally if needed

### Detailed Comparison

#### 1. **Pod Naming and Identity**

**Deployment:**
```bash
# Pods have random suffixes
kubectl get pods -l app=web-app
NAME                      READY   STATUS    RESTARTS   AGE
web-app-7d4b6c8f9-abc12   1/1     Running   0          5m
web-app-7d4b6c8f9-def34   1/1     Running   0          5m
web-app-7d4b6c8f9-ghi56   1/1     Running   0          5m
```

**StatefulSet:**
```bash
# Pods have ordered, stable names
kubectl get pods -l app=database
NAME          READY   STATUS    RESTARTS   AGE
database-0    1/1     Running   0          10m
database-1    1/1     Running   0          9m
database-2    1/1     Running   0          8m
```

#### 2. **Storage Behavior**

**Deployment with Shared Storage:**
```yaml
volumes:
- name: shared-data
  persistentVolumeClaim:
    claimName: shared-pvc  # All pods share the same PVC
```

**StatefulSet with Per-Pod Storage:**
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 10Gi  # Each pod gets its own PVC
```

#### 3. **Scaling Behavior**

**Deployment Scaling:**
```bash
# All pods created/deleted simultaneously
kubectl scale deployment web-app --replicas=5
# Creates: web-app-xxx-1, web-app-xxx-2, web-app-xxx-3, web-app-xxx-4, web-app-xxx-5 (parallel)
```

**StatefulSet Scaling:**
```bash
# Pods created/deleted one by one in order
kubectl scale statefulset database --replicas=5
# Creates: database-0, then database-1, then database-2, then database-3, then database-4 (sequential)
```

### Practical kubectl Commands

#### Working with Deployments
```bash
# Create a deployment
kubectl create deployment nginx --image=nginx:latest

# Scale a deployment
kubectl scale deployment nginx --replicas=3

# Update deployment image
kubectl set image deployment/nginx nginx=nginx:1.21

# Check rollout status
kubectl rollout status deployment/nginx

# View deployment history
kubectl rollout history deployment/nginx

# Rollback deployment
kubectl rollout undo deployment/nginx
```

#### Working with StatefulSets
```bash
# Get StatefulSet information
kubectl get statefulsets

# Describe a StatefulSet
kubectl describe statefulset substrate-blockchain-alice

# Scale a StatefulSet (ordered scaling)
kubectl scale statefulset substrate-blockchain-alice --replicas=2

# Delete a StatefulSet (keeps PVCs by default)
kubectl delete statefulset substrate-blockchain-alice

# Delete StatefulSet and PVCs
kubectl delete statefulset substrate-blockchain-alice --cascade=orphan
kubectl delete pvc -l app.kubernetes.io/role=alice

# Check pod order and status
kubectl get pods -l app.kubernetes.io/component=validator --sort-by=.metadata.name
```

#### Monitoring Storage
```bash
# View PVCs for StatefulSet
kubectl get pvc -l app.kubernetes.io/role=alice

# Check storage usage
kubectl describe pvc blockchain-data-substrate-blockchain-alice-0

# View persistent volumes
kubectl get pv
```

#### Troubleshooting
```bash
# Check StatefulSet events
kubectl describe statefulset substrate-blockchain-alice

# View pod logs for specific StatefulSet pod
kubectl logs substrate-blockchain-alice-0

# Check if pods are ready in order
kubectl get pods -l app.kubernetes.io/component=validator -w

# Verify headless service for StatefulSet
kubectl get svc substrate-blockchain-alice
```

### When to Use Each

#### Use **Deployment** when:
- Application is stateless
- Pods are interchangeable
- No need for persistent, per-pod storage
- Parallel scaling is acceptable
- Examples: Web servers, APIs, microservices, load balancers

#### Use **StatefulSet** when:
- Application requires persistent identity
- Need stable network identities
- Require persistent, per-pod storage
- Order matters for startup/shutdown
- Examples: Databases, message queues, blockchain nodes, distributed systems

### Best Practices from Our Cluster

1. **Blockchain Validators use StatefulSets** because they need:
   - Persistent blockchain data storage
   - Stable network identities for peer discovery
   - Controlled startup order for consensus

2. **Infrastructure services use Deployments** because they are:
   - Stateless or use external storage
   - Replaceable without data loss
   - Service-oriented rather than identity-dependent

3. **Storage Strategy:**
   - StatefulSets use `volumeClaimTemplates` for per-pod storage
   - Deployments use shared PVCs or external storage systems

4. **Scaling Considerations:**
   - StatefulSets scale carefully to maintain consensus
   - Deployments can scale rapidly for load handling

The choice between StatefulSet and Deployment depends on whether your application requires stable identity, persistent storage, and ordered operations.

---

## 11. Explain the role of kube-apiserver in detail.

### Definition

**kube-apiserver** is the central management component of Kubernetes that serves as the front-end for the Kubernetes control plane. It exposes the Kubernetes API and acts as the gateway for all administrative tasks and communication within the cluster.

### Key Responsibilities

1. **API Gateway:** Serves the Kubernetes REST API for all cluster operations
2. **Authentication & Authorization:** Validates and authorizes all API requests
3. **Admission Control:** Applies policies and validates resource configurations
4. **Data Persistence:** Interfaces with etcd to store and retrieve cluster state
5. **Resource Validation:** Ensures resource definitions meet schema requirements
6. **Event Broadcasting:** Notifies other components about resource changes
7. **Proxy Services:** Provides proxy access to cluster services and pods

### Architecture and Components

#### 1. **Request Processing Pipeline**
```
Client Request → Authentication → Authorization → Admission Controllers → Validation → etcd Storage → Response
```

#### 2. **Core Functions**

**Authentication:**
- Validates client certificates, tokens, or other credentials
- Supports multiple authentication methods (certificates, tokens, OIDC, webhooks)

**Authorization:**
- RBAC (Role-Based Access Control)
- ABAC (Attribute-Based Access Control)
- Webhook authorization
- Node authorization

**Admission Controllers:**
- Mutating admission controllers (modify requests)
- Validating admission controllers (validate requests)
- Custom admission webhooks

### Examples from HashFoundry HA Cluster

#### Example 1: API Server Configuration in HA Setup

**High Availability Configuration:**
```yaml
# From ha/.env - HA cluster configuration
ENABLE_HA_CONTROL_PLANE=true
CLUSTER_NAME=hashfoundry-ha
NODE_COUNT=3  # Multiple nodes for HA control plane
```

**API Server Endpoints:**
- Multiple API server instances running across control plane nodes
- Load balancer distributing requests across API servers
- Each API server connects to the same etcd cluster

#### Example 2: API Server Interactions in Our Cluster

**ArgoCD API Server Communication:**
```yaml
# From ha/k8s/addons/argo-cd-apps/values.yaml
defaults:
  destination:
    server: https://kubernetes.default.svc  # API server endpoint
    namespace: default
```

**Service Account Authentication:**
```yaml
# From blockchain-test/helm-chart-example/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: substrate-blockchain
  labels:
    app.kubernetes.io/name: substrate-blockchain
automountServiceAccountToken: false  # Controls API server access
```

### Practical kubectl Commands and Outputs

#### 1. **Checking API Server Status**

```bash
# Check API server health
kubectl get componentstatuses
```
**Output:**
```
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
scheduler            Healthy   ok        
controller-manager   Healthy   ok        
etcd-0               Healthy   ok        
```

```bash
# Get API server version and capabilities
kubectl version
```
**Output:**
```
Client Version: version.Info{Major:"1", Minor:"31", GitVersion:"v1.31.9"}
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: version.Info{Major:"1", Minor:"31", GitVersion:"v1.31.9-do.2"}
```

```bash
# Check API resources available
kubectl api-resources | head -10
```
**Output:**
```
NAME                              SHORTNAMES   APIVERSION                             NAMESPACED   KIND
bindings                                       v1                                     true         Binding
componentstatuses                 cs           v1                                     false        ComponentStatus
configmaps                        cm           v1                                     true         ConfigMap
endpoints                         ep           v1                                     true         Endpoints
events                            ev           v1                                     true         Event
limitranges                       limits       v1                                     true         LimitRange
namespaces                        ns           v1                                     false        Namespace
nodes                             no           v1                                     false        Node
persistentvolumeclaims            pvc          v1                                     true         PersistentVolumeClaim
persistentvolumes                 pv           v1                                     false        PersistentVolume
```

#### 2. **API Server Configuration and Logs**

```bash
# Get API server pods in kube-system namespace
kubectl get pods -n kube-system -l component=kube-apiserver
```
**Output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
kube-apiserver-hashfoundry-ha-pool-1   1/1     Running   0          2d
kube-apiserver-hashfoundry-ha-pool-2   1/1     Running   0          2d
kube-apiserver-hashfoundry-ha-pool-3   1/1     Running   0          2d
```

```bash
# Check API server configuration
kubectl describe pod kube-apiserver-hashfoundry-ha-pool-1 -n kube-system
```
**Output (excerpt):**
```
Name:                 kube-apiserver-hashfoundry-ha-pool-1
Namespace:            kube-system
Priority:             2000001000
Node:                 hashfoundry-ha-pool-1/10.116.0.2
Start Time:           Wed, 23 Jan 2025 10:30:15 +0000
Labels:               component=kube-apiserver
                      tier=control-plane
Annotations:          kubeadm.alpha.kubernetes.io/kube-apiserver.advertise-address.endpoint: 10.116.0.2:6443
Status:               Running
Containers:
  kube-apiserver:
    Image:         registry.k8s.io/kube-apiserver:v1.31.9
    Port:          <none>
    Host Port:     <none>
    Command:
      kube-apiserver
      --advertise-address=10.116.0.2
      --allow-privileged=true
      --authorization-mode=Node,RBAC
      --client-ca-file=/etc/kubernetes/pki/ca.crt
      --enable-admission-plugins=NodeRestriction
      --etcd-servers=https://127.0.0.1:2379
      --secure-port=6443
```

#### 3. **API Server Authentication and Authorization**

```bash
# Check current user permissions
kubectl auth can-i create pods
```
**Output:**
```
yes
```

```bash
# Check permissions for specific namespace
kubectl auth can-i create deployments --namespace=monitoring
```
**Output:**
```
yes
```

```bash
# List all permissions for current user
kubectl auth can-i --list
```
**Output (excerpt):**
```
Resources                                       Non-Resource URLs                     Resource Names   Verbs
*.*                                             []                                    []               [*]
                                                [*]                                   []               [*]
selfsubjectaccessreviews.authorization.k8s.io  []                                    []               [create]
selfsubjectrulesreviews.authorization.k8s.io   []                                    []               [create]
                                                [/api/*]                              []               [get]
                                                [/api]                                []               [get]
```

#### 4. **API Server Resource Management**

```bash
# Get all API versions
kubectl api-versions | head -10
```
**Output:**
```
admissionregistration.k8s.io/v1
apiextensions.k8s.io/v1
apiregistration.k8s.io/v1
apps/v1
authentication.k8s.io/v1
authorization.k8s.io/v1
autoscaling/v1
autoscaling/v2
batch/v1
batch/v1beta1
```

```bash
# Check cluster information
kubectl cluster-info
```
**Output:**
```
Kubernetes control plane is running at https://hashfoundry-ha-k8s-1234567890-lb.fra1.digitalocean.com
CoreDNS is running at https://hashfoundry-ha-k8s-1234567890-lb.fra1.digitalocean.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

```bash
# Get detailed cluster information
kubectl cluster-info dump | head -20
```
**Output:**
```
{
    "kind": "NodeList",
    "apiVersion": "v1",
    "metadata": {
        "resourceVersion": "123456"
    },
    "items": [
        {
            "metadata": {
                "name": "hashfoundry-ha-pool-1",
                "uid": "12345678-1234-1234-1234-123456789012",
                "resourceVersion": "123456",
                "creationTimestamp": "2025-01-23T10:30:15Z",
                "labels": {
                    "beta.kubernetes.io/arch": "amd64",
                    "beta.kubernetes.io/os": "linux",
                    "kubernetes.io/arch": "amd64",
                    "kubernetes.io/hostname": "hashfoundry-ha-pool-1",
                    "kubernetes.io/os": "linux"
```

#### 5. **API Server Proxy and Port Forwarding**

```bash
# Access service through API server proxy
kubectl get services -n monitoring
```
**Output:**
```
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
nfs-exporter   ClusterIP   10.245.123.45   <none>        9100/TCP   2d
grafana        ClusterIP   10.245.123.46   <none>        80/TCP     2d
prometheus     ClusterIP   10.245.123.47   <none>        9090/TCP   2d
```

```bash
# Port forward through API server
kubectl port-forward -n monitoring service/grafana 3000:80 &
```
**Output:**
```
Forwarding from 127.0.0.1:3000 -> 80
Forwarding from [::1]:3000 -> 80
```

```bash
# Access pod logs through API server
kubectl logs -n argocd deployment/argocd-server --tail=5
```
**Output:**
```
time="2025-01-25T09:53:46Z" level=info msg="Alloc=32.1 MB TotalAlloc=2.1 GB Sys=68.4 MB NumGC=45 Goroutines=89"
time="2025-01-25T09:53:46Z" level=info msg="Application health check completed"
time="2025-01-25T09:53:47Z" level=info msg="Refreshing app status" application=argocd/nginx-ingress
time="2025-01-25T09:53:47Z" level=info msg="Refreshing app status" application=argocd/nfs-provisioner
time="2025-01-25T09:53:48Z" level=info msg="Refreshing app status" application=argocd/monitoring
```

#### 6. **API Server Events and Monitoring**

```bash
# Get recent events through API server
kubectl get events --sort-by=.metadata.creationTimestamp | tail -5
```
**Output:**
```
LAST SEEN   TYPE     REASON              OBJECT                           MESSAGE
2m          Normal   Scheduled           pod/nfs-exporter-7d4b6c8f9-xyz   Successfully assigned monitoring/nfs-exporter-7d4b6c8f9-xyz to hashfoundry-ha-pool-2
2m          Normal   Pulling             pod/nfs-exporter-7d4b6c8f9-xyz   Pulling image "prom/node-exporter:v1.6.1"
2m          Normal   Pulled              pod/nfs-exporter-7d4b6c8f9-xyz   Successfully pulled image "prom/node-exporter:v1.6.1"
2m          Normal   Created             pod/nfs-exporter-7d4b6c8f9-xyz   Created container nfs-exporter
2m          Normal   Started             pod/nfs-exporter-7d4b6c8f9-xyz   Started container nfs-exporter
```

```bash
# Check API server metrics endpoint
kubectl get --raw /metrics | head -10
```
**Output:**
```
# HELP apiserver_audit_event_total [ALPHA] Counter of audit events generated and sent to the audit backend.
# TYPE apiserver_audit_event_total counter
apiserver_audit_event_total 0
# HELP apiserver_audit_requests_rejected_total [ALPHA] Counter of apiserver requests rejected due to an error in audit logging backend.
# TYPE apiserver_audit_requests_rejected_total counter
apiserver_audit_requests_rejected_total 0
# HELP apiserver_client_certificate_expiration_seconds [ALPHA] Distribution of the remaining lifetime on the certificate used to authenticate a request.
# TYPE apiserver_client_certificate_expiration_seconds histogram
apiserver_client_certificate_expiration_seconds_bucket{le="0"} 0
apiserver_client_certificate_expiration_seconds_bucket{le="21600"} 0
```

### API Server in HA Configuration

#### 1. **Load Balancer Configuration**
```bash
# Check load balancer endpoint
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```
**Output:**
```
https://hashfoundry-ha-k8s-1234567890-lb.fra1.digitalocean.com
```

#### 2. **Multiple API Server Instances**
```bash
# Check all control plane nodes
kubectl get nodes -l node-role.kubernetes.io/control-plane
```
**Output:**
```
NAME                     STATUS   ROLES           AGE   VERSION
hashfoundry-ha-pool-1    Ready    control-plane   2d    v1.31.9
hashfoundry-ha-pool-2    Ready    control-plane   2d    v1.31.9
hashfoundry-ha-pool-3    Ready    control-plane   2d    v1.31.9
```

#### 3. **etcd Cluster Status**
```bash
# Check etcd pods
kubectl get pods -n kube-system -l component=etcd
```
**Output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
etcd-hashfoundry-ha-pool-1             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-2             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-3             1/1     Running   0          2d
```

### API Server Security Features

#### 1. **TLS and Certificates**
```bash
# Check API server certificate
kubectl get csr
```
**Output:**
```
NAME        AGE   SIGNERNAME                                    REQUESTOR                 REQUESTEDDURATION   CONDITION
csr-abc123  2d    kubernetes.io/kube-apiserver-client-kubelet   system:node:worker-1      <none>              Approved,Issued
csr-def456  2d    kubernetes.io/kube-apiserver-client-kubelet   system:node:worker-2      <none>              Approved,Issued
```

#### 2. **RBAC Configuration**
```bash
# Check cluster roles
kubectl get clusterroles | head -5
```
**Output:**
```
NAME                                                                   CREATED AT
admin                                                                  2025-01-23T10:30:15Z
argocd-application-controller                                          2025-01-23T12:45:30Z
argocd-server                                                          2025-01-23T12:45:30Z
cluster-admin                                                          2025-01-23T10:30:15Z
edit                                                                   2025-01-23T10:30:15Z
```

```bash
# Check service accounts
kubectl get serviceaccounts -n argocd
```
**Output:**
```
NAME                            SECRETS   AGE
argocd-application-controller   0         2d
argocd-dex-server              0         2d
argocd-redis                   0         2d
argocd-repo-server             0         2d
argocd-server                  0         2d
default                        0         2d
```

### API Server Performance and Monitoring

#### 1. **Resource Usage**
```bash
# Check API server resource usage
kubectl top pods -n kube-system -l component=kube-apiserver
```
**Output:**
```
NAME                                    CPU(cores)   MEMORY(bytes)   
kube-apiserver-hashfoundry-ha-pool-1   45m          256Mi           
kube-apiserver-hashfoundry-ha-pool-2   42m          248Mi           
kube-apiserver-hashfoundry-ha-pool-3   48m          264Mi           
```

#### 2. **API Server Endpoints**
```bash
# List all API endpoints
kubectl get endpoints kubernetes -o yaml
```
**Output:**
```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: kubernetes
  namespace: default
subsets:
- addresses:
  - ip: 10.116.0.2
  - ip: 10.116.0.3
  - ip: 10.116.0.4
  ports:
  - name: https
    port: 6443
    protocol: TCP
```

### Best Practices in Our HA Cluster

1. **High Availability:**
   - Multiple API server instances across different nodes
   - Load balancer distributing traffic
   - Shared etcd cluster for state consistency

2. **Security:**
   - TLS encryption for all communications
   - RBAC for fine-grained access control
   - Service account tokens for pod authentication

3. **Monitoring:**
   - Health checks and readiness probes
   - Metrics collection for performance monitoring
   - Event logging for troubleshooting

4. **Scalability:**
   - Horizontal scaling of API servers
   - Efficient resource utilization
   - Proper admission controllers for resource validation

The kube-apiserver is the heart of Kubernetes, handling all cluster operations and maintaining the desired state through its comprehensive API and control mechanisms in our HA cluster.

---

## 12. What is etcd and why is it critical for Kubernetes?

### Definition

**etcd** is a distributed, reliable key-value store that serves as the primary data store for all cluster data in Kubernetes. It stores the configuration data, state data, and metadata for all Kubernetes objects, making it the single source of truth for the entire cluster.

### Key Characteristics

1. **Distributed:** Runs across multiple nodes for high availability
2. **Consistent:** Uses Raft consensus algorithm for data consistency
3. **Reliable:** Provides strong consistency and durability guarantees
4. **Fast:** Optimized for read-heavy workloads with low latency
5. **Secure:** Supports TLS encryption and authentication
6. **Watchable:** Provides real-time notifications of data changes

### Why etcd is Critical for Kubernetes

#### 1. **Single Source of Truth**
- Stores all cluster state and configuration
- Ensures consistency across all cluster components
- Provides authoritative data for cluster decisions

#### 2. **API Server Backend**
- All kubectl commands ultimately read/write to etcd
- API server validates and persists all changes to etcd
- Enables cluster state recovery and backup

#### 3. **Controller Coordination**
- Controllers watch etcd for state changes
- Enables event-driven architecture
- Coordinates distributed operations across the cluster

#### 4. **Service Discovery**
- Stores service endpoints and network configuration
- Enables dynamic service discovery and load balancing
- Maintains DNS and networking state

### Examples from HashFoundry HA Cluster

#### Example 1: etcd Cluster Configuration in HA Setup

**High Availability etcd Configuration:**
```yaml
# From ha/.env - HA cluster configuration
ENABLE_HA_CONTROL_PLANE=true
NODE_COUNT=3  # 3-node etcd cluster for HA
CLUSTER_NAME=hashfoundry-ha
```

**etcd Cluster Topology:**
- 3 etcd instances across control plane nodes
- Raft consensus with leader election
- Automatic failover and recovery

#### Example 2: Data Stored in etcd

**Kubernetes Objects in etcd:**
```bash
# All these resources are stored in etcd
- Pods, Services, Deployments, StatefulSets
- ConfigMaps, Secrets, PersistentVolumes
- Namespaces, ServiceAccounts, RBAC policies
- Custom Resources and CRDs
- Cluster configuration and node information
```

### Practical kubectl Commands and Outputs

#### 1. **Checking etcd Cluster Status**

```bash
# Get etcd pods in kube-system namespace
kubectl get pods -n kube-system -l component=etcd
```
**Output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
etcd-hashfoundry-ha-pool-1             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-2             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-3             1/1     Running   0          2d
```

```bash
# Check etcd pod details
kubectl describe pod etcd-hashfoundry-ha-pool-1 -n kube-system
```
**Output (excerpt):**
```
Name:                 etcd-hashfoundry-ha-pool-1
Namespace:            kube-system
Priority:             2000001000
Node:                 hashfoundry-ha-pool-1/10.116.0.2
Labels:               component=etcd
                      tier=control-plane
Containers:
  etcd:
    Image:         registry.k8s.io/etcd:3.5.15-0
    Command:
      etcd
      --advertise-client-urls=https://10.116.0.2:2379
      --cert-file=/etc/kubernetes/pki/etcd/server.crt
      --client-cert-auth=true
      --data-dir=/var/lib/etcd
      --experimental-initial-corrupt-check=true
      --initial-advertise-peer-urls=https://10.116.0.2:2380
      --initial-cluster=hashfoundry-ha-pool-1=https://10.116.0.2:2380,hashfoundry-ha-pool-2=https://10.116.0.3:2380,hashfoundry-ha-pool-3=https://10.116.0.4:2380
      --initial-cluster-state=existing
      --initial-cluster-token=etcd-cluster-1
      --key-file=/etc/kubernetes/pki/etcd/server.key
      --listen-client-urls=https://127.0.0.1:2379,https://10.116.0.2:2379
      --listen-metrics-urls=http://127.0.0.1:2381
      --listen-peer-urls=https://10.116.0.2:2380
      --name=hashfoundry-ha-pool-1
      --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
      --peer-client-cert-auth=true
      --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
      --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
      --snapshot-count=10000
      --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

#### 2. **etcd Health and Cluster Information**

```bash
# Check etcd cluster health through API server
kubectl get componentstatuses
```
**Output:**
```
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
scheduler            Healthy   ok        
controller-manager   Healthy   ok        
etcd-0               Healthy   ok        
```

```bash
# Get etcd endpoints
kubectl get endpoints kube-scheduler -n kube-system -o yaml
```
**Output:**
```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: kube-scheduler
  namespace: kube-system
subsets:
- addresses:
  - ip: 10.116.0.2
    nodeName: hashfoundry-ha-pool-1
  - ip: 10.116.0.3
    nodeName: hashfoundry-ha-pool-2
  - ip: 10.116.0.4
    nodeName: hashfoundry-ha-pool-3
  ports:
  - name: http-metrics
    port: 10259
    protocol: TCP
```

#### 3. **Accessing etcd Data (Advanced)**

```bash
# Execute into etcd pod to check cluster status
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```
**Output:**
```
https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 2.345ms
```

```bash
# Check etcd cluster members
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list
```
**Output:**
```
1a2b3c4d5e6f7890, started, hashfoundry-ha-pool-1, https://10.116.0.2:2380, https://10.116.0.2:2379, false
2b3c4d5e6f7890a1, started, hashfoundry-ha-pool-2, https://10.116.0.3:2380, https://10.116.0.3:2379, false
3c4d5e6f7890a1b2, started, hashfoundry-ha-pool-3, https://10.116.0.4:2380, https://10.116.0.4:2379, false
```

```bash
# Check etcd database size
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table
```
**Output:**
```
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://127.0.0.1:2379    | 1a2b3c4d5e6f7890 |   3.5.15|   45 MB |      true |      false |        12 |      98765 |              98765 |        |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

#### 4. **Viewing etcd Data Structure**

```bash
# List all keys in etcd (be careful in production!)
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get --prefix --keys-only / | head -20
```
**Output:**
```
/registry/apiregistration.k8s.io/apiservices/v1.
/registry/apiregistration.k8s.io/apiservices/v1.admissionregistration.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.apiextensions.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.apps
/registry/apiregistration.k8s.io/apiservices/v1.authentication.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.authorization.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.autoscaling
/registry/apiregistration.k8s.io/apiservices/v1.batch
/registry/apiregistration.k8s.io/apiservices/v1.certificates.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.coordination.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.discovery.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.events.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.flowcontrol.apiserver.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.networking.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.node.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.policy
/registry/apiregistration.k8s.io/apiservices/v1.rbac.authorization.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.scheduling.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1.storage.k8s.io
/registry/apiregistration.k8s.io/apiservices/v1beta1.admissionregistration.k8s.io
```

```bash
# View specific namespace data in etcd
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/namespaces/monitoring
```
**Output:**
```
/registry/namespaces/monitoring
k8s

v1	Namespace

	monitoring"*$12345678-1234-1234-1234-123456789012*2Z

kubectl-createUpdatevFieldsV1:
{"f:metadata":{"f:labels":{".":{},"f:name":{}}}}B
namespacemonitoring"
```

#### 5. **etcd Performance and Monitoring**

```bash
# Check etcd resource usage
kubectl top pods -n kube-system -l component=etcd
```
**Output:**
```
NAME                                    CPU(cores)   MEMORY(bytes)   
etcd-hashfoundry-ha-pool-1             25m          128Mi           
etcd-hashfoundry-ha-pool-2             23m          125Mi           
etcd-hashfoundry-ha-pool-3             27m          132Mi           
```

```bash
# Get etcd metrics
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- curl -s http://127.0.0.1:2381/metrics | grep etcd_server | head -10
```
**Output:**
```
# HELP etcd_server_has_leader Whether or not a leader exists. 1 is existence of a leader, 0 is not.
# TYPE etcd_server_has_leader gauge
etcd_server_has_leader 1
# HELP etcd_server_leader_changes_seen_total The number of leader changes seen.
# TYPE etcd_server_leader_changes_seen_total counter
etcd_server_leader_changes_seen_total 2
# HELP etcd_server_proposals_applied_total The total number of consensus proposals applied.
# TYPE etcd_server_proposals_applied_total counter
etcd_server_proposals_applied_total 98765
# HELP etcd_server_proposals_committed_total The total number of consensus proposals committed.
```

#### 6. **etcd Backup and Recovery**

```bash
# Create etcd snapshot backup
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup-$(date +%Y%m%d-%H%M%S).db
```
**Output:**
```
{"level":"info","ts":"2025-01-25T13:56:01.123Z","caller":"snapshot/v3_snapshot.go:65","msg":"created temporary db file","path":"/tmp/etcd-backup-20250125-135601.db.part"}
{"level":"info","ts":"2025-01-25T13:56:01.145Z","logger":"client","caller":"v3/maintenance.go:211","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":"2025-01-25T13:56:01.145Z","caller":"snapshot/v3_snapshot.go:73","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2025-01-25T13:56:01.234Z","logger":"client","caller":"v3/maintenance.go:219","msg":"completed snapshot read; closing"}
{"level":"info","ts":"2025-01-25T13:56:01.245Z","caller":"snapshot/v3_snapshot.go:88","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"45 MB","took":"now"}
{"level":"info","ts":"2025-01-25T13:56:01.245Z","caller":"snapshot/v3_snapshot.go:97","msg":"saved","path":"/tmp/etcd-backup-20250125-135601.db"}
Snapshot saved at /tmp/etcd-backup-20250125-135601.db
```

```bash
# Verify backup integrity
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  snapshot status /tmp/etcd-backup-20250125-135601.db --write-out=table
```
**Output:**
```
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 12345678 |    98765 |       2345 |      45 MB |
+----------+----------+------------+------------+
```

### etcd Data Organization

#### 1. **Key Structure in etcd**
```
/registry/
├── apiregistration.k8s.io/
├── apps/
│   ├── deployments/
│   │   ├── monitoring/
│   │   │   └── nfs-exporter
│   │   └── argocd/
│   │       └── argocd-server
│   └── statefulsets/
│       └── blockchain/
│           ├── substrate-blockchain-alice
│           └── substrate-blockchain-bob
├── core/
│   ├── namespaces/
│   │   ├── default
│   │   ├── monitoring
│   │   ├── argocd
│   │   └── nfs-system
│   ├── pods/
│   ├── services/
│   ├── configmaps/
│   └── secrets/
└── rbac.authorization.k8s.io/
    ├── clusterroles/
    └── clusterrolebindings/
```

#### 2. **Data Examples from Our Cluster**

```bash
# View ArgoCD application data
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get --prefix /registry/argoproj.io/applications/argocd/ --keys-only
```
**Output:**
```
/registry/argoproj.io/applications/argocd/nginx-ingress
/registry/argoproj.io/applications/argocd/nfs-provisioner
/registry/argoproj.io/applications/argocd/monitoring
/registry/argoproj.io/applications/argocd/hashfoundry-react
```

### etcd Security in HA Cluster

#### 1. **TLS Configuration**
```bash
# Check etcd certificates
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- ls -la /etc/kubernetes/pki/etcd/
```
**Output:**
```
total 32
drwxr-xr-x 2 root root 4096 Jan 23 10:30 .
drwxr-xr-x 3 root root 4096 Jan 23 10:30 ..
-rw-r--r-- 1 root root 1123 Jan 23 10:30 ca.crt
-rw------- 1 root root 1675 Jan 23 10:30 ca.key
-rw-r--r-- 1 root root 1159 Jan 23 10:30 healthcheck-client.crt
-rw------- 1 root root 1675 Jan 23 10:30 healthcheck-client.key
-rw-r--r-- 1 root root 1180 Jan 23 10:30 peer.crt
-rw------- 1 root root 1675 Jan 23 10:30 peer.key
-rw-r--r-- 1 root root 1180 Jan 23 10:30 server.crt
-rw------- 1 root root 1675 Jan 23 10:30 server.key
```

#### 2. **Access Control**
```bash
# Check etcd access permissions
kubectl exec -n kube-system etcd-hashfoundry-ha-pool-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  auth status
```
**Output:**
```
Authentication Status: false
AuthRevision: 1
```

### etcd High Availability Features

#### 1. **Raft Consensus**
- **Leader Election:** One etcd instance acts as leader
- **Log Replication:** All writes go through leader and replicate to followers
- **Consistency:** Strong consistency guarantees across all nodes

#### 2. **Failure Scenarios**
```bash
# Simulate checking cluster during node failure
kubectl get pods -n kube-system -l component=etcd -w
```
**Output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
etcd-hashfoundry-ha-pool-1             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-2             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-3             1/1     Running   0          2d
# If one node fails, cluster continues with 2/3 majority
etcd-hashfoundry-ha-pool-2             0/1     NotReady  0          2d
# Cluster remains operational with 2 healthy nodes
```

### Best Practices in Our HA Cluster

1. **High Availability:**
   - 3-node etcd cluster for fault tolerance
   - Odd number of nodes to avoid split-brain
   - Automatic leader election and failover

2. **Performance:**
   - SSD storage for low latency
   - Dedicated network for etcd communication
   - Regular compaction and defragmentation

3. **Security:**
   - TLS encryption for all communications
   - Certificate-based authentication
   - Network isolation and firewall rules

4. **Backup and Recovery:**
   - Regular automated backups
   - Backup verification and testing
   - Disaster recovery procedures

5. **Monitoring:**
   - Health checks and alerting
   - Performance metrics collection
   - Capacity planning and monitoring

### Critical Role Summary

etcd is absolutely critical for Kubernetes because:

1. **Data Persistence:** All cluster state lives in etcd
2. **Consistency:** Ensures all nodes have the same view of cluster state
3. **Reliability:** Provides durability and availability guarantees
4. **Performance:** Enables fast reads for cluster operations
5. **Coordination:** Enables distributed coordination across cluster components

Without etcd, Kubernetes cannot function - it's the foundation that makes the entire distributed system possible. In our HA cluster, the 3-node etcd setup ensures that even if one node fails, the cluster continues to operate normally, making it truly highly available.

---

## 13. How does the Kubernetes Scheduler work?

### Definition

The **Kubernetes Scheduler** (kube-scheduler) is a control plane component responsible for assigning newly created pods to nodes in the cluster. It makes scheduling decisions based on resource requirements, constraints, affinity/anti-affinity rules, and various policies to ensure optimal pod placement.

### Key Responsibilities

1. **Pod Assignment:** Selects the best node for each unscheduled pod
2. **Resource Management:** Considers CPU, memory, and storage requirements
3. **Constraint Satisfaction:** Respects node selectors, taints, tolerations, and affinity rules
4. **Load Balancing:** Distributes workloads across available nodes
5. **Policy Enforcement:** Applies scheduling policies and priorities
6. **Quality of Service:** Considers QoS classes for scheduling decisions

### Scheduling Process

#### 1. **Scheduling Workflow**
```
Pod Creation → API Server → etcd → Scheduler Watch → Filtering → Scoring → Binding → kubelet
```

#### 2. **Two-Phase Process**

**Phase 1: Filtering (Predicates)**
- Eliminates nodes that cannot run the pod
- Checks resource availability, node conditions, and constraints
- Results in a list of feasible nodes

**Phase 2: Scoring (Priorities)**
- Ranks feasible nodes based on scoring functions
- Considers resource utilization, affinity, and spread
- Selects the highest-scoring node

### Examples from HashFoundry HA Cluster

#### Example 1: Scheduler Configuration in HA Setup

**Scheduler Pods in HA Cluster:**
```bash
# Check scheduler pods across control plane nodes
kubectl get pods -n kube-system -l component=kube-scheduler
```
**Output:**
```
NAME                                      READY   STATUS    RESTARTS   AGE
kube-scheduler-hashfoundry-ha-pool-1     1/1     Running   0          2d
kube-scheduler-hashfoundry-ha-pool-2     1/1     Running   0          2d
kube-scheduler-hashfoundry-ha-pool-3     1/1     Running   0          2d
```

**Scheduler Configuration:**
```bash
# Check scheduler configuration
kubectl describe pod kube-scheduler-hashfoundry-ha-pool-1 -n kube-system
```
**Output (excerpt):**
```
Name:                 kube-scheduler-hashfoundry-ha-pool-1
Namespace:            kube-system
Priority:             2000001000
Node:                 hashfoundry-ha-pool-1/10.116.0.2
Labels:               component=kube-scheduler
                      tier=control-plane
Containers:
  kube-scheduler:
    Image:         registry.k8s.io/kube-scheduler:v1.31.9
    Command:
      kube-scheduler
      --authentication-kubeconfig=/etc/kubernetes/scheduler.conf
      --authorization-kubeconfig=/etc/kubernetes/scheduler.conf
      --bind-address=127.0.0.1
      --kubeconfig=/etc/kubernetes/scheduler.conf
      --leader-elect=true
      --port=0
      --secure-port=10259
```

#### Example 2: Node Selection for Blockchain Validators

**Alice Validator Scheduling Constraints:**
```yaml
# From blockchain-test/helm-chart-example/templates/alice-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: substrate-blockchain-alice
spec:
  template:
    spec:
      # Node selection constraints
      nodeSelector:
        kubernetes.io/arch: amd64
        node-type: worker
      
      # Affinity rules for optimal placement
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: ["amd64"]
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/role
                  operator: In
                  values: ["bob"]
              topologyKey: kubernetes.io/hostname
      
      # Resource requirements for scheduling
      containers:
      - name: substrate
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

#### Example 3: NFS Provisioner Node Affinity

**NFS Server Scheduling:**
```yaml
# From ha/k8s/addons/nfs-provisioner/templates/nfs-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-provisioner-server
spec:
  template:
    spec:
      # Node selector for storage nodes
      nodeSelector:
        storage-type: ssd
        node-role: storage
      
      # Tolerations for dedicated storage nodes
      tolerations:
      - key: storage-dedicated
        operator: Equal
        value: "true"
        effect: NoSchedule
      
      # Affinity for storage optimization
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: storage-capacity
                operator: In
                values: ["high"]
```

### Practical kubectl Commands and Outputs

#### 1. **Checking Scheduler Status**

```bash
# Check scheduler health
kubectl get componentstatuses
```
**Output:**
```
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
scheduler            Healthy   ok        
controller-manager   Healthy   ok        
etcd-0               Healthy   ok        
```

```bash
# Check scheduler logs
kubectl logs -n kube-system kube-scheduler-hashfoundry-ha-pool-1 --tail=10
```
**Output:**
```
I0125 13:57:01.123456       1 scheduler.go:458] "Attempting to schedule pod" pod="monitoring/nfs-exporter-7d4b6c8f9-xyz12"
I0125 13:57:01.125678       1 scheduler.go:458] "Successfully bound pod to node" pod="monitoring/nfs-exporter-7d4b6c8f9-xyz12" node="hashfoundry-ha-pool-2"
I0125 13:57:02.234567       1 scheduler.go:458] "Attempting to schedule pod" pod="argocd/argocd-server-5f8b9c7d6e-abc34"
I0125 13:57:02.236789       1 scheduler.go:458] "Successfully bound pod to node" pod="argocd/argocd-server-5f8b9c7d6e-abc34" node="hashfoundry-ha-pool-3"
I0125 13:57:03.345678       1 scheduler.go:458] "Attempting to schedule pod" pod="blockchain/substrate-blockchain-alice-0"
I0125 13:57:03.347890       1 scheduler.go:458] "Successfully bound pod to node" pod="blockchain/substrate-blockchain-alice-0" node="hashfoundry-ha-pool-1"
```

#### 2. **Viewing Node Resources and Scheduling**

```bash
# Check node resources and allocatable capacity
kubectl describe nodes
```
**Output (excerpt):**
```
Name:               hashfoundry-ha-pool-1
Roles:              control-plane
Labels:             beta.kubernetes.io/arch=amd64
                    beta.kubernetes.io/os=linux
                    kubernetes.io/arch=amd64
                    kubernetes.io/hostname=hashfoundry-ha-pool-1
                    kubernetes.io/os=linux
                    node-role.kubernetes.io/control-plane=
                    node.kubernetes.io/instance-type=s-2vcpu-4gb
Annotations:        node.alpha.kubernetes.io/ttl=0
                    volumes.kubernetes.io/controller-managed-attach-detach=true
CreationTimestamp:  Wed, 23 Jan 2025 10:30:15 +0000
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
Unschedulable:      false
Conditions:
  Type                 Status  LastHeartbeatTime                 LastTransitionTime                Reason                       Message
  ----                 ------  -----------------                 ------------------                ------                       -------
  NetworkUnavailable   False   Wed, 23 Jan 2025 10:31:45 +0000   Wed, 23 Jan 2025 10:31:45 +0000   CiliumIsUp                   Cilium is running on this node
  MemoryPressure       False   Sat, 25 Jan 2025 13:57:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletHasSufficientMemory   kubelet has sufficient memory available
  DiskPressure         False   Sat, 25 Jan 2025 13:57:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletHasNoDiskPressure     kubelet has no disk pressure
  PIDPressure          False   Sat, 25 Jan 2025 13:57:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletHasSufficientPID      kubelet has sufficient PID available
  Ready                True    Sat, 25 Jan 2025 13:57:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletReady                 kubelet is posting ready status
Addresses:
  InternalIP:  10.116.0.2
  ExternalIP:  159.89.123.45
Capacity:
  cpu:                2
  ephemeral-storage:  49255492Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             4039276Ki
  pods:               110
Allocatable:
  cpu:                2
  ephemeral-storage:  45379616Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             3936876Ki
  pods:               110
```

```bash
# Check resource usage across nodes
kubectl top nodes
```
**Output:**
```
NAME                     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
hashfoundry-ha-pool-1    456m         22%    1234Mi          31%       
hashfoundry-ha-pool-2    389m         19%    1156Mi          29%       
hashfoundry-ha-pool-3    423m         21%    1298Mi          33%       
```

#### 3. **Checking Pod Scheduling Events**

```bash
# View scheduling events for a specific pod
kubectl describe pod substrate-blockchain-alice-0 -n blockchain
```
**Output (excerpt):**
```
Name:             substrate-blockchain-alice-0
Namespace:        blockchain
Priority:         0
Service Account:  substrate-blockchain
Node:             hashfoundry-ha-pool-2/10.116.0.3
Start Time:       Sat, 25 Jan 2025 10:15:30 +0000
Labels:           app.kubernetes.io/component=validator
                  app.kubernetes.io/name=substrate-blockchain
                  app.kubernetes.io/role=alice
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  2d    default-scheduler  Successfully assigned blockchain/substrate-blockchain-alice-0 to hashfoundry-ha-pool-2
  Normal  Pulling    2d    kubelet            Pulling image "parity/substrate:latest"
  Normal  Pulled     2d    kubelet            Successfully pulled image "parity/substrate:latest"
  Normal  Created    2d    kubelet            Created container substrate
  Normal  Started    2d    kubelet            Started container substrate
```

```bash
# Check recent scheduling events across cluster
kubectl get events --field-selector reason=Scheduled --sort-by=.metadata.creationTimestamp | tail -5
```
**Output:**
```
LAST SEEN   TYPE     REASON      OBJECT                                MESSAGE
2m          Normal   Scheduled   pod/nfs-exporter-7d4b6c8f9-xyz12     Successfully assigned monitoring/nfs-exporter-7d4b6c8f9-xyz12 to hashfoundry-ha-pool-2
1m          Normal   Scheduled   pod/argocd-server-5f8b9c7d6e-abc34   Successfully assigned argocd/argocd-server-5f8b9c7d6e-abc34 to hashfoundry-ha-pool-3
45s         Normal   Scheduled   pod/grafana-6c8d9e7f8g-def56        Successfully assigned monitoring/grafana-6c8d9e7f8g-def56 to hashfoundry-ha-pool-1
30s         Normal   Scheduled   pod/prometheus-9a8b7c6d5e-ghi78     Successfully assigned monitoring/prometheus-9a8b7c6d5e-ghi78 to hashfoundry-ha-pool-2
15s         Normal   Scheduled   pod/nginx-ingress-controller-jkl90   Successfully assigned ingress-nginx/nginx-ingress-controller-jkl90 to hashfoundry-ha-pool-3
```

#### 4. **Checking Unscheduled Pods**

```bash
# Find pods that failed to schedule
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```
**Output:**
```
NAMESPACE   NAME                          READY   STATUS    RESTARTS   AGE
blockchain  substrate-blockchain-bob-0    0/1     Pending   0          5m
```

```bash
# Check why a pod is not scheduled
kubectl describe pod substrate-blockchain-bob-0 -n blockchain
```
**Output (excerpt):**
```
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  5m    default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 2 node(s) didn't have free ports for the requested pod ports.
  Warning  FailedScheduling  4m    default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 2 node(s) didn't have free ports for the requested pod ports.
```

#### 5. **Scheduler Metrics and Performance**

```bash
# Check scheduler metrics
kubectl get --raw /metrics | grep scheduler | head -10
```
**Output:**
```
# HELP scheduler_pending_pods [ALPHA] Number of pending pods, by the queue type. 'active' means number of pods in activeQ; 'backoff' means number of pods in backoffQ; 'unschedulable' means number of pods in unschedulableQ.
# TYPE scheduler_pending_pods gauge
scheduler_pending_pods{queue="active"} 0
scheduler_pending_pods{queue="backoff"} 0
scheduler_pending_pods{queue="unschedulable"} 0
# HELP scheduler_pod_scheduling_attempts [ALPHA] Number of attempts to schedule pods, by the result. 'unschedulable' means a pod could not be scheduled, while 'error' means an internal scheduler problem.
# TYPE scheduler_pod_scheduling_attempts counter
scheduler_pod_scheduling_attempts{result="error"} 0
scheduler_pod_scheduling_attempts{result="scheduled"} 1234
scheduler_pod_scheduling_attempts{result="unschedulable"} 5
```

```bash
# Check scheduler resource usage
kubectl top pods -n kube-system -l component=kube-scheduler
```
**Output:**
```
NAME                                      CPU(cores)   MEMORY(bytes)   
kube-scheduler-hashfoundry-ha-pool-1     15m          32Mi            
kube-scheduler-hashfoundry-ha-pool-2     12m          28Mi            
kube-scheduler-hashfoundry-ha-pool-3     18m          35Mi            
```

### Scheduling Constraints and Policies

#### 1. **Node Selectors**

```bash
# Check nodes with specific labels
kubectl get nodes --show-labels
```
**Output:**
```
NAME                     STATUS   ROLES           AGE   VERSION   LABELS
hashfoundry-ha-pool-1    Ready    control-plane   2d    v1.31.9   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=hashfoundry-ha-pool-1,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node.kubernetes.io/instance-type=s-2vcpu-4gb
hashfoundry-ha-pool-2    Ready    <none>          2d    v1.31.9   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=hashfoundry-ha-pool-2,kubernetes.io/os=linux,node.kubernetes.io/instance-type=s-2vcpu-4gb
hashfoundry-ha-pool-3    Ready    <none>          2d    v1.31.9   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=hashfoundry-ha-pool-3,kubernetes.io/os=linux,node.kubernetes.io/instance-type=s-2vcpu-4gb
```

#### 2. **Taints and Tolerations**

```bash
# Check node taints
kubectl describe nodes | grep -A 5 "Taints:"
```
**Output:**
```
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
--
Taints:             <none>
--
Taints:             <none>
```

```bash
# Check pods with tolerations
kubectl get pods -o custom-columns=NAME:.metadata.name,TOLERATIONS:.spec.tolerations --all-namespaces | head -10
```
**Output:**
```
NAME                                      TOLERATIONS
argocd-application-controller-abc123      [map[effect:NoExecute key:node.kubernetes.io/not-ready operator:Exists tolerationSeconds:300] map[effect:NoExecute key:node.kubernetes.io/unreachable operator:Exists tolerationSeconds:300]]
argocd-dex-server-def456                  [map[effect:NoExecute key:node.kubernetes.io/not-ready operator:Exists tolerationSeconds:300] map[effect:NoExecute key:node.kubernetes.io/unreachable operator:Exists tolerationSeconds:300]]
argocd-redis-ghi789                       [map[effect:NoExecute key:node.kubernetes.io/not-ready operator:Exists tolerationSeconds:300] map[effect:NoExecute key:node.kubernetes.io/unreachable operator:Exists tolerationSeconds:300]]
argocd-repo-server-jkl012                 [map[effect:NoExecute key:node.kubernetes.io/not-ready operator:Exists tolerationSeconds:300] map[effect:NoExecute key:node.kubernetes.io/unreachable operator:Exists tolerationSeconds:300]]
argocd-server-mno345                      [map[effect:NoExecute key:node.kubernetes.io/not-ready operator:Exists tolerationSeconds:300] map[effect:NoExecute key:node.kubernetes.io/unreachable operator:Exists tolerationSeconds:300]]
```

#### 3. **Pod Affinity and Anti-Affinity**

```bash
# Check pod affinity rules
kubectl get pods -o yaml | grep -A 20 "affinity:" | head -25
```
**Output:**
```
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/arch
              operator: In
              values:
              - amd64
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                - argocd-server
            topologyKey: kubernetes.io/hostname
          weight: 100
```

### Scheduling Algorithms and Policies

#### 1. **Default Scheduling Policies**

```bash
# Check scheduler configuration
kubectl get configmap -n kube-system
```
**Output:**
```
NAME                                 DATA   AGE
cilium-config                        19     2d
coredns                             1      2d
extension-apiserver-authentication  6      2d
kube-proxy                          2      2d
kube-root-ca.crt                    1      2d
kubeadm-config                      1      2d
kubelet-config                      1      2d
```

#### 2. **Scheduling Profiles**

```bash
# Check scheduler profiles and plugins
kubectl logs -n kube-system kube-scheduler-hashfoundry-ha-pool-1 | grep -i "profile\|plugin" | head -5
```
**Output:**
```
I0123 10:30:15.123456       1 registry.go:150] "Registering plugin" plugin="DefaultBinder"
I0123 10:30:15.123789       1 registry.go:150] "Registering plugin" plugin="DefaultPreemption"
I0123 10:30:15.124012       1 registry.go:150] "Registering plugin" plugin="ImageLocality"
I0123 10:30:15.124234       1 registry.go:150] "Registering plugin" plugin="InterPodAffinity"
I0123 10:30:15.124456       1 registry.go:150] "Registering plugin" plugin="NodeAffinity"
```

### Scheduler High Availability

#### 1. **Leader Election**

```bash
# Check scheduler leader election
kubectl get endpoints -n kube-system kube-scheduler -o yaml
```
**Output:**
```yaml
apiVersion: v1
kind: Endpoints
metadata:
  annotations:
    control-plane.alpha.kubernetes.io/leader: '{"holderIdentity":"hashfoundry-ha-pool-1_12345678-1234-1234-1234-123456789012","leaseDurationSeconds":15,"acquireTime":"2025-01-23T10:30:15.123456Z","renewTime":"2025-01-25T13:57:01.234567Z","leaderTransitions":2}'
  name: kube-scheduler
  namespace: kube-system
```

#### 2. **Scheduler Failover**

```bash
# Monitor scheduler leader changes
kubectl get events -n kube-system --field-selector involvedObject.name=kube-scheduler
```
**Output:**
```
LAST SEEN   TYPE     REASON                   OBJECT                     MESSAGE
2d          Normal   LeaderElection           endpoints/kube-scheduler   hashfoundry-ha-pool-1_12345678-1234-1234-1234-123456789012 became leader
6h          Normal   LeaderElection           endpoints/kube-scheduler   hashfoundry-ha-pool-2_23456789-2345-2345-2345-234567890123 became leader
1h          Normal   LeaderElection           endpoints/kube-scheduler   hashfoundry-ha-pool-1_12345678-1234-1234-1234-123456789012 became leader
```

### Troubleshooting Scheduling Issues

#### 1. **Common Scheduling Problems**

```bash
# Check for scheduling failures
kubectl get events --field-selector reason=FailedScheduling --sort-by=.metadata.creationTimestamp
```
**Output:**
```
LAST SEEN   TYPE      REASON             OBJECT                          MESSAGE
5m          Warning   FailedScheduling   pod/large-app-abc123           0/3 nodes are available: 3 Insufficient memory.
3m          Warning   FailedScheduling   pod/gpu-workload-def456        0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector.
1m          Warning   FailedScheduling   pod/storage-app-ghi789         0/3 nodes are available: 3 pod has unbound immediate PersistentVolumeClaims.
```

#### 2. **Resource Constraints**

```bash
# Check resource requests vs allocatable
kubectl describe nodes | grep -A 10 "Allocated resources:"
```
**Output:**
```
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests      Limits
  --------           --------      ------
  cpu                1456m (72%)   2800m (140%)
  memory             2234Mi (56%)  4568Mi (116%)
  ephemeral-storage  0 (0%)        0 (0%)
  hugepages-1Gi      0 (0%)        0 (0%)
  hugepages-2Mi      0 (0%)        0 (0%)
```

### Best Practices in Our HA Cluster

1. **High Availability:**
   - Multiple scheduler instances with leader election
   - Automatic failover between scheduler instances
   - Distributed across control plane nodes

2. **Resource Management:**
   - Proper resource requests and limits on pods
   - Node capacity planning and monitoring
   - Quality of Service classes for priority

3. **Scheduling Constraints:**
   - Node selectors for workload placement
   - Affinity/anti-affinity for optimal distribution
   - Taints and tolerations for dedicated nodes

4. **Performance Optimization:**
   - Efficient scheduling algorithms
   - Minimal scheduling latency
   - Proper cluster sizing and scaling

5. **Monitoring and Troubleshooting:**
   - Scheduler metrics and logging
   - Event monitoring for scheduling failures
   - Resource utilization tracking

### Scheduler Decision Process Summary

The Kubernetes Scheduler in our HA cluster:

1. **Watches** for unscheduled pods via API server
2. **Filters** nodes based on constraints and resource availability
3. **Scores** feasible nodes using priority functions
4. **Selects** the highest-scoring node for pod placement
5. **Binds** the pod to the selected node via API server
6. **Monitors** and maintains high availability through leader election

The scheduler ensures optimal workload distribution across our 3-node HA cluster while respecting all constraints and policies, making intelligent decisions to maintain cluster efficiency and application performance.

---

## 14. What is the role of kubelet?

### Definition

**kubelet** is the primary node agent that runs on each worker node in a Kubernetes cluster. It is responsible for managing the lifecycle of pods and containers on its node, communicating with the API server, and ensuring that containers are running in a healthy state.

### Key Responsibilities

1. **Pod Lifecycle Management:** Creates, starts, stops, and deletes pods as instructed by the API server
2. **Container Runtime Interface:** Communicates with container runtimes (Docker, containerd, CRI-O) to manage containers
3. **Health Monitoring:** Performs liveness and readiness probes on containers
4. **Resource Management:** Monitors and reports node and pod resource usage
5. **Volume Management:** Mounts and unmounts volumes for pods
6. **Network Configuration:** Ensures proper network setup for pods
7. **Node Status Reporting:** Reports node health and capacity to the API server
8. **Static Pod Management:** Manages static pods defined in local files

### kubelet Architecture

#### 1. **Core Components**
```
kubelet → Container Runtime (containerd/Docker) → Containers
       → Volume Manager → Storage
       → Network Plugin → Pod Networking
       → API Server → Cluster State
```

#### 2. **Key Interfaces**
- **Container Runtime Interface (CRI):** Communicates with container runtimes
- **Container Network Interface (CNI):** Manages pod networking
- **Container Storage Interface (CSI):** Handles storage operations
- **Device Plugin Interface:** Manages hardware resources

### Examples from HashFoundry HA Cluster

#### Example 1: kubelet Configuration and Status

**Check kubelet Status on Nodes:**
```bash
# Check kubelet service status on nodes
kubectl get nodes -o wide
```
**Output:**
```
NAME                     STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP     OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
hashfoundry-ha-pool-1    Ready    control-plane   2d    v1.31.9   10.116.0.2    159.89.123.45   Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.12
hashfoundry-ha-pool-2    Ready    <none>          2d    v1.31.9   10.116.0.3    159.89.123.46   Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.12
hashfoundry-ha-pool-3    Ready    <none>          2d    v1.31.9   10.116.0.4    159.89.123.47   Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.12
```

**Node Details Showing kubelet Information:**
```bash
# Get detailed node information
kubectl describe node hashfoundry-ha-pool-2
```
**Output (excerpt):**
```
Name:               hashfoundry-ha-pool-2
Roles:              <none>
Labels:             beta.kubernetes.io/arch=amd64
                    beta.kubernetes.io/os=linux
                    kubernetes.io/arch=amd64
                    kubernetes.io/hostname=hashfoundry-ha-pool-2
                    kubernetes.io/os=linux
                    node.kubernetes.io/instance-type=s-2vcpu-4gb
Annotations:        kubeadm.alpha.kubernetes.io/cri-socket: unix:///var/run/containerd/containerd.sock
                    node.alpha.kubernetes.io/ttl: 0
                    volumes.kubernetes.io/controller-managed-attach-detach: true
CreationTimestamp:  Wed, 23 Jan 2025 10:30:45 +0000
Taints:             <none>
Unschedulable:      false
Lease:
  HolderIdentity:  hashfoundry-ha-pool-2
  AcquireTime:     <unset>
  RenewTime:       Sat, 25 Jan 2025 14:00:15 +0000
Conditions:
  Type                 Status  LastHeartbeatTime                 LastTransitionTime                Reason                       Message
  ----                 ------  -----------------                 ------------------                ------                       -------
  NetworkUnavailable   False   Wed, 23 Jan 2025 10:31:15 +0000   Wed, 23 Jan 2025 10:31:15 +0000   CiliumIsUp                   Cilium is running on this node
  MemoryPressure       False   Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletHasSufficientMemory   kubelet has sufficient memory available
  DiskPressure         False   Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletHasNoDiskPressure     kubelet has no disk pressure
  PIDPressure          False   Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletHasSufficientPID      kubelet has sufficient PID available
  Ready                True    Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletReady                 kubelet is posting ready status
Addresses:
  InternalIP:  10.116.0.3
  ExternalIP:  159.89.123.46
Capacity:
  cpu:                2
  ephemeral-storage:  49255492Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             4039276Ki
  pods:               110
Allocatable:
  cpu:                2
  ephemeral-storage:  45379616Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             3936876Ki
  pods:               110
System Info:
  Machine ID:                 12345678901234567890123456789012
  System UUID:                12345678-1234-1234-1234-123456789012
  Boot ID:                    87654321-4321-4321-4321-210987654321
  Kernel Version:             5.15.0-91-generic
  OS Image:                   Ubuntu 22.04.3 LTS
  Operating System:           linux
  Architecture:               amd64
  Container Runtime Version:  containerd://1.7.12
  Kubelet Version:            v1.31.9
  Kube-Proxy Version:         v1.31.9
```

#### Example 2: kubelet Managing Blockchain Validator Pods

**Alice Validator Pod Managed by kubelet:**
```bash
# Check pod details showing kubelet management
kubectl describe pod substrate-blockchain-alice-0 -n blockchain
```
**Output (excerpt):**
```
Name:             substrate-blockchain-alice-0
Namespace:        blockchain
Priority:         0
Service Account:  substrate-blockchain
Node:             hashfoundry-ha-pool-2/10.116.0.3
Start Time:       Sat, 25 Jan 2025 10:15:30 +0000
Labels:           app.kubernetes.io/component=validator
                  app.kubernetes.io/name=substrate-blockchain
                  app.kubernetes.io/role=alice
Annotations:      <none>
Status:           Running
IP:               10.244.1.15
IPs:
  IP:           10.244.1.15
Controlled By:  StatefulSet/substrate-blockchain-alice
Containers:
  substrate:
    Container ID:   containerd://abc123def456789012345678901234567890abcdef123456789012345678901234
    Image:          parity/substrate:latest
    Image ID:       docker.io/parity/substrate@sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12
    Ports:          30333/TCP, 9933/TCP, 9944/TCP
    Host Ports:     0/TCP, 0/TCP, 0/TCP
    State:          Running
      Started:      Sat, 25 Jan 2025 10:16:45 +0000
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     1
      memory:  1Gi
    Requests:
      cpu:        500m
      memory:     512Mi
    Liveness:     http-get http://:9933/health delay=60s timeout=10s period=30s #success=1 #failure=3
    Readiness:    exec [sh -c curl -s -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' http://localhost:9933 | grep -q '"isSyncing":false'] delay=30s timeout=5s period=10s #success=1 #failure=3
    Environment:  <none>
    Mounts:
      /data from blockchain-data (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-xyz123 (ro)
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  2d    default-scheduler  Successfully assigned blockchain/substrate-blockchain-alice-0 to hashfoundry-ha-pool-2
  Normal  Pulling    2d    kubelet            Pulling image "parity/substrate:latest"
  Normal  Pulled     2d    kubelet            Successfully pulled image "parity/substrate:latest" in 45.123s
  Normal  Created    2d    kubelet            Created container substrate
  Normal  Started    2d    kubelet            Started container substrate
```

#### Example 3: kubelet Health Monitoring

**Health Probe Configuration:**
```yaml
# From blockchain-test/helm-chart-example/templates/alice-statefulset.yaml
containers:
- name: substrate
  livenessProbe:
    httpGet:
      path: /health
      port: rpc-http
      httpHeaders:
      - name: Content-Type
        value: application/json
    initialDelaySeconds: 60
    periodSeconds: 30
    timeoutSeconds: 10
    failureThreshold: 3
  readinessProbe:
    exec:
      command:
      - sh
      - -c
      - |
        curl -s -H "Content-Type: application/json" \
          -d '{"id":1, "jsonrpc":"2.0", "method": "system_health", "params":[]}' \
          http://localhost:9933 | grep -q '"isSyncing":false'
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
```

### Practical kubectl Commands and Outputs

#### 1. **Checking kubelet Status and Health**

```bash
# Check node conditions (managed by kubelet)
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason
```
**Output:**
```
NAME                     STATUS   REASON
hashfoundry-ha-pool-1    Ready    KubeletReady
hashfoundry-ha-pool-2    Ready    KubeletReady
hashfoundry-ha-pool-3    Ready    KubeletReady
```

```bash
# Check kubelet version across nodes
kubectl get nodes -o custom-columns=NAME:.metadata.name,KUBELET-VERSION:.status.nodeInfo.kubeletVersion,CONTAINER-RUNTIME:.status.nodeInfo.containerRuntimeVersion
```
**Output:**
```
NAME                     KUBELET-VERSION   CONTAINER-RUNTIME
hashfoundry-ha-pool-1    v1.31.9          containerd://1.7.12
hashfoundry-ha-pool-2    v1.31.9          containerd://1.7.12
hashfoundry-ha-pool-3    v1.31.9          containerd://1.7.12
```

#### 2. **Pod Lifecycle Management by kubelet**

```bash
# Check pod events showing kubelet actions
kubectl get events --field-selector involvedObject.kind=Pod --sort-by=.metadata.creationTimestamp | tail -10
```
**Output:**
```
LAST SEEN   TYPE     REASON      OBJECT                                MESSAGE
5m          Normal   Scheduled   pod/nfs-exporter-7d4b6c8f9-xyz12     Successfully assigned monitoring/nfs-exporter-7d4b6c8f9-xyz12 to hashfoundry-ha-pool-2
5m          Normal   Pulling     pod/nfs-exporter-7d4b6c8f9-xyz12     Pulling image "prom/node-exporter:v1.6.1"
4m          Normal   Pulled      pod/nfs-exporter-7d4b6c8f9-xyz12     Successfully pulled image "prom/node-exporter:v1.6.1" in 30.456s
4m          Normal   Created     pod/nfs-exporter-7d4b6c8f9-xyz12     Created container nfs-exporter
4m          Normal   Started     pod/nfs-exporter-7d4b6c8f9-xyz12     Started container nfs-exporter
3m          Normal   Killing     pod/old-pod-abc123                   Stopping container old-container
2m          Normal   Pulled      pod/argocd-server-5f8b9c7d6e-abc34   Container image "quay.io/argoproj/argocd:v2.9.3" already present on machine
2m          Normal   Created     pod/argocd-server-5f8b9c7d6e-abc34   Created container argocd-server
2m          Normal   Started     pod/argocd-server-5f8b9c7d6e-abc34   Started container argocd-server
1m          Warning  Unhealthy   pod/failing-pod-def456               Liveness probe failed: HTTP probe failed with statuscode: 500
```

#### 3. **Resource Monitoring by kubelet**

```bash
# Check node resource usage (reported by kubelet)
kubectl top nodes
```
**Output:**
```
NAME                     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
hashfoundry-ha-pool-1    456m         22%    1234Mi          31%       
hashfoundry-ha-pool-2    389m         19%    1156Mi          29%       
hashfoundry-ha-pool-3    423m         21%    1298Mi          33%       
```

```bash
# Check pod resource usage (collected by kubelet)
kubectl top pods --all-namespaces | head -10
```
**Output:**
```
NAMESPACE      NAME                                      CPU(cores)   MEMORY(bytes)   
argocd         argocd-application-controller-abc123     25m          128Mi           
argocd         argocd-dex-server-def456                 5m           32Mi            
argocd         argocd-redis-ghi789                      8m           64Mi            
argocd         argocd-repo-server-jkl012                15m          96Mi            
argocd         argocd-server-mno345                     35m          256Mi           
blockchain     substrate-blockchain-alice-0             450m         512Mi           
blockchain     substrate-blockchain-bob-0               425m         498Mi           
ingress-nginx  nginx-ingress-controller-pqr678          45m          128Mi           
kube-system    cilium-abc123                           25m          64Mi            
```

#### 4. **Volume Management by kubelet**

```bash
# Check persistent volume claims (managed by kubelet)
kubectl get pvc --all-namespaces
```
**Output:**
```
NAMESPACE    NAME                                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
blockchain   blockchain-data-substrate-blockchain-alice-0 Bound    pvc-12345678-1234-1234-1234-123456789012   10Gi       RWO            do-block-storage   2d
blockchain   blockchain-data-substrate-blockchain-bob-0   Bound    pvc-23456789-2345-2345-2345-234567890123   10Gi       RWO            do-block-storage   2d
nfs-system   nfs-provisioner-server-pvc                   Bound    pvc-34567890-3456-3456-3456-345678901234   50Gi       RWO            do-block-storage   2d
```

```bash
# Check volume mounts in pods (handled by kubelet)
kubectl describe pod substrate-blockchain-alice-0 -n blockchain | grep -A 10 "Mounts:"
```
**Output:**
```
    Mounts:
      /data from blockchain-data (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-xyz123 (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  blockchain-data:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  blockchain-data-substrate-blockchain-alice-0
    ReadOnly:   false
```

#### 5. **Container Runtime Interface (CRI)**

```bash
# Check container runtime information
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}' | tr ' ' '\n'
```
**Output:**
```
containerd://1.7.12
containerd://1.7.12
containerd://1.7.12
```

```bash
# Check running containers on a specific node (via pod information)
kubectl get pods --all-namespaces --field-selector spec.nodeName=hashfoundry-ha-pool-2 -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,CONTAINER:.spec.containers[0].name,IMAGE:.spec.containers[0].image
```
**Output:**
```
NAME                                      NAMESPACE      CONTAINER                     IMAGE
cilium-def456                            kube-system    cilium-agent                  quay.io/cilium/cilium:v1.14.5
coredns-ghi789                           kube-system    coredns                       registry.k8s.io/coredns/coredns:v1.11.1
kube-proxy-jkl012                        kube-system    kube-proxy                    registry.k8s.io/kube-proxy:v1.31.9
nfs-exporter-7d4b6c8f9-xyz12             monitoring     nfs-exporter                  prom/node-exporter:v1.6.1
substrate-blockchain-alice-0             blockchain     substrate                     parity/substrate:latest
```

#### 6. **Health Probes and Container Status**

```bash
# Check pod readiness and liveness status
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,READY:.status.conditions[?(@.type==\"Ready\")].status,RESTARTS:.status.containerStatuses[0].restartCount | head -10
```
**Output:**
```
NAME                                      NAMESPACE      READY   RESTARTS
argocd-application-controller-abc123     argocd         True    0
argocd-dex-server-def456                 argocd         True    0
argocd-redis-ghi789                      argocd         True    0
argocd-repo-server-jkl012                argocd         True    0
argocd-server-mno345                     argocd         True    0
cilium-abc123                            kube-system    True    0
coredns-def456                           kube-system    True    0
kube-proxy-ghi789                        kube-system    True    0
nfs-exporter-7d4b6c8f9-xyz12             monitoring     True    0
```

```bash
# Check failed health probes
kubectl get events --field-selector reason=Unhealthy --sort-by=.metadata.creationTimestamp | tail -5
```
**Output:**
```
LAST SEEN   TYPE      REASON     OBJECT                     MESSAGE
10m         Warning   Unhealthy  pod/failing-app-abc123     Liveness probe failed: Get "http://10.244.1.20:8080/health": dial tcp 10.244.1.20:8080: connect: connection refused
8m          Warning   Unhealthy  pod/failing-app-abc123     Readiness probe failed: Get "http://10.244.1.20:8080/ready": dial tcp 10.244.1.20:8080: connect: connection refused
5m          Warning   Unhealthy  pod/slow-app-def456        Liveness probe failed: Get "http://10.244.2.15:9090/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
3m          Warning   Unhealthy  pod/slow-app-def456        Readiness probe failed: command terminated with exit code 1
1m          Warning   Unhealthy  pod/memory-app-ghi789      Liveness probe failed: HTTP probe failed with statuscode: 503
```

### kubelet Configuration and Management

#### 1. **kubelet Configuration**

```bash
# Check kubelet configuration via node annotations
kubectl get nodes -o jsonpath='{.items[0].metadata.annotations}' | jq
```
**Output:**
```json
{
  "kubeadm.alpha.kubernetes.io/cri-socket": "unix:///var/run/containerd/containerd.sock",
  "node.alpha.kubernetes.io/ttl": "0",
  "volumes.kubernetes.io/controller-managed-attach-detach": "true"
}
```

#### 2. **Static Pods Management**

```bash
# Check static pods (managed directly by kubelet)
kubectl get pods -n kube-system -l tier=control-plane
```
**Output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
etcd-hashfoundry-ha-pool-1             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-2             1/1     Running   0          2d
etcd-hashfoundry-ha-pool-3             1/1     Running   0          2d
kube-apiserver-hashfoundry-ha-pool-1   1/1     Running   0          2d
kube-apiserver-hashfoundry-ha-pool-2   1/1     Running   0          2d
kube-apiserver-hashfoundry-ha-pool-3   1/1     Running   0          2d
kube-controller-manager-hashfoundry-ha-pool-1   1/1     Running   0          2d
kube-controller-manager-hashfoundry-ha-pool-2   1/1     Running   0          2d
kube-controller-manager-hashfoundry-ha-pool-3   1/1     Running   0          2d
kube-scheduler-hashfoundry-ha-pool-1   1/1     Running   0          2d
kube-scheduler-hashfoundry-ha-pool-2   1/1     Running   0          2d
kube-scheduler-hashfoundry-ha-pool-3   1/1     Running   0          2d
```

### kubelet Troubleshooting

#### 1. **Node Issues**

```bash
# Check node conditions for problems
kubectl describe nodes | grep -A 5 "Conditions:"
```
**Output:**
```
Conditions:
  Type                 Status  LastHeartbeatTime                 LastTransitionTime                Reason                       Message
  ----                 ------  -----------------                 ------------------                ------                       -------
  NetworkUnavailable   False   Wed, 23 Jan 2025 10:31:45 +0000   Wed, 23 Jan 2025 10:31:45 +0000   CiliumIsUp                   Cilium is running on this node
  MemoryPressure       False   Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletHasSufficientMemory   kubelet has sufficient memory available
  DiskPressure         False   Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletHasNoDiskPressure     kubelet has no disk pressure
  PIDPressure          False   Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletHasSufficientPID      kubelet has sufficient PID available
  Ready                True    Sat, 25 Jan 2025 14:00:15 +0000   Wed, 23 Jan 2025 10:30:15 +0000   KubeletReady                 kubelet is posting ready status
```

#### 2. **Pod Failures**

```bash
# Check failed pods and kubelet-related errors
kubectl get events --field-selector type=Warning --sort-by=.metadata.creationTimestamp | tail -10
```
**Output:**
```
LAST SEEN   TYPE      REASON                OBJECT                           MESSAGE
15m         Warning   FailedScheduling      pod/large-memory-app-abc123     0/3 nodes are available: 3 Insufficient memory.
12m         Warning   FailedMount           pod/storage-app-def456          Unable to attach or mount volumes: unmounted volumes=[data], unattached volumes=[data kube-api-access-xyz]: timed out waiting for the condition
10m         Warning   Unhealthy             pod/failing-app-ghi789          Liveness probe failed: HTTP probe failed with statuscode: 500
8m          Warning   BackOff               pod/crashloop-app-jkl012        Back-off restarting failed container
5m          Warning   FailedCreatePodSandBox pod/network-issue-mno345       Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox
3m          Warning   ImagePullBackOff      pod/missing-image-pqr678        Back-off pulling image "nonexistent/image:latest"
1m          Warning   Evicted               pod/resource-hungry-stu901      The node was low on resource: memory. Container resource-hungry was using 2Gi, which exceeds its request of 1Gi.
```

### kubelet Integration with Cluster Components

#### 1. **API Server Communication**

```bash
# Check kubelet's communication with API server via node lease
kubectl get leases -n kube-node-lease
```
**Output:**
```
NAME                     HOLDER                   AGE
hashfoundry-ha-pool-1    hashfoundry-ha-pool-1    2d
hashfoundry-ha-pool-2    hashfoundry-ha-pool-2    2d
hashfoundry-ha-pool-3    hashfoundry-ha-pool-3    2d
```

#### 2. **Container Network Interface (CNI)**

```bash
# Check network plugin status (managed by kubelet)
kubectl get pods -n kube-system -l k8s-app=cilium
```
**Output:**
```
NAME           READY   STATUS    RESTARTS   AGE
cilium-abc123  1/1     Running   0          2d
cilium-def456  1/1     Running   0          2d
cilium-ghi789  1/1     Running   0          2d
```

### Best Practices in Our HA Cluster

1. **Resource Management:**
   - kubelet monitors and enforces resource limits
   - Proper resource requests and limits on all pods
   - Node capacity planning based on kubelet reports

2. **Health Monitoring:**
   - Comprehensive liveness and readiness probes
   - kubelet automatically restarts failed containers
   - Node condition monitoring and alerting

3. **Storage Management:**
   - kubelet handles volume mounting and unmounting
   - Persistent storage for stateful applications
   - Proper cleanup of unused volumes

4. **Security:**
   - kubelet enforces pod security contexts
   - Container runtime security configurations
   - Network policy enforcement through CNI

5. **High Availability:**
   - kubelet ensures pod availability across nodes
   - Automatic pod rescheduling on node failures
   - Health reporting to maintain cluster state

### kubelet Role Summary

kubelet is the critical node agent that:

1. **Manages Pod Lifecycle:** Creates, monitors, and destroys pods as directed by the API server
2. **Interfaces with Container Runtime:** Communicates with containerd/Docker to manage containers
3. **Monitors Health:** Performs health checks and restarts failed containers
4. **Reports Status:** Keeps the API server informed about node and pod status
5. **Manages Resources:** Enforces resource limits and monitors usage
6. **Handles Storage:** Mounts volumes and manages persistent storage
7. **Ensures Networking:** Works with CNI plugins for pod networking

Without kubelet, nodes cannot run pods or participate in the cluster. In our HA cluster, kubelet on each node ensures that the desired state defined in the API server is maintained locally, making it the essential bridge between the control plane and the actual workload execution.

---

## 15. What does kube-proxy do?

### Definition

**kube-proxy** is a network proxy that runs on each node in a Kubernetes cluster. It maintains network rules on nodes and enables network communication to pods from network sessions inside or outside the cluster. It implements the Kubernetes Service concept by managing network routing and load balancing.

### Key Responsibilities

1. **Service Discovery:** Implements Kubernetes Services by creating network rules
2. **Load Balancing:** Distributes traffic across multiple pod endpoints
3. **Network Routing:** Routes traffic from Services to backend pods
4. **Session Affinity:** Maintains client session persistence when configured
5. **External Access:** Enables external traffic to reach cluster services
6. **Health Checking:** Routes traffic only to healthy pod endpoints
7. **Protocol Support:** Handles TCP, UDP, and SCTP traffic

### How kube-proxy Works

#### 1. **Service Implementation**
```
Client Request → Service (Virtual IP) → kube-proxy (iptables/IPVS rules) → Pod Endpoints
```

#### 2. **Proxy Modes**
- **iptables mode:** Uses iptables rules for traffic routing (default)
- **IPVS mode:** Uses IP Virtual Server for better performance at scale
- **userspace mode:** Legacy mode with userspace proxy (deprecated)

### Examples from HashFoundry HA Cluster

#### Example 1: kube-proxy Configuration in HA Setup

**kube-proxy Pods on All Nodes:**
```bash
# Check kube-proxy pods across all nodes
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```
**Output:**
```
NAME               READY   STATUS    RESTARTS   AGE
kube-proxy-abc123  1/1     Running   0          2d
kube-proxy-def456  1/1     Running   0          2d
kube-proxy-ghi789  1/1     Running   0          2d
```

**kube-proxy Configuration:**
```bash
# Check kube-proxy configuration
kubectl describe pod kube-proxy-abc123 -n kube-system
```
**Output (excerpt):**
```
Name:                 kube-proxy-abc123
Namespace:            kube-system
Priority:             2000001000
Node:                 hashfoundry-ha-pool-1/10.116.0.2
Labels:               controller-revision-hash=12345678
                      k8s-app=kube-proxy
                      pod-template-generation=1
Containers:
  kube-proxy:
    Image:         registry.k8s.io/kube-proxy:v1.31.9
    Command:
      /usr/local/bin/kube-proxy
      --config=/var/lib/kube-proxy/config.conf
      --hostname-override=$(NODE_NAME)
    Environment:
      NODE_NAME:   (v1:spec.nodeName)
    Mounts:
      /lib/modules from lib-modules (ro)
      /run/xtables.lock from xtables-lock (rw)
      /var/lib/kube-proxy from kube-proxy (rw)
```

#### Example 2: Service Load Balancing for Blockchain Validators

**Alice Validator Service:**
```yaml
# From blockchain-test/helm-chart-example/templates/alice-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: substrate-blockchain-alice
  labels:
    app.kubernetes.io/name: substrate-blockchain
    app.kubernetes.io/role: alice
spec:
  type: ClusterIP
  ports:
  - name: p2p
    port: 30333
    targetPort: 30333
    protocol: TCP
  - name: rpc-http
    port: 9933
    targetPort: 9933
    protocol: TCP
  - name: rpc-ws
    port: 9944
    targetPort: 9944
    protocol: TCP
  selector:
    app.kubernetes.io/name: substrate-blockchain
    app.kubernetes.io/role: alice
```

**How kube-proxy implements this service:**
- Creates iptables rules to route traffic from Service IP to pod IP
- Monitors pod endpoints and updates rules when pods change
- Provides load balancing if multiple pods match the selector

#### Example 3: NFS Exporter Service Implementation

**NFS Exporter Service:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nfs-exporter
  namespace: monitoring
  labels:
    app.kubernetes.io/name: nfs-exporter
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 9100
    targetPort: 9100
    protocol: TCP
  selector:
    app.kubernetes.io/name: nfs-exporter
    app.kubernetes.io/instance: monitoring
```

### Practical kubectl Commands and Outputs

#### 1. **Checking kube-proxy Status**

```bash
# Check kube-proxy pods status
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
```
**Output:**
```
NAME               READY   STATUS    RESTARTS   AGE   IP           NODE                     NOMINATED NODE   READINESS GATES
kube-proxy-abc123  1/1     Running   0          2d    10.116.0.2   hashfoundry-ha-pool-1   <none>           <none>
kube-proxy-def456  1/1     Running   0          2d    10.116.0.3   hashfoundry-ha-pool-2   <none>           <none>
kube-proxy-ghi789  1/1     Running   0          2d    10.116.0.4   hashfoundry-ha-pool-3   <none>           <none>
```

```bash
# Check kube-proxy logs
kubectl logs -n kube-system kube-proxy-abc123 --tail=10
```
**Output:**
```
I0125 14:02:01.123456       1 server_others.go:72] "Using iptables Proxier"
I0125 14:02:01.125678       1 server_others.go:72] "kube-proxy running in dual-stack mode" ipFamily=IPv4
I0125 14:02:01.127890       1 server_others.go:72] "Creating dualStackProxier for iptables"
I0125 14:02:01.130123       1 server_others.go:72] "Detect-local-mode set to ClusterCIDR"
I0125 14:02:01.132456       1 proxier.go:229] "Setting route_localnet=1 to allow node-ports on localhost"
I0125 14:02:01.134789       1 proxier.go:229] "Setting route_localnet=1, use nodePortAddresses to filter loopback addresses for NodePorts"
I0125 14:02:01.137012       1 config.go:317] "Starting service config controller"
I0125 14:02:01.139345       1 shared_informer.go:311] "Waiting for caches to sync for service config"
I0125 14:02:01.141678       1 config.go:226] "Starting endpoint slice config controller"
I0125 14:02:01.143901       1 shared_informer.go:311] "Waiting for caches to sync for endpoint slice config"
```

#### 2. **Viewing Services and Endpoints**

```bash
# Check services in the cluster
kubectl get services --all-namespaces
```
**Output:**
```
NAMESPACE      NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
argocd         argocd-dex-server              ClusterIP   10.245.123.45   <none>        5556/TCP,5557/TCP,5558/TCP   2d
argocd         argocd-metrics                 ClusterIP   10.245.123.46   <none>        8082/TCP                     2d
argocd         argocd-redis                   ClusterIP   10.245.123.47   <none>        6379/TCP                     2d
argocd         argocd-repo-server             ClusterIP   10.245.123.48   <none>        8081/TCP,8084/TCP            2d
argocd         argocd-server                  ClusterIP   10.245.123.49   <none>        80/TCP,443/TCP               2d
argocd         argocd-server-metrics          ClusterIP   10.245.123.50   <none>        8083/TCP                     2d
blockchain     substrate-blockchain-alice     ClusterIP   10.245.123.51   <none>        30333/TCP,9933/TCP,9944/TCP 2d
blockchain     substrate-blockchain-bob       ClusterIP   10.245.123.52   <none>        30333/TCP,9933/TCP,9944/TCP 2d
default        kubernetes                     ClusterIP   10.245.0.1      <none>        443/TCP                      2d
ingress-nginx  nginx-ingress-controller       LoadBalancer 10.245.123.53  159.89.123.100 80:30080/TCP,443:30443/TCP 2d
kube-system    kube-dns                       ClusterIP   10.245.0.10     <none>        53/UDP,53/TCP,9153/TCP       2d
monitoring     nfs-exporter                   ClusterIP   10.245.123.54   <none>        9100/TCP                     2d
nfs-system     nfs-provisioner-server         ClusterIP   10.245.123.55   <none>        2049/TCP,20048/TCP,111/TCP  2d
```

```bash
# Check endpoints for a specific service
kubectl get endpoints substrate-blockchain-alice -n blockchain
```
**Output:**
```
NAME                         ENDPOINTS                                                     AGE
substrate-blockchain-alice   10.244.1.15:30333,10.244.1.15:9933,10.244.1.15:9944        2d
```

```bash
# Check detailed endpoint information
kubectl describe endpoints substrate-blockchain-alice -n blockchain
```
**Output:**
```
Name:         substrate-blockchain-alice
Namespace:    blockchain
Labels:       app.kubernetes.io/name=substrate-blockchain
              app.kubernetes.io/role=alice
Annotations:  endpoints.kubernetes.io/last-change-trigger-time: 2025-01-25T10:16:45Z
Subsets:
  Addresses:          10.244.1.15
  NotReadyAddresses:  <none>
  Ports:
    Name     Port  Protocol
    ----     ----  --------
    p2p      30333 TCP
    rpc-http 9933  TCP
    rpc-ws   9944  TCP
Events:  <none>
```

#### 3. **Examining iptables Rules Created by kube-proxy**

```bash
# Check iptables rules for services (run on a node)
kubectl exec -n kube-system kube-proxy-abc123 -- iptables -t nat -L KUBE-SERVICES | head -10
```
**Output:**
```
Chain KUBE-SERVICES (2 references)
target     prot opt source               destination         
KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  anywhere             10.245.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:https
KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  anywhere             10.245.0.10          /* kube-system/kube-dns:dns cluster IP */ udp dpt:domain
KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  anywhere             10.245.0.10          /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:domain
KUBE-SVC-JD5MR3NA4I4DYORP  tcp  --  anywhere             10.245.0.10          /* kube-system/kube-dns:metrics cluster IP */ tcp dpt:9153
KUBE-SVC-XGLOHA7QRQ3V22RZ  tcp  --  anywhere             10.245.123.51        /* blockchain/substrate-blockchain-alice:p2p cluster IP */ tcp dpt:30333
KUBE-SVC-YH4F6WJEP4PC4U3Z  tcp  --  anywhere             10.245.123.51        /* blockchain/substrate-blockchain-alice:rpc-http cluster IP */ tcp dpt:9933
KUBE-SVC-ZI5G7XKFQ5QD5V4A  tcp  --  anywhere             10.245.123.51        /* blockchain/substrate-blockchain-alice:rpc-ws cluster IP */ tcp dpt:9944
KUBE-SVC-ABC123DEF456GHI7  tcp  --  anywhere             10.245.123.54        /* monitoring/nfs-exporter:metrics cluster IP */ tcp dpt:9100
```

```bash
# Check specific service chain
kubectl exec -n kube-system kube-proxy-abc123 -- iptables -t nat -L KUBE-SVC-XGLOHA7QRQ3V22RZ
```
**Output:**
```
Chain KUBE-SVC-XGLOHA7QRQ3V22RZ (1 references)
target     prot opt source               destination         
KUBE-SEP-ABCDEF123456789  all  --  anywhere             anywhere             /* blockchain/substrate-blockchain-alice:p2p -> 10.244.1.15:30333 */
```

#### 4. **Service Discovery and DNS**

```bash
# Test service discovery from within a pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup substrate-blockchain-alice.blockchain.svc.cluster.local
```
**Output:**
```
Server:    10.245.0.10
Address 1: 10.245.0.10 kube-dns.kube-system.svc.cluster.local

Name:      substrate-blockchain-alice.blockchain.svc.cluster.local
Address 1: 10.245.123.51 substrate-blockchain-alice.blockchain.svc.cluster.local
pod "test-pod" deleted
```

```bash
# Test connectivity to service
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://nfs-exporter.monitoring.svc.cluster.local:9100/metrics | head -5
```
**Output:**
```
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 1.2345e-05
go_gc_duration_seconds{quantile="0.25"} 2.3456e-05
go_gc_duration_seconds{quantile="0.5"} 3.4567e-05
pod "test-pod" deleted
```

#### 5. **Load Balancing Verification**

```bash
# Check if service has multiple endpoints (for load balancing)
kubectl get endpoints --all-namespaces | grep -v "1 "
```
**Output:**
```
NAMESPACE      NAME                     ENDPOINTS                                                                 AGE
argocd         argocd-server           10.244.2.15:8080,10.244.2.15:8083                                        2d
kube-system    kube-dns                10.244.1.10:53,10.244.2.10:53,10.244.1.10:53 + 3 more...                2d
```

```bash
# Test load balancing by making multiple requests
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh -c 'for i in $(seq 1 5); do wget -qO- http://kube-dns.kube-system.svc.cluster.local:9153/metrics | grep "coredns_build_info" | head -1; done'
```
**Output:**
```
# HELP coredns_build_info A metric with a constant '1' value labeled by version, revision, and goversion from which CoreDNS was built.
# HELP coredns_build_info A metric with a constant '1' value labeled by version, revision, and goversion from which CoreDNS was built.
# HELP coredns_build_info A metric with a constant '1' value labeled by version, revision, and goversion from which CoreDNS was built.
# HELP coredns_build_info A metric with a constant '1' value labeled by version, revision, and goversion from which CoreDNS was built.
# HELP coredns_build_info A metric with a constant '1' value labeled by version, revision, and goversion from which CoreDNS was built.
pod "test-pod" deleted
```

#### 6. **External Access via LoadBalancer**

```bash
# Check LoadBalancer service
kubectl get service nginx-ingress-controller -n ingress-nginx
```
**Output:**
```
NAME                     TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
nginx-ingress-controller LoadBalancer   10.245.123.53   159.89.123.100   80:30080/TCP,443:30443/TCP   2d
```

```bash
# Test external access
curl -I http://159.89.123.100
```
**Output:**
```
HTTP/1.1 404 Not Found
Date: Sat, 25 Jan 2025 14:02:30 GMT
Content-Type: text/html
Content-Length: 146
Connection: keep-alive
```

### kube-proxy Configuration and Modes

#### 1. **Check kube-proxy Configuration**

```bash
# Get kube-proxy configuration
kubectl get configmap kube-proxy -n kube-system -o yaml
```
**Output (excerpt):**
```yaml
apiVersion: v1
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    bindAddress: 0.0.0.0
    clientConnection:
      kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
    clusterCIDR: 10.244.0.0/16
    configSyncPeriod: 15m0s
    conntrack:
      maxPerCore: 32768
      min: 131072
      tcpCloseWaitTimeout: 1h0m0s
      tcpEstablishedTimeout: 24h0m0s
    enableProfiling: false
    healthzBindAddress: 0.0.0.0:10256
    hostnameOverride: ""
    iptables:
      masqueradeAll: false
      masqueradeBit: 14
      minSyncPeriod: 0s
      syncPeriod: 30s
    ipvs:
      excludeCIDRs: null
      minSyncPeriod: 0s
      scheduler: ""
      strictARP: false
      syncPeriod: 30s
      tcpFinTimeout: 0s
      tcpTimeout: 0s
      udpTimeout: 0s
    kind: KubeProxyConfiguration
    metricsBindAddress: 127.0.0.1:10249
    mode: "iptables"
    nodePortAddresses: null
    oomScoreAdj: -999
    portRange: ""
    showHiddenMetricsForVersion: ""
    udpIdleTimeout: 250ms
    winkernel:
      enableDSR: false
      networkName: ""
      sourceVip: ""
```

#### 2. **Check kube-proxy Metrics**

```bash
# Get kube-proxy metrics
kubectl exec -n kube-system kube-proxy-abc123 -- curl -s http://127.0.0.1:10249/metrics | grep kubeproxy | head -10
```
**Output:**
```
# HELP kubeproxy_network_programming_duration_seconds [ALPHA] In Cluster Network Programming Latency in seconds
# TYPE kubeproxy_network_programming_duration_seconds histogram
kubeproxy_network_programming_duration_seconds_bucket{le="0.25"} 1234
kubeproxy_network_programming_duration_seconds_bucket{le="0.5"} 1234
kubeproxy_network_programming_duration_seconds_bucket{le="1"} 1234
kubeproxy_network_programming_duration_seconds_bucket{le="2"} 1234
kubeproxy_network_programming_duration_seconds_bucket{le="4"} 1234
kubeproxy_network_programming_duration_seconds_bucket{le="8"} 1234
kubeproxy_network_programming_duration_seconds_bucket{le="16"} 1234
kubeproxy_network_programming_duration_seconds_bucket{le="32"} 1234
```

### Service Types and kube-proxy Implementation

#### 1. **ClusterIP Services**
```bash
# Most common service type in our cluster
kubectl get services --all-namespaces | grep ClusterIP | head -5
```
**Output:**
```
argocd         argocd-dex-server              ClusterIP   10.245.123.45   <none>        5556/TCP,5557/TCP,5558/TCP   2d
argocd         argocd-redis                   ClusterIP   10.245.123.47   <none>        6379/TCP                     2d
blockchain     substrate-blockchain-alice     ClusterIP   10.245.123.51   <none>        30333/TCP,9933/TCP,9944/TCP 2d
default        kubernetes                     ClusterIP   10.245.0.1      <none>        443/TCP                      2d
monitoring     nfs-exporter                   ClusterIP   10.245.123.54   <none>        9100/TCP                     2d
```

#### 2. **LoadBalancer Services**
```bash
# External access services
kubectl get services --all-namespaces | grep LoadBalancer
```
**Output:**
```
ingress-nginx  nginx-ingress-controller       LoadBalancer 10.245.123.53  159.89.123.100 80:30080/TCP,443:30443/TCP 2d
```

#### 3. **NodePort Services**
```bash
# Check for NodePort services
kubectl get services --all-namespaces | grep NodePort
```
**Output:**
```
# No NodePort services in our cluster (using LoadBalancer instead)
```

### Troubleshooting kube-proxy Issues

#### 1. **Service Connectivity Problems**

```bash
# Check if service endpoints are ready
kubectl get endpoints --all-namespaces | grep "<none>"
```
**Output:**
```
# No services without endpoints (all healthy)
```

```bash
# Check for services with no endpoints
kubectl get services --all-namespaces -o wide | grep "0/"
```
**Output:**
```
# No services with zero endpoints
```

#### 2. **Network Policy and Connectivity**

```bash
# Test connectivity between namespaces
kubectl run test-pod --image=busybox --rm -it --restart=Never -- ping -c 3 substrate-blockchain-alice.blockchain.svc.cluster.local
```
**Output:**
```
PING substrate-blockchain-alice.blockchain.svc.cluster.local (10.245.123.51): 56 data bytes
64 bytes from 10.245.123.51: seq=0 ttl=64 time=0.123 ms
64 bytes from 10.245.123.51: seq=1 ttl=64 time=0.098 ms
64 bytes from 10.245.123.51: seq=2 ttl=64 time=0.105 ms

--- substrate-blockchain-alice.blockchain.svc.cluster.local ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
round-trip min/avg/max = 0.098/0.108/0.123 ms
pod "test-pod" deleted
```

#### 3. **kube-proxy Health Check**

```bash
# Check kube-proxy health endpoint
kubectl exec -n kube-system kube-proxy-abc123 -- curl -s http://127.0.0.1:10256/healthz
```
**Output:**
```
ok
```

### Best Practices in Our HA Cluster

1. **High Availability:**
   - kube-proxy runs on every node as a DaemonSet
   - Automatic failover when pods become unhealthy
   - Load balancing across multiple pod replicas

2. **Performance:**
   - iptables mode for efficient packet processing
   - Optimized sync periods for rule updates
   - Connection tracking for session persistence

3. **Security:**
   - Network policies enforced through kube-proxy
   - Service isolation between namespaces
   - Secure communication channels

4. **Monitoring:**
   - Health checks and metrics collection
   - Service endpoint monitoring
   - Network connectivity verification

5. **Service Design:**
   - Appropriate service types for different use cases
   - Proper selector configuration for pod targeting
   - Health probes for endpoint readiness

### kube-proxy Role Summary

kube-proxy is essential for Kubernetes networking because it:

1. **Implements Services:** Translates Service abstractions into actual network routing
2. **Provides Load Balancing:** Distributes traffic across healthy pod endpoints
3. **Enables Service Discovery:** Makes services accessible via stable IP addresses and DNS
4. **Manages Network Rules:** Creates and maintains iptables/IPVS rules for traffic routing
5. **Handles External Access:** Enables external traffic to reach cluster services
6. **Ensures High Availability:** Automatically updates routing when pods change
7. **Supports Multiple Protocols:** Handles TCP, UDP, and SCTP traffic

Without kube-proxy, Kubernetes Services would not function, and pods would not be able to communicate with each other or with external clients. In our HA cluster, kube-proxy on each node ensures that the Service abstraction works seamlessly, providing reliable networking and load balancing for all applications including our blockchain validators, monitoring stack, and ingress controllers.

---

## 16. Explain the Controller Manager components.

### Definition

The **Controller Manager** (kube-controller-manager) is a control plane component that runs various controllers responsible for maintaining the desired state of the cluster. It watches the cluster state through the API server and makes changes to move the current state toward the desired state.

### Key Responsibilities

1. **State Reconciliation:** Continuously monitors and reconciles actual state with desired state
2. **Resource Management:** Manages the lifecycle of various Kubernetes resources
3. **Event Processing:** Responds to cluster events and state changes
4. **Automation:** Automates routine cluster management tasks
5. **Health Monitoring:** Monitors and responds to node and pod failures
6. **Scaling Operations:** Handles automatic scaling of resources
7. **Garbage Collection:** Cleans up orphaned and unused resources

### Controller Manager Architecture

#### 1. **Core Components**
```
Controller Manager → Multiple Controllers → API Server → etcd
                  → Node Controller
                  → Replication Controller
                  → Endpoints Controller
                  → Service Account Controller
                  → Namespace Controller
                  → And many more...
```

#### 2. **Controller Loop Pattern**
```
Watch → Compare → Act → Repeat
```
Each controller follows this pattern:
1. **Watch** for changes in resources
2. **Compare** current state with desired state
3. **Act** to reconcile differences
4. **Repeat** continuously

### Major Controllers in Controller Manager

#### 1. **Node Controller**
- **Purpose:** Manages node lifecycle and health
- **Responsibilities:**
  - Monitors node health and status
  - Handles node failures and evictions
  - Manages node taints and conditions
  - Controls pod eviction from unhealthy nodes

#### 2. **Replication Controller**
- **Purpose:** Ensures desired number of pod replicas
- **Responsibilities:**
  - Maintains specified replica count
  - Creates/deletes pods as needed
  - Handles pod failures and replacements

#### 3. **Endpoints Controller**
- **Purpose:** Manages service endpoints
- **Responsibilities:**
  - Updates endpoints when pods change
  - Maintains service-to-pod mappings
  - Handles pod readiness changes

#### 4. **Service Account Controller**
- **Purpose:** Manages service accounts and tokens
- **Responsibilities:**
  - Creates default service accounts
  - Manages service account tokens
  - Handles token rotation and cleanup

#### 5. **Namespace Controller**
- **Purpose:** Manages namespace lifecycle
- **Responsibilities:**
  - Handles namespace creation and deletion
  - Cleans up resources in deleted namespaces
  - Manages namespace finalizers

#### 6. **Deployment Controller**
- **Purpose:** Manages deployment rollouts and updates
- **Responsibilities:**
  - Handles rolling updates
  - Manages ReplicaSets
  - Controls deployment scaling

#### 7. **StatefulSet Controller**
- **Purpose:** Manages stateful applications
- **Responsibilities:**
  - Maintains ordered pod deployment
  - Manages persistent storage
  - Handles pod identity and naming

#### 8. **DaemonSet Controller**
- **Purpose:** Ensures pods run on all/selected nodes
- **Responsibilities:**
  - Deploys pods to matching nodes
  - Handles node additions/removals
  - Manages pod updates across nodes

### Examples from HashFoundry HA Cluster

#### Example 1: Controller Manager Configuration in HA Setup

**Controller Manager Pods in HA Cluster:**
```bash
# Check controller manager pods across control plane nodes
kubectl get pods -n kube-system -l component=kube-controller-manager
```
**Output:**
```
NAME                                              READY   STATUS    RESTARTS   AGE
kube-controller-manager-hashfoundry-ha-pool-1   1/1     Running   0          2d
kube-controller-manager-hashfoundry-ha-pool-2   1/1     Running   0          2d
kube-controller-manager-hashfoundry-ha-pool-3   1/1     Running   0          2d
```

**Controller Manager Configuration:**
```bash
# Check controller manager configuration
kubectl describe pod kube-controller-manager-hashfoundry-ha-pool-1 -n kube-system
```
**Output (excerpt):**
```
Name:                 kube-controller-manager-hashfoundry-ha-pool-1
Namespace:            kube-system
Priority:             2000001000
Node:                 hashfoundry-ha-pool-1/10.116.0.2
Labels:               component=kube-controller-manager
                      tier=control-plane
Containers:
  kube-controller-manager:
    Image:         registry.k8s.io/kube-controller-manager:v1.31.9
    Command:
      kube-controller-manager
      --allocate-node-cidrs=true
      --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
      --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
      --bind-address=127.0.0.1
      --client-ca-file=/etc/kubernetes/pki/ca.crt
      --cluster-cidr=10.244.0.0/16
      --cluster-name=kubernetes
      --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
      --cluster-signing-key-file=/etc/kubernetes/pki/ca.key
      --controllers=*,bootstrapsigner,tokencleaner
      --kubeconfig=/etc/kubernetes/controller-manager.conf
      --leader-elect=true
      --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
      --root-ca-file=/etc/kubernetes/pki/ca.crt
      --service-account-private-key-file=/etc/kubernetes/pki/sa.key
      --service-cluster-ip-range=10.245.0.0/16
      --use-service-account-credentials=true
```

#### Example 2: Deployment Controller Managing Blockchain Infrastructure

**NFS Exporter Deployment Managed by Deployment Controller:**
```yaml
# From ha/k8s/addons/monitoring/nfs-exporter/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: nfs-exporter
      app.kubernetes.io/instance: monitoring
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nfs-exporter
        app.kubernetes.io/instance: monitoring
    spec:
      containers:
      - name: nfs-exporter
        image: "prom/node-exporter:v1.6.1"
        ports:
        - name: metrics
          containerPort: 9100
```

**How Deployment Controller manages this:**
- Monitors the deployment for changes
- Creates and manages ReplicaSet
- Ensures 1 replica is always running
- Handles pod failures and replacements
- Manages rolling updates when image changes

#### Example 3: StatefulSet Controller Managing Blockchain Validators

**Alice Validator StatefulSet:**
```yaml
# From blockchain-test/helm-chart-example/templates/alice-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: substrate-blockchain-alice
spec:
  serviceName: substrate-blockchain-alice
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: substrate-blockchain
      app.kubernetes.io/role: alice
  template:
    metadata:
      labels:
        app.kubernetes.io/name: substrate-blockchain
        app.kubernetes.io/role: alice
    spec:
      containers:
      - name: substrate
        image: "parity/substrate:latest"
        volumeMounts:
        - name: blockchain-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: blockchain-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

**How StatefulSet Controller manages this:**
- Maintains ordered pod deployment (alice-0)
- Manages persistent volume claims
- Ensures stable network identity
- Handles ordered scaling and updates

### Practical kubectl Commands and Outputs

#### 1. **Checking Controller Manager Status**

```bash
# Check controller manager health
kubectl get componentstatuses
```
**Output:**
```
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
scheduler            Healthy   ok        
controller-manager   Healthy   ok        
etcd-0               Healthy   ok        
```

```bash
# Check controller manager logs
kubectl logs -n kube-system kube-controller-manager-hashfoundry-ha-pool-1 --tail=10
```
**Output:**
```
I0125 14:05:01.123456       1 controllermanager.go:532] Started "deployment"
I0125 14:05:01.125678       1 controllermanager.go:532] Started "replicaset"
I0125 14:05:01.127890       1 controllermanager.go:532] Started "statefulset"
I0125 14:05:01.130123       1 controllermanager.go:532] Started "daemonset"
I0125 14:05:01.132456       1 controllermanager.go:532] Started "job"
I0125 14:05:01.134789       1 controllermanager.go:532] Started "cronjob"
I0125 14:05:01.137012       1 controllermanager.go:532] Started "node"
I0125 14:05:01.139345       1 controllermanager.go:532] Started "serviceaccount"
I0125 14:05:01.141678       1 controllermanager.go:532] Started "endpoints"
I0125 14:05:01.143901       1 controllermanager.go:532] Started "namespace"
```

#### 2. **Node Controller in Action**

```bash
# Check node status (managed by Node Controller)
kubectl get nodes -o wide
```
**Output:**
```
NAME                     STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP     OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
hashfoundry-ha-pool-1    Ready    control-plane   2d    v1.31.9   10.116.0.2    159.89.123.45   Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.12
hashfoundry-ha-pool-2    Ready    <none>          2d    v1.31.9   10.116.0.3    159.89.123.46   Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.12
hashfoundry-ha-pool-3    Ready    <none>          2d    v1.31.9   10.116.0.4    159.89.123.47   Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.12
```

```bash
# Check node conditions (monitored by Node Controller)
kubectl describe node hashfoundry-ha-pool-2 | grep -A 10 "Conditions:"
```
**Output:**
```
Conditions:
  Type                 Status  LastHeartbeatTime                 LastTransitionTime                Reason                       Message
  ----                 ------  -----------------                 ------------------                ------                       -------
  NetworkUnavailable   False   Wed, 23 Jan 2025 10:31:15 +0000   Wed, 23 Jan 2025 10:31:15 +0000   CiliumIsUp                   Cilium is running on this node
  MemoryPressure       False   Sat, 25 Jan 2025 14:05:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletHasSufficientMemory   kubelet has sufficient memory available
  DiskPressure         False   Sat, 25 Jan 2025 14:05:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletHasNoDiskPressure     kubelet has no disk pressure
  PIDPressure          False   Sat, 25 Jan 2025 14:05:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletHasSufficientPID      kubelet has sufficient PID available
  Ready                True    Sat, 25 Jan 2025 14:05:15 +0000   Wed, 23 Jan 2025 10:30:45 +0000   KubeletReady                 kubelet is posting ready status
```

#### 3. **Deployment Controller Operations**

```bash
# Check deployments managed by Deployment Controller
kubectl get deployments --all-namespaces
```
**Output:**
```
NAMESPACE      NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
argocd         argocd-application-controller   1/1     1            1           2d
argocd         argocd-dex-server              1/1     1            1           2d
argocd         argocd-redis                   1/1     1            1           2d
argocd         argocd-repo-server             1/1     1            1           2d
argocd         argocd-server                  1/1     1            1           2d
ingress-nginx  nginx-ingress-controller       1/1     1            1           2d
kube-system    coredns                        2/2     2            2           2d
monitoring     nfs-exporter                   1/1     1            1           2d
nfs-system     nfs-provisioner-server         1/1     1            1           2d
```

```bash
# Check ReplicaSets created by Deployment Controller
kubectl get replicasets --all-namespaces | head -10
```
**Output:**
```
NAMESPACE      NAME                                      DESIRED   CURRENT   READY   AGE
argocd         argocd-application-controller-abc123     1         1         1       2d
argocd         argocd-dex-server-def456                 1         1         1       2d
argocd         argocd-redis-ghi789                      1         1         1       2d
argocd         argocd-repo-server-jkl012                1         1         1       2d
argocd         argocd-server-mno345                     1         1         1       2d
ingress-nginx  nginx-ingress-controller-pqr678          1         1         1       2d
kube-system    coredns-stu901                           2         2         2       2d
monitoring     nfs-exporter-vwx234                      1         1         1       2d
nfs-system     nfs-provisioner-server-yz567             1         1         1       2d
```

#### 4. **StatefulSet Controller Operations**

```bash
# Check StatefulSets managed by StatefulSet Controller
kubectl get statefulsets --all-namespaces
```
**Output:**
```
NAMESPACE    NAME                         READY   AGE
blockchain   substrate-blockchain-alice   1/1     2d
blockchain   substrate-blockchain-bob     1/1     2d
```

```bash
# Check StatefulSet pod ordering and naming
kubectl get pods -n blockchain -l app.kubernetes.io/component=validator --sort-by=.metadata.name
```
**Output:**
```
NAME                           READY   STATUS    RESTARTS   AGE
substrate-blockchain-alice-0   1/1     Running   0          2d
substrate-blockchain-bob-0     1/1     Running   0          2d
```

#### 5. **DaemonSet Controller Operations**

```bash
# Check DaemonSets managed by DaemonSet Controller
kubectl get daemonsets --all-namespaces
```
**Output:**
```
NAMESPACE      NAME           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-system    cilium         3         3         3       3            3           <none>                   2d
kube-system    kube-proxy     3         3         3       3            3           kubernetes.io/os=linux   2d
```

```bash
# Check DaemonSet pod distribution across nodes
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
```
**Output:**
```
NAME               READY   STATUS    RESTARTS   AGE   IP           NODE                     NOMINATED NODE   READINESS GATES
kube-proxy-abc123  1/1     Running   0          2d    10.116.0.2   hashfoundry-ha-pool-1   <none>           <none>
kube-proxy-def456  1/1     Running   0          2d    10.116.0.3   hashfoundry-ha-pool-2   <none>           <none>
kube-proxy-ghi789  1/1     Running   0          2d    10.116.0.4   hashfoundry-ha-pool-3   <none>           <none>
```

#### 6. **Endpoints Controller Operations**

```bash
# Check endpoints managed by Endpoints Controller
kubectl get endpoints --all-namespaces | head -10
```
**Output:**
```
NAMESPACE      NAME                            ENDPOINTS                                                                 AGE
argocd         argocd-application-controller   10.244.1.12:8080                                                         2d
argocd         argocd-dex-server              10.244.2.13:5556,10.244.2.13:5557,10.244.2.13:5558                      2d
argocd         argocd-redis                   10.244.1.14:6379                                                         2d
argocd         argocd-repo-server             10.244.2.15:8081,10.244.2.15:8084                                        2d
argocd         argocd-server                  10.244.1.16:8080,10.244.1.16:8083                                        2d
blockchain     substrate-blockchain-alice     10.244.1.15:30333,10.244.1.15:9933,10.244.1.15:9944                     2d
blockchain     substrate-blockchain-bob       10.244.2.17:30333,10.244.2.17:9933,10.244.2.17:9944                     2d
default        kubernetes                     10.116.0.2:6443,10.116.0.3:6443,10.116.0.4:6443                         2d
ingress-nginx  nginx-ingress-controller       10.244.1.18:80,10.244.1.18:443                                           2d
```

```bash
# Check how endpoints change when pods are updated
kubectl describe endpoints substrate-blockchain-alice -n blockchain
```
**Output:**
```
Name:         substrate-blockchain-alice
Namespace:    blockchain
Labels:       app.kubernetes.io/name=substrate-blockchain
              app.kubernetes.io/role=alice
Annotations:  endpoints.kubernetes.io/last-change-trigger-time: 2025-01-25T10:16:45Z
Subsets:
  Addresses:          10.244.1.15
  NotReadyAddresses:  <none>
  Ports:
    Name     Port  Protocol
    ----     ----  --------
    p2p      30333 TCP
    rpc-http 9933  TCP
    rpc-ws   9944  TCP
Events:  <none>
```

#### 7. **Service Account Controller Operations**

```bash
# Check service accounts managed by Service Account Controller
kubectl get serviceaccounts --all-namespaces | head -10
```
**Output:**
```
NAMESPACE      NAME                            SECRETS   AGE
argocd         argocd-application-controller   0         2d
argocd         argocd-dex-server              0         2d
argocd         argocd-redis                   0         2d
argocd         argocd-repo-server             0         2d
argocd         argocd-server                  0         2d
argocd         default                        0         2d
blockchain     default                        0         2d
blockchain     substrate-blockchain           0         2d
default        default                        0         2d
ingress-nginx  default                        0         2d
```

```bash
# Check service account tokens
kubectl get secrets --all-namespaces | grep service-account-token | head -5
```
**Output:**
```
# Modern Kubernetes uses projected volumes instead of secret-based tokens
# Service Account Controller manages token projection automatically
```

#### 8. **Namespace Controller Operations**

```bash
# Check namespaces managed by Namespace Controller
kubectl get namespaces
```
**Output:**
```
NAME              STATUS   AGE
argocd            Active   2d
blockchain        Active   2d
default           Active   2d
ingress-nginx     Active   2d
kube-node-lease   Active   2d
kube-public       Active   2d
kube-system       Active   2d
monitoring        Active   2d
nfs-system        Active   2d
```

```bash
# Check namespace finalizers (managed by Namespace Controller)
kubectl get namespace monitoring -o yaml | grep -A 5 finalizers
```
**Output:**
```
  finalizers:
  - kubernetes
  name: monitoring
  resourceVersion: "123456"
  uid: 12345678-1234-1234-1234-123456789012
status:
```

### Controller Manager Metrics and Monitoring

#### 1. **Controller Manager Resource Usage**

```bash
# Check controller manager resource usage
kubectl top pods -n kube-system -l component=kube-controller-manager
```
**Output:**
```
NAME                                              CPU(cores)   MEMORY(bytes)   
kube-controller-manager-hashfoundry-ha-pool-1   35m          64Mi            
kube-controller-manager-hashfoundry-ha-pool-2   32m          58Mi            
kube-controller-manager-hashfoundry-ha-pool-3   38m          67Mi            
```

#### 2. **Controller Metrics**

```bash
# Get controller manager metrics
kubectl get --raw /metrics | grep controller_manager | head -10
```
**Output:**
```
# HELP controller_manager_leader_election_master_status [ALPHA] Gauge of if the reporting manager is master.
# TYPE controller_manager_leader_election_master_status gauge
controller_manager_leader_election_master_status 1
# HELP workqueue_adds_total [ALPHA] Total number of adds handled by workqueue
# TYPE workqueue_adds_total counter
workqueue_adds_total{name="deployment"} 1234
workqueue_adds_total{name="replicaset"} 2345
workqueue_adds_total{name="statefulset"} 345
workqueue_adds_total{name="daemonset"} 456
workqueue_adds_total{name="node"} 567
```

#### 3. **Controller Events**

```bash
# Check controller-related events
kubectl get events --all-namespaces --field-selector source=controller-manager --sort-by=.metadata.creationTimestamp | tail -10
```
**Output:**
```
LAST SEEN   TYPE     REASON                    OBJECT                                MESSAGE
5m          Normal   SuccessfulCreate          replicaset/nfs-exporter-vwx234       Created pod: nfs-exporter-vwx234-xyz12
4m          Normal   ScalingReplicaSet         deployment/nfs-exporter              Scaled up replica set nfs-exporter-vwx234 to 1
3m          Normal   SuccessfulCreate          replicaset/argocd-server-mno345      Created pod: argocd-server-mno345-abc34
2m          Normal   ScalingReplicaSet         deployment/argocd-server             Scaled up replica set argocd-server-mno345 to 1
1m          Normal   SuccessfulCreate          statefulset/substrate-blockchain-alice Created pod: substrate-blockchain-alice-0
```

### Controller Manager High Availability

#### 1. **Leader Election**

```bash
# Check controller manager leader election
kubectl get endpoints -n kube-system kube-controller-manager -o yaml
```
**Output:**
```yaml
apiVersion: v1
kind: Endpoints
metadata:
  annotations:
    control-plane.alpha.kubernetes.io/leader: '{"holderIdentity":"hashfoundry-ha-pool-1_12345678-1234-1234-1234-123456789012","leaseDurationSeconds":15,"acquireTime":"2025-01-23T10:30:15.123456Z","renewTime":"2025-01-25T14:05:01.234567Z","leaderTransitions":2}'
  name: kube-controller-manager
  namespace: kube-system
```

#### 2. **Failover Scenarios**

```bash
# Monitor controller manager leader changes
kubectl get events -n kube-system --field-selector involvedObject.name=kube-controller-manager
```
**Output:**
```
LAST SEEN   TYPE     REASON                   OBJECT                           MESSAGE
2d          Normal   LeaderElection           endpoints/kube-controller-manager hashfoundry-ha-pool-1_12345678-1234-1234-1234-123456789012 became leader
6h          Normal   LeaderElection           endpoints/kube-controller-manager hashfoundry-ha-pool-2_23456789-2345-2345-2345-234567890123 became leader
1h          Normal   LeaderElection           endpoints/kube-controller-manager hashfoundry-ha-pool-1_12345678-1234-1234-1234-123456789012 became leader
```

### Troubleshooting Controller Issues

#### 1. **Controller Failures**

```bash
# Check for controller-related errors
kubectl get events --all-namespaces --field-selector type=Warning | grep -i controller | head -5
```
**Output:**
```
LAST SEEN   TYPE      REASON                OBJECT                           MESSAGE
10m         Warning   FailedCreate          replicaset/failing-app-abc123   Error creating: pods "failing-app-abc123-xyz12" is forbidden: exceeded quota
8m          Warning   FailedMount           pod/storage-app-def456          Unable to attach or mount volumes: unmounted volumes=[data]
5m          Warning   FailedScheduling      pod/large-app-ghi789            0/3 nodes are available: 3 Insufficient memory
3m          Warning   Unhealthy             pod/probe-app-jkl012            Liveness probe failed: HTTP probe failed with statuscode: 500
1m          Warning   BackOff               pod/crash-app-mno345            Back-off restarting failed container
```

#### 2. **Resource Reconciliation Issues**

```bash
# Check for resources stuck in pending state
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```
**Output:**
```
# No pending pods (all controllers working correctly)
```

```bash
# Check for failed deployments
kubectl get deployments --all-namespaces | grep -v "1/1"
```
**Output:**
```
# All deployments are healthy (1/1 ready)
```

### Best Practices in Our HA Cluster

1. **High Availability:**
   - Multiple controller manager instances with leader election
   - Automatic failover between controller manager instances
   - Distributed across control plane nodes

2. **Resource Management:**
   - Proper resource requests and limits for controllers
   - Efficient controller reconciliation loops
   - Appropriate controller sync periods

3. **Monitoring and Alerting:**
   - Controller manager health checks
   - Metrics collection for controller performance
   - Event monitoring for controller actions

4. **Security:**
   - RBAC permissions for controller operations
   - Secure communication with API server
   - Service account token management

5. **Performance Optimization:**
   - Controller concurrency settings
   - Work queue optimization
   - Efficient resource watching and caching

### Controller Manager Components Summary

The Controller Manager is essential for Kubernetes automation because it:

1. **Maintains Desired State:** Continuously reconciles actual state with desired state
2. **Automates Operations:** Handles routine cluster management tasks automatically
3. **Manages Resource Lifecycle:** Controls creation, updates, and deletion of resources
4. **Ensures High Availability:** Provides automatic failover and recovery mechanisms
5. **Handles Scaling:** Manages automatic scaling of applications and infrastructure
6. **Monitors Health:** Responds to node and pod failures appropriately
7. **Coordinates Controllers:** Runs multiple specialized controllers in a single process

### Individual Controller Responsibilities

1. **Node Controller:** Node health, taints, and evictions
2. **Deployment Controller:** Rolling updates and replica management
3. **StatefulSet Controller:** Ordered deployment and persistent storage
4. **DaemonSet Controller:** Node-wide pod deployment
5. **Endpoints Controller:** Service endpoint management
6. **Service Account Controller:** Authentication token management
7. **Namespace Controller:** Namespace lifecycle and cleanup
8. **Replication Controller:** Basic replica management (legacy)

Without the Controller Manager, Kubernetes would be a static system requiring manual intervention for every change. In our HA cluster, the Controller Manager ensures that all desired states are automatically maintained, making the cluster self-healing and highly available across our 3-node infrastructure.

---

## 17. What is the difference between kube-controller-manager and cloud-controller-manager?

### Definition

**kube-controller-manager** is the core Kubernetes controller manager that runs cloud-agnostic controllers responsible for managing standard Kubernetes resources and cluster operations.

**cloud-controller-manager** is a separate component that runs cloud-specific controllers, allowing cloud providers to integrate their services with Kubernetes without modifying the core Kubernetes codebase.

### Key Differences

| Aspect | kube-controller-manager | cloud-controller-manager |
|--------|------------------------|---------------------------|
| **Purpose** | Core Kubernetes functionality | Cloud provider integration |
| **Controllers** | Cloud-agnostic controllers | Cloud-specific controllers |
| **Deployment** | Always present in cluster | Optional, cloud-dependent |
| **Scope** | Standard K8s resources | Cloud provider resources |
| **Examples** | Deployment, StatefulSet, Node | LoadBalancer, Volume, Route |
| **Maintenance** | Kubernetes community | Cloud provider |

### Architecture Separation

#### 1. **Traditional Architecture (Pre-CCM)**
```
kube-controller-manager → All Controllers (including cloud-specific)
```

#### 2. **Modern Architecture (With CCM)**
```
kube-controller-manager → Core Controllers (cloud-agnostic)
cloud-controller-manager → Cloud Controllers (provider-specific)
```

### Controllers Distribution

#### 1. **kube-controller-manager Controllers**
- **Deployment Controller:** Manages application deployments
- **StatefulSet Controller:** Manages stateful applications
- **DaemonSet Controller:** Manages node-wide pods
- **Job Controller:** Manages batch jobs
- **CronJob Controller:** Manages scheduled jobs
- **ReplicaSet Controller:** Manages pod replicas
- **Endpoints Controller:** Manages service endpoints
- **Service Account Controller:** Manages service accounts
- **Namespace Controller:** Manages namespaces
- **PersistentVolume Controller:** Manages PV lifecycle (non-cloud)
- **Node Controller:** Manages node lifecycle (non-cloud aspects)

#### 2. **cloud-controller-manager Controllers**
- **Node Controller:** Cloud-specific node management
- **Route Controller:** Cloud network routing
- **Service Controller:** Cloud LoadBalancer integration
- **Volume Controller:** Cloud storage integration

### Examples from HashFoundry HA Cluster (Digital Ocean)

#### Example 1: kube-controller-manager in Our Cluster

**Core Controllers Running:**
```bash
# Check kube-controller-manager pods
kubectl get pods -n kube-system -l component=kube-controller-manager
```
**Output:**
```
NAME                                              READY   STATUS    RESTARTS   AGE
kube-controller-manager-hashfoundry-ha-pool-1   1/1     Running   0          2d
kube-controller-manager-hashfoundry-ha-pool-2   1/1     Running   0          2d
kube-controller-manager-hashfoundry-ha-pool-3   1/1     Running   0          2d
```

**Controllers Managed by kube-controller-manager:**
```bash
# Check deployments (managed by kube-controller-manager)
kubectl get deployments --all-namespaces
```
**Output:**
```
NAMESPACE      NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
argocd         argocd-application-controller   1/1     1            1           2d
argocd         argocd-dex-server              1/1     1            1           2d
argocd         argocd-redis                   1/1     1            1           2d
argocd         argocd-repo-server             1/1     1            1           2d
argocd         argocd-server                  1/1     1            1           2d
ingress-nginx  nginx-ingress-controller       1/1     1            1           2d
kube-system    coredns                        2/2     2            2           2d
monitoring     nfs-exporter                   1/1     1            1           2d
nfs-system     nfs-provisioner-server         1/1     1            1           2d
```

#### Example 2: cloud-controller-manager (Digital Ocean)

**Digital Ocean Cloud Controller Manager:**
```bash
# Check for cloud-controller-manager (may be managed by DO)
kubectl get pods -n kube-system | grep cloud
```
**Output:**
```
# In managed clusters like DOKS, cloud-controller-manager runs outside the cluster
# or is integrated into the managed control plane
```

**Cloud-Managed Resources:**
```bash
# LoadBalancer service (managed by cloud-controller-manager)
kubectl get service nginx-ingress-controller -n ingress-nginx
```
**Output:**
```
NAME                     TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
nginx-ingress-controller LoadBalancer   10.245.123.53   159.89.123.100   80:30080/TCP,443:30443/TCP   2d
```

**Digital Ocean Block Storage (managed by cloud-controller-manager):**
```bash
# Check persistent volumes (cloud storage)
kubectl get pv
```
**Output:**
```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                  STORAGECLASS     REASON   AGE
pvc-12345678-1234-1234-1234-123456789012   10Gi       RWO            Delete           Bound    blockchain/blockchain-data-substrate-blockchain-alice-0   do-block-storage            2d
pvc-23456789-2345-2345-2345-234567890123   10Gi       RWO            Delete           Bound    blockchain/blockchain-data-substrate-blockchain-bob-0     do-block-storage            2d
pvc-34567890-3456-3456-3456-345678901234   50Gi       RWO            Delete           Bound    nfs-system/nfs-provisioner-server-pvc                    do-block-storage            2d
```

#### Example 3: Cloud Provider Integration

**Digital Ocean Storage Class:**
```yaml
# Managed by cloud-controller-manager
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: do-block-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: pd-ssd
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**LoadBalancer Service Configuration:**
```yaml
# From ha/k8s/addons/nginx-ingress/values.yaml
controller:
  service:
    type: LoadBalancer  # Managed by cloud-controller-manager
    annotations:
      service.beta.kubernetes.io/do-loadbalancer-name: "hashfoundry-ha-lb"
      service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
      service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/healthz"
```

### Practical kubectl Commands and Outputs

#### 1. **Checking Controller Manager Components**

```bash
# Check kube-controller-manager configuration
kubectl describe pod kube-controller-manager-hashfoundry-ha-pool-1 -n kube-system | grep -A 20 "Command:"
```
**Output:**
```
    Command:
      kube-controller-manager
      --allocate-node-cidrs=true
      --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
      --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
      --bind-address=127.0.0.1
      --client-ca-file=/etc/kubernetes/pki/ca.crt
      --cluster-cidr=10.244.0.0/16
      --cluster-name=kubernetes
      --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
      --cluster-signing-key-file=/etc/kubernetes/pki/ca.key
      --controllers=*,bootstrapsigner,tokencleaner
      --kubeconfig=/etc/kubernetes/controller-manager.conf
      --leader-elect=true
      --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
      --root-ca-file=/etc/kubernetes/pki/ca.crt
      --service-account-private-key-file=/etc/kubernetes/pki/sa.key
      --service-cluster-ip-range=10.245.0.0/16
      --use-service-account-credentials=true
```

```bash
# Check for cloud-controller-manager
kubectl get pods --all-namespaces | grep cloud-controller
```
**Output:**
```
# In DOKS (Digital Ocean Kubernetes Service), cloud-controller-manager
# is managed by Digital Ocean and may not be visible in the cluster
```

#### 2. **Cloud-Specific Resources**

```bash
# Check LoadBalancer services (managed by cloud-controller-manager)
kubectl get services --all-namespaces | grep LoadBalancer
```
**Output:**
```
ingress-nginx  nginx-ingress-controller       LoadBalancer   10.245.123.53   159.89.123.100   80:30080/TCP,443:30443/TCP   2d
```

```bash
# Check storage classes (provided by cloud-controller-manager)
kubectl get storageclass
```
**Output:**
```
NAME                         PROVISIONER                 RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
do-block-storage (default)   dobs.csi.digitalocean.com   Delete          WaitForFirstConsumer   true                   2d
```

```bash
# Check node information (cloud metadata)
kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER-ID:.spec.providerID,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type
```
**Output:**
```
NAME                     PROVIDER-ID                                    INSTANCE-TYPE
hashfoundry-ha-pool-1    digitalocean://123456789                      s-2vcpu-4gb
hashfoundry-ha-pool-2    digitalocean://234567890                      s-2vcpu-4gb
hashfoundry-ha-pool-3    digitalocean://345678901                      s-2vcpu-4gb
```

#### 3. **Cloud Provider Events**

```bash
# Check events related to cloud resources
kubectl get events --all-namespaces | grep -i "digitalocean\|loadbalancer\|volume" | head -5
```
**Output:**
```
LAST SEEN   TYPE     REASON                   OBJECT                           MESSAGE
2d          Normal   EnsuringLoadBalancer     service/nginx-ingress-controller  Ensuring load balancer
2d          Normal   EnsuredLoadBalancer      service/nginx-ingress-controller  Ensured load balancer
2d          Normal   ProvisioningSucceeded    persistentvolumeclaim/blockchain-data-substrate-blockchain-alice-0  Successfully provisioned volume pvc-12345678-1234-1234-1234-123456789012
2d          Normal   ProvisioningSucceeded    persistentvolumeclaim/blockchain-data-substrate-blockchain-bob-0    Successfully provisioned volume pvc-23456789-2345-2345-2345-234567890123
2d          Normal   ProvisioningSucceeded    persistentvolumeclaim/nfs-provisioner-server-pvc                   Successfully provisioned volume pvc-34567890-3456-3456-3456-345678901234
```

#### 4. **Controller Responsibilities**

```bash
# Check core Kubernetes resources (kube-controller-manager)
kubectl get deployments,statefulsets,daemonsets --all-namespaces | head -10
```
**Output:**
```
NAMESPACE      NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
argocd         deployment.apps/argocd-application-controller   1/1     1            1           2d
argocd         deployment.apps/argocd-dex-server              1/1     1            1           2d
argocd         deployment.apps/argocd-redis                   1/1     1            1           2d
argocd         deployment.apps/argocd-repo-server             1/1     1            1           2d
argocd         deployment.apps/argocd-server                  1/1     1            1           2d
ingress-nginx  deployment.apps/nginx-ingress-controller       1/1     1            1           2d
kube-system    deployment.apps/coredns                        2/2     2            2           2d
monitoring     deployment.apps/nfs-exporter                   1/1     1            1           2d
nfs-system     deployment.apps/nfs-provisioner-server         1/1     1            1           2d

NAMESPACE    NAME                                         READY   AGE
blockchain   statefulset.apps/substrate-blockchain-alice   1/1     2d
blockchain   statefulset.apps/substrate-blockchain-bob     1/1     2d

NAMESPACE     NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-system   daemonset.apps/cilium       3         3         3       3            3           <none>                   2d
kube-system   daemonset.apps/kube-proxy   3         3         3       3            3           kubernetes.io/os=linux   2d
```

### Controller Migration and Separation

#### 1. **Historical Context**

**Before Cloud Controller Manager:**
- All controllers (including cloud-specific) ran in kube-controller-manager
- Cloud provider code was embedded in Kubernetes core
- Updates required Kubernetes releases

**After Cloud Controller Manager:**
- Cloud-specific controllers moved to separate component
- Cloud providers maintain their own controller managers
- Independent release cycles for cloud integrations

#### 2. **Migration Process**

```bash
# Check if cloud controllers are disabled in kube-controller-manager
kubectl logs -n kube-system kube-controller-manager-hashfoundry-ha-pool-1 | grep -i "cloud\|external"
```
**Output:**
```
I0123 10:30:15.123456       1 controllermanager.go:532] Started "deployment"
I0123 10:30:15.125678       1 controllermanager.go:532] Started "replicaset"
I0123 10:30:15.127890       1 controllermanager.go:532] Started "statefulset"
# Cloud controllers are handled externally by Digital Ocean
```

### Cloud Provider Specific Examples

#### 1. **Digital Ocean Integration**

**LoadBalancer Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  annotations:
    # Digital Ocean specific annotations (handled by cloud-controller-manager)
    service.beta.kubernetes.io/do-loadbalancer-name: "hashfoundry-ha-lb"
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/healthz"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-port: "10254"
spec:
  type: LoadBalancer  # Provisioned by cloud-controller-manager
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
```

**Block Storage Integration:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: blockchain-data-substrate-blockchain-alice-0
  namespace: blockchain
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: do-block-storage  # Handled by cloud-controller-manager
```

#### 2. **Node Management**

```bash
# Check node labels added by cloud-controller-manager
kubectl get nodes -o yaml | grep -A 10 -B 5 "digitalocean\|topology"
```
**Output:**
```yaml
    labels:
      beta.kubernetes.io/arch: amd64
      beta.kubernetes.io/instance-type: s-2vcpu-4gb
      beta.kubernetes.io/os: linux
      kubernetes.io/arch: amd64
      kubernetes.io/hostname: hashfoundry-ha-pool-1
      kubernetes.io/os: linux
      node.kubernetes.io/instance-type: s-2vcpu-4gb
      topology.kubernetes.io/region: fra1
      topology.kubernetes.io/zone: fra1
  spec:
    providerID: digitalocean://123456789
```

### Benefits of Separation

#### 1. **For Kubernetes Core**
- **Reduced Complexity:** Core controllers focus on standard Kubernetes resources
- **Faster Development:** No dependency on cloud provider release cycles
- **Better Testing:** Cloud-agnostic testing of core functionality
- **Smaller Binary:** Reduced size without cloud provider code

#### 2. **For Cloud Providers**
- **Independent Releases:** Update cloud integrations without Kubernetes releases
- **Custom Features:** Implement provider-specific functionality
- **Better Support:** Direct control over cloud integration quality
- **Faster Innovation:** Rapid deployment of new cloud services

#### 3. **For Users**
- **Better Reliability:** Separation of concerns reduces failure domains
- **Flexibility:** Choose cloud providers without core Kubernetes changes
- **Performance:** Optimized cloud integrations by providers
- **Support:** Clear ownership of cloud vs. core issues

### Troubleshooting Differences

#### 1. **kube-controller-manager Issues**

```bash
# Check core controller problems
kubectl get events --all-namespaces --field-selector reason=FailedCreate
```
**Output:**
```
LAST SEEN   TYPE      REASON        OBJECT                           MESSAGE
5m          Warning   FailedCreate  replicaset/failing-app-abc123   Error creating: pods "failing-app-abc123-xyz12" is forbidden: exceeded quota
```

#### 2. **cloud-controller-manager Issues**

```bash
# Check cloud resource problems
kubectl describe service nginx-ingress-controller -n ingress-nginx
```
**Output:**
```
Events:
  Type     Reason                Age   From                Message
  ----     ------                ----  ----                -------
  Normal   EnsuringLoadBalancer  2d    service-controller  Ensuring load balancer
  Normal   EnsuredLoadBalancer   2d    service-controller  Ensured load balancer
```

```bash
# Check storage provisioning issues
kubectl describe pvc blockchain-data-substrate-blockchain-alice-0 -n blockchain
```
**Output:**
```
Events:
  Type    Reason                Age   From                         Message
  ----    ------                ----  ----                         -------
  Normal  Provisioning          2d    dobs.csi.digitalocean.com    External provisioner is provisioning volume for claim "blockchain/blockchain-data-substrate-blockchain-alice-0"
  Normal  ProvisioningSucceeded  2d    dobs.csi.digitalocean.com    Successfully provisioned volume pvc-12345678-1234-1234-1234-123456789012
```

### Best Practices in Our HA Cluster

1. **Clear Separation:**
   - Core Kubernetes resources managed by kube-controller-manager
   - Cloud resources managed by Digital Ocean's cloud-controller-manager
   - No overlap in controller responsibilities

2. **Monitoring:**
   - Monitor both core and cloud controller health
   - Separate alerting for core vs. cloud issues
   - Track cloud resource provisioning separately

3. **Troubleshooting:**
   - Identify whether issues are core Kubernetes or cloud-specific
   - Use appropriate logs and events for each controller type
   - Engage correct support channels (Kubernetes vs. cloud provider)

4. **Configuration:**
   - Use cloud-specific annotations for LoadBalancer services
   - Leverage cloud storage classes for persistent volumes
   - Configure cloud-specific node labels and taints

### Summary

The key differences between kube-controller-manager and cloud-controller-manager:

1. **kube-controller-manager:**
   - Manages core Kubernetes resources (Deployments, StatefulSets, etc.)
   - Cloud-agnostic functionality
   - Part of standard Kubernetes distribution
   - Always present in clusters

2. **cloud-controller-manager:**
   - Manages cloud-specific resources (LoadBalancers, Volumes, etc.)
   - Provider-specific functionality
   - Maintained by cloud providers
   - Optional, depends on cloud integration

In our HashFoundry HA cluster on Digital Ocean, kube-controller-manager handles all the standard Kubernetes workloads like our blockchain validators, monitoring stack, and ArgoCD applications, while Digital Ocean's cloud-controller-manager manages the LoadBalancer for ingress and the block storage for our persistent volumes.
