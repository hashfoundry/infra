#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found"
  exit 1
fi

# Export variables for Terraform
export TF_VAR_do_token=$DO_TOKEN
export TF_VAR_cluster_name=$CLUSTER_NAME
export TF_VAR_cluster_region=$CLUSTER_REGION
export TF_VAR_cluster_version=$CLUSTER_VERSION
export TF_VAR_node_pool_name=$NODE_POOL_NAME
export TF_VAR_node_size=$NODE_SIZE
export TF_VAR_node_count=$NODE_COUNT

# Run Terraform command
terraform $@
