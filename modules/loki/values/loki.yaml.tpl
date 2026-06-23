## Loki Helm values — SingleBinary mode for single-cluster deployment
## Template variables: storage_size, retention_hours

# Explicitly declare SingleBinary deployment mode. Without this the chart's
# validate.yaml rejects the config when scalable-mode defaults (backend/read/write)
# still have replicas > 0.
deploymentMode: SingleBinary

loki:
  auth_enabled: false

  commonConfig:
    replication_factor: 1

  storage:
    type: filesystem

  limits_config:
    retention_period: ${retention_hours}h
    ingestion_rate_mb: 16
    ingestion_burst_size_mb: 32
    max_query_lookback: ${retention_hours}h

  compactor:
    retention_enabled: true
    retention_delete_delay: 2h
    retention_delete_worker_count: 150
    delete_request_store: filesystem

  # Helm chart v6.x validate.yaml checks for schemaConfig (camelCase).
  # The chart template converts this to schema_config in the rendered Loki config.
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

singleBinary:
  replicas: 1

  persistence:
    enabled: true
    storageClass: gp2
    size: ${storage_size}

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

# Zero out scalable-mode components — required when deploymentMode is SingleBinary
# to satisfy the chart's validate.yaml mutual-exclusion check.
backend:
  replicas: 0

read:
  replicas: 0

write:
  replicas: 0

# Disable self-monitoring to reduce resource usage in dev
monitoring:
  selfMonitoring:
    enabled: false
    grafanaAgent:
      installOperator: false
  lokiCanary:
    enabled: false
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack

# Disable test pod
test:
  enabled: false

# Gateway is not needed for single-binary mode with direct Promtail connection
gateway:
  enabled: false
