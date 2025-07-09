resource "digitalocean_kubernetes_cluster" "kubernetes_cluster" {
  name       = var.cluster_name
  region     = var.cluster_region
  version    = var.cluster_version
  project_id = var.do_project_id != "" ? var.do_project_id : null

  node_pool {
    name       = var.node_pool_name
    size       = var.node_size
    node_count = var.node_count
    auto_scale = false
  }
}

# Save kubeconfig to a file
resource "local_file" "kubeconfig" {
  content  = digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].raw_config
  filename = "${path.module}/kubeconfig.yaml"
}
