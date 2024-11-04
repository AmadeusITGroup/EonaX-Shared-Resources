output "collector_url" {
  value = "http://${local.collector_service_name}:${local.collector_service_port}"
}

output "collector_service" {
  value = local.collector_service_name
}

output "collector_service_port" {
  value = local.collector_service_port
}