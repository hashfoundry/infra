module "kubernetes_cluster" {
  source = "./modules/kubernetes"

  # Pass variables to the module
  do_token        = var.do_token
  cluster_name    = var.cluster_name
  cluster_region  = var.cluster_region
  cluster_version = var.cluster_version
  node_pool_name  = var.node_pool_name
  node_size       = var.node_size
  node_count      = var.node_count
}
