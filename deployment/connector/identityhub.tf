locals {
  identityhub_release_name = "identityhub"
  did_url                  = "did:web:${local.identityhub_release_name}%3A8383:api:did"
  
  sts_port                = 8484
  sts_path                = "/api/sts"
  sts_url                 = "http://${local.identityhub_release_name}:${local.sts_port}${local.sts_path}/token"
  sts_client_secret_alias = "${local.did_url}-sts-client-secret"
  did_url_base64_url      = replace(replace(replace(base64encode(local.did_url), "+", "-"), "/", "_"), "=", "")
  protocol_url = "http://${local.controlplane_release_name}:8282/api/dsp"
  identityhub_credentials_url = "http://${local.identityhub_release_name}:8282/api/credentials"
}

resource "helm_release" "identity-hub" {
  name              = local.identityhub_release_name
  cleanup_on_fail   = true
  dependency_update = true
  recreate_pods     = true
  chart             = "./identityhub.tgz"

  values = [
    yamlencode({
      "identityhub" : {
        "initContainers" : [],
        "image" : {
          "repository" : "eonax-identity-hub-postgresql-hashicorpvault"
          "tag" : "latest"
          "pullPolicy" : "Never"
        },
        "keys" : {
          "sts" : {
            "privateKeyAlias" : var.privatekey_alias,
            "publicKeyAlias" : var.publickey_alias,
            "publicKeyId" : "${local.did_url}#my-key"
          }
        },
        "participantcontext" : {
          "superuser" : {
            "key" : "${local.did_url_base64_url}.root"
            "services" : jsonencode([
              {
                id : "dsp-url"
                type : "DSPMessaging",
                serviceEndpoint : local.protocol_url
              },
              {
                id : "credential-service-url"
                type : "CredentialService",
                serviceEndpoint : "${local.identityhub_credentials_url}/v1/participants/${local.did_url_base64_url}"
              }
            ])
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
        "postgresql" : {
          "jdbcUrl" : "jdbc:postgresql://${var.db_server_fqdn}/${var.db_name}",
          "credentials" : {
            "secret" : {
              "name" : var.db_credentials_secret_name
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
              "path" : "/ih/(identity)(.*)",
              "pathType" : "ImplementationSpecific"
            },
            {
              "port" : 8282,
              "path" : "/ih/(credentials)(.*)",
              "pathType" : "ImplementationSpecific"
            },
            {
              "port" : 8383,
              "path" : "/ih/(did)(.*)",
              "pathType" : "ImplementationSpecific"
            },
            {
              "port" : 8484,
              "path" : "/ih/(sts)(.*)",
              "pathType" : "ImplementationSpecific"
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
}
