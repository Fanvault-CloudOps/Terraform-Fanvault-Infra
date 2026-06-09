# =============================================================================
# DynamoDB Module — Outputs
# =============================================================================

output "table_users_name" {
  value       = aws_dynamodb_table.users.name
  description = "Name of the fanvault-users DynamoDB table"
}

output "table_profiles_name" {
  value       = aws_dynamodb_table.profiles.name
  description = "Name of the fanvault-profiles DynamoDB table"
}

output "table_products_name" {
  value       = aws_dynamodb_table.products.name
  description = "Name of the fanvault-products DynamoDB table"
}

output "table_orders_name" {
  value       = aws_dynamodb_table.orders.name
  description = "Name of the fanvault-orders DynamoDB table"
}

output "table_users_arn" {
  value       = aws_dynamodb_table.users.arn
  description = "ARN of the fanvault-users table (used in IAM policies)"
}

output "table_profiles_arn" {
  value       = aws_dynamodb_table.profiles.arn
  description = "ARN of the fanvault-profiles table"
}

output "table_products_arn" {
  value       = aws_dynamodb_table.products.arn
  description = "ARN of the fanvault-products table"
}

output "table_orders_arn" {
  value       = aws_dynamodb_table.orders.arn
  description = "ARN of the fanvault-orders table"
}

output "table_audit_logs_name" {
  value       = aws_dynamodb_table.audit_logs.name
  description = "Name of the fanvault-audit-logs DynamoDB table"
}

output "table_metadata_name" {
  value       = aws_dynamodb_table.metadata.name
  description = "Name of the fanvault-metadata DynamoDB table"
}

output "table_audit_logs_arn" {
  value       = aws_dynamodb_table.audit_logs.arn
  description = "ARN of the fanvault-audit-logs table (used in IAM policies)"
}

output "table_metadata_arn" {
  value       = aws_dynamodb_table.metadata.arn
  description = "ARN of the fanvault-metadata table (used in IAM policies)"
}
