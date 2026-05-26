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
