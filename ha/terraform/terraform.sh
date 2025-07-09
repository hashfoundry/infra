#!/bin/bash

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
    echo "  brew install terraform"
    echo ""
    echo "🐧 For Ubuntu/Debian:"
    echo "  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
    echo "  echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com focal main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list"
    echo "  sudo apt update && sudo apt install terraform"
    echo ""
    echo "🪟 For Windows:"
    echo "  choco install terraform"
    echo "  # Or download from: https://www.terraform.io/downloads"
    echo ""
}

# Check required CLI tools
echo "🔍 Checking required CLI tools..."
missing_tools=0

required_tools=("terraform")

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

# Load environment variables from main .env file (one level up)
if [ -f ../.env ]; then
  export $(grep -v '^#' ../.env | xargs)
elif [ -f config/.env ]; then
  # Fallback to local config/.env for backward compatibility
  export $(grep -v '^#' config/.env | xargs)
else
  echo "Error: .env file not found (checked ../.env and config/.env)"
  exit 1
fi

# Export variables for Terraform
export TF_VAR_do_token=$DO_TOKEN
export TF_VAR_do_project_name=$DO_PROJECT_NAME
export TF_VAR_cluster_name=$CLUSTER_NAME
export TF_VAR_cluster_region=$CLUSTER_REGION
export TF_VAR_cluster_version=$CLUSTER_VERSION
export TF_VAR_node_pool_name=$NODE_POOL_NAME
export TF_VAR_node_size=$NODE_SIZE
export TF_VAR_node_count=$NODE_COUNT

# HA-specific variables
export TF_VAR_auto_scale_enabled=$AUTO_SCALE_ENABLED
export TF_VAR_min_nodes=$MIN_NODES
export TF_VAR_max_nodes=$MAX_NODES
export TF_VAR_enable_ha_control_plane=$ENABLE_HA_CONTROL_PLANE

# Load Balancer variables
export TF_VAR_create_global_lb=$CREATE_GLOBAL_LB
export TF_VAR_create_standard_lb=$CREATE_STANDARD_LB
export TF_VAR_origin_endpoint=$ORIGIN_ENDPOINT
export TF_VAR_custom_domain=$CUSTOM_DOMAIN
export TF_VAR_lb_name=$LB_NAME
export TF_VAR_create_k8s_service=$CREATE_K8S_SERVICE
export TF_VAR_k8s_service_name=$K8S_SERVICE_NAME
export TF_VAR_k8s_namespace=$K8S_NAMESPACE

# Run Terraform command
terraform $@
