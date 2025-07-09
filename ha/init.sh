#!/bin/bash

# HashFoundry Infrastructure Initialization Script

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
    echo "  # envsubst is part of gettext package, htpasswd is part of httpd"
    echo "  brew install gettext httpd"
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
    echo "  # envsubst (gettext-base) and htpasswd (apache2-utils)"
    echo "  sudo apt-get install gettext-base apache2-utils"
    echo ""
    echo "🪟 For Windows:"
    echo "  # Use Chocolatey or download binaries manually"
    echo "  choco install terraform kubernetes-cli kubernetes-helm"
    echo "  # For doctl and envsubst, download from official releases"
    echo ""
}

echo "🚀 Initializing HashFoundry Infrastructure..."

# Check required CLI tools
echo "🔍 Checking required CLI tools..."
missing_tools=0

# Note: envsubst check is basic as it might be part of different packages
required_tools=("terraform" "kubectl" "helm" "doctl" "envsubst" "htpasswd")

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

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📋 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ .env file created. Please edit it with your actual values."
else
    echo "⚠️  .env file already exists. Skipping creation."
fi


# Load environment variables
if [ -f .env ]; then
    echo "📖 Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

echo ""
echo "📝 Next steps:"
echo "1. Edit .env file with your actual values (especially DO_TOKEN)"
echo "2. Run: ./deploy.sh"
echo ""
echo "🔐 ArgoCD admin password will be set to: ${ARGOCD_ADMIN_PASSWORD:-hashfoundry123}"
echo ""
