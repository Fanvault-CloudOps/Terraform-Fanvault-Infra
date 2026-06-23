output "loki_service_url" {
  value       = "http://loki.monitoring.svc.cluster.local:3100"
  description = "Loki push endpoint (cluster-internal URL for Promtail/Grafana)"
}
