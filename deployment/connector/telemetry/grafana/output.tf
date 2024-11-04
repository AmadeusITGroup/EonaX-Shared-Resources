output "grafana_url" {
  value = "http://${local.grafana_service}:${local.grafana_service_port}"
}

output "grafana_credentials_secret" {
  value = local.grafana_datasource_secret
}