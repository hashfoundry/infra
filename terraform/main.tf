# Provider configuration
terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Variables
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "hashfoundry"
}

variable "cluster_region" {
  description = "Region where the Kubernetes cluster will be created"
  type        = string
  default     = "fra1"
}

variable "cluster_version" {
  description = "Version of Kubernetes to use for the cluster"
  type        = string
  default     = "latest"
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
  default     = "worker-pool"
}

variable "node_size" {
  description = "Size of the nodes in the node pool"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 1
}

# Module reference
module "kubernetes_cluster" {
  source = "./modules/kubernetes"

  # Pass variables to the module
  do_token        = var.do_token
  cluster_name    = var.cluster_name
  cluster_region  = var.cluster_region
  cluster_version = var.cluster_version
  node_pool_name  = var.node_pool_name
  node_size       = var.node_size
  node_count      = var.node_count
}

# Outputs
output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = module.kubernetes_cluster.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes cluster"
  value       = module.kubernetes_cluster.cluster_endpoint
}

output "cluster_status" {
  description = "Status of the Kubernetes cluster"
  value       = module.kubernetes_cluster.cluster_status
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = module.kubernetes_cluster.kubeconfig_path
}

output "node_pool" {
  description = "Node pool details"
  value       = module.kubernetes_cluster.node_pool
}
