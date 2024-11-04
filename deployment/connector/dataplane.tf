locals {
  dataplane_release_name = "dataplane"

  dpf_selector_url = "http://${local.controlplane_release_name}:8383/api/control/v1/dataplanes"
}

resource "helm_release" "dataplane" {
  name              = local.dataplane_release_name
  cleanup_on_fail   = true
  dependency_update = true
  recreate_pods     = true
  chart             = "../../charts/dataplane-0.2.4.tgz"

  values = [
    yamlencode({
      "dataplane" : {
        "image" : {
          "repository" : "localhost/eonax-data-plane-postgresql-hashicorpvault"
          "tag" : "latest"
          "pullPolicy" : "Never"
        },
        "service" = {
          "labels" = {
            "prometheus.io/scrape-eonax" = var.telemetry_enabled ? "true" : "false"
          }
        }
        "keys" : {
          // use the same key pair for simplicity
          "dataplane" : {
            "privateKeyVaultAlias" : var.private_key_alias,
            "publicKeyVaultAlias" : var.public_key_alias
          }
        }
        "logging" : <<EOT
        .level=INFO
        org.eclipse.edc.level=ALL
        handlers=java.util.logging.ConsoleHandler
        java.util.logging.ConsoleHandler.formatter=java.util.logging.SimpleFormatter
        java.util.logging.ConsoleHandler.level=ALL
        java.util.logging.SimpleFormatter.format=[%1$tY-%1$tm-%1$td %1$tH:%1$tM:%1$tS] [%4$-7s] %5$s%6$s%n
               EOT
        "opentelemetry" : <<EOT
otel.javaagent.enabled=${var.telemetry_enabled}
otel.javaagent.debug=false
otel.exporter.otlp.protocol=grpc
otel.exporter.otlp.endpoint=http://eonax-otel-collector:4317
otel.exporter.otlp.headers=tenant_id=dataplane
otel.service.name=dataplane
otel.metrics.exporter=prometheus
otel.instrumentation.default.enabled=false
otel.instrumentation.micrometer.enabled=true
    EOT
        "config" : <<EOT
edc.vault.hashicorp.token.scheduled-renew-enabled=false
edc.dataplane.state-machine.iteration-wait-millis=${var.data_plane_state_machine_wait_millis}
        EOT
        "ingress" : {
          "enabled" : true
          "className" : "nginx"
          "annotations" : {
            "nginx.ingress.kubernetes.io/ssl-redirect" : "false"
            "nginx.ingress.kubernetes.io/use-regex" : "true"
            "nginx.ingress.kubernetes.io/rewrite-target" : "/api/$1$2"
          },
          "endpoints" : [
            {
              "port" : 8181,
              "path" : "/dp/(public)(.*)"
              "pathType": "ImplementationSpecific"
            },
            {
              "port" : 8282,
              "path" : "/dp/(data)(.*)"
              "pathType": "ImplementationSpecific"

            }
          ]
        },

        "selector" : {
          "url" : local.dpf_selector_url
        }

        "url" : {
          "public" : var.data_plane_public_url
        },

        "postgresql" : {
          "jdbcUrl" : "jdbc:postgresql://${var.db_server_fqdn}/${var.db_name}",
          "credentials" : {
            "secret" : {
              "name" : kubernetes_secret.db-user-credentials.metadata.0.name
            }
          }
        },
        "vault" : {
          "hashicorp" : {
            "url" : var.vault_url
            "token" : {
              "secret" : {
                "name" : var.vault_token_secret_name
              }
            }
          }
        }
      }
    })
  ]

  depends_on = [module.db, helm_release.controlplane]
}