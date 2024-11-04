variable "k8s_namespace" {
  description = "(Required) Kubernetes namespace in which resource will be deployed"
}

variable "environment" {
  description = "(Required) Deployment environment (e.g. test, prod...)"
}

variable "service_account" {
  description = "(Required) Existing service account with monitoring roles"
}

variable "prometheus_scraping_port" {
  default     = 9464
  description = "(Optional) Prometheus metrics scraping port"
}

variable "replica_count" {
  default     = 0
  description = "(Optional) The number of replicas for the opentelemetry collector pod. Default is 0."
}

variable "cpu" {
  default     = "500m"
  description = "(Optional) The maximum CPU resources to be allocated for the opentelemetry collector pod. Default is 500m."
}

variable "ram" {
  default     = "512Mi"
  description = "(Optional) The maximum RAM resources to be allocated for the opentelemetry collector pod. Default is '512Mi'."
}

variable "elastic_stack_enabled" {
  default     = true
  description = "(Required) Whether the elastic stack must be deployed"
}

variable "tempo_stack_enabled" {
  default     = true
  description = "(Required) Whether the tempo stack must be deployed"
}

variable "prometheus_stack_enabled" {
  default     = true
  description = "(Required) Whether the prometheus stack must be deployed"
}

variable "tempo_distributor_url" {
  description = "(Required) The URL of the Tempo distributor"
}

variable "loki_stack_enabled" {
  default     = true
  description = "(Required) Whether the loki stack must be deployed"
}

variable "loki_url" {
  description = "(Required) The URL of Loki"
}

variable "fleet_url" {
  description = "(Required) The URL of the fleet"
  default = ""
}