locals {
  dataplane_release_name = "dataplane"

  dpf_selector_url = "http://${local.controlplane_release_name}:8383/api/control/v1/dataplanes"
}

resource "helm_release" "dataplane" {
  name              = local.dataplane_release_name
  cleanup_on_fail   = true
  dependency_update = true
  recreate_pods     = true
  chart             = "./dataplane.tgz"

  values = [
    yamlencode({
      "dataplane" : {
        "initContainers" : [],
        "image" : {
          "repository" : "eonax-data-plane-postgresql-hashicorpvault"
          "tag" : "latest"
          "pullPolicy" : "Never"
        },

        "did" : {
          "web" : {
            "url" : var.identity_hub_did_web_url,
            "useHttps" : false
          }
        },

        "keys" : {
          // use the same key pair for simplicity
          "dataplane" : {
            "privateKeyVaultAlias" : var.privatekey_alias,
            "publicKeyVaultAlias" : var.publickey_alias
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
              "path" : "/dp/(public)(.*)",
              "pathType" : "ImplementationSpecific"
            },
            {
              "port" : 8282,
              "path" : "/dp/(data)(.*)",
              "pathType" : "ImplementationSpecific"
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
              "name" : var.db_credentials_secret_name
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

  depends_on = [helm_release.controlplane]
}
