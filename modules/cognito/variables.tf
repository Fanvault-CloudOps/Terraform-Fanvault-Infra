variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment (dev, prod, etc.)"
}

variable "callback_urls" {
  type        = list(string)
  description = "List of allowed callback URLs for the identity provider client"
  default     = ["http://localhost/callback"]
}

variable "logout_urls" {
  type        = list(string)
  description = "List of allowed logout URLs for the identity provider client"
  default     = ["http://localhost/logout"]
}
