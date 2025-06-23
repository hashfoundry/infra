# Outputs for the Load Balancer module

# Global Load Balancer (CDN) outputs
output "global_lb_id" {
  description = "The ID of the global load balancer (CDN)"
  value       = var.create_global_lb ? digitalocean_cdn.global_lb[0].id : null
}

output "global_lb_endpoint" {
  description = "The endpoint of the global load balancer (CDN)"
  value       = var.create_global_lb ? digitalocean_cdn.global_lb[0].endpoint : null
}

output "global_lb_created_at" {
  description = "The creation timestamp of the global load balancer (CDN)"
  value       = var.create_global_lb ? digitalocean_cdn.global_lb[0].created_at : null
}

output "global_lb_ttl" {
  description = "The TTL of the global load balancer (CDN)"
  value       = var.create_global_lb ? digitalocean_cdn.global_lb[0].ttl : null
}

# Standard Load Balancer outputs
output "standard_lb_id" {
  description = "The ID of the standard load balancer"
  value       = var.create_standard_lb && length(digitalocean_loadbalancer.standard_lb) > 0 ? digitalocean_loadbalancer.standard_lb[0].id : null
}

output "standard_lb_ip" {
  description = "The IP address of the standard load balancer"
  value       = var.create_standard_lb && length(digitalocean_loadbalancer.standard_lb) > 0 ? digitalocean_loadbalancer.standard_lb[0].ip : null
}

output "standard_lb_status" {
  description = "The status of the standard load balancer"
  value       = var.create_standard_lb && length(digitalocean_loadbalancer.standard_lb) > 0 ? digitalocean_loadbalancer.standard_lb[0].status : null
}

output "standard_lb_forwarding_rules" {
  description = "The forwarding rules of the standard load balancer"
  value       = var.create_standard_lb && length(digitalocean_loadbalancer.standard_lb) > 0 ? digitalocean_loadbalancer.standard_lb[0].forwarding_rule : null
}

# Kubernetes Service outputs
output "k8s_service_name" {
  description = "The name of the Kubernetes service"
  value       = var.create_k8s_service ? kubernetes_service.lb_service[0].metadata[0].name : null
}

output "k8s_service_namespace" {
  description = "The namespace of the Kubernetes service"
  value       = var.create_k8s_service ? kubernetes_service.lb_service[0].metadata[0].namespace : null
}

output "k8s_service_cluster_ip" {
  description = "The cluster IP of the Kubernetes service"
  value       = var.create_k8s_service ? kubernetes_service.lb_service[0].spec[0].cluster_ip : null
}

output "k8s_service_load_balancer_ingress" {
  description = "The load balancer ingress of the Kubernetes service"
  value       = var.create_k8s_service ? kubernetes_service.lb_service[0].status[0].load_balancer[0].ingress : null
}
