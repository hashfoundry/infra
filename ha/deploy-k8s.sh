#!/bin/bash

# HashFoundry Kubernetes Applications Deployment Script

set -e

# Load common functions
source "$(dirname "$0")/common-functions.sh"

echo "🚀 Deploying HashFoundry Kubernetes Applications..."

# Check required CLI tools for K8s deployment
check_cli_tools "kubectl" "helm" "doctl" "envsubst" "htpasswd"

# Load and validate environment variables
load_and_validate_env

# Authenticate with DigitalOcean
authenticate_digitalocean

# Check if cluster exists
if ! check_cluster_exists "$CLUSTER_NAME"; then
    echo "❌ Cluster '$CLUSTER_NAME' does not exist. Please run ./deploy-terraform.sh first."
    exit 1
fi

# Setup kubectl context
setup_kubectl_context "$CLUSTER_NAME" "$CLUSTER_REGION"

echo "🗄️  Step 1: Deploying NFS Provisioner (Dynamic IP approach)..."
cd k8s/addons/nfs-provisioner

# Phase 1: Deploy only the NFS server (without provisioner)
echo "   Phase 1: Installing NFS Server only..."
helm upgrade --install --create-namespace -n nfs-system nfs-provisioner . -f values.yaml --set nfsProvisioner.enabled=false --wait --timeout=10m

# Wait for NFS server service to be ready
echo "   Waiting for NFS server service to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=nfs-server -n nfs-system --timeout=300s

# Phase 2: Get the dynamic IP address of NFS server service
echo "   Phase 2: Getting NFS server service IP dynamically..."
NFS_SERVER_IP=$(kubectl get svc nfs-provisioner-server -n nfs-system -o jsonpath='{.spec.clusterIP}')
echo "   ✅ NFS Server IP detected: $NFS_SERVER_IP"

# Phase 3: Deploy the provisioner with the dynamically obtained IP
echo "   Phase 3: Installing NFS Provisioner with dynamic server IP..."
helm upgrade nfs-provisioner . -n nfs-system -f values.yaml --set nfsProvisioner.nfsServer="$NFS_SERVER_IP" --wait --timeout=5m

echo "✅ NFS Provisioner deployed successfully with dynamic IP approach!"
echo "   📦 StorageClass 'nfs-client' is now available for ReadWriteMany volumes"
echo "   🌐 NFS Server IP: $NFS_SERVER_IP"
echo "   🔄 No hard-coded IPs - fully repeatable deployment!"

echo "🎯 Step 2: Deploying ArgoCD..."
cd ../argo-cd
helm dependency update

# Deploy ArgoCD with environment variables (includes NFS integration)
envsubst < values.yaml | helm upgrade --install --create-namespace -n argocd argocd . -f -

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "🏗️  Step 3: Creating required namespaces..."
# Create namespaces that ArgoCD applications need
echo "   Creating ingress-nginx namespace..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

echo "   Creating hashfoundry-react-dev namespace..."
kubectl create namespace hashfoundry-react-dev --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Step 4: Deploying ArgoCD Apps..."
cd ../argo-cd-apps

# Update NFS Provisioner Application with dynamic IP before deploying
echo "   Preparing ArgoCD Applications with dynamic NFS IP..."
# Create a temporary values file with the dynamic NFS IP
cat > values-dynamic.yaml << EOF
addons:
  - name: nfs-provisioner
    namespace: nfs-system
    project: default
    source:
      path: ha/k8s/addons/nfs-provisioner
      helm:
        valueFiles:
          - values.yaml
        parameters:
          - name: nfsProvisioner.nfsServer
            value: "$NFS_SERVER_IP"
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
      syncOptions:
        - CreateNamespace=true
    autosync: true
EOF

# Deploy ArgoCD Apps with base values first
helm upgrade --install -n argocd argo-cd-apps . -f values.yaml

# Wait a moment for applications to be created
echo "   Waiting for ArgoCD Applications to be created..."
sleep 10

# Update NFS Provisioner with dynamic IP
echo "   Updating NFS Provisioner with dynamic IP: $NFS_SERVER_IP"
kubectl patch application nfs-provisioner -n argocd --type merge --patch "{\"spec\":{\"source\":{\"helm\":{\"parameters\":[{\"name\":\"nfsProvisioner.nfsServer\",\"value\":\"$NFS_SERVER_IP\"}]}}}}"

echo "⏳ Waiting for all applications to sync..."
sleep 30

echo "🔄 Step 5: Verifying application synchronization..."
# Check application status and trigger sync if needed
for app in nginx-ingress hashfoundry-react nfs-provisioner; do
    echo "   Checking $app application status..."
    status=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
    if [ "$status" != "Synced" ]; then
        echo "   Triggering sync for $app..."
        kubectl patch application $app -n argocd --type merge --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' 2>/dev/null || true
    fi
done

echo "⏳ Waiting for final synchronization..."
sleep 30

# Clean up temporary file
rm -f values-dynamic.yaml

echo "✅ Kubernetes applications deployment completed!"
echo ""
echo "🔗 Access Information:"
echo "ArgoCD UI: http://localhost:8080 (run: kubectl port-forward svc/argocd-server -n argocd 8080:80)"
echo "Username: admin"
echo "Password: $ARGOCD_ADMIN_PASSWORD"
echo ""
echo "📊 Check status:"
echo "./status.sh                    # Comprehensive status check"
echo "kubectl get applications -n argocd"
echo "kubectl get nodes"
echo ""
