#!/bin/bash

# HashFoundry Infrastructure Force Cleanup Script
# Use this script when regular cleanup.sh gets stuck

set -e

echo "🚨 Force Cleanup - HashFoundry Infrastructure..."

# Load environment variables
if [ -f .env ]; then
    echo "📖 Loading environment variables from .env..."
    source .env
else
    echo "❌ .env file not found! Please ensure .env file exists."
    exit 1
fi

# Check if DO_TOKEN is set
if [ -z "$DO_TOKEN" ] || [ "$DO_TOKEN" = "your_digitalocean_api_token_here" ]; then
    echo "❌ Please set your DigitalOcean API token in .env file"
    exit 1
fi

# Authenticate with DigitalOcean
echo "🔐 Authenticating with DigitalOcean..."
doctl auth init -t $DO_TOKEN

echo ""
echo "⚠️  FORCE CLEANUP MODE - This will aggressively delete stuck resources"
echo "   - All PVCs will be force deleted (finalizers removed)"
echo "   - All PVs will be force deleted"
echo "   - All DigitalOcean volumes will be force deleted"
echo "   - Kubernetes cluster will be force deleted"
echo ""
read -p "Are you sure you want to continue with force cleanup? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Force cleanup cancelled."
    exit 0
fi

echo ""
echo "🚨 Starting force cleanup process..."

# Step 1: Force delete all PVCs by removing finalizers
echo "💾 Step 1: Force deleting all PVCs..."
if kubectl config current-context | grep -q "$CLUSTER_NAME" 2>/dev/null; then
    echo "📋 Found active kubectl context, force deleting PVCs..."
    
    # Get all PVCs and force delete them
    all_pvcs=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | awk '{print $2 " " $1}' || true)
    if [ -n "$all_pvcs" ]; then
        echo "$all_pvcs" | while read pvc_name namespace_name; do
            echo "   Force deleting PVC: $pvc_name in namespace $namespace_name"
            # Remove finalizers first
            kubectl patch pvc "$pvc_name" -n "$namespace_name" -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            # Force delete
            kubectl delete pvc "$pvc_name" -n "$namespace_name" --force --grace-period=0 2>/dev/null || true
        done
    else
        echo "   No PVCs found"
    fi
    
    echo "✅ PVCs force deleted"
else
    echo "⚠️  No active kubectl context found"
fi

# Step 2: Force delete all PVs
echo "💾 Step 2: Force deleting all PVs..."
if kubectl config current-context | grep -q "$CLUSTER_NAME" 2>/dev/null; then
    all_pvs=$(kubectl get pv --no-headers 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$all_pvs" ]; then
        echo "$all_pvs" | while read pv_name; do
            echo "   Force deleting PV: $pv_name"
            # Remove finalizers first
            kubectl patch pv "$pv_name" -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            # Force delete
            kubectl delete pv "$pv_name" --force --grace-period=0 2>/dev/null || true
        done
    else
        echo "   No PVs found"
    fi
    
    echo "✅ PVs force deleted"
fi

# Step 3: Force delete all DigitalOcean volumes
echo "💾 Step 3: Force deleting DigitalOcean volumes..."
all_volumes=$(doctl compute volume list --format Name,ID --no-header || true)

if [ -n "$all_volumes" ]; then
    echo "🗑️  Found DigitalOcean volumes, force deleting ALL..."
    echo "$all_volumes" | while read vol_name vol_id; do
        echo "   Force deleting volume: $vol_name ($vol_id)"
        doctl compute volume delete $vol_id --force 2>/dev/null || echo "     Failed to delete $vol_name"
    done
    echo "✅ DigitalOcean volumes force deleted"
else
    echo "✅ No DigitalOcean volumes found"
fi

# Step 4: Force delete cluster
echo "🏗️  Step 4: Force deleting Kubernetes cluster..."
cluster_info=$(doctl kubernetes cluster list --format Name,ID --no-header | grep -i "$CLUSTER_NAME" || true)

if [ -n "$cluster_info" ]; then
    echo "$cluster_info" | while read cluster_name cluster_id; do
        echo "   Force deleting cluster: $cluster_name ($cluster_id)"
        doctl kubernetes cluster delete $cluster_id --force
    done
    echo "✅ Cluster force deleted"
else
    echo "✅ No cluster found with name $CLUSTER_NAME"
fi

# Step 5: Force delete all load balancers
echo "🔍 Step 5: Force deleting all load balancers..."
all_lbs=$(doctl compute load-balancer list --format Name,ID --no-header || true)

if [ -n "$all_lbs" ]; then
    echo "🗑️  Found load balancers, force deleting ALL..."
    echo "$all_lbs" | while read lb_name lb_id; do
        echo "   Force deleting load balancer: $lb_name ($lb_id)"
        doctl compute load-balancer delete $lb_id --force
    done
    echo "✅ Load balancers force deleted"
else
    echo "✅ No load balancers found"
fi

# Step 6: Clean up local kubectl context
echo "🧹 Step 6: Cleaning up local kubectl context..."
kubectl config delete-context "do-$CLUSTER_REGION-$CLUSTER_NAME" 2>/dev/null || echo "   Context not found or already deleted"
kubectl config delete-cluster "do-$CLUSTER_REGION-$CLUSTER_NAME" 2>/dev/null || echo "   Cluster config not found or already deleted"

# Step 7: Clean up local files
echo "🧹 Step 7: Cleaning up local files..."
if [ -f terraform/kubeconfig.yaml ]; then
    rm terraform/kubeconfig.yaml
    echo "   Removed terraform/kubeconfig.yaml"
fi

if [ -d terraform/.terraform ]; then
    rm -rf terraform/.terraform
    echo "   Removed terraform/.terraform directory"
fi

if [ -f terraform/terraform.tfstate ]; then
    rm terraform/terraform.tfstate
    echo "   Removed terraform/terraform.tfstate"
fi

if [ -f terraform/terraform.tfstate.backup ]; then
    rm terraform/terraform.tfstate.backup
    echo "   Removed terraform/terraform.tfstate.backup"
fi

echo ""
echo "✅ Force cleanup completed!"
echo ""
echo "📊 Summary:"
echo "   ✅ All PVCs force deleted (finalizers removed)"
echo "   ✅ All PVs force deleted"
echo "   ✅ All DigitalOcean volumes force deleted"
echo "   ✅ Kubernetes cluster force deleted"
echo "   ✅ All load balancers force deleted"
echo "   ✅ Local kubectl context cleaned up"
echo "   ✅ Local Terraform files cleaned up"
echo ""
echo "💡 Note: Your .env file has been preserved for future deployments"
echo "🚨 Warning: This was an aggressive cleanup - verify all resources are deleted"
echo ""
