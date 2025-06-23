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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host                   = module.kubernetes_cluster.cluster_endpoint
  token                  = data.digitalocean_kubernetes_cluster.cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(data.digitalocean_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate)
}

# Data source to get the existing cluster details
data "digitalocean_kubernetes_cluster" "cluster" {
  name = var.cluster_name
  depends_on = [module.kubernetes_cluster]
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

# Load Balancer variables
variable "create_global_lb" {
  description = "Whether to create a global load balancer using DigitalOcean CDN"
  type        = bool
  default     = true
}

variable "create_standard_lb" {
  description = "Whether to create a standard load balancer without caching"
  type        = bool
  default     = true
}

variable "origin_endpoint" {
  description = "The origin endpoint for the CDN"
  type        = string
  default     = ""
}

variable "custom_domain" {
  description = "The custom domain for the CDN"
  type        = string
  default     = ""
}

variable "lb_name" {
  description = "The name of the load balancer"
  type        = string
  default     = "hashfoundry-lb"
}

variable "create_k8s_service" {
  description = "Whether to create a Kubernetes service for the load balancer"
  type        = bool
  default     = true
}

variable "k8s_service_name" {
  description = "The name of the Kubernetes service"
  type        = string
  default     = "hashfoundry-service"
}

variable "k8s_namespace" {
  description = "The namespace for the Kubernetes service"
  type        = string
  default     = "default"
}

variable "k8s_selector" {
  description = "The selector for the Kubernetes service"
  type        = map(string)
  default     = {
    app = "hashfoundry"
  }
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

  # Explicitly specify providers
  providers = {
    digitalocean = digitalocean
  }
}

# Load Balancer module
module "loadbalancer" {
  source = "./modules/loadbalancer"
  
  # Global Load Balancer (CDN) configuration
  create_global_lb = var.create_global_lb
  origin_endpoint  = coalesce(var.origin_endpoint, module.kubernetes_cluster.cluster_endpoint)
  custom_domain    = var.custom_domain
  
  # Standard Load Balancer configuration
  create_standard_lb = var.create_standard_lb
  lb_name            = var.lb_name
  region             = var.cluster_region
  
  # Kubernetes Service configuration
  create_k8s_service = var.create_k8s_service
  k8s_service_name   = var.k8s_service_name
  k8s_namespace      = var.k8s_namespace
  k8s_selector       = var.k8s_selector
  
  # Default values for optional parameters
  sticky_sessions_type = "none"
  redirect_http_to_https = true
  
  # Explicitly specify providers
  providers = {
    digitalocean = digitalocean
    kubernetes   = kubernetes
  }
  
  # Ensure the Kubernetes cluster is created first
  depends_on = [module.kubernetes_cluster]
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

# Load Balancer outputs
output "global_lb_endpoint" {
  description = "The endpoint of the global load balancer (CDN)"
  value       = module.loadbalancer.global_lb_endpoint
}

output "standard_lb_ip" {
  description = "The IP address of the standard load balancer"
  value       = module.loadbalancer.standard_lb_ip
}

output "k8s_service_name" {
  description = "The name of the Kubernetes service"
  value       = module.loadbalancer.k8s_service_name
}

output "k8s_service_load_balancer_ingress" {
  description = "The load balancer ingress of the Kubernetes service"
  value       = module.loadbalancer.k8s_service_load_balancer_ingress
}
