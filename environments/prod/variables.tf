variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Target Region"
}

variable "project_name" {
  type        = string
  default     = "fanvault"
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment tag"
}

variable "github_repo" {
  type        = string
  default     = "Savitxr/Fanvault-v2"
  description = "GitHub repository for OIDC trust relationship"
}

variable "jwt_secret" {
  type        = string
  description = "JWT access token signing secret (minimum 32 chars)"
  sensitive   = true
}

variable "jwt_refresh_secret" {
  type        = string
  description = "JWT refresh token signing secret (minimum 32 chars, must differ from jwt_secret)"
  sensitive   = true
}
