locals {
  identityhub_release_name = "identityhub"
}

resource "helm_release" "identity-hub" {
  name              = local.identityhub_release_name
  cleanup_on_fail   = true
  dependency_update = true
  recreate_pods     = true
  chart             = "../../charts/identityhub-0.2.4.tgz"

  values = [
    yamlencode({
      "identityhub" : {
        "image" : {
          "repository" : "localhost/eonax-identity-hub-postgresql-hashicorpvault"
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
            "publicKeyVaultAlias" : var.public_key_alias
          }
        },
        "did" : {
          "web" : {
            "url" : var.identity_hub_did_web_url,
            "useHttps" : false
          }
        },
        "config" : <<EOT
edc.vault.hashicorp.token.scheduled-renew-enabled=false
        EOT
        "opentelemetry" : <<EOT
otel.javaagent.enabled=${var.telemetry_enabled}
otel.javaagent.debug=false
otel.exporter.otlp.protocol=grpc
otel.exporter.otlp.endpoint=http://eonax-otel-collector:4317
otel.exporter.otlp.headers=tenant_id=identityhub
otel.service.name=identityhub
otel.metrics.exporter=prometheus
otel.instrumentation.default.enabled=false
otel.instrumentation.micrometer.enabled=true
    EOT
        "postgresql" : {
          "jdbcUrl" : "jdbc:postgresql://${var.db_server_fqdn}/${var.db_name}",
          "credentials" : {
            "secret" : {
              "name" : kubernetes_secret.db-user-credentials.metadata.0.name
            }
          }
        },
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
              "path" : "/ih/(identity)(.*)"
              "pathType": "ImplementationSpecific"
            },
            {
              "port" : 8282,
              "path" : "/ih/(resolution)(.*)"
              "pathType": "ImplementationSpecific"
            },
            {
              "port" : 8383,
              "path" : "/ih/(did)(.*)"
              "pathType": "ImplementationSpecific"
            }
          ]
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

        "logging" : <<EOT
        .level=DEBUG
        org.eclipse.edc.level=ALL
        handlers=java.util.logging.ConsoleHandler
        java.util.logging.ConsoleHandler.formatter=java.util.logging.SimpleFormatter
        java.util.logging.ConsoleHandler.level=ALL
        java.util.logging.SimpleFormatter.format=[%1$tY-%1$tm-%1$td %1$tH:%1$tM:%1$tS] [%4$-7s] %5$s%6$s%n
               EOT
      }
    })
  ]

  depends_on = [module.db]
}