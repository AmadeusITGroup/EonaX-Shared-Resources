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

variable "artifactory_url" {
  description = "(Optional) Artifactory URL"
  default = ""
}

variable "replica_count" {
  default     = 0
  description = "(Optional) The number of replicas for the prometheus pod. Default is 0."
}

variable "cpu" {
  default     = 0.5
  description = "(Optional) The maximum CPU resources to be allocated for the prometheus pod. Default is 0.5."
}

variable "ram" {
  default     = "512Mi"
  description = "(Optional) The maximum RAM resources to be allocated for the prometheus pod. Default is '512Mi'."
}

variable "storage_size" {
  default     = "5Gi"
  description = "(Optional) The storage size for the prometheus pod. Default is '5Gi'."
}