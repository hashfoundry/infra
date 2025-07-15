#!/bin/bash

# HashFoundry Infrastructure Full Deployment Script
# This script orchestrates the complete deployment by calling separate scripts

set -e

echo "🚀 HashFoundry Infrastructure Full Deployment"
echo "=============================================="
echo ""
echo "This script will deploy the complete HashFoundry infrastructure:"
echo "1. Terraform infrastructure (Kubernetes cluster)"
echo "2. Kubernetes applications (ArgoCD, NGINX Ingress, Apps)"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found! Please run ./init.sh first."
    exit 1
fi

# Ask for confirmation
read -p "Do you want to proceed with the full deployment? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 0
fi

echo ""
echo "🏗️  Phase 1: Deploying Terraform Infrastructure..."
echo "=================================================="
./deploy-terraform.sh

if [ $? -ne 0 ]; then
    echo "❌ Terraform deployment failed!"
    exit 1
fi

echo ""
echo "✅ Terraform deployment completed successfully!"
echo ""
echo "🎯 Phase 2: Deploying Kubernetes Applications..."
echo "================================================"
./deploy-k8s.sh

if [ $? -ne 0 ]; then
    echo "❌ Kubernetes deployment failed!"
    exit 1
fi

echo ""
echo "🎉 Full deployment completed successfully!"
echo "=========================================="
echo ""
echo "🔗 Access Information:"
echo "ArgoCD UI: http://localhost:8080 (run: kubectl port-forward svc/argocd-server -n argocd 8080:80)"
echo "Username: admin"
echo "Password: (check your .env file)"
echo ""
echo "📊 Quick status check:"
echo "kubectl get applications -n argocd"
echo "kubectl get nodes"
echo ""
echo "📚 For more information, see:"
echo "- QUICKSTART.md - Quick start guide"
echo "- ARGOCD_HA_ANALYSIS.md - HA architecture analysis"
echo "- HA_TESTING_REPORT.md - Testing and verification results"
echo ""
