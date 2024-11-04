locals {
  grafana_release_name     = "eonax-tempo-grafana-${var.environment}"
  grafana_chart            = "grafana"
  grafana_chart_version    = "11.3.25"
  grafana_image_registry   = "docker.io/bitnami"
  grafana_image_repository = "grafana"
  grafana_image_version    = var.grafana_version

  grafana_service      = "grafana"
  grafana_service_port = 3000

  grafana_admin_username    = "admin"
  grafana_admin_password    = "admin"
  grafana_datasource_secret = "grafana-datasources"
  grafana_dashboard_config  = "grafana-dashboards"

  dashboards = "${path.module}/dashboards"
}

resource "kubernetes_config_map" "grafana-dashboards" {
  metadata {
    name      = local.grafana_dashboard_config
    namespace = var.k8s_namespace
  }
  data = {
    for f in fileset(local.dashboards, "*.json") :
    f => file(join("/", [local.dashboards, f]))
  }
}

resource "kubernetes_secret" "grafana-datasource" {
  metadata {
    name      = local.grafana_datasource_secret
    namespace = var.k8s_namespace
  }
  data = {
    "datasources.yaml" = yamlencode(local.grafana_datasources)
  }
  type = "Opaque"
}

resource "helm_release" "grafana" {
  # repository        = "oci://${var.artifactory_url}/eonax/helm"
  # chart             = local.grafana_chart
  # version           = local.grafana_chart_version
  chart = "../../charts/${local.grafana_chart}-${local.grafana_chart_version}.tgz"

  name              = local.grafana_release_name
  namespace         = var.k8s_namespace
  cleanup_on_fail   = true
  dependency_update = true
  recreate_pods     = true
  values = [
    yamlencode({
      "fullnameOverride" = local.grafana_service

      "global" = {
        "imageRegistry" = local.grafana_image_registry
        "compatibility" = {
          "openshift" = {
            "adaptSecurityContext" = "force"
          }
        }
      }

      image = {
        registry   = local.grafana_image_registry
        repository = local.grafana_image_repository
        tag        = local.grafana_image_version
      }

      "admin" = {
        "user" = local.grafana_admin_username
        "password" = local.grafana_admin_password
      }
      "plugins" = "grafana-opensearch-datasource"
      "dashboardsProvider" = {
        "enabled" = true
      },
      "datasources" = {
        "secretDefinition" = ""
        "secretName"       = local.grafana_datasource_secret
      }
      "ingress" = {
        "enabled"  = true
        "ingressClassName" : "nginx"
        "hostname" = " ${local.grafana_service}.127.0.0.1.nip.io"
        "path"     = "/"
        "pathType" = "Prefix"
        annotations = {
          "kubernetes.io/ingress.class" = "nginx"
        }
      }
      "grafana" = {
        "replicaCount" = var.replica_count
        "resources" = {
          "requests" = {
            "cpu"    = var.cpu
            "memory" = var.ram
          }
          "limits" = {
            "cpu"    = var.cpu
            "memory" = var.ram
          }
        }
        "containerSecurityContext" = {
          "enabled" = false
        }
        "podSecurityContext" = {
          "enabled" = false
        }
        "extraConfigmaps" = [
          {
            "name"      = local.grafana_dashboard_config
            "mountPath" = "/opt/bitnami/grafana/dashboards"
          }
        ]
      }
      "metrics" = {
        "enabled" = true
        "service" = {
          "annotations" = {
            "prometheus.io/scrape" = "true"
          }
        }
      }
      "networkPolicy" = {
        "enabled" = false
      }
      "persistence" = {
        "enabled" = false
        "size"    = var.storage_size
      }
      "service" = {
        "extraPorts" = [
          {
            "name"       = "metrics"
            "nodePort"   = null
            "port"       = var.prometheus_scraping_port
            "protocol"   = "TCP"
            "targetPort" = "metrics"
          }
        ]
      }
      "serviceAccount" = {
        "create" = false
        "name"   = var.service_account
      },
    })
  ]
  depends_on = [kubernetes_secret.grafana-datasource, kubernetes_config_map.grafana-dashboards]
}