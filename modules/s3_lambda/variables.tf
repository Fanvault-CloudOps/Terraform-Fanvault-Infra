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
