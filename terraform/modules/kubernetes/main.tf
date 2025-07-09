# Data source to get project by name
data "digitalocean_projects" "existing" {}

# Local to get project ID by name
locals {
  project_id = [for p in data.digitalocean_projects.existing.projects : p.id if p.name == var.do_project_name][0]
}

resource "digitalocean_kubernetes_cluster" "kubernetes_cluster" {
  name    = var.cluster_name
  region  = var.cluster_region
  version = var.cluster_version

  node_pool {
    name       = var.node_pool_name
    size       = var.node_size
    node_count = var.node_count
    auto_scale = false
  }
}

# Assign cluster to project
resource "digitalocean_project_resources" "cluster_assignment" {
  project = local.project_id
  resources = [
    digitalocean_kubernetes_cluster.kubernetes_cluster.urn
  ]
}

# Save kubeconfig to a file
resource "local_file" "kubeconfig" {
  content  = digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].raw_config
  filename = "${path.module}/kubeconfig.yaml"
}
