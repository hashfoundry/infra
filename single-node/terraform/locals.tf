# Local values
locals {
  existing_project = [for p in data.digitalocean_projects.existing.projects : p if p.name == var.do_project_name]
  project_id = length(local.existing_project) > 0 ? local.existing_project[0].id : digitalocean_project.hashfoundry[0].id
}
