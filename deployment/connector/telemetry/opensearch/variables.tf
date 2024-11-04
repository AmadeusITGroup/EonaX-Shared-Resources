variable "k8s_namespace" {
  description = "(Required) Kubernetes namespace in which resource will be deployed"
}

variable "environment" {
  description = "(Required) Deployment environment (e.g. test, prod...)"
}

variable "service_account" {
  description = "(Required) Existing service account with monitoring roles"
}

variable "opensearch_version" {
  description = "(Required) The version of Opensearch to be deployed."
}

variable "data_prepper_version" {
  description = "(Required) The version of Data Prepper to be deployed."
  default = "2.8.0"
}

variable "cpu" {
  default     = 1
  description = "(Optional) The maximum CPU resources to be allocated for the ingester pod. Default is 1."
}

variable "ram" {
  default     = "1Gi"
  description = "(Optional) The maximum RAM resources to be allocated for the ingester pod. Default is '1Gi'."
}

variable "storage_size" {
  default     = "20Gi"
  description = "(Optional) The storage size for the ingester pod. Default is '20Gi'."
}