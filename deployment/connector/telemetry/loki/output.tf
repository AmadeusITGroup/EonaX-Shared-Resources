output "loki_url" {
  value = "http://${local.loki_service}:${local.loki_service_port}"
}
