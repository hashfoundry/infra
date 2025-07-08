#!/bin/bash

# HashFoundry Infrastructure Deployment Script

set -e

echo "🚀 Deploying HashFoundry Infrastructure..."

# Load environment variables
if [ -f .env ]; then
    echo "📖 Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ .env file not found! Please run ./init.sh first."
    exit 1
fi

# Check required variables
if [ -z "$DO_TOKEN" ] || [ "$DO_TOKEN" = "your_digitalocean_api_token_here" ]; then
    echo "❌ Please set your DigitalOcean API token in .env file"
    exit 1
fi

if [ -z "$ARGOCD_ADMIN_PASSWORD" ]; then
    echo "❌ ARGOCD_ADMIN_PASSWORD not set in .env file"
    exit 1
fi

echo "🏗️  Step 1: Deploying infrastructure with Terraform..."
cd terraform

# Deploy infrastructure
./terraform.sh init
./terraform.sh apply -auto-approve

echo "⚙️  Step 2: Configuring kubectl context..."
cd ..
doctl kubernetes cluster kubeconfig save $CLUSTER_NAME

echo "🎯 Step 3: Deploying ArgoCD..."
cd k8s/addons/argo-cd
helm dependency update

# Deploy ArgoCD with environment variables
envsubst < values.yaml | helm upgrade --install --create-namespace -n argocd argocd . -f -

echo "⏳ Waiting for ArgoCD to be ready..."
export KUBECONFIG=$(pwd)/../../../terraform/modules/kubernetes/kubeconfig.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "📱 Step 4: Deploying ArgoCD Apps..."
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
