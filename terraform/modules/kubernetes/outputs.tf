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

output "cluster_urn" {
  description = "URN of the Kubernetes cluster for project assignment"
  value       = digitalocean_kubernetes_cluster.kubernetes_cluster.urn
}
