variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "log_retention_days" {
  type        = number
  description = "Specifies the number of days you want to retain log events"
  default     = 7
}
