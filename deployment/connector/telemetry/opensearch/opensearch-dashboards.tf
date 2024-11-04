locals {
  opensearch_dashboards_release_name     = "opensearch-dashboards"
  opensearch_dashboards_chart            = "opensearch-dashboards"
  opensearch_dashboards_chart_version    = "2.24.1"
  opensearch_dashboards_image_registry   = "opensearchproject"
  opensearch_dashboards_image_repository = "opensearch-dashboards"
  opensearch_dashboards_service          = "opensearch-dashboards"
  opensearch_dashboards_service_port     = 5601
}

resource "helm_release" "opensearch_dashboards" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.opensearch_dashboards_chart
  # version    = local.opensearch_dashboards_chart_version
  chart     = "../../charts/${local.opensearch_dashboards_chart}-${local.opensearch_dashboards_chart_version}.tgz"
  name      = local.opensearch_dashboards_release_name
  namespace = var.k8s_namespace

  values = [
    yamlencode({
      # "opensearchHosts" = "http://${local.opensearch_service_headless}:${local.opensearch_service_port}"
      "ingress" = {
        "enabled" = true
        "ingressClassName" : "nginx"
        "hosts" = [
          {
            "host" = "${local.opensearch_dashboards_service}.127.0.0.1.nip.io"
            "paths" = [
              {
                "path" = "/"
                "backend" = {
                  "service"     = local.opensearch_dashboards_service
                  "servicePort" = local.opensearch_dashboards_service_port
                }
              }
            ]
          }

        ]
        "path"     = "/"
        "pathType" = "Prefix"
        annotations = {
          "kubernetes.io/ingress.class" = "nginx"
        }
      }
    })
  ]

  depends_on = [helm_release.opensearch]
}
