locals {
  tempo_stack_configuration = <<-EOT
      multitenancy_enabled: true
      usage_report:
        reporting_enabled: false
      cache:
        caches:
          - memcached:
              addresses: {{ include "grafana-tempo.memcached.url" . }}
              timeout: 500ms
              consistent_hash: true
            roles:
              - bloom
              - trace-id-index
              - frontend-search
      compactor:
        compaction:
          block_retention: 168h
          max_block_bytes: 104857600
        ring:
          kvstore:
            store: memberlist
      distributor:
        ring:
          kvstore:
            store: memberlist
        receivers:
          {{- if  or (.Values.tempo.traces.jaeger.thriftCompact) (.Values.tempo.traces.jaeger.thriftBinary) (.Values.tempo.traces.jaeger.thriftHttp) (.Values.tempo.traces.jaeger.grpc) }}
          jaeger:
            protocols:
              {{- if .Values.tempo.traces.jaeger.thriftCompact }}
              thrift_compact:
                endpoint: 0.0.0.0:6831
              {{- end }}
              {{- if .Values.tempo.traces.jaeger.thriftBinary }}
              thrift_binary:
                endpoint: 0.0.0.0:6832
              {{- end }}
              {{- if .Values.tempo.traces.jaeger.thriftHttp }}
              thrift_http:
                endpoint: 0.0.0.0:14268
              {{- end }}
              {{- if .Values.tempo.traces.jaeger.grpc }}
              grpc:
                endpoint: 0.0.0.0:14250
              {{- end }}
          {{- end }}
          {{- if .Values.tempo.traces.zipkin }}
          zipkin:
            endpoint: 0.0.0.0:9411
          {{- end }}
          {{- if or (.Values.tempo.traces.otlp.http) (.Values.tempo.traces.otlp.grpc) }}
          otlp:
            protocols:
              {{- if .Values.tempo.traces.otlp.http }}
              http:
                endpoint: 0.0.0.0:55681
              {{- end }}
              {{- if .Values.tempo.traces.otlp.grpc }}
              grpc:
                endpoint: 0.0.0.0:4317
              {{- end }}
          {{- end }}
          {{- if .Values.tempo.traces.opencensus }}
          opencensus:
            endpoint: 0.0.0.0:55678
          {{- end }}
      querier:
        frontend_worker:
          frontend_address: {{ include "grafana-tempo.query-frontend.fullname" . }}-headless:{{ .Values.queryFrontend.service.ports.grpc }}
      query_frontend:
        multi_tenant_queries_enabled: true
      ingester:
        flush_check_period: 10s
        trace_idle_period: 10s
        lifecycler:
          ring:
            replication_factor: 1
            kvstore:
              store: memberlist
          tokens_file_path: {{ .Values.tempo.dataDir }}/tokens.json
      metrics_generator:
        ring:
          kvstore:
            store: memberlist
        processor:
          service_graphs:
              wait: 10s
          span_metrics:
            enable_target_info: true
            intrinsic_dimensions:
              service: true
              span_name: true
              span_kind: true
              status_code: true
        storage:
          path: {{ .Values.tempo.dataDir }}/wal
          remote_write: {{ include "common.tplvalues.render" (dict "value" .Values.metricsGenerator.remoteWrite "context" $) | nindent 6 }}
      memberlist:
        abort_if_cluster_join_fails: false
        join_members:
          - {{ include "grafana-tempo.gossip-ring.fullname" . }}
      overrides:
        defaults:
          metrics_generator:
            processors:
             - service-graphs
             - span-metrics
        per_tenant_override_config: /bitnami/grafana-tempo/conf/overrides.yaml

      server:
        http_listen_port: {{ .Values.tempo.containerPorts.web }}
      storage:
        trace:
          backend: azure
          blocklist_poll: 5m
          blocklist_poll_tenant_index_builders: 1
          azure:
            storage_account_name: $${AZURE_STORAGE_ACCOUNT_NAME}
            storage_account_key: $${AZURE_STORAGE_ACCOUNT_KEY}
            container_name: $${AZURE_CONTAINER_NAME}
            use_v2_sdk: true
          local:
            path: {{ .Values.tempo.dataDir }}/traces
          wal:
            path: {{ .Values.tempo.dataDir }}/wal
      EOT
}