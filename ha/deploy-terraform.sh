#!/bin/bash

# HashFoundry Terraform Infrastructure Deployment Script

set -e

# Load common functions
source "$(dirname "$0")/common-functions.sh"

echo "🚀 Deploying HashFoundry Terraform Infrastructure..."

# Check required CLI tools for Terraform deployment
check_cli_tools "terraform" "doctl"

# Load and validate environment variables
load_and_validate_env

# Authenticate with DigitalOcean
authenticate_digitalocean

echo "🏗️  Step 1: Deploying infrastructure with Terraform..."
cd terraform

# Deploy infrastructure
./terraform.sh init
if [ -n "$DO_PROJECT_NAME" ]; then
    ./terraform.sh apply -var="do_project_name=$DO_PROJECT_NAME" -auto-approve
else
    ./terraform.sh apply -auto-approve
fi
