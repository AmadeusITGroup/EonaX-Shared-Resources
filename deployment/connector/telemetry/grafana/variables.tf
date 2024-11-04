variable "participants" {
  description = "(Required) Dataspace participants"

  type = list(object({
    name    = string
    db_name = string
  }))

}
variable "k8s_namespace" {
  description = "(Required) Kubernetes namespace in which resource will be deployed"
}

variable "environment" {
  description = "(Required) Deployment environment (e.g. test, prod...)"
}

variable "service_account" {
  description = "(Required) Existing service account with monitoring roles"
}

variable "artifactory_url" {
  description = "(Required) Artifactory URL"
  default     = "docker-production-agp.nce.dockerhub.rnd.amadeus.net"
}

variable "prometheus_scraping_port" {
  default     = 9464
  description = "(Optional) Prometheus metrics scraping port"
}

variable "grafana_version" {
  description = "(Required) The version of grafana to be deployed."
}

variable "storage_size" {
  default     = "50Mi"
  description = "(Optional) The storage size for the elasticsearch pod. Default is '2Gi'."
}

variable "replica_count" {
  default     = 0
  description = "(Optional) The number of replicas for the grafana pod. Default is 0."
}

variable "cpu" {
  default     = "200m"
  description = "(Optional) The maximum CPU resources to be allocated for the grafana pod. Default is 200m."
}

variable "ram" {
  default     = "512Mi"
  description = "(Optional) The maximum RAM resources to be allocated for the grafana pod. Default is '512Mi'."
}

variable "prometheus_url" {
  description = "(Required) The URL of the Prometheus instance"
}

variable "elasticsearch_url" {
  description = "(Required) The URL of the Elasticsearch instance"
}

variable "tempo_query_url" {
  description = "(Required) The URL for querying Tempo"
}

variable "loki_url" {
  description = "(Required) The URL for querying Loki"
}