output "alb_dns_name" {
  value       = module.compute.alb_dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "bastion_public_ip" {
  value       = module.compute.bastion_public_ip
  description = "The public IP address of the Bastion host (Jump Box)"
}

output "github_actions_role_arn" {
  value       = module.iam.github_actions_role_arn
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC"
}

output "event_bus_name" {
  value       = module.event_driven.event_bus_name
  description = "Name of the EventBridge custom event bus"
}

output "event_dlq_name" {
  value       = module.event_driven.event_dlq_name
  description = "Name of the SQS Dead-Letter Queue"
}




