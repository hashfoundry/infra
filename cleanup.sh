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

# Step 1: Delete Terraform infrastructure (includes cluster and load balancers)
echo "🏗️  Step 1: Destroying Terraform infrastructure..."
cd terraform

if [ -f terraform.tfstate ] || [ -d .terraform ]; then
    echo "📋 Found Terraform state, proceeding with destroy..."
    ./terraform.sh destroy -auto-approve
    echo "✅ Terraform infrastructure destroyed"
else
    echo "⚠️  No Terraform state found, skipping terraform destroy"
fi

cd ..

# Step 2: Clean up any remaining load balancers manually (if any)
echo "🔍 Step 2: Checking for remaining load balancers..."
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

# Step 3: Verify cluster deletion
echo "🔍 Step 3: Verifying cluster deletion..."
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

# Step 4: Clean up local kubectl context
echo "🧹 Step 4: Cleaning up local kubectl context..."
kubectl config delete-context "do-$CLUSTER_REGION-$CLUSTER_NAME" 2>/dev/null || echo "   Context not found or already deleted"
kubectl config delete-cluster "do-$CLUSTER_REGION-$CLUSTER_NAME" 2>/dev/null || echo "   Cluster config not found or already deleted"

# Step 5: Clean up local files
echo "🧹 Step 5: Cleaning up local files..."
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
echo "   ✅ Kubernetes cluster '$CLUSTER_NAME' deleted"
echo "   ✅ Load balancers removed"
echo "   ✅ Local kubectl context cleaned up"
echo "   ✅ Local Terraform files cleaned up"
echo ""
echo "💡 Note: Your .env file has been preserved for future deployments"
echo ""
