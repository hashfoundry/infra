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

echo "🗄️  Step 1: Deploying NFS Provisioner..."
cd k8s/addons/nfs-provisioner
echo "   Installing NFS Provisioner for ReadWriteMany storage support..."
helm upgrade --install --create-namespace -n nfs-system nfs-provisioner . -f values.yaml --wait --timeout=10m

echo "✅ NFS Provisioner deployed successfully!"
echo "   StorageClass 'nfs-client' is now available for ReadWriteMany volumes"

echo "🎯 Step 2: Deploying ArgoCD..."
cd ../argo-cd
helm dependency update

# Deploy ArgoCD with environment variables (includes NFS integration)
envsubst < values.yaml | helm upgrade --install --create-namespace -n argocd argocd . -f -

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "📦 Step 3: Deploying ArgoCD Apps..."
cd ../argo-cd-apps
helm upgrade --install -n argocd argo-cd-apps . -f values.yaml

echo "⏳ Waiting for all applications to sync..."
sleep 30

echo "🔄 Step 4: Triggering application synchronization..."
# Trigger sync for applications that might be OutOfSync
kubectl patch application nginx-ingress -n argocd --type merge --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' 2>/dev/null || true
kubectl patch application hashfoundry-react -n argocd --type merge --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' 2>/dev/null || true

echo "⏳ Waiting for final synchronization..."
sleep 20

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
