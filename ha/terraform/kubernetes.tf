# Data source to get the existing cluster details
data "digitalocean_kubernetes_cluster" "cluster" {
  name       = var.cluster_name
  depends_on = [digitalocean_kubernetes_cluster.kubernetes_cluster]
}

# Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "kubernetes_cluster" {
  name    = var.cluster_name
  region  = var.cluster_region
  version = var.cluster_version

  node_pool {
    name       = var.node_pool_name
    size       = var.node_size
    node_count = var.node_count
    auto_scale = var.auto_scale_enabled
    min_nodes  = var.auto_scale_enabled ? var.min_nodes : null
    max_nodes  = var.auto_scale_enabled ? var.max_nodes : null
    
    # Tags for HA identification
    tags = ["ha", "production"]
  }

  depends_on = [digitalocean_project.hashfoundry]
}

# Save kubeconfig to a file
resource "local_file" "kubeconfig" {
  content  = digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].raw_config
  filename = "${path.module}/kubeconfig.yaml"
}
