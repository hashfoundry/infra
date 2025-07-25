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
