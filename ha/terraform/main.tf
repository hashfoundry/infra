# HashFoundry Infrastructure
# This file serves as the main entry point for the Terraform configuration.
# The actual resources are organized in separate files by logical components:
#
# - providers.tf    : Provider configurations
# - variables.tf    : Input variables
# - locals.tf       : Local values and computed data
# - project.tf      : DigitalOcean project management
# - kubernetes.tf   : Kubernetes cluster and related resources
# - outputs.tf      : Output values
#
# This organization improves maintainability and makes it easier to
# understand the infrastructure components.
