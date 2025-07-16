#!/bin/bash

# Grafana Safe Upgrade Script with Recreate Strategy
# Solves ReadWriteOnce PVC conflicts during Helm upgrades

set -e

echo "🔄 Starting Grafana upgrade with Recreate strategy..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "values.yaml" ]; then
    print_error "values.yaml not found. Please run this script from the grafana chart directory."
    exit 1
fi

# Check current deployment strategy
print_status "Checking current deployment strategy..."
CURRENT_STRATEGY=$(kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.strategy.type}' 2>/dev/null || echo "NotFound")

if [ "$CURRENT_STRATEGY" = "NotFound" ]; then
    print_warning "Grafana deployment not found. This might be a fresh installation."
elif [ "$CURRENT_STRATEGY" = "Recreate" ]; then
    print_success "Deployment strategy is already set to Recreate"
else
    print_warning "Current deployment strategy: $CURRENT_STRATEGY (will be changed to Recreate)"
fi

# Show current Grafana status
print_status "Current Grafana status:"
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana 2>/dev/null || print_warning "No Grafana pods found"

# Show PVC status
print_status "Current PVC status:"
kubectl get pvc -n monitoring | grep grafana 2>/dev/null || print_warning "No Grafana PVC found"

# Confirm upgrade
echo ""
print_warning "This upgrade will:"
echo "  1. Apply Recreate deployment strategy"
echo "  2. Cause brief downtime (30-60 seconds) during pod recreation"
echo "  3. Preserve all data in persistent volume"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Upgrade cancelled by user"
    exit 0
fi

# Perform the upgrade
print_status "Upgrading Grafana with Recreate strategy..."
helm upgrade grafana . -n monitoring -f values.yaml

# Wait for deployment to be ready
print_status "Waiting for Grafana to be ready..."
if kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring; then
    print_success "Grafana deployment is ready!"
else
    print_error "Timeout waiting for Grafana to be ready"
    print_status "Current pod status:"
    kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
    exit 1
fi

# Verify the upgrade
print_status "Verifying upgrade..."

# Check deployment strategy
NEW_STRATEGY=$(kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.strategy.type}')
if [ "$NEW_STRATEGY" = "Recreate" ]; then
    print_success "Deployment strategy successfully set to: $NEW_STRATEGY"
else
    print_warning "Deployment strategy: $NEW_STRATEGY (expected: Recreate)"
fi

# Check pod status
POD_STATUS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$POD_STATUS" = "Running" ]; then
    print_success "Grafana pod is running"
else
    print_warning "Grafana pod status: $POD_STATUS"
fi

# Check PVC status
PVC_STATUS=$(kubectl get pvc grafana -n monitoring -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" = "Bound" ]; then
    print_success "Grafana PVC is bound"
else
    print_warning "Grafana PVC status: $PVC_STATUS"
fi

# Final status report
echo ""
print_success "Grafana upgrade completed!"
echo ""
print_status "Final status:"
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
echo ""
kubectl get pvc -n monitoring | grep grafana
echo ""

# Test connectivity
print_status "Testing Grafana connectivity..."
if kubectl exec -n monitoring deployment/grafana -- curl -s -f http://localhost:3000/api/health > /dev/null; then
    print_success "Grafana health check passed"
else
    print_warning "Grafana health check failed (might still be starting up)"
fi

echo ""
print_success "🌐 Grafana should be available at: https://grafana.hashfoundry.local"
print_status "📊 You can also use port-forward: kubectl port-forward -n monitoring svc/grafana 3000:80"
echo ""
print_status "Upgrade completed successfully! 🎉"
