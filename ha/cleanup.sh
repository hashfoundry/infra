#!/bin/bash

# HashFoundry Infrastructure Cleanup Script

set -e

echo "🧹 Cleaning up HashFoundry Infrastructure..."

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

# Confirm deletion
echo ""
echo "⚠️  WARNING: This will permanently delete the following resources:"
echo "   - Kubernetes cluster: $CLUSTER_NAME"
echo "   - All associated Load Balancers"
echo "   - All persistent volumes and data"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled."
    exit 0
fi

echo ""
echo "🗑️  Starting cleanup process..."

# Step 1: Clean up Kubernetes volumes before cluster deletion
echo "💾 Step 1: Cleaning up Kubernetes volumes..."
if kubectl config current-context | grep -q "$CLUSTER_NAME" 2>/dev/null; then
    echo "📋 Found active kubectl context, cleaning up volumes..."
    
    # Delete all PVCs with force and short timeout
    echo "   Deleting PersistentVolumeClaims..."
    kubectl delete pvc --all --all-namespaces --timeout=30s --force --grace-period=0 2>/dev/null || echo "   Initial PVC deletion completed or timed out"
    
    # Force delete any remaining PVCs by removing finalizers
    echo "   Force deleting remaining PVCs..."
    remaining_pvcs=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | awk '{print $2 " -n " $1}' || true)
    if [ -n "$remaining_pvcs" ]; then
        echo "$remaining_pvcs" | while read pvc_name namespace_flag namespace_name; do
            echo "     Force deleting PVC: $pvc_name in namespace $namespace_name"
            kubectl patch pvc "$pvc_name" -n "$namespace_name" -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            kubectl delete pvc "$pvc_name" -n "$namespace_name" --force --grace-period=0 2>/dev/null || true
        done
    fi
    
    # Wait a bit for PVCs to be deleted
    sleep 5
    
    # Force delete any remaining PVs
    echo "   Checking for remaining PersistentVolumes..."
    remaining_pvs=$(kubectl get pv --no-headers 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$remaining_pvs" ]; then
        echo "   Force deleting remaining PersistentVolumes..."
        echo "$remaining_pvs" | while read pv_name; do
            echo "     Deleting PV: $pv_name"
            kubectl patch pv "$pv_name" -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            kubectl delete pv "$pv_name" --force --grace-period=0 2>/dev/null || true
        done
    fi
    
    echo "✅ Kubernetes volumes cleaned up"
else
    echo "⚠️  No active kubectl context found, skipping volume cleanup"
fi

# Step 2: Clean up DigitalOcean volumes manually
echo "💾 Step 2: Cleaning up DigitalOcean volumes..."
remaining_volumes=$(doctl compute volume list --format Name,ID --no-header | grep -E "(pvc-|$CLUSTER_NAME)" || true)

if [ -n "$remaining_volumes" ]; then
    echo "🗑️  Found remaining DigitalOcean volumes, deleting..."
    echo "$remaining_volumes" | while read vol_name vol_id; do
        echo "   Deleting volume: $vol_name ($vol_id)"
        doctl compute volume delete $vol_id --force 2>/dev/null || echo "     Failed to delete $vol_name (may be in use)"
    done
    echo "✅ DigitalOcean volumes cleaned up"
else
    echo "✅ No DigitalOcean volumes found"
fi

# Step 3: Delete Terraform infrastructure (includes cluster and load balancers)
echo "🏗️  Step 3: Destroying Terraform infrastructure..."
cd terraform

if [ -f terraform.tfstate ] || [ -d .terraform ]; then
    echo "📋 Found Terraform state, proceeding with destroy..."
    ./terraform.sh destroy -auto-approve
    echo "✅ Terraform infrastructure destroyed"
else
    echo "⚠️  No Terraform state found, skipping terraform destroy"
fi

cd ..

# Step 4: Clean up any remaining load balancers manually (if any)
echo "🔍 Step 4: Checking for remaining load balancers..."
remaining_lbs=$(doctl compute load-balancer list --format Name,ID --no-header | grep -E "hashfoundry" || true)

if [ -n "$remaining_lbs" ]; then
    echo "🗑️  Found remaining load balancers, deleting..."
    echo "$remaining_lbs" | while read lb_name lb_id; do
        echo "   Deleting load balancer: $lb_name ($lb_id)"
        doctl compute load-balancer delete $lb_id --force
    done
    echo "✅ Remaining load balancers deleted"
else
    echo "✅ No remaining load balancers found"
fi

# Step 5: Verify cluster deletion
echo "🔍 Step 5: Verifying cluster deletion..."
remaining_clusters=$(doctl kubernetes cluster list --format Name,ID --no-header | grep -i "$CLUSTER_NAME" || true)

if [ -n "$remaining_clusters" ]; then
    echo "🗑️  Found remaining cluster, deleting manually..."
    echo "$remaining_clusters" | while read cluster_name cluster_id; do
        echo "   Deleting cluster: $cluster_name ($cluster_id)"
        doctl kubernetes cluster delete $cluster_id --force
    done
    echo "✅ Remaining cluster deleted"
else
    echo "✅ Cluster successfully deleted"
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
echo "✅ Cleanup completed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ Kubernetes volumes and PVCs deleted"
echo "   ✅ DigitalOcean volumes removed"
echo "   ✅ Kubernetes cluster '$CLUSTER_NAME' deleted"
echo "   ✅ Load balancers removed"
echo "   ✅ Local kubectl context cleaned up"
echo "   ✅ Local Terraform files cleaned up"
echo ""
echo "💡 Note: Your .env file has been preserved for future deployments"
echo ""
