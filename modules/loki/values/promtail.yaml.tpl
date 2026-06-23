## Promtail Helm values — DaemonSet log collector
## Template variable: cluster_name, loki_url

config:
  logLevel: info
  serverPort: 3101

  clients:
    - url: ${loki_url}/loki/api/v1/push

  snippets:
    pipelineStages:
      - cri: {}

    extraRelabelConfigs:
      # Attach cluster label to every log line
      - action: replace
        replacement: ${cluster_name}
        targetLabel: cluster

      # Copy node name from k8s meta
      - source_labels: [__meta_kubernetes_pod_node_name]
        action: replace
        targetLabel: node

      # Namespace
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        targetLabel: namespace

      # Pod name
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        targetLabel: pod

      # Container name
      - source_labels: [__meta_kubernetes_pod_container_name]
        action: replace
        targetLabel: container

      # App label for easy filtering
      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
        action: replace
        targetLabel: app

      # Drop empty streams
      - action: drop
        regex: ""
        source_labels: [namespace]

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Run on ALL nodes (including Karpenter-provisioned nodes)
tolerations:
  - operator: Exists

# Mount /var/log for host log access
extraVolumes:
  - name: machine-id
    hostPath:
      path: /etc/machine-id

extraVolumeMounts:
  - name: machine-id
    mountPath: /etc/machine-id
    readOnly: true

serviceMonitor:
  enabled: true
  labels:
    release: kube-prometheus-stack
