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

# Data source to check if project exists
data "digitalocean_projects" "existing" {}

# Create project if it doesn't exist
resource "digitalocean_project" "hashfoundry" {
  count = length([for p in data.digitalocean_projects.existing.projects : p if p.name == var.do_project_name]) == 0 ? 1 : 0

  name        = var.do_project_name
  description = "HashFoundry infrastructure project managed by Terraform"
  purpose     = "Web Application"
  environment = "Production"
}

# Local to get project ID (either existing or newly created)
locals {
  existing_project = [for p in data.digitalocean_projects.existing.projects : p if p.name == var.do_project_name]
  project_id = length(local.existing_project) > 0 ? local.existing_project[0].id : digitalocean_project.hashfoundry[0].id
}

# Data source to get the existing cluster details
data "digitalocean_kubernetes_cluster" "cluster" {
  name       = var.cluster_name
  depends_on = [module.kubernetes_cluster]
}

# Variables
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "do_project_name" {
  description = "DigitalOcean Project Name"
  type        = string
  default     = "hashfoundry"
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

  # Explicitly specify providers
  providers = {
    digitalocean = digitalocean
  }

  # Ensure project is created before cluster
  depends_on = [digitalocean_project.hashfoundry]
}

# Assign cluster to project
resource "digitalocean_project_resources" "cluster_assignment" {
  project = local.project_id
  resources = [
    "do:kubernetes:${module.kubernetes_cluster.cluster_id}"
  ]

  depends_on = [module.kubernetes_cluster, digitalocean_project.hashfoundry]

  lifecycle {
    ignore_changes = [resources]
  }
}


# Outputs
output "project_id" {
  description = "ID of the DigitalOcean project"
  value       = local.project_id
}

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
