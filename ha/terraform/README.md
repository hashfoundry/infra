# Digital Ocean Kubernetes Cluster Terraform Configuration

This directory contains Terraform configuration to create a minimal Kubernetes cluster in Digital Ocean's Frankfurt region.

## Directory Structure

- `providers.tf` - Provider configurations (DigitalOcean, Kubernetes, Local)
- `variables.tf` - Input variables with descriptions and defaults
- `locals.tf` - Local values and computed data
- `project.tf` - DigitalOcean project management and resource assignment
- `kubernetes.tf` - Kubernetes cluster and related resources
- `outputs.tf` - Output values for cluster information
- `main.tf` - Documentation and entry point (actual resources are in other files)
- `terraform.sh` - Helper script to load environment variables and run Terraform commands

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [Digital Ocean API Token](https://cloud.digitalocean.com/account/api/tokens)

## Configuration

1. Create a `.env` file in the project root (one level up from terraform/) with your Digital Ocean API token:
   ```
   DO_TOKEN=your_digitalocean_api_token
   DO_PROJECT_NAME=hashfoundry
   CLUSTER_NAME=hashfoundry
   CLUSTER_REGION=fra1
   # ... other variables
   ```

2. You can customize other variables in the `.env` file if needed.

## Project Management

The Terraform configuration automatically manages DigitalOcean projects:

- **Project Creation**: If a project with the name specified in `DO_PROJECT_NAME` doesn't exist, it will be created automatically
- **Resource Assignment**: All infrastructure resources (Kubernetes cluster) are automatically assigned to the specified project
- **Project Reuse**: If a project with the specified name already exists, it will be used instead of creating a new one

## Usage

The `terraform.sh` script loads environment variables from the `.env` file and runs Terraform commands.

### Initialize Terraform

```bash
./terraform.sh init
```

### Plan the deployment

```bash
./terraform.sh plan
```

### Apply the configuration

```bash
./terraform.sh apply
```

### Destroy the infrastructure

```bash
./terraform.sh destroy
```

## Accessing the Kubernetes Cluster

After applying the Terraform configuration, a `kubeconfig.yaml` file will be created in the terraform directory. You can use this file to access the cluster with kubectl:

```bash
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes
```

You can also copy the kubeconfig to the standard location:

```bash
mkdir -p ~/.kube
cp kubeconfig.yaml ~/.kube/config
```

Or merge it with your existing kubeconfig:

```bash
KUBECONFIG=~/.kube/config:kubeconfig.yaml kubectl config view --flatten > ~/.kube/merged_config
mv ~/.kube/merged_config ~/.kube/config
```

## Outputs

The Terraform configuration outputs the following information:

- `project_id`: ID of the DigitalOcean project
- `cluster_id`: ID of the Kubernetes cluster
- `cluster_endpoint`: Endpoint of the Kubernetes cluster
- `cluster_status`: Status of the Kubernetes cluster
- `kubeconfig_path`: Path to the kubeconfig file
- `node_pool`: Details of the node pool (ID, name, size, node count)

## Common Kubernetes Operations

Once your cluster is created, you can perform various operations:

### View Cluster Information

```bash
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### Deploy a Sample Application

```bash
kubectl create deployment hello-node --image=k8s.gcr.io/echoserver:1.4
kubectl expose deployment hello-node --type=LoadBalancer --port=8080
kubectl get services hello-node
```

### Scale the Deployment

```bash
kubectl scale deployment hello-node --replicas=3
```

### Update the Cluster

If you need to update the cluster configuration, modify the variables in the `.env` file and run:

```bash
./terraform.sh apply
```

### Monitor the Cluster

```bash
kubectl top nodes
kubectl top pods --all-namespaces
```

### Install Kubernetes Dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl proxy
```

Then access the dashboard at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
