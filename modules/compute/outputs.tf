output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP address of the Bastion jump host"
}

output "mongodb_private_ip" {
  value       = aws_instance.mongodb.private_ip
  description = "Private IP address of the MongoDB instance"
}
