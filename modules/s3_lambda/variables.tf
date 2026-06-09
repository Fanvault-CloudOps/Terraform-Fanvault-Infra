variable "lambda_role_arn" {
  type        = string
  description = "The ARN of the IAM execution role for Lambda"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "cors_origin" {
  type        = string
  description = "Allowed CORS origin for both backend services"
}

