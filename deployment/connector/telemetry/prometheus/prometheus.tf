locals {
  prometheus_release_name  = "eonax-prometheus-${var.environment}"
  prometheus_chart         = "prometheus"
  prometheus_chart_version = "25.28.0"

  prometheus_image_registry   = "docker.io"
  prometheus_image_repository = "prom/prometheus"
  prometheus_image_version    = var.prometheus_version

  prometheus_service      = "prometheus"
  prometheus_service_port = 9090
}

resource "helm_release" "prometheus" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.prometheus_chart
  # version    = local.prometheus_chart_version
  chart     = "../../charts/${local.prometheus_chart}-${local.prometheus_chart_version}.tgz"
  name      = local.prometheus_release_name
  namespace = var.k8s_namespace

  values = [
    yamlencode({
      "alertmanager" = {
        "enabled" = false
      }
      "commonMetaLabels" = var.mandatory_labels
      "configmapReload" = {
        "env" = []
        "prometheus" = {
          "enabled" = false
        }
        "reloadUrl" = ""
      }
      "kube-state-metrics" = {
        "enabled" = false
      }
      "networkPolicy" = {
        "enabled" = false
      }
      "podSecurityPolicy" = {
        "enabled" = false
      }
      "prometheus-node-exporter" = {
        "enabled" = false
      }
      "prometheus-pushgateway" = {
        "enabled" = false
      }
      "rbac" = {
        "create" = false
      }

      "server" = {
        "fullnameOverride" : local.prometheus_service
        "remoteWrite" = []
        "retention" = "15d"

        "service" = {
          "enabled" = true
          "servicePort" : local.prometheus_service_port
        }
        "extraFlags" = [
          "web.enable-lifecycle",
          "web.enable-remote-write-receiver",
          "enable-feature=exemplar-storage,otlp-write-receiver"
        ]
        "exemplars" = {
          max_exemplars : 100000
        }
        "enableServiceLinks" = true
        "env" = []
        "global" = {
          "evaluation_interval" = "1m"
          "scrape_interval"     = "20s"
          "scrape_timeout"      = "10s"
        }
        "image" = {
          "repository" = "${local.prometheus_image_registry}/${local.prometheus_image_repository}"
          "tag"        = local.prometheus_image_version
        }
        "name" = "server"
        "persistentVolume" = {
          "enabled" = true
          "size"    = var.storage_size
        }
        "podSecurityPolicy" = {
          "annotations" = {}
        }
        "replicaCount" = var.replica_count
        "resources" = {
          "limits" = {
            "cpu"    = var.cpu
            "memory" = var.ram
          }
          "requests" = {
            "cpu"    = "100m"
            "memory" = "200Mi"
          }
        }
        "securityContext" = {
          "fsGroup"      = null
          "runAsGroup"   = null
          "runAsNonRoot" = false
          "runAsUser"    = null
        }
        "ingress" = {
          "enabled" = true
          "ingressClassName" : "nginx"
          "hosts" = ["${local.prometheus_service}.127.0.0.1.nip.io"]
          "path"    = "/"
          "pathType" = "Prefix"
          annotations = {
            "kubernetes.io/ingress.class" = "nginx"
          }
        }

      }
      "serverFiles" = {
        "prometheus.yml" = {
          "scrape_configs" = [
            {
              "job_name" = "prometheus"
              "static_configs" = [
                {
                  "targets" = [
                    "localhost:9090",
                  ]
                },
              ]
            },
            {
              "job_name"        = "eonax-apps"
              "scrape_interval" = "15s"
              "static_configs" = [
                {
                  "targets" = [
                    "${var.opentelemetry_collector_service}:${var.prometheus_scraping_port}",
                  ]
                },
              ]
            },
          ]
        }
      }
      "serviceAccounts" = {
        "server" = {
          "create" = false
          "name"   = var.service_account
        }
      }
    })
  ]
}