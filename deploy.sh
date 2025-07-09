#!/bin/bash

# HashFoundry Infrastructure Deployment Script

set -e

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed"
        return 1
    else
        echo "✅ $1 is installed"
        return 0
    fi
}

# Function to display installation instructions
show_installation_instructions() {
    echo ""
    echo "📋 Installation Instructions:"
    echo ""
    echo "🍺 For macOS (using Homebrew):"
    echo "  brew install terraform kubectl helm doctl"
    echo "  # envsubst is part of gettext package"
    echo "  brew install gettext"
    echo ""
    echo "🐧 For Ubuntu/Debian:"
    echo "  # Terraform"
    echo "  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
    echo "  echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com focal main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list"
    echo "  sudo apt update && sudo apt install terraform"
    echo ""
    echo "  # kubectl"
    echo "  curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
    echo "  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
    echo ""
    echo "  # Helm"
    echo "  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null"
    echo "  echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main\" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list"
    echo "  sudo apt-get update && sudo apt-get install helm"
    echo ""
    echo "  # doctl"
    echo "  cd ~ && wget https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz"
    echo "  tar xf ~/doctl-1.104.0-linux-amd64.tar.gz && sudo mv ~/doctl /usr/local/bin"
    echo ""
    echo "  # envsubst (gettext-base)"
    echo "  sudo apt-get install gettext-base"
    echo ""
    echo "🪟 For Windows:"
    echo "  # Use Chocolatey or download binaries manually"
    echo "  choco install terraform kubernetes-cli kubernetes-helm"
    echo "  # For doctl and envsubst, download from official releases"
    echo ""
}

echo "🚀 Deploying HashFoundry Infrastructure..."

# Check required CLI tools
echo "🔍 Checking required CLI tools..."
missing_tools=0

required_tools=("terraform" "kubectl" "helm" "doctl" "envsubst")

for tool in "${required_tools[@]}"; do
    if ! check_command "$tool"; then
        missing_tools=$((missing_tools + 1))
    fi
done

if [ $missing_tools -gt 0 ]; then
    echo ""
    echo "❌ $missing_tools required tool(s) are missing!"
    show_installation_instructions
    echo "Please install the missing tools and run this script again."
    exit 1
fi

echo "✅ All required CLI tools are installed!"
echo ""

# Load environment variables
if [ -f .env ]; then
    echo "📖 Loading environment variables from .env..."
    source .env
    export ARGOCD_ADMIN_PASSWORD_HASH
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

if [ -z "$ARGOCD_ADMIN_PASSWORD_HASH" ]; then
    echo "❌ ARGOCD_ADMIN_PASSWORD_HASH not set in .env file"
    exit 1
fi

echo "🔐 Authenticating with DigitalOcean..."
doctl auth init -t $DO_TOKEN

echo "📋 Checking available clusters..."
doctl kubernetes cluster list

echo "🏗️  Step 1: Deploying infrastructure with Terraform..."
cd terraform

# Deploy infrastructure
./terraform.sh init
if [ -n "$DO_PROJECT_ID" ]; then
    ./terraform.sh apply -var="do_project_id=$DO_PROJECT_ID" -auto-approve
else
    ./terraform.sh apply -auto-approve
fi

echo "⚙️  Step 2: Configuring kubectl context..."
cd ..
# Clean up any existing contexts for this cluster to avoid conflicts
kubectl config delete-context do-$CLUSTER_REGION-$CLUSTER_NAME 2>/dev/null || true
kubectl config delete-cluster do-$CLUSTER_REGION-$CLUSTER_NAME 2>/dev/null || true
# Force overwrite existing kubeconfig to avoid conflicts
doctl kubernetes cluster kubeconfig save $CLUSTER_NAME --set-current-context
kubectl config use-context do-$CLUSTER_REGION-$CLUSTER_NAME

echo "🎯 Step 3: Deploying ArgoCD..."
cd k8s/addons/argo-cd
helm dependency update

# Deploy ArgoCD with environment variables
envsubst < values.yaml | helm upgrade --install --create-namespace -n argocd argocd . -f -

echo "⏳ Waiting for ArgoCD to be ready..."
export KUBECONFIG=$(pwd)/../../../terraform/modules/kubernetes/kubeconfig.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo " Step 4: Deploying ArgoCD Apps..."
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
