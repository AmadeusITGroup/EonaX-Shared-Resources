variable "participant" {
  type = object({
    name = string,
    vc   = list(any)
  })
}

# POSTGRES
variable "postgres_host" {}
variable "postgres_credentials_secret_name" {}

# FEDERATED CATALOG
variable "connector_repo" {}
variable "connector_chart_name" {}
variable "connector_version" {}

# IDENTITY HUB
variable "identityhub_repo" {}
variable "identityhub_chart_name" {}
variable "identityhub_version" {}

# DOCKER PULL
variable "helm_chart_repo" {}
variable "docker_image_pull_secret_name" {}