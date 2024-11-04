locals {
  controlplane_release_name = "controlplane"
}

resource "helm_release" "controlplane" {
  name              = local.controlplane_release_name
  cleanup_on_fail   = true
  dependency_update = true
  recreate_pods     = true
  chart             = "../../charts/controlplane-0.2.4.tgz"

  values = [
    yamlencode({
      "controlplane" : {
        "image" : {
          "repository" : "localhost/eonax-control-plane-postgresql-hashicorpvault"
          "tag" : "latest"
          "pullPolicy" : "Never"
        },
        "service" = {
          "labels" = {
            "prometheus.io/scrape-eonax" = var.telemetry_enabled ? "true" : "false"
          }
        }
        "keys" : {
          "sts" : {
            "privateKeyVaultAlias" : var.private_key_alias,
            "publicKeyId" : "${var.identity_hub_did_web_url}#my-key"
          }
        },
        "did" : {
          "web" : {
            "url" : var.identity_hub_did_web_url
            "useHttps" : false
          }
        },

        "url" : {
          "protocol" : var.control_plane_dsp_url
        },

        "logging" : <<EOT
        .level=DEBUG
        org.eclipse.edc.level=ALL
        handlers=java.util.logging.ConsoleHandler
        java.util.logging.ConsoleHandler.formatter=java.util.logging.SimpleFormatter
        java.util.logging.ConsoleHandler.level=ALL
        java.util.logging.SimpleFormatter.format=[%1$tY-%1$tm-%1$td %1$tH:%1$tM:%1$tS] [%4$-7s] %5$s%6$s%n
               EOT
        "config" : <<EOT
edc.vault.hashicorp.token.scheduled-renew-enabled=false
edc.negotiation.state-machine.iteration-wait-millis=${var.negotiation_state_machine_wait_millis}
edc.transfer.state-machine.iteration-wait-millis=${var.transfer_state_machine_wait_millis}
edc.policy.monitor.state-machine.iteration-wait-millis=${var.policy_monitor_state_machine_wait_millis}
        EOT
        "opentelemetry" : <<EOT
otel.javaagent.enabled=${var.telemetry_enabled}
otel.javaagent.debug=false
otel.exporter.otlp.protocol=grpc
otel.exporter.otlp.endpoint=http://eonax-otel-collector:4317
otel.exporter.otlp.headers=tenant_id=controlplane
otel.service.name=controlplane
otel.metrics.exporter=prometheus
otel.instrumentation.default.enabled=false
otel.instrumentation.micrometer.enabled=true
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
              "path" : "/cp/(management)(.*)"
              "pathType": "ImplementationSpecific"
            },
            {
              "port" : 8282,
              "path" : "/cp/(dsp)(.*)"
              "pathType": "ImplementationSpecific"
            }
          ]
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

  depends_on = [module.db]
}