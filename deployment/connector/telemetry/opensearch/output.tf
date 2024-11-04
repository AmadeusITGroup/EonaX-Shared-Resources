output "opensearch_url" {
  value = "http://${local.opensearch_service}:${local.opensearch_service_port}"
}

output "opensearch_dashboards_url" {
  value = "http://${local.opensearch_dashboards_service}:${local.opensearch_dashboards_service_port}"
}