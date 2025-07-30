#!/bin/bash
"""
Upload ML Model to DigitalOcean Spaces
This script uploads the trained Iris classifier model to DigitalOcean Spaces (S3-compatible storage)
"""

set -e

# Configuration
BUCKET_NAME="hashfoundry-ml-models"
MODEL_PATH="iris-classifier/v1"
LOCAL_MODEL_DIR="../iris-classifier"
REGION="nyc3"  # New York region

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

# Function to check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v doctl &> /dev/null; then
        print_error "doctl is not installed. Please install DigitalOcean CLI tool."
        echo "Installation: https://docs.digitalocean.com/reference/doctl/how-to/install/"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "aws CLI is not installed. Please install AWS CLI for S3 operations."
        echo "Installation: pip install awscli"
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Function to check authentication
check_auth() {
    print_status "Checking DigitalOcean authentication..."
    
    if ! doctl auth list &> /dev/null; then
        print_error "DigitalOcean authentication not configured."
        echo "Please run: doctl auth init"
        exit 1
    fi
    
    print_success "DigitalOcean authentication verified"
}

# Function to create bucket if it doesn't exist
create_bucket() {
    print_status "Checking if bucket '$BUCKET_NAME' exists..."
    
    # Try to list bucket contents to check if it exists
    if aws s3 ls "s3://$BUCKET_NAME" --endpoint-url "https://$REGION.digitaloceanspaces.com" --profile digitalocean &> /dev/null; then
        print_success "Bucket '$BUCKET_NAME' already exists"
    else
        print_status "Creating bucket '$BUCKET_NAME'..."
        aws s3 mb "s3://$BUCKET_NAME" --endpoint-url "https://$REGION.digitaloceanspaces.com" --profile digitalocean
        print_success "Bucket '$BUCKET_NAME' created successfully"
    fi
}

# Function to configure AWS CLI for DigitalOcean Spaces
configure_aws_cli() {
    print_status "Configuring AWS CLI for DigitalOcean Spaces..."
    
    # Get DigitalOcean Spaces credentials
    if [[ -z "$DO_SPACES_ACCESS_KEY" ]] || [[ -z "$DO_SPACES_SECRET_KEY" ]]; then
        print_error "DigitalOcean Spaces credentials not found in environment variables."
        echo "Please set DO_SPACES_ACCESS_KEY and DO_SPACES_SECRET_KEY"
        echo "You can create these in the DigitalOcean control panel under API > Spaces Keys"
        exit 1
    fi
    
    # Configure AWS CLI profile for DigitalOcean Spaces
    aws configure set aws_access_key_id "$DO_SPACES_ACCESS_KEY" --profile digitalocean
    aws configure set aws_secret_access_key "$DO_SPACES_SECRET_KEY" --profile digitalocean
    aws configure set region "$REGION" --profile digitalocean
    
    print_success "AWS CLI configured for DigitalOcean Spaces"
}

# Function to upload model files
upload_model() {
    print_status "Uploading model files to DigitalOcean Spaces..."
    
    # Check if local model files exist
    if [[ ! -f "$LOCAL_MODEL_DIR/model.pkl" ]]; then
        print_error "Model file not found: $LOCAL_MODEL_DIR/model.pkl"
        echo "Please run the training script first: python3 train_model.py"
        exit 1
    fi
    
    if [[ ! -f "$LOCAL_MODEL_DIR/metadata.json" ]]; then
        print_error "Metadata file not found: $LOCAL_MODEL_DIR/metadata.json"
        echo "Please run the training script first: python3 train_model.py"
        exit 1
    fi
    
    # Upload model.pkl
    print_status "Uploading model.pkl..."
    aws s3 cp "$LOCAL_MODEL_DIR/model.pkl" \
        "s3://$BUCKET_NAME/$MODEL_PATH/model.pkl" \
        --endpoint-url "https://$REGION.digitaloceanspaces.com" \
        --profile digitalocean
    
    # Upload metadata.json
    print_status "Uploading metadata.json..."
    aws s3 cp "$LOCAL_MODEL_DIR/metadata.json" \
        "s3://$BUCKET_NAME/$MODEL_PATH/metadata.json" \
        --endpoint-url "https://$REGION.digitaloceanspaces.com" \
        --profile digitalocean
    
    print_success "Model files uploaded successfully"
}

# Function to verify upload
verify_upload() {
    print_status "Verifying uploaded files..."
    
    # List files in the bucket
    print_status "Files in bucket '$BUCKET_NAME/$MODEL_PATH':"
    aws s3 ls "s3://$BUCKET_NAME/$MODEL_PATH/" \
        --endpoint-url "https://$REGION.digitaloceanspaces.com" \
        --profile digitalocean
    
    # Check file sizes
    model_size=$(aws s3 ls "s3://$BUCKET_NAME/$MODEL_PATH/model.pkl" \
        --endpoint-url "https://$REGION.digitaloceanspaces.com" \
        --profile digitalocean | awk '{print $3}')
    
    metadata_size=$(aws s3 ls "s3://$BUCKET_NAME/$MODEL_PATH/metadata.json" \
        --endpoint-url "https://$REGION.digitaloceanspaces.com" \
        --profile digitalocean | awk '{print $3}')
    
    print_success "model.pkl size: $model_size bytes"
    print_success "metadata.json size: $metadata_size bytes"
}

# Function to set public access (optional)
set_public_access() {
    print_status "Setting public read access for model files..."
    
    # Make model.pkl publicly readable
    aws s3api put-object-acl \
        --bucket "$BUCKET_NAME" \
        --key "$MODEL_PATH/model.pkl" \
        --acl public-read \
        --endpoint-url "https://$REGION.digitaloceanspaces.com" \
        --profile digitalocean
    
    # Make metadata.json publicly readable
    aws s3api put-object-acl \
        --bucket "$BUCKET_NAME" \
        --key "$MODEL_PATH/metadata.json" \
        --acl public-read \
        --endpoint-url "https://$REGION.digitaloceanspaces.com" \
        --profile digitalocean
    
    print_success "Public read access configured"
    
    # Print public URLs
    echo ""
    print_success "Public URLs:"
    echo "Model: https://$BUCKET_NAME.$REGION.digitaloceanspaces.com/$MODEL_PATH/model.pkl"
    echo "Metadata: https://$BUCKET_NAME.$REGION.digitaloceanspaces.com/$MODEL_PATH/metadata.json"
}

# Function to create .env template
create_env_template() {
    print_status "Creating .env template..."
    
    cat > "../.env.example" << EOF
# DigitalOcean Spaces Configuration
DO_SPACES_ACCESS_KEY=your_access_key_here
DO_SPACES_SECRET_KEY=your_secret_key_here
DO_SPACES_BUCKET=hashfoundry-ml-models
DO_SPACES_REGION=fra1
DO_SPACES_ENDPOINT=https://fra1.digitaloceanspaces.com

# Model Configuration
MODEL_NAME=iris-classifier
MODEL_VERSION=v1
MODEL_PATH=iris-classifier/v1
EOF
    
    print_success ".env.example created"
    print_warning "Please copy .env.example to .env and fill in your credentials"
}

# Main function
main() {
    echo "🚀 DigitalOcean Spaces Model Upload Script"
    echo "=========================================="
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    # Check dependencies
    check_dependencies
    
    # Check authentication
    check_auth
    
    # Create .env template if it doesn't exist
    if [[ ! -f "../.env.example" ]]; then
        create_env_template
    fi
    
    # Load environment variables if .env exists
    if [[ -f "../.env" ]]; then
        print_status "Loading environment variables from .env file..."
        source "../.env"
    fi
    
    # Configure AWS CLI
    configure_aws_cli
    
    # Create bucket
    create_bucket
    
    # Upload model
    upload_model
    
    # Verify upload
    verify_upload
    
    # Set public access (optional)
    read -p "Do you want to make the model files publicly accessible? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        set_public_access
    fi
    
    echo ""
    print_success "🎉 Model upload completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Verify the files are accessible in DigitalOcean Spaces console"
    echo "2. Configure KServe InferenceService to use the uploaded model"
    echo "3. Test the model deployment"
}

# Run main function
main "$@"
