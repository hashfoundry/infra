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
