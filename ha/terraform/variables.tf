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
  default     = "1.31.9-do.1"
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
  default     = 3
}

variable "auto_scale_enabled" {
  description = "Enable auto-scaling for the node pool"
  type        = bool
  default     = true
}

variable "min_nodes" {
  description = "Minimum number of nodes in the auto-scaling node pool"
  type        = number
  default     = 3
}

variable "max_nodes" {
  description = "Maximum number of nodes in the auto-scaling node pool"
  type        = number
  default     = 6
}

variable "enable_ha_control_plane" {
  description = "Enable HA control plane (managed by DigitalOcean)"
  type        = bool
  default     = true
}
