variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "alert_email" {
  type        = string
  description = "Email address for direct operational alerts subscription (optional)"
  default     = ""
}
