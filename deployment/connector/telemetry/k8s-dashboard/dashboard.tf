locals {
  k8s_dashboard_release_name             = "kubernetes-dashboard"
  k8s_dashboard_chart                    = "kubernetes-dashboard"
  k8s_dashboard_chart_version            = "7.9.0"
  k8s_dashboard_image_registry           = "docker.io/kubernetesui/"
  k8s_dashboard_metrics_image_repository = "dashboard-metrics-scraper"
  k8s_dashboard_metrics_image_version    = "1.2.1"
  k8s_dashboard_auth_image_repository    = "dashboard-auth"
  k8s_dashboard_auth_image_version       = "1.2.1"
  k8s_dashboard_api_image_repository     = "dashboard-api"
  k8s_dashboard_api_image_version        = "1.10.0"
  k8s_dashboard_web_image_repository     = "dashboard-web"
  k8s_dashboard_web_image_version        = "1.5.1"
  k8s_namespace                          = "kubernetes-dashboard"
  k8s_dashboard_service                  = "kubernetes-dashboard"
  k8s_dashboard_service_port             = 9090

  admin_user = "admin-user"
}

resource "tls_private_key" "k8s_tls_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_private_key" "kong_tls_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "k8s_tls_self_signed_cert" {
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]

  dns_names = [
    "kubernetes-dashboard.127.0.0.1.nip.io"
  ]
  subject {
    common_name = "kubernetes-dashboard.127.0.0.1.nip.io"
  }

  validity_period_hours = 8760
  is_ca_certificate     = false
  private_key_pem       = tls_private_key.k8s_tls_private_key.private_key_pem
}

resource "tls_self_signed_cert" "kong_manager_tls_self_signed_cert" {
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
  dns_names = [
    "kong-manager.127.0.0.1.nip.io",
  ]
  subject {
    common_name = "kong-manager.127.0.0.1.nip.io"
  }

  validity_period_hours = 8760
  is_ca_certificate     = false
  private_key_pem       = tls_private_key.kong_tls_private_key.private_key_pem
}

resource "kubernetes_namespace" "k8s_dashboard_namespace" {
  metadata {
    name = local.k8s_namespace
  }
}

resource "kubernetes_secret" "kubernetes_tls_secret" {
  metadata {
    name      = "kubernetes-dashboard-certs"
    namespace = local.k8s_namespace
  }
  data = {
    "tls.crt" = tls_self_signed_cert.k8s_tls_self_signed_cert.cert_pem
    "tls.key" = tls_private_key.k8s_tls_private_key.private_key_pem
  }
  type = "kubernetes.io/tls"
}

resource "kubernetes_secret" "kong_tls_secret" {
  metadata {
    name      = "kong-manager-certs"
    namespace = local.k8s_namespace
  }
  data = {
    "tls.crt" = tls_self_signed_cert.kong_manager_tls_self_signed_cert.cert_pem
    "tls.key" = tls_private_key.kong_tls_private_key.private_key_pem
  }
  type = "kubernetes.io/tls"
}

resource "kubernetes_service_account" "admin_user_k8-ns" {
  metadata {
    name      = local.admin_user
    namespace = local.k8s_namespace
  }
}

resource "kubernetes_service_account" "admin_user_default-ns" {
  metadata {
    name      = local.admin_user
    namespace = "default"
  }
}
#
# resource "kubernetes_service_account" "admin_user_system-ns" {
#   metadata {
#     name      = local.admin_user
#     namespace = "kube-system"
#   }
# }

resource "kubernetes_cluster_role_binding" "admin_k8s_user_binding" {
  metadata {
    name = "${local.admin_user}-k8s"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.admin_user
    namespace = local.k8s_namespace
  }
}

resource "kubernetes_cluster_role_binding" "admin_default__user_binding" {
  metadata {
    name = "${local.admin_user}-default"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.admin_user
    namespace = "default"
  }
}

resource "helm_release" "k8s-dashboard" {
  # repository = "oci://${var.artifactory_url}/eonax/helm"
  # chart      = local.k8s_dashboard_chart
  # version    = local.k8s_dashboard_chart_version
  chart     = "../../charts/${local.k8s_dashboard_chart}-${local.k8s_dashboard_chart_version}.tgz"
  name      = local.k8s_dashboard_release_name
  namespace = local.k8s_namespace

  values = [
    yamlencode({
      "metricsScraper" = {
        "enabled" = true
      }
      "deployment"= {
        "kong" = {
          "enabled" = false
        }
      }

      "kong" = {
        "enabled" = false
        "ingressController" = {
          "enabled" = false
          "env" = {
            "KONG_CLIENT_BODY_BUFFER_SIZE" = "512k"
            "CLIENT_BODY_BUFFER_SIZE" = "512k"
            "nginx_admin_client_body_buffer_size" = "512k"
            "http_client_body_buffer_size" = "512k"
          }
        }
        "manager" = {
          "enabled" = true
          "type"    = "ClusterIP"
          "tls" = {
            "enabled"     = false
            "servicePort" = 443
          }
          ingress = {
            enabled          = true
            ingressClassName = "nginx"
            hostname         = "kong-manager.127.0.0.1.nip.io"
            annotations = {
              "kubernetes.io/ingress.class" = "kong"
              "konghq.com/strip-path"       = "true"
              "konghq.com/protocols"        = "http"
              # "konghq.com/https-redirect-status-code" = "301"
            }
            "tls"    = "kong-manager-certs"
            path     = "/"
            # pathType = "Prefix"
          }
        }
        "proxy" = {
          "type" = "ClusterIP"
          "http" = {
            "enabled" = true
          }
        }
      }
      "app" = {
        "ingress" = {
          "enabled"               = false
          "ingressClassName"      = "nginx"
          "useDefaultAnnotations" = true
          "useDefaultIngressClass" = false
          "path"                  = "/"
          # "pathType"              = "Prefix"
          "hosts" = [
            "kubernetes.127.0.0.1.nip.io"
          ]
          "issuer" = {
            "name"  = "selfsigned"
            "scope" = "disabled"
          }
          "tls" = {
            "enabled"    = false
            "secretName" = "kubernetes-dashboard-certs"
          }
          annotations = {
            "kubernetes.io/ingress.class" = "nginx"
            # "konghq.com/strip-path"       = "true"
            # "konghq.com/protocols"        = "http"
          }
        }
      }

      "api" = {
        "role" = "api"
        "volumes" = [
          {
            "name" = "tmp-volume"
            "emptyDir" = {}
          },
          {
            "name" = "tls-secret"
            "secret" = {
              "secretName" = "kubernetes-dashboard-certs"
            }
          }
        ]
        "containers" = {
          "ports" = [
            {
              "name"          = "api"
              "containerPort" = 8000
              "protocol"      = "TCP"
            }
          ]
          "args" = [
            "--insecure-port=8000",
            # "--namespace=${local.k8s_namespace}",
            # "--port=8001",
            "--v=5",
            "--disable-csrf-protection=false",
            "--act-as-proxy=true",
            "--auto-generate-certificates=false",
            # "--tls-cert-file=tls.crt",
            # "--tls-key-file=tls.key"
          ]
          "env" = []
          "volumeMounts" = [
            {
              "name"      = "tls-secret"
              "mountPath" = "/certs"
              "readOnly"  = true
            },
            {
              "mountPath" = "/tmp"
              "name"      = "tmp-volume"
            }
          ]
          "resources" = {
            "requests" = {
              "cpu"    = "100m"
              "memory" = "200Mi"
            }
            "limits" = {
              "cpu"    = "250m"
              "memory" = "400Mi"
            }
          }
        }
      }
      "auth" = {
        "role" = "auth"
        "volumes" = [
          {
            "name" = "tmp-volume"
            "emptyDir" = {}
          },
          {
            "name" = "tls-secret"
            "secret" = {
              "secretName" = "kubernetes-dashboard-certs"
            }
          }
        ]
        "scaling" = {
          "replicas"             = 1
          "revisionHistoryLimit" = 10
        }
        "containers" = {
          "ports" = [
            {
              "name"          = "auth"
              "containerPort" = 8000
              "protocol"      = "TCP"
            }
          ]
          "args" = [
            "--port=8000",
            "--v=5",
            # "--apiserver-host=kubernetes-dashboard-api:8001",
            # "--act-as-proxy=true",
            # "--insecure-port=8000",
          ]
          "env" = []
          "volumeMounts" = [
            {
              "name"      = "tls-secret"
              "mountPath" = "/certs"
              "readOnly"  = true
            },
            {
              "mountPath" = "/tmp"
              "name"      = "tmp-volume"
            }
          ]
          "resources" = {
            "requests" = {
              "cpu"    = "100m"
              "memory" = "200Mi"
            }
            "limits" = {
              "cpu"    = "250m"
              "memory" = "400Mi"
            }
          }
        }
      }

      "web" = {
        "role" = "web"
        "image" = {
          "repository" = "docker.io/kubernetesui/dashboard-web"
          "tag"        = "1.5.1"
        }

        "volumes" = [
          {
            "name" = "tmp-volume"
            "emptyDir" = {}
          },
          {
            "name" = "tls-secret"
            "secret" = {
              "secretName" = "kubernetes-dashboard-certs"
            }
          }
        ]
        "containers" = {
          "ports" = [
            {
              "name"          = "web"
              "containerPort" = 8000
              "protocol"      = "TCP"
            }
          ]
          "args" = [
            "--insecure-port=8000",
            "--port=8001",
            "--auto-generate-certificates=false",
            # "--namespace=${local.k8s_namespace}",
            "--v=5",
            # "--tls-cert-file=tls.crt",
            # "--tls-key-file=tls.key"
          ]
          "env" = []
          "volumeMounts" = [
            {
              "name"      = "tls-secret"
              "mountPath" = "/certs"
              "readOnly"  = true
            },
            {
              "mountPath" = "/tmp"
              "name"      = "tmp-volume"
            }
          ]
          "resources" = {
            "requests" = {
              "cpu"    = "100m"
              "memory" = "200Mi"
            }
            "limits" = {
              "cpu"    = "250m"
              "memory" = "400Mi"
            }
          }
        }
      }

      "cert-manager" = {
        "enabled" = false
      }
    })
  ]
  depends_on = [kubernetes_secret.kubernetes_tls_secret]
}
resource "kubernetes_ingress_v1" "kubernetes_dashboard" {
  metadata {
    name      = "kubernetes-dashboard-ingress"
    namespace = local.k8s_namespace
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      host = "kubernetes-dashboard.127.0.0.1.nip.io"
      http {
        path {
          path      = "/api/v1/login"
          path_type = "Prefix"
          backend {
            service {
              name = "${local.k8s_dashboard_release_name}-auth"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/api/v1/csrftoken/login"
          path_type = "Prefix"
          backend {
            service {
              name = "${local.k8s_dashboard_release_name}-auth"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/api/v1/me"
          path_type = "Prefix"
          backend {
            service {
              name = "${local.k8s_dashboard_release_name}-auth"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = "${local.k8s_dashboard_release_name}-api"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/metrics"
          path_type = "Prefix"
          backend {
            service {
              name = "${local.k8s_dashboard_release_name}-api"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "${local.k8s_dashboard_release_name}-web"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "admin_user_secret" {
  metadata {
    name      = local.admin_user
    namespace = local.k8s_namespace
    annotations = {
      "kubernetes.io/service-account.name" = local.admin_user
    }
  }
  type = "kubernetes.io/service-account-token"
}