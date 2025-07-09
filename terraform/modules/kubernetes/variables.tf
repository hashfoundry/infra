variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "cluster_region" {
  description = "Region where the Kubernetes cluster will be created"
  type        = string
}

variable "cluster_version" {
  description = "Version of Kubernetes to use for the cluster"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
}

variable "node_size" {
  description = "Size of the nodes in the node pool"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
}

variable "do_project_id" {
  description = "DigitalOcean Project ID"
  type        = string
  default     = ""
}
