locals {
  controlplane_release_name = "controlplane"
}

resource "helm_release" "controlplane" {
  name              = local.controlplane_release_name
  cleanup_on_fail   = true
  dependency_update = true
  recreate_pods     = true
  chart             = "./controlplane.tgz"

  values = [
    yamlencode({
      "controlplane" : {
        "initContainers" : [],
        "image" : {
          # "repository" : "eonax-control-plane-postgresql-hashicorpvault"
          # "pullPolicy" : "Never"
        //? "repository" : local.control_plane_image
        // ? "pullPolicy" : var.environment == "local" ? "Never" : "IfNotPresent"
          "tag" : "latest"
        },
       "sts" : {
          "tokenUrl" : local.sts_url // "http://${local.identityhub_release_name}:${local.sts_port}${local.sts_path}/token"
          "clientId" : local.did_url,  // "did:web:${local.identityhub_release_name}%3A8383:api:did"
          "clientSecretAlias" : local.sts_client_secret_alias
        },
        "did" : {
          "web" : {
            "url" : var.identity_hub_did_web_url
            "useHttps" : false
          }
        },
        # "trustedIssuers" : {
        #   "authority" : {
        #     # "did" : local.authority_did ??
        #   }
        # },
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
              "path" : "/cp/(management)(.*)",
              "pathType" : "ImplementationSpecific"
            },
            {
              "port" : 8282,
              "path" : "/cp/(dsp)(.*)",
              "pathType" : "ImplementationSpecific"
            }
          ]
        },
        "postgresql" : {
          "jdbcUrl" : "jdbc:postgresql://${var.db_server_fqdn}/${var.db_name}",
          "credentials" : {
            "secret" : {
              "name" : var.db_credentials_secret_name
            }
          }
        },
        "api" : {
          "cors" : {
            "enabled" : true
          }
        },
        "vault" : {
          "hashicorp" : {
            "url" : var.vault_url
            "token" : {
              "secret" : {
                "name" : var.vault_token_secret_name,
                "tokenKey" : "rootToken"
              }
            }
          }
        }
      }
    })
  ]
}
