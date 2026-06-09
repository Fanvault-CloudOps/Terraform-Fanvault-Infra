variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "A standard prefix for resources created by this project"
  default     = "fanvault"
}

variable "environment" {
  type        = string
  description = "Application deployment environment context tag"
  default     = "production"
}

variable "admin_ssh_ip" {
  type        = string
  description = "The public IP of the administrator for secure SSH access (Bastion)"
  default     = "0.0.0.0/0" # In real usage, this should be restricted to e.g. "198.51.100.50/32"
}

variable "key_name" {
  type        = string
  description = "The EC2 key pair name to use for SSH authentication"
  default     = "fanvault-key"
}

variable "cors_origin" {
  type        = string
  description = "Allowed CORS origin for both backend services (e.g. https://fanvault.example.com)"
  default     = "https://fanvault.example.com"
}

# ── Secrets — supply via terraform.tfvars or TF_VAR_* env variables ──────────
# These are stored as SecureString in SSM Parameter Store by the ssm module.
# Never commit actual values to source control.

variable "jwt_secret" {
  type        = string
  description = "JWT access token signing secret — minimum 32 characters"
  sensitive   = true
  default     = "CHANGE_ME_TO_A_RANDOM_32_PLUS_CHAR_STRING"
}

variable "jwt_refresh_secret" {
  type        = string
  description = "JWT refresh token signing secret — different from jwt_secret"
  sensitive   = true
  default     = "CHANGE_ME_TO_A_DIFFERENT_RANDOM_32_PLUS_CHAR_STRING"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name in the format 'owner/repo' (e.g. 'Savitxr/Fanvault-v2')"
  default     = "Savitxr/Fanvault-v2"
}

