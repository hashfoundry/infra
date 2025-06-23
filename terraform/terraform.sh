#!/bin/bash

# Load environment variables from config/.env file
if [ -f config/.env ]; then
  export $(grep -v '^#' config/.env | xargs)
else
  echo "Error: config/.env file not found"
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
