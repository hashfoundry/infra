# Digital Ocean Load Balancer Module
# This module creates two types of load balancers:
# 1. Global load balancer (using DigitalOcean's CDN)
# 2. Standard load balancer without caching

# Global Load Balancer using DigitalOcean CDN
# Note: For DigitalOcean CDN, the origin must be a valid domain or a Spaces bucket
# The Kubernetes cluster endpoint is not a valid origin for the CDN
resource "digitalocean_cdn" "global_lb" {
  count       = var.create_global_lb && var.custom_domain != "" ? 1 : 0
  origin      = var.custom_domain
  ttl         = var.cdn_ttl
  certificate_name = var.certificate_name
}

# Standard Load Balancer without caching
resource "digitalocean_loadbalancer" "standard_lb" {
  count       = var.create_standard_lb ? 1 : 0
  name        = var.lb_name
  region      = var.region
  size        = var.lb_size

  # Forward HTTP traffic to the Kubernetes nodes
  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"
    target_port     = 30000 # This should match your Kubernetes service NodePort
    target_protocol = "http"
  }

  # Forward HTTPS traffic to the Kubernetes nodes (only if certificate_name is provided)
  dynamic "forwarding_rule" {
    for_each = var.certificate_name != "" ? [1] : []
    content {
      entry_port     = 443
      entry_protocol = "https"
      target_port     = 30001 # This should match your Kubernetes service NodePort for HTTPS
      target_protocol = "http"
      certificate_name = var.certificate_name
    }
  }

  # Health check configuration
  healthcheck {
    port     = 30000 # This should match your Kubernetes service NodePort
    protocol = "http"
    path     = "/health"
  }

  # Sticky sessions configuration (only if type is not "none")
  dynamic "sticky_sessions" {
    for_each = var.sticky_sessions_type != "none" ? [1] : []
    content {
      type               = var.sticky_sessions_type
      cookie_name        = var.sticky_sessions_type == "cookies" ? coalesce(var.sticky_sessions_cookie_name, "DO-LB-COOKIE") : null
      cookie_ttl_seconds = var.sticky_sessions_type == "cookies" ? var.sticky_sessions_cookie_ttl : null
    }
  }

  # Redirect HTTP to HTTPS (only if certificate_name is provided)
  redirect_http_to_https = var.certificate_name != "" ? var.redirect_http_to_https : false

  # Enable proxy protocol
  enable_proxy_protocol = var.enable_proxy_protocol

  # Enable backend keepalive
  enable_backend_keepalive = var.enable_backend_keepalive

  # Disable lets encrypt DNS records
  disable_lets_encrypt_dns_records = var.disable_lets_encrypt_dns_records

  # Project ID
  project_id = var.project_id
}

# Kubernetes Service for the Load Balancer
resource "kubernetes_service" "lb_service" {
  count = var.create_k8s_service ? 1 : 0
  
  metadata {
    name = var.k8s_service_name
    namespace = var.k8s_namespace
    annotations = {
      "service.beta.kubernetes.io/do-loadbalancer-protocol" = "http"
      "service.beta.kubernetes.io/do-loadbalancer-algorithm" = var.lb_algorithm
      "service.beta.kubernetes.io/do-loadbalancer-tls-ports" = var.certificate_name != "" ? "443" : null
      "service.beta.kubernetes.io/do-loadbalancer-certificate-name" = var.certificate_name
      "service.beta.kubernetes.io/do-loadbalancer-redirect-http-to-https" = var.certificate_name != "" && var.redirect_http_to_https ? "true" : "false"
      "service.beta.kubernetes.io/do-loadbalancer-sticky-sessions-type" = var.sticky_sessions_type
      "service.beta.kubernetes.io/do-loadbalancer-sticky-sessions-cookie-name" = var.sticky_sessions_type == "cookies" ? coalesce(var.sticky_sessions_cookie_name, "DO-LB-COOKIE") : null
      "service.beta.kubernetes.io/do-loadbalancer-sticky-sessions-cookie-ttl" = var.sticky_sessions_type == "cookies" ? tostring(var.sticky_sessions_cookie_ttl) : null
      "service.beta.kubernetes.io/do-loadbalancer-disable-lets-encrypt-dns-records" = var.disable_lets_encrypt_dns_records ? "true" : "false"
    }
  }
  
  spec {
    selector = var.k8s_selector
    
    port {
      name        = "http"
      port        = 80
      target_port = var.k8s_target_port
    }
    
    port {
      name        = "https"
      port        = 443
      target_port = var.k8s_target_port
    }
    
    type = "LoadBalancer"
  }
}
