output "tempo_query_url" {
  value = "http://${local.tempo_service}:${local.tempo_query_frontend_service_http_port}"
}

output "tempo_distributor_url" {
  value = "http://${local.tempo_service}:${local.tempo_distributor_service_otlp_port}"
}

output "tempo_generator_url" {
  value = "http://${local.tempo_service}:${local.tempo_distributor_service_otlp_port}"
}