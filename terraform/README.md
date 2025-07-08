# Digital Ocean Kubernetes Cluster Terraform Configuration

This directory contains Terraform configuration to create a minimal Kubernetes cluster in Digital Ocean's Frankfurt region.

## Directory Structure

- `modules/` - Reusable Terraform modules
  - `kubernetes/` - Kubernetes cluster module with its own variables, outputs, and main configuration
  - `loadbalancer/` - Load balancer module for creating global and standard load balancers
- `main.tf` - Single configuration file that includes all provider settings, variables, module references, and outputs
- `terraform.sh` - Helper script to load environment variables and run Terraform commands

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [Digital Ocean API Token](https://cloud.digitalocean.com/account/api/tokens)

## Configuration

1. Create a `.env` file in the project root (one level up from terraform/) with your Digital Ocean API token:
   ```
   DO_TOKEN=your_digitalocean_api_token
   CLUSTER_NAME=hashfoundry
   CLUSTER_REGION=fra1
   # ... other variables
   ```

2. You can customize other variables in the `.env` file if needed, including load balancer configurations.

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

After applying the Terraform configuration, a `kubeconfig.yaml` file will be created in the `modules/kubernetes` directory. You can use this file to access the cluster with kubectl:

```bash
export KUBECONFIG=$(pwd)/modules/kubernetes/kubeconfig.yaml
kubectl get nodes
```

You can also copy the kubeconfig to the standard location:

```bash
mkdir -p ~/.kube
cp modules/kubernetes/kubeconfig.yaml ~/.kube/config
```

Or merge it with your existing kubeconfig:

```bash
KUBECONFIG=~/.kube/config:modules/kubernetes/kubeconfig.yaml kubectl config view --flatten > ~/.kube/merged_config
mv ~/.kube/merged_config ~/.kube/config
```

## Outputs

The Terraform configuration outputs the following information:

- `cluster_id`: ID of the Kubernetes cluster
- `cluster_endpoint`: Endpoint of the Kubernetes cluster
- `cluster_status`: Status of the Kubernetes cluster
- `kubeconfig_path`: Path to the kubeconfig file
- `node_pool`: Details of the node pool (ID, name, size, node count)
- `standard_lb_ip`: IP address of the standard load balancer
- `global_lb_endpoint`: Endpoint of the global load balancer (CDN) if enabled
- `k8s_service_name`: Name of the Kubernetes service
- `k8s_service_load_balancer_ingress`: Load balancer ingress details for the Kubernetes service

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

## Load Balancer Configuration

This Terraform configuration includes two types of load balancers:

1. **Global Load Balancer**: Uses DigitalOcean's CDN to provide global content delivery with caching capabilities.
2. **Standard Load Balancer**: A regular load balancer without caching, suitable for dynamic content.

### Global Load Balancer

The global load balancer uses DigitalOcean's CDN service to distribute content globally with edge caching. This is ideal for static content like images, CSS, and JavaScript files.

To configure the global load balancer, set the following variables in your `.env` file:

```
CREATE_GLOBAL_LB=true
ORIGIN_ENDPOINT=your_origin_endpoint  # Optional, defaults to cluster endpoint
```

### Standard Load Balancer

The standard load balancer is a regular DigitalOcean load balancer without caching. This is suitable for dynamic content and API endpoints.

To configure the standard load balancer, set the following variables in your `.env` file:

```
CREATE_STANDARD_LB=true
LB_NAME=your_lb_name
```

### Kubernetes Service

The configuration also includes a Kubernetes service that can be used to expose your applications through the load balancers.

To configure the Kubernetes service, set the following variables in your `.env` file:

```
CREATE_K8S_SERVICE=true
K8S_SERVICE_NAME=your_service_name
K8S_NAMESPACE=your_namespace
```

### Accessing Your Applications

Once the load balancers are created, you can access your applications using:

- Global Load Balancer: Use the `global_lb_endpoint` output
- Standard Load Balancer: Use the `standard_lb_ip` output

For example:

```bash
# Get the global load balancer endpoint
./terraform.sh output global_lb_endpoint

# Get the standard load balancer IP
./terraform.sh output standard_lb_ip
```
