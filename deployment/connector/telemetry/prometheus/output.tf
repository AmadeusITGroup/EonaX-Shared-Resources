output "prometheus_url" {
  value = "http://${local.prometheus_service}:${local.prometheus_service_port}"
}