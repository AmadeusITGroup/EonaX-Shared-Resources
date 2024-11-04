locals {
  collector_chart            = "opentelemetry-collector"
  collector_chart_version    = "0.108.0"
  collector_image_registry   = "docker.io"
  collector_image_repository = "otel/opentelemetry-collector-contrib"
  collector_image_version    = "0.111.0"

  collector_release_name = "eonax-otlp-collector"
  collector_service_name = "eonax-otel-collector"
  collector_service_port = 4317

  tempo_distributor_url = var.tempo_distributor_url
  elastic_fleet_url     = var.fleet_url
  elastic_apm_token     = "Bearer bzJsSnBZNEJiU1JuZGl1d1VDSHY6enZUNjhJNHVRNHVlQlNWOGItcUJtZw=="
}

resource "helm_release" "collector" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.collector_chart
  # version    = local.collector_chart_version
  chart     = "../../charts/${local.collector_chart}-${local.collector_chart_version}.tgz"
  name      = local.collector_release_name
  namespace = var.k8s_namespace

  values = [
    yamlencode({

      global : {
        imageRegistry = local.collector_image_registry
      }

      image = {
        repository = local.collector_image_repository
        tag        = local.collector_image_version
      }

      fullnameOverride = local.collector_service_name

      "mode" = "statefulset"

      "replicaCount" = var.replica_count

      "resources" = {
        "requests" = {
          "cpu"    = "100m"
          "memory" = "500Mi"
        }
        "limits" = {
          "cpu"    = var.cpu
          "memory" = var.ram
        }
      }

      "config" = {
        "extensions" = {
          "basicauth/loki" = {
            "client_auth" = {
              "username" = "admin"
              "password" = "admin"
            }
          }
          "headers_setter" = {
            "headers" = [
              {
                "action"       = "insert"
                "from_context" = "tenant_id"
                "key"          = "X-Scope-OrgID"
              },
            ]
          }
          "health_check" = {
            "endpoint" = "$${env:MY_POD_IP}:13133"
          }
          # "memory_ballast" = {}
        }
        "exporters" = {

          "debug" = {}

          "otlphttp/loki" = {

            "logs_endpoint" = "http://loki:3100/otlp/v1/logs"
            "tls" = {
              "insecure" = true
            }
          }

          "otlp/opensearch-logs" = {
              "endpoint" = "http://opensearch-data-prepper:21892"
              "tls" = {
                "insecure" = true
              }
            }
          "otlp/opensearch-metrics" = {
            "endpoint" = "http://opensearch-data-prepper:21891"
            "tls" = {
              "insecure" = true
            }
          }
          "otlp/opensearch-traces" = {
            "endpoint" = "http://opensearch-data-prepper:21890"
            "tls" = {
              "insecure" = true
            }
          }
          "otlp/tempo" = {
            "auth" = {
              "authenticator" = "headers_setter"
            }
            "endpoint" = local.tempo_distributor_url
            "tls" = {
              "insecure" = true
            }
          }

          "prometheus" = {
            "enable_open_metrics" = true
            "endpoint"            = "0.0.0.0:9464"
            "metric_expiration"   = "180m"
            "namespace"           = ""
          }

        }

        "processors" = {
          "batch" = {
            "metadata_keys" = [
              "tenant_id",
            ]
          }

          "filter/ottl" = {
            "error_mode" = "ignore"
            "traces" = {
              "span" = [
                "attributes[\"db.operation\"] == \"SELECT\"",
                "attributes[\"http.route\"] == \"/api/check/readiness\"",
                "attributes[\"http.route\"] == \"/api/check/liveness\"",
              ]
            }
          }
          "batch/logs" = null
          # "memory_limiter" = null
        }
        "receivers" = {
          "otlp" = {
            "protocols" = {
              "grpc" = {
                "endpoint"         = "$${env:MY_POD_IP}:4317"
                "include_metadata" = true
              }
            }
          }
          "prometheus" = {
            "config" = {
              "scrape_configs" = [
                {
                  "job_name" = "eonax_services"
                  "kubernetes_sd_configs" = [
                    {
                      "namespaces" = {
                        "names" = [
                          var.k8s_namespace
                        ]
                      }
                      "role" = "service"
                    },
                  ]
                  "relabel_configs" = [
                    {
                      "action" = "keep"
                      "regex"  = "true"
                      "source_labels" = [
                        "__meta_kubernetes_service_label_prometheus_io_scrape_eonax",
                      ]
                    }
                  ]
                  "scrape_interval" = "10s"
                },
              ]
            }
          }
        }
        "service" = {
          "extensions" = [
            "basicauth/loki",
            "health_check",
            # "memory_ballast",
            "headers_setter",
          ]
          "pipelines" = {
            "logs" = {
              "receivers" = [
                "otlp",
              ]
              "exporters" = [
                "debug",
                "otlphttp/loki",
                "otlp/opensearch-logs"
              ]
            }
            "metrics" = {
              "exporters" = [
                "debug",
                "prometheus",
                "otlp/opensearch-metrics"
                # "otlp/elastic",
              ]
              "processors" = []
              "receivers" = [
                "prometheus",
              ]
            }
            "traces" = {
              "exporters" = [
                "debug",
                "otlp/tempo",
                "otlp/opensearch-traces"
              ]
              "processors" = [
                "filter/ottl",
                "batch",
              ]
              "receivers" = [
                "otlp",
              ]
            }
          }
          "telemetry" = {
            "metrics" = {
              "address" = "$${env:MY_POD_IP}:8888"
            }
          }
        }
      }

      "ports" = {
        "otlp" = {
          "enabled"       = true
          "appProtocol"   = "grpc"
          "protocol"      = "TCP"
          "containerPort" = local.collector_service_port
          "hostPort"      = local.collector_service_port
          "servicePort"   = local.collector_service_port
        }
        "metrics-eonax" = {
          "enabled"       = true
          "protocol"      = "TCP"
          "servicePort"   = var.prometheus_scraping_port
          "containerPort" = var.prometheus_scraping_port
        }
        "jaeger-compact" = {
          "enabled" = false
        }
        "jaeger-grpc" = {
          "enabled" = false
        }
        "jaeger-thrift" = {
          "enabled" = false
        }
        "metrics" = {
          "enabled" = false
        }
        "otlp-http" = {
          "enabled" = false
        }
        "zipkin" = {
          "enabled" = false
        }
      }

      "serviceAccount" = {
        "create" = false
        "name"   = var.service_account
      }

      "statefulset" = {
        "persistentVolumeClaimRetentionPolicy" = {
          "enabled" = true
        }
      }
    })
  ]
}