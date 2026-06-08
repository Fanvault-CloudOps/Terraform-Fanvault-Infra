output "alb_dns_name" {
  value       = module.compute.alb_dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "bastion_public_ip" {
  value       = module.compute.bastion_public_ip
  description = "The public IP address of the Bastion host (Jump Box)"
}


