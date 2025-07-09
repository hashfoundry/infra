# Data source to check if project exists
data "digitalocean_projects" "existing" {}

# Create project if it doesn't exist
resource "digitalocean_project" "hashfoundry" {
  count = length([for p in data.digitalocean_projects.existing.projects : p if p.name == var.do_project_name]) == 0 ? 1 : 0

  name        = var.do_project_name
  description = "HashFoundry infrastructure project managed by Terraform"
  purpose     = "Web Application"
  environment = "Production"
}

# Assign cluster to project
resource "digitalocean_project_resources" "cluster_assignment" {
  project = local.project_id
  resources = [
    "do:kubernetes:${digitalocean_kubernetes_cluster.kubernetes_cluster.id}"
  ]

  depends_on = [digitalocean_kubernetes_cluster.kubernetes_cluster, digitalocean_project.hashfoundry]

  lifecycle {
    ignore_changes = [resources]
  }
}
