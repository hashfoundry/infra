# Outputs
output "project_id" {
  description = "ID of the DigitalOcean project"
  value       = local.project_id
}

output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.kubernetes_cluster.id
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.kubernetes_cluster.endpoint
}

output "cluster_status" {
  description = "Status of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.kubernetes_cluster.status
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "node_pool" {
  description = "Node pool details"
  value = {
    id         = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].id
    name       = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].name
    size       = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].size
    node_count = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].node_count
  }
}

output "ha_status" {
  description = "High Availability status of the cluster"
  value = {
    node_count     = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].actual_node_count
    auto_scale     = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].auto_scale
    min_nodes      = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].min_nodes
    max_nodes      = digitalocean_kubernetes_cluster.kubernetes_cluster.node_pool[0].max_nodes
    ha_enabled     = digitalocean_kubernetes_cluster.kubernetes_cluster.ha
  }
}
