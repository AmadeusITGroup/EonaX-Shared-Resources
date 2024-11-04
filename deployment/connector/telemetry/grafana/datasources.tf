locals {

  prometheus_datasource_name    = "prometheus-datasource"
  elasticsearch_datasource_name = "elasticsearch-datasource"
  loki_datasource_name          = "loki-datasource"
  tempo_datasource_name         = "tempo-datasource"

  tempo_multi_tenant_header = join("|", [for p in var.participants : p.name])

  grafana_datasources = {
    apiVersion = 1

    deleteDatasources = [
      {
        "name" = local.elasticsearch_datasource_name
      },
      {
        "name" = local.loki_datasource_name
      },
      {
        "name" = local.tempo_datasource_name
      },
      {
        "name" = local.prometheus_datasource_name
      },
    ],
    datasources = [
      {
        "basicAuth"     = true
        "basicAuthUser" = "elastic"
        "editable"      = true
        "isDefault"     = false
        "jsonData" = {
          "includeFrozen"     = false
          "index"             = ""
          "logLevelField"     = ""
          "logMessageField"   = ""
          "oauthPassThru"     = false
          "sigV4Auth"         = false
          "timeField"         = "@timestamp"
          "tlsAuth"           = false
          "tlsAuthWithCACert" = true
          "tlsSkipVerify"     = false
          "xpack"             = true
        }
        "name" = "Elasticsearch"
        "secureJsonData" = {
        }
        "type"        = "elasticsearch"
        "typeLogoUrl" = "/public/app/plugins/datasource/elasticsearch/img/elasticsearch.svg"
        "typeName"    = "Elasticsearch"
        "uid"         = local.elasticsearch_datasource_name
        "url"         = var.elasticsearch_url
      },
      {
        "name"        = "loki"
        "type"        = "loki"
        "type_name"   = "Loki"
        "editable"    = true
        type_logo_url = "public/app/plugins/datasource/loki/img/loki_icon.svg"
        "access"      = "proxy"
        "user"        = ""
        "database"    = ""
        "basic_auth"  = false
        "is_default"  = false
        "json_data" = {}
        "read_only"   = false
        "url"         = var.loki_url
        "uid"         = local.loki_datasource_name
      },
      {
        "basicAuth" = false
        "database"  = ""
        "editable"  = true
        "isDefault" = false
        "jsonData" = {
          "exemplarTraceIdDestinations" = [
            {
              "datasourceUid" = local.tempo_datasource_name
              "name"          = "traceID"
            }
          ]
          "httpMethod" = "POST"
        }
        "name"        = "Prometheus"
        "type"        = "prometheus"
        "typeLogoUrl" = "/public/app/plugins/datasource/prometheus/img/prometheus_logo.svg"
        "typeName"    = "Prometheus"
        "uid"         = local.prometheus_datasource_name
        "url"         = var.prometheus_url
        "user"        = ""
      },
      {
        "basicAuth" = false
        "database"  = ""
        "editable"  = true
        "isDefault" = true
        "jsonData" = {
          "httpHeaderName1" = "elastic"
          "httpHeaderName2" = "Authorization"
          "httpHeaderName3" = "X-Scope-OrgID"
          "nodeGraph" = {
            "enabled" = true
          }
          "search" : {
            "filters" : [
              {
                "id" : "service-name",
                "operator" : "=",
                "scope" : "resource",
                "tag" : "service.name"
              },
              {
                "id" : "span-name",
                "operator" : "=",
                "scope" : "span",
                "tag" : "name"
              }
            ]
          }
        }

        "name" = "Tempo"

        "secureJsonData" = {
          "httpHeaderValue2" = "Bearer WjB1RVY0NEJmWF9lNndvU29Wb286M3l4bmowcGlRTC1vQktfNXBVVUstZw=="
          "httpHeaderValue3" = local.tempo_multi_tenant_header
        }
        "serviceMap" = {
          "datasourceUid" = local.prometheus_datasource_name
        }
        "tlsSkipVerify" = true
        "tracesToLogsV2" = {
          "customQuery"   = false
          "datasourceUid" = local.elasticsearch_datasource_name
          "filterBySpanID" : false,
          "filterByTraceID" : true,
          "tags" : [
            {
              "key" : "service_name",
              "value" : "service.name"
            }
          ]
        }
        "type"        = "tempo"
        "typeLogoUrl" = "/public/app/plugins/datasource/tempo/img/tempo_logo.svg"
        "typeName"    = "Tempo"
        "uid"         = local.tempo_datasource_name
        "url"         = var.tempo_query_url
        "user"        = ""
      },
    ]
  }
}