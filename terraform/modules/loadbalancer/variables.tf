# Variables for the Load Balancer module

# Global Load Balancer (CDN) variables
variable "create_global_lb" {
  description = "Whether to create a global load balancer using DigitalOcean CDN"
  type        = bool
  default     = false
}

variable "origin_endpoint" {
  description = "The origin endpoint for the CDN (e.g., 'example.com' or an IP address)"
  type        = string
  default     = ""
}

variable "cdn_ttl" {
  description = "The TTL (Time To Live) for cached content in seconds"
  type        = number
  default     = 3600
}

variable "custom_domain" {
  description = "The custom domain for the CDN"
  type        = string
  default     = ""
}

variable "certificate_name" {
  description = "The name of the certificate to use for the CDN"
  type        = string
  default     = ""
}

# Standard Load Balancer variables
variable "create_standard_lb" {
  description = "Whether to create a standard load balancer"
  type        = bool
  default     = false
}

variable "lb_name" {
  description = "The name of the load balancer"
  type        = string
  default     = "k8s-loadbalancer"
}

variable "region" {
  description = "The region where the load balancer will be created"
  type        = string
  default     = "fra1"
}

variable "droplet_tag" {
  description = "The tag to use for droplet assignment to the load balancer"
  type        = string
  default     = ""
}

variable "lb_size" {
  description = "The size of the load balancer (lb-small, lb-medium, or lb-large)"
  type        = string
  default     = "lb-small"
}

variable "lb_algorithm" {
  description = "The load balancing algorithm (round_robin, least_connections, or random)"
  type        = string
  default     = "round_robin"
}

variable "certificate_id" {
  description = "The ID of the certificate to use for the load balancer"
  type        = string
  default     = ""
}

variable "sticky_sessions_type" {
  description = "The type of sticky sessions (cookies or none)"
  type        = string
  default     = "none"
}

variable "sticky_sessions_cookie_name" {
  description = "The name of the cookie for sticky sessions"
  type        = string
  default     = ""
}

variable "sticky_sessions_cookie_ttl" {
  description = "The TTL for the sticky session cookie in seconds"
  type        = number
  default     = 3600
}

variable "redirect_http_to_https" {
  description = "Whether to redirect HTTP traffic to HTTPS"
  type        = bool
  default     = true
}

variable "enable_proxy_protocol" {
  description = "Whether to enable proxy protocol"
  type        = bool
  default     = false
}

variable "enable_backend_keepalive" {
  description = "Whether to enable backend keepalive"
  type        = bool
  default     = false
}

variable "disable_lets_encrypt_dns_records" {
  description = "Whether to disable Let's Encrypt DNS records"
  type        = bool
  default     = false
}

variable "vpc_uuid" {
  description = "The UUID of the VPC for the load balancer"
  type        = string
  default     = ""
}

variable "project_id" {
  description = "The ID of the project for the load balancer"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the load balancer"
  type        = list(string)
  default     = []
}

# Kubernetes Service variables
variable "create_k8s_service" {
  description = "Whether to create a Kubernetes service for the load balancer"
  type        = bool
  default     = false
}

variable "k8s_service_name" {
  description = "The name of the Kubernetes service"
  type        = string
  default     = "loadbalancer"
}

variable "k8s_namespace" {
  description = "The namespace for the Kubernetes service"
  type        = string
  default     = "default"
}

variable "k8s_selector" {
  description = "The selector for the Kubernetes service"
  type        = map(string)
  default     = {}
}

variable "k8s_target_port" {
  description = "The target port for the Kubernetes service"
  type        = number
  default     = 80
}
