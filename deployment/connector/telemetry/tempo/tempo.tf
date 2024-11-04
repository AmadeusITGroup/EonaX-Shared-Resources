locals {
  tempo_release_name  = "tempo"
  tempo_chart         = "tempo"
  tempo_chart_version = "1.10.3"
  tempo_image_registry   = "grafana"
  tempo_image_repository = "tempo"
  tempo_image_version    = var.tempo_version

  tempo_service      = "tempo"
  tempo_service_port = 9090
  tempo_distributor_service_otlp_port            = 4317
  tempo_query_frontend_service_http_port         = 3100
  tempo_query_frontend_service_grpc_port         = 9095
}

resource "helm_release" "tempo" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.tempo_chart
  # version    = local.tempo_chart_version
  chart     = "../../charts/${local.tempo_chart}-${local.tempo_chart_version}.tgz"
  name      = local.tempo_release_name
  namespace = var.k8s_namespace

  values = [
    yamlencode({
      "tempo" = {
        "metricsGenerator" = {
          "enabled" = var.generator_enabled
          "remoteWriteUrl" = "${var.prometheus_url}/api/v1/write"
        }
        "resources" = {
          "limits" = {
            "cpu"    = var.cpu
            "memory" = var.ram
          }
          "requests" = {
            "cpu"    = var.cpu
            "memory" = var.ram
          }
        }
      }
    })
  ]
}