variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "account_id" {
  type        = string
  description = "AWS Account ID to prevent naming collisions"
}
