locals {
  sql_files_path = fileset(path.module, "sql/*.sql")
  sql_files_full_path = formatlist("${path.module}/%s", local.sql_files_path)
  sql_files = [for p in local.sql_files_full_path : file(p)]
  db_bootstrap_sql_script = join("\n", local.sql_files)


  service_account = "default"
  k8s_namespace   = "default"
  environment     = "local"

  participants = []
  elastic_stack_version    = "8.13.0"
  opensearch_stack_version = "2.17.1"
  tempo_stack_version      = "2.5.0"
  loki_version             = "3.2.0"
  prometheus_version       = "v2.55.0"
  grafana_version          = "11.3.0"
  opentelemetry-collector = "eonax-otel-collector"

  # Prometheus
  prometheus_url = length(module.prometheus_stack) > 0  ? module.prometheus_stack[0].prometheus_url : ""

  # Elastic
  elastic_stack_cluster_name = "eonax-elastic"
  elasticsearch_url          = ""
  # fleet_url                  = length(module.elastic_stack) > 0 ? module.elastic_stack[0].fleet_apm_url : ""


  # Loki
  has_loki = length(module.loki_stack) > 0
  loki_url = local.has_loki ? module.loki_stack[0].loki_url : ""

  node_groups = ["master", "data"]
  elasticsearch_service_names = [for node in local.node_groups : format("${local.elastic_stack_cluster_name}-%s", node)]
  fleet_service_name          = "${local.elastic_stack_cluster_name}-fleet"
  kibana_service_name = "kibana"

  # Tempo
  has_tempo             = length(module.grafana_tempo_stack) > 0
  tempo_distributor_url = local.has_tempo ? module.grafana_tempo_stack[0].tempo_distributor_url : ""
  tempo_query_url       = local.has_tempo ? module.grafana_tempo_stack[0].tempo_query_url : ""


  tempo_stack_enabled      = var.telemetry_enabled && var.tempo_stack_enabled
  loki_enabled             = var.telemetry_enabled && var.loki_enabled
  opensearch_stack_enabled = var.telemetry_enabled && var.opensearch_stack_enabled
  k8s-dashboard_enabled    = var.telemetry_enabled && var.k8s-dashboard_enabled
  prometheus_stack_enabled = var.telemetry_enabled && var.prometheus_stack_enabled
  grafana_enabled          = var.telemetry_enabled && var.grafana_enabled
}

#############################
## DB BOOTSTRAP SQL SCRIPT ##
#############################

resource "kubernetes_config_map" "db-bootstrap-sql-script" {

  metadata {
    name = "db-bootstrap-sql-script"
  }

  data = {
    "bootstrap.sql" = local.db_bootstrap_sql_script
  }
}

module "db" {
  source = "./db-bootstrap"

  db_name                                = var.db_name
  db_server_fqdn                         = var.db_server_fqdn
  db_user                                = var.db_username
  db_user_password                       = var.db_password
  postgres_admin_credentials_secret_name = var.postgres_admin_credentials_secret_name
  db_bootstrap_sql_script_configmap_name = kubernetes_config_map.db-bootstrap-sql-script.metadata.0.name
}

resource "kubernetes_secret" "db-user-credentials" {

  metadata {
    name = "${var.db_name}-db-credentials"
  }

  data = {
    "username" = var.db_username
    "password" = var.db_password
  }
}


module "opentelemetry-collector" {
  count                    = var.telemetry_enabled ? 1 : 0
  source                   = "./telemetry/opentelemetry-collector"
  k8s_namespace            = "default"
  environment              = "local"
  service_account          = "admin-user"
  elastic_stack_enabled    = false
  tempo_stack_enabled      = true
  prometheus_stack_enabled = true
  tempo_distributor_url    = local.tempo_distributor_url
  loki_url                 = local.tempo_distributor_url
  replica_count            = 1
  cpu                      = 1
  ram                      = "512Mi"
}

############
## TRACES ##
############
module "grafana_tempo_stack" {
  count             = local.tempo_stack_enabled ? 1 : 0
  source            = "./telemetry/tempo"
  k8s_namespace     = local.k8s_namespace
  environment       = local.environment
  service_account   = local.service_account
  tempo_version     = local.tempo_stack_version
  prometheus_url    = local.prometheus_url
  generator_enabled = true
  cpu               = "200m"
  ram               = "512Mi"
}

module "loki_stack" {
  count           = local.loki_enabled ? 1 : 0
  source          = "./telemetry/loki"
  k8s_namespace   = local.k8s_namespace
  environment     = local.environment
  service_account = local.service_account
  loki_version    = local.loki_version
  prometheus_url  = local.prometheus_url
  cpu             = "200m"
  ram             = "512Mi"
}


module "opensearch_stack" {
  count              = local.opensearch_stack_enabled ? 1 : 0
  source             = "./telemetry/opensearch"
  k8s_namespace      = local.k8s_namespace
  environment        = local.environment
  service_account    = local.service_account
  opensearch_version = local.opensearch_stack_version
  cpu                = "200m"
  ram                = "512Mi"
}


module "k8s_dashboard" {
  count           = local.k8s-dashboard_enabled ? 1 : 0
  source          = "./telemetry/k8s-dashboard"
  k8s_namespace   = local.k8s_namespace
  environment     = local.environment
  service_account = "admin-user"
  replica_count   = 1
}

module "prometheus_stack" {
  count                           = local.prometheus_stack_enabled ? 1 : 0
  source                          = "./telemetry/prometheus"
  k8s_namespace                   = local.k8s_namespace
  environment                     = local.environment
  service_account                 = local.service_account
  prometheus_version              = local.prometheus_version
  opentelemetry_collector_service = local.opentelemetry-collector
  replica_count                   = 1
  cpu                             = "200m"
  ram                             = "512Mi"
}

module "grafana_dashboard" {
  count             = local.grafana_enabled ? 1 : 0
  source            = "./telemetry/grafana"
  participants      = local.participants
  k8s_namespace     = local.k8s_namespace
  environment       = local.environment
  service_account   = local.service_account
  grafana_version   = local.grafana_version
  elasticsearch_url = local.elasticsearch_url
  prometheus_url    = local.prometheus_url
  tempo_query_url   = local.tempo_query_url
  loki_url          = local.loki_url
  replica_count     = 1
  cpu               = "200m"
  ram               = "512Mi"
}