locals {
  loki_release_name     = "loki"
  loki_chart            = "loki"
  loki_chart_version    = "6.18.0"
  loki_image_registry   = "grafana"
  loki_image_repository = "loki"
  loki_image_version    = var.loki_version

  loki_service      = "loki"
  loki_service_port = 3100

  loki_stack_name   = "loki"

}

resource "helm_release" "loki" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.loki_chart
  # version    = local.loki_chart_version
  chart     = "../../charts/${local.loki_chart}-${local.loki_chart_version}.tgz"
  name      = local.loki_release_name
  namespace = var.k8s_namespace

  values = [
    yamlencode({

      loki = {
        commonConfig = {
          replication_factor = 1
        }
        "auth_enabled" = false
        schemaConfig = {
          configs = [
            {
              from = "2024-04-01"
              store = "tsdb"
              object_store = "s3"
              schema = "v13"
              index = {
                prefix = "loki_index_"
                period = "24h"
              }
            }
          ]
        }
        ingester = {
          chunk_encoding = "snappy"
        }
        tracing = {
          enabled = true
        }
        querier = {
          max_concurrent = 2
        }
      }
      deploymentMode = "SingleBinary"
      singleBinary = {
        replicas = 1
        resources = {
          limits = {
            cpu = 1
            memory = "1Gi"
          }
          requests = {
            cpu = 1
            memory = "1Gi"
          }
        }
        extraEnv = [
          {
            name = "GOMEMLIMIT"
            value = "3750MiB"
          }
        ]
      }

      chunksCache = {
        writebackSizeLimit = "10MB"
      }

      minio = {
        enabled = true
      }
      "ingress" = {
        "enabled"          = true
        "ingressClassName" = "nginx"
        "hosts" = ["${local.loki_service}.127.0.0.1.nip.io"]
      }
      gateway = {
        "enabled" = false

        "basicAuth" = {
          "enabled" = false
          "username" = "admin"
          "password" = "admin"
        }
        ingress = {
          enabled = true
          hosts = [
            {
              host = "${local.loki_service}-gateway.127.0.0.1.nip.io"
              paths = [
                {
                  path = "/"
                  pathType = "Prefix"
                }
              ]
            }
          ]
        }
      }
      "test" = {
        "enabled" = false
      }
      "lokiCanary" = {
        "enabled" = false
      }

      backend = {
        replicas = 0
      }

      read = {
        replicas = 0
      }

      write = {
        replicas = 0
      }

      ingester = {
        replicas = 0
      }

      querier = {
        replicas = 0
      }

      queryFrontend = {
        replicas = 0
      }

      queryScheduler = {
        replicas = 0
      }

      distributor = {
        replicas = 0
      }

      compactor = {
        replicas = 0
      }

      indexGateway = {
        replicas = 0
      }

      bloomCompactor = {
        replicas = 0
      }

      bloomGateway = {
        replicas = 0
      }
    })
  ]
}