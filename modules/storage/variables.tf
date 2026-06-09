# =============================================================================
# Storage Module — Variables
# =============================================================================

variable "project_name" {
  type        = string
  description = "Project name prefix used in resource names"
}

variable "environment" {
  type        = string
  description = "Environment (production, staging, dev)"
  default     = "production"
}

variable "billing_mode" {
  type        = string
  description = "DynamoDB billing mode: PAY_PER_REQUEST or PROVISIONED"
  default     = "PAY_PER_REQUEST"
}

variable "enable_pitr" {
  type        = bool
  description = "Enable Point-in-Time Recovery on all tables"
  default     = true
}

variable "enable_encryption" {
  type        = bool
  description = "Enable server-side encryption using AWS-owned KMS key"
  default     = true
}

variable "lambda_role_arn" {
  type        = string
  description = "The ARN of the IAM execution role for Lambda"
}

variable "cors_origin" {
  type        = string
  description = "Allowed CORS origin for both backend services"
}
