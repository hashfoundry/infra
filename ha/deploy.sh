#!/bin/bash

# HashFoundry Infrastructure Complete Deployment Script
# This script deploys both Terraform infrastructure and Kubernetes applications

set -e

# Load common functions
source "$(dirname "$0")/common-functions.sh"

echo "🚀 HashFoundry Infrastructure Complete Deployment"
echo "=================================================="

# Check required CLI tools
check_cli_tools "terraform" "kubectl" "helm" "doctl" "envsubst" "htpasswd"

# Load and validate environment variables
load_and_validate_env

echo ""
echo "📋 Deployment Plan:"
echo "   1. 🏗️  Deploy Terraform infrastructure (cluster, networking)"
echo "   2. 🗄️  Deploy NFS Provisioner with dynamic IP approach"
echo "   3. 🎯 Deploy ArgoCD with NFS integration"
echo "   4. 📦 Deploy applications via ArgoCD"
echo ""

# Step 1: Deploy Terraform infrastructure
echo "🏗️  Step 1: Deploying Terraform infrastructure..."
./deploy-terraform.sh

echo ""
echo "⏳ Waiting 30 seconds for cluster to stabilize..."
sleep 30

# Step 2: Deploy Kubernetes applications with NFS
echo ""
echo "🎯 Step 2: Deploying Kubernetes applications..."
./deploy-k8s.sh

echo ""
echo "🎉 Complete deployment finished successfully!"
echo "=============================================="
echo ""
echo "🔗 Access Information:"
echo "ArgoCD UI: http://localhost:8080"
echo "   Command: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo "   Username: admin"
echo "   Password: $ARGOCD_ADMIN_PASSWORD"
echo ""
echo "📊 Status Commands:"
echo "   ./status.sh                    # Comprehensive status check"
echo "   kubectl get applications -n argocd"
echo "   kubectl get nodes"
echo "   kubectl get pods -n nfs-system"
echo ""
echo "🗄️  NFS Storage:"
echo "   StorageClass 'nfs-client' is available for ReadWriteMany volumes"
echo "   Dynamic IP approach ensures repeatable deployments"
echo ""
echo "🧹 Cleanup:"
echo "   ./cleanup.sh                   # Remove all infrastructure"
echo ""
