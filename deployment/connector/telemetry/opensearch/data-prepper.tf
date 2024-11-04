locals {
  data_prepper_release_name     = "opensearch-data-prepper"
  data_prepper_chart            = "data-prepper"
  data_prepper_chart_version    = "0.1.0"
  data_prepper_image_registry   = "opensearchproject"
  data_prepper_image_repository = "data-prepper"
  data_prepper_image_version    = var.data_prepper_version
  data_prepper_service          = "data_prepper"
  data_prepper_service_headless = "data_prepper-cluster-master-headless"
  data_prepper_service_port     = 9200
  data_prepper_stack_name       = "eonax-data_prepper"
}

resource "helm_release" "data_prepper" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.data_prepper_chart
  # version    = local.data_prepper_chart_version
  chart     = "../../charts/${local.data_prepper_chart}-${local.data_prepper_chart_version}.tgz"
  name      = local.data_prepper_release_name
  namespace = var.k8s_namespace

  values = [
    yamlencode({
      config = {
        "data-prepper-config.yaml" = <<-EOT
ssl: false
circuit_breakers:
  heap:
    usage: 2gb
    reset: 30s
    check_interval: 5s
EOT
      }

      pipelineConfig = {
        enabled = true
        "resources" = {
          "requests" = {
            "cpu"    = "1000m"
            "memory" = "2Gi"
          }
          "limits" = {
            "cpu"    = "1000m"
            "memory" = "2Gi"
          }
        }
        config = {
          otel_logs_pipeline = {
            workers = 1
            delay   = 10
            source = {
              otel_logs_source = {
                ssl = false
              }
            }
            buffer = {
              bounded_blocking = {}
            }
            sink = [
              {
                opensearch = {
                  hosts = ["https://${local.opensearch_service_headless}:${local.opensearch_service_port}"]
                  username   = "admin"
                  password   = local.opensearch_admin_password
                  insecure   = true
                  index_type = "custom"
                  index = "events-%%{yyyy.MM.dd}"
                  # max_retries = 20
                  bulk_size  = 4
                }
              }
            ]
          }
        }
        test = {

          otel_metrics_pipeline = {
            workers = 8
            delay   = 3000
            source = {
              otel_metrics_source = {
                health_check_service = true
                ssl                  = false
              }
            }
            buffer = {
              bounded_blocking = {
                buffer_size = 1024
                batch_size  = 1024
              }
            }
            processor = [
              {
                otel_metrics = {
                  calculate_histogram_buckets             = true
                  calculate_exponential_histogram_buckets = true
                  exponential_histogram_max_allowed_scale = 10
                  flatten_attributes                      = false
                }
              }
            ]
            sink = [
              {
                opensearch = {
                  hosts = ["https://opensearch-cluster-master:9200"]
                  username   = "admin"
                  password   = local.opensearch_admin_password
                  insecure   = true
                  index_type = "custom"
                  index = "metrics-%%{yyyy.MM.dd}"
                  # max_retries = 20
                  bulk_size  = 4
                }
              }
            ]
          }
          /*
              otel_trace_pipeline = {
                workers = 8
                delay   = "100"
                source = {
                  otel_trace_source = {
                    ssl = false
                  }
                }
                buffer = {
                  bounded_blocking = {
                    buffer_size = 25600
                    batch_size  = 400
                  }
                }
                sink = [
                  {
                    pipeline = {
                      name = "raw-traces-pipeline"
                    }
                  },
                  {
                    pipeline = {
                      name = "otel-service-map-pipeline"
                    }
                  }
                ]
              }

              raw_traces_pipeline = {
                workers = 5
                delay   = 3000
                source = {
                  pipeline = {
                    name = "otel-trace-pipeline"
                  }
                }
                buffer = {
                  bounded_blocking = {
                    buffer_size = 25600
                    batch_size  = 400
                  }
                }
                processor = [
                  {
                    otel_traces = {}
                  },
                  {
                    otel_trace_group = {
                      hosts    = ["https://opensearch-cluster-master:9200"]
                      insecure = true
                      username = "admin"
                      password = "admin"
                    }
                  }
                ]
                sink = [
                  {
                    opensearch = {
                      hosts      = ["https://opensearch-cluster-master:9200"]
                      username   = "admin"
                      password   = "admin"
                      insecure   = true
                      index_type = "trace-analytics-raw"
                    }
                  }
                ]
              }

              otel_service_map_pipeline = {
                workers = 5
                delay   = 3000
                source = {
                  pipeline = {
                    name = "otel-trace-pipeline"
                  }
                }
                processor = [
                  {
                    service_map = {
                      window_duration = 180
                    }
                  }
                ]
                buffer = {
                  bounded_blocking = {
                    buffer_size = 25600
                    batch_size  = 400
                  }
                }
                sink = [
                  {
                    opensearch = {
                      hosts      = ["https://opensearch-cluster-master:9200"]
                      username   = "admin"
                      password   = "admin"
                      insecure   = true
                      index_type = "trace-analytics-service-map"
                      # index = "otel-v1-apm-span-%\{yyyy.MM.dd}"
                      # max_retries = 20
                      bulk_size  = 4
                    }
                  }
                ]
              }
              */
        }
      }
    })
  ]
}
