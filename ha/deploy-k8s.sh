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

echo "🎯 Step 2: Deploying ArgoCD..."
cd k8s/addons/argo-cd
helm dependency update

# Deploy ArgoCD with environment variables
envsubst < values.yaml | helm upgrade --install --create-namespace -n argocd argocd . -f -

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo " Step 3: Deploying ArgoCD Apps..."
cd ../argo-cd-apps
helm upgrade --install -n argocd argo-cd-apps . -f values.yaml

echo "⏳ Waiting for all applications to sync..."
sleep 30

echo "✅ Deployment completed!"
echo ""
echo "🔗 Access Information:"
echo "ArgoCD UI: http://localhost:8080 (run: kubectl port-forward svc/argocd-server -n argocd 8080:80)"
echo "Username: admin"
echo "Password: $ARGOCD_ADMIN_PASSWORD"
echo ""
echo "📊 Check status:"
echo "kubectl get applications -n argocd"
echo "kubectl get nodes"
echo ""
