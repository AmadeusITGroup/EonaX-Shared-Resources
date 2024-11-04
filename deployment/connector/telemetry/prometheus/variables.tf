variable "k8s_namespace" {
  description = "(Required) Kubernetes namespace in which resource will be deployed"
}

variable "environment" {
  description = "(Required) Deployment environment (e.g. test, prod...)"
}

variable "mandatory_labels" {
  type        = any
  description = "(Required) Mandatory Pod labels"
  default = []
}

variable "service_account" {
  description = "(Required) Existing service account with monitoring roles"
}

variable "prometheus_version" {
  description = "(Required) The version of Prometheus to be deployed."
}

variable "prometheus_scraping_port" {
  default     = 9464
  description = "(Optional) Prometheus metrics scraping port"
}

variable "artifactory_url" {
  description = "(Optional) Artifactory URL"
  default = ""
}

variable "replica_count" {
  default     = 1
  description = "(Optional) The number of replicas for the prometheus pod. Default is 0."
}

variable "cpu" {
  default     = "200m"
  description = "(Optional) The maximum CPU resources to be allocated for the prometheus pod. Default is 0.5."
}

variable "ram" {
  default     = "512Mi"
  description = "(Optional) The maximum RAM resources to be allocated for the prometheus pod. Default is '512Mi'."
}

variable "storage_size" {
  default     = "512Mi"
  description = "(Optional) The storage size for the prometheus pod. Default is '5Gi'."
}

variable "opentelemetry_collector_service" {
  type        = string
  description = "(Required) The service name of the OpenTelemetry Collector"
}

variable "opentelemetry_collector_port" {
  default     = 4317
  description = "(Optional) The port on which the OpenTelemetry Collector is running. Default is 4317."
}
