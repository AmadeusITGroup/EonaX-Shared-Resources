locals {
  opensearch_release_name     = "opensearch"
  opensearch_chart            = "opensearch"
  opensearch_chart_version    = "2.26.1"
  opensearch_image_registry   = "opensearchproject"
  opensearch_image_repository = "opensearch"
  opensearch_image_version    = var.opensearch_version
  opensearch_service          = "opensearch"
  opensearch_service_headless = "opensearch-cluster-master-headless"
  opensearch_service_port     = 9200
  opensearch_stack_name       = "eonax-opensearch"

  opensearch_admin_password = "eonaxP4ssword1!"

}

resource "helm_release" "opensearch" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.opensearch_chart
  # version    = local.opensearch_chart_version
  chart     = "../../charts/${local.opensearch_chart}-${local.opensearch_chart_version}.tgz"
  name      = local.opensearch_release_name
  namespace = var.k8s_namespace

  values = [
    yamlencode({
      "clusterName" = local.opensearch_stack_name
      "singleNode"  = true
      "replicas"    = 1
      "resources" = {
        "requests" = {
          "cpu"    = "1000m"
          "memory" = "1024Mi"
        }
        "limits" = {
          "cpu"    = "1000m"
          "memory" = "1024Mi"
        }
      }
      "protocol" = "http"

      "securityConfig" = {
        "enabled" = false
      }
      "persistence" = {
        "enabled" = false
      }
      extraEnvs = [
        {
          name  = "OPENSEARCH_INITIAL_ADMIN_PASSWORD"
          value = local.opensearch_admin_password
        }
      ]
      config = {
        "opensearch.yml" = <<-EOT
      cluster.name: ${local.opensearch_stack_name}
      network.host: 0.0.0.0
      discovery.type: single-node
      plugins:
        security:
          ssl:
            transport:
              pemcert_filepath: esnode.pem
              pemkey_filepath: esnode-key.pem
              pemtrustedcas_filepath: root-ca.pem
              enforce_hostname_verification: false
            http:
              enabled: true
              pemcert_filepath: esnode.pem
              pemkey_filepath: esnode-key.pem
              pemtrustedcas_filepath: root-ca.pem
          allow_unsafe_democertificates: true
          allow_default_init_securityindex: true
          authcz:
            admin_dn:
              - CN=kirk,OU=client,O=client,L=test,C=de
          audit.type: internal_opensearch
          enable_snapshot_restore_privilege: true
          check_snapshot_restore_write_privileges: true
          restapi:
            roles_enabled: ["all_access", "security_rest_api_access"]
          system_indices:
            enabled: true
            indices:
              [
                ".opendistro-alerting-config",
                ".opendistro-alerting-alert*",
                ".opendistro-anomaly-results*",
                ".opendistro-anomaly-detector*",
                ".opendistro-anomaly-checkpoints",
                ".opendistro-anomaly-detection-state",
                ".opendistro-reports-*",
                ".opendistro-notifications-*",
                ".opendistro-notebooks",
                ".opendistro-asynchronous-search-response*",
              ]
    EOT
      }
    })
  ]
}
