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
  default     = "1.31.1-do.4"
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
