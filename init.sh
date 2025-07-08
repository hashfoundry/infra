#!/bin/bash

# HashFoundry Infrastructure Initialization Script

set -e

echo "🚀 Initializing HashFoundry Infrastructure..."

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
