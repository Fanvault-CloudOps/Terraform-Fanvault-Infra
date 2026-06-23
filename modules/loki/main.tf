locals {
  loki_service_url = "http://loki.monitoring.svc.cluster.local:3100"
}

# ── Loki ──────────────────────────────────────────────────────────────────────
resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = var.loki_version
  namespace        = "monitoring"
  create_namespace = false
  timeout          = 300

  values = [templatefile("${path.module}/values/loki.yaml.tpl", {
    storage_size    = var.loki_storage_size
    retention_hours = var.loki_retention_hours
  })]
}

# ── Promtail ──────────────────────────────────────────────────────────────────
resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = var.promtail_version
  namespace        = "monitoring"
  create_namespace = false
  timeout          = 180

  values = [templatefile("${path.module}/values/promtail.yaml.tpl", {
    cluster_name = var.cluster_name
    loki_url     = local.loki_service_url
  })]

  depends_on = [helm_release.loki]
}
