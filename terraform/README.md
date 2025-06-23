# Digital Ocean Kubernetes Cluster Terraform Configuration

This directory contains Terraform configuration to create a minimal Kubernetes cluster in Digital Ocean's Frankfurt region.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [Digital Ocean API Token](https://cloud.digitalocean.com/account/api/tokens)

## Configuration

1. Copy `.env.example` to `.env` if you haven't already:
   ```
   cp .env.example .env
   ```

2. Edit the `.env` file and set your Digital Ocean API token:
   ```
   DO_TOKEN=your_digitalocean_api_token
   ```

3. You can also customize other variables in the `.env` file if needed.

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

## Outputs

The Terraform configuration outputs the following information:

- `cluster_id`: ID of the Kubernetes cluster
- `cluster_endpoint`: Endpoint of the Kubernetes cluster
- `cluster_status`: Status of the Kubernetes cluster
- `kubeconfig_path`: Path to the kubeconfig file
- `node_pool`: Details of the node pool (ID, name, size, node count)
