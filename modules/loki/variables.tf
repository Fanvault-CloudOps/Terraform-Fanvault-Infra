variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev/prod)"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name (used as Promtail cluster label)"
}

variable "loki_version" {
  type        = string
  description = "Loki Helm chart version"
  default     = "6.20.0"
}

variable "promtail_version" {
  type        = string
  description = "Promtail Helm chart version"
  default     = "6.16.6"
}

variable "loki_storage_size" {
  type        = string
  description = "PVC size for Loki data"
  default     = "20Gi"
}

variable "loki_retention_hours" {
  type        = number
  description = "Log retention period in hours (dev: 168 = 7d, prod: 720 = 30d)"
  default     = 168
}
